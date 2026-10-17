import 'package:flutter/material.dart';

/// SecureScreen wrapper widget
/// Placeholder for screen security flags without external uninstalled dependencies
class SecureScreen extends StatefulWidget {
  final Widget child;
  
  const SecureScreen({super.key, required this.child});

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
