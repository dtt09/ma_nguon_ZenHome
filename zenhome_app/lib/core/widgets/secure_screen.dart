import 'package:flutter/material.dart';
import 'package:zenhome_app/core/utils/secure_window_helper.dart';

/// SecureScreen wrapper widget.
/// Applies reference-counted FLAG_SECURE on Android / iOS to prevent
/// screenshots, screen recording, and task switcher leaks on sensitive views.
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
    SecureWindowHelper.acquire();
  }

  @override
  void dispose() {
    SecureWindowHelper.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
