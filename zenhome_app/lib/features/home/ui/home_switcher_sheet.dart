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
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';
import 'package:zenhome_app/features/home/ui/edit_home_properties_sheet.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

void showHomeSwitcherBottomSheet(BuildContext context, WidgetRef ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  HapticFeedback.lightImpact();

  showZenGlassBottomSheet(
    context: context,
    maxHeightFactor: 0.85,
    builder: (sheetContext) {
      return Consumer(
        builder: (context, refWatch, _) {
          final homeNotifier = refWatch.watch(homeConfigProvider);
          final allHomes = homeNotifier.availableHomes;
          final activeConfig = homeNotifier.activeConfig;

          final zen = context.zenColors;

          return Padding(
            padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tiêu đề & Nút Thêm nhà mới (Bảo vệ chống tràn chữ)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ZenLiquidGlass(
                            blurSigma: 0,
                            borderRadius: 12,
                            padding: const EdgeInsets.all(8),
                            glowColor: zen.primary,
                            surfaceColor: zen.primary.withOpacity(0.14),
                            child: Icon(Icons.home_work_rounded, color: zen.primary, size: 20),
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
                        // Nút thêm nhà mới dạng Kính Lỏng
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
                          child: ZenGlassPill(
                            blurSigma: 0,
                            borderRadius: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6.5),
                            isSelected: true,
                            glowColor: zen.primary,
                            customGradient: zen.brandHero,
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
                        const SizedBox(width: 6),
                        ZenGlassIconButton(
                          icon: Icons.close_rounded,
                          size: 32,
                          iconSize: 18,
                          borderRadius: 10,
                          blurSigma: 0,
                          onTap: () => Navigator.pop(sheetContext),
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
                            child: ZenGlassCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              borderRadius: 20,
                              isActive: isSelected,
                              glowColor: typeColor,
                              blurSigma: 0,
                              child: Row(
                                children: [
                                  ZenLiquidGlass(
                                    blurSigma: 0,
                                    borderRadius: 14,
                                    padding: const EdgeInsets.all(10),
                                    glowColor: isSelected ? typeColor : null,
                                    surfaceColor: isSelected
                                        ? typeColor.withOpacity(0.20)
                                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.75)),
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
                                          const SizedBox(height: 4),
                                          ZenGlassPill(
                                            blurSigma: 0,
                                            borderRadius: 7,
                                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                            isSelected: true,
                                            glowColor: AppColors.amberGlow,
                                            child: Text(
                                              '⚠️ Chưa thiết lập ESP32',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppColors.amberGlow : Colors.amber.shade800,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ] else if (home.homeRules.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          ZenGlassPill(
                                            blurSigma: 0,
                                            borderRadius: 7,
                                            padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                                            isSelected: true,
                                            glowColor: typeColor,
                                            child: Text(
                                              '🛡️ ${home.homeRules.length} quy tắc thông minh',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
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
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: typeColor,
                                        boxShadow: [
                                          BoxShadow(
                                            color: typeColor.withOpacity(0.45),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                        size: 15,
                                      ),
                                    ),
                                  // Menu tùy chọn Kính Lỏng (Thuộc tính, Đổi tên, Xóa nhà) cho chủ nhà
                                  if (isOwner)
                                    ZenGlassPopupMenuButton<String>(
                                      icon: Icons.more_vert_rounded,
                                      iconColor: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                      onSelected: (action) {
                                        if (action == 'edit_properties') {
                                          showEditHomePropertiesBottomSheet(context, ref, home);
                                        } else if (action == 'rename') {
                                          _showRenameHomeDialog(context, ref, home);
                                        } else if (action == 'delete') {
                                          _showDeleteHomeDialog(context, ref, home);
                                        }
                                      },
                                      items: [
                                        ZenGlassMenuOption<String>(
                                          value: 'edit_properties',
                                          icon: Icons.palette_rounded,
                                          color: typeColor,
                                          label: context.tr('home_customization_title') ?? 'Thuộc tính & Quy tắc',
                                        ),
                                        ZenGlassMenuOption<String>(
                                          value: 'rename',
                                          icon: Icons.edit_rounded,
                                          color: zen.primary,
                                          label: context.tr('rename_home') ?? 'Đổi tên nhà',
                                        ),
                                        if (isSub)
                                          ZenGlassMenuOption<String>(
                                            value: 'delete',
                                            icon: Icons.delete_outline_rounded,
                                            label: context.tr('delete_home') ?? 'Xóa nhà này',
                                            isDanger: true,
                                            showDividerAbove: true,
                                          ),
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

/// Hộp thoại Cảnh báo Kính Lỏng nếu Tài khoản đã có 1 Ngôi nhà chưa thiết lập ESP32
void _showExistingEmptyHomeNoticeDialog(
  BuildContext context,
  WidgetRef ref,
  BuildContext sheetContext,
  SmartConfig emptyHome,
) {
  showZenGlassDialog(
    context: context,
    accentColor: AppColors.amberGlow,
    builder: (dialogCtx) {
      final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
      final zen = dialogCtx.zenColors;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZenLiquidGlass(
                blurSigma: 0,
                borderRadius: 12,
                padding: const EdgeInsets.all(9),
                glowColor: AppColors.amberGlow,
                surfaceColor: AppColors.amberGlow.withOpacity(0.16),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.amberGlow, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.tr('empty_esp_limit_title') ?? 'Đã có nhà chưa cài ESP32',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            (context.tr('empty_esp_limit_desc') ??
                    'Bạn đang có ngôi nhà "{name}" chưa được thiết lập ESP32.\n\nMỗi tài khoản chỉ được phép có 1 ngôi nhà duy nhất trống ESP32. Bạn có muốn thiết lập ESP32 cho ngôi nhà này ngay bây giờ không?')
                .replaceAll('{name}', emptyHome.homeName),
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ZenGlassButton(
                  isPrimary: false,
                  label: context.tr('btn_cancel') ?? 'Để sau',
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ZenGlassButton(
                  accentColor: zen.primary,
                  label: context.tr('btn_setup_esp_now') ?? 'Thiết lập ngay',
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
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Hộp thoại Kính Lỏng Tạo Ngôi Nhà Mới & Chuyển thẳng sang Setup ESP32
void _showCreateHomeDialog(BuildContext context, WidgetRef ref, BuildContext sheetContext) {
  final nameController = TextEditingController();
  bool isCreating = false;

  showZenGlassDialog(
    context: context,
    accentColor: context.zenColors.primary,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final zen = ctx.zenColors;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 12,
                      padding: const EdgeInsets.all(9),
                      glowColor: zen.primary,
                      surfaceColor: zen.primary.withOpacity(0.15),
                      child: Icon(Icons.add_home_work_rounded, color: zen.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('create_new_home') ?? 'Thêm Ngôi Nhà Mới',
                        style: TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                  decoration: zenGlassInputDecoration(
                    ctx,
                    hintText: context.tr('hint_home_name') ?? 'Ví dụ: Nhà vườn, Căn hộ 2, Biệt thự...',
                    prefixIcon: Icons.home_rounded,
                    borderRadius: 15,
                  ),
                ),
                const SizedBox(height: 12),
                ZenLiquidGlass(
                  blurSigma: 0,
                  borderRadius: 14,
                  padding: const EdgeInsets.all(12),
                  glowColor: zen.primary,
                  surfaceColor: zen.primary.withOpacity(0.10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: zen.primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.tr('create_home_then_setup_desc') ??
                              'Sau khi đặt tên nhà, ứng dụng sẽ tự động chuyển tới quy trình ghép nối và cấp phát Wi-Fi cho Hub ESP32.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade300 : zen.primary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: ZenGlassButton(
                        isPrimary: false,
                        label: context.tr('btn_cancel') ?? 'Hủy',
                        onPressed: isCreating ? null : () => Navigator.pop(dialogCtx),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ZenGlassButton(
                        isLoading: isCreating,
                        icon: Icons.arrow_forward_rounded,
                        label: context.tr('btn_create_and_setup_esp') ?? 'Tạo & Cài ESP32',
                        onPressed: () async {
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Hộp thoại Kính Lỏng Đổi tên Ngôi Nhà
void _showRenameHomeDialog(BuildContext context, WidgetRef ref, SmartConfig home) {
  final renameController = TextEditingController(text: home.homeName);
  bool isSaving = false;

  showZenGlassDialog(
    context: context,
    accentColor: context.zenColors.primary,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final zen = ctx.zenColors;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 12,
                    padding: const EdgeInsets.all(9),
                    glowColor: zen.primary,
                    surfaceColor: zen.primary.withOpacity(0.15),
                    child: Icon(Icons.edit_rounded, color: zen.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('rename_home') ?? 'Đổi Tên Ngôi Nhà',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: renameController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: zenGlassInputDecoration(
                  ctx,
                  hintText: context.tr('hint_new_home_name') ?? 'Nhập tên mới cho ngôi nhà...',
                  prefixIcon: Icons.home_outlined,
                  borderRadius: 15,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ZenGlassButton(
                      isPrimary: false,
                      label: context.tr('btn_cancel') ?? 'Hủy',
                      onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ZenGlassButton(
                      isLoading: isSaving,
                      label: context.tr('btn_save') ?? 'Lưu',
                      onPressed: () async {
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
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

/// Hộp thoại Kính Lỏng Xóa Ngôi Nhà Phụ
void _showDeleteHomeDialog(BuildContext context, WidgetRef ref, SmartConfig home) {
  bool isDeleting = false;

  showZenGlassDialog(
    context: context,
    accentColor: AppColors.roseGlow,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 12,
                    padding: const EdgeInsets.all(9),
                    glowColor: AppColors.roseGlow,
                    surfaceColor: AppColors.roseGlow.withOpacity(0.16),
                    child: const Icon(Icons.warning_amber_rounded, color: AppColors.roseGlow, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('delete_home_confirm_title') ?? 'Xóa Ngôi Nhà?',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.roseGlow),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                (context.tr('delete_home_confirm_desc') ?? 'Bạn có chắc chắn muốn xóa ngôi nhà "{name}"? Toàn bộ thiết bị, cấu hình và lịch trình của ngôi nhà này sẽ bị xóa vĩnh viễn.')
                    .replaceAll('{name}', home.homeName),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ZenGlassButton(
                      isPrimary: false,
                      label: context.tr('btn_cancel') ?? 'Hủy',
                      onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ZenGlassButton(
                      isDanger: true,
                      isLoading: isDeleting,
                      icon: Icons.delete_forever_rounded,
                      label: context.tr('btn_delete') ?? 'Xóa vĩnh viễn',
                      onPressed: () async {
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
                    ),
                  ),
                ],
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
