import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<Map<String, dynamic>>>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  // SEC-FIX [ZH-MED-20]: Bảo mật lịch sử thông báo bằng Hardware Keystore
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  NotificationNotifier() : super([]) {
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    try {
      final secureData = await _storage.read(key: 'secure_notification_history');
      if (secureData != null && secureData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(secureData);
        final parsed = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        parsed.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        state = parsed;
        return;
      }
    } catch (_) {}

    // Migration fallback từ SharedPreferences cũ
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> hist = prefs.getStringList('notification_history') ?? [];
      if (hist.isNotEmpty) {
        final parsed = hist.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
        parsed.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
        state = parsed;
        await _saveToStorage(parsed);
        await prefs.remove('notification_history');
        return;
      }
    } catch (_) {}

    state = [];
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
    await _storage.delete(key: 'secure_notification_history');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_history');
    } catch (_) {}
  }

  Future<void> _saveToStorage(List<Map<String, dynamic>> list) async {
    try {
      await _storage.write(key: 'secure_notification_history', value: jsonEncode(list));
    } catch (_) {}
  }
}
