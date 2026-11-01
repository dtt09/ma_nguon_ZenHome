import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';

import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/auth/ui/forgot_password_screen.dart';
import 'package:zenhome_app/features/auth/ui/google_confirm_screen.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/auth/logic/auth_helper_mixin.dart';

mixin LoginLogicMixin on ConsumerState<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();
  
  bool isGoogleLoading = false;
  bool isLoading = false;
  bool obscurePassword = true;
  String? phoneError;
  String? passwordError;

  void initLoginLogic() {
    phoneFocus.addListener(() { if (mounted) setState(() {}); });
    passwordFocus.addListener(() { if (mounted) setState(() {}); });
  }

  void disposeLoginLogic() {
    phoneController.dispose();
    passwordController.dispose();
    phoneFocus.dispose();
    passwordFocus.dispose();
  }

  Future<void> _verifyAndCleanEmail(User user, Map<String, dynamic> data, String username) async {
    final providers = user.providerData.map((p) => p.providerId).toList();
    bool hasGoogle = providers.contains('google.com');
    
    String currentAuthEmail = user.email ?? '';
    String phoneInDb = data['phoneNumber'] ?? '';
    
    if (currentAuthEmail.isNotEmpty) {
      if (!currentAuthEmail.endsWith('@zenhome.local')) {
        // Nếu có Google và là @gmail.com thì đồng bộ vào Firestore
        if (hasGoogle && currentAuthEmail.toLowerCase().endsWith('@gmail.com')) {
          if (data['email'] != currentAuthEmail) {
            try {
              await FirebaseFirestore.instance.collection('users').doc(username).update({
                'email': currentAuthEmail
              });
            } catch (_) {}
          }
        } else {
          // Trục xuất email nếu không còn liên kết Google hoặc không phải @gmail.com
          String fallbackEmail = phoneInDb.isNotEmpty
              ? '${phoneInDb.replaceAll('+', '')}@zenhome.local'
              : 'ghost_${user.uid.substring(0, 5)}@zenhome.local';
          try {
            await FirebaseFirestore.instance.collection('unlink_requests').doc(user.uid).set({
              'uid': user.uid,
              'type': 'cleanup',
              'fallbackEmail': fallbackEmail
            });
            await FirebaseFirestore.instance.collection('users').doc(username).update({
              'email': FieldValue.delete()
            });
          } catch (e) {
            debugPrint('Could not request email eviction: $e');
          }
        }
      } else {
        // Chuẩn hóa email ảo nếu SĐT bị thay đổi
        if (phoneInDb.isNotEmpty) {
          String expectedDummy = '${phoneInDb.replaceAll('+', '')}@zenhome.local';
          if (currentAuthEmail != expectedDummy) {
            try {
              await FirebaseFirestore.instance.collection('unlink_requests').doc(user.uid).set({
                'uid': user.uid,
                'type': 'sync',
                'fallbackEmail': expectedDummy
              });
            } catch (e) {
              debugPrint('Could not request dummy email update: $e');
            }
          }
        }
      }
    }

    // Đồng bộ vào bảng phone_lookup để đảm bảo luôn tra cứu được khi đăng nhập bằng SĐT
    if (phoneInDb.isNotEmpty) {
      String expectedPhone = phoneInDb;
      if (expectedPhone.startsWith('0')) expectedPhone = '+84${expectedPhone.substring(1)}';
      else if (!expectedPhone.startsWith('+')) expectedPhone = '+$expectedPhone';

      String targetEmail = currentAuthEmail.isNotEmpty
          ? currentAuthEmail
          : (data['email'] ?? '${expectedPhone.replaceAll('+', '')}@zenhome.local');

      try {
        await FirebaseFirestore.instance.collection('phone_lookup').doc(expectedPhone).set({
          'email': targetEmail,
          'username': username,
          'uid': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Could not sync phone_lookup in _verifyAndCleanEmail: $e');
      }
    }
  }

  Future<void> saveAndNavigate(String username) async {
    bool synced = false;
    try {
      synced = await ref.read(homeConfigProvider).syncFromFirestore(targetUsername: username);
    } catch (e) {
      debugPrint("Lỗi syncFromFirestore: $e");
    }

    if (!synced || ref.read(homeConfigProvider).availableHomes.isEmpty) {
      final fallbackHome = SmartConfig(
        userId: username,
        macAddress: '',
        mqttServer: 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud',
        devices: [],
        role: 'owner',
        homeName: context.tr('my_home_default'),
        ownerEmail: username,
        canEditAutomation: true,
      );
      await ref.read(homeConfigProvider).setAvailableHomes([fallbackHome]);
    }

    // Ghi nhận session không đồng bộ để không chặn việc chuyển màn hình
    SessionManager.recordSession().catchError((e) {
      debugPrint("Lỗi ghi session: $e");
    });

    if (mounted) {
      await LoadingOverlay.hideSuccess(delayMs: 600);
      showFloatingToast(context, context.tr('toast_success'), context.tr('msg_sync_success') ?? 'Đã đồng bộ dữ liệu!', isError: false);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
    }
  }

  void handlePhoneLogin() async {
    final String rawInput = phoneController.text.trim();
    final String input = rawInput.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    final String password = passwordController.text;
    
    setState(() {
      phoneError = input.isEmpty ? context.tr('err_empty_field') : null;
      passwordError = password.isEmpty ? context.tr('err_empty_field') : null;
    });

    if (input.isEmpty || password.isEmpty) {
      return;
    }

    LoadingOverlay.show(context);
    String emailToLogin = input;
    String? phoneNumber;
    try {
      
      if (!input.contains('@')) {
        final phoneDigits = input.replaceAll('+', '');
        final bool isPhone = RegExp(r'^\d{9,15}$').hasMatch(phoneDigits);
        
        if (!isPhone) {
           final doc = await FirebaseFirestore.instance.collection('users').doc(input).get();
           if (!doc.exists) {
              await LoadingOverlay.hideError();
              showFloatingToast(context, context.tr('error'), context.tr('err_user_not_found'), isError: true);
              return;
           }
           final data = doc.data() as Map<String, dynamic>;
           if (data.containsKey('email') && data['email'].toString().isNotEmpty) {
              emailToLogin = data['email'];
           } else if (data.containsKey('phoneNumber') && data['phoneNumber'].toString().isNotEmpty) {
              phoneNumber = data['phoneNumber'];
           } else {
              await LoadingOverlay.hideError();
              showFloatingToast(context, context.tr('error'), context.tr('err_unlinked_account'), isError: true);
              return;
           }
        } else {
           // Chuẩn hóa các biến thể của SĐT (+84..., 0..., và chuỗi số thuần)
           String plusVariant = input.startsWith('0') ? '+84${input.substring(1)}' : (input.startsWith('+') ? input : '+$input');
           String zeroVariant = input.startsWith('+84') ? '0${input.substring(3)}' : (input.startsWith('0') ? input : '0$phoneDigits');
           phoneNumber = plusVariant;

           // Tra cứu qua bảng phone_lookup với allow get: if true (O(1) tuyệt đối an toàn)
           final candidates = [plusVariant, zeroVariant, phoneDigits];
           for (final candidate in candidates) {
             try {
               final phoneLookupDoc = await FirebaseFirestore.instance.collection('phone_lookup').doc(candidate).get();
               if (phoneLookupDoc.exists) {
                 final data = phoneLookupDoc.data() as Map<String, dynamic>;
                 if (data.containsKey('email') && data['email'].toString().isNotEmpty) {
                   emailToLogin = data['email'];
                   break;
                 } else if (data.containsKey('username') && data['username'].toString().isNotEmpty) {
                   // Tra cứu tiếp hồ sơ người dùng qua username (get O(1) được phép công khai)
                   final userDoc = await FirebaseFirestore.instance.collection('users').doc(data['username'].toString()).get();
                   if (userDoc.exists) {
                     final uData = userDoc.data() as Map<String, dynamic>;
                     if (uData.containsKey('email') && uData['email'].toString().isNotEmpty) {
                       emailToLogin = uData['email'];
                       break;
                     }
                   }
                 }
               }
             } catch (e) {
               debugPrint('Lỗi tra cứu phone_lookup ($candidate): $e');
             }
           }
        }

        if (phoneNumber != null && (emailToLogin == input || emailToLogin.isEmpty)) {
           emailToLogin = '${phoneNumber!.replaceAll('+', '')}@zenhome.local';
        }
      } else {
         // Đăng nhập trực tiếp bằng email mà không cần tra cứu Firestore trước,
         // tránh trường hợp email trong Firestore bị lệch so với Firebase Auth.
         emailToLogin = input;
      }

      UserCredential? userCred;
      try {
        userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
           email: emailToLogin,
           password: password
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
           String? dummyEmailToTry;
           
           if (phoneNumber != null) {
               dummyEmailToTry = '${phoneNumber!.replaceAll('+', '')}@zenhome.local';
           }
           
           if (dummyEmailToTry != null && dummyEmailToTry != emailToLogin) {
             userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: dummyEmailToTry,
                password: password
             );
           } else {
             rethrow;
           }
        } else {
           rethrow;
        }
      }

      final QuerySnapshot query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: userCred.user!.uid).get();
      
      if (query.docs.isNotEmpty) {
          await _verifyAndCleanEmail(userCred.user!, query.docs.first.data() as Map<String, dynamic>, query.docs.first.id);
          await saveAndNavigate(query.docs.first.id);
      } else {
          await FirebaseAuth.instance.signOut();
          await LoadingOverlay.hideError();
          showFloatingToast(context, context.tr('error'), context.tr('err_user_not_found'), isError: true);
      }
    } on FirebaseAuthException catch (e) {
      await LoadingOverlay.hideError();
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          final isGoogleCandidate = emailToLogin.toLowerCase().endsWith('@gmail.com');
          final errorMsg = isGoogleCandidate
              ? 'Sai mật khẩu! Nếu tài khoản này đăng ký qua Google, vui lòng chọn "Đăng nhập bằng Google".'
              : context.tr('err_invalid_login');
          showFloatingToast(context, context.tr('error'), errorMsg, isError: true);
      } else if (e.code == 'too-many-requests') {
          showFloatingToast(context, context.tr('error'), context.tr('err_too_many_requests'), isError: true);
      } else if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          showFloatingToast(context, context.tr('error'), context.tr('err_phone_not_registered'), isError: true);
      } else {
          showFloatingToast(context, context.tr('error'), '${context.tr('error')}: ${e.message}', isError: true);
      }
    } catch (e) {
      await LoadingOverlay.hideError();
      showFloatingToast(context, context.tr('error'), '${context.tr('err_generic')} $e', isError: true);
    }
  }
  
  void handleForgotPassword() {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()));
  }

  void _checkUserExistsAndNavigate(String uid, String email, GoogleSignIn googleSignIn, AuthCredential credential) async {
    LoadingOverlay.show(context);
    try {
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: uid).get();
      if (query.docs.isNotEmpty) {
        await _verifyAndCleanEmail(FirebaseAuth.instance.currentUser!, query.docs.first.data() as Map<String, dynamic>, query.docs.first.id);
        await saveAndNavigate(query.docs.first.id);
      } else {
        await FirebaseAuth.instance.currentUser?.delete();
        LoadingOverlay.hide();
        
        if (!mounted) return;
        
        final bool? shouldRegister = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoogleConfirmScreen(email: email),
          ),
        );
        
        if (shouldRegister == true) {
          LoadingOverlay.show(context);
          try {
             final UserCredential newUserCred = await FirebaseAuth.instance.signInWithCredential(credential);
             LoadingOverlay.hide();
             
             if (!mounted) return;
             await Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (context) => RegisterScreen(
                   isPhone: false,
                   uid: newUserCred.user!.uid,
                 ),
               ),
             );
             
             final docCheck = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: newUserCred.user!.uid).get();
             if (docCheck.docs.isEmpty) {
               final currentUser = FirebaseAuth.instance.currentUser;
               if (currentUser != null && currentUser.uid == newUserCred.user!.uid) {
                   await currentUser.delete();
                   await googleSignIn.signOut();
               }
             }
          } catch (e) {
             LoadingOverlay.hide();
             await googleSignIn.signOut();
          }
        } else {
          await googleSignIn.signOut();
        }
      }
    } catch (e) {
      await LoadingOverlay.hideError();
      debugPrint("Google Login Error in check: $e");
      if (mounted) {
        showFloatingToast(context, context.tr('error'), '${context.tr('error')}: $e', isError: true);
      }
    }
  }

  void handleGoogleLogin() async {
    setState(() => isGoogleLoading = true);
    try {
      final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      if (clientId == null || clientId.isEmpty) {
         showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_missing_google_id') ?? 'Thiếu cấu hình GOOGLE_CLIENT_ID', isError: true);
         setState(() => isGoogleLoading = false);
         return;
      }
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
      await googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => isGoogleLoading = false);
        return;
      }
      if (!googleUser.email.toLowerCase().endsWith('@gmail.com')) {
        await googleSignIn.signOut();
        showFloatingToast(context, context.tr('error'), context.tr('err_only_gmail_supported'), isError: true);
        setState(() => isGoogleLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      _checkUserExistsAndNavigate(userCred.user!.uid, googleUser.email, googleSignIn, credential);
    } catch (e) {
      showFloatingToast(context, context.tr('error'), '${context.tr('error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }
}
