import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/auth/ui/change_password_screen.dart';
import 'package:zenhome_app/features/auth/ui/logged_devices_screen.dart';
import 'package:zenhome_app/features/auth/ui/update_email_phone_screen.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/auth/logic/profile_controller.dart';
import 'package:zenhome_app/core/utils/masking_helper.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  bool _maskSensitiveDetails = true;

  bool _hasChanges = false;
  String _initialName = '';
  String _initialBirthday = '';

  @override
  void initState() {
    super.initState();
    _initialName = user?.displayName ?? '';
    _nameController.text = _initialName;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(profileControllerProvider.notifier).fetchUserData();
      final pState = ref.read(profileControllerProvider);
      if (mounted) {
        if (pState.displayName.isNotEmpty) {
          _nameController.text = pState.displayName;
          _initialName = pState.displayName;
        }
        if (pState.birthday.isNotEmpty) {
          _birthdayController.text = pState.birthday;
          _initialBirthday = pState.birthday;
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _checkForChanges() {
    final changed = _nameController.text.trim() != _initialName.trim() ||
        _birthdayController.text.trim() != _initialBirthday.trim();
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_hasChanges) return;
    HapticFeedback.lightImpact();

    final result = await ref.read(profileControllerProvider.notifier).saveProfileChanges(
      newName: _nameController.text,
      newBirthday: _birthdayController.text,
    );

    if (!mounted) return;
    if (result.success) {
      _initialName = _nameController.text.trim();
      _initialBirthday = _birthdayController.text.trim();
      setState(() => _hasChanges = false);
      showFloatingToast(
        context,
        context.tr('toast_success'),
        context.tr('msg_profile_updated'),
      );
    } else {
      showFloatingToast(
        context,
        context.tr('error'),
        result.errorMessage ?? context.tr('error'),
        isError: true,
      );
    }
  }

  Future<void> _selectBirthday() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 20));
    if (_birthdayController.text.isNotEmpty) {
      final parts = _birthdayController.text.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          initial = DateTime(y, m, d);
        }
      }
    }

    final zen = context.zenColors;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: zen.primaryAccent,
                    surface: const Color(0xFF0F172A),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: zen.primary,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() {
        _birthdayController.text = formatted;
      });
      _checkForChanges();
    }
  }

  void _updateAvatar() {
    String newUrl = '';
    showZenGlassDialog<void>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final zen = ctx.zenColors;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: zen.brandHero,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('update_avatar'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              onChanged: (val) => newUrl = val.trim(),
              style: TextStyle(color: textColor),
              decoration: zenGlassInputDecoration(
                ctx,
                hintText: context.tr('enter_image_url'),
                prefixIcon: Icons.link_rounded,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel'),
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_save_image'),
                    icon: Icons.check_rounded,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      if (newUrl.isNotEmpty) {
                        final result = await ref.read(profileControllerProvider.notifier).updateAvatar(newUrl);
                        if (!mounted) return;
                        if (result.success) {
                          showFloatingToast(
                            context,
                            context.tr('toast_success'),
                            context.tr('msg_avatar_updated'),
                          );
                        } else {
                          showFloatingToast(
                            context,
                            context.tr('error'),
                            result.errorMessage ?? context.tr('error'),
                            isError: true,
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGoogleLinkToggle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final profileState = ref.read(profileControllerProvider);

    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_require_trusted_device'),
          isError: true,
        );
      }
      return;
    }

    if (profileState.isGoogleLinked) {
      if (!profileState.isPhoneLinked) {
        if (!mounted) return;
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_cannot_unlink_last'),
          isError: true,
        );
        return;
      }

      bool hasPassword = user.providerData.any((p) => p.providerId == 'password');
      if (!hasPassword) {
        if (!mounted) return;
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_create_pass_before_unlink_google'),
          isError: true,
        );
        return;
      }

      if (!mounted) return;
      bool? confirm = await _showConfirmDialog(
        context.tr('confirm_unlink_google'),
        context.tr('confirm_unlink_google_desc'),
      );
      if (confirm != true) return;

      if (!mounted) return;
      bool isReauthed = await ReauthHelper.reauthWithGoogleExplicit(
        context,
        reason: context.tr('confirm_unlink_google'),
      );
      if (!isReauthed) return;

      if (!mounted) return;
      LoadingOverlay.show(context);
      final result = await ref.read(profileControllerProvider.notifier).unlinkGoogle();
      LoadingOverlay.hide();
      if (!mounted) return;

      if (result.success) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('msg_google_unlinked'),
        );
      } else {
        showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
      }
    } else {
      if (!mounted) return;
      LoadingOverlay.show(context);
      try {
        final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
        final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
        await googleSignIn.signOut();

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          LoadingOverlay.hide();
          return;
        }

        if (!googleUser.email.toLowerCase().endsWith('@gmail.com')) {
          await googleSignIn.signOut();
          LoadingOverlay.hide();
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              context.tr('err_only_gmail_supported'),
              isError: true,
            );
          }
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final result = await ref.read(profileControllerProvider.notifier).linkGoogle(credential, googleUser.email);
        LoadingOverlay.hide();
        if (!mounted) return;

        if (result.success) {
          showFloatingToast(
            context,
            context.tr('toast_success'),
            context.tr('msg_google_linked'),
          );
        } else {
          String errorMsg = result.errorMessage ?? context.tr('error');
          if (result.errorCode == 'credential-already-in-use') {
            errorMsg = context.tr('err_credential_in_use');
          }
          showFloatingToast(context, context.tr('error'), errorMsg, isError: true);
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error'), e.toString(), isError: true);
      }
    }
  }

  Future<void> _handlePhoneLinkToggle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final profileState = ref.read(profileControllerProvider);

    if (profileState.isPhoneLinked) {
      if (!profileState.isGoogleLinked) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_cannot_unlink_last'),
          isError: true,
        );
        return;
      }

      bool hasPassword = user.providerData.any((p) => p.providerId == 'password');
      if (!hasPassword) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_create_pass_before_unlink_phone'),
          isError: true,
        );
        return;
      }

      bool? confirm = await _showConfirmDialog(
        context.tr('confirm_unlink_phone'),
        context.tr('confirm_unlink_phone_desc'),
      );
      if (confirm != true) return;

      if (!mounted) return;
      bool isReauthed = await ReauthHelper.reauthenticate(
        context,
        reason: context.tr('confirm_unlink_phone'),
      );
      if (!isReauthed) return;

      if (!mounted) return;
      LoadingOverlay.show(context);
      final result = await ref.read(profileControllerProvider.notifier).unlinkPhone();
      LoadingOverlay.hide();
      if (!mounted) return;

      if (result.success) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('msg_phone_unlinked'),
        );
      } else {
        showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
      }
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateEmailPhoneScreen(isPhone: true)));
      await ref.read(profileControllerProvider.notifier).fetchUserData();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showZenGlassDialog<String>(
      context: context,
      accentColor: AppColors.amberGlow,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.amberGlow.withOpacity(0.32)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.amberGlow, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('confirm_exit'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('msg_unsaved_changes'),
              style: TextStyle(
                fontSize: 14,
                color: mutedColor,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_stay'),
                    isPrimary: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_leave'),
                    isPrimary: false,
                    isDanger: true,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    onPressed: () => Navigator.pop(ctx, 'discard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_save'),
                icon: Icons.check_rounded,
                onPressed: () => Navigator.pop(ctx, 'save'),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'discard') {
      return true;
    } else if (result == 'save') {
      await _saveProfileChanges();
      return true;
    }
    return false;
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showZenGlassDialog<bool>(
      context: context,
      accentColor: AppColors.roseGlow,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.roseGlow.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.roseGlow.withOpacity(0.32)),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.roseGlow, size: 36),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.roseGlow,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: mutedColor,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel'),
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_confirm'),
                    isDanger: true,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_trusted_device_only_delete'),
          isError: true,
        );
      }
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    if (activeConfig.role == 'owner' &&
        activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown') {
      final isEspOnline = ref.read(espOnlineStateProvider);
      if (!isEspOnline) {
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_hub_offline_delete'),
            isError: true,
          );
        }
        return;
      }
    }

    if (!mounted) return;
    bool isPasswordVerified = await ReauthHelper.verifyPasswordOnly(
      context,
      reason: context.tr('reason_delete_account'),
    );
    if (!isPasswordVerified) return;

    if (!mounted) return;
    bool isNativeVerified = await ReauthHelper.verifyNativeMethodOnly(context);
    if (!isNativeVerified) return;

    if (!mounted) return;
    bool? confirm1 = await showZenGlassDialog<bool>(
      context: context,
      accentColor: AppColors.amberGlow,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.amberGlow.withOpacity(0.32)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AppColors.amberGlow, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr('menu_delete_account'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.amberGlow,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.tr('msg_confirm_delete_account'),
              style: TextStyle(fontSize: 14, height: 1.45, color: mutedColor),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel'),
                    isPrimary: false,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_yes'),
                    accentColor: AppColors.amberGlow,
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirm1 != true) return;

    if (!mounted) return;
    String currentUsername = ref.read(profileControllerProvider).username;
    if (currentUsername.isEmpty) {
      currentUsername = user.email?.split('@')[0] ?? 'user';
    }

    final TextEditingController usernameConfirmController = TextEditingController();

    if (!mounted) return;
    bool? confirm2 = await showZenGlassDialog<bool>(
      context: context,
      accentColor: AppColors.roseGlow,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDark ? AppColors.darkText : AppColors.lightText;
            final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
            bool isMatched = usernameConfirmController.text.trim() == currentUsername;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.roseGlow.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.roseGlow.withOpacity(0.35)),
                        ),
                        child: const Icon(Icons.gpp_bad_rounded, color: AppColors.roseGlow, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('final_warning'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.roseGlow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('delete_account_warning'),
                    style: TextStyle(fontSize: 13.5, height: 1.45, color: mutedColor),
                  ),
                  const SizedBox(height: 12),
                  ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    glowColor: AppColors.roseGlow,
                    child: Center(
                      child: Text(
                        currentUsername,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          fontFamily: 'monospace',
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: usernameConfirmController,
                    onChanged: (_) => setDialogState(() {}),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    decoration: zenGlassInputDecoration(
                      context,
                      hintText: '${context.tr('enter')} $currentUsername',
                      prefixIcon: Icons.verified_user_outlined,
                      accentColor: AppColors.roseGlow,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: ZenGlassButton(
                          label: context.tr('btn_cancel'),
                          isPrimary: false,
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ZenGlassButton(
                          label: context.tr('btn_still_delete'),
                          isDanger: true,
                          icon: Icons.delete_forever_rounded,
                          onPressed: isMatched ? () => Navigator.pop(ctx, true) : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    usernameConfirmController.dispose();

    if (confirm2 != true) return;

    if (!mounted) return;
    LoadingOverlay.show(context);
    final result = await ref.read(profileControllerProvider.notifier).executeAccountDeletion(currentUsername);
    if (!mounted) return;

    if (result.success) {
      await LoadingOverlay.hideSuccess();
    } else {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
    required bool isDark,
    Color? accentColor,
    bool isDanger = false,
  }) {
    final zen = context.zenColors;
    final effectiveAccent = isDanger
        ? AppColors.roseGlow
        : (accentColor ?? (isDark ? zen.primaryAccent : zen.primary));

    return ZenGlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      padding: const EdgeInsets.all(18),
      blurSigma: 16,
      glowColor: isDanger ? AppColors.roseGlow : null,
      isActive: isDanger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: effectiveAccent.withOpacity(isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: effectiveAccent.withOpacity(0.28)),
                ),
                child: Icon(titleIcon, color: effectiveAccent, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDanger
                        ? AppColors.roseGlow
                        : (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ZenLiquidGlass(
        blurSigma: 0,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        surfaceColor: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.white.withOpacity(0.58),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: zen.primary.withOpacity(isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDark ? zen.primaryAccent : zen.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isNotEmpty ? value : context.tr('not_set'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: value.isNotEmpty ? textColor : mutedColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlassMenuRow({
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final zen = context.zenColors;
    final accent = isDanger
        ? AppColors.roseGlow
        : (isDark ? zen.primaryAccent : zen.primary);
    final textColor = isDanger
        ? AppColors.roseGlow
        : (isDark ? AppColors.darkText : AppColors.lightText);

    return ZenLiquidGlass(
      blurSigma: 0,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      surfaceColor: isDanger
          ? AppColors.roseGlow.withOpacity(isDark ? 0.10 : 0.06)
          : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.58)),
      glowColor: isDanger ? AppColors.roseGlow : null,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: textColor,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isDanger
                ? AppColors.roseGlow
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final profileState = ref.watch(profileControllerProvider);

    final roleColor = activeConfig.role == 'owner'
        ? AppColors.purpleGlow
        : AppColors.emeraldGlow;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: ZenGlassScaffold(
        appBar: ZenGlassAppBar(
          centerTitle: true,
          titleText: context.tr('profile_title'),
          onBack: () async {
            final shouldLeave = await _onWillPop();
            if (shouldLeave && mounted) {
              Navigator.of(context).pop();
            }
          },
          actions: [
            if (_hasChanges)
              ZenGlassButton(
                label: context.tr('btn_save'),
                icon: Icons.check_rounded,
                isLoading: profileState.isLoading,
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                accentColor: AppColors.emeraldGlow,
                onPressed: profileState.isLoading ? null : _saveProfileChanges,
              ),
          ],
        ),
        body: RefreshIndicator(
          color: zen.primary,
          onRefresh: () async {
            await user?.reload();
            await ref.read(profileControllerProvider.notifier).fetchUserData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Avatar Hero Glass Card
                ZenGlassCard(
                  margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  blurSigma: 16,
                  isActive: true,
                  child: Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 106,
                              height: 106,
                              decoration: BoxDecoration(
                                gradient: zen.brandHero,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(isDark ? 0.28 : 0.9),
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: zen.primary.withOpacity(isDark ? 0.38 : 0.24),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                                image: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(user!.photoURL!),
                                        fit: BoxFit.cover,
                                        onError: (e, s) => debugPrint('[Avatar] Lỗi nạp avatar: $e'),
                                      )
                                    : null,
                              ),
                              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                                  ? Center(
                                      child: Text(
                                        (user?.displayName ?? 'U').isNotEmpty
                                            ? (user!.displayName ?? 'U').substring(0, 1).toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontSize: 42,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _updateAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: zen.brandHero,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                      width: 2.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: zen.primary.withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          user?.displayName?.isNotEmpty == true ? user!.displayName! : 'ZenHome User',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            if (profileState.username.isNotEmpty)
                              ZenGlassPill(
                                blurSigma: 0,
                                isSelected: true,
                                glowColor: zen.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                child: Text(
                                  '@${profileState.username}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? zen.primaryAccent : zen.primary,
                                  ),
                                ),
                              ),
                            ZenGlassPill(
                              blurSigma: 0,
                              isSelected: true,
                              glowColor: roleColor,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    activeConfig.role == 'owner'
                                        ? Icons.workspace_premium_rounded
                                        : Icons.verified_user_rounded,
                                    size: 13,
                                    color: roleColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    activeConfig.role == 'owner'
                                        ? context.tr('owner_role')
                                        : context.tr('member_role'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: roleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Card 1: Thông tin cá nhân & Liên kết
                _buildSectionCard(
                  context: context,
                  title: context.tr('menu_account_info'),
                  titleIcon: Icons.badge_outlined,
                  isDark: isDark,
                  children: [
                    // Họ và tên
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => _checkForChanges(),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                      decoration: zenGlassInputDecoration(
                        context,
                        labelText: context.tr('full_name'),
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ngày sinh
                    InkWell(
                      onTap: _selectBirthday,
                      borderRadius: BorderRadius.circular(16),
                      child: IgnorePointer(
                        child: TextField(
                          controller: _birthdayController,
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                          decoration: zenGlassInputDecoration(
                            context,
                            labelText: context.tr('birthday'),
                            hintText: 'DD/MM/YYYY',
                            prefixIcon: Icons.cake_outlined,
                            suffixIcon: Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withOpacity(0.10)
                            : const Color(0xFFCBD5E1).withOpacity(0.6),
                      ),
                    ),

                    // Tiêu đề & Nút bật/tắt che thông tin liên lạc nhạy cảm (Data Masking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('sec_linked_info'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: mutedColor,
                              ),
                            ),
                          ),
                          ZenGlassIconButton(
                            blurSigma: 0,
                            size: 34,
                            iconSize: 17,
                            borderRadius: 11,
                            icon: _maskSensitiveDetails
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            iconColor: isDark ? zen.primaryAccent : zen.primary,
                            tooltip: _maskSensitiveDetails
                                ? context.tr('show_sensitive_info')
                                : context.tr('hide_sensitive_info'),
                            onTap: () => setState(() => _maskSensitiveDetails = !_maskSensitiveDetails),
                          ),
                        ],
                      ),
                    ),

                    // Email (Google)
                    _buildInfoRow(
                      label: 'Email (Google)',
                      value: profileState.email.isNotEmpty
                          ? (_maskSensitiveDetails
                              ? MaskingHelper.maskEmail(profileState.email)
                              : profileState.email)
                          : context.tr('unlinked'),
                      icon: Icons.alternate_email_rounded,
                      isDark: isDark,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ZenGlassPill(
                            blurSigma: 0,
                            isSelected: profileState.isGoogleLinked,
                            glowColor: profileState.isGoogleLinked ? AppColors.emeraldGlow : Colors.grey,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              profileState.isGoogleLinked ? context.tr('linked') : context.tr('unlinked'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: profileState.isGoogleLinked ? AppColors.emeraldGlow : mutedColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ZenGlassPill(
                            blurSigma: 0,
                            isSelected: true,
                            glowColor: profileState.isGoogleLinked ? AppColors.roseGlow : zen.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            onTap: _handleGoogleLinkToggle,
                            child: Text(
                              profileState.isGoogleLinked ? context.tr('unlink') : context.tr('link'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                color: profileState.isGoogleLinked
                                    ? AppColors.roseGlow
                                    : (isDark ? zen.primaryAccent : zen.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Số điện thoại
                    _buildInfoRow(
                      label: context.tr('phone_number'),
                      value: profileState.phone.isNotEmpty
                          ? (_maskSensitiveDetails
                              ? MaskingHelper.maskPhone(profileState.phone)
                              : profileState.phone)
                          : context.tr('unlinked'),
                      icon: Icons.phone_android_outlined,
                      isDark: isDark,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ZenGlassPill(
                            blurSigma: 0,
                            isSelected: profileState.isPhoneLinked,
                            glowColor: profileState.isPhoneLinked ? AppColors.emeraldGlow : Colors.grey,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              profileState.isPhoneLinked ? context.tr('linked') : context.tr('unlinked'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: profileState.isPhoneLinked ? AppColors.emeraldGlow : mutedColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (profileState.isPhoneLinked) ...[
                            ZenGlassIconButton(
                              blurSigma: 0,
                              size: 30,
                              iconSize: 15,
                              borderRadius: 9,
                              icon: Icons.edit_outlined,
                              tooltip: context.tr('tooltip_change_phone'),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UpdateEmailPhoneScreen(isPhone: true),
                                  ),
                                );
                                await user?.reload();
                                await ref.read(profileControllerProvider.notifier).fetchUserData();
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          ZenGlassPill(
                            blurSigma: 0,
                            isSelected: true,
                            glowColor: profileState.isPhoneLinked ? AppColors.roseGlow : zen.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            onTap: _handlePhoneLinkToggle,
                            child: Text(
                              profileState.isPhoneLinked ? context.tr('unlink') : context.tr('link'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                color: profileState.isPhoneLinked
                                    ? AppColors.roseGlow
                                    : (isDark ? zen.primaryAccent : zen.primary),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_hasChanges) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton(
                          label: context.tr('btn_save'),
                          icon: Icons.check_circle_outline_rounded,
                          isLoading: profileState.isLoading,
                          onPressed: profileState.isLoading ? null : _saveProfileChanges,
                        ),
                      ),
                    ],
                  ],
                ),

                // Card 2: Bảo mật & Thiết bị
                _buildSectionCard(
                  context: context,
                  title: context.tr('security_and_devices'),
                  titleIcon: Icons.security_outlined,
                  isDark: isDark,
                  children: [
                    _buildGlassMenuRow(
                      icon: Icons.lock_reset_rounded,
                      title: context.tr('menu_change_password'),
                      isDark: isDark,
                      onTap: () async {
                        bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
                        if (!isTrusted) {
                          if (mounted) {
                            showFloatingToast(
                              context,
                              context.tr('error'),
                              context.tr('err_trusted_device_only_delete'),
                              isError: true,
                            );
                          }
                          return;
                        }
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildGlassMenuRow(
                      icon: Icons.devices_rounded,
                      title: context.tr('menu_logged_devices'),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoggedDevicesScreen()),
                      ),
                    ),
                  ],
                ),

                // Card 3: Vùng nguy hiểm (Xóa tài khoản)
                _buildSectionCard(
                  context: context,
                  title: context.tr('danger_zone'),
                  titleIcon: Icons.warning_amber_rounded,
                  isDark: isDark,
                  isDanger: true,
                  children: [
                    _buildGlassMenuRow(
                      icon: Icons.delete_forever_rounded,
                      title: context.tr('menu_delete_account'),
                      isDark: isDark,
                      isDanger: true,
                      onTap: _deleteAccount,
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
