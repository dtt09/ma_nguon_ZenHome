import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenhome_app/core/repositories/mqtt_repository.dart';

part 'mqtt_provider.g.dart';

@Riverpod(keepAlive: true)
MqttRepository mqttRepository(MqttRepositoryRef ref) {
  final repo = MqttRepository();
  ref.onDispose(() {
    repo.dispose();
  });
  return repo;
}

@Riverpod(keepAlive: true)
class MqttConnectionState extends _$MqttConnectionState {
  @override
  int build() {
    final repo = ref.watch(mqttRepositoryProvider);
    final sub = repo.connectionStateStream.listen((state) {
      this.state = state;
    });
    ref.onDispose(sub.cancel);
    return 0; // 0: disconnected, 1: connecting, 2: connected, -1: error, -2: hard disconnect
  }
}

@Riverpod(keepAlive: true)
class EspOnlineState extends _$EspOnlineState {
  @override
  bool build() {
    final repo = ref.watch(mqttRepositoryProvider);
    final sub = repo.espOnlineStream.listen((isOnline) {
      state = isOnline;
    });
    ref.onDispose(sub.cancel);
    return false;
  }
}

@Riverpod(keepAlive: true)
class GlobalDeviceStates extends _$GlobalDeviceStates {
  @override
  Map<String, bool> build() {
    final repo = ref.watch(mqttRepositoryProvider);
    final sub = repo.deviceStateStream.listen((update) {
      state = {...state, ...update};
    });
    ref.onDispose(sub.cancel);
    return {};
  }

  void updateState(String deviceId, bool isOn) {
    state = {...state, deviceId: isOn};
  }

  void clearStates() {
    state = {};
  }
}

@riverpod
class MqttIndoorTemp extends _$MqttIndoorTemp {
  @override
  String build() {
    final repo = ref.watch(mqttRepositoryProvider);
    final sub = repo.indoorTempStream.listen((temp) {
      state = temp;
    });
    ref.onDispose(sub.cancel);
    return '--';
  }
}

@Riverpod(keepAlive: true)
class MqttNotification extends _$MqttNotification {
  @override
  String build() {
    final repo = ref.watch(mqttRepositoryProvider);
    final sub = repo.notificationStream.listen((notification) {
      state = notification;
    });
    ref.onDispose(sub.cancel);
    return '';
  }
}

/// Provider quản lý tập hợp các thiết bị đang trong trạng thái xử lý lệnh (Pending)
/// Tự động lắng nghe và giải phóng thiết bị ngay khi nhận được phản hồi trạng thái từ ESP32,
/// hoặc tự hủy sau 3.5s an toàn chống đơ/treo công tắc vĩnh viễn ngay cả khi người dùng chuyển tab.
class PendingDeviceOperations extends Notifier<Set<String>> {
  final Map<String, Timer> _safetyTimers = {};

  @override
  Set<String> build() {
    final repo = ref.watch(mqttRepositoryProvider);

    // Bất cứ khi nào phần cứng ESP32 phát trạng thái xác nhận, tự động xóa cờ pending
    final sub = repo.deviceStateStream.listen((update) {
      if (state.isNotEmpty) {
        bool hasChanges = false;
        final next = Set<String>.from(state);
        for (var devId in update.keys) {
          if (next.remove(devId)) {
            hasChanges = true;
            _safetyTimers[devId]?.cancel();
            _safetyTimers.remove(devId);
          }
        }
        if (hasChanges) {
          state = next;
        }
      }
    });

    ref.onDispose(() {
      sub.cancel();
      for (var t in _safetyTimers.values) {
        t.cancel();
      }
      _safetyTimers.clear();
    });

    return {};
  }

  void setPending(String devId, bool isPending, {VoidCallback? onTimeout}) {
    _safetyTimers[devId]?.cancel();
    _safetyTimers.remove(devId);

    if (isPending) {
      state = {...state, devId};

      // Đặt hẹn giờ an toàn: Quá 3.5s không nhận được phản hồi -> Tự động giải phóng chống treo vĩnh viễn
      _safetyTimers[devId] = Timer(const Duration(milliseconds: 3500), () {
        _safetyTimers.remove(devId);
        if (state.contains(devId)) {
          final next = Set<String>.from(state);
          next.remove(devId);
          state = next;
          onTimeout?.call();
        }
      });
    } else {
      if (state.contains(devId)) {
        final next = Set<String>.from(state);
        next.remove(devId);
        state = next;
      }
    }
  }

  void clearAll() {
    for (var t in _safetyTimers.values) {
      t.cancel();
    }
    _safetyTimers.clear();
    state = {};
  }
}

final pendingDeviceOperationsProvider =
    NotifierProvider<PendingDeviceOperations, Set<String>>(PendingDeviceOperations.new);

