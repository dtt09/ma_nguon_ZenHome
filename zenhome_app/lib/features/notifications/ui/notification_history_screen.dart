import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends ConsumerState<NotificationHistoryScreen> {
  String _selectedCategory = 'all';

  final List<String> _categories = [
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

  Color _getColorForCategory(String? category) {
    switch (category) {
      case 'update':
        return AppColors.primaryLight;
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationProvider);
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;

    List<Map<String, dynamic>> filteredNotifs = _selectedCategory == 'all'
        ? notifications
        : notifications.where((n) => (n['category'] ?? 'other') == _selectedCategory).toList();

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardElevated : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('notification_history_title'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '${notifications.length} ${context.tr('notification')}',
              style: TextStyle(fontSize: 11, color: mutedColor),
            ),
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _clearHistory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.roseGlow.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.roseGlow.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_sweep_rounded, color: AppColors.roseGlow, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('clear_all'),
                        style: const TextStyle(
                          color: AppColors.roseGlow,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // Luxury Category Pill Selector (Horizontal Scroll)
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

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.brandHero : null,
                        color: isSelected
                            ? null
                            : (isDark ? AppColors.darkCardElevated : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primaryAccent
                              : borderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          _getCategoryName(cat),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Notifications List or Empty State
          Expanded(
            child: filteredNotifs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.12),
                                  AppColors.primaryLight.withOpacity(0.04),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 56,
                              color: AppColors.primaryLight.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            context.tr('no_notifications'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('empty_notification_desc'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: mutedColor, fontSize: 13, height: 1.4),
                          ),
                        ],
                      ).animate().fade(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filteredNotifs.length,
                    itemBuilder: (context, index) {
                      final notif = filteredNotifs[index];
                      final cat = notif['category'] as String?;
                      final catColor = _getColorForCategory(cat);
                      final catIcon = _getIconForCategory(cat);

                      DateTime time = DateTime.fromMillisecondsSinceEpoch(notif['timestamp'] ?? 0);
                      String formattedTime = DateFormat('dd/MM/yyyy HH:mm').format(time);

                      bool isRead = notif['isRead'] ?? true;
                      bool isSharedHome = notif['homeId'] != null &&
                          notif['homeId'].toString().isNotEmpty &&
                          notif['homeId'] != activeConfig.userId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isRead ? borderColor : AppColors.primaryLight.withOpacity(0.5),
                            width: isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.18 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              if (notif['category'] == 'update') {
                                AppUpdateService.checkAndPromptUpdate(context, isManualCheck: true);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leading Category Icon in Squircle
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: catColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: catColor.withOpacity(0.25)),
                                    ),
                                    child: Icon(catIcon, color: catColor, size: 22),
                                  ),
                                  const SizedBox(width: 14),

                                  // Content Body
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Title + Shared badge + unread dot
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                notif['title'] ?? '',
                                                style: TextStyle(
                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                  fontSize: 15,
                                                  color: textColor,
                                                ),
                                              ),
                                            ),
                                            if (isSharedHome) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.purpleGlow.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: AppColors.purpleGlow.withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  context.tr('shared_home_badge'),
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    color: AppColors.purpleGlow,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (!isRead) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.primaryLight.withOpacity(0.8),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 5),

                                        // Body Text
                                        Text(
                                          notif['body'] ?? '',
                                          style: TextStyle(
                                            color: mutedColor,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Footer row: Category tag & Timestamp
                                        Row(
                                          children: [
                                            // Category Pill
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: catColor.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _getCategoryName(cat ?? 'other'),
                                                style: TextStyle(
                                                  color: catColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            // Timestamp
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.access_time_rounded, size: 12, color: mutedColor.withOpacity(0.7)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  formattedTime,
                                                  style: TextStyle(
                                                    color: mutedColor.withOpacity(0.7),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
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
                            ),
                          ),
                        ),
                      ).animate().slideX(
                            begin: 0.08,
                            delay: Duration(milliseconds: (index.clamp(0, 10)) * 30),
                            duration: 250.ms,
                          );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
