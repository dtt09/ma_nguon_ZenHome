import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/ui/home_switcher_sheet.dart';
import 'package:zenhome_app/features/settings/ui/member_screen.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';

class DisabledView extends ConsumerWidget {
  final bool isDark;

  const DisabledView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final isOwner = activeConfig.role == 'owner' || activeConfig.role == 'co_owner';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_person_rounded, size: 64, color: Colors.amber),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('access_restricted') ?? 'Quyền truy cập bị giới hạn',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${context.tr('msg_disabled_desc') ?? 'Tài khoản của bạn đã bị vô hiệu hoá tạm thời hoặc thiết bị ngoại tuyến trong ngôi nhà'} "${activeConfig.homeName}".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, height: 1.5),
              ),
            ),
            const SizedBox(height: 28),

            // Card chứa các CTA hành động trực tiếp
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 1. Chuyển đổi nhà
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () => showHomeSwitcherBottomSheet(context, ref),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                      label: Text(context.tr('switch_home') ?? 'Chuyển đổi sang nhà khác', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // 2. Quản lý thành viên & Quyền (nếu có quyền owner/co_owner)
                  if (isOwner) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => MemberScreen()));
                        },
                        icon: const Icon(Icons.people_outline_rounded, size: 20),
                        label: Text(context.tr('manage_members') ?? 'Quản lý thành viên & Quyền', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],

                  // 3. Cài đặt lại Wi-Fi Hub
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF14B8A6) : const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiSetupScreen()));
                      },
                      icon: const Icon(Icons.wifi_rounded, size: 20),
                      label: Text(context.tr('wifi_setup_title') ?? 'Cài đặt lại Wi-Fi cho Hub', style: const TextStyle(fontWeight: FontWeight.w600)),
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


