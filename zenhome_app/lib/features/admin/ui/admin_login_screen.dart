import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/secure_window_helper.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/zen_page_route.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/admin/logic/admin_login_logic.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final TextEditingController _passController = TextEditingController();
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    SecureWindowHelper.acquire();
  }

  @override
  void dispose() {
    SecureWindowHelper.release();
    _passController.dispose();
    super.dispose();
  }

  void _login() {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    if (activeConfig.macAddress == 'unknown_mac' ||
        activeConfig.macAddress.isEmpty) {
      showFloatingToast(
        context,
        context.tr('warning'),
        context.tr('err_not_linked_esp32'),
        isError: true,
      );
      return;
    }

    final isSuccess = ref
        .read(adminLoginProvider.notifier)
        .verifyPassword(ref, _passController.text);
    if (isSuccess) {
      Navigator.pushReplacement(
        context,
        ZenPageRoute(builder: (context) => const DeviceMappingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final loginState = ref.watch(adminLoginProvider);

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        centerTitle: true,
        titleText: context.tr('admin_login_title'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZenLiquidGlass.lightweight(
                  width: 96,
                  height: 96,
                  borderRadius: 48,
                  glowColor: zen.primary,
                  alignment: Alignment.center,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: zen.brandHero,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: zen.primary.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ZenGlassCard.lightweight(
                  isActive: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        context.tr('admin_login_title'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('admin_login_desc'),
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _passController,
                        obscureText: _obscurePass,
                        onSubmitted: (_) => _login(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: zenGlassInputDecoration(
                          context,
                          labelText: context.tr('password'),
                          errorText: loginState.isError
                              ? context.tr('admin_pass_incorrect')
                              : null,
                          prefixIcon: Icons.lock_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: mutedColor,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton.lightweight(
                          label: context.tr('btn_confirm'),
                          icon: Icons.verified_user_rounded,
                          maxLines: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          onPressed: _login,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
