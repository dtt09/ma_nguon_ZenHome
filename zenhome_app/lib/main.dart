import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'dart:io';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/services/logger_service.dart';
import 'package:zenhome_app/core/utils/helpers.dart';   
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/home/ui/dashboard_screen.dart';
import 'package:zenhome_app/features/home/ui/scenes_screen.dart';
import 'package:zenhome_app/features/settings/ui/settings_screen.dart';
import 'package:zenhome_app/features/onboarding/ui/splash_screen.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';

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
  
  try {
    await Firebase.initializeApp();
    
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    
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
    
    if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
      // Previously handled topic subscriptions here. Now using token-based FCM routing.
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
      
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A3A7C), brightness: Brightness.light),
        useMaterial3: true,
        fontFamily: 'Roboto',

      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5C8CFF), brightness: Brightness.dark),
        useMaterial3: true,
        fontFamily: 'Roboto',

      ),
      home: const SplashScreen(),
    );
  }
}
