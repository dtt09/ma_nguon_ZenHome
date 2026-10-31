import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

  /// Xác định dải màu ánh sáng thông minh tùy theo loại thiết bị
  LinearGradient _getDeviceGradient(bool isDark) {
    // 1. Nhóm đèn / chiếu sáng: Sắc vàng cam ấm cúng (Warm Amber / Sun Gold)
    if (icon == Icons.lightbulb_rounded || icon == Icons.lightbulb_outline || icon == Icons.highlight || icon == Icons.tungsten) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 2. Nhóm đèn ngủ / thư giãn ban đêm: Tím oải hương / Indigo huyền ảo
    if (icon == Icons.bedtime_rounded || icon == Icons.nightlight_round || icon == Icons.nights_stay || icon == Icons.bed_rounded) {
      return const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 3. Nhóm quạt / điều hòa / làm mát: Xanh băng thanh khiết (Cool Cyan / Azure)
    if (icon == Icons.mode_fan_off || icon == Icons.air_rounded || icon == Icons.wind_power || icon == Icons.toys_outlined) {
      return const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 4. Nhóm nước / bình nóng lạnh / máy bơm: Xanh biển sâu (Ocean Sapphire)
    if (icon == Icons.water_drop || icon == Icons.waves || icon == Icons.hot_tub_rounded || icon == Icons.opacity) {
      return const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 5. Nhóm ổ cắm / công tắc / nguồn điện: Xanh ngọc lục bảo (Emerald Energy)
    if (icon == Icons.power_rounded || icon == Icons.outlet_rounded || icon == Icons.bolt_rounded) {
      return const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 6. Nhóm TV / Âm thanh / Giải trí: San hô rực rỡ (Neon Coral / Rose)
    if (icon == Icons.tv_rounded || icon == Icons.speaker_rounded || icon == Icons.music_note || icon == Icons.sports_esports) {
      return const LinearGradient(
        colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 7. Mặc định: Xanh chàm công nghệ (Cyber Indigo)
    return const LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _getGlowColor() {
    if (icon == Icons.lightbulb_rounded || icon == Icons.lightbulb_outline || icon == Icons.highlight || icon == Icons.tungsten) {
      return const Color(0xFFF59E0B);
    }
    if (icon == Icons.bedtime_rounded || icon == Icons.nightlight_round || icon == Icons.nights_stay || icon == Icons.bed_rounded) {
      return const Color(0xFF8B5CF6);
    }
    if (icon == Icons.mode_fan_off || icon == Icons.air_rounded || icon == Icons.wind_power || icon == Icons.toys_outlined) {
      return const Color(0xFF06B6D4);
    }
    if (icon == Icons.water_drop || icon == Icons.waves || icon == Icons.hot_tub_rounded || icon == Icons.opacity) {
      return const Color(0xFF0EA5E9);
    }
    if (icon == Icons.power_rounded || icon == Icons.outlet_rounded || icon == Icons.bolt_rounded) {
      return const Color(0xFF10B981);
    }
    if (icon == Icons.tv_rounded || icon == Icons.speaker_rounded || icon == Icons.music_note || icon == Icons.sports_esports) {
      return const Color(0xFFF43F5E);
    }
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final LinearGradient activeGradient = _getDeviceGradient(isDark);
    final Color glowColor = _getGlowColor();

    // Box Decoration theo phong cách Neumorphic & Frosted Glass cao cấp
    final BoxDecoration decoration = isOn
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: activeGradient,
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isDark ? 0.48 : 0.38),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            border: Border.all(
              color: isDark ? glowColor.withOpacity(0.18) : glowColor.withOpacity(0.14),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(isDark ? 0.08 : 0.04),
                blurRadius: 14,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          );

    final Color primaryTextColor = isOn
        ? Colors.white
        : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A));

    final Color secondaryTextColor = isOn
        ? Colors.white.withOpacity(0.85)
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    final Color iconColor = isOn
        ? Colors.white
        : (isDark ? glowColor.withOpacity(0.9) : glowColor);

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header hàng trên: Icon tròn + Mini Switch Capsule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon hộp tròn với hiệu ứng nổi Animate UI và màu nhận diện loại thiết bị
                Builder(
                  builder: (context) {
                    Widget iconChild = Icon(
                      icon,
                      size: 28,
                      color: iconColor,
                    );

                    // Hiệu ứng quay động cơ Animate UI khi bật quạt / làm mát
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
                            end: const Offset(1.12, 1.12),
                            duration: 280.ms,
                            curve: Curves.easeOutBack,
                          );
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOn
                            ? Colors.white.withOpacity(0.24)
                            : glowColor.withOpacity(isDark ? 0.16 : 0.09),
                        shape: BoxShape.circle,
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.2),
                                  blurRadius: 8,
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
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade800
                    ),
                  )
                else if (isCooldown)
                  LogoLoadingIndicator(color: primaryTextColor, size: 22)
                else
                  // Capsule switch toggle Animate UI với lò xo easeOutBack
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 38,
                    height: 22,
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isOn
                          ? Colors.white.withOpacity(0.3)
                          : (isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFCBD5E1)),
                      border: isOn ? null : Border.all(color: glowColor.withOpacity(0.25), width: 1),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutBack,
                      alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 17,
                        height: 17,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
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

            const Spacer(),

            // Footer hàng dưới: Tên thiết bị + Room badge + Trạng thái chữ
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
                // Tên thiết bị chính
                Text(
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
                const SizedBox(height: 5),
                // Trạng thái BẬT / TẮT với chấm đèn phát quang
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: isOn ? 8 : 6,
                      height: isOn ? 8 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn
                            ? (icon == Icons.lightbulb_rounded ? Colors.amberAccent : Colors.lightGreenAccent)
                            : (isDark ? Colors.white30 : Colors.black26),
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                  color: (icon == Icons.lightbulb_rounded ? Colors.amberAccent : Colors.lightGreenAccent)
                                      .withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isOn ? FontWeight.w700 : FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                      child: Text(
                        isOn ? context.tr('status_on') : context.tr('status_off'),
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
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: isCooldown ? null : onLongPress,
      scaleFactor: 0.96,
      child: card,
    );
  }
}
