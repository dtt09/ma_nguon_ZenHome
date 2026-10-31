import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:wifi_scan/wifi_scan.dart';
import 'package:zenhome_app/features/setup/logic/wifi_provisioning_service.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/setup/logic/wifi_setup_wizard_controller.dart';
import 'package:zenhome_app/core/utils/masking_helper.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';

class WifiSetupScreen extends ConsumerStatefulWidget {
  final SmartConfig? targetHome;
  const WifiSetupScreen({super.key, this.targetHome});

  @override
  ConsumerState<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends ConsumerState<WifiSetupScreen> {
  int _currentStep = 0; // 0: Chuẩn bị, 1: Nhập WiFi, 2: Đang ghép nối, 3: Hoàn tất

  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _adminPassController = TextEditingController();
  final TextEditingController _confirmAdminPassController = TextEditingController();

  final TextEditingController _mqttServerController = TextEditingController();
  final TextEditingController _mqttUserController = TextEditingController();
  final TextEditingController _mqttPassController = TextEditingController();

  bool _obscureWifiPass = true;
  bool _obscureAdminPass = true;
  bool _obscureConfirmPass = true;
  bool _showAdvancedMqtt = false;

  bool _isCheckingEsp = false;
  String? _detectedEspMac;

  // Trạng thái quét sóng ESP32 và kết nối trực tiếp trong ứng dụng
  bool _isScanningEsp = false;
  bool _hasScannedEsp = false;
  List<WiFiAccessPoint> _scannedEspDevices = [];

  bool _isConnectingInApp = false;
  String? _connectingSsid;

  bool _isScanningHomeWifi = false;

  // Giám sát trạng thái mạng Wi-Fi hiện tại của máy
  Timer? _wifiMonitorTimer;
  String? _currentConnectedSsid;
  bool _isCheckingCurrentWifi = false;

  // Trạng thái cho Step 2 (Đang ghép nối)
  double _pairingProgress = 0.0;
  String _pairingMessage = '';
  bool _pairingFailed = false;
  String _pairingErrorMessage = '';

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    // Đảm bảo đồng bộ với ngôi nhà mục tiêu được truyền vào nếu có
    if (widget.targetHome != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(homeConfigProvider).switchActiveHome(widget.targetHome!.userId);
      });
    }
    final activeConfig = widget.targetHome ?? ref.read(homeConfigProvider).activeConfig;
    final defaultServer = dotenv.env['DEFAULT_MQTT_SERVER'] ?? 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud';
    final defaultUser = dotenv.env['DEFAULT_MQTT_USER'] ?? 'DTC_ZenHome';
    final defaultPass = dotenv.env['DEFAULT_MQTT_PASS'] ?? 'DTC_ZenHome2103';

    _mqttServerController.text = (activeConfig.mqttServer.isNotEmpty && activeConfig.mqttServer != 'broker.emqx.io')
        ? activeConfig.mqttServer
        : defaultServer;
    _mqttUserController.text = (activeConfig.mqttUser != null && activeConfig.mqttUser!.isNotEmpty && !activeConfig.mqttUser!.startsWith('user_'))
        ? activeConfig.mqttUser!
        : defaultUser;
    _mqttPassController.text = (activeConfig.mqttPass != null && activeConfig.mqttPass!.isNotEmpty)
        ? activeConfig.mqttPass!
        : defaultPass;

    _startWifiMonitoring();
  }

  void _startWifiMonitoring() {
    _checkCurrentWifiStatus();
    _wifiMonitorTimer?.cancel();
    _wifiMonitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentStep == 0 && !_isConnectingInApp) {
        _checkCurrentWifiStatus();
      }
    });
  }

  Future<void> _checkCurrentWifiStatus() async {
    if (_isCheckingCurrentWifi) return;
    _isCheckingCurrentWifi = true;
    try {
      final ssid = await WifiProvisioningService.getCurrentSsid();
      if (!mounted) return;
      if (ssid != _currentConnectedSsid) {
        setState(() {
          _currentConnectedSsid = ssid;
        });

        // Nếu điện thoại đang kết nối vào mạng ESP32, tự động bắt tay thử
        if (ssid != null && (ssid.startsWith('ZenHome_Setup_') || ssid.startsWith('ESP32_'))) {
          _autoPingEsp(ssid);
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isCheckingCurrentWifi = false);
      }
    }
  }

  Future<void> _autoPingEsp(String ssid) async {
    try {
      final mac = await WifiProvisioningService.pingEspQuick();
      if (!mounted) return;
      if (mac != null && mac.isNotEmpty && _detectedEspMac == null) {
        setState(() {
          _detectedEspMac = mac;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // Nếu màn hình bị đóng khi chưa hoàn tất toàn bộ bước ghép nối, reset MAC để tránh liên kết ảo
    if (_currentStep != 3) {
      final activeConfig = ref.read(homeConfigProvider).activeConfig;
      if (activeConfig.macAddress.isNotEmpty) {
        activeConfig.macAddress = '';
        ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
        debugPrint("[SETUP-DISPOSE] 🛑 Đã dọn dẹp và reset MAC về rỗng do người dùng thoát trước khi hoàn tất.");
      }
    }
    _wifiMonitorTimer?.cancel();
    WifiProvisioningService.releaseWifiUsage();
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    _ssidController.dispose();
    _passController.dispose();
    _adminPassController.dispose();
    _confirmAdminPassController.dispose();
    _mqttServerController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    super.dispose();
  }

  Future<void> _scanForEspDevices() async {
    setState(() {
      _isScanningEsp = true;
      _hasScannedEsp = true;
    });

    try {
      final cap = await WifiProvisioningService.checkScanCapability();
      if (!mounted) return;

      if (cap == ScanCapability.locationDisabled) {
        setState(() => _isScanningEsp = false);
        _showGpsDisabledDialog();
        return;
      } else if (cap == ScanCapability.wifiDisabled) {
        setState(() => _isScanningEsp = false);
        _showWifiDisabledDialog();
        return;
      }

      final results = await WifiProvisioningService.scanNearbyWifi(espOnly: true);
      if (mounted) {
        setState(() {
          _scannedEspDevices = results;
          _isScanningEsp = false;
        });

        if (results.isEmpty) {
          showFloatingToast(
            context,
            context.tr('info'),
            context.tr('wifi_no_esp_found'),
          );
        } else {
          showFloatingToast(
            context,
            context.tr('toast_success'),
            context.tr('wifi_detected_esp_title').replaceAll('{count}', results.length.toString()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningEsp = false);
        showFloatingToast(context, context.tr('error'), e.toString(), isError: true);
      }
    }
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.amber, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.tr('wifi_btn_turn_on_gps'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Text(
            context.tr('wifi_gps_disabled_warning'),
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('btn_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                WifiProvisioningService.openSystemWifiSettings();
              },
              child: Text(context.tr('wifi_open_settings_shortcut')),
            ),
          ],
        );
      },
    );
  }

  void _showWifiDisabledDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
          title: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.tr('wifi_btn_turn_on_wifi'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Text(
            context.tr('wifi_adapter_disabled_warning'),
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr('btn_cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                WifiProvisioningService.enableWifi();
              },
              child: Text(context.tr('wifi_btn_turn_on_wifi')),
            ),
          ],
        );
      },
    );
  }

  void _showConnectToEspModal(WiFiAccessPoint ap) {
    final passCtrl = TextEditingController(text: '12345678');
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2E) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F766E).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF0F766E), size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('wifi_connect_esp_title').replaceAll('{ssid}', ap.ssid),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    context.tr('wifi_signal_quality')
                                        .replaceAll('{rssi}', ap.level.toString())
                                        .replaceAll('{quality}', WifiProvisioningService.getSignalQuality(ap.level)),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('wifi_connect_esp_subtitle'),
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passCtrl,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            labelText: context.tr('wifi_esp_pass_label'),
                            hintText: context.tr('wifi_esp_pass_hint'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setModalState(() => obscure = !obscure),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showConnectingProgressModal(ap, passCtrl.text.trim());
                            },
                            child: Text(
                              context.tr('wifi_btn_connect_now'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showConnectingProgressModal(WiFiAccessPoint ap, String password) {
    EspConnectStep step = EspConnectStep.requestingWifi;
    int currentAttempt = 1;
    String? capturedMac;
    bool isTriggered = false;

    setState(() {
      _isConnectingInApp = true;
      _connectingSsid = ap.ssid;
    });

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;

            if (!isTriggered) {
              isTriggered = true;
              WifiProvisioningService.connectToEspWithProgress(
                ssid: ap.ssid,
                bssid: ap.bssid,
                password: password,
                onProgress: (newStep, {attempt, maxAttempts, mac, error}) {
                  if (!mounted) return;
                  setModalState(() {
                    step = newStep;
                    if (attempt != null) currentAttempt = attempt;
                    if (mac != null) capturedMac = mac;
                  });

                  if (newStep == EspConnectStep.success) {
                    setState(() {
                      _detectedEspMac = mac ?? ap.ssid.replaceFirst('ZenHome_Setup_', 'ESP_');
                      _isConnectingInApp = false;
                      _connectingSsid = null;
                      _currentConnectedSsid = ap.ssid;
                    });
                    Future.delayed(const Duration(milliseconds: 1400), () {
                      if (Navigator.canPop(modalCtx)) {
                        Navigator.pop(modalCtx);
                      }
                      if (mounted) {
                        ref.read(wifiSetupWizardProvider.notifier).setStep(1);
                        setState(() => _currentStep = 1);
                      }
                    });
                  } else if (newStep == EspConnectStep.failed) {
                    setState(() {
                      _isConnectingInApp = false;
                      _connectingSsid = null;
                    });
                  }
                },
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    context.tr('wifi_progress_modal_title'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${ap.ssid} • ${WifiProvisioningService.getSignalQuality(ap.level)} (${ap.level} dBm)',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // STEP 1: Yêu cầu kết nối Wi-Fi
                  _buildProgressItem(
                    isDark: isDark,
                    title: context.tr('wifi_progress_step1_req').replaceAll('{ssid}', ap.ssid),
                    isActive: step == EspConnectStep.requestingWifi,
                    isCompleted: step == EspConnectStep.routingInterface || step == EspConnectStep.handshaking || step == EspConnectStep.success,
                    isFailed: step == EspConnectStep.failed && currentAttempt == 1,
                  ),
                  const SizedBox(height: 12),

                  // STEP 2: Định tuyến cổng Wi-Fi
                  _buildProgressItem(
                    isDark: isDark,
                    title: context.tr('wifi_progress_step2_route'),
                    isActive: step == EspConnectStep.routingInterface,
                    isCompleted: step == EspConnectStep.handshaking || step == EspConnectStep.success,
                    isFailed: false,
                  ),
                  const SizedBox(height: 12),

                  // STEP 3: Bắt tay với ESP32 (192.168.4.1)
                  _buildProgressItem(
                    isDark: isDark,
                    title: context.tr('wifi_progress_step3_handshake').replaceAll('{retry}', currentAttempt.toString()),
                    isActive: step == EspConnectStep.handshaking,
                    isCompleted: step == EspConnectStep.success,
                    isFailed: step == EspConnectStep.failed,
                  ),
                  const SizedBox(height: 20),

                  // Trạng thái hoàn thành hoặc thất bại
                  if (step == EspConnectStep.success) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('wifi_progress_step4_success'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('wifi_progress_step4_desc').replaceAll('{mac}', capturedMac ?? ''),
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (step == EspConnectStep.failed) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 26),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr('wifi_progress_step4_failed'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('wifi_progress_failed_reason'),
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              WifiProvisioningService.openSystemWifiSettings();
                            },
                            child: Text(context.tr('wifi_open_settings_shortcut'), style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () {
                              setModalState(() {
                                step = EspConnectStep.requestingWifi;
                                currentAttempt = 1;
                                capturedMac = null;
                                isTriggered = false;
                              });
                            },
                            child: Text(context.tr('wifi_btn_retry_connect'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: Text(context.tr('btn_cancel'), style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Đang giữ kết nối... Nếu điện thoại hỏi "Mạng không có Internet, tiếp tục?", vui lòng chọn Có.',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildProgressItem({
    required bool isDark,
    required String title,
    required bool isActive,
    required bool isCompleted,
    required bool isFailed,
  }) {
    Color iconColor;
    Widget iconWidget;

    if (isCompleted) {
      iconColor = const Color(0xFF10B981);
      iconWidget = const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20);
    } else if (isFailed) {
      iconColor = Colors.redAccent;
      iconWidget = const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 20);
    } else if (isActive) {
      iconColor = const Color(0xFF0F766E);
      iconWidget = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
      );
    } else {
      iconColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
      iconWidget = Icon(Icons.radio_button_unchecked_rounded, color: iconColor, size: 20);
    }

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: iconWidget,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isCompleted
                      ? const Color(0xFF10B981)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openHomeWifiPicker() async {
    setState(() => _isScanningHomeWifi = true);

    try {
      final uniqueList = await ref.read(wifiSetupWizardProvider.notifier).scanNearbyHomeWifi();
      if (!mounted) return;
      setState(() => _isScanningHomeWifi = false);

      if (uniqueList.isEmpty) {
        showFloatingToast(context, context.tr('info'), context.tr('wifi_no_esp_found'));
        return;
      }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.65,
              ),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.wifi_rounded, color: Color(0xFF0F766E)),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('wifi_select_home_wifi_title'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: uniqueList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final ap = uniqueList[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Icon(
                            ap.level >= -65 ? Icons.wifi : Icons.wifi_2_bar_rounded,
                            color: ap.level >= -65 ? const Color(0xFF10B981) : Colors.amber,
                          ),
                          title: Text(ap.ssid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(
                            context.tr('wifi_signal_quality')
                                .replaceAll('{rssi}', ap.level.toString())
                                .replaceAll('{quality}', WifiProvisioningService.getSignalQuality(ap.level)),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            _ssidController.text = ap.ssid;
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningHomeWifi = false);
        showFloatingToast(context, context.tr('error'), e.toString(), isError: true);
      }
    }
  }

  Future<void> _checkEspConnection() async {
    setState(() {
      _isCheckingEsp = true;
    });

    try {
      final espMac = await WifiProvisioningService.pingEspQuick();
      if (!mounted) return;
      setState(() => _isCheckingEsp = false);

      if (espMac != null && espMac.isNotEmpty) {
        setState(() {
          _detectedEspMac = espMac;
        });
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('wifi_handshake_success').replaceAll('{mac}', espMac),
        );
      } else {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('wifi_handshake_failed'),
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingEsp = false);
        showFloatingToast(context, context.tr('error'), e.toString(), isError: true);
      }
    }
  }

  /// Bắt buộc xác thực kết nối tới Hub ESP32 trước khi cho phép chuyển sang Step 1 (Setup WiFi)
  Future<void> _proceedToStep1WithVerification() async {
    // 1. Nếu đã xác thực được kết nối với ESP32 từ trước
    if (_detectedEspMac != null && _detectedEspMac!.isNotEmpty) {
      if (mounted) {
        ref.read(wifiSetupWizardProvider.notifier).setStep(1);
        setState(() => _currentStep = 1);
      }
      return;
    }

    // 2. Nếu chưa có, chủ động thực hiện ping bắt tay với ESP32 tại 192.168.4.1
    setState(() => _isCheckingEsp = true);
    try {
      final espMac = await WifiProvisioningService.pingEspQuick();
      if (!mounted) return;
      setState(() => _isCheckingEsp = false);

      if (espMac != null && espMac.isNotEmpty) {
        ref.read(wifiSetupWizardProvider.notifier).setStep(1);
        setState(() {
          _detectedEspMac = espMac;
          _currentStep = 1;
        });
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('wifi_handshake_success').replaceAll('{mac}', espMac),
        );
      } else {
        _showEspNotConnectedDialog();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingEsp = false);
        _showEspNotConnectedDialog();
      }
    }
  }

  void _showEspNotConnectedDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Chưa kết nối với Hub ESP32',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Để cấu hình mạng Wi-Fi và liên kết tài khoản, điện thoại bắt buộc phải kết nối với sóng Wi-Fi phát ra từ Hub ESP32 trước.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('setup_steps_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(context.tr('setup_step_1'), style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(context.tr('setup_step_2'), style: const TextStyle(fontSize: 12.5)),
                  const SizedBox(height: 4),
                  Text(context.tr('setup_step_3'), style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('btn_understood'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _checkEspConnection();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.tr('btn_retry_connection'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWifiBanner(bool isDark) {
    final ssid = _currentConnectedSsid;
    final isEsp = ssid != null &&
        (ssid.startsWith('ZenHome_Setup_') ||
            ssid.startsWith('ESP32_') ||
            ssid.toLowerCase().contains('setup'));

    Color bgColor;
    Color borderColor;
    Color iconColor;
    IconData iconData;
    String title;
    String subtitle;

    if (isEsp) {
      bgColor = const Color(0xFF10B981).withOpacity(0.12);
      borderColor = const Color(0xFF10B981).withOpacity(0.4);
      iconColor = const Color(0xFF10B981);
      iconData = Icons.wifi_tethering_rounded;
      title = context.tr('wifi_current_esp_connected');
      subtitle = ssid;
    } else if (ssid != null && ssid.isNotEmpty) {
      bgColor = const Color(0xFF0F766E).withOpacity(0.08);
      borderColor = const Color(0xFF0F766E).withOpacity(0.25);
      iconColor = const Color(0xFF0F766E);
      iconData = Icons.wifi_rounded;
      title = context.tr('wifi_current_status_title');
      subtitle = context.tr('wifi_current_connected_to').replaceAll('{ssid}', ssid);
    } else {
      bgColor = Colors.amber.withOpacity(0.08);
      borderColor = Colors.amber.withOpacity(0.3);
      iconColor = Colors.amber;
      iconData = Icons.wifi_off_rounded;
      title = context.tr('wifi_current_status_title');
      subtitle = context.tr('wifi_current_disconnected');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isEsp
                            ? const Color(0xFF10B981)
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isEsp ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCheckingCurrentWifi)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                ),
            ],
          ),
          if (isEsp) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('wifi_current_esp_desc'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isCheckingEsp ? null : _checkEspConnection,
                icon: _isCheckingEsp
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  context.tr('wifi_handshake_now_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _validateAndStartPairing() {
    if (_ssidController.text.trim().isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_wifi_empty'), isError: true);
      return;
    }
    if (_adminPassController.text.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_empty_admin_pass'), isError: true);
      return;
    }
    if (_adminPassController.text != _confirmAdminPassController.text) {
      showFloatingToast(context, context.tr('error'), context.tr('err_pass_mismatch'), isError: true);
      return;
    }

    setState(() {
      _currentStep = 2;
      _pairingProgress = 0.15;
      _pairingFailed = false;
      _pairingErrorMessage = '';
      _pairingMessage = context.tr('step_check_esp_connection');
    });

    _executePairingWorkflow();
  }

  Future<void> _executePairingWorkflow() async {
    final activeConfig = widget.targetHome ?? ref.read(homeConfigProvider).activeConfig;
    final defaultServer = dotenv.env['DEFAULT_MQTT_SERVER'] ?? 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud';
    final defaultUser = dotenv.env['DEFAULT_MQTT_USER'] ?? 'DTC_ZenHome';
    final defaultPass = dotenv.env['DEFAULT_MQTT_PASS'] ?? 'DTC_ZenHome2103';

    await ref.read(wifiSetupWizardProvider.notifier).executePairingWorkflow(
      wifiSsid: _ssidController.text.trim(),
      wifiPass: _passController.text.trim(),
      adminPass: _adminPassController.text,
      mqttServer: _mqttServerController.text.trim(),
      mqttUser: _mqttUserController.text.trim(),
      mqttPass: _mqttPassController.text.trim(),
      defaultServer: defaultServer,
      defaultUser: defaultUser,
      defaultPass: defaultPass,
      targetHomeId: activeConfig.userId,
    );

    final pState = ref.read(wifiSetupWizardProvider);
    if (!mounted) return;
    setState(() {
      _currentStep = pState.currentStep;
      _pairingProgress = pState.pairingProgress;
      _pairingFailed = pState.pairingFailed;
      _pairingErrorMessage = pState.pairingErrorMessage;
      _pairingMessage = pState.pairingMessage;
      if (pState.detectedEspMac != null) {
        _detectedEspMac = pState.detectedEspMac;
      }
    });
  }

  Widget _buildStepperHeader(bool isDark) {
    final steps = [
      {'title': context.tr('wifi_step_prep'), 'icon': Icons.power_rounded},
      {'title': context.tr('wifi_step_config'), 'icon': Icons.wifi_rounded},
      {'title': context.tr('wifi_step_pair'), 'icon': Icons.sync_rounded},
      {'title': context.tr('wifi_step_done'), 'icon': Icons.check_circle_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepBefore = index ~/ 2;
            final isPassed = _currentStep > stepBefore;
            return Expanded(
              child: Container(
                height: 3,
                color: isPassed ? const Color(0xFF10B981) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCurrent = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          Color badgeColor;
          Color textColor;
          if (isCompleted) {
            badgeColor = const Color(0xFF10B981);
            textColor = Colors.white;
          } else if (isCurrent) {
            badgeColor = const Color(0xFF0F766E);
            textColor = Colors.white;
          } else {
            badgeColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
            textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F766E).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[stepIndex]['title'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? Colors.grey.shade500 : Colors.grey.shade600),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // --- STEP 0: Chuẩn bị thiết bị & Dò quét sóng ESP32 ---
  Widget _buildStep0Prepare(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hướng dẫn ban đầu
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E).withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, color: Color(0xFF0F766E), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr('wifi_prep_desc'),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildCurrentWifiBanner(isDark),
        const SizedBox(height: 18),

        _buildGuideCard(
          stepNumber: '1',
          title: context.tr('wifi_step1_title'),
          description: context.tr('wifi_step1_desc'),
          icon: Icons.electrical_services_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 12),

        _buildGuideCard(
          stepNumber: '2',
          title: context.tr('wifi_step2_title'),
          description: context.tr('wifi_step2_desc'),
          icon: Icons.lightbulb_outline_rounded,
          isDark: isDark,
        ),
        const SizedBox(height: 18),

        // 2. KHU VỰC DÒ QUÉT SÓNG ESP32 VÀ KẾT NỐI TRỰC TIẾP TRONG ỨNG DỤNG
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _detectedEspMac != null
                  ? const Color(0xFF10B981).withOpacity(0.6)
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              width: _detectedEspMac != null ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _detectedEspMac != null ? Icons.check_circle_rounded : Icons.wifi_find_rounded,
                          color: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _detectedEspMac != null ? context.tr('wifi_found_esp') : context.tr('wifi_scan_esp_btn'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  if (_detectedEspMac != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _detectedEspMac!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Nút bấm kích hoạt dò quét sóng ESP32
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_isScanningEsp || _isConnectingInApp) ? null : _scanForEspDevices,
                  icon: _isScanningEsp
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.sensors_rounded, size: 20),
                  label: Text(
                    _isScanningEsp ? context.tr('wifi_scanning_signal') : context.tr('wifi_scan_esp_btn'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              // Danh sách thiết bị ESP32 quét được
              if (_isScanningEsp) ...[
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF0F766E)),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('wifi_scanning_signal'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_scannedEspDevices.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  context.tr('wifi_detected_esp_title').replaceAll('{count}', _scannedEspDevices.length.toString()),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scannedEspDevices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ap = _scannedEspDevices[i];
                    final isConnectingThis = _isConnectingInApp && _connectingSsid == ap.ssid;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              ap.level >= -60 ? Icons.wifi : Icons.wifi_2_bar_rounded,
                              color: ap.level >= -60 ? const Color(0xFF10B981) : Colors.amber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ap.ssid,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('wifi_signal_quality')
                                      .replaceAll('{rssi}', ap.level.toString())
                                      .replaceAll('{quality}', WifiProvisioningService.getSignalQuality(ap.level)),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _isConnectingInApp ? null : () => _showConnectToEspModal(ap),
                              child: isConnectingThis
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(context.tr('btn_connect'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (_hasScannedEsp && !_isScanningEsp) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('wifi_no_esp_found'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kiểm tra lại bo mạch ESP32:\n'
                        '• Đảm bảo ESP32 đã cấp nguồn điện (đèn đỏ sáng).\n'
                        '• Đèn LED xanh (GPIO 2) đang nháy nhanh (chế độ phát sóng AP).\n'
                        '• Nếu đèn không nháy hoặc đang sáng đứng: Nhấn giữ nút BOOT trong 5 giây để reset về chế độ cài đặt.\n'
                        '• Đảm bảo đã bật Vị trí (GPS) và Wi-Fi trên điện thoại.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Phím tắt mở Cài đặt Wi-Fi máy nếu người dùng muốn thao tác truyền thống
              Center(
                child: TextButton.icon(
                  onPressed: () => WifiProvisioningService.openSystemWifiSettings(),
                  icon: const Icon(Icons.settings_suggest_outlined, size: 16),
                  label: Text(
                    context.tr('wifi_open_settings_shortcut'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. Phím kiểm tra kết nối thủ công
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _detectedEspMac != null ? Icons.check_circle : Icons.link_rounded,
                        color: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _detectedEspMac != null ? context.tr('wifi_found_esp') : context.tr('wifi_check_conn_label'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isCheckingEsp ? null : _checkEspConnection,
                  icon: _isCheckingEsp
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(_isCheckingEsp ? context.tr('wifi_checking_esp') : context.tr('wifi_check_esp_btn')),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        // 4. Nút Tiếp tục cấu hình
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: _isCheckingEsp ? null : _proceedToStep1WithVerification,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _detectedEspMac != null
                      ? 'Đã kết nối (${MaskingHelper.maskMac(_detectedEspMac)}) • Tiếp tục'
                      : 'Kiểm tra kết nối Hub & Tiếp tục',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                stepNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, size: 24),
        ],
      ),
    );
  }

  // --- STEP 1: Cấu hình Mạng & Mật khẩu kỹ thuật ---
  Widget _buildStep1Configure(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E).withOpacity(isDark ? 1 : 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wifi_rounded, color: Color(0xFF0F766E)),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('wifi_home_info_section'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: context.tr('wifi_ssid'),
                  hintText: context.tr('wifi_ssid_hint'),
                  prefixIcon: const Icon(Icons.router_outlined),
                  suffixIcon: IconButton(
                    tooltip: context.tr('wifi_scan_nearby_home_btn'),
                    icon: _isScanningHomeWifi
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find_rounded, color: Color(0xFF0F766E)),
                    onPressed: _isScanningHomeWifi ? null : _openHomeWifiPicker,
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passController,
                obscureText: _obscureWifiPass,
                decoration: InputDecoration(
                  labelText: context.tr('wifi_pass'),
                  hintText: context.tr('wifi_pass_hint'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureWifiPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureWifiPass = !_obscureWifiPass),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E).withOpacity(isDark ? 1 : 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF0F766E)),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('wifi_admin_pass_section'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _adminPassController,
                obscureText: _obscureAdminPass,
                decoration: InputDecoration(
                  labelText: context.tr('admin_pass_opt'),
                  hintText: context.tr('admin_pass_hint'),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureAdminPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureAdminPass = !_obscureAdminPass),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _confirmAdminPassController,
                obscureText: _obscureConfirmPass,
                decoration: InputDecoration(
                  labelText: context.tr('confirm_admin_pass'),
                  hintText: context.tr('confirm_admin_pass_hint'),
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Cấu hình MQTT nâng cao (Collapsible)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF131B2E).withOpacity(isDark ? 1 : 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showAdvancedMqtt,
              onExpansionChanged: (val) => setState(() => _showAdvancedMqtt = val),
              leading: const Icon(Icons.cloud_sync_outlined, color: Color(0xFF0F766E)),
              title: Text(context.tr('wifi_mqtt_adv_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(
                _mqttServerController.text.isNotEmpty ? _mqttServerController.text : context.tr('wifi_mqtt_default_cloud'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _mqttServerController,
                        decoration: InputDecoration(
                          labelText: context.tr('mqtt_server_address'),
                          hintText: context.tr('mqtt_server_hint'),
                          prefixIcon: const Icon(Icons.dns_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mqttUserController,
                        decoration: InputDecoration(
                          labelText: context.tr('mqtt_user'),
                          hintText: context.tr('mqtt_user_hint'),
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mqttPassController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: context.tr('mqtt_pass'),
                          hintText: context.tr('mqtt_pass_hint'),
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    ref.read(wifiSetupWizardProvider.notifier).setStep(0);
                    setState(() => _currentStep = 0);
                  },
                  child: Text(context.tr('wifi_btn_back')),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                  ),
                  onPressed: _validateAndStartPairing,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.tr('wifi_btn_start_pairing'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      const Icon(Icons.flash_on_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- STEP 2: Đang ghép nối & nạp cấu hình ---
  Widget _buildStep2Pairing(bool isDark) {
    final remainingSecs = ref.watch(wifiSetupWizardProvider.select((s) => s.remainingTimeoutSeconds));
    final mins = remainingSecs ~/ 60;
    final secs = remainingSecs % 60;
    final timeFormatted = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (!_pairingFailed) ...[
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${(_pairingProgress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LinearProgressIndicator(
                value: _pairingProgress,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _pairingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF0F766E)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('wifi_time_remaining').replaceAll('{time}', timeFormatted),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('wifi_pairing_failed_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            const SizedBox(height: 12),
            Text(
              _pairingErrorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isCheckingEsp ? null : _proceedToStep1WithVerification,
                    child: Text(context.tr('wifi_btn_change_wifi_pass')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _validateAndStartPairing,
                    child: Text(context.tr('wifi_btn_retry')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- STEP 3: Hoàn tất & Sẵn sàng ---
  Widget _buildStep3Complete(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 55),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('wifi_pairing_success_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('wifi_pairing_success_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          if (_detectedEspMac != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory_rounded, size: 18, color: Color(0xFF0F766E)),
                  const SizedBox(width: 8),
                  Text(
                    'MAC: $_detectedEspMac',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _detectedEspMac != null ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const DeviceMappingScreen()),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.dashboard_customize_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(context.tr('wifi_btn_device_mapping'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('wifi_btn_return_home'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetHomeBanner(bool isDark, SmartConfig home) {
    final themeColor = HomeHelper.getThemeColor(home.homeColor);
    final iconData = HomeHelper.getIconData(home.homeIcon);
    final typeName = HomeHelper.getHomeTypeLabel(home.homeType, context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Đang cài đặt cho: ',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        home.homeName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$typeName • Hub ESP32 sẽ liên kết độc quyền với nhà này',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: themeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, size: 16, color: themeColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WifiSetupWizardState>(wifiSetupWizardProvider, (previous, next) {
      if (mounted) {
        setState(() {
          if (next.currentStep != previous?.currentStep) {
            _currentStep = next.currentStep;
          }
          _pairingProgress = next.pairingProgress;
          _pairingFailed = next.pairingFailed;
          _pairingErrorMessage = next.pairingErrorMessage;
          _pairingMessage = next.pairingMessage;
          if (next.detectedEspMac != null) {
            _detectedEspMac = next.detectedEspMac;
          }
        });

        // Hoàn thành thiết lập -> Tự động chuyển sang Thêm thiết bị (Device Mapping)
        if (next.currentStep == 3 && previous?.currentStep != 3) {
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DeviceMappingScreen()),
              );
            }
          });
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentStep != 2,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(context.tr('wifi_cancel_pairing_title'))),
              ],
            ),
            content: Text(context.tr('wifi_cancel_pairing_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('btn_cancel')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('btn_understood')),
              ),
            ],
          ),
        );

        if (shouldCancel == true && context.mounted) {
          await ref.read(wifiSetupWizardProvider.notifier).cancelSetupWorkflow();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF6F8FB),
        appBar: AppBar(
          title: Text(
            context.tr('wifi_setup_title'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              _buildTargetHomeBanner(isDark, widget.targetHome ?? ref.watch(homeConfigProvider).activeConfig),
              _buildStepperHeader(isDark),
              const SizedBox(height: 24),
              if (_currentStep == 0) _buildStep0Prepare(isDark),
              if (_currentStep == 1) _buildStep1Configure(isDark),
              if (_currentStep == 2) _buildStep2Pairing(isDark),
              if (_currentStep == 3) _buildStep3Complete(isDark),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
