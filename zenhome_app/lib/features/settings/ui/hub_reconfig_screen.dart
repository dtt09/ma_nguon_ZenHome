import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/masking_helper.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/zen_page_route.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/widgets/zenhome_luxury_dialog.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/settings/logic/hub_reconfig_controller.dart';
import 'package:zenhome_app/features/settings/ui/wifi_picker_bottom_sheet.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';

/// Màn hình Cấu hình lại Wi-Fi kết nối và MQTT Broker cho Hub ESP32
class HubReconfigScreen extends ConsumerStatefulWidget {
  const HubReconfigScreen({super.key});

  @override
  ConsumerState<HubReconfigScreen> createState() => _HubReconfigScreenState();
}

class _HubReconfigScreenState extends ConsumerState<HubReconfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _ssidController;
  late TextEditingController _wifiPassController;
  late TextEditingController _mqttServerController;
  late TextEditingController _mqttUserController;
  late TextEditingController _mqttPassController;
  late TextEditingController _adminPassController;

  bool _obscureWifiPass = true;
  bool _obscureMqttPass = true;
  bool _obscureAdminPass = true;

  @override
  void initState() {
    super.initState();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    _ssidController = TextEditingController();
    _wifiPassController = TextEditingController();
    _mqttServerController = TextEditingController(text: activeConfig.mqttServer);
    _mqttUserController =
        TextEditingController(text: activeConfig.mqttUser ?? '');
    _mqttPassController =
        TextEditingController(text: activeConfig.mqttPass ?? '');
    _adminPassController = TextEditingController(
      text: activeConfig.adminPass.isNotEmpty ? activeConfig.adminPass : 'admin',
    );
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _wifiPassController.dispose();
    _mqttServerController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _adminPassController.dispose();
    super.dispose();
  }

  Future<void> _openWifiPicker() async {
    HapticHelper.light();
    final list = await ref.read(hubReconfigProvider.notifier).scanWifi();
    if (!mounted) return;

    if (list.isEmpty) {
      showFloatingToast(
        context,
        context.tr('info'),
        context.tr('hub_no_wifi_found'),
      );
      return;
    }

    WifiPickerBottomSheet.show(
      context,
      wifiList: list,
      onWifiSelected: (ssid) => _ssidController.text = ssid,
    );
  }

  Map<String, String>? _localizeDetails(
    BuildContext context,
    Map<String, String>? raw,
  ) {
    if (raw == null) return null;
    final localized = <String, String>{};
    for (final entry in raw.entries) {
      String key = entry.key;
      if (key == 'Tên Wi-Fi mới') {
        key = context.tr('detail_new_wifi');
      } else if (key == 'Mã MAC') {
        key = context.tr('detail_mac_label');
      } else if (key == 'Phương thức') {
        key = context.tr('detail_method');
      } else if (key == 'Thời gian') {
        key = context.tr('detail_time_label');
      }

      String val = entry.value;
      if (val == 'Đã lưu trên Cloud (Hub Offline)') {
        val = context.tr('hub_reconfig_method_cloud');
      } else if (val == 'Bắn lệnh Cloud OTA (Thành công)') {
        val = context.tr('hub_reconfig_method_ota');
      } else if (val == 'Gửi trực tiếp qua LAN/BLE Zero-Touch (Thành công)') {
        val = context.tr('hub_reconfig_method_local');
      }
      localized[key] = val;
    }
    return localized;
  }

  Future<void> _handleApplyConfig() async {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.warning();
      return;
    }

    final newSsid = _ssidController.text.trim();
    if (newSsid.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('hub_err_empty_ssid'),
        isError: true,
      );
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final isEspOnline = ref.read(mqttRepositoryProvider).isEspOnline;
    HapticHelper.medium();

    final confirm = await showCautionConfirmDialog(
      context,
      title: context.tr('hub_reconfig_confirm_title'),
      warningText: context.tr('hub_reconfig_confirm_desc'),
      cautionDetails: context.l10n.hub_reconfig_summary(
        newSsid,
        _mqttServerController.text.trim(),
        MaskingHelper.maskMac(activeConfig.macAddress),
      ),
      confirmText: isEspOnline
          ? context.tr('hub_btn_push_ota_now')
          : context.tr('hub_btn_save_cloud'),
      cancelText: context.tr('btn_review'),
      isDanger: false,
    );
    if (!confirm || !mounted) return;

    LoadingOverlay.show(context);

    final result = await ref.read(hubReconfigProvider.notifier).applyConfig(
          newSsid: newSsid,
          newWifiPass: _wifiPassController.text.trim(),
          newServer: _mqttServerController.text.trim(),
          newUser: _mqttUserController.text.trim(),
          newPass: _mqttPassController.text.trim(),
          newAdminPass: _adminPassController.text.trim(),
        );

    LoadingOverlay.hide();
    if (!mounted) return;

    if (result.success) {
      await showZaloPaySuccessDialog(
        context,
        title: context.tr('hub_reconfig_success_title'),
        message: result.isEspOnline
            ? context.tr('hub_reconfig_ota_success_desc')
            : context.tr('hub_reconfig_cloud_success_desc'),
        details: _localizeDetails(context, result.details),
        buttonText: context.tr('btn_done'),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      showZaloPayWarningDialog(
        context,
        title: context.tr('hub_reconfig_err_title'),
        message: result.errorMessage ?? context.tr('hub_reconfig_err_desc'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isEspOnline = ref.watch(mqttRepositoryProvider).isEspOnline;
    final isScanningWifi = ref.watch(hubReconfigProvider).isScanningWifi;

    final Color statusColor = isEspOnline ? zen.success : zen.warning;
    final String currentBroker = _mqttServerController.text.trim();
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        titleText: context.tr('hub_reconfig_title'),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: ZenGlassCard.lightweight(
                    borderRadius: 24,
                    isActive: true,
                    glowColor: statusColor,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor.withValues(alpha: 0.14),
                              ),
                              child: Icon(
                                isEspOnline
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                color: statusColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          isEspOnline
                                              ? context.tr('hub_reconfig_online')
                                              : context
                                                  .tr('hub_reconfig_offline'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w800,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'MAC: ${MaskingHelper.maskMac(activeConfig.macAddress)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ZenLiquidGlass.lightweight(
                          borderRadius: 14,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          surfaceColor: statusColor.withValues(
                            alpha: isDark ? 0.12 : 0.08,
                          ),
                          glowColor: statusColor,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: statusColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isEspOnline
                                      ? context.tr('hub_reconfig_online_desc')
                                      : context.tr('hub_reconfig_offline_desc'),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _buildSectionHeader(
                  title: context.tr('hub_wifi_section'),
                  icon: Icons.wifi_rounded,
                  isDark: isDark,
                  primaryColor: isDark ? zen.primaryAccent : zen.primary,
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  child: ZenGlassCard.lightweight(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('hub_wifi_ssid_label'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _ssidController,
                          decoration: zenGlassInputDecoration(
                            context,
                            hintText: context.tr('hub_wifi_ssid_hint'),
                            prefixIcon: Icons.wifi_rounded,
                            suffixIcon: IconButton(
                              icon: isScanningWifi
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isDark
                                            ? zen.primaryAccent
                                            : zen.primary,
                                      ),
                                    )
                                  : Icon(
                                      Icons.wifi_find_rounded,
                                      color: isDark
                                          ? zen.primaryAccent
                                          : zen.primary,
                                    ),
                              tooltip: context.tr('hub_scan_wifi_tooltip'),
                              onPressed: _openWifiPicker,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('wifi_pass'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _wifiPassController,
                          obscureText: _obscureWifiPass,
                          decoration: zenGlassInputDecoration(
                            context,
                            hintText: context.tr('wifi_pass_hint'),
                            prefixIcon: Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureWifiPass
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureWifiPass = !_obscureWifiPass,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _buildSectionHeader(
                  title: context.tr('hub_mqtt_section'),
                  icon: Icons.hub_rounded,
                  isDark: isDark,
                  primaryColor: isDark ? zen.primaryAccent : zen.primary,
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  child: ZenGlassCard.lightweight(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('hub_mqtt_host_label'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _mqttServerController,
                          onChanged: (_) => setState(() {}),
                          decoration: zenGlassInputDecoration(
                            context,
                            hintText: context.tr('mqtt_server_hint'),
                            prefixIcon: Icons.dns_rounded,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return context.tr('hub_err_empty_mqtt');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildPresetChip(
                              context: context,
                              label: 'HiveMQ TLS',
                              isSelected: currentBroker ==
                                  'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud',
                              onTap: () {
                                HapticHelper.light();
                                setState(() {
                                  _mqttServerController.text =
                                      'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud';
                                });
                              },
                            ),
                            _buildPresetChip(
                              context: context,
                              label: 'EMQX Public',
                              isSelected: currentBroker == 'broker.emqx.io',
                              onTap: () {
                                HapticHelper.light();
                                setState(() {
                                  _mqttServerController.text =
                                      'broker.emqx.io';
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('mqtt_user'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _mqttUserController,
                          decoration: zenGlassInputDecoration(
                            context,
                            hintText: context.tr('mqtt_user_hint'),
                            prefixIcon: Icons.person_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.tr('mqtt_pass'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _mqttPassController,
                          obscureText: _obscureMqttPass,
                          decoration: zenGlassInputDecoration(
                            context,
                            hintText: context.tr('mqtt_pass_hint'),
                            prefixIcon: Icons.key_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureMqttPass
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureMqttPass = !_obscureMqttPass,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ZenLiquidGlass.lightweight(
                          borderRadius: 14,
                          padding: const EdgeInsets.all(12),
                          surfaceColor: zen.primary.withValues(
                            alpha: isDark ? 0.12 : 0.07,
                          ),
                          glowColor: zen.primary,
                          child: Row(
                            children: [
                              Icon(
                                Icons.security_rounded,
                                size: 19,
                                color: isDark ? zen.primaryAccent : zen.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('hub_comm_channel_title'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.tr('hub_comm_channel_desc'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: mutedColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _buildSectionHeader(
                  title: context.tr('hub_admin_security_section'),
                  icon: Icons.shield_rounded,
                  isDark: isDark,
                  primaryColor: isDark ? zen.primaryAccent : zen.primary,
                ),
                const SizedBox(height: 10),
                RepaintBoundary(
                  child: ZenGlassCard.lightweight(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.tr('hub_admin_pass_desc'),
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _adminPassController,
                          obscureText: _obscureAdminPass,
                          decoration: zenGlassInputDecoration(
                            context,
                            hintText: context.tr('admin_pass_hint'),
                            prefixIcon: Icons.admin_panel_settings_outlined,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureAdminPass
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureAdminPass = !_obscureAdminPass,
                              ),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return context.tr('hub_err_empty_admin_pass');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        ZenGlassButton.lightweight(
                          label: isEspOnline
                              ? context.tr('hub_btn_apply_ota')
                              : context.tr('hub_btn_save_cloud'),
                          icon: Icons.send_rounded,
                          isPrimary: true,
                          maxLines: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 15,
                          ),
                          onPressed: _handleApplyConfig,
                        ),
                        const SizedBox(height: 10),
                        ZenGlassButton.lightweight(
                          label: context.tr('hub_btn_softap'),
                          icon: Icons.wifi_tethering_rounded,
                          isPrimary: false,
                          maxLines: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              ZenPageRoute(
                                builder: (context) => const WifiSetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Row(
      children: [
        ZenLiquidGlass.lightweight(
          width: 34,
          height: 34,
          borderRadius: 11,
          alignment: Alignment.center,
          surfaceColor: primaryColor.withValues(alpha: 0.14),
          glowColor: primaryColor,
          child: Icon(icon, size: 18, color: primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color activeColor = isDark ? zen.primaryAccent : zen.primary;

    return ZenGlassPill.lightweight(
      isSelected: isSelected,
      glowColor: zen.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 15,
            color: isSelected
                ? activeColor
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? activeColor
                  : (isDark ? AppColors.darkText : AppColors.lightText),
            ),
          ),
        ],
      ),
    );
  }
}
