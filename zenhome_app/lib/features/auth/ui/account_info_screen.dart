import 'package:flutter/material.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';

/// AccountInfoScreen is now unified into ProfileScreen.
/// This widget acts as a direct alias so existing routes remain 100% compatible.
class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
