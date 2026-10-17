import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/home/ui/dashboard_screen.dart';
import 'package:zenhome_app/features/home/ui/scenes_screen.dart';
import 'package:zenhome_app/features/settings/ui/settings_screen.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';

import 'package:zenhome_app/features/home/logic/auth_sync_mixin.dart';
import 'package:zenhome_app/features/home/logic/home_sync_mixin.dart';
import 'package:zenhome_app/features/home/ui/components/disabled_view.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});
  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> with AuthSyncMixin, HomeSyncMixin {
  int _currentIndex = 0;
  bool _isDragging = false;
  double _dragAlignment = -1.0;
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    SessionManager.updateLastAccess();
    
    // Initialize mixins
    initAuthSync();
    initHomeSync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeConfig = ref.read(homeConfigProvider).activeConfig;
      ref.read(mqttRepositoryProvider).connect(
        userId: activeConfig.userId,
        mqttServer: activeConfig.mqttServer,
        mqttPrefix: activeConfig.mqttPrefix,
        dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
        mqttUser: activeConfig.mqttUser,
        mqttPass: activeConfig.mqttPass,
      );

      // Kiểm tra bản cập nhật mới ngầm trong nền sau 3 giây khởi động ứng dụng
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          AppUpdateService.checkAndPromptUpdate(context, isManualCheck: false);
        }
      });
    });
    
    // Local MQTT Notifications
    _notificationSubscription = ref.read(mqttRepositoryProvider).notificationStream.listen((val) {
      if (val.isNotEmpty && mounted) {
        final msg = val.split('|')[0];
        final title = context.tr('toast_sys_report');
        showFloatingToast(context, title, msg);
        ref.read(notificationProvider.notifier).addNotification(title, msg, 'other');
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    disposeAuthSync();
    disposeHomeSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reload connection when activeConfig changes
    ref.listen(homeConfigProvider, (previous, next) {
      if (previous?.activeConfig.userId != next.activeConfig.userId || previous?.activeConfig.role != next.activeConfig.role) {
        disposeHomeSync();
        if (mounted) setState(() => isDisabled = false);
        initHomeSync();
        
        final activeConfig = next.activeConfig;
        ref.read(mqttRepositoryProvider).disconnect();
        ref.read(mqttRepositoryProvider).connect(
          userId: activeConfig.userId,
          mqttServer: activeConfig.mqttServer,
          mqttPrefix: activeConfig.mqttPrefix,
          dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
          mqttUser: activeConfig.mqttUser,
          mqttPass: activeConfig.mqttPass,
        );
      }
    });

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isConnectedState = ref.watch(mqttConnectionStateProvider);
    final isHardDisconnected = isConnectedState == -2;

    final List<Widget> screens = [
      const DashboardScreen(key: ValueKey<int>(0)),
      const ScenesScreen(key: ValueKey<int>(1)),
      const SettingsScreen(key: ValueKey<int>(2)),
    ];

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF0F2F5),
          body: isDisabled 
            ? DisabledView(isDark: isDark)
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: screens[_currentIndex],
              ),
          bottomNavigationBar: isDisabled ? null : SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF0F172A).withOpacity(0.82) 
                    : Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: isDark ? const Color(0x33FFFFFF) : const Color(0x14000000),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                  if (isDark)
                    BoxShadow(
                      color: AppColors.primaryLight.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: GestureDetector(
                    onHorizontalDragStart: (details) {
                      setState(() {
                        _isDragging = true;
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        // Approximate the width of the navigation bar
                        double width = MediaQuery.of(context).size.width - 36;
                        double fraction = details.localPosition.dx / width;
                        _dragAlignment = (fraction * 2) - 1.0;
                        _dragAlignment = _dragAlignment.clamp(-1.0, 1.0);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      setState(() {
                        _isDragging = false;
                        if (_dragAlignment < -0.33) {
                          _currentIndex = 0;
                        } else if (_dragAlignment > 0.33) {
                          _currentIndex = 2;
                        } else {
                          _currentIndex = 1;
                        }
                      });
                    },
                    child: Stack(
                      children: [
                        // Sliding Indicator Pill
                        Positioned.fill(
                          child: AnimatedAlign(
                            duration: Duration(milliseconds: _isDragging ? 50 : 320),
                            curve: _isDragging ? Curves.linear : Curves.easeOutCubic,
                            alignment: _isDragging 
                                ? Alignment(_dragAlignment, 0)
                                : (_currentIndex == 0 
                                    ? Alignment.centerLeft 
                                    : _currentIndex == 1 
                                        ? Alignment.center 
                                        : Alignment.centerRight),
                            child: FractionallySizedBox(
                              widthFactor: 0.3333,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
                                decoration: BoxDecoration(
                                  gradient: isDark
                                      ? LinearGradient(
                                          colors: [
                                            AppColors.primaryLight.withOpacity(0.24),
                                            AppColors.primaryAccent.withOpacity(0.12),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : LinearGradient(
                                          colors: [
                                            AppColors.primary.withOpacity(0.12),
                                            AppColors.primaryLight.withOpacity(0.06),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.25),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Menu Items
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _buildNavItem(Icons.home_rounded, context.tr('tab_home'), 0, isDark)),
                            Expanded(child: _buildNavItem(Icons.auto_awesome_mosaic_rounded, context.tr('tab_scene'), 1, isDark)),
                            Expanded(child: _buildNavItem(Icons.settings_rounded, context.tr('tab_settings'), 2, isDark)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (isHardDisconnected)
          Container(
            color: Colors.black.withOpacity(0.85),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 60),
                      const SizedBox(height: 20),
                      Text(context.tr('hard_disconnect_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 10),
                      Text(context.tr('hard_disconnect_desc'), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          onPressed: () {
                            ref.read(mqttRepositoryProvider).disconnect();
                            ref.read(mqttRepositoryProvider).connect(
                              userId: activeConfig.userId,
                              mqttServer: activeConfig.mqttServer,
                              mqttPrefix: activeConfig.mqttPrefix,
                              dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
                              mqttUser: activeConfig.mqttUser,
                              mqttPass: activeConfig.mqttPass,
                            );
                          },
                          child: Text(context.tr('btn_retry'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    bool isSelected = _currentIndex == index;
    Color activeColor = isDark ? AppColors.primaryLight : AppColors.primary;
    Color inactiveColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : inactiveColor,
              size: 22,
            ).animate(target: isSelected ? 1 : 0).scale(
              begin: const Offset(0.9, 0.9), 
              end: const Offset(1.08, 1.08),
              curve: Curves.easeOutBack,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: activeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ).animate().fade(duration: const Duration(milliseconds: 200)).slideX(begin: -0.1),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

