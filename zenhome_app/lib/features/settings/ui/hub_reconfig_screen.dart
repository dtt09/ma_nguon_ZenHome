import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/widgets/zenhome_luxury_dialog.dart';
import 'package:zenhome_app/core/utils/masking_helper.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/settings/logic/hub_reconfig_controller.dart';
import 'package:zenhome_app/features/settings/ui/wifi_picker_bottom_sheet.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';

/// Màn hình Cấu hình lại Wi-Fi kết nối và MQTT Broker cho Hub ESP32
/// Đã tách biệt Tầng Giao Diện (UI) và Tầng Nghiệp Vụ (HubReconfigController).
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
    _mqttUserController = TextEditingController(text: activeConfig.mqttUser ?? '');
    _mqttPassController = TextEditingController(text: activeConfig.mqttPass ?? '');
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
      showFloatingToast(context, context.tr('info'), 'Không tìm thấy mạng Wi-Fi nào khả dụng');
      return;
    }

    WifiPickerBottomSheet.show(
      context,
      wifiList: list,
      onWifiSelected: (ssid) => _ssidController.text = ssid,
    );
  }

  Future<void> _handleApplyConfig() async {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.warning();
      return;
    }

    final newSsid = _ssidController.text.trim();
    if (newSsid.isEmpty) {
      showFloatingToast(context, context.tr('error'), 'Vui lòng nhập hoặc chọn Tên Wi-Fi (SSID)', isError: true);
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final isEspOnline = ref.read(mqttRepositoryProvider).isEspOnline;
    HapticHelper.medium();

    // Xác nhận trước khi áp dụng
    final confirm = await showCautionConfirmDialog(
      context,
      title: 'Xác nhận đổi Wi-Fi & MQTT',
      warningText: 'Hub ESP32 sẽ lưu cấu hình mới và tự động khởi động lại để kết nối vào mạng Wi-Fi và Broker MQTT mới.',
      cautionDetails: 'Wi-Fi mới: $newSsid\nMQTT Broker: ${_mqttServerController.text.trim()}\nMAC Hub: ${MaskingHelper.maskMac(activeConfig.macAddress)}',
      confirmText: isEspOnline ? 'Bắn cấu hình OTA ngay' : 'Lưu cấu hình Cloud',
      cancelText: 'Xem lại',
      isDanger: false,
    );
    if (!confirm || !mounted) return;

    LoadingOverlay.show(context);

    // Kích hoạt logic nghiệp vụ qua Controller
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
        title: 'Cập nhật cấu hình thành công',
        message: result.isEspOnline
            ? 'Đã gửi cấu hình Wi-Fi & MQTT mới sang Hub ESP32 qua mạng OTA thành công! Bo mạch đang khởi động lại và kết nối vào mạng mới.'
            : 'Đã lưu cấu hình mới lên tài khoản Cloud. Do Hub đang offline, bạn có thể nạp trực tiếp qua cổng AP hoặc chờ thiết bị vào mạng.',
        details: result.details,
        buttonText: 'Hoàn tất',
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      showZaloPayWarningDialog(
        context,
        title: 'Lỗi áp dụng cấu hình',
        message: result.errorMessage ?? 'Không thể cập nhật cấu hình',
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

    final Color statusColor = isEspOnline ? AppColors.emeraldGlow : AppColors.amberGlow;
    final String currentBroker = _mqttServerController.text.trim();

    return ZenGlassScaffold(
      appBar: const ZenGlassAppBar(
        titleText: 'Cấu hình Wi-Fi & MQTT Hub',
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
                // --- BANNER TRẠNG THÁI HUB (CONNECTION MODE GLASS CARD) ---
                ZenGlassCard(
                  blurSigma: 16,
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
                              color: statusColor.withOpacity(0.16),
                              boxShadow: [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              isEspOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
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
                                        isEspOnline ? 'Hub ESP32 Trực tuyến' : 'Hub ESP32 Ngoại tuyến',
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
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.6),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'MAC: ${MaskingHelper.maskMac(activeConfig.macAddress)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        surfaceColor: statusColor.withOpacity(isDark ? 0.12 : 0.08),
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
                                    ? 'Hub đang online MQTT. Bạn có thể gửi cấu hình Wi-Fi và Broker mới trực tiếp qua OTA mà không cần cắm lại thiết bị!'
                                    : 'Hub đang offline. Bạn có thể lưu cấu hình mới lên Cloud hoặc bấm nút bên dưới để cấu hình trực tiếp qua Wi-Fi AP (192.168.4.1).',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // --- CARD 1: CẤU HÌNH WI-FI ---
                _buildSectionHeader(
                  title: 'Mạng Wi-Fi Kết Nối',
                  icon: Icons.wifi_rounded,
                  isDark: isDark,
                  primaryColor: isDark ? zen.primaryAccent : zen.primary,
                ),
                const SizedBox(height: 10),
                ZenGlassCard(
                  blurSigma: 16,
                  borderRadius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tên Wi-Fi (SSID)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ssidController,
                        decoration: zenGlassInputDecoration(
                          context,
                          hintText: 'Nhập tên Wi-Fi 2.4GHz',
                          prefixIcon: Icons.wifi_rounded,
                          suffixIcon: IconButton(
                            icon: isScanningWifi
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: isDark ? zen.primaryAccent : zen.primary,
                                    ),
                                  )
                                : Icon(
                                    Icons.wifi_find_rounded,
                                    color: isDark ? zen.primaryAccent : zen.primary,
                                  ),
                            tooltip: 'Quét Wi-Fi xung quanh',
                            onPressed: _openWifiPicker,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Mật khẩu Wi-Fi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _wifiPassController,
                        obscureText: _obscureWifiPass,
                        decoration: zenGlassInputDecoration(
                          context,
                          hintText: 'Mật khẩu Wi-Fi (để trống nếu không có)',
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureWifiPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureWifiPass = !_obscureWifiPass),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // --- CARD 2: CẤU HÌNH MQTT BROKER ---
                _buildSectionHeader(
                  title: 'Cấu hình MQTT Broker',
                  icon: Icons.hub_rounded,
                  isDark: isDark,
                  primaryColor: isDark ? zen.primaryAccent : zen.primary,
                ),
                const SizedBox(height: 10),
                ZenGlassCard(
                  blurSigma: 16,
                  borderRadius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Máy chủ MQTT (Server / Broker Host)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mqttServerController,
                        onChanged: (_) => setState(() {}),
                        decoration: zenGlassInputDecoration(
                          context,
                          hintText: 'e.g. e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud',
                          prefixIcon: Icons.dns_rounded,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập địa chỉ máy chủ MQTT';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Preset nhanh máy chủ (ZenGlassPill)
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
                                _mqttServerController.text = 'broker.emqx.io';
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Username & Password MQTT
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MQTT Username',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _mqttUserController,
                                  decoration: zenGlassInputDecoration(
                                    context,
                                    hintText: 'Username',
                                    prefixIcon: Icons.person_outline_rounded,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MQTT Password',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _mqttPassController,
                                  obscureText: _obscureMqttPass,
                                  decoration: zenGlassInputDecoration(
                                    context,
                                    hintText: 'Password',
                                    prefixIcon: Icons.key_rounded,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureMqttPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() => _obscureMqttPass = !_obscureMqttPass),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bảo mật kênh truyền thông (Ẩn topic MQTT kỹ thuật)
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 14,
                        padding: const EdgeInsets.all(12),
                        surfaceColor: zen.primary.withOpacity(isDark ? 0.12 : 0.07),
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
                                  const Text(
                                    'Kênh truyền thông: Bảo mật nội bộ',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Định tuyến bảo mật riêng biệt gắn liền với User ID và MAC của Hub.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
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

                const SizedBox(height: 24),

                // --- CARD 3: MẬT KHẨU QUẢN TRỊ & TÁC VỤ ĐỒNG BỘ ---
                _buildSectionHeader(
                  title: 'Bảo mật Quản trị & Đồng bộ',
                  icon: Icons.shield_rounded,
                  isDark: isDark,
                  primaryColor: isDark ? zen.primaryAccent : zen.primary,
                ),
                const SizedBox(height: 10),
                ZenGlassCard(
                  blurSigma: 16,
                  borderRadius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Mật khẩu quản trị Hub (Dùng để bảo vệ phân quyền, gán chân, hủy liên kết)',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _adminPassController,
                        obscureText: _obscureAdminPass,
                        decoration: zenGlassInputDecoration(
                          context,
                          hintText: 'Mật khẩu quản trị (Mặc định: admin)',
                          prefixIcon: Icons.admin_panel_settings_outlined,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureAdminPass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureAdminPass = !_obscureAdminPass),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng không để trống mật khẩu quản trị';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      // Nút hành động chính (ZenGlassButton)
                      ZenGlassButton(
                        label: isEspOnline
                            ? 'Lưu & Bắn Cấu hình OTA sang Hub'
                            : 'Lưu Cấu hình lên Cloud',
                        icon: Icons.send_rounded,
                        isPrimary: true,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                        onPressed: _handleApplyConfig,
                      ),
                      const SizedBox(height: 10),

                      // Nút cấu hình qua SoftAP nếu cần
                      ZenGlassButton(
                        label: 'Cấu hình qua Wi-Fi AP của Hub (192.168.4.1)',
                        icon: Icons.wifi_tethering_rounded,
                        isPrimary: false,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WifiSetupScreen()),
                          );
                        },
                      ),
                    ],
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
        ZenLiquidGlass(
          width: 34,
          height: 34,
          borderRadius: 11,
          blurSigma: 0,
          alignment: Alignment.center,
          surfaceColor: primaryColor.withOpacity(0.14),
          glowColor: primaryColor,
          child: Icon(icon, size: 18, color: primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: isDark ? AppColors.darkText : AppColors.lightText,
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

    return ZenGlassPill(
      blurSigma: 0,
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
