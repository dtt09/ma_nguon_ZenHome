import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/features/auth/ui/update_email_phone_screen.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AccountInfoScreen extends ConsumerStatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  ConsumerState<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends ConsumerState<AccountInfoScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool _isLoading = false;
  String _currentUsername = '';
  
  bool _isGoogleLinked = false;
  bool _isPhoneLinked = false;

  String _initialName = '';
  String _initialBirthday = '';

  bool _hasUnsavedChanges() {
    return _nameController.text.trim() != _initialName.trim() ||
           _birthdayController.text.trim() != _initialBirthday.trim();
  }

  @override
  void initState() {
    super.initState();
    _initialName = user?.displayName ?? '';
    _nameController.text = _initialName;
    _emailController.text = getDisplayEmail(user);
    _fetchUserData();
    _checkLinkedProviders();
  }

  void _checkLinkedProviders() {
    if (user != null) {
      _isGoogleLinked = false;
      _isPhoneLinked = false;
      for (var provider in user!.providerData) {
        if (provider.providerId == 'google.com') _isGoogleLinked = true;
        if (provider.providerId == 'phone') _isPhoneLinked = true;
      }
      setState(() {});
    }
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;
    try {
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user!.uid).get();
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        _currentUsername = doc.id;
        final data = doc.data();
        
        // Kiểm tra xem người dùng có thực sự có provider email không
        bool hasEmailProvider = user!.providerData.any((p) => p.providerId == 'password' || p.providerId == 'google.com');
        
        if (hasEmailProvider && user!.email != null && user!.email!.isNotEmpty && data['email'] != user!.email) {
          // Đồng bộ email nếu user vừa nhấn link xác nhận từ verifyBeforeUpdateEmail
          await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({'email': user!.email});
          data['email'] = user!.email;
        }
        
        setState(() {
          _usernameController.text = _currentUsername;
          _emailController.text = hasEmailProvider ? getDisplayEmail(user) : '';
          _phoneController.text = data['phoneNumber'] ?? '';
          if (_phoneController.text.isEmpty && user != null && user!.email != null && user!.email!.endsWith('@zenhome.local')) {
            _phoneController.text = '+${user!.email!.replaceAll('@zenhome.local', '')}';
          }
          _birthdayController.text = data['birthday'] ?? '';
          _initialBirthday = _birthdayController.text;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _navigateWithTrustCheck(bool isPhone) async {
    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_require_trusted_device') ?? 'Chỉ thiết bị tin cậy mới có thể thay đổi liên kết tài khoản', isError: true);
      return;
    }
    
    // Nếu đang thay đổi SĐT đã liên kết, hiện bảng cảnh báo
    if (isPhone && _isPhoneLinked) {
      bool? confirm = await _showConfirmDialog(
        context.tr('confirm_change_phone') ?? 'Thay đổi Số điện thoại',
        context.tr('confirm_change_phone_desc') ?? 'Việc thay đổi số điện thoại sẽ đổi luôn tên đăng nhập của bạn. Bạn có chắc chắn muốn tiếp tục?',
      );
      if (confirm != true) return;
    }

    if (mounted) {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => UpdateEmailPhoneScreen(isPhone: isPhone)));
      await user?.reload();
      _checkLinkedProviders();
      _fetchUserData();
    }
  }

  Future<void> _handleGoogleLinkToggle() async {
    if (user == null) return;
    
    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_require_trusted_device') ?? 'Chỉ thiết bị tin cậy mới có thể thay đổi liên kết tài khoản', isError: true);
      return;
    }

    if (_isGoogleLinked) {
      if (!_isPhoneLinked) {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_cannot_unlink_last') ?? 'Không thể hủy liên kết duy nhất (cần ít nhất 1 liên kết SĐT hoặc Google).', isError: true);
        return;
      }
      
      bool hasPassword = user!.providerData.any((p) => p.providerId == 'password');
      if (!hasPassword) {
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', 'Bạn cần tạo mật khẩu (Vào mục Đổi mật khẩu) trước khi hủy liên kết Google để có thể đăng nhập.', isError: true);
        return;
      }
      
      bool? confirm = await _showConfirmDialog(
        context.tr('confirm_unlink_google') ?? 'Hủy liên kết Google',
        context.tr('confirm_unlink_google_desc') ?? 'Bạn có chắc chắn muốn hủy liên kết tài khoản Google này không? (Bạn vẫn có thể liên kết lại sau)',
      );
      if (confirm != true) return;
      
      LoadingOverlay.show(context);
      try {
        await user!.unlink('google.com');
        await GoogleSignIn().signOut();
        
        String fallbackEmail = '';
        if (user!.phoneNumber != null && user!.phoneNumber!.isNotEmpty) {
           fallbackEmail = '${user!.phoneNumber!.replaceAll('+', '')}@zenhome.local';
        } else {
           final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUsername).get();
           final phone = doc.data()?['phoneNumber'] ?? '';
           fallbackEmail = '${phone.toString().replaceAll('+', '')}@zenhome.local';
        }
        
        if (fallbackEmail.length > 15) { // Valid dummy email check
          await FirebaseFirestore.instance.collection('unlink_requests').doc(user!.uid).set({
            'uid': user!.uid,
            'type': 'google.com',
            'fallbackEmail': fallbackEmail
          });
          
          // Xóa email khỏi Firestore để app ko tự động lấy lại email cũ
          await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({
            'email': FieldValue.delete()
          });
        }
        
        await user!.reload();
        
        // Removed aggressive email clearing logic here so Phone login can still look up the email.

        _checkLinkedProviders();
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_google_unlinked') ?? 'Đã hủy liên kết tài khoản Google', isError: false);
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
      }
    } else {
      LoadingOverlay.show(context);
      try {
        final String? clientId = dotenv.env['GOOGLE_CLIENT_ID'];
        final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: clientId);
        await googleSignIn.signOut(); // Ép buộc hiển thị bảng chọn
        
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          LoadingOverlay.hide();
          return;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user!.linkWithCredential(credential);
        
        try {
          if (googleUser.email.isNotEmpty && user!.email != googleUser.email) {
            // Update primary email in Firebase Auth (requires user to click link in email)
            await user!.verifyBeforeUpdateEmail(googleUser.email);
            // We DO NOT update Firestore here. We wait for the user to verify.
            // The next time they open this screen, _fetchUserData will detect the change and sync it.
          }
        } catch (e) {
          debugPrint("Không thể cập nhật email chính: $e");
        }
        
        await user!.reload();
        _checkLinkedProviders();
        LoadingOverlay.hide();
        if (mounted) showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_google_linked') ?? 'Đã liên kết tài khoản Google thành công', isError: false);
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

  Future<void> _handlePhoneUnlink() async {
    if (user == null) return;
    
    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_require_trusted_device') ?? 'Chỉ thiết bị tin cậy mới có thể thay đổi liên kết tài khoản', isError: true);
      return;
    }

    if (!_isGoogleLinked) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_cannot_unlink_last') ?? 'Không thể hủy liên kết duy nhất (cần ít nhất 1 liên kết SĐT hoặc Google).', isError: true);
      return;
    }

    bool? confirm = await _showConfirmDialog(
      context.tr('confirm_unlink_phone') ?? 'Hủy liên kết Số điện thoại',
      context.tr('confirm_unlink_phone_desc') ?? 'Bạn có chắc chắn muốn hủy liên kết số điện thoại này không? Bạn sẽ không thể đăng nhập bằng SĐT này nữa.',
    );
    if (confirm != true) return;

    LoadingOverlay.show(context);
    try {
      await user!.unlink('phone');
      
      if (_currentUsername.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({
          'phoneNumber': ''
        });
      }
      
      await user!.reload();
      _checkLinkedProviders();
      setState(() {
         _phoneController.text = '';
      });
      LoadingOverlay.hide();
      if (mounted) showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_phone_unlinked') ?? 'Đã hủy liên kết Số điện thoại', isError: false);
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.toString(), isError: true);
    }
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 45),
            ),
            const SizedBox(height: 15),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.redAccent)),
          ],
        ),
        content: Text(
          content,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.5, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20, top: 10),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.3))),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.tr('confirm') ?? 'Xác nhận', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _updateAvatar() {
    String newUrl = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('update_avatar') ?? 'Cập nhật ảnh đại diện', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          onChanged: (val) => newUrl = val,
          decoration: InputDecoration(
            hintText: context.tr('enter_image_url') ?? 'Nhập link ảnh (URL)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              if (newUrl.isNotEmpty) {
                setState(() => _isLoading = true);
                try {
                  await user?.updatePhotoURL(newUrl);
                  await user?.reload();
                  showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_avatar_updated') ?? 'Ảnh đại diện đã được cập nhật');
                } catch (e) {
                  showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('error') ?? 'Lỗi', isError: true);
                } finally {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: Text(context.tr('btn_save_image') ?? 'Lưu ảnh'),
          ),
        ],
      ),
    );
  }

  void _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      if (_nameController.text.trim() != user?.displayName) {
        await user?.updateDisplayName(_nameController.text.trim());
      }
      if (_currentUsername.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(_currentUsername).update({
          'birthday': _birthdayController.text.trim(),
        });
      }
      
      _initialName = _nameController.text.trim();
      _initialBirthday = _birthdayController.text.trim();

      showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_profile_updated') ?? 'Hồ sơ đã được cập nhật');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('error') ?? 'Lỗi', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProviderTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isLinked,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121827) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isLinked ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(icon, size: 40, color: iconColor),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Text(subtitle, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLinked ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLinked ? (context.tr('btn_unlink') ?? 'Hủy liên kết') : (context.tr('btn_link') ?? 'Liên kết'),
                    style: TextStyle(
                      color: isLinked ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneProviderTile(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121827) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _isPhoneLinked ? Colors.green.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            const Icon(Icons.phone, size: 40, color: Colors.blue),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('phone_number') ?? 'Số điện thoại', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(_isPhoneLinked ? (_phoneController.text.isNotEmpty ? _phoneController.text : (user?.phoneNumber ?? (context.tr('status_linked') ?? 'Đã liên kết'))) : (context.tr('status_unlinked') ?? 'Chưa liên kết'), style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            if (_isPhoneLinked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _navigateWithTrustCheck(true), // Thay đổi SĐT
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(context.tr('btn_change') ?? 'Đổi', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _handlePhoneUnlink,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(context.tr('btn_unlink') ?? 'Hủy liên kết', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              )
            else
              InkWell(
                onTap: () => _navigateWithTrustCheck(true), // Liên kết mới
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(context.tr('btn_link') ?? 'Liên kết', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('confirm_exit') ?? 'Xác nhận thoát'),
            content: Text(context.tr('msg_unsaved_changes') ?? 'Bạn có thay đổi chưa lưu. Bạn có chắc chắn muốn thoát?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('cancel') ?? 'Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('confirm') ?? 'Thoát'),
              ),
            ],
          ),
        );
        if (confirm == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(context.tr('menu_account_info') ?? 'Thông tin tài khoản', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _updateAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3A7C),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                        image: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                            ? DecorationImage(image: NetworkImage(user!.photoURL!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                          ? Center(
                              child: Text(
                                (user?.displayName ?? 'U').isNotEmpty ? (user!.displayName ?? 'U').substring(0, 1).toUpperCase() : 'U',
                                style: const TextStyle(fontSize: 45, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            Text(context.tr('basic_info') ?? 'Thông tin cơ bản', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            
            // Username (Khóa)
            TextField(
              enabled: false,
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.account_circle),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 15),
            
            // Display Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.tr('display_name') ?? 'Tên hiển thị',
                prefixIcon: const Icon(Icons.badge),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 15),

            // Birthday
            TextField(
              controller: _birthdayController,
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _birthdayController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                  });
                }
              },
              decoration: InputDecoration(
                labelText: context.tr('birthday') ?? 'Ngày sinh',
                prefixIcon: const Icon(Icons.cake),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 25),

            Text(context.tr('title_linked_accounts') ?? 'Tài khoản liên kết', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            
            _buildProviderTile(
              icon: Icons.g_mobiledata,
              iconColor: Colors.red,
              title: 'Google',
              subtitle: _isGoogleLinked ? (context.tr('status_linked_safe') ?? 'Đã liên kết an toàn') : (context.tr('status_unlinked') ?? 'Chưa liên kết'),
              isLinked: _isGoogleLinked,
              isDark: isDark,
              onTap: _handleGoogleLinkToggle,
            ),
            
            _buildPhoneProviderTile(isDark),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A3A7C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading 
                     ? LogoLoadingIndicator(color: Colors.white, size: 24) 
                     : Text(context.tr('btn_save_changes') ?? 'Lưu thay đổi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    ),
    );
  }
}
