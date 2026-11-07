import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenhome_app/core/providers/local_network_provider.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/home/logic/auth_sync_mixin.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/home/logic/home_sync_mixin.dart';
import 'package:zenhome_app/features/home/ui/components/disabled_view.dart';
import 'package:zenhome_app/features/home/ui/dashboard_screen.dart';
import 'package:zenhome_app/features/home/ui/scenes_screen.dart';
import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'package:zenhome_app/features/settings/ui/settings_screen.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout>
    with AuthSyncMixin, HomeSyncMixin {
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

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          AppUpdateService.checkAndPromptUpdate(context, isManualCheck: false);
        }
      });
    });

    _notificationSubscription =
        ref.read(mqttRepositoryProvider).notificationStream.listen((val) {
      if (val.isNotEmpty && mounted) {
        final msg = val.split('|')[0];
        final title = context.tr('toast_sys_report');
        showFloatingToast(context, title, msg);
        ref
            .read(notificationProvider.notifier)
            .addNotification(title, msg, 'other');
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
    ref.listen(homeConfigProvider, (previous, next) {
      if (previous?.activeConfig.userId != next.activeConfig.userId ||
          previous?.activeConfig.role != next.activeConfig.role) {
        disposeHomeSync();
        if (mounted) setState(() => isDisabled = false);
        initHomeSync();

        ref.read(globalDeviceStatesProvider.notifier).clearStates();
        ref.read(pendingDeviceOperationsProvider.notifier).clearAll();
        ref.read(localNetworkServiceProvider).stopMonitoring();

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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isConnectedState = ref.watch(mqttConnectionStateProvider);
    final isHardDisconnected = isConnectedState == -2;

    final List<Widget> screens = const [
      DashboardScreen(key: ValueKey<int>(0)),
      ScenesScreen(key: ValueKey<int>(1)),
      SettingsScreen(key: ValueKey<int>(2)),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Lớp Nền Cực Quang Khúc Xạ Đa Tầng cho toàn bộ 3 Tab chính
        const ZenAmbientMeshBackground(intensity: 1.05),

        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
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
          bottomNavigationBar: isDisabled
              ? null
              : RepaintBoundary(
                  child: SafeArea(
                    bottom: false,
                    child: ZenGlassContainer(
                      borderRadius: 36,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      glowColor: isDark ? zen.primaryLight : zen.primary,
                      blurSigma: 28,
                      child: GestureDetector(
                        onHorizontalDragStart: (_) {
                          setState(() {
                            _isDragging = true;
                          });
                        },
                        onHorizontalDragUpdate: (details) {
                          setState(() {
                            final double width =
                                MediaQuery.of(context).size.width - 36;
                            final double fraction =
                                details.localPosition.dx / width;
                            _dragAlignment = ((fraction * 2) - 1.0).clamp(
                              -1.0,
                              1.0,
                            );
                          });
                        },
                        onHorizontalDragEnd: (_) {
                          int targetIdx;
                          if (_dragAlignment < -0.33) {
                            targetIdx = 0;
                          } else if (_dragAlignment > 0.33) {
                            targetIdx = 2;
                          } else {
                            targetIdx = 1;
                          }
                          setState(() {
                            _isDragging = false;
                            _currentIndex = targetIdx;
                          });
                          if (_pageController.hasClients) {
                            _pageController.animateToPage(
                              targetIdx,
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        child: Stack(
                          children: [
                            // Giọt Kính Lỏng Trượt Thời Gian Thực Đồng Bộ PageView (Real-time Fluid Droplet Pill)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _pageController,
                                builder: (context, _) {
                                  double alignX = -1.0;
                                  if (_isDragging) {
                                    alignX = _dragAlignment;
                                  } else if (_pageController.hasClients &&
                                      _pageController.position.haveDimensions) {
                                    final double page = _pageController.page ??
                                        _currentIndex.toDouble();
                                    alignX = (page - 1.0).clamp(-1.0, 1.0);
                                  } else {
                                    alignX = _currentIndex == 0
                                        ? -1.0
                                        : (_currentIndex == 1 ? 0.0 : 1.0);
                                  }

                                  return Align(
                                    alignment: Alignment(alignX, 0),
                                    child: FractionallySizedBox(
                                      widthFactor: 0.3333,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 2.5,
                                          horizontal: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDark
                                                ? [
                                                    zen.primaryLight
                                                        .withOpacity(0.28),
                                                    zen.primaryAccent
                                                        .withOpacity(0.12),
                                                  ]
                                                : [
                                                    zen.primary
                                                        .withOpacity(0.16),
                                                    zen.primaryLight
                                                        .withOpacity(0.08),
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                          border: Border.all(
                                            color: (isDark
                                                    ? zen.primaryAccent
                                                    : zen.primary)
                                                .withOpacity(
                                                    isDark ? 0.48 : 0.35),
                                            width: 1.25,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (isDark
                                                      ? zen.primaryLight
                                                      : zen.primary)
                                                  .withOpacity(
                                                      isDark ? 0.30 : 0.18),
                                              blurRadius: 16,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: _buildNavItem(
                                  Icons.home_rounded,
                                  context.tr('tab_home'),
                                  0,
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildNavItem(
                                  Icons.auto_awesome_mosaic_rounded,
                                  context.tr('tab_scene'),
                                  1,
                                  isDark,
                                ),
                              ),
                              Expanded(
                                child: _buildNavItem(
                                  Icons.settings_rounded,
                                  context.tr('tab_settings'),
                                  2,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ),

        if (isHardDisconnected)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: ZenGlassCard(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.all(26),
                    borderRadius: 28,
                    blurSigma: 24,
                    isActive: true,
                    glowColor: AppColors.roseGlow,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.roseGlow.withOpacity(0.16),
                            border: Border.all(
                              color: AppColors.roseGlow.withOpacity(0.45),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: AppColors.roseGlow,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.tr('hard_disconnect_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr('hard_disconnect_desc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ZenGlassButton(
                            label: context.tr('btn_retry'),
                            icon: Icons.refresh_rounded,
                            onPressed: () {
                              ref.read(mqttRepositoryProvider).disconnect();
                              ref.read(mqttRepositoryProvider).connect(
                                    userId: activeConfig.userId,
                                    mqttServer: activeConfig.mqttServer,
                                    mqttPrefix: activeConfig.mqttPrefix,
                                    dynamicTopics:
                                        getDynamicDeviceTopicsList(activeConfig),
                                    mqttUser: activeConfig.mqttUser,
                                    mqttPass: activeConfig.mqttPass,
                                  );
                            },
                          ),
                        ),
                      ],
                    ),
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
    final Color activeColor =
        isDark ? context.zenColors.primaryAccent : context.zenColors.primary;
    final Color inactiveColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

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
                            offset: isSelected
                                ? Offset.zero
                                : const Offset(-0.25, 0),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                color: activeColor,
                                fontWeight: FontWeight.w800,
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
