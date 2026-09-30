import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C)) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05))),
          boxShadow: isSelected ? [BoxShadow(color: (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C)).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Center(
          child: Text(
            context.tr(roomCode), 
            style: TextStyle(
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
