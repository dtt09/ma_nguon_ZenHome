import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: initSettingsAndroid);
    
    try {
      await _notificationsPlugin.initialize(settings: initSettings);
      
      final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500]);
      
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'zenhome_channel_id',
        'Zen Home Notifications',
        description: 'Kênh thông báo cho Zen Home',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
      );

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e, stack) {
      print('NotificationHelper init error: $e');
    }
  }

  static Future<void> showLocalNotification(String title, String body) async {
    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500]);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'zenhome_channel_id',
      'Zen Home Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibrationPattern,
    );
    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    await _notificationsPlugin.show(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }
}