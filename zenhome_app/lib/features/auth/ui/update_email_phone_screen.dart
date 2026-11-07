import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';

class UpdateEmailPhoneScreen extends StatefulWidget {
  final bool isPhone;
  const UpdateEmailPhoneScreen({super.key, required this.isPhone});

  @override
  State<UpdateEmailPhoneScreen> createState() => _UpdateEmailPhoneScreenState();
}

class _UpdateEmailPhoneScreenState extends State<UpdateEmailPhoneScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String _verificationId = '';

  @override
  void dispose() {
    _inputController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    if (_inputController.text.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        widget.isPhone
            ? context.tr('err_empty_phone')
            : context.tr('err_empty_email'),
        isError: true,
      );
      return;
    }

    // Yêu cầu xác thực lại
    bool isReauthed = await ReauthHelper.reauthenticate(
      context,
      reason: context.tr('reason_update_contact'),
    );
    if (!isReauthed) return;

    if (widget.isPhone) {
      String phoneNumber = _inputController.text.trim();
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '+84${phoneNumber.substring(1)}';
      } else if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }

      if (!mounted) return;
      setState(() => _isLoading = true);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          showFloatingToast(
            context,
            context.tr('error'),
            '${context.tr('err_send_otp')}: ${e.message}',
            isError: true,
          );
        },
        codeSent: (verId, forceResendingToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verId;
            _codeSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } else {
      // Đổi Email
      if (!mounted) return;
      LoadingOverlay.show(context);
      try {
        await user!.verifyBeforeUpdateEmail(_inputController.text.trim());
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_success'),
            context.tr('msg_verify_email_sent'),
            isError: false,
          );
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        LoadingOverlay.hide();
        if (e.code == 'email-already-in-use') {
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              context.tr('err_email_already_linked'),
              isError: true,
            );
          }
        } else {
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              e.message ?? context.tr('err_update_email'),
              isError: true,
            );
          }
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_update_email'),
            isError: true,
          );
        }
      }
    }
  }

  void _verifyOtpAndSave() async {
    if (_otpController.text.length != 6) return;

    LoadingOverlay.show(context);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );

      try {
        await user!.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          LoadingOverlay.hide();
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              context.tr('err_phone_already_linked'),
              isError: true,
            );
          }
          return;
        } else if (e.code == 'provider-already-linked') {
          await user!.updatePhoneNumber(credential);
        } else {
          rethrow;
        }
      }

      String? username;
      Map<String, dynamic>? userDocData;
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user!.uid)
          .get();
      if (query.docs.isNotEmpty) {
        username = query.docs.first.id;
        userDocData = query.docs.first.data();
      }

      if (username != null) {
        String phoneNumber = _inputController.text.trim();
        if (phoneNumber.startsWith('0')) {
          phoneNumber = '+84${phoneNumber.substring(1)}';
        } else if (!phoneNumber.startsWith('+')) {
          phoneNumber = '+$phoneNumber';
        }

        // Xóa SĐT cũ khỏi bảng tra cứu phone_lookup nếu đã đổi sang số khác
        final oldPhone = userDocData?['phoneNumber'] as String?;
        if (oldPhone != null && oldPhone.isNotEmpty && oldPhone != phoneNumber) {
          try {
            await FirebaseFirestore.instance
                .collection('phone_lookup')
                .doc(oldPhone)
                .delete();
          } catch (_) {}
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(username)
            .update({'phoneNumber': phoneNumber});

        // Xác định email đăng nhập thật để ánh xạ vào phone_lookup
        String emailForLookup = '';
        if (user!.email != null &&
            !user!.email!.endsWith('@zenhome.local') &&
            user!.email!.isNotEmpty) {
          emailForLookup = user!.email!;
        } else if (userDocData != null &&
            userDocData.containsKey('email') &&
            userDocData['email'].toString().isNotEmpty) {
          emailForLookup = userDocData['email'];
        } else {
          emailForLookup = '${phoneNumber.replaceAll('+', '')}@zenhome.local';
        }

        await FirebaseFirestore.instance
            .collection('phone_lookup')
            .doc(phoneNumber)
            .set({
          'email': emailForLookup,
          'username': username,
          'uid': user!.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('msg_update_phone_success'),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      LoadingOverlay.hide();
      if (e.code == 'invalid-verification-code') {
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_invalid_otp'),
            isError: true,
          );
        }
      } else if (e.code == 'credential-already-in-use') {
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_phone_already_linked'),
            isError: true,
          );
        }
      } else {
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            e.message ?? 'Lỗi xác thực',
            isError: true,
          );
        }
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_invalid_otp'),
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentColor = isDark ? zen.primaryAccent : zen.primary;

    // Translucent Frosted Glass PinTheme
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 58,
      textStyle: TextStyle(
        fontSize: 23,
        color: textColor,
        fontWeight: FontWeight.w800,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.18)
              : const Color(0xFFCBD5E1).withOpacity(0.85),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.24 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      color: zen.primary.withOpacity(isDark ? 0.16 : 0.10),
      border: Border.all(color: zen.primary, width: 2.0),
      boxShadow: [
        BoxShadow(
          color: zen.primary.withOpacity(isDark ? 0.36 : 0.22),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyDecorationWith(
      color: AppColors.emeraldGlow.withOpacity(isDark ? 0.14 : 0.09),
      border: Border.all(
        color: AppColors.emeraldGlow.withOpacity(0.85),
        width: 1.8,
      ),
    );

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        titleText: widget.isPhone
            ? context.tr('update_phone_title')
            : context.tr('update_email_title'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing Glass Hero Orb
              ZenLiquidGlass(
                width: 98,
                height: 98,
                borderRadius: 49,
                blurSigma: 16,
                glowColor: zen.primary,
                alignment: Alignment.center,
                child: Icon(
                  widget.isPhone
                      ? Icons.phone_iphone_rounded
                      : Icons.mark_email_unread_rounded,
                  size: 46,
                  color: accentColor,
                ),
              )
                  .animate()
                  .scale(duration: 550.ms, curve: Curves.easeOutBack)
                  .shimmer(
                    delay: 350.ms,
                    duration: 1200.ms,
                    color: accentColor.withOpacity(0.32),
                  ),

              const SizedBox(height: 24),

              // Step Card
              ZenGlassCard(
                blurSigma: 18,
                isActive: true,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      widget.isPhone
                          ? context.tr('new_phone_number')
                          : context.tr('new_email'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 150.ms)
                        .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    Text(
                      widget.isPhone
                          ? context.tr('enter_new_phone_desc')
                          : context.tr('enter_new_email_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: mutedColor,
                        height: 1.5,
                        fontSize: 14,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 250.ms)
                        .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),

                    const SizedBox(height: 26),

                    TextField(
                      controller: _inputController,
                      enabled: !_codeSent,
                      keyboardType: widget.isPhone
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: zenGlassInputDecoration(
                        context,
                        labelText: widget.isPhone
                            ? context.tr('phone_number')
                            : context.tr('email_address'),
                        prefixIcon: widget.isPhone
                            ? Icons.phone_rounded
                            : Icons.email_outlined,
                      ),
                    ).animate().fadeIn(delay: 350.ms).scale(
                          begin: const Offset(0.95, 0.95),
                          duration: 380.ms,
                          curve: Curves.easeOutBack,
                        ),

                    const SizedBox(height: 24),

                    if (_codeSent && widget.isPhone) ...[
                      ZenGlassPill(
                        blurSigma: 0,
                        isSelected: true,
                        glowColor: zen.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        child: Text(
                          context.tr('enter_6_digit_otp'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: accentColor,
                          ),
                        ),
                      ).animate().fadeIn(duration: 350.ms),
                      const SizedBox(height: 16),
                      Pinput(
                        length: 6,
                        controller: _otpController,
                        defaultPinTheme: defaultPinTheme,
                        focusedPinTheme: focusedPinTheme,
                        submittedPinTheme: submittedPinTheme,
                        onCompleted: (_) => _verifyOtpAndSave(),
                      ).animate().fadeIn(duration: 380.ms).scale(
                            begin: const Offset(0.94, 0.94),
                            duration: 380.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton(
                          label: context.tr('btn_confirm_update'),
                          icon: Icons.verified_rounded,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          onPressed: _verifyOtpAndSave,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 380.ms)
                          .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton(
                          label: widget.isPhone
                              ? context.tr('send_otp')
                              : context.tr('send_verify_email'),
                          icon: widget.isPhone
                              ? Icons.sms_outlined
                              : Icons.mark_email_read_outlined,
                          isLoading: _isLoading,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          onPressed: _isLoading ? null : _sendOtp,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 420.ms)
                          .slideY(begin: 0.25, end: 0, curve: Curves.easeOut),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
