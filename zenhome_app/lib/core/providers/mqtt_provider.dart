import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zenhome_app/core/repositories/mqtt_repository.dart';
import 'package:zenhome_app/core/models/smart_config.dart';

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
