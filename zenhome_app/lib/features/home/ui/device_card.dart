import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class DeviceCard extends StatelessWidget {
  final String deviceName;
  final String roomName;
  final IconData icon;
  final bool isOn;
  final bool isCooldown;
  final bool isRestricted;
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

    final Color primaryTextColor =
        isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondaryTextColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final Color iconColor = isOn
        ? (isDark ? Colors.white : glowColor)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    final Widget card = ZenGlassCard(
      borderRadius: 26,
      isActive: isOn,
      glowColor: glowColor,
      blurSigma: 15.0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  Widget iconChild = Icon(
                    icon,
                    size: 26,
                    color: iconColor,
                  );

                  final bool isFan = icon == Icons.mode_fan_off ||
                      icon == Icons.air_rounded ||
                      icon == Icons.wind_power ||
                      icon == Icons.toys_outlined;

                  if (isFan && isOn) {
                    iconChild = iconChild
                        .animate(onPlay: (c) => c.repeat())
                        .rotate(duration: 1200.ms, curve: Curves.linear);
                  } else {
                    iconChild = iconChild.animate(target: isOn ? 1 : 0).scale(
                          begin: const Offset(0.92, 0.92),
                          end: const Offset(1.08, 1.08),
                          duration: 250.ms,
                          curve: Curves.easeOutCubic,
                        );
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: isOn
                          ? glowColor.withOpacity(isDark ? 0.26 : 0.16)
                          : (isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.white.withOpacity(0.65)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOn
                            ? glowColor.withOpacity(isDark ? 0.55 : 0.35)
                            : (isDark
                                ? Colors.white.withOpacity(0.14)
                                : const Color(0xFFCBD5E1).withOpacity(0.75)),
                        width: 1.1,
                      ),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: glowColor.withOpacity(0.32),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: iconChild,
                  );
                },
              ),
              if (isRestricted)
                ZenGlassPill(
                  blurSigma: 0,
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
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  width: 42,
                  height: 24,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isOn
                        ? glowColor
                        : (isDark
                            ? Colors.white.withOpacity(0.14)
                            : const Color(0xFFCBD5E1).withOpacity(0.75)),
                    border: Border.all(
                      color: isOn
                          ? Colors.white.withOpacity(0.35)
                          : Colors.white.withOpacity(isDark ? 0.12 : 0.7),
                      width: 0.9,
                    ),
                    boxShadow: isOn
                        ? [
                            BoxShadow(
                              color: glowColor.withOpacity(0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment:
                        isOn ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 18.5,
                      height: 18.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.22),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Expanded(child: SizedBox(height: 8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                roomName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: primaryTextColor,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: isOn ? 8 : 6,
                    height: isOn ? 8 : 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOn
                          ? glowColor
                          : (isDark ? Colors.white30 : Colors.black26),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: glowColor.withOpacity(0.65),
                                blurRadius: 7,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isOn ? FontWeight.w700 : FontWeight.w600,
                        color: isOn
                            ? (isDark ? glowColor : AppColors.lightText)
                            : secondaryTextColor,
                      ),
                      child: Text(
                        isOn
                            ? context.tr('status_on')
                            : context.tr('status_off'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
      scaleFactor: 0.96,
      child: card,
    );
  }
}
