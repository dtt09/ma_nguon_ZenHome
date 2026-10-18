import 'package:flutter/material.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

class RoomTabWidget extends StatelessWidget {
  final String roomCode;
  final bool isSelected;
  final VoidCallback onTap;

  const RoomTabWidget({
    super.key,
    required this.roomCode,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getRoomIcon(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('khach') || lower.contains('living')) {
      return Icons.weekend_rounded;
    }
    if (lower.contains('ngu') || lower.contains('bed')) {
      return Icons.bed_rounded;
    }
    if (lower.contains('bep') || lower.contains('kitchen')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('tam') || lower.contains('bath')) {
      return Icons.bathtub_rounded;
    }
    if (lower.contains('cong') || lower.contains('balcony') || lower.contains('san')) {
      return Icons.balcony_rounded;
    }
    if (lower.contains('lam_viec') || lower.contains('work') || lower.contains('office')) {
      return Icons.desk_rounded;
    }
    return Icons.meeting_room_rounded;
  }

  LinearGradient _getRoomGradient(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('khach') || lower.contains('living')) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)], // Warm Amber / Sunset
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('ngu') || lower.contains('bed')) {
      return const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)], // Lavender / Indigo
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('bep') || lower.contains('kitchen')) {
      return const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFE11D48)], // Warm Coral / Flame
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('tam') || lower.contains('bath')) {
      return const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0284C7)], // Azure / Ocean
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('cong') || lower.contains('balcony') || lower.contains('san')) {
      return const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)], // Emerald Garden
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('lam_viec') || lower.contains('work') || lower.contains('office')) {
      return const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Sapphire
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF0D9488), Color(0xFF0F766E)], // Teal Zen
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Color _getRoomGlow(String code) {
    final lower = code.toLowerCase();
    if (lower.contains('khach') || lower.contains('living')) return const Color(0xFFF59E0B);
    if (lower.contains('ngu') || lower.contains('bed')) return const Color(0xFF8B5CF6);
    if (lower.contains('bep') || lower.contains('kitchen')) return const Color(0xFFF97316);
    if (lower.contains('tam') || lower.contains('bath')) return const Color(0xFF06B6D4);
    if (lower.contains('cong') || lower.contains('balcony') || lower.contains('san')) return const Color(0xFF10B981);
    if (lower.contains('lam_viec') || lower.contains('work') || lower.contains('office')) return const Color(0xFF3B82F6);
    return const Color(0xFF0D9488);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final IconData roomIcon = _getRoomIcon(roomCode);
    final LinearGradient roomGradient = _getRoomGradient(roomCode);
    final Color roomColor = _getRoomGlow(roomCode);

    return BouncingButton(
      onTap: onTap,
      scaleFactor: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: isSelected
            ? BoxDecoration(
                gradient: roomGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: roomColor.withOpacity(0.4),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? roomColor.withOpacity(0.18)
                      : roomColor.withOpacity(0.12),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.15)
                        : const Color(0xFF0F172A).withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              roomIcon,
              size: 17,
              color: isSelected
                  ? Colors.white
                  : (isDark ? roomColor.withOpacity(0.9) : roomColor),
            ),
            const SizedBox(width: 7),
            Text(
              context.tr(roomCode),
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B)),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13.5,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
