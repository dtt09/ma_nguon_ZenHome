import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserAvatar extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.radius = 25,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    Widget avatarWidget;
    
    if (user?.photoURL != null && user!.photoURL!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user.photoURL!),
        backgroundColor: Colors.transparent,
      );
    } else {
      String firstLetter = (user?.displayName ?? 'U').isNotEmpty 
          ? (user?.displayName ?? 'U').substring(0, 1).toUpperCase() 
          : 'U';
      avatarWidget = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF0F766E),
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarWidget,
      );
    }
    
    return avatarWidget;
  }
}

