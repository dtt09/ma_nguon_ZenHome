import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class GoogleConfirmScreen extends ConsumerWidget {
  final String email;

  const GoogleConfirmScreen({super.key, required this.email});

  Widget _buildMainContent(
    BuildContext context, {
    required bool isOverWave,
    required ScrollController controller,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color primaryColor = isDark ? zen.primaryAccent : zen.primary;
    final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;

    // Split-wave header colors
    final Color headerLogoColor = isOverWave ? Colors.white : primaryColor;
    final Color headerTitleColor =
        isOverWave ? Colors.white : (isDark ? AppColors.darkText : AppColors.lightText);
    final Color headerSubtitleColor = isOverWave
        ? Colors.white.withOpacity(0.86)
        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: ZenGlassIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                size: 40,
                iconSize: 18,
                borderRadius: 14,
                blurSigma: isOverWave ? 0 : 14,
                iconColor: isDark ? Colors.white : AppColors.lightText,
                onTap: () => Navigator.pop(context, false),
              ),
            ),
          ),

          // --- Split-Wave Brand Header ---
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isOverWave
                      ? Colors.white.withOpacity(0.18)
                      : primaryColor.withOpacity(0.12),
                  border: Border.all(
                    color: isOverWave
                        ? Colors.white.withOpacity(0.35)
                        : primaryColor.withOpacity(0.28),
                    width: 1.2,
                  ),
                ),
                child: Image.asset(
                  'public/zenhome_logo_transparent.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                  color: headerLogoColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ZenHome',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: headerTitleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('account_not_registered'),
                style: TextStyle(
                  color: headerSubtitleColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (constraints.maxHeight - 34).clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      child: ZenLiquidGlass(
                        borderRadius: 28,
                        blurSigma: isOverWave ? 0 : 20,
                        rimWidth: 1.3,
                        glowColor: zen.primary,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        customShadows: isOverWave ? const [] : null,
                        customGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  const Color(0xFF0F172A).withOpacity(0.70),
                                  const Color(0xFF0A1120).withOpacity(0.54),
                                ]
                              : [
                                  Colors.white.withOpacity(0.84),
                                  Colors.white.withOpacity(0.70),
                                ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ZenLiquidGlass(
                              width: 76,
                              height: 76,
                              borderRadius: 24,
                              blurSigma: 0,
                              alignment: Alignment.center,
                              surfaceColor: Colors.white.withOpacity(
                                isDark ? 0.09 : 0.88,
                              ),
                              customShadows: const [],
                              child: Image.asset(
                                'public/google_logo.png',
                                width: 36,
                                height: 36,
                              ),
                            ),
                            const SizedBox(height: 16),

                            ZenGlassPill(
                              blurSigma: 0,
                              isSelected: true,
                              glowColor: primaryColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.alternate_email_rounded,
                                    size: 15,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            Text(
                              context.l10n.ask_register_google(email),
                              style: TextStyle(
                                fontSize: 15.5,
                                color: textColor,
                                height: 1.55,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ZenGlassButton(
                                label: context.tr('btn_yes'),
                                icon: Icons.person_add_alt_1_rounded,
                                borderRadius: 16,
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context, true);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ZenGlassButton(
                                label: context.tr('btn_cancel'),
                                isPrimary: false,
                                borderRadius: 16,
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context, false);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZenGlassScaffold(
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.40,
        builder: (context, isTopLayer, controller) => _buildMainContent(
          context,
          isOverWave: isTopLayer,
          controller: controller,
        ),
      ),
    );
  }
}
