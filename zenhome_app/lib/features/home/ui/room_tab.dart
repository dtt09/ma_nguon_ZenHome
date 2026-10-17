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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final IconData roomIcon = _getRoomIcon(roomCode);

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
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.35),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withOpacity(0.12) : const Color(0xFF0F172A).withOpacity(0.03),
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
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
