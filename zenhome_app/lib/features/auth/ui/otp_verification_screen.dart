import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';
import 'package:zenhome_app/features/auth/ui/reset_password_screen.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final bool isRegistration;
  final bool isForgotPassword;
  const OtpVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.isRegistration = false,
    this.isForgotPassword = false,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  late String _currentVerificationId;
  Timer? _timer;
  int _secondsRemaining = 300; // 5 phút = 300 giây
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _pinFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 300;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinFocusNode.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _verifyOtp() async {
    if (_pinController.text.length != 6 || _isVerifying) return;

    setState(() => _isVerifying = true);
    LoadingOverlay.show(context);
    try {
      // 1. Tạo credential từ OTP
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: _pinController.text.trim(),
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final uid = userCred.user!.uid;

      LoadingOverlay.hide();

      if (widget.isRegistration) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RegisterScreen(
                isPhone: true,
                phoneNumber: widget.phoneNumber,
                uid: uid,
              ),
            ),
          );
        }
      } else if (widget.isForgotPassword) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(
                phoneNumber: widget.phoneNumber,
                uid: uid,
              ),
            ),
          );
        }
      } else {
        await SessionManager.recordSession();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
            (r) => false,
          );
        }
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        setState(() => _isVerifying = false);
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_invalid_otp'),
          isError: true,
        );
      }
    }
  }

  void _resendOtp() async {
    if (!_canResend) return;
    LoadingOverlay.show(context);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {},
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
        codeSent: (String newVerificationId, int? resendToken) {
          LoadingOverlay.hide();
          if (mounted) {
            _currentVerificationId = newVerificationId;
            showFloatingToast(
              context,
              context.tr('toast_success'),
              context.tr('msg_otp_resent'),
            );
            _startTimer();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (_) {
      LoadingOverlay.hide();
    }
  }

  Widget _buildMainContent(
    BuildContext context, {
    required bool isOverWave,
    required ScrollController controller,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color primaryColor = isDark ? zen.primaryAccent : zen.primary;
    final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    // Split-wave header colors
    final Color headerAccent = isOverWave ? Colors.white : primaryColor;
    final Color headerTitleColor =
        isOverWave ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText);
    final Color headerDescColor = isOverWave
        ? Colors.white.withOpacity(0.86)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    // Frosted Glass PinTheme 2.0
    final defaultPinTheme = PinTheme(
      width: 46,
      height: 58,
      textStyle: TextStyle(
        fontSize: 24,
        color: textColor,
        fontWeight: FontWeight.w800,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isDark ? 0.08 : 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.18)
              : const Color(0xFFCBD5E1).withOpacity(0.88),
          width: 1.2,
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      color: isDark
          ? context.zenColors.primary.withOpacity(0.16)
          : Colors.white.withOpacity(0.94),
      border: Border.all(color: context.zenColors.primary, width: 2.0),
      boxShadow: isOverWave
          ? const []
          : [
              BoxShadow(
                color: context.zenColors.primary.withOpacity(
                  isDark ? 0.38 : 0.24,
                ),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: AppColors.emeraldGlow.withOpacity(isDark ? 0.14 : 0.09),
      border: Border.all(
        color: AppColors.emeraldGlow.withOpacity(0.85),
        width: 1.6,
      ),
    );

    final String formattedTime =
        '${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: ZenGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 40,
                iconSize: 18,
                borderRadius: 14,
                blurSigma: isOverWave ? 0 : 14,
                iconColor: isDark ? Colors.white : AppColors.lightText,
                onTap: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pop(context);
                },
              ),
            ),
          ),

          Expanded(
            child: Center(
              child: SingleChildScrollView(
                controller: controller,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Split-Wave Shield Emblem ---
                    Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOverWave
                            ? Colors.white.withOpacity(0.16)
                            : primaryColor.withOpacity(0.12),
                        border: Border.all(
                          color: isOverWave
                              ? Colors.white.withOpacity(0.36)
                              : primaryColor.withOpacity(0.28),
                          width: 1.3,
                        ),
                        boxShadow: isOverWave
                            ? const []
                            : [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.20),
                                  blurRadius: 22,
                                  spreadRadius: 2,
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 46,
                        color: headerAccent,
                      ),
                    )
                        .animate()
                        .scale(duration: 600.ms, curve: Curves.easeOutBack)
                        .shimmer(
                          delay: 400.ms,
                          duration: 1200.ms,
                          color: isOverWave
                              ? Colors.white38
                              : primaryColor.withOpacity(0.3),
                        ),
                    const SizedBox(height: 22),

                    Text(
                      context.tr('verify_otp'),
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: headerTitleColor,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${context.tr('otp_sent_to')} ${widget.phoneNumber}.\n${context.tr('enter_6_digit_otp')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: headerDescColor,
                          height: 1.5,
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 32),

                    // --- True Refractive Liquid Glass 2.0 OTP Card ---
                    ZenLiquidGlass(
                      borderRadius: 28,
                      blurSigma: isOverWave ? 0 : 20,
                      rimWidth: 1.3,
                      glowColor: zen.primary,
                      padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
                      customShadows: isOverWave ? const [] : null,
                      customGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A).withOpacity(0.70),
                                const Color(0xFF0A1120).withOpacity(0.54),
                              ]
                            : [
                                Colors.white.withOpacity(0.84),
                                Colors.white.withOpacity(0.70),
                              ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Pinput(
                            length: 6,
                            controller: _pinController,
                            readOnly: _isVerifying,
                            focusNode: isOverWave ? null : _pinFocusNode,
                            defaultPinTheme: defaultPinTheme,
                            focusedPinTheme: focusedPinTheme,
                            submittedPinTheme: submittedPinTheme,
                            separatorBuilder: (index) =>
                                const SizedBox(width: 6),
                            onChanged: (_) {
                              if (mounted && !isOverWave) setState(() {});
                            },
                            onCompleted: (pin) => _verifyOtp(),
                          )
                              .animate()
                              .fadeIn(delay: 380.ms)
                              .scale(
                                begin: const Offset(0.94, 0.94),
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              ),

                          const SizedBox(height: 24),

                          ZenGlassPill(
                            blurSigma: 0,
                            isSelected: _secondsRemaining > 0,
                            glowColor: _secondsRemaining > 0
                                ? primaryColor
                                : AppColors.roseGlow,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _secondsRemaining > 0
                                      ? Icons.timer_outlined
                                      : Icons.error_outline_rounded,
                                  size: 16,
                                  color: _secondsRemaining > 0
                                      ? primaryColor
                                      : AppColors.roseGlow,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _secondsRemaining > 0
                                      ? context
                                          .tr('resend_otp_in')
                                          .replaceFirst(
                                            '{seconds}',
                                            formattedTime,
                                          )
                                      : context.tr('err_invalid_otp'),
                                  style: TextStyle(
                                    color: _secondsRemaining > 0
                                        ? textColor
                                        : AppColors.roseGlow,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.tr('did_not_receive_otp'),
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 13.5,
                                ),
                              ),
                              TextButton(
                                onPressed: _canResend
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        _resendOtp();
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  context.tr('resend'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: _canResend
                                        ? primaryColor
                                        : mutedColor.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ZenGlassButton(
                              label: context.tr('btn_verify_otp'),
                              icon: Icons.verified_rounded,
                              isLoading: _isVerifying,
                              borderRadius: 16,
                              onPressed: _pinController.text.length == 6 &&
                                      _secondsRemaining > 0 &&
                                      !_isVerifying
                                  ? () {
                                      HapticFeedback.lightImpact();
                                      _verifyOtp();
                                    }
                                  : null,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZenGlassScaffold(
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.35,
        builder: (context, isTopLayer, controller) => _buildMainContent(
          context,
          isOverWave: isTopLayer,
          controller: controller,
        ),
      ),
    );
  }
}
