import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class ReauthHelper {
  /// Xác thực bằng Google một cách trực tiếp
  static Future<bool> reauthWithGoogleExplicit(
    BuildContext context, {
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return _reauthWithGoogle(context, user, reason);
  }

  /// Xác thực bằng SĐT (OTP) một cách trực tiếp
  static Future<bool> reauthWithPhoneExplicit(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return _reauthWithPhone(context, user);
  }

  /// Xác thực lại người dùng dựa trên phương thức họ đã dùng để đăng nhập / liên kết.
  static Future<bool> reauthenticate(
    BuildContext context, {
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final bool isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    if (!isPhone &&
        user.email != null &&
        user.email!.endsWith('@zenhome.local')) {
      isPhone = true;
    }

    if (isGoogle) {
      return _reauthWithGoogle(context, user, reason);
    }
    if (isPhone) {
      return _reauthWithPhone(context, user);
    }
    return _reauthWithPassword(context, user, reason);
  }

  /// Lớp bảo vệ 2: Bắt buộc xác thực bằng Mật khẩu (nếu tài khoản có mật khẩu)
  static Future<bool> verifyPasswordOnly(
    BuildContext context, {
    required String reason,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final bool hasPassword =
        user.providerData.any((p) => p.providerId == 'password');
    if (!hasPassword || user.email == null) {
      return true;
    }

    return _reauthWithPassword(context, user, reason);
  }

  /// Lớp bảo vệ 3: Xác thực bằng phương thức gốc (OTP hoặc Google)
  static Future<bool> verifyNativeMethodOnly(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final bool isGoogle =
        user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    if (!isPhone &&
        user.email != null &&
        user.email!.endsWith('@zenhome.local')) {
      isPhone = true;
    }

    if (isGoogle) {
      return _reauthWithGoogle(
        context,
        user,
        context.tr('verify_identity'),
      );
    }
    if (isPhone) {
      return _reauthWithPhone(context, user);
    }
    return true;
  }

  static Future<bool> _reauthWithGoogle(
    BuildContext context,
    User user,
    String reason,
  ) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    final bool? confirmed = await showZenGlassBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        zen.primary.withValues(alpha: 0.16),
                        zen.primaryAccent.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: zen.primary.withValues(alpha: isDark ? 0.28 : 0.22),
                      width: 0.9,
                    ),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: isDark ? zen.primaryAccent : zen.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('reauth_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.reauth_reason_msg(reason),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 24),
                ZenLiquidGlass.lightweight(
                  borderRadius: 16,
                  enableSpecularRim: false,
                  glowColor: zen.primary,
                  customGradient: zen.brandHero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  onTap: () => Navigator.pop(ctx, true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Image.asset(
                          'public/google_logo.png',
                          width: 18,
                          height: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          context.tr('btn_continue'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ZenGlassButton(
                    label: context.tr('btn_cancel'),
                    isPrimary: false,
                    maxLines: 2,
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !context.mounted) return false;

    LoadingOverlay.show(context);
    try {
      final String? clientId = const String.fromEnvironment('GOOGLE_CLIENT_ID');
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        LoadingOverlay.hide();
        return false;
      }

      final linkedGoogleProvider = user.providerData
          .where((p) => p.providerId == 'google.com')
          .firstOrNull;
      if (linkedGoogleProvider?.email != null &&
          googleUser.email.toLowerCase() !=
              linkedGoogleProvider!.email!.toLowerCase()) {
        await googleSignIn.signOut();
        LoadingOverlay.hide();
        if (context.mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            'Vui lòng chọn đúng tài khoản Google đã liên kết (${linkedGoogleProvider.email}) để xác thực!',
            isError: true,
          );
        }
        return false;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      LoadingOverlay.hide();
      return true;
    } catch (e) {
      LoadingOverlay.hide();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}

      if (context.mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_reauth_google_failed'),
          isError: true,
        );
      }
      return false;
    }
  }

  static Future<bool> _reauthWithPhone(BuildContext context, User user) async {
    String phoneNumber = user.phoneNumber ?? '';
    if (phoneNumber.isEmpty &&
        user.email != null &&
        user.email!.endsWith('@zenhome.local')) {
      phoneNumber = user.email!.replaceAll('@zenhome.local', '');
    }
    if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+')) {
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '+84${phoneNumber.substring(1)}';
      } else {
        phoneNumber = '+$phoneNumber';
      }
    }

    if (phoneNumber.isEmpty) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .get();
        if (query.docs.isNotEmpty) {
          phoneNumber = query.docs.first.data()['phoneNumber'] ?? '';
          if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+')) {
            if (phoneNumber.startsWith('0')) {
              phoneNumber = '+84${phoneNumber.substring(1)}';
            } else {
              phoneNumber = '+$phoneNumber';
            }
          }
        }
      } catch (_) {}
    }

    if (phoneNumber.isEmpty || !context.mounted) return false;

    final bool? result = await showZenGlassBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      padBottomForKeyboard: true,
      builder: (ctx) => _PhoneReauthSheet(
        user: user,
        phoneNumber: phoneNumber,
      ),
    );
    return result == true;
  }

  static Future<bool> _reauthWithPassword(
    BuildContext context,
    User user,
    String reason,
  ) async {
    final bool? result = await showZenGlassBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      padBottomForKeyboard: true,
      builder: (ctx) => _PasswordReauthSheet(
        user: user,
        reason: reason,
      ),
    );
    return result == true;
  }
}

class _PhoneReauthSheet extends StatefulWidget {
  final User user;
  final String phoneNumber;

  const _PhoneReauthSheet({
    required this.user,
    required this.phoneNumber,
  });

  @override
  State<_PhoneReauthSheet> createState() => _PhoneReauthSheetState();
}

class _PhoneReauthSheetState extends State<_PhoneReauthSheet> {
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = '';
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _requestOtp();
  }

  void _requestOtp() {
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!mounted) return;
        final String errTitle = context.tr('error');
        final String errMsg = context.l10n.err_send_otp_failed(e.message ?? '');
        Navigator.pop(context, false);
        showFloatingToast(
          context,
          errTitle,
          errMsg,
          isError: true,
        );
      },
      codeSent: (verId, forceResendingToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verId;
          _codeSent = true;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _submitOtp() async {
    if (_otpController.text.length != 6) return;
    LoadingOverlay.show(context);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );
      try {
        await widget.user.reauthenticateWithCredential(credential);
      } catch (e) {
        await widget.user.linkWithCredential(credential);
      }
      LoadingOverlay.hide();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      LoadingOverlay.hide();
      if (!mounted) return;
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_invalid_otp_code'),
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: zen.success.withValues(alpha: 0.14),
                border: Border.all(
                  color: zen.success.withValues(alpha: isDark ? 0.28 : 0.24),
                  width: 0.9,
                ),
              ),
              child: Icon(
                Icons.sms_rounded,
                color: zen.success,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('reauth_sms_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !_codeSent
                  ? context.tr('reauth_sending_otp')
                  : context.l10n.reauth_enter_otp_msg(widget.phoneNumber),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 20),
            if (!_codeSent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: LogoLoadingIndicator(
                  color: isDark ? zen.primaryAccent : zen.primary,
                  size: 34,
                ),
              )
            else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitOtp(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                decoration: zenGlassInputDecoration(
                  context,
                  hintText: '------',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  label: context.tr('btn_confirm'),
                  icon: Icons.verified_rounded,
                  maxLines: 2,
                  onPressed: _submitOtp,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_cancel'),
                isPrimary: false,
                maxLines: 2,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordReauthSheet extends StatefulWidget {
  final User user;
  final String reason;

  const _PasswordReauthSheet({
    required this.user,
    required this.reason,
  });

  @override
  State<_PasswordReauthSheet> createState() => _PasswordReauthSheetState();
}

class _PasswordReauthSheetState extends State<_PasswordReauthSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  Future<void> _submitPassword() async {
    if (_passwordController.text.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_empty_password'),
        isError: true,
      );
      return;
    }
    LoadingOverlay.show(context);
    try {
      final credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: _passwordController.text.trim(),
      );
      await widget.user.reauthenticateWithCredential(credential);
      LoadingOverlay.hide();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      LoadingOverlay.hide();
      if (!mounted) return;
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_wrong_password'),
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    zen.primary.withValues(alpha: 0.16),
                    zen.primaryAccent.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: zen.primary.withValues(alpha: isDark ? 0.28 : 0.22),
                  width: 0.9,
                ),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: isDark ? zen.primaryAccent : zen.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('reauth_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.reauth_reason_msg(widget.reason),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitPassword(),
              decoration: zenGlassInputDecoration(
                context,
                labelText: context.tr('password'),
                prefixIcon: Icons.lock_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_confirm'),
                icon: Icons.verified_user_rounded,
                maxLines: 2,
                onPressed: _submitPassword,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_cancel'),
                isPrimary: false,
                maxLines: 2,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
