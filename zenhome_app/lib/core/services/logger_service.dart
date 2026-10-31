import 'package:flutter/foundation.dart';
import 'package:zenhome_app/core/services/crash_sync_service.dart';

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
    
    // Đồng bộ lỗi tự động qua CrashSyncService tới cả Firebase Crashlytics & Cloud Firestore
    try {
      CrashSyncService.recordCrash(
        error ?? message,
        stackTrace,
        reason: message,
        fatal: false,
        severity: 'error',
      );
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
