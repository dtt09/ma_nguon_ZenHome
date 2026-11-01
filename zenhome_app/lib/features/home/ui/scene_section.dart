import 'dart:ui';
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
import 'package:zenhome_app/core/services/local_network_service.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';

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

  final List<Color> _availableColors = [
    const Color(0xFF0D9488), // Teal
    const Color(0xFF10B981), // Emerald
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFF97316), // Orange
    const Color(0xFFF43F5E), // Rose
    const Color(0xFF06B6D4), // Cyan
  ];
  
  List<Map<String, dynamic>> _customScenes = [];
  StreamSubscription<QuerySnapshot>? _scenesSubscription;

  @override
  void initState() {
    super.initState();
    _loadScenesFromDisk();
    _subscribeToFirestoreScenes();
  }

  @override
  void dispose() {
    _scenesSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToFirestoreScenes() {
    _scenesSubscription?.cancel();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    if (targetId.isEmpty || targetId == 'guest') return;

    _scenesSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(targetId)
        .collection('scenes')
        .snapshots()
        .listen((snap) async {
      final prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString('custom_scenes_data_$targetId');
      List<dynamic> localScenes = (data != null) ? jsonDecode(data) : [];
      List<dynamic> firestoreScenes = snap.docs.map((doc) => doc.data()).toList();

      List<Map<String, dynamic>> combined = [];
      combined.addAll(localScenes.map((e) => Map<String, dynamic>.from(e)));
      combined.addAll(firestoreScenes.map((e) => Map<String, dynamic>.from(e)));

      Map<String, Map<String, dynamic>> uniqueMap = {};
      for (var item in combined) {
        if (item['id'] != null) {
          uniqueMap[item['id']] = item;
        }
      }

      if (mounted) {
        if (!mounted) return;
    setState(() {
          _customScenes = uniqueMap.values.map((item) => {
            'id': item['id'],
            'name': item['name'],
            'icon': _iconFromName(item['iconName'] ?? 'auto_awesome'),
            'color': Color(item['colorValue'] ?? 0xFF10B981),
            'actions': Map<String, String>.from(item['actions'] ?? {}),
            'isShared': item['isShared'] ?? false,
            'order': item['order'] ?? 0,
            'authorUid': item['authorUid'] ?? '',
            'authorName': item['authorName'] ?? '',
          }).toList();
          _customScenes.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
        });
      }
    }, onError: (err) {
      debugPrint("Lỗi stream scenes: $err");
    });
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
      final id = item['id'];
      if (id != null && id.toString().isNotEmpty) {
        uniqueMap[id.toString()] = item;
      }
    }

    if (!mounted) return;
    setState(() {
      _customScenes = uniqueMap.values.map((item) {
        final rawColor = item['colorValue'];
        final colorInt = (rawColor is int) ? rawColor : 0xFF4F46E5;
        final rawActions = item['actions'];
        final actionsMap = (rawActions is Map) 
            ? rawActions.map((k, v) => MapEntry(k.toString(), v.toString())) 
            : <String, String>{};
        final rawOrder = item['order'];
        final orderVal = (rawOrder is int) ? rawOrder : 0;

        return {
          'id': item['id']?.toString() ?? '',
          'name': item['name']?.toString() ?? 'Ngữ cảnh',
          'icon': _iconFromName(item['iconName']?.toString() ?? 'auto_awesome'),
          'color': Color(colorInt),
          'actions': actionsMap,
          'isShared': item['isShared'] ?? false,
          'order': orderVal,
          'authorUid': item['authorUid']?.toString() ?? '',
          'authorName': item['authorName']?.toString() ?? '',
        };
      }).toList();
      _customScenes.sort((a, b) => ((a['order'] ?? 0) as int).compareTo((b['order'] ?? 0) as int));
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
      'authorName': item['authorName'] ?? '',
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

  bool _canManageScene(Map<String, dynamic> scene) {
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final bool isShared = scene['isShared'] == true;
    final String authorUid = scene['authorUid'] ?? '';

    // Ngữ cảnh cá nhân: chỉ tác giả
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

    // Tác giả tự tạo ngữ cảnh chia sẻ
    if (authorUid.isNotEmpty && authorUid == currentUid) {
      return true;
    }

    return false;
  }

  bool _isSceneOnCooldown = false;

  void _executeCustomScene(Map<String, dynamic> scene) {
    if (_isSceneOnCooldown) {
      showFloatingToast(context, context.tr('toast_sys_report') ?? 'Hệ thống', context.tr('msg_processing') ?? 'Đang xử lý, vui lòng đợi...');
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    // Kiểm tra nếu tài khoản đang bị Chủ nhà tạm khóa quyền điều khiển
    if (activeConfig.isDisabled) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('member_disabled_msg') ?? 'Tài khoản của bạn đã bị Chủ nhà tạm khóa quyền điều khiển!',
        isError: true,
      );
      return;
    }

    final localService = ref.read(localNetworkServiceProvider);
    final isLocalAvailable = localService.isLocalAvailable;
    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);

    if (!isLocalAvailable && (mqttState != 2 || !isOnline)) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }

    // Lọc các thiết bị mà thành viên được phép điều khiển
    Map<String, String> actions = Map<String, String>.from(scene['actions'] ?? {});
    if (activeConfig.role != 'owner' && activeConfig.role != 'co_owner' && activeConfig.allowedDevices != null) {
      actions.removeWhere((topic, _) {
        String devId = topic.split('/').last;
        return !activeConfig.allowedDevices!.contains(devId);
      });
    }

    if (actions.isEmpty) {
      showFloatingToast(
        context,
        context.tr('error'),
        'Bạn không có quyền điều khiển các thiết bị trong ngữ cảnh này!',
        isError: true,
      );
      return;
    }
    
    setState(() => _isSceneOnCooldown = true);
    
    HapticFeedback.heavyImpact(); // Rung mạnh khi kích hoạt ngữ cảnh

    // Thực thi các hành động với độ trễ xen kẽ (Staggered Execution: 60ms) chống sụt áp nguồn (Brownout Protection)
    final mqttPrefix = activeConfig.mqttPrefix;
    final cleanPrefix = mqttPrefix.replaceAll(':', '');

    final user = FirebaseAuth.instance.currentUser;
    String currentUsername = activeConfig.userId;
    if (user != null) {
      currentUsername = user.displayName ?? (user.email?.split('@')[0] ?? user.uid);
    }

    int delayMs = 0;
    actions.forEach((topic, command) {
      String devId = topic.split('/').last;
      String roomId = 'living_room';
      final parts = topic.split('/');
      if (parts.length >= 2) {
        roomId = parts[parts.length - 2];
      }

      final payloadMap = {
        'action': command,
        'user': currentUsername,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      final mqttPayload = jsonEncode(payloadMap);

      Future.delayed(Duration(milliseconds: delayMs), () {
        ref.read(pendingDeviceOperationsProvider.notifier).setPending(devId, true);

        if (isLocalAvailable) {
          localService.sendLocalControl(devId: devId, cmd: command).then((success) {
            if (!success) {
              // Dự phòng sang MQTT Cloud nếu LAN không nhận lệnh
              ref.read(mqttRepositoryProvider).publishCmd('$mqttPrefix/$roomId/$devId/cmd', mqttPayload);
            }
          });
        } else {
          final targetTopic = '$mqttPrefix/$roomId/$devId/cmd';
          ref.read(mqttRepositoryProvider).publishCmd(targetTopic, mqttPayload);
          if (cleanPrefix != mqttPrefix) {
            ref.read(mqttRepositoryProvider).publishCmd('$cleanPrefix/$roomId/$devId/cmd', mqttPayload);
          }
        }
      });
      delayMs += 60; // Xen kẽ 60ms giữa các cuộn hút rơ-le
    });

    if (isLocalAvailable) {
      showFloatingToast(context, context.tr('toast_activated'), '${_getSceneName(scene)} (Local ⚡)');
    } else {
      showFloatingToast(context, context.tr('toast_activated'), '${_getSceneName(scene)} (Cloud)');
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSceneOnCooldown = false);
      }
    });
  }

  void _showAddSceneBottomSheet({Map<String, dynamic>? editScene}) {
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

    bool isEdit = editScene != null;
    String newSceneName = isEdit ? editScene['name'] : '';
    IconData selectedIcon = isEdit ? editScene['icon'] : Icons.auto_awesome;
    Color selectedColor = isEdit ? editScene['color'] : Colors.purple;
    bool _shareWithAll = isEdit ? (editScene['isShared'] ?? false) : false;
    
    final allTopics = getSortedDeviceTopicsList(context, activeConfig);
    final dynamicDeviceTopicsList = allTopics.where((topic) {
      if (activeConfig.role == 'owner' || activeConfig.role == 'co_owner' || activeConfig.allowedDevices == null) {
        return true;
      }
      final devId = topic.split('/').last;
      return activeConfig.allowedDevices!.contains(devId);
    }).toList();

    if (dynamicDeviceTopicsList.isEmpty) {
      showFloatingToast(context, context.tr('error'), 'Bạn không có quyền điều khiển thiết bị nào để tạo ngữ cảnh.', isError: true);
      return;
    }
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color sheetBg = isDark ? const Color(0xF20F172A) : const Color(0xF8FFFFFF);
            final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final Color subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final Color cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
            final Color cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.88,
                  padding: EdgeInsets.only(
                    top: 14,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    color: sheetBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.6 : 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, -6),
                      ),
                      BoxShadow(
                        color: selectedColor.withOpacity(isDark ? 0.18 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header Row
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  selectedColor.withOpacity(0.25),
                                  selectedColor.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selectedColor.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: selectedColor.withOpacity(0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(selectedIcon, color: selectedColor, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? context.tr('scene_edit') : context.tr('scene_create'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kịch bản thông minh đồng bộ chỉ với 1 chạm',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close_rounded,
                              color: subTextColor,
                              size: 22,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Nội dung cuộn chính
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // 1. Tên Ngữ cảnh
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selectedColor.withOpacity(0.35),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: selectedColor.withOpacity(isDark ? 0.1 : 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                initialValue: newSceneName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixIcon: Icon(Icons.edit_note_rounded, color: selectedColor, size: 22),
                                  labelText: context.tr('scene_name_hint'),
                                  labelStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: subTextColor,
                                  ),
                                  floatingLabelStyle: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: selectedColor,
                                  ),
                                  border: InputBorder.none,
                                  hintText: 'VD: Rời khỏi nhà, Thư giãn tối...',
                                  hintStyle: TextStyle(
                                    color: subTextColor.withOpacity(0.6),
                                    fontSize: 13.5,
                                  ),
                                ),
                                onChanged: (val) => newSceneName = val,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 2. Chọn Icon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr('select_icon'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: selectedColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '12 Biểu tượng',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: selectedColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 54,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _availableIcons.length,
                                itemBuilder: (context, index) {
                                  final icon = _availableIcons[index];
                                  final bool isSelected = selectedIcon == icon;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => selectedIcon = icon);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 52,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? selectedColor
                                            : cardBg,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.white
                                              : cardBorder,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: selectedColor.withOpacity(0.55),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Icon(
                                        icon,
                                        color: isSelected
                                            ? Colors.white
                                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                                        size: 24,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 3. Chọn Màu Sắc Thần Thái
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr('choose_color'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: selectedColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: selectedColor.withOpacity(0.6),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 46,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _availableColors.length,
                                itemBuilder: (context, index) {
                                  final col = _availableColors[index];
                                  final bool isSelected = selectedColor.value == col.value;
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => selectedColor = col);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 44,
                                      height: 44,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: col,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          width: isSelected ? 2.8 : 0,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: col.withOpacity(0.65),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.12),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                      ),
                                      child: isSelected
                                          ? const Center(
                                              child: Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 4. Thiết lập hành động thiết bị
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr('set_actions'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '${newActions.values.where((v) => v != null).length}/${dynamicDeviceTopicsList.length} thiết bị',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: subTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Danh sách thiết bị dạng Luxury Card
                            ...dynamicDeviceTopicsList.map((topic) {
                              final name = getDeviceNameHelper(context, topic, activeConfig);
                              final devId = topic.split('/').last;
                              String roomName = '';
                              IconData devIcon = Icons.devices_other_rounded;
                              try {
                                final dev = activeConfig.devices.firstWhere((d) => d.id == devId);
                                roomName = dev.room;
                                switch (dev.icon) {
                                  case 'light': case 'lightbulb': devIcon = Icons.lightbulb_rounded; break;
                                  case 'fan': devIcon = Icons.mode_fan_off; break;
                                  case 'ac': devIcon = Icons.air_rounded; break;
                                  case 'socket': devIcon = Icons.power_rounded; break;
                                  case 'tv': devIcon = Icons.tv_rounded; break;
                                  case 'pump': case 'water': devIcon = Icons.water_drop_rounded; break;
                                  default: devIcon = Icons.bolt_rounded; break;
                                }
                              } catch (_) {}

                              final currentAction = newActions[topic];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: currentAction != null
                                        ? (currentAction == '1'
                                            ? const Color(0xFF10B981).withOpacity(0.4)
                                            : const Color(0xFFF43F5E).withOpacity(0.4))
                                        : cardBorder,
                                    width: currentAction != null ? 1.4 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Thông tin thiết bị
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: currentAction == '1'
                                                ? const Color(0xFF10B981).withOpacity(0.18)
                                                : (currentAction == '0'
                                                    ? const Color(0xFFF43F5E).withOpacity(0.18)
                                                    : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            devIcon,
                                            size: 18,
                                            color: currentAction == '1'
                                                ? const Color(0xFF10B981)
                                                : (currentAction == '0'
                                                    ? const Color(0xFFF43F5E)
                                                    : subTextColor),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.5,
                                                  color: textColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (roomName.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  context.tr(roomName),
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: subTextColor,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Bộ điều khiển 3 trạng thái Capsule (Bỏ qua / Bật / Tắt)
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          // 1. Bỏ qua
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setModalState(() => newActions[topic] = null);
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: currentAction == null
                                                      ? (isDark ? const Color(0xFF334155) : Colors.white)
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(11),
                                                  boxShadow: currentAction == null
                                                      ? [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 1),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    context.tr('action_ignore'),
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight: currentAction == null ? FontWeight.w800 : FontWeight.w600,
                                                      color: currentAction == null
                                                          ? textColor
                                                          : subTextColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // 2. BẬT
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setModalState(() => newActions[topic] = '1');
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  gradient: currentAction == '1'
                                                      ? const LinearGradient(
                                                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                                                        )
                                                      : null,
                                                  color: currentAction == '1' ? null : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(11),
                                                  boxShadow: currentAction == '1'
                                                      ? [
                                                          BoxShadow(
                                                            color: const Color(0xFF10B981).withOpacity(0.4),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      if (currentAction == '1')
                                                        const Padding(
                                                          padding: EdgeInsets.only(right: 4),
                                                          child: Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                                                        ),
                                                      Text(
                                                        context.tr('action_on'),
                                                        style: TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight: currentAction == '1' ? FontWeight.w800 : FontWeight.w600,
                                                          color: currentAction == '1'
                                                              ? Colors.white
                                                              : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // 3. TẮT
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.selectionClick();
                                                setModalState(() => newActions[topic] = '0');
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 180),
                                                padding: const EdgeInsets.symmetric(vertical: 8),
                                                decoration: BoxDecoration(
                                                  gradient: currentAction == '0'
                                                      ? const LinearGradient(
                                                          colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                                                        )
                                                      : null,
                                                  color: currentAction == '0' ? null : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(11),
                                                  boxShadow: currentAction == '0'
                                                      ? [
                                                          BoxShadow(
                                                            color: const Color(0xFFF43F5E).withOpacity(0.4),
                                                            blurRadius: 6,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ]
                                                      : null,
                                                ),
                                                child: Center(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      if (currentAction == '0')
                                                        const Padding(
                                                          padding: EdgeInsets.only(right: 4),
                                                          child: Icon(Icons.power_settings_new_rounded, size: 13, color: Colors.white),
                                                        ),
                                                      Text(
                                                        context.tr('action_off'),
                                                        style: TextStyle(
                                                          fontSize: 12.5,
                                                          fontWeight: currentAction == '0' ? FontWeight.w800 : FontWeight.w600,
                                                          color: currentAction == '0'
                                                              ? Colors.white
                                                              : (isDark ? const Color(0xFFFB7185) : const Color(0xFFE11D48)),
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
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 14),

                            // 5. Thẻ Chia Sẻ Gia Đình (Family Sharing Card)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.group_work_rounded,
                                      color: Color(0xFF6366F1),
                                      size: 20,
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
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tất cả thành viên trong nhà đều có thể kích hoạt',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: subTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _shareWithAll,
                                    activeColor: selectedColor,
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      setModalState(() => _shareWithAll = val);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),

                      // Thanh nút bấm Action bên dưới
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(color: cardBorder, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                context.tr('btn_close'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: subTextColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: 4,
                                shadowColor: selectedColor.withOpacity(0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
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
                                
                                HapticFeedback.heavyImpact();
                                String newId = isEdit ? editScene['id'] : DateTime.now().millisecondsSinceEpoch.toString();
                                final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                                final currentName = FirebaseAuth.instance.currentUser?.displayName ?? 
                                                    FirebaseAuth.instance.currentUser?.email ?? 'Thành viên';
                                final authorUid = isEdit ? (editScene['authorUid'] ?? currentUid) : currentUid;
                                final authorName = isEdit ? (editScene['authorName'] ?? currentName) : currentName;

                                Map<String, dynamic> newScene = {
                                  'id': newId,
                                  'name': newSceneName,
                                  'icon': selectedIcon,
                                  'color': selectedColor,
                                  'actions': finalActions,
                                  'isShared': _shareWithAll,
                                  'order': isEdit ? editScene['order'] : _customScenes.length,
                                  'authorUid': authorUid,
                                  'authorName': authorName,
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
                                  'authorUid': authorUid,
                                  'authorName': authorName,
                                };
                                
                                if (!mounted) return;
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
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    context.tr('btn_save'),
                                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeConfigProvider, (previous, next) {
      if (previous?.activeConfig.userId != next.activeConfig.userId) {
        _scenesSubscription?.cancel();
        _loadScenesFromDisk();
        _subscribeToFirestoreScenes();
      }
    });

    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.purpleGlow.withOpacity(0.2), AppColors.primaryLight.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.purpleGlow, size: 18),
                ),
                const SizedBox(width: 10),
                Text(context.tr('scene_title'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                if (_customScenes.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_customScenes.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            BouncingButton(
              onTap: () => _showAddSceneBottomSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.navPillGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      context.tr('btn_add') ?? 'Add',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        
        if (_customScenes.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 36, color: (isDark ? Colors.white : Colors.black).withOpacity(0.25)),
                  const SizedBox(height: 10),
                  Text(context.tr('scene_empty'), style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 152,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _customScenes.length,
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                HapticFeedback.heavyImpact();
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double scale = 1.0 + (0.06 * animValue);
                    
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
                if (!mounted) return;
    setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final Map<String, dynamic> item = _customScenes.removeAt(oldIndex);
                  _customScenes.insert(newIndex, item);
                  
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
                final Color sceneColor = scene['color'] as Color;
                final int actionCount = (scene['actions'] as Map?)?.length ?? 0;

                return BouncingButton(
                  key: ValueKey(scene['id']),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _executeCustomScene(scene);
                  },
                  child: Container(
                    width: 136,
                    margin: const EdgeInsets.only(right: 14, bottom: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      gradient: LinearGradient(
                        colors: isDark
                            ? [sceneColor.withOpacity(0.14), AppColors.darkCard]
                            : [sceneColor.withOpacity(0.08), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: sceneColor.withOpacity(isDark ? 0.3 : 0.2),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: sceneColor.withOpacity(isDark ? 0.15 : 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Icon & Status / Menu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: sceneColor.withOpacity(isDark ? 0.22 : 0.14),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: sceneColor.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(scene['icon'], color: sceneColor, size: 22),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  scene['isShared'] == true ? Icons.public : Icons.lock_outline,
                                  size: 14,
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                                ),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Colors.transparent,
                                      builder: (ctx) => Container(
                                        padding: const EdgeInsets.only(top: 20, bottom: 40, left: 20, right: 20),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.darkCardElevated : Colors.white,
                                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
                                            const SizedBox(height: 18), 
                                            Text(
                                              '${context.tr('scene_options')}: ${_getSceneName(scene)}',
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            ), 
                                            const SizedBox(height: 16),
                                            if (_canManageScene(scene)) ...[
                                              ListTile(
                                                leading: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                                                  child: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                ),
                                                title: Text(context.tr('scene_edit'), style: const TextStyle(fontWeight: FontWeight.w600)), 
                                                onTap: () { 
                                                  Navigator.pop(ctx); 
                                                  _showAddSceneBottomSheet(editScene: scene); 
                                                }
                                              ),
                                              ListTile(
                                                leading: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                                                  child: const Icon(Icons.delete, color: Colors.red, size: 20),
                                                ),
                                                title: Text(context.tr('scene_delete'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)), 
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
                                                leading: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                                                  child: const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
                                                ),
                                                title: Text(context.tr('perm_view_activate_only'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                                subtitle: Text(
                                                  scene["authorName"] != null && scene["authorName"].toString().isNotEmpty
                                                      ? "Ngữ cảnh này do " + scene["authorName"].toString() + " tạo. Bạn có thể bấm để kích hoạt nhưng không có quyền sửa hoặc xóa."
                                                      : "Bạn có thể bấm để kích hoạt nhưng không có quyền sửa hoặc xóa ngữ cảnh chung này.",
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.more_vert, size: 18, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Bottom info: Scene Name and Action Count
                        Text(
                          _getSceneName(scene),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$actionCount ${context.tr('action')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 6),
        if (_customScenes.isNotEmpty)
          Text(
            context.tr('tip_scene'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
      ],
    );
  }
}
