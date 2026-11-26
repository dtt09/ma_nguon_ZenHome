import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';

/// Reference-counted screen protection helper for Android/iOS FLAG_SECURE.
///
/// Ensures popping one protected route does not clear FLAG_SECURE while another
/// protected route remains mounted in the navigation stack.
class SecureWindowHelper {
  SecureWindowHelper._();

  static int _activeLocks = 0;

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> acquire() async {
    if (!isSupportedPlatform) return;
    _activeLocks++;
    if (_activeLocks == 1) {
      try {
        await FlutterWindowManagerPlus.addFlags(
          FlutterWindowManagerPlus.FLAG_SECURE,
        );
      } catch (_) {}
    }
  }

  static Future<void> release() async {
    if (!isSupportedPlatform) return;
    if (_activeLocks <= 0) {
      _activeLocks = 0;
      return;
    }
    _activeLocks--;
    if (_activeLocks == 0) {
      try {
        await FlutterWindowManagerPlus.clearFlags(
          FlutterWindowManagerPlus.FLAG_SECURE,
        );
      } catch (_) {}
    }
  }
}
