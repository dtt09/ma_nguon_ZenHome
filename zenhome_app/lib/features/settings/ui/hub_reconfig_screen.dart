import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
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
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isEspOnline = ref.watch(mqttRepositoryProvider).isEspOnline;
    final isScanningWifi = ref.watch(hubReconfigProvider).isScanningWifi;

    final primaryColor = const Color(0xFF0F766E);
    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text(
          'Cấu hình Wi-Fi & MQTT Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- BANNER TRẠNG THÁI HUB ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isEspOnline
                          ? const Color(0xFF10B981).withOpacity(0.35)
                          : const Color(0xFFF59E0B).withOpacity(0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isEspOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.12),
                            ),
                            child: Icon(
                              isEspOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                              color: isEspOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isEspOnline ? 'Hub ESP32 Trực tuyến' : 'Hub ESP32 Ngoại tuyến',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isEspOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isEspOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'MAC: ${MaskingHelper.maskMac(activeConfig.macAddress)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: (isEspOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: isEspOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isEspOnline
                                    ? 'Hub đang online MQTT. Bạn có thể gửi cấu hình Wi-Fi và Broker mới trực tiếp qua OTA mà không cần cắm lại thiết bị!'
                                    : 'Hub đang offline. Bạn có thể lưu cấu hình mới lên Cloud hoặc bấm nút bên dưới để cấu hình trực tiếp qua Wi-Fi AP (192.168.4.1).',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- CARD 1: CẤU HÌNH WI-FI ---
                _buildSectionHeader(
                  title: 'Mạng Wi-Fi Kết Nối',
                  icon: Icons.wifi_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên Wi-Fi (SSID)
                      Text(
                        'Tên Wi-Fi (SSID)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _ssidController,
                        decoration: InputDecoration(
                          hintText: 'Nhập tên Wi-Fi 2.4GHz',
                          prefixIcon: const Icon(Icons.wifi, color: Color(0xFF0F766E), size: 20),
                          suffixIcon: IconButton(
                            icon: isScanningWifi
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                                  )
                                : const Icon(Icons.wifi_find_rounded, color: Color(0xFF0F766E)),
                            tooltip: 'Quét Wi-Fi xung quanh',
                            onPressed: _openWifiPicker,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Mật khẩu Wi-Fi
                      Text(
                        'Mật khẩu Wi-Fi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _wifiPassController,
                        obscureText: _obscureWifiPass,
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu Wi-Fi (để trống nếu không có)',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
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

                const SizedBox(height: 24),

                // --- CARD 2: CẤU HÌNH MQTT BROKER ---
                _buildSectionHeader(
                  title: 'Cấu hình MQTT Broker',
                  icon: Icons.hub_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Máy chủ MQTT (Server / Host)
                      Text(
                        'Máy chủ MQTT (Server / Broker Host)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mqttServerController,
                        decoration: InputDecoration(
                          hintText: 'e.g. e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud',
                          prefixIcon: const Icon(Icons.dns_rounded, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Vui lòng nhập địa chỉ máy chủ MQTT';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      // Preset nhanh máy chủ
                      Row(
                        children: [
                          _buildPresetChip(
                            label: 'HiveMQ TLS',
                            onTap: () {
                              setState(() {
                                _mqttServerController.text = 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud';
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildPresetChip(
                            label: 'EMQX Public',
                            onTap: () {
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
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MQTT Username',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _mqttUserController,
                                  decoration: InputDecoration(
                                    hintText: 'Username',
                                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _mqttPassController,
                                  obscureText: _obscureMqttPass,
                                  decoration: InputDecoration(
                                    hintText: 'Password',
                                    prefixIcon: const Icon(Icons.key_rounded, size: 18),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureMqttPass ? Icons.visibility_off : Icons.visibility, size: 18),
                                      onPressed: () => setState(() => _obscureMqttPass = !_obscureMqttPass),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Bảo mật kênh truyền thông (Ẩn topic MQTT kỹ thuật)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, size: 18, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kênh truyền thông: Bảo mật nội bộ',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Định tuyến bảo mật riêng biệt gắn liền với User ID và MAC của Hub.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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

                // --- CARD 3: MẬT KHẨU QUẢN TRỊ HUB ---
                _buildSectionHeader(
                  title: 'Mật khẩu Quản trị Bo mạch',
                  icon: Icons.shield_rounded,
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mật khẩu quản trị Hub (Dùng để bảo vệ phân quyền, gán chân, hủy liên kết)',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _adminPassController,
                        obscureText: _obscureAdminPass,
                        decoration: InputDecoration(
                          hintText: 'Mật khẩu quản trị (Mặc định: admin)',
                          prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureAdminPass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _obscureAdminPass = !_obscureAdminPass),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Vui lòng không để trống mật khẩu quản trị';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- NÚT HÀNH ĐỘNG CHÍNH ---
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      isEspOnline ? 'Lưu & Bắn Cấu hình OTA sang Hub' : 'Lưu Cấu hình lên Cloud',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: _handleApplyConfig,
                  ),
                ),

                const SizedBox(height: 12),

                // Nút cấu hình qua SoftAP nếu cần
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: borderColor),
                    ),
                    icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                    label: Text(
                      'Cấu hình qua Wi-Fi AP của Hub (192.168.4.1)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const WifiSetupScreen()),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 30),
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
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip({required String label, required VoidCallback onTap}) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      avatar: const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFF0F766E)),
      backgroundColor: const Color(0xFF0F766E).withOpacity(0.08),
      side: BorderSide(color: const Color(0xFF0F766E).withOpacity(0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: onTap,
    );
  }
}
