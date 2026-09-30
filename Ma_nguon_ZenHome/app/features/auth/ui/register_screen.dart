import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/widgets/animations/wave_background.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/services/session_manager.dart';
import 'package:zenhome_app/features/home/ui/main_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final bool isPhone;
  final String? phoneNumber;
  final String? uid;

  const RegisterScreen({
    super.key,
    this.isPhone = false,
    this.phoneNumber,
    this.uid,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  Timer? _usernameDebounce;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() { if (mounted) setState(() {}); });
    _nameFocus.addListener(() { if (mounted) setState(() {}); });
    _passwordFocus.addListener(() { if (mounted) setState(() {}); });
    _confirmPasswordFocus.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _nameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _checkUsernameValidity(String value) {
    _usernameDebounce?.cancel();
    setState(() {
      _isUsernameAvailable = null;
      _isCheckingUsername = false;
      _usernameError = null;
    });

    final String username = value.trim();
    if (username.isEmpty) return;

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      setState(() {
        _usernameError = context.tr('err_invalid_username') ?? 'Username chỉ gồm chữ cái không dấu, số, dấu "-" và "_"';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    _usernameDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(username).get();
        if (mounted && _usernameController.text.trim() == username) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = !doc.exists;
            if (doc.exists) {
                _usernameError = context.tr('err_username_in_use') ?? 'Username này đã được sử dụng. Vui lòng chọn tên khác!';
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  void _checkPasswordStrength(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    });
  }

  void _showConfirmationDialog() async {
    final String username = _usernameController.text.trim();
    final String displayName = _nameController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || displayName.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_empty_field') ?? 'Vui lòng nhập đầy đủ thông tin!', isError: true);
      return;
    }

    if (password != confirmPassword) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_pass_mismatch') ?? 'Mật khẩu xác nhận không khớp!', isError: true);
      return;
    }
    
    if (!_hasMinLength || !_hasUppercase || !_hasLowercase || !_hasNumber || !_hasSpecialChar) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_firebase_weak_password') ?? 'Mật khẩu chưa đạt đủ các yêu cầu bảo mật!', isError: true);
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(username)) {
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_invalid_username') ?? 'Username chỉ gồm chữ cái không dấu, số, dấu "-" và "_"', isError: true);
      return;
    }

    LoadingOverlay.show(context);
    try {
      // 1. Kiểm tra username đã tồn tại chưa
      final doc = await FirebaseFirestore.instance.collection('users').doc(username).get();
      if (doc.exists) {
        await LoadingOverlay.hideError();
        showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_username_in_use') ?? 'Username này đã được sử dụng. Vui lòng chọn tên khác!', isError: true);
        return;
      }
      LoadingOverlay.hide();
      
      // Hiển thị dialog xác nhận thông tin
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: Colors.blue),
              const SizedBox(width: 10),
              Text(context.tr('confirm_title') ?? 'Xác nhận thông tin', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('register_review_info') ?? 'Vui lòng kiểm tra lại các thông tin sau trước khi tạo tài khoản:', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)),
              const SizedBox(height: 15),
              Text('• ${context.tr('full_name_label') ?? 'Họ và tên:'} $displayName', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('• ${context.tr('username_label_full') ?? 'Tên đăng nhập (Username):'} $username', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (widget.isPhone && widget.phoneNumber != null)
                Text('• ${context.tr('phone_label') ?? 'Số điện thoại:'} ${widget.phoneNumber}', style: const TextStyle(fontWeight: FontWeight.bold))
              else
                Text('• ${context.tr('google_linked') ?? 'Liên kết Google: Đã xác thực'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 8),
              Text('• ${context.tr('password_label') ?? 'Mật khẩu:'} ********', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('btn_edit_info') ?? 'Sửa lại', style: const TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _executeRegistration(username, displayName, password);
              },
              child: Text(context.tr('btn_create_account') ?? 'Tạo tài khoản'),
            ),
          ],
        ),
      );

    } catch (e) {
      await LoadingOverlay.hideError();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_generic') ?? "Đã xảy ra lỗi"}: $e', isError: true);
    }
  }

  void _executeRegistration(String username, String displayName, String password) async {
    LoadingOverlay.show(context);
    try {
      
      // 2. Xử lý liên kết tài khoản Firebase Auth
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (widget.isPhone && widget.phoneNumber != null) {
        final String dummyEmail = '${widget.phoneNumber!.replaceAll('+', '')}@zenhome.local';
        
        if (currentUser != null) {
          try {
            // Liên kết Email/Password vào tài khoản SĐT đang đăng nhập hiện tại
            final cred = EmailAuthProvider.credential(email: dummyEmail, password: password);
            await currentUser.linkWithCredential(cred);
          } on FirebaseAuthException catch (e) {
             if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
                // Nếu email dummy đã bị dùng (ví dụ đăng ký lỗi trước đó), ta thử đăng nhập vào nó và liên kết ngược lại số điện thoại (trường hợp hiếm)
                // Hoặc đơn giản là update email/password nếu được
                try {
                   await currentUser.updatePassword(password);
                } catch (_) {
                   await LoadingOverlay.hideError();
                   showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_phone_pass_conflict') ?? 'Tài khoản SĐT này đã tồn tại dữ liệu. Vui lòng thử đăng nhập lại.', isError: true);
                   return;
                }
             } else {
                await LoadingOverlay.hideError();
                showFloatingToast(context, context.tr('error') ?? 'Lỗi', e.message ?? 'Lỗi liên kết tài khoản', isError: true);
                return;
             }
          }
        }
      } else {
        // Tài khoản Google: đã login, giờ chỉ cần liên kết mật khẩu để sau này có thể đăng nhập bằng Email/Pass
        if (currentUser != null && currentUser.email != null) {
          try {
            final cred = EmailAuthProvider.credential(email: currentUser.email!, password: password);
            await currentUser.linkWithCredential(cred);
          } catch (e) {
            // Nếu đã liên kết hoặc có lỗi, thử updatePassword
            await currentUser.updatePassword(password);
          }
        }
      }

      final updatedUser = FirebaseAuth.instance.currentUser;
      if (updatedUser != null) {
          await updatedUser.updateDisplayName(displayName);
      }

      // 3. Lưu thông tin user vào Firestore
      await FirebaseFirestore.instance.collection('users').doc(username).set({
        'uid': updatedUser?.uid ?? widget.uid,
        'phoneNumber': widget.phoneNumber ?? '',
        'email': updatedUser?.email ?? '',
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Tạo cấu trúc config mẫu
      List<SmartConfig> myHomes = [
        SmartConfig(
          userId: username,
          macAddress: 'unknown_mac',
          mqttServer: 'broker.emqx.io',
          devices: [],
          role: 'owner',
          homeName: context.tr('my_home_default'),
          ownerEmail: username,
        ),
      ];
      await ref.read(homeConfigProvider).setAvailableHomes(myHomes);

      await LoadingOverlay.hideSuccess();
      
      await SessionManager.recordSession();
      
      if (mounted) {
        showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_profile_updated') ?? 'Đã tạo tài khoản thành công!');
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainLayout()), (r) => false);
      }
    } catch (e) {
      await LoadingOverlay.hideError();
      showFloatingToast(context, context.tr('error') ?? 'Lỗi', '${context.tr('err_generic') ?? "Đã xảy ra lỗi"}: $e', isError: true);
    }
  }

  Widget _buildRequirement(String text, bool isMet, Color baseColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : baseColor.withOpacity(0.5),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? Colors.green : baseColor.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C);
    Color textColor = isDark ? Colors.white : Colors.black87;

    int strengthScore = (_hasMinLength ? 1 : 0) +
        (_hasUppercase ? 1 : 0) +
        (_hasLowercase ? 1 : 0) +
        (_hasNumber ? 1 : 0) +
        (_hasSpecialChar ? 1 : 0);
    double strengthPercent = strengthScore / 5;
    Color strengthColor = strengthPercent <= 0.4 ? Colors.red : (strengthPercent <= 0.8 ? Colors.orange : Colors.green);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. Background Wave
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
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                // --- Logo & Title ---
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('public/zenhome_logo_transparent.png', width: 60, height: 60, fit: BoxFit.contain, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text('ZenHome', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                    const SizedBox(height: 5),
                    Text(context.tr('complete_info') ?? 'Hoàn tất đăng ký', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontStyle: FontStyle.italic)),
                    if (!widget.isPhone) ...[
                      const SizedBox(height: 15),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.g_mobiledata, color: Colors.white, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('google_register_hint') ?? 'Đã xác thực Google. Vui lòng thiết lập thêm Mật khẩu để bảo vệ tài khoản.', 
                                style: const TextStyle(color: Colors.white, fontSize: 12)
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // --- Glassmorphism Form ---
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
                              Widget? suffixIcon;
                              if (_usernameController.text.trim().isNotEmpty) {
                                if (_isCheckingUsername) {
                                  suffixIcon = Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: SizedBox(
                                      width: 20, height: 20,
                                      child: LogoLoadingIndicator(color: primaryColor, size: 24),
                                    ),
                                  );
                                } else if (_usernameError != null) {
                                  suffixIcon = const Icon(Icons.error, color: Colors.red);
                                } else if (_isUsernameAvailable == true) {
                                  suffixIcon = const Icon(Icons.check_circle, color: Colors.green);
                                }
                              }

                              Widget field = TextField(
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                onChanged: _checkUsernameValidity,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('username_label') ?? 'Username (Dùng để định danh)',
                                  labelStyle: TextStyle(color: _usernameFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.alternate_email, color: _usernameFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  suffixIcon: suffixIcon,
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  errorText: _usernameError,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 1.0)),
                                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.red, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              return field;
                            }
                          ),
                          const SizedBox(height: 15),
                          
                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('display_name') ?? 'Tên hiển thị',
                                  labelStyle: TextStyle(color: _nameFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.badge, color: _nameFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              return field;
                            }
                          ),
                          const SizedBox(height: 15),
                          
                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocus,
                                obscureText: _obscurePassword,
                                onChanged: _checkPasswordStrength,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('password_label') ?? 'Mật khẩu đăng nhập',
                                  labelStyle: TextStyle(color: _passwordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.lock, color: _passwordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: _passwordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                    onPressed: () { setState(() => _obscurePassword = !_obscurePassword); },
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              return field;
                            }
                          ),
                          const SizedBox(height: 10),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: LinearProgressIndicator(
                                  value: strengthPercent,
                                  backgroundColor: textColor.withOpacity(0.1),
                                  color: strengthColor,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildRequirement(context.tr('req_min_length') ?? 'Ít nhất 8 ký tự', _hasMinLength, textColor),
                              _buildRequirement(context.tr('req_uppercase') ?? 'Chữ hoa', _hasUppercase, textColor),
                              _buildRequirement(context.tr('req_lowercase') ?? 'Chữ thường', _hasLowercase, textColor),
                              _buildRequirement(context.tr('req_number') ?? 'Chữ số', _hasNumber, textColor),
                              _buildRequirement(context.tr('req_special_char') ?? 'Ký tự đặc biệt (!@#\$%^&*)', _hasSpecialChar, textColor),
                            ],
                          ),
                          const SizedBox(height: 15),
                          
                          Builder(
                            builder: (context) {
                              Widget field = TextField(
                                controller: _confirmPasswordController,
                                focusNode: _confirmPasswordFocus,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
                                  labelText: context.tr('confirm_password') ?? 'Xác nhận mật khẩu',
                                  labelStyle: TextStyle(color: _confirmPasswordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.6)),
                                  prefixIcon: Icon(Icons.lock_outline, color: _confirmPasswordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: _confirmPasswordFocus.hasFocus ? primaryColor : textColor.withOpacity(0.5)),
                                    onPressed: () { setState(() => _obscureConfirmPassword = !_obscureConfirmPassword); },
                                  ),
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryColor, width: 2.0)),
                                ),
                                style: TextStyle(color: textColor),
                              );
                              return field;
                            }
                          ),
                          const SizedBox(height: 30),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A3A7C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 5,
                                shadowColor: const Color(0xFF2A3A7C).withOpacity(0.5),
                              ),
                              onPressed: _showConfirmationDialog,
                              child: Text(context.tr('btn_continue') ?? 'Bắt đầu sử dụng', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
