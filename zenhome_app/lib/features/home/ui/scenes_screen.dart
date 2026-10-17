import 'dart:ui';
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

class ScenesScreen extends ConsumerStatefulWidget {
  const ScenesScreen({super.key});

  @override
  ConsumerState<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends ConsumerState<ScenesScreen> {
  int _selectedTabIndex = 0; // 0: Ngữ cảnh (Scenes), 1: Tự động hóa (Automations)

  @override
  Widget build(BuildContext context) {
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final mqttState = ref.watch(mqttConnectionStateProvider);
    final isOnline = ref.watch(espOnlineStateProvider);
    final isUnlinked = activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty;
    final isConnected = mqttState == 2 && isOnline && !isUnlinked;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Status chip configuration
    String statusLabel;
    Color statusColor;
    if (isUnlinked) {
      statusLabel = context.tr('unlinked');
      statusColor = const Color(0xFFF59E0B);
    } else if (isConnected) {
      statusLabel = context.tr('online');
      statusColor = AppColors.emeraldGlow;
    } else {
      statusLabel = context.tr('offline');
      statusColor = const Color(0xFFEF4444);
    }

    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // LỚP NỘI DUNG NỀN (BỊ KHÓA HOÀN TOÀN TƯƠNG TÁC KHI CHƯA LIÊN KẾT HOẶC OFFLINE)
          IgnorePointer(
            ignoring: !isConnected,
            child: RefreshIndicator(
              color: AppColors.primaryLight,
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedTabIndex == 0
                                      ? context.tr('tab_scenes')
                                      : context.tr('tab_automation'),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: isDark ? AppColors.darkText : AppColors.lightText,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedTabIndex == 0
                                      ? context.tr('scenes_subtitle')
                                      : context.tr('automation_subtitle'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Connection Status Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
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
                                        color: statusColor.withOpacity(0.5),
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
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fade(duration: 350.ms).slideY(begin: -0.1),

                    // Segmented Switcher Bar (Glassmorphic Sliding Indicator Pill - matching main_layout style)
                    Container(
                      margin: const EdgeInsets.only(bottom: 22),
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xCC111827) : const Color(0xDDFFFFFF),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: isDark ? const Color(0x33FFFFFF) : const Color(0x14000000),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          if (isDark)
                            BoxShadow(
                              color: AppColors.primaryLight.withOpacity(0.08),
                              blurRadius: 14,
                              offset: const Offset(0, -1),
                            ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Stack(
                            children: [
                              // Sliding Indicator Pill
                              Positioned.fill(
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                  alignment: _selectedTabIndex == 0
                                      ? Alignment.centerLeft
                                      : Alignment.centerRight,
                                  child: FractionallySizedBox(
                                    widthFactor: 0.5,
                                    child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        gradient: isDark
                                            ? LinearGradient(
                                                colors: [
                                                  AppColors.primaryLight.withOpacity(0.28),
                                                  AppColors.primaryAccent.withOpacity(0.14),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : LinearGradient(
                                                colors: [
                                                  AppColors.primary.withOpacity(0.14),
                                                  AppColors.primaryLight.withOpacity(0.08),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                        borderRadius: BorderRadius.circular(26),
                                        border: Border.all(
                                          color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.3),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.15),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Tab Items
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(32),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedTabIndex = 0);
                                      },
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            AnimatedScale(
                                              scale: _selectedTabIndex == 0 ? 1.1 : 0.95,
                                              duration: const Duration(milliseconds: 200),
                                              child: Icon(
                                                Icons.auto_awesome_rounded,
                                                size: 18,
                                                color: _selectedTabIndex == 0
                                                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: AnimatedDefaultTextStyle(
                                                duration: const Duration(milliseconds: 200),
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontWeight: _selectedTabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: _selectedTabIndex == 0
                                                      ? (isDark ? Colors.white : AppColors.primary)
                                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                ),
                                                child: Text(
                                                  context.tr('tab_scenes'),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(32),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _selectedTabIndex = 1);
                                      },
                                      child: Center(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            AnimatedScale(
                                              scale: _selectedTabIndex == 1 ? 1.1 : 0.95,
                                              duration: const Duration(milliseconds: 200),
                                              child: Icon(
                                                Icons.alarm_on_rounded,
                                                size: 18,
                                                color: _selectedTabIndex == 1
                                                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: AnimatedDefaultTextStyle(
                                                duration: const Duration(milliseconds: 200),
                                                style: TextStyle(
                                                  fontFamily: 'SF Pro Display',
                                                  fontWeight: _selectedTabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                                                  fontSize: 14,
                                                  color: _selectedTabIndex == 1
                                                      ? (isDark ? Colors.white : AppColors.primary)
                                                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                ),
                                                child: Text(
                                                  context.tr('tab_automation'),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
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
                    ),

                    // Tab 0: Ngữ cảnh
                    if (_selectedTabIndex == 0) ...[
                      const SceneSection().animate().fade(duration: 300.ms).slideY(begin: 0.05),
                    ],

                    // Tab 1: Tự động hóa (Hẹn giờ & Lịch trình)
                    if (_selectedTabIndex == 1) ...[
                      Column(
                        children: [
                          const TimerSection().animate().fade(duration: 300.ms).slideY(begin: 0.05),
                          const SizedBox(height: 24),
                          const ScheduleSection().animate(delay: 100.ms).fade(duration: 300.ms).slideY(begin: 0.05),
                        ],
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
                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.35),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131B2E) : Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isUnlinked
                              ? const Color(0xFFF59E0B).withOpacity(0.4)
                              : const Color(0xFFEF4444).withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.6 : 0.12),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glowing Icon Container
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (isUnlinked ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)).withOpacity(0.12),
                              border: Border.all(
                                color: (isUnlinked ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              isUnlinked ? Icons.link_off_rounded : Icons.cloud_off_rounded,
                              size: 34,
                              color: isUnlinked ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
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
                              color: isDark ? Colors.white : Colors.black87,
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
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: isUnlinked ? const Color(0xFFF59E0B) : const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 3,
                              ),
                              icon: Icon(isUnlinked ? Icons.settings_remote_rounded : Icons.refresh_rounded, size: 20),
                              label: Text(
                                isUnlinked
                                    ? context.tr('btn_setup_hub')
                                    : context.tr('btn_reconnect'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              onPressed: () {
                                if (isUnlinked) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const WifiSetupScreen()),
                                  );
                                } else {
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
    );
  }
}
