import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:wifi_scan/wifi_scan.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
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
  final TextEditingController _confirmAdminPassController =
      TextEditingController();

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
        ref
            .read(homeConfigProvider)
            .switchActiveHome(widget.targetHome!.userId);
      });
    }
    final activeConfig =
        widget.targetHome ?? ref.read(homeConfigProvider).activeConfig;
    final defaultServer = dotenv.env['DEFAULT_MQTT_SERVER'] ??
        'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud';
    final defaultUser = dotenv.env['DEFAULT_MQTT_USER'] ?? 'DTC_ZenHome';
    final defaultPass = dotenv.env['DEFAULT_MQTT_PASS'] ?? 'DTC_ZenHome2103';

    _mqttServerController.text = (activeConfig.mqttServer.isNotEmpty &&
            activeConfig.mqttServer != 'broker.emqx.io')
        ? activeConfig.mqttServer
        : defaultServer;
    _mqttUserController.text = (activeConfig.mqttUser != null &&
            activeConfig.mqttUser!.isNotEmpty &&
            !activeConfig.mqttUser!.startsWith('user_'))
        ? activeConfig.mqttUser!
        : defaultUser;
    _mqttPassController.text =
        (activeConfig.mqttPass != null && activeConfig.mqttPass!.isNotEmpty)
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
        if (ssid != null &&
            (ssid.startsWith('ZenHome_Setup_') || ssid.startsWith('ESP32_'))) {
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
        debugPrint(
            "[SETUP-DISPOSE] 🛑 Đã dọn dẹp và reset MAC về rỗng do người dùng thoát trước khi hoàn tất.");
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

      final results =
          await WifiProvisioningService.scanNearbyWifi(espOnly: true);
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
            context
                .tr('wifi_detected_esp_title')
                .replaceAll('{count}', results.length.toString()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningEsp = false);
        showFloatingToast(context, context.tr('error'), e.toString(),
            isError: true);
      }
    }
  }

  void _showGpsDisabledDialog() {
    showZenGlassDialog<void>(
      context: context,
      accentColor: AppColors.amberGlow,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final mutedColor =
            isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.amberGlow.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.location_off_rounded,
                      color: AppColors.amberGlow, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('wifi_btn_turn_on_gps'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('wifi_gps_disabled_warning'),
              style: TextStyle(fontSize: 14, height: 1.45, color: mutedColor),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel'),
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('wifi_open_settings_shortcut'),
                    accentColor:
                        _detectedEspMac != null ? AppColors.emeraldGlow : null,
                    onPressed: () {
                      Navigator.pop(ctx);
                      WifiProvisioningService.openSystemWifiSettings();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showWifiDisabledDialog() {
    showZenGlassDialog<void>(
      context: context,
      accentColor: AppColors.roseGlow,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final mutedColor =
            isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.roseGlow.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.roseGlow.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.wifi_off_rounded,
                      color: AppColors.roseGlow, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('wifi_btn_turn_on_wifi'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('wifi_adapter_disabled_warning'),
              style: TextStyle(fontSize: 14, height: 1.45, color: mutedColor),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel'),
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('wifi_btn_turn_on_wifi'),
                    accentColor:
                        _detectedEspMac != null ? AppColors.emeraldGlow : null,
                    onPressed: () {
                      Navigator.pop(ctx);
                      WifiProvisioningService.enableWifi();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showConnectToEspModal(WiFiAccessPoint ap) {
    final passCtrl = TextEditingController(text: '12345678');
    bool obscure = true;

    showZenGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showHandle: true,
      padBottomForKeyboard: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final zen = ctx.zenColors;
            final textColor = isDark ? AppColors.darkText : AppColors.lightText;
            final mutedColor =
                isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22,
                8,
                22,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          gradient: zen.brandHero,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.wifi_tethering_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context
                                  .tr('wifi_connect_esp_title')
                                  .replaceAll('{ssid}', ap.ssid),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context
                                  .tr('wifi_signal_quality')
                                  .replaceAll('{rssi}', ap.level.toString())
                                  .replaceAll(
                                    '{quality}',
                                    WifiProvisioningService.getSignalQuality(
                                        ap.level),
                                  ),
                              style: TextStyle(
                                fontSize: 12,
                                color: mutedColor,
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
                      fontSize: 13.5,
                      color: mutedColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    style: TextStyle(
                        color: textColor, fontWeight: FontWeight.w600),
                    decoration: zenGlassInputDecoration(
                      ctx,
                      labelText: context.tr('wifi_esp_pass_label'),
                      hintText: context.tr('wifi_esp_pass_hint'),
                      prefixIcon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: mutedColor,
                        ),
                        onPressed: () =>
                            setModalState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ZenGlassButton(
                      label: context.tr('wifi_btn_connect_now'),
                      icon: Icons.bolt_rounded,
                      accentColor: _detectedEspMac != null
                          ? AppColors.emeraldGlow
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      onPressed: () {
                        final pwd = passCtrl.text.trim();
                        Navigator.pop(ctx);
                        _showConnectingProgressModal(ap, pwd);
                      },
                    ),
                  ),
                ],
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

    showZenGlassDialog<void>(
      context: context,
      barrierDismissible: false,
      maxWidth: 420,
      builder: (modalCtx) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final zen = ctx.zenColors;
              final textColor =
                  isDark ? AppColors.darkText : AppColors.lightText;
              final mutedColor =
                  isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

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
                        _detectedEspMac = mac ??
                            ap.ssid.replaceFirst('ZenHome_Setup_', 'ESP_');
                        _isConnectingInApp = false;
                        _connectingSsid = null;
                        _currentConnectedSsid = ap.ssid;
                      });
                      Future.delayed(const Duration(milliseconds: 1400), () {
                        if (modalCtx.mounted && Navigator.canPop(modalCtx)) {
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

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('wifi_progress_modal_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${ap.ssid} • ${WifiProvisioningService.getSignalQuality(ap.level)} (${ap.level} dBm)',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // STEP 1: Yêu cầu kết nối Wi-Fi
                    _buildProgressItem(
                      ctx: ctx,
                      isDark: isDark,
                      title: context
                          .tr('wifi_progress_step1_req')
                          .replaceAll('{ssid}', ap.ssid),
                      isActive: step == EspConnectStep.requestingWifi,
                      isCompleted: step == EspConnectStep.routingInterface ||
                          step == EspConnectStep.handshaking ||
                          step == EspConnectStep.success,
                      isFailed: step == EspConnectStep.failed &&
                          currentAttempt == 1,
                    ),
                    const SizedBox(height: 12),

                    // STEP 2: Định tuyến cổng Wi-Fi
                    _buildProgressItem(
                      ctx: ctx,
                      isDark: isDark,
                      title: context.tr('wifi_progress_step2_route'),
                      isActive: step == EspConnectStep.routingInterface,
                      isCompleted: step == EspConnectStep.handshaking ||
                          step == EspConnectStep.success,
                      isFailed: false,
                    ),
                    const SizedBox(height: 12),

                    // STEP 3: Bắt tay với ESP32 (192.168.4.1)
                    _buildProgressItem(
                      ctx: ctx,
                      isDark: isDark,
                      title: context
                          .tr('wifi_progress_step3_handshake')
                          .replaceAll('{retry}', currentAttempt.toString()),
                      isActive: step == EspConnectStep.handshaking,
                      isCompleted: step == EspConnectStep.success,
                      isFailed: step == EspConnectStep.failed,
                    ),
                    const SizedBox(height: 20),

                    // Trạng thái hoàn thành hoặc thất bại
                    if (step == EspConnectStep.success) ...[
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(14),
                        surfaceColor: AppColors.emeraldGlow
                            .withOpacity(isDark ? 0.14 : 0.10),
                        glowColor: AppColors.emeraldGlow,
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.emeraldGlow, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('wifi_progress_step4_success'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.emeraldGlow,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context
                                        .tr('wifi_progress_step4_desc')
                                        .replaceAll('{mac}', capturedMac ?? ''),
                                    style: TextStyle(
                                        fontSize: 12, color: mutedColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (step == EspConnectStep.failed) ...[
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(14),
                        surfaceColor:
                            AppColors.roseGlow.withOpacity(isDark ? 0.14 : 0.08),
                        glowColor: AppColors.roseGlow,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel_rounded,
                                    color: AppColors.roseGlow, size: 24),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr('wifi_progress_step4_failed'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.roseGlow,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('wifi_progress_failed_reason'),
                              style:
                                  TextStyle(fontSize: 12, color: mutedColor),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ZenGlassButton(
                              label: context.tr('wifi_open_settings_shortcut'),
                              isPrimary: false,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 13),
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                WifiProvisioningService
                                    .openSystemWifiSettings();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ZenGlassButton(
                              label: context.tr('wifi_btn_retry_connect'),
                              accentColor: _detectedEspMac != null
                                  ? AppColors.emeraldGlow
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 13),
                              onPressed: () {
                                setModalState(() {
                                  step = EspConnectStep.requestingWifi;
                                  currentAttempt = 1;
                                  capturedMac = null;
                                  isTriggered = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          child: Text(
                            context.tr('btn_cancel'),
                            style: TextStyle(
                              color: mutedColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 14,
                        padding: const EdgeInsets.all(12),
                        surfaceColor:
                            zen.primary.withOpacity(isDark ? 0.10 : 0.06),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? zen.primaryAccent : zen.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Đang giữ kết nối... Nếu điện thoại hỏi "Mạng không có Internet, tiếp tục?", vui lòng chọn Có.',
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProgressItem({
    required BuildContext ctx,
    required bool isDark,
    required String title,
    required bool isActive,
    required bool isCompleted,
    required bool isFailed,
  }) {
    final zen = ctx.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final activePrimary = isDark ? zen.primaryAccent : zen.primary;

    Color iconColor;
    Widget iconWidget;

    if (isCompleted) {
      iconColor = AppColors.emeraldGlow;
      iconWidget = const Icon(Icons.check_circle_rounded,
          color: AppColors.emeraldGlow, size: 20);
    } else if (isFailed) {
      iconColor = AppColors.roseGlow;
      iconWidget = const Icon(Icons.cancel_rounded,
          color: AppColors.roseGlow, size: 20);
    } else if (isActive) {
      iconColor = activePrimary;
      iconWidget = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: activePrimary),
      );
    } else {
      iconColor = mutedColor;
      iconWidget =
          Icon(Icons.radio_button_unchecked_rounded, color: iconColor, size: 20);
    }

    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.14),
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
              fontWeight:
                  isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
              color: isActive
                  ? textColor
                  : (isCompleted ? AppColors.emeraldGlow : mutedColor),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openHomeWifiPicker() async {
    setState(() => _isScanningHomeWifi = true);

    try {
      final uniqueList = await ref
          .read(wifiSetupWizardProvider.notifier)
          .scanNearbyHomeWifi();
      if (!mounted) return;
      setState(() => _isScanningHomeWifi = false);

      if (uniqueList.isEmpty) {
        showFloatingToast(
            context, context.tr('info'), context.tr('wifi_no_esp_found'));
        return;
      }

      showZenGlassBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        maxHeightFactor: 0.68,
        showHandle: true,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final zen = ctx.zenColors;
          final textColor = isDark ? AppColors.darkText : AppColors.lightText;
          final mutedColor =
              isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: zen.brandHero,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.wifi_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('wifi_select_home_wifi_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: uniqueList.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final ap = uniqueList[i];
                      final bool isStrong = ap.level >= -65;
                      return ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        surfaceColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white.withOpacity(0.60),
                        onTap: () {
                          _ssidController.text = ap.ssid;
                          Navigator.pop(ctx);
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isStrong
                                        ? AppColors.emeraldGlow
                                        : AppColors.amberGlow)
                                    .withOpacity(0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isStrong
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_2_bar_rounded,
                                color: isStrong
                                    ? AppColors.emeraldGlow
                                    : AppColors.amberGlow,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ap.ssid,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context
                                        .tr('wifi_signal_quality')
                                        .replaceAll(
                                            '{rssi}', ap.level.toString())
                                        .replaceAll(
                                          '{quality}',
                                          WifiProvisioningService
                                              .getSignalQuality(ap.level),
                                        ),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: mutedColor),
                          ],
                        ),
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
        showFloatingToast(context, context.tr('error'), e.toString(),
            isError: true);
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
        showFloatingToast(context, context.tr('error'), e.toString(),
            isError: true);
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
    showZenGlassDialog<void>(
      context: context,
      accentColor: AppColors.amberGlow,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final mutedColor =
            isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.amberGlow.withOpacity(0.3)),
                  ),
                  child: const Icon(Icons.wifi_off_rounded,
                      color: AppColors.amberGlow, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chưa kết nối với Hub ESP32',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Để cấu hình mạng Wi-Fi và liên kết tài khoản, điện thoại bắt buộc phải kết nối với sóng Wi-Fi phát ra từ Hub ESP32 trước.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 14),
            ZenLiquidGlass(
              blurSigma: 0,
              borderRadius: 14,
              padding: const EdgeInsets.all(12),
              surfaceColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('setup_steps_title'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(context.tr('setup_step_1'),
                      style: TextStyle(fontSize: 12.5, color: mutedColor)),
                  const SizedBox(height: 4),
                  Text(context.tr('setup_step_2'),
                      style: TextStyle(fontSize: 12.5, color: mutedColor)),
                  const SizedBox(height: 4),
                  Text(context.tr('setup_step_3'),
                      style: TextStyle(fontSize: 12.5, color: mutedColor)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_understood'),
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_retry_connection'),
                    icon: Icons.refresh_rounded,
                    accentColor:
                        _detectedEspMac != null ? AppColors.emeraldGlow : null,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _checkEspConnection();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurrentWifiBanner(bool isDark) {
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final ssid = _currentConnectedSsid;
    final isEsp = ssid != null &&
        (ssid.startsWith('ZenHome_Setup_') ||
            ssid.startsWith('ESP32_') ||
            ssid.toLowerCase().contains('setup'));

    Color iconColor;
    IconData iconData;
    String title;
    String subtitle;

    if (isEsp) {
      iconColor = AppColors.emeraldGlow;
      iconData = Icons.wifi_tethering_rounded;
      title = context.tr('wifi_current_esp_connected');
      subtitle = ssid;
    } else if (ssid != null && ssid.isNotEmpty) {
      iconColor = isDark ? zen.primaryAccent : zen.primary;
      iconData = Icons.wifi_rounded;
      title = context.tr('wifi_current_status_title');
      subtitle =
          context.tr('wifi_current_connected_to').replaceAll('{ssid}', ssid);
    } else {
      iconColor = AppColors.amberGlow;
      iconData = Icons.wifi_off_rounded;
      title = context.tr('wifi_current_status_title');
      subtitle = context.tr('wifi_current_disconnected');
    }

    return ZenGlassCard(
      blurSigma: 14,
      isActive: isEsp,
      glowColor: iconColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.16),
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
                        color: isEsp ? AppColors.emeraldGlow : textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isEsp ? FontWeight.bold : FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isCheckingCurrentWifi)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                ),
            ],
          ),
          if (isEsp) ...[
            const SizedBox(height: 12),
            Text(
              context.tr('wifi_current_esp_desc'),
              style: TextStyle(
                fontSize: 12,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('wifi_handshake_now_btn'),
                icon: Icons.bolt_rounded,
                isLoading: _isCheckingEsp,
                accentColor: AppColors.emeraldGlow,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                onPressed: _isCheckingEsp ? null : _checkEspConnection,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _validateAndStartPairing() {
    if (_ssidController.text.trim().isEmpty) {
      showFloatingToast(
          context, context.tr('error'), context.tr('err_wifi_empty'),
          isError: true);
      return;
    }
    if (_adminPassController.text.isEmpty) {
      showFloatingToast(
          context, context.tr('error'), context.tr('err_empty_admin_pass'),
          isError: true);
      return;
    }
    if (_adminPassController.text != _confirmAdminPassController.text) {
      showFloatingToast(
          context, context.tr('error'), context.tr('err_pass_mismatch'),
          isError: true);
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
    final activeConfig =
        widget.targetHome ?? ref.read(homeConfigProvider).activeConfig;
    final defaultServer = dotenv.env['DEFAULT_MQTT_SERVER'] ??
        'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud';
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
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final steps = [
      {'title': context.tr('wifi_step_prep'), 'icon': Icons.power_rounded},
      {'title': context.tr('wifi_step_config'), 'icon': Icons.wifi_rounded},
      {'title': context.tr('wifi_step_pair'), 'icon': Icons.sync_rounded},
      {
        'title': context.tr('wifi_step_done'),
        'icon': Icons.check_circle_rounded
      },
    ];

    return ZenGlassCard(
      blurSigma: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepBefore = index ~/ 2;
            final isPassed = _currentStep > stepBefore;
            return Expanded(
              child: Container(
                height: 2.5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isPassed
                      ? AppColors.emeraldGlow
                      : (isDark
                          ? Colors.white.withOpacity(0.14)
                          : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = index ~/ 2;
          final isCurrent = _currentStep == stepIndex;
          final isCompleted = _currentStep > stepIndex;

          final Color activeGlow =
              isCompleted ? AppColors.emeraldGlow : zen.primary;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZenGlassPill(
                blurSigma: 0,
                borderRadius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isSelected: isCurrent || isCompleted,
                glowColor: activeGlow,
                customGradient: isCurrent ? zen.brandHero : null,
                child: isCompleted
                    ? const Icon(Icons.check_rounded,
                        size: 17, color: AppColors.emeraldGlow)
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : mutedColor,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[stepIndex]['title'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  color: isCurrent
                      ? textColor
                      : (isCompleted ? AppColors.emeraldGlow : mutedColor),
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
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentColor = isDark ? zen.primaryAccent : zen.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hướng dẫn ban đầu
        ZenGlassCard(
          blurSigma: 14,
          isActive: true,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: zen.brandHero,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.tips_and_updates_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  context.tr('wifi_prep_desc'),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCurrentWifiBanner(isDark),
        const SizedBox(height: 16),

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
        const SizedBox(height: 16),

        // 2. KHU VỰC DÒ QUÉT SÓNG ESP32 VÀ KẾT NỐI TRỰC TIẾP TRONG ỨNG DỤNG
        ZenGlassCard(
          blurSigma: 16,
          isActive: _detectedEspMac != null,
          glowColor:
              _detectedEspMac != null ? AppColors.emeraldGlow : zen.primary,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: (_detectedEspMac != null
                                    ? AppColors.emeraldGlow
                                    : accentColor)
                                .withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _detectedEspMac != null
                                ? Icons.check_circle_rounded
                                : Icons.wifi_find_rounded,
                            color: _detectedEspMac != null
                                ? AppColors.emeraldGlow
                                : accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _detectedEspMac != null
                                ? context.tr('wifi_found_esp')
                                : context.tr('wifi_scan_esp_btn'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_detectedEspMac != null) ...[
                    const SizedBox(width: 8),
                    ZenGlassPill(
                      blurSigma: 0,
                      isSelected: true,
                      glowColor: AppColors.emeraldGlow,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Text(
                        _detectedEspMac!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.emeraldGlow,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Nút bấm kích hoạt dò quét sóng ESP32
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  label: _isScanningEsp
                      ? context.tr('wifi_scanning_signal')
                      : context.tr('wifi_scan_esp_btn'),
                  icon: Icons.sensors_rounded,
                  isLoading: _isScanningEsp,
                  accentColor:
                      _detectedEspMac != null ? AppColors.emeraldGlow : null,
                  onPressed: (_isScanningEsp || _isConnectingInApp)
                      ? null
                      : _scanForEspDevices,
                ),
              ),

              // Danh sách thiết bị ESP32 quét được
              if (_isScanningEsp) ...[
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: accentColor),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('wifi_scanning_signal'),
                        style: TextStyle(
                          fontSize: 13,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_scannedEspDevices.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  context
                      .tr('wifi_detected_esp_title')
                      .replaceAll('{count}', _scannedEspDevices.length.toString()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _scannedEspDevices.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ap = _scannedEspDevices[i];
                    final isConnectingThis =
                        _isConnectingInApp && _connectingSsid == ap.ssid;
                    final bool isStrong = ap.level >= -60;

                    return ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 16,
                      padding: const EdgeInsets.all(12),
                      surfaceColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.62),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: (isStrong
                                      ? AppColors.emeraldGlow
                                      : AppColors.amberGlow)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              isStrong
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_2_bar_rounded,
                              color: isStrong
                                  ? AppColors.emeraldGlow
                                  : AppColors.amberGlow,
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context
                                      .tr('wifi_signal_quality')
                                      .replaceAll('{rssi}', ap.level.toString())
                                      .replaceAll(
                                        '{quality}',
                                        WifiProvisioningService.getSignalQuality(
                                            ap.level),
                                      ),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ZenGlassButton(
                            label: context.tr('btn_connect'),
                            isLoading: isConnectingThis,
                            accentColor: _detectedEspMac != null
                                ? AppColors.emeraldGlow
                                : null,
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 9),
                            onPressed: _isConnectingInApp
                                ? null
                                : () => _showConnectToEspModal(ap),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (_hasScannedEsp && !_isScanningEsp) ...[
                const SizedBox(height: 14),
                ZenLiquidGlass(
                  blurSigma: 0,
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  surfaceColor:
                      AppColors.amberGlow.withOpacity(isDark ? 0.12 : 0.08),
                  glowColor: AppColors.amberGlow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.amberGlow, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('wifi_no_esp_found'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.amber.shade200
                                    : Colors.amber.shade900,
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
                          color: mutedColor,
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
                  onPressed: () =>
                      WifiProvisioningService.openSystemWifiSettings(),
                  icon: Icon(Icons.settings_suggest_outlined,
                      size: 16, color: accentColor),
                  label: Text(
                    context.tr('wifi_open_settings_shortcut'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Phím kiểm tra kết nối thủ công
        ZenGlassCard(
          blurSigma: 14,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _detectedEspMac != null
                        ? Icons.check_circle_rounded
                        : Icons.link_rounded,
                    color: _detectedEspMac != null
                        ? AppColors.emeraldGlow
                        : accentColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _detectedEspMac != null
                          ? context.tr('wifi_found_esp')
                          : context.tr('wifi_check_conn_label'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  label: _isCheckingEsp
                      ? context.tr('wifi_checking_esp')
                      : context.tr('wifi_check_esp_btn'),
                  icon: Icons.refresh_rounded,
                  isPrimary: false,
                  isLoading: _isCheckingEsp,
                  onPressed: _isCheckingEsp ? null : _checkEspConnection,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),
        // 4. Nút Tiếp tục cấu hình
        SizedBox(
          width: double.infinity,
          child: ZenGlassButton(
            label: _detectedEspMac != null
                ? 'Đã kết nối (${MaskingHelper.maskMac(_detectedEspMac)}) • Tiếp tục'
                : 'Kiểm tra kết nối Hub & Tiếp tục',
            icon: Icons.arrow_forward_rounded,
            accentColor:
                _detectedEspMac != null ? AppColors.emeraldGlow : null,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            onPressed:
                _isCheckingEsp ? null : _proceedToStep1WithVerification,
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
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentColor = isDark ? zen.primaryAccent : zen.primary;

    return ZenGlassCard(
      blurSigma: 12,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZenGlassPill(
            blurSigma: 0,
            isSelected: true,
            glowColor: zen.primary,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text(
              stepNumber,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accentColor,
                fontSize: 13.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: mutedColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: mutedColor.withOpacity(0.75), size: 22),
        ],
      ),
    );
  }

  // --- STEP 1: Cấu hình Mạng & Mật khẩu kỹ thuật ---
  Widget _buildStep1Configure(bool isDark) {
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentColor = isDark ? zen.primaryAccent : zen.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wi-Fi Credentials Card
        ZenGlassCard(
          blurSigma: 16,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.wifi_rounded, color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('wifi_home_info_section'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _ssidController,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                decoration: zenGlassInputDecoration(
                  context,
                  labelText: context.tr('wifi_ssid'),
                  hintText: context.tr('wifi_ssid_hint'),
                  prefixIcon: Icons.router_outlined,
                  suffixIcon: IconButton(
                    tooltip: context.tr('wifi_scan_nearby_home_btn'),
                    icon: _isScanningHomeWifi
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          )
                        : Icon(Icons.wifi_find_rounded, color: accentColor),
                    onPressed:
                        _isScanningHomeWifi ? null : _openHomeWifiPicker,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passController,
                obscureText: _obscureWifiPass,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                decoration: zenGlassInputDecoration(
                  context,
                  labelText: context.tr('wifi_pass'),
                  hintText: context.tr('wifi_pass_hint'),
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureWifiPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: mutedColor,
                    ),
                    onPressed: () =>
                        setState(() => _obscureWifiPass = !_obscureWifiPass),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Admin Password Card
        ZenGlassCard(
          blurSigma: 16,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: zen.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(Icons.admin_panel_settings_outlined,
                        color: accentColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('wifi_admin_pass_section'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _adminPassController,
                obscureText: _obscureAdminPass,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                decoration: zenGlassInputDecoration(
                  context,
                  labelText: context.tr('admin_pass_opt'),
                  hintText: context.tr('admin_pass_hint'),
                  prefixIcon: Icons.vpn_key_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureAdminPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: mutedColor,
                    ),
                    onPressed: () =>
                        setState(() => _obscureAdminPass = !_obscureAdminPass),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _confirmAdminPassController,
                obscureText: _obscureConfirmPass,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                decoration: zenGlassInputDecoration(
                  context,
                  labelText: context.tr('confirm_admin_pass'),
                  hintText: context.tr('confirm_admin_pass_hint'),
                  prefixIcon: Icons.key_outlined,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: mutedColor,
                    ),
                    onPressed: () => setState(
                        () => _obscureConfirmPass = !_obscureConfirmPass),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cấu hình MQTT nâng cao (Collapsible Glass Card)
        ZenGlassCard(
          blurSigma: 16,
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: _showAdvancedMqtt,
              onExpansionChanged: (val) =>
                  setState(() => _showAdvancedMqtt = val),
              leading: Icon(Icons.cloud_sync_outlined, color: accentColor),
              title: Text(
                context.tr('wifi_mqtt_adv_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: textColor,
                ),
              ),
              subtitle: Text(
                _mqttServerController.text.isNotEmpty
                    ? _mqttServerController.text
                    : context.tr('wifi_mqtt_default_cloud'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: mutedColor),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                  child: Column(
                    children: [
                      TextField(
                        controller: _mqttServerController,
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.w600),
                        decoration: zenGlassInputDecoration(
                          context,
                          labelText: context.tr('mqtt_server_address'),
                          hintText: context.tr('mqtt_server_hint'),
                          prefixIcon: Icons.dns_outlined,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mqttUserController,
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.w600),
                        decoration: zenGlassInputDecoration(
                          context,
                          labelText: context.tr('mqtt_user'),
                          hintText: context.tr('mqtt_user_hint'),
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _mqttPassController,
                        obscureText: true,
                        style: TextStyle(
                            color: textColor, fontWeight: FontWeight.w600),
                        decoration: zenGlassInputDecoration(
                          context,
                          labelText: context.tr('mqtt_pass'),
                          hintText: context.tr('mqtt_pass_hint'),
                          prefixIcon: Icons.lock_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 26),

        Row(
          children: [
            Expanded(
              child: ZenGlassButton(
                label: context.tr('wifi_btn_back'),
                isPrimary: false,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                onPressed: () {
                  ref.read(wifiSetupWizardProvider.notifier).setStep(0);
                  setState(() => _currentStep = 0);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ZenGlassButton(
                label: context.tr('wifi_btn_start_pairing'),
                icon: Icons.flash_on_rounded,
                accentColor:
                    _detectedEspMac != null ? AppColors.emeraldGlow : null,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                onPressed: _validateAndStartPairing,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- STEP 2: Đang ghép nối & nạp cấu hình ---
  Widget _buildStep2Pairing(bool isDark) {
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentColor = isDark ? zen.primaryAccent : zen.primary;

    final remainingSecs = ref.watch(
        wifiSetupWizardProvider.select((s) => s.remainingTimeoutSeconds));
    final mins = remainingSecs ~/ 60;
    final secs = remainingSecs % 60;
    final timeFormatted =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return ZenGlassCard(
      blurSigma: 18,
      isActive: true,
      glowColor: _pairingFailed ? AppColors.roseGlow : zen.primary,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Column(
        children: [
          if (!_pairingFailed) ...[
            ZenLiquidGlass(
              blurSigma: 0,
              width: 92,
              height: 92,
              borderRadius: 46,
              glowColor: zen.primary,
              alignment: Alignment.center,
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              '${(_pairingProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: accentColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _pairingProgress,
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.10)
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _pairingMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ZenGlassPill(
              blurSigma: 0,
              isSelected: true,
              glowColor: zen.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    context
                        .tr('wifi_time_remaining')
                        .replaceAll('{time}', timeFormatted),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ZenLiquidGlass(
              blurSigma: 0,
              width: 84,
              height: 84,
              borderRadius: 42,
              glowColor: AppColors.roseGlow,
              surfaceColor: AppColors.roseGlow.withOpacity(0.14),
              alignment: Alignment.center,
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.roseGlow, size: 46),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('wifi_pairing_failed_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.roseGlow,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _pairingErrorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: mutedColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('wifi_btn_change_wifi_pass'),
                    isPrimary: false,
                    onPressed: _isCheckingEsp
                        ? null
                        : _proceedToStep1WithVerification,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('wifi_btn_retry'),
                    accentColor:
                        _detectedEspMac != null ? AppColors.emeraldGlow : null,
                    onPressed: _validateAndStartPairing,
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
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return ZenGlassCard(
      blurSigma: 18,
      isActive: true,
      glowColor: AppColors.emeraldGlow,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      child: Column(
        children: [
          ZenLiquidGlass(
            blurSigma: 0,
            width: 92,
            height: 92,
            borderRadius: 46,
            glowColor: AppColors.emeraldGlow,
            surfaceColor: AppColors.emeraldGlow.withOpacity(0.16),
            alignment: Alignment.center,
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.emeraldGlow, size: 54),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('wifi_pairing_success_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.emeraldGlow,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('wifi_pairing_success_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: mutedColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          if (_detectedEspMac != null)
            ZenGlassPill(
              blurSigma: 0,
              isSelected: true,
              glowColor: AppColors.emeraldGlow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.memory_rounded,
                      size: 17, color: AppColors.emeraldGlow),
                  const SizedBox(width: 8),
                  Text(
                    'MAC: $_detectedEspMac',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: AppColors.emeraldGlow,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ZenGlassButton(
              label: context.tr('wifi_btn_device_mapping'),
              icon: Icons.dashboard_customize_rounded,
              accentColor: AppColors.emeraldGlow,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DeviceMappingScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ZenGlassButton(
              label: context.tr('wifi_btn_return_home'),
              isPrimary: false,
              onPressed: () => Navigator.pop(context),
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
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return ZenGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      blurSigma: 14,
      isActive: true,
      glowColor: themeColor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.32),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
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
                        color: mutedColor,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        home.homeName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
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
                    fontWeight: FontWeight.w600,
                    color: themeColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, size: 17, color: themeColor),
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
                MaterialPageRoute(
                    builder: (context) => const DeviceMappingScreen()),
              );
            }
          });
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return PopScope(
      canPop: _currentStep != 2,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldCancel = await showZenGlassDialog<bool>(
          context: context,
          accentColor: AppColors.roseGlow,
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amberGlow.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.amberGlow.withOpacity(0.32)),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.amberGlow, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('wifi_cancel_pairing_title'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('wifi_cancel_pairing_desc'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ZenGlassButton(
                      label: context.tr('btn_cancel'),
                      isPrimary: false,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ZenGlassButton(
                      label: context.tr('btn_understood'),
                      isDanger: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        if (shouldCancel == true && context.mounted) {
          await ref
              .read(wifiSetupWizardProvider.notifier)
              .cancelSetupWorkflow();
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: ZenGlassScaffold(
        appBar: ZenGlassAppBar(
          centerTitle: true,
          titleText: context.tr('wifi_setup_title'),
          onBack: () => Navigator.maybePop(context),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              _buildTargetHomeBanner(
                isDark,
                widget.targetHome ??
                    ref.watch(homeConfigProvider).activeConfig,
              ),
              _buildStepperHeader(isDark),
              const SizedBox(height: 22),
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
