import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:zenhome_app/features/setup/logic/esp_api_service.dart';

enum ScanCapability {
  ready,
  wifiDisabled,
  locationDisabled,
  permissionDenied,
  unsupported,
  failed,
}

enum EspConnectStep {
  requestingWifi,
  routingInterface,
  handshaking,
  success,
  failed,
}

typedef EspProgressCallback = void Function(
  EspConnectStep step, {
  int? attempt,
  int? maxAttempts,
  String? mac,
  String? error,
});

class WifiProvisioningService {
  /// Lấy SSID của mạng Wi-Fi điện thoại đang kết nối hiện tại
  static Future<String?> getCurrentSsid() async {
    try {
      final ssid = await WiFiForIoTPlugin.getSSID();
      if (ssid != null) {
        final clean = ssid.replaceAll('"', '').trim();
        if (clean.isNotEmpty && clean != '<unknown ssid>' && clean != '0x') {
          return clean;
        }
      }
    } catch (e) {
      debugPrint('[WIFI_SSID] Lỗi lấy SSID hiện tại: $e');
    }
    return null;
  }

  /// Kiểm tra xem Wi-Fi trên máy có đang bật hay không
  static Future<bool> isWifiEnabled() async {
    try {
      return await WiFiForIoTPlugin.isEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Bật Wi-Fi hoặc mở cài đặt nếu không có quyền can thiệp trực tiếp
  static Future<void> enableWifi() async {
    try {
      await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
    } catch (e) {
      debugPrint('[WIFI] Lỗi bật Wi-Fi: $e');
    }
  }

  /// Kiểm tra toàn diện khả năng quét sóng (Wi-Fi bật, GPS bật, Quyền vị trí)
  static Future<ScanCapability> checkScanCapability() async {
    try {
      final isEnabled = await isWifiEnabled();
      if (!isEnabled) {
        return ScanCapability.wifiDisabled;
      }

      final can = await WiFiScan.instance.canStartScan(askPermissions: true);
      switch (can) {
        case CanStartScan.yes:
          return ScanCapability.ready;
        case CanStartScan.noLocationServiceDisabled:
          return ScanCapability.locationDisabled;
        case CanStartScan.noLocationPermissionDenied:
        case CanStartScan.noLocationPermissionRequired:
        case CanStartScan.noLocationPermissionUpgradeAccuracy:
          return ScanCapability.permissionDenied;
        case CanStartScan.notSupported:
          return ScanCapability.unsupported;
        case CanStartScan.failed:
          return ScanCapability.failed;
      }
    } catch (e) {
      debugPrint('[WIFI_SCAN] Lỗi kiểm tra điều kiện quét: $e');
      return ScanCapability.failed;
    }
  }

  /// Quét danh sách Wi-Fi xung quanh
  /// [espOnly] = true: Lọc ra các mạng Access Point của ESP32 (ZenHome_Setup, ESP32, etc.)
  static Future<List<WiFiAccessPoint>> scanNearbyWifi({bool espOnly = true}) async {
    try {
      final canStart = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canStart == CanStartScan.yes) {
        await WiFiScan.instance.startScan();
        // Chờ thiết bị nhận sóng Wi-Fi từ các AP xung quanh
        await Future.delayed(const Duration(milliseconds: 1800));
      }

      final canGet = await WiFiScan.instance.canGetScannedResults(askPermissions: true);
      if (canGet == CanGetScannedResults.yes) {
        final list = await WiFiScan.instance.getScannedResults();
        
        List<WiFiAccessPoint> filtered = list.where((ap) => ap.ssid.trim().isNotEmpty).toList();

        if (espOnly) {
          filtered = filtered.where((ap) {
            final lower = ap.ssid.toLowerCase();
            return lower.startsWith('zenhome') ||
                   lower.contains('setup') ||
                   lower.startsWith('esp32') ||
                   lower.startsWith('esp_');
          }).toList();
        }

        // Sắp xếp theo cường độ tín hiệu (level dBm lớn hơn đứng trước)
        filtered.sort((a, b) => b.level.compareTo(a.level));
        return filtered;
      }
    } catch (e) {
      debugPrint('[WIFI_SCAN] Ngoại lệ khi quét Wi-Fi: $e');
    }
    return [];
  }

  /// Kết nối trực tiếp vào mạng Wi-Fi AP của ESP32 với tiến trình phản hồi rõ ràng
  static Future<bool> connectToEspWithProgress({
    required String ssid,
    String? bssid,
    String password = '',
    required EspProgressCallback onProgress,
  }) async {
    try {
      // BƯỚC 1: Bắt sóng và gửi yêu cầu kết nối
      onProgress(EspConnectStep.requestingWifi);
      debugPrint('[WIFI_CONNECT] Bắt đầu kết nối vào $ssid...');

      final connectRequested = await WiFiForIoTPlugin.connect(
        ssid,
        bssid: bssid,
        password: password.isEmpty ? null : password,
        security: password.isEmpty ? NetworkSecurity.NONE : NetworkSecurity.WPA,
        joinOnce: false,
        withInternet: false, // AP của ESP32 là mạng cục bộ IoT không Internet
        timeoutInSeconds: 20,
      );

      debugPrint('[WIFI_CONNECT] Yêu cầu kết nối hệ thống trả về: $connectRequested');

      // BƯỚC 2: Cấu hình định tuyến cổng Wi-Fi
      onProgress(EspConnectStep.routingInterface);
      await WiFiForIoTPlugin.forceWifiUsage(true);

      // BƯỚC 3: Bắt tay (Handshake) với ESP32 tại 192.168.4.1/ping
      const maxRetries = 6;
      for (int i = 1; i <= maxRetries; i++) {
        onProgress(EspConnectStep.handshaking, attempt: i, maxAttempts: maxRetries);
        await Future.delayed(const Duration(milliseconds: 1400));
        
        final mac = await EspApiService.pingESP();
        if (mac != null && mac.isNotEmpty) {
          debugPrint('[WIFI_CONNECT] ✅ Bắt tay thành công với ESP32 tại 192.168.4.1! MAC: $mac');
          onProgress(EspConnectStep.success, mac: mac);
          return true;
        }
      }

      // Thất bại sau các lần thử
      onProgress(EspConnectStep.failed, error: 'ESP32 không phản hồi tại 192.168.4.1');
      return false;
    } catch (e) {
      debugPrint('[WIFI_CONNECT] Lỗi ngoại lệ khi kết nối ESP32: $e');
      onProgress(EspConnectStep.failed, error: e.toString());
      return false;
    }
  }

  /// Ping kiểm tra phản hồi từ ESP32 tại 192.168.4.1/ping
  static Future<String?> pingEspQuick() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(true);
      return await EspApiService.pingESP();
    } catch (_) {
      return null;
    }
  }

  /// Giải phóng ép buộc Wi-Fi khi hoàn tất thiết lập
  static Future<void> releaseWifiUsage() async {
    try {
      await WiFiForIoTPlugin.forceWifiUsage(false);
    } catch (_) {}
  }

  /// Mở màn hình cài đặt Wi-Fi hệ thống (dự phòng)
  static Future<void> openSystemWifiSettings() async {
    try {
      await WiFiForIoTPlugin.setEnabled(true, shouldOpenSettings: true);
    } catch (e) {
      debugPrint('[WIFI_CONNECT] Lỗi mở cài đặt Wi-Fi: $e');
    }
  }

  /// Lấy đánh giá chất lượng tín hiệu (Mạnh, Tốt, Yếu)
  static String getSignalQuality(int level) {
    if (level >= -60) return 'Mạnh';
    if (level >= -75) return 'Tốt';
    return 'Yếu';
  }
}
