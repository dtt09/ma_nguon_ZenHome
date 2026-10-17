import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
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

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final bool isEspLinked = activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown';

    // RÀNG BUỘC: Tài khoản phải liên kết với ESP32 mới được phép mời thành viên
    if (!isEspLinked) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('err_esp_required_for_invite'),
        isError: true,
      );
      return;
    }

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
        'ownerEmail': FieldValue.delete()
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
      showFloatingToast(context, context.tr('toast_success'), canEdit ? '${context.tr('msg_grant_edit')} $memberUsername' : '${context.tr('msg_revoke_edit')} $memberUsername');
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final bool isEspLinked = activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: Text(
          context.tr('family_members'), 
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: currentUsername == null
          ? const Center(child: LogoLoadingIndicator(color: AppColors.primary, size: 28))
          : StreamBuilder<DocumentSnapshot>(
              stream: _getMyDataStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LogoLoadingIndicator(color: AppColors.primary, size: 28));
                }

                final data = (snapshot.data?.exists ?? false) ? snapshot.data!.data() as Map<String, dynamic> : {};
                final List<dynamic> pendingInvites = data.containsKey('pendingInvitations') ? data['pendingInvitations'] : [];
                final List<dynamic> sharedMembers = data.containsKey('sharedWith') ? data['sharedWith'] : [];
                final List<dynamic> disabledMembers = data.containsKey('disabledMembers') ? data['disabledMembers'] : [];

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await ref.read(homeConfigProvider).syncFromFirestore();
                    setState(() {});
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          
                          // Hero Header Banner
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? const LinearGradient(
                                      colors: [Color(0xFF0E2521), Color(0xFF081513)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFFE6F4F1), Color(0xFFF0FDF4)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.people_alt_rounded, color: AppColors.primaryLight, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('manage_members'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDark ? AppColors.darkText : AppColors.lightText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        context.tr('invite_member_subtitle'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // CẢNH BÁO RÀNG BUỘC ESP32 (NẾU CHƯA LIÊN KẾT HUB)
                          if (!isEspLinked) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF231A08) : const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.amber.shade400.withOpacity(0.4), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(isDark ? 0.05 : 0.08),
                                    blurRadius: 16,
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
                                        padding: const EdgeInsets.all(9),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.router_rounded, color: Colors.amber, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              context.tr('esp_required_for_invite_title'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.amber,
                                              ),
                                            ),
                                            Text(
                                              context.tr('status_unlinked'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    context.tr('err_esp_required_for_invite'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.wifi_find_rounded, size: 18),
                                      label: Text(
                                        context.tr('btn_link_hub_now'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (context) => const WifiSetupScreen()));
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Danh sách lời mời đang chờ phản hồi (Pending Invitations)
                          if (pendingInvites.isNotEmpty) ...[
                            Text(
                              context.tr('new_invite'), 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange)
                            ),
                            const SizedBox(height: 10),
                            ...pendingInvites.map((inviterUsername) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange.shade300.withOpacity(0.5)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.orange.shade600,
                                      radius: 20,
                                      child: const Icon(Icons.mail_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            inviterUsername,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.tr('invite_desc'),
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                                      onPressed: () => _acceptInvite(inviterUsername),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 28),
                                      onPressed: () => _rejectInvite(inviterUsername),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 15),
                            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            const SizedBox(height: 15),
                          ],

                          // Thêm thành viên mới (Invite Bar)
                          Text(
                            context.tr('add_new_member'), 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                          ),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                width: 1.2,
                              ),
                              boxShadow: isDark ? [] : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.person_add_rounded, color: AppColors.primaryLight, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _usernameController,
                                    enabled: isEspLinked && !_isLoading,
                                    decoration: InputDecoration(
                                      hintText: isEspLinked ? context.tr('username_member') : context.tr('err_esp_required_for_invite'),
                                      hintStyle: TextStyle(
                                        fontSize: 13, 
                                        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: isEspLinked 
                                        ? AppColors.brandHero
                                        : const LinearGradient(colors: [Colors.grey, Colors.blueGrey]),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: IconButton(
                                    icon: _isLoading 
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                    onPressed: (!isEspLinked || _isLoading) ? null : _sendInvite,
                                    tooltip: context.tr('btn_add'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Danh sách thành viên liên kết (Members List Header)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('linked_list'), 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${sharedMembers.length} ${context.tr('family_members')}',
                                  style: const TextStyle(
                                    color: AppColors.primaryLight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (sharedMembers.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(36),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.withOpacity(0.4)),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('empty_member'),
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...sharedMembers.map((member) {
                              final String email = member.toString();
                              final bool isDisabled = disabledMembers.contains(email);
                              final String currentRole = (data.containsKey('memberRoles') && data['memberRoles'][email] != null) 
                                  ? data['memberRoles'][email] 
                                  : 'member';
                              final bool isCoOwner = currentRole == 'co_owner';
                              final bool canEditAuto = (data['automationEditors'] as List<dynamic>?)?.contains(email) ?? false;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkCard : Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                                    width: 1.2,
                                  ),
                                  boxShadow: isDark ? [] : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Member row header
                                      Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: isDisabled 
                                                  ? Colors.grey.withOpacity(0.15) 
                                                  : (isCoOwner ? Colors.amber.withOpacity(0.15) : AppColors.primary.withOpacity(0.15)),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              isDisabled 
                                                  ? Icons.lock_rounded 
                                                  : (isCoOwner ? Icons.shield_rounded : Icons.person_rounded),
                                              color: isDisabled 
                                                  ? Colors.grey 
                                                  : (isCoOwner ? Colors.amber : AppColors.primaryLight),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  email,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    decoration: isDisabled ? TextDecoration.lineThrough : null,
                                                    color: isDisabled ? Colors.grey : null,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isCoOwner ? Colors.amber.withOpacity(0.15) : AppColors.primary.withOpacity(0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        isCoOwner ? context.tr('co_owner') : context.tr('member_role'),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: isCoOwner ? Colors.amber.shade700 : AppColors.primaryLight,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      isDisabled ? context.tr('member_disabled') : context.tr('member_active'),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDisabled ? Colors.grey : Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Action button: Phân quyền vai trò
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                                            tooltip: context.tr('tooltip_permission'),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            onSelected: (val) => _changeRole(email, val),
                                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                              PopupMenuItem<String>(
                                                value: 'member',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.primaryLight),
                                                    const SizedBox(width: 10),
                                                    Text(context.tr('member_role')),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'co_owner',
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.shield_rounded, size: 18, color: Colors.amber),
                                                    const SizedBox(width: 10),
                                                    Text(context.tr('role_co_owner_full')),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                      const SizedBox(height: 10),

                                      // Switches & Kick button
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Toggle Disable / Enable
                                          Row(
                                            children: [
                                              Icon(
                                                !isDisabled ? Icons.check_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                                                size: 18,
                                                color: !isDisabled ? Colors.green : Colors.grey,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                !isDisabled ? context.tr('member_active') : context.tr('member_disabled'),
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              const SizedBox(width: 4),
                                              Switch(
                                                value: !isDisabled,
                                                activeColor: AppColors.primaryLight,
                                                onChanged: (val) => _toggleDisableMember(email, !val),
                                              ),
                                            ],
                                          ),

                                          // Automation toggle for regular members
                                          if (!isCoOwner)
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.auto_awesome_rounded,
                                                  size: 16,
                                                  color: canEditAuto ? Colors.purple : Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Switch(
                                                  value: canEditAuto,
                                                  activeColor: Colors.purple,
                                                  onChanged: (val) => _toggleAutomationEditor(email, val),
                                                ),
                                              ],
                                            ),

                                          // Kick / Revoke
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                            tooltip: context.tr('btn_kick'),
                                            onPressed: () => _confirmRemoveMember(email),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),

                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
  );
  }
} 