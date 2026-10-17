import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zalopay_status_dialog.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/setup/logic/wifi_provisioning_service.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/core/utils/helpers.dart';

/// Màn hình Cấu hình lại Wi-Fi kết nối và MQTT Broker cho Hub ESP32
/// Yêu cầu mật khẩu quản trị trước khi truy cập.
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
  bool _isScanningWifi = false;

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
    setState(() => _isScanningWifi = true);
    HapticHelper.light();

    try {
      final results = await WifiProvisioningService.scanNearbyWifi(espOnly: false);
      if (!mounted) return;
      setState(() => _isScanningWifi = false);

      final homeAps = results.where((ap) {
        final s = ap.ssid.toLowerCase();
        return !s.startsWith('zenhome') && !s.contains('setup') && ap.ssid.isNotEmpty;
      }).toList();

      final uniqueMap = <String, WiFiAccessPoint>{};
      for (final ap in homeAps) {
        if (!uniqueMap.containsKey(ap.ssid) || ap.level > uniqueMap[ap.ssid]!.level) {
          uniqueMap[ap.ssid] = ap;
        }
      }
      final uniqueList = uniqueMap.values.toList();

      if (uniqueList.isEmpty) {
        showFloatingToast(context, context.tr('info'), 'Không tìm thấy mạng Wi-Fi nào khả dụng');
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.65,
              ),
              padding: const EdgeInsets.all(22),
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
                            '${WifiProvisioningService.getSignalQuality(ap.level)} (${ap.level} dBm)',
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
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningWifi = false);
        showFloatingToast(context, context.tr('error'), 'Lỗi quét Wi-Fi: $e', isError: true);
      }
    }
  }

  Future<void> _handleApplyConfig() async {
    if (!_formKey.currentState!.validate()) {
      HapticHelper.warning();
      return;
    }

    final newSsid = _ssidController.text.trim();
    final newWifiPass = _wifiPassController.text.trim();
    final newServer = _mqttServerController.text.trim();
    final newUser = _mqttUserController.text.trim();
    final newPass = _mqttPassController.text.trim();
    final newAdminPass = _adminPassController.text.trim();

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
      cautionDetails: 'Wi-Fi mới: $newSsid\nMQTT Broker: $newServer\nMAC Hub: ${activeConfig.macAddress}',
      confirmText: isEspOnline ? 'Bắn cấu hình OTA ngay' : 'Lưu cấu hình Cloud',
      cancelText: 'Xem lại',
      isDanger: false,
    );
    if (!confirm) return;
    if (!mounted) return;

    LoadingOverlay.show(context);

    try {
      // 1. Nếu Hub Online qua MQTT: Bắn gói JSON OTA tới topic ${mqttPrefix}/system/config
      if (isEspOnline) {
        final payload = jsonEncode({
          'wifi_ssid': newSsid,
          'wifi_pass': newWifiPass,
          'mqtt_server': newServer,
          if (newUser.isNotEmpty) 'mqtt_user': newUser,
          if (newPass.isNotEmpty) 'mqtt_pass': newPass,
          'mqtt_prefix': activeConfig.mqttPrefix,
          'admin_pass': newAdminPass,
        });

        ref.read(mqttRepositoryProvider).publishCmd(
          '${activeConfig.mqttPrefix}/system/config',
          payload,
        );

        // Đợi 800ms để gói tin gửi trọn vẹn qua MQTT TLS
        await Future.delayed(const Duration(milliseconds: 800));
      }

      // 2. Cập nhật cấu hình trên Local Storage của App
      final oldServer = activeConfig.mqttServer;
      final oldUser = activeConfig.mqttUser;
      final oldPass = activeConfig.mqttPass;

      activeConfig.mqttServer = newServer;
      activeConfig.mqttUser = newUser;
      activeConfig.mqttPass = newPass;
      activeConfig.adminPass = newAdminPass;

      await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

      // 3. Cập nhật trên Cloud Firestore nếu đã đăng nhập
      if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
            'mqttServer': newServer,
            'mqttUser': newUser,
            'mqttPass': newPass,
            'adminPass': newAdminPass,
            'lastWifiSsid': newSsid,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Lỗi cập nhật Firestore khi reconfig: $e');
        }
      }

      // 4. Nếu thông số Broker MQTT thay đổi, tự động reconnect client của App
      final mqttChanged = oldServer != newServer || oldUser != newUser || oldPass != newPass;
      if (mqttChanged) {
        final mqttRepo = ref.read(mqttRepositoryProvider);
        mqttRepo.disconnect();
        mqttRepo.connect(
          userId: activeConfig.userId,
          mqttServer: newServer,
          mqttPrefix: activeConfig.mqttPrefix,
          dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
          mqttUser: newUser,
          mqttPass: newPass,
        );
      }

      LoadingOverlay.hide();

      if (!mounted) return;

      // 5. Hiển thị thông báo ZaloPay hoàn tất
      await showZaloPaySuccessDialog(
        context,
        title: 'Cập nhật cấu hình thành công',
        message: isEspOnline
            ? 'Đã gửi cấu hình Wi-Fi & MQTT mới sang Hub ESP32 qua mạng OTA thành công! Bo mạch đang khởi động lại và kết nối vào mạng mới.'
            : 'Đã lưu cấu hình mới lên tài khoản Cloud. Do Hub đang offline, bạn có thể nạp trực tiếp qua cổng AP hoặc chờ thiết bị vào mạng.',
        details: {
          'Tên Wi-Fi mới': newSsid,
          'MQTT Server': newServer,
          'Mã MAC': activeConfig.macAddress,
          'Phương thức': isEspOnline ? 'Bắn lệnh Cloud OTA (Thành công)' : 'Đã lưu trên Cloud (Hub Offline)',
          'Thời gian': DateTime.now().toLocal().toString().substring(0, 19),
        },
        buttonText: 'Hoàn tất',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showZaloPayWarningDialog(
          context,
          title: 'Lỗi áp dụng cấu hình',
          message: 'Không thể cập nhật cấu hình: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isEspOnline = ref.watch(mqttRepositoryProvider).isEspOnline;

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
                                  'MAC: ${activeConfig.macAddress}',
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
                            icon: _isScanningWifi
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
                                _mqttUserController.text = 'DTC_ZenHome';
                                _mqttPassController.text = 'DTC_ZenHome2103';
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

                      // Tiền tố Topic Prefix
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Topic Prefix: ${activeConfig.mqttPrefix}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
