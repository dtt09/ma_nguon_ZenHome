import 'package:flutter/material.dart';

class NotificationBadge extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onPressed;

  const NotificationBadge({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, size: 24),
            onPressed: onPressed,
          ),
          if (unreadCount > 0)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
