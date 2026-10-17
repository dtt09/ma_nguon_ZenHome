import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/auth/ui/change_password_screen.dart';
import 'package:zenhome_app/features/auth/ui/logged_devices_screen.dart';
import 'package:zenhome_app/features/auth/ui/update_email_phone_screen.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  
  String _currentUsername = '';
  String _currentEmail = '';
  String _currentPhone = '';
  bool _isGoogleLinked = false;
  bool _isPhoneLinked = false;
  bool _isLoading = false;
  bool _hasChanges = false;
  String _initialName = '';
  String _initialBirthday = '';

  @override
  void initState() {
    super.initState();
    _initialName = user?.displayName ?? '';
    _nameController.text = _initialName;
    _currentEmail = getDisplayEmail(user);
    _checkLinkedProviders();
    _fetchUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _checkLinkedProviders() {
    if (user != null) {
      _isGoogleLinked = false;
      _isPhoneLinked = false;
      for (var provider in user!.providerData) {
        if (provider.providerId == 'google.com') {
          if (provider.email != null && provider.email!.toLowerCase().endsWith('@gmail.com')) {
            _isGoogleLinked = true;
          }
        }
        if (provider.providerId == 'phone') _isPhoneLinked = true;
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user!.uid)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        _currentUsername = doc.id;
        final data = doc.data();

        final googleEmail = getDisplayEmail(user);
        final bool hasValidGoogleEmail = googleEmail.isNotEmpty;

        if (hasValidGoogleEmail) {
          if (data['email'] != googleEmail) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUsername)
                .update({'email': googleEmail});
            data['email'] = googleEmail;
          }
        } else {
          // Nếu không có Google hoặc không phải @gmail.com, xoá email khỏi Firestore
          if (data['email'] != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUsername)
                .update({'email': FieldValue.delete()});
            data.remove('email');
          }
        }

        String phone = data['phoneNumber'] ?? '';
        if (phone.isEmpty && user!.phoneNumber != null && user!.phoneNumber!.isNotEmpty) {
          phone = user!.phoneNumber!;
        }
        if (phone.isEmpty &&
            user!.email != null &&
            user!.email!.endsWith('@zenhome.local')) {
          String raw = user!.email!.replaceAll('@zenhome.local', '');
          phone = raw.startsWith('+') ? raw : '+$raw';
        }

        if (mounted) {
          setState(() {
            _currentEmail = googleEmail;
            _currentPhone = phone;
            _isGoogleLinked = hasValidGoogleEmail;
            _isPhoneLinked = phone.isNotEmpty;
            _birthdayController.text = data['birthday'] ?? '';
            _initialBirthday = _birthdayController.text;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  void _checkForChanges() {
    final changed = _nameController.text.trim() != _initialName.trim() ||
        _birthdayController.text.trim() != _initialBirthday.trim();
    if (changed != _hasChanges) {
      setState(() => _hasChanges = changed);
    }
  }

  Future<void> _saveProfileChanges() async {
    if (!_hasChanges) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      final newName = _nameController.text.trim();
      if (newName != user?.displayName) {
        await user?.updateDisplayName(newName);
      }

      if (_currentUsername.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUsername)
            .update({
          'displayName': newName,
          'birthday': _birthdayController.text.trim(),
        });
      }

      _initialName = newName;
      _initialBirthday = _birthdayController.text.trim();
      setState(() => _hasChanges = false);

      if (mounted) {
        showFloatingToast(
          context,
          context.tr('toast_success') ?? 'Thành công',
          context.tr('msg_profile_updated') ?? 'Thông tin hồ sơ đã được lưu',
        );
      }
    } catch (e) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectBirthday() async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 365 * 20));
    if (_birthdayController.text.isNotEmpty) {
      final parts = _birthdayController.text.split('/');
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          initial = DateTime(y, m, d);
        }
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF14B8A6),
                    surface: Color(0xFF1E293B),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF0F766E),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      setState(() {
        _birthdayController.text = formatted;
      });
      _checkForChanges();
    }
  }

  void _updateAvatar() {
    String newUrl = '';
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            context.tr('update_avatar') ?? 'Cập nhật ảnh đại diện',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            onChanged: (val) => newUrl = val.trim(),
            decoration: InputDecoration(
              hintText: context.tr('enter_image_url') ?? 'Nhập link ảnh (URL)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.link),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                context.tr('btn_cancel') ?? 'Hủy',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                if (newUrl.isNotEmpty) {
                  setState(() => _isLoading = true);
                  try {
                    await user?.updatePhotoURL(newUrl);
                    await user?.reload();
                    if (_currentUsername.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(_currentUsername)
                          .update({'photoURL': newUrl});
                    }
                    if (mounted) {
                      showFloatingToast(
                        context,
                        context.tr('toast_success') ?? 'Thành công',
                        context.tr('msg_avatar_updated') ?? 'Ảnh đại diện đã được cập nhật',
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                }
              },
              child: Text(context.tr('btn_save_image') ?? 'Lưu ảnh'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleGoogleLinkToggle() async {
    if (user == null) return;

    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          context.tr('err_require_trusted_device') ?? 'Chỉ thiết bị tin cậy mới có thể thay đổi liên kết tài khoản',
          isError: true,
        );
      }
      return;
    }

    if (_isGoogleLinked) {
      if (!_isPhoneLinked) {
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          context.tr('err_cannot_unlink_last') ?? 'Không thể hủy liên kết duy nhất (cần ít nhất 1 liên kết SĐT hoặc Google).',
          isError: true,
        );
        return;
      }

      bool hasPassword = user!.providerData.any((p) => p.providerId == 'password');
      if (!hasPassword) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_create_pass_before_unlink_google'),
          isError: true,
        );
        return;
      }

      bool? confirm = await _showConfirmDialog(
        context.tr('confirm_unlink_google') ?? 'Hủy liên kết Google',
        context.tr('confirm_unlink_google_desc') ?? 'Bạn có chắc chắn muốn hủy liên kết tài khoản Google này không?',
      );
      if (confirm != true) return;

      bool isReauthed = await ReauthHelper.reauthWithGoogleExplicit(
        context,
        reason: context.tr('confirm_unlink_google') ?? 'hủy liên kết Google',
      );
      if (!isReauthed) return;

      LoadingOverlay.show(context);
      try {
        await user!.unlink('google.com');
        await GoogleSignIn().signOut();

        if (_currentUsername.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({
            'email': FieldValue.delete(),
          });
        }

        await user!.reload();
        _checkLinkedProviders();
        await _fetchUserData();
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_success') ?? 'Thành công',
            context.tr('msg_google_unlinked') ?? 'Đã hủy liên kết Google',
          );
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
      }
    } else {
      LoadingOverlay.show(context);
      try {
        final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
        final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
        await googleSignIn.signOut();

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          LoadingOverlay.hide();
          return;
        }

        if (!googleUser.email.toLowerCase().endsWith('@gmail.com')) {
          await googleSignIn.signOut();
          LoadingOverlay.hide();
          if (mounted) {
            showFloatingToast(
              context,
              context.tr('error'),
              context.tr('err_only_gmail_supported'),
              isError: true,
            );
          }
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user!.linkWithCredential(credential);

        if (_currentUsername.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({
            'email': googleUser.email,
          });
        }

        await user!.reload();
        _checkLinkedProviders();
        await _fetchUserData();
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_success') ?? 'Thành công',
            context.tr('msg_google_linked') ?? 'Đã liên kết Google thành công',
          );
        }
      } on FirebaseAuthException catch (e) {
        LoadingOverlay.hide();
        String errorMsg = e.message ?? e.toString();
        if (e.code == 'credential-already-in-use') {
          errorMsg = context.tr('err_credential_in_use') ?? 'Tài khoản Google này đã được liên kết với một tài khoản khác.';
        }
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', errorMsg, isError: true);
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
      }
    }
  }

  Future<void> _handlePhoneLinkToggle() async {
    if (user == null) return;

    if (_isPhoneLinked) {
      // 1. Kiểm tra điều kiện: Cần duy trì ít nhất 1 phương thức liên kết (Google hoặc SĐT)
      if (!_isGoogleLinked) {
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          context.tr('err_cannot_unlink_last') ?? 'Không thể hủy liên kết duy nhất (Mỗi tài khoản phải liên kết ít nhất 1 trong Số điện thoại hoặc Google).',
          isError: true,
        );
        return;
      }

      // 2. Kiểm tra mật khẩu
      bool hasPassword = user!.providerData.any((p) => p.providerId == 'password');
      if (!hasPassword) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_create_pass_before_unlink_phone'),
          isError: true,
        );
        return;
      }

      // 3. Hộp thoại xác nhận
      bool? confirm = await _showConfirmDialog(
        context.tr('confirm_unlink_phone') ?? 'Hủy liên kết Số điện thoại',
        context.tr('confirm_unlink_phone_desc') ?? 'Bạn có chắc chắn muốn hủy liên kết số điện thoại này khỏi tài khoản không?',
      );
      if (confirm != true) return;

      // 4. Xác thực bảo mật lại
      bool isReauthed = await ReauthHelper.reauthenticate(
        context,
        reason: context.tr('confirm_unlink_phone') ?? 'hủy liên kết số điện thoại',
      );
      if (!isReauthed) return;

      LoadingOverlay.show(context);
      try {
        for (var p in user!.providerData) {
          if (p.providerId == 'phone') {
            await user!.unlink('phone');
            break;
          }
        }

        if (_currentUsername.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({
            'phoneNumber': FieldValue.delete(),
          });
        }

        await user!.reload();
        _checkLinkedProviders();
        await _fetchUserData();
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_success') ?? 'Thành công',
            context.tr('msg_phone_unlinked') ?? 'Đã hủy liên kết Số điện thoại thành công',
          );
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
      }
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateEmailPhoneScreen(isPhone: true)));
      await user?.reload();
      _checkLinkedProviders();
      _fetchUserData();
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('confirm_exit') ?? 'Thay đổi chưa lưu',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            context.tr('msg_unsaved_changes') ?? 'Bạn đang có thông tin thay đổi chưa được lưu lại. Bạn có chắc chắn muốn thoát không?',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(
                context.tr('btn_stay'),
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(
                context.tr('btn_leave'),
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(
                context.tr('btn_save') ?? 'Lưu & Thoát',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'discard') {
      return true;
    } else if (result == 'save') {
      await _saveProfileChanges();
      return true;
    }
    return false;
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.redAccent),
            ),
          ],
        ),
        content: Text(
          content,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.tr('btn_confirm') ?? 'Xác nhận', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          context.tr('err_trusted_device_only_delete') ?? 'Bạn chỉ có thể xoá tài khoản trên Thiết bị tin cậy',
          isError: true,
        );
      }
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    if (activeConfig.role == 'owner' &&
        activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown') {
      final isEspOnline = ref.read(espOnlineStateProvider);
      if (!isEspOnline) {
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error') ?? 'Lỗi',
            context.tr('err_hub_offline_delete') ?? 'Hub trung tâm đang ngoại tuyến. Vui lòng bật nguồn Hub để có thể dọn dẹp bộ nhớ thiết bị trước khi xóa tài khoản.',
            isError: true,
          );
        }
        return;
      }
    }

    if (!mounted) return;
    bool isPasswordVerified = await ReauthHelper.verifyPasswordOnly(
      context,
      reason: context.tr('reason_delete_account') ?? 'tiếp tục quá trình xóa tài khoản',
    );
    if (!isPasswordVerified) return;

    if (!mounted) return;
    bool isNativeVerified = await ReauthHelper.verifyNativeMethodOnly(context);
    if (!isNativeVerified) return;

    if (!mounted) return;
    bool? confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Text(
              context.tr('menu_delete_account') ?? 'Xóa tài khoản',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        content: Text(context.tr('msg_confirm_delete_account') ?? 'Bạn có chắc chắn muốn xóa tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('btn_yes') ?? 'Đồng ý'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    if (!mounted) return;
    String? currentUsername = _currentUsername;
    if (currentUsername.isEmpty) {
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
      if (query.docs.isNotEmpty) {
        currentUsername = query.docs.first.id;
      } else {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_user_not_found') ?? 'Không tìm thấy tài khoản', isError: true);
        return;
      }
    }

    final TextEditingController usernameConfirmController = TextEditingController();

    if (!mounted) return;
    bool? confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isMatched = usernameConfirmController.text.trim() == currentUsername;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('final_warning') ?? 'Cảnh báo cuối cùng',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('delete_account_warning') ?? 'Hành động này KHÔNG THỂ hoàn tác. Nhập Username của bạn để xác nhận:'),
                    const SizedBox(height: 12),
                    Text(currentUsername!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: usernameConfirmController,
                      onChanged: (val) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: '${context.tr('enter') ?? 'Nhập'} $currentUsername',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('btn_cancel') ?? 'Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMatched ? Colors.red : Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isMatched ? () => Navigator.pop(ctx, true) : null,
                  child: Text(context.tr('btn_still_delete') ?? 'Vẫn xóa', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm2 != true) return;

    if (!mounted) return;
    LoadingOverlay.show(context);
    try {
      if (currentUsername != null) {
        await FirebaseFirestore.instance.collection('delete_requests').doc(currentUsername).set({
          'uid': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await SessionManager.clearSession();
      await ref.read(homeConfigProvider).clearAllHomes();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_history');

      await LoadingOverlay.hideSuccess();

      try {
        await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
      }
    }
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData titleIcon,
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(titleIcon, color: isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isNotEmpty ? value : (context.tr('not_set') ?? 'Chưa thiết lập'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value.isNotEmpty
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _onWillPop();
        if (shouldLeave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF6F8FB),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              final shouldLeave = await _onWillPop();
              if (shouldLeave && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            context.tr('profile_title') ?? 'Hồ sơ của tôi',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _isLoading ? null : _saveProfileChanges,
                icon: const Icon(Icons.check, size: 18),
                label: Text(context.tr('btn_save') ?? 'Lưu'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF10B981),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0F766E),
        onRefresh: () async {
          await user?.reload();
          await _fetchUserData();
          _checkLinkedProviders();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          children: [
            const SizedBox(height: 10),
            // Header: Avatar with Edit Button, Name & Badges
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 105,
                        height: 105,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F766E), Color(0xFF4A65C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F766E).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          image: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                              ? DecorationImage(image: NetworkImage(user!.photoURL!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                            ? Center(
                                child: Text(
                                  (user?.displayName ?? 'U').isNotEmpty
                                      ? (user!.displayName ?? 'U').substring(0, 1).toUpperCase()
                                      : 'U',
                                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _updateAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        user?.displayName?.isNotEmpty == true ? user!.displayName! : 'ZenHome User',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentUsername.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.25)),
                          ),
                          child: Text(
                            '@$_currentUsername',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: (activeConfig.role == 'owner' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (activeConfig.role == 'owner' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981)).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          activeConfig.role == 'owner' ? (context.tr('owner_role') ?? 'Chủ nhà') : (context.tr('member_role') ?? 'Thành viên'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: activeConfig.role == 'owner' ? const Color(0xFF8B5CF6) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // Card 1: Thông tin cá nhân & Liên kết
            _buildSectionCard(
              context: context,
              title: context.tr('menu_account_info') ?? 'Thông tin cá nhân & Liên kết',
              titleIcon: Icons.badge_outlined,
              isDark: isDark,
              children: [
                // Họ và tên
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: TextField(
                    controller: _nameController,
                    onChanged: (_) => _checkForChanges(),
                    decoration: InputDecoration(
                      labelText: context.tr('full_name') ?? 'Họ và tên',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Ngày sinh
                InkWell(
                  onTap: _selectBirthday,
                  borderRadius: BorderRadius.circular(14),
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: TextField(
                        controller: _birthdayController,
                        decoration: InputDecoration(
                          labelText: context.tr('birthday') ?? 'Ngày sinh',
                          hintText: 'DD/MM/YYYY',
                          prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                ),

                const Divider(height: 24),

                // Email (Google)
                _buildInfoRow(
                  label: 'Email (Google)',
                  value: _currentEmail.isNotEmpty ? _currentEmail : (context.tr('unlinked') ?? 'Chưa liên kết'),
                  icon: Icons.alternate_email_rounded,
                  isDark: isDark,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_isGoogleLinked ? Colors.green : Colors.grey).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isGoogleLinked ? (context.tr('linked') ?? 'Đã liên kết') : (context.tr('unlinked') ?? 'Chưa có'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isGoogleLinked ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: _isGoogleLinked ? Colors.redAccent.withOpacity(0.12) : const Color(0xFF0F766E).withOpacity(0.12),
                          foregroundColor: _isGoogleLinked ? Colors.redAccent : const Color(0xFF0F766E),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _handleGoogleLinkToggle,
                        child: Text(
                          _isGoogleLinked ? (context.tr('unlink') ?? 'Hủy') : (context.tr('link') ?? 'Liên kết'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // Số điện thoại
                _buildInfoRow(
                  label: context.tr('phone_number') ?? 'Số điện thoại',
                  value: _currentPhone.isNotEmpty ? _currentPhone : (context.tr('unlinked') ?? 'Chưa có'),
                  icon: Icons.phone_android_outlined,
                  isDark: isDark,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (_isPhoneLinked ? Colors.green : Colors.grey).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isPhoneLinked ? (context.tr('linked') ?? 'Đã liên kết') : (context.tr('unlinked') ?? 'Chưa có'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isPhoneLinked ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (_isPhoneLinked) ...[
                        IconButton(
                          tooltip: context.tr('tooltip_change_phone'),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => const UpdateEmailPhoneScreen(isPhone: true)));
                            await user?.reload();
                            _checkLinkedProviders();
                            _fetchUserData();
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          backgroundColor: _isPhoneLinked ? Colors.redAccent.withOpacity(0.12) : const Color(0xFF0F766E).withOpacity(0.12),
                          foregroundColor: _isPhoneLinked ? Colors.redAccent : const Color(0xFF0F766E),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _handlePhoneLinkToggle,
                        child: Text(
                          _isPhoneLinked ? (context.tr('unlink') ?? 'Hủy') : (context.tr('link') ?? 'Liên kết'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_hasChanges) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _saveProfileChanges,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(context.tr('btn_save') ?? 'Lưu thay đổi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ],
            ),

            // Card 2: Bảo mật & Thiết bị
            _buildSectionCard(
              context: context,
              title: context.tr('security_and_devices') ?? 'Bảo mật & Thiết bị',
              titleIcon: Icons.security_outlined,
              isDark: isDark,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_reset_rounded, color: isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E), size: 20),
                  ),
                  title: Text(context.tr('menu_change_password') ?? 'Đổi mật khẩu', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () async {
                    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
                    if (!isTrusted) {
                      if (mounted) {
                        showFloatingToast(
                          context,
                          context.tr('error') ?? 'Lỗi',
                          context.tr('err_trusted_device_only_delete') ?? 'Chỉ thiết bị tin cậy mới có thể thực hiện thao tác này',
                          isError: true,
                        );
                      }
                      return;
                    }
                    if (mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.devices_rounded, color: isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E), size: 20),
                  ),
                  title: Text(context.tr('menu_logged_devices') ?? 'Quản lý thiết bị đăng nhập', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoggedDevicesScreen())),
                ),
              ],
            ),

            // Card 3: Vùng nguy hiểm (Xóa tài khoản)
            _buildSectionCard(
              context: context,
              title: context.tr('danger_zone') ?? 'Vùng nguy hiểm',
              titleIcon: Icons.warning_amber_rounded,
              isDark: isDark,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                  ),
                  title: Text(
                    context.tr('menu_delete_account') ?? 'Xóa tài khoản vĩnh viễn',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.redAccent),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.redAccent),
                  onTap: _deleteAccount,
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  ),
);
}
}

