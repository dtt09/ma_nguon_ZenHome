import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

/// Builds only visible rows, letting the tallest device name set each row's height.
class SliverDeviceGrid extends StatelessWidget {
  const SliverDeviceGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    final minWidth = 56 + 6 * MediaQuery.textScalerOf(context).scale(16);
    const gap = 12.0;
    int? previousColumns;
    Widget? rows;
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.crossAxisExtent + gap) ~/ (minWidth + gap)).clamp(1, 4);
        // Scrolling also changes sliver constraints. Reuse the delegate until
        // layout columns or the device inputs change.
        if (columns == previousColumns) return rows!;
        previousColumns = columns;
        final rowCount = (itemCount + columns - 1) ~/ columns;
        return rows = SliverList.builder(
          itemCount: rowCount,
          itemBuilder: (context, row) => Padding(
            padding: EdgeInsets.only(bottom: row + 1 < rowCount ? gap : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: gap),
                  Expanded(
                    child: row * columns + column < itemCount
                        ? itemBuilder(context, row * columns + column)
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class DeviceCard extends StatelessWidget {
  final String deviceName;
  final String roomName;
  final IconData icon;
  final bool isOn;
  final bool isCooldown;
  final bool isRestricted;
  final bool showRoomName;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.roomName,
    required this.icon,
    required this.isOn,
    this.isCooldown = false,
    this.isRestricted = false,
    this.showRoomName = true,
    required this.onTap,
    this.onLongPress,
  });

  Color _getGlowColor(BuildContext context) {
    if (icon == Icons.lightbulb_rounded ||
        icon == Icons.lightbulb_outline ||
        icon == Icons.highlight ||
        icon == Icons.tungsten) {
      return AppColors.amberGlow;
    }
    if (icon == Icons.bedtime_rounded ||
        icon == Icons.nightlight_round ||
        icon == Icons.nights_stay ||
        icon == Icons.bed_rounded) {
      return AppColors.purpleGlow;
    }
    if (icon == Icons.mode_fan_off ||
        icon == Icons.air_rounded ||
        icon == Icons.wind_power ||
        icon == Icons.toys_outlined) {
      return AppColors.cyanGlow;
    }
    if (icon == Icons.water_drop ||
        icon == Icons.waves ||
        icon == Icons.hot_tub_rounded ||
        icon == Icons.opacity) {
      return const Color(0xFF0EA5E9);
    }
    if (icon == Icons.power_rounded ||
        icon == Icons.outlet_rounded ||
        icon == Icons.bolt_rounded) {
      return AppColors.emeraldGlow;
    }
    if (icon == Icons.tv_rounded ||
        icon == Icons.speaker_rounded ||
        icon == Icons.music_note ||
        icon == Icons.sports_esports) {
      return AppColors.roseGlow;
    }
    return context.zenColors.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color glowColor = _getGlowColor(context);
    final switchDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    final Color primaryTextColor =
        isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondaryTextColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final Color iconColor = isOn
        ? (isDark ? Colors.white : Color.lerp(glowColor, AppColors.lightText, 0.35)!)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    final Widget card = ZenGlassCard.lightweight(
      borderRadius: 26,
      isActive: isOn,
      glowColor: glowColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(11.8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn
                      ? glowColor.withValues(alpha: isDark ? 0.18 : 0.13)
                      : Colors.white.withValues(alpha: isDark ? 0.07 : 0.54),
                ),
                child: Icon(icon, size: 26, color: iconColor),
              ),
              if (isRestricted)
                ZenGlassPill.lightweight(
                  isSelected: true,
                  glowColor: context.zenColors.warning,
                  borderRadius: 12,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 14,
                    color: context.zenColors.warning,
                  ),
                )
              else if (isCooldown)
                LogoLoadingIndicator(color: primaryTextColor, size: 22)
              else
                AnimatedContainer(
                  duration: switchDuration,
                  curve: Curves.easeOutCubic,
                  width: 42,
                  height: 24,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isOn
                        ? glowColor
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : const Color(0xFFCBD5E1).withValues(alpha: 0.72)),
                    border: Border.all(
                      color: isOn
                          ? glowColor.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
                      width: 0.8,
                    ),
                  ),
                  child: AnimatedAlign(
                    duration: switchDuration,
                    curve: Curves.easeOutCubic,
                    alignment:
                        isOn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 18.5,
                      height: 18.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showRoomName) ...[
                Text(
                  roomName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              Text(
                deviceName,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isOn ? 8 : 6,
                    height: isOn ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn
                          ? glowColor
                          : (isDark ? Colors.white30 : Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isOn ? context.tr('status_on') : context.tr('status_off'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isOn ? FontWeight.w700 : FontWeight.w600,
                        color: isOn
                            ? (isDark ? glowColor : AppColors.lightText)
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return BouncingButton(
      onTap: isCooldown
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onTap();
            },
      onLongPress: isCooldown ? null : onLongPress,
      scaleFactor: 0.985,
      child: card,
    );
  }
}
