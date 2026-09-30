import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<Map<String, dynamic>>>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  NotificationNotifier() : super([]) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> hist = prefs.getStringList('notification_history') ?? [];
    
    final parsed = hist.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    parsed.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    
    state = parsed;
  }

  Future<void> addNotification(String title, String body, String category, [String homeId = '']) async {
    final nowTime = DateTime.now().millisecondsSinceEpoch;
    
    // Check duplicates
    if (state.isNotEmpty) {
      final lastNotif = state.first;
      if (lastNotif['title'] == title && lastNotif['body'] == body) {
        if (nowTime - (lastNotif['timestamp'] as int) < 5000) {
          return; // Duplicate
        }
      }
    }
    
    final newNotif = {
      'title': title,
      'body': body,
      'timestamp': nowTime,
      'isRead': false,
      'category': category,
      'homeId': homeId,
    };
    
    final newState = [newNotif, ...state];
    if (newState.length > 100) {
      newState.removeLast();
    }
    
    state = newState;
    await _saveToStorage(newState);
    
    // Show local notification
    NotificationHelper.showLocalNotification(title, body);
  }

  Future<void> markAllAsRead() async {
    final newState = state.map((n) {
      final Map<String, dynamic> copy = Map.from(n);
      copy['isRead'] = true;
      return copy;
    }).toList();
    
    state = newState;
    await _saveToStorage(newState);
  }

  Future<void> clearAll() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
  }

  Future<void> _saveToStorage(List<Map<String, dynamic>> list) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = list.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('notification_history', stringList);
  }
}
