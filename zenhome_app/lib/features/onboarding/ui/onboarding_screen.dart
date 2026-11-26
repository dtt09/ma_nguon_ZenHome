import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/widgets/animations/zen_page_route.dart';
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
        ZenPageRoute(builder: (context) => const LoginScreen()),
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
        'color': zen.primary,
      },
      {
        'icon': Icons.auto_awesome_mosaic_rounded,
        'title': context.tr('onboarding_title_2'),
        'desc': context.tr('onboarding_desc_2'),
        'color': zen.success,
      },
      {
        'icon': Icons.notifications_active_rounded,
        'title': context.tr('onboarding_title_3'),
        'desc': context.tr('onboarding_desc_3'),
        'color': zen.warning,
      },
    ];

    final Color activePageColor = pages[_currentPage]['color'] as Color;

    return ZenGlassScaffold(
      meshIntensity: 1.0,
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
            Flexible(
              child: Text(
                'ZenHome',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ZenGlassPill.lightweight(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              onTap: _onSkip,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      context.tr('btn_skip'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: mutedColor,
                      ),
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
                        child: ZenGlassCard.lightweight(
                          borderRadius: 32,
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
                                          pageColor.withValues(
                                            alpha: isDark ? 0.24 : 0.14,
                                          ),
                                          pageColor.withValues(alpha: 0.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                  ZenLiquidGlass.lightweight(
                                    width: 118,
                                    height: 118,
                                    borderRadius: 36,
                                    glowColor: pageColor,
                                    alignment: Alignment.center,
                                    surfaceColor: pageColor.withValues(
                                      alpha: isDark ? 0.16 : 0.10,
                                    ),
                                    customShadows: [
                                      BoxShadow(
                                        color: pageColor.withValues(
                                          alpha: isDark ? 0.20 : 0.12,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
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
                                    duration: 420.ms,
                                    curve: Curves.easeOutCubic,
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
                  ZenGlassPill.lightweight(
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
                            duration: const Duration(milliseconds: 260),
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
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: activePageColor.withValues(
                                          alpha: 0.28,
                                        ),
                                        blurRadius: 6,
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
                  const SizedBox(width: 12),
                  Flexible(
                    child: ZenGlassButton.lightweight(
                      label: _currentPage == 2
                          ? context.tr('btn_get_started')
                          : context.tr('btn_next'),
                      icon: _currentPage == 2
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      accentColor: _currentPage == 2 ? null : activePageColor,
                      borderRadius: 22,
                      maxLines: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      onPressed: _onNext,
                    ),
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
