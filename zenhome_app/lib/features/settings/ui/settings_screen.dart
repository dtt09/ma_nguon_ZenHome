import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/admin/ui/admin_login_screen.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';
import 'package:zenhome_app/features/settings/ui/member_screen.dart';
import 'package:zenhome_app/features/settings/ui/hub_reconfig_screen.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/widgets/zalopay_status_dialog.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/admin_password_dialog.dart';
import 'package:zenhome_app/core/widgets/user_avatar.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/features/feedback/ui/bug_report_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _handleLogout(BuildContext context, WidgetRef ref) async {
    showPremiumConfirmDialog(
      context: context,
      title: context.tr('confirm_title'),
      message: context.tr('logout_confirm_desc'),
      confirmText: context.tr('btn_logout'),
      cancelText: context.tr('btn_cancel'),
      isDanger: true,
      icon: Icons.logout_rounded,
      onConfirm: () async {
        // FCM Tokens are now managed by SessionManager in Firestore.
        // We do not need to unsubscribe from topics here.
        await SessionManager.clearSession();
        
        await FirebaseAuth.instance.signOut();
        
        await ref.read(homeConfigProvider).clearAllHomes();
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('notification_history');
        
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );
        }
      },
    );
  }


  // Hàm xử lý rời khỏi nhà
  void _handleLeaveHome(BuildContext context, WidgetRef ref, String? ownerUsername, String? ownerId) {
    if (ownerUsername == null || ownerUsername.isEmpty) return;
    
    showPremiumConfirmDialog(
      context: context,
      title: context.tr('confirm_title') ?? 'Xác nhận',
      message: context.tr('msg_confirm_leave_home') ?? 'Bạn có chắc chắn muốn rời khỏi nhà này không? Bạn sẽ mất toàn quyền điều khiển.',
      confirmText: context.tr('btn_leave_home') ?? 'Rời khỏi',
      cancelText: context.tr('btn_cancel') ?? 'Hủy',
      isDanger: true,
      icon: Icons.exit_to_app,
      onConfirm: () async {
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) return;
          
          String? currentUsername;
          final userQuery = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: currentUser.uid).get();
          if (userQuery.docs.isNotEmpty) {
            currentUsername = userQuery.docs.first.id;
          }
          if (currentUsername == null) return;

          // Xóa mình khỏi danh sách của chủ nhà
          await FirebaseFirestore.instance.collection('users').doc(ownerUsername).update({
            'sharedWith': FieldValue.arrayRemove([currentUsername]),
            'automationEditors': FieldValue.arrayRemove([currentUsername]),
            'disabledMembers': FieldValue.arrayRemove([currentUsername]),
            'memberRoles.$currentUsername': FieldValue.delete(),
          });
          
          // Xóa liên kết chủ nhà ở bản thân
          await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
            'ownerUsername': FieldValue.delete(),
            'ownerEmail': FieldValue.delete()
          });

          // Hủy đăng ký FCM Topic
          try {
            await FirebaseMessaging.instance.unsubscribeFromTopic('home_$ownerId');
            await FirebaseMessaging.instance.unsubscribeFromTopic('home_${ownerId}_vi');
            await FirebaseMessaging.instance.unsubscribeFromTopic('home_${ownerId}_en');
          } catch (e) {
            debugPrint('Error unsubscribing FCM: $e');
          }

          // Xóa nhà này khỏi danh sách và quay về MainLayout
          final provider = ref.read(homeConfigProvider);
          final remainingHomes = provider.availableHomes.where((h) => h.userId != ownerId).toList();
          await provider.setAvailableHomes(remainingHomes);

          if (context.mounted) {
            showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_leave_home_success') ?? 'Đã rời khỏi nhà ảo thành công.');
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const MainLayout()),
              (Route<dynamic> route) => false,
            );
          }
        } catch (e) {
          if (context.mounted) {
            showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('error')}: $e', isError: true);
          }
        }
      },
    );
  }

  // Hàm lưu Theme vào ổ cứng
  Future<void> _setTheme(ThemeMode mode, WidgetRef ref) async {
    ref.read(themeModeNotifierProvider.notifier).setThemeMode(mode);
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) {
      await prefs.setString('app_theme', 'light');
    } else if (mode == ThemeMode.dark) {
      await prefs.setString('app_theme', 'dark');
    } else {
      await prefs.setString('app_theme', 'system');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Builder(
      
      builder: (context) { ThemeMode currentThemeMode = ref.watch(themeModeNotifierProvider);
        return Builder(
          
          builder: (context) { String currentLang = ref.watch(localeNotifierProvider).languageCode;
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            bool isEng = currentLang == 'en';
            final activeConfig = ref.watch(homeConfigProvider).activeConfig;
            
            return SafeArea(
              bottom: false,
              child: RefreshIndicator(
                color: const Color(0xFF0F766E),
                onRefresh: () async {
                  await ref.read(homeConfigProvider).syncFromFirestore();
                  final activeConfig = ref.read(homeConfigProvider).activeConfig;
                  ref.read(mqttRepositoryProvider).disconnect();
                  await Future.delayed(const Duration(milliseconds: 300));
                  ref.read(mqttRepositoryProvider).connect(
                    userId: activeConfig.userId,
                    mqttServer: activeConfig.mqttServer,
                    mqttPrefix: activeConfig.mqttPrefix,
                    dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
                    mqttUser: activeConfig.mqttUser,
                    mqttPass: activeConfig.mqttPass,
                  );
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                children: [
                  Text(context.tr('setting_title'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
                      .animate().slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 25),
                  
                  // --- GROUP 1: TÀI KHOẢN ---
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Material(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                        child: ListTile(
                          leading: const UserAvatar(radius: 25),
                          title: Text(FirebaseAuth.instance.currentUser?.displayName ?? context.tr('profile_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          subtitle: Text(getDisplayEmailOrPhone(FirebaseAuth.instance.currentUser)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())).then((_) {
                              (context as Element).markNeedsBuild();
                            });
                          },
                        ),
                      ),
                    ),
                  ).animate(delay: 100.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
                  const SizedBox(height: 25),
                  
                  // --- GROUP 2: CÀI ĐẶT CHUNG ---
                  Text(context.tr('general_settings'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500))
                      .animate(delay: 200.ms).fade(duration: 400.ms),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Material(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            if (activeConfig.role == 'owner') ...[
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.group_add_rounded, color: Colors.orange, size: 22),
                                ),
                                title: Text(context.tr('family_members'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MemberScreen())),
                              ),
                              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
                            ],
                            
                            // --- NÚT CHỌN THEME 3 NẤC ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  currentThemeMode == ThemeMode.light
                                      ? Icons.light_mode_rounded
                                      : (currentThemeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.brightness_auto_rounded), 
                                  color: Colors.purple,
                                  size: 22,
                                ),
                              ),
                              title: Text(context.tr('theme_mode'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              trailing: ToggleButtons(
                                borderRadius: BorderRadius.circular(12),
                                constraints: const BoxConstraints(minHeight: 35, minWidth: 40),
                                isSelected: [
                                  currentThemeMode == ThemeMode.light,
                                  currentThemeMode == ThemeMode.system,
                                  currentThemeMode == ThemeMode.dark,
                                ],
                                fillColor: Colors.purple.withOpacity(0.1),
                                selectedColor: Colors.purple,
                                color: isDark ? Colors.white54 : Colors.black54,
                                onPressed: (index) {
                                  if (index == 0) _setTheme(ThemeMode.light, ref);
                                  else if (index == 1) _setTheme(ThemeMode.system, ref);
                                  else _setTheme(ThemeMode.dark, ref);
                                },
                                children: const [
                                  Tooltip(message: 'Light', child: Icon(Icons.light_mode_rounded, size: 20)),
                                  Tooltip(message: 'Auto', child: Icon(Icons.brightness_auto_rounded, size: 20)),
                                  Tooltip(message: 'Dark', child: Icon(Icons.dark_mode_rounded, size: 20)),
                                ],
                              ),
                            ),
                            
                            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
                            
                            // --- NÚT ĐỔI NGÔN NGỮ ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.translate_rounded, color: Colors.blue, size: 22),
                              ),
                              title: Text(context.tr('language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              trailing: ToggleButtons(
                                borderRadius: BorderRadius.circular(12),
                                constraints: const BoxConstraints(minHeight: 35, minWidth: 40),
                                isSelected: [!isEng, isEng],
                                fillColor: const Color(0xFF0F766E).withOpacity(0.1),
                                selectedColor: const Color(0xFF0F766E),
                                color: isDark ? Colors.white54 : Colors.black54,
                                onPressed: (index) async {
                                  String newLang = index == 0 ? 'vi' : 'en';
                                  await ref.read(localeNotifierProvider.notifier).setLocale(newLang);
                                },
                                children: const [
                                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('VN', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('EN', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: 250.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
                  const SizedBox(height: 25),
                  
                  // --- GROUP 3: HỆ THỐNG ESP32 ---
                  if (activeConfig.role == 'owner') ...[
                    Text(context.tr('system_settings'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500))
                        .animate(delay: 300.ms).fade(duration: 400.ms),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Material(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.wifi_find_rounded,
                                    size: 22,
                                    color: Color(0xFF0D9488),
                                  ),
                                ),
                                title: Text(
                                  context.tr('setup_wifi'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  (activeConfig.macAddress.isNotEmpty && activeConfig.macAddress != 'unknown_mac')
                                      ? 'Đã liên kết (MAC: ${activeConfig.macAddress})'
                                      : 'Cấu hình mạng Wi-Fi và liên kết Hub',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () async {
                                  final isLinked = activeConfig.macAddress.isNotEmpty && activeConfig.macAddress != 'unknown_mac';
                                  if (isLinked) {
                                    final action = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.settings_suggest_rounded, color: Color(0xFF0D9488)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                context.tr('setup_wifi'),
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0D9488).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.2)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.memory_rounded, size: 20, color: Color(0xFF0D9488)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        'MAC: ${activeConfig.macAddress}',
                                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              const Text(
                                                'Thiết bị Hub đã được liên kết bảo mật với tài khoản. Bạn muốn cấu hình lại Wi-Fi hay hủy liên kết & Factory Reset Hub từ xa?',
                                                style: TextStyle(fontSize: 14, height: 1.45),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF0D9488),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    elevation: 1,
                                                  ),
                                                  icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                                                  onPressed: () => Navigator.pop(ctx, 'setup'),
                                                  label: const Text('Cấu hình lại Wi-Fi & MQTT', style: TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(height: 8),
                                                OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.redAccent,
                                                    side: const BorderSide(color: Colors.redAccent),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  icon: const Icon(Icons.link_off_rounded, size: 18),
                                                  onPressed: () => Navigator.pop(ctx, 'unlink'),
                                                  label: Text(
                                                    context.tr('unlink_hub_menu_title'),
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, 'cancel'),
                                                  child: Text(context.tr('cancel'), style: const TextStyle(color: Colors.grey)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (action == 'unlink') {
                                      // 1. Kiểm tra trạng thái online của ESP32
                                      final isEspOnline = ref.read(mqttRepositoryProvider).isEspOnline;
                                      if (!isEspOnline) {
                                        final forceUnlink = await showCautionConfirmDialog(
                                          context,
                                          title: 'Hub ESP32 ngoại tuyến!',
                                          warningText: context.tr('unlink_hub_offline_warning'),
                                          cautionDetails: 'Nếu thiết bị đã hỏng hoặc mất, việc hủy sẽ xóa liên kết trên tài khoản ứng dụng nhưng trên mạch ESP32 vẫn giữ cấu hình cũ cho đến khi bạn reset thủ công.',
                                          confirmText: 'Vẫn hủy liên kết (Hub offline)',
                                          cancelText: 'Kiểm tra lại',
                                          isDanger: true,
                                        );
                                        if (!forceUnlink) return;
                                      }

                                      // 2. Xác thực Mật khẩu Quản trị của Hub ESP32 (Admin Password)
                                      if (!context.mounted) return;
                                      final isAdminPassValid = await showAdminPasswordDialog(
                                        context,
                                        currentAdminPassword: activeConfig.adminPass,
                                        title: 'Mật khẩu quản trị Hub',
                                        description: 'Vui lòng nhập mật khẩu quản trị của Hub ESP32 để ủy quyền hủy liên kết và xóa sạch cấu hình từ xa.',
                                      );
                                      if (!isAdminPassValid) {
                                        if (context.mounted) {
                                          showZaloPayWarningDialog(
                                            context,
                                            title: 'Hủy thao tác bảo mật',
                                            message: 'Chưa xác thực mật khẩu quản trị. Hub ESP32 vẫn được bảo vệ an toàn.',
                                          );
                                        }
                                        return;
                                      }

                                      // 3. Xác thực danh tính người dùng (Password/Google/Phone OTP như khi xóa tài khoản)
                                      if (!context.mounted) return;
                                      final authenticated = await ReauthHelper.reauthenticate(
                                        context,
                                        reason: 'xác nhận hủy liên kết và xóa sạch cấu hình Hub ESP32 từ xa',
                                      );
                                      if (!authenticated) {
                                        if (context.mounted) {
                                          showZaloPayWarningDialog(
                                            context,
                                            title: 'Hủy thao tác bảo mật',
                                            message: 'Chưa hoàn thành xác thực danh tính. Hub ESP32 vẫn được bảo vệ nguyên vẹn.',
                                          );
                                        }
                                        return;
                                      }

                                      // 3. Bảng thông báo thận trọng cuối cùng
                                      if (!context.mounted) return;
                                      final confirmed = await showCautionConfirmDialog(
                                        context,
                                        title: context.tr('unlink_hub_confirm_title'),
                                        warningText: context.tr('unlink_hub_confirm_desc'),
                                        cautionDetails: 'MAC Hub: ${activeConfig.macAddress} • ESP32 sẽ lập tức xóa /config.json, ngắt mọi rơ-le và tự động khởi động lại vào AP Setup.',
                                        confirmText: 'Bắn tín hiệu Reset & Hủy',
                                        cancelText: 'Giữ lại liên kết',
                                        isDanger: true,
                                      );
                                      if (!confirmed) return;

                                      // 4. Bắn tín hiệu boot lại và reset ESP32 từ xa qua MQTT
                                      LoadingOverlay.show(context);
                                      try {
                                        if (isEspOnline) {
                                          ref.read(mqttRepositoryProvider).publishCmd('${activeConfig.mqttPrefix}/system/reset', '1');
                                          await Future.delayed(const Duration(milliseconds: 600));
                                        }
                                      } catch (e) {
                                        debugPrint('Lỗi publish reset mqtt: $e');
                                      }

                                      // 5. Cập nhật gỡ MAC trong Local và Firestore
                                      String previousMac = activeConfig.macAddress;
                                      activeConfig.macAddress = 'unknown_mac';
                                      await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
                                      try {
                                        if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
                                          await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
                                            'macAddress': 'unknown_mac',
                                          }, SetOptions(merge: true));
                                        }
                                      } catch (e) {
                                        debugPrint('Lỗi cập nhật Firestore macAddress: $e');
                                      }
                                      LoadingOverlay.hide();

                                      // 6. Hiển thị thông báo hoàn tất ZaloPay
                                      if (context.mounted) {
                                        await showZaloPaySuccessDialog(
                                          context,
                                          title: context.tr('unlink_hub_success_title'),
                                          message: isEspOnline
                                              ? context.tr('unlink_hub_success_desc')
                                              : 'Đã hủy liên kết Hub ESP32 khỏi tài khoản trên hệ thống Cloud thành công.',
                                          details: {
                                            'Thao tác': 'Factory Reset & Hủy Hub',
                                            'Mã MAC': previousMac,
                                            'Tín hiệu ESP32': isEspOnline ? 'Đã gửi lệnh Reset (/system/reset)' : 'Hub Offline (Đã gỡ trên Cloud)',
                                            'Thời gian': DateTime.now().toLocal().toString().substring(0, 19),
                                          },
                                          buttonText: 'Hoàn tất',
                                        );
                                      }
                                    } else if (action == 'setup') {
                                      if (!context.mounted) return;
                                      final isAdminPassValid = await showAdminPasswordDialog(
                                        context,
                                        currentAdminPassword: activeConfig.adminPass,
                                        title: 'Mật khẩu quản trị Hub',
                                        description: 'Vui lòng nhập mật khẩu quản trị của Hub ESP32 để truy cập tính năng thay đổi Wi-Fi và MQTT.',
                                      );
                                      if (!isAdminPassValid) {
                                        if (context.mounted) {
                                          showZaloPayWarningDialog(
                                            context,
                                            title: 'Hủy thao tác bảo mật',
                                            message: 'Chưa xác thực mật khẩu quản trị. Cấu hình Hub ESP32 được giữ an toàn.',
                                          );
                                        }
                                        return;
                                      }

                                      if (context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const HubReconfigScreen()),
                                        );
                                      }
                                    }
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WifiSetupScreen()));
                                  }
                                },
                              ),
                              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),

                              // --- NÚT KHỞI ĐỘNG LẠI HUB ESP32 (SYSTEM RESTART) ---
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.restart_alt_rounded, color: Colors.amber, size: 22),
                                ),
                                title: Text(context.tr('restart_hub_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                  context.tr('restart_hub_desc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () async {
                                  final isLinked = activeConfig.macAddress.isNotEmpty && activeConfig.macAddress != 'unknown_mac';
                                  if (!isLinked) {
                                    showZaloPayWarningDialog(
                                      context,
                                      title: 'Chưa liên kết Hub',
                                      message: 'Tài khoản chưa được kết nối với Hub ESP32 nào. Vui lòng thiết lập Wi-Fi cho Hub trước.',
                                    );
                                    return;
                                  }

                                  final isEspOnline = ref.read(mqttRepositoryProvider).isEspOnline;
                                  if (!isEspOnline) {
                                    showZaloPayErrorDialog(
                                      context,
                                      title: 'Hub ESP32 ngoại tuyến',
                                      message: context.tr('restart_hub_offline_err'),
                                      details: {
                                        'Mã Hub': activeConfig.macAddress,
                                        'Trạng thái': 'Ngoại tuyến (Offline)',
                                        'Khắc phục': 'Vui lòng kiểm tra nguồn điện và Wi-Fi của thiết bị.',
                                      },
                                    );
                                    return;
                                  }

                                  final confirmed = await showCautionConfirmDialog(
                                    context,
                                    title: context.tr('restart_hub_confirm_title'),
                                    warningText: context.tr('restart_hub_confirm_desc'),
                                    cautionDetails: 'MAC: ${activeConfig.macAddress} • Lệnh gửi qua giao thức bảo mật MQTT TLS.',
                                    confirmText: 'Khởi động lại ngay',
                                    cancelText: 'Hủy bỏ',
                                    isDanger: false,
                                  );

                                  if (confirmed && context.mounted) {
                                    try {
                                      ref.read(mqttRepositoryProvider).publishCmd('${activeConfig.mqttPrefix}/system/reboot', '1');
                                      await showZaloPaySuccessDialog(
                                        context,
                                        title: context.tr('restart_hub_success_title'),
                                        message: context.tr('restart_hub_success_desc'),
                                        details: {
                                          'Hành động': 'Khởi động lại Hub từ xa',
                                          'MAC Thiết bị': activeConfig.macAddress,
                                          'Kênh điều khiển': '${activeConfig.mqttPrefix}/system/reboot',
                                          'Thời gian': DateTime.now().toLocal().toString().substring(0, 19),
                                        },
                                        buttonText: 'Đã hiểu',
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        showZaloPayErrorDialog(
                                          context,
                                          title: 'Lỗi gửi lệnh',
                                          message: 'Không thể truyền lệnh khởi động lại: $e',
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),

                              // --- KHU VỰC KỸ THUẬT ---
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.redAccent, size: 22),
                                ),
                                title: Text(context.tr('tech_area'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () {
                                  if (activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty) {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const DeviceMappingScreen()));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminLoginScreen()));
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: 350.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
                  ],
                  
                  // --- GROUP 4: THÀNH VIÊN RỜI NHÀ ---
                  if (activeConfig.role != 'owner' && activeConfig.userId.isNotEmpty && activeConfig.userId != 'guest') ...[
                    Text(context.tr('leave_home_title') ?? 'QUẢN LÝ QUYỀN TRUY CẬP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500))
                        .animate(delay: 400.ms).fade(duration: 400.ms),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Material(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.exit_to_app_rounded, color: Colors.red, size: 22),
                            ),
                            title: Text(context.tr('btn_leave_home') ?? 'Rời khỏi nhà này', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
                            onTap: () => _handleLeaveHome(context, ref, activeConfig.ownerEmail, activeConfig.userId),
                          ),
                        ),
                      ),
                    ).animate().slideX(begin: 0.1, end: 0),
                  ],

                  // --- GROUP: CẬP NHẬT & PHIÊN BẢN ỨNG DỤNG ---
                  const SizedBox(height: 10),
                  Text(context.tr('app_version_title'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500))
                      .animate(delay: 420.ms).fade(duration: 400.ms),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Material(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.system_update_rounded, color: Colors.blueAccent, size: 22),
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      context.tr('check_for_updates'),
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  FutureBuilder(
                                    future: AppUpdateService.getPendingUpdateInfo(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            context.tr('has_new_version_badge'),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                              subtitle: FutureBuilder(
                                future: AppUpdateService.getPackageInfo(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    final info = snapshot.data!;
                                    return Text('ZenHome v${info.version} (Build ${info.buildNumber})', style: const TextStyle(fontSize: 12, color: Colors.grey));
                                  }
                                  return const Text('ZenHome...', style: TextStyle(fontSize: 12, color: Colors.grey));
                                },
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.refresh_rounded, size: 14, color: Colors.blueAccent),
                                    const SizedBox(width: 4),
                                    Text(context.tr('btn_check'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                                  ],
                                ),
                              ),
                              onTap: () {
                                AppUpdateService.checkAndPromptUpdate(context, isManualCheck: true);
                              },
                            ),
                            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.bug_report_rounded, color: Color(0xFFF59E0B), size: 22),
                              ),
                              title: Text(
                                context.tr('report_bug_title') ?? 'Báo cáo sự cố & Góp ý',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                context.tr('report_bug_desc') ?? 'Gửi phản hồi trực tiếp tới đội ngũ phát triển',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () => BugReportDialog.show(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: 450.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),

                  const SizedBox(height: 35),
                  // --- ĐĂNG XUẤT ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(context.tr('btn_logout'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () => _handleLogout(context, ref),
                    ),
                  ).animate(delay: 500.ms).fade(duration: 400.ms).scaleXY(begin: 0.9, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 100),
                ],
              ),
              ),
            );
          },
        );
      },
    );
  }
}
