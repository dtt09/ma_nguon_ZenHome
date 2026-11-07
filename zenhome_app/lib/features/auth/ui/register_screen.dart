import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/auth/ui/otp_verification_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final bool isPhone;
  final String? phoneNumber;
  final String? uid;
  final int initialTab;

  const RegisterScreen({
    super.key,
    this.isPhone = false,
    this.phoneNumber,
    this.uid,
    this.initialTab = 0,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late int _selectedTab;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneInputController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneInputFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.isPhone ? 1 : widget.initialTab;
    _usernameFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _nameFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _emailFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _phoneInputFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _passwordFocus.addListener(() {
      if (mounted) setState(() {});
    });
    _confirmPasswordFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneInputController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneInputFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _checkUsernameValidity(String value) {
    _usernameDebounce?.cancel();
    setState(() {
      _isUsernameAvailable = null;
      _isCheckingUsername = false;
      _usernameError = null;
    });

    final String username = value.trim();
    if (username.isEmpty) return;

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      setState(() {
        _usernameError = context.tr('err_invalid_username');
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(username)
            .get();
        if (mounted && _usernameController.text.trim() == username) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = !doc.exists;
            if (doc.exists) {
              _usernameError = context.tr('err_username_in_use');
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  void _handleSendPhoneOtp() async {
    final String input = _phoneInputController.text.trim();
    if (input.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_empty_field'),
        isError: true,
      );
      return;
    }
    LoadingOverlay.show(context);
    try {
      String phoneNumber = input;
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '+84${phoneNumber.substring(1)}';
      } else if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }

      bool isRegistered = false;
      try {
        final phoneDoc = await FirebaseFirestore.instance
            .collection('phone_lookup')
            .doc(phoneNumber)
            .get();
        if (phoneDoc.exists) {
          isRegistered = true;
        }
      } catch (_) {}

      if (!isRegistered) {
        try {
          final query = await FirebaseFirestore.instance
              .collection('users')
              .where('phoneNumber', isEqualTo: phoneNumber)
              .get();
          if (query.docs.isNotEmpty) {
            isRegistered = true;
          }
        } catch (_) {}
      }

      if (isRegistered) {
        LoadingOverlay.hide();
        if (!mounted) return;
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_phone_already_registered'),
          isError: true,
        );
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCred =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final uid = userCred.user!.uid;
            LoadingOverlay.hide();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RegisterScreen(
                    isPhone: true,
                    phoneNumber: phoneNumber,
                    uid: uid,
                  ),
                ),
              );
            }
          } catch (e) {
            LoadingOverlay.hide();
            if (mounted) {
              showFloatingToast(
                context,
                context.tr('error'),
                e.toString(),
                isError: true,
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          LoadingOverlay.hide();
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              e.message ?? context.tr('err_send_otp'),
              isError: true,
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          LoadingOverlay.hide();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationScreen(
                  verificationId: verificationId,
                  phoneNumber: phoneNumber,
                  isRegistration: true,
                ),
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          '${context.tr('err_generic')}: $e',
          isError: true,
        );
      }
    }
  }

  void _showConfirmationDialog() async {
    final String username = _usernameController.text.trim();
    final String displayName = _nameController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;
    final String email = _emailController.text.trim();

    if (username.isEmpty ||
        displayName.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_empty_field'),
        isError: true,
      );
      return;
    }

    if (_selectedTab == 0 &&
        widget.phoneNumber == null &&
        FirebaseAuth.instance.currentUser == null) {
      if (email.isEmpty || !email.toLowerCase().endsWith('@gmail.com')) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_only_gmail_supported'),
          isError: true,
        );
        return;
      }
    }

    if (password != confirmPassword) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_pass_mismatch'),
        isError: true,
      );
      return;
    }

    if (!_hasMinLength ||
        !_hasUppercase ||
        !_hasLowercase ||
        !_hasNumber ||
        !_hasSpecialChar) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_firebase_weak_password'),
        isError: true,
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_invalid_username'),
        isError: true,
      );
      return;
    }

    LoadingOverlay.show(context);
    try {
      // 1. Kiểm tra username đã tồn tại chưa
      bool usernameInUse = false;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(username)
            .get();
        if (doc.exists) {
          usernameInUse = true;
        }
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          usernameInUse = true;
        } else {
          rethrow;
        }
      }

      if (usernameInUse) {
        await LoadingOverlay.hideError();
        if (!mounted) return;
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_username_in_use'),
          isError: true,
        );
        return;
      }
      LoadingOverlay.hide();

      // Hiển thị hộp thoại xác nhận thông tin bằng Zen Liquid Glass 2.0
      if (!mounted) return;
      showZenGlassDialog(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final zen = ctx.zenColors;
          final primaryText =
              isDark ? AppColors.darkText : AppColors.lightText;
          final mutedText =
              isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: zen.primary.withOpacity(isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.fact_check_rounded,
                      color: isDark ? zen.primaryAccent : zen.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ctx.tr('confirm_title'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                ctx.tr('register_review_info'),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: mutedText,
                ),
              ),
              const SizedBox(height: 16),
              ZenLiquidGlass(
                borderRadius: 18,
                blurSigma: 0,
                padding: const EdgeInsets.all(14),
                surfaceColor:
                    Colors.white.withOpacity(isDark ? 0.06 : 0.65),
                customShadows: const [],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow(
                      icon: Icons.badge_outlined,
                      label: ctx.tr('full_name_label'),
                      value: displayName,
                      isDark: isDark,
                      zen: zen,
                    ),
                    const SizedBox(height: 10),
                    _buildSummaryRow(
                      icon: Icons.alternate_email_rounded,
                      label: ctx.tr('username_label_full'),
                      value: username,
                      isDark: isDark,
                      zen: zen,
                    ),
                    const SizedBox(height: 10),
                    if (_selectedTab == 0 && email.isNotEmpty)
                      _buildSummaryRow(
                        icon: Icons.email_outlined,
                        label: 'Email:',
                        value: email,
                        isDark: isDark,
                        zen: zen,
                      )
                    else if (widget.isPhone && widget.phoneNumber != null)
                      _buildSummaryRow(
                        icon: Icons.phone_iphone_rounded,
                        label: ctx.tr('phone_label'),
                        value: widget.phoneNumber!,
                        isDark: isDark,
                        zen: zen,
                      )
                    else
                      _buildSummaryRow(
                        icon: Icons.verified_rounded,
                        label: 'Google:',
                        value: ctx.tr('google_linked'),
                        isDark: isDark,
                        zen: zen,
                        valueColor: AppColors.emeraldGlow,
                      ),
                    const SizedBox(height: 10),
                    _buildSummaryRow(
                      icon: Icons.lock_outline_rounded,
                      label: ctx.tr('password_label'),
                      value: '••••••••',
                      isDark: isDark,
                      zen: zen,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ZenGlassButton(
                      label: ctx.tr('btn_edit_info'),
                      isPrimary: false,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ZenGlassButton(
                      label: ctx.tr('btn_create_account'),
                      isPrimary: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _executeRegistration(
                          username,
                          displayName,
                          password,
                          email,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (e) {
      await LoadingOverlay.hideError();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          '${context.tr('err_generic')}: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required ZenThemeColorsExtension zen,
    Color? valueColor,
  }) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: isDark ? zen.primaryAccent : zen.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13.5, color: mutedColor, height: 1.35),
              children: [
                TextSpan(text: '$label '),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _executeRegistration(
    String username,
    String displayName,
    String password,
    String email,
  ) async {
    LoadingOverlay.show(context);
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;

      // Trường hợp 1: Đăng ký trực tiếp bằng Email & Mật khẩu
      if (_selectedTab == 0 &&
          widget.phoneNumber == null &&
          currentUser == null) {
        final userCred =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        currentUser = userCred.user;
      }
      // Trường hợp 2: Đăng ký bằng Số điện thoại (sau khi đã xác thực OTP)
      else if (widget.isPhone && widget.phoneNumber != null) {
        final String dummyEmail =
            '${widget.phoneNumber!.replaceAll('+', '')}@zenhome.local';

        if (currentUser != null) {
          try {
            final cred = EmailAuthProvider.credential(
              email: dummyEmail,
              password: password,
            );
            await currentUser.linkWithCredential(cred);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use') {
              try {
                await currentUser.updatePassword(password);
              } catch (_) {
                await LoadingOverlay.hideError();
                if (!mounted) return;
                showFloatingToast(
                  context,
                  context.tr('error'),
                  context.tr('err_phone_pass_conflict'),
                  isError: true,
                );
                return;
              }
            } else {
              await LoadingOverlay.hideError();
              if (!mounted) return;
              showFloatingToast(
                context,
                context.tr('error'),
                e.message ?? 'Lỗi liên kết tài khoản',
                isError: true,
              );
              return;
            }
          }
        }
      }
      // Trường hợp 3: Đăng ký Google bổ sung mật khẩu
      else if (currentUser != null && currentUser.email != null) {
        try {
          final cred = EmailAuthProvider.credential(
            email: currentUser.email!,
            password: password,
          );
          await currentUser.linkWithCredential(cred);
        } catch (e) {
          await currentUser.updatePassword(password);
        }
      }

      final updatedUser = FirebaseAuth.instance.currentUser ?? currentUser;
      if (updatedUser != null) {
        await updatedUser.updateDisplayName(displayName);
      }

      // 3. Lưu thông tin user vào Firestore
      String emailToSave = '';
      if (updatedUser?.email != null &&
          !updatedUser!.email!.endsWith('@zenhome.local') &&
          updatedUser.email!.toLowerCase().endsWith('@gmail.com')) {
        emailToSave = updatedUser.email!;
      } else if (email.isNotEmpty &&
          email.toLowerCase().endsWith('@gmail.com')) {
        emailToSave = email;
      }

      final Map<String, dynamic> userDataToSave = {
        'uid': updatedUser?.uid ?? widget.uid,
        'phoneNumber': widget.phoneNumber ?? '',
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (emailToSave.isNotEmpty) {
        userDataToSave['email'] = emailToSave;
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(username)
            .set(userDataToSave);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          await LoadingOverlay.hideError();
          if (!mounted) return;
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_username_in_use'),
            isError: true,
          );
          return;
        }
        rethrow;
      }

      // Ánh xạ SĐT vào bảng tra cứu phone_lookup nếu đăng ký bằng SĐT
      if (widget.phoneNumber != null && widget.phoneNumber!.isNotEmpty) {
        String phoneToSave = widget.phoneNumber!;
        if (phoneToSave.startsWith('0')) {
          phoneToSave = '+84${phoneToSave.substring(1)}';
        } else if (!phoneToSave.startsWith('+')) {
          phoneToSave = '+$phoneToSave';
        }

        final String lookupEmail = emailToSave.isNotEmpty
            ? emailToSave
            : '${phoneToSave.replaceAll('+', '')}@zenhome.local';

        try {
          await FirebaseFirestore.instance
              .collection('phone_lookup')
              .doc(phoneToSave)
              .set({
            'email': lookupEmail,
            'username': username,
            'uid': updatedUser?.uid ?? widget.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error saving phone_lookup in registration: $e');
        }
      }

      if (!mounted) return;

      // 4. Tạo cấu trúc config mẫu
      final List<SmartConfig> myHomes = [
        SmartConfig(
          userId: username,
          macAddress: '',
          mqttServer: 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud',
          devices: [],
          role: 'owner',
          homeName: context.tr('my_home_default'),
          ownerEmail: username,
        ),
      ];
      await ref.read(homeConfigProvider).setAvailableHomes(myHomes);

      await LoadingOverlay.hideSuccess();
      await SessionManager.recordSession();

      if (mounted) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('msg_profile_updated'),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (r) => false,
        );
      }
    } catch (e) {
      await LoadingOverlay.hideError();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          '${context.tr('err_generic')}: $e',
          isError: true,
        );
      }
    }
  }

  Widget _buildRequirement(String text, bool isMet, bool isDark) {
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isMet ? AppColors.emeraldGlow : mutedColor.withOpacity(0.65),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? AppColors.emeraldGlow : mutedColor,
                fontSize: 12,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color primaryColor = isDark ? zen.primaryAccent : zen.primary;
    final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final int strengthScore = (_hasMinLength ? 1 : 0) +
        (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasNumber ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0);
    final double strengthPercent = strengthScore / 5;
    final Color strengthColor = strengthPercent <= 0.4
        ? AppColors.roseGlow
        : (strengthPercent <= 0.8 ? AppColors.amberGlow : AppColors.emeraldGlow);

    final bool isGoogleFlow = !widget.isPhone &&
        (widget.uid != null || FirebaseAuth.instance.currentUser != null);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Nền Cực Quang Khúc Xạ (Aurora Mesh 2.0)
          const ZenAmbientMeshBackground(intensity: 1.05),

          // 1. Sóng Chuyển Động (Wave Layer)
          const Positioned.fill(
            child: WaveBackground(heightPercent: 0.40),
          ),

          // 2. Nội Dung Chính
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ZenGlassIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        size: 38,
                        iconSize: 17,
                        borderRadius: 14,
                        blurSigma: 14,
                        iconColor: isDark ? Colors.white : AppColors.lightText,
                        onTap: () => Navigator.pop(context),
                      ),
                      ZenGlassIconButton(
                        icon: isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 38,
                        iconSize: 18,
                        borderRadius: 14,
                        blurSigma: 14,
                        iconColor: isDark ? Colors.white : AppColors.lightText,
                        onTap: () {
                          ref
                              .read(themeModeNotifierProvider.notifier)
                              .setThemeMode(
                                isDark ? ThemeMode.light : ThemeMode.dark,
                              );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),
                // --- Brand Header ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ZenLiquidGlass(
                      width: 68,
                      height: 68,
                      borderRadius: 22,
                      blurSigma: 12,
                      alignment: Alignment.center,
                      customGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.24),
                          Colors.white.withOpacity(0.06),
                        ],
                      ),
                      customShadows: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      child: Image.asset(
                        'public/zenhome_logo_transparent.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ZenHome',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('complete_info'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontStyle: FontStyle.italic,
                        fontSize: 13.5,
                      ),
                    ),
                    if (isGoogleFlow) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: ZenLiquidGlass(
                          borderRadius: 16,
                          blurSigma: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          customGradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.22),
                              Colors.white.withOpacity(0.10),
                            ],
                          ),
                          customShadows: const [],
                          child: Row(
                            children: [
                              Image.asset(
                                'public/google_logo.png',
                                width: 20,
                                height: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr('google_register_hint'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 16),

                // --- True Refractive Liquid Glass 2.0 Form ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                    child: ZenLiquidGlass(
                      borderRadius: 28,
                      blurSigma: 22,
                      rimWidth: 1.3,
                      glowColor: zen.primary,
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                      customGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A).withOpacity(0.70),
                                const Color(0xFF0A1120).withOpacity(0.54),
                              ]
                            : [
                                Colors.white.withOpacity(0.82),
                                Colors.white.withOpacity(0.66),
                              ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Frosted Glass Segmented Control (Email vs Số điện thoại)
                          if (widget.phoneNumber == null &&
                              FirebaseAuth.instance.currentUser == null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 22),
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(isDark ? 0.06 : 0.62),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : const Color(0xFFCBD5E1)
                                          .withOpacity(0.75),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _selectedTab = 0);
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 240),
                                        curve: Curves.easeOutCubic,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: _selectedTab == 0
                                              ? zen.brandHero
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: _selectedTab == 0
                                              ? [
                                                  BoxShadow(
                                                    color: zen.primary
                                                        .withOpacity(0.32),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                              : const [],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.email_outlined,
                                              size: 17,
                                              color: _selectedTab == 0
                                                  ? Colors.white
                                                  : mutedColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              context.tr('email'),
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: _selectedTab == 0
                                                    ? Colors.white
                                                    : textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _selectedTab = 1);
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 240),
                                        curve: Curves.easeOutCubic,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: _selectedTab == 1
                                              ? zen.brandHero
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: _selectedTab == 1
                                              ? [
                                                  BoxShadow(
                                                    color: zen.primary
                                                        .withOpacity(0.32),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                              : const [],
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.phone_android_rounded,
                                              size: 17,
                                              color: _selectedTab == 1
                                                  ? Colors.white
                                                  : mutedColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                context.tr('phone_label'),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _selectedTab == 1
                                                      ? Colors.white
                                                      : textColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 2. PHÂN HỆ: Nhập Số điện thoại để gửi OTP (khi chưa xác thực)
                          if (_selectedTab == 1 &&
                              widget.phoneNumber == null) ...[
                            TextField(
                              controller: _phoneInputController,
                              focusNode: _phoneInputFocus,
                              keyboardType: TextInputType.phone,
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('phone_label'),
                                hintText: '0912 345 678',
                                prefixIcon: Icons.phone_android_rounded,
                                borderRadius: 16,
                                accentColor: primaryColor,
                              ),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ZenLiquidGlass(
                              borderRadius: 14,
                              blurSigma: 0,
                              padding: const EdgeInsets.all(12),
                              surfaceColor:
                                  primaryColor.withOpacity(isDark ? 0.12 : 0.08),
                              glowColor: primaryColor,
                              customShadows: const [],
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      context.tr('register_sms_otp_hint'),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ZenGlassButton(
                                label: context.tr('register_btn_get_otp'),
                                icon: Icons.sms_rounded,
                                borderRadius: 16,
                                onPressed: _handleSendPhoneOtp,
                              ),
                            ),
                          ] else ...[
                            // 3. PHÂN HỆ: Đăng ký bằng Email HOẶC Hoàn tất sau khi xác thực Phone
                            if (widget.phoneNumber != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: ZenGlassPill(
                                  blurSigma: 0,
                                  isSelected: true,
                                  glowColor: AppColors.emeraldGlow,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.emeraldGlow,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          context
                                              .tr('register_verified_phone')
                                              .replaceAll(
                                                '{phone}',
                                                widget.phoneNumber ?? '',
                                              ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.emeraldGlow,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            Builder(
                              builder: (context) {
                                Widget? suffixIcon;
                                if (_usernameController.text
                                    .trim()
                                    .isNotEmpty) {
                                  if (_isCheckingUsername) {
                                    suffixIcon = Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: LogoLoadingIndicator(
                                          color: primaryColor,
                                          size: 24,
                                        ),
                                      ),
                                    );
                                  } else if (_usernameError != null) {
                                    suffixIcon = const Icon(
                                      Icons.error_rounded,
                                      color: AppColors.roseGlow,
                                    );
                                  } else if (_isUsernameAvailable == true) {
                                    suffixIcon = const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.emeraldGlow,
                                    );
                                  }
                                }

                                return TextField(
                                  controller: _usernameController,
                                  focusNode: _usernameFocus,
                                  onChanged: _checkUsernameValidity,
                                  decoration: zenGlassInputDecoration(
                                    context,
                                    labelText: context.tr('username_label'),
                                    prefixIcon: Icons.alternate_email_rounded,
                                    suffixIcon: suffixIcon,
                                    errorText: _usernameError,
                                    borderRadius: 16,
                                    accentColor: primaryColor,
                                  ),
                                  style: TextStyle(color: textColor),
                                );
                              },
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _nameController,
                              focusNode: _nameFocus,
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('display_name'),
                                prefixIcon: Icons.badge_outlined,
                                borderRadius: 16,
                                accentColor: primaryColor,
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 14),

                            // Trường nhập Email (nếu đăng ký bằng Email)
                            if (_selectedTab == 0 &&
                                widget.phoneNumber == null &&
                                FirebaseAuth.instance.currentUser == null) ...[
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                decoration: zenGlassInputDecoration(
                                  context,
                                  labelText: context.tr('email'),
                                  prefixIcon: Icons.email_outlined,
                                  borderRadius: 16,
                                  accentColor: primaryColor,
                                ),
                                style: TextStyle(color: textColor),
                              ),
                              const SizedBox(height: 14),
                            ],

                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: _obscurePassword,
                              onChanged: _checkPasswordStrength,
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('password_label'),
                                prefixIcon: Icons.lock_outline_rounded,
                                borderRadius: 16,
                                accentColor: primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                    color: _passwordFocus.hasFocus
                                        ? primaryColor
                                        : mutedColor,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 12),

                            // Frosted Password Strength Checklist
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withOpacity(isDark ? 0.05 : 0.55),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.08)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: strengthPercent,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.10)
                                          : const Color(0xFFE2E8F0),
                                      color: strengthColor,
                                      minHeight: 6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRequirement(
                                    context.tr('req_min_length'),
                                    _hasMinLength,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_uppercase'),
                                    _hasUppercase,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_lowercase'),
                                    _hasLowercase,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_number'),
                                    _hasNumber,
                                    isDark,
                                  ),
                                  _buildRequirement(
                                    context.tr('req_special_char'),
                                    _hasSpecialChar,
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocus,
                              obscureText: _obscureConfirmPassword,
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('confirm_password'),
                                prefixIcon: Icons.verified_user_outlined,
                                borderRadius: 16,
                                accentColor: primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    size: 20,
                                    color: _confirmPasswordFocus.hasFocus
                                        ? primaryColor
                                        : mutedColor,
                                  ),
                                  onPressed: () {
                                    setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    );
                                  },
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ZenGlassButton(
                                label: context.tr('btn_continue'),
                                icon: Icons.arrow_forward_rounded,
                                borderRadius: 16,
                                onPressed: _showConfirmationDialog,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.tr('already_have_account'),
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 13.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  child: Text(
                                    context.tr('btn_login'),
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
