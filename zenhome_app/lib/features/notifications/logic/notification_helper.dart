import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

      final AndroidNotificationChannel downloadChannel = const AndroidNotificationChannel(
        'zenhome_download_channel',
        'Zen Home Downloads',
        description: 'Thông báo tiến trình tải bản cập nhật Zen Home',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      final androidPlugin = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        await androidPlugin.createNotificationChannel(downloadChannel);
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      // Ignored
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
    
    try {
      await _notificationsPlugin.show(
        id: DateTime.now().millisecond,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      // Ignored if permissions not granted
    }
  }

  static const int downloadNotificationId = 8888;

  static Future<void> showDownloadProgressNotification({
    int id = downloadNotificationId,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    bool indeterminate = false,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'zenhome_download_channel',
        'Zen Home Downloads',
        channelDescription: 'Thông báo tiến trình tải bản cập nhật Zen Home',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        indeterminate: indeterminate,
        ongoing: true,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
      );
      final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
      
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
      );
    } catch (e) {
      // Don't let notification issues block download progress
    }
  }

  static Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (_) {}
  }
}