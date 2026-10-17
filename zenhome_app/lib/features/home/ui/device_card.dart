import 'dart:ui';
import 'package:flutter/material.dart';
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
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.deviceName,
    required this.roomName,
    required this.icon,
    required this.isOn,
    this.isCooldown = false,
    required this.onTap,
  });

  /// Xác định dải màu ánh sáng thông minh tùy theo loại thiết bị
  LinearGradient _getDeviceGradient(bool isDark) {
    // 1. Nhóm đèn / chiếu sáng: Sắc vàng cam ấm cúng (Warm Amber)
    if (icon == Icons.lightbulb_rounded || icon == Icons.bedtime_rounded || icon == Icons.lightbulb_outline) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 2. Nhóm quạt / điều hòa: Sắc xanh băng thanh mát (Cool Cyan / Azure)
    if (icon == Icons.mode_fan_off || icon == Icons.air_rounded || icon == Icons.wind_power) {
      return const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 3. Nhóm nước / bình nóng lạnh: Xanh biển sâu (Ocean Sapphire)
    if (icon == Icons.water_drop || icon == Icons.waves) {
      return const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    // 4. Mặc định: Sắc xanh tím tương lai (Cyber Sapphire)
    return isDark
        ? const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }

  Color _getGlowColor() {
    if (icon == Icons.lightbulb_rounded || icon == Icons.bedtime_rounded) {
      return const Color(0xFFF59E0B);
    }
    if (icon == Icons.mode_fan_off) {
      return const Color(0xFF06B6D4);
    }
    return const Color(0xFF3B82F6);
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
                color: glowColor.withOpacity(isDark ? 0.45 : 0.35),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withOpacity(0.25) : const Color(0xFF0F172A).withOpacity(0.04),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
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
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569));

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
                // Icon hộp tròn với hiệu ứng nổi
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOn
                        ? Colors.white.withOpacity(0.22)
                        : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: iconColor,
                  )
                      .animate(target: isOn ? 1 : 0)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.08, 1.08), duration: 250.ms),
                ),

                // Trạng thái / Đang xử lý
                if (isCooldown)
                  LogoLoadingIndicator(color: primaryTextColor, size: 22)
                else
                  // Capsule switch toggle sang trọng
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
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 250),
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
                // Trạng thái BẬT / TẮT
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn
                            ? (icon == Icons.lightbulb_rounded ? Colors.amberAccent : Colors.lightGreenAccent)
                            : (isDark ? Colors.white30 : Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOn ? context.tr('status_on') : context.tr('status_off'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
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
      onTap: isCooldown ? null : onTap,
      scaleFactor: 0.96,
      child: card,
    );
  }
}