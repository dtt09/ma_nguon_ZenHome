import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

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
    if (lower == 'all') {
      return Icons.grid_view_rounded;
    }
    if (lower.contains('khach') ||
        lower.contains('living') ||
        lower.contains('room_1')) {
      return Icons.weekend_rounded;
    }
    if (lower.contains('ngu') ||
        lower.contains('bed') ||
        lower.contains('room_2')) {
      return Icons.bed_rounded;
    }
    if (lower.contains('bep') ||
        lower.contains('kitchen') ||
        lower.contains('room_3')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('cong') ||
        lower.contains('balcony') ||
        lower.contains('san') ||
        lower.contains('room_4')) {
      return Icons.balcony_rounded;
    }
    if (lower.contains('lam_viec') ||
        lower.contains('work') ||
        lower.contains('office') ||
        lower.contains('room_5')) {
      return Icons.desk_rounded;
    }
    if (lower.contains('tam') ||
        lower.contains('bath') ||
        lower.contains('room_6')) {
      return Icons.bathtub_rounded;
    }
    if (lower.contains('an') ||
        lower.contains('dining') ||
        lower.contains('room_7')) {
      return Icons.dinner_dining_rounded;
    }
    if (lower.contains('tho') ||
        lower.contains('altar') ||
        lower.contains('room_8')) {
      return Icons.temple_buddhist_rounded;
    }
    if (lower.contains('thuong') ||
        lower.contains('terrace') ||
        lower.contains('room_9')) {
      return Icons.roofing_rounded;
    }
    if (lower.contains('hanh_lang') ||
        lower.contains('stairs') ||
        lower.contains('cau_thang') ||
        lower.contains('room_10')) {
      return Icons.stairs_rounded;
    }
    if (lower.contains('gara') ||
        lower.contains('garage') ||
        lower.contains('xe') ||
        lower.contains('room_11')) {
      return Icons.garage_rounded;
    }
    return Icons.meeting_room_rounded;
  }

  LinearGradient _getRoomGradient(BuildContext context, String code) {
    final lower = code.toLowerCase();
    if (lower.contains('khach') || lower.contains('living')) {
      return const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('ngu') || lower.contains('bed')) {
      return const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('bep') || lower.contains('kitchen')) {
      return const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFE11D48)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('tam') || lower.contains('bath')) {
      return const LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('cong') ||
        lower.contains('balcony') ||
        lower.contains('san')) {
      return const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (lower.contains('lam_viec') ||
        lower.contains('work') ||
        lower.contains('office')) {
      return const LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return context.zenColors.brandHero;
  }

  Color _getRoomGlow(BuildContext context, String code) {
    final lower = code.toLowerCase();
    if (lower.contains('khach') || lower.contains('living')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('ngu') || lower.contains('bed')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('bep') || lower.contains('kitchen')) {
      return const Color(0xFFF97316);
    }
    if (lower.contains('tam') || lower.contains('bath')) {
      return const Color(0xFF06B6D4);
    }
    if (lower.contains('cong') ||
        lower.contains('balcony') ||
        lower.contains('san')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('lam_viec') ||
        lower.contains('work') ||
        lower.contains('office')) {
      return const Color(0xFF3B82F6);
    }
    return context.zenColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final IconData roomIcon = _getRoomIcon(roomCode);
    final LinearGradient roomGradient = _getRoomGradient(context, roomCode);
    final Color roomColor = _getRoomGlow(context, roomCode);

    return RepaintBoundary(
      child: BouncingButton(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        scaleFactor: 0.94,
        child: ZenGlassPill(
          isSelected: isSelected,
          glowColor: roomColor,
          blurSigma: 0, // Tối ưu GPU 120 FPS: 0 blur cục bộ, giữ nguyên viền quang học 3D và gradient
          customGradient: isSelected ? roomGradient : null,
          borderRadius: 22,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutBack,
                child: Icon(
                  roomIcon,
                  size: 17,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? roomColor.withOpacity(0.92) : roomColor),
                ),
              ),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.darkText : AppColors.lightText),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
                child: Text(context.tr(roomCode)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
