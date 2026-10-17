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
  }

  Future<void> saveAndNavigate(String username) async {
    List<SmartConfig> myHomes = [];
    try {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(username).get();
      if (myDoc.exists) {
        final data = myDoc.data() as Map<String, dynamic>;
        List<DeviceConfig> restoredDevices = [];
        if (data['devices'] != null) {
          restoredDevices = (data['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
        }
        
        if (data['displayName'] != null) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null && user.displayName != data['displayName']) {
                await user.updateDisplayName(data['displayName']);
            }
        }

        // Đồng bộ ngôn ngữ giữa App và Firebase Profile
        if (data['language'] != null && (data['language'] == 'vi' || data['language'] == 'en')) {
          final savedLang = data['language'].toString();
          final currentLang = ref.read(localeNotifierProvider).languageCode;
          if (currentLang != savedLang) {
            await ref.read(localeNotifierProvider.notifier).setLocale(savedLang);
          }
        } else {
          final currentLang = ref.read(localeNotifierProvider).languageCode;
          await myDoc.reference.set({'language': currentLang}, SetOptions(merge: true));
        }

        myHomes.add(SmartConfig(
          userId: username,
          macAddress: data['macAddress'] ?? 'unknown_mac',
          mqttServer: data['mqttServer'] ?? 'broker.emqx.io',
          mqttUser: data['mqttUser'],
          mqttPass: data['mqttPass'],
          devices: restoredDevices,
          role: 'owner',
          homeName: context.tr('my_home_default'),
          ownerEmail: username,
          canEditAutomation: true,
        ));

        if (data['ownerUsername'] != null && data['ownerUsername'].toString().isNotEmpty) {
           String ownerUsername = data['ownerUsername'];
           try {
              final ownerDoc = await FirebaseFirestore.instance.collection('users').doc(ownerUsername).get();
              if (ownerDoc.exists) {
                  final ownerData = ownerDoc.data() as Map<String, dynamic>;
                  List<DeviceConfig> ownerDevices = [];
                  if (ownerData['devices'] != null) {
                      ownerDevices = (ownerData['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
                  }
                  String ownerName = ownerData['displayName'] ?? ownerUsername;
                  String assignedRole = 'member';
                  if (ownerData['memberRoles'] != null && ownerData['memberRoles'][username] != null) {
                    assignedRole = ownerData['memberRoles'][username];
                  }
                  bool canEdit = false;
                  if (ownerData['automationEditors'] != null && (ownerData['automationEditors'] as List).contains(username)) {
                    canEdit = true;
                  }
                  
                  myHomes.add(SmartConfig(
                      userId: ownerUsername,
                      macAddress: ownerData['macAddress'] ?? 'unknown_mac',
                      mqttServer: ownerData['mqttServer'] ?? 'broker.emqx.io',
                      mqttUser: ownerData['mqttUser'],
                      mqttPass: ownerData['mqttPass'],
                      devices: ownerDevices,
                      role: assignedRole,
                      homeName: '${context.tr('home_of')} $ownerName',
                      ownerEmail: ownerUsername, 
                      canEditAutomation: canEdit,
                  ));
              }
           } catch (e) {
              debugPrint("Lỗi tải nhà được mời: $e");
           }
        }
      } else {
        myHomes.add(SmartConfig(
          userId: username,
          macAddress: 'unknown_mac',
          mqttServer: 'broker.emqx.io',
          devices: [],
          role: 'owner',
          homeName: context.tr('my_home_default'),
          ownerEmail: username,
          canEditAutomation: true,
        ));
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ Firebase: $e");
    }

    if (myHomes.isEmpty) {
      myHomes.add(SmartConfig(
        userId: username, macAddress: 'unknown_mac', devices: [], role: 'owner', homeName: context.tr('my_home_default'), ownerEmail: username, canEditAutomation: true,
      ));
    }
    await ref.read(homeConfigProvider).setAvailableHomes(myHomes);

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
    final String input = phoneController.text.trim().replaceAll(' ', '');
    final String password = passwordController.text;
    
    setState(() {
      phoneError = input.isEmpty ? context.tr('err_empty_field') : null;
      passwordError = password.isEmpty ? context.tr('err_empty_field') : null;
    });

    if (input.isEmpty || password.isEmpty) {
      return;
    }

    LoadingOverlay.show(context);
    try {
      String emailToLogin = input;
      String? phoneNumber;
      
      if (!input.contains('@')) {
        final phoneRegex = RegExp(r'^(\+84|0)\d{9,10}$');
        bool isPhone = phoneRegex.hasMatch(input) || RegExp(r'^\+\d{10,14}$').hasMatch(input);
        
        if (!isPhone) {
           final doc = await FirebaseFirestore.instance.collection('users').doc(input).get();
           if (!doc.exists) {
              await LoadingOverlay.hideError();
              showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_user_not_found') ?? 'Tài khoản không tồn tại!', isError: true);
              return;
           }
           final data = doc.data() as Map<String, dynamic>;
           if (data.containsKey('email') && data['email'].toString().isNotEmpty) {
              emailToLogin = data['email'];
           } else if (data.containsKey('phoneNumber') && data['phoneNumber'].toString().isNotEmpty) {
              phoneNumber = data['phoneNumber'];
           } else {
              await LoadingOverlay.hideError();
              showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_unlinked_account') ?? 'Tài khoản chưa liên kết SĐT/Email!', isError: true);
              return;
           }
        } else {
           phoneNumber = input;
           if (phoneNumber!.startsWith('0')) phoneNumber = '+84${phoneNumber!.substring(1)}';
           else if (!phoneNumber!.startsWith('+')) phoneNumber = '+$phoneNumber';
           
           final query = await FirebaseFirestore.instance.collection('users').where('phoneNumber', isEqualTo: phoneNumber).get();
           if (query.docs.isNotEmpty) {
               final data = query.docs.first.data() as Map<String, dynamic>;
               if (data.containsKey('email') && data['email'].toString().isNotEmpty) {
                   emailToLogin = data['email'];
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
           } else if (input.contains('@')) {
               // Nhập bằng email nhưng có thể tk gốc là SĐT (dummy email), 
               // ta đi tìm SĐT của họ trong Firestore để lấy dummy email thử lại
               final emailQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: input).get();
               if (emailQuery.docs.isNotEmpty) {
                   final data = emailQuery.docs.first.data() as Map<String, dynamic>;
                   if (data.containsKey('phoneNumber') && data['phoneNumber'].toString().isNotEmpty) {
                       dummyEmailToTry = '${data['phoneNumber'].toString().replaceAll('+', '')}@zenhome.local';
                   }
               }
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
          await _verifyAndCleanEmail(userCred!.user!, query.docs.first.data() as Map<String, dynamic>, query.docs.first.id);
          await saveAndNavigate(query.docs.first.id);
      } else {
          await FirebaseAuth.instance.signOut();
          await LoadingOverlay.hideError();
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_user_not_found') ?? 'Tài khoản không tồn tại', isError: true);
      }
    } on FirebaseAuthException catch (e) {
      await LoadingOverlay.hideError();
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_invalid_login') ?? 'Sai tài khoản hoặc mật khẩu', isError: true);
      } else if (e.code == 'too-many-requests') {
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_too_many_requests') ?? 'Tài khoản đang bị khóa tạm thời do nhập sai quá nhiều lần. Vui lòng thử lại sau.', isError: true);
      } else if (e.code == 'user-not-found' || e.code == 'invalid-email') {
          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_phone_not_registered') ?? 'Tài khoản chưa được đăng ký!', isError: true);
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
