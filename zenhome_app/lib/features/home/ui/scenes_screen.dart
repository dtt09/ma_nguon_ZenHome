import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/home/ui/scene_section.dart';
import 'package:zenhome_app/features/home/ui/timer_section.dart';
import 'package:zenhome_app/features/home/ui/schedule_section.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class ScenesScreen extends ConsumerStatefulWidget {
  const ScenesScreen({super.key});

  @override
  ConsumerState<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends ConsumerState<ScenesScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _selectedTabIndex = 0; // 0: Ngữ cảnh (Scenes), 1: Tự động hóa (Automations)

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isLocalAvailable = ref.watch(isLocalNetworkAvailableProvider).value ?? ref.watch(localNetworkServiceProvider).isLocalAvailable;
    final mqttState = ref.watch(mqttConnectionStateProvider);
    final isOnline = ref.watch(espOnlineStateProvider);
    final isUnlinked = activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty;
    final isConnected = (isLocalAvailable || (mqttState == 2 && isOnline)) && !isUnlinked;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    // Status chip configuration
    String statusLabel;
    Color statusColor;
    if (isUnlinked) {
      statusLabel = context.tr('unlinked') ?? 'Chưa l.kết';
      statusColor = zen.warning;
    } else if (isLocalAvailable) {
      statusLabel = 'Local ⚡';
      statusColor = zen.success;
    } else if (mqttState == 2 && isOnline) {
      statusLabel = 'Cloud';
      statusColor = zen.info;
    } else {
      statusLabel = context.tr('offline') ?? 'Offline';
      statusColor = zen.danger;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // LỚP NỘI DUNG NỀN (BỊ KHÓA HOÀN TOÀN TƯƠNG TÁC KHI CHƯA LIÊN KẾT HOẶC OFFLINE)
            IgnorePointer(
              ignoring: !isConnected,
              child: RefreshIndicator(
                color: isDark ? zen.primaryAccent : zen.primary,
                backgroundColor: isDark ? const Color(0xFF0E1628) : Colors.white,
                onRefresh: () async {
                  await ref.read(homeConfigProvider).syncFromFirestore();
                  final activeConfig = ref.read(homeConfigProvider).activeConfig;
                  ref.read(localNetworkServiceProvider).checkConnectivity();
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
                child: AnimatedOpacity(
                  opacity: isConnected ? 1.0 : 0.25,
                  duration: const Duration(milliseconds: 300),
                  child: ListView(
                    physics: isConnected
                        ? const AlwaysScrollableScrollPhysics()
                        : const NeverScrollableScrollPhysics(), // KHÓA CUỘN KHI OFFLINE/CHƯA LIÊN KẾT
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 18.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Dynamic Header Glass Icon Badge
                            ZenLiquidGlass(
                              width: 48,
                              height: 48,
                              borderRadius: 16,
                              blurSigma: 12,
                              glowColor: zen.primary,
                              surfaceColor: zen.primary.withOpacity(isDark ? 0.20 : 0.12),
                              customGradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  zen.primary.withOpacity(isDark ? 0.32 : 0.20),
                                  zen.primaryAccent.withOpacity(isDark ? 0.12 : 0.06),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                transitionBuilder: (child, anim) => ScaleTransition(
                                  scale: anim,
                                  child: FadeTransition(opacity: anim, child: child),
                                ),
                                child: Icon(
                                  _selectedTabIndex == 0
                                      ? Icons.auto_awesome_rounded
                                      : Icons.alarm_on_rounded,
                                  key: ValueKey<int>(_selectedTabIndex),
                                  color: isDark ? zen.primaryAccent : zen.primary,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedTabIndex == 0
                                        ? context.tr('tab_scenes')
                                        : context.tr('tab_automation'),
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: isDark ? AppColors.darkText : AppColors.lightText,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _selectedTabIndex == 0
                                        ? context.tr('scenes_subtitle')
                                        : context.tr('automation_subtitle'),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Connection Status Chip (Zen Glass Pill)
                            ZenGlassPill(
                              color: statusColor,
                              glowColor: statusColor,
                              isSelected: true,
                              blurSigma: 10,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
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
                                  const SizedBox(width: 6),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(duration: 350.ms).slideY(begin: -0.1),

                      // Segmented Switcher Bar Đồng Bộ Menu Chính (Zen Glass Segmented Bar 2.0)
                      ZenGlassSegmentedBar<int>(
                        height: 44,
                        borderRadius: 30,
                        margin: const EdgeInsets.only(bottom: 22),
                        padding: const EdgeInsets.all(4),
                        blurSigma: 22,
                        selectedValue: _selectedTabIndex,
                        onValueChanged: (val) {
                          setState(() => _selectedTabIndex = val);
                        },
                        items: [
                          ZenGlassSegmentedItem<int>(
                            value: 0,
                            label: context.tr('tab_scenes'),
                            icon: Icons.auto_awesome_rounded,
                            activeGlowColor: zen.primaryAccent,
                          ),
                          ZenGlassSegmentedItem<int>(
                            value: 1,
                            label: context.tr('tab_automation'),
                            icon: Icons.alarm_on_rounded,
                            activeGlowColor: zen.primaryAccent,
                          ),
                        ],
                      ),

                      // Tab 0: Ngữ cảnh
                      if (_selectedTabIndex == 0) ...[
                        RepaintBoundary(
                          child: const SceneSection()
                              .animate()
                              .fade(duration: 300.ms)
                              .slideY(begin: 0.05),
                        ),
                      ],

                      // Tab 1: Tự động hóa (Hẹn giờ & Lịch trình)
                      if (_selectedTabIndex == 1) ...[
                        RepaintBoundary(
                          child: Column(
                            children: [
                              const TimerSection()
                                  .animate()
                                  .fade(duration: 300.ms)
                                  .slideY(begin: 0.05),
                              const SizedBox(height: 24),
                              const ScheduleSection()
                                  .animate(delay: 100.ms)
                                  .fade(duration: 300.ms)
                                  .slideY(begin: 0.05),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),

            // LỚP KHÓA CỐ ĐỊNH CHỐNG VUỐT/CHỐNG TRƯỢT (KHI CHƯA LIÊN KẾT HOẶC OFFLINE)
            if (!isConnected)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // CHẶN TOÀN BỘ CỬ CHỈ CHẠM XUYÊN QUA
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.30),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ZenLiquidGlass(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                          borderRadius: 28,
                          blurSigma: 24,
                          rimWidth: 1.4,
                          glowColor: isUnlinked ? zen.warning : zen.danger,
                          surfaceColor: isDark
                              ? const Color(0xFF0C1426).withOpacity(0.78)
                              : Colors.white.withOpacity(0.84),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Glowing Icon Container
                              ZenLiquidGlass(
                                width: 68,
                                height: 68,
                                borderRadius: 34,
                                blurSigma: 0,
                                glowColor: isUnlinked ? zen.warning : zen.danger,
                                surfaceColor: (isUnlinked ? zen.warning : zen.danger)
                                    .withOpacity(isDark ? 0.18 : 0.12),
                                alignment: Alignment.center,
                                child: Icon(
                                  isUnlinked ? Icons.link_off_rounded : Icons.cloud_off_rounded,
                                  size: 34,
                                  color: isUnlinked ? zen.warning : zen.danger,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                isUnlinked
                                    ? context.tr('device_not_linked_title')
                                    : context.tr('device_offline_title'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                isUnlinked
                                    ? context.tr('device_not_linked_desc')
                                    : context.tr('device_offline_desc'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ZenGlassButton(
                                  label: isUnlinked
                                      ? context.tr('btn_setup_hub')
                                      : context.tr('btn_reconnect'),
                                  icon: isUnlinked ? Icons.settings_remote_rounded : Icons.refresh_rounded,
                                  isPrimary: true,
                                  accentColor: isUnlinked ? zen.warning : zen.primary,
                                  onPressed: () {
                                    if (isUnlinked) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const WifiSetupScreen()),
                                      );
                                    } else {
                                      ref.read(localNetworkServiceProvider).discoverHub(force: true);
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
                                  },
                                ),
                              ),
                            ],
                          ),
                        ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
