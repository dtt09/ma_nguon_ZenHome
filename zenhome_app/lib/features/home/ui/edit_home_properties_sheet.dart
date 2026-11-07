import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

/// BottomSheet tùy chỉnh Thuộc tính, Biểu tượng, Màu sắc và Bộ quy tắc ngôi nhà (Liquid Glass 2.0)
void showEditHomePropertiesBottomSheet(
  BuildContext context,
  WidgetRef ref,
  SmartConfig home,
) {
  final primaryThemeColor = HomeHelper.getThemeColor(
    home.homeColor.isNotEmpty ? home.homeColor : '#0F766E',
  );
  showZenGlassBottomSheet(
    context: context,
    maxHeightFactor: 0.90,
    padBottomForKeyboard: true,
    accentColor: primaryThemeColor,
    builder: (sheetCtx) => _EditHomePropertiesContent(home: home),
  );
}

class _EditHomePropertiesContent extends ConsumerStatefulWidget {
  final SmartConfig home;

  const _EditHomePropertiesContent({required this.home});

  @override
  ConsumerState<_EditHomePropertiesContent> createState() => _EditHomePropertiesContentState();
}

class _EditHomePropertiesContentState extends ConsumerState<_EditHomePropertiesContent> {
  late TextEditingController _nameController;
  late String _selectedType;
  late String _selectedIcon;
  late String _selectedColorHex;
  late List<String> _activeRules;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.home.homeName);
    _selectedType = widget.home.homeType.isNotEmpty ? widget.home.homeType : 'townhouse';
    _selectedIcon = widget.home.homeIcon.isNotEmpty ? widget.home.homeIcon : 'home';
    _selectedColorHex = widget.home.homeColor.isNotEmpty ? widget.home.homeColor : '#0F766E';
    _activeRules = List<String>.from(widget.home.homeRules);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error') ?? 'Lỗi',
        context.tr('err_empty_home_name') ?? 'Vui lòng nhập tên ngôi nhà!',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final success = await ref.read(homeConfigProvider).updateHomeProperties(
            homeId: widget.home.userId,
            homeName: newName,
            homeIcon: _selectedIcon,
            homeType: _selectedType,
            homeColor: _selectedColorHex,
            homeRules: _activeRules,
          );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.pop(context);
          showFloatingToast(
            context,
            context.tr('toast_success') ?? 'Thành công',
            context.tr('home_props_saved') ?? 'Đã lưu thuộc tính và bộ quy tắc ngôi nhà!',
          );
        } else {
          showFloatingToast(
            context,
            context.tr('error') ?? 'Lỗi',
            context.tr('err_save_home_props') ?? 'Không thể lưu thuộc tính nhà. Vui lòng thử lại!',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showFloatingToast(
          context,
          context.tr('error') ?? 'Lỗi',
          '${context.tr('err_save_home_props') ?? 'Lỗi khi lưu:'} $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryThemeColor = HomeHelper.getThemeColor(_selectedColorHex);
    final homeIconData = HomeHelper.getIconData(_selectedIcon);
    final homeTypeLabel = HomeHelper.getHomeTypeLabel(_selectedType, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 12,
                      padding: const EdgeInsets.all(8),
                      glowColor: primaryThemeColor,
                      surfaceColor: primaryThemeColor.withOpacity(0.16),
                      child: Icon(Icons.palette_rounded, color: primaryThemeColor, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        context.tr('home_customization_title') ?? 'Thuộc tính & Bộ quy tắc',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ZenGlassIconButton(
                icon: Icons.close_rounded,
                size: 34,
                iconSize: 18,
                borderRadius: 11,
                blurSigma: 0,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content scrollable
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LIVE PREVIEW CARD (LIQUID GLASS 2.0) ---
                  ZenGlassCard(
                    blurSigma: 0,
                    borderRadius: 22,
                    isActive: true,
                    glowColor: primaryThemeColor,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryThemeColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: primaryThemeColor.withOpacity(0.42),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(homeIconData, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nameController.text.trim().isEmpty
                                    ? (context.tr('hint_home_name') ?? 'Tên ngôi nhà')
                                    : _nameController.text.trim(),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  ZenGlassPill(
                                    blurSigma: 0,
                                    borderRadius: 8,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    isSelected: true,
                                    glowColor: primaryThemeColor,
                                    child: Text(
                                      homeTypeLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: primaryThemeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${_activeRules.length} quy tắc đang bật',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. TÊN NGÔI NHÀ
                  _buildSectionTitle(context.tr('enter_home_name') ?? 'Tên ngôi nhà:', isDark),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    onChanged: (val) => setState(() {}),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: zenGlassInputDecoration(
                      context,
                      hintText: context.tr('hint_home_name') ?? 'Ví dụ: Căn hộ Times City, Biệt thự...',
                      prefixIcon: Icons.home_rounded,
                      accentColor: primaryThemeColor,
                      borderRadius: 16,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. LOẠI HÌNH NGÔI NHÀ (Home Type)
                  _buildSectionTitle(context.tr('home_type_title') ?? 'Loại hình ngôi nhà:', isDark),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: HomeHelper.availableHomeTypes.map((type) {
                      final isSelected = type['id'] == _selectedType;
                      final typeLabel = context.tr(type['labelKey']) ?? type['defaultLabel'];
                      final typeIcon = type['icon'] as IconData;

                      return ZenGlassPill(
                        blurSigma: 0,
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isSelected: isSelected,
                        glowColor: primaryThemeColor,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedType = type['id']);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              typeIcon,
                              size: 16,
                              color: isSelected
                                  ? primaryThemeColor
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? primaryThemeColor
                                    : (isDark ? Colors.white : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // 3. BIỂU TƯỢNG ĐẠI DIỆN (Home Icon)
                  _buildSectionTitle(context.tr('home_icon_title') ?? 'Biểu tượng nhận diện:', isDark),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 58,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: HomeHelper.availableIcons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) {
                        final item = HomeHelper.availableIcons[idx];
                        final isSelected = item['id'] == _selectedIcon;
                        final icon = item['icon'] as IconData;

                        return BouncingButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIcon = item['id']);
                          },
                          child: ZenLiquidGlass(
                            width: 54,
                            height: 54,
                            borderRadius: 27,
                            blurSigma: 0,
                            alignment: Alignment.center,
                            glowColor: isSelected ? primaryThemeColor : null,
                            surfaceColor: isSelected
                                ? primaryThemeColor
                                : (isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.72)),
                            customShadows: isSelected
                                ? [
                                    BoxShadow(
                                      color: primaryThemeColor.withOpacity(0.40),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : const [],
                            child: Icon(
                              icon,
                              size: 24,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. MÀU SẮC CHỦ ĐẠO (Theme Color)
                  _buildSectionTitle(context.tr('home_color_title') ?? 'Màu sắc chủ đạo:', isDark),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: HomeHelper.availableColors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final colorItem = HomeHelper.availableColors[idx];
                        final hex = colorItem['hex'] as String;
                        final color = colorItem['color'] as Color;
                        final isSelected = hex.toLowerCase() == _selectedColorHex.toLowerCase();

                        return BouncingButton(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColorHex = hex);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white.withOpacity(0.22),
                                width: isSelected ? 2.6 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(isSelected ? 0.52 : 0.20),
                                  blurRadius: isSelected ? 10 : 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. BỘ QUY TẮC ĐẶC THÙ CHO THUỘC TÍNH NHÀ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(context.tr('home_rules_title') ?? 'Bộ quy tắc đặc thù:', isDark),
                      ZenGlassPill(
                        blurSigma: 0,
                        borderRadius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3),
                        isSelected: true,
                        glowColor: primaryThemeColor,
                        child: Text(
                          '${_activeRules.length}/${HomeHelper.ruleDefinitions.length} kích hoạt',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primaryThemeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('home_rules_desc') ?? 'Kích hoạt các quy tắc hành vi thông minh tự động áp dụng riêng cho ngôi nhà này:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Danh sách các quy tắc dạng Kính Lỏng
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: HomeHelper.ruleDefinitions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final rule = HomeHelper.ruleDefinitions[idx];
                      final isEnabled = _activeRules.contains(rule.id);
                      final isRecommended = rule.recommendedTypes.contains(_selectedType);
                      final title = context.tr(rule.titleKey) ?? rule.defaultTitle;
                      final desc = context.tr(rule.descKey) ?? rule.defaultDesc;

                      return ZenGlassCard(
                        blurSigma: 0,
                        borderRadius: 18,
                        isActive: isEnabled,
                        glowColor: primaryThemeColor,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ZenLiquidGlass(
                              blurSigma: 0,
                              borderRadius: 12,
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(top: 2),
                              glowColor: isEnabled ? primaryThemeColor : null,
                              surfaceColor: isEnabled
                                  ? primaryThemeColor.withOpacity(0.20)
                                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.75)),
                              child: Icon(
                                rule.icon,
                                size: 18,
                                color: isEnabled
                                    ? primaryThemeColor
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      if (isRecommended) ...[
                                        const SizedBox(width: 6),
                                        ZenGlassPill(
                                          blurSigma: 0,
                                          borderRadius: 6,
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          isSelected: true,
                                          glowColor: AppColors.amberGlow,
                                          child: Text(
                                            'Khuyên dùng',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? AppColors.amberGlow : Colors.amber.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    desc,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Switch(
                              value: isEnabled,
                              activeColor: primaryThemeColor,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (val) {
                                    _activeRules.add(rule.id);
                                  } else {
                                    _activeRules.remove(rule.id);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                isLoading: _isSaving,
                accentColor: primaryThemeColor,
                icon: Icons.check_circle_rounded,
                label: context.tr('btn_save_changes') ?? 'Lưu thay đổi',
                onPressed: _handleSave,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
      ),
    );
  }
}
