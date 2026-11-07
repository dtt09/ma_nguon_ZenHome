import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/setup/logic/wifi_provisioning_service.dart';

/// Modal bottom sheet Kính Lỏng Quang Học 2.0 hiển thị danh sách sóng Wi-Fi khả dụng
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
    return showZenGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      maxHeightFactor: 0.72,
      showHandle: true,
      builder: (ctx) => WifiPickerBottomSheet(
        wifiList: wifiList,
        onWifiSelected: onWifiSelected,
      ),
    );
  }

  Color _signalColor(int rssi) {
    if (rssi >= -60) return AppColors.emeraldGlow;
    if (rssi >= -72) return AppColors.cyanGlow;
    return AppColors.amberGlow;
  }

  IconData _signalIcon(int rssi) {
    if (rssi >= -60) return Icons.wifi_rounded;
    if (rssi >= -72) return Icons.wifi_2_bar_rounded;
    return Icons.wifi_1_bar_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('wifi_select_home_wifi_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Băng tần hỗ trợ: 2.4GHz (${wifiList.length} mạng khả dụng)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                ZenGlassIconButton(
                  icon: Icons.close_rounded,
                  size: 34,
                  iconSize: 18,
                  blurSigma: 0,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: wifiList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final ap = wifiList[i];
                  final Color sigColor = _signalColor(ap.level);
                  final IconData sigIcon = _signalIcon(ap.level);

                  return ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    surfaceColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white.withOpacity(0.66),
                    glowColor: ap.level >= -60 ? sigColor : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onWifiSelected(ap.ssid);
                      Navigator.pop(context);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: sigColor.withOpacity(isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(sigIcon, color: sigColor, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ap.ssid,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                WifiProvisioningService.getSignalQuality(ap.level),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ZenGlassPill(
                          blurSigma: 0,
                          isSelected: true,
                          glowColor: sigColor,
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          child: Text(
                            '${ap.level} dBm',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: sigColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ],
                    ),
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
