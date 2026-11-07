import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/bouncing_button.dart';
import 'package:zenhome_app/core/widgets/luxury_slider.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class TimerSection extends ConsumerStatefulWidget {
  const TimerSection({super.key});

  @override
  ConsumerState<TimerSection> createState() => _TimerSectionState();
}

class _TimerSectionState extends ConsumerState<TimerSection> with SingleTickerProviderStateMixin {
  List<String> _timerDevices = [];
  String _timerAction = 'delay_off';
  double _timerMinutes = 30;
  List<Map<String, dynamic>> _timerHistory = [];
  StreamSubscription<QuerySnapshot>? _timersSubscription;
  late AnimationController _sliderAnimController;
  Animation<double>? _sliderAnimation;

  @override
  void initState() {
    super.initState();
    _sliderAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final allTopics = getSortedDeviceTopicsList(context, activeConfig);
    final dynamicDeviceTopicsList = allTopics.where((topic) {
      if (activeConfig.role == 'owner' || activeConfig.role == 'co_owner' || activeConfig.allowedDevices == null) {
        return true;
      }
      final devId = topic.split('/').last;
      return activeConfig.allowedDevices!.contains(devId);
    }).toList();
    if (dynamicDeviceTopicsList.isNotEmpty) {
      _timerDevices = [dynamicDeviceTopicsList.first];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateDefaultActionForDevice(_timerDevices.first);
      });
    }
    _loadTimerHistory();
    _subscribeToFirestoreTimers();
  }

  void _showCustomTimeDialog() {
    int currentTotalMinutes = _timerMinutes.round();
    int initialHours = (currentTotalMinutes ~/ 60).clamp(0, 24);
    int initialMinutes = (currentTotalMinutes % 60).clamp(0, 59);
    if (initialHours == 0 && initialMinutes == 0) {
      initialMinutes = 30;
    }

    final FixedExtentScrollController hourWheelCtrl =
        FixedExtentScrollController(initialItem: initialHours);
    final FixedExtentScrollController minWheelCtrl =
        FixedExtentScrollController(initialItem: initialMinutes);
    final TextEditingController hoursCtrl =
        TextEditingController(text: initialHours > 0 ? '$initialHours' : '0');
    final TextEditingController minutesCtrl =
        TextEditingController(text: '$initialMinutes');
    bool isSyncingWheel = false;

    showZenGlassBottomSheet(
      context: context,
      padBottomForKeyboard: true,
      accentColor: AppColors.amberGlow,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final amberText = isDark ? AppColors.amberGlow : AppColors.amberDeep;
            int h = int.tryParse(hoursCtrl.text.trim()) ?? 0;
            int m = int.tryParse(minutesCtrl.text.trim()) ?? 0;
            int totalMins = (h * 60) + m;

            String previewText;
            if (totalMins <= 0) {
              previewText = 'Vui lòng nhập thời gian lớn hơn 0';
            } else if (totalMins > 1440) {
              previewText = 'Thời gian tối đa 24 ${context.tr('hours')} (1440 ${context.tr('minutes')})';
            } else if (h > 0 && m > 0) {
              previewText = '$h ${context.tr('hours')} $m ${context.tr('minutes')} ($totalMins ${context.tr('minutes')})';
            } else if (h > 0) {
              previewText = '$h ${context.tr('hours')} ($totalMins ${context.tr('minutes')})';
            } else {
              previewText = '$m ${context.tr('minutes')}';
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row (showZenGlassBottomSheet already renders drag handle)
                    Row(
                      children: [
                        ZenLiquidGlass(
                          blurSigma: 0,
                          width: 40,
                          height: 40,
                          borderRadius: 13,
                          alignment: Alignment.center,
                          glowColor: AppColors.amberGlow,
                          surfaceColor: AppColors.amberGlow.withOpacity(isDark ? 0.20 : 0.14),
                          customShadows: const [],
                          child: const Icon(
                            Icons.hourglass_top_rounded,
                            color: AppColors.amberGlow,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _timerAction == 'delay_off'
                                ? context.tr('time_off_label')
                                : context.tr('time_on_label'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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
                    const SizedBox(height: 16),

                    // Frosted Glass Cupertino Wheel Picker Container (blurSigma: 0)
                    ZenLiquidGlass(
                      blurSigma: 0,
                      height: 146,
                      borderRadius: 20,
                      glowColor: AppColors.amberGlow,
                      surfaceColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.68),
                      customShadows: const [],
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          // Hours Wheel
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: hourWheelCtrl,
                              itemExtent: 38,
                              diameterRatio: 1.25,
                              magnification: 1.08,
                              useMagnifier: true,
                              selectionOverlay: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.amberGlow.withOpacity(isDark ? 0.16 : 0.12),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: AppColors.amberGlow.withOpacity(0.35),
                                  ),
                                ),
                              ),
                              onSelectedItemChanged: (val) {
                                if (isSyncingWheel) return;
                                HapticFeedback.selectionClick();
                                hoursCtrl.text = '$val';
                                if (val == 24 && (int.tryParse(minutesCtrl.text) ?? 0) > 0) {
                                  isSyncingWheel = true;
                                  minutesCtrl.text = '0';
                                  minWheelCtrl.jumpToItem(0);
                                  isSyncingWheel = false;
                                }
                                setDialogState(() {});
                              },
                              children: List.generate(25, (hr) {
                                return Center(
                                  child: Text(
                                    '$hr ${context.tr('hours')}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkText : AppColors.lightText,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 86,
                            color: isDark
                                ? Colors.white.withOpacity(0.10)
                                : const Color(0xFFCBD5E1).withOpacity(0.7),
                          ),
                          // Minutes Wheel
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: minWheelCtrl,
                              itemExtent: 38,
                              diameterRatio: 1.25,
                              magnification: 1.08,
                              useMagnifier: true,
                              selectionOverlay: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.amberGlow.withOpacity(isDark ? 0.16 : 0.12),
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: AppColors.amberGlow.withOpacity(0.35),
                                  ),
                                ),
                              ),
                              onSelectedItemChanged: (val) {
                                if (isSyncingWheel) return;
                                HapticFeedback.selectionClick();
                                minutesCtrl.text = '$val';
                                setDialogState(() {});
                              },
                              children: List.generate(60, (mn) {
                                return Center(
                                  child: Text(
                                    '$mn ${context.tr('minutes')}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkText : AppColors.lightText,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Two Direct Glass Input Fields: Giờ (Hours) & Phút (Minutes)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('hours_label'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: hoursCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                decoration: zenGlassInputDecoration(
                                  ctx,
                                  hintText: '0',
                                  borderRadius: 14,
                                  accentColor: AppColors.amberGlow,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                ).copyWith(
                                  suffixText: context.tr('hours'),
                                  suffixStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: amberText,
                                  ),
                                ),
                                onChanged: (txt) {
                                  final parsed = int.tryParse(txt.trim());
                                  if (parsed != null && parsed >= 0 && parsed <= 24 && hourWheelCtrl.hasClients) {
                                    isSyncingWheel = true;
                                    hourWheelCtrl.jumpToItem(parsed);
                                    isSyncingWheel = false;
                                  }
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('minutes_label'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: minutesCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                decoration: zenGlassInputDecoration(
                                  ctx,
                                  hintText: '0',
                                  borderRadius: 14,
                                  accentColor: AppColors.amberGlow,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                ).copyWith(
                                  suffixText: context.tr('minutes'),
                                  suffixStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: amberText,
                                  ),
                                ),
                                onChanged: (txt) {
                                  final parsed = int.tryParse(txt.trim());
                                  if (parsed != null && parsed >= 0 && parsed <= 59 && minWheelCtrl.hasClients) {
                                    isSyncingWheel = true;
                                    minWheelCtrl.jumpToItem(parsed);
                                    isSyncingWheel = false;
                                  }
                                  setDialogState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Hour Glass Pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [1, 2, 3, 4, 6, 8, 12, 24].map((hr) {
                        bool isHrSelected = h == hr && m == 0;
                        return ZenGlassPill(
                          blurSigma: 0,
                          borderRadius: 11,
                          isSelected: isHrSelected,
                          color: AppColors.amberGlow,
                          glowColor: AppColors.amberGlow,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            isSyncingWheel = true;
                            hoursCtrl.text = '$hr';
                            minutesCtrl.text = '0';
                            if (hourWheelCtrl.hasClients) {
                              hourWheelCtrl.animateToItem(
                                hr,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                              );
                            }
                            if (minWheelCtrl.hasClients) {
                              minWheelCtrl.animateToItem(
                                0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                              );
                            }
                            Future.delayed(const Duration(milliseconds: 240), () {
                              isSyncingWheel = false;
                            });
                            setDialogState(() {});
                          },
                          child: Text(
                            '$hr ${context.tr('hours')}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isHrSelected ? FontWeight.bold : FontWeight.w600,
                              color: isHrSelected
                                  ? amberText
                                  : (isDark ? AppColors.darkText : AppColors.lightText),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Frosted Glass Preview Banner
                    ZenLiquidGlass(
                      blurSigma: 0,
                      width: double.infinity,
                      borderRadius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      glowColor: AppColors.amberGlow,
                      surfaceColor: AppColors.amberGlow.withOpacity(isDark ? 0.14 : 0.10),
                      customShadows: const [],
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 18, color: amberText),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              previewText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: amberText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm ZenGlassButton
                    SizedBox(
                      width: double.infinity,
                      child: ZenGlassButton(
                        label: context.tr('btn_confirm'),
                        icon: Icons.check_circle_rounded,
                        isPrimary: true,
                        accentColor: AppColors.amberGlow,
                        onPressed: totalMins >= 1 && totalMins <= 1440
                            ? () {
                                _animateToMinutes(totalMins.toDouble());
                                Navigator.pop(ctx);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 350), () {
        hourWheelCtrl.dispose();
        minWheelCtrl.dispose();
        hoursCtrl.dispose();
        minutesCtrl.dispose();
      });
    });
  }

  void _animateToMinutes(double targetMinutes) {
    _sliderAnimController.stop();
    final double start = _timerMinutes;
    _sliderAnimation = Tween<double>(begin: start, end: targetMinutes).animate(
      CurvedAnimation(parent: _sliderAnimController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _timerMinutes = _sliderAnimation!.value;
        });
      });
    _sliderAnimController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _sliderAnimController.dispose();
    _timersSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToFirestoreTimers() {
    _timersSubscription?.cancel();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    if (targetId.isEmpty || targetId == 'guest') return;

    _timersSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(targetId)
        .collection('timers')
        .snapshots()
        .listen((snap) async {
      final prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString('timer_history_data_$targetId');
      List<dynamic> localRaw = (data != null) ? jsonDecode(data) : [];
      // CHỈ giữ lại timer cá nhân cục bộ, loại bỏ triệt để timer chia sẻ cũ đã bị xóa trên Firestore (Chống Zombie Document)
      List<dynamic> localPersonalTimers = localRaw.where((e) => e['isShared'] != true).toList();
      List<dynamic> firestoreTimers = snap.docs.map((doc) => doc.data()).toList();

      List<Map<String, dynamic>> combined = [];
      combined.addAll(localPersonalTimers.map((e) => Map<String, dynamic>.from(e)));
      combined.addAll(firestoreTimers.map((e) => Map<String, dynamic>.from(e)));

      Map<String, Map<String, dynamic>> uniqueMap = {};
      for (var item in combined) {
        if (item['id'] != null) {
          uniqueMap[item['id']] = item;
        }
      }

      int now = DateTime.now().millisecondsSinceEpoch;
      List<Map<String, dynamic>> finalList = uniqueMap.values.toList();
      for (var parsedItem in finalList) {
        if (parsedItem['status'] == 'active' && now > (parsedItem['targetTime'] ?? 0)) {
          parsedItem['status'] = 'completed';
        }
      }

      if (mounted) {
        setState(() {
          _timerHistory = finalList;
          _timerHistory.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));
        });
      }
    }, onError: (err) {
      debugPrint("Lỗi stream timers: $err");
    });
  }

  bool _isMultiDeviceMode = false;

  IconData _getDeviceIcon(String iconStr) {
    switch (iconStr) {
      case 'lightbulb_rounded': return Icons.lightbulb_rounded;
      case 'mode_fan_off': return Icons.mode_fan_off;
      case 'bedtime_rounded': return Icons.bedtime_rounded;
      case 'water_drop': return Icons.water_drop;
      default: return Icons.widgets_rounded;
    }
  }

  void _showDevicePicker(List<String> dynamicDeviceTopicsList, SmartConfig activeConfig) {
    final zenOuter = context.zenColors;
    showZenGlassBottomSheet(
      context: context,
      maxHeightFactor: 0.78,
      accentColor: zenOuter.primary,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final zen = ctx.zenColors;
            final states = ref.read(globalDeviceStatesProvider);

            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header & Single/Multi Mode Switcher (showZenGlassBottomSheet already renders drag handle)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                context.tr('select_device') ?? 'Chọn thiết bị hẹn giờ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 12),
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 16,
                          padding: const EdgeInsets.all(4),
                          surfaceColor: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.64),
                          customShadows: const [],
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() {
                                      _isMultiDeviceMode = false;
                                      if (_timerDevices.length > 1) {
                                        _timerDevices = [_timerDevices.first];
                                        _updateDefaultActionForDevice(_timerDevices.first);
                                      }
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      gradient: !_isMultiDeviceMode ? zen.navPillGradient : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: !_isMultiDeviceMode
                                          ? [
                                              BoxShadow(
                                                color: zen.primary.withOpacity(isDark ? 0.35 : 0.22),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        context.tr('timer_single_device'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: !_isMultiDeviceMode ? FontWeight.w800 : FontWeight.w600,
                                          color: !_isMultiDeviceMode
                                              ? Colors.white
                                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setSheetState(() {
                                      _isMultiDeviceMode = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      gradient: _isMultiDeviceMode ? zen.navPillGradient : null,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: _isMultiDeviceMode
                                          ? [
                                              BoxShadow(
                                                color: zen.primary.withOpacity(isDark ? 0.35 : 0.22),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        context.tr('timer_multi_device'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: _isMultiDeviceMode ? FontWeight.w800 : FontWeight.w600,
                                          color: _isMultiDeviceMode
                                              ? Colors.white
                                              : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0),
                    height: 1,
                  ),

                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: dynamicDeviceTopicsList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final topic = dynamicDeviceTopicsList[idx];
                        final devId = topic.split('/').last;
                        final devName = getDeviceNameHelper(ctx, topic, activeConfig);
                        final bool isSelected = _timerDevices.contains(topic);
                        final bool isOn = states[devId] ?? false;

                        final DeviceConfig? devObj = activeConfig.devices.firstWhere(
                          (d) => d.id == devId,
                          orElse: () => DeviceConfig(id: devId, pin: -1, room: '', name: devName, icon: 'lightbulb_rounded'),
                        );

                        return ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          glowColor: isSelected ? zen.primary : null,
                          rimWidth: isSelected ? 1.4 : 1.05,
                          surfaceColor: isSelected
                              ? zen.primary.withOpacity(isDark ? 0.20 : 0.12)
                              : (isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.white.withOpacity(0.66)),
                          customShadows: const [],
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (!_isMultiDeviceMode) {
                              setState(() {
                                _timerDevices = [topic];
                                _timerAction = isOn ? 'delay_off' : 'delay_on';
                              });
                              Navigator.pop(ctx);
                            } else {
                              setSheetState(() {
                                if (isSelected) {
                                  if (_timerDevices.length > 1) {
                                    _timerDevices.remove(topic);
                                  }
                                } else {
                                  _timerDevices.add(topic);
                                }
                              });
                              setState(() {});
                            }
                          },
                          child: Row(
                            children: [
                              ZenLiquidGlass(
                                blurSigma: 0,
                                width: 42,
                                height: 42,
                                borderRadius: 14,
                                alignment: Alignment.center,
                                glowColor: isOn ? AppColors.amberGlow : null,
                                surfaceColor: isOn
                                    ? AppColors.amberGlow.withOpacity(isDark ? 0.20 : 0.14)
                                    : (isDark
                                        ? Colors.white.withOpacity(0.07)
                                        : Colors.white.withOpacity(0.75)),
                                customShadows: const [],
                                child: Icon(
                                  _getDeviceIcon(devObj?.icon ?? 'lightbulb_rounded'),
                                  size: 21,
                                  color: isOn
                                      ? AppColors.amberGlow
                                      : (isDark ? AppColors.darkText : AppColors.lightText),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      devName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkText : AppColors.lightText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isOn ? AppColors.emeraldGlow : Colors.grey).withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: isOn ? AppColors.emeraldGlow : Colors.grey,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isOn ? 'Đang bật' : 'Đang tắt',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isOn
                                                      ? (isDark ? AppColors.emeraldGlow : AppColors.emeraldDeep)
                                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!_isMultiDeviceMode)
                                          Text(
                                            isOn ? '→ Tự động: Hẹn giờ TẮT' : '→ Tự động: Hẹn giờ BẬT',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isOn
                                                  ? AppColors.roseGlow
                                                  : (isDark ? zen.primaryAccent : zen.primary),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isMultiDeviceMode)
                                Radio<bool>(
                                  value: true,
                                  groupValue: isSelected,
                                  activeColor: isDark ? zen.primaryAccent : zen.primary,
                                  onChanged: (_) {
                                    setState(() {
                                      _timerDevices = [topic];
                                      _timerAction = isOn ? 'delay_off' : 'delay_on';
                                    });
                                    Navigator.pop(ctx);
                                  },
                                )
                              else
                                Checkbox(
                                  value: isSelected,
                                  activeColor: isDark ? zen.primaryAccent : zen.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  onChanged: (val) {
                                    setSheetState(() {
                                      if (val == true) {
                                        _timerDevices.add(topic);
                                      } else if (_timerDevices.length > 1) {
                                        _timerDevices.remove(topic);
                                      }
                                    });
                                    setState(() {});
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  if (_isMultiDeviceMode)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                      child: SizedBox(
                        width: double.infinity,
                        child: ZenGlassButton(
                          label: 'Xác nhận (${_timerDevices.length} thiết bị)',
                          icon: Icons.check_circle_rounded,
                          isPrimary: true,
                          onPressed: () => Navigator.pop(ctx),
                        ),
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

  void _updateDefaultActionForDevice(String deviceTopic) {
    final parts = deviceTopic.split('/');
    if (parts.length >= 2) {
      String devId = parts.last;
      final states = ref.read(globalDeviceStatesProvider);
      bool isOn = states[devId] ?? false;
      setState(() {
        _timerAction = isOn ? 'delay_off' : 'delay_on';
      });
    }
  }

  Widget _buildSelector({
    required String title,
    required String valueText,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    return ZenLiquidGlass(
      blurSigma: 0,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      glowColor: zen.primary,
      surfaceColor: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.white.withOpacity(0.66),
      customShadows: const [],
      onTap: onTap,
      child: Row(
        children: [
          ZenLiquidGlass(
            blurSigma: 0,
            borderRadius: 11,
            padding: const EdgeInsets.all(8),
            glowColor: zen.primary,
            surfaceColor: zen.primary.withOpacity(isDark ? 0.20 : 0.12),
            customShadows: const [],
            child: Icon(icon, size: 20, color: isDark ? zen.primaryAccent : zen.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valueText,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              size: 20,
            ),
        ],
      ),
    );
  }

  Future<void> _saveTimerHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final localTimers = _timerHistory.where((e) => e['isShared'] != true).toList();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    await prefs.setString('timer_history_data_$targetId', jsonEncode(localTimers));
  }

  Future<void> _loadTimerHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    
    // Migration: nếu có dữ liệu cũ chưa có targetId, nạp nó lên và sau đó xóa
    String? data = prefs.getString('timer_history_data_$targetId');
    if (data == null && prefs.containsKey('timer_history_data')) {
      data = prefs.getString('timer_history_data');
      prefs.remove('timer_history_data');
    }
    
    List<dynamic> localTimers = [];
    if (data != null) {
      localTimers = jsonDecode(data);
    }
    
    List<dynamic> sharedTimers = [];
    if (targetId.isNotEmpty && targetId != 'guest') {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .collection('timers')
            .get();
        for (var doc in snap.docs) {
          sharedTimers.add(doc.data());
        }
      } catch (e) {
        debugPrint("Error fetching shared timers: $e");
      }
    }

    int now = DateTime.now().millisecondsSinceEpoch;
    List<Map<String, dynamic>> combined = [];
    combined.addAll(localTimers.map((e) => Map<String, dynamic>.from(e)));
    combined.addAll(sharedTimers.map((e) => Map<String, dynamic>.from(e)));
    
    Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var item in combined) {
      uniqueMap[item['id']] = item;
    }
    
    List<Map<String, dynamic>> finalList = uniqueMap.values.toList();
    
    bool needsSave = false;
    for (var parsedItem in finalList) {
      if (parsedItem['status'] == 'active' && now > parsedItem['targetTime']) {
        parsedItem['status'] = 'completed';
        needsSave = true;
        String targetId = activeConfig.userId;
        if (parsedItem['isShared'] == true && targetId.isNotEmpty && targetId != 'guest') {
          FirebaseFirestore.instance.collection('users').doc(targetId).collection('timers').doc(parsedItem['id']).update({'status': 'completed'});
        }
      }
    }
    
    setState(() {
      _timerHistory = finalList;
      _timerHistory.sort((a, b) => b['id'].compareTo(a['id']));
    });
    
    if (needsSave) _saveTimerHistory();
  }

  bool _canManageTimer(Map<String, dynamic> timer) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isShared = timer['isShared'] == true;
    final String authorUid = timer['authorUid'] ?? '';

    // Đếm ngược cá nhân: chỉ người tạo
    if (!isShared) {
      return authorUid.isEmpty || authorUid == currentUid;
    }

    // Chủ nhà & Phó chủ nhà: toàn quyền
    if (activeConfig.role == 'owner' || activeConfig.role == 'co_owner') {
      return true;
    }

    // Thành viên có quyền tự động hóa
    if (activeConfig.canEditAutomation) {
      return true;
    }

    // Tác giả tự tạo đếm ngược
    if (authorUid.isNotEmpty && authorUid == currentUid) {
      return true;
    }

    return false;
  }

  void _executeTimer() {
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

    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);
    if (mqttState != 2 || !isOnline) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }

    if (_timerDevices.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_select_device') ?? 'Vui lòng chọn ít nhất một thiết bị!', isError: true);
      return;
    }

    int mins = _timerMinutes.toInt();
    String actionText = _timerAction == 'delay_off' ? (context.tr('timer_action_off') ?? 'Tắt sau') : (context.tr('timer_action_on') ?? 'Bật sau');
    String targetId = activeConfig.userId;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentName = FirebaseAuth.instance.currentUser?.displayName ?? 
                        FirebaseAuth.instance.currentUser?.email ?? 'Thành viên';
    int targetTime = DateTime.now().millisecondsSinceEpoch + (mins * 60000);
    String timeStr = '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';

    List<Map<String, dynamic>> createdTimers = [];

    for (int i = 0; i < _timerDevices.length; i++) {
      String deviceTopic = _timerDevices[i];
      if (_timerAction == 'delay_off') {
        ref.read(mqttRepositoryProvider).publishCmd('$deviceTopic/timer_off', mins.toString());
      } else if (_timerAction == 'delay_on') {
        ref.read(mqttRepositoryProvider).publishCmd('$deviceTopic/timer_on', mins.toString());
      }

      String timerId = '${DateTime.now().millisecondsSinceEpoch}_$i';

      Map<String, dynamic> newTimer = {
        'id': timerId,
        'topic': deviceTopic,
        'action': actionText,
        'minutes': mins,
        'timeStr': timeStr,
        'status': 'active', 
        'targetTime': targetTime,
        'isShared': true,
        'authorUid': currentUid,
        'authorName': currentName,
      };

      createdTimers.add(newTimer);

      if (targetId.isNotEmpty && targetId != 'guest') {
        FirebaseFirestore.instance.collection('users').doc(targetId).collection('timers').doc(timerId).set(newTimer);
      }
    }

    setState(() {
      for (var t in createdTimers) {
        _timerHistory.insert(0, t);
      }
    });

    _saveTimerHistory();

    if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null && targetId.isNotEmpty && targetId != 'guest') {
      String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
      FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
        'type': 'automation_edit',
        'author': name,
        'actionName': context.tr('act_add_timer') ?? 'vừa thêm một đếm ngược mới',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    showFloatingToast(
      context,
      context.tr('toast_timer_title'),
      _timerDevices.length == 1
          ? '${context.tr('toast_timer_set')} $mins ${context.tr('minutes')}'
          : 'Đã hẹn giờ cho ${_timerDevices.length} thiết bị ($mins ${context.tr('minutes')})',
    );
  }

  void _cancelTimerHistory(int index) {
    final timerItem = _timerHistory[index];
    if (!_canManageTimer(timerItem)) {
      showFloatingToast(context, context.tr('error'), 'Bạn không có quyền hủy đếm ngược này (do Chủ nhà hoặc thành viên khác đặt).', isError: true);
      return;
    }

    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);
    if (mqttState != 2 || !isOnline) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }
    
    showPremiumConfirmDialog(
      context: context,
      title: context.tr('confirm_title'),
      message: context.tr('confirm_delete_timer'),
      confirmText: context.tr('btn_delete'),
      cancelText: context.tr('btn_cancel'),
      isDanger: true,
      icon: Icons.timer_off_rounded,
      onConfirm: () {
        final activeConfig = ref.read(homeConfigProvider).activeConfig;
        String topic = _timerHistory[index]['topic'];
        ref.read(mqttRepositoryProvider).publishCmd('$topic/timer_off', '0');
        ref.read(mqttRepositoryProvider).publishCmd('$topic/timer_on', '0');
        setState(() => _timerHistory[index]['status'] = 'canceled');
        
        String targetId = activeConfig.userId;
        if (_timerHistory[index]['isShared'] == true && targetId.isNotEmpty && targetId != 'guest') {
          FirebaseFirestore.instance.collection('users').doc(targetId).collection('timers').doc(_timerHistory[index]['id']).update({'status': 'canceled'});
          
          if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null) {
            String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
            FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
              'type': 'automation_edit',
              'author': name,
              'actionName': context.tr('act_cancel_timer') ?? 'vừa hủy một đếm ngược',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        } else {
          _saveTimerHistory();
        }
        showFloatingToast(context, context.tr('cancel_cmd'), context.tr('toast_timer_cancel'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeConfigProvider, (previous, next) {
      if (previous?.activeConfig.userId != next.activeConfig.userId) {
        _timersSubscription?.cancel();
        _loadTimerHistory();
        _subscribeToFirestoreTimers();
      }
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final Color amberText = isDark ? AppColors.amberGlow : AppColors.amberDeep;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final allDeviceTopics = getSortedDeviceTopicsList(context, activeConfig);
    final dynamicDeviceTopicsList = allDeviceTopics.where((topic) {
      if (activeConfig.role == 'owner' || activeConfig.role == 'co_owner' || activeConfig.allowedDevices == null) {
        return true;
      }
      final devId = topic.split('/').last;
      return activeConfig.allowedDevices!.contains(devId);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            ZenLiquidGlass(
              blurSigma: 8,
              borderRadius: 11,
              padding: const EdgeInsets.all(7),
              glowColor: AppColors.amberGlow,
              surfaceColor: AppColors.amberGlow.withOpacity(isDark ? 0.20 : 0.12),
              customGradient: LinearGradient(
                colors: [
                  AppColors.amberGlow.withOpacity(isDark ? 0.28 : 0.18),
                  AppColors.amberDeep.withOpacity(isDark ? 0.12 : 0.06),
                ],
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: AppColors.amberGlow, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              context.tr('timer_title'),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (dynamicDeviceTopicsList.isEmpty)
          ZenGlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(24),
            blurSigma: 12,
            glowColor: zen.primary,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_disabled_rounded,
                    size: 34,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('no_device'),
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ZenGlassCard(
            borderRadius: 26,
            padding: const EdgeInsets.all(20),
            blurSigma: 16,
            glowColor: zen.primary,
            isActive: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device Selector (nested inside ZenGlassCard -> blurSigma: 0)
                _buildSelector(
                  title: context.tr('select_device'),
                  valueText: _timerDevices.isEmpty
                      ? (context.tr('select_device') ?? 'Chọn thiết bị')
                      : (_timerDevices.length == 1
                          ? getDeviceNameHelper(context, _timerDevices.first, activeConfig)
                          : '${_timerDevices.length} ${context.tr('devices_selected') ?? 'thiết bị đã chọn'} (${_timerDevices.map((t) => getDeviceNameHelper(context, t, activeConfig)).join(', ')})'),
                  icon: Icons.devices_other_rounded,
                  onTap: () => _showDevicePicker(dynamicDeviceTopicsList, activeConfig),
                ),
                const SizedBox(height: 14),

                // ON / OFF Action Mode Selector Pills (ZenGlassPill with blurSigma: 0)
                Row(
                  children: [
                    Expanded(
                      child: ZenGlassPill(
                        blurSigma: 0,
                        borderRadius: 16,
                        isSelected: _timerAction == 'delay_off',
                        color: AppColors.roseGlow,
                        glowColor: AppColors.roseGlow,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _timerAction = 'delay_off');
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.power_settings_new_rounded,
                                  size: 15,
                                  color: _timerAction == 'delay_off'
                                      ? AppColors.roseGlow
                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      context.tr('timer_action_off'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _timerAction == 'delay_off'
                                            ? AppColors.roseGlow
                                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '(${context.tr('state_currently_on') ?? 'Đang bật'})',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _timerAction == 'delay_off'
                                      ? AppColors.roseGlow.withOpacity(0.9)
                                      : (isDark
                                          ? AppColors.darkTextMuted.withOpacity(0.75)
                                          : AppColors.lightTextMuted.withOpacity(0.75)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ZenGlassPill(
                        blurSigma: 0,
                        borderRadius: 16,
                        isSelected: _timerAction == 'delay_on',
                        color: AppColors.emeraldGlow,
                        glowColor: AppColors.emeraldGlow,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _timerAction = 'delay_on');
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: _timerAction == 'delay_on'
                                      ? (isDark ? AppColors.emeraldGlow : AppColors.emeraldDeep)
                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      context.tr('timer_action_on'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _timerAction == 'delay_on'
                                            ? (isDark ? AppColors.emeraldGlow : AppColors.emeraldDeep)
                                            : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '(${context.tr('state_currently_off') ?? 'Đang tắt'})',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _timerAction == 'delay_on'
                                      ? (isDark ? AppColors.emeraldGlow : AppColors.emeraldDeep).withOpacity(0.9)
                                      : (isDark
                                          ? AppColors.darkTextMuted.withOpacity(0.75)
                                          : AppColors.lightTextMuted.withOpacity(0.75)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Digital Timer Display (ZenGlassPill with blurSigma: 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _timerAction == 'delay_off'
                            ? context.tr('time_off_label')
                            : context.tr('time_on_label'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ZenGlassPill(
                      blurSigma: 0,
                      borderRadius: 15,
                      isSelected: true,
                      color: AppColors.amberGlow,
                      glowColor: AppColors.amberGlow,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      onTap: _showCustomTimeDialog,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (_timerMinutes.round() >= 60) ...[
                            Text(
                              '${_timerMinutes.round() ~/ 60}',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: amberText,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              context.tr('hours'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: amberText.withOpacity(0.88),
                              ),
                            ),
                            if (_timerMinutes.round() % 60 > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${_timerMinutes.round() % 60}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: amberText,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'm',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: amberText.withOpacity(0.88),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Text(
                              '(${_timerMinutes.round()}m)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: amberText.withOpacity(0.70),
                              ),
                            ),
                          ] else ...[
                            Text(
                              '${_timerMinutes.round()}',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: amberText,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('minutes'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: amberText.withOpacity(0.88),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Icon(
                            Icons.edit_calendar_rounded,
                            size: 14,
                            color: amberText.withOpacity(0.80),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Thanh trượt thời gian phong cách Luxury Smart Home đẳng cấp
                LuxurySlider(
                  value: _timerMinutes.clamp(1.0, (_timerMinutes > 720 ? _timerMinutes : 720).toDouble()),
                  min: 1,
                  max: (_timerMinutes > 720 ? _timerMinutes : 720).toDouble(),
                  activeGradient: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
                  glowColor: AppColors.amberGlow,
                  milestoneValues: const [15, 30, 60, 120, 240, 480, 720],
                  milestoneLabelBuilder: (m) => m < 60 ? '${m}m' : '${m ~/ 60}h',
                  onChanged: (val) {
                    _sliderAnimController.stop();
                    setState(() => _timerMinutes = val);
                  },
                ),
                const SizedBox(height: 12),

                // Quick Minutes & Hours Glass Pills (blurSigma: 0)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720].map((mins) {
                      bool isSelected = _timerMinutes.round() == mins;
                      String chipLabel;
                      if (mins < 60) {
                        chipLabel = '${mins}m';
                      } else if (mins % 60 == 0) {
                        chipLabel = '${mins ~/ 60} ${context.tr('hours')}';
                      } else {
                        chipLabel = '${(mins / 60).toStringAsFixed(1)} ${context.tr('hours')}';
                      }
                      return ZenGlassPill(
                        blurSigma: 0,
                        borderRadius: 12,
                        margin: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        isSelected: isSelected,
                        color: AppColors.amberGlow,
                        glowColor: AppColors.amberGlow,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _animateToMinutes(mins.toDouble());
                        },
                        child: Text(
                          chipLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected
                                ? amberText
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Start Timer Luminous Glass Button synced with context.zenColors
                BouncingButton(
                  onTap: _executeTimer,
                  child: ZenLiquidGlass(
                    blurSigma: 0,
                    width: double.infinity,
                    height: 50,
                    borderRadius: 16,
                    glowColor: zen.primary,
                    rimWidth: 1.35,
                    surfaceColor: zen.primary,
                    customGradient: zen.navPillGradient,
                    customShadows: [
                      BoxShadow(
                        color: zen.primary.withOpacity(isDark ? 0.38 : 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('timer_start'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Timer History / Active Countdown List Section
        if (_timerHistory.isNotEmpty) ...[
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('timer_history'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              ZenGlassPill(
                blurSigma: 8,
                borderRadius: 14,
                color: AppColors.roseGlow,
                glowColor: AppColors.roseGlow,
                isSelected: false,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                onTap: () {
                  showPremiumConfirmDialog(
                    context: context,
                    title: context.tr('clear_history'),
                    message: context.tr('clear_history_confirm'),
                    confirmText: context.tr('btn_delete'),
                    cancelText: context.tr('btn_cancel'),
                    isDanger: true,
                    icon: Icons.delete_sweep_rounded,
                    onConfirm: () async {
                      String targetId = activeConfig.userId;
                      if (targetId.isNotEmpty && targetId != 'guest') {
                        for (var t in _timerHistory) {
                          if (t['isShared'] == true) {
                            await FirebaseFirestore.instance.collection('users').doc(targetId).collection('timers').doc(t['id']).delete();
                          }
                        }
                      }
                      setState(() => _timerHistory.clear());
                      _saveTimerHistory();
                    },
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_sweep_rounded, size: 15, color: AppColors.roseGlow),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('clear_history'),
                      style: const TextStyle(
                        color: AppColors.roseGlow,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timerHistory.length,
            itemBuilder: (context, index) {
              final item = _timerHistory[index];
              String status = item['status'];
              final bool isActive = status == 'active';
              final Color statusColor = isActive
                  ? AppColors.amberGlow
                  : (status == 'completed' ? AppColors.emeraldGlow : Colors.grey);

              return ZenGlassCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                borderRadius: 20,
                blurSigma: 12,
                isActive: isActive,
                glowColor: isActive
                    ? AppColors.amberGlow
                    : (status == 'completed' ? AppColors.emeraldGlow : null),
                child: Row(
                  children: [
                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 14,
                      padding: const EdgeInsets.all(10),
                      glowColor: isActive ? statusColor : null,
                      surfaceColor: statusColor.withOpacity(isDark ? 0.20 : 0.13),
                      customShadows: const [],
                      child: Icon(
                        isActive
                            ? Icons.hourglass_top_rounded
                            : (status == 'completed'
                                ? Icons.check_circle_rounded
                                : Icons.cancel_outlined),
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  getDeviceNameHelper(context, item['topic'], activeConfig),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: isActive
                                        ? (isDark ? AppColors.darkText : AppColors.lightText)
                                        : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (item['isShared'] == true)
                                ZenGlassPill(
                                  blurSigma: 0,
                                  borderRadius: 8,
                                  isSelected: true,
                                  color: zen.primary,
                                  glowColor: zen.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    context.tr('shared'),
                                    style: TextStyle(
                                      color: isDark ? zen.primaryAccent : zen.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                ZenGlassPill(
                                  blurSigma: 0,
                                  borderRadius: 8,
                                  isSelected: false,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: Text(
                                    context.tr('private'),
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item['action']} ${item['minutes']} ${context.tr('minutes')} • ${item['timeStr']}',
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive && _canManageTimer(item))
                      ZenGlassPill(
                        blurSigma: 0,
                        borderRadius: 12,
                        isSelected: true,
                        color: AppColors.roseGlow,
                        glowColor: AppColors.roseGlow,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onTap: () => _cancelTimerHistory(index),
                        child: Text(
                          context.tr('cancel_cmd'),
                          style: const TextStyle(
                            color: AppColors.roseGlow,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      )
                    else if (isActive)
                      Text(
                        item['authorName'] != null && item['authorName'].toString().isNotEmpty
                            ? '${context.tr('status_waiting')} (${item['authorName']})'
                            : context.tr('status_waiting'),
                        style: TextStyle(
                          color: amberText,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      )
                    else if (status == 'completed')
                      Text(
                        context.tr('completed'),
                        style: TextStyle(
                          color: isDark ? AppColors.emeraldGlow : AppColors.emeraldDeep,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    else
                      Text(
                        context.tr('canceled'),
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}