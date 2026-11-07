import 'dart:convert';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/core/widgets/animations/telegram_theme_transition.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/admin/ui/admin_login_screen.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';
import 'package:zenhome_app/features/settings/ui/member_screen.dart';
import 'package:zenhome_app/features/settings/ui/hub_reconfig_screen.dart';
import 'package:zenhome_app/features/settings/ui/esp_ota_dialog.dart';
import 'package:zenhome_app/features/settings/ui/version_changelog_screen.dart';
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
import 'package:zenhome_app/core/services/crash_sync_service.dart';
import 'package:zenhome_app/features/feedback/ui/bug_report_dialog.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';
import 'package:zenhome_app/core/services/ble_local_service.dart';
import 'package:zenhome_app/core/utils/masking_helper.dart';
import 'package:zenhome_app/features/home/ui/home_switcher_sheet.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

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
        final localNet = ref.read(localNetworkServiceProvider);
        final homeConfig = ref.read(homeConfigProvider);

        // FCM Tokens are now managed by SessionManager in Firestore.
        // We do not need to unsubscribe from topics here.
        await SessionManager.clearSession();
        
        // Ngắt kết nối và giải phóng toàn bộ dịch vụ cục bộ & Bluetooth LE
        localNet.stopMonitoring();
        BleLocalService().stop();

        // Xóa sạch toàn bộ khóa bảo mật Zero-Knowledge khỏi Secure Storage
        try {
          const FlutterSecureStorage().deleteAll();
        } catch (_) {}

        await FirebaseAuth.instance.signOut();
        
        await homeConfig.clearAllHomes();
        
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
          try {
            final Map<String, dynamic> leaveUpdates = {
              'sharedWith': FieldValue.arrayRemove([currentUsername]),
              'automationEditors': FieldValue.arrayRemove([currentUsername]),
              'disabledMembers': FieldValue.arrayRemove([currentUsername]),
            };
            if (currentUser.uid.isNotEmpty) {
              leaveUpdates['sharedUids'] = FieldValue.arrayRemove([currentUser.uid]);
              leaveUpdates['disabledUids'] = FieldValue.arrayRemove([currentUser.uid]);
            }
            await FirebaseFirestore.instance.collection('users').doc(ownerUsername).update(leaveUpdates);
          } catch (e) {
            debugPrint('Error leaving owner document: $e');
          }
          
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

          // Ngắt kết nối và giải phóng mạng cục bộ & Bluetooth Low Energy
          ref.read(localNetworkServiceProvider).stopMonitoring();
          BleLocalService().stop();
          try {
            const FlutterSecureStorage().deleteAll();
          } catch (_) {}

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

  // Hàm xử lý xóa ngôi nhà phụ hiện tại
  void _handleDeleteCurrentSubHome(BuildContext context, WidgetRef ref, SmartConfig activeConfig) async {
    final confirmed = await showCautionConfirmDialog(
      context,
      title: context.tr('delete_home_confirm_title') ?? 'Xóa ngôi nhà?',
      warningText: (context.tr('delete_home_confirm_desc') ?? 'Bạn có chắc chắn muốn xóa ngôi nhà "{name}"? Toàn bộ thiết bị, cấu hình và lịch trình của ngôi nhà này sẽ bị xóa vĩnh viễn.')
          .replaceAll('{name}', activeConfig.homeName),
      cautionDetails: 'Hành động này không thể hoàn tác. Ứng dụng sẽ tự động chuyển về Nhà chính mặc định của bạn.',
      confirmText: context.tr('btn_delete') ?? 'Xóa vĩnh viễn',
      cancelText: context.tr('btn_cancel') ?? 'Hủy',
      isDanger: true,
    );

    if (confirmed == true) {
      LoadingOverlay.show(context);
      final success = await ref.read(homeConfigProvider).deleteHome(activeConfig.userId);
      LoadingOverlay.hide();
      if (context.mounted) {
        if (success) {
          showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_delete_home_success') ?? 'Đã xóa ngôi nhà và chuyển về nhà chính!');
        } else {
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_delete_home') ?? 'Không thể xóa ngôi nhà!', isError: true);
        }
      }
    }
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

  void _changeThemeWithTelegramTransition(
    BuildContext context,
    ThemeMode mode,
    ThemeMode currentMode,
    WidgetRef ref,
    Offset tapPosition,
  ) {
    if (mode == currentMode) return;
    HapticFeedback.mediumImpact();
    final transitionState = TelegramThemeTransition.of(context);
    if (transitionState != null) {
      transitionState.startThemeTransition(
        center: tapPosition,
        performThemeChange: () async {
          await _setTheme(mode, ref);
        },
      );
    } else {
      _setTheme(mode, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Builder(
      builder: (context) {
        ThemeMode currentThemeMode = ref.watch(themeModeNotifierProvider);
        return Builder(
          builder: (context) {
            String currentLang = ref.watch(localeNotifierProvider).languageCode;
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            bool isEng = currentLang == 'en';
            final zen = context.zenColors;
            final activeConfig = ref.watch(homeConfigProvider).activeConfig;
            final currentPreset = ref.watch(themePresetNotifierProvider);
            final currentPresetConfig = ThemePresetConfig.fromPreset(currentPreset);
            final Color glassDividerColor = isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFCBD5E1).withOpacity(0.55);

            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: zen.primary,
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
                      Text(
                        context.tr('setting_title'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                      ).animate().slideY(begin: -0.2, end: 0),
                      const SizedBox(height: 22),

                      // --- GROUP 1: TÀI KHOẢN (PROFILE HERO GLASS CARD 2.0) ---
                      ZenGlassCard(
                        borderRadius: 26,
                        blurSigma: 14,
                        isActive: true,
                        glowColor: zen.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          ).then((_) {
                            if (context.mounted) {
                              (context as Element).markNeedsBuild();
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: zen.brandHero,
                                boxShadow: [
                                  BoxShadow(
                                    color: zen.primary.withOpacity(isDark ? 0.42 : 0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const UserAvatar(radius: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    FirebaseAuth.instance.currentUser?.displayName ?? context.tr('profile_title'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    getDisplayEmailOrPhone(FirebaseAuth.instance.currentUser),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 7),
                                  ZenGlassPill(
                                    blurSigma: 0,
                                    isSelected: true,
                                    glowColor: zen.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          activeConfig.role == 'owner'
                                              ? Icons.verified_user_rounded
                                              : Icons.home_rounded,
                                          size: 12.5,
                                          color: isDark ? zen.primaryAccent : zen.primary,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            activeConfig.homeName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? zen.primaryAccent : zen.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ZenLiquidGlass(
                              width: 36,
                              height: 36,
                              borderRadius: 12,
                              blurSigma: 0,
                              alignment: Alignment.center,
                              surfaceColor: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.68),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: isDark ? zen.primaryAccent : zen.primary,
                              ),
                            ),
                          ],
                        ),
                      ).animate(delay: 100.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
                      const SizedBox(height: 25),

                      // --- GROUP 2: CÀI ĐẶT CHUNG ---
                      Text(
                        context.tr('general_settings'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ).animate(delay: 200.ms).fade(duration: 400.ms),
                      const SizedBox(height: 10),
                      ZenGlassCard(
                        borderRadius: 24,
                        blurSigma: 14,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            // --- QUẢN LÝ NGÔI NHÀ & CHUYỂN ĐỔI NHÀ ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: zen.primary.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.home_work_rounded,
                                  color: isDark ? zen.primaryAccent : zen.primary,
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                context.tr('manage_homes') ?? 'Quản lý ngôi nhà',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${activeConfig.homeName} • ${ref.watch(homeConfigProvider).availableHomes.length} ${context.tr('homes_count') ?? 'ngôi nhà'}',
                                style: TextStyle(fontSize: 12.5, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () => showHomeSwitcherBottomSheet(context, ref),
                            ),
                            Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),

                            if (activeConfig.role == 'owner') ...[
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.group_add_rounded, color: Colors.orange, size: 22),
                                ),
                                title: Text(context.tr('family_members'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MemberScreen())),
                              ),
                              Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),
                            ],

                            // --- NÚT CHỌN THEME 3 NẤC (FROSTED GLASS CAPSULE 2.0) ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: zen.primary.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  currentThemeMode == ThemeMode.light
                                      ? Icons.light_mode_rounded
                                      : (currentThemeMode == ThemeMode.dark
                                          ? Icons.dark_mode_rounded
                                          : Icons.brightness_auto_rounded),
                                  color: isDark ? zen.primaryAccent : zen.primary,
                                  size: 22,
                                ),
                              ),
                              title: Text(context.tr('theme_mode'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              trailing: ZenLiquidGlass(
                                width: 144,
                                height: 40,
                                borderRadius: 22,
                                blurSigma: 0,
                                rimWidth: 1.1,
                                surfaceColor: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.58),
                                customShadows: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.24 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                child: Stack(
                                  children: [
                                    // Glowing Active Droplet Pill
                                    AnimatedAlign(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      alignment: currentThemeMode == ThemeMode.light
                                          ? Alignment.centerLeft
                                          : (currentThemeMode == ThemeMode.system
                                              ? Alignment.center
                                              : Alignment.centerRight),
                                      child: FractionallySizedBox(
                                        widthFactor: 1 / 3,
                                        child: Container(
                                          margin: const EdgeInsets.all(3.5),
                                          decoration: BoxDecoration(
                                            gradient: zen.brandHero,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.36),
                                              width: 0.9,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: zen.primary.withOpacity(0.45),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Action Options
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) {
                                              _changeThemeWithTelegramTransition(
                                                context,
                                                ThemeMode.light,
                                                currentThemeMode,
                                                ref,
                                                details.globalPosition,
                                              );
                                            },
                                            child: Center(
                                              child: Icon(
                                                Icons.light_mode_rounded,
                                                size: 18,
                                                color: currentThemeMode == ThemeMode.light
                                                    ? Colors.white
                                                    : (isDark ? Colors.white60 : Colors.black54),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) {
                                              _changeThemeWithTelegramTransition(
                                                context,
                                                ThemeMode.system,
                                                currentThemeMode,
                                                ref,
                                                details.globalPosition,
                                              );
                                            },
                                            child: Center(
                                              child: Icon(
                                                Icons.brightness_auto_rounded,
                                                size: 18,
                                                color: currentThemeMode == ThemeMode.system
                                                    ? Colors.white
                                                    : (isDark ? Colors.white60 : Colors.black54),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (details) {
                                              _changeThemeWithTelegramTransition(
                                                context,
                                                ThemeMode.dark,
                                                currentThemeMode,
                                                ref,
                                                details.globalPosition,
                                              );
                                            },
                                            child: Center(
                                              child: Icon(
                                                Icons.dark_mode_rounded,
                                                size: 18,
                                                color: currentThemeMode == ThemeMode.dark
                                                    ? Colors.white
                                                    : (isDark ? Colors.white60 : Colors.black54),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),

                            // --- NÚT ĐỔI NGÔN NGỮ (FROSTED GLASS CAPSULE 2.0) ---
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.cyanGlow.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.translate_rounded, color: AppColors.cyanGlow, size: 22),
                              ),
                              title: Text(context.tr('language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              trailing: ZenLiquidGlass(
                                width: 126,
                                height: 40,
                                borderRadius: 22,
                                blurSigma: 0,
                                rimWidth: 1.1,
                                surfaceColor: isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.58),
                                customShadows: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.24 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                child: Stack(
                                  children: [
                                    // Glowing Active Droplet Pill
                                    AnimatedAlign(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      alignment: !isEng ? Alignment.centerLeft : Alignment.centerRight,
                                      child: FractionallySizedBox(
                                        widthFactor: 0.5,
                                        child: Container(
                                          margin: const EdgeInsets.all(3.5),
                                          decoration: BoxDecoration(
                                            gradient: zen.brandHero,
                                            borderRadius: BorderRadius.circular(18),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.36),
                                              width: 0.9,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: zen.primary.withOpacity(0.45),
                                                blurRadius: 10,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Action Options
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () async {
                                              if (!isEng) return;
                                              HapticFeedback.selectionClick();
                                              await ref.read(localeNotifierProvider.notifier).setLocale('vi');
                                            },
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('🇻🇳', style: TextStyle(fontSize: 13)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'VN',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: !isEng ? FontWeight.w800 : FontWeight.w600,
                                                      color: !isEng
                                                          ? Colors.white
                                                          : (isDark ? Colors.white60 : Colors.black54),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () async {
                                              if (isEng) return;
                                              HapticFeedback.selectionClick();
                                              await ref.read(localeNotifierProvider.notifier).setLocale('en');
                                            },
                                            child: Center(
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('🇬🇧', style: TextStyle(fontSize: 13)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'EN',
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: isEng ? FontWeight.w800 : FontWeight.w600,
                                                      color: isEng
                                                          ? Colors.white
                                                          : (isDark ? Colors.white60 : Colors.black54),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),
                            
                            // --- CÁ NHÂN HÓA BẢNG MÀU CHỦ ĐỀ (THEME PRESETS) ---
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          gradient: currentPresetConfig.brandHero,
                                          borderRadius: BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: currentPresetConfig.primary.withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(currentPresetConfig.icon, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr('theme_preset_title'),
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isEng ? currentPresetConfig.titleEn : currentPresetConfig.titleVi,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: currentPresetConfig.primaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Danh sách các viên ngọc màu Liquid Glass Chủ đề
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: ThemePresetConfig.presets.map((cfg) {
                                        final isSelected = cfg.preset == currentPreset;
                                        return GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            if (isSelected) return;
                                            HapticFeedback.mediumImpact();
                                            ref.read(themePresetNotifierProvider.notifier).setThemePreset(cfg.preset);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(right: 12),
                                            child: Column(
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 250),
                                                  curve: Curves.easeOutCubic,
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    gradient: cfg.brandHero,
                                                    borderRadius: BorderRadius.circular(14),
                                                    border: Border.all(
                                                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                                                      width: isSelected ? 2.5 : 1,
                                                    ),
                                                    boxShadow: [
                                                      if (isSelected)
                                                        BoxShadow(
                                                          color: cfg.primary.withOpacity(0.6),
                                                          blurRadius: 12,
                                                          spreadRadius: 1,
                                                          offset: const Offset(0, 3),
                                                        )
                                                      else
                                                        BoxShadow(
                                                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                    ],
                                                  ),
                                                  child: isSelected
                                                      ? const Center(
                                                          child: Icon(Icons.check_rounded, color: Colors.white, size: 22),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  isEng ? cfg.titleEn.split(' ').first : cfg.titleVi.split(' ').first,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                                    color: isSelected
                                                        ? (isDark ? Colors.white : Colors.black87)
                                                        : (isDark ? Colors.white54 : Colors.black45),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ).animate(delay: 250.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
                  const SizedBox(height: 25),
                  
                  // --- GROUP 3: HỆ THỐNG ESP32 ---
                  if (activeConfig.role == 'owner') ...[
                    Text(
                      context.tr('system_settings'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ).animate(delay: 300.ms).fade(duration: 400.ms),
                    const SizedBox(height: 10),
                    ZenGlassCard(
                      borderRadius: 24,
                      blurSigma: 14,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                            children: [
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: zen.primary.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.wifi_find_rounded,
                                    size: 22,
                                    color: isDark ? zen.primaryAccent : zen.primary,
                                  ),
                                ),
                                title: Text(
                                  context.tr('setup_wifi'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  (activeConfig.macAddress.isNotEmpty && activeConfig.macAddress != 'unknown_mac')
                                      ? 'Đã liên kết (MAC: ${MaskingHelper.maskMac(activeConfig.macAddress)})'
                                      : 'Cấu hình mạng Wi-Fi và liên kết Hub',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () async {
                                  final isLinked = activeConfig.macAddress.isNotEmpty && activeConfig.macAddress != 'unknown_mac';
                                  if (isLinked) {
                                    final action = await showZenGlassDialog<String>(
                                      context: context,
                                      accentColor: zen.primary,
                                      builder: (ctx) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  gradient: zen.brandHero,
                                                  borderRadius: BorderRadius.circular(14),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: zen.primary.withOpacity(0.35),
                                                      blurRadius: 12,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.settings_suggest_rounded,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  context.tr('setup_wifi'),
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          ZenLiquidGlass(
                                            blurSigma: 0,
                                            borderRadius: 14,
                                            padding: const EdgeInsets.all(12),
                                            surfaceColor: zen.primary.withOpacity(isDark ? 0.14 : 0.08),
                                            glowColor: zen.primary,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.memory_rounded,
                                                  size: 20,
                                                  color: isDark ? zen.primaryAccent : zen.primary,
                                                ),
                                                const SizedBox(width: 9),
                                                Expanded(
                                                  child: Text(
                                                    'MAC: ${MaskingHelper.maskMac(activeConfig.macAddress)}',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            'Thiết bị Hub đã được liên kết bảo mật với tài khoản. Bạn muốn cấu hình lại Wi-Fi hay hủy liên kết & Factory Reset Hub từ xa?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.45,
                                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          ZenGlassButton(
                                            label: context.tr('reconfig_wifi_mqtt'),
                                            icon: Icons.settings_suggest_rounded,
                                            isPrimary: true,
                                            onPressed: () => Navigator.pop(ctx, 'setup'),
                                          ),
                                          const SizedBox(height: 10),
                                          ZenGlassButton(
                                            label: context.tr('unlink_hub_menu_title'),
                                            icon: Icons.link_off_rounded,
                                            isPrimary: false,
                                            isDanger: true,
                                            onPressed: () => Navigator.pop(ctx, 'unlink'),
                                          ),
                                          const SizedBox(height: 8),
                                          ZenGlassButton(
                                            label: context.tr('cancel'),
                                            isPrimary: false,
                                            onPressed: () => Navigator.pop(ctx, 'cancel'),
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
                                        cautionDetails: 'MAC Hub: ${MaskingHelper.maskMac(activeConfig.macAddress)} • ESP32 sẽ lập tức xóa /config.json, ngắt mọi rơ-le và tự động khởi động lại vào AP Setup.',
                                        confirmText: 'Bắn tín hiệu Reset & Hủy',
                                        cancelText: 'Giữ lại liên kết',
                                        isDanger: true,
                                      );
                                      if (!confirmed) return;

                                      // 4. Bắn tín hiệu boot lại và reset ESP32 từ xa qua MQTT
                                      LoadingOverlay.show(context);
                                      try {
                                        if (isEspOnline) {
                                          final resetPayload = jsonEncode({
                                            'action': 'factory_reset',
                                            'admin_pass': activeConfig.adminPass ?? 'admin',
                                            'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                          });
                                          ref.read(mqttRepositoryProvider).publishCmd('${activeConfig.mqttPrefix}/system/reset', resetPayload);
                                          await Future.delayed(const Duration(milliseconds: 600));
                                        }
                                      } catch (e) {
                                        debugPrint('Lỗi publish reset mqtt: $e');
                                      }

                                      // 5. Cập nhật gỡ MAC trong Local và Firestore
                                      String previousMac = activeConfig.macAddress;
                                      activeConfig.macAddress = '';
                                      await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
                                      try {
                                        if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
                                          await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
                                            'macAddress': '',
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
                                            'Tín hiệu ESP32': isEspOnline ? 'Đã gửi lệnh Reset bảo mật' : 'Hub Offline (Đã gỡ trên Cloud)',
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
                              Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),

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
                                        'Mã Hub': MaskingHelper.maskMac(activeConfig.macAddress),
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
                                    cautionDetails: 'MAC: ${MaskingHelper.maskMac(activeConfig.macAddress)} • Lệnh gửi qua giao thức bảo mật MQTT TLS.',
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
                                          'MAC Thiết bị': MaskingHelper.maskMac(activeConfig.macAddress),
                                          'Kênh điều khiển': 'Kênh mã hóa bảo mật (TLS)',
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
                              Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),

                              // --- NÚT NÂNG CẤP FIRMWARE ESP32 (FIRMWARE OTA) ---
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.system_update_alt_rounded, color: Color(0xFF0284C7), size: 22),
                                ),
                                title: Text(context.tr('hub_ota_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                subtitle: Text(
                                  context.tr('hub_ota_desc'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                onTap: () => EspOtaDialog.startOtaProcess(context, ref, activeConfig),
                              ),
                              Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),

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
                    ).animate(delay: 350.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),
                  ],
                  
                  // --- GROUP 4: THÀNH VIÊN RỜI NHÀ ---
                  if (activeConfig.role != 'owner' && activeConfig.userId.isNotEmpty && activeConfig.userId != 'guest') ...[
                    Text(
                      context.tr('leave_home_title') ?? 'QUẢN LÝ QUYỀN TRUY CẬP',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ).animate(delay: 400.ms).fade(duration: 400.ms),
                    const SizedBox(height: 10),
                    ZenGlassCard(
                      borderRadius: 24,
                      blurSigma: 14,
                      isActive: true,
                      glowColor: AppColors.roseGlow,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.roseGlow.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.exit_to_app_rounded, color: AppColors.roseGlow, size: 22),
                        ),
                        title: Text(
                          context.tr('btn_leave_home') ?? 'Rời khỏi nhà này',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.roseGlow),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.roseGlow),
                        onTap: () => _handleLeaveHome(context, ref, activeConfig.ownerEmail, activeConfig.userId),
                      ),
                    ).animate().slideX(begin: 0.1, end: 0),
                  ],

                  // --- GROUP: XÓA NGÔI NHÀ PHỤ HIỆN TẠI (CHO CHỦ SỞ HỮU) ---
                  if (activeConfig.isSubHome && activeConfig.role == 'owner') ...[
                    const SizedBox(height: 18),
                    Text(
                      context.tr('manage_sub_home_title') ?? 'QUẢN LÝ NGÔI NHÀ PHỤ',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ).animate(delay: 400.ms).fade(duration: 400.ms),
                    const SizedBox(height: 10),
                    ZenGlassCard(
                      borderRadius: 24,
                      blurSigma: 14,
                      isActive: true,
                      glowColor: AppColors.roseGlow,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.roseGlow.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: AppColors.roseGlow, size: 22),
                        ),
                        title: Text(
                          context.tr('delete_this_sub_home') ?? 'Xóa ngôi nhà phụ này',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.roseGlow),
                        ),
                        subtitle: Text(
                          'Xóa vĩnh viễn ${activeConfig.homeName} và trở về nhà chính',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.roseGlow),
                        onTap: () => _handleDeleteCurrentSubHome(context, ref, activeConfig),
                      ),
                    ).animate().slideX(begin: 0.1, end: 0),
                  ],

                  // --- GROUP: CẬP NHẬT & PHIÊN BẢN ỨNG DỤNG ---
                  const SizedBox(height: 22),
                  Text(
                    context.tr('app_version_title'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ).animate(delay: 420.ms).fade(duration: 400.ms),
                  const SizedBox(height: 10),
                  ZenGlassCard(
                    borderRadius: 24,
                    blurSigma: 14,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                          children: [
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: zen.primary.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.system_update_rounded,
                                  color: isDark ? zen.primaryAccent : zen.primary,
                                  size: 22,
                                ),
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
                                            color: AppColors.roseGlow,
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
                                    return Text(
                                      'ZenHome v${info.version} (Build ${info.buildNumber})',
                                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                    );
                                  }
                                  return const Text('ZenHome...', style: TextStyle(fontSize: 12, color: Colors.grey));
                                },
                              ),
                              trailing: ZenGlassPill(
                                blurSigma: 0,
                                isSelected: true,
                                glowColor: zen.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 14, color: isDark ? zen.primaryAccent : zen.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('btn_check'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? zen.primaryAccent : zen.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () {
                                AppUpdateService.checkAndPromptUpdate(context, isManualCheck: true);
                              },
                            ),
                            Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.purpleGlow.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.article_rounded, color: AppColors.purpleGlow, size: 22),
                              ),
                              title: Text(
                                context.tr('version_changelog_title'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                context.tr('version_changelog_desc'),
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const VersionChangelogScreen()),
                                );
                              },
                            ),
                            Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.amberGlow.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.bug_report_rounded, color: AppColors.amberGlow, size: 22),
                              ),
                              title: Text(
                                context.tr('report_bug_title') ?? 'Báo cáo sự cố & Góp ý',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                context.tr('report_bug_desc') ?? 'Gửi phản hồi trực tiếp tới đội ngũ phát triển',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                              onTap: () => BugReportDialog.show(context),
                            ),
                            Divider(height: 1, color: glassDividerColor, indent: 64, endIndent: 16),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: AppColors.roseGlow.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.flourescent_rounded, color: AppColors.roseGlow, size: 22),
                              ),
                              title: const Text(
                                'Kiểm tra Crashlytics Realtime',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                'Mô phỏng gửi lỗi lên Firebase & đồng bộ Web Admin',
                                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              trailing: ZenGlassPill(
                                blurSigma: 0,
                                isSelected: true,
                                glowColor: AppColors.roseGlow,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.send_rounded, size: 14, color: AppColors.roseGlow),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('btn_send_test'),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.roseGlow),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () async {
                                final success = await CrashSyncService.sendTestCrash();
                                if (context.mounted) {
                                  if (success) {
                                    showFloatingToast(context, 'Crashlytics Test', 'Đã gửi log kiểm thử Crashlytics & Firestore thành công! Mời kiểm tra Web Admin.', isError: false);
                                  } else {
                                    showFloatingToast(context, 'Lỗi', 'Không thể gửi test log kiểm thử', isError: true);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                    ).animate(delay: 450.ms).fade(duration: 400.ms).slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuart),

                  const SizedBox(height: 32),
                  // --- ĐĂNG XUẤT ---
                  ZenGlassCard(
                    borderRadius: 22,
                    blurSigma: 12,
                    isActive: true,
                    glowColor: AppColors.roseGlow,
                    height: 56,
                    padding: EdgeInsets.zero,
                    onTap: () => _handleLogout(context, ref),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded, color: AppColors.roseGlow, size: 21),
                          const SizedBox(width: 9),
                          Text(
                            context.tr('btn_logout'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.roseGlow,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: 500.ms).fade(duration: 400.ms).scaleXY(begin: 0.9, end: 1, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 110),
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
}
