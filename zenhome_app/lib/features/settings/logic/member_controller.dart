import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/services/local_network_service.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';

class MemberOperationResult {
  final bool success;
  final String? message;
  final String? errorMessage;

  const MemberOperationResult({
    required this.success,
    this.message,
    this.errorMessage,
  });
}

/// Controller quản lý toàn bộ nghiệp vụ Mời thành viên, Phân quyền và Rời nhà
class MemberController extends StateNotifier<bool> {
  final Ref _ref;
  String? currentUsername;

  MemberController(this._ref) : super(false); // state = isLoading

  /// Tải username hiện tại từ UID người dùng đang đăng nhập
  Future<String?> loadCurrentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .get();
        for (var doc in query.docs) {
          if (doc.data()['isSubHome'] != true) {
            await FirebaseFirestore.instance.collection('membership_identities').doc(user.uid).set({'username': doc.id});
            currentUsername = doc.id;
            return currentUsername;
          }
        }
        if (query.docs.isNotEmpty) {
          currentUsername = query.docs.first.id;
          return currentUsername;
        }
      } catch (e) {
        debugPrint('Lỗi tải username: $e');
      }
    }
    return null;
  }

  /// Stream lắng nghe tài liệu Firestore của chính người dùng
  Stream<DocumentSnapshot>? getMyDataStream() {
    if (currentUsername == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(currentUsername).snapshots();
  }

  /// Gửi lời mời tham gia ngôi nhà cho một username khác
  Future<MemberOperationResult> sendInvite(String targetUsername) async {
    if (currentUsername == null) await loadCurrentUsername();

    final activeConfig = _ref.read(homeConfigProvider).activeConfig;
    final bool isEspLinked = activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown';

    if (!isEspLinked) {
      return const MemberOperationResult(
        success: false,
        errorMessage: 'err_esp_required_for_invite',
      );
    }

    final trimmed = targetUsername.trim();
    if (trimmed.isEmpty) {
      return const MemberOperationResult(
        success: false,
        errorMessage: 'Vui lòng nhập Username hợp lệ',
      );
    }
    if (trimmed == currentUsername) {
      return const MemberOperationResult(
        success: false,
        errorMessage: 'err_self_invite',
      );
    }

    state = true;
    try {
      final db = FirebaseFirestore.instance;
      final owner = db.collection('users').doc(currentUsername!);
      final target = db.collection('users').doc(trimmed);
      final batch = db.batch();
      batch.update(owner, {'sentInvitations': FieldValue.arrayUnion([trimmed])});
      batch.update(target, {'pendingInvitations': FieldValue.arrayUnion([currentUsername])});
      batch.set(target.collection('alerts').doc(), {
        'type': 'new_invite',
        'inviter': currentUsername,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      state = false;
      return MemberOperationResult(
        success: true,
        message: 'Đã gửi lời mời tới $trimmed',
      );
    } catch (e) {
      state = false;
      return MemberOperationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Thu hồi / Hủy lời mời đã gửi trước đó
  Future<MemberOperationResult> cancelSentInvite(String targetUsername) async {
    if (currentUsername == null) await loadCurrentUsername();
    state = true;
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('users').doc(targetUsername), {
        'pendingInvitations': FieldValue.arrayRemove([currentUsername])
      });
      batch.update(db.collection('users').doc(currentUsername!), {
        'sentInvitations': FieldValue.arrayRemove([targetUsername])
      });
      await batch.commit();

      state = false;
      return MemberOperationResult(
        success: true,
        message: 'Đã thu hồi lời mời tới $targetUsername',
      );
    } catch (e) {
      state = false;
      return MemberOperationResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Chấp nhận lời mời tham gia ngôi nhà của chủ nhà
  Future<MemberOperationResult> acceptInvite(String ownerUsername) async {
    if (currentUsername == null) await loadCurrentUsername();
    state = true;

    final activeConfig = _ref.read(homeConfigProvider).activeConfig;

    try {
      // 1. Hủy đăng ký topic FCM của nhà cũ
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}');
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}_vi');
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}_en');
    } catch (e) {
      debugPrint('Lỗi hủy topic FCM: $e');
    }

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('users').doc(ownerUsername), {
        'sharedWith': FieldValue.arrayUnion([currentUsername]),
        'sharedUids': FieldValue.arrayUnion([uid]),
        'memberUids.$currentUsername': uid,
        'sentInvitations': FieldValue.arrayRemove([currentUsername]),
      });
      batch.update(db.collection('users').doc(currentUsername!), {
        'ownerUsername': ownerUsername,
        'sharedHomeIds': FieldValue.arrayUnion([ownerUsername]),
        'pendingInvitations': FieldValue.arrayRemove([ownerUsername]),
      });
      await batch.commit();

      // 4. Lấy dữ liệu nhà chủ và chuyển không gian làm việc
      final targetDoc = await FirebaseFirestore.instance.collection('users').doc(ownerUsername).get();
      if (targetDoc.exists) {
        final data = targetDoc.data() as Map<String, dynamic>;
        List<DeviceConfig> restoredDevices = [];
        if (data.containsKey('devices') && data['devices'] != null) {
          restoredDevices = (data['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
        }

        String ownerName = data['displayName'] ?? ownerUsername;
        String assignedRole = 'member';
        if (data['memberRoles'] != null && data['memberRoles'][currentUsername] != null) {
          assignedRole = data['memberRoles'][currentUsername];
        }

        bool canEdit = false;
        if (assignedRole == 'co_owner' ||
            (data['automationEditors'] != null && (data['automationEditors'] as List).contains(currentUsername))) {
          canEdit = true;
        }

        List<String>? allowedDevs;
        if (data['memberDevicePermissions'] != null &&
            data['memberDevicePermissions'][currentUsername] != null) {
          allowedDevs = List<String>.from(data['memberDevicePermissions'][currentUsername]);
        }

        bool isUserDisabled = false;
        if (data['disabledMembers'] != null && (data['disabledMembers'] as List).contains(currentUsername)) {
          isUserDisabled = true;
        }

        final newConfig = SmartConfig(
          userId: ownerUsername,
          macAddress: (data['macAddress'] == 'unknown_mac' || data['macAddress'] == 'unknown' || data['macAddress'] == null) ? '' : data['macAddress'],
          mqttServer: (data['mqttServer'] != null && data['mqttServer'].toString().isNotEmpty && data['mqttServer'] != 'broker.emqx.io')
              ? data['mqttServer']
              : 'e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud',
          mqttUser: data['mqttUser'],
          mqttPass: null,
          devices: restoredDevices,
          role: assignedRole,
          homeName: 'Nhà của $ownerName',
          ownerEmail: ownerUsername,
          canEditAutomation: canEdit,
          allowedDevices: allowedDevs,
          isDisabled: isUserDisabled,
        );

        await _ref.read(homeConfigProvider).saveConfigToStorage(newConfig);
        await _ref.read(homeConfigProvider).switchActiveHome(ownerUsername);
      }

      // 5. Đăng ký nhận thông báo FCM của nhà mới
      try {
        final prefs = await SharedPreferences.getInstance();
        String lang = prefs.getString('app_lang') ?? 'en';
        await FirebaseMessaging.instance.subscribeToTopic('home_${ownerUsername}_$lang');
      } catch (e) {
        debugPrint('Lỗi subscribe FCM: $e');
      }

      state = false;
      return const MemberOperationResult(success: true);
    } catch (e) {
      state = false;
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Từ chối lời mời vào nhà
  Future<MemberOperationResult> rejectInvite(String ownerUsername) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('users').doc(currentUsername!), {
        'pendingInvitations': FieldValue.arrayRemove([ownerUsername])
      });
      batch.update(db.collection('users').doc(ownerUsername), {
        'sentInvitations': FieldValue.arrayRemove([currentUsername])
      });
      await batch.commit();
      return MemberOperationResult(success: true, message: 'Đã từ chối lời mời từ $ownerUsername');
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Xóa thành viên khỏi ngôi nhà (Dành cho Chủ nhà)
  Future<MemberOperationResult> removeMember(String memberUsername) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      final owner = FirebaseFirestore.instance.collection('users').doc(currentUsername!);
      final members = (await owner.get()).data()?['memberUids'];
      final memberUid = members is Map ? members[memberUsername] as String? : null;

      final Map<String, dynamic> ownerUpdates = {
        'sharedWith': FieldValue.arrayRemove([memberUsername]),
        'automationEditors': FieldValue.arrayRemove([memberUsername]),
        'disabledMembers': FieldValue.arrayRemove([memberUsername]),
        'memberUids.$memberUsername': FieldValue.delete(),
        'memberRoles.$memberUsername': FieldValue.delete(),
        'memberDevicePermissions.$memberUsername': FieldValue.delete(),
      };
      if (memberUid != null && memberUid.isNotEmpty) {
        ownerUpdates['sharedUids'] = FieldValue.arrayRemove([memberUid]);
        ownerUpdates['disabledUids'] = FieldValue.arrayRemove([memberUid]);
      }

      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update(ownerUpdates);
      _syncToLocalHubIfAvailable();
      return MemberOperationResult(success: true, message: 'Đã gỡ quyền truy cập của $memberUsername');
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Cập nhật quyền truy cập thiết bị cụ thể cho thành viên
  Future<MemberOperationResult> updateDevicePermissions(String memberUsername, List<String> allowedDevices) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      if (allowedDevices.isEmpty) {
        // Cho phép toàn bộ thiết bị (xóa giới hạn riêng)
        await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
          'memberDevicePermissions.$memberUsername': FieldValue.delete(),
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(currentUsername).set({
          'memberDevicePermissions': {
            memberUsername: allowedDevices,
          }
        }, SetOptions(merge: true));
      }
      _syncToLocalHubIfAvailable();
      return MemberOperationResult(
        success: true,
        message: 'Đã cập nhật quyền thiết bị cho $memberUsername',
      );
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Bật / Tắt tạm thời quyền điều khiển thiết bị của thành viên
  Future<MemberOperationResult> toggleDisableMember(String memberUsername, bool isDisabled) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      final owner = FirebaseFirestore.instance.collection('users').doc(currentUsername!);
      final members = (await owner.get()).data()?['memberUids'];
      final memberUid = members is Map ? members[memberUsername] as String? : null;

      final Map<String, dynamic> ownerUpdates = {
        'disabledMembers': isDisabled
            ? FieldValue.arrayUnion([memberUsername])
            : FieldValue.arrayRemove([memberUsername])
      };
      if (memberUid != null && memberUid.isNotEmpty) {
        ownerUpdates['disabledUids'] = isDisabled
            ? FieldValue.arrayUnion([memberUid])
            : FieldValue.arrayRemove([memberUid]);
      }

      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update(ownerUpdates);
      _syncToLocalHubIfAvailable();
      return MemberOperationResult(
        success: true,
        message: isDisabled ? 'Đã vô hiệu hóa $memberUsername' : 'Đã mở khóa $memberUsername',
      );
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Bật / Tắt quyền chỉnh sửa tự động hóa (Hẹn giờ, Lịch trình, Ngữ cảnh)
  Future<MemberOperationResult> toggleAutomationEditor(String memberUsername, bool canEdit) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'automationEditors': canEdit
            ? FieldValue.arrayUnion([memberUsername])
            : FieldValue.arrayRemove([memberUsername])
      });
      return MemberOperationResult(
        success: true,
        message: canEdit ? 'Đã cấp quyền tự động hóa cho $memberUsername' : 'Đã thu hồi quyền tự động hóa của $memberUsername',
      );
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Thay đổi chức vụ / vai trò của thành viên trong nhà (co_owner hoặc member)
  Future<MemberOperationResult> changeRole(String memberUsername, String newRole) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).set({
        'memberRoles': {
          memberUsername: newRole
        }
      }, SetOptions(merge: true));
      _syncToLocalHubIfAvailable();
      return MemberOperationResult(
        success: true,
        message: 'Đã cập nhật vai trò cho $memberUsername',
      );
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Tự động đẩy phân quyền thành viên xuống Hub qua mạng LAN nếu Hub đang online trên cùng mạng Wi-Fi
  Future<void> _syncToLocalHubIfAvailable() async {
    try {
      if (currentUsername == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUsername).get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};
      final membersList = <Map<String, dynamic>>[];
      if (data['sharedWith'] is List) {
        for (var m in (data['sharedWith'] as List)) {
          final mStr = m.toString();
          final role = (data['memberRoles'] is Map && data['memberRoles'][mStr] != null) ? data['memberRoles'][mStr] : 'member';
          final disabled = (data['disabledMembers'] is List && (data['disabledMembers'] as List).contains(mStr));
          final allowed = (data['memberDevicePermissions'] is Map && data['memberDevicePermissions'][mStr] is List)
              ? List<String>.from(data['memberDevicePermissions'][mStr])
              : <String>[];
          membersList.add({
            'user': mStr,
            'role': role,
            'disabled': disabled,
            'allowed': allowed,
            'allowedDevices': allowed,
          });
        }
      }
      final payload = {
        'owner': currentUsername,
        'members': membersList,
        'disabled': data['disabledMembers'] ?? [],
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      // 1. Đồng bộ qua mạng nội bộ LAN nếu đang cùng mạng Wi-Fi
      await LocalNetworkService().syncMembersToHub(payload);

      // 2. Đồng bộ tức thời qua Cloud MQTT để Hub nhận lệnh ngay cả khi Chủ nhà ở xa (4G/Công tác)
      final activeConfig = _ref.read(homeConfigProvider).activeConfig;
      if (activeConfig.mqttPrefix.isNotEmpty && !activeConfig.mqttPrefix.startsWith('guest/')) {
        final mqttTopic = '${activeConfig.mqttPrefix}/system/members';
        _ref.read(mqttRepositoryProvider).publishCmd(mqttTopic, jsonEncode(payload));

        final cleanPrefix = activeConfig.mqttPrefix.replaceAll(':', '');
        if (cleanPrefix != activeConfig.mqttPrefix) {
          _ref.read(mqttRepositoryProvider).publishCmd('$cleanPrefix/system/members', jsonEncode(payload));
        }
      }
    } catch (_) {}
  }
}

final memberControllerProvider = StateNotifierProvider.autoDispose<MemberController, bool>((ref) {
  return MemberController(ref);
});
