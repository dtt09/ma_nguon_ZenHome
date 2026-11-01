import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';

import 'dart:async';

import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';




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
import 'package:zenhome_app/core/providers/local_network_provider.dart';



class MainLayout extends ConsumerStatefulWidget {

  const MainLayout({super.key});

  @override

  ConsumerState<MainLayout> createState() => _MainLayoutState();

}



class _MainLayoutState extends ConsumerState<MainLayout> with AuthSyncMixin, HomeSyncMixin {

  int _currentIndex = 0;
  late final PageController _pageController;

  bool _isDragging = false;

  double _dragAlignment = -1.0;

  StreamSubscription<String>? _notificationSubscription;



  @override

  void initState() {

    super.initState();

    SessionManager.updateLastAccess();
    SessionManager.listenToCurrentSession();
    _pageController = PageController(initialPage: _currentIndex);

    

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
    SessionManager.stopListeningSession();
    _notificationSubscription?.cancel();
    _pageController.dispose();

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
        
        // 1. Dọn dẹp kết nối mạng cục bộ LAN & BLE của ngôi nhà cũ trước khi chuyển
        ref.read(localNetworkServiceProvider).stopMonitoring();

        final activeConfig = next.activeConfig;

        // 2. Ngắt MQTT cũ và kết nối MQTT tới broker với không gian nhà mới
        ref.read(mqttRepositoryProvider).disconnect();
        ref.read(mqttRepositoryProvider).connect(
          userId: activeConfig.userId,
          mqttServer: activeConfig.mqttServer,
          mqttPrefix: activeConfig.mqttPrefix,
          dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
          mqttUser: activeConfig.mqttUser,
          mqttPass: activeConfig.mqttPass,
        );

        // 3. Khởi động lại giám sát mạng cục bộ LAN & BLE với cấu hình nhà mới (nếu có Hub)
        if (activeConfig.macAddress.isNotEmpty &&
            activeConfig.macAddress != 'unknown_mac' &&
            activeConfig.macAddress != 'unknown') {
          ref.read(localNetworkServiceProvider).startMonitoring(
            targetMac: activeConfig.macAddress,
            adminPass: activeConfig.adminPass,
            userId: activeConfig.userId,
            role: activeConfig.role,
            isDisabled: activeConfig.isDisabled,
            allowedDevices: activeConfig.allowedDevices,
          );
        }
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

            : PageView(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                },
                children: screens,
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

                            duration: Duration(milliseconds: _isDragging ? 50 : 360),

                            curve: _isDragging ? Curves.linear : Curves.easeOutBack,

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

                                    color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.35),

                                    width: 1.2,

                                  ),

                                  boxShadow: [

                                    BoxShadow(

                                      color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(isDark ? 0.28 : 0.18),

                                      blurRadius: 14,

                                      offset: const Offset(0, 3),

                                    ),

                                  ],

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

    final bool isSelected = _currentIndex == index;

    final Color activeColor = isDark ? AppColors.primaryLight : AppColors.primary;

    final Color inactiveColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    

    return GestureDetector(

      onTap: () {

        HapticFeedback.lightImpact();

        if (_currentIndex != index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
          setState(() => _currentIndex = index);
        }

      },

      behavior: HitTestBehavior.opaque,

      child: AnimatedContainer(

        duration: const Duration(milliseconds: 280),

        curve: Curves.easeOutCubic,

        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),

        child: Row(

          mainAxisAlignment: MainAxisAlignment.center,

          mainAxisSize: MainAxisSize.min,

          children: [

            AnimatedScale(

              scale: isSelected ? 1.12 : 0.95,

              duration: const Duration(milliseconds: 280),

              curve: Curves.easeOutBack,

              child: AnimatedSlide(

                offset: isSelected ? const Offset(0, -0.04) : Offset.zero,

                duration: const Duration(milliseconds: 280),

                curve: Curves.easeOutCubic,

                child: TweenAnimationBuilder<Color?>(

                  tween: ColorTween(

                    begin: inactiveColor,

                    end: isSelected ? activeColor : inactiveColor,

                  ),

                  duration: const Duration(milliseconds: 240),

                  builder: (context, color, child) {

                    return Icon(icon, color: color, size: 22);

                  },

                ),

              ),

            ),

            ClipRect(

              child: AnimatedSize(

                duration: const Duration(milliseconds: 280),

                curve: Curves.easeOutCubic,

                alignment: Alignment.centerLeft,

                child: isSelected

                    ? Padding(

                        padding: const EdgeInsets.only(left: 6),

                        child: AnimatedOpacity(

                          opacity: isSelected ? 1.0 : 0.0,

                          duration: const Duration(milliseconds: 220),

                          curve: Curves.easeOut,

                          child: AnimatedSlide(

                            offset: isSelected ? Offset.zero : const Offset(-0.25, 0),

                            duration: const Duration(milliseconds: 260),

                            curve: Curves.easeOutCubic,

                            child: Text(

                              label,

                              maxLines: 1,

                              softWrap: false,

                              overflow: TextOverflow.clip,

                              style: TextStyle(

                                color: activeColor,

                                fontWeight: FontWeight.w700,

                                fontSize: 13,

                                letterSpacing: 0.2,

                              ),

                            ),

                          ),

                        ),

                      )

                    : const SizedBox.shrink(),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



