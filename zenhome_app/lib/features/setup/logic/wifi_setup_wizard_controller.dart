import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:mqtt_client/mqtt_client.dart';

import 'package:zenhome_app/features/setup/logic/wifi_provisioning_service.dart';
import 'package:zenhome_app/features/setup/logic/esp_api_service.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart' hide MqttConnectionState;
import 'package:zenhome_app/core/utils/helpers.dart';

class WifiSetupWizardState {
  final int currentStep; // 0: Chuẩn bị, 1: Nhập WiFi, 2: Đang ghép nối, 3: Hoàn tất
  final String? currentConnectedSsid;
  final bool isCheckingCurrentWifi;
  final String? detectedEspMac;
  final bool isScanningEsp;
  final bool hasScannedEsp;
  final List<WiFiAccessPoint> scannedEspDevices;
  final bool isConnectingInApp;
  final String? connectingSsid;
  final bool isScanningHomeWifi;
  final double pairingProgress;
  final String pairingMessage;
  final bool pairingFailed;
  final String pairingErrorMessage;

  const WifiSetupWizardState({
    this.currentStep = 0,
    this.currentConnectedSsid,
    this.isCheckingCurrentWifi = false,
    this.detectedEspMac,
    this.isScanningEsp = false,
    this.hasScannedEsp = false,
    this.scannedEspDevices = const [],
    this.isConnectingInApp = false,
    this.connectingSsid,
    this.isScanningHomeWifi = false,
    this.pairingProgress = 0.0,
    this.pairingMessage = '',
    this.pairingFailed = false,
    this.pairingErrorMessage = '',
  });

  WifiSetupWizardState copyWith({
    int? currentStep,
    String? currentConnectedSsid,
    bool? isCheckingCurrentWifi,
    String? detectedEspMac,
    bool? isScanningEsp,
    bool? hasScannedEsp,
    List<WiFiAccessPoint>? scannedEspDevices,
    bool? isConnectingInApp,
    String? connectingSsid,
    bool? isScanningHomeWifi,
    double? pairingProgress,
    String? pairingMessage,
    bool? pairingFailed,
    String? pairingErrorMessage,
  }) {
    return WifiSetupWizardState(
      currentStep: currentStep ?? this.currentStep,
      currentConnectedSsid: currentConnectedSsid ?? this.currentConnectedSsid,
      isCheckingCurrentWifi: isCheckingCurrentWifi ?? this.isCheckingCurrentWifi,
      detectedEspMac: detectedEspMac ?? this.detectedEspMac,
      isScanningEsp: isScanningEsp ?? this.isScanningEsp,
      hasScannedEsp: hasScannedEsp ?? this.hasScannedEsp,
      scannedEspDevices: scannedEspDevices ?? this.scannedEspDevices,
      isConnectingInApp: isConnectingInApp ?? this.isConnectingInApp,
      connectingSsid: connectingSsid ?? this.connectingSsid,
      isScanningHomeWifi: isScanningHomeWifi ?? this.isScanningHomeWifi,
      pairingProgress: pairingProgress ?? this.pairingProgress,
      pairingMessage: pairingMessage ?? this.pairingMessage,
      pairingFailed: pairingFailed ?? this.pairingFailed,
      pairingErrorMessage: pairingErrorMessage ?? this.pairingErrorMessage,
    );
  }
}

/// Controller điều phối quy trình cài đặt và cấp phát mạng Wi-Fi cho ESP32
class WifiSetupWizardController extends StateNotifier<WifiSetupWizardState> {
  final Ref _ref;

  WifiSetupWizardController(this._ref) : super(const WifiSetupWizardState());

  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  /// Kiểm tra SSID Wi-Fi đang kết nối trên điện thoại
  Future<void> checkCurrentWifiStatus() async {
    if (state.isCheckingCurrentWifi) return;
    state = state.copyWith(isCheckingCurrentWifi: true);
    try {
      final ssid = await WifiProvisioningService.getCurrentSsid();
      if (ssid != state.currentConnectedSsid) {
        state = state.copyWith(currentConnectedSsid: ssid);
        if (ssid != null && (ssid.startsWith('ZenHome_Setup_') || ssid.startsWith('ESP32_'))) {
          await autoPingEsp(ssid);
        }
      }
    } catch (_) {
    } finally {
      state = state.copyWith(isCheckingCurrentWifi: false);
    }
  }

  /// Bắt tay tự động nếu điện thoại đang kết nối vào mạng ESP32
  Future<void> autoPingEsp(String ssid) async {
    try {
      final mac = await WifiProvisioningService.pingEspQuick();
      if (mac != null && mac.isNotEmpty && state.detectedEspMac == null) {
        state = state.copyWith(detectedEspMac: mac);
      }
    } catch (_) {}
  }

  /// Quét sóng các điểm phát Wi-Fi của ESP32 gần đó
  Future<ScanCapability> scanForEspDevices() async {
    state = state.copyWith(isScanningEsp: true, hasScannedEsp: true);
    try {
      final cap = await WifiProvisioningService.checkScanCapability();
      if (cap != ScanCapability.ready) {
        state = state.copyWith(isScanningEsp: false);
        return cap;
      }

      final results = await WifiProvisioningService.scanNearbyWifi(espOnly: true);
      state = state.copyWith(
        scannedEspDevices: results,
        isScanningEsp: false,
      );
      return ScanCapability.ready;
    } catch (e) {
      state = state.copyWith(isScanningEsp: false);
      rethrow;
    }
  }

  void setConnectingInApp(bool isConnecting, String? ssid) {
    state = state.copyWith(isConnectingInApp: isConnecting, connectingSsid: ssid);
  }

  void onEspConnectedSuccess(String ssid, String? mac) {
    state = state.copyWith(
      detectedEspMac: mac ?? ssid.replaceFirst('ZenHome_Setup_', 'ESP_'),
      isConnectingInApp: false,
      connectingSsid: null,
      currentConnectedSsid: ssid,
    );
  }

  /// Quét danh sách Wi-Fi gia đình xung quanh
  Future<List<WiFiAccessPoint>> scanNearbyHomeWifi() async {
    state = state.copyWith(isScanningHomeWifi: true);
    try {
      final results = await WifiProvisioningService.scanNearbyWifi(espOnly: false);
      state = state.copyWith(isScanningHomeWifi: false);

      final homeAps = results.where((ap) {
        final s = ap.ssid.toLowerCase();
        return !s.startsWith('zenhome') && !s.contains('setup');
      }).toList();

      final uniqueMap = <String, WiFiAccessPoint>{};
      for (final ap in homeAps) {
        if (!uniqueMap.containsKey(ap.ssid)) {
          uniqueMap[ap.ssid] = ap;
        }
      }
      return uniqueMap.values.toList();
    } catch (e) {
      state = state.copyWith(isScanningHomeWifi: false);
      rethrow;
    }
  }

  /// Khởi chạy chuỗi hành động cấu hình và ghép nối ESP32
  Future<void> executePairingWorkflow({
    required String wifiSsid,
    required String wifiPass,
    required String adminPass,
    required String mqttServer,
    required String mqttUser,
    required String mqttPass,
    required String defaultServer,
    required String defaultUser,
    required String defaultPass,
  }) async {
    state = state.copyWith(
      currentStep: 2,
      pairingProgress: 0.15,
      pairingFailed: false,
      pairingErrorMessage: '',
      pairingMessage: 'Đang kiểm tra kết nối với Hub ESP32...',
    );

    try {
      // 1. Ping ESP32
      state = state.copyWith(
        pairingProgress: 0.25,
        pairingMessage: 'Đang bắt tay với Hub ESP32...',
      );

      String? espMac = await EspApiService.pingESP();
      if (espMac == null) {
        state = state.copyWith(
          pairingFailed: true,
          pairingErrorMessage: 'Không tìm thấy thiết bị ESP32 (192.168.4.1). Hãy kết nối đúng Wi-Fi Hub.',
        );
        return;
      }

      if (espMac == "unknown_mac_fallback" || espMac.isEmpty) {
        espMac = 'ESP_${DateTime.now().millisecondsSinceEpoch}';
      }
      state = state.copyWith(detectedEspMac: espMac);

      final activeConfig = _ref.read(homeConfigProvider).activeConfig;

      String serverInput = mqttServer.trim();
      if (serverInput.isEmpty) {
        serverInput = defaultServer;
      } else if (!serverInput.contains('.')) {
        serverInput = '$serverInput.s1.eu.hivemq.cloud';
      }

      String userMqtt = mqttUser.trim();
      if (userMqtt.isEmpty) {
        userMqtt = (activeConfig.mqttUser != null && activeConfig.mqttUser!.isNotEmpty)
            ? activeConfig.mqttUser!
            : defaultUser;
      }

      String passMqtt = mqttPass.trim();
      if (passMqtt.isEmpty) {
        passMqtt = (activeConfig.mqttPass != null && activeConfig.mqttPass!.isNotEmpty)
            ? activeConfig.mqttPass!
            : defaultPass;
      }

      activeConfig.macAddress = espMac;
      activeConfig.mqttServer = serverInput;
      activeConfig.mqttUser = userMqtt;
      activeConfig.mqttPass = passMqtt;
      activeConfig.adminPass = adminPass;

      // 2. Gửi config sang ESP32 qua HTTP SoftAP
      state = state.copyWith(
        pairingProgress: 0.50,
        pairingMessage: 'Đang gửi thông tin Wi-Fi và MQTT đến Hub...',
      );

      bool isSuccess = await EspApiService.sendConfigToESP(
        wifiSsid: wifiSsid.trim(),
        wifiPass: wifiPass.trim(),
        adminPass: activeConfig.adminPass,
        config: activeConfig,
      );

      if (!isSuccess) {
        activeConfig.macAddress = 'unknown_mac';
        state = state.copyWith(
          pairingFailed: true,
          pairingErrorMessage: 'ESP32 từ chối gói cấu hình. Vui lòng kiểm tra lại mật khẩu quản trị.',
        );
        return;
      }

      // Ngắt kết nối SoftAP để điện thoại bắt lại Internet
      await WifiProvisioningService.releaseWifiUsage();
      try {
        await WiFiForIoTPlugin.disconnect();
      } catch (_) {}

      // 3. Đợi thiết bị reboot và lên mạng MQTT
      state = state.copyWith(
        pairingProgress: 0.75,
        pairingMessage: 'Đang đợi Hub khởi động và kết nối MQTT Broker...',
      );

      final mqttRepo = _ref.read(mqttRepositoryProvider);
      mqttRepo.disconnect();

      bool isEspOnline = false;
      final sub = mqttRepo.espOnlineStream.listen((online) {
        if (online) isEspOnline = true;
      });

      await Future.delayed(const Duration(seconds: 3));

      int waitLoops = 0;
      int lastConnectAttempt = -10;

      while (!isEspOnline && waitLoops < 90) {
        if (mqttRepo.isEspOnline) {
          isEspOnline = true;
          break;
        }
        if (waitLoops - lastConnectAttempt >= 6) {
          final mqttState = mqttRepo.client?.connectionStatus?.state;
          if (mqttState != MqttConnectionState.connected && mqttState != MqttConnectionState.connecting) {
            lastConnectAttempt = waitLoops;
            mqttRepo.disconnect();
            mqttRepo.connect(
              userId: activeConfig.userId,
              mqttServer: activeConfig.mqttServer,
              mqttPrefix: activeConfig.mqttPrefix,
              dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
              mqttUser: activeConfig.mqttUser,
              mqttPass: activeConfig.mqttPass,
            );
          }
        }
        await Future.delayed(const Duration(seconds: 1));
        waitLoops++;
        if (waitLoops % 10 == 0) {
          state = state.copyWith(
            pairingProgress: min(0.95, 0.75 + (waitLoops / 90.0) * 0.20),
          );
        }
      }

      sub.cancel();

      if (!isEspOnline) {
        activeConfig.macAddress = 'unknown_mac';
        await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
        state = state.copyWith(
          pairingFailed: true,
          pairingErrorMessage: 'Quá thời gian chờ Hub online trên MQTT. Hãy kiểm tra lại mật khẩu Wi-Fi nhà.',
        );
        return;
      }

      // 4. Lưu MAC và đồng bộ
      activeConfig.macAddress = espMac;
      await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

      // 5. Đồng bộ Firebase
      try {
        if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
            'mqttServer': activeConfig.mqttServer,
            'mqttUser': activeConfig.mqttUser,
            'mqttPass': activeConfig.mqttPass,
            'macAddress': activeConfig.macAddress,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint("Lỗi đồng bộ Firebase sau khi setup: $e");
      }

      // 6. Hoàn tất -> Bước 3
      state = state.copyWith(
        pairingProgress: 1.0,
        currentStep: 3,
      );
    } catch (e) {
      state = state.copyWith(
        pairingFailed: true,
        pairingErrorMessage: 'Đã xảy ra lỗi: $e',
      );
    }
  }
}

final wifiSetupWizardProvider = StateNotifierProvider.autoDispose<WifiSetupWizardController, WifiSetupWizardState>((ref) {
  return WifiSetupWizardController(ref);
});
