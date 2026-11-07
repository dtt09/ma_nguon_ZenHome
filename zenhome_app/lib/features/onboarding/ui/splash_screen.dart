import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
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
            transitionDuration: const Duration(milliseconds: 700),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart,
              );

              return FadeTransition(
                opacity: curvedAnimation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.03),
                      end: Offset.zero,
                    ).animate(curvedAnimation),
                    child: child,
                  ),
                ),
              );
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color brandColor = isDark ? Colors.white : zen.primary;

    return ZenGlassScaffold(
      meshIntensity: 1.15,
      body: Stack(
        children: [
          // Centered Glass Emblem & Brand Name
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ZenLiquidGlass(
                  width: 118,
                  height: 118,
                  borderRadius: 34,
                  blurSigma: 22,
                  glowColor: zen.primary,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'public/zenhome_logo_transparent.png',
                    width: 68,
                    height: 68,
                    fit: BoxFit.contain,
                    color: brandColor,
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 1000.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fade(duration: 800.ms),
                const SizedBox(height: 20),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 34,
                      color: isDark ? Colors.white : AppColors.lightText,
                      letterSpacing: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Zen',
                        style: TextStyle(fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: 'Home',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark ? zen.primaryAccent : zen.primary,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .slideY(
                      begin: 0.2,
                      end: 0,
                      duration: 800.ms,
                      curve: Curves.easeOutQuart,
                    )
                    .fade(duration: 800.ms),
              ],
            ),
          ),

          // Bottom Footer Glass Pill
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ZenGlassPill(
                blurSigma: 16,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'from',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => zen.brandHero.createShader(bounds),
                      child: const Text(
                        'STEM 2026',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate(delay: 500.ms)
                .slideY(
                  begin: 0.5,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutCubic,
                )
                .fade(duration: 600.ms),
          ),
        ],
      ),
    );
  }
}


