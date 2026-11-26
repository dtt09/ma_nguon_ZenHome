import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
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

  Widget _buildPinInput(BuildContext context, BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;
    const length = 6;
    final gap = math.min(6.0, constraints.maxWidth * 0.016);
    final width = math.min(
      52.0,
      (constraints.maxWidth - gap * (length - 1)) / length,
    );
    final theme = PinTheme(
      width: width,
      height: math.max(54.0, MediaQuery.textScalerOf(context).scale(22) + 16),
      textStyle: TextStyle(
        fontSize: 22,
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
    );
    return Pinput(
      length: length,
      controller: _pinController,
      focusNode: _pinFocusNode,
      readOnly: _isVerifying,
      defaultPinTheme: theme,
      focusedPinTheme: theme.copyDecorationWith(
        border: Border.all(color: scheme.primary, width: 2),
      ),
      submittedPinTheme: theme.copyDecorationWith(
        color: scheme.primary.withValues(alpha: 0.08),
      ),
      separatorBuilder: (_) => SizedBox(width: gap),
      pinAnimationType: MediaQuery.disableAnimationsOf(context)
          ? PinAnimationType.none
          : PinAnimationType.fade,
      onChanged: (_) => setState(() {}),
      onCompleted: (_) => _verifyOtp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = context.zenColors;
    final scheme = Theme.of(context).colorScheme;
    final formattedTime =
        '${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}';
    return ZenGlassScaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: BackButton(
                        onPressed: () {
                          FirebaseAuth.instance.signOut();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('verify_otp'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr('otp_sent_to')} ${widget.phoneNumber}.\n${context.tr('enter_6_digit_otp')}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ZenGlassCard.lightweight(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(builder: _buildPinInput),
                          const SizedBox(height: 18),
                          Text(
                            _secondsRemaining > 0
                                ? context
                                      .tr('resend_otp_in')
                                      .replaceFirst('{seconds}', formattedTime)
                                : context.tr('err_invalid_otp'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _secondsRemaining > 0
                                  ? scheme.onSurfaceVariant
                                  : zen.danger,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(context.tr('did_not_receive_otp')),
                              TextButton(
                                onPressed: _canResend
                                    ? () {
                                        HapticFeedback.lightImpact();
                                        _resendOtp();
                                      }
                                    : null,
                                child: Text(context.tr('resend')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ZenGlassButton(
                            label: context.tr('btn_verify_otp'),
                            icon: Icons.verified_outlined,
                            maxLines: 3,
                            isLoading: _isVerifying,
                            onPressed:
                                _pinController.text.length == 6 &&
                                    _secondsRemaining > 0 &&
                                    !_isVerifying
                                ? () {
                                    HapticFeedback.lightImpact();
                                    _verifyOtp();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
