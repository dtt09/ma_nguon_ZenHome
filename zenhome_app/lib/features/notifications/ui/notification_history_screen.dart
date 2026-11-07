import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState
    extends ConsumerState<NotificationHistoryScreen> {
  String _selectedCategory = 'all';

  final List<String> _categories = const [
    'all',
    'update',
    'important',
    'schedule',
    'timer',
    'action',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).markAllAsRead();
    });
  }

  Future<void> _clearHistory() async {
    showPremiumConfirmDialog(
      context: context,
      title: context.tr('confirm_title'),
      message: context.tr('clear_history_confirm'),
      confirmText: context.tr('btn_yes'),
      cancelText: context.tr('btn_no'),
      isDanger: true,
      icon: Icons.delete_sweep_rounded,
      onConfirm: () async {
        await ref.read(notificationProvider.notifier).clearAll();
      },
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case 'update':
        return Icons.system_update_rounded;
      case 'important':
        return Icons.warning_amber_rounded;
      case 'schedule':
        return Icons.schedule_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'action':
        return Icons.touch_app_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getColorForCategory(BuildContext context, String? category) {
    switch (category) {
      case 'update':
        return context.zenColors.primary;
      case 'important':
        return AppColors.roseGlow;
      case 'schedule':
        return AppColors.emeraldGlow;
      case 'timer':
        return AppColors.amberGlow;
      case 'action':
        return AppColors.cyanGlow;
      default:
        return AppColors.purpleGlow;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'all':
        return context.tr('notification_category_all');
      case 'update':
        return context.tr('notification_category_update');
      case 'important':
        return context.tr('notification_category_important');
      case 'schedule':
        return context.tr('notification_category_schedule');
      case 'timer':
        return context.tr('notification_category_timer');
      case 'action':
        return context.tr('notification_category_action');
      case 'other':
        return context.tr('notification_category_other');
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final notifications = ref.watch(notificationProvider);
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;

    final List<Map<String, dynamic>> filteredNotifs = _selectedCategory == 'all'
        ? notifications
        : notifications
            .where((n) => (n['category'] ?? 'other') == _selectedCategory)
            .toList();

    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('notification_history_title'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18.5,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${notifications.length} ${context.tr('notification')}',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: mutedColor,
              ),
            ),
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            Center(
              child: ZenGlassPill(
                blurSigma: 0,
                isSelected: true,
                glowColor: AppColors.roseGlow,
                borderRadius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                onTap: _clearHistory,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_sweep_rounded,
                      color: AppColors.roseGlow,
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('clear_all'),
                      style: const TextStyle(
                        color: AppColors.roseGlow,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // Thanh Lọc Danh Mục Kính Lỏng (Liquid Glass Category Menu)
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                final Color pillColor = cat == 'all'
                    ? zen.primary
                    : _getColorForCategory(context, cat);

                return ZenGlassPill(
                  isSelected: isSelected,
                  glowColor: pillColor,
                  blurSigma: 14,
                  customGradient: isSelected && cat == 'all'
                      ? zen.brandHero
                      : (isSelected
                          ? LinearGradient(
                              colors: [
                                pillColor.withOpacity(0.92),
                                Color.lerp(pillColor, Colors.white, 0.16)!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null),
                  borderRadius: 16,
                  margin: const EdgeInsets.only(right: 9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (cat != 'all') ...[
                        Icon(
                          _getIconForCategory(cat),
                          size: 14.5,
                          color: isSelected ? Colors.white : pillColor,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _getCategoryName(cat),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkText
                                  : AppColors.lightText),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Danh sách Thẻ Thông Báo Kính Lỏng hoặc Màn hình Trống Pha Lê
          Expanded(
            child: filteredNotifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: ZenGlassCard(
                        borderRadius: 28,
                        blurSigma: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 34,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    zen.primary.withOpacity(0.20),
                                    zen.primaryAccent.withOpacity(0.06),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: zen.primary.withOpacity(0.32),
                                  width: 1.4,
                                ),
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 52,
                                color: isDark ? zen.primaryAccent : zen.primary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              context.tr('no_notifications'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr('empty_notification_desc'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fade(duration: 280.ms)
                          .scale(begin: const Offset(0.95, 0.95)),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: filteredNotifs.length,
                    itemBuilder: (context, index) {
                      final notif = filteredNotifs[index];
                      final cat = notif['category'] as String?;
                      final catColor = _getColorForCategory(context, cat);
                      final catIcon = _getIconForCategory(cat);

                      final DateTime time = DateTime.fromMillisecondsSinceEpoch(
                        notif['timestamp'] ?? 0,
                      );
                      final String formattedTime =
                          DateFormat('dd/MM/yyyy HH:mm').format(time);

                      final bool isRead = notif['isRead'] ?? true;
                      final bool isSharedHome = notif['homeId'] != null &&
                          notif['homeId'].toString().isNotEmpty &&
                          notif['homeId'] != activeConfig.userId;

                      return ZenGlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        borderRadius: 22,
                        blurSigma: 14,
                        isActive: !isRead,
                        glowColor: catColor,
                        padding: const EdgeInsets.all(15),
                        onTap: notif['category'] == 'update'
                            ? () {
                                AppUpdateService.checkAndPromptUpdate(
                                  context,
                                  isManualCheck: true,
                                );
                              }
                            : null,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Leading Glowing Squircle Icon
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    catColor.withOpacity(isDark ? 0.24 : 0.16),
                                    catColor.withOpacity(isDark ? 0.08 : 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      catColor.withOpacity(isDark ? 0.42 : 0.3),
                                  width: 1.15,
                                ),
                              ),
                              child: Icon(catIcon, color: catColor, size: 22),
                            ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w700
                                                : FontWeight.w800,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                      if (isSharedHome) ...[
                                        const SizedBox(width: 6),
                                        ZenGlassPill(
                                          blurSigma: 0,
                                          isSelected: true,
                                          glowColor: AppColors.purpleGlow,
                                          borderRadius: 8,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          child: Text(
                                            context.tr('shared_home_badge'),
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              color: AppColors.purpleGlow,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (!isRead) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 8.5,
                                          height: 8.5,
                                          decoration: BoxDecoration(
                                            color: catColor,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    catColor.withOpacity(0.85),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    notif['body'] ?? '',
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 13.2,
                                      height: 1.38,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.5,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: catColor
                                              .withOpacity(isDark ? 0.16 : 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: catColor.withOpacity(0.24),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          _getCategoryName(cat ?? 'other'),
                                          style: TextStyle(
                                            color: catColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 12,
                                            color: mutedColor.withOpacity(0.8),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color:
                                                  mutedColor.withOpacity(0.85),
                                              fontSize: 11.2,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().slideX(
                            begin: 0.06,
                            delay: Duration(
                              milliseconds: (index.clamp(0, 10)) * 28,
                            ),
                            duration: 240.ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
