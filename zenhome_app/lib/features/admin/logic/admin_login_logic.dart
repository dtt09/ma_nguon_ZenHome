import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

class AdminLoginState {
  final bool isError;
  const AdminLoginState({this.isError = false});
}

class AdminLoginNotifier extends StateNotifier<AdminLoginState> {
  AdminLoginNotifier() : super(const AdminLoginState());

  bool verifyPassword(WidgetRef ref, String password) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    if (password == activeConfig.adminPass) {
      state = const AdminLoginState(isError: false);
      return true;
    } else {
      state = const AdminLoginState(isError: true);
      return false;
    }
  }
}

final adminLoginProvider = StateNotifierProvider<AdminLoginNotifier, AdminLoginState>((ref) {
  return AdminLoginNotifier();
});
