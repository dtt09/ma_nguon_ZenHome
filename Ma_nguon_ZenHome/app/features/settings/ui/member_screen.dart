import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';

class MemberScreen extends ConsumerStatefulWidget {
  const MemberScreen({super.key});

  @override
  ConsumerState<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends ConsumerState<MemberScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _usernameController = TextEditingController();
  bool _isLoading = false;
  String? currentUsername;

  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
  }

  Future<void> _loadCurrentUsername() async {
    if (currentUser != null) {
      final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: currentUser!.uid).get();
      if (query.docs.isNotEmpty && mounted) {
        setState(() {
          currentUsername = query.docs.first.id;
        });
      }
    }
  }

  Stream<DocumentSnapshot>? _getMyDataStream() {
    if (currentUsername == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(currentUsername).snapshots();
  }

  void _sendInvite() async {
    String targetUsername = _usernameController.text.trim();
    if (targetUsername.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_invalid_username') ?? 'Vui lòng nhập Username hợp lệ', isError: true);
      return;
    }
    if (targetUsername == currentUsername) {
      showFloatingToast(context, context.tr('error'), context.tr('err_self_invite'), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final targetDoc = await FirebaseFirestore.instance.collection('users').doc(targetUsername).get();
      if (!targetDoc.exists) {
        showFloatingToast(context, context.tr('error'), context.tr('err_user_not_found'), isError: true);
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(targetUsername).set({
        'pendingInvitations': FieldValue.arrayUnion([currentUsername])
      }, SetOptions(merge: true));
      
      // Bắn Alert để Server gọi Push FCM
      String inviterName = FirebaseAuth.instance.currentUser?.displayName ?? currentUsername ?? (context.tr('someone') ?? 'Ai đó');
      await FirebaseFirestore.instance.collection('users').doc(targetUsername).collection('alerts').add({
        'type': 'new_invite',
        'inviter': inviterName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _usernameController.clear();
      showFloatingToast(context, context.tr('toast_success'), '${context.tr('msg_send_success')} $targetUsername');
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _acceptInvite(String ownerUsername) async {
    showFloatingToast(context, context.tr('msg_processing'), '${context.tr('msg_syncing_home')} $ownerUsername...');
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    // --- 1. HỦY ĐĂNG KÝ KÊNH NHÀ CŨ TRƯỚC KHI ĐỔI ---
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}');
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}_vi');
      await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}_en');
    } catch (e) {
      debugPrint('Error getting email: $e');
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(ownerUsername).set({
        'sharedWith': FieldValue.arrayUnion([currentUsername])
      }, SetOptions(merge: true));
      
      // Cập nhật ownerUsername cho chính mình và xoá khỏi danh sách chờ
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'ownerUsername': ownerUsername,
        'pendingInvitations': FieldValue.arrayRemove([ownerUsername])
      });

      final targetDoc = await FirebaseFirestore.instance.collection('users').doc(ownerUsername).get();
      if (targetDoc.exists) {
        final data = targetDoc.data() as Map<String, dynamic>;
        List<DeviceConfig> restoredDevices = [];
        if (data.containsKey('devices') && data['devices'] != null) {
          restoredDevices = (data['devices'] as List)
              .map((e) => DeviceConfig.fromJson(e))
              .toList();
        }
        
        String ownerName = data['displayName'] ?? ownerUsername;
        String assignedRole = 'member';
        if (data['memberRoles'] != null && data['memberRoles'][currentUsername] != null) {
          assignedRole = data['memberRoles'][currentUsername];
        }
        
        SmartConfig newConfig = SmartConfig(
          userId: ownerUsername,
          macAddress: data['macAddress'] ?? 'unknown_mac',
          mqttServer: data['mqttServer'] ?? 'broker.emqx.io',
          mqttUser: data['mqttUser'],
          mqttPass: data['mqttPass'],
          devices: restoredDevices,
          role: assignedRole,
          homeName: '${context.tr('home_of')} $ownerName',
          ownerEmail: ownerUsername,
        );

        // Cập nhật nhà mới
        await ref.read(homeConfigProvider).saveConfigToStorage(newConfig);
        await ref.read(homeConfigProvider).switchActiveHome(ownerUsername);
      }

      // --- 2. ĐĂNG KÝ VÀO KÊNH NHÀ MỚI ---
      try {
        final prefs = await SharedPreferences.getInstance();
        String lang = prefs.getString('app_lang') ?? 'en';
        await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}');
        await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}_vi');
        await FirebaseMessaging.instance.unsubscribeFromTopic('home_${activeConfig.userId}_en');
        await FirebaseMessaging.instance.subscribeToTopic('home_${activeConfig.userId}_$lang');
      } catch (e) {
        debugPrint('Error validating target email: $e');
      }

      if (mounted) {
        showFloatingToast(context, context.tr('toast_success'), context.tr('msg_sync_success'));
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    }
  }
  void _rejectInvite(String ownerUsername) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'pendingInvitations': FieldValue.arrayRemove([ownerUsername])
      });
      showFloatingToast(context, context.tr('toast_success'), '${context.tr('msg_reject_success')} $ownerUsername');
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    }
  }

  void _removeMember(String memberUsername) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'sharedWith': FieldValue.arrayRemove([memberUsername]),
        'automationEditors': FieldValue.arrayRemove([memberUsername]),
        'disabledMembers': FieldValue.arrayRemove([memberUsername]),
        'memberRoles.$memberUsername': FieldValue.delete(),
      });
      await FirebaseFirestore.instance.collection('users').doc(memberUsername).update({
        'ownerUsername': FieldValue.delete(),
        'ownerEmail': FieldValue.delete() // Xóa cả 2 đề phòng
      });
      showFloatingToast(context, context.tr('msg_deleted_title'), '${context.tr('msg_revoke_success')} $memberUsername');
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    }
  }

  void _toggleDisableMember(String memberUsername, bool isDisabled) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'disabledMembers': isDisabled 
            ? FieldValue.arrayUnion([memberUsername])
            : FieldValue.arrayRemove([memberUsername])
      });
      showFloatingToast(context, context.tr('toast_success'), isDisabled ? context.l10n.msg_disabled_member(memberUsername) : context.l10n.msg_enabled_member(memberUsername));
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    }
  }

  void _toggleAutomationEditor(String memberUsername, bool canEdit) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).update({
        'automationEditors': canEdit 
            ? FieldValue.arrayUnion([memberUsername])
            : FieldValue.arrayRemove([memberUsername])
      });
      showFloatingToast(context, context.tr('toast_success'), canEdit ? '${context.tr('msg_grant_edit') ?? 'Đã cấp quyền sửa tự động hóa cho'} $memberUsername' : '${context.tr('msg_revoke_edit') ?? 'Đã thu hồi quyền sửa tự động hóa của'} $memberUsername');
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    }
  }

  void _changeRole(String memberUsername, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUsername).set({
        'memberRoles': {
          memberUsername: newRole
        }
      }, SetOptions(merge: true));
      showFloatingToast(context, context.tr('toast_success'), context.l10n.msg_role_granted(newRole == 'co_owner' ? context.tr('co_owner') : context.tr('member_role'), memberUsername));
    } catch (e) {
      showFloatingToast(context, context.tr('error'), context.tr('error'), isError: true);
    }
  }

  void _confirmRemoveMember(String memberUsername) {
    showPremiumConfirmDialog(
      context: context,
      title: context.tr('confirm_title'),
      message: context.tr('msg_confirm_revoke').replaceAll('{email}', memberUsername),
      confirmText: context.tr('btn_revoke'),
      cancelText: context.tr('btn_cancel'),
      isDanger: true,
      icon: Icons.person_remove_rounded,
      onConfirm: () {
        _removeMember(memberUsername); 
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(context.tr('family_members'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: currentUsername == null
          ? const Center(child: LogoLoadingIndicator(color: Colors.blue, size: 24))
          : StreamBuilder<DocumentSnapshot>(
              stream: _getMyDataStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LogoLoadingIndicator(color: Colors.blue, size: 24));
                }

          final data = (snapshot.data?.exists ?? false) ? snapshot.data!.data() as Map<String, dynamic> : {};
          final List<dynamic> pendingInvites = data.containsKey('pendingInvitations') ? data['pendingInvitations'] : [];
          final List<dynamic> sharedMembers = data.containsKey('sharedWith') ? data['sharedWith'] : [];
          final List<dynamic> disabledMembers = data.containsKey('disabledMembers') ? data['disabledMembers'] : [];

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pendingInvites.isNotEmpty) ...[
                  Text(context.tr('new_invite'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pendingInvites.length,
                    itemBuilder: (context, index) {
                      String inviterUsername = pendingInvites[index];
                      return Card(
                        color: Colors.orange.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade300)),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.mail, color: Colors.white)),
                          title: Text(inviterUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(context.tr('invite_desc')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                onPressed: () => _acceptInvite(inviterUsername),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                onPressed: () => _rejectInvite(inviterUsername),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 25),
                ],

                Text(context.tr('add_new_member'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: context.tr('username_member'),
                          prefixIcon: const Icon(Icons.person_add),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey.shade400),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 55, width: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: EdgeInsets.zero),
                        onPressed: _isLoading ? null : _sendInvite,
                        child: _isLoading ? LogoLoadingIndicator(color: Colors.white, size: 24) : const Icon(Icons.send),
                      ),
                    )
                  ],
                ),
                
                const SizedBox(height: 30),
                
                Text(context.tr('linked_list'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Expanded(
                  child: sharedMembers.isEmpty 
                    ? Center(child: Text(context.tr('empty_member'), style: TextStyle(color: Colors.grey.shade500)))
                    : ListView.builder(
                        itemCount: sharedMembers.length,
                        itemBuilder: (context, index) {
                          String email = sharedMembers[index];
                          bool isDisabled = disabledMembers.contains(email);
                          String currentRole = (data.containsKey('memberRoles') && data['memberRoles'][email] != null) ? data['memberRoles'][email] : 'member';
                          
                          return Card(
                            color: isDark ? const Color(0xFF121827) : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isDisabled ? Colors.grey.shade300 : (currentRole == 'co_owner' ? Colors.blue.shade100 : Colors.green.shade100), 
                                    child: Icon(isDisabled ? Icons.lock : (currentRole == 'co_owner' ? Icons.manage_accounts : Icons.person), color: isDisabled ? Colors.grey : (currentRole == 'co_owner' ? Colors.blue : Colors.green))
                                  ),
                                  title: Text(email, style: TextStyle(fontWeight: FontWeight.bold, decoration: isDisabled ? TextDecoration.lineThrough : null, color: isDisabled ? Colors.grey : null)),
                                  subtitle: Text(currentRole == 'co_owner' ? context.tr('co_owner') : context.tr('member_role'), style: TextStyle(color: isDisabled ? Colors.grey : (currentRole == 'co_owner' ? Colors.blue : Colors.green))),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.shield, color: Colors.orange),
                                        tooltip: context.tr('tooltip_permission') ?? 'Phân quyền',
                                        onSelected: (val) => _changeRole(email, val),
                                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                          PopupMenuItem<String>(
                                            value: 'member',
                                            child: Text(context.tr('member_role')),
                                          ),
                                          PopupMenuItem<String>(
                                            value: 'co_owner',
                                            child: Text(context.tr('co_owner')),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.power_settings_new, color: Colors.grey, size: 20),
                                          const SizedBox(width: 5),
                                          Switch(
                                            value: !isDisabled,
                                            activeColor: Colors.green,
                                            onChanged: (val) {
                                              _toggleDisableMember(email, !val);
                                            },
                                          ),
                                        ],
                                      ),
                                      if (currentRole == 'member') Row(
                                        children: [
                                          const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                                          const SizedBox(width: 5),
                                          Switch(
                                            value: (data['automationEditors'] as List<dynamic>?)?.contains(email) ?? false,
                                            activeColor: Colors.purple,
                                            onChanged: (val) {
                                              _toggleAutomationEditor(email, val);
                                            },
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red), 
                                        tooltip: context.tr('btn_kick') ?? 'Trực xuất',
                                        onPressed: () => _confirmRemoveMember(email) 
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
} 