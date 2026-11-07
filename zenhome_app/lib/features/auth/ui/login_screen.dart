import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:zenhome_app/features/auth/ui/phone_registration_screen.dart';
import 'package:zenhome_app/features/auth/ui/register_screen.dart';
import 'package:zenhome_app/features/auth/logic/login_logic_mixin.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with LoginLogicMixin {
  @override
  void initState() {
    super.initState();
    initLoginLogic();
  }

  @override
  void dispose() {
    disposeLoginLogic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final String currentLang = ref.watch(localeNotifierProvider).languageCode;
    final Color primaryColor = isDark ? zen.primaryAccent : zen.primary;
    final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final Color mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Nền Cực Quang Khúc Xạ Đa Tầng (Aurora Mesh 2.0)
          const ZenAmbientMeshBackground(intensity: 1.05),

          // 1. Sóng Chuyển Động Đặc Trưng (Wave Layer)
          const Positioned.fill(
            child: WaveBackground(heightPercent: 0.40),
          ),

          // 2. Nội Dung Chính
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                // --- Top Floating Theme & Language Capsules ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ZenGlassIconButton(
                        icon: isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 38,
                        iconSize: 18,
                        borderRadius: 14,
                        blurSigma: 14,
                        iconColor: isDark ? Colors.white : AppColors.lightText,
                        onTap: () {
                          ref
                              .read(themeModeNotifierProvider.notifier)
                              .setThemeMode(
                                isDark ? ThemeMode.light : ThemeMode.dark,
                              );
                        },
                      ),
                      const SizedBox(width: 10),
                      ZenGlassPill(
                        borderRadius: 20,
                        blurSigma: 14,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final String newLang =
                              currentLang == 'vi' ? 'en' : 'vi';
                          await ref
                              .read(localeNotifierProvider.notifier)
                              .setLocale(newLang);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.language_rounded,
                              size: 17,
                              color:
                                  isDark ? Colors.white : AppColors.lightText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              currentLang == 'vi' ? 'VN' : 'EN',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.4,
                                color:
                                    isDark ? Colors.white : AppColors.lightText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // --- Logo & Brand Title (Sits over Wave) ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ZenLiquidGlass(
                      width: 80,
                      height: 80,
                      borderRadius: 24,
                      blurSigma: 12,
                      alignment: Alignment.center,
                      customGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.24),
                          Colors.white.withOpacity(0.06),
                        ],
                      ),
                      customShadows: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      child: Image.asset(
                        'public/zenhome_logo_transparent.png',
                        width: 54,
                        height: 54,
                        fit: BoxFit.contain,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'ZenHome',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        context.tr('login_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontStyle: FontStyle.italic,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // --- True Refractive Liquid Glass 2.0 Login Form ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                    child: ZenLiquidGlass(
                      borderRadius: 28,
                      blurSigma: 22,
                      rimWidth: 1.3,
                      glowColor: zen.primary,
                      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                      customGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0F172A).withOpacity(0.70),
                                const Color(0xFF0A1120).withOpacity(0.54),
                              ]
                            : [
                                Colors.white.withOpacity(0.82),
                                Colors.white.withOpacity(0.66),
                              ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: phoneController,
                                focusNode: phoneFocus,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (val) {
                                  if (phoneError != null) {
                                    setState(() => phoneError = null);
                                  }
                                },
                                decoration: zenGlassInputDecoration(
                                  context,
                                  labelText: context.tr('phone_or_email'),
                                  prefixIcon: Icons.person_outline_rounded,
                                  errorText: phoneError,
                                  borderRadius: 16,
                                  accentColor: primaryColor,
                                ),
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                              if (phoneError != null) {
                                field = field
                                    .animate(key: ValueKey(phoneError))
                                    .shake(
                                      hz: 8,
                                      curve: Curves.easeInOutCubic,
                                      duration: 300.ms,
                                    );
                              }
                              return field;
                            },
                          ),
                          const SizedBox(height: 16),

                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: passwordController,
                                focusNode: passwordFocus,
                                obscureText: obscurePassword,
                                onChanged: (val) {
                                  if (passwordError != null && val.isNotEmpty) {
                                    setState(() => passwordError = null);
                                  }
                                },
                                decoration: zenGlassInputDecoration(
                                  context,
                                  labelText: context.tr('password_label'),
                                  prefixIcon: Icons.lock_outline_rounded,
                                  errorText: passwordError,
                                  borderRadius: 16,
                                  accentColor: primaryColor,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 20,
                                      color: passwordFocus.hasFocus
                                          ? primaryColor
                                          : mutedColor,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () =>
                                            obscurePassword = !obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                              if (passwordError != null) {
                                field = field
                                    .animate(key: ValueKey(passwordError))
                                    .shake(
                                      hz: 8,
                                      curve: Curves.easeInOutCubic,
                                      duration: 300.ms,
                                    );
                              }
                              return field;
                            },
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                              ),
                              child: Text(
                                context.tr('forgot_password'),
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ZenGlassButton(
                              label: context.tr('btn_login'),
                              icon: Icons.login_rounded,
                              isLoading: isLoading,
                              borderRadius: 16,
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      handlePhoneLogin();
                                    },
                            ),
                          ),

                          const SizedBox(height: 14),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                context.tr('no_account'),
                                style: TextStyle(
                                  color: mutedColor,
                                  fontSize: 13.5,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  context.tr('register_now'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  context.tr('or_login_with'),
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.12)
                                      : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // --- Frosted Specular Social / Quick Capsules (Google & Phone) ---
                          Row(
                            children: [
                              Expanded(
                                child: ZenLiquidGlass(
                                  height: 52,
                                  borderRadius: 16,
                                  blurSigma: 0,
                                  rimWidth: 1.15,
                                  alignment: Alignment.center,
                                  surfaceColor: Colors.white.withOpacity(
                                    isDark ? 0.07 : 0.68,
                                  ),
                                  customGradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            Colors.white.withOpacity(0.11),
                                            Colors.white.withOpacity(0.04),
                                          ]
                                        : [
                                            Colors.white.withOpacity(0.86),
                                            Colors.white.withOpacity(0.58),
                                          ],
                                  ),
                                  customShadows: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDark ? 0.22 : 0.05,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  onTap: isGoogleLoading
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          handleGoogleLogin();
                                        },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isGoogleLoading)
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: LogoLoadingIndicator(
                                            color: primaryColor,
                                            size: 22,
                                          ),
                                        )
                                      else
                                        Image.asset(
                                          'public/google_logo.png',
                                          width: 22,
                                          height: 22,
                                        ),
                                      const SizedBox(width: 9),
                                      Text(
                                        'Google',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ZenLiquidGlass(
                                  height: 52,
                                  borderRadius: 16,
                                  blurSigma: 0,
                                  rimWidth: 1.15,
                                  alignment: Alignment.center,
                                  surfaceColor: Colors.white.withOpacity(
                                    isDark ? 0.07 : 0.68,
                                  ),
                                  customGradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDark
                                        ? [
                                            Colors.white.withOpacity(0.11),
                                            Colors.white.withOpacity(0.04),
                                          ]
                                        : [
                                            Colors.white.withOpacity(0.86),
                                            Colors.white.withOpacity(0.58),
                                          ],
                                  ),
                                  customShadows: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDark ? 0.22 : 0.05,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const PhoneRegistrationScreen(),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.phone_iphone_rounded,
                                        size: 20,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 7),
                                      Flexible(
                                        child: Text(
                                          context.tr('phone_label'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
