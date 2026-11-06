import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

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

  /// Màu sắc nhận diện và phát quang Luminescent theo loại thiết bị
  Color _getGlowColor() {
    // 1. Nhóm đèn / chiếu sáng: Sắc vàng cam ấm cúng (Warm Amber / Sun Gold)
    if (icon == Icons.lightbulb_rounded || icon == Icons.lightbulb_outline || icon == Icons.highlight || icon == Icons.tungsten) {
      return AppColors.amberGlow;
    }
    // 2. Nhóm đèn ngủ / thư giãn ban đêm: Tím oải hương / Twilight
    if (icon == Icons.bedtime_rounded || icon == Icons.nightlight_round || icon == Icons.nights_stay || icon == Icons.bed_rounded) {
      return AppColors.purpleGlow;
    }
    // 3. Nhóm quạt / điều hòa / làm mát: Xanh băng thanh khiết (Cool Glacier Cyan)
    if (icon == Icons.mode_fan_off || icon == Icons.air_rounded || icon == Icons.wind_power || icon == Icons.toys_outlined) {
      return AppColors.cyanGlow;
    }
    // 4. Nhóm nước / bình nóng lạnh / máy bơm: Xanh biển sâu (Ocean Sapphire)
    if (icon == Icons.water_drop || icon == Icons.waves || icon == Icons.hot_tub_rounded || icon == Icons.opacity) {
      return const Color(0xFF0EA5E9);
    }
    // 5. Nhóm ổ cắm / công tắc / nguồn điện: Xanh ngọc lục bảo (Emerald Energy)
    if (icon == Icons.power_rounded || icon == Icons.outlet_rounded || icon == Icons.bolt_rounded) {
      return AppColors.emeraldGlow;
    }
    // 6. Nhóm TV / Âm thanh / Giải trí: San hô rực rỡ (Neon Coral / Rose)
    if (icon == Icons.tv_rounded || icon == Icons.speaker_rounded || icon == Icons.music_note || icon == Icons.sports_esports) {
      return AppColors.roseGlow;
    }
    // 7. Mặc định: Xanh chàm công nghệ (Cyber Indigo)
    return AppColors.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color glowColor = _getGlowColor();

    // Box Decoration theo phong cách Zen Luxury Luminescent cao cấp
    final BoxDecoration decoration = isOn
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      glowColor.withOpacity(0.18),
                      const Color(0xFF0F1626),
                      const Color(0xFF0F1626),
                    ]
                  : [
                      glowColor.withOpacity(0.10),
                      Colors.white,
                      Colors.white,
                    ],
              stops: const [0.0, 0.45, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: glowColor.withOpacity(isDark ? 0.55 : 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isDark ? 0.22 : 0.12),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
              if (isDark)
                BoxShadow(
                  color: glowColor.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 0),
                ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          );

    final Color primaryTextColor = isDark ? AppColors.darkText : AppColors.lightText;
    final Color secondaryTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final Color iconColor = isOn
        ? (isDark ? Colors.white : glowColor)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header hàng trên: Icon tròn + Mini Switch Capsule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon tròn với hào quang phát quang Luminescent
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
                      iconChild = iconChild
                          .animate(target: isOn ? 1 : 0)
                          .scale(
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
                            ? glowColor.withOpacity(isDark ? 0.24 : 0.16)
                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
                        shape: BoxShape.circle,
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                  color: glowColor.withOpacity(0.25),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: iconChild,
                    );
                  },
                ),

                // Trạng thái / Đang xử lý
                if (isRestricted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber.withOpacity(0.18) : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lock_rounded, 
                      size: 14, 
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                    ),
                  )
                else if (isCooldown)
                  LogoLoadingIndicator(color: primaryTextColor, size: 22)
                else
                  // Capsule switch toggle Animate UI mượt mà
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    width: 40,
                    height: 24,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isOn
                          ? glowColor
                          : (isDark ? Colors.white.withOpacity(0.14) : const Color(0xFFCBD5E1)),
                      boxShadow: isOn
                          ? [
                              BoxShadow(
                                color: glowColor.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Flexible spacing an toàn tuyệt đối chống tràn RenderFlex
            const Expanded(
              child: SizedBox(height: 8),
            ),

            // Footer hàng dưới: Tên phòng + Tên thiết bị + Trạng thái chữ
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tên phòng nhỏ
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
                // Tên thiết bị chính với FittedBox co giãn chống tràn chữ
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    deviceName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                // Trạng thái BẬT / TẮT với chấm đèn phát quang
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
                                  color: glowColor.withOpacity(0.6),
                                  blurRadius: 6,
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
                          isOn ? context.tr('status_on') : context.tr('status_off'),
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
      ),
    );

    return BouncingButton(
      onTap: isCooldown ? null : () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      onLongPress: isCooldown ? null : onLongPress,
      scaleFactor: 0.96,
      child: card,
    );
  }
}
