import 'package:flutter/material.dart';

import 'package:flutter/services.dart';


import 'package:zenhome_app/core/widgets/bouncing_button.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
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

    if (lower.contains('khach') || lower.contains('living') || lower.contains('room_1')) {

      return Icons.weekend_rounded;

    }

    if (lower.contains('ngu') || lower.contains('bed') || lower.contains('room_2')) {

      return Icons.bed_rounded;

    }

    if (lower.contains('bep') || lower.contains('kitchen') || lower.contains('room_3')) {

      return Icons.restaurant_rounded;

    }

    if (lower.contains('cong') || lower.contains('balcony') || lower.contains('san') || lower.contains('room_4')) {

      return Icons.balcony_rounded;

    }

    if (lower.contains('lam_viec') || lower.contains('work') || lower.contains('office') || lower.contains('room_5')) {

      return Icons.desk_rounded;

    }

    if (lower.contains('tam') || lower.contains('bath') || lower.contains('room_6')) {

      return Icons.bathtub_rounded;

    }

    if (lower.contains('an') || lower.contains('dining') || lower.contains('room_7')) {

      return Icons.dinner_dining_rounded;

    }

    if (lower.contains('tho') || lower.contains('altar') || lower.contains('room_8')) {

      return Icons.temple_buddhist_rounded;

    }

    if (lower.contains('thuong') || lower.contains('terrace') || lower.contains('room_9')) {

      return Icons.roofing_rounded;

    }

    if (lower.contains('hanh_lang') || lower.contains('stairs') || lower.contains('cau_thang') || lower.contains('room_10')) {

      return Icons.stairs_rounded;

    }

    if (lower.contains('gara') || lower.contains('garage') || lower.contains('xe') || lower.contains('room_11')) {

      return Icons.garage_rounded;

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

      onTap: () {

        HapticFeedback.lightImpact();

        onTap();

      },

      scaleFactor: 0.93,

      child: ZenGlassPill(
        isSelected: isSelected,
        glowColor: roomColor,
        customGradient: isSelected ? roomGradient : null,
        borderRadius: 22,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            AnimatedScale(

              scale: isSelected ? 1.15 : 1.0,

              duration: const Duration(milliseconds: 250),

              curve: Curves.easeOutBack,

              child: Icon(

                roomIcon,

                size: 17,

                color: isSelected

                    ? Colors.white

                    : (isDark ? roomColor.withOpacity(0.9) : roomColor),

              ),

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

