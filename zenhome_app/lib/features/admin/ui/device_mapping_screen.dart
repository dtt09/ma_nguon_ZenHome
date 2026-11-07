import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/core/widgets/zalopay_status_dialog.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/features/admin/logic/device_mapping_controller.dart';
import 'package:zenhome_app/features/setup/ui/wifi_setup_screen.dart';

class DeviceMappingScreen extends ConsumerStatefulWidget {
  const DeviceMappingScreen({super.key});

  @override
  ConsumerState<DeviceMappingScreen> createState() =>
      _DeviceMappingScreenState();
}

class _DeviceMappingScreenState extends ConsumerState<DeviceMappingScreen> {
  List<DeviceConfig> _tempDevices = [];

  final List<String> _iconOptions = [
    'lightbulb_rounded',
    'mode_fan_off',
    'bedtime_rounded',
    'water_drop',
    'power',
    'tv',
  ];
  final List<String> _roomOptions = [
    'room_1',
    'room_2',
    'room_3',
    'room_4',
    'room_5',
    'room_6',
    'room_7',
    'room_8',
    'room_9',
    'room_10',
    'room_11',
    'custom',
  ];
  final List<int> _suggestedPins = [
    // Mạch mở rộng I2C PCF8574 (Chân P0 -> P7)
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    // Chân GPIO trực tiếp trên ESP32 (Đã loại trừ 21, 22 bảo vệ I2C)
    12,
    13,
    14,
    15,
    18,
    19,
    23,
    25,
    26,
    27,
  ];

  @override
  void initState() {
    super.initState();
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    _tempDevices = activeConfig.devices
        .map((e) => DeviceConfig.fromJson(e.toJson()))
        .toList();
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

    final controller = ref.read(deviceMappingProvider.notifier);

    // 1. KIỂM TRA TOÀN DIỆN TRÁNH TRÙNG CHÂN GPIO QUA CONTROLLER
    final gpioConflict = controller.checkGpioConflict(_tempDevices);
    if (gpioConflict != null) {
      showZaloPayErrorDialog(
        context,
        title: context.tr('gpio_conflict_title'),
        message:
            'Chân GPIO ${gpioConflict.pin} đang bị gán trùng cho nhiều thiết bị: "${gpioConflict.deviceNames.join('", "')}". Mỗi thiết bị phải kết nối một chân GPIO độc lập.',
        details: {
          'Chân GPIO': '${gpioConflict.pin}',
          'Thiết bị trùng': gpioConflict.deviceNames.join(', '),
          'Yêu cầu': 'Thay đổi chân GPIO trước khi lưu',
        },
      );
      return;
    }

    // 2. KIỂM TRA TRÙNG TÊN THIẾT BỊ TRONG PHÒNG QUA CONTROLLER
    final nameConflict = controller.checkRoomNameConflict(_tempDevices);
    if (nameConflict != null) {
      final roomTitle = context.tr(nameConflict.roomKey);
      showZaloPayErrorDialog(
        context,
        title: context.tr('room_name_conflict_title'),
        message:
            'Trong "$roomTitle" có nhiều thiết bị cùng mang tên "${nameConflict.deviceName}". Vui lòng đặt tên khác nhau để tránh nhầm lẫn.',
        details: {
          'Khu vực': roomTitle,
          'Tên xung đột': nameConflict.deviceName,
          'Yêu cầu': 'Đổi tên thiết bị trước khi lưu',
        },
      );
      return;
    }

    // 3. THỰC THI ĐỒNG BỘ CẤU HÌNH QUA CONTROLLER
    final result = await controller.saveMapping(_tempDevices);
    if (!mounted) return;

    if (!result.isOffline) {
      await showZaloPaySuccessDialog(
        context,
        title: context.tr('mapping_saved_title'),
        message: context.tr('mapping_saved_desc'),
        details: result.details,
        buttonText: context.tr('btn_confirm'),
      );
      if (mounted) Navigator.pop(context);
    } else {
      await showZaloPayErrorDialog(
        context,
        title: context.tr('offline_saved_title'),
        message:
            '${context.tr('msg_sync_offline')}\nChi tiết: ${result.errorMessage}',
        details: {
          'Chế độ': 'Lưu tạm cục bộ (Offline)',
          'Lỗi': result.errorMessage ?? '',
        },
      );
      if (mounted) Navigator.pop(context);
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
    final zen = context.zenColors;
    final bool confirmed = await showZenGlassDialog<bool>(
          context: context,
          accentColor: zen.danger,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final textColor = isDark ? AppColors.darkText : AppColors.lightText;
            final mutedColor =
                isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: zen.danger.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: zen.danger.withOpacity(0.32)),
                      ),
                      child: Icon(Icons.delete_forever_rounded,
                          color: zen.danger, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('confirm_delete_device_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: zen.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Bạn có chắc chắn muốn xóa thiết bị "${dev.name}" (GPIO ${dev.pin}) khỏi cấu hình không?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                ZenLiquidGlass(
                  blurSigma: 0,
                  borderRadius: 14,
                  padding: const EdgeInsets.all(12),
                  surfaceColor:
                      zen.danger.withOpacity(isDark ? 0.10 : 0.06),
                  glowColor: zen.danger,
                  child: Text(
                    'Khu vực: ${context.tr(dev.room)} • ID: ${dev.id}\nLưu ý: Mọi lịch trình, hẹn giờ và ngữ cảnh gắn với thiết bị này sẽ bị gỡ bỏ.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: mutedColor,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: ZenGlassButton(
                        label: context.tr('cancel'),
                        isPrimary: false,
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ZenGlassButton(
                        label: context.tr('btn_delete'),
                        icon: Icons.delete_outline_rounded,
                        isDanger: true,
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ) ??
        false;

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
    bool isCustomRoom = isEdit && !_roomOptions.contains(editDevice.room);

    final formKey = GlobalKey<FormState>();
    final pinController = TextEditingController(text: pin.toString());
    final customRoomController =
        TextEditingController(text: isCustomRoom ? editDevice.room : '');

    showZenGlassBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      maxHeightFactor: 0.88,
      showHandle: true,
      padBottomForKeyboard: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
            final zen = ctx.zenColors;
            final textColor = isDark ? AppColors.darkText : AppColors.lightText;
            final mutedColor =
                isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
            final accentColor = isDark ? zen.primaryAccent : zen.primary;

            return Form(
              key: formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Title with Icon (no duplicate drag handle)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: zen.brandHero,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: zen.primary.withOpacity(0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.tune_rounded
                                : Icons.add_circle_outline_rounded,
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
                                isEdit
                                    ? context.tr('edit_device_title')
                                    : context.tr('add_device_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('admin_mapping_subtitle'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Device ID
                    Text(
                      context.tr('device_id_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: devId,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                      decoration: zenGlassInputDecoration(
                        ctx,
                        hintText: 'relay_1',
                        prefixIcon: Icons.fingerprint_rounded,
                      ),
                      onChanged: (val) => devId = val.trim(),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? context.tr('err_empty_field')
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Device Name
                    Text(
                      context.tr('device_name_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      initialValue: name,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: zenGlassInputDecoration(
                        ctx,
                        hintText: context.tr('dev_name_hint'),
                        prefixIcon: Icons.label_outline_rounded,
                      ),
                      onChanged: (val) => name = val.trim(),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? context.tr('err_empty_field')
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // GPIO Pin Input + Quick Suggestion Chips
                    Text(
                      context.tr('select_pin_label'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                      decoration: zenGlassInputDecoration(
                        ctx,
                        hintText: '2',
                        prefixIcon: Icons.memory_rounded,
                      ),
                      onChanged: (val) {
                        setModalState(() {
                          pin = int.tryParse(val) ?? 0;
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Quick GPIO Glass Pills (blurSigma: 0)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _suggestedPins.map((p) {
                          final isCurPin = pin == p;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ZenGlassPill(
                              blurSigma: 0,
                              isSelected: isCurPin,
                              glowColor: zen.primary,
                              borderRadius: 12,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 11, vertical: 6),
                              onTap: () {
                                setModalState(() {
                                  pin = p;
                                  pinController.text = p.toString();
                                });
                              },
                              child: Text(
                                p <= 7 ? 'P$p (I2C)' : 'GPIO $p',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontFamily: 'monospace',
                                  fontWeight: isCurPin
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isCurPin ? accentColor : mutedColor,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Room Selector
                    Text(
                      context.tr('room_hint'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InputDecorator(
                      decoration: zenGlassInputDecoration(
                        ctx,
                        prefixIcon: Icons.meeting_room_outlined,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: (isCustomRoom || !_roomOptions.contains(room))
                              ? 'custom'
                              : room,
                          dropdownColor: isDark
                              ? const Color(0xFF0E172A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          items: _roomOptions
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r == 'custom'
                                        ? '✨ ${context.tr('custom_room')}...'
                                        : context.tr(r),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setModalState(() {
                              if (val == 'custom') {
                                isCustomRoom = true;
                              } else {
                                isCustomRoom = false;
                                room = val;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    if (isCustomRoom || !_roomOptions.contains(room)) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: customRoomController,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: zenGlassInputDecoration(
                          ctx,
                          hintText: context.tr('custom_room_hint'),
                          prefixIcon: Icons.edit_location_alt_rounded,
                          accentColor: AppColors.amberGlow,
                        ),
                        onChanged: (val) => room = val.trim(),
                        validator: (val) {
                          if (isCustomRoom &&
                              (val == null || val.trim().isEmpty)) {
                            return context.tr('err_empty_custom_room');
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Icon Selector (blurSigma: 0 glass pills)
                    Text(
                      context.tr('choose_icon'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 66,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _iconOptions.length,
                        itemBuilder: (context, i) {
                          final String icName = _iconOptions[i];
                          final bool isSelected = icon == icName;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: ZenGlassPill(
                              blurSigma: 0,
                              borderRadius: 18,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 14),
                              isSelected: isSelected,
                              glowColor: zen.primary,
                              customGradient: isSelected ? zen.brandHero : null,
                              onTap: () => setModalState(() => icon = icName),
                              child: Icon(
                                _getIconData(icName),
                                color: isSelected ? Colors.white : mutedColor,
                                size: 25,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ZenGlassButton(
                        label: isEdit
                            ? context.tr('btn_update_device')
                            : context.tr('btn_add_device'),
                        icon: isEdit
                            ? Icons.check_circle_outline_rounded
                            : Icons.add_circle_outline_rounded,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            // 1. Kiểm tra Device ID trùng
                            bool exists = false;
                            for (int i = 0; i < _tempDevices.length; i++) {
                              if (i != index &&
                                  _tempDevices[i].id.trim().toLowerCase() ==
                                      devId.trim().toLowerCase()) {
                                exists = true;
                                break;
                              }
                            }
                            if (exists) {
                              showZaloPayWarningDialog(
                                context,
                                title: context.tr('err_duplicate_dev_id'),
                                message:
                                    'Mã ID "$devId" đã được sử dụng cho một thiết bị khác. Vui lòng chọn mã ID khác.',
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
                                title: context.tr('gpio_conflict_title'),
                                message:
                                    'Chân GPIO $pin đã được sử dụng cho thiết bị "${conflictingPinDev.name}" (${context.tr(conflictingPinDev.room)}). Vui lòng chọn chân GPIO khác!',
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
                                  _tempDevices[i].name.trim().toLowerCase() ==
                                      name.trim().toLowerCase()) {
                                conflictingNameDev = _tempDevices[i];
                                break;
                              }
                            }
                            if (conflictingNameDev != null) {
                              showZaloPayWarningDialog(
                                context,
                                title: context.tr('room_name_conflict_title'),
                                message:
                                    'Trong "${context.tr(room)}" đã có thiết bị mang tên "$name". Vui lòng đặt tên khác để dễ phân biệt khi điều khiển!',
                                details: {
                                  'Khu vực': context.tr(room),
                                  'Tên trùng': name,
                                },
                              );
                              return;
                            }

                            setState(() {
                              final finalRoom = (isCustomRoom ||
                                      !_roomOptions.contains(room))
                                  ? (customRoomController.text
                                          .trim()
                                          .isNotEmpty
                                      ? customRoomController.text.trim()
                                      : room)
                                  : room;
                              DeviceConfig newConfig = DeviceConfig(
                                id: devId,
                                pin: pin,
                                room: finalRoom,
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
                      ),
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final activeConfig = ref.watch(homeConfigProvider).activeConfig;
    final bool isEspOnline = ref.watch(espOnlineStateProvider);
    final bool isSyncing = ref.watch(deviceMappingProvider);

    final bool isUnlinked = activeConfig.macAddress == 'unknown_mac' ||
        activeConfig.macAddress.isEmpty ||
        activeConfig.macAddress == 'unknown';

    final String statusText = isUnlinked
        ? context.tr('status_unlinked')
        : (isEspOnline ? context.tr('online') : context.tr('offline'));

    final Color statusColor = isUnlinked
        ? AppColors.amberGlow
        : (isEspOnline ? AppColors.emeraldGlow : Colors.grey.shade400);

    final bool hasUnsavedChanges =
        jsonEncode(_tempDevices.map((e) => e.toJson()).toList()) !=
            jsonEncode(activeConfig.devices.map((e) => e.toJson()).toList());

    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final accentColor = isDark ? zen.primaryAccent : zen.primary;

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool? confirm = await showZenGlassDialog<bool>(
          context: context,
          accentColor: zen.danger,
          builder: (ctx) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: zen.danger.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: zen.danger.withOpacity(0.32)),
                    ),
                    child: Icon(Icons.warning_amber_rounded,
                        color: zen.danger, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('unsaved_changes_device_title'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('unsaved_changes_device_desc'),
                style: TextStyle(color: mutedColor, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: ZenGlassButton(
                      label: context.tr('cancel'),
                      isPrimary: false,
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ZenGlassButton(
                      label: context.tr('confirm'),
                      isDanger: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: ZenGlassScaffold(
        appBar: ZenGlassAppBar(
          onBack: () => Navigator.maybePop(context),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('admin_mapping_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.5,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                context.tr('admin_mapping_subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
          actions: [
            // Sort Button
            ZenGlassIconButton(
              blurSigma: 0,
              size: 38,
              iconSize: 19,
              borderRadius: 12,
              icon: Icons.sort_by_alpha_rounded,
              iconColor: accentColor,
              tooltip: context.tr('sort_devices'),
              onTap: () {
                setState(() {
                  _tempDevices.sort((a, b) {
                    int roomCompare =
                        context.tr(a.room).compareTo(context.tr(b.room));
                    if (roomCompare != 0) return roomCompare;
                    return a.name
                        .toLowerCase()
                        .compareTo(b.name.toLowerCase());
                  });
                });
                showFloatingToast(
                  context,
                  context.tr('toast_success'),
                  context.tr('sorted_devices_success'),
                );
              },
            ),
            const SizedBox(width: 8),

            // Save / Sync Button
            ZenGlassButton(
              label: context.tr('btn_save'),
              icon: Icons.cloud_upload_rounded,
              isLoading: isSyncing,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onPressed: isSyncing ? null : _saveMapping,
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: IntrinsicWidth(
          child: ZenGlassButton(
            label: context.tr('btn_add_device'),
            icon: Icons.add_rounded,
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          color: zen.primary,
          onRefresh: () async {
            await ref.read(homeConfigProvider).syncFromFirestore();
            final activeConfig = ref.read(homeConfigProvider).activeConfig;
            if (mounted) {
              setState(() {
                _tempDevices = activeConfig.devices
                    .map((e) => DeviceConfig.fromJson(e.toJson()))
                    .toList();
              });
            }
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ESP32 Status Card (Liquid Glass 2.0)
              ZenGlassCard(
                padding: const EdgeInsets.all(18),
                blurSigma: 16,
                isActive: !isUnlinked && isEspOnline,
                glowColor: statusColor,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withOpacity(0.22),
                                statusColor.withOpacity(0.06),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: statusColor.withOpacity(0.35)),
                          ),
                          child: Icon(Icons.router_rounded,
                              size: 26, color: statusColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      context.tr('esp32_hub'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: textColor,
                                      ),
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
                                  Icon(Icons.fingerprint_rounded,
                                      size: 14, color: mutedColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isUnlinked
                                          ? context.tr('status_unlinked')
                                          : activeConfig.macAddress,
                                      style: TextStyle(
                                        color: mutedColor,
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
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
                        // Status Glass Pill
                        ZenGlassPill(
                          blurSigma: 0,
                          isSelected: true,
                          glowColor: statusColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 14,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        surfaceColor: AppColors.amberGlow
                            .withOpacity(isDark ? 0.12 : 0.08),
                        glowColor: AppColors.amberGlow,
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.amberGlow, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('err_link_esp_first'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.amber.shade200
                                      : Colors.amber.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ZenGlassButton(
                              label: context.tr('btn_link_hub_now'),
                              accentColor: AppColors.amberGlow,
                              borderRadius: 11,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const WifiSetupScreen()),
                                );
                              },
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
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: zen.brandHero,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('relay_device_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  ZenGlassPill(
                    blurSigma: 0,
                    isSelected: true,
                    glowColor: zen.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                    child: Text(
                      context
                          .tr('device_count_label')
                          .replaceAll('{count}', _tempDevices.length.toString()),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Device List
              if (_tempDevices.isEmpty) ...[
                ZenGlassCard(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(28),
                  blurSigma: 16,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: zen.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.devices_rounded,
                            size: 46, color: accentColor),
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
                      ZenGlassButton(
                        label: context.tr('btn_add_device'),
                        icon: Icons.add_rounded,
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
                    final bool isMapped =
                        dev.pin >= 0 && dev.id.trim().isNotEmpty;

                    return ZenGlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      isActive: isMapped,
                      blurSigma: 12,
                      onTap: () =>
                          _showDeviceBottomSheet(editDevice: dev, index: index),
                      child: Row(
                        children: [
                          // Squircle Glass Icon Container
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  zen.primary.withOpacity(isDark ? 0.24 : 0.16),
                                  zen.primaryLight
                                      .withOpacity(isDark ? 0.10 : 0.06),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: accentColor.withOpacity(0.32)),
                            ),
                            child: Icon(
                              _getIconData(dev.icon),
                              size: 26,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Device Details & Glass Pills
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    // Room Glass Pill
                                    ZenGlassPill(
                                      blurSigma: 0,
                                      borderRadius: 10,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.meeting_room_outlined,
                                              size: 11, color: mutedColor),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              context.tr(dev.room),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: mutedColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // GPIO Pin Glass Pill
                                    ZenGlassPill(
                                      blurSigma: 0,
                                      isSelected: true,
                                      glowColor: zen.primary,
                                      borderRadius: 10,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      child: Text(
                                        dev.pin <= 7
                                            ? 'P${dev.pin} (I2C)'
                                            : 'GPIO ${dev.pin}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: accentColor,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),

                                    // ID Glass Pill
                                    ZenGlassPill(
                                      blurSigma: 0,
                                      borderRadius: 10,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      child: Text(
                                        dev.id,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

                          const SizedBox(width: 6),

                          // Edit Glass IconButton
                          ZenGlassIconButton(
                            blurSigma: 0,
                            size: 38,
                            iconSize: 18,
                            borderRadius: 12,
                            icon: Icons.edit_rounded,
                            iconColor: accentColor,
                            tooltip: context.tr('edit_device_title'),
                            onTap: () => _showDeviceBottomSheet(
                                editDevice: dev, index: index),
                          ),
                          const SizedBox(width: 6),

                          // Delete Glass IconButton
                          ZenGlassIconButton(
                            blurSigma: 0,
                            size: 38,
                            iconSize: 18,
                            borderRadius: 12,
                            icon: Icons.delete_outline_rounded,
                            iconColor: zen.danger,
                            glowColor: zen.danger,
                            tooltip: context.tr('btn_delete'),
                            onTap: () => _showDeleteConfirmDialog(index),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }
}
