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

class ScheduleSection extends ConsumerStatefulWidget {
  const ScheduleSection({super.key});

  @override
  ConsumerState<ScheduleSection> createState() => _ScheduleSectionState();
}

class _ScheduleSectionState extends ConsumerState<ScheduleSection> {
  List<Map<String, dynamic>> _savedSchedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedulesFromDisk();
  }

  Widget _buildSelector({required String title, required String valueText, required VoidCallback onTap}) {
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
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          ],
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
        'timeOn': item['timeOn'],
        'timeOff': item['timeOff'],
        'days': List<bool>.from(item['days']),
        'isActive': item['isActive'],
        'isShared': item['isShared'] ?? false,
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
    final dynamicDeviceTopicsList = getSortedDeviceTopicsList(context, activeConfig);
    if (dynamicDeviceTopicsList.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('no_device'), isError: true);
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
    final List<String> dayLabels = [context.tr('mon'), context.tr('tue'), context.tr('wed'), context.tr('thu'), context.tr('fri'), context.tr('sat'), context.tr('sun')];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.75, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20), Text(isEdit ? context.tr('schedule_edit') : context.tr('schedule_add'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
                  
                  _buildSelector(
                    title: context.tr('select_device'),
                    valueText: newDevices.isEmpty 
                      ? context.tr('select_device') 
                      : newDevices.map((t) => getDeviceNameHelper(context, t, activeConfig)).join(', '),
                    onTap: () {
                      showCustomMultiSelectBottomSheetPicker(
                        context: context,
                        title: context.tr('select_device'),
                        currentValues: newDevices,
                        items: dynamicDeviceTopicsList.map((topic) => PickerItem(topic, getDeviceNameHelper(context, topic, activeConfig))).toList(),
                        onSelected: (val) => setModalState(() => newDevices = val),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: GestureDetector(onTap: () async { final picked = await showTimePicker(context: context, initialTime: timeOn); if (picked != null) setModalState(() => timeOn = picked); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green)), child: Column(children: [Text(context.tr('schedule_turn_on'), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), Text(timeOn.format(context), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])))),
                      const SizedBox(width: 15),
                      Expanded(child: GestureDetector(onTap: () async { final picked = await showTimePicker(context: context, initialTime: timeOff); if (picked != null) setModalState(() => timeOff = picked); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red)), child: Column(children: [Text(context.tr('schedule_turn_off'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), Text(timeOff.format(context), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(context.tr('schedule_repeat'), style: const TextStyle(color: Colors.grey)), const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (index) { return GestureDetector(onTap: () => setModalState(() => selectedDays[index] = !selectedDays[index]), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: selectedDays[index] ? const Color(0xFF2A3A7C) : (isDark ? Colors.grey.shade800 : Colors.grey.shade200), shape: BoxShape.circle), child: Center(child: Text(dayLabels[index], style: TextStyle(color: selectedDays[index] ? Colors.white : Colors.grey, fontWeight: FontWeight.bold))))); })),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Checkbox(
                        value: _shareWithAll,
                        onChanged: (val) => setModalState(() => _shareWithAll = val ?? false),
                        activeColor: const Color(0xFF2A3A7C),
                      ),
                      Expanded(child: Text(context.tr('share_with_all'))),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () {
                        if (newDevices.isEmpty) { Navigator.pop(context); showAlertDialogHelper(context, context.tr('error'), context.tr('err_select_device') ?? 'Vui lòng chọn thiết bị', isError: true); return; }
                        if (!selectedDays.contains(true)) { Navigator.pop(context); showAlertDialogHelper(context, context.tr('error'), context.tr('err_select_day'), isError: true); return; }
                        if (_checkConflict(newDevices, timeOn, timeOff, selectedDays, isEdit ? editSchedule['id'] : null)) { Navigator.pop(context); showAlertDialogHelper(context, context.tr('error'), context.tr('err_conflict'), isError: true); return; }
                        
                        final mqttState = ref.read(mqttConnectionStateProvider);
                        final isOnline = ref.read(espOnlineStateProvider);
                        if (mqttState != 2 || !isOnline) {
                          Navigator.pop(context);
                          showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
                          return;
                        }

                        String hOn = timeOn.hour.toString().padLeft(2, '0'); String mOn = timeOn.minute.toString().padLeft(2, '0'); 
                        String hOff = timeOff.hour.toString().padLeft(2, '0'); String mOff = timeOff.minute.toString().padLeft(2, '0'); 
                        String daysBinary = selectedDays.map((d) => d ? '1' : '0').join('');
                        String newId = isEdit ? editSchedule['id'] : DateTime.now().millisecondsSinceEpoch.toString();
                        
                        for (String dev in newDevices) {
                          ref.read(mqttRepositoryProvider).publishCmd('$dev/schedule', '$newId|$hOn:$mOn|$hOff:$mOff|$daysBinary|1');
                        }
                        
                        Map<String, dynamic> newSchedule = {'id': newId, 'topics': newDevices, 'timeOn': '$hOn:$mOn', 'timeOff': '$hOff:$mOff', 'days': List.from(selectedDays), 'isActive': true, 'isShared': _shareWithAll};
                        
                        setState(() {
                          if (isEdit) {
                            int idx = _savedSchedules.indexWhere((e) => e['id'] == editSchedule['id']);
                            _savedSchedules[idx] = newSchedule;
                          } else {
                            _savedSchedules.add(newSchedule);
                          }
                        });
                        
                        final activeConfig = ref.read(homeConfigProvider).activeConfig;
                        String targetId = activeConfig.userId;
                        if (_shareWithAll && targetId.isNotEmpty && targetId != 'guest') {
                          FirebaseFirestore.instance.collection('users').doc(targetId).collection('schedules').doc(newId).set(newSchedule);
                          
                          if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null) {
                            String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
                            FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
                              'type': 'automation_edit',
                              'author': name,
                              'actionName': isEdit ? (context.tr('act_edit_schedule') ?? 'vừa sửa một lịch trình') : (context.tr('act_add_schedule') ?? 'vừa thêm một lịch trình mới'),
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          }
                        } else {
                          _saveSchedulesToDisk();
                        }
                        Navigator.pop(context);
                        showAlertDialogHelper(context, context.tr('msg_saved_title'), context.tr('msg_schedule_saved'));
                      },
                      child: Text(context.tr('schedule_save'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
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
    List<String> sTopics = List<String>.from(schedule['topics'] ?? (schedule['topic'] != null ? [schedule['topic']] : []));
    String deviceNames = sTopics.map((t) => getDeviceNameHelper(context, t, activeConfig)).join(', ');
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.5, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Text(context.tr('schedule_view_only'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text('${context.tr('device_label')} $deviceNames', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Text('${context.tr('time_on_label')} ${schedule['timeOn']}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 10),
              Text('${context.tr('time_off_label')} ${schedule['timeOff']}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              Text(context.tr('err_no_permission_schedule'), style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
              const Spacer(),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.tr('btn_close'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              )
            ]
          )
        );
      }
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
            String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
            FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
              'type': 'automation_edit',
              'author': name,
              'actionName': context.tr('act_delete_schedule') ?? 'vừa xóa một lịch trình',
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        } else {
          _saveSchedulesToDisk();
        }
        
        showFloatingToast(context, context.tr('msg_deleted_title'), context.tr('msg_schedule_deleted_desc'));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('schedule_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => _showScheduleBottomSheet(), icon: const Icon(Icons.add_circle, color: Color(0xFF2A3A7C), size: 30)),
          ],
        ),
        const SizedBox(height: 15),
        _savedSchedules.isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(context.tr('schedule_empty'), style: TextStyle(color: Colors.grey.shade500))))
            : ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _savedSchedules.length,
                itemBuilder: (context, index) {
                  final schedule = _savedSchedules[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: BorderRadius.circular(20), border: isDark ? Border.all(color: Colors.grey.shade800) : null, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: schedule['isActive'] ? const Color(0xFF2A3A7C) : Colors.grey, size: 40), const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(List<String>.from(schedule['topics'] ?? (schedule['topic'] != null ? [schedule['topic']] : [])).map((t) => getDeviceNameHelper(context, t, ref.watch(homeConfigProvider).activeConfig)).join(', '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  const SizedBox(width: 5),
                                  if (schedule['isShared'] == true)
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)), child: Text(context.tr('shared'), style: const TextStyle(color: Colors.blue, fontSize: 10)))
                                  else
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: Text(context.tr('private'), style: const TextStyle(color: Colors.grey, fontSize: 10))),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text('${context.tr('status_on')}: ${schedule['timeOn']} - ${context.tr('status_off')}: ${schedule['timeOff']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)), const SizedBox(height: 5),
                              Row(children: List.generate(7, (dayIndex) { bool isActiveDay = schedule['days'][dayIndex]; return Container(margin: const EdgeInsets.only(right: 4), width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isActiveDay ? Colors.green : Colors.grey.shade300)); }))
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Switch(
                              value: schedule['isActive'], activeColor: const Color(0xFF2A3A7C),
                              onChanged: (val) {
                                final mqttState = ref.read(mqttConnectionStateProvider);
                                final isOnline = ref.read(espOnlineStateProvider);
                                if (mqttState != 2 || !isOnline) {
                                  showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
                                  return;
                                }
                                
                                setState(() => schedule['isActive'] = val);
                                String daysBinary = List<bool>.from(schedule['days']).map((d) => d ? '1' : '0').join('');
                                String activeFlag = val ? '1' : '0';
                                String payload = '${schedule['id']}|${schedule['timeOn']}|${schedule['timeOff']}|$daysBinary|$activeFlag';
                                List<String> sTopics = List<String>.from(schedule['topics'] ?? (schedule['topic'] != null ? [schedule['topic']] : []));
                                for (String dev in sTopics) {
                                  ref.read(mqttRepositoryProvider).publishCmd('$dev/schedule', payload);
                                }
                                
                                final activeConfig = ref.read(homeConfigProvider).activeConfig;
                                String targetId = activeConfig.userId;
                                if (schedule['isShared'] == true && targetId.isNotEmpty && targetId != 'guest') {
                                  FirebaseFirestore.instance.collection('users').doc(targetId).collection('schedules').doc(schedule['id']).update({'isActive': val});
                                } else {
                                  _saveSchedulesToDisk();
                                }
                              }
                            ),
                              Row(
                                children: [
                                  if (schedule['isShared'] == true && ref.watch(homeConfigProvider).activeConfig.role == 'member' && !ref.watch(homeConfigProvider).activeConfig.canEditAutomation && schedule['authorUid'] != FirebaseAuth.instance.currentUser?.uid) ...[
                                    IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue, size: 20), onPressed: () => _showViewOnlyScheduleBottomSheet(schedule)),
                                  ] else ...[
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showScheduleBottomSheet(editSchedule: schedule)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => _deleteSchedule(schedule['id'])),
                                  ]
                                ],
                              )
                          ],
                        )
                      ],
                    ),
                  );
                },
              )
      ],
    );
  }
}