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
import 'package:zenhome_app/core/utils/constants.dart'; // Chứa themeNotifier, langNotifier, tr()
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/admin/ui/admin_login_screen.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';
import 'package:zenhome_app/features/settings/ui/member_screen.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/widgets/user_avatar.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';

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
                color: const Color(0xFF2A3A7C),
                onRefresh: () async {
                  final activeConfig = ref.read(homeConfigProvider).activeConfig;
                  ref.read(mqttRepositoryProvider).disconnect();
                  await Future.delayed(const Duration(milliseconds: 500));
                  ref.read(mqttRepositoryProvider).connect(
                    userId: activeConfig.userId,
                    mqttServer: activeConfig.mqttServer,
                    mqttPrefix: activeConfig.mqttPrefix,
                    dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
                    mqttUser: activeConfig.mqttUser,
                    mqttPass: activeConfig.mqttPass,
                  );
                  await Future.delayed(const Duration(seconds: 1));
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.group_add, color: Colors.orange),
                                ),
                                title: Text(context.tr('family_members'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MemberScreen())),
                              ),
                              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
                            ],
                            
                            // --- NÚT CHỌN THEME 3 NẤC ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), shape: BoxShape.circle),
                                child: Icon(
                                  currentThemeMode == ThemeMode.light ? Icons.light_mode : (currentThemeMode == ThemeMode.dark ? Icons.dark_mode : Icons.brightness_auto), 
                                  color: Colors.purple
                                ),
                              ),
                              title: Text(context.tr('theme_mode'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              trailing: ToggleButtons(
                                borderRadius: BorderRadius.circular(10),
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
                                  Tooltip(message: 'Light', child: Icon(Icons.light_mode, size: 20)),
                                  Tooltip(message: 'Auto', child: Icon(Icons.brightness_auto, size: 20)),
                                  Tooltip(message: 'Dark', child: Icon(Icons.dark_mode, size: 20)),
                                ],
                              ),
                            ),
                            
                            Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
                            
                            // --- NÚT ĐỔI NGÔN NGỮ ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.language, color: Colors.blue),
                              ),
                              title: Text(context.tr('language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              trailing: ToggleButtons(
                                borderRadius: BorderRadius.circular(10),
                                constraints: const BoxConstraints(minHeight: 35, minWidth: 40),
                                isSelected: [!isEng, isEng],
                                fillColor: const Color(0xFF2A3A7C).withOpacity(0.1),
                                selectedColor: const Color(0xFF2A3A7C),
                                color: isDark ? Colors.white54 : Colors.black54,
                                onPressed: (index) async {
                                  String newLang = index == 0 ? 'vi' : 'en';
                                  String oldLang = index == 0 ? 'en' : 'vi';
                                  ref.read(localeNotifierProvider.notifier).setLocale(newLang);
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('app_lang', newLang);
                                  
                                  if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
                                    // FCM Routing is now token-based. No need to update topics on language change.
                                    // The backend will use the language stored in Firestore user document.
                                  }
                                  
                                  try {
                                    if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
                                      await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set(
                                        {'language': newLang},
                                        SetOptions(merge: true),
                                      );
                                    }
                                  } catch (e) {
                                    print('Lỗi cập nhật ngôn ngữ lên Firebase: $e');
                                  }
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty) 
                                           ? Colors.grey.withOpacity(0.1) 
                                           : Colors.green.withOpacity(0.1), 
                                    shape: BoxShape.circle
                                  ),
                                  child: Icon(Icons.wifi_find, 
                                    color: (activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty) 
                                           ? Colors.grey 
                                           : Colors.green
                                  ),
                                ),
                                title: Text(context.tr('setup_wifi'), 
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w500,
                                    color: (activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty) ? Colors.grey : null
                                  )
                                ),
                                trailing: (activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty)
                                    ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                                    : const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  if (activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty) {
                                    showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_esp32_already_linked') ?? 'Thiết bị ESP32 đã được liên kết với nhà này. Bạn không thể thiết lập lại.', isError: true);
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WifiSetupScreen()));
                                  }
                                },
                              ),
                              Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, indent: 60),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                                  child: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                                ),
                                title: Text(context.tr('tech_area'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.exit_to_app, color: Colors.red),
                            ),
                            title: Text(context.tr('btn_leave_home') ?? 'Rời khỏi nhà này', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                            onTap: () => _handleLeaveHome(context, ref, activeConfig.ownerEmail, activeConfig.userId),
                          ),
                        ),
                      ),
                    ).animate().slideX(begin: 0.1, end: 0),
                  ],
                  
                  const SizedBox(height: 40),
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
                  const SizedBox(height: 20),
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