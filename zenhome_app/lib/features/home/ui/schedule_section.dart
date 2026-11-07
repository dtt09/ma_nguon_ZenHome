import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class ScheduleSection extends ConsumerStatefulWidget {
  const ScheduleSection({super.key});

  @override
  ConsumerState<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends ConsumerState<ScheduleSection> {
  List<Map<String, dynamic>> _savedSchedules = [];
  StreamSubscription<QuerySnapshot>? _schedulesSubscription;

  @override
  void initState() {
    super.initState();
    _loadSchedulesFromDisk();
    _subscribeToFirestoreSchedules();
  }

  @override
  void dispose() {
    _schedulesSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToFirestoreSchedules() {
    _schedulesSubscription?.cancel();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    if (targetId.isEmpty || targetId == 'guest') return;

    _schedulesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(targetId)
        .collection('schedules')
        .snapshots()
        .listen((snap) async {
      final prefs = await SharedPreferences.getInstance();
      String? schedulesString = prefs.getString('schedules_data_$targetId');
      List<dynamic> localRaw = (schedulesString != null) ? jsonDecode(schedulesString) : [];
      // CHỈ giữ lại lịch cá nhân cục bộ, loại bỏ triệt để lịch chia sẻ cũ đã bị xóa trên Firestore (Chống Zombie Document)
      List<dynamic> localPersonalSchedules = localRaw.where((e) => e['isShared'] != true).toList();
      List<dynamic> firestoreSchedules = snap.docs.map((doc) => doc.data()).toList();

      List<Map<String, dynamic>> combined = [];
      combined.addAll(localPersonalSchedules.map((e) => Map<String, dynamic>.from(e)));
      combined.addAll(firestoreSchedules.map((e) => Map<String, dynamic>.from(e)));

      Map<String, Map<String, dynamic>> uniqueMap = {};
      for (var item in combined) {
        if (item['id'] != null) {
          uniqueMap[item['id']] = item;
        }
      }

      if (mounted) {
        setState(() {
          _savedSchedules = uniqueMap.values.map((item) => {
            'id': item['id'],
            'topic': item['topic'],
            'topics': item['topics'] != null ? List<String>.from(item['topics']) : (item['topic'] != null ? [item['topic']] : []),
            'timeOn': item['timeOn'],
            'timeOff': item['timeOff'],
            'days': List<bool>.from(item['days'] ?? List.filled(7, true)),
            'isActive': item['isActive'] ?? true,
            'isShared': item['isShared'] ?? false,
            'authorUid': item['authorUid'] ?? '',
            'authorName': item['authorName'] ?? '',
          }).toList();
        });
      }
    }, onError: (err) {
      debugPrint("Lỗi stream schedules: $err");
    });
  }

  Widget _buildSelector({
    required String title,
    required String valueText,
    required VoidCallback onTap,
    IconData icon = Icons.devices_rounded,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    return ZenLiquidGlass(
      blurSigma: 0,
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      glowColor: zen.primary,
      surfaceColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.white.withOpacity(0.68),
      customShadows: const [],
      onTap: onTap,
      child: Row(
        children: [
          ZenLiquidGlass(
            blurSigma: 0,
            borderRadius: 12,
            padding: const EdgeInsets.all(9),
            glowColor: zen.primary,
            surfaceColor: zen.primary.withOpacity(isDark ? 0.20 : 0.12),
            customShadows: const [],
            child: Icon(
              icon,
              color: isDark ? zen.primaryAccent : zen.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            Icons.keyboard_arrow_right_rounded,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildPresetPill({
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ZenGlassPill(
      blurSigma: 0,
      borderRadius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        ),
      ),
    );
  }

  Future<void> _loadSchedulesFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    
    // Migration: nếu có dữ liệu cũ chưa có targetId, nạp nó lên và sau đó xóa
    String? schedulesString = prefs.getString('schedules_data_$targetId');
    if (schedulesString == null && prefs.containsKey('schedules_data')) {
      schedulesString = prefs.getString('schedules_data');
      prefs.remove('schedules_data');
    }
    
    List<dynamic> localSchedules = [];
    if (schedulesString != null) {
      localSchedules = jsonDecode(schedulesString);
    }
    
    List<dynamic> sharedSchedules = [];
    if (targetId.isNotEmpty && targetId != 'guest') {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .collection('schedules')
            .get();
        for (var doc in snap.docs) {
          sharedSchedules.add(doc.data());
        }
      } catch (e) {
        debugPrint("Error fetching shared schedules: $e");
      }
    }
    
    List<Map<String, dynamic>> combined = [];
    combined.addAll(localSchedules.map((e) => Map<String, dynamic>.from(e)));
    combined.addAll(sharedSchedules.map((e) => Map<String, dynamic>.from(e)));
    
    Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var item in combined) {
      uniqueMap[item['id']] = item;
    }

    setState(() {
      _savedSchedules = uniqueMap.values.map((item) => {
        'id': item['id'],
        'topic': item['topic'],
        'topics': item['topics'] != null ? List<String>.from(item['topics']) : (item['topic'] != null ? [item['topic']] : []),
        'timeOn': item['timeOn'],
        'timeOff': item['timeOff'],
        'days': List<bool>.from(item['days']),
        'isActive': item['isActive'],
        'isShared': item['isShared'] ?? false,
        'authorUid': item['authorUid'] ?? '',
        'authorName': item['authorName'] ?? '',
      }).toList();
    });
  }

  Future<void> _saveSchedulesToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final localSchedules = _savedSchedules.where((e) => e['isShared'] != true).toList();
    final String encodedData = jsonEncode(localSchedules);
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    await prefs.setString('schedules_data_$targetId', encodedData);
  }

  bool _canManageSchedule(Map<String, dynamic> schedule) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isShared = schedule['isShared'] == true;
    final String authorUid = schedule['authorUid'] ?? '';

    // Lịch cá nhân: chỉ tác giả
    if (!isShared) {
      return authorUid.isEmpty || authorUid == currentUid;
    }

    // Chủ nhà & Phó chủ nhà: toàn quyền
    if (activeConfig.role == 'owner' || activeConfig.role == 'co_owner') {
      return true;
    }

    // Thành viên được cấp quyền tự động hóa
    if (activeConfig.canEditAutomation) {
      return true;
    }

    // Tác giả tự tạo lịch trình chia sẻ
    if (authorUid.isNotEmpty && authorUid == currentUid) {
      return true;
    }

    return false;
  }

  bool _checkConflict(List<String> newDevices, TimeOfDay timeOn, TimeOfDay timeOff, List<bool> newDays, String? ignoreId) {
    int startMins = timeOn.hour * 60 + timeOn.minute;
    int endMins = timeOff.hour * 60 + timeOff.minute;
    if (endMins <= startMins) endMins += 24 * 60;
    
    for (var s in _savedSchedules) {
      if (s['id'] == ignoreId) continue;
      
      List<String> sTopics = List<String>.from(s['topics'] ?? (s['topic'] != null ? [s['topic']] : []));
      bool hasSameDevice = false;
      for (String dev in newDevices) {
        if (sTopics.contains(dev)) { hasSameDevice = true; break; }
      }
      if (!hasSameDevice) continue;

      bool hasSameDay = false;
      for (int i = 0; i < 7; i++) { 
        if (newDays[i] && s['days'][i]) { hasSameDay = true; break; } 
      }
      
      if (!hasSameDay) continue;
      
      List<String> sOn = s['timeOn'].split(':');
      List<String> sOff = s['timeOff'].split(':');
      int exStartMins = int.parse(sOn[0]) * 60 + int.parse(sOn[1]);
      int exEndMins = int.parse(sOff[0]) * 60 + int.parse(sOff[1]);
      
      if (exEndMins <= exStartMins) exEndMins += 24 * 60;
      if (startMins < exEndMins && endMins > exStartMins) return true;
    }
    return false;
  }

  void _showScheduleBottomSheet({Map<String, dynamic>? editSchedule}) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    // Kiểm tra nếu tài khoản đang bị Chủ nhà tạm khóa
    if (activeConfig.isDisabled) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('member_disabled_msg') ?? 'Tài khoản của bạn đã bị Chủ nhà tạm khóa quyền điều khiển!',
        isError: true,
      );
      return;
    }

    // Kiểm tra quyền chỉnh sửa tự động hóa
    if (activeConfig.role != 'owner' && activeConfig.role != 'co_owner' && !activeConfig.canEditAutomation) {
      showFloatingToast(
        context,
        context.tr('error'),
        'Bạn chưa được cấp quyền quản lý tự động hóa.',
        isError: true,
      );
      return;
    }

    final allTopics = getSortedDeviceTopicsList(context, activeConfig);
    final dynamicDeviceTopicsList = allTopics.where((topic) {
      if (activeConfig.role == 'owner' || activeConfig.role == 'co_owner' || activeConfig.allowedDevices == null) {
        return true;
      }
      final devId = topic.split('/').last;
      return activeConfig.allowedDevices!.contains(devId);
    }).toList();

    if (dynamicDeviceTopicsList.isEmpty) {
      showFloatingToast(context, context.tr('error'), 'Bạn không có quyền điều khiển thiết bị nào để tạo lịch trình.', isError: true);
      return;
    }

    bool isEdit = editSchedule != null;
    List<String> newDevices = isEdit 
      ? List<String>.from(editSchedule['topics'] ?? (editSchedule['topic'] != null ? [editSchedule['topic']] : [])) 
      : (dynamicDeviceTopicsList.isNotEmpty ? [dynamicDeviceTopicsList.first] : []);
    TimeOfDay timeOn = isEdit ? TimeOfDay(hour: int.parse(editSchedule['timeOn'].split(':')[0]), minute: int.parse(editSchedule['timeOn'].split(':')[1])) : const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay timeOff = isEdit ? TimeOfDay(hour: int.parse(editSchedule['timeOff'].split(':')[0]), minute: int.parse(editSchedule['timeOff'].split(':')[1])) : const TimeOfDay(hour: 6, minute: 0);
    List<bool> selectedDays = isEdit ? List<bool>.from(editSchedule['days']) : [true, true, true, true, true, true, true];
    bool _shareWithAll = isEdit ? (editSchedule['isShared'] ?? false) : false;
    final List<String> dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    String calculateDuration(TimeOfDay on, TimeOfDay off) {
      int start = on.hour * 60 + on.minute;
      int end = off.hour * 60 + off.minute;
      if (end <= start) end += 24 * 60;
      int diff = end - start;
      int h = diff ~/ 60;
      int m = diff % 60;
      if (m == 0) return '$h giờ';
      return '$h giờ $m phút';
    }

    showZenGlassBottomSheet(
      context: context,
      maxHeightFactor: 0.90,
      accentColor: context.zenColors.primary,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
            final zen = ctx.zenColors;
            final durationStr = calculateDuration(timeOn, timeOff);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 6,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).padding.bottom +
                    22,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ZenLiquidGlass(
                        blurSigma: 0,
                        width: 46,
                        height: 46,
                        borderRadius: 15,
                        alignment: Alignment.center,
                        customGradient: zen.brandHero,
                        glowColor: zen.primary,
                        rimWidth: 1.3,
                        customShadows: [
                          BoxShadow(
                            color: zen.primary.withOpacity(isDark ? 0.36 : 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit
                                  ? context.tr('schedule_edit')
                                  : context.tr('schedule_add'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('schedule_auto_desc'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ZenGlassIconButton(
                        icon: Icons.close_rounded,
                        size: 38,
                        iconSize: 19,
                        blurSigma: 0,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildSelector(
                    title: context.tr('select_device'),
                    valueText: newDevices.isEmpty
                        ? context.tr('select_device')
                        : newDevices
                            .map((t) => getDeviceNameHelper(context, t, activeConfig))
                            .join(', '),
                    icon: Icons.devices_rounded,
                    onTap: () {
                      showCustomMultiSelectBottomSheetPicker(
                        context: ctx,
                        title: context.tr('select_device'),
                        currentValues: newDevices,
                        items: dynamicDeviceTopicsList
                            .map((topic) => PickerItem(
                                topic, getDeviceNameHelper(context, topic, activeConfig)))
                            .toList(),
                        onSelected: (val) => setModalState(() => newDevices = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 20,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          glowColor: AppColors.amberGlow,
                          rimWidth: 1.35,
                          surfaceColor: AppColors.amberGlow.withOpacity(isDark ? 0.14 : 0.12),
                          customGradient: LinearGradient(
                            colors: isDark
                                ? [
                                    AppColors.amberGlow.withOpacity(0.22),
                                    AppColors.amberDeep.withOpacity(0.08),
                                  ]
                                : [
                                    const Color(0xFFFFFBEB).withOpacity(0.88),
                                    const Color(0xFFFEF3C7).withOpacity(0.76),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          customShadows: [
                            BoxShadow(
                              color: AppColors.amberGlow.withOpacity(isDark ? 0.16 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: timeOn,
                            );
                            if (picked != null) setModalState(() => timeOn = picked);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: AppColors.amberGlow.withOpacity(0.22),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.wb_sunny_rounded,
                                      color: isDark
                                          ? AppColors.amberGlow
                                          : AppColors.amberDeep,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('schedule_turn_on'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFFB45309),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  timeOn.format(ctx),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF78350F),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('schedule_tap_to_change'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 20,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          glowColor: const Color(0xFF6366F1),
                          rimWidth: 1.35,
                          surfaceColor:
                              const Color(0xFF6366F1).withOpacity(isDark ? 0.14 : 0.12),
                          customGradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF6366F1).withOpacity(0.22),
                                    const Color(0xFF4338CA).withOpacity(0.08),
                                  ]
                                : [
                                    const Color(0xFFEEF2FF).withOpacity(0.88),
                                    const Color(0xFFE0E7FF).withOpacity(0.76),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          customShadows: [
                            BoxShadow(
                              color:
                                  const Color(0xFF6366F1).withOpacity(isDark ? 0.16 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: timeOff,
                            );
                            if (picked != null) setModalState(() => timeOff = picked);
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.22),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.nightlight_round,
                                      color: isDark
                                          ? const Color(0xFFA5B4FC)
                                          : const Color(0xFF4F46E5),
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      context.tr('schedule_turn_off'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isDark
                                            ? const Color(0xFFA5B4FC)
                                            : const Color(0xFF3730A3),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  timeOff.format(ctx),
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1E1B4B),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('schedule_tap_to_change'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : const Color(0xFF4338CA),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Center(
                    child: ZenGlassPill(
                      blurSigma: 0,
                      borderRadius: 20,
                      isSelected: true,
                      glowColor: zen.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            size: 15,
                            color: isDark ? zen.primaryAccent : zen.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${context.tr('schedule_activity_duration')}: $durationStr',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          context.tr('schedule_repeat'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildPresetPill(
                              label: context.tr('schedule_preset_all'),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  for (int i = 0; i < 7; i++) {
                                    selectedDays[i] = true;
                                  }
                                });
                              },
                            ),
                            _buildPresetPill(
                              label: context.tr('schedule_preset_weekdays'),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  for (int i = 0; i < 5; i++) {
                                    selectedDays[i] = true;
                                  }
                                  selectedDays[5] = false;
                                  selectedDays[6] = false;
                                });
                              },
                            ),
                            _buildPresetPill(
                              label: context.tr('schedule_preset_weekends'),
                              isDark: isDark,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setModalState(() {
                                  for (int i = 0; i < 5; i++) {
                                    selectedDays[i] = false;
                                  }
                                  selectedDays[5] = true;
                                  selectedDays[6] = true;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: List.generate(7, (index) {
                      final isSelected = selectedDays[index];
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: index < 6 ? 6 : 0),
                          child: ZenLiquidGlass(
                            blurSigma: 0,
                            height: 44,
                            borderRadius: 13,
                            alignment: Alignment.center,
                            glowColor: isSelected ? zen.primary : null,
                            rimWidth: isSelected ? 1.4 : 1.0,
                            customGradient: isSelected ? zen.navPillGradient : null,
                            surfaceColor: isSelected
                                ? null
                                : (isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.white.withOpacity(0.66)),
                            customShadows: isSelected
                                ? [
                                    BoxShadow(
                                      color: zen.primary.withOpacity(isDark ? 0.35 : 0.22),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : const [],
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(
                                  () => selectedDays[index] = !selectedDays[index]);
                            },
                            child: Text(
                              dayLabels[index],
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted),
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 18),

                  ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    glowColor: _shareWithAll ? zen.primary : null,
                    surfaceColor: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.white.withOpacity(0.68),
                    customShadows: const [],
                    child: Row(
                      children: [
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 11,
                          padding: const EdgeInsets.all(8.5),
                          glowColor: zen.primary,
                          surfaceColor: zen.primary.withOpacity(isDark ? 0.20 : 0.12),
                          customShadows: const [],
                          child: Icon(
                            Icons.people_alt_rounded,
                            color: isDark ? zen.primaryAccent : zen.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('share_with_all'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('schedule_shared_hint'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _shareWithAll,
                          onChanged: (val) => setModalState(() => _shareWithAll = val),
                          activeColor: isDark ? zen.primaryAccent : zen.primary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ZenGlassButton(
                      label: context.tr('schedule_save'),
                      icon: Icons.check_circle_outline_rounded,
                      isPrimary: true,
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      onPressed: () {
                        if (newDevices.isEmpty) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          showAlertDialogHelper(
                            context,
                            context.tr('error'),
                            context.tr('err_select_device'),
                            isError: true,
                          );
                          return;
                        }
                        if (!selectedDays.contains(true)) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          showAlertDialogHelper(
                            context,
                            context.tr('error'),
                            context.tr('err_select_day'),
                            isError: true,
                          );
                          return;
                        }
                        if (_checkConflict(
                          newDevices,
                          timeOn,
                          timeOff,
                          selectedDays,
                          isEdit ? editSchedule['id'] : null,
                        )) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          showAlertDialogHelper(
                            context,
                            context.tr('error'),
                            context.tr('err_conflict'),
                            isError: true,
                          );
                          return;
                        }

                        final mqttState = ref.read(mqttConnectionStateProvider);
                        final isOnline = ref.read(espOnlineStateProvider);
                        if (mqttState != 2 || !isOnline) {
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          showFloatingToast(
                            context,
                            context.tr('error'),
                            context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...',
                            isError: true,
                          );
                          return;
                        }

                        HapticFeedback.mediumImpact();

                        String hOn = timeOn.hour.toString().padLeft(2, '0');
                        String mOn = timeOn.minute.toString().padLeft(2, '0');
                        String hOff = timeOff.hour.toString().padLeft(2, '0');
                        String mOff = timeOff.minute.toString().padLeft(2, '0');
                        String daysBinary = selectedDays.map((d) => d ? '1' : '0').join('');
                        String newId = isEdit
                            ? editSchedule['id']
                            : DateTime.now().millisecondsSinceEpoch.toString();

                        for (String dev in newDevices) {
                          ref.read(mqttRepositoryProvider).publishCmd(
                              '$dev/schedule', '$newId|$hOn:$mOn|$hOff:$mOff|$daysBinary|1');
                        }

                        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        final currentName =
                            FirebaseAuth.instance.currentUser?.displayName ??
                                FirebaseAuth.instance.currentUser?.email ??
                                'Thành viên';
                        final authorUid =
                            isEdit ? (editSchedule['authorUid'] ?? currentUid) : currentUid;
                        final authorName = isEdit
                            ? (editSchedule['authorName'] ?? currentName)
                            : currentName;

                        Map<String, dynamic> newSchedule = {
                          'id': newId,
                          'topics': newDevices,
                          'timeOn': '$hOn:$mOn',
                          'timeOff': '$hOff:$mOff',
                          'days': List.from(selectedDays),
                          'isActive': true,
                          'isShared': _shareWithAll,
                          'authorUid': authorUid,
                          'authorName': authorName,
                        };

                        setState(() {
                          if (isEdit) {
                            int idx = _savedSchedules
                                .indexWhere((e) => e['id'] == editSchedule['id']);
                            if (idx != -1) _savedSchedules[idx] = newSchedule;
                          } else {
                            _savedSchedules.add(newSchedule);
                          }
                        });

                        final activeConfig = ref.read(homeConfigProvider).activeConfig;
                        String targetId = activeConfig.userId;
                        if (_shareWithAll &&
                            targetId.isNotEmpty &&
                            targetId != 'guest') {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(targetId)
                              .collection('schedules')
                              .doc(newId)
                              .set(newSchedule);

                          if (activeConfig.role != 'owner' &&
                              FirebaseAuth.instance.currentUser != null) {
                            String name =
                                FirebaseAuth.instance.currentUser!.displayName ??
                                    FirebaseAuth.instance.currentUser!.email ??
                                    context.tr('a_member') ??
                                    'Một thành viên';
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(targetId)
                                .collection('alerts')
                                .add({
                              'type': 'automation_edit',
                              'author': name,
                              'actionName': isEdit
                                  ? (context.tr('act_edit_schedule') ??
                                      'vừa sửa một lịch trình')
                                  : (context.tr('act_add_schedule') ??
                                      'vừa thêm một lịch trình mới'),
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          }
                        } else {
                          _saveSchedulesToDisk();
                        }
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        showAlertDialogHelper(
                          context,
                          context.tr('msg_saved_title'),
                          context.tr('msg_schedule_saved'),
                        );
                      },
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

  void _showViewOnlyScheduleBottomSheet(Map<String, dynamic> schedule) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    List<String> sTopics = List<String>.from(
        schedule['topics'] ?? (schedule['topic'] != null ? [schedule['topic']] : []));
    String deviceNames =
        sTopics.map((t) => getDeviceNameHelper(context, t, activeConfig)).join(', ');

    showZenGlassBottomSheet(
      context: context,
      accentColor: context.zenColors.primary,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        final zen = ctx.zenColors;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            22,
            6,
            22,
            MediaQuery.of(ctx).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ZenLiquidGlass(
                    blurSigma: 0,
                    width: 42,
                    height: 42,
                    borderRadius: 13,
                    alignment: Alignment.center,
                    glowColor: zen.primary,
                    surfaceColor: zen.primary.withOpacity(isDark ? 0.20 : 0.12),
                    customShadows: const [],
                    child: Icon(
                      Icons.remove_red_eye_rounded,
                      color: isDark ? zen.primaryAccent : zen.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('schedule_view_only'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  ZenGlassIconButton(
                    icon: Icons.close_rounded,
                    size: 36,
                    iconSize: 18,
                    blurSigma: 0,
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(
                Icons.devices_rounded,
                context.tr('device_label'),
                deviceNames,
                isDark,
                accentColor: isDark ? zen.primaryAccent : zen.primary,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                Icons.wb_sunny_rounded,
                context.tr('time_on_label'),
                schedule['timeOn'] ?? '',
                isDark,
                accentColor: isDark ? AppColors.amberGlow : AppColors.amberDeep,
              ),
              const SizedBox(height: 10),
              _buildDetailRow(
                Icons.nightlight_round,
                context.tr('time_off_label'),
                schedule['timeOff'] ?? '',
                isDark,
                accentColor: const Color(0xFF6366F1),
              ),
              if (schedule['authorName'] != null &&
                  schedule['authorName'].toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.person_rounded,
                  context.tr('schedule_author'),
                  schedule['authorName'],
                  isDark,
                  accentColor: isDark ? zen.primaryAccent : zen.primary,
                ),
              ],
              const SizedBox(height: 18),
              ZenLiquidGlass(
                blurSigma: 0,
                borderRadius: 14,
                padding: const EdgeInsets.all(12),
                glowColor: AppColors.amberGlow,
                surfaceColor: AppColors.amberGlow.withOpacity(isDark ? 0.14 : 0.10),
                customShadows: const [],
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? AppColors.amberGlow : AppColors.amberDeep,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('err_no_permission_schedule'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.amberGlow : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  label: context.tr('btn_close'),
                  icon: Icons.close_rounded,
                  isPrimary: false,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String value,
    bool isDark, {
    Color? accentColor,
  }) {
    final Color iconTint = accentColor ?? AppColors.cyanGlow;
    return ZenLiquidGlass(
      blurSigma: 0,
      borderRadius: 15,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      surfaceColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.white.withOpacity(0.68),
      customShadows: const [],
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6.5),
            decoration: BoxDecoration(
              color: iconTint.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: iconTint),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteSchedule(String id) {
    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);
    if (mqttState != 2 || !isOnline) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }
    
    showPremiumConfirmDialog(
      context: context,
      title: context.tr('confirm_title'),
      message: context.tr('confirm_delete_schedule'),
      confirmText: context.tr('btn_delete'),
      cancelText: context.tr('btn_cancel'),
      isDanger: true,
      icon: Icons.auto_delete_rounded,
      onConfirm: () {
        final scheduleToDel = _savedSchedules.firstWhere((s) => s['id'] == id);
        List<String> sTopics = List<String>.from(scheduleToDel['topics'] ?? (scheduleToDel['topic'] != null ? [scheduleToDel['topic']] : []));
        for (String topic in sTopics) {
          ref.read(mqttRepositoryProvider).publishCmd('$topic/schedule', '${scheduleToDel['id']}|00:00|00:00|0000000|0');
        }
        
        setState(() => _savedSchedules.removeWhere((s) => s['id'] == id));
        
        final activeConfig = ref.read(homeConfigProvider).activeConfig;
        String targetId = activeConfig.userId;
        if (scheduleToDel['isShared'] == true && targetId.isNotEmpty && targetId != 'guest') {
          FirebaseFirestore.instance.collection('users').doc(targetId).collection('schedules').doc(id).delete();
          
          if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null) {
            String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member');
            FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
              'type': 'automation_edit',
              'author': name,
              'actionName': context.tr('act_delete_schedule'),
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
        _saveSchedulesToDisk();
        
        showFloatingToast(context, context.tr('msg_deleted_title'), context.tr('msg_schedule_deleted_desc'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeConfigProvider, (previous, next) {
      if (previous?.activeConfig.userId != next.activeConfig.userId) {
        _schedulesSubscription?.cancel();
        _loadSchedulesFromDisk();
        _subscribeToFirestoreSchedules();
      }
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ZenLiquidGlass(
                    blurSigma: 0,
                    borderRadius: 11,
                    padding: const EdgeInsets.all(7.5),
                    glowColor: zen.primary,
                    surfaceColor: zen.primary.withOpacity(isDark ? 0.18 : 0.12),
                    customShadows: const [],
                    child: Icon(
                      Icons.alarm_on_rounded,
                      color: isDark ? zen.primaryAccent : zen.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.tr('schedule_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  if (_savedSchedules.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ZenGlassPill(
                      blurSigma: 0,
                      borderRadius: 10,
                      padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 2.5),
                      isSelected: true,
                      glowColor: zen.primary,
                      child: Text(
                        '${_savedSchedules.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isDark ? zen.primaryAccent : zen.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            BouncingButton(
              onTap: () => _showScheduleBottomSheet(),
              child: ZenLiquidGlass(
                blurSigma: 0,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
                customGradient: zen.navPillGradient,
                glowColor: zen.primary,
                rimWidth: 1.25,
                customShadows: [
                  BoxShadow(
                    color: zen.primary.withOpacity(isDark ? 0.35 : 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('btn_add') ?? 'Add',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_savedSchedules.isEmpty)
          ZenGlassCard(
            isActive: false,
            glowColor: zen.primary,
            blurSigma: 12,
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: Column(
                children: [
                  ZenLiquidGlass(
                    blurSigma: 0,
                    width: 56,
                    height: 56,
                    borderRadius: 18,
                    alignment: Alignment.center,
                    glowColor: zen.primary,
                    surfaceColor: zen.primary.withOpacity(isDark ? 0.14 : 0.09),
                    customShadows: const [],
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 26,
                      color: (isDark ? zen.primaryAccent : zen.primary).withOpacity(0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr('schedule_empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _savedSchedules.length,
            itemBuilder: (context, index) {
              final schedule = _savedSchedules[index];
              final bool isActive = schedule['isActive'] ?? false;
              final List<String> topics = List<String>.from(schedule['topics'] ??
                  (schedule['topic'] != null ? [schedule['topic']] : []));
              final String deviceNames = topics
                  .map((t) =>
                      getDeviceNameHelper(context, t, ref.watch(homeConfigProvider).activeConfig))
                  .join(', ');
              final bool isShared = schedule['isShared'] == true;

              return ZenGlassCard(
                isActive: isActive,
                glowColor: zen.primary,
                blurSigma: 12,
                borderRadius: 22,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Icon, device names, shared chip, and switch
                    Row(
                      children: [
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 14,
                          padding: const EdgeInsets.all(9.5),
                          glowColor: isActive ? zen.primary : null,
                          surfaceColor: isActive
                              ? zen.primary.withOpacity(isDark ? 0.22 : 0.14)
                              : (isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04)),
                          customShadows: const [],
                          child: Icon(
                            Icons.alarm_rounded,
                            color: isActive
                                ? (isDark ? zen.primaryAccent : zen.primary)
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                deviceNames,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (isShared)
                                ZenGlassPill(
                                  blurSigma: 0,
                                  borderRadius: 8,
                                  isSelected: true,
                                  glowColor: AppColors.cyanGlow,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people_outline_rounded,
                                        size: 11,
                                        color: isDark
                                            ? AppColors.cyanGlow
                                            : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          schedule['authorUid'] ==
                                                  FirebaseAuth.instance.currentUser?.uid
                                              ? '${context.tr('shared')} (${Localizations.localeOf(context).languageCode == 'en' ? 'You' : 'Bạn tạo'})'
                                              : ((schedule['authorName'] != null &&
                                                      schedule['authorName']
                                                          .toString()
                                                          .isNotEmpty)
                                                  ? '${context.tr('shared')} (${schedule['authorName']})'
                                                  : context.tr('shared')),
                                          style: TextStyle(
                                            color: isDark
                                                ? AppColors.cyanGlow
                                                : const Color(0xFF0284C7),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ZenGlassPill(
                                  blurSigma: 0,
                                  borderRadius: 8,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  child: Text(
                                    context.tr('private'),
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: isActive,
                            activeColor: isDark ? zen.primaryAccent : zen.primary,
                            onChanged: !_canManageSchedule(schedule)
                                ? null
                                : (val) {
                                    final mqttState =
                                        ref.read(mqttConnectionStateProvider);
                                    final isOnline = ref.read(espOnlineStateProvider);
                                    if (mqttState != 2 || !isOnline) {
                                      showFloatingToast(
                                        context,
                                        context.tr('error'),
                                        context.tr('toast_mqtt_wait') ??
                                            'Đang kết nối máy chủ...',
                                        isError: true,
                                      );
                                      return;
                                    }

                                    setState(() => schedule['isActive'] = val);
                                    String daysBinary = List<bool>.from(schedule['days'])
                                        .map((d) => d ? '1' : '0')
                                        .join('');
                                    String activeFlag = val ? '1' : '0';
                                    String payload =
                                        '${schedule['id']}|${schedule['timeOn']}|${schedule['timeOff']}|$daysBinary|$activeFlag';
                                    List<String> sTopics = List<String>.from(
                                        schedule['topics'] ??
                                            (schedule['topic'] != null
                                                ? [schedule['topic']]
                                                : []));
                                    for (String dev in sTopics) {
                                      ref
                                          .read(mqttRepositoryProvider)
                                          .publishCmd('$dev/schedule', payload);
                                    }

                                    final activeConfig =
                                        ref.read(homeConfigProvider).activeConfig;
                                    String targetId = activeConfig.userId;
                                    if (schedule['isShared'] == true &&
                                        targetId.isNotEmpty &&
                                        targetId != 'guest') {
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(targetId)
                                          .collection('schedules')
                                          .doc(schedule['id'])
                                          .update({'isActive': val});
                                    } else {
                                      _saveSchedulesToDisk();
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Glowing active time display
                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9.5),
                      glowColor: isActive ? zen.primary : null,
                      rimWidth: isActive ? 1.25 : 1.0,
                      surfaceColor: isActive
                          ? zen.primary.withOpacity(isDark ? 0.14 : 0.08)
                          : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.white.withOpacity(0.55)),
                      customShadows: isActive
                          ? [
                              BoxShadow(
                                color: zen.primary.withOpacity(isDark ? 0.22 : 0.10),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : const [],
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              size: 15,
                              color: isDark ? AppColors.amberGlow : AppColors.amberDeep,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${context.tr('status_on')}: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                            Text(
                              '${schedule['timeOn']}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: isActive
                                    ? (isDark ? Colors.white : AppColors.lightText)
                                    : (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted),
                                shadows: isActive && isDark
                                    ? [
                                        Shadow(
                                          color: AppColors.amberGlow.withOpacity(0.55),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 13,
                                color: isActive
                                    ? (isDark ? zen.primaryAccent : zen.primary)
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                            Icon(
                              Icons.nightlight_round,
                              size: 15,
                              color: isActive
                                  ? (isDark ? zen.primaryAccent : zen.primary)
                                  : const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${context.tr('status_off')}: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                            Text(
                              '${schedule['timeOff']}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: isActive
                                    ? (isDark ? Colors.white : AppColors.lightText)
                                    : (isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted),
                                shadows: isActive && isDark
                                    ? [
                                        Shadow(
                                          color: zen.primaryAccent.withOpacity(0.55),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 7-day glass pills & actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(7, (dayIndex) {
                                  final bool isActiveDay = schedule['days'][dayIndex];
                                  return ZenGlassPill(
                                    blurSigma: 0,
                                    borderRadius: 8,
                                    margin: EdgeInsets.only(right: dayIndex < 6 ? 5 : 0),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3.5),
                                    isSelected: isActiveDay && isActive,
                                    glowColor: zen.primary,
                                    color: isActiveDay ? zen.primary : null,
                                    child: Text(
                                      dayLabels[dayIndex],
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight:
                                            isActiveDay ? FontWeight.w800 : FontWeight.w600,
                                        color: isActiveDay
                                            ? (isActive
                                                ? (isDark ? zen.primaryAccent : zen.primary)
                                                : (isDark
                                                    ? AppColors.darkText
                                                    : AppColors.lightText))
                                            : (isDark
                                                ? AppColors.darkTextMuted.withOpacity(0.65)
                                                : AppColors.lightTextMuted
                                                    .withOpacity(0.75)),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_canManageSchedule(schedule)) ...[
                              ZenGlassIconButton(
                                icon: Icons.remove_red_eye_rounded,
                                size: 32,
                                iconSize: 16,
                                borderRadius: 10,
                                blurSigma: 0,
                                iconColor: isDark ? zen.primaryAccent : zen.primary,
                                glowColor: zen.primary,
                                onTap: () => _showViewOnlyScheduleBottomSheet(schedule),
                              ),
                            ] else ...[
                              ZenGlassIconButton(
                                icon: Icons.edit_rounded,
                                size: 32,
                                iconSize: 16,
                                borderRadius: 10,
                                blurSigma: 0,
                                iconColor: isDark ? zen.primaryAccent : zen.primary,
                                glowColor: zen.primary,
                                onTap: () =>
                                    _showScheduleBottomSheet(editSchedule: schedule),
                              ),
                              const SizedBox(width: 6),
                              ZenGlassIconButton(
                                icon: Icons.delete_outline_rounded,
                                size: 32,
                                iconSize: 16,
                                borderRadius: 10,
                                blurSigma: 0,
                                iconColor: AppColors.roseGlow,
                                glowColor: AppColors.roseGlow,
                                onTap: () => _deleteSchedule(schedule['id']),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
