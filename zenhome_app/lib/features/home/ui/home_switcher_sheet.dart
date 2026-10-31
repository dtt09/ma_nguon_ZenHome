import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';
import 'package:zenhome_app/features/home/ui/edit_home_properties_sheet.dart';

void showHomeSwitcherBottomSheet(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  HapticFeedback.lightImpact();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (sheetContext) {
      return Consumer(
        builder: (context, refWatch, _) {
          final homeNotifier = refWatch.watch(homeConfigProvider);
          final allHomes = homeNotifier.availableHomes;
          final activeConfig = homeNotifier.activeConfig;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
            ),
            padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101625) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thanh kéo pill mềm mại
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Tiêu đề & Nút Thêm nhà mới (Bảo vệ chống tràn chữ)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.home_work_rounded, color: Color(0xFF0F766E), size: 20),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              context.tr('switch_home') ?? 'Quản lý & Chuyển nhà',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nút thêm nhà mới
                        BouncingButton(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            // QUY TẮC: 1 TÀI KHOẢN CHỈ ĐƯỢC CÓ TỐI ĐA 1 NGÔI NHÀ TRỐNG ESP32
                            final emptyEspHomeIndex = allHomes.indexWhere(
                              (h) => h.role == 'owner' && (h.macAddress.isEmpty || h.macAddress == 'unknown_mac'),
                            );

                            if (emptyEspHomeIndex != -1) {
                              _showExistingEmptyHomeNoticeDialog(context, ref, sheetContext, allHomes[emptyEspHomeIndex]);
                            } else {
                              _showCreateHomeDialog(context, ref, sheetContext);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F766E).withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                                const SizedBox(width: 3),
                                Text(
                                  context.tr('btn_add_home') ?? 'Thêm nhà',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Danh sách nhà
                if (allHomes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(Icons.home_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('no_home_to_switch') ?? 'Không có ngôi nhà nào khác',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: allHomes.length,
                      itemBuilder: (context, index) {
                        final home = allHomes[index];
                        final isSelected = home.userId == activeConfig.userId;
                        final isOwner = home.role == 'owner';
                        final isSub = home.isSubHome;

                        // Định nghĩa Icon & Màu theo thuộc tính nhà
                        final defaultColor = isOwner
                            ? (isSub ? const Color(0xFF3B82F6) : const Color(0xFF0F766E))
                            : const Color(0xFF8B5CF6);
                        final typeColor = HomeHelper.getThemeColor(home.homeColor, defaultColor: defaultColor);
                        final homeIcon = HomeHelper.getIconData(home.homeIcon);
                        final typeName = HomeHelper.getHomeTypeLabel(home.homeType, context);
                        String typeLabel;

                        if (isOwner) {
                          if (isSub) {
                            typeLabel = '$typeName (${context.tr('owner_role') ?? 'Chủ sở hữu'})';
                          } else {
                            typeLabel = '👑 $typeName (${context.tr('owner_role') ?? 'Chủ sở hữu'})';
                          }
                        } else {
                          typeLabel = '👥 $typeName (${home.role})';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: BouncingButton(
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              if (!isSelected) {
                                HapticFeedback.selectionClick();
                                showFloatingToast(
                                  context,
                                  context.tr('switch_home') ?? 'Chuyển đổi nhà',
                                  (context.tr('switching_to_home') ?? 'Đang chuyển sang {name}...').replaceAll('{name}', home.homeName),
                                );
                                try {
                                  await ref.read(homeConfigProvider).switchActiveHome(home.userId).timeout(const Duration(seconds: 5));
                                  if (context.mounted) {
                                    showFloatingToast(
                                      context,
                                      context.tr('toast_success') ?? 'Thành công',
                                      (context.tr('switched_to_home') ?? 'Đã chuyển sang {name}!').replaceAll('{name}', home.homeName),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    showFloatingToast(
                                      context,
                                      context.tr('error') ?? 'Lỗi',
                                      '${context.tr('err_switch_home_failed') ?? 'Không thể chuyển nhà:'} $e',
                                      isError: true,
                                    );
                                  }
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? typeColor.withOpacity(isDark ? 0.22 : 0.08)
                                    : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? typeColor
                                      : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? typeColor.withOpacity(0.2)
                                          : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      homeIcon,
                                      color: isSelected ? typeColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          home.homeName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected
                                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                                : (isDark ? Colors.grey.shade200 : const Color(0xFF334155)),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: typeColor,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                typeLabel,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected ? typeColor : Colors.grey.shade500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (home.macAddress.isEmpty || home.macAddress == 'unknown_mac') ...[
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '⚠️ Chưa thiết lập ESP32',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.amber.shade700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ] else if (home.homeRules.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: typeColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '🛡️ ${home.homeRules.length} quy tắc thông minh',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: typeColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: typeColor,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  // Menu tùy chọn (Thuộc tính, Đổi tên, Xóa nhà) cho chủ nhà
                                  if (isOwner)
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert_rounded,
                                        size: 20,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      onSelected: (action) {
                                        if (action == 'edit_properties') {
                                          showEditHomePropertiesBottomSheet(context, ref, home);
                                        } else if (action == 'rename') {
                                          _showRenameHomeDialog(context, ref, home);
                                        } else if (action == 'delete') {
                                          _showDeleteHomeDialog(context, ref, home);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 'edit_properties',
                                          child: Row(
                                            children: [
                                              Icon(Icons.palette_rounded, size: 18, color: typeColor),
                                              const SizedBox(width: 10),
                                              Text(
                                                context.tr('home_customization_title') ?? 'Thuộc tính & Quy tắc',
                                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF0F766E)),
                                              const SizedBox(width: 10),
                                              Text(
                                                context.tr('rename_home') ?? 'Đổi tên nhà',
                                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSub) ...[
                                          const PopupMenuDivider(),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                                const SizedBox(width: 10),
                                                Text(
                                                  context.tr('delete_home') ?? 'Xóa nhà này',
                                                  style: const TextStyle(color: Colors.red),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                
                const SizedBox(height: 10),
                // Lời nhắc tiện ích
                Text(
                  context.tr('multi_home_tip') ?? 'Bạn có thể làm chủ nhiều ngôi nhà và chuyển đổi tức thì không cần đăng xuất.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Hộp thoại Cảnh báo nếu Tài khoản đã có 1 Ngôi nhà chưa thiết lập ESP32
void _showExistingEmptyHomeNoticeDialog(
  BuildContext context,
  WidgetRef ref,
  BuildContext sheetContext,
  SmartConfig emptyHome,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('empty_esp_limit_title') ?? 'Đã có nhà chưa cài ESP32',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          (context.tr('empty_esp_limit_desc') ??
                  'Bạn đang có ngôi nhà "{name}" chưa được thiết lập ESP32.\n\nMỗi tài khoản chỉ được phép có 1 ngôi nhà duy nhất trống ESP32. Bạn có muốn thiết lập ESP32 cho ngôi nhà này ngay bây giờ không?')
              .replaceAll('{name}', emptyHome.homeName),
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              context.tr('btn_cancel') ?? 'Để sau',
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              Navigator.pop(sheetContext);
              // Chuyển sang ngôi nhà này nếu chưa active
              await ref.read(homeConfigProvider).switchActiveHome(emptyHome.userId);
              // Mở màn hình Setup ESP32
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WifiSetupScreen(targetHome: emptyHome)),
                );
              }
            },
            child: Text(
              context.tr('btn_setup_esp_now') ?? 'Thiết lập ESP32 ngay',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
            ),
          ),
        ],
      );
    },
  );
}

/// Hộp thoại Tạo Ngôi Nhà Mới & Chuyển thẳng sang Setup ESP32
void _showCreateHomeDialog(BuildContext context, WidgetRef ref, BuildContext sheetContext) {
  final nameController = TextEditingController();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  bool isCreating = false;

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add_home_work_rounded, color: Color(0xFF0F766E), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('create_new_home') ?? 'Thêm Ngôi Nhà Mới',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('enter_home_name') ?? 'Tên ngôi nhà mới:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: context.tr('hint_home_name') ?? 'Ví dụ: Nhà vườn, Căn hộ 2, Biệt thự...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF0F766E), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('create_home_then_setup_desc') ??
                                'Sau khi đặt tên nhà, ứng dụng sẽ tự động chuyển tới quy trình ghép nối và cấp phát Wi-Fi cho Hub ESP32.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF0F766E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  context.tr('btn_cancel') ?? 'Hủy',
                  style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isCreating
                    ? null
                    : () async {
                        final homeName = nameController.text.trim();
                        if (homeName.isEmpty) {
                          showFloatingToast(
                            context,
                            context.tr('error') ?? 'Lỗi',
                            context.tr('err_empty_home_name') ?? 'Vui lòng nhập tên ngôi nhà!',
                            isError: true,
                          );
                          return;
                        }

                        setDialogState(() => isCreating = true);
                        final newHome = await ref.read(homeConfigProvider).createNewHome(
                              homeName: homeName,
                              macAddress: '',
                            );
                        setDialogState(() => isCreating = false);

                        if (newHome != null) {
                          Navigator.pop(dialogCtx);
                          Navigator.pop(sheetContext);
                          if (context.mounted) {
                            showFloatingToast(
                              context,
                              context.tr('toast_success') ?? 'Thành công',
                              (context.tr('created_home_success') ?? 'Đã tạo ngôi nhà "{name}"! Đang mở thiết lập ESP32...')
                                  .replaceAll('{name}', homeName),
                            );
                            // Chuyển thẳng tới Setup ESP32
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => WifiSetupScreen(targetHome: newHome)),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            showFloatingToast(
                              context,
                              context.tr('error') ?? 'Lỗi',
                              context.tr('err_create_home_failed') ?? 'Không thể tạo nhà mới. Vui lòng thử lại!',
                              isError: true,
                            );
                          }
                        }
                      },
                child: isCreating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('btn_create_and_setup_esp') ?? 'Tạo & Cài đặt ESP32',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                        ],
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hộp thoại Đổi tên Ngôi Nhà
void _showRenameHomeDialog(BuildContext context, WidgetRef ref, SmartConfig home) {
  final renameController = TextEditingController(text: home.homeName);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              context.tr('rename_home') ?? 'Đổi Tên Ngôi Nhà',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            content: TextField(
              controller: renameController,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: context.tr('hint_new_home_name') ?? 'Nhập tên mới cho ngôi nhà...',
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text(context.tr('btn_cancel') ?? 'Hủy', style: TextStyle(color: Colors.grey.shade500)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newName = renameController.text.trim();
                        if (newName.isEmpty) return;

                        setDialogState(() => isSaving = true);
                        final success = await ref.read(homeConfigProvider).renameHome(home.userId, newName);
                        setDialogState(() => isSaving = false);

                        if (success) {
                          Navigator.pop(dialogCtx);
                          if (context.mounted) {
                            showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_rename_home_success') ?? 'Đã cập nhật tên nhà thành công!');
                          }
                        } else {
                          if (context.mounted) {
                            showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_rename_home') ?? 'Không thể đổi tên nhà!', isError: true);
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(context.tr('btn_save') ?? 'Lưu', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hộp thoại Xóa Ngôi Nhà Phụ
void _showDeleteHomeDialog(BuildContext context, WidgetRef ref, SmartConfig home) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  bool isDeleting = false;

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('delete_home_confirm_title') ?? 'Xóa Ngôi Nhà?',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              ],
            ),
            content: Text(
              (context.tr('delete_home_confirm_desc') ?? 'Bạn có chắc chắn muốn xóa ngôi nhà "{name}"? Toàn bộ thiết bị, cấu hình và lịch trình của ngôi nhà này sẽ bị xóa vĩnh viễn.')
                  .replaceAll('{name}', home.homeName),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                child: Text(context.tr('btn_cancel') ?? 'Hủy', style: TextStyle(color: Colors.grey.shade500)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        final success = await ref.read(homeConfigProvider).deleteHome(home.userId);
                        setDialogState(() => isDeleting = false);

                        if (success) {
                          Navigator.pop(dialogCtx);
                          if (context.mounted) {
                            showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', context.tr('msg_delete_home_success') ?? 'Đã xóa ngôi nhà thành công!');
                          }
                        } else {
                          if (context.mounted) {
                            showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_delete_home') ?? 'Không thể xóa ngôi nhà này!', isError: true);
                          }
                        }
                      },
                child: isDeleting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(context.tr('btn_delete') ?? 'Xóa vĩnh viễn', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<Map<String, bool>> _checkDisabledStatus(List<SmartConfig> homes) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return {};
  
  Map<String, bool> disabledStatus = {};
  String? myUsername;
  
  try {
    final query = await FirebaseFirestore.instance.collection('users').where('uid', isEqualTo: user.uid).get();
    for (var doc in query.docs) {
      if (doc.data()['isSubHome'] != true) {
        myUsername = doc.id;
        break;
      }
    }
    if (myUsername == null && query.docs.isNotEmpty) {
      myUsername = query.docs.first.id;
    }
  } catch (e) {
    return {};
  }
  
  if (myUsername == null) return {};

  for (var home in homes) {
    if (home.role == 'owner') {
      disabledStatus[home.userId] = false;
      continue;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(home.userId).get();
      if (doc.exists) {
        List<dynamic> disabledMembers = doc.data()?['disabledMembers'] ?? [];
        disabledStatus[home.userId] = disabledMembers.contains(myUsername);
      } else {
        disabledStatus[home.userId] = false;
      }
    } catch (e) {
      disabledStatus[home.userId] = false;
    }
  }
  return disabledStatus;
}
