import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
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
  Timer? _timer;
  int _secondsRemaining = 300; // 5 phút = 300 giây
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _pinFocusNode.addListener(() { if (mounted) setState(() {}); });
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 300;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: _pinController.text.trim(),
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final uid = userCred.user!.uid;
      
      LoadingOverlay.hide();
      
      if (widget.isRegistration) {
          if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RegisterScreen(isPhone: true, phoneNumber: widget.phoneNumber, uid: uid)));
          }
      } else if (widget.isForgotPassword) {
          if (mounted) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResetPasswordScreen(phoneNumber: widget.phoneNumber, uid: uid)));
          }
      } else {
          // Normal flow (if any)
          await SessionManager.recordSession();
          if (mounted) {
             Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainLayout()), (r) => false);
          }
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) setState(() => _isVerifying = false);
      showFloatingToast(
        context,
        context.tr('error') ?? 'Lỗi',
        context.tr('err_invalid_otp') ?? 'Mã OTP không đúng hoặc đã hết hạn!',
        isError: true,
      );
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
          showFloatingToast(
            context,
            context.tr('error') ?? 'Lỗi',
            e.message ?? context.tr('err_send_otp') ?? 'Lỗi gửi lại',
            isError: true,
          );
        },
        codeSent: (String newVerificationId, int? resendToken) {
          LoadingOverlay.hide();
          showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_otp_resent') ?? 'Đã gửi lại mã OTP!');
          // Cập nhật verificationId (trong thực tế cần lift state up hoặc dùng riverpod,
          // nhưng vì widget fields là final, ta chỉ khởi động lại timer cho UI)
          _startTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      LoadingOverlay.hide();
    }
  }

  Widget _buildContent(
    BuildContext context,
    bool isTopLayer,
    ScrollController controller,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isTopLayer
        ? Colors.white
        : (isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E));

    final defaultPinTheme = PinTheme(
      width: 55,
      height: 65,
      textStyle: TextStyle(
        fontSize: 26,
        color: isTopLayer
            ? Colors.white
            : (isDark ? Colors.white : Colors.black87),
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: isTopLayer
            ? Colors.white.withOpacity(0.15)
            : (isDark ? const Color(0xFF121827) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (isTopLayer && _pinFocusNode.hasFocus) ? color : color.withOpacity(0.2), width: 1.5),
        boxShadow: isTopLayer ? [] : [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: color, width: 2),
      boxShadow: isTopLayer ? [] : [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, 8),
        )
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Colors.green.withOpacity(0.8), width: 2),
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: color),
                onPressed: () {
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
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: isTopLayer ? Colors.white.withOpacity(0.1) : color.withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: isTopLayer ? [] : [
                          BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                        ]
                      ),
                      child: Icon(Icons.shield_rounded, size: 60, color: color),
                    ).animate()
                     .scale(duration: 600.ms, curve: Curves.easeOutBack)
                     .shimmer(delay: 400.ms, duration: 1200.ms, color: isTopLayer ? Colors.white38 : color.withOpacity(0.3)),
                    const SizedBox(height: 30),

                    Text(
                      context.tr('verify_otp') ?? 'Xác minh OTP',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 15),
                    Text(
                      '${context.tr('otp_sent_to') ?? 'Mã OTP đã được gửi đến số điện thoại'} ${widget.phoneNumber}.\n${context.tr('enter_6_digit_otp') ?? 'Vui lòng kiểm tra tin nhắn và nhập mã gồm 6 chữ số'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: color.withOpacity(0.8),
                        height: 1.5,
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 50),

                    Pinput(
                      length: 6,
                      controller: _pinController,
                      readOnly: _isVerifying,
                      focusNode: isTopLayer ? null : _pinFocusNode,
                      defaultPinTheme: defaultPinTheme,
                      focusedPinTheme: focusedPinTheme,
                      submittedPinTheme: submittedPinTheme,
                      onCompleted: (pin) => _verifyOtp(),
                    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.easeOutBack),

                    const SizedBox(height: 40),

                    Text(
                      _secondsRemaining > 0
                          ? (context.tr('resend_otp_in')?.replaceFirst('{seconds}', '${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}') ?? 'Gửi lại mã sau ${_secondsRemaining ~/ 60}:${(_secondsRemaining % 60).toString().padLeft(2, '0')}s')
                          : (context.tr('err_invalid_otp') ?? 'Mã OTP đã hết hạn'),
                      style: TextStyle(
                        color: _secondsRemaining > 0
                            ? color.withOpacity(0.7)
                            : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.tr('did_not_receive_otp') ?? 'Chưa nhận được mã?',
                          style: TextStyle(color: color.withOpacity(0.7)),
                        ),
                        TextButton(
                          onPressed: _canResend ? _resendOtp : null,
                          child: Text(
                            context.tr('resend') ?? 'Gửi lại',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _canResend ? color : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 550.ms),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTopLayer
                              ? Colors.white
                              : const Color(0xFF0F766E),
                          foregroundColor: isTopLayer
                              ? const Color(0xFF0F766E)
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: isTopLayer ? 0 : 5,
                          shadowColor: isTopLayer ? Colors.transparent : const Color(0xFF0F766E).withOpacity(0.5),
                        ),
                        onPressed:
                            _pinController.text.length == 6 &&
                                _secondsRemaining > 0 && !_isVerifying
                            ? _verifyOtp
                            : null,
                        child: Text(
                          context.tr('btn_verify_otp') ?? 'Xác nhận OTP',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090C15)
          : const Color(0xFFF5F7FA),
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.35,
        builder: _buildContent,
      ),
    );
  }
}


