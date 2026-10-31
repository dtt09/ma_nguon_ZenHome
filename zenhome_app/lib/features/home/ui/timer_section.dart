import 'dart:ui';
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
    int initialHours = currentTotalMinutes ~/ 60;
    int initialMinutes = currentTotalMinutes % 60;

    final TextEditingController hoursCtrl = TextEditingController(text: initialHours > 0 ? '$initialHours' : '');
    final TextEditingController minutesCtrl = TextEditingController(text: initialMinutes > 0 ? '$initialMinutes' : (initialHours > 0 ? '0' : '30'));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            int h = int.tryParse(hoursCtrl.text.trim()) ?? 0;
            int m = int.tryParse(minutesCtrl.text.trim()) ?? 0;
            int totalMins = (h * 60) + m;

            String previewText;
            if (totalMins <= 0) {
              previewText = 'Vui lòng nhập thời gian lớn hơn 0';
            } else if (h > 0 && m > 0) {
              previewText = '$h ${context.tr('hours')} $m ${context.tr('minutes')} ($totalMins ${context.tr('minutes')})';
            } else if (h > 0) {
              previewText = '$h ${context.tr('hours')} ($totalMins ${context.tr('minutes')})';
            } else {
              previewText = '$m ${context.tr('minutes')}';
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _timerAction == 'delay_off' ? context.tr('time_off_label') : context.tr('time_on_label'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Two input fields: Giờ (Hours) & Phút (Minutes)
                    Row(
                      children: [
                        // Hours Input
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
                                autofocus: true,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: context.tr('hours'),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Minutes Input
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
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  suffixText: context.tr('minutes'),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Hour Buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [1, 2, 3, 4, 6, 8, 12, 24].map((hr) {
                        bool isHrSelected = h == hr && m == 0;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            hoursCtrl.text = '$hr';
                            minutesCtrl.text = '0';
                            setDialogState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isHrSelected
                                  ? AppColors.amberGlow.withOpacity(0.2)
                                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isHrSelected ? AppColors.amberGlow : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '$hr ${context.tr('hours')}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isHrSelected ? FontWeight.bold : FontWeight.w500,
                                color: isHrSelected
                                    ? AppColors.amberGlow
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Preview Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.amberGlow.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.amberGlow.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 18, color: AppColors.amberGlow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              previewText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.amberGlow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.amberGlow,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: totalMins >= 1 && totalMins <= 1440
                            ? () {
                                _animateToMinutes(totalMins.toDouble());
                                Navigator.pop(ctx);
                              }
                            : null,
                        child: Text(
                          context.tr('btn_confirm'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      List<dynamic> localTimers = (data != null) ? jsonDecode(data) : [];
      List<dynamic> firestoreTimers = snap.docs.map((doc) => doc.data()).toList();

      List<Map<String, dynamic>> combined = [];
      combined.addAll(localTimers.map((e) => Map<String, dynamic>.from(e)));
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final states = ref.read(globalDeviceStatesProvider);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131D31) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                context.tr('select_device') ?? 'Chọn thiết bị hẹn giờ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 22),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: !_isMultiDeviceMode
                                            ? (isDark ? AppColors.primaryLight.withOpacity(0.2) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: !_isMultiDeviceMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.08),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Mặc định: 1 thiết bị',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: !_isMultiDeviceMode ? FontWeight.bold : FontWeight.w500,
                                            color: !_isMultiDeviceMode
                                                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                                : (isDark ? Colors.white60 : Colors.black54),
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
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _isMultiDeviceMode
                                            ? (isDark ? AppColors.primaryLight.withOpacity(0.2) : Colors.white)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: _isMultiDeviceMode
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.08),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          'Nhiều thiết bị',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: _isMultiDeviceMode ? FontWeight.bold : FontWeight.w500,
                                            color: _isMultiDeviceMode
                                                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                                : (isDark ? Colors.white60 : Colors.black54),
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
                    const SizedBox(height: 12),
                    Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),

                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: dynamicDeviceTopicsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
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

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
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
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? AppColors.primaryLight.withOpacity(0.12) : AppColors.primary.withOpacity(0.08))
                                    : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isOn ? Colors.amber : Colors.blueGrey).withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getDeviceIcon(devObj?.icon ?? 'lightbulb_rounded'),
                                      size: 22,
                                      color: isOn ? Colors.amber : (isDark ? Colors.white70 : Colors.black87),
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
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: (isOn ? Colors.green : Colors.grey).withOpacity(0.14),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: isOn ? Colors.green : Colors.grey,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isOn ? 'Đang bật' : 'Đang tắt',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isOn ? Colors.green : Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (!_isMultiDeviceMode)
                                              Text(
                                                isOn ? '→ Tự động: Hẹn giờ TẮT' : '→ Tự động: Hẹn giờ BẬT',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isOn ? Colors.redAccent : Colors.teal,
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
                            ),
                          );
                        },
                      ),
                    ),

                    if (_isMultiDeviceMode) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Xác nhận (${_timerDevices.length} thiết bị)',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
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

  Widget _buildSelector({required String title, required String valueText, required IconData icon, VoidCallback? onTap}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0x12FFFFFF) : const Color(0x08000000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0x0F000000),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: isDark ? AppColors.primaryLight : AppColors.primary),
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
                      fontWeight: FontWeight.w500,
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
                color: isDark ? Colors.white54 : Colors.black45,
                size: 20,
              ),
          ],
        ),
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
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
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

    bool isDark = Theme.of(context).brightness == Brightness.dark;
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
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.amberGlow.withOpacity(0.2), AppColors.amberDeep.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hourglass_top_rounded, color: AppColors.amberGlow, size: 18),
            ),
            const SizedBox(width: 10),
            Text(context.tr('timer_title'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 14),
        
        if (dynamicDeviceTopicsList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Center(child: Text(context.tr('no_device'), style: TextStyle(color: Colors.grey.shade500))),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device Selector (Hỗ trợ chọn 1 hoặc nhiều thiết bị)
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

                // Action Toggle Pills
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _timerAction = 'delay_off');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _timerAction == 'delay_off'
                                ? (isDark ? AppColors.roseGlow.withOpacity(0.2) : Colors.red.shade50)
                                : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _timerAction == 'delay_off'
                                  ? AppColors.roseGlow.withOpacity(0.5)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
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
                                    color: _timerAction == 'delay_off' ? AppColors.roseGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
                                          color: _timerAction == 'delay_off' ? AppColors.roseGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
                                    fontWeight: FontWeight.w500,
                                    color: _timerAction == 'delay_off' 
                                        ? AppColors.roseGlow.withOpacity(0.85) 
                                        : (isDark ? AppColors.darkTextMuted.withOpacity(0.7) : AppColors.lightTextMuted.withOpacity(0.7)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _timerAction = 'delay_on');
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _timerAction == 'delay_on'
                                ? (isDark ? AppColors.emeraldGlow.withOpacity(0.2) : Colors.green.shade50)
                                : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _timerAction == 'delay_on'
                                  ? AppColors.emeraldGlow.withOpacity(0.5)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
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
                                    color: _timerAction == 'delay_on' ? AppColors.emeraldGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
                                          color: _timerAction == 'delay_on' ? AppColors.emeraldGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
                                    fontWeight: FontWeight.w500,
                                    color: _timerAction == 'delay_on' 
                                        ? AppColors.emeraldGlow.withOpacity(0.85) 
                                        : (isDark ? AppColors.darkTextMuted.withOpacity(0.7) : AppColors.lightTextMuted.withOpacity(0.7)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Digital Timer Display
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
                    GestureDetector(
                      onTap: _showCustomTimeDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.amberGlow.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.amberGlow.withOpacity(0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amberGlow.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (_timerMinutes.round() >= 60) ...[
                              Text(
                                '${_timerMinutes.round() ~/ 60}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: AppColors.amberGlow,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                context.tr('hours'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amberGlow.withOpacity(0.85),
                                ),
                              ),
                              if (_timerMinutes.round() % 60 > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${_timerMinutes.round() % 60}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.amberGlow,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.amberGlow.withOpacity(0.85),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              Text(
                                '(${_timerMinutes.round()}m)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amberGlow.withOpacity(0.65),
                                ),
                              ),
                            ] else ...[
                              Text(
                                '${_timerMinutes.round()}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: AppColors.amberGlow,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('minutes'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.amberGlow.withOpacity(0.85),
                                ),
                              ),
                            ],
                            const SizedBox(width: 6),
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 14,
                              color: AppColors.amberGlow.withOpacity(0.75),
                            ),
                          ],
                        ),
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

                // Quick Minutes & Hours Chips with horizontal scroll and smooth gliding animation
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
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _animateToMinutes(mins.toDouble());
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutBack,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.amberGlow.withOpacity(0.2)
                                  : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.amberGlow
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.amberGlow.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Text(
                              chipLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.amberGlow
                                    : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 20),

                // Start Timer Button
                BouncingButton(
                  onTap: _executeTimer,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.navPillGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryLight.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
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
                ),
              ],
            ),
          ),
        
        // Timer History Section
        if (_timerHistory.isNotEmpty) ...[
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('timer_history'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () { 
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
                child: Text(context.tr('clear_history'), style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _timerHistory.length,
            itemBuilder: (context, index) {
              final item = _timerHistory[index];
              String status = item['status'];
              Color statusColor = status == 'active' 
                  ? AppColors.amberGlow 
                  : (status == 'completed' ? AppColors.emeraldGlow : Colors.grey);
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        status == 'active' ? Icons.hourglass_top_rounded : (status == 'completed' ? Icons.check_circle_rounded : Icons.cancel_outlined), 
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
                                    fontSize: 14,
                                    color: status == 'active' ? (isDark ? AppColors.darkText : AppColors.lightText) : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (item['isShared'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                  ),
                                  child: Text(context.tr('shared'), style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(context.tr('private'), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item['action']} ${item['minutes']} ${context.tr('minutes')} • ${item['timeStr']}',
                            style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (status == 'active' && _canManageTimer(item)) 
                      TextButton(
                        onPressed: () => _cancelTimerHistory(index),
                        child: Text(context.tr('cancel_cmd'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      )
                    else if (status == 'active')
                      Text(
                        item['authorName'] != null && item['authorName'].toString().isNotEmpty
                            ? '${context.tr('status_waiting')} (${item['authorName']})'
                            : context.tr('status_waiting'),
                        style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 12),
                      )
                    else if (status == 'completed')
                      Text(context.tr('completed'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
                    else 
                      Text(context.tr('canceled'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
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