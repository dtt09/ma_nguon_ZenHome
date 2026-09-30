import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';

mixin AuthSyncMixin on ConsumerState<MainLayout> {
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<DocumentSnapshot>? sessionSubscription;
  StreamSubscription<QuerySnapshot>? alertsSubscription;

  void initAuthSync() {
    _listenForSessionStatus();
    
    authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        if (mounted) {
           showFloatingToast(context, context.tr('notification') ?? 'Thông báo', context.tr('session_expired') ?? 'Phiên đăng nhập đã kết thúc.', isError: true);
           Navigator.of(context).pushAndRemoveUntil(
             MaterialPageRoute(builder: (context) => const LoginScreen()),
             (route) => false,
           );
        }
      }
    });

    _listenForAlerts();
  }

  void _listenForSessionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    String? username;
    final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      username = query.docs.first.id;
    }
    if (username == null) return;

    String currentDeviceId = await SessionManager.getUniqueDeviceId();
    
    sessionSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(username)
        .collection('sessions')
        .doc(currentDeviceId)
        .snapshots()
        .listen((docSnapshot) async {
      if (!docSnapshot.exists) {
        sessionSubscription?.cancel();
        await FirebaseAuth.instance.signOut();
      } else {
        final data = docSnapshot.data() as Map<String, dynamic>;
        if (data['isActive'] == false) {
          sessionSubscription?.cancel();
          await FirebaseAuth.instance.signOut();
        }
      }
    });
  }

  void _listenForAlerts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    String? username;
    final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      username = query.docs.first.id;
    }
    if (username == null) return;

    String currentDeviceId = await SessionManager.getUniqueDeviceId();
    final alertsRef = FirebaseFirestore.instance.collection('users').doc(username).collection('alerts');
    final now = Timestamp.now();

    alertsSubscription = alertsRef
        .where('timestamp', isGreaterThan: now)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final type = data['type'];
            if (type == 'trust_request') {
              final requesterDeviceId = data['deviceId'];
              if (requesterDeviceId != currentDeviceId) {
                FirebaseFirestore.instance.collection('users').doc(username!).collection('sessions').doc(currentDeviceId).get().then((currentSessionDoc) {
                  if (currentSessionDoc.exists && (currentSessionDoc.data()?['isTrusted'] == true)) {
                    final requesterName = data['deviceName'] ?? context.tr('default_device_name');
                    if (mounted) {
                       _showTrustRequestDialog(username!, requesterDeviceId, requesterName);
                    }
                  }
                });
              }
            } else if (type == 'new_invite') {
              final inviter = data['inviter'] ?? context.tr('someone');
              if (mounted) {
                 final title = context.tr('invite_title') ?? 'Lời mời Tham gia nhà';
                 final body = '${inviter} ${context.tr('invite_body') ?? 'vừa mời bạn tham gia và điều khiển nhà của họ. Hãy mở app để xác nhận!'}';
                 ref.read(notificationProvider.notifier).addNotification(title, body, 'important');
              }
            }
          }
        }
      }
    });
  }

  void _showTrustRequestDialog(String username, String targetDeviceId, String deviceName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('trust_req_title'), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        content: Text(context.l10n.trust_req_msg(deviceName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('btn_refuse'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance
                  .collection('users')
                  .doc(username)
                  .collection('sessions')
                  .doc(targetDeviceId)
                  .update({'isTrusted': true});
                if (mounted) {
                  showFloatingToast(context, context.tr('msg_success_title'), context.l10n.msg_trusted_success(deviceName));
                  ref.read(notificationProvider.notifier).addNotification(
                    context.tr('msg_success_title') ?? 'Thành công', 
                    context.l10n.msg_trusted_success(deviceName), 
                    'important'
                  );
                }
              } catch (e) {
                if (mounted) {
                  showFloatingToast(context, context.tr('msg_error_title'), context.tr('msg_trust_error'), isError: true);
                }
              }
            },
            child: Text(context.tr('btn_agree'))
          )
        ],
      )
    );
  }

  void disposeAuthSync() {
    authSubscription?.cancel();
    sessionSubscription?.cancel();
    alertsSubscription?.cancel();
  }
}
