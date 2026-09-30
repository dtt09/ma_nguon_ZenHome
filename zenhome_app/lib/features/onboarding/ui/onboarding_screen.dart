import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/auth/ui/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onSkip() async {
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
    if (_currentPage == 2) {
      _onSkip();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.ease,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    final List<Map<String, dynamic>> pages = [
      {
        'icon': Icons.home_max_rounded,
        'title': context.tr('onboarding_title_1'),
        'desc': context.tr('onboarding_desc_1'),
        'color': const Color(0xFF3B82F6)
      },
      {
        'icon': Icons.auto_awesome_mosaic_rounded,
        'title': context.tr('onboarding_title_2'),
        'desc': context.tr('onboarding_desc_2'),
        'color': const Color(0xFF10B981)
      },
      {
        'icon': Icons.notifications_active_rounded,
        'title': context.tr('onboarding_title_3'),
        'desc': context.tr('onboarding_desc_3'),
        'color': const Color(0xFFF59E0B)
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _onSkip,
                child: Text(context.tr('btn_skip'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(
                            color: pages[index]['color'].withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            pages[index]['icon'],
                            size: 100,
                            color: pages[index]['color'],
                          ),
                        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
                        const SizedBox(height: 50),
                        Text(
                          pages[index]['title'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms).fadeIn(),
                        const SizedBox(height: 20),
                        Text(
                          pages[index]['desc'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ).animate().slideY(begin: 0.5, end: 0, duration: 400.ms, delay: 100.ms).fadeIn(),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 10,
                        width: _currentPage == index ? 25 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? const Color(0xFF2A3A7C) : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A3A7C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      elevation: 5,
                    ),
                    onPressed: _onNext,
                    child: Text(
                      _currentPage == 2 ? context.tr('btn_get_started') : context.tr('btn_next'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ).animate().scaleXY(begin: 0.9, end: 1.0),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
