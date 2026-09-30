import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;

class DeviceMappingScreen extends ConsumerStatefulWidget {
  const DeviceMappingScreen({super.key});

  @override
  ConsumerState<DeviceMappingScreen> createState() => _DeviceMappingScreenState();
}

class _DeviceMappingScreenState extends ConsumerState<DeviceMappingScreen> {
  List<DeviceConfig> _tempDevices = [];
  bool _isSyncing = false; 

  final List<String> _iconOptions = [
    'lightbulb_rounded', 'mode_fan_off', 'bedtime_rounded', 'water_drop', 'power', 'tv'
  ];
  final List<String> _roomOptions = ['room_1', 'room_2', 'room_3', 'room_4'];

  @override
  void initState() {
    super.initState();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    _tempDevices = activeConfig.devices.map((e) => DeviceConfig.fromJson(e.toJson())).toList();
  }

  void _saveMapping() async {
    if (_tempDevices.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_need_device'), isError: true);
      return;
    }

    setState(() => _isSyncing = true);
    final activeConfig = ref.read(homeConfigProvider).activeConfig;

    // Lưu local trước để đảm bảo tính năng Offline hoạt động
    activeConfig.devices = _tempDevices;
    await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

    try {
      if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
          'devices': _tempDevices.map((e) => e.toJson()).toList(),
          'mqttServer': activeConfig.mqttServer,
          'mqttUser': activeConfig.mqttUser,
          'mqttPass': activeConfig.mqttPass,
          'macAddress': activeConfig.macAddress,
        }, SetOptions(merge: true)); 
      }
      
      // Đồng bộ thiết bị mới xuống thẳng ESP32 qua MQTT để ESP32 cập nhật lại cấu hình Relay
      try {
        String devicesJson = jsonEncode(_tempDevices.map((e) => e.toJson()).toList());
        String configTopic = '${activeConfig.mqttPrefix}/system/config';
        ref.read(mqttRepositoryProvider).publishCmd(configTopic, devicesJson);
        
        // Gửi lệnh restart cho ESP32
        String restartTopic = '${activeConfig.mqttPrefix}/system/restart';
        ref.read(mqttRepositoryProvider).publishCmd(restartTopic, '1');
        
        // Đăng ký nhận bản tin state cho các thiết bị vừa thêm để app không bị timeout
        final mqttRepo = ref.read(mqttRepositoryProvider);
        if (mqttRepo.client?.connectionStatus?.state == mqtt.MqttConnectionState.connected) {
          for (var dev in _tempDevices) {
            String stateTopic = '${activeConfig.mqttPrefix}/${dev.room}/${dev.id}/state';
            mqttRepo.client?.subscribe(stateTopic, mqtt.MqttQos.atLeastOnce);
          }
        }
      } catch (e) {
        print("Lỗi publish config mqtt: $e");
      }

      setState(() => _isSyncing = false);
      if (mounted) {
        showFloatingToast(context, context.tr('toast_success'), context.tr('msg_saved_title'));
        Navigator.pop(context);
      }
    } catch (e) {
      print("Lỗi đồng bộ: $e");
      setState(() => _isSyncing = false);
      if (mounted) {
        showFloatingToast(context, context.tr('error'), context.tr('msg_sync_offline') ?? 'Lỗi mạng, đã lưu Offline', isError: true);
        Navigator.pop(context);
      }
    }
  }

  IconData _getIconData(String iconStr) {
    switch (iconStr) {
      case 'lightbulb_rounded': return Icons.lightbulb_rounded;
      case 'mode_fan_off': return Icons.mode_fan_off;
      case 'bedtime_rounded': return Icons.bedtime_rounded;
      case 'water_drop': return Icons.water_drop;
      case 'power': return Icons.power;
      case 'tv': return Icons.tv;
      default: return Icons.widgets_rounded;
    }
  }

  void _showDeviceBottomSheet({DeviceConfig? editDevice, int? index}) {
    bool isEdit = editDevice != null;
    String devId = isEdit ? editDevice.id : 'relay_${_tempDevices.length + 1}';
    String name = isEdit ? editDevice.name : '';
    int pin = isEdit ? editDevice.pin : 0;
    String room = isEdit ? editDevice.room : _roomOptions.first;
    String icon = isEdit ? editDevice.icon : _iconOptions.first;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121827) : Colors.white,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text(isEdit ? context.tr('edit_relay') : context.tr('add_relay'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      
                      // Bọc OutlineInputBorder cho TextField
                      TextFormField(
                        initialValue: devId,
                        decoration: InputDecoration(
                          labelText: context.tr('dev_id_hint'), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                        onChanged: (val) => devId = val,
                        validator: (val) => val!.isEmpty ? context.tr('err_empty_field') : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        initialValue: name,
                        decoration: InputDecoration(
                          labelText: context.tr('dev_name_hint'), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                        onChanged: (val) => name = val,
                        validator: (val) => val!.isEmpty ? context.tr('err_empty_field') : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        initialValue: pin.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('gpio_hint'), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                        onChanged: (val) => pin = int.tryParse(val) ?? 0,
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: room,
                        decoration: InputDecoration(
                          labelText: context.tr('room_hint'), 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        ),
                        items: _roomOptions.map((r) => DropdownMenuItem(value: r, child: Text(context.tr(r)))).toList(),
                        onChanged: (val) => setModalState(() => room = val!),
                      ),
                      const SizedBox(height: 20),
                      Text(context.tr('choose_icon'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _iconOptions.length,
                          itemBuilder: (context, i) {
                            String icName = _iconOptions[i];
                            bool isSelected = icon == icName;
                            return GestureDetector(
                              onTap: () => setModalState(() => icon = icName),
                              child: Container(
                                width: 60, margin: const EdgeInsets.only(right: 15),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2A3A7C) : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                                  shape: BoxShape.circle,
                                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                ),
                                child: Icon(_getIconData(icName), color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54)),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              // Validate if device ID already exists
                              bool exists = false;
                              for (int i = 0; i < _tempDevices.length; i++) {
                                if (i != index && _tempDevices[i].id == devId) {
                                  exists = true;
                                  break;
                                }
                              }
                              
                              if (exists) {
                                showFloatingToast(context, context.tr('error') ?? 'Lỗi', context.tr('err_device_id_exists') ?? 'Device ID đã tồn tại!', isError: true);
                                return;
                              }

                              setState(() {
                                DeviceConfig newConfig = DeviceConfig(id: devId, pin: pin, room: room, name: name, icon: icon);
                                if (isEdit && index != null) {
                                  _tempDevices[index] = newConfig;
                                } else {
                                  _tempDevices.add(newConfig);
                                }
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          child: Text(isEdit ? context.tr('btn_update') : context.tr('btn_add_device'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final bool isEspOnline = ref.watch(espOnlineStateProvider);
    bool isUnlinked = activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty;
    
    String statusText = isUnlinked ? (context.tr('unlinked') ?? 'Chưa l.kết') : (isEspOnline ? 'Online' : 'Offline');
    Color statusColor = isUnlinked ? Colors.orange : (isEspOnline ? Colors.green : Colors.grey.shade400);

    bool hasUnsavedChanges = jsonEncode(_tempDevices.map((e) => e.toJson()).toList()) != jsonEncode(activeConfig.devices.map((e) => e.toJson()).toList());

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.tr('confirm_exit') ?? 'Xác nhận thoát'),
            content: Text(context.tr('msg_unsaved_changes') ?? 'Bạn có thay đổi chưa lưu. Bạn có chắc chắn muốn thoát?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('cancel') ?? 'Hủy'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('confirm') ?? 'Thoát'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('admin_mapping_title') ?? 'Khu vực kỹ thuật', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF121827) : Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_by_alpha, color: Color(0xFF2A3A7C)),
            onPressed: () {
              setState(() {
                _tempDevices.sort((a, b) {
                  int roomCompare = context.tr(a.room).compareTo(context.tr(b.room));
                  if (roomCompare != 0) return roomCompare;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });
              });
              showFloatingToast(context, context.tr('toast_success') ?? 'Thành công', 'Đã sắp xếp thiết bị');
            },
            tooltip: 'Sắp xếp thiết bị',
          ),
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(width: 20, height: 20, child: LogoLoadingIndicator(color: Colors.white, size: 20))
                : const Icon(Icons.cloud_upload, color: Color(0xFF2A3A7C)),
            onPressed: _isSyncing ? null : _saveMapping,
            tooltip: context.tr('tooltip_save_sync'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2A3A7C),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          final activeConfig = ref.read(homeConfigProvider).activeConfig;
          if (activeConfig.macAddress == 'unknown_mac' || activeConfig.macAddress.isEmpty) {
            showFloatingToast(context, context.tr('error') ?? 'Lỗi', 'Vui lòng liên kết ESP32 trước khi thêm thiết bị mới!', isError: true);
            return;
          }
          _showDeviceBottomSheet();
        },
      ),
      body: Column(
        children: [
          // ESP32 Status Card
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2235) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.router, size: 30, color: statusColor),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('esp32_hub') ?? 'Hub Trung Tâm (ESP32)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Text('MAC: ${activeConfig.macAddress}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          // Device List
          Expanded(
            child: _tempDevices.isEmpty
                ? Center(child: Text(context.tr('no_device') ?? 'Chưa có thiết bị nào'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _tempDevices.length,
                    itemBuilder: (context, index) {
                      final dev = _tempDevices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121827) : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 5))]
                        ),
                        child: Row(
                          children: [
                            Icon(_getIconData(dev.icon), size: 40, color: const Color(0xFF2A3A7C)),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dev.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 5),
                                  Text(context.l10n.device_mapping_info(dev.id, dev.pin.toString()), style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  Text('${context.tr(dev.room)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showDeviceBottomSheet(editDevice: dev, index: index)),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() => _tempDevices.removeAt(index)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
    );
  }
}