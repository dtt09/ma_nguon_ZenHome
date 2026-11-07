import 'package:zenhome_app/features/notifications/logic/notification_provider.dart';
import 'dart:async';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/auth/logic/auth_provider.dart';
import 'package:zenhome_app/core/utils/helpers.dart'; 
import 'package:zenhome_app/features/home/ui/device_card.dart';
import 'package:zenhome_app/features/home/ui/weather_card.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/features/notifications/ui/notification_history_screen.dart';
import 'package:zenhome_app/features/auth/ui/profile_screen.dart';
import 'package:zenhome_app/core/widgets/user_avatar.dart';
import 'package:zenhome_app/features/home/ui/home_switcher_sheet.dart';
import 'package:zenhome_app/features/home/ui/room_tab.dart';
import 'package:zenhome_app/features/notifications/ui/notification_badge.dart';
import 'package:zenhome_app/features/home/ui/scene_section.dart';
import 'package:zenhome_app/features/home/ui/scenes_screen.dart';
import 'package:zenhome_app/core/utils/home_helper.dart';
import 'package:zenhome_app/core/services/ble_local_service.dart';
import 'package:zenhome_app/core/providers/local_network_provider.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
        isDisabled: activeConfig.isDisabled,
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

    // Kiểm tra quyền điều khiển thiết bị của thành viên
    if (activeConfig.role == 'member' &&
        activeConfig.allowedDevices != null &&
        !activeConfig.allowedDevices!.contains(devId)) {
      showFloatingToast(
        context,
        context.tr('error'),
        context.tr('no_permission_device') ?? 'Bạn không có quyền điều khiển thiết bị này',
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
        HapticFeedback.vibrate();
        if (mounted) {
          showFloatingToast(
            context,
            context.tr('toast_error') ?? 'Lỗi',
            context.tr('toast_mqtt_timeout') ?? 'Thiết bị không phản hồi, vui lòng kiểm tra kết nối!',
            isError: true,
          );
        }
      },
    );

    // 2. KÍCH HOẠT LỆNH ĐIỀU KHIỂN (ƯU TIÊN LOCAL LAN TỨC THÌ, DỰ PHÒNG TUẦN TỰ CLOUD MQTT)
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

    void sendCloudMqtt() {
      try {
        final mqttPrefix = activeConfig.mqttPrefix;
        final topicCmd1 = '$mqttPrefix/$roomId/$devId/cmd';
        final senderUser = FirebaseAuth.instance.currentUser?.email?.split('@')[0] ?? (activeConfig.role == 'owner' ? activeConfig.userId : 'member');
        final payload = jsonEncode({
          'action': cmd,
          'user': senderUser,
        });
        ref.read(mqttRepositoryProvider).publishCmd(topicCmd1, payload);

        final cleanPrefix = mqttPrefix.replaceAll(':', '');
        if (cleanPrefix != mqttPrefix) {
          final topicCmd2 = '$cleanPrefix/$roomId/$devId/cmd';
          ref.read(mqttRepositoryProvider).publishCmd(topicCmd2, payload);
        }
      } catch (e) {
        debugPrint('[MQTT] Lỗi publish lệnh relay: $e');
      }
    }

    // Kênh 1: Ưu tiên gửi qua mạng nội bộ LAN HTTP (Tốc độ < 15ms) hoặc BLE
    if (isLocalAvailable) {
      localService.sendLocalControl(devId: devId, cmd: cmd).then((success) {
        if (success) {
          onHardwareConfirmed(!currentState);
        } else {
          // Dự phòng tuần tự: Nếu LAN không nhận lệnh, chuyển sang Cloud MQTT
          sendCloudMqtt();
        }
      });
    } else {
      // Kênh 2: Phát qua MQTT Cloud khi ở ngoài nhà
      sendCloudMqtt();
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


  void _showConnectionDetailSheet(BuildContext context, SmartConfig activeConfig) {
    showZenGlassBottomSheet(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final localService = ref.read(localNetworkServiceProvider);
        final isLanAvailable = ref.watch(isLanAvailableProvider).value ?? localService.isLanAvailable;
        final localIp = ref.watch(localHubIpProvider).value ?? (isLanAvailable ? localService.cachedHubIp : null);
        final isEspOnline = ref.watch(espOnlineStateProvider);
        final isBleConnected = BleLocalService().isConnected;
        final isBleNearby = BleLocalService().isHubNearby;
        final isLanConnected = isLanAvailable && localIp != null && localIp.isNotEmpty;
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

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
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

              // Thẻ kênh ưu tiên hiện tại dạng Kính Lỏng phát quang
              ZenLiquidGlass(
                borderRadius: 20,
                blurSigma: 0,
                glowColor: gradientColors.last,
                customGradient: LinearGradient(
                  colors: [
                    gradientColors.first.withOpacity(0.88),
                    gradientColors.last.withOpacity(0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                padding: const EdgeInsets.all(16),
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
                        ZenGlassPill(
                          blurSigma: 0,
                          borderRadius: 10,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          isSelected: true,
                          glowColor: Colors.white,
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
              ZenLiquidGlass(
                borderRadius: 20,
                blurSigma: 0,
                surfaceColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.65),
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
                          ZenGlassPill(
                            blurSigma: 0,
                            borderRadius: 9,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            isSelected: isLanConnected,
                            glowColor: const Color(0xFF10B981),
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
                          ZenGlassPill(
                            blurSigma: 0,
                            borderRadius: 9,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            isSelected: isBleConnected || isBleNearby,
                            glowColor: const Color(0xFF6366F1),
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
                          ZenGlassPill(
                            blurSigma: 0,
                            borderRadius: 9,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            isSelected: isEspOnline,
                            glowColor: const Color(0xFF0EA5E9),
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

              // Nút Chẩn đoán & Quét lại kết nối dạng Kính Lỏng
              SizedBox(
                width: double.infinity,
                child: ZenGlassButton(
                  icon: Icons.radar_rounded,
                  label: context.tr('hub_btn_diagnose'),
                  accentColor: const Color(0xFF10B981),
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
    super.build(context);
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
        color: context.zenColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Kiến Trúc Kính Lỏng (Liquid Glass Tiered Architecture)
              // Tầng 1: Lời chào, Logo, Vai trò + Nút Thông báo & Avatar
              // Tầng 2: Thanh Kính Lỏng Tên nhà & Chip trạng thái mạng phát quang
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TẦNG 1: Lời chào, Logo, Vai trò + Nút Thông báo & Avatar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Cụm Lời chào + Vai trò
                      Expanded(
                        child: Row(
                          children: [
                            ZenLiquidGlass(
                              blurSigma: 12,
                              borderRadius: 16,
                              padding: const EdgeInsets.all(2.5),
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
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569),
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
                                return ZenGlassPill(
                                  blurSigma: 10,
                                  borderRadius: 10,
                                  padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                                  isSelected: true,
                                  glowColor: roleColor,
                                  child: Text(
                                    roleName,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: roleColor),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Nút Thông báo & Avatar góc phải
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // TẦNG 2: THANH KÍNH LỎNG QUANG HỌC (ZEN LIQUID GLASS CAPSULE)
                  // Thiết kế độc quyền: Không gian tên nhà rộng mở 100%, chip kết nối phát quang tinh tế, tuyệt đối không bao giờ đè lấn nhau
                  ZenLiquidGlass(
                    borderRadius: 22,
                    blurSigma: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Cột Bên trái: Home Selector (Icon nhà + Tên nhà to rõ + Chevron)
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => showHomeSwitcherBottomSheet(context, ref),
                            child: Row(
                              children: [
                                ZenLiquidGlass(
                                  blurSigma: 0,
                                  borderRadius: 11,
                                  padding: const EdgeInsets.all(6),
                                  margin: const EdgeInsets.only(right: 9),
                                  glowColor: HomeHelper.getThemeColor(activeConfig.homeColor),
                                  surfaceColor: HomeHelper.getThemeColor(activeConfig.homeColor).withOpacity(0.16),
                                  child: Icon(
                                    HomeHelper.getIconData(activeConfig.homeIcon),
                                    color: HomeHelper.getThemeColor(activeConfig.homeColor),
                                    size: 19,
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          activeConfig.homeName,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? const Color(0xFFF8FAFC)
                                                : const Color(0xFF0F172A),
                                            letterSpacing: -0.4,
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
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Cột Bên phải: Connection Capsule với hiệu ứng đèn thở quang học (Pulsing Glow)
                        Builder(
                          builder: (context) {
                            final isLanAvailable = ref.watch(isLanAvailableProvider).value ?? ref.watch(localNetworkServiceProvider).isLanAvailable;
                            final isBleConnected = BleLocalService().isConnected;
                            final isBleNearby = BleLocalService().isHubNearby;
                            bool isOnline = ref.watch(espOnlineStateProvider);
                            bool isUnlinked = activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty;

                            String statusText;
                            Color statusColor;
                            IconData statusIcon;

                            if (isUnlinked) {
                              statusText = context.tr('unlinked') ?? 'Chưa liên kết';
                              statusColor = const Color(0xFFF59E0B);
                              statusIcon = Icons.link_off_rounded;
                            } else if (isLanAvailable) {
                              statusText = 'LAN ⚡';
                              statusColor = const Color(0xFF10B981);
                              statusIcon = Icons.bolt_rounded;
                            } else if (isBleConnected || isBleNearby) {
                              statusText = isBleConnected ? 'BLE 🔐' : 'BLE 📱';
                              statusColor = const Color(0xFF6366F1);
                              statusIcon = isBleConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded;
                            } else if (isOnline) {
                              statusText = 'Cloud';
                              statusColor = const Color(0xFF0EA5E9);
                              statusIcon = Icons.cloud_done_rounded;
                            } else {
                              statusText = 'Offline';
                              statusColor = const Color(0xFFEF4444);
                              statusIcon = Icons.cloud_off_rounded;
                            }

                            return ZenGlassPill(
                              blurSigma: 0,
                              borderRadius: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              isSelected: true,
                              glowColor: statusColor,
                              onTap: () => _showConnectionDetailSheet(context, activeConfig),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: statusColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: statusColor.withOpacity(0.8),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(statusIcon, size: 12.5, color: statusColor),
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
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ZenGlassCard(
                        width: double.infinity,
                        borderRadius: 24,
                        blurSigma: 18,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ZenLiquidGlass(
                              blurSigma: 0,
                              borderRadius: 20,
                              padding: const EdgeInsets.all(14),
                              child: Icon(
                                Icons.widgets_outlined,
                                size: 36,
                                color: context.zenColors.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('no_device'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
                  }

                  return AnimatedOpacity(
                    opacity: isConnected ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.86,
                      children: activeDevices.asMap().entries.map((entry) {
                        final delayMs = (entry.key * 25).clamp(0, 150);
                        return entry.value
                            .animate(
                              key: ValueKey('anim_${_selectedRoomCode}_${entry.key}'),
                              delay: Duration(milliseconds: delayMs),
                            )
                            .fade(duration: 280.ms, curve: Curves.easeOutQuart)
                            .slideY(begin: 0.08, end: 0, duration: 280.ms, curve: Curves.easeOutQuart)
                            .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.0, 1.0), duration: 280.ms, curve: Curves.easeOutQuart);
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
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    final deviceTopic = '${activeConfig.mqttPrefix}/${dev.room}/${dev.id}';
    final targetAction = currentIsOn ? 'delay_off' : 'delay_on';
    final targetActionText = currentIsOn ? context.tr('action_turn_off') : context.tr('action_turn_on');
    final targetColor = currentIsOn ? AppColors.roseGlow : context.zenColors.primary;

    showZenGlassBottomSheet(
      context: context,
      accentColor: targetColor,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Device Info & Status
                Row(
                  children: [
                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 18,
                      padding: const EdgeInsets.all(12),
                      glowColor: currentIsOn ? Colors.amber : null,
                      surfaceColor: (currentIsOn ? Colors.amber : Colors.blueGrey).withOpacity(0.16),
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
                              fontWeight: FontWeight.w800,
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
                    ZenGlassPill(
                      blurSigma: 0,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      isSelected: true,
                      glowColor: targetColor,
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

                const SizedBox(height: 20),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                const SizedBox(height: 18),

                // Section 1: Hẹn giờ nhanh
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: targetColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${context.tr('timer_quick_title') ?? 'Hẹn giờ'} $targetActionText ${context.tr('timer_quick_after') ?? 'nhanh sau:'}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
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
                  child: ZenGlassButton(
                    isPrimary: false,
                    icon: Icons.edit_calendar_rounded,
                    label: context.tr('quick_timer_custom_title'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCustomQuickTimerDialog(dev, deviceTopic, targetAction, targetActionText);
                    },
                  ),
                ),

                const SizedBox(height: 18),
                Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
                const SizedBox(height: 14),

                // Section 2: Tạo lịch trình định kỳ dạng Kính Lỏng
                ZenGlassCard(
                  blurSigma: 0,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ScenesScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 12,
                        padding: const EdgeInsets.all(10),
                        glowColor: AppColors.purpleGlow,
                        surfaceColor: AppColors.purpleGlow.withOpacity(0.14),
                        child: const Icon(Icons.calendar_month_rounded, color: AppColors.purpleGlow, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('periodic_schedule'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('periodic_schedule_desc'),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ],
                  ),
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
      child: ZenGlassCard(
        blurSigma: 0,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(vertical: 12),
        onTap: () {
          Navigator.pop(ctx);
          _applyQuickTimer(dev, deviceTopic, targetAction, targetActionText, minutes);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              minutes < 60 ? '$minutes' : '${minutes ~/ 60}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              minutes < 60 ? context.tr('minutes') : context.tr('hours'),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
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
    final accent = targetAction == 'delay_off' ? AppColors.roseGlow : context.zenColors.primary;

    showZenGlassDialog(
      context: context,
      accentColor: accent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ZenLiquidGlass(
                  blurSigma: 0,
                  borderRadius: 12,
                  padding: const EdgeInsets.all(9),
                  glowColor: accent,
                  surfaceColor: accent.withOpacity(0.16),
                  child: Icon(Icons.timer_outlined, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${context.tr('timer')} $targetActionText: ${dev.name}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('quick_timer_enter_minutes'),
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minutesCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.lightText,
              ),
              decoration: zenGlassInputDecoration(
                ctx,
                borderRadius: 16,
                accentColor: accent,
              ).copyWith(
                suffixText: context.tr('minutes'),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ZenGlassButton(
                    isPrimary: false,
                    label: context.tr('btn_cancel'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZenGlassButton(
                    label: context.tr('btn_confirm'),
                    accentColor: accent,
                    onPressed: () {
                      final int? mins = int.tryParse(minutesCtrl.text.trim());
                      if (mins != null && mins > 0 && mins <= 1440) {
                        Navigator.pop(ctx);
                        _applyQuickTimer(dev, deviceTopic, targetAction, targetActionText, mins);
                      } else {
                        showFloatingToast(context, context.tr('error'), context.tr('quick_timer_invalid_minutes'), isError: true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

}
