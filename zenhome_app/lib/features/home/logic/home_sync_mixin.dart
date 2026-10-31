import 'dart:async';

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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:zenhome_app/core/services/local_network_service.dart';

import 'package:zenhome_app/core/services/ble_local_service.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';



mixin HomeSyncMixin on ConsumerState<MainLayout> {

  StreamSubscription<DocumentSnapshot>? userDocSubscription;

  StreamSubscription<DocumentSnapshot>? ownerUpdateSubscription;

  Timer? _reconnectDebounceTimer;

  String? cachedUsername;

  bool isDisabled = false;



  void initHomeSync() {

    listenForHomeUpdates();

  }



  bool _areDevicesEqual(List<DeviceConfig> a, List<DeviceConfig> b) {

    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {

      if (a[i].id != b[i].id ||

          a[i].name != b[i].name ||

          a[i].pin != b[i].pin ||

          a[i].room != b[i].room ||

          a[i].icon != b[i].icon) {

        return false;

      }

    }

    return true;

  }



  void listenForHomeUpdates() async {

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null && cachedUsername == null) {

      final userQuery = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: currentUser.uid).limit(1).get();

      if (userQuery.docs.isNotEmpty) {

        cachedUsername = userQuery.docs.first.id;

      }

    }



    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    String targetDocId = activeConfig.ownerEmail ?? activeConfig.userId;

    if (targetDocId.isEmpty || targetDocId == 'guest') {

      if (cachedUsername != null && cachedUsername!.isNotEmpty) {

        targetDocId = cachedUsername!;

      }

    }



    // 1. Lắng nghe cập nhật của chính tài khoản người dùng

    if (cachedUsername != null && cachedUsername!.isNotEmpty) {

      userDocSubscription?.cancel();

      userDocSubscription = FirebaseFirestore.instance.collection('users').doc(cachedUsername).snapshots().listen((docSnapshot) async {

        if (!docSnapshot.exists) return;

        final data = docSnapshot.data() as Map<String, dynamic>;



        // Nếu người dùng đang ở nhà của chính mình (owner), đồng bộ ngay thiết bị & MAC

        final currentActive = ref.read(homeConfigProvider).activeConfig;

        if (currentActive.userId == cachedUsername) {

          _processDocUpdate(data, currentActive);

        }



        // Kiểm tra xem có nhà được mời mới (ownerUsername) không

        if (data.containsKey('ownerUsername')) {

          String? ownerUser = data['ownerUsername'];

          bool hasShared = ref.read(homeConfigProvider).availableHomes.any((h) => h.userId == ownerUser);

          if (ownerUser != null && ownerUser.isNotEmpty && !hasShared) {

            await ref.read(homeConfigProvider).syncFromFirestore();

          }

        }

      }, onError: (err) {

        debugPrint("Lỗi stream user doc: $err");

      });

    }



    // 2. Lắng nghe cập nhật của nhà đang chọn (nếu là nhà được chia sẻ khác với tài khoản chính)

    if (targetDocId.isNotEmpty && targetDocId != 'guest' && targetDocId != cachedUsername) {

      ownerUpdateSubscription?.cancel();

      ownerUpdateSubscription = FirebaseFirestore.instance.collection('users').doc(targetDocId).snapshots().listen((docSnapshot) async {

        final currentActive = ref.read(homeConfigProvider).activeConfig;

        if (docSnapshot.exists) {

          final data = docSnapshot.data() as Map<String, dynamic>;

          _processDocUpdate(data, currentActive);

        } else {
          if (currentActive.role != 'owner') {
            _handleKickedFromHome();
          }
        }

      }, onError: (err) {

        debugPrint("Lỗi stream owner doc: $err");

      });

    }

  }



  void _processDocUpdate(Map<String, dynamic> data, SmartConfig activeConfig) async {

    bool needReconnect = false;

    bool configChanged = false;



    // Kiểm tra quyền thành viên nếu là nhà được mời

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

      }



      if (data.containsKey('automationEditors')) {

        final List<dynamic> editors = data['automationEditors'];

        bool canEdit = editors.contains(cachedUsername);

        if (activeConfig.canEditAutomation != canEdit) {

          activeConfig.canEditAutomation = canEdit;

          configChanged = true;

        }

      }



      if (data.containsKey('memberDevicePermissions')) {

        Map<String, dynamic> devPerms = Map<String, dynamic>.from(data['memberDevicePermissions'] ?? {});

        if (devPerms.containsKey(cachedUsername)) {

          List<dynamic> allowedList = devPerms[cachedUsername] ?? [];

          activeConfig.allowedDevices = allowedList.map((e) => e.toString()).toList();

          configChanged = true;

        } else if (activeConfig.allowedDevices != null) {

          activeConfig.allowedDevices = null;

          configChanged = true;

        }

      } else if (activeConfig.allowedDevices != null) {

        activeConfig.allowedDevices = null;

        configChanged = true;

      }

    }



    // Đồng bộ danh sách thiết bị

    if (data.containsKey('devices') && data['devices'] != null) {

      List<DeviceConfig> restoredDevices = (data['devices'] as List)

          .map((e) => DeviceConfig.fromJson(e))

          .toList();

      if (!_areDevicesEqual(activeConfig.devices, restoredDevices)) {

        activeConfig.devices = restoredDevices;

        needReconnect = true;

        configChanged = true;

      }

    } else if (activeConfig.devices.isNotEmpty) {

      activeConfig.devices = [];

      needReconnect = true;

      configChanged = true;

    }



    // Đồng bộ MAC Address

    if (data.containsKey('macAddress')) {

      if (activeConfig.macAddress != data['macAddress']) {

        final rawMac = data['macAddress']?.toString() ?? '';
        activeConfig.macAddress = (rawMac == 'unknown_mac' || rawMac == 'unknown') ? '' : rawMac;

        needReconnect = true;

        configChanged = true;

      }

    }



    // Đồng bộ MQTT Server

    if (data.containsKey('mqttServer') && activeConfig.mqttServer != data['mqttServer']) {

      activeConfig.mqttServer = data['mqttServer'];

      needReconnect = true;

      configChanged = true;

    }



    if (configChanged) {

      await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

      ref.read(homeConfigProvider).notifyChanges();

      // Đồng bộ phân quyền và cấu hình mới nhất cho mạng cục bộ & BLE

      ref.read(localNetworkServiceProvider).startMonitoring(

        targetMac: activeConfig.macAddress,

        adminPass: activeConfig.adminPass,

        userId: activeConfig.userId,

        role: activeConfig.role,

        allowedDevices: activeConfig.allowedDevices,

      );

      if (mounted) setState(() {});

    }



    if (needReconnect) {

      _reconnectDebounceTimer?.cancel();

      _reconnectDebounceTimer = Timer(const Duration(milliseconds: 600), () {

        if (!mounted) return;

        ref.read(mqttRepositoryProvider).disconnect();

        ref.read(mqttRepositoryProvider).connect(

          userId: activeConfig.userId,

          mqttServer: activeConfig.mqttServer,

          mqttPrefix: activeConfig.mqttPrefix,

          dynamicTopics: getDynamicDeviceTopicsList(activeConfig),

          mqttUser: activeConfig.mqttUser,

          mqttPass: activeConfig.mqttPass,

        );

      });

    }

  }



  void _handleKickedFromHome() async {

    ownerUpdateSubscription?.cancel();

    

    final currentConfig = ref.read(homeConfigProvider).activeConfig;

    

    // Ngắt toàn bộ kết nối cục bộ và BLE, xóa khóa bảo mật của Hub này

    ref.read(localNetworkServiceProvider).stopMonitoring();

    BleLocalService().stop();

    if (currentConfig.macAddress.isNotEmpty && currentConfig.macAddress != 'unknown_mac') {

      final clean = currentConfig.macAddress.replaceAll(':', '').replaceAll('-', '').trim().toUpperCase();

      try {

        const FlutterSecureStorage().delete(key: 'local_sec_key_' + clean);

      } catch (_) {}

    }

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

          title: Text(context.tr('error'), style: const TextStyle(fontWeight: FontWeight.bold)),

          content: Text(context.tr('msg_kicked_desc')),

          actions: [

            ElevatedButton(

              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white),

              onPressed: () {

                Navigator.pop(ctx);

                Navigator.of(context).pushReplacement(

                  MaterialPageRoute(builder: (context) => const MainLayout()),

                );

              },

              child: Text(context.tr('btn_agree')),

            )

          ],

        ),

      );

    }

  }



  void disposeHomeSync() {

    _reconnectDebounceTimer?.cancel();

    userDocSubscription?.cancel();

    ownerUpdateSubscription?.cancel();

  }

}



