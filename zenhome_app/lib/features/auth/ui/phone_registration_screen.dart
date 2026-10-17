import 'package:flutter/material.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';

/// Màn hình đăng ký số điện thoại - Hiện được hợp nhất liền mạch vào RegisterScreen với tab Số điện thoại
class PhoneRegistrationScreen extends StatelessWidget {
  const PhoneRegistrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RegisterScreen(initialTab: 1);
  }
}
