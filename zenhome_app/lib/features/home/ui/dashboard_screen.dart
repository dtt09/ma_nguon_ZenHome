import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/auth/logic/auth_provider.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/utils/helpers.dart'; 
import 'package:zenhome_app/features/home/ui/device_card.dart';
import 'package:zenhome_app/features/home/ui/weather_card.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/main.dart'; 
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:zenhome_app/features/notifications/ui/notification_history_screen.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';
import 'package:zenhome_app/core/widgets/user_avatar.dart';
import 'package:zenhome_app/features/home/ui/home_switcher_sheet.dart';
import 'package:zenhome_app/features/home/ui/room_tab.dart';
import 'package:zenhome_app/features/notifications/ui/notification_badge.dart';
import 'package:zenhome_app/features/home/ui/scene_section.dart';
import 'package:zenhome_app/core/services/local_network_service.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedRoomCode = '';
  final Map<String, bool> _cooldowns = {};
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    for (var timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    List<String> availableRooms = activeConfig.devices.map((e) => e.room).toSet().toList();
    if (availableRooms.isNotEmpty) {
      _selectedRoomCode = availableRooms.first; 
    }
    // Khởi chạy giám sát mạng cục bộ (Local LAN) và kích hoạt cầu nối đồng bộ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localSyncBridgeProvider);
      ref.read(localNetworkServiceProvider).startMonitoring(targetMac: activeConfig.macAddress);
    });
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    String greeting = '';

    if (hour >= 5 && hour < 12) {
      greeting = context.tr('greeting_morning');
    } else if (hour >= 12 && hour < 18) {
      greeting = context.tr('greeting_afternoon');
    } else {
      greeting = context.tr('greeting_evening');
    }

    final user = FirebaseAuth.instance.currentUser;
    String name = user?.displayName ?? (user?.email?.split('@')[0] ?? 'User');
    
    return '$greeting, $name';
  }

  Future<void> _onRefresh() async {
    // 1. Đồng bộ trực tiếp 100% dữ liệu tài khoản, thiết bị từ Cloud Firestore
    await ref.read(homeConfigProvider).syncFromFirestore();

    // 2. Tái kết nối MQTT với danh sách topic thiết bị mới nhất
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    ref.read(mqttRepositoryProvider).disconnect();
    await Future.delayed(const Duration(milliseconds: 300));
    ref.read(mqttRepositoryProvider).connect(
      userId: activeConfig.userId,
      mqttServer: activeConfig.mqttServer,
      mqttPrefix: activeConfig.mqttPrefix,
      dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
      mqttUser: activeConfig.mqttUser,
      mqttPass: activeConfig.mqttPass,
    );

    // 3. Kiểm tra lại kết nối mạng cục bộ LAN
    ref.read(localNetworkServiceProvider).checkConnectivity();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _toggleDevice(String devId, String roomId, bool currentState) {
    if (_cooldowns[devId] == true) return; 

    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    // Kiểm tra quyền điều khiển thiết bị của thành viên
    if (activeConfig.role == 'member' &&
        activeConfig.allowedDevices != null &&
        !activeConfig.allowedDevices!.contains(devId)) {
      showFloatingToast(
        context,
        context.tr('error'),
        'Bạn không có quyền điều khiển thiết bị này',
        isError: true,
      );
      return;
    }

    final localService = ref.read(localNetworkServiceProvider);
    final bool isLocalAvailable = localService.isLocalAvailable;
    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);

    // Nếu không có mạng LAN VÀ không có kết nối MQTT Cloud
    if (!isLocalAvailable && (mqttState != 2 || !isOnline)) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...',
        isError: true,
      );
      return;
    }

    String cmd = !currentState ? '1' : '0';
    String actionText = !currentState ? context.tr('status_on') : context.tr('status_off');

    // Thêm hiệu ứng rung phản hồi (Haptics)
    if (!currentState) {
      HapticFeedback.heavyImpact(); // Rung mạnh khi BẬT
    } else {
      HapticFeedback.mediumImpact(); // Rung vừa khi TẮT
    }

    // 1. ƯU TIÊN MẠNG CỤC BỘ (LOCAL LAN) NẾU ĐANG CÙNG MẠNG VỚI ESP32
    if (isLocalAvailable) {
      setState(() => _cooldowns[devId] = true);
      // Tối ưu hóa UI lạc quan (Optimistic UI)
      final currentStates = Map<String, bool>.from(ref.read(globalDeviceStatesProvider));
      currentStates[devId] = !currentState;
      ref.read(globalDeviceStatesProvider.notifier).state = currentStates;

      localService.sendLocalControl(devId: devId, cmd: cmd).then((success) {
        if (!mounted) return;
        setState(() => _cooldowns[devId] = false);

        if (success) {
          showFloatingToast(
            context,
            context.tr('toast_success'),
            '${!currentState ? context.tr('toast_turn_on') : context.tr('toast_turn_off')} (Mạng LAN ⚡)',
          );
          _logHistoryToFirebase(devId, actionText);
        } else {
          // Dự phòng tự động: Thử gửi tiếp qua Cloud MQTT nếu Local HTTP trục trặc
          _sendViaMqtt(devId, roomId, currentState, cmd, actionText, activeConfig);
        }
      });
      return;
    }

    // 2. GỬI QUA CLOUD MQTT NẾU KHÔNG Ở MẠNG LAN
    _sendViaMqtt(devId, roomId, currentState, cmd, actionText, activeConfig);
  }

  void _sendViaMqtt(
    String devId,
    String roomId,
    bool currentState,
    String cmd,
    String actionText,
    SmartConfig activeConfig,
  ) {
    String topicCmd = '${activeConfig.mqttPrefix}/$roomId/$devId/cmd';
    try {
      final currentStates = Map<String, bool>.from(ref.read(globalDeviceStatesProvider));
      currentStates[devId] = !currentState;
      ref.read(globalDeviceStatesProvider.notifier).state = currentStates;

      bool confirmed = false;
      final sub = ref.read(mqttRepositoryProvider).deviceStateStream.listen((update) {
         if (update.containsKey(devId) && update[devId] == !currentState) {
            confirmed = true;
         }
      });
      _subscriptions.add(sub);

      ref.read(mqttRepositoryProvider).publishCmd(topicCmd, cmd);
      showFloatingToast(context, context.tr('toast_success'), !currentState ? context.tr('toast_turn_on') : context.tr('toast_turn_off'));
      
      _logHistoryToFirebase(devId, actionText);

      setState(() => _cooldowns[devId] = true);

      late Timer timer;
      timer = Timer(const Duration(seconds: 3), () {
        sub.cancel();
        _subscriptions.remove(sub);
        _timers.remove(timer); // Xóa khỏi danh sách để chống leak RAM

        if (!confirmed) {
           final revertStates = Map<String, bool>.from(ref.read(globalDeviceStatesProvider));
           revertStates[devId] = currentState;
           ref.read(globalDeviceStatesProvider.notifier).state = revertStates;
           if (mounted) {
              showFloatingToast(context, context.tr('toast_error') ?? 'Lỗi', context.tr('toast_mqtt_timeout') ?? 'Thiết bị không phản hồi, đã hoàn tác!', isError: true);
           }
        }
        if (mounted) setState(() => _cooldowns[devId] = false);
      });
      _timers.add(timer);
    } catch (e) {
      showFloatingToast(context, context.tr('toast_error'), context.tr('toast_mqtt_wait'), isError: true);
    }
  }

  void _logHistoryToFirebase(String devId, String actionText) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        String devName = '${context.tr('default_device_name')} $devId';
        final activeConfig = ref.read(homeConfigProvider).activeConfig;
        try {
          devName = activeConfig.devices.firstWhere((d) => d.id == devId).name;
        } catch (e) {
          debugPrint('Error getting Device Name: $e');
        }
        if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
          await ref.read(firestoreRepositoryProvider).logDeviceHistory(activeConfig.userId, devName, actionText);
        }
      }
    } catch (e) {
      print("Lỗi lưu lịch sử: $e");
    }
  }

  IconData _getIconData(String iconStr) {
    switch (iconStr) {
      case 'lightbulb_rounded': return Icons.lightbulb_rounded;
      case 'mode_fan_off': return Icons.mode_fan_off;
      case 'bedtime_rounded': return Icons.bedtime_rounded;
      case 'water_drop': return Icons.water_drop;
      default: return Icons.widgets_rounded; 
    }
  }


  @override
  Widget build(BuildContext context) {
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    List<String> roomTabs = activeConfig.devices.map((e) => e.room).toSet().toList();
    roomTabs.sort((a, b) => context.tr(a).compareTo(context.tr(b)));
    if ((_selectedRoomCode.isEmpty || !roomTabs.contains(_selectedRoomCode)) && roomTabs.isNotEmpty) {
      _selectedRoomCode = roomTabs.first;
    }
    
    final mqttState = ref.watch(mqttConnectionStateProvider);
    final isOnline = ref.watch(espOnlineStateProvider);
    final isConnected = mqttState == 2 && isOnline;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF0F766E),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header cao cấp: Logo + Lời chào + Chọn nhà + Nút thông báo/Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lời chào + Role badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.08)
                                    : const Color(0xFFF1F5F9),
                              ),
                              child: ClipOval(
                                child: Image.asset('public/zenhome_logo_padded.png', width: 22, height: 22, fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _getDynamicGreeting(),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                String roleName = activeConfig.role == 'owner'
                                    ? (context.tr('owner_role') ?? 'Chủ nhà')
                                    : (activeConfig.role == 'co_owner'
                                        ? (context.tr('co_owner') ?? 'Phó chủ nhà')
                                        : (context.tr('member_role') ?? 'Thành viên'));
                                Color roleColor = activeConfig.role == 'owner'
                                    ? const Color(0xFF8B5CF6)
                                    : (activeConfig.role == 'co_owner'
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFF10B981));
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: roleColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: roleColor.withOpacity(0.25), width: 1),
                                  ),
                                  child: Text(
                                    roleName,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Tên Nhà (Home Selector Capsule) + Trạng thái ESP32
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () => showHomeSwitcherBottomSheet(context, ref),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          activeConfig.homeName,
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFFF8FAFC)
                                                : const Color(0xFF0F172A),
                                            letterSpacing: -0.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white70
                                            : Colors.black54,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Builder(
                              builder: (context) {
                                final isLocalAvailable = ref.watch(isLocalNetworkAvailableProvider).value ?? ref.watch(localNetworkServiceProvider).isLocalAvailable;
                                bool isOnline = ref.watch(espOnlineStateProvider);
                                bool isUnlinked = activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty;

                                String statusText;
                                Color statusColor;
                                IconData statusIcon;

                                if (isUnlinked) {
                                  statusText = context.tr('unlinked') ?? 'Chưa l.kết';
                                  statusColor = const Color(0xFFF59E0B);
                                  statusIcon = Icons.link_off_rounded;
                                } else if (isLocalAvailable) {
                                  statusText = 'Mạng LAN ⚡';
                                  statusColor = const Color(0xFF10B981);
                                  statusIcon = Icons.bolt_rounded;
                                } else if (isOnline) {
                                  statusText = 'Cloud MQTT';
                                  statusColor = const Color(0xFF0EA5E9);
                                  statusIcon = Icons.cloud_done_rounded;
                                } else {
                                  statusText = 'Offline';
                                  statusColor = const Color(0xFFEF4444);
                                  statusIcon = Icons.cloud_off_rounded;
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(statusIcon, size: 12, color: statusColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Nút Thông báo & Avatar góc phải
                  Row(
                    children: [
                      NotificationBadge(
                        unreadCount: ref.watch(notificationProvider).where((n) => n['isRead'] == false).length,
                        onPressed: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationHistoryScreen()));
                        },
                      ),
                      const SizedBox(width: 10),
                      UserAvatar(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                        },
                      ),
                    ],
                  ),
                ],
              ).animate().slideY(begin: -0.15, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 18),
              
              AnimatedOpacity(
                opacity: isConnected ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 300),
                child: const WeatherCard().animate().scale(begin: const Offset(0.95, 0.95)),
              ),
              
              const SizedBox(height: 22),

              // 1-touch Quick Scene section
              AbsorbPointer(
                absorbing: !isConnected,
                child: const SceneSection(),
              ).animate(delay: 50.ms).fade(duration: 400.ms).slideY(begin: 0.08, duration: 400.ms, curve: Curves.easeOutQuart),
              
              const SizedBox(height: 25),
              
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: roomTabs.asMap().entries.map((entry) {
                    return RoomTabWidget(
                      roomCode: entry.value,
                      isSelected: _selectedRoomCode == entry.value,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedRoomCode = entry.value);
                      },
                    ).animate(delay: (entry.key * 50).ms)
                        .fade(duration: 300.ms)
                        .slideX(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutQuart);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              
              Builder(
                
                builder: (context) { Map<String, bool> states = ref.watch(globalDeviceStatesProvider);
                  List<DeviceConfig> sortedDevices = activeConfig.devices
                      .where((dev) => dev.room == _selectedRoomCode)
                      .toList();
                  sortedDevices.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  List<Widget> activeDevices = sortedDevices.map((dev) {
                        bool isOn = states[dev.id] ?? false;
                        bool isCooldown = _cooldowns[dev.id] ?? false; 
                        bool isRestricted = activeConfig.role == 'member' &&
                            activeConfig.allowedDevices != null &&
                            !activeConfig.allowedDevices!.contains(dev.id);

                        return DeviceCard(
                          deviceName: dev.name, 
                          roomName: context.tr(dev.room), 
                          icon: _getIconData(dev.icon),
                          isOn: isOn,
                          isCooldown: isCooldown, 
                          isRestricted: isRestricted,
                          onTap: () => _toggleDevice(dev.id, dev.room, isOn),
                        );
                      }).toList();

                  if (activeDevices.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Column(
                          children: [
                            Icon(Icons.widgets_outlined, size: 50, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text(context.tr('no_device'), style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    );
                  }

                  return AnimatedOpacity(
                    opacity: isConnected ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.82,
                      children: activeDevices.asMap().entries.map((entry) {
                        return entry.value.animate(delay: (100 + entry.key * 75).ms)
                            .fade(duration: 400.ms)
                            .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuart)
                            .scale(begin: const Offset(0.9, 0.9), duration: 400.ms, curve: Curves.easeOutQuart);
                      }).toList(),
                    ),
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

}
