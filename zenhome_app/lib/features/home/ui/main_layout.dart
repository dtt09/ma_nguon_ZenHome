import 'dart:async';
import 'package:zenhome_app/features/home/ui/home_navigation_dock.dart';
import 'package:flutter/material.dart';

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
      ref
          .read(mqttRepositoryProvider)
          .connect(
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

    _notificationSubscription = ref
        .read(mqttRepositoryProvider)
        .notificationStream
        .listen((val) {
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
        ref
            .read(mqttRepositoryProvider)
            .connect(
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
          ref
              .read(localNetworkServiceProvider)
              .startMonitoring(
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
                  child: HomeNavigationDock(
                    controller: _pageController,
                    currentIndex: _currentIndex,
                  ),
                ),
        ),
        if (isHardDisconnected)
          ColoredBox(
            color: Colors.black54,
            child: SafeArea(
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    child: ZenGlassCard(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.all(26),
                      borderRadius: 28,
                      blurSigma: 8,
                      isActive: true,
                      glowColor: zen.danger,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: zen.danger.withOpacity(0.16),
                              border: Border.all(
                                color: zen.danger.withOpacity(0.45),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.wifi_off_rounded,
                              color: zen.danger,
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
                              color: isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
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
                                ref
                                    .read(mqttRepositoryProvider)
                                    .connect(
                                      userId: activeConfig.userId,
                                      mqttServer: activeConfig.mqttServer,
                                      mqttPrefix: activeConfig.mqttPrefix,
                                      dynamicTopics: getDynamicDeviceTopicsList(
                                        activeConfig,
                                      ),
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
          ),
      ],
    );
  }
}
