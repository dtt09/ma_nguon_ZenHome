import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'zen_liquid_glass.dart';

class UserAvatar extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.radius = 21,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final zen = context.zenColors;
    Widget avatarWidget;

    if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: radius - 2.5,
        backgroundImage: NetworkImage(user.photoURL!),
        backgroundColor: Colors.transparent,
      );
    } else {
      final String firstLetter = (user?.displayName ?? 'U').isNotEmpty
          ? (user?.displayName ?? 'U').substring(0, 1).toUpperCase()
          : 'U';
      avatarWidget = Container(
        width: (radius - 2.5) * 2,
        height: (radius - 2.5) * 2,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: zen.brandHero,
        ),
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: radius * 0.72,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
    }

    return ZenLiquidGlass(
      width: radius * 2,
      height: radius * 2,
      borderRadius: radius,
      blurSigma: 14,
      padding: const EdgeInsets.all(2.2),
      alignment: Alignment.center,
      onTap: onTap != null
          ? () {
              HapticFeedback.selectionClick();
              onTap!();
            }
          : null,
      child: avatarWidget,
    );
  }
}

