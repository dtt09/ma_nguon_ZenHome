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
import 'package:zenhome_app/core/providers/local_network_provider.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

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
      currentUsername = user.email?.split('@')[0] ?? (activeConfig.userId.isNotEmpty ? activeConfig.userId : (user.displayName ?? user.uid));
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

    final zenInit = context.zenColors;
    bool isEdit = editScene != null;
    String newSceneName = isEdit ? editScene['name'] : '';
    IconData selectedIcon = isEdit ? editScene['icon'] : Icons.auto_awesome;
    Color selectedColor = isEdit ? editScene['color'] : zenInit.primary;
    bool _shareWithAll = isEdit ? (editScene['isShared'] ?? false) : false;

    final List<Color> colorOptions = [
      if (!_availableColors.any((c) => c.value == zenInit.primary.value)) zenInit.primary,
      ..._availableColors,
    ];
    if (isEdit && !colorOptions.any((c) => c.value == selectedColor.value)) {
      colorOptions.insert(0, selectedColor);
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

    showZenGlassBottomSheet(
      context: context,
      maxHeightFactor: 0.88,
      padBottomForKeyboard: true,
      accentColor: selectedColor,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
            final Color textColor = isDark ? AppColors.darkText : AppColors.lightText;
            final Color subTextColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row (showZenGlassBottomSheet already renders top drag handle)
                    Row(
                      children: [
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 18,
                          padding: const EdgeInsets.all(11),
                          glowColor: selectedColor,
                          rimWidth: 1.35,
                          surfaceColor: selectedColor.withOpacity(isDark ? 0.22 : 0.14),
                          customGradient: LinearGradient(
                            colors: [
                              selectedColor.withOpacity(isDark ? 0.30 : 0.20),
                              selectedColor.withOpacity(isDark ? 0.10 : 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          customShadows: [
                            BoxShadow(
                              color: selectedColor.withOpacity(isDark ? 0.32 : 0.20),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
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
                        ZenGlassIconButton(
                          icon: Icons.close_rounded,
                          size: 36,
                          iconSize: 19,
                          blurSigma: 0,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Nội dung cuộn chính
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // 1. Tên Ngữ cảnh (Zen Glass Input)
                          TextFormField(
                            initialValue: newSceneName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            decoration: zenGlassInputDecoration(
                              ctx,
                              labelText: context.tr('scene_name_hint'),
                              hintText: 'VD: Rời khỏi nhà, Thư giãn tối...',
                              borderRadius: 18,
                              accentColor: selectedColor,
                            ).copyWith(
                              prefixIcon: Icon(Icons.edit_note_rounded, color: selectedColor, size: 22),
                              floatingLabelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: selectedColor,
                              ),
                            ),
                            onChanged: (val) => newSceneName = val,
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
                              ZenGlassPill(
                                blurSigma: 0,
                                color: selectedColor,
                                glowColor: selectedColor,
                                isSelected: true,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                child: Text(
                                  '${_availableIcons.length} Biểu tượng',
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
                            height: 56,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _availableIcons.length,
                              itemBuilder: (ctx, index) {
                                final icon = _availableIcons[index];
                                final bool isSelected = selectedIcon == icon;
                                return ZenLiquidGlass(
                                  blurSigma: 0,
                                  width: 52,
                                  height: 52,
                                  margin: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
                                  borderRadius: 16,
                                  alignment: Alignment.center,
                                  glowColor: isSelected ? selectedColor : null,
                                  rimWidth: isSelected ? 1.45 : 1.05,
                                  surfaceColor: isSelected
                                      ? selectedColor.withOpacity(0.92)
                                      : (isDark
                                          ? Colors.white.withOpacity(0.06)
                                          : Colors.white.withOpacity(0.64)),
                                  customGradient: isSelected
                                      ? LinearGradient(
                                          colors: [
                                            selectedColor,
                                            Color.lerp(selectedColor, Colors.white, 0.20)!,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  customShadows: isSelected
                                      ? [
                                          BoxShadow(
                                            color: selectedColor.withOpacity(isDark ? 0.45 : 0.28),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                      : [],
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setModalState(() => selectedIcon = icon);
                                  },
                                  child: Icon(
                                    icon,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? AppColors.darkText : AppColors.lightTextMuted),
                                    size: 23,
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
                                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: selectedColor.withOpacity(0.65),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: colorOptions.length,
                              itemBuilder: (ctx, index) {
                                final col = colorOptions[index];
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
                                    margin: const EdgeInsets.only(right: 10, top: 2, bottom: 2),
                                    decoration: BoxDecoration(
                                      color: col,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withOpacity(isDark ? 0.22 : 0.55),
                                        width: isSelected ? 2.8 : 1.2,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: col.withOpacity(0.65),
                                                blurRadius: 10,
                                                spreadRadius: 1.5,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.14),
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
                                              size: 21,
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 22),

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
                              ZenGlassPill(
                                blurSigma: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                child: Text(
                                  '${newActions.values.where((v) => v != null).length}/${dynamicDeviceTopicsList.length} thiết bị',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: subTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Danh sách thiết bị dạng Translucent Glass Card (blurSigma: 0)
                          ...dynamicDeviceTopicsList.map((topic) {
                            final name = getDeviceNameHelper(context, topic, activeConfig);
                            final devId = topic.split('/').last;
                            String roomName = '';
                            IconData devIcon = Icons.devices_other_rounded;
                            try {
                              final dev = activeConfig.devices.firstWhere((d) => d.id == devId);
                              roomName = dev.room;
                              switch (dev.icon) {
                                case 'light':
                                case 'lightbulb':
                                  devIcon = Icons.lightbulb_rounded;
                                  break;
                                case 'fan':
                                  devIcon = Icons.mode_fan_off;
                                  break;
                                case 'ac':
                                  devIcon = Icons.air_rounded;
                                  break;
                                case 'socket':
                                  devIcon = Icons.power_rounded;
                                  break;
                                case 'tv':
                                  devIcon = Icons.tv_rounded;
                                  break;
                                case 'pump':
                                case 'water':
                                  devIcon = Icons.water_drop_rounded;
                                  break;
                                default:
                                  devIcon = Icons.bolt_rounded;
                                  break;
                              }
                            } catch (_) {}

                            final currentAction = newActions[topic];
                            final Color? actionGlow = currentAction == '1'
                                ? AppColors.emeraldGlow
                                : (currentAction == '0' ? AppColors.roseGlow : null);

                            return ZenLiquidGlass(
                              blurSigma: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              borderRadius: 20,
                              glowColor: actionGlow,
                              rimWidth: currentAction != null ? 1.35 : 1.05,
                              surfaceColor: isDark
                                  ? Colors.white.withOpacity(currentAction != null ? 0.08 : 0.05)
                                  : Colors.white.withOpacity(currentAction != null ? 0.76 : 0.62),
                              customShadows: [
                                if (actionGlow != null)
                                  BoxShadow(
                                    color: actionGlow.withOpacity(isDark ? 0.18 : 0.10),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Thông tin thiết bị
                                  Row(
                                    children: [
                                      ZenLiquidGlass(
                                        blurSigma: 0,
                                        borderRadius: 12,
                                        padding: const EdgeInsets.all(8),
                                        glowColor: actionGlow,
                                        surfaceColor: actionGlow != null
                                            ? actionGlow.withOpacity(isDark ? 0.20 : 0.14)
                                            : (isDark
                                                ? Colors.white.withOpacity(0.07)
                                                : Colors.white.withOpacity(0.72)),
                                        customShadows: const [],
                                        child: Icon(
                                          devIcon,
                                          size: 18,
                                          color: actionGlow ?? subTextColor,
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

                                  // Bộ điều khiển 3 trạng thái Glass Capsule (Bỏ qua / Bật / Tắt)
                                  Container(
                                    padding: const EdgeInsets.all(3.5),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.28)
                                          : const Color(0xFFE2E8F0).withOpacity(0.68),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.07)
                                            : Colors.white.withOpacity(0.8),
                                      ),
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
                                                    ? (isDark
                                                        ? Colors.white.withOpacity(0.14)
                                                        : Colors.white.withOpacity(0.92))
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(11),
                                                border: currentAction == null
                                                    ? Border.all(
                                                        color: Colors.white.withOpacity(isDark ? 0.18 : 0.9),
                                                        width: 1,
                                                      )
                                                    : null,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  context.tr('action_ignore'),
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: currentAction == null ? FontWeight.w800 : FontWeight.w600,
                                                    color: currentAction == null ? textColor : subTextColor,
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
                                                        colors: [AppColors.emeraldGlow, AppColors.emeraldDeep],
                                                      )
                                                    : null,
                                                borderRadius: BorderRadius.circular(11),
                                                border: currentAction == '1'
                                                    ? Border.all(
                                                        color: Colors.white.withOpacity(0.35),
                                                        width: 1,
                                                      )
                                                    : null,
                                                boxShadow: currentAction == '1'
                                                    ? [
                                                        BoxShadow(
                                                          color: AppColors.emeraldGlow.withOpacity(0.38),
                                                          blurRadius: 8,
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
                                                            : (isDark ? const Color(0xFF34D399) : AppColors.emeraldDeep),
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
                                                        colors: [AppColors.roseGlow, Color(0xFFE11D48)],
                                                      )
                                                    : null,
                                                borderRadius: BorderRadius.circular(11),
                                                border: currentAction == '0'
                                                    ? Border.all(
                                                        color: Colors.white.withOpacity(0.35),
                                                        width: 1,
                                                      )
                                                    : null,
                                                boxShadow: currentAction == '0'
                                                    ? [
                                                        BoxShadow(
                                                          color: AppColors.roseGlow.withOpacity(0.38),
                                                          blurRadius: 8,
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

                          // 5. Thẻ Chia Sẻ Gia Đình (Translucent Glass Family Sharing Card)
                          ZenLiquidGlass(
                            blurSigma: 0,
                            padding: const EdgeInsets.all(14),
                            borderRadius: 20,
                            glowColor: _shareWithAll ? selectedColor : null,
                            surfaceColor: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.64),
                            customShadows: const [],
                            child: Row(
                              children: [
                                ZenLiquidGlass(
                                  blurSigma: 0,
                                  borderRadius: 12,
                                  padding: const EdgeInsets.all(9),
                                  glowColor: selectedColor,
                                  surfaceColor: selectedColor.withOpacity(isDark ? 0.18 : 0.12),
                                  customShadows: const [],
                                  child: Icon(
                                    Icons.group_work_rounded,
                                    color: selectedColor,
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Thanh nút bấm Luminous Glass Action bên dưới
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: ZenGlassButton(
                            label: context.tr('btn_close'),
                            isPrimary: false,
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ZenGlassButton(
                            label: context.tr('btn_save'),
                            icon: Icons.check_circle_rounded,
                            isPrimary: true,
                            accentColor: selectedColor,
                            onPressed: () {
                              if (newSceneName.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr('err_empty_name')),
                                    backgroundColor: AppColors.roseGlow,
                                  ),
                                );
                                return;
                              }

                              Map<String, String> finalActions = {};
                              newActions.forEach((key, value) {
                                if (value != null) finalActions[key] = value;
                              });

                              if (finalActions.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(context.tr('err_no_action')),
                                    backgroundColor: AppColors.roseGlow,
                                  ),
                                );
                                return;
                              }

                              HapticFeedback.heavyImpact();
                              String newId = isEdit ? editScene['id'] : DateTime.now().millisecondsSinceEpoch.toString();
                              final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                              final currentName = FirebaseAuth.instance.currentUser?.displayName ??
                                  FirebaseAuth.instance.currentUser?.email ??
                                  'Thành viên';
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
                                  String name = FirebaseAuth.instance.currentUser!.displayName ??
                                      FirebaseAuth.instance.currentUser!.email ??
                                      context.tr('a_member') ??
                                      'Một thành viên';
                                  FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
                                    'type': 'automation_edit',
                                    'author': name,
                                    'actionName': isEdit
                                        ? (context.tr('act_edit_scene') ?? 'vừa sửa một ngữ cảnh')
                                        : (context.tr('act_add_scene') ?? 'vừa thêm một ngữ cảnh mới'),
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });
                                }
                              } else if (targetId.isNotEmpty && targetId != 'guest') {
                                FirebaseFirestore.instance.collection('users').doc(targetId).collection('scenes').doc(newId).delete();
                              }
                              _saveScenesToDisk();

                              Navigator.pop(ctx);
                              if (mounted) {
                                showAlertDialogHelper(context, context.tr('msg_saved_title'), context.tr('msg_saved_desc'));
                              }
                            },
                          ),
                        ),
                      ],
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

  Widget _buildSceneOptionTile({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    String? subtitle,
    required Color accentColor,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final effectiveColor = isDanger ? AppColors.roseGlow : accentColor;

    return ZenLiquidGlass(
      blurSigma: 0,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: 18,
      glowColor: isDanger ? AppColors.roseGlow : null,
      surfaceColor: isDanger
          ? AppColors.roseGlow.withOpacity(isDark ? 0.14 : 0.08)
          : (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.white.withOpacity(0.68)),
      customShadows: const [],
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          ZenLiquidGlass(
            blurSigma: 0,
            width: 38,
            height: 38,
            borderRadius: 12,
            alignment: Alignment.center,
            glowColor: effectiveColor,
            surfaceColor: effectiveColor.withOpacity(isDark ? 0.20 : 0.12),
            customShadows: const [],
            child: Icon(icon, color: effectiveColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDanger
                        ? AppColors.roseGlow
                        : (isDark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: isDanger
                ? AppColors.roseGlow.withOpacity(0.75)
                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
        ],
      ),
    );
  }

  void _showSceneOptionsSheet(Map<String, dynamic> scene, int index) {
    final Color sceneColor = scene['color'] as Color;
    final int actionCount = (scene['actions'] as Map?)?.length ?? 0;
    final zen = context.zenColors;

    showZenGlassBottomSheet(
      context: context,
      accentColor: sceneColor,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final isEn = Localizations.localeOf(context).languageCode == 'en';

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row (showZenGlassBottomSheet already renders drag handle)
                Row(
                  children: [
                    ZenLiquidGlass(
                      blurSigma: 0,
                      width: 46,
                      height: 46,
                      borderRadius: 15,
                      alignment: Alignment.center,
                      glowColor: sceneColor,
                      surfaceColor: sceneColor.withOpacity(isDark ? 0.22 : 0.14),
                      customShadows: [
                        BoxShadow(
                          color: sceneColor.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      child: Icon(scene['icon'], color: sceneColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getSceneName(scene),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$actionCount ${context.tr('action')} • ${scene['isShared'] == true ? context.tr('shared') : context.tr('private')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
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
                const SizedBox(height: 18),

                // Option 1: Run Scene Immediately
                _buildSceneOptionTile(
                  ctx: ctx,
                  icon: Icons.play_arrow_rounded,
                  label: isEn ? 'Run Scene Now' : 'Kích hoạt ngữ cảnh ngay',
                  subtitle: isEn
                      ? 'Execute $actionCount configured device actions'
                      : 'Thực thi đồng bộ $actionCount thiết bị ngay lập tức',
                  accentColor: sceneColor,
                  onTap: () {
                    Navigator.pop(ctx);
                    _executeCustomScene(scene);
                  },
                ),

                if (_canManageScene(scene)) ...[
                  // Option 2: Edit Scene
                  _buildSceneOptionTile(
                    ctx: ctx,
                    icon: Icons.edit_rounded,
                    label: context.tr('scene_edit'),
                    subtitle: isEn
                        ? 'Customize icon, color & device actions'
                        : 'Tùy chỉnh biểu tượng, màu sắc và thiết bị',
                    accentColor: isDark ? zen.primaryAccent : zen.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddSceneBottomSheet(editScene: scene);
                    },
                  ),

                  // Option 3: Delete Scene (AppColors.roseGlow)
                  _buildSceneOptionTile(
                    ctx: ctx,
                    icon: Icons.delete_outline_rounded,
                    label: context.tr('scene_delete'),
                    subtitle: isEn
                        ? 'Permanently remove this smart scene'
                        : 'Xóa vĩnh viễn ngữ cảnh này khỏi danh sách',
                    accentColor: AppColors.roseGlow,
                    isDanger: true,
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
                              String name = FirebaseAuth.instance.currentUser!.displayName ??
                                  FirebaseAuth.instance.currentUser!.email ??
                                  context.tr('a_member') ??
                                  'Một thành viên';
                              FirebaseFirestore.instance.collection('users').doc(targetId).collection('alerts').add({
                                'type': 'automation_edit',
                                'author': name,
                                'actionName': context.tr('act_delete_scene') ?? 'vừa xóa một ngữ cảnh',
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            }
                          }
                          _saveScenesToDisk();
                          showFloatingToast(
                            context,
                            context.tr('msg_deleted_title'),
                            context.tr('msg_scene_deleted') ?? 'Đã xóa ngữ cảnh thành công!',
                          );
                        },
                      );
                    },
                  ),
                ] else ...[
                  ZenLiquidGlass(
                    blurSigma: 0,
                    padding: const EdgeInsets.all(14),
                    borderRadius: 18,
                    glowColor: zen.primary,
                    surfaceColor: zen.primary.withOpacity(isDark ? 0.14 : 0.08),
                    customShadows: const [],
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ZenLiquidGlass(
                          blurSigma: 0,
                          width: 36,
                          height: 36,
                          borderRadius: 11,
                          alignment: Alignment.center,
                          surfaceColor: zen.primary.withOpacity(isDark ? 0.22 : 0.14),
                          customShadows: const [],
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? zen.primaryAccent : zen.primary,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('perm_view_activate_only'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkText : AppColors.lightText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEn
                                    ? (scene['authorName'] != null && scene['authorName'].toString().isNotEmpty
                                        ? 'Created by ${scene['authorName']}. You can activate it but cannot edit or delete.'
                                        : 'You can activate this shared scene but cannot edit or delete it.')
                                    : (scene['authorName'] != null && scene['authorName'].toString().isNotEmpty
                                        ? 'Ngữ cảnh này do ${scene['authorName']} tạo. Bạn có thể bấm để kích hoạt nhưng không có quyền sửa hoặc xóa.'
                                        : 'Bạn có thể bấm để kích hoạt nhưng không có quyền sửa hoặc xóa ngữ cảnh chung này.'),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
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

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

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
                    blurSigma: 8,
                    borderRadius: 11,
                    padding: const EdgeInsets.all(7),
                    glowColor: zen.primary,
                    surfaceColor: zen.primary.withOpacity(isDark ? 0.20 : 0.12),
                    customGradient: LinearGradient(
                      colors: [
                        zen.primary.withOpacity(isDark ? 0.28 : 0.18),
                        zen.primaryAccent.withOpacity(isDark ? 0.12 : 0.06),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: isDark ? zen.primaryAccent : zen.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      context.tr('scene_title'),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_customScenes.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ZenGlassPill(
                      blurSigma: 8,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
            ),
            const SizedBox(width: 8),
            BouncingButton(
              onTap: () => _showAddSceneBottomSheet(),
              child: ZenLiquidGlass(
                blurSigma: 10,
                borderRadius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                glowColor: zen.primary,
                surfaceColor: zen.primary,
                customGradient: zen.navPillGradient,
                customShadows: [
                  BoxShadow(
                    color: zen.primary.withOpacity(isDark ? 0.38 : 0.24),
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
          ZenGlassCard(
            borderRadius: 22,
            padding: const EdgeInsets.all(24),
            blurSigma: 12,
            glowColor: zen.primary,
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 36,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('scene_empty'),
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
                  child: ZenGlassCard(
                    width: 136,
                    margin: const EdgeInsets.only(right: 14, bottom: 4),
                    padding: const EdgeInsets.all(14),
                    borderRadius: 22,
                    glowColor: sceneColor,
                    isActive: true,
                    blurSigma: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: Icon & Status / Menu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ZenLiquidGlass(
                              blurSigma: 0,
                              padding: const EdgeInsets.all(9),
                              borderRadius: 14,
                              glowColor: sceneColor,
                              surfaceColor: sceneColor.withOpacity(isDark ? 0.24 : 0.15),
                              customShadows: [
                                BoxShadow(
                                  color: sceneColor.withOpacity(0.22),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              child: Icon(scene['icon'], color: sceneColor, size: 22),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  scene['isShared'] == true ? Icons.public : Icons.lock_outline,
                                  size: 13.5,
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.45),
                                ),
                                const SizedBox(width: 2),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    _showSceneOptionsSheet(scene, index);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      Icons.more_vert_rounded,
                                      size: 18,
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.58),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Bottom info: Scene Name and Action Count (FittedBox chống tràn chữ)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _getSceneName(scene),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}
