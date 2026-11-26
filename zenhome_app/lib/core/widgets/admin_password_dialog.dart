import 'package:flutter/material.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

/// Hộp thoại Kính Lỏng xác thực Mật khẩu Quản trị (Admin Password)
Future<bool> showAdminPasswordDialog(
  BuildContext context, {
  required String currentAdminPassword,
  String? title,
  String? description,
}) async {
  HapticHelper.warning();
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final result = await showZenGlassBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    padBottomForKeyboard: true,
    builder: (ctx) {
      return _AdminPasswordModalContent(
        isDark: isDark,
        currentAdminPassword: currentAdminPassword,
        title: title ?? context.tr('admin_verify_title'),
        description: description ?? context.tr('admin_verify_desc'),
      );
    },
  );

  return result == true;
}

class _AdminPasswordModalContent extends StatefulWidget {
  final bool isDark;
  final String currentAdminPassword;
  final String title;
  final String description;

  const _AdminPasswordModalContent({
    required this.isDark,
    required this.currentAdminPassword,
    required this.title,
    required this.description,
  });

  @override
  State<_AdminPasswordModalContent> createState() =>
      _AdminPasswordModalContentState();
}

class _AdminPasswordModalContentState
    extends State<_AdminPasswordModalContent> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final entered = _controller.text.trim();
    if (entered.isEmpty) {
      HapticHelper.warning();
      setState(() {
        _errorMessage = context.tr('err_empty_admin_pass');
      });
      return;
    }

    final expected = widget.currentAdminPassword.isNotEmpty
        ? widget.currentAdminPassword
        : 'admin';
    if (entered == expected) {
      HapticHelper.medium();
      Navigator.pop(context, true);
    } else {
      HapticHelper.errorVibrate();
      setState(() {
        _errorMessage = context.tr('admin_pass_incorrect');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zenColors;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: zen.brandHero,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: widget.isDark ? 0.24 : 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: widget.isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: widget.isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verify(),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? AppColors.darkText : AppColors.lightText,
              ),
              decoration: zenGlassInputDecoration(
                context,
                labelText: context.tr('wifi_admin_pass_hint'),
                hintText: context.tr('admin_pass_default_hint'),
                errorText: _errorMessage,
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: widget.isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_confirm'),
                icon: Icons.verified_user_rounded,
                maxLines: 2,
                onPressed: _verify,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_cancel'),
                isPrimary: false,
                maxLines: 2,
                onPressed: () {
                  HapticHelper.light();
                  Navigator.pop(context, false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
