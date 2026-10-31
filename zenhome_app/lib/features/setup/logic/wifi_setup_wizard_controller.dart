import 'dart:async';
import 'dart:convert';
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
import 'package:zenhome_app/core/services/app_update_service.dart';
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
  final int remainingTimeoutSeconds;

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
    this.remainingTimeoutSeconds = 180,
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
    int? remainingTimeoutSeconds,
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
      remainingTimeoutSeconds: remainingTimeoutSeconds ?? this.remainingTimeoutSeconds,
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
    state = state.copyWith(isScanningHomeWifi: true, currentStep: 1);
    try {
      final results = await WifiProvisioningService.scanNearbyWifi(espOnly: false);
      state = state.copyWith(isScanningHomeWifi: false, currentStep: 1);

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
      state = state.copyWith(isScanningHomeWifi: false, currentStep: 1);
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
    String? targetHomeId,
  }) async {
    state = state.copyWith(
      currentStep: 2,
      pairingProgress: 0.15,
      pairingFailed: false,
      pairingErrorMessage: '',
      pairingMessage: 'Đang kiểm tra kết nối với Hub ESP32...',
      remainingTimeoutSeconds: 180,
    );

    try {
      // Đảm bảo cấu hình đang active đúng là ngôi nhà mục tiêu (tránh xung đột giữa các nhà)
      if (targetHomeId != null && targetHomeId.isNotEmpty) {
        final curActive = _ref.read(homeConfigProvider).activeConfig;
        if (curActive.userId != targetHomeId) {
          debugPrint('[SETUP] 🔄 Chuyển active home sang mục tiêu thiết lập: $targetHomeId');
          await _ref.read(homeConfigProvider).switchActiveHome(targetHomeId);
        }
      }

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
      if (userMqtt.isEmpty || userMqtt.startsWith('user_')) {
        userMqtt = (activeConfig.mqttUser != null && activeConfig.mqttUser!.isNotEmpty && !activeConfig.mqttUser!.startsWith('user_'))
            ? activeConfig.mqttUser!
            : defaultUser;
      }

      String passMqtt = mqttPass.trim();
      if (passMqtt.isEmpty) {
        passMqtt = (activeConfig.mqttPass != null && activeConfig.mqttPass!.isNotEmpty)
            ? activeConfig.mqttPass!
            : defaultPass;
      }

      // Đảm bảo đồng bộ tuyệt đối với HiveMQ Cloud
      if (serverInput.contains('hivemq.cloud')) {
        if (userMqtt.isEmpty || userMqtt.startsWith('user_') || passMqtt.isEmpty) {
          userMqtt = 'DTC_ZenHome';
          passMqtt = 'DTC_ZenHome2103';
        }
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

      String? liveServerUrl;
      try {
        liveServerUrl = await AppUpdateService.getLiveServerBaseUrl();
      } catch (_) {}

      bool isSuccess = await EspApiService.sendConfigToESP(
        wifiSsid: wifiSsid.trim(),
        wifiPass: wifiPass.trim(),
        adminPass: activeConfig.adminPass,
        config: activeConfig,
        serverUrl: liveServerUrl,
      );

      if (!isSuccess) {
        activeConfig.macAddress = '';
        state = state.copyWith(
          pairingFailed: true,
          pairingErrorMessage: 'ESP32 từ chối gói cấu hình. Vui lòng kiểm tra lại mật khẩu quản trị.',
        );
        return;
      }

      // Ngắt kết nối SoftAP ngay lập tức để điện thoại chuyển lại về Wi-Fi nhà hoặc 4G/5G Internet
      await WifiProvisioningService.releaseWifiUsage();
      try {
        await WiFiForIoTPlugin.disconnect();
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 1500));

      // 3. Đợi thiết bị reboot và lên mạng MQTT (Thời gian chờ tối đa 3 phút)
      state = state.copyWith(
        pairingProgress: 0.65,
        pairingMessage: 'Đang đợi Hub kết nối Wi-Fi & MQTT Cloud lần đầu...',
        remainingTimeoutSeconds: 180,
      );

      final mqttRepo = _ref.read(mqttRepositoryProvider);
      mqttRepo.disconnect();

      bool isEspOnline = false;
      bool isHandshakeReceived = false;
      bool isSetupCompleted = false;

      final targetMqttPrefix = '${activeConfig.userId}/$espMac';

      final setupSub = mqttRepo.setupMessageStream.listen((msg) {
        final topic = msg['topic'];
        final payload = msg['payload'] ?? '';
        final fullTopic = msg['fullTopic'] ?? '';
        debugPrint('[SETUP-APP] 📩 Nhận setup message từ Hub: $topic (Full: $fullTopic) -> $payload');
        if (topic == 'handshake') {
          isHandshakeReceived = true;
          state = state.copyWith(
            pairingProgress: 0.90,
            pairingMessage: 'Đã bắt được tín hiệu từ Hub! Đang gửi phản hồi xác nhận kích hoạt...',
          );
          // Gửi phản hồi xác nhận bắt tay để ESP32 hoàn tất thiết lập
          try {
            final confirmPayload = jsonEncode({
              'confirm': true,
              'mac': espMac,
              'userId': activeConfig.userId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
            mqttRepo.publishCmd('$targetMqttPrefix/setup/confirm', confirmPayload);
            if (fullTopic.endsWith('/setup/handshake')) {
              final detectedPrefix = fullTopic.replaceAll('/setup/handshake', '');
              if (detectedPrefix != targetMqttPrefix) {
                mqttRepo.publishCmd('$detectedPrefix/setup/confirm', confirmPayload);
                debugPrint('[SETUP-APP] 📤 Đã gửi thêm confirm tới detectedPrefix: $detectedPrefix/setup/confirm');
              }
            }
            debugPrint('[SETUP-APP] 📤 Đã gửi confirm tới Hub trên: $targetMqttPrefix/setup/confirm');
          } catch (e) {
            debugPrint('[SETUP-APP] ⚠️ Lỗi gửi confirm: $e');
          }
        } else if (topic == 'complete') {
          isSetupCompleted = true;
          isEspOnline = true;
          state = state.copyWith(
            pairingProgress: 0.98,
            pairingMessage: 'Thiết lập hoàn tất! Hub đã mở khóa toàn bộ tính năng.',
          );
        }
      });

      final onlineSub = mqttRepo.espOnlineStream.listen((online) {
        if (online) {
          isEspOnline = true;
          if (isHandshakeReceived) {
            isSetupCompleted = true;
          }
        }
      });

      // Kết nối MQTT ngay với targetMqttPrefix đã có MAC chính xác
      try {
        mqttRepo.connect(
          userId: activeConfig.userId,
          mqttServer: serverInput,
          mqttPrefix: targetMqttPrefix,
          dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
          mqttUser: userMqtt,
          mqttPass: passMqtt,
        );
      } catch (e) {
        debugPrint('[SETUP-APP] Lỗi kết nối MQTT ban đầu: $e');
      }

      int waitLoops = 0;
      int lastConnectAttempt = 0;
      const int maxTimeoutSeconds = 180; // Giới hạn 3 phút ghép nối

      while (!isSetupCompleted && waitLoops < maxTimeoutSeconds) {
        final remaining = maxTimeoutSeconds - waitLoops;
        state = state.copyWith(remainingTimeoutSeconds: remaining);

        // Nếu đã online nhưng chưa handshake hoặc chưa hoàn tất, gửi xác nhận
        if (isEspOnline && !isSetupCompleted && isHandshakeReceived) {
          isSetupCompleted = true;
          break;
        }

        if (waitLoops - lastConnectAttempt >= 6) {
          final mqttState = mqttRepo.client?.connectionStatus?.state;
          if (mqttState != MqttConnectionState.connected && mqttState != MqttConnectionState.connecting) {
            lastConnectAttempt = waitLoops;
            mqttRepo.disconnect();
            mqttRepo.connect(
              userId: activeConfig.userId,
              mqttServer: serverInput,
              mqttPrefix: targetMqttPrefix,
              dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
              mqttUser: userMqtt,
              mqttPass: passMqtt,
            );
          }
        }

        // Nếu điện thoại đã kết nối MQTT và đã nhận handshake nhưng chưa nhận complete, định kỳ nhắc lại confirm
        if (isHandshakeReceived && !isSetupCompleted && waitLoops % 2 == 0) {
          try {
            final confirmPayload = jsonEncode({
              'confirm': true,
              'mac': espMac,
              'userId': activeConfig.userId,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
            mqttRepo.publishCmd('$targetMqttPrefix/setup/confirm', confirmPayload);
          } catch (_) {}
        }

        await Future.delayed(const Duration(seconds: 1));
        waitLoops++;

        if (waitLoops % 4 == 0 && !isHandshakeReceived) {
          state = state.copyWith(
            pairingProgress: min(0.85, 0.65 + (waitLoops / maxTimeoutSeconds.toDouble()) * 0.20),
            pairingMessage: 'Đang đợi Hub bắt tín hiệu lần đầu (${waitLoops}s / 3 phút)...',
          );
        }
      }

      setupSub.cancel();
      onlineSub.cancel();

      if (!isSetupCompleted && !isEspOnline) {
        activeConfig.macAddress = '';
        await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
        state = state.copyWith(
          pairingFailed: true,
          pairingErrorMessage: 'Hết thời gian chờ kết nối (3 phút)! Vui lòng kiểm tra lại thông tin Wi-Fi nhà và khoảng cách đến Hub.',
        );
        return;
      }

      // 4. Lưu MAC và kích hoạt liên kết độc quyền (Exclusive MAC Binding)
      activeConfig.macAddress = espMac;
      await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
      await _ref.read(homeConfigProvider).claimExclusiveMacAddress(activeConfig.userId, espMac);

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
        pairingMessage: 'Thiết lập hoàn tất! Hub đã mở khóa toàn bộ tính năng. Đang chuyển sang thêm thiết bị...',
        currentStep: 3,
        remainingTimeoutSeconds: 0,
      );
    } catch (e) {
      state = state.copyWith(
        pairingFailed: true,
        pairingErrorMessage: 'Đã xảy ra lỗi: $e',
      );
    }
  }

  /// Hủy bỏ quy trình thiết lập, đảm bảo không lưu MAC ảo vào cấu hình Local
  Future<void> cancelSetupWorkflow() async {
    try {
      final activeConfig = _ref.read(homeConfigProvider).activeConfig;
      if (activeConfig.macAddress.isNotEmpty) {
        // Chỉ reset nếu chưa hoàn thành thiết lập hợp lệ
        if (state.currentStep != 3) {
          activeConfig.macAddress = '';
          await _ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
          debugPrint("[SETUP] 🛑 Đã hủy quy trình ghép nối và reset MAC về rỗng (tránh liên kết ảo).");
        }
      }
      final mqttRepo = _ref.read(mqttRepositoryProvider);
      mqttRepo.disconnect();
    } catch (e) {
      debugPrint("[SETUP] Lỗi khi hủy quy trình ghép nối: $e");
    }
  }
}

final wifiSetupWizardProvider = StateNotifierProvider.autoDispose<WifiSetupWizardController, WifiSetupWizardState>((ref) {
  return WifiSetupWizardController(ref);
});
