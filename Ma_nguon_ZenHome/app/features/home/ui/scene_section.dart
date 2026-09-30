import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class SceneSection extends ConsumerStatefulWidget {
  const SceneSection({super.key});

  @override
  ConsumerState<SceneSection> createState() => _SceneSectionState();
}

class _SceneSectionState extends ConsumerState<SceneSection> {
  final List<IconData> _availableIcons = [
    Icons.auto_awesome, Icons.movie, Icons.dinner_dining, Icons.sports_esports,
    Icons.nights_stay, Icons.work, Icons.music_note, Icons.fitness_center,
    Icons.coffee, Icons.local_bar, Icons.directions_run, Icons.home_filled,
  ];
  
  List<Map<String, dynamic>> _customScenes = [];

  @override
  void initState() {
    super.initState();
    _loadScenesFromDisk();
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'movie':
        return Icons.movie;
      case 'dinner_dining':
        return Icons.dinner_dining;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'nights_stay':
        return Icons.nights_stay;
      case 'work':
        return Icons.work;
      case 'music_note':
        return Icons.music_note;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'coffee':
        return Icons.coffee;
      case 'local_bar':
        return Icons.local_bar;
      case 'directions_run':
        return Icons.directions_run;
      case 'home_filled':
        return Icons.home_filled;
      default:
        return Icons.auto_awesome;
    }
  }

  String _iconName(IconData icon) {
    if (icon == Icons.auto_awesome) return 'auto_awesome';
    if (icon == Icons.movie) return 'movie';
    if (icon == Icons.dinner_dining) return 'dinner_dining';
    if (icon == Icons.sports_esports) return 'sports_esports';
    if (icon == Icons.nights_stay) return 'nights_stay';
    if (icon == Icons.work) return 'work';
    if (icon == Icons.music_note) return 'music_note';
    if (icon == Icons.fitness_center) return 'fitness_center';
    if (icon == Icons.coffee) return 'coffee';
    if (icon == Icons.local_bar) return 'local_bar';
    if (icon == Icons.directions_run) return 'directions_run';
    if (icon == Icons.home_filled) return 'home_filled';
    return 'auto_awesome';
  }

  // --- HÀM TẢI NGỮ CẢNH TỪ BỘ NHỚ VÀ FIREBASE LÊN ---
  Future<void> _loadScenesFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    
    // Migration: nếu có dữ liệu cũ chưa có targetId, nạp nó lên và sau đó xóa
    String? data = prefs.getString('custom_scenes_data_$targetId');
    if (data == null && prefs.containsKey('custom_scenes_data')) {
      data = prefs.getString('custom_scenes_data');
      prefs.remove('custom_scenes_data');
    }
    
    List<dynamic> localScenes = [];
    if (data != null) {
      localScenes = jsonDecode(data);
    }
    
    List<dynamic> sharedScenes = [];
    if (targetId.isNotEmpty && targetId != 'guest') {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetId)
            .collection('scenes')
            .get();
        for (var doc in snap.docs) {
          sharedScenes.add(doc.data());
        }
      } catch (e) {
        debugPrint("Error fetching shared scenes: $e");
      }
    }
    
    List<Map<String, dynamic>> combined = [];
    combined.addAll(localScenes.map((e) => Map<String, dynamic>.from(e)));
    combined.addAll(sharedScenes.map((e) => Map<String, dynamic>.from(e)));
    
    Map<String, Map<String, dynamic>> uniqueMap = {};
    for (var item in combined) {
      uniqueMap[item['id']] = item;
    }

    setState(() {
      _customScenes = uniqueMap.values.map((item) => {
        'id': item['id'],
        'name': item['name'],
        'icon': _iconFromName(item['iconName'] ?? 'auto_awesome'),
        'color': Color(item['colorValue']),
        'actions': Map<String, String>.from(item['actions']),
        'isShared': item['isShared'] ?? false,
        'order': item['order'] ?? 0,
        'authorUid': item['authorUid'] ?? '',
      }).toList();
      _customScenes.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
    });
  }

  // --- HÀM LƯU NGỮ CẢNH XUỐNG BỘ NHỚ ---
  Future<void> _saveScenesToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> toSave = _customScenes.map((item) => {
      'id': item['id'],
      'name': item['name'],
      'iconName': _iconName(item['icon'] as IconData),
      'colorValue': (item['color'] as Color).value,
      'actions': item['actions'],
      'isShared': item['isShared'] ?? false,
      'order': item['order'] ?? 0,
      'authorUid': item['authorUid'] ?? '',
    }).toList();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    await prefs.setString('custom_scenes_data_$targetId', jsonEncode(toSave));
  }



  String _getSceneName(Map<String, dynamic> scene) {
    if (scene['id'] == 'leave') return context.tr('scene_leave');
    if (scene['id'] == 'home') return context.tr('scene_home');
    return scene['name'];
  }

  bool _isSceneOnCooldown = false;

  void _executeCustomScene(Map<String, dynamic> scene) {
    if (_isSceneOnCooldown) {
      showFloatingToast(context, context.tr('toast_sys_report') ?? 'Hệ thống', context.tr('msg_processing') ?? 'Đang xử lý, vui lòng đợi...');
      return;
    }

    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);
    if (mqttState != 2 || !isOnline) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }
    
    setState(() => _isSceneOnCooldown = true);
    
    HapticFeedback.heavyImpact(); // Rung mạnh khi kích hoạt ngữ cảnh

    Map<String, String> actions = scene['actions'];
    actions.forEach((topic, command) => ref.read(mqttRepositoryProvider).publishCmd('$topic/cmd', command));
    showFloatingToast(context, context.tr('toast_activated'), _getSceneName(scene));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSceneOnCooldown = false);
      }
    });
  }

  void _showAddSceneBottomSheet({Map<String, dynamic>? editScene}) {
    bool isEdit = editScene != null;
    String newSceneName = isEdit ? editScene['name'] : '';
    IconData selectedIcon = isEdit ? editScene['icon'] : Icons.auto_awesome;
    Color selectedColor = isEdit ? editScene['color'] : Colors.purple;
    bool _shareWithAll = isEdit ? (editScene['isShared'] ?? false) : false;
    
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final dynamicDeviceTopicsList = getSortedDeviceTopicsList(context, activeConfig);
    Map<String, String?> newActions = {};
    for (String baseTopic in dynamicDeviceTopicsList) {
      newActions[baseTopic] = null; 
    }
    
    if (isEdit) {
      Map<String, String> existingActions = editScene['actions'];
      existingActions.forEach((key, val) {
        if (newActions.containsKey(key)) {
          newActions[key] = val;
        }
      });
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85, 
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121827) : Colors.white, 
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text(isEdit ? context.tr('scene_edit') : context.tr('scene_create'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    initialValue: newSceneName, 
                    decoration: InputDecoration(labelText: context.tr('scene_name_hint'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), 
                    onChanged: (val) => newSceneName = val
                  ),
                  const SizedBox(height: 25),
                  
                  Text(context.tr('select_icon'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal, itemCount: _availableIcons.length,
                      itemBuilder: (context, index) {
                        IconData icon = _availableIcons[index]; 
                        bool isSelected = selectedIcon == icon;
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedIcon = icon),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200), width: 60, margin: const EdgeInsets.only(right: 15),
                            decoration: BoxDecoration(color: isSelected ? const Color(0xFF2A3A7C) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100), shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 2) : null, boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF2A3A7C).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : null),
                            child: Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54), size: 28),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  Text(context.tr('set_actions'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: dynamicDeviceTopicsList.map((topic) {
                        String name = getDeviceNameHelper(context, topic, activeConfig); 
                        String? currentAction = newActions[topic];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(child: ChoiceChip(label: Center(child: Text(context.tr('action_ignore'))), selected: currentAction == null, onSelected: (val) => setModalState(() => newActions[topic] = null))), const SizedBox(width: 8),
                                  Expanded(child: ChoiceChip(label: Center(child: Text(context.tr('action_on'))), selectedColor: Colors.green.shade200, selected: currentAction == '1', onSelected: (val) => setModalState(() => newActions[topic] = '1'))), const SizedBox(width: 8),
                                  Expanded(child: ChoiceChip(label: Center(child: Text(context.tr('action_off'))), selectedColor: Colors.red.shade200, selected: currentAction == '0', onSelected: (val) => setModalState(() => newActions[topic] = '0'))),
                                ],
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () {
                        if (newSceneName.trim().isEmpty) { 
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('err_empty_name')), backgroundColor: Colors.red)); 
                          return; 
                        }
                        
                        Map<String, String> finalActions = {};
                        newActions.forEach((key, value) { 
                          if (value != null) finalActions[key] = value; 
                        });
                        
                        if (finalActions.isEmpty) { 
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('err_no_action')), backgroundColor: Colors.red)); 
                          return; 
                        }
                        
                        
                        String newId = isEdit ? editScene['id'] : DateTime.now().millisecondsSinceEpoch.toString();
                        Map<String, dynamic> newScene = {
                          'id': newId,
                          'name': newSceneName,
                          'icon': selectedIcon,
                          'color': selectedColor,
                          'actions': finalActions,
                          'isShared': _shareWithAll,
                          'order': isEdit ? editScene['order'] : _customScenes.length,
                          'authorUid': isEdit ? editScene['authorUid'] : FirebaseAuth.instance.currentUser?.uid ?? '',
                          'iconName': _iconName(selectedIcon),
                          'colorValue': selectedColor.value,
                        };
                        
                        Map<String, dynamic> firebaseScene = {
                          'id': newId, 
                          'name': newSceneName, 
                          'actions': finalActions, 
                          'isShared': _shareWithAll,
                          'iconName': _iconName(selectedIcon),
                          'colorValue': selectedColor.value,
                          'order': newScene['order'],
                          'authorUid': newScene['authorUid'],
                        };
                        
                        setState(() {
                          if (isEdit) {
                            int idx = _customScenes.indexWhere((s) => s['id'] == editScene['id']);
                            _customScenes[idx] = newScene;
                          } else {
                            _customScenes.add(newScene);
                          }
                        });
                        
                        final activeConfig = ref.read(homeConfigProvider).activeConfig;
                        String targetId = activeConfig.userId;
                        if (_shareWithAll && targetId.isNotEmpty && targetId != 'guest') {
                          FirebaseFirestore.instance.collection('users').doc(targetId).collection('scenes').doc(newId).set(firebaseScene);
                          
                          if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null) {
                            String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
                            FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
                              'type': 'automation_edit',
                              'author': name,
                              'actionName': isEdit ? (context.tr('act_edit_scene') ?? 'vừa sửa một ngữ cảnh') : (context.tr('act_add_scene') ?? 'vừa thêm một ngữ cảnh mới'),
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          }
                        } else if (targetId.isNotEmpty && targetId != 'guest') {
                          FirebaseFirestore.instance.collection('users').doc(targetId).collection('scenes').doc(newId).delete();
                        }
                        _saveScenesToDisk();
                        
                        Navigator.pop(context);
                        showAlertDialogHelper(context, context.tr('msg_saved_title'), context.tr('msg_saved_desc'));
                      },
                      child: Text(context.tr('btn_save'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(context.tr('scene_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => _showAddSceneBottomSheet(), icon: const Icon(Icons.add_circle, color: Color(0xFF2A3A7C), size: 30)),
          ],
        ),
        const SizedBox(height: 15),
        
        if (_customScenes.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(context.tr('schedule_empty'), style: TextStyle(color: Colors.grey.shade500))))
        else
          SizedBox(
            height: 140,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal, itemCount: _customScenes.length,
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                HapticFeedback.heavyImpact();
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double scale = 1.0 + (0.08 * animValue);
                    
                    return Transform.scale(
                      scale: scale,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final Map<String, dynamic> item = _customScenes.removeAt(oldIndex);
                  _customScenes.insert(newIndex, item);
                  
                  // Update order field
                  for (int i = 0; i < _customScenes.length; i++) {
                    _customScenes[i]['order'] = i;
                  }
                  _saveScenesToDisk();
                  
                  final activeConfig = ref.read(homeConfigProvider).activeConfig;
                  String targetId = activeConfig.userId;
                  if (targetId.isNotEmpty && targetId != 'guest') {
                    for (var s in _customScenes) {
                      if (s['isShared'] == true) {
                        FirebaseFirestore.instance.collection('users').doc(targetId).collection('scenes').doc(s['id']).update({'order': s['order']});
                      }
                    }
                  }
                });
              },
              itemBuilder: (context, index) {
                final scene = _customScenes[index];
                return GestureDetector(
                  key: ValueKey(scene['id']),
                  onTap: () => _executeCustomScene(scene),
                  child: Stack(
                      children: [
                        Container(
                          width: 120, margin: const EdgeInsets.only(right: 15, bottom: 5), padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: BorderRadius.circular(20), border: isDark ? Border.all(color: Colors.grey.shade800) : null, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (scene['color'] as Color).withOpacity(0.2), shape: BoxShape.circle), child: Icon(scene['icon'], color: scene['color'], size: 24)),
                              const Spacer(),
                              Text(_getSceneName(scene), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 15,
                          child: Row(
                            children: [
                              Icon(scene['isShared'] == true ? Icons.public : Icons.lock_outline, size: 16, color: Colors.grey.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context, backgroundColor: Colors.transparent,
                                    builder: (ctx) => Container(
                                      padding: const EdgeInsets.only(top: 20, bottom: 40, left: 20, right: 20),
                                      decoration: BoxDecoration(color: isDark ? const Color(0xFF121827) : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
                                          const SizedBox(height: 20), 
                                          Text('${context.tr('scene_options')}: ${_getSceneName(scene)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), 
                                          const SizedBox(height: 20),
                                          if (scene['isShared'] != true || ref.read(homeConfigProvider).activeConfig.role != 'member' || ref.read(homeConfigProvider).activeConfig.canEditAutomation || scene['authorUid'] == FirebaseAuth.instance.currentUser?.uid) ...[
                                            ListTile(
                                              leading: const Icon(Icons.edit, color: Colors.blue), 
                                              title: Text(context.tr('scene_edit')), 
                                              onTap: () { 
                                                Navigator.pop(ctx); 
                                                _showAddSceneBottomSheet(editScene: scene); 
                                              }
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.delete, color: Colors.red), 
                                              title: Text(context.tr('scene_delete'), style: const TextStyle(color: Colors.red)), 
                                              onTap: () { 
                                                  Navigator.pop(ctx);
                                                  
                                                  showPremiumConfirmDialog(
                                                    context: context,
                                                    title: context.tr('confirm_title'),
                                                    message: context.tr('confirm_delete_scene') ?? 'Bạn có chắc chắn muốn xóa ngữ cảnh này không?',
                                                    confirmText: context.tr('btn_delete'),
                                                    cancelText: context.tr('btn_cancel'),
                                                    isDanger: true,
                                                    icon: Icons.delete_forever,
                                                    onConfirm: () {
                                                      setState(() => _customScenes.removeAt(index)); 
                                                      final activeConfig = ref.read(homeConfigProvider).activeConfig;
                                                      String targetId = activeConfig.userId;
                                                      if (scene['isShared'] == true && targetId.isNotEmpty && targetId != 'guest') {
                                                        FirebaseFirestore.instance.collection('users').doc(targetId).collection('scenes').doc(scene['id']).delete();
                                                        
                                                        if (activeConfig.role != 'owner' && FirebaseAuth.instance.currentUser != null) {
                                                          String name = FirebaseAuth.instance.currentUser!.displayName ?? FirebaseAuth.instance.currentUser!.email ?? context.tr('a_member') ?? 'Một thành viên';
                                                          FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
                                                            'type': 'automation_edit',
                                                            'author': name,
                                                            'actionName': context.tr('act_delete_scene') ?? 'vừa xóa một ngữ cảnh',
                                                            'timestamp': FieldValue.serverTimestamp(),
                                                          });
                                                        }
                                                      }
                                                      _saveScenesToDisk();
                                                      showFloatingToast(context, context.tr('msg_deleted_title'), context.tr('msg_scene_deleted') ?? 'Đã xóa ngữ cảnh thành công!');
                                                    }
                                                  );
                                                }
                                            ),
                                          ] else ...[
                                            ListTile(
                                              leading: const Icon(Icons.info, color: Colors.orange), 
                                              title: Text(context.tr('err_no_permission_scene'), style: const TextStyle(color: Colors.orange, fontSize: 14)), 
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(Icons.more_vert, size: 18, color: Colors.grey.withOpacity(0.7)),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                );
              },
            ),
          ),
        const SizedBox(height: 5),
        if (_customScenes.isNotEmpty) Text(context.tr('tip_scene'), style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
      ],
    );
  }
}