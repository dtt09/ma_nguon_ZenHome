import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

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
            .limit(1)
            .get();
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
      final targetDoc = await FirebaseFirestore.instance.collection('users').doc(trimmed).get();
      if (!targetDoc.exists) {
        state = false;
        return const MemberOperationResult(
          success: false,
          errorMessage: 'err_user_not_found',
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(trimmed).set({
        'pendingInvitations': FieldValue.arrayUnion([currentUsername])
      }, SetOptions(merge: true));

      // Bắn Alert để Server kích hoạt thông báo Push FCM
      final inviterName = FirebaseAuth.instance.currentUser?.displayName ?? currentUsername ?? 'Ai đó';
      await FirebaseFirestore.instance.collection('users').doc(trimmed).collection('alerts').add({
        'type': 'new_invite',
        'inviter': inviterName,
        'timestamp': FieldValue.serverTimestamp(),
      });

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
      // 2. Thêm người dùng vào sharedWith của Chủ nhà
      await FirebaseFirestore.instance.collection('users').doc(ownerUsername).set({
        'sharedWith': FieldValue.arrayUnion([currentUsername])
      }, SetOptions(merge: true));

      // 3. Cập nhật ownerUsername cho chính mình và gỡ khỏi danh sách chờ
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'ownerUsername': ownerUsername,
        'pendingInvitations': FieldValue.arrayRemove([ownerUsername])
      });

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

        final newConfig = SmartConfig(
          userId: ownerUsername,
          macAddress: data['macAddress'] ?? 'unknown_mac',
          mqttServer: data['mqttServer'] ?? 'broker.emqx.io',
          mqttUser: data['mqttUser'],
          mqttPass: data['mqttPass'],
          devices: restoredDevices,
          role: assignedRole,
          homeName: 'Nhà của $ownerName',
          ownerEmail: ownerUsername,
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
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'pendingInvitations': FieldValue.arrayRemove([ownerUsername])
      });
      return MemberOperationResult(success: true, message: 'Đã từ chối lời mời từ $ownerUsername');
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Xóa thành viên khỏi ngôi nhà (Dành cho Chủ nhà)
  Future<MemberOperationResult> removeMember(String memberUsername) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'sharedWith': FieldValue.arrayRemove([memberUsername]),
        'automationEditors': FieldValue.arrayRemove([memberUsername]),
        'disabledMembers': FieldValue.arrayRemove([memberUsername]),
        'memberRoles.$memberUsername': FieldValue.delete(),
      });
      await FirebaseFirestore.instance.collection('users').doc(memberUsername).update({
        'ownerUsername': FieldValue.delete(),
        'ownerEmail': FieldValue.delete()
      });
      return MemberOperationResult(success: true, message: 'Đã gỡ quyền truy cập của $memberUsername');
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }

  /// Bật / Tắt tạm thời quyền điều khiển thiết bị của thành viên
  Future<MemberOperationResult> toggleDisableMember(String memberUsername, bool isDisabled) async {
    if (currentUsername == null) await loadCurrentUsername();
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'disabledMembers': isDisabled
            ? FieldValue.arrayUnion([memberUsername])
            : FieldValue.arrayRemove([memberUsername])
      });
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
      return MemberOperationResult(
        success: true,
        message: 'Đã cập nhật vai trò cho $memberUsername',
      );
    } catch (e) {
      return MemberOperationResult(success: false, errorMessage: e.toString());
    }
  }
}

final memberControllerProvider = StateNotifierProvider.autoDispose<MemberController, bool>((ref) {
  return MemberController(ref);
});
