import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/animations/dual_layer_screen_wrapper.dart';

class GoogleConfirmScreen extends ConsumerWidget {
  final String email;

  const GoogleConfirmScreen({super.key, required this.email});

  Widget _buildContent(BuildContext context, bool isTopLayer, ScrollController controller) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color color = isTopLayer ? Colors.white : (isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C));

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const SizedBox(height: 40),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('public/zenhome_logo_transparent.png', width: 75, height: 75, fit: BoxFit.contain, color: color),
              const SizedBox(height: 10),
              Text('ZenHome', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: color)),
              const SizedBox(height: 5),
              Text(
                context.tr('account_not_registered') ?? 'Tài khoản chưa đăng ký', 
                style: TextStyle(color: color.withOpacity(0.8), fontStyle: FontStyle.italic)
              ),
            ],
          ),
          
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isTopLayer ? Colors.white.withOpacity(0.1) : color.withOpacity(0.1),
                          ),
                          child: Icon(
                            Icons.g_mobiledata,
                            size: 80,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          context.l10n.ask_register_google(email),
                          style: TextStyle(fontSize: 16, color: color, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isTopLayer ? Colors.white : const Color(0xFF2A3A7C),
                              foregroundColor: isTopLayer ? const Color(0xFF2A3A7C) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            onPressed: () {
                              Navigator.pop(context, true); // User agrees to register
                            },
                            child: Text(context.tr('btn_yes') ?? 'Đồng ý', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: color.withOpacity(0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              foregroundColor: color,
                            ),
                            onPressed: () {
                              Navigator.pop(context, false); // User cancels
                            },
                            child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090C15) : const Color(0xFFF5F7FA),
      body: DualLayerScreenWrapper(
        waveHeightPercent: 0.40,
        builder: _buildContent,
      ),
    );
  }
}
