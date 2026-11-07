import 'package:flutter/material.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';

/// AccountInfoScreen is unified into ProfileScreen (Zen Liquid Glass 2.0).
/// This widget acts as a direct alias so existing routes remain 100% compatible.
class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}
