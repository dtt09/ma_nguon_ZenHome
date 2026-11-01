import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Dịch vụ Đồng bộ Hóa Crashlytics & Firestore Realtime (Dual-Reporting Service)
/// Đảm bảo mọi lỗi runtime / fatal crash của ứng dụng di động Flutter đều được:
/// 1. Ghi nhận lên Google Firebase Crashlytics Console
/// 2. Đồng thời lưu trữ có cấu trúc lên Firestore collection `crash_logs` & `users/{userId}/crash_logs`
///    giúp Website Admin Dashboard hiển thị và cảnh báo Realtime ngay lập tức.
class CrashSyncService {
  static const _storage = FlutterSecureStorage();
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static String _deviceModel = 'Unknown Device';
  static String _osVersion = 'Unknown OS';
  static String _appVersion = '1.7.9';
  static int _buildNumber = 179;
  static bool _metadataInitialized = false;

  // Bộ đệm chống spam lỗi lặp lại liên tục (Throttling / Debounce trong 15s)
  static final Map<String, int> _recentErrors = {};
  static const int _debounceMs = 15000;

  /// Khởi tạo và nạp thông tin thiết bị ngầm
  static Future<void> initialize() async {
    if (_metadataInitialized) return;
    try {
      // 1. Lấy thông tin phiên bản ứng dụng
      try {
        final pkg = await PackageInfo.fromPlatform();
        _appVersion = pkg.version.isNotEmpty ? pkg.version : '1.7.9';
        _buildNumber = int.tryParse(pkg.buildNumber) ?? 179;
      } catch (_) {
        _appVersion = '1.7.9';
        _buildNumber = 179;
      }

      // 2. Lấy thông tin phần cứng thiết bị
      try {
        if (Platform.isAndroid) {
          final info = await _deviceInfoPlugin.androidInfo;
          _deviceModel = '${info.manufacturer} ${info.model}'.trim();
          _osVersion = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
        } else if (Platform.isIOS) {
          final info = await _deviceInfoPlugin.iosInfo;
          _deviceModel = info.utsname.machine.isNotEmpty ? info.utsname.machine : 'iPhone/iPad';
          _osVersion = '${info.systemName} ${info.systemVersion}';
        } else {
          _deviceModel = 'Desktop/Web Platform';
          _osVersion = Platform.operatingSystemVersion;
        }
      } catch (e) {
        _deviceModel = 'Mobile Device';
        _osVersion = 'OS';
      }

      _metadataInitialized = true;
    } catch (e) {
      debugPrint('[CRASH-SYNC] Lỗi khởi tạo metadata: $e');
    }
  }

  /// Bắt lỗi Flutter Fatal Error (gắn vào FlutterError.onError)
  static void recordFlutterFatalError(FlutterErrorDetails details) {
    // 1. Chuyển tiếp tới Firebase Crashlytics chính quy
    try {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    } catch (_) {}

    // 2. Đồng bộ Firestore Realtime
    recordCrash(
      details.exception,
      details.stack,
      reason: details.context?.toDescription() ?? details.summary.toString(),
      fatal: true,
      severity: 'fatal',
    );
  }

  /// Làm sạch thông tin nhạy cảm (mật khẩu, Wi-Fi, secret, tokens) trước khi gửi lên Cloud
  static String _sanitizeSensitive(String input) {
    if (input.isEmpty) return input;
    String sanitized = input;
    sanitized = sanitized.replaceAll(RegExp(r'(wifi_pass|admin_pass|password|pass|secret|token)\s*[:=]\s*[^\s,;"]+', caseSensitive: false), r'$1: ***REDACTED***');
    sanitized = sanitized.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-_\.]+', caseSensitive: false), 'Bearer ***REDACTED***');
    sanitized = sanitized.replaceAll(RegExp(r'"(wifi_pass|admin_pass|password|pass|token|secret)"\s*:\s*"[^"]*"', caseSensitive: false), r'"$1": "***REDACTED***"');
    return sanitized;
  }

  /// Ghi nhận và đồng bộ lỗi runtime/exception
  static Future<void> recordCrash(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    String? severity,
  }) async {
    if (error == null) return;

    final errorStr = error.toString();
    final reasonStr = reason ?? '';
    final dedupeKey = '${errorStr}_$reasonStr';
    final now = DateTime.now().millisecondsSinceEpoch;

    // Chống bão log (Throttling) nếu cùng 1 lỗi xuất hiện liên tiếp trong 15s
    if (_recentErrors.containsKey(dedupeKey)) {
      final lastTime = _recentErrors[dedupeKey]!;
      if (now - lastTime < _debounceMs) {
        return;
      }
    }
    _recentErrors[dedupeKey] = now;
    if (_recentErrors.length > 50) {
      _recentErrors.remove(_recentErrors.keys.first);
    }

    // Đảm bảo metadata đã nạp
    if (!_metadataInitialized) {
      await initialize();
    }

    // 1. Ghi nhận lên Firebase Crashlytics SDK
    try {
      if (Firebase.apps.isNotEmpty) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: reason,
          fatal: fatal,
        );
      }
    } catch (_) {}

    // 2. Thu thập ngữ cảnh người dùng
    String userId = 'guest';
    String userName = 'Người dùng ZenHome';
    String userEmail = '';

    try {
      // Ưu tiên Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        userId = user.uid;
        userName = user.displayName ?? (user.email?.split('@').first ?? user.uid);
        userEmail = user.email ?? '';
      }

      // Nếu chưa có, kiểm tra cấu hình home đã lưu
      if (userId == 'guest' || userId.isEmpty) {
        final activeHomeId = await _storage.read(key: 'active_home_id');
        if (activeHomeId != null && activeHomeId.isNotEmpty && activeHomeId != 'guest') {
          userId = activeHomeId;
          userName = activeHomeId;
        } else {
          final prefs = await SharedPreferences.getInstance();
          final prefHomeId = prefs.getString('active_home_id');
          if (prefHomeId != null && prefHomeId.isNotEmpty) {
            userId = prefHomeId;
            userName = prefHomeId;
          }
        }
      }
    } catch (_) {}

    // 3. Chuẩn hóa tiêu đề & stack trace
    String title = errorStr;
    if (title.contains(':')) {
      title = title.split(':').take(2).join(':').trim();
    }
    if (title.length > 120) {
      title = '${title.substring(0, 117)}...';
    }

    final stackTraceStr = stack?.toString() ?? StackTrace.current.toString();
    final effectiveSeverity = fatal ? 'fatal' : (severity ?? 'error');

    final payload = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'errorTitle': _sanitizeSensitive(title),
      'errorMessage': _sanitizeSensitive(errorStr),
      'stackTrace': _sanitizeSensitive(stackTraceStr),
      'severity': effectiveSeverity,
      'reason': _sanitizeSensitive(reasonStr),
      'deviceModel': _deviceModel,
      'osVersion': _osVersion,
      'appVersion': _appVersion,
      'buildNumber': _buildNumber,
      'isResolved': false,
      'source': 'flutter_app',
      'createdAt': DateTime.now().toIso8601String(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    // 4. Đồng bộ lên Cloud Firestore
    bool firestoreSaved = false;
    try {
      if (Firebase.apps.isNotEmpty) {
        // Ghi vào collection dùng chung cho toàn bộ Admin xem realtime
        final topRef = await FirebaseFirestore.instance
            .collection('crash_logs')
            .add(payload)
            .timeout(const Duration(seconds: 4));
        firestoreSaved = true;

        // Nếu có userId xác định, lưu cả vào subcollection của user
        if (userId.isNotEmpty && userId != 'guest') {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('crash_logs')
              .doc(topRef.id)
              .set(payload)
              .timeout(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('[CRASH-SYNC] Firestore write error: $e');
    }

    // 5. Fallback HTTP tới Backend Server nếu Firestore không ghi được (ví dụ do Rules hoặc Offline)
    if (!firestoreSaved) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final serverIp = prefs.getString('zenhome_server_ip') ?? '192.168.1.100';
        final url = Uri.parse('http://$serverIp:5000/api/v1/system/crash-logs');
        
        // Timeout 3s để không chặn luồng giao diện
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        // Hoàn toàn im lặng khi offline
      }
    }
  }

  /// Kích hoạt lỗi kiểm thử (Test Crash) phục vụ kiểm chứng đồng bộ hệ thống
  static Future<bool> sendTestCrash() async {
    try {
      await initialize();
      final testError = Exception('ZenHomeTestException: Kiểm thử đồng bộ Crashlytics Realtime từ Ứng dụng Di động');
      final testStack = StackTrace.current;
      await recordCrash(
        testError,
        testStack,
        reason: 'Sự cố thử nghiệm tạo từ chức năng Chẩn đoán của App ZenHome v$_appVersion',
        fatal: false,
        severity: 'warning',
      );
      return true;
    } catch (e) {
      debugPrint('[CRASH-SYNC] Lỗi tạo test crash: $e');
      return false;
    }
  }
}
