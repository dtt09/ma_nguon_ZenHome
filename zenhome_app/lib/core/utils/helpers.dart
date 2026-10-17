import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zenhome_app/core/utils/haptic_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/models/smart_config.dart';

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

String getDeviceNameHelper(BuildContext context, String baseTopic, SmartConfig config) {
  try {
    final parts = baseTopic.split('/');
    final devId = parts.last;
    final device = config.devices.firstWhere((dev) => dev.id == devId);
    // Nhờ import constants.dart ở trên nên hàm tr() gọi ở đây hoàn toàn hợp lệ
    return '${device.name} (${context.tr(device.room)})';
  } catch (e) {
    return baseTopic;
  }
}

void showAlertDialogHelper(BuildContext context, String title, String message, {bool isError = false}) {
  if (isError) {
    HapticHelper.errorVibrate();
  }
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle, color: isError ? Colors.red : Colors.green, size: 30),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
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
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 40),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121827) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: items.map((item) {
                    bool isSelected = item.value == currentValue;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(item.value);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F766E).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isSelected ? const Color(0xFF0F766E) : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.label, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFF0F766E) : (isDark ? Colors.white : Colors.black)))),
                            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF0F766E)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
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
  bool isDark = Theme.of(context).brightness == Brightness.dark;
  List<String> selectedValues = List.from(currentValues);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121827) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 25),
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.map((item) {
                        bool isSelected = selectedValues.contains(item.value);
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              if (isSelected) {
                                selectedValues.remove(item.value);
                              } else {
                                selectedValues.add(item.value);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0F766E).withOpacity(0.1) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isSelected ? const Color(0xFF0F766E) : Colors.transparent),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.label, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? const Color(0xFF0F766E) : (isDark ? Colors.white : Colors.black)))),
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setModalState(() {
                                      if (val == true) {
                                        selectedValues.add(item.value);
                                      } else {
                                        selectedValues.remove(item.value);
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF0F766E),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    onPressed: () {
                      Navigator.pop(context);
                      onSelected(selectedValues);
                    },
                    child: Text('OK', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      );
    },
  );
}
