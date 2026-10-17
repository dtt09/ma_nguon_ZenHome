import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/premium_dialog.dart';
import 'package:zenhome_app/core/widgets/zalopay_status_dialog.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';
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
    'lightbulb_rounded',
    'mode_fan_off',
    'bedtime_rounded',
    'water_drop',
    'power',
    'tv',
  ];
  final List<String> _roomOptions = ['room_1', 'room_2', 'room_3', 'room_4'];
  final List<int> _suggestedPins = [2, 4, 12, 13, 14, 15, 18, 19, 21, 22, 23, 25, 26, 27];

  @override
  void initState() {
    super.initState();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    _tempDevices = activeConfig.devices.map((e) => DeviceConfig.fromJson(e.toJson())).toList();
  }

  void _saveMapping() async {
    if (_tempDevices.isEmpty) {
      showZaloPayWarningDialog(
        context,
        title: context.tr('error'),
        message: context.tr('err_need_device'),
      );
      return;
    }

    // --- KIỂM TRA TOÀN DIỆN TRÁNH TRÙNG CHÂN GPIO ---
    final Map<int, List<String>> pinToDevices = {};
    for (var dev in _tempDevices) {
      pinToDevices.putIfAbsent(dev.pin, () => []).add(dev.name);
    }
    for (var entry in pinToDevices.entries) {
      if (entry.value.length > 1) {
        showZaloPayErrorDialog(
          context,
          title: 'Xung đột phần cứng GPIO',
          message: 'Chân GPIO ${entry.key} đang bị gán trùng cho nhiều thiết bị: "${entry.value.join('", "')}". Mỗi thiết bị phải kết nối một chân GPIO độc lập.',
          details: {
            'Chân GPIO': '${entry.key}',
            'Thiết bị trùng': entry.value.join(', '),
            'Yêu cầu': 'Thay đổi chân GPIO trước khi lưu',
          },
        );
        return;
      }
    }

    // --- KIỂM TRA TOÀN DIỆN TRÁNH TRÙNG TÊN THIẾT BỊ TRONG CÙNG PHÒNG ---
    final Map<String, List<String>> roomNameToDevices = {};
    for (var dev in _tempDevices) {
      final key = '${dev.room}::${dev.name.trim().toLowerCase()}';
      roomNameToDevices.putIfAbsent(key, () => []).add(dev.name);
    }
    for (var entry in roomNameToDevices.entries) {
      if (entry.value.length > 1) {
        final parts = entry.key.split('::');
        final roomTitle = context.tr(parts[0]);
        showZaloPayErrorDialog(
          context,
          title: 'Trùng tên thiết bị trong phòng',
          message: 'Trong "$roomTitle" có nhiều thiết bị cùng mang tên "${entry.value.first}". Vui lòng đặt tên khác nhau để tránh nhầm lẫn.',
          details: {
            'Khu vực': roomTitle,
            'Tên xung đột': entry.value.first,
            'Yêu cầu': 'Đổi tên thiết bị trước khi lưu',
          },
        );
        return;
      }
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
        debugPrint('Lỗi publish config mqtt: $e');
      }

      setState(() => _isSyncing = false);
      if (mounted) {
        await showZaloPaySuccessDialog(
          context,
          title: context.tr('mapping_saved_title'),
          message: context.tr('mapping_saved_desc'),
          details: {
            'Số lượng thiết bị': '${_tempDevices.length} thiết bị',
            'Đồng bộ Cloud': 'Firestore thành công',
            'Đồng bộ ESP32': 'Đã gửi qua MQTT (${activeConfig.mqttPrefix})',
            'Thời gian': DateTime.now().toLocal().toString().substring(0, 19),
          },
          buttonText: 'Hoàn tất',
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Lỗi đồng bộ: $e');
      setState(() => _isSyncing = false);
      if (mounted) {
        await showZaloPayErrorDialog(
          context,
          title: 'Lưu ngoại tuyến',
          message: '${context.tr('msg_sync_offline')}\nChi tiết: $e',
          details: {
            'Chế độ': 'Lưu tạm cục bộ (Offline)',
            'Lỗi': e.toString(),
          },
        );
        if (mounted) Navigator.pop(context);
      }
    }
  }

  IconData _getIconData(String iconStr) {
    switch (iconStr) {
      case 'lightbulb_rounded':
        return Icons.lightbulb_rounded;
      case 'mode_fan_off':
        return Icons.mode_fan_off;
      case 'bedtime_rounded':
        return Icons.bedtime_rounded;
      case 'water_drop':
        return Icons.water_drop;
      case 'power':
        return Icons.power;
      case 'tv':
        return Icons.tv;
      default:
        return Icons.widgets_rounded;
    }
  }

  void _showDeleteConfirmDialog(int index) async {
    final dev = _tempDevices[index];
    final confirmed = await showCautionConfirmDialog(
      context,
      title: context.tr('confirm_delete_device_title'),
      warningText: 'Bạn có chắc chắn muốn xóa thiết bị "${dev.name}" (GPIO ${dev.pin}) khỏi cấu hình không?',
      cautionDetails: 'Khu vực: ${context.tr(dev.room)} • ID: ${dev.id}\nLưu ý: Mọi lịch trình, hẹn giờ và ngữ cảnh gắn với thiết bị này sẽ bị gỡ bỏ.',
      confirmText: context.tr('btn_delete'),
      cancelText: context.tr('cancel'),
      isDanger: true,
    );
    if (confirmed && mounted) {
      setState(() {
        _tempDevices.removeAt(index);
      });
    }
  }

  void _showDeviceBottomSheet({DeviceConfig? editDevice, int? index}) {
    bool isEdit = editDevice != null;
    String devId = isEdit ? editDevice.id : 'relay_${_tempDevices.length + 1}';
    String name = isEdit ? editDevice.name : '';
    int pin = isEdit ? editDevice.pin : 2;
    String room = isEdit ? editDevice.room : _roomOptions.first;
    String icon = isEdit ? editDevice.icon : _iconOptions.first;

    final formKey = GlobalKey<FormState>();
    final pinController = TextEditingController(text: pin.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            bool isDark = Theme.of(context).brightness == Brightness.dark;
            final cardColor = isDark ? AppColors.darkCard : Colors.white;
            final textColor = isDark ? AppColors.darkText : AppColors.lightText;
            final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
            final borderColor = isDark ? AppColors.darkCardBorder : const Color(0xFFE2EFEA);

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: EdgeInsets.only(
                top: 16,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border(
                  top: BorderSide(color: isDark ? AppColors.primaryLight.withOpacity(0.3) : AppColors.lightCardBorder, width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.6 : 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header Title with Icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: AppColors.brandHero,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              isEdit ? Icons.tune_rounded : Icons.add_circle_outline_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? context.tr('edit_device_title') : context.tr('add_device_title'),
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('admin_mapping_subtitle'),
                                  style: TextStyle(fontSize: 12, color: mutedColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Device ID
                      Text(
                        context.tr('device_id_label'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: devId,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'relay_1',
                          hintStyle: TextStyle(color: mutedColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.fingerprint_rounded, color: AppColors.primaryLight, size: 22),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => devId = val.trim(),
                        validator: (val) => (val == null || val.trim().isEmpty) ? context.tr('err_empty_field') : null,
                      ),
                      const SizedBox(height: 16),

                      // Device Name
                      Text(
                        context.tr('device_name_label'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: name,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: context.tr('dev_name_hint'),
                          hintStyle: TextStyle(color: mutedColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.label_outline_rounded, color: AppColors.primaryLight, size: 22),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => name = val.trim(),
                        validator: (val) => (val == null || val.trim().isEmpty) ? context.tr('err_empty_field') : null,
                      ),
                      const SizedBox(height: 16),

                      // GPIO Pin Input + Quick Suggestion Chips
                      Text(
                        context.tr('select_pin_label'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: '2',
                          hintStyle: TextStyle(color: mutedColor.withOpacity(0.5)),
                          prefixIcon: Icon(Icons.memory_rounded, color: AppColors.primaryLight, size: 22),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onChanged: (val) => pin = int.tryParse(val) ?? 0,
                      ),
                      const SizedBox(height: 8),

                      // Quick GPIO Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: _suggestedPins.map((p) {
                            final isCurPin = pin == p;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setModalState(() {
                                    pin = p;
                                    pinController.text = p.toString();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isCurPin
                                        ? AppColors.primary.withOpacity(0.2)
                                        : (isDark ? AppColors.darkCardElevated : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurPin ? AppColors.primaryLight : borderColor,
                                      width: isCurPin ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Text(
                                    'GPIO $p',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isCurPin ? FontWeight.bold : FontWeight.w500,
                                      color: isCurPin ? AppColors.primaryLight : mutedColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Room Dropdown
                      Text(
                        context.tr('room_hint'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: room,
                        dropdownColor: cardColor,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.meeting_room_outlined, color: AppColors.primaryLight, size: 22),
                          filled: true,
                          fillColor: isDark ? AppColors.darkCardElevated : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        items: _roomOptions.map((r) => DropdownMenuItem(value: r, child: Text(context.tr(r)))).toList(),
                        onChanged: (val) => setModalState(() => room = val!),
                      ),
                      const SizedBox(height: 20),

                      // Icon Selector
                      Text(
                        context.tr('choose_icon'),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: mutedColor),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 68,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _iconOptions.length,
                          itemBuilder: (context, i) {
                            String icName = _iconOptions[i];
                            bool isSelected = icon == icName;
                            return GestureDetector(
                              onTap: () => setModalState(() => icon = icName),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 62,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  gradient: isSelected ? AppColors.brandHero : null,
                                  color: isSelected
                                      ? null
                                      : (isDark ? AppColors.darkCardElevated : Colors.grey.shade100),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryAccent : borderColor,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primaryLight.withOpacity(0.35),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  _getIconData(icName),
                                  color: isSelected ? Colors.white : mutedColor,
                                  size: 26,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandHero,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              // 1. Kiểm tra Device ID trùng
                              bool exists = false;
                              for (int i = 0; i < _tempDevices.length; i++) {
                                if (i != index && _tempDevices[i].id.trim().toLowerCase() == devId.trim().toLowerCase()) {
                                  exists = true;
                                  break;
                                }
                              }
                              if (exists) {
                                showZaloPayWarningDialog(
                                  context,
                                  title: 'Mã thiết bị đã tồn tại',
                                  message: 'Mã ID "$devId" đã được sử dụng cho một thiết bị khác. Vui lòng chọn mã ID khác.',
                                  details: {'Mã nhập vào': devId},
                                );
                                return;
                              }

                              // 2. Kiểm tra trùng chân GPIO
                              DeviceConfig? conflictingPinDev;
                              for (int i = 0; i < _tempDevices.length; i++) {
                                if (i != index && _tempDevices[i].pin == pin) {
                                  conflictingPinDev = _tempDevices[i];
                                  break;
                                }
                              }
                              if (conflictingPinDev != null) {
                                showZaloPayWarningDialog(
                                  context,
                                  title: 'Xung đột chân GPIO $pin',
                                  message: 'Chân GPIO $pin đã được sử dụng cho thiết bị "${conflictingPinDev.name}" (${context.tr(conflictingPinDev.room)}). Vui lòng chọn chân GPIO khác!',
                                  details: {
                                    'Chân GPIO': '$pin',
                                    'Đang sử dụng bởi': conflictingPinDev.name,
                                    'Phòng': context.tr(conflictingPinDev.room),
                                  },
                                );
                                return;
                              }

                              // 3. Kiểm tra trùng tên thiết bị trong cùng 1 phòng
                              DeviceConfig? conflictingNameDev;
                              for (int i = 0; i < _tempDevices.length; i++) {
                                if (i != index &&
                                    _tempDevices[i].room == room &&
                                    _tempDevices[i].name.trim().toLowerCase() == name.trim().toLowerCase()) {
                                  conflictingNameDev = _tempDevices[i];
                                  break;
                                }
                              }
                              if (conflictingNameDev != null) {
                                showZaloPayWarningDialog(
                                  context,
                                  title: 'Trùng tên trong cùng phòng',
                                  message: 'Trong "${context.tr(room)}" đã có thiết bị mang tên "$name". Vui lòng đặt tên khác để dễ phân biệt khi điều khiển!',
                                  details: {
                                    'Khu vực': context.tr(room),
                                    'Tên trùng': name,
                                  },
                                );
                                return;
                              }

                              setState(() {
                                DeviceConfig newConfig = DeviceConfig(
                                  id: devId,
                                  pin: pin,
                                  room: room,
                                  name: name,
                                  icon: icon,
                                );
                                if (isEdit && index != null) {
                                  _tempDevices[index] = newConfig;
                                } else {
                                  _tempDevices.add(newConfig);
                                }
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          child: Text(
                            isEdit ? context.tr('btn_update_device') : context.tr('btn_add_device'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final bool isEspOnline = ref.watch(espOnlineStateProvider);

    bool isUnlinked = activeConfig.macAddress == 'unknown_mac' ||
        activeConfig.macAddress.isEmpty ||
        activeConfig.macAddress == 'unknown';

    String statusText = isUnlinked
        ? context.tr('status_unlinked')
        : (isEspOnline ? context.tr('online') : context.tr('offline'));

    Color statusColor = isUnlinked
        ? AppColors.amberGlow
        : (isEspOnline ? AppColors.emeraldGlow : Colors.grey.shade400);

    bool hasUnsavedChanges = jsonEncode(_tempDevices.map((e) => e.toJson()).toList()) !=
        jsonEncode(activeConfig.devices.map((e) => e.toJson()).toList());

    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool? confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              context.tr('unsaved_changes_device_title'),
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            content: Text(
              context.tr('unsaved_changes_device_desc'),
              style: TextStyle(color: mutedColor),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.tr('cancel'), style: TextStyle(color: mutedColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.roseGlow,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.tr('confirm')),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCardElevated : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textColor),
              ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('admin_mapping_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                context.tr('admin_mapping_subtitle'),
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
          actions: [
            // Sort Button
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _tempDevices.sort((a, b) {
                      int roomCompare = context.tr(a.room).compareTo(context.tr(b.room));
                      if (roomCompare != 0) return roomCompare;
                      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                    });
                  });
                  showFloatingToast(context, context.tr('toast_success'), context.tr('sorted_devices_success'));
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.sort_by_alpha_rounded, color: AppColors.primaryLight, size: 20),
                ),
              ),
            ),

            // Save / Sync Button
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isSyncing ? null : _saveMapping,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandHero,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: LogoLoadingIndicator(color: Colors.white, size: 20),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              context.tr('btn_save'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: AppColors.brandHero,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryLight.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            elevation: 0,
            highlightElevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: Text(
              context.tr('btn_add_device'),
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
            onPressed: () {
              final currentConfig = ref.read(homeConfigProvider).activeConfig;
              if (currentConfig.macAddress == 'unknown_mac' ||
                  currentConfig.macAddress.isEmpty ||
                  currentConfig.macAddress == 'unknown') {
                showFloatingToast(
                  context,
                  context.tr('error'),
                  context.tr('err_link_esp_first'),
                  isError: true,
                );
                return;
              }
              _showDeviceBottomSheet();
            },
          ),
        ),
        body: RefreshIndicator(
          color: AppColors.primaryLight,
          onRefresh: () async {
            await ref.read(homeConfigProvider).syncFromFirestore();
            final activeConfig = ref.read(homeConfigProvider).activeConfig;
            if (mounted) {
              setState(() {
                _tempDevices = activeConfig.devices.map((e) => DeviceConfig.fromJson(e.toJson())).toList();
              });
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ESP32 Status Card (Luxury Frosted / Glowing Border)
              Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isUnlinked ? AppColors.amberGlow.withOpacity(0.5) : borderColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUnlinked ? AppColors.amberGlow : AppColors.primary).withOpacity(isDark ? 0.15 : 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withOpacity(0.2),
                              statusColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Icon(Icons.router_rounded, size: 26, color: statusColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.tr('esp32_hub'),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: statusColor.withOpacity(0.8),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.fingerprint_rounded, size: 14, color: mutedColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isUnlinked ? context.tr('status_unlinked') : activeConfig.macAddress,
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isUnlinked) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.amberGlow.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.amberGlow.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.amberGlow, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('err_link_esp_first'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.amberGlow,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const WifiSetupScreen()),
                              );
                            },
                            child: Text(
                              context.tr('btn_link_hub_now'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('relay_device_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCardElevated : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    context.tr('device_count_label').replaceAll('{count}', _tempDevices.length.toString()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Device List
            if (_tempDevices.isEmpty) ...[
              Container(
                margin: const EdgeInsets.only(top: 30),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.devices_rounded, size: 48, color: AppColors.primaryLight),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('device_empty_list'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('device_empty_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: mutedColor),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(context.tr('btn_add_device')),
                      onPressed: () {
                        if (isUnlinked) {
                          showFloatingToast(
                            context,
                            context.tr('error'),
                            context.tr('err_link_esp_first'),
                            isError: true,
                          );
                          return;
                        }
                        _showDeviceBottomSheet();
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              for (int index = 0; index < _tempDevices.length; index++)
                Builder(builder: (context) {
                  final dev = _tempDevices[index];
                  return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Squircle Icon Container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.18),
                              AppColors.primaryLight.withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primaryLight.withOpacity(0.25)),
                        ),
                        child: Icon(
                          _getIconData(dev.icon),
                          size: 26,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Device Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                // Room Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkCardElevated : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.meeting_room_outlined, size: 11, color: mutedColor),
                                      const SizedBox(width: 3),
                                      Text(
                                        context.tr(dev.room),
                                        style: TextStyle(fontSize: 10, color: mutedColor, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),

                                // GPIO Pin Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primaryLight.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'GPIO ${dev.pin}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.primaryLight,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),

                                // ID Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkCardElevated : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    dev.id,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: mutedColor,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Edit Action
                      IconButton(
                        tooltip: context.tr('edit_device_title'),
                        icon: Icon(Icons.edit_rounded, color: AppColors.primaryLight, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showDeviceBottomSheet(editDevice: dev, index: index),
                      ),
                      const SizedBox(width: 6),

                      // Delete Action
                      IconButton(
                        tooltip: context.tr('btn_delete'),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.roseGlow, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.roseGlow.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _showDeleteConfirmDialog(index),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
  );
}
}