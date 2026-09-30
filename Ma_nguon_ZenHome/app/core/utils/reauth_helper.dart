import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';

class ReauthHelper {
  /// Xác thực lại người dùng dựa trên phương thức họ đã dùng để đăng nhập.
  /// Trả về true nếu xác thực thành công.
  static Future<bool> reauthenticate(BuildContext context, {required String reason}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    bool isPhone = user.phoneNumber != null && user.phoneNumber!.isNotEmpty;
    // Note: Since we use fake email + password for phone, user.phoneNumber might be empty in FirebaseAuth if we didn't link it.
    // If it's empty, check if email ends with @zenhome.local
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
    bool isConfirmed = false;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.blue),
            const SizedBox(width: 10),
            Text(context.tr('reauth_title') ?? 'Xác thực lại', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.reauth_reason_msg(reason)),
            const SizedBox(height: 15),
            Text(context.tr('reauth_google_msg') ?? 'Bạn cần đăng nhập lại bằng tài khoản Google để tiếp tục.', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () {
              isConfirmed = true;
              Navigator.pop(ctx);
            },
            child: Text(context.tr('btn_continue') ?? 'Tiếp tục'),
          ),
        ],
      ),
    );

    if (!isConfirmed) return false;

    LoadingOverlay.show(context);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut(); // Ép buộc đăng xuất để chọn lại tài khoản
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        LoadingOverlay.hide();
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
      
      // Xóa bộ nhớ đệm Google để tránh tự động đăng nhập vào tài khoản sai
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
    // Phone re-authentication requires sending OTP.
    // To simplify, we can show a dialog that asks the user to enter their password instead since we saved them with Email/Pass.
    // However, the user EXPLICITLY requested OTP.
    String phoneNumber = user.phoneNumber ?? (user.email?.replaceAll('@zenhome.local', '') ?? '');
    if (phoneNumber.isEmpty) return false;

    bool isSuccess = false;
    String verificationId = '';
    bool codeSent = false;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
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

            return AlertDialog(
              title: Text(context.tr('reauth_sms_title') ?? 'Xác thực lại qua SMS', style: const TextStyle(color: Colors.blue)),
              content: !codeSent 
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LogoLoadingIndicator(color: Colors.blue, size: 24),
                      const SizedBox(height: 15),
                      Text(context.tr('reauth_sending_otp') ?? 'Đang gửi mã OTP đến số điện thoại của bạn...'),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.l10n.reauth_enter_otp_msg(phoneNumber)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: context.tr('enter_otp') ?? 'Mã OTP',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ],
                  ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey))
                ),
                if (codeSent)
                  ElevatedButton(
                    onPressed: () async {
                      if (otpController.text.length != 6) return;
                      LoadingOverlay.show(context);
                      try {
                        PhoneAuthCredential credential = PhoneAuthProvider.credential(
                          verificationId: verificationId,
                          smsCode: otpController.text.trim(),
                        );
                        // In firebase, if the user was signed in with Email/Password (fake email),
                        // linking or reauthenticating with PhoneCredential might fail if phone isn't linked.
                        // We will try to link it if reauthenticate fails.
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
                    child: Text(context.tr('btn_confirm') ?? 'Xác nhận'),
                  ),
              ],
            );
          }
        );
      }
    );
    return isSuccess;
  }

  static Future<bool> _reauthWithPassword(BuildContext context, User user, String reason) async {
    bool isSuccess = false;
    await showDialog(
      context: context,
      builder: (ctx) {
        TextEditingController passwordController = TextEditingController();
        bool obscurePassword = true;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.lock_clock, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text(context.tr('reauth_title') ?? 'Xác thực lại', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.reauth_reason_msg(reason)),
                  const SizedBox(height: 15),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: context.tr('password') ?? 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
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
                  child: Text(context.tr('btn_confirm') ?? 'Xác nhận'),
                ),
              ],
            );
          }
        );
      }
    );
    return isSuccess;
  }
}
