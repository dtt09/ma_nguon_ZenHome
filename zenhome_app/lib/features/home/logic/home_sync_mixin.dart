import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';

mixin HomeSyncMixin on ConsumerState<MainLayout> {
  StreamSubscription<DocumentSnapshot>? ownerUpdateSubscription;
  String? cachedUsername;
  bool isDisabled = false;

  void initHomeSync() {
    listenForOwnerUpdates();
  }

  void listenForOwnerUpdates() {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    if (activeConfig.ownerEmail != null && activeConfig.ownerEmail!.isNotEmpty) {
      ownerUpdateSubscription = FirebaseFirestore.instance.collection('users').doc(activeConfig.ownerEmail).snapshots().listen((docSnapshot) async {
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;
          final activeConfig = ref.read(homeConfigProvider).activeConfig;
          bool needReconnect = false;
          bool configChanged = false;

          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null && cachedUsername == null) {
            final userQuery = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: currentUser.uid).get();
            if (userQuery.docs.isNotEmpty) cachedUsername = userQuery.docs.first.id;
          }

          if (cachedUsername != null && activeConfig.role != 'owner') {
            if (data.containsKey('sharedWith')) {
              List<dynamic> shared = data['sharedWith'];
              if (!shared.contains(cachedUsername)) {
                _handleKickedFromHome();
                return;
              }
            }

            if (data.containsKey('disabledMembers')) {
              final List<dynamic> disabledMembers = data['disabledMembers'];
              bool currentlyDisabled = disabledMembers.contains(cachedUsername);
              if (isDisabled != currentlyDisabled) {
                if (mounted) setState(() => isDisabled = currentlyDisabled);
                if (currentlyDisabled) {
                  ref.read(mqttRepositoryProvider).disconnect();
                } else {
                  needReconnect = true;
                }
              }
            }

            if (data.containsKey('memberRoles')) {
              Map<String, dynamic> memberRoles = data['memberRoles'];
              String assignedRole = memberRoles[cachedUsername] ?? 'member';
              if (activeConfig.role != assignedRole) {
                activeConfig.role = assignedRole;
                configChanged = true;
              }
            } else if (activeConfig.role != 'member') {
              activeConfig.role = 'member';
              configChanged = true;
            }
            
            if (data.containsKey('automationEditors')) {
              final List<dynamic> editors = data['automationEditors'];
              bool canEdit = editors.contains(cachedUsername);
              if (activeConfig.canEditAutomation != canEdit) {
                activeConfig.canEditAutomation = canEdit;
                configChanged = true;
              }
            } else if (activeConfig.canEditAutomation != false) {
              activeConfig.canEditAutomation = false;
              configChanged = true;
            }
          }

          if (data.containsKey('devices') && data['devices'] != null) {
            List<DeviceConfig> restoredDevices = (data['devices'] as List)
                .map((e) => DeviceConfig.fromJson(e))
                .toList();
            if (jsonEncode(activeConfig.devices) != jsonEncode(restoredDevices)) {
              activeConfig.devices = restoredDevices;
              needReconnect = true;
              configChanged = true;
            }
          } else if (activeConfig.devices.isNotEmpty) {
             activeConfig.devices = [];
             needReconnect = true;
             configChanged = true;
          }
          
          if (data.containsKey('mqttServer') && activeConfig.mqttServer != data['mqttServer']) {
            activeConfig.mqttServer = data['mqttServer'];
            needReconnect = true;
            configChanged = true;
          }
          if (data.containsKey('mqttUser') && activeConfig.mqttUser != data['mqttUser']) {
            activeConfig.mqttUser = data['mqttUser'];
            needReconnect = true;
            configChanged = true;
          }
          if (data.containsKey('mqttPass') && activeConfig.mqttPass != data['mqttPass']) {
            activeConfig.mqttPass = data['mqttPass'];
            needReconnect = true;
            configChanged = true;
          }
          
          if (data.containsKey('macAddress')) {
            if (activeConfig.macAddress != data['macAddress']) {
              activeConfig.macAddress = data['macAddress'] ?? 'unknown_mac';
              needReconnect = true;
              configChanged = true;
            }
          } else if (activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty) {
             activeConfig.macAddress = 'unknown_mac';
             needReconnect = true;
             configChanged = true;
          }

          if (configChanged) {
            await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);
            if (mounted) setState(() {});
          }

          if (needReconnect) {
            ref.read(mqttRepositoryProvider).disconnect();
            ref.read(mqttRepositoryProvider).connect(
              userId: activeConfig.userId,
              mqttServer: activeConfig.mqttServer,
              mqttPrefix: activeConfig.mqttPrefix,
              dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
              mqttUser: activeConfig.mqttUser,
              mqttPass: activeConfig.mqttPass,
            );
          }
        } else {
          _handleKickedFromHome();
        }
      });
    }
  }

  void _handleKickedFromHome() async {
    ownerUpdateSubscription?.cancel();
    
    final currentConfig = ref.read(homeConfigProvider).activeConfig;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${currentConfig.userId}');
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${currentConfig.userId}_vi');
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${currentConfig.userId}_en');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
    
    final provider = ref.read(homeConfigProvider);
    final remainingHomes = provider.availableHomes.where((h) => h.userId != currentConfig.userId).toList();
    await provider.setAvailableHomes(remainingHomes);
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr('error') ?? 'Thông báo', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(context.tr('msg_kicked_desc') ?? 'Bạn đã bị thu hồi quyền truy cập khỏi nhà này. Hệ thống sẽ tự động chuyển về không gian làm việc mặc định.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const MainLayout()),
                );
              },
              child: Text(context.tr('btn_agree') ?? 'Đồng ý'),
            )
          ],
        ),
      );
    }
  }

  void disposeHomeSync() {
    ownerUpdateSubscription?.cancel();
  }
}
