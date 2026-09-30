import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

class NotificationHistoryScreen extends ConsumerStatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  ConsumerState<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends ConsumerState<NotificationHistoryScreen> {
  String _selectedCategory = 'all';
  final List<String> _categories = ['all', 'important', 'schedule', 'timer', 'action', 'other'];

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
      icon: Icons.delete_sweep,
      onConfirm: () async {
        await ref.read(notificationProvider.notifier).clearAll();
      },
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case 'important': return Icons.warning_rounded;
      case 'schedule': return Icons.schedule_rounded;
      case 'timer': return Icons.timer_rounded;
      case 'action': return Icons.touch_app_rounded;
      default: return Icons.notifications;
    }
  }

  Color _getColorForCategory(String? category) {
    switch (category) {
      case 'important': return Colors.red;
      case 'schedule': return Colors.green;
      case 'timer': return Colors.orange;
      case 'action': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'all': return context.tr('all');
      case 'important': return context.tr('important');
      case 'schedule': return context.tr('schedule');
      case 'timer': return context.tr('timer');
      case 'action': return context.tr('action');
      case 'other': return context.tr('other');
      default: return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final notifications = ref.watch(notificationProvider);
    List<Map<String, dynamic>> filteredNotifs = _selectedCategory == 'all' 
      ? notifications 
      : notifications.where((n) => (n['category'] ?? 'other') == _selectedCategory).toList();

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121827) : Colors.white,
        appBar: AppBar(
          title: Text(context.tr('notification_history_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            if (notifications.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                tooltip: context.tr('clear_all'),
                onPressed: _clearHistory,
              )
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: const Color(0xFF2A3A7C),
            labelColor: isDark ? Colors.white : const Color(0xFF2A3A7C),
            unselectedLabelColor: Colors.grey,
            onTap: (index) {
              setState(() {
                _selectedCategory = _categories[index];
              });
            },
            tabs: _categories.map((c) => Tab(text: _getCategoryName(c))).toList(),
          ),
        ),
        body: filteredNotifs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 20),
                    Text(context.tr('no_notifications'), style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  ],
                ).animate().scale(),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: filteredNotifs.length,
                itemBuilder: (context, index) {
                  final notif = filteredNotifs[index];
                  DateTime time = DateTime.fromMillisecondsSinceEpoch(notif['timestamp'] ?? 0);
                  String formattedTime = DateFormat('dd/MM/yyyy HH:mm').format(time);
                  
                  bool isRead = notif['isRead'] ?? true;
                  
                  return Card(
                    elevation: isDark ? 0 : 2,
                    color: isDark ? const Color(0xFF1A2235) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: isRead ? BorderSide.none : const BorderSide(color: Color(0xFF2A3A7C), width: 1.5),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getColorForCategory(notif['category']).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getIconForCategory(notif['category']), color: _getColorForCategory(notif['category'])),
                      ),
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(notif['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 16)),
                          ),
                          if (notif['homeId'] != null && notif['homeId'].toString().isNotEmpty && notif['homeId'] != ref.read(homeConfigProvider).activeConfig.userId)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.purple.withOpacity(0.3)),
                              ),
                              child: Text(context.tr('shared_home') ?? 'Shared Home', style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(notif['body'] ?? '', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black87, height: 1.3)),
                          const SizedBox(height: 8),
                          Text(formattedTime, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                  ).animate().slideX(begin: 0.1, delay: Duration(milliseconds: index * 50));
                },
              ),
      ),
    );
  }
}
