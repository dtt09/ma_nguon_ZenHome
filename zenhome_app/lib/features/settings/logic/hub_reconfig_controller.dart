import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/setup/logic/wifi_provisioning_service.dart';
import 'package:zenhome_app/features/settings/logic/hub_reconfig_state.dart';

class HubReconfigResult {
  final bool success;
  final bool isEspOnline;
  final String? errorMessage;
  final Map<String, String>? details;

  const HubReconfigResult({
    required this.success,
    required this.isEspOnline,
    this.errorMessage,
    this.details,
  });
}

class HubReconfigController extends StateNotifier<HubReconfigState> {
  final Ref _ref;

  HubReconfigController(this._ref) : super(const HubReconfigState());

  /// Quét tìm danh sách Wi-Fi 2.4GHz khả dụng xung quanh
  Future<List<WiFiAccessPoint>> scanWifi() async {
    state = state.copyWith(isScanningWifi: true, clearError: true);
    try {
      final results = await WifiProvisioningService.scanNearbyWifi(espOnly: false);

      final homeAps = results.where((ap) {
        final s = ap.ssid.toLowerCase();
        return !s.startsWith('zenhome') && !s.contains('setup') && ap.ssid.isNotEmpty;
      }).toList();

      final uniqueMap = <String, WiFiAccessPoint>{};
      for (final ap in homeAps) {
        if (!uniqueMap.containsKey(ap.ssid) || ap.level > uniqueMap[ap.ssid]!.level) {
          uniqueMap[ap.ssid] = ap;
        }
      }
      final uniqueList = uniqueMap.values.toList();
      state = state.copyWith(isScanningWifi: false, nearbyWifiList: uniqueList);
      return uniqueList;
    } catch (e) {
      state = state.copyWith(
        isScanningWifi: false,
        errorMessage: 'Lỗi khi quét sóng Wi-Fi: $e',
      );
      return [];
    }
  }

  /// Áp dụng cấu hình Wi-Fi & MQTT mới sang Hub ESP32 và lưu trữ đám mây
  Future<HubReconfigResult> applyConfig({
    required String newSsid,
    required String newWifiPass,
    required String newServer,
    required String newUser,
    required String newPass,
    required String newAdminPass,
  }) async {
    state = state.copyWith(isApplying: true, clearError: true);

    try {
      final activeConfig = _ref.read(homeConfigProvider).activeConfig;
      final isEspOnline = _ref.read(mqttRepositoryProvider).isEspOnline;

      // 1. Nếu Hub Online: Bắn gói tin JSON OTA tới topic ${mqttPrefix}/system/config
      if (isEspOnline) {
        final payload = jsonEncode({
          'wifi_ssid': newSsid,
          'wifi_pass': newWifiPass,
          'mqtt_server': newServer,
          if (newUser.isNotEmpty) 'mqtt_user': newUser,
          if (newPass.isNotEmpty) 'mqtt_pass': newPass,
          'mqtt_prefix': activeConfig.mqttPrefix,
          'admin_pass': newAdminPass,
        });

        _ref.read(mqttRepositoryProvider).publishCmd(
          '${activeConfig.mqttPrefix}/system/config',
          payload,
        );

        // Đợi 800ms để đảm bảo gói tin gửi trọn vẹn qua MQTT TLS
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // 2. Cập nhật cấu hình vào Local Storage của ứng dụng
      final oldServer = activeConfig.mqttServer;
      final oldUser = activeConfig.mqttUser;
      final oldPass = activeConfig.mqttPass;

      activeConfig.mqttServer = newServer;
      activeConfig.mqttUser = newUser;
      activeConfig.mqttPass = newPass;
      activeConfig.adminPass = newAdminPass;

      await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

      // 3. Cập nhật lên Cloud Firestore nếu tài khoản đã đăng nhập
      if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
            'mqttServer': newServer,
            'mqttUser': newUser,
            'mqttPass': newPass,
            'adminPass': newAdminPass,
            'lastWifiSsid': newSsid,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Lỗi cập nhật Firestore khi reconfig: $e');
        }
      }

      // 4. Nếu thông số Broker MQTT thay đổi, tự động Reconnect client của App
      final mqttChanged = oldServer != newServer || oldUser != newUser || oldPass != newPass;
      if (mqttChanged) {
        final mqttRepo = _ref.read(mqttRepositoryProvider);
        mqttRepo.disconnect();
        mqttRepo.connect(
          userId: activeConfig.userId,
          mqttServer: newServer,
          mqttPrefix: activeConfig.mqttPrefix,
          dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
          mqttUser: newUser,
          mqttPass: newPass,
        );
      }

      final details = {
        'Tên Wi-Fi mới': newSsid,
        'MQTT Server': newServer,
        'Mã MAC': activeConfig.macAddress,
        'Phương thức': isEspOnline ? 'Bắn lệnh Cloud OTA (Thành công)' : 'Đã lưu trên Cloud (Hub Offline)',
        'Thời gian': DateTime.now().toLocal().toString().substring(0, 19),
      };

      state = state.copyWith(
        isApplying: false,
        lastAppliedDetails: details,
      );

      return HubReconfigResult(
        success: true,
        isEspOnline: isEspOnline,
        details: details,
      );
    } catch (e) {
      final err = 'Lỗi áp dụng cấu hình: $e';
      state = state.copyWith(isApplying: false, errorMessage: err);
      return HubReconfigResult(
        success: false,
        isEspOnline: false,
        errorMessage: err,
      );
    }
  }
}

final hubReconfigProvider = StateNotifierProvider.autoDispose<HubReconfigController, HubReconfigState>((ref) {
  return HubReconfigController(ref);
});
