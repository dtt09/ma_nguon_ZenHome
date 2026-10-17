import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';

void showHomeSwitcherBottomSheet(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final allHomes = ref.read(homeConfigProvider).availableHomes;
  final activeConfig = ref.read(homeConfigProvider).activeConfig;
  
  // Khởi tạo Future kiểm tra trạng thái vô hiệu hóa 1 lần duy nhất bên ngoài builder
  // Tránh việc animation mở Bottom Sheet bị khựng/drop-frame do Firebase query liên tục
  final disabledStatusFuture = _checkDisabledStatus(allHomes);
  
  HapticFeedback.lightImpact();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (sheetContext) {
      return FutureBuilder<Map<String, bool>>(
        future: disabledStatusFuture,
        initialData: const {},
        builder: (context, snapshot) {
          final disabledMap = snapshot.data ?? {};

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 36),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101625) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thanh kéo pill mềm mại
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
                const SizedBox(height: 20),

                // Tiêu đề
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.home_work_rounded, color: Color(0xFF3B82F6), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          context.tr('switch_home') ?? 'Chuyển đổi nhà',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Danh sách nhà
                if (allHomes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.home_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('no_home_to_switch') ?? 'Không có ngôi nhà nào khác',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: allHomes.length,
                      itemBuilder: (context, index) {
                        final home = allHomes[index];
                        final isSelected = home.userId == activeConfig.userId;
                        final isHomeDisabled = disabledMap[home.userId] == true;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BouncingButton(
                            onTap: () async {
                              if (isHomeDisabled) {
                                showFloatingToast(
                                  context,
                                  context.tr('error') ?? 'Lỗi',
                                  context.tr('status_disabled') ?? 'Bị vô hiệu hóa tạm thời',
                                  isError: true,
                                );
                                return;
                              }
                              Navigator.pop(sheetContext);
                              if (!isSelected) {
                                HapticFeedback.selectionClick();
                                showFloatingToast(
                                  context,
                                  context.tr('switch_home'),
                                  context.tr('switching_to_home').replaceAll('{name}', home.homeName),
                                );
                                try {
                                  await ref.read(homeConfigProvider).switchActiveHome(home.userId).timeout(const Duration(seconds: 5));
                                  if (context.mounted) {
                                    showFloatingToast(
                                      context,
                                      context.tr('toast_success'),
                                      context.tr('switched_to_home').replaceAll('{name}', home.homeName),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showFloatingToast(
                                      context,
                                      context.tr('error') ?? 'Lỗi',
                                      '${context.tr('err_switch_home_failed') ?? 'Không thể chuyển nhà:'} $e',
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF0F766E).withOpacity(isDark ? 0.25 : 0.08)
                                    : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6).withOpacity(0.18)
                                          : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.home_rounded,
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          home.homeName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected
                                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                : (isDark ? Colors.grey.shade200 : const Color(0xFF334155)),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isHomeDisabled ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isHomeDisabled
                                                  ? (context.tr('status_disabled') ?? 'Bị vô hiệu hóa tạm thời')
                                                  : (home.role == 'owner'
                                                      ? (context.tr('owner_role') ?? 'Nhà chính của bạn')
                                                      : (context.tr('shared_home') ?? 'Nhà được chia sẻ')),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isHomeDisabled ? const Color(0xFFEF4444) : Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<Map<String, bool>> _checkDisabledStatus(List<SmartConfig> homes) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  
  Map<String, bool> disabledStatus = {};
  String? myUsername;
  
  try {
    final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
    if (query.docs.isNotEmpty) {
      myUsername = query.docs.first.id;
    }
  } catch (e) {
    return {};
  }
  
  if (myUsername == null) return {};

  for (var home in homes) {
    if (home.role == 'owner') {
      disabledStatus[home.userId] = false;
      continue;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(home.userId).get();
      if (doc.exists) {
        List<dynamic> disabledMembers = doc.data()?['disabledMembers'] ?? [];
        disabledStatus[home.userId] = disabledMembers.contains(myUsername);
      } else {
        disabledStatus[home.userId] = false;
      }
    } catch (e) {
      disabledStatus[home.userId] = false;
    }
  }
  return disabledStatus;
}

