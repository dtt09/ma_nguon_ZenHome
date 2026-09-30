import re

content = """import '../../utils/helpers.dart';
import '../../providers/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main_layout.dart';
import '../../utils/toast_helper.dart';
import '../../models/smart_config.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';
import '../../utils/localization_extension.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/dual_layer_screen_wrapper.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  void _saveAndNavigate(String username) async {
    List<SmartConfig> myHomes = [];
    try {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(username).get();
      if (myDoc.exists) {
        final data = myDoc.data() as Map<String, dynamic>;
        // ... (simplified logic)
        List<DeviceConfig> restoredDevices = [];
        if (data['devices'] != null) {
          restoredDevices = (data['devices'] as List).map((e) => DeviceConfig.fromJson(e)).toList();
        }
        myHomes.add(SmartConfig(
          userId: username,
          macAddress: data['macAddress'] ?? 'unknown_mac',
          mqttServer: data['mqttServer'] ?? 'broker.emqx.io',
          mqttUser: data['mqttUser'],
          mqttPass: data['mqttPass'],
          devices: restoredDevices,
          role: 'owner',
          homeName: context.tr('my_home_default'),
          ownerEmail: username,
        ));
      } else {
        myHomes.add(SmartConfig(
          userId: username,
          macAddress: 'unknown_mac',
          mqttServer: 'broker.emqx.io',
          devices: [],
          role: 'owner',
          homeName: context.tr('my_home_default'),
          ownerEmail: username,
        ));
      }
    } catch (e) {
      print("Lỗi đồng bộ Firebase: $e");
    }

    if (myHomes.isEmpty) {
      myHomes.add(SmartConfig(userId: username, macAddress: 'unknown_mac', devices: [], role: 'owner', homeName: context.tr('my_home_default'), ownerEmail: username));
    }
    setAvailableHomes(myHomes);
    
    if (mounted) {
      showFloatingToast(context, context.tr('toast_success'), context.tr('msg_sync_success') ?? 'Đã đồng bộ dữ liệu!', isError: false);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
    }
  }

  void _handlePhoneAuth() async {
    final String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showFloatingToast(context, context.tr('error'), 'Vui lòng nhập số điện thoại', isError: true);
      return;
    }
    
    LoadingOverlay.show(context);
    try {
      String phoneNumber = phone;
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '+84${phoneNumber.substring(1)}';
      } else if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
           // Auto resolved
           LoadingOverlay.hide();
           try {
              final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
              _checkUserExistsAndNavigate(userCred.user!.uid);
           } catch(e) {}
        },
        verificationFailed: (FirebaseAuthException e) {
           LoadingOverlay.hide();
           showFloatingToast(context, context.tr('error'), e.message ?? 'Lỗi xác thực', isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
           LoadingOverlay.hide();
           Navigator.push(context, MaterialPageRoute(builder: (context) => OtpVerificationScreen(
               verificationId: verificationId, 
               phoneNumber: phoneNumber
           )));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
           // Timeout
        },
      );
    } catch (e) {
      LoadingOverlay.hide();
      showFloatingToast(context, context.tr('error'), 'Đã xảy ra lỗi: $e', isError: true);
    }
  }

  void _checkUserExistsAndNavigate(String uid) async {
      LoadingOverlay.show(context);
      try {
         final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: uid).get();
         LoadingOverlay.hide();
         if (query.docs.isNotEmpty) {
             _saveAndNavigate(query.docs.first.id); // document ID is username
         } else {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen(isPhone: true)));
         }
      } catch(e) {
         LoadingOverlay.hide();
      }
  }

  void _handleGoogleLogin() async {
    // Google logic...
    setState(() => _isGoogleLoading = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(serverClientId: dotenv.env['GOOGLE_CLIENT_ID']!);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) { setState(() => _isGoogleLoading = false); return; }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final UserCredential userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      
      _checkUserExistsAndNavigate(userCred.user!.uid);
      
    } catch (e) {
      showFloatingToast(context, context.tr('error'), '${context.tr('error')}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Widget _buildContent(BuildContext context, bool isTopLayer, ScrollController controller) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isTopLayer ? Colors.white : (isDark ? const Color(0xFF6C8DF0) : const Color(0xFF2A3A7C));
    
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Header
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('public/zenhome_logo_transparent.png', width: 75, height: 75, fit: BoxFit.contain, color: color),
              const SizedBox(height: 10),
              Text('ZenHome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: color)),
              const SizedBox(height: 5),
              Text(context.tr('login_subtitle') ?? 'Đồng bộ nhịp sống, kết nối tương lai.', style: TextStyle(color: color.withOpacity(0.8), fontStyle: FontStyle.italic)),
            ],
          ),
          
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isTopLayer ? Colors.white.withOpacity(0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                        labelText: 'Số điện thoại',
                        labelStyle: TextStyle(color: isTopLayer ? Colors.white70 : null),
                        prefixIcon: Icon(Icons.phone, color: color),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color.withOpacity(0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: color)),
                      ),
                      style: TextStyle(color: isTopLayer ? Colors.white : (isDark ? Colors.white : Colors.black)),
                    ),
                    
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTopLayer ? Colors.white : const Color(0xFF2A3A7C),
                          foregroundColor: isTopLayer ? const Color(0xFF2A3A7C) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _isLoading ? null : _handlePhoneAuth,
                        child: Text(context.tr('login') ?? 'Đăng Nhập', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Divider(color: color.withOpacity(0.5))),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(context.tr('or_login_with') ?? 'hoặc đăng nhập với', style: TextStyle(color: color.withOpacity(0.7)))),
                        Expanded(child: Divider(color: color.withOpacity(0.5))),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: color.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                        icon: Image.asset('public/google_logo.png', width: 24, height: 24, color: isTopLayer ? Colors.white : null),
                        label: Text('Google', style: TextStyle(fontSize: 16, color: color)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.45,
        builder: _buildContent,
      ),
    );
  }
}
"""

with open("lib/screens/auth/login_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
