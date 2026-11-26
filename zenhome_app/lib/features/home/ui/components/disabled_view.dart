import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/animations/zen_page_route.dart';
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
    final zen = context.zenColors;

    return SafeArea(
      bottom: false,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 30, 24, zenBottomNavClearance(context)),
          child: ZenGlassCard.lightweight(
            borderRadius: 28,
            isActive: true,
            glowColor: zen.warning,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ZenLiquidGlass.lightweight(
                  borderRadius: 34,
                  padding: const EdgeInsets.all(20),
                  glowColor: zen.warning,
                  surfaceColor: zen.warning.withValues(alpha: 0.14),
                  child: Icon(
                    Icons.lock_person_rounded,
                    size: 52,
                    color: zen.warning,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('access_restricted'),
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
                    '${context.tr('disabled_desc_detailed')} "${activeConfig.homeName}".',
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
                    label: context.tr('btn_switch_other_home'),
                    maxLines: 2,
                    onPressed: () => showHomeSwitcherBottomSheet(context, ref),
                  ),
                ),

                // CTA 2: Quản lý thành viên & Quyền (nếu có quyền owner/co_owner)
                if (isOwner) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ZenGlassButton.lightweight(
                      isPrimary: false,
                      icon: Icons.people_outline_rounded,
                      label: context.tr('btn_manage_members_perms'),
                      maxLines: 2,
                      onPressed: () {
                        Navigator.push(context, ZenPageRoute(builder: (_) => MemberScreen()));
                      },
                    ),
                  ),
                ],

                // CTA 3: Cài đặt lại Wi-Fi Hub
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ZenGlassButton.lightweight(
                    isPrimary: false,
                    icon: Icons.wifi_rounded,
                    label: context.tr('btn_reconfig_hub_wifi'),
                    maxLines: 2,
                    onPressed: () {
                      Navigator.push(context, ZenPageRoute(builder: (_) => const WifiSetupScreen()));
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


