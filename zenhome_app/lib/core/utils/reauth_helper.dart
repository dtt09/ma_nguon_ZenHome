import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';

class ReauthHelper {
  /// Xác thực bằng Google một cách trực tiếp
  static Future<bool> reauthWithGoogleExplicit(BuildContext context, {required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return await _reauthWithGoogle(context, user, reason);
  }

  /// Xác thực bằng SĐT (OTP) một cách trực tiếp
  static Future<bool> reauthWithPhoneExplicit(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return await _reauthWithPhone(context, user);
  }

  /// Xác thực lại người dùng dựa trên phương thức họ đã dùng để đăng nhập / liên kết.
  /// Trả về true nếu xác thực thành công.
  static Future<bool> reauthenticate(BuildContext context, {required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    if (!isPhone && user.email != null && user.email!.endsWith('@zenhome.local')) {
      isPhone = true;
    }

    if (isGoogle) {
      return await _reauthWithGoogle(context, user, reason);
    } else if (isPhone) {
      return await _reauthWithPhone(context, user);
    } else {
      return await _reauthWithPassword(context, user, reason);
    }
  }

  /// Lớp bảo vệ 2: Bắt buộc xác thực bằng Mật khẩu (nếu tài khoản có mật khẩu)
  static Future<bool> verifyPasswordOnly(BuildContext context, {required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    // Kiểm tra xem user có provider password không
    bool hasPassword = user.providerData.any((p) => p.providerId == 'password');
    if (!hasPassword || user.email == null) {
      // Nếu đăng nhập hoàn toàn bằng Google (chưa từng tạo mật khẩu), bỏ qua bước này
      return true;
    }

    return await _reauthWithPassword(context, user, reason);
  }

  /// Lớp bảo vệ 3: Xác thực bằng phương thức gốc (OTP hoặc Google)
  static Future<bool> verifyNativeMethodOnly(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    if (!isPhone && user.email != null && user.email!.endsWith('@zenhome.local')) {
      isPhone = true;
    }

    if (isGoogle) {
      return await _reauthWithGoogle(context, user, context.tr('verify_identity') ?? 'xác minh danh tính');
    } else if (isPhone) {
      return await _reauthWithPhone(context, user);
    } else {
      // Tài khoản Email/Password thuần túy, không có OTP hay Google.
      // Do đã qua bước mật khẩu, ta cho phép qua bước này.
      return true;
    }
  }

  static Future<bool> _reauthWithGoogle(BuildContext context, User user, String reason) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isConfirmed = false;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(top: 14, left: 24, right: 24, bottom: 36),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                    ),
                    child: const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('reauth_title') ?? 'Xác thực bảo mật',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.reauth_reason_msg(reason),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      icon: Image.asset('public/google_logo.png', width: 22, height: 22),
                      label: Text(
                        context.tr('btn_continue') ?? 'Xác thực với Google',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      onPressed: () {
                        isConfirmed = true;
                        Navigator.pop(ctx, true);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      context.tr('btn_cancel') ?? 'Hủy bỏ',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!isConfirmed) return false;

    LoadingOverlay.show(context);
    try {
      final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        LoadingOverlay.hide();
        return false;
      }

      // Kiểm tra xem có đúng là email Gmail đã liên kết không
      final linkedGoogleProvider = user.providerData.where((p) => p.providerId == 'google.com').firstOrNull;
      if (linkedGoogleProvider?.email != null && googleUser.email.toLowerCase() != linkedGoogleProvider!.email!.toLowerCase()) {
        await googleSignIn.signOut();
        LoadingOverlay.hide();
        if (context.mounted) {
          showFloatingToast(
            context,
            context.tr('error') ?? 'Lỗi',
            'Vui lòng chọn đúng tài khoản Google đã liên kết (${linkedGoogleProvider.email}) để xác thực!',
            isError: true,
          );
        }
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
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
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_reauth_google_failed') ?? 'Không thể xác thực lại bằng Google', isError: true);
      }
      return false;
    }
  }

  static Future<bool> _reauthWithPhone(BuildContext context, User user) async {
    String phoneNumber = user.phoneNumber ?? '';
    if (phoneNumber.isEmpty && user.email != null && user.email!.endsWith('@zenhome.local')) {
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
        final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
        if (query.docs.isNotEmpty) {
          phoneNumber = query.docs.first.data()['phoneNumber'] ?? '';
          if (phoneNumber.isNotEmpty && !phoneNumber.startsWith('+')) {
            if (phoneNumber.startsWith('0')) phoneNumber = '+84${phoneNumber.substring(1)}';
            else phoneNumber = '+$phoneNumber';
          }
        }
      } catch (_) {}
    }

    if (phoneNumber.isEmpty) return false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSuccess = false;
    String verificationId = '';
    bool codeSent = false;
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        TextEditingController otpController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setState) {
            if (!codeSent) {
              FirebaseAuth.instance.verifyPhoneNumber(
                phoneNumber: phoneNumber,
                verificationCompleted: (_) {},
                verificationFailed: (e) {
                  Navigator.pop(ctx);
                  showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.l10n.err_send_otp_failed(e.message ?? ''), isError: true);
                },
                codeSent: (verId, forceResendingToken) {
                  setState(() {
                    verificationId = verId;
                    codeSent = true;
                  });
                },
                codeAutoRetrievalTimeout: (_) {},
              );
            }

            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(top: 14, left: 24, right: 24, bottom: bottomInset > 0 ? bottomInset + 16 : 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withOpacity(0.12),
                        ),
                        child: const Icon(Icons.sms_rounded, color: Color(0xFF10B981), size: 30),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('reauth_sms_title') ?? 'Xác thực qua SMS',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !codeSent 
                          ? (context.tr('reauth_sending_otp') ?? 'Đang gửi mã OTP đến số điện thoại của bạn...')
                          : context.l10n.reauth_enter_otp_msg(phoneNumber),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      if (!codeSent)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: LogoLoadingIndicator(color: Color(0xFF0F766E), size: 32),
                        )
                      else ...[
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                          decoration: InputDecoration(
                            hintText: '------',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () async {
                              if (otpController.text.length != 6) return;
                              LoadingOverlay.show(context);
                              try {
                                PhoneAuthCredential credential = PhoneAuthProvider.credential(
                                  verificationId: verificationId,
                                  smsCode: otpController.text.trim(),
                                );
                                try {
                                   await user.reauthenticateWithCredential(credential);
                                } catch (e) {
                                   await user.linkWithCredential(credential);
                                }
                                isSuccess = true;
                                LoadingOverlay.hide();
                                if (context.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                LoadingOverlay.hide();
                                showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_invalid_otp_code') ?? 'Mã OTP không hợp lệ', isError: true);
                              }
                            },
                            child: Text(context.tr('btn_confirm') ?? 'Xác nhận', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx), 
                        child: Text(context.tr('btn_cancel') ?? 'Hủy', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600))
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
    return isSuccess;
  }

  static Future<bool> _reauthWithPassword(BuildContext context, User user, String reason) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSuccess = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        TextEditingController passwordController = TextEditingController();
        bool obscurePassword = true;
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(top: 14, left: 24, right: 24, bottom: bottomInset > 0 ? bottomInset + 16 : 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF3B82F6).withOpacity(0.12),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF3B82F6), size: 30),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.tr('reauth_title') ?? 'Xác thực mật khẩu',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.reauth_reason_msg(reason),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: context.tr('password') ?? 'Mật khẩu',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF8FAFC),
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => obscurePassword = !obscurePassword),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () async {
                            if (passwordController.text.isEmpty) {
                              showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_empty_password') ?? 'Vui lòng nhập mật khẩu', isError: true);
                              return;
                            }
                            LoadingOverlay.show(context);
                            try {
                              AuthCredential credential = EmailAuthProvider.credential(
                                email: user.email!,
                                password: passwordController.text.trim(),
                              );
                              await user.reauthenticateWithCredential(credential);
                              isSuccess = true;
                              LoadingOverlay.hide();
                              if (context.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              LoadingOverlay.hide();
                              showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_wrong_password') ?? 'Mật khẩu không đúng', isError: true);
                            }
                          },
                          child: Text(
                            context.tr('btn_confirm') ?? 'Xác nhận',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          context.tr('btn_cancel') ?? 'Hủy',
                          style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    return isSuccess;
  }
}

