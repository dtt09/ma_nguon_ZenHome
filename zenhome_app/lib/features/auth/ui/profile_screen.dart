import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/features/auth/ui/account_info_screen.dart';
import 'package:zenhome_app/features/auth/ui/change_password_screen.dart';
import 'package:zenhome_app/features/auth/ui/logged_devices_screen.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  
  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Lớp 1: Thiết bị tin cậy
    bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
    if (!isTrusted) {
      if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_trusted_device_only_delete') ?? 'Bạn chỉ có thể xoá tài khoản trên Thiết bị tin cậy', isError: true);
      return;
    }

    // Lớp 1.5: Kiểm tra trạng thái Hub online (Chỉ dành cho Owner)
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    if (activeConfig.role == 'owner' && 
        activeConfig.macAddress.isNotEmpty && 
        activeConfig.macAddress != 'unknown_mac' && 
        activeConfig.macAddress != 'unknown') {
      final isEspOnline = ref.read(espOnlineStateProvider);
      if (!isEspOnline) {
        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_hub_offline_delete') ?? 'Hub trung tâm đang ngoại tuyến. Vui lòng bật nguồn Hub để có thể dọn dẹp bộ nhớ thiết bị trước khi xóa tài khoản.', isError: true);
        return;
      }
    }

    // Lớp 2: Mật khẩu
    if (!mounted) return;
    bool isPasswordVerified = await ReauthHelper.verifyPasswordOnly(context, reason: context.tr('reason_delete_account') ?? 'tiếp tục quá trình xóa tài khoản');
    if (!isPasswordVerified) return;
    
    // Lớp 3: Phương thức gốc (OTP / Google)
    if (!mounted) return;
    bool isNativeVerified = await ReauthHelper.verifyNativeMethodOnly(context);
    if (!isNativeVerified) return;

    // Lớp 4: Mật khẩu kỹ thuật (Chỉ dành cho Owner nếu có thiết bị)
    if (activeConfig.role == 'owner' && activeConfig.macAddress != 'unknown_mac' && activeConfig.macAddress.isNotEmpty && activeConfig.adminPass.isNotEmpty) {
      if (!mounted) return;
      bool? isTechPassVerified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final TextEditingController passController = TextEditingController();
          bool isError = false;
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Color(0xFF2A3A7C)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('confirm_admin_pass') ?? 'Xác nhận mật khẩu kỹ thuật',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr('admin_login_desc') ?? 'Vui lòng nhập mật khẩu kỹ thuật để tiếp tục.'),
                    const SizedBox(height: 15),
                    TextField(
                      controller: passController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.tr('password') ?? 'Mật khẩu',
                        errorText: isError ? (context.tr('admin_pass_incorrect') ?? 'Mật khẩu không đúng') : null,
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A3A7C),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (passController.text == activeConfig.adminPass) {
                        Navigator.pop(ctx, true);
                      } else {
                        setState(() { isError = true; });
                      }
                    },
                    child: Text(context.tr('btn_confirm') ?? 'Xác nhận'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (isTechPassVerified != true) return;
    }

    // Xác nhận lần 1
    if (!mounted) return;
    bool? confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Text(context.tr('menu_delete_account') ?? 'Xóa tài khoản', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
          ],
        ),
        content: Text(context.tr('msg_confirm_delete_account') ?? 'Bạn có chắc chắn muốn xóa tài khoản?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('btn_yes') ?? 'Đồng ý'),
          ),
        ],
      ),
    );

    if (confirm1 != true) return;

    // Xác nhận lần 2
    if (!mounted) return;
    String? currentUsername;
    final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      currentUsername = query.docs.first.id;
    } else {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_user_not_found') ?? 'Không tìm thấy tài khoản', isError: true);
      return;
    }

    final TextEditingController _usernameConfirmController = TextEditingController();

    if (!mounted) return;
    bool? confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isMatched = _usernameConfirmController.text.trim() == currentUsername;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 10),
                  Text(context.tr('final_warning') ?? 'Cảnh báo cuối cùng', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('delete_account_warning') ?? 'Đây là hành động KHÔNG THỂ hoàn tác. Toàn bộ dữ liệu nhà thông minh sẽ bị xóa vĩnh viễn.\n\nVui lòng nhập Username của bạn để xác nhận:'),
                  const SizedBox(height: 15),
                  Text(currentUsername!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _usernameConfirmController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '${context.tr('enter') ?? 'Nhập'} $currentUsername',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.tr('btn_cancel') ?? 'Hủy'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: isMatched ? Colors.red : Colors.grey, foregroundColor: Colors.white),
                  onPressed: isMatched ? () => Navigator.pop(ctx, true) : null,
                  child: Text(context.tr('btn_still_delete') ?? 'Vẫn xóa', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );

    if (confirm2 != true) return;

    if (!mounted) return;
    LoadingOverlay.show(context);
    try {
      // Gửi lệnh xóa cho server (Backend NodeJS sẽ nhận lệnh và xử lý xóa Auth & Firestore)
      if (currentUsername != null) {
        await FirebaseFirestore.instance.collection('delete_requests').doc(currentUsername).set({
          'uid': user.uid,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Xóa cấu hình nội bộ (Clear local session state)
      await SessionManager.clearSession();
      await ref.read(homeConfigProvider).clearAllHomes();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notification_history');

      await LoadingOverlay.hideSuccess();

      // Đăng xuất khỏi thiết bị (timeout để không bị hang nếu gọi đồng thời với listener)
      try {
        await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 2));
      } catch (_) {}
      
      // Không cần Navigator.pushAndRemoveUntil ở đây vì MainLayout auth listener đã xử lý khi user == null
    } on FirebaseAuthException catch (e) {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? (context.tr('err_delete_account') ?? 'Lỗi xóa tài khoản'), isError: true);
    } catch (e) {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_generic') ?? 'Đã xảy ra lỗi', isError: true);
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF2A3A7C)).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C))),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(context.tr('profile_title') ?? 'Hồ sơ của tôi', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Header: Avatar and Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100, height: 100,
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
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(user?.displayName ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(getDisplayEmailOrPhone(user), style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Menu Items
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121827) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.person_outline,
                    title: context.tr('menu_account_info') ?? 'Thông tin tài khoản',
                    isDark: isDark,
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountInfoScreen()));
                      if (mounted) setState(() {});
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 70, endIndent: 20),
                  
                  _buildMenuItem(
                    icon: Icons.lock_outline,
                    title: context.tr('menu_change_password') ?? 'Đổi mật khẩu',
                    isDark: isDark,
                    onTap: () async {
                      bool isTrusted = await SessionManager.isCurrentDeviceTrusted();
                      if (!isTrusted) {
                        if (mounted) showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_trusted_device_only_delete') ?? 'Chỉ thiết bị tin cậy mới có thể thực hiện thao tác này', isError: true);
                        return;
                      }
                      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
                    },
                  ),
                  Divider(height: 1, color: Colors.grey.withOpacity(0.2), indent: 70, endIndent: 20),
                  
                  _buildMenuItem(
                    icon: Icons.devices,
                    title: context.tr('menu_logged_devices') ?? 'Thiết bị đăng nhập',
                    isDark: isDark,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoggedDevicesScreen())),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 25),
            
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121827) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: _buildMenuItem(
                icon: Icons.delete_outline,
                title: context.tr('menu_delete_account') ?? 'Xóa tài khoản',
                iconColor: Colors.red,
                textColor: Colors.red,
                isDark: isDark,
                onTap: _deleteAccount,
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}