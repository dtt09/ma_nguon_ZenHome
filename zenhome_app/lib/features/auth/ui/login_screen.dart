import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    String currentLang = ref.watch(localeNotifierProvider).languageCode;
    Color primaryColor = isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E);
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Background Wave (Fixed)
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height,
            child: const WaveBackground(heightPercent: 0.40),
          ),
          
          // 2. Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 20),
                // --- Language Switcher ---
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: InkWell(
                      onTap: () async {
                        String newLang = currentLang == 'vi' ? 'en' : 'vi';
                        await ref.read(localeNotifierProvider.notifier).setLocale(newLang);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language, size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              currentLang == 'vi' ? 'VN' : 'EN',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                // --- Logo & Title (Always White because it sits on the Wave) ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('public/zenhome_logo_transparent.png', width: 75, height: 75, fit: BoxFit.contain, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text('ZenHome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(context.tr('login_subtitle') ?? 'Đồng bộ nhịp sống, kết nối tương lai.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontStyle: FontStyle.italic)),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // --- Glassmorphism Login Form ---
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121827).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.1), blurRadius: 30, offset: const Offset(0, 15)),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.5), width: 1.5),
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
                                  if (phoneError != null) setState(() => phoneError = null);
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('phone_or_email'),
                                  labelStyle: TextStyle(color: phoneFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.phone, color: phoneFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  errorText: phoneError,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
                                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              if (phoneError != null) {
                                field = field.animate(key: ValueKey(phoneError)).shake(hz: 8, curve: Curves.easeInOutCubic, duration: 300.ms);
                              }
                              return field;
                            }
                          ),
                          const SizedBox(height: 20),
                          
                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: passwordController,
                                focusNode: passwordFocus,
                                obscureText: obscurePassword,
                                onChanged: (val) {
                                  if (passwordError != null && val.isNotEmpty) setState(() => passwordError = null);
                                },
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('password_label'),
                                  labelStyle: TextStyle(color: passwordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.lock, color: passwordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  errorText: passwordError,
                                  suffixIcon: IconButton(
                                    icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility, color: passwordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                    onPressed: () { setState(() => obscurePassword = !obscurePassword); },
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
                                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              if (passwordError != null) {
                                field = field.animate(key: ValueKey(passwordError)).shake(hz: 8, curve: Curves.easeInOutCubic, duration: 300.ms);
                              }
                              return field;
                            }
                          ),
                          
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: handleForgotPassword,
                              child: Text(context.tr('forgot_password'), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                                shadowColor: const Color(0xFF0F766E).withOpacity(0.5),
                              ),
                              onPressed: isLoading ? null : () {
                                HapticFeedback.lightImpact();
                                handlePhoneLogin();
                              },
                              child: Text(context.tr('btn_login'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(context.tr('no_account'), style: TextStyle(color: textColor.withOpacity(0.7))),
                              TextButton(
                                onPressed: () {
                                   Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                                },
                                child: Text(context.tr('register_now'), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Expanded(child: Divider(color: textColor.withOpacity(0.2))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(context.tr('or_login_with') ?? 'HOẶC', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                              ),
                              Expanded(child: Divider(color: textColor.withOpacity(0.2))),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: textColor.withOpacity(0.2)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                foregroundColor: textColor,
                              ),
                              icon: isGoogleLoading
                                  ? SizedBox(width: 24, height: 24, child: LogoLoadingIndicator(color: primaryColor, size: 24))
                                  : Image.asset('public/google_logo.png', width: 24, height: 24),
                              label: const Text('Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              onPressed: isGoogleLoading ? null : () {
                                HapticFeedback.lightImpact();
                                handleGoogleLogin();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



