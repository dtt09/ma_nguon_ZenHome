import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with LoginLogicMixin {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark
        ? context.zenColors.primaryAccent
        : context.zenColors.primaryDark;
    final scheme = Theme.of(context).colorScheme;
    final language = ref.watch(localeNotifierProvider).languageCode;

    return ZenGlassScaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: context.tr(
                            isDark ? 'theme_light' : 'theme_dark',
                          ),
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                          onPressed: () => ref
                              .read(themeModeNotifierProvider.notifier)
                              .setThemeMode(
                                isDark ? ThemeMode.light : ThemeMode.dark,
                              ),
                        ),
                        TextButton.icon(
                          onPressed: () => ref
                              .read(localeNotifierProvider.notifier)
                              .setLocale(language == 'vi' ? 'en' : 'vi'),
                          icon: const Icon(Icons.language_rounded, size: 18),
                          label: Text(language == 'vi' ? 'VN' : 'EN'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ZenLiquidGlass.lightweight(
                        width: 60,
                        height: 60,
                        borderRadius: 18,
                        surfaceColor: accent.withValues(alpha: 0.10),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset(
                          'public/zenhome_logo_transparent.png',
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'ZenHome',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('login_subtitle'),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ZenGlassCard.lightweight(
                      borderRadius: 24,
                      padding: const EdgeInsets.all(18),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: phoneController,
                              focusNode: phoneFocus,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              onChanged: (_) {
                                if (phoneError != null)
                                  setState(() => phoneError = null);
                              },
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('phone_or_email'),
                                prefixIcon: Icons.person_outline_rounded,
                                errorText: phoneError,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: passwordController,
                              focusNode: passwordFocus,
                              obscureText: obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              onChanged: (value) {
                                if (passwordError != null && value.isNotEmpty)
                                  setState(() => passwordError = null);
                              },
                              decoration: zenGlassInputDecoration(
                                context,
                                labelText: context.tr('password_label'),
                                prefixIcon: Icons.lock_outline_rounded,
                                errorText: passwordError,
                                suffixIcon: IconButton(
                                  tooltip: obscurePassword
                                      ? context.l10n.show_password
                                      : context.l10n.hide_password,
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: TextButton(
                                onPressed: handleForgotPassword,
                                child: Text(context.tr('forgot_password')),
                              ),
                            ),
                            ZenGlassButton(
                              label: context.tr('btn_login'),
                              icon: Icons.login_rounded,
                              maxLines: 2,
                              isLoading: isLoading,
                              onPressed: isLoading
                                  ? null
                                  : () {
                                      HapticFeedback.lightImpact();
                                      handlePhoneLogin();
                                    },
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(context.tr('no_account')),
                                TextButton(
                                  child: Text(context.tr('register_now')),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Text(
                              context.tr('or_login_with'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              alignment: WrapAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  icon: isGoogleLoading
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Image.asset(
                                          'public/google_logo.png',
                                          width: 18,
                                          height: 18,
                                        ),
                                  label: const Text('Google'),
                                  onPressed: isGoogleLoading
                                      ? null
                                      : () {
                                          HapticFeedback.lightImpact();
                                          handleGoogleLogin();
                                        },
                                ),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 18,
                                  ),
                                  label: Text(context.tr('phone_label')),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PhoneRegistrationScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
