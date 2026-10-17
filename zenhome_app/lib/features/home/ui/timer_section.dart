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

class TimerSection extends ConsumerStatefulWidget {
  const TimerSection({super.key});

  @override
  ConsumerState<TimerSection> createState() => _TimerSectionState();
}

class _TimerSectionState extends ConsumerState<TimerSection> {
  String? _timerDevice;
  String _timerAction = 'delay_off';
  double _timerMinutes = 30;
  List<Map<String, dynamic>> _timerHistory = [];
  StreamSubscription<QuerySnapshot>? _timersSubscription;

  @override
  void initState() {
    super.initState();
    final dynamicDeviceTopicsList = getSortedDeviceTopicsList(context, ref.read(homeConfigProvider).activeConfig);
    if (dynamicDeviceTopicsList.isNotEmpty) {
      _timerDevice = dynamicDeviceTopicsList.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateDefaultActionForDevice(_timerDevice!);
      });
    }
    _loadTimerHistory();
    _subscribeToFirestoreTimers();
  }

  @override
  void dispose() {
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

  void _executeTimer() {
    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);
    if (mqttState != 2 || !isOnline) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }

    if (_timerDevice == null) {
      showFloatingToast(context, context.tr('error'), context.tr('no_device'), isError: true);
      return;
    }

    int mins = _timerMinutes.toInt();
    String actionText = _timerAction == 'delay_off' ? context.tr('timer_action_off') : context.tr('timer_action_on');
    
    if (_timerAction == 'delay_off') {
      ref.read(mqttRepositoryProvider).publishCmd('$_timerDevice/timer_off', mins.toString());
    } else if (_timerAction == 'delay_on') {
      ref.read(mqttRepositoryProvider).publishCmd('$_timerDevice/timer_on', mins.toString());
    }
    
    int targetTime = DateTime.now().millisecondsSinceEpoch + (mins * 60000);
    String timerId = DateTime.now().millisecondsSinceEpoch.toString();
    
    Map<String, dynamic> newTimer = {
      'id': timerId,
      'topic': _timerDevice,
      'action': actionText,
      'minutes': mins,
      'timeStr': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'status': 'active', 
      'targetTime': targetTime,
      'isShared': true
    };

    setState(() {
      _timerHistory.insert(0, newTimer);
    });
    
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    if (targetId.isNotEmpty && targetId != 'guest') {
      FirebaseFirestore.instance.collection('users').doc(targetId).collection('timers').doc(timerId).set(newTimer);
      
      // Gửi thông báo nếu không phải owner
      if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null) {
        String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
        FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
          'type': 'automation_edit',
          'author': name,
          'actionName': context.tr('act_add_timer') ?? 'vừa thêm một đếm ngược mới',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } else {
      _saveTimerHistory();
    }
    
    showFloatingToast(context, context.tr('toast_timer_title'), context.tr('toast_timer_set'));
  }

  void _cancelTimerHistory(int index) {
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final dynamicDeviceTopicsList = getSortedDeviceTopicsList(context, activeConfig);

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
                // Device Selector
                _buildSelector(
                  title: context.tr('select_device'),
                  valueText: getDeviceNameHelper(context, _timerDevice ?? '', activeConfig),
                  icon: Icons.devices_other_rounded,
                  onTap: () {
                    showCustomBottomSheetPicker(
                      context: context,
                      title: context.tr('select_device'),
                      currentValue: _timerDevice ?? '',
                      items: dynamicDeviceTopicsList.map((topic) => PickerItem(topic, getDeviceNameHelper(context, topic, activeConfig))).toList(),
                      onSelected: (val) {
                        setState(() => _timerDevice = val);
                        _updateDefaultActionForDevice(val);
                      },
                    );
                  },
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
                          padding: const EdgeInsets.symmetric(vertical: 11),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.power_settings_new_rounded,
                                size: 16,
                                color: _timerAction == 'delay_off' ? AppColors.roseGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('timer_action_off'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _timerAction == 'delay_off' ? AppColors.roseGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
                          padding: const EdgeInsets.symmetric(vertical: 11),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16,
                                color: _timerAction == 'delay_on' ? AppColors.emeraldGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('timer_action_on'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _timerAction == 'delay_on' ? AppColors.emeraldGlow : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
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
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      context.tr('time_on_label') ?? 'Duration',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_timerMinutes.toInt()}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('minutes'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: isDark ? AppColors.primaryLight : AppColors.primary,
                    inactiveTrackColor: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                    thumbColor: isDark ? AppColors.primaryLight : AppColors.primary,
                    overlayColor: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _timerMinutes,
                    min: 1,
                    max: 120,
                    onChanged: (val) => setState(() => _timerMinutes = val),
                  ),
                ),
                const SizedBox(height: 6),

                // Quick Minutes Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [15, 30, 45, 60, 90, 120].map((mins) {
                    bool isSelected = _timerMinutes.toInt() == mins;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _timerMinutes = mins.toDouble());
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.primaryLight.withOpacity(0.2) : AppColors.primary.withOpacity(0.1))
                              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.4)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          '${mins}m',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
                    if (status == 'active' && (activeConfig.role != 'member' || activeConfig.canEditAutomation || item['isShared'] != true)) 
                      TextButton(
                        onPressed: () => _cancelTimerHistory(index),
                        child: Text(context.tr('cancel_cmd'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                      )
                    else if (status == 'active')
                      Text(context.tr('status_waiting'), style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 12))
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