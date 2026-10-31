import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';

/// SecureScreen wrapper widget
/// Automatically applies FLAG_SECURE on Android / iOS to prevent screenshots,
/// screen recording, and task switcher preview leaks on sensitive views (SEC-FIND-08).
class SecureScreen extends StatefulWidget {
  final Widget child;
  
  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  void initState() {
    super.initState();
    _enableScreenSecurity();
  }

  Future<void> _enableScreenSecurity() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disableScreenSecurity();
    super.dispose();
  }

  Future<void> _disableScreenSecurity() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
