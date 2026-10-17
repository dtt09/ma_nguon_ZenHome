import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart'; 
import 'package:zenhome_app/features/auth/ui/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/onboarding/ui/onboarding_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Tự động đồng bộ dữ liệu mới nhất từ Firestore ngay khi mở app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeConfig = ref.read(homeConfigProvider).activeConfig;
      if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
        ref.read(homeConfigProvider).syncFromFirestore().catchError((e) {
          debugPrint("Lỗi sync ngầm khi mở app: $e");
          return false;
        });
      }
    });

    // Reduce splash time to 2.5s for a snappier, modern feel
    Timer(const Duration(milliseconds: 2500), () async {
      final prefs = await SharedPreferences.getInstance();
      bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

      Widget nextScreen;
      if (isFirstRun) {
        nextScreen = const OnboardingScreen();
      } else {
        final activeConfig = ref.read(homeConfigProvider).activeConfig;
        nextScreen = (activeConfig.userId == 'guest' || activeConfig.userId.isEmpty)
            ? const LoginScreen() 
            : const MainLayout(); 
      }
          
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child); 
            },
            transitionDuration: const Duration(milliseconds: 600), 
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color brandColor = isDark ? Colors.white : const Color(0xFF0F766E);
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : Colors.white, 
      body: Stack(
        children: [
          // Centered Logo and Brand Name
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Icon
                Image.asset(
                  'public/zenhome_logo_transparent.png', 
                  width: 85, 
                  height: 85, 
                  fit: BoxFit.contain, 
                  color: brandColor
                ).animate()
                 .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 1000.ms, curve: Curves.easeOutCubic)
                 .fade(duration: 800.ms),
                
                const SizedBox(height: 16),
                
                // Brand Name
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 34,
                      color: brandColor,
                      letterSpacing: 1.5,
                    ),
                    children: const [
                      TextSpan(text: 'Zen', style: TextStyle(fontWeight: FontWeight.w400)),
                      TextSpan(text: 'Home', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ).animate()
                 .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutQuart)
                 .fade(duration: 800.ms),
              ],
            ),
          ),
          
          // Bottom Footer (like "from Meta" or "from TikTok")
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'from',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Gradient or styled company name
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    colors: isDark 
                        ? [const Color(0xFF14B8A6), const Color(0xFF2DD4BF)]
                        : [const Color(0xFF0F766E), const Color(0xFF14B8A6)],
                  ).createShader(bounds),
                  child: const Text(
                    'STEM 2026',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ).animate(delay: 500.ms)
             .slideY(begin: 0.5, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
             .fade(duration: 600.ms),
          ),
        ],
      ),
    );
  }
}


