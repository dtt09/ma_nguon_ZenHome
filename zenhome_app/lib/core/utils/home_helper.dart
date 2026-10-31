import 'package:flutter/material.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

/// Metadata định nghĩa một quy tắc đặc thù cho ngôi nhà
class HomeRuleDefinition {
  final String id;
  final String titleKey;
  final String defaultTitle;
  final String descKey;
  final String defaultDesc;
  final IconData icon;
  final List<String> recommendedTypes;

  const HomeRuleDefinition({
    required this.id,
    required this.titleKey,
    required this.defaultTitle,
    required this.descKey,
    required this.defaultDesc,
    required this.icon,
    this.recommendedTypes = const [],
  });
}

/// Helper quản lý biểu tượng, màu sắc, loại hình và bộ quy tắc ngôi nhà
class HomeHelper {
  // --- BỘ ICON NGÔI NHÀ ---
  static const Map<String, IconData> iconMap = {
    'home': Icons.home_rounded,
    'villa': Icons.villa_rounded,
    'apartment': Icons.apartment_rounded,
    'cottage': Icons.cottage_rounded,
    'business': Icons.business_rounded,
    'nature': Icons.nature_people_rounded,
    'beach_access': Icons.beach_access_rounded,
    'store': Icons.storefront_rounded,
    'castle': Icons.castle_rounded,
    'warehouse': Icons.warehouse_rounded,
  };

  static const List<Map<String, dynamic>> availableIcons = [
    {'id': 'home', 'label': 'Nhà phố', 'icon': Icons.home_rounded},
    {'id': 'villa', 'label': 'Biệt thự', 'icon': Icons.villa_rounded},
    {'id': 'apartment', 'label': 'Căn hộ', 'icon': Icons.apartment_rounded},
    {'id': 'cottage', 'label': 'Nhà vườn', 'icon': Icons.cottage_rounded},
    {'id': 'business', 'label': 'Văn phòng', 'icon': Icons.business_rounded},
    {'id': 'nature', 'label': 'Sinh thái', 'icon': Icons.nature_people_rounded},
    {'id': 'beach_access', 'label': 'Ven biển', 'icon': Icons.beach_access_rounded},
    {'id': 'store', 'label': 'Cửa hàng', 'icon': Icons.storefront_rounded},
    {'id': 'castle', 'label': 'Dinh thự', 'icon': Icons.castle_rounded},
    {'id': 'warehouse', 'label': 'Kho xưởng', 'icon': Icons.warehouse_rounded},
  ];

  // --- BỘ MÀU CHỦ ĐẠO ---
  static const List<Map<String, dynamic>> availableColors = [
    {'hex': '#0F766E', 'label': 'Xanh ngọc Zen', 'color': Color(0xFF0F766E)},
    {'hex': '#2563EB', 'label': 'Xanh hoàng gia', 'color': Color(0xFF2563EB)},
    {'hex': '#7C3AED', 'label': 'Tím hiện đại', 'color': Color(0xFF7C3AED)},
    {'hex': '#EA580C', 'label': 'Cam năng lượng', 'color': Color(0xFFEA580C)},
    {'hex': '#059669', 'label': 'Lục bảo', 'color': Color(0xFF059669)},
    {'hex': '#E11D48', 'label': 'Đỏ Ruby', 'color': Color(0xFFE11D48)},
    {'hex': '#D97706', 'label': 'Hổ phách', 'color': Color(0xFFD97706)},
    {'hex': '#475569', 'label': 'Xám cẩm thạch', 'color': Color(0xFF475569)},
  ];

  // --- BỘ LOẠI HÌNH NGÔI NHÀ ---
  static const List<Map<String, dynamic>> availableHomeTypes = [
    {'id': 'townhouse', 'labelKey': 'home_type_townhouse', 'defaultLabel': 'Nhà phố', 'icon': Icons.home_rounded},
    {'id': 'apartment', 'labelKey': 'home_type_apartment', 'defaultLabel': 'Chung cư', 'icon': Icons.apartment_rounded},
    {'id': 'villa', 'labelKey': 'home_type_villa', 'defaultLabel': 'Biệt thự', 'icon': Icons.villa_rounded},
    {'id': 'countryside', 'labelKey': 'home_type_countryside', 'defaultLabel': 'Nhà vườn', 'icon': Icons.cottage_rounded},
    {'id': 'office', 'labelKey': 'home_type_office', 'defaultLabel': 'Văn phòng', 'icon': Icons.business_rounded},
    {'id': 'store', 'labelKey': 'home_type_store', 'defaultLabel': 'Cửa hàng', 'icon': Icons.storefront_rounded},
  ];

  // --- BỘ QUY TẮC ĐẶC THÙ CHO THUỘC TÍNH NHÀ ---
  static const List<HomeRuleDefinition> ruleDefinitions = [
    HomeRuleDefinition(
      id: 'rule_night_security',
      titleKey: 'rule_night_security_title',
      defaultTitle: 'Bảo vệ an ninh ban đêm',
      descKey: 'rule_night_security_desc',
      defaultDesc: 'Tự động kích hoạt giám sát cảm biến & khóa cửa sau 23:00. Báo động tức thì nếu có xâm nhập.',
      icon: Icons.shield_rounded,
      recommendedTypes: ['townhouse', 'villa', 'countryside', 'store'],
    ),
    HomeRuleDefinition(
      id: 'rule_energy_saving',
      titleKey: 'rule_energy_saving_title',
      defaultTitle: 'Tiết kiệm điện khi rời nhà',
      descKey: 'rule_energy_saving_desc',
      defaultDesc: 'Tự động ngắt điều hòa, bình nóng lạnh và thiết bị tải nặng khi chủ nhà rời khỏi khu vực.',
      icon: Icons.eco_rounded,
      recommendedTypes: ['townhouse', 'apartment', 'villa', 'office'],
    ),
    HomeRuleDefinition(
      id: 'rule_outdoor_lighting',
      titleKey: 'rule_outdoor_lighting_title',
      defaultTitle: 'Chiếu sáng cảnh quan tự động',
      descKey: 'rule_outdoor_lighting_desc',
      defaultDesc: 'Bật đèn sân vườn, ban công hoặc bảng hiệu từ 18:00 đến 23:00 hàng ngày.',
      icon: Icons.wb_twilight_rounded,
      recommendedTypes: ['villa', 'countryside', 'store'],
    ),
    HomeRuleDefinition(
      id: 'rule_fire_gas_priority',
      titleKey: 'rule_fire_gas_priority_title',
      defaultTitle: 'Ưu tiên khẩn cấp Hỏa hoạn & Khí Gas',
      descKey: 'rule_fire_gas_priority_desc',
      defaultDesc: 'Cảnh báo còi báo động tối đa và đẩy thông báo khẩn cấp ngay cả khi điện thoại bật Không làm phiền.',
      icon: Icons.local_fire_department_rounded,
      recommendedTypes: ['townhouse', 'apartment', 'villa', 'countryside', 'office', 'store'],
    ),
    HomeRuleDefinition(
      id: 'rule_office_workhours',
      titleKey: 'rule_office_workhours_title',
      defaultTitle: 'Giờ làm việc tập trung (08:00 - 18:00)',
      descKey: 'rule_office_workhours_desc',
      defaultDesc: 'Tự động duy trì ánh sáng làm việc chuẩn và ổn định nhiệt độ điều hòa 25°C trong giờ hành chính.',
      icon: Icons.work_outline_rounded,
      recommendedTypes: ['office', 'store'],
    ),
    HomeRuleDefinition(
      id: 'rule_vacation_simulation',
      titleKey: 'rule_vacation_simulation_title',
      defaultTitle: 'Giả lập có người ở nhà khi đi vắng',
      descKey: 'rule_vacation_simulation_desc',
      defaultDesc: 'Bật/tắt ngẫu nhiên một số bóng đèn vào buổi tối để phòng chống trộm khi bạn đi du lịch hoặc công tác.',
      icon: Icons.flight_takeoff_rounded,
      recommendedTypes: ['townhouse', 'apartment', 'villa'],
    ),
    HomeRuleDefinition(
      id: 'rule_quiet_hours',
      titleKey: 'rule_quiet_hours_title',
      defaultTitle: 'Khung giờ yên tĩnh nghỉ ngơi (22:00 - 06:00)',
      descKey: 'rule_quiet_hours_desc',
      defaultDesc: 'Giảm độ sáng đèn đêm hành lang xuống mức 20% và tắt âm bíp phản hồi để không làm phiền giấc ngủ.',
      icon: Icons.bedtime_rounded,
      recommendedTypes: ['townhouse', 'apartment', 'villa'],
    ),
  ];

  /// Lấy IconData từ iconId
  static IconData getIconData(String? iconId) {
    if (iconId == null || iconId.isEmpty) return Icons.home_rounded;
    return iconMap[iconId] ?? Icons.home_rounded;
  }

  /// Lấy Color từ hex string
  static Color getThemeColor(String? hexColor, {Color defaultColor = const Color(0xFF0F766E)}) {
    if (hexColor == null || hexColor.isEmpty) return defaultColor;
    try {
      String cleanHex = hexColor.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  /// Lấy nhãn loại hình nhà được bản địa hóa
  static String getHomeTypeLabel(String? homeType, BuildContext context) {
    final match = availableHomeTypes.firstWhere(
      (t) => t['id'] == homeType,
      orElse: () => {'id': 'townhouse', 'labelKey': 'home_type_townhouse', 'defaultLabel': 'Nhà phố'},
    );
    final key = match['labelKey'] as String;
    final fallback = match['defaultLabel'] as String;
    return context.tr(key) ?? fallback;
  }
}
