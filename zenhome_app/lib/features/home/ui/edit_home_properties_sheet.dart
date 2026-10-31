import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';

/// BottomSheet tùy chỉnh Thuộc tính, Biểu tượng, Màu sắc và Bộ quy tắc ngôi nhà
void showEditHomePropertiesBottomSheet(
  BuildContext context,
  WidgetRef ref,
  SmartConfig home,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    elevation: 0,
    barrierColor: Colors.black.withOpacity(0.6),
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101625) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryThemeColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.palette_rounded, color: primaryThemeColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('home_customization_title') ?? 'Thuộc tính & Bộ quy tắc',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.close_rounded, size: 22),
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Content scrollable
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LIVE PREVIEW CARD ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryThemeColor.withOpacity(0.18),
                          primaryThemeColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: primaryThemeColor.withOpacity(0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: primaryThemeColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: primaryThemeColor.withOpacity(0.4),
                                blurRadius: 12,
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: primaryThemeColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
                                  Text(
                                    '${_activeRules.length} quy tắc đang bật',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                    decoration: InputDecoration(
                      hintText: context.tr('hint_home_name') ?? 'Ví dụ: Căn hộ Times City, Biệt thự...',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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

                      return BouncingButton(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedType = type['id']);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryThemeColor.withOpacity(0.18)
                                : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? primaryThemeColor
                                  : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                typeIcon,
                                size: 16,
                                color: isSelected ? primaryThemeColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? primaryThemeColor : (isDark ? Colors.white : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryThemeColor
                                  : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? primaryThemeColor
                                    : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0)),
                                width: 2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: primaryThemeColor.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
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
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(isSelected ? 0.5 : 0.2),
                                  blurRadius: isSelected ? 8 : 4,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: primaryThemeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
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

                  // Danh sách các quy tắc
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

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? primaryThemeColor.withOpacity(isDark ? 0.16 : 0.06)
                              : (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF8FAFC)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isEnabled
                                ? primaryThemeColor.withOpacity(0.35)
                                : (isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE2E8F0)),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isEnabled
                                    ? primaryThemeColor.withOpacity(0.2)
                                    : (isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Khuyên dùng',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade800,
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.only(top: 12),
            width: double.infinity,
            child: BouncingButton(
              onTap: _isSaving ? null : _handleSave,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryThemeColor, primaryThemeColor.withOpacity(0.85)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryThemeColor.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('btn_save_changes') ?? 'Lưu thay đổi',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
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
