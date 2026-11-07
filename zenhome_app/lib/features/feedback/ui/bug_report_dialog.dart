import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

Future<void> showBugReportDialog(BuildContext context) =>
    BugReportDialog.show(context);

class BugReportDialog extends StatefulWidget {
  const BugReportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showZenGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      padBottomForKeyboard: true,
      showHandle: true,
      maxHeightFactor: 0.90,
      builder: (_) => const BugReportDialog(),
    );
  }

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'ui';
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': 'ui',
      'labelKey': 'bug_report_category_ui',
      'icon': Icons.palette_rounded,
      'color': Color(0xFF8B5CF6),
    },
    {
      'id': 'mqtt',
      'labelKey': 'bug_report_category_network',
      'icon': Icons.wifi_rounded,
      'color': Color(0xFFF59E0B),
    },
    {
      'id': 'device',
      'labelKey': 'bug_report_category_control',
      'icon': Icons.toggle_on_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'id': 'automation',
      'labelKey': 'bug_report_category_scene',
      'icon': Icons.auto_awesome_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'id': 'other',
      'labelKey': 'bug_report_category_other',
      'icon': Icons.help_outline_rounded,
      'color': Color(0xFF64748B),
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    if (title.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('bug_report_err_empty_title'), isError: true);
      return;
    }
    if (desc.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('bug_report_err_empty_desc'), isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.lightImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      String deviceModel = context.tr('bug_report_device_mobile');
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceModel = '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceModel = '${iosInfo.utsname.machine} (iOS ${iosInfo.systemVersion})';
        }
      } catch (_) {}

      String appVersion = '1.7.9';
      int buildNumber = 177;
      try {
        final pkg = await PackageInfo.fromPlatform();
        appVersion = pkg.version;
        buildNumber = int.tryParse(pkg.buildNumber) ?? 171;
      } catch (_) {}

      final contact = getDisplayEmailOrPhone(user);

      final reportData = {
        'userId': user?.uid ?? 'guest',
        'authorName': user?.displayName ?? (contact.isNotEmpty ? contact : context.tr('bug_report_user_zenhome')),
        'contactInfo': contact,
        'category': _selectedCategory,
        'title': title,
        'description': desc,
        'deviceModel': deviceModel,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1. Lưu vào collection top-level bug_reports để Admin Web hiển thị realtime
      await FirebaseFirestore.instance.collection('bug_reports').add(reportData);

      // 2. Lưu vào subcollection người dùng nếu có UID
      if (user != null && user.uid.isNotEmpty) {
        try {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();
          if (userSnap.docs.isNotEmpty) {
            await userSnap.docs.first.reference.collection('bug_reports').add(reportData);
          }
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        showFloatingToast(
          context,
          context.tr('toast_success'),
          context.tr('bug_report_success_msg'),
        );
      }
    } catch (e) {
      if (mounted) {
        showFloatingToast(context, context.tr('error'), '${context.tr('bug_report_send_failed')} $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (không lặp lại drag handle vì showZenGlassBottomSheet đã có sẵn)
            Row(
              children: [
                ZenLiquidGlass(
                  blurSigma: 0,
                  width: 44,
                  height: 44,
                  borderRadius: 14,
                  glowColor: zen.primary,
                  surfaceColor: zen.primary.withOpacity(isDark ? 0.18 : 0.12),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.bug_report_rounded,
                    color: isDark ? zen.primaryAccent : zen.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('bug_report_modal_title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('bug_report_modal_subtitle'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                ZenGlassIconButton(
                  icon: Icons.close_rounded,
                  size: 36,
                  iconSize: 18,
                  blurSigma: 0,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Selector (ZenGlassPill)
            Text(
              context.tr('bug_report_category_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  final Color catColor = cat['color'] as Color;

                  return ZenGlassPill(
                    blurSigma: 0,
                    isSelected: isSelected,
                    glowColor: catColor,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 8.5,
                    ),
                    borderRadius: 16,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat['id'] as String);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? catColor
                              : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr(cat['labelKey'] as String),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : catColor)
                                : (isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),

            // Title Input
            Text(
              context.tr('bug_report_title_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              decoration: zenGlassInputDecoration(
                context,
                hintText: context.tr('bug_report_title_hint'),
                prefixIcon: Icons.short_text_rounded,
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            Text(
              context.tr('bug_report_desc_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              decoration: zenGlassInputDecoration(
                context,
                hintText: context.tr('bug_report_desc_hint'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Diagnostic Auto-Attach Note
            ZenLiquidGlass(
              blurSigma: 0,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              surfaceColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.55),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: isDark ? zen.primaryAccent : zen.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('bug_report_auto_attach_hint'),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('bug_report_btn_submit'),
                icon: Icons.send_rounded,
                isPrimary: true,
                isLoading: _isSubmitting,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                onPressed: _isSubmitting ? null : _submitReport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

