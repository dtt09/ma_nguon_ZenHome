import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/services/session_manager.dart';

class LoggedDevicesScreen extends StatefulWidget {
  const LoggedDevicesScreen({super.key});

  @override
  State<LoggedDevicesScreen> createState() => _LoggedDevicesScreenState();
}

class _LoggedDevicesScreenState extends State<LoggedDevicesScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _currentDeviceId = '';
  String? _username;
  bool _isTrustRequested = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentDeviceId();
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    if (user != null) {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user!.uid)
          .get();
      if (query.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _username = query.docs.first.id;
          });
        }
      }
    }
  }

  Future<void> _fetchCurrentDeviceId() async {
    String deviceId = 'unknown_id';
    try {
      deviceId = await SessionManager.getUniqueDeviceId();
    } catch (e) {
      debugPrint("Error fetching device ID: $e");
    }

    if (mounted) {
      setState(() {
        _currentDeviceId = deviceId;
      });
    }
  }

  void _revokeSession(String deviceId, String deviceName) async {
    if (user == null) return;

    final String displayDevice =
        deviceName.isNotEmpty ? deviceName : context.tr('unknown_device');

    final zen = context.zenColors;
    bool confirm = await showZenGlassDialog<bool>(
          context: context,
          accentColor: zen.danger,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final mutedColor =
                isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: zen.danger.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: zen.danger.withOpacity(0.32)),
                      ),
                      child: Icon(Icons.phonelink_erase_rounded,
                          color: zen.danger, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('logout_device_title'),
                        style: TextStyle(
                          color: zen.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  context
                      .tr('confirm_kick_device')
                      .replaceAll('{device}', displayDevice),
                  style: TextStyle(fontSize: 14, height: 1.5, color: mutedColor),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: ZenGlassButton(
                        label: context.tr('btn_cancel'),
                        isPrimary: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ZenGlassButton(
                        label: context.tr('btn_kick_device'),
                        icon: Icons.logout_rounded,
                        isDanger: true,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      if (!mounted) return;
      bool isReauthed = await ReauthHelper.reauthenticate(
        context,
        reason: context.tr('reason_kick_device'),
      );
      if (!isReauthed) return;

      if (!mounted) return;
      LoadingOverlay.show(context);
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_username)
            .collection('sessions')
            .doc(deviceId)
            .update({'isActive': false, 'fcmToken': FieldValue.delete()});

        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_success'),
            context.tr('msg_kick_success'),
          );
        }
      } catch (e) {
        LoadingOverlay.hide();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('error'),
            context.tr('err_kick_failed'),
            isError: true,
          );
        }
      }
    }
  }

  void _requestTrust(String deviceName) async {
    if (_username == null) return;
    setState(() {
      _isTrustRequested = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_username)
          .collection('alerts')
          .add({
        'type': 'trust_request',
        'deviceName': deviceName,
        'deviceId': _currentDeviceId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('msg_trust_req_sent'),
        );
      }
    } catch (e) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('error'),
          context.tr('err_trust_req_failed'),
          isError: true,
        );
        setState(() {
          _isTrustRequested = false;
        });
      }
    }
  }

  Widget _buildMetaRow(IconData icon, String text, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14.5, color: mutedColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: mutedColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
    bool isCurrentDevice,
    bool isCurrentDeviceTrusted,
    bool isDark,
  ) {
    final zen = context.zenColors;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final bool isActive = data['isActive'] ?? false;
    final bool isTrusted = data['isTrusted'] ?? false;
    final String deviceName = data['deviceName'] ?? 'Unknown Device';
    final String os = data['os'] ?? 'Unknown OS';
    final String location = data['location'] ?? 'Unknown Location';

    final Timestamp? lastLoginTs = data['lastLogin'];
    final Timestamp? lastAccessTs = data['lastAccess'];

    String lastLoginStr = 'Unknown';
    if (lastLoginTs != null) {
      lastLoginStr = DateFormat('HH:mm dd/MM/yyyy').format(lastLoginTs.toDate());
    }

    String lastAccessStr = 'Unknown';
    if (lastAccessTs != null) {
      lastAccessStr =
          DateFormat('HH:mm dd/MM/yyyy').format(lastAccessTs.toDate());
    }

    // Checking if > 30 days
    bool isExpired = false;
    if (lastAccessTs != null) {
      if (DateTime.now().difference(lastAccessTs.toDate()).inDays > 30) {
        isExpired = true;
      }
    }

    final bool effectivelyActive = isActive && !isExpired;
    final Color deviceAccent = isCurrentDevice
        ? zen.primary
        : (effectivelyActive ? AppColors.cyanGlow : mutedColor);

    final bool isApple =
        os.toLowerCase().contains('ios') || os.toLowerCase().contains('mac');

    return ZenGlassCard(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      isActive: isCurrentDevice,
      glowColor: isCurrentDevice ? zen.primary : null,
      blurSigma: isCurrentDevice ? 16 : 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isCurrentDevice
                      ? zen.brandHero
                      : LinearGradient(
                          colors: [
                            deviceAccent.withOpacity(isDark ? 0.22 : 0.14),
                            deviceAccent.withOpacity(isDark ? 0.08 : 0.06),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isCurrentDevice
                        ? Colors.white.withOpacity(0.32)
                        : deviceAccent.withOpacity(0.28),
                  ),
                ),
                child: Icon(
                  isApple ? Icons.apple : Icons.phone_android_rounded,
                  size: 26,
                  color: isCurrentDevice ? Colors.white : deviceAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            deviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: effectivelyActive
                                  ? textColor
                                  : mutedColor.withOpacity(0.75),
                            ),
                          ),
                        ),
                        if (isTrusted) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Trusted Device',
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: isDark ? zen.primaryAccent : zen.primary,
                              size: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          os,
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isCurrentDevice)
                          ZenGlassPill(
                            blurSigma: 0,
                            isSelected: true,
                            glowColor: zen.success,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            child: Text(
                              context.tr('this_device'),
                              style: TextStyle(
                                color: zen.success,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withOpacity(0.09)
                  : const Color(0xFFCBD5E1).withOpacity(0.55),
            ),
          ),
          _buildMetaRow(Icons.location_on_outlined, location, mutedColor),
          _buildMetaRow(
            Icons.login_rounded,
            '${context.tr('last_login')} $lastLoginStr',
            mutedColor,
          ),
          _buildMetaRow(
            Icons.access_time_rounded,
            '${context.tr('last_access')} $lastAccessStr',
            mutedColor,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Online / Logged-out Status Pill
              ZenGlassPill(
                blurSigma: 0,
                isSelected: effectivelyActive,
                glowColor:
                    effectivelyActive ? zen.success : zen.danger,
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: effectivelyActive
                            ? zen.success
                            : mutedColor,
                        boxShadow: effectivelyActive
                            ? [
                                BoxShadow(
                                  color: zen.success.withOpacity(0.65),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      effectivelyActive
                          ? context.tr('status_logged_in')
                          : context.tr('status_logged_out'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: effectivelyActive
                            ? zen.success
                            : zen.danger,
                      ),
                    ),
                  ],
                ),
              ),

              // Revoke Session Glass Button
              if (effectivelyActive &&
                  !isCurrentDevice &&
                  isCurrentDeviceTrusted)
                ZenGlassPill(
                  blurSigma: 0,
                  isSelected: true,
                  glowColor: zen.danger,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onTap: () => _revokeSession(id, deviceName),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded,
                          size: 14, color: zen.danger),
                      const SizedBox(width: 5),
                      Text(
                        context.tr('btn_logout'),
                        style: TextStyle(
                          color: zen.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // Request Trust Glass Pill
              if (effectivelyActive && isCurrentDevice && !isTrusted)
                _isTrustRequested
                    ? ZenGlassPill(
                        blurSigma: 0,
                        isSelected: true,
                        glowColor: zen.warning,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        child: Text(
                          context.tr('btn_request_sent'),
                          style: TextStyle(
                            color: zen.warning,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                          ),
                        ),
                      )
                    : ZenGlassPill(
                        blurSigma: 0,
                        isSelected: true,
                        glowColor: zen.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        onTap: () => _requestTrust(deviceName),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: isDark ? zen.primaryAccent : zen.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('btn_request_trust'),
                              style: TextStyle(
                                color: isDark ? zen.primaryAccent : zen.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        titleText: context.tr('menu_logged_devices'),
      ),
      body: _username == null
          ? Center(
              child: LogoLoadingIndicator(color: zen.primary, size: 28),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_username)
                  .collection('sessions')
                  .orderBy('lastAccess', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: LogoLoadingIndicator(color: zen.primary, size: 28),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: ZenGlassCard(
                        blurSigma: 16,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: zen.primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.devices_other_rounded,
                                size: 46,
                                color: isDark ? zen.primaryAccent : zen.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              context.tr('msg_no_other_devices'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                // Determine if current device is trusted
                bool isCurrentTrusted = false;
                for (var doc in docs) {
                  if (doc.id == _currentDeviceId) {
                    final d = doc.data() as Map<String, dynamic>;
                    isCurrentTrusted = d['isTrusted'] ?? false;
                    break;
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final isCurrent = id == _currentDeviceId;

                    return _buildDeviceItem(
                      context,
                      data,
                      id,
                      isCurrent,
                      isCurrentTrusted,
                      isDark,
                    );
                  },
                );
              },
            ),
    );
  }
}
