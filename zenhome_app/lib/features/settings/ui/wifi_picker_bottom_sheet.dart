import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/setup/logic/wifi_provisioning_service.dart';

/// Modal bottom sheet hiển thị danh sách sóng Wi-Fi khả dụng để người dùng chọn nhanh
class WifiPickerBottomSheet extends StatelessWidget {
  final List<WiFiAccessPoint> wifiList;
  final ValueChanged<String> onWifiSelected;

  const WifiPickerBottomSheet({
    super.key,
    required this.wifiList,
    required this.onWifiSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<WiFiAccessPoint> wifiList,
    required ValueChanged<String> onWifiSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WifiPickerBottomSheet(
        wifiList: wifiList,
        onWifiSelected: onWifiSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.wifi_rounded, color: Color(0xFF0F766E)),
                const SizedBox(width: 10),
                Text(
                  context.tr('wifi_select_home_wifi_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: wifiList.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final ap = wifiList[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Icon(
                      ap.level >= -65 ? Icons.wifi : Icons.wifi_2_bar_rounded,
                      color: ap.level >= -65 ? const Color(0xFF10B981) : Colors.amber,
                    ),
                    title: Text(ap.ssid, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      '${WifiProvisioningService.getSignalQuality(ap.level)} (${ap.level} dBm)',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      onWifiSelected(ap.ssid);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
