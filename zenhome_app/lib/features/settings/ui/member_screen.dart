import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/settings/logic/member_controller.dart';

class MemberScreen extends ConsumerStatefulWidget {
  const MemberScreen({super.key});

  @override
  ConsumerState<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends ConsumerState<MemberScreen> {
  final TextEditingController _usernameController = TextEditingController();
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
    final username = await ref.read(memberControllerProvider.notifier).loadCurrentUsername();
    if (mounted) {
      setState(() {
        currentUsername = username;
      });
    }
  }

  Stream<DocumentSnapshot>? _getMyDataStream() {
    return ref.read(memberControllerProvider.notifier).getMyDataStream();
  }

  void _sendInvite() async {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final bool isEspLinked = activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown';

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
      showFloatingToast(context, context.tr('error'), context.tr('err_invalid_username'), isError: true);
      return;
    }
    if (targetUsername == currentUsername) {
      showFloatingToast(context, context.tr('error'), context.tr('err_self_invite'), isError: true);
      return;
    }

    final result = await ref.read(memberControllerProvider.notifier).sendInvite(targetUsername);
    if (!mounted) return;

    if (result.success) {
      _usernameController.clear();
      showFloatingToast(context, context.tr('toast_success'), '${context.tr('msg_send_success')} $targetUsername');
    } else {
      final msg = result.errorMessage == 'err_user_not_found'
          ? context.tr('err_user_not_found')
          : (result.errorMessage ?? context.tr('error'));
      showFloatingToast(context, context.tr('error'), msg, isError: true);
    }
  }

  void _acceptInvite(String ownerUsername) async {
    showFloatingToast(context, context.tr('msg_processing'), '${context.tr('msg_syncing_home')} $ownerUsername...');
    final result = await ref.read(memberControllerProvider.notifier).acceptInvite(ownerUsername);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(context, context.tr('toast_success'), context.tr('msg_sync_success'));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainLayout()),
        (Route<dynamic> route) => false,
      );
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  void _rejectInvite(String ownerUsername) async {
    final result = await ref.read(memberControllerProvider.notifier).rejectInvite(ownerUsername);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(context, context.tr('toast_success'), '${context.tr('msg_reject_success')} $ownerUsername');
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  void _removeMember(String memberUsername) async {
    final result = await ref.read(memberControllerProvider.notifier).removeMember(memberUsername);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(context, context.tr('msg_deleted_title'), '${context.tr('msg_revoke_success')} $memberUsername');
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  void _toggleDisableMember(String memberUsername, bool isDisabled) async {
    final result = await ref.read(memberControllerProvider.notifier).toggleDisableMember(memberUsername, isDisabled);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(
        context,
        context.tr('toast_success'),
        isDisabled
            ? context.l10n.msg_disabled_member(memberUsername)
            : context.l10n.msg_enabled_member(memberUsername),
      );
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  void _toggleAutomationEditor(String memberUsername, bool canEdit) async {
    final result = await ref.read(memberControllerProvider.notifier).toggleAutomationEditor(memberUsername, canEdit);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(
        context,
        context.tr('toast_success'),
        canEdit
            ? '${context.tr('msg_grant_edit')} $memberUsername'
            : '${context.tr('msg_revoke_edit')} $memberUsername',
      );
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  void _changeRole(String memberUsername, String newRole) async {
    final result = await ref.read(memberControllerProvider.notifier).changeRole(memberUsername, newRole);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(
        context,
        context.tr('toast_success'),
        context.l10n.msg_role_granted(
          newRole == 'co_owner' ? context.tr('co_owner') : context.tr('member_role'),
          memberUsername,
        ),
      );
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
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

  void _cancelSentInvite(String targetUsername) async {
    final result = await ref.read(memberControllerProvider.notifier).cancelSentInvite(targetUsername);
    if (!mounted) return;

    if (result.success) {
      showFloatingToast(context, context.tr('toast_success'), 'Đã thu hồi lời mời tới $targetUsername');
    } else {
      showFloatingToast(context, context.tr('error'), result.errorMessage ?? context.tr('error'), isError: true);
    }
  }

  void _showDevicePermissionsDialog(String memberUsername, List<dynamic>? currentAllowedList) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final allDevices = activeConfig.devices;

    // Nếu currentAllowedList == null, nghĩa là toàn quyền (all allowed)
    bool isCustom = currentAllowedList != null;
    final Set<String> selectedIds = currentAllowedList != null
        ? currentAllowedList.map((e) => e.toString()).toSet()
        : allDevices.map((e) => e.id).toSet();

    showZenGlassDialog(
      context: context,
      maxWidth: 420,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (sbCtx, setDialogState) {
            final isDark = Theme.of(sbCtx).brightness == Brightness.dark;
            final zen = sbCtx.zenColors;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: zen.brandHero,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: zen.primary.withOpacity(0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Quyền điều khiển thiết bị',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: -0.2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memberUsername,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Toggle Cho phép tất cả vs Chọn lọc
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          surfaceColor: isCustom
                              ? AppColors.amberGlow.withOpacity(isDark ? 0.14 : 0.10)
                              : zen.primary.withOpacity(isDark ? 0.16 : 0.10),
                          glowColor: isCustom ? AppColors.amberGlow : zen.primary,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isCustom ? 'Chỉ thiết bị được chọn' : 'Toàn quyền (Tất cả thiết bị)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isCustom
                                        ? (isDark ? Colors.amber.shade300 : Colors.amber.shade800)
                                        : (isDark ? zen.primaryAccent : zen.primary),
                                  ),
                                ),
                              ),
                              Switch(
                                value: !isCustom,
                                activeColor: isDark ? zen.primaryAccent : zen.primary,
                                onChanged: (val) {
                                  setDialogState(() {
                                    isCustom = !val;
                                    if (!isCustom) {
                                      selectedIds.clear();
                                      selectedIds.addAll(allDevices.map((e) => e.id));
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        if (isCustom) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Chọn thiết bị được bật/tắt (${selectedIds.length}/${allDevices.length}):',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 260),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: allDevices.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (_, idx) {
                                final dev = allDevices[idx];
                                final bool isSelected = selectedIds.contains(dev.id);
                                return ZenLiquidGlass(
                                  blurSigma: 0,
                                  borderRadius: 14,
                                  surfaceColor: isSelected
                                      ? zen.primary.withOpacity(isDark ? 0.16 : 0.10)
                                      : (isDark
                                          ? Colors.white.withOpacity(0.04)
                                          : Colors.white.withOpacity(0.55)),
                                  glowColor: isSelected ? zen.primary : null,
                                  child: CheckboxListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    activeColor: isDark ? zen.primaryAccent : zen.primary,
                                    title: Text(
                                      dev.name,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      dev.room,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      ),
                                    ),
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selectedIds.add(dev.id);
                                        } else {
                                          selectedIds.remove(dev.id);
                                        }
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ZenGlassButton(
                        label: context.tr('btn_cancel'),
                        isPrimary: false,
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ZenGlassButton(
                        label: context.tr('btn_save_changes'),
                        icon: Icons.check_rounded,
                        isPrimary: true,
                        onPressed: () async {
                          Navigator.pop(dialogCtx);
                          final List<String> toSave = isCustom ? selectedIds.toList() : <String>[];
                          final res = await ref
                              .read(memberControllerProvider.notifier)
                              .updateDevicePermissions(memberUsername, toSave);
                          if (!mounted) return;
                          if (res.success) {
                            showFloatingToast(
                              context,
                              context.tr('toast_success'),
                              res.message ?? 'Đã cập nhật quyền thiết bị',
                            );
                          } else {
                            showFloatingToast(
                              context,
                              context.tr('error'),
                              res.errorMessage ?? 'Lỗi cập nhật',
                              isError: true,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final bool isLoading = ref.watch(memberControllerProvider);
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final bool isEspLinked = activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown';
    final Color glassDividerColor = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFCBD5E1).withOpacity(0.55);

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        titleText: context.tr('family_members'),
      ),
      body: currentUsername == null
          ? Center(child: LogoLoadingIndicator(color: zen.primary, size: 28))
          : StreamBuilder<DocumentSnapshot>(
              stream: _getMyDataStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: LogoLoadingIndicator(color: zen.primary, size: 28));
                }

                final data = (snapshot.data?.exists ?? false) ? snapshot.data!.data() as Map<String, dynamic> : {};
                final List<dynamic> pendingInvites = data.containsKey('pendingInvitations') ? data['pendingInvitations'] : [];
                final List<dynamic> sentInvites = data.containsKey('sentInvitations') ? data['sentInvitations'] : [];
                final List<dynamic> sharedMembers = data.containsKey('sharedWith') ? data['sharedWith'] : [];
                final List<dynamic> disabledMembers = data.containsKey('disabledMembers') ? data['disabledMembers'] : [];

                return RefreshIndicator(
                  color: zen.primary,
                  onRefresh: () async {
                    await ref.read(homeConfigProvider).syncFromFirestore();
                    setState(() {});
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // Hero Header Banner
                            ZenGlassCard(
                              blurSigma: 12,
                              borderRadius: 24,
                              isActive: true,
                              glowColor: zen.primary,
                              padding: const EdgeInsets.all(20),
                              margin: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(13),
                                    decoration: BoxDecoration(
                                      gradient: zen.brandHero,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: zen.primary.withOpacity(isDark ? 0.38 : 0.24),
                                          blurRadius: 14,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 26),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('manage_members'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16.5,
                                            letterSpacing: -0.2,
                                            color: isDark ? AppColors.darkText : AppColors.lightText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.tr('invite_member_subtitle'),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                            height: 1.35,
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
                              ZenGlassCard(
                                blurSigma: 12,
                                borderRadius: 24,
                                isActive: true,
                                glowColor: AppColors.amberGlow,
                                padding: const EdgeInsets.all(18),
                                margin: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.amberGlow.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: const Icon(Icons.router_rounded, color: AppColors.amberGlow, size: 22),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.tr('esp_required_for_invite_title'),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  color: AppColors.amberGlow,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
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
                                    const SizedBox(height: 12),
                                    Text(
                                      context.tr('err_esp_required_for_invite'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightText,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ZenGlassButton(
                                        label: context.tr('btn_link_hub_now'),
                                        icon: Icons.wifi_find_rounded,
                                        isPrimary: true,
                                        accentColor: AppColors.amberDeep,
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const WifiSetupScreen()),
                                          );
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: AppColors.amberGlow,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...pendingInvites.map((inviterUsername) {
                                final String inviter = inviterUsername.toString();
                                return ZenGlassCard(
                                  blurSigma: 12,
                                  borderRadius: 20,
                                  isActive: true,
                                  glowColor: AppColors.amberGlow,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.lightOn,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.mail_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inviter,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              context.tr('invite_desc'),
                                              style: TextStyle(
                                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ZenGlassIconButton(
                                        icon: Icons.check_rounded,
                                        size: 38,
                                        iconSize: 20,
                                        blurSigma: 0,
                                        iconColor: AppColors.emeraldGlow,
                                        glowColor: AppColors.emeraldGlow,
                                        onTap: () => _acceptInvite(inviter),
                                      ),
                                      const SizedBox(width: 8),
                                      ZenGlassIconButton(
                                        icon: Icons.close_rounded,
                                        size: 38,
                                        iconSize: 20,
                                        blurSigma: 0,
                                        iconColor: AppColors.roseGlow,
                                        glowColor: AppColors.roseGlow,
                                        onTap: () => _rejectInvite(inviter),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              Divider(color: glassDividerColor),
                              const SizedBox(height: 12),
                            ],

                            // Danh sách lời mời đã gửi (Sent Invitations)
                            if (sentInvites.isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.outbox_rounded, size: 18, color: AppColors.cyanGlow),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Lời mời đã gửi (${sentInvites.length}):',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppColors.cyanGlow,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...sentInvites.map((targetUsername) {
                                final String target = targetUsername.toString();
                                return ZenGlassCard(
                                  blurSigma: 12,
                                  borderRadius: 20,
                                  isActive: true,
                                  glowColor: AppColors.cyanGlow,
                                  padding: const EdgeInsets.all(14),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.fanOn,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.person_search_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              target,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              context.tr('invite_pending_confirm'),
                                              style: TextStyle(
                                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ZenGlassButton(
                                        label: context.tr('btn_revoke'),
                                        icon: Icons.undo_rounded,
                                        isPrimary: false,
                                        isDanger: true,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        borderRadius: 12,
                                        onPressed: () => _cancelSentInvite(target),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              Divider(color: glassDividerColor),
                              const SizedBox(height: 12),
                            ],

                            // Thêm thành viên mới (Invite Bar)
                            Text(
                              context.tr('add_new_member'),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 10),
                            ZenGlassCard(
                              blurSigma: 12,
                              borderRadius: 22,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _usernameController,
                                      enabled: isEspLinked && !isLoading,
                                      decoration: zenGlassInputDecoration(
                                        context,
                                        hintText: isEspLinked
                                            ? context.tr('username_member')
                                            : context.tr('err_esp_required_for_invite'),
                                        prefixIcon: Icons.person_add_alt_1_rounded,
                                        borderRadius: 16,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ZenGlassButton(
                                    label: context.tr('btn_add'),
                                    icon: Icons.send_rounded,
                                    isPrimary: true,
                                    isLoading: isLoading,
                                    borderRadius: 16,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13.5),
                                    onPressed: (!isEspLinked || isLoading) ? null : _sendInvite,
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
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                ZenGlassPill(
                                  blurSigma: 10,
                                  isSelected: true,
                                  glowColor: zen.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  child: Text(
                                    '${sharedMembers.length} ${context.tr('family_members')}',
                                    style: TextStyle(
                                      color: isDark ? zen.primaryAccent : zen.primary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (sharedMembers.isEmpty)
                              ZenGlassCard(
                                blurSigma: 12,
                                borderRadius: 24,
                                padding: const EdgeInsets.all(36),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.people_outline_rounded,
                                      size: 48,
                                      color: (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted).withOpacity(0.55),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      context.tr('empty_member'),
                                      style: TextStyle(
                                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...sharedMembers.map((member) {
                                final String email = member.toString();
                                final bool isDisabled = disabledMembers.contains(email);
                                final String currentRole =
                                    (data.containsKey('memberRoles') && data['memberRoles'][email] != null)
                                        ? data['memberRoles'][email]
                                        : 'member';
                                final bool isCoOwner = currentRole == 'co_owner';
                                final bool canEditAuto =
                                    (data['automationEditors'] as List<dynamic>?)?.contains(email) ?? false;
                                final Map<String, dynamic> allDevPerms = data.containsKey('memberDevicePermissions')
                                    ? Map<String, dynamic>.from(data['memberDevicePermissions'] ?? {})
                                    : {};
                                final List<dynamic>? memberAllowedDevs = allDevPerms[email];
                                final bool hasCustomDevs = memberAllowedDevs != null;

                                return ZenGlassCard(
                                  blurSigma: 12,
                                  borderRadius: 22,
                                  padding: const EdgeInsets.all(16.0),
                                  margin: const EdgeInsets.only(bottom: 14),
                                  isActive: isCoOwner && !isDisabled,
                                  glowColor: isCoOwner ? AppColors.amberGlow : zen.primary,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Member row header
                                      Row(
                                        children: [
                                          ZenLiquidGlass(
                                            width: 44,
                                            height: 44,
                                            borderRadius: 15,
                                            blurSigma: 0,
                                            alignment: Alignment.center,
                                            surfaceColor: isDisabled
                                                ? Colors.grey.withOpacity(0.15)
                                                : (isCoOwner
                                                    ? AppColors.amberGlow.withOpacity(0.18)
                                                    : zen.primary.withOpacity(0.16)),
                                            glowColor: isDisabled
                                                ? null
                                                : (isCoOwner ? AppColors.amberGlow : zen.primary),
                                            child: Icon(
                                              isDisabled
                                                  ? Icons.lock_rounded
                                                  : (isCoOwner ? Icons.shield_rounded : Icons.person_rounded),
                                              color: isDisabled
                                                  ? Colors.grey
                                                  : (isCoOwner
                                                      ? AppColors.amberGlow
                                                      : (isDark ? zen.primaryAccent : zen.primary)),
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
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    decoration: isDisabled ? TextDecoration.lineThrough : null,
                                                    color: isDisabled ? Colors.grey : null,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 5),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    ZenGlassPill(
                                                      blurSigma: 0,
                                                      isSelected: true,
                                                      glowColor: isCoOwner ? AppColors.amberGlow : zen.primary,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                      child: Text(
                                                        isCoOwner ? context.tr('co_owner') : context.tr('member_role'),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w800,
                                                          color: isCoOwner
                                                              ? (isDark ? Colors.amber.shade300 : Colors.amber.shade800)
                                                              : (isDark ? zen.primaryAccent : zen.primary),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      isDisabled ? context.tr('member_disabled') : context.tr('member_active'),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDisabled ? Colors.grey : AppColors.emeraldGlow,
                                                      ),
                                                    ),
                                                    if (hasCustomDevs)
                                                      ZenGlassPill(
                                                        blurSigma: 0,
                                                        isSelected: true,
                                                        glowColor: AppColors.cyanGlow,
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                                        child: Text(
                                                          '${memberAllowedDevs.length} thiết bị',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w700,
                                                            color: isDark ? Colors.cyan.shade200 : AppColors.cyanDeep,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Action button: Phân quyền vai trò & thiết bị & xóa (ZenGlassPopupMenuButton)
                                          ZenGlassPopupMenuButton<String>(
                                            tooltip: context.tr('tooltip_permission'),
                                            onSelected: (val) {
                                              if (val == 'device_perm') {
                                                _showDevicePermissionsDialog(email, memberAllowedDevs);
                                              } else if (val == 'remove') {
                                                _confirmRemoveMember(email);
                                              } else {
                                                _changeRole(email, val);
                                              }
                                            },
                                            items: [
                                              ZenGlassMenuOption<String>(
                                                value: 'member',
                                                label: context.tr('member_role'),
                                                icon: Icons.person_outline_rounded,
                                                color: zen.primary,
                                              ),
                                              ZenGlassMenuOption<String>(
                                                value: 'co_owner',
                                                label: context.tr('role_co_owner_full'),
                                                icon: Icons.shield_rounded,
                                                color: AppColors.amberGlow,
                                              ),
                                              ZenGlassMenuOption<String>(
                                                value: 'device_perm',
                                                label: context.tr('device_permissions_title'),
                                                icon: Icons.tune_rounded,
                                                color: AppColors.cyanGlow,
                                                showDividerAbove: true,
                                              ),
                                              ZenGlassMenuOption<String>(
                                                value: 'remove',
                                                label: context.tr('btn_kick'),
                                                icon: Icons.person_remove_rounded,
                                                isDanger: true,
                                                showDividerAbove: true,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      Divider(height: 1, color: glassDividerColor),
                                      const SizedBox(height: 10),

                                      // Switches & Action buttons
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Toggle Disable / Enable
                                          Row(
                                            children: [
                                              Icon(
                                                !isDisabled
                                                    ? Icons.check_circle_outline_rounded
                                                    : Icons.pause_circle_outline_rounded,
                                                size: 18,
                                                color: !isDisabled ? AppColors.emeraldGlow : Colors.grey,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                !isDisabled ? context.tr('member_active') : context.tr('member_disabled'),
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                              const SizedBox(width: 4),
                                              Switch(
                                                value: !isDisabled,
                                                activeColor: isDark ? zen.primaryAccent : zen.primary,
                                                onChanged: (val) => _toggleDisableMember(email, !val),
                                              ),
                                            ],
                                          ),

                                          Row(
                                            children: [
                                              // Automation toggle for regular members
                                              if (!isCoOwner) ...[
                                                Icon(
                                                  Icons.auto_awesome_rounded,
                                                  size: 16,
                                                  color: canEditAuto ? AppColors.purpleGlow : Colors.grey,
                                                ),
                                                const SizedBox(width: 4),
                                                Switch(
                                                  value: canEditAuto,
                                                  activeColor: AppColors.purpleGlow,
                                                  onChanged: (val) => _toggleAutomationEditor(email, val),
                                                ),
                                                const SizedBox(width: 6),
                                              ],

                                              // Device permissions shortcut
                                              ZenGlassIconButton(
                                                icon: Icons.tune_rounded,
                                                size: 36,
                                                iconSize: 18,
                                                blurSigma: 0,
                                                iconColor: hasCustomDevs ? AppColors.cyanGlow : Colors.grey,
                                                glowColor: hasCustomDevs ? AppColors.cyanGlow : null,
                                                tooltip: 'Phân quyền thiết bị',
                                                onTap: () => _showDevicePermissionsDialog(email, memberAllowedDevs),
                                              ),
                                              const SizedBox(width: 8),

                                              // Kick / Revoke
                                              ZenGlassIconButton(
                                                icon: Icons.delete_outline_rounded,
                                                size: 36,
                                                iconSize: 18,
                                                blurSigma: 0,
                                                iconColor: AppColors.roseGlow,
                                                glowColor: AppColors.roseGlow,
                                                tooltip: context.tr('btn_kick'),
                                                onTap: () => _confirmRemoveMember(email),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 24),
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