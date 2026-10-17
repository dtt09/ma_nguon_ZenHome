import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/features/auth/ui/otp_verification_screen.dart';
import 'package:zenhome_app/features/auth/ui/reset_password_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
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
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_empty_phone_forgot') ?? 'Vui lòng nhập Email, SĐT hoặc Tên đăng nhập', isError: true);
      return;
    }
    
    LoadingOverlay.show(context);
    try {
      // 1. KIỂM TRA TỒN TẠI TÀI KHOẢN TOÀN DIỆN
      Map<String, dynamic>? userData;
      String? username;
      
      String normalizedInput = input;
      if (!input.contains('@')) {
        if (input.startsWith('0')) normalizedInput = '+84${input.substring(1)}';
        else if (RegExp(r'^\d+$').hasMatch(input)) normalizedInput = '+$input';
      }

      // Thử tìm theo Username
      var doc = await FirebaseFirestore.instance.collection('users').doc(input).get();
      if (doc.exists) {
        userData = doc.data();
        username = doc.id;
      } else {
        // Thử tìm theo SĐT
        var phoneQuery = await FirebaseFirestore.instance.collection('users').where('phoneNumber', isEqualTo: normalizedInput).get();
        if (phoneQuery.docs.isNotEmpty) {
          userData = phoneQuery.docs.first.data();
          username = phoneQuery.docs.first.id;
        } else if (input.contains('@')) {
          if (input.toLowerCase().endsWith('@gmail.com')) {
            // Thử tìm theo Email Google
            var emailQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: input).get();
            if (emailQuery.docs.isNotEmpty) {
              userData = emailQuery.docs.first.data();
              username = emailQuery.docs.first.id;
            }
          }
        }
      }

      if (userData == null) {
        LoadingOverlay.hide();
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_user_not_found') ?? 'Không tìm thấy tài khoản nào khớp với thông tin này!', isError: true);
        return;
      }

      LoadingOverlay.hide();
      
      // Hiển thị Dialog xác nhận
      if (!mounted) return;
      _showAccountFoundDialog(userData, username!);
      
    } catch (e) {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_generic') ?? "Đã xảy ra lỗi"}: $e', isError: true);
    }
  }

  void _showAccountFoundDialog(Map<String, dynamic> data, String username) {
      String? phone = (data.containsKey('phoneNumber') && data['phoneNumber'].toString().isNotEmpty) ? data['phoneNumber'] : null;
      String? email = (data.containsKey('email') && data['email'].toString().isNotEmpty) ? data['email'] : null;
      if (email != null && (!email.toLowerCase().endsWith('@gmail.com') || email.endsWith('@zenhome.local'))) {
        email = null;
      }
      String displayName = data['displayName'] ?? username;
      bool isDark = Theme.of(context).brightness == Brightness.dark;
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 45),
              ),
              const SizedBox(height: 15),
              Text(context.tr('account_found') ?? 'Đã tìm thấy tài khoản', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Xin chào, $displayName', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 10),
              Text(context.tr('choose_reset_method') ?? 'Vui lòng chọn phương thức khôi phục mật khẩu:', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              const SizedBox(height: 25),
              
              if (phone != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                      child: const Icon(Icons.sms, color: Colors.white, size: 24),
                    ),
                    title: Text(context.tr('send_sms') ?? 'Gửi mã OTP qua SMS', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text('Tới: ${phone.replaceRange(3, phone.length - 3, '***')}', style: TextStyle(color: isDark ? Colors.blue.shade200 : Colors.blue.shade700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendOtpToPhone(phone);
                    },
                  ),
                ),
              
              if (email != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.red.withOpacity(0.1) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
                    ),
                    title: Text(context.tr('verify_via_google') ?? 'Xác thực bằng Google', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text('Qua: ${_maskEmail(email!)}', style: TextStyle(color: isDark ? Colors.red.shade200 : Colors.red.shade700)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendResetEmail(email!);
                    },
                  ),
                ),
                
              if (phone == null && email == null)
                Text(context.tr('err_no_recovery_method') ?? 'Tài khoản của bạn chưa có thông tin nào để khôi phục!', style: const TextStyle(color: Colors.red)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.only(bottom: 20),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.3))),
              ),
              onPressed: () => Navigator.pop(ctx), 
              child: Text(context.tr('cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))
            ),
          ],
        ),
      );
  }
  
  String _maskEmail(String email) {
    int atIndex = email.indexOf('@');
    if (atIndex <= 2) return '${email.substring(0, 1)}***@${email.substring(atIndex + 1)}';
    return '${email.substring(0, 2)}***${email.substring(atIndex - 1)}';
  }
  
  void _sendResetEmail(String email) async {
      LoadingOverlay.show(context);
      try {
        final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
        final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
        await googleSignIn.signOut(); // Force account selector
        
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          LoadingOverlay.hide();
          return;
        }
        
        if (googleUser.email != email) {
          await googleSignIn.signOut();
          LoadingOverlay.hide();
          if (mounted) showFloatingToast(context, context.tr('error'), context.tr('err_reauth_select_google').replaceAll('{email}', email), isError: true);
          return;
        }
        
        // Xác thực thành công, lấy thông tin credential
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        
        try {
          final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
          final uid = userCred.user!.uid;
          LoadingOverlay.hide();
          if (mounted) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResetPasswordScreen(phoneNumber: email, uid: uid)));
          }
        } catch (e) {
          LoadingOverlay.hide();
          if (mounted) showFloatingToast(context, context.tr('error'), e.toString(), isError: true);
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error'), context.tr('err_google_auth_failed').replaceAll('{err}', e.toString()), isError: true);
      }
  }

  void _sendOtpToPhone(String phoneNumber) async {
      LoadingOverlay.show(context);
      try {
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: phoneNumber,
            verificationCompleted: (PhoneAuthCredential credential) async {
               try {
                 final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
                 final uid = userCred.user!.uid;
                 LoadingOverlay.hide();
                 if (mounted) {
                   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ResetPasswordScreen(phoneNumber: phoneNumber, uid: uid)));
                 }
               } catch (e) {
                 LoadingOverlay.hide();
               }
            },
            verificationFailed: (FirebaseAuthException e) {
              LoadingOverlay.hide();
              showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? 'Lỗi gửi OTP', isError: true);
            },
            codeSent: (String verificationId, int? resendToken) {
               LoadingOverlay.hide();
               if (mounted) {
                   Navigator.push(context, MaterialPageRoute(builder: (context) => OtpVerificationScreen(
                       verificationId: verificationId, 
                       phoneNumber: phoneNumber,
                       isForgotPassword: true,
                   )));
               }
            },
            codeAutoRetrievalTimeout: (String verificationId) {},
          );
      } catch (e) {
          LoadingOverlay.hide();
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
      }
  }

  Widget _buildContent(BuildContext context, bool isTopLayer, ScrollController controller) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isTopLayer ? Colors.white : (isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E));
    
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
                onPressed: () => Navigator.pop(context),
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
                    Icon(Icons.lock_reset_rounded, size: 70, color: color),
                    const SizedBox(height: 20),
                    Text(context.tr('forgot_password') ?? 'Quên mật khẩu?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                    const SizedBox(height: 10),
                    Text(context.tr('forgot_password_desc'), textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.8), fontStyle: FontStyle.italic, height: 1.5)),
                    
                    const SizedBox(height: 40),
                    
                    Builder(
                      builder: (context) {
                        Widget field = TextField(
                          controller: _phoneController,
                          focusNode: isTopLayer ? null : _phoneFocus,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isTopLayer ? Colors.white.withOpacity(0.1) : (isDark ? const Color(0xFF121827) : Colors.white),
                            labelText: context.tr('phone_or_email'),
                            labelStyle: TextStyle(color: isTopLayer ? Colors.white70 : null),
                            prefixIcon: Icon(Icons.phone, color: color),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: (isTopLayer && _phoneFocus.hasFocus) ? color : color.withOpacity(0.3))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color)),
                          ),
                          style: TextStyle(color: isTopLayer ? Colors.white : (isDark ? Colors.white : Colors.black)),
                        );
                        if (isTopLayer) {
                        }
                        return field;
                      }
                    ),
                    
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTopLayer ? Colors.white : const Color(0xFF0F766E),
                          foregroundColor: isTopLayer ? const Color(0xFF0F766E) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _isLoading ? null : _handleSendOtp,
                        child: Text(context.tr('send_reset_link'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.40,
        builder: _buildContent,
      ),
    );
  }
}

