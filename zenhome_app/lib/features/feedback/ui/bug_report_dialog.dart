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
import 'package:zenhome_app/core/widgets/bouncing_button.dart';

class BugReportDialog extends StatefulWidget {
  const BugReportDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
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

      String appVersion = '1.7.1';
      int buildNumber = 171;
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 18,
        left: 20,
        right: 20,
        bottom: bottomInset > 0 ? bottomInset + 16 : 34,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101625) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.bug_report_rounded, color: Color(0xFF3B82F6), size: 24),
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
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('bug_report_modal_subtitle'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category Selector
            Text(
              context.tr('bug_report_category_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat['id'];
                  final Color catColor = cat['color'] as Color;

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat['id']);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? catColor.withOpacity(0.16)
                            : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? catColor : (isDark ? Colors.white.withOpacity(0.08) : Colors.transparent),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cat['icon'] as IconData,
                            size: 16,
                            color: isSelected ? catColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.tr(cat['labelKey'] as String),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? catColor : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
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
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: context.tr('bug_report_title_hint'),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Input
            Text(
              context.tr('bug_report_desc_label'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: context.tr('bug_report_desc_hint'),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Diagnostic note
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.tr('bug_report_auto_attach_hint'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: BouncingButton(
                onTap: _isSubmitting ? null : _submitReport,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('bug_report_btn_submit'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

