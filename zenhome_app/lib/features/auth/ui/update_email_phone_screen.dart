import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pinput/pinput.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
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

  void _sendOtp() async {
    if (_inputController.text.isEmpty) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', widget.isPhone ? (context.tr('err_empty_phone') ?? 'Vui lòng nhập số điện thoại') : (context.tr('err_empty_email') ?? 'Vui lòng nhập email'), isError: true);
      return;
    }
    
    // Yêu cầu xác thực lại
    bool isReauthed = await ReauthHelper.reauthenticate(context, reason: context.tr('reason_update_contact') ?? 'xác nhận thay đổi thông tin liên hệ');
    if (!isReauthed) return;

    if (widget.isPhone) {
      String phoneNumber = _inputController.text.trim();
      if (phoneNumber.startsWith('0')) phoneNumber = '+84${phoneNumber.substring(1)}';
      else if (!phoneNumber.startsWith('+')) phoneNumber = '+$phoneNumber';
      
      setState(() => _isLoading = true);
      
      // Kiểm tra SĐT đã tồn tại chưa
      try {
        final existingQuery = await FirebaseFirestore.instance.collection('users').where('phoneNumber', isEqualTo: phoneNumber).get();
        if (existingQuery.docs.isNotEmpty) {
          String? currentUsername;
          final userQuery = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user!.uid).get();
          if (userQuery.docs.isNotEmpty) currentUsername = userQuery.docs.first.id;
          
          bool isUsedByOther = false;
          for (var doc in existingQuery.docs) {
            if (doc.id != currentUsername) {
              isUsedByOther = true;
              break;
            }
          }
          
          if (isUsedByOther) {
            setState(() => _isLoading = false);
            if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_phone_already_linked') ?? 'Số điện thoại này đã được liên kết với một tài khoản khác', isError: true);
            return;
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_check_data_failed') ?? 'Không thể kiểm tra dữ liệu, vui lòng thử lại', isError: true);
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          setState(() => _isLoading = false);
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_send_otp') ?? 'Lỗi gửi OTP'}: ${e.message}', isError: true);
        },
        codeSent: (verId, forceResendingToken) {
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
      LoadingOverlay.show(context);
      try {
        await user!.verifyBeforeUpdateEmail(_inputController.text.trim());
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_verify_email_sent') ?? 'Đã gửi email xác nhận. Vui lòng kiểm tra hộp thư.', isError: false);
          Navigator.pop(context);
        }
      } on FirebaseAuthException catch (e) {
        LoadingOverlay.hide();
        if (e.code == 'email-already-in-use') {
          if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_email_already_linked') ?? 'Email này đã được liên kết với một tài khoản khác', isError: true);
        } else {
          if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? (context.tr('err_update_email') ?? 'Lỗi đổi email'), isError: true);
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_update_email') ?? 'Lỗi đổi email', isError: true);
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
           if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_phone_already_linked') ?? 'Số điện thoại này đã được liên kết với một tài khoản khác', isError: true);
           return;
        } else if (e.code == 'provider-already-linked') {
           await user!.updatePhoneNumber(credential);
        } else {
           rethrow;
        }
      }
      
      String? username;
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user!.uid).get();
      if (query.docs.isNotEmpty) {
        username = query.docs.first.id;
      }
      
      if (username != null) {
        String phoneNumber = _inputController.text.trim();
        if (phoneNumber.startsWith('0')) phoneNumber = '+84${phoneNumber.substring(1)}';
        else if (!phoneNumber.startsWith('+')) phoneNumber = '+$phoneNumber';
        
        await FirebaseFirestore.instance.collection('users').doc(username).update({
          'phoneNumber': phoneNumber
        });
      }
      
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_update_phone_success') ?? 'Cập nhật số điện thoại thành công');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      LoadingOverlay.hide();
      if (e.code == 'invalid-verification-code') {
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_invalid_otp') ?? 'Mã OTP không hợp lệ', isError: true);
      } else if (e.code == 'credential-already-in-use') {
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_phone_already_linked') ?? 'Số điện thoại này đã được liên kết với một tài khoản khác', isError: true);
      } else {
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? 'Lỗi xác thực', isError: true);
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_invalid_otp') ?? 'Mã OTP không hợp lệ', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C);

    final defaultPinTheme = PinTheme(
      width: 55,
      height: 65,
      textStyle: TextStyle(
        fontSize: 26,
        color: isDark ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w700,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
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
      boxShadow: [
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.isPhone ? (context.tr('update_phone_title') ?? 'Cập nhật Số điện thoại') : (context.tr('update_email_title') ?? 'Cập nhật Email'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                  ]
                ),
                child: Icon(widget.isPhone ? Icons.phone_iphone_rounded : Icons.mark_email_unread_rounded, size: 60, color: color),
              ).animate()
               .scale(duration: 600.ms, curve: Curves.easeOutBack)
               .shimmer(delay: 400.ms, duration: 1200.ms, color: color.withOpacity(0.3)),
               
              const SizedBox(height: 30),
              
              Text(
                widget.isPhone ? (context.tr('new_phone_number') ?? 'Số điện thoại mới') : (context.tr('new_email') ?? 'Email mới'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
              
              const SizedBox(height: 15),
              
              Text(
                widget.isPhone 
                  ? (context.tr('enter_new_phone_desc') ?? 'Vui lòng nhập số điện thoại mới của bạn. Một mã OTP sẽ được gửi đến để xác minh.')
                  : (context.tr('enter_new_email_desc') ?? 'Vui lòng nhập email mới. Một liên kết xác minh sẽ được gửi đến hộp thư của bạn.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: color.withOpacity(0.8), height: 1.5, fontSize: 15),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
              
              const SizedBox(height: 40),
              
              TextField(
                controller: _inputController,
                enabled: !_codeSent,
                keyboardType: widget.isPhone ? TextInputType.phone : TextInputType.emailAddress,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF121827) : Colors.white,
                  labelText: widget.isPhone ? (context.tr('phone_number') ?? 'Số điện thoại') : (context.tr('email_address') ?? 'Email'),
                  prefixIcon: Icon(widget.isPhone ? Icons.phone : Icons.email, color: color),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color.withOpacity(0.3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color, width: 2)),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.easeOutBack),
              
              const SizedBox(height: 30),
              
              if (_codeSent && widget.isPhone) ...[
                Text(
                  context.tr('enter_6_digit_otp') ?? 'Nhập mã OTP gồm 6 chữ số',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color.withOpacity(0.8)),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 15),
                Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  onCompleted: (pin) => _verifyOtpAndSave(),
                ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.easeOutBack),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: color.withOpacity(0.5),
                    ),
                    onPressed: _verifyOtpAndSave,
                    child: Text(context.tr('btn_confirm_update') ?? 'Xác nhận & Cập nhật', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut)
              ] else ...[
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: color.withOpacity(0.5),
                    ),
                    onPressed: _isLoading ? null : _sendOtp,
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: LogoLoadingIndicator(color: Colors.white, size: 24))
                      : Text(widget.isPhone ? (context.tr('send_otp') ?? 'Gửi mã OTP') : (context.tr('send_verify_email') ?? 'Gửi Email Xác Nhận'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
