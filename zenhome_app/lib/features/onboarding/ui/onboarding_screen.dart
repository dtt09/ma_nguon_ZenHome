import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onSkip() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstRun', false);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _onNext() async {
    HapticFeedback.lightImpact();
    if (_currentPage == 2) {
      _onSkip();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color primaryColor = isDark ? zen.primaryAccent : zen.primary;
    final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final List<Map<String, dynamic>> pages = [
      {
        'icon': Icons.home_max_rounded,
        'title': context.tr('onboarding_title_1'),
        'desc': context.tr('onboarding_desc_1'),
        'color': const Color(0xFF3B82F6),
      },
      {
        'icon': Icons.auto_awesome_mosaic_rounded,
        'title': context.tr('onboarding_title_2'),
        'desc': context.tr('onboarding_desc_2'),
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.notifications_active_rounded,
        'title': context.tr('onboarding_title_3'),
        'desc': context.tr('onboarding_desc_3'),
        'color': const Color(0xFFF59E0B),
      },
    ];

    final Color activePageColor = pages[_currentPage]['color'] as Color;

    return ZenGlassScaffold(
      meshIntensity: 1.15,
      appBar: ZenGlassAppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'public/zenhome_logo_transparent.png',
              width: 26,
              height: 26,
              fit: BoxFit.contain,
              color: primaryColor,
            ),
            const SizedBox(width: 9),
            Text(
              'ZenHome',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: textColor,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ZenGlassPill(
              blurSigma: 0,
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              onTap: _onSkip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr('btn_skip'),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: mutedColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final Color pageColor = pages[index]['color'] as Color;
                  final IconData pageIcon = pages[index]['icon'] as IconData;
                  final String pageTitle = pages[index]['title'] as String;
                  final String pageDesc = pages[index]['desc'] as String;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 18.0,
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ZenGlassCard(
                          borderRadius: 32,
                          blurSigma: 22,
                          isActive: true,
                          glowColor: pageColor,
                          padding: const EdgeInsets.fromLTRB(26, 30, 26, 34),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Step Indicator Pill
                              ZenGlassPill(
                                blurSigma: 0,
                                isSelected: true,
                                glowColor: pageColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                child: Text(
                                  '0${index + 1} / 0${pages.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: pageColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Luminous 3D Frosted Icon Orb
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 150,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          pageColor.withOpacity(
                                            isDark ? 0.28 : 0.18,
                                          ),
                                          pageColor.withOpacity(0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ZenLiquidGlass(
                                    width: 118,
                                    height: 118,
                                    borderRadius: 36,
                                    blurSigma: 0,
                                    glowColor: pageColor,
                                    rimWidth: 1.4,
                                    alignment: Alignment.center,
                                    surfaceColor: pageColor.withOpacity(
                                      isDark ? 0.16 : 0.10,
                                    ),
                                    customShadows: [
                                      BoxShadow(
                                        color: pageColor.withOpacity(
                                          isDark ? 0.30 : 0.18,
                                        ),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                    child: Icon(
                                      pageIcon,
                                      size: 56,
                                      color: pageColor,
                                    ),
                                  ),
                                ],
                              )
                                  .animate()
                                  .scale(
                                    duration: 500.ms,
                                    curve: Curves.easeOutBack,
                                  )
                                  .fadeIn(),

                              const SizedBox(height: 30),

                              Text(
                                pageTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.25,
                                  color: textColor,
                                ),
                              )
                                  .animate()
                                  .slideY(
                                    begin: 0.35,
                                    end: 0,
                                    duration: 380.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .fadeIn(),

                              const SizedBox(height: 14),

                              Text(
                                pageDesc,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.55,
                                  color: mutedColor,
                                ),
                              )
                                  .animate()
                                  .slideY(
                                    begin: 0.35,
                                    end: 0,
                                    duration: 380.ms,
                                    delay: 80.ms,
                                    curve: Curves.easeOut,
                                  )
                                  .fadeIn(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // --- Bottom Liquid Glass Controls (Page Dots Capsule + Luminous Action Button) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ZenGlassPill(
                    blurSigma: 16,
                    borderRadius: 24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        pages.length,
                        (index) {
                          final bool isActive = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            margin: EdgeInsets.only(
                              right: index == pages.length - 1 ? 0 : 7,
                            ),
                            height: 9,
                            width: isActive ? 26 : 9,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? activePageColor
                                  : (isDark
                                      ? Colors.white.withOpacity(0.22)
                                      : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color:
                                            activePageColor.withOpacity(0.45),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : const [],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  ZenGlassButton(
                    label: _currentPage == 2
                        ? context.tr('btn_get_started')
                        : context.tr('btn_next'),
                    icon: _currentPage == 2
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    accentColor: _currentPage == 2 ? null : activePageColor,
                    borderRadius: 22,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 15,
                    ),
                    onPressed: _onNext,
                  ).animate(key: ValueKey(_currentPage == 2)).scaleXY(
                        begin: 0.94,
                        end: 1.0,
                        duration: 240.ms,
                        curve: Curves.easeOutBack,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
