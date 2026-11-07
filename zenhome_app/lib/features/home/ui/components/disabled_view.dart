import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
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

    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 110),
          child: ZenGlassCard(
            borderRadius: 28,
            blurSigma: 22,
            isActive: true,
            glowColor: AppColors.amberGlow,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZenLiquidGlass(
                  blurSigma: 0,
                  borderRadius: 34,
                  padding: const EdgeInsets.all(20),
                  glowColor: AppColors.amberGlow,
                  surfaceColor: AppColors.amberGlow.withOpacity(0.16),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 52,
                    color: AppColors.amberGlow,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('access_restricted') ?? 'Quyền truy cập bị giới hạn',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${context.tr('msg_disabled_desc') ?? 'Tài khoản của bạn đã bị vô hiệu hoá tạm thời hoặc thiết bị ngoại tuyến trong ngôi nhà'} "${activeConfig.homeName}".',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // CTA 1: Chuyển đổi nhà
                SizedBox(
                  width: double.infinity,
                  child: ZenGlassButton(
                    icon: Icons.swap_horiz_rounded,
                    label: context.tr('switch_home') ?? 'Chuyển đổi sang nhà khác',
                    onPressed: () => showHomeSwitcherBottomSheet(context, ref),
                  ),
                ),

                // CTA 2: Quản lý thành viên & Quyền (nếu có quyền owner/co_owner)
                if (isOwner) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ZenGlassButton(
                      isPrimary: false,
                      icon: Icons.people_outline_rounded,
                      label: context.tr('manage_members') ?? 'Quản lý thành viên & Quyền',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => MemberScreen()));
                      },
                    ),
                  ),
                ],

                // CTA 3: Cài đặt lại Wi-Fi Hub
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ZenGlassButton(
                    isPrimary: false,
                    icon: Icons.wifi_rounded,
                    label: context.tr('wifi_setup_title') ?? 'Cài đặt lại Wi-Fi cho Hub',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const WifiSetupScreen()));
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


