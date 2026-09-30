import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/utils/helpers.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';

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
  }

  void _updateDefaultActionForDevice(String deviceTopic) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
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

  Widget _buildSelector({required String title, required String valueText, VoidCallback? onTap}) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(valueText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
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
        Text(context.tr('timer_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        
          if (dynamicDeviceTopicsList.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: BorderRadius.circular(20), border: isDark ? Border.all(color: Colors.grey.shade800) : null),
              child: Center(child: Text(context.tr('no_device'), style: TextStyle(color: Colors.grey.shade500))),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: BorderRadius.circular(20), border: isDark ? Border.all(color: Colors.grey.shade800) : null, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  _buildSelector(
                    title: context.tr('select_device'),
                    valueText: getDeviceNameHelper(context, _timerDevice ?? '', activeConfig),
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
                  const SizedBox(height: 10),
                  _buildSelector(
                    title: context.tr('action'),
                    valueText: _timerAction == 'delay_off' ? context.tr('timer_action_off') : context.tr('timer_action_on'),
                    onTap: null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Slider(value: _timerMinutes, min: 1, max: 120, activeColor: const Color(0xFF2A3A7C), onChanged: (val) => setState(() => _timerMinutes = val))),
                      Text('${_timerMinutes.toInt()} ${context.tr('minutes')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, 
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), 
                      onPressed: _executeTimer, 
                      child: Text(context.tr('timer_start'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                    )
                  )
                ],
              ),
            ),
        
        if (_timerHistory.isNotEmpty) ...[
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('timer_history'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                child: Text(context.tr('clear_history'), style: const TextStyle(color: Colors.red))
              ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _timerHistory.length,
            itemBuilder: (context, index) {
              final item = _timerHistory[index];
              String status = item['status'];
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: BorderRadius.circular(15), border: isDark ? Border.all(color: Colors.grey.shade800) : null),
                child: Row(
                  children: [
                    Icon(
                      status == 'active' ? Icons.timer : (status == 'completed' ? Icons.check_circle : Icons.cancel), 
                      color: status == 'active' ? Colors.orange : (status == 'completed' ? Colors.green : Colors.grey), 
                      size: 30
                    ), 
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(getDeviceNameHelper(context, item['topic'], activeConfig), style: TextStyle(fontWeight: FontWeight.bold, color: status == 'active' ? (isDark ? Colors.white : Colors.black) : Colors.grey)),
                              const SizedBox(width: 5),
                              if (item['isShared'] == true)
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)), child: Text(context.tr('shared'), style: const TextStyle(color: Colors.blue, fontSize: 10)))
                              else
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: Text(context.tr('private'), style: const TextStyle(color: Colors.grey, fontSize: 10))),
                            ],
                          ),
                          Text('${item['action']} ${item['minutes']} ${context.tr('minutes')} - ${item['timeStr']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (status == 'active' && (activeConfig.role != 'member' || activeConfig.canEditAutomation || item['isShared'] != true)) 
                      TextButton(onPressed: () => _cancelTimerHistory(index), child: Text(context.tr('cancel_cmd'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))
                    else if (status == 'active')
                      Text(context.tr('status_waiting'), style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic))
                    else if (status == 'completed')
                      Text(context.tr('completed'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                    else 
                      Text(context.tr('canceled'), style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
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