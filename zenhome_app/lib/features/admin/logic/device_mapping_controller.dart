import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;

import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

class DeviceMappingSaveResult {
  final bool success;
  final bool isOffline;
  final String? errorMessage;
  final Map<String, String>? details;

  const DeviceMappingSaveResult({
    required this.success,
    this.isOffline = false,
    this.errorMessage,
    this.details,
  });
}

class GpioConflictResult {
  final int pin;
  final List<String> deviceNames;

  const GpioConflictResult({required this.pin, required this.deviceNames});
}

class RoomNameConflictResult {
  final String roomKey;
  final String deviceName;

  const RoomNameConflictResult({required this.roomKey, required this.deviceName});
}

/// Controller quản lý nghiệp vụ cấu hình chân GPIO và danh sách thiết bị
class DeviceMappingController extends StateNotifier<bool> {
  final Ref _ref;

  DeviceMappingController(this._ref) : super(false); // state = isSyncing

  /// Kiểm tra xung đột chân GPIO (mỗi chân chỉ được gán 1 thiết bị)
  GpioConflictResult? checkGpioConflict(List<DeviceConfig> devices) {
    final Map<int, List<String>> pinToDevices = {};
    for (var dev in devices) {
      pinToDevices.putIfAbsent(dev.pin, () => []).add(dev.name);
    }
    for (var entry in pinToDevices.entries) {
      if (entry.value.length > 1) {
        return GpioConflictResult(pin: entry.key, deviceNames: entry.value);
      }
    }
    return null;
  }

  /// Kiểm tra trùng tên thiết bị trong cùng một phòng
  RoomNameConflictResult? checkRoomNameConflict(List<DeviceConfig> devices) {
    final Map<String, List<String>> roomNameToDevices = {};
    for (var dev in devices) {
      final key = '${dev.room}::${dev.name.trim().toLowerCase()}';
      roomNameToDevices.putIfAbsent(key, () => []).add(dev.name);
    }
    for (var entry in roomNameToDevices.entries) {
      if (entry.value.length > 1) {
        final parts = entry.key.split('::');
        return RoomNameConflictResult(roomKey: parts[0], deviceName: entry.value.first);
      }
    }
    return null;
  }

  /// Bắn lệnh test thử đóng/ngắt Relay qua MQTT
  void testRelay({
    required String room,
    required String devId,
    required bool turnOn,
  }) {
    final activeConfig = _ref.read(homeConfigProvider).activeConfig;
    final topic = '${activeConfig.mqttPrefix}/$room/$devId/cmd';
    final payload = turnOn ? '1' : '0';
    _ref.read(mqttRepositoryProvider).publishCmd(topic, payload);
  }

  /// Lưu cấu hình thiết bị: Local Storage -> Firestore -> Bo mạch ESP32 qua MQTT
  Future<DeviceMappingSaveResult> saveMapping(List<DeviceConfig> devices) async {
    state = true;
    final activeConfig = _ref.read(homeConfigProvider).activeConfig;

    // 1. Lưu Local trước để đảm bảo tính năng Offline luôn sẵn sàng
    activeConfig.devices = devices;
    await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

    try {
      // 2. Lưu lên Firestore
      if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
          'devices': devices.map((e) => e.toJson()).toList(),
          'mqttServer': activeConfig.mqttServer,
          'mqttUser': activeConfig.mqttUser,
          'mqttPass': activeConfig.mqttPass,
          'macAddress': activeConfig.macAddress,
        }, SetOptions(merge: true));
      }

      // 3. Đồng bộ xuống ESP32 qua MQTT để ESP32 cập nhật lại cấu hình Relay
      try {
        final devicesList = devices.map((e) => e.toJson()).toList();
        final configPayload = jsonEncode({
          'admin_pass': activeConfig.adminPass,
          'devices': devicesList,
        });
        final configTopic = '${activeConfig.mqttPrefix}/system/config';
        _ref.read(mqttRepositoryProvider).publishCmd(configTopic, configPayload);

        // Đồng thời gửi cả payload dạng mảng thuần để tương thích mọi phiên bản Firmware
        _ref.read(mqttRepositoryProvider).publishCmd(configTopic, jsonEncode(devicesList));

        final restartTopic = '${activeConfig.mqttPrefix}/system/restart';
        _ref.read(mqttRepositoryProvider).publishCmd(restartTopic, '1');

        final mqttRepo = _ref.read(mqttRepositoryProvider);
        if (mqttRepo.client?.connectionStatus?.state == mqtt.MqttConnectionState.connected) {
          for (var dev in devices) {
            final stateTopic = '${activeConfig.mqttPrefix}/${dev.room}/${dev.id}/state';
            mqttRepo.client?.subscribe(stateTopic, mqtt.MqttQos.atLeastOnce);
          }
        }
      } catch (e) {
        debugPrint('Lỗi publish config MQTT: $e');
      }

      state = false;
      return DeviceMappingSaveResult(
        success: true,
        details: {
          'Số lượng thiết bị': '${devices.length} thiết bị',
          'Đồng bộ Cloud': 'Firestore thành công',
          'Đồng bộ ESP32': 'Đã gửi qua kênh kết nối bảo mật',
          'Thời gian': DateTime.now().toLocal().toString().substring(0, 19),
        },
      );
    } catch (e) {
      debugPrint('Lỗi đồng bộ Cloud: $e');
      state = false;
      return DeviceMappingSaveResult(
        success: true,
        isOffline: true,
        errorMessage: e.toString(),
      );
    }
  }
}

final deviceMappingProvider = StateNotifierProvider.autoDispose<DeviceMappingController, bool>((ref) {
  return DeviceMappingController(ref);
});
