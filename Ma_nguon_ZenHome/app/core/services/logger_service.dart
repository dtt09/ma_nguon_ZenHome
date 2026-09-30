import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart'; // Thêm cái này
import 'package:flutter/foundation.dart';

class LoggerService {
  static void i(String message) {
    if (kDebugMode) {
      print('💡 [INFO]: $message');
    }
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('🚨 [ERROR]: $message');
      if (error != null) print(error);
      if (stackTrace != null) print(stackTrace);
    }
    
    // FIX 2: Bắt buộc check Firebase đã sống chưa rồi mới gửi Crashlytics
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(
          error ?? message,
          stackTrace,
          reason: message,
          fatal: false,
        );
      }
    } catch (e) {
      debugPrint('Logger error: $e');
    }
  }

  static void w(String message) {
    if (kDebugMode) {
      print('⚠️ [WARNING]: $message');
    }
  }
}