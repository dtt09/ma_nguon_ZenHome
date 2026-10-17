import 'dart:io';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/features/admin/logic/admin_login_logic.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final TextEditingController _passController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    _passController.dispose();
    super.dispose();
  }

  void _login() {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    if (activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty) {
      showFloatingToast(context, context.tr('warning'), context.tr('err_not_linked_esp32'), isError: true);
    }

    final isSuccess = ref.read(adminLoginProvider.notifier).verifyPassword(ref, _passController.text);
    if (isSuccess) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DeviceMappingScreen()),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 80, color: Color(0xFF0F766E)),
                const SizedBox(height: 20),
                Text(context.tr('admin_login_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(context.tr('admin_login_desc'), style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
                const SizedBox(height: 30),
                
                // Đã sửa thành OutlineInputBorder
                TextField(
                  controller: _passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.tr('password'),
                    errorText: ref.watch(adminLoginProvider).isError ? context.tr('admin_pass_incorrect') : null,
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _login,
                    child: Text(context.tr('btn_confirm'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
