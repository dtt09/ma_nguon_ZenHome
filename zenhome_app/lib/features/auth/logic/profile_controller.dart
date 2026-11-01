import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

class ProfileState {
  final String username;
  final String email;
  final String phone;
  final String displayName;
  final String birthday;
  final String? photoUrl;
  final bool isGoogleLinked;
  final bool isPhoneLinked;
  final bool isLoading;

  const ProfileState({
    this.username = '',
    this.email = '',
    this.phone = '',
    this.displayName = '',
    this.birthday = '',
    this.photoUrl,
    this.isGoogleLinked = false,
    this.isPhoneLinked = false,
    this.isLoading = false,
  });

  ProfileState copyWith({
    String? username,
    String? email,
    String? phone,
    String? displayName,
    String? birthday,
    String? photoUrl,
    bool? isGoogleLinked,
    bool? isPhoneLinked,
    bool? isLoading,
  }) {
    return ProfileState(
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      displayName: displayName ?? this.displayName,
      birthday: birthday ?? this.birthday,
      photoUrl: photoUrl ?? this.photoUrl,
      isGoogleLinked: isGoogleLinked ?? this.isGoogleLinked,
      isPhoneLinked: isPhoneLinked ?? this.isPhoneLinked,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ProfileActionResult {
  final bool success;
  final String? message;
  final String? errorCode;
  final String? errorMessage;

  const ProfileActionResult({
    required this.success,
    this.message,
    this.errorCode,
    this.errorMessage,
  });
}

/// Controller quản lý logic hồ sơ người dùng, liên kết định danh (Google/Phone) và xóa tài khoản
class ProfileController extends StateNotifier<ProfileState> {
  final Ref _ref;

  ProfileController(this._ref) : super(const ProfileState());

  User? get currentUser => FirebaseAuth.instance.currentUser;

  /// Tải thông tin hồ sơ người dùng từ Firebase Auth và Firestore
  Future<void> fetchUserData() async {
    final user = currentUser;
    if (user == null) return;

    bool phoneLinked = false;
    for (var provider in user.providerData) {
      if (provider.providerId == 'phone') phoneLinked = true;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final username = doc.id;
        final data = doc.data();

        final googleEmail = getDisplayEmail(user);
        final bool hasValidGoogleEmail = googleEmail.isNotEmpty;

        if (hasValidGoogleEmail) {
          if (data['email'] != googleEmail) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(username)
                .update({'email': googleEmail});
            data['email'] = googleEmail;
          }
        } else {
          if (data['email'] != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(username)
                .update({'email': FieldValue.delete()});
            data.remove('email');
          }
        }

        String phone = data['phoneNumber'] ?? '';
        if (phone.isEmpty && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          phone = user.phoneNumber!;
        }
        if (phone.isEmpty && user.email != null && user.email!.endsWith('@zenhome.local')) {
          String raw = user.email!.replaceAll('@zenhome.local', '');
          phone = raw.startsWith('+') ? raw : '+$raw';
        }

        state = state.copyWith(
          username: username,
          email: googleEmail,
          phone: phone,
          displayName: user.displayName ?? '',
          birthday: data['birthday'] ?? '',
          photoUrl: user.photoURL,
          isGoogleLinked: hasValidGoogleEmail,
          isPhoneLinked: phone.isNotEmpty || phoneLinked,
        );
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu người dùng: $e');
    }
  }

  /// Cập nhật họ tên và ngày sinh
  Future<ProfileActionResult> saveProfileChanges({
    required String newName,
    required String newBirthday,
  }) async {
    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(success: false, errorMessage: 'User not authenticated');
    }

    state = state.copyWith(isLoading: true);
    try {
      final trimmedName = newName.trim();
      final trimmedBirthday = newBirthday.trim();

      if (trimmedName != user.displayName) {
        await user.updateDisplayName(trimmedName);
      }

      if (state.username.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(state.username).update({
          'displayName': trimmedName,
          'birthday': trimmedBirthday,
        });
      }

      state = state.copyWith(
        displayName: trimmedName,
        birthday: trimmedBirthday,
        isLoading: false,
      );
      return const ProfileActionResult(success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return ProfileActionResult(success: false, errorMessage: e.toString());
    }
  }

  /// Cập nhật ảnh đại diện người dùng
  Future<ProfileActionResult> updateAvatar(String newUrl) async {
    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(success: false, errorMessage: 'User not authenticated');
    }

    state = state.copyWith(isLoading: true);
    try {
      await user.updatePhotoURL(newUrl);
      await user.reload();

      if (state.username.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(state.username)
            .update({'photoURL': newUrl});
      }

      state = state.copyWith(photoUrl: newUrl, isLoading: false);
      return const ProfileActionResult(success: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return ProfileActionResult(success: false, errorMessage: e.toString());
    }
  }

  /// Hủy liên kết tài khoản Google
  Future<ProfileActionResult> unlinkGoogle() async {
    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(success: false, errorMessage: 'User not authenticated');
    }

    try {
      await user.unlink('google.com');
      await GoogleSignIn().signOut();

      if (state.username.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(state.username).update({
          'email': FieldValue.delete(),
        });
      }

      await user.reload();
      await fetchUserData();
      return const ProfileActionResult(success: true);
    } catch (e) {
      return ProfileActionResult(success: false, errorMessage: e.toString());
    }
  }

  /// Liên kết tài khoản Google mới
  Future<ProfileActionResult> linkGoogle(AuthCredential credential, String email) async {
    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(success: false, errorMessage: 'User not authenticated');
    }

    try {
      await user.linkWithCredential(credential);

      if (state.username.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(state.username).update({
          'email': email,
        });
      }

      await user.reload();
      await fetchUserData();
      return const ProfileActionResult(success: true);
    } on FirebaseAuthException catch (e) {
      return ProfileActionResult(
        success: false,
        errorCode: e.code,
        errorMessage: e.message ?? e.toString(),
      );
    } catch (e) {
      return ProfileActionResult(success: false, errorMessage: e.toString());
    }
  }

  /// Hủy liên kết số điện thoại
  Future<ProfileActionResult> unlinkPhone() async {
    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(success: false, errorMessage: 'User not authenticated');
    }

    try {
      for (var p in user.providerData) {
        if (p.providerId == 'phone') {
          await user.unlink('phone');
          break;
        }
      }

      if (state.phoneNumber != null && state.phoneNumber!.isNotEmpty) {
        String phoneToDelete = state.phoneNumber!;
        if (phoneToDelete.startsWith('0')) phoneToDelete = '+84${phoneToDelete.substring(1)}';
        else if (!phoneToDelete.startsWith('+')) phoneToDelete = '+$phoneToDelete';
        try {
          await FirebaseFirestore.instance.collection('phone_lookup').doc(phoneToDelete).delete();
        } catch (_) {}
      }

      if (state.username.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(state.username).update({
          'phoneNumber': FieldValue.delete(),
        });
      }

      await user.reload();
      await fetchUserData();
      return const ProfileActionResult(success: true);
    } catch (e) {
      return ProfileActionResult(success: false, errorMessage: e.toString());
    }
  }

  /// Thực hiện gửi yêu cầu xóa tài khoản và dọn dẹp phiên đăng nhập
  Future<ProfileActionResult> executeAccountDeletion(String targetUsername) async {
    final user = currentUser;
    if (user == null) {
      return const ProfileActionResult(success: false, errorMessage: 'User not authenticated');
    }

    try {
      await FirebaseFirestore.instance.collection('delete_requests').doc(targetUsername).set({
        'uid': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await SessionManager.clearSession();
      await _ref.read(homeConfigProvider).clearAllHomes();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_history');

      try {
        await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}

      return const ProfileActionResult(success: true);
    } catch (e) {
      return ProfileActionResult(success: false, errorMessage: e.toString());
    }
  }
}

final profileControllerProvider = StateNotifierProvider.autoDispose<ProfileController, ProfileState>((ref) {
  return ProfileController(ref);
});
