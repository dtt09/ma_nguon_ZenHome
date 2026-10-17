import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'dart:async';
import 'dart:convert';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:zenhome_app/core/services/logger_service.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/onboarding/ui/splash_screen.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:zenhome_app/core/services/connectivity_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  LoggerService.i("[CHẠY NGẦM] Nhận thông báo: ${message.notification?.title}");
  
  if (message.notification != null) {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> hist = prefs.getStringList('notification_history') ?? [];
      final newNotif = {
        'title': message.notification!.title ?? 'ZenHome Notification',
        'body': message.notification!.body ?? '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'isRead': false,
        'category': message.data['category'] ?? 'other',
        'homeId': message.data['homeId'] ?? '',
      };
      hist.insert(0, jsonEncode(newNotif));
      if (hist.length > 100) hist = hist.sublist(0, 100);
      await prefs.setStringList('notification_history', hist);
    } catch (e) {
      LoggerService.e('Lỗi lưu lịch sử thông báo background: $e');
    }
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bảo mật: Chống Root / Jailbreak
  bool jailbroken = false;
  try {
    jailbroken = await JailbreakRootDetection.instance.isJailBroken;
  } catch (e) {
    jailbroken = false;
  }
  if (jailbroken) {
    // Tùy chọn: Thoát ứng dụng nếu phát hiện thiết bị bị bẻ khóa
    // exit(0); 
    // Tuy nhiên ở bản Dev ta chỉ log ra:
    print("⚠️ THIẾT BỊ ĐÃ BỊ ROOT / JAILBREAK!");
  }
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
  
  // FIX 1: Bọc try-catch cho dotenv để không sập app nếu mất file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("⚠️ Không tìm thấy file .env hoặc cấu hình thiếu trong assets.");
  }

  final container = ProviderContainer();
  await container.read(homeConfigProvider).loadConfigFromStorage();
  final activeConfig = container.read(homeConfigProvider).activeConfig;

  await NotificationHelper.init();
  
  // Dọn dẹp an toàn các file APK rác trong cache (nếu vừa nâng cấp phiên bản)
  AppUpdateService.cleanOldApkFiles();
  
  // Tùy biến ErrorWidget để không bao giờ hiện màn hình trắng xóa nếu có lỗi ngoại lệ hoặc mạng
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF081210),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.amberGlow),
                ),
                const SizedBox(height: 20),
                Text(
                  PlatformDispatcher.instance.locale.languageCode == 'vi' ? 'Không thể tải nội dung' : 'Unable to load content',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  PlatformDispatcher.instance.locale.languageCode == 'vi'
                      ? 'Vui lòng kiểm tra lại kết nối mạng Wifi/4G và mở lại ứng dụng.'
                      : 'Please check your network connection and restart the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 3));
    
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        container.read(notificationProvider.notifier).addNotification(
          message.notification!.title ?? 'ZenHome Notification',
          message.notification!.body ?? '',
          message.data['category'] ?? 'other',
          message.data['homeId'] ?? '',
        );
      }
    });

    // Chạy ngầm việc cấp quyền và subscribe topic FCM không chặn khởi động app khi mất mạng
    unawaited(() async {
      try {
        await messaging.requestPermission(alert: true, badge: true, sound: true).timeout(const Duration(seconds: 2));
        final prefs = await SharedPreferences.getInstance();
        final lang = prefs.getString('language') ?? (PlatformDispatcher.instance.locale.languageCode == 'vi' ? 'vi' : 'en');
        await messaging.subscribeToTopic('all_users').timeout(const Duration(seconds: 2));
        if (lang == 'en') {
          await messaging.subscribeToTopic('all_users_en').timeout(const Duration(seconds: 2));
          await messaging.unsubscribeFromTopic('all_users_vi').timeout(const Duration(seconds: 2));
        } else {
          await messaging.subscribeToTopic('all_users_vi').timeout(const Duration(seconds: 2));
          await messaging.unsubscribeFromTopic('all_users_en').timeout(const Duration(seconds: 2));
        }
      } catch (_) {}
    }());

    if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
      LoggerService.i("FCM Token-based routing enabled for user: ${activeConfig.userId}");
    }
  } catch (e, stack) {
    LoggerService.e("⚠️ [OFFLINE MODE] App khởi động không cần mạng", e, stack);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZenHomeApp(),
    ),
  );
}

class ZenHomeApp extends ConsumerWidget {
  const ZenHomeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeNotifierProvider);
    final locale = ref.watch(localeNotifierProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: currentMode,
      
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      builder: (context, child) {
        return ConnectivityBannerWrapper(
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
