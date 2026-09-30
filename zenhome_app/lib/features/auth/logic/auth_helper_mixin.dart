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

import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:zenhome_app/features/auth/ui/google_confirm_screen.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';

mixin AuthHelperMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  
  void saveAndNavigate(String username) async {
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
        ));
      }
    } catch (e) {
      debugPrint("Lỗi đồng bộ Firebase: $e");
    }

    if (myHomes.isEmpty) {
      myHomes.add(SmartConfig(
        userId: username, macAddress: 'unknown_mac', devices: [], role: 'owner', homeName: context.tr('my_home_default'), ownerEmail: username,
      ));
    }
    await ref.read(homeConfigProvider).setAvailableHomes(myHomes);

    await SessionManager.recordSession();

    if (mounted) {
      showFloatingToast(context, context.tr('toast_success'), context.tr('msg_sync_success') ?? 'Đã đồng bộ dữ liệu!', isError: false);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
    }
  }

  void checkUserExistsAndNavigate(String uid, String email, GoogleSignIn googleSignIn, AuthCredential credential) async {
    LoadingOverlay.show(context);
    try {
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: uid).get();
      if (query.docs.isNotEmpty) {
        await LoadingOverlay.hideSuccess();
        saveAndNavigate(query.docs.first.id);
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

  Future<void> handleGoogleAuth({String? loginHint}) async {
    try {
      final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
      if (clientId == null || clientId.isEmpty) {
         showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_missing_google_id') ?? 'Thiếu cấu hình GOOGLE_CLIENT_ID', isError: true);
         return;
      }
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
      await googleSignIn.signOut(); // Ép buộc hiển thị lại bảng chọn tài khoản
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      checkUserExistsAndNavigate(userCred.user!.uid, googleUser.email, googleSignIn, credential);
    } catch (e) {
      showFloatingToast(context, context.tr('error'), '${context.tr('error')}: $e', isError: true);
    }
  }
}
