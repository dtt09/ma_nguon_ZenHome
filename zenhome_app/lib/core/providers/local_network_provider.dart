import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/services/local_network_service.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';

final localNetworkServiceProvider = Provider<LocalNetworkService>((ref) {
  final service = LocalNetworkService();
  ref.onDispose(() {
    service.stopMonitoring();
  });
  return service;
});

/// Theo dõi trạng thái khả dụng của mạng cục bộ LAN (true: Đang kết nối trực tiếp với ESP32)
final isLocalNetworkAvailableProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(localNetworkServiceProvider);
  return service.localAvailableStream;
});

/// IP hiện tại của Hub ESP32 trong mạng LAN
final localHubIpProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(localNetworkServiceProvider);
  return service.hubIpStream;
});

/// Cầu nối lắng nghe trạng thái thiết bị và nhiệt độ từ mạng cục bộ để đồng bộ vào State toàn cục
final localSyncBridgeProvider = Provider<void>((ref) {
  final service = ref.watch(localNetworkServiceProvider);

  // Lắng nghe cập nhật trạng thái thiết bị cục bộ
  final devSub = service.localDeviceStateStream.listen((states) {
    final current = ref.read(globalDeviceStatesProvider);
    ref.read(globalDeviceStatesProvider.notifier).state = {...current, ...states};
  });

  // Lắng nghe cập nhật nhiệt độ phòng cục bộ
  final tempSub = service.localTempStream.listen((temp) {
    if (temp != null && temp != '--') {
      ref.read(mqttIndoorTempProvider.notifier).state = temp;
    }
  });

  ref.onDispose(() {
    devSub.cancel();
    tempSub.cancel();
  });
});
