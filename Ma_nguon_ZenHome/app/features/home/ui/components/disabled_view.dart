import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/ui/home_switcher_sheet.dart';

class DisabledView extends ConsumerWidget {
  final bool isDark;

  const DisabledView({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    String ownerName = activeConfig.ownerEmail ?? activeConfig.userId;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_rounded, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(context.tr('error') ?? 'Lỗi', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '${context.tr('msg_disabled_desc') ?? 'Tài khoản của bạn đã bị vô hiệu hoá tạm thời'} ${context.tr('by_admin') ?? 'bởi quản trị viên nhà'} "${activeConfig.homeName}".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A3A7C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => showHomeSwitcherBottomSheet(context, ref),
            icon: const Icon(Icons.swap_horiz),
            label: Text(context.tr('switch_home') ?? 'Chuyển đổi nhà'),
          ),
        ],
      ),
    );
  }
}
