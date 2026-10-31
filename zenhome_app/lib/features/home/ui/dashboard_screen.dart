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
import 'package:zenhome_app/features/home/ui/scenes_screen.dart';
import 'package:zenhome_app/core/services/local_network_service.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';
import 'package:zenhome_app/core/services/ble_local_service.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedRoomCode = '';
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
    // Khởi chạy giám sát mạng cục bộ (Local LAN) và kích hoạt cầu nối đồng bộ kèm phân quyền
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localSyncBridgeProvider);
      ref.read(localNetworkServiceProvider).startMonitoring(
        targetMac: activeConfig.macAddress,
        adminPass: activeConfig.adminPass,
        userId: activeConfig.userId,
        role: activeConfig.role,
        allowedDevices: activeConfig.allowedDevices,
      );
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
    if (ref.read(pendingDeviceOperationsProvider).contains(devId)) return; 

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

    // Phản hồi xúc giác chạm nhẹ
    HapticFeedback.selectionClick();

    // 1. Quản lý trạng thái chờ phản hồi qua Global Pending Provider (Bất tử qua mọi lần chuyển Tab)
    ref.read(pendingDeviceOperationsProvider.notifier).setPending(
      devId,
      true,
      onTimeout: () {
        ref.read(mqttRepositoryProvider).markEspOffline();
        HapticFeedback.vibrate();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_error') ?? 'Lỗi',
            context.tr('toast_mqtt_timeout') ?? 'Thiết bị không phản hồi, vui lòng kiểm tra nguồn điện!',
            isError: true,
          );
        }
      },
    );

    // 2. KÍCH HOẠT LỆNH ĐIỀU KHIỂN (ƯU TIÊN LOCAL LAN TỨC THÌ + DỰ PHÒNG CLOUD MQTT SONG SONG)
    bool confirmed = false;

    void onHardwareConfirmed(bool newState) {
      if (confirmed) return;
      confirmed = true;

      // Xóa cờ pending trên toàn cục
      ref.read(pendingDeviceOperationsProvider.notifier).setPending(devId, false);

      // Cập nhật công tắc trên app CHỈ KHI nhận được phản hồi thực tế từ ESP32
      ref.read(globalDeviceStatesProvider.notifier).updateState(devId, newState);

      // Rung phản hồi thành công khi rơ-le thực tế đã đóng/ngắt
      if (newState) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.mediumImpact();
      }

      _logHistoryToFirebase(devId, actionText);
    }

    // Kênh 1: Gửi qua mạng nội bộ LAN HTTP (Tốc độ < 15ms) hoặc BLE
    if (isLocalAvailable) {
      localService.sendLocalControl(devId: devId, cmd: cmd).then((success) {
        if (success) {
          onHardwareConfirmed(!currentState);
        }
      });
    }

    // Kênh 2: Phát qua MQTT Cloud (Đa topic đảm bảo cả có dấu hai chấm và không dấu)
    try {
      final mqttPrefix = activeConfig.mqttPrefix;
      final topicCmd1 = '$mqttPrefix/$roomId/$devId/cmd';
      ref.read(mqttRepositoryProvider).publishCmd(topicCmd1, cmd);

      final cleanPrefix = mqttPrefix.replaceAll(':', '');
      if (cleanPrefix != mqttPrefix) {
        final topicCmd2 = '$cleanPrefix/$roomId/$devId/cmd';
        ref.read(mqttRepositoryProvider).publishCmd(topicCmd2, cmd);
      }
    } catch (e) {
      debugPrint('[MQTT] Lỗi publish lệnh relay: $e');
    }
  }

  void _sendViaMqtt(
    String devId,
    String roomId,
    bool currentState,
    String cmd,
    String actionText,
    SmartConfig activeConfig,
  ) {
    // Được gộp vào quy trình song song tối ưu của _toggleDevice
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


  void _showConnectionDetailSheet(BuildContext context, SmartConfig activeConfig) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final localService = ref.read(localNetworkServiceProvider);
        final isLocalAvailable = ref.watch(isLocalNetworkAvailableProvider).value ?? localService.isLocalAvailable;
        final localIp = ref.watch(localHubIpProvider).value ?? localService.cachedHubIp;
        final isEspOnline = ref.watch(espOnlineStateProvider);
        final isBleConnected = BleLocalService().isConnected;
        final isBleNearby = BleLocalService().isHubNearby;
        final isLanConnected = isLocalAvailable && localIp != null && localIp.isNotEmpty;
        final isUnlinked = activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty;

        // Xác định Kênh kết nối ưu tiên đang hoạt động
        String activeTitle = context.tr('hub_mode_offline');
        String activeDesc = context.tr('hub_desc_offline');
        String activeLatency = 'N/A';
        List<Color> gradientColors = [const Color(0xFF7F1D1D), const Color(0xFF991B1B)];
        IconData activeIcon = Icons.cloud_off_rounded;

        if (isUnlinked) {
          activeTitle = context.tr('hub_status_unlinked');
          activeDesc = context.tr('hub_status_unlinked_desc');
          gradientColors = [const Color(0xFF475569), const Color(0xFF334155)];
          activeIcon = Icons.link_off_rounded;
        } else if (isLanConnected) {
          activeTitle = context.tr('hub_mode_lan');
          activeDesc = context.tr('hub_desc_lan');
          activeLatency = '~5ms';
          gradientColors = [const Color(0xFF065F46), const Color(0xFF047857)];
          activeIcon = Icons.bolt_rounded;
        } else if (isBleConnected || isBleNearby) {
          final isBleAuth = BleLocalService().isAuthenticated;
          activeTitle = isBleConnected
              ? (isBleAuth ? '${context.tr('hub_mode_ble')} 🔐' : context.tr('hub_mode_ble'))
              : '${context.tr('hub_mode_ble')} ⚡';
          activeDesc = isBleConnected
              ? (isBleAuth ? '${context.tr('hub_desc_ble')} (Đã xác thực Key an toàn)' : context.tr('hub_desc_ble'))
              : 'Sẵn sàng nhận lệnh (Hàng đợi Connect-on-Demand & Tự ngắt nhường sóng)';
          activeLatency = '~20ms';
          gradientColors = [const Color(0xFF4338CA), const Color(0xFF6366F1)];
          activeIcon = isBleConnected
              ? (isBleAuth ? Icons.lock_open_rounded : Icons.bluetooth_connected_rounded)
              : Icons.bluetooth_searching_rounded;
        } else if (isEspOnline) {
          activeTitle = context.tr('hub_mode_cloud');
          activeDesc = context.tr('hub_desc_cloud');
          activeLatency = '~200ms';
          gradientColors = [const Color(0xFF075985), const Color(0xFF0284C7)];
          activeIcon = Icons.cloud_rounded;
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLanConnected
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : isBleConnected
                              ? const Color(0xFF6366F1).withOpacity(0.15)
                              : isEspOnline
                                  ? const Color(0xFF0EA5E9).withOpacity(0.15)
                                  : Colors.red.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activeIcon,
                      color: isLanConnected
                          ? const Color(0xFF10B981)
                          : isBleConnected
                              ? const Color(0xFF6366F1)
                              : isEspOnline
                                  ? const Color(0xFF0EA5E9)
                                  : Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('hub_status_title'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('hub_status_subtitle'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Thẻ kênh ưu tiên hiện tại
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activeTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Độ trễ: $activeLatency',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      activeDesc,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Bảng thông số 3 tầng kết nối: Local LAN, Bluetooth LE ngầm, Cloud MQTT
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: [
                    // Kênh 1: Local LAN Wi-Fi
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.wifi_rounded,
                            size: 20,
                            color: isLanConnected ? const Color(0xFF10B981) : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('hub_channel_lan_title'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  localIp != null ? 'IP Hub: $localIp (Port 80)' : 'Chưa phát hiện IP Hub',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isLanConnected
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isLanConnected ? context.tr('hub_ready_lan') : context.tr('hub_channel_unavailable'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isLanConnected ? const Color(0xFF10B981) : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),

                    // Kênh 2: Bluetooth LE ngầm Zero-Touch
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bluetooth_rounded,
                            size: 20,
                            color: isBleConnected ? const Color(0xFF6366F1) : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('hub_channel_ble_title'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isBleConnected
                                      ? (BleLocalService().isAuthenticated
                                          ? context.tr('hub_ble_gatt_secured')
                                          : context.tr('hub_ble_gatt_verifying'))
                                      : (isBleNearby
                                          ? 'Sẵn sàng nhận lệnh (Hàng đợi Connect-on-Demand)'
                                          : 'Dự phòng ngầm khi router Wi-Fi mất nguồn'),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isBleConnected || isBleNearby)
                                  ? const Color(0xFF6366F1).withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isBleConnected
                                  ? (BleLocalService().isAuthenticated ? context.tr('hub_ble_key_ready') : context.tr('hub_ble_key_waiting'))
                                  : (isBleNearby ? 'Sẵn sàng ⚡' : context.tr('hub_channel_unavailable')),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: (isBleConnected || isBleNearby) ? const Color(0xFF6366F1) : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06)),

                    // Kênh 3: Đám mây Cloud MQTT TLS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_outlined,
                            size: 20,
                            color: isEspOnline ? const Color(0xFF0EA5E9) : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('hub_channel_cloud_title'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeConfig.mqttServer.isNotEmpty
                                      ? activeConfig.mqttServer
                                      : 'Chưa cấu hình broker',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isEspOnline
                                  ? const Color(0xFF0EA5E9).withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isEspOnline ? context.tr('hub_ready_cloud') : context.tr('hub_channel_unavailable'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isEspOnline ? const Color(0xFF0EA5E9) : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Nút Chẩn đoán & Quét lại kết nối
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    showFloatingToast(context, context.tr('hub_status_title'), context.tr('hub_diagnosing'));
                    // Quét đồng thời cả mạng LAN Wi-Fi và BLE ngầm
                    await localService.discoverHub(force: true);
                    BleLocalService().start(
                      targetMac: activeConfig.macAddress,
                      adminPass: activeConfig.adminPass,
                      userId: activeConfig.userId,
                      role: activeConfig.role,
                      allowedDevices: activeConfig.allowedDevices,
                    );

                    if (context.mounted) {
                      if (localService.isLocalAvailable) {
                        showFloatingToast(context, context.tr('toast_success'), context.tr('hub_toast_lan_found').replaceAll('{ip}', localService.cachedHubIp ?? ''));
                      } else if (BleLocalService().isAuthenticated) {
                        showFloatingToast(context, context.tr('toast_success'), context.tr('hub_toast_ble_connected'));
                      } else {
                        showFloatingToast(context, context.tr('hub_status_title'), context.tr('hub_toast_cloud_fallback'), isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.radar_rounded, size: 18),
                  label: Text(
                    context.tr('hub_btn_diagnose'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    List<String> roomTabs = activeConfig.devices.map((e) => e.room).toSet().toList();
    roomTabs.sort((a, b) => context.tr(a).compareTo(context.tr(b)));
    if ((_selectedRoomCode.isEmpty || !roomTabs.contains(_selectedRoomCode)) && roomTabs.isNotEmpty) {
      _selectedRoomCode = roomTabs.first;
    }
    
    final localService = ref.watch(localNetworkServiceProvider);
    final isLocalAvailable = ref.watch(isLocalNetworkAvailableProvider).value ?? localService.isLocalAvailable;
    final mqttState = ref.watch(mqttConnectionStateProvider);
    final isOnline = ref.watch(espOnlineStateProvider);
    final isConnected = isLocalAvailable || (mqttState == 2 && isOnline);

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
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: HomeHelper.getThemeColor(activeConfig.homeColor).withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          HomeHelper.getIconData(activeConfig.homeIcon),
                                          color: HomeHelper.getThemeColor(activeConfig.homeColor),
                                          size: 18,
                                        ),
                                      ),
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
                                  statusText = 'Local ⚡';
                                  statusColor = const Color(0xFF10B981);
                                  statusIcon = Icons.bolt_rounded;
                                } else if (isOnline) {
                                  statusText = 'Cloud';
                                  statusColor = const Color(0xFF0EA5E9);
                                  statusIcon = Icons.cloud_done_rounded;
                                } else {
                                  statusText = 'Offline';
                                  statusColor = const Color(0xFFEF4444);
                                  statusIcon = Icons.cloud_off_rounded;
                                }

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showConnectionDetailSheet(context, activeConfig),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
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
                                    ),
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
                child: const WeatherCard()
                    .animate()
                    .fade(duration: 350.ms)
                    .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.0, 1.0), curve: Curves.easeOutBack),
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
                
                builder: (context) {
                  final Map<String, bool> states = ref.watch(globalDeviceStatesProvider);
                  final Set<String> pendingDevices = ref.watch(pendingDeviceOperationsProvider);
                  List<DeviceConfig> sortedDevices = activeConfig.devices
                      .where((dev) => dev.room == _selectedRoomCode)
                      .toList();
                  sortedDevices.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  List<Widget> activeDevices = sortedDevices.map((dev) {
                        bool isOn = states[dev.id] ?? false;
                        bool isCooldown = pendingDevices.contains(dev.id); 
                        bool isRestricted = activeConfig.role == 'member' &&
                            activeConfig.allowedDevices != null &&
                            !activeConfig.allowedDevices!.contains(dev.id);

                        return DeviceCard(
                          key: ValueKey('dev_${dev.id}_$_selectedRoomCode'),
                          deviceName: dev.name, 
                          roomName: context.tr(dev.room), 
                          icon: _getIconData(dev.icon),
                          isOn: isOn,
                          isCooldown: isCooldown, 
                          isRestricted: isRestricted,
                          onTap: () => _toggleDevice(dev.id, dev.room, isOn),
                          onLongPress: isRestricted ? null : () => _showQuickAutomationModal(dev, isOn),
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
                    ).animate().fade(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack);
                  }

                  return AnimatedOpacity(
                    opacity: isConnected ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.82,
                      children: activeDevices.asMap().entries.map((entry) {
                        return entry.value
                            .animate(
                              key: ValueKey('anim_${_selectedRoomCode}_${entry.key}'),
                              delay: (entry.key * 45).ms,
                            )
                            .fade(duration: 320.ms, curve: Curves.easeOutCubic)
                            .slideY(begin: 0.12, end: 0, duration: 320.ms, curve: Curves.easeOutBack)
                            .scale(begin: const Offset(0.92, 0.92), end: const Offset(1.0, 1.0), duration: 320.ms, curve: Curves.easeOutBack);
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


  // ==========================================
  // TIỆN ÍCH NHANH: TỰ ĐỘNG HÓA KHI NHẤN GIỮ Ô CÔNG TẮC
  // ==========================================
  void _showQuickAutomationModal(DeviceConfig dev, bool currentIsOn) {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final deviceTopic = '${activeConfig.mqttPrefix}/${dev.room}/${dev.id}';
    final targetAction = currentIsOn ? 'delay_off' : 'delay_on';
    final targetActionText = currentIsOn ? 'Tắt' : 'Bật';
    final targetColor = currentIsOn ? const Color(0xFFEF4444) : const Color(0xFF0F766E);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header: Device Info & Status
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (currentIsOn ? Colors.amber : Colors.blueGrey).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconData(dev.icon),
                        color: currentIsOn ? Colors.amber : (isDark ? Colors.white70 : Colors.black87),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dev.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${context.tr(dev.room)} • ${currentIsOn ? context.tr('status_on') : context.tr('status_off')}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: targetColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: targetColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, size: 14, color: targetColor),
                          const SizedBox(width: 4),
                          Text(
                            'Tự động hóa',
                            style: TextStyle(
                              color: targetColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                const SizedBox(height: 18),

                // Section 1: Hẹn giờ nhanh
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      'Hẹn giờ $targetActionText nhanh sau:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Preset buttons
                Row(
                  children: [
                    _buildQuickTimerPresetBtn(ctx, dev, deviceTopic, targetAction, targetActionText, 15, '15p', isDark),
                    const SizedBox(width: 8),
                    _buildQuickTimerPresetBtn(ctx, dev, deviceTopic, targetAction, targetActionText, 30, '30p', isDark),
                    const SizedBox(width: 8),
                    _buildQuickTimerPresetBtn(ctx, dev, deviceTopic, targetAction, targetActionText, 60, '1 giờ', isDark),
                    const SizedBox(width: 8),
                    _buildQuickTimerPresetBtn(ctx, dev, deviceTopic, targetAction, targetActionText, 120, '2 giờ', isDark),
                  ],
                ),

                const SizedBox(height: 12),

                // Custom time button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    ),
                    icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                    label: const Text('Tùy chỉnh thời gian hẹn giờ...'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCustomQuickTimerDialog(dev, deviceTopic, targetAction, targetActionText);
                    },
                  ),
                ),

                const SizedBox(height: 18),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                const SizedBox(height: 14),

                // Section 2: Tạo lịch trình định kỳ
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Colors.purple, size: 22),
                  ),
                  title: Text(
                    'Lịch trình định kỳ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Cài đặt tự động bật/tắt lặp lại các ngày trong tuần',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ScenesScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickTimerPresetBtn(
    BuildContext ctx,
    DeviceConfig dev,
    String deviceTopic,
    String targetAction,
    String targetActionText,
    int minutes,
    String label,
    bool isDark,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _applyQuickTimer(dev, deviceTopic, targetAction, targetActionText, minutes);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0x28FFFFFF) : const Color(0x18000000),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                minutes < 60 ? '$minutes' : '${minutes ~/ 60}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                minutes < 60 ? 'phút' : 'giờ',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyQuickTimer(
    DeviceConfig dev,
    String deviceTopic,
    String targetAction,
    String targetActionText,
    int mins,
  ) async {
    final mqttState = ref.read(mqttConnectionStateProvider);
    final isOnline = ref.read(espOnlineStateProvider);
    if (mqttState != 2 || !isOnline) {
      showFloatingToast(context, context.tr('error'), context.tr('toast_mqtt_wait') ?? 'Đang kết nối máy chủ...', isError: true);
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    String targetId = activeConfig.userId;
    String cmdTopic = targetAction == 'delay_off' ? '$deviceTopic/timer_off' : '$deviceTopic/timer_on';

    ref.read(mqttRepositoryProvider).publishCmd(cmdTopic, mins.toString());

    int targetTime = DateTime.now().millisecondsSinceEpoch + (mins * 60000);
    String timerId = DateTime.now().millisecondsSinceEpoch.toString();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentName = FirebaseAuth.instance.currentUser?.displayName ?? 
                        FirebaseAuth.instance.currentUser?.email ?? 'Thành viên';

    Map<String, dynamic> newTimer = {
      'id': timerId,
      'topic': deviceTopic,
      'action': targetAction == 'delay_off' ? (context.tr('timer_action_off') ?? 'Tắt sau') : (context.tr('timer_action_on') ?? 'Bật sau'),
      'minutes': mins,
      'timeStr': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      'status': 'active', 
      'targetTime': targetTime,
      'isShared': true,
      'authorUid': currentUid,
      'authorName': currentName,
    };

    if (targetId.isNotEmpty && targetId != 'guest') {
      try {
        FirebaseFirestore.instance.collection('users').doc(targetId).collection('timers').doc(timerId).set(newTimer);
      } catch (_) {}
    }

    showFloatingToast(
      context,
      context.tr('toast_success'),
      'Đã hẹn giờ $targetActionText ${dev.name} sau $mins phút',
    );
  }

  void _showCustomQuickTimerDialog(
    DeviceConfig dev,
    String deviceTopic,
    String targetAction,
    String targetActionText,
  ) {
    final TextEditingController minutesCtrl = TextEditingController(text: '45');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFF0F766E)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hẹn giờ $targetActionText ${dev.name}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập số phút muốn hẹn giờ:', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 12),
            TextField(
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                suffixText: 'phút',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('btn_cancel') ?? 'Hủy', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              int? mins = int.tryParse(minutesCtrl.text.trim());
              if (mins != null && mins > 0 && mins <= 1440) {
                Navigator.pop(ctx);
                _applyQuickTimer(dev, deviceTopic, targetAction, targetActionText, mins);
              } else {
                showFloatingToast(context, 'Lỗi', 'Vui lòng nhập số phút hợp lệ (1 - 1440)', isError: true);
              }
            },
            child: Text(context.tr('btn_confirm') ?? 'Xác nhận'),
          ),
        ],
      ),
    );
  }

}
