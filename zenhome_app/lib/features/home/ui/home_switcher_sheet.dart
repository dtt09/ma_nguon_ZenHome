import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';

void showHomeSwitcherBottomSheet(BuildContext context, WidgetRef ref) {
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  
  List<SmartConfig> allHomes = ref.read(homeConfigProvider).availableHomes;
  final activeConfig = ref.read(homeConfigProvider).activeConfig;
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return FutureBuilder<Map<String, bool>>(
        future: _checkDisabledStatus(allHomes),
        builder: (context, snapshot) {
          final disabledMap = snapshot.data ?? {};
          return Container(
            padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121827) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  context.tr('switch_home') ?? 'Chuyển đổi nhà',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 25),
                if (allHomes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      context.tr('no_home_to_switch') ?? 'Không có nhà nào khác',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else
                  ...allHomes.map((home) {
                    bool isSelected = home.userId == activeConfig.userId;
                    bool isHomeDisabled = disabledMap[home.userId] == true;
                    
                    return GestureDetector(
                      onTap: () async {
                        if (isHomeDisabled) {
                          showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('status_disabled') ?? 'Bị vô hiệu hóa tạm thời', isError: true);
                          return;
                        }
                        Navigator.pop(sheetContext);
                        if (!isSelected) {
                          LoadingOverlay.show(context);
                          
                          if (context.mounted) {
                            try {
                              await ref.read(homeConfigProvider).switchActiveHome(home.userId).timeout(const Duration(seconds: 5));
                              await Future.delayed(const Duration(milliseconds: 400));
                              await LoadingOverlay.hideSuccess();
                            } catch (e) {
                              await LoadingOverlay.hideError();
                              if (context.mounted) {
                                showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_switch_home_failed') ?? 'Không thể chuyển nhà:'} $e', isError: true);
                              }
                            }
                          } else {
                            LoadingOverlay.hide();
                          }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2A3A7C).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? const Color(0xFF2A3A7C) : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.home_work_rounded, color: isSelected ? const Color(0xFF2A3A7C) : Colors.grey, size: 28),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    home.homeName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF2A3A7C) : (isDark ? Colors.white : Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (snapshot.connectionState == ConnectionState.waiting)
                                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
                                  else
                                    Text(
                                      isHomeDisabled ? (context.tr('status_disabled') ?? 'Bị vô hiệu hóa tạm thời') : (context.tr('status_normal') ?? 'Bình thường'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isHomeDisabled ? Colors.red : Colors.green,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF2A3A7C)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        }
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
