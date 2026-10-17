import 'package:wifi_scan/wifi_scan.dart';

/// Trạng thái của luồng Cấu hình lại Hub ESP32 (Wi-Fi & MQTT)
class HubReconfigState {
  final bool isScanningWifi;
  final bool isApplying;
  final List<WiFiAccessPoint> nearbyWifiList;
  final String? errorMessage;
  final Map<String, String>? lastAppliedDetails;

  const HubReconfigState({
    this.isScanningWifi = false,
    this.isApplying = false,
    this.nearbyWifiList = const [],
    this.errorMessage,
    this.lastAppliedDetails,
  });

  HubReconfigState copyWith({
    bool? isScanningWifi,
    bool? isApplying,
    List<WiFiAccessPoint>? nearbyWifiList,
    String? errorMessage,
    Map<String, String>? lastAppliedDetails,
    bool clearError = false,
  }) {
    return HubReconfigState(
      isScanningWifi: isScanningWifi ?? this.isScanningWifi,
      isApplying: isApplying ?? this.isApplying,
      nearbyWifiList: nearbyWifiList ?? this.nearbyWifiList,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastAppliedDetails: lastAppliedDetails ?? this.lastAppliedDetails,
    );
  }
}
