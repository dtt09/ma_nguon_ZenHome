import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

String getDisplayEmailOrPhone(User? user) {
  if (user == null) return '';

  // 1. Ưu tiên hiển thị Gmail đã liên kết với Google
  String displayEmail = getDisplayEmail(user);
  if (displayEmail.isNotEmpty) {
    return displayEmail;
  }

  // 2. Nếu có SĐT thực
  if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
    return user.phoneNumber!;
  }

  // 3. Fallback từ email ảo của hệ thống SĐT
  if (user.email != null && user.email!.endsWith('@zenhome.local')) {
    String p = user.email!.replaceAll('@zenhome.local', '');
    return p.startsWith('+') ? p : '+$p';
  }

  return '';
}

String getDisplayEmail(User? user) {
  if (user == null) return '';

  // Chỉ lấy email khi có liên kết Google
  UserInfo? googleProvider;
  for (var p in user.providerData) {
    if (p.providerId == 'google.com') {
      googleProvider = p;
      break;
    }
  }
  if (googleProvider == null) return '';

  final email = googleProvider.email ?? user.email;
  if (email == null || email.isEmpty) return '';

  // Chỉ hiển thị nếu đúng đuôi @gmail.com
  if (!email.toLowerCase().endsWith('@gmail.com')) return '';

  return email;
}

List<String> getDynamicDeviceTopicsList(SmartConfig config) {
  return config.devices.map((dev) {
    return '${config.mqttPrefix}/${dev.room}/${dev.id}';
  }).toList();
}

List<String> getSortedDeviceTopicsList(BuildContext context, SmartConfig config) {
  List<DeviceConfig> sortedDevices = List.from(config.devices);
  sortedDevices.sort((a, b) {
    int roomCompare = context.tr(a.room).compareTo(context.tr(b.room));
    if (roomCompare != 0) return roomCompare;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return sortedDevices.map((dev) {
    return '${config.mqttPrefix}/${dev.room}/${dev.id}';
  }).toList();
}

String getDeviceNameHelper(
  BuildContext context,
  String baseTopic,
  SmartConfig config,
) {
  try {
    final parts = baseTopic.split('/');
    final devId = parts.last;
    final device = config.devices.firstWhere((dev) => dev.id == devId);
    return '${device.name} (${context.tr(device.room)})';
  } catch (e) {
    final parts = baseTopic.split('/');
    if (parts.isNotEmpty && parts.last.isNotEmpty) {
      final devId = parts.last;
      return devId.replaceAll('_', ' ').toUpperCase();
    }
    return context.tr('device');
  }
}

void showAlertDialogHelper(
  BuildContext context,
  String title,
  String message, {
  bool isError = false,
}) {
  if (isError) {
    HapticHelper.errorVibrate();
  } else {
    HapticHelper.light();
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;
  final accent = isError ? zen.danger : zen.success;

  showZenGlassDialog(
    context: context,
    accentColor: accent,
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withOpacity(0.15),
              border: Border.all(color: accent.withOpacity(0.4), width: 1.4),
            ),
            child: Icon(
              isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
              color: accent,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ZenGlassButton(
              label: 'OK',
              isDanger: isError,
              accentColor: isError ? zen.danger : zen.primary,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
      );
    },
  );
}

class PickerItem {
  final String value;
  final String label;
  PickerItem(this.value, this.label);
}

void showCustomBottomSheetPicker({
  required BuildContext context,
  required String title,
  required List<PickerItem> items,
  required String currentValue,
  required Function(String) onSelected,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;

  showZenGlassBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 18),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.58,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: items.map((item) {
                      final bool isSelected = item.value == currentValue;
                      return ZenGlassCard(
                        blurSigma: 0,
                        isActive: isSelected,
                        glowColor: zen.primary,
                        borderRadius: 18,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(ctx);
                          onSelected(item.value);
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? zen.primaryAccent : zen.primary)
                                      : (isDark
                                          ? AppColors.darkText
                                          : AppColors.lightText),
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: isDark ? zen.primaryAccent : zen.primary,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showCustomMultiSelectBottomSheetPicker({
  required BuildContext context,
  required String title,
  required List<PickerItem> items,
  required List<String> currentValues,
  required Function(List<String>) onSelected,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final zen = context.zenColors;
  final List<String> selectedValues = List.from(currentValues);

  showZenGlassBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.52,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) {
                          final bool isSelected =
                              selectedValues.contains(item.value);
                          return ZenGlassCard(
                            blurSigma: 0,
                            isActive: isSelected,
                            glowColor: zen.primary,
                            borderRadius: 18,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() {
                                if (isSelected) {
                                  selectedValues.remove(item.value);
                                } else {
                                  selectedValues.add(item.value);
                                }
                              });
                            },
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? (isDark
                                              ? zen.primaryAccent
                                              : zen.primary)
                                          : (isDark
                                              ? AppColors.darkText
                                              : AppColors.lightText),
                                    ),
                                  ),
                                ),
                                Checkbox(
                                  value: isSelected,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    setModalState(() {
                                      if (val == true) {
                                        selectedValues.add(item.value);
                                      } else {
                                        selectedValues.remove(item.value);
                                      }
                                    });
                                  },
                                  activeColor: zen.primary,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ZenGlassButton(
                      label: 'OK',
                      icon: Icons.check_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        onSelected(selectedValues);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
