import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:zenhome_app/core/services/logger_service.dart';
import 'package:zenhome_app/core/services/crash_sync_service.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/onboarding/ui/splash_screen.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:zenhome_app/core/services/connectivity_service.dart';
import 'package:zenhome_app/core/widgets/animations/telegram_theme_transition.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  final notifTitle = message.notification?.title ?? message.data['title']?.toString();
  final notifBody = message.notification?.body ?? message.data['body']?.toString();
  LoggerService.i("[CHẠY NGẦM] Nhận thông báo: $notifTitle");
  
  if (notifTitle != null || message.notification != null || message.data.isNotEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> hist = prefs.getStringList('notification_history') ?? [];
      final newNotif = {
        'title': notifTitle ?? 'ZenHome Notification',
        'body': notifBody ?? '',
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
    LoggerService.w("⚠️ CẢNH BÁO BẢO MẬT: Phát hiện thiết bị đã bị Root / Jailbreak!");
    // Kích hoạt cơ chế bảo vệ theo thuyết minh: Thoát ứng dụng khi ở bản Release Mode
    if (!kDebugMode) {
      exit(0);
    }
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
  
  // Tùy biến ErrorWidget chuẩn xác: Debug hiện thông tin chi tiết; Release hiện lỗi giao diện đúng ngữ nghĩa (không gây hiểu nhầm mất Wifi)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      return ErrorWidget(details.exception);
    }
    return Material(
      color: const Color(0xFF0F172A),
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
                    color: const Color(0xFFF43F5E).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFF43F5E)),
                ),
                const SizedBox(height: 20),
                Text(
                  PlatformDispatcher.instance.locale.languageCode == 'vi' ? 'Đã xảy ra lỗi giao diện' : 'UI Display Error',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  PlatformDispatcher.instance.locale.languageCode == 'vi'
                      ? 'Thành phần giao diện gặp sự cố tạm thời. Vui lòng khởi động lại ứng dụng.'
                      : 'An interface component encountered an error. Please restart the app.',
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
    
    unawaited(CrashSyncService.initialize());
    FlutterError.onError = CrashSyncService.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      final errStr = error.toString();
      final isNetwork = error is SocketException || 
                        error is HttpException || 
                        errStr.contains('SocketException') || 
                        errStr.contains('HandshakeException') ||
                        errStr.contains('Software caused connection abort') ||
                        errStr.contains('ConnectionException') ||
                        errStr.contains('Failed host lookup') ||
                        errStr.contains('Operation not permitted') ||
                        errStr.contains('Network is unreachable');
      CrashSyncService.recordCrash(
        error, 
        stack, 
        fatal: !isNetwork, 
        severity: isNetwork ? 'warning' : 'fatal',
        reason: isNetwork ? 'Sự cố ngắt kết nối mạng / Chuyển đổi Wi-Fi' : null,
      );
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
          child: TelegramThemeTransition(
            child: child ?? const SizedBox(),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
