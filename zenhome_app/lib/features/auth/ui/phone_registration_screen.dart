import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/features/auth/ui/otp_verification_screen.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';
import 'package:zenhome_app/features/auth/logic/auth_helper_mixin.dart';

class PhoneRegistrationScreen extends ConsumerStatefulWidget {
  const PhoneRegistrationScreen({super.key});
  
  @override
  ConsumerState<PhoneRegistrationScreen> createState() => _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends ConsumerState<PhoneRegistrationScreen> with AuthHelperMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _handleSendOtp() async {
    final String input = _phoneController.text.trim();
    if (input.isEmpty) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_empty_field') ?? 'Vui lòng nhập thông tin', isError: true);
      return;
    }
    
    if (input.contains('@')) {
       setState(() => _isLoading = true);
       await handleGoogleAuth(loginHint: input);
       if (mounted) setState(() => _isLoading = false);
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

      // Kiểm tra SĐT đã tồn tại chưa
      final query = await FirebaseFirestore.instance.collection('users').where('phoneNumber', isEqualTo: phoneNumber).get();
      if (query.docs.isNotEmpty) {
          LoadingOverlay.hide();
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_phone_already_registered') ?? 'Số điện thoại này đã được đăng ký!', isError: true);
          return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
           try {
             final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
             final uid = userCred.user!.uid;
             LoadingOverlay.hide();
             if (mounted) {
               Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => RegisterScreen(isPhone: true, phoneNumber: phoneNumber, uid: uid)));
             }
           } catch (e) {
             LoadingOverlay.hide();
             showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
           }
        },
        verificationFailed: (FirebaseAuthException e) {
           LoadingOverlay.hide();
           showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? context.tr('err_send_otp') ?? 'Lỗi gửi mã OTP', isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
           LoadingOverlay.hide();
           if (mounted) {
               Navigator.push(context, MaterialPageRoute(builder: (context) => OtpVerificationScreen(
                   verificationId: verificationId, 
                   phoneNumber: phoneNumber,
                   isRegistration: true,
               )));
           }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
           // Timeout
        },
      );
    } catch (e) {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_generic') ?? "Đã xảy ra lỗi"}: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C);
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Background Wave (Fixed)
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height,
            child: const WaveBackground(heightPercent: 0.40),
          ),
          
          // 2. Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                // --- Logo & Title ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded, size: 70, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(context.tr('register_account') ?? 'Tạo tài khoản mới', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                    const SizedBox(height: 5),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(context.tr('enter_phone_continue') ?? 'Vui lòng nhập Số điện thoại để nhận mã xác thực OTP.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // --- Glassmorphism Form ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121827).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.1), blurRadius: 30, offset: const Offset(0, 15)),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.5), width: 1.5),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: _phoneController,
                                focusNode: _phoneFocus,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('phone_or_email') ?? 'Số điện thoại / Email',
                                  labelStyle: TextStyle(color: _phoneFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.contact_mail, color: _phoneFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              return field;
                            }
                          ),
                          
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A3A7C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                                shadowColor: const Color(0xFF2A3A7C).withOpacity(0.5),
                              ),
                              onPressed: _isLoading ? null : _handleSendOtp,
                              child: _isLoading 
                                ? const SizedBox(width: 24, height: 24, child: LogoLoadingIndicator(color: Colors.white, size: 24))
                                : Text(context.tr('btn_continue') ?? 'Tiếp tục', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(context.tr('have_account') ?? 'Đã có tài khoản?', style: TextStyle(color: textColor.withOpacity(0.7))),
                              TextButton(
                                onPressed: () {
                                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
                                },
                                child: Text(context.tr('login') ?? 'Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
