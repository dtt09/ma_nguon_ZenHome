import 'package:flutter/material.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';

/// Màn hình đăng ký số điện thoại (Zen Liquid Glass 2.0)
/// Được hợp nhất liền mạch vào RegisterScreen với phân hệ Số điện thoại (initialTab: 1).
class PhoneRegistrationScreen extends StatelessWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RegisterScreen(initialTab: 1);
  }
}
