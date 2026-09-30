import 'dart:ui';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    BoxDecoration decoration = isOn 
      ? BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            colors: isDark ? [const Color(0xFF3850A2), const Color(0xFF1E285D)] : [const Color(0xFF6B8AFD), const Color(0xFF4A69D0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? const Color(0xFF3850A2) : const Color(0xFF6B8AFD)).withOpacity(0.35),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 10),
            )
          ],
        )
      : BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.02),
              blurRadius: 16,
              spreadRadius: -5,
              offset: const Offset(0, 6),
            )
          ],
        );

    Color textColor = isOn ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black.withOpacity(0.8));
    Color subTextColor = isOn ? Colors.white.withOpacity(0.7) : (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5));
    Color iconColor = isOn ? Colors.white : (isDark ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.6));

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      decoration: decoration,
      child: Padding(
        padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOn ? Colors.white.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon, 
                        size: 32, 
                        color: iconColor
                      ).animate(target: isOn ? 1 : 0).scale(end: const Offset(1.1, 1.1), duration: 200.ms),
                    ),
                    if (isCooldown)
                      LogoLoadingIndicator(color: textColor, size: 24)
                    else
                      Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.only(top: 8, right: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          color: isOn ? Colors.greenAccent : (isDark ? Colors.white24 : Colors.black26),
                          boxShadow: isOn ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 8)] : [],
                        ),
                      ).animate(target: isOn ? 1 : 0).scaleXY(begin: 0.8, end: 1.2, duration: 200.ms)
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text(isOn ? context.tr('status_on') : context.tr('status_off'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subTextColor)),
                  ],
                ),
              ],
            ),
          ),
    );

    return BouncingButton(
      onTap: isCooldown ? null : onTap, 
      child: card,
    );
  }
}