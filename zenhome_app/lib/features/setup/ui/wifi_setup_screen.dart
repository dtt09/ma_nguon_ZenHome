import 'dart:io';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zenhome_app/features/setup/logic/esp_api_service.dart';
import 'package:zenhome_app/core/utils/helpers.dart';
import 'package:zenhome_app/core/utils/constants.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/features/admin/ui/device_mapping_screen.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zenhome_app/features/home/logic/home_config_provider.dart';
import 'dart:math';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart' hide MqttConnectionState;
import 'package:mqtt_client/mqtt_client.dart';

class WifiSetupScreen extends ConsumerStatefulWidget {
  const WifiSetupScreen({super.key});

  @override
  ConsumerState<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends ConsumerState<WifiSetupScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _adminPassController = TextEditingController();
  final TextEditingController _confirmAdminPassController = TextEditingController();
  
  // Nạp sẵn cái địa chỉ MQTT đang lưu vào ô nhập
  final TextEditingController _mqttServerController = TextEditingController(); 
  final TextEditingController _mqttUserController = TextEditingController();
  final TextEditingController _mqttPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscureWifiPass = true; 
  bool _obscureAdminPass = true;
  bool _obscureConfirmPass = true;


  @override
  void dispose() {
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    _ssidController.dispose();
    _passController.dispose();
    _adminPassController.dispose();
    _confirmAdminPassController.dispose();
    _mqttServerController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _setupStepNotifier.dispose();
    _setupErrorNotifier.dispose();
    super.dispose();
  }

  String _generateRandomToken(int length) {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  final ValueNotifier<String> _setupStepNotifier = ValueNotifier('');
  final ValueNotifier<bool> _setupErrorNotifier = ValueNotifier(false);

  void _showSetupLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: ValueListenableBuilder<bool>(
                valueListenable: _setupErrorNotifier,
                builder: (context, isError, child) {
                  return ValueListenableBuilder<String>(
                    valueListenable: _setupStepNotifier,
                    builder: (context, stepMsg, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isError)
                             CircularProgressIndicator(color: isDark ? const Color(0xFF5C8CFF) : const Color(0xFF2A3A7C)),
                          if (isError)
                             const Icon(Icons.error_outline, color: Colors.red, size: 50),
                          const SizedBox(height: 25),
                          Text(
                            stepMsg,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold, 
                              color: isError ? Colors.red : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          if (isError) ...[
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white),
                              onPressed: () {
                                Navigator.pop(ctx);
                                setState(() => _isLoading = false);
                              },
                              child: Text(context.tr('btn_close') ?? 'Đóng'),
                            )
                          ]
                        ],
                      );
                    },
                  );
                }
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
    }
    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    _mqttServerController.text = activeConfig.mqttServer.isEmpty || activeConfig.mqttServer == 'broker.emqx.io' 
        ? (dotenv.env['DEFAULT_MQTT_SERVER'] ?? 'broker.emqx.io')
        : activeConfig.mqttServer;
  }

  void _sendSetupData() async {
    if (_ssidController.text.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_wifi_empty'), isError: true);
      return;
    }
    if (_adminPassController.text.isEmpty) {
      showFloatingToast(context, context.tr('error'), context.tr('err_empty_admin_pass') ?? 'Vui lòng nhập Mật khẩu quản trị', isError: true);
      return;
    }
    if (_adminPassController.text != _confirmAdminPassController.text) {
      showFloatingToast(context, context.tr('error'), context.tr('err_pass_mismatch'), isError: true);
      return;
    }

    setState(() => _isLoading = true);
    _setupErrorNotifier.value = false;
    _setupStepNotifier.value = context.tr('step_check_esp_connection') ?? 'Đang kiểm tra kết nối với ESP32...';
    _showSetupLoadingDialog();
    
    // Kiểm tra xem điện thoại đã kết nối WiFi của ESP32 chưa
    String? espMac = await EspApiService.pingESP();
    if (espMac == null) {
      _setupErrorNotifier.value = true;
      _setupStepNotifier.value = context.tr('step_esp_unreachable') ?? 'Không thể kết nối đến ESP32. Vui lòng kết nối vào WiFi "ZenHome_Setup_...".';
      return;
    }

    final activeConfig = ref.read(homeConfigProvider).activeConfig;
    
    if (espMac == "unknown_mac_fallback" || espMac.isEmpty) {
      espMac = 'ESP_${DateTime.now().millisecondsSinceEpoch}';
    }
    activeConfig.macAddress = espMac;

    String serverInput = _mqttServerController.text.trim();
    // Tự động thêm đuôi nếu người dùng chỉ nhập mỗi chuỗi mã cluster của HiveMQ Cloud
    if (serverInput.isNotEmpty && !serverInput.contains('.')) {
      serverInput = '$serverInput.s1.eu.hivemq.cloud';
    }
    activeConfig.mqttServer = serverInput;
    activeConfig.mqttUser = _mqttUserController.text.trim();
    activeConfig.mqttPass = _mqttPassController.text.trim();
    
    activeConfig.adminPass = _adminPassController.text;
    await ref.read(homeConfigProvider).saveConfigToStorage(activeConfig);

    _setupStepNotifier.value = context.tr('step_sending_config') ?? 'Đang truyền cấu hình xuống thiết bị...';
    bool isSuccess = await EspApiService.sendConfigToESP(
      wifiSsid: _ssidController.text.trim(),
      wifiPass: _passController.text.trim(),
      adminPass: activeConfig.adminPass, // Lấy từ não truyền xuống ESP
      config: activeConfig, 
    );

    if (!isSuccess) {
      _setupErrorNotifier.value = true;
      _setupStepNotifier.value = context.tr('step_config_failed') ?? 'Lỗi truyền cấu hình. Vui lòng thử lại.';
      return;
    }

    _setupStepNotifier.value = context.tr('step_waiting_reboot') ?? 'Đang đợi thiết bị khởi động và kết nối mạng (có thể mất 1-2 phút)...';
    
    // Connect app to MQTT to verify
    final mqttRepo = ref.read(mqttRepositoryProvider);
    
    // NGẮT KẾT NỐI CŨ ĐỂ ÉP KẾT NỐI LẠI VỚI PREFIX MỚI (CHỨA MAC ADDRESS MỚI)
    mqttRepo.disconnect();

    bool isEspOnline = false;
    final sub = mqttRepo.espOnlineStream.listen((online) {
       if (online) isEspOnline = true;
    });

    int waitLoops = 0;
    int lastConnectAttempt = -10; // Đảm bảo kết nối ngay ở giây đầu tiên

    while (!isEspOnline && waitLoops < 120) {
       // Thử kết nối lại mỗi 10 giây nếu điện thoại bị rớt mạng tạm thời do đổi WiFi
       if (waitLoops - lastConnectAttempt >= 10) {
         final mqttState = mqttRepo.client?.connectionStatus?.state;
         if (mqttState != MqttConnectionState.connected && mqttState != MqttConnectionState.connecting) {
           lastConnectAttempt = waitLoops;
           mqttRepo.disconnect();
           // Không await để không block vòng lặp, chạy ngầm tự retry
           mqttRepo.connect(
             userId: activeConfig.userId,
             mqttServer: activeConfig.mqttServer,
             mqttPrefix: activeConfig.mqttPrefix,
             dynamicTopics: getDynamicDeviceTopicsList(activeConfig),
             mqttUser: activeConfig.mqttUser,
             mqttPass: activeConfig.mqttPass
           );
         }
       }
       
       // Thêm logic: Nếu MQTT đã connected nhưng sau 30s chưa thấy ESP online, 
       // có thể gửi 1 dummy message để nhử ESP trả lời (nếu ESP hỗ trợ)
       // Ở đây ta cứ ráng chờ, vì có thể do mạng chậm.
       
       await Future.delayed(const Duration(seconds: 1));
       waitLoops++;
    }

    sub.cancel();

    if (!isEspOnline) {
       _setupErrorNotifier.value = true;
       _setupStepNotifier.value = context.tr('step_setup_failed') ?? 'Sai mật khẩu WiFi hoặc không kết nối được MQTT. Vui lòng nhấn giữ nút BOOT trên thiết bị trong 5s để reset và thử lại.';
       return;
    }

    // ĐỒNG BỘ NGAY LÊN FIREBASE ĐỂ THÀNH VIÊN KHÔNG BỊ SAI BROKER
    try {
      if (activeConfig.userId != 'guest' && activeConfig.userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(activeConfig.userId).set({
          'mqttServer': activeConfig.mqttServer,
          'mqttUser': activeConfig.mqttUser,
          'mqttPass': activeConfig.mqttPass,
          'macAddress': activeConfig.macAddress,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print("Lỗi đồng bộ Firebase sau khi setup Wifi: $e");
    }
    
    if (mounted) {
      Navigator.pop(context); // Đóng dialog
      showFloatingToast(context, context.tr('toast_success'), context.tr('msg_pump_success'));
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => DeviceMappingScreen()) 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121827) : Colors.white,
      appBar: AppBar(
        title: Text(context.tr('wifi_setup_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade300)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(child: Text(context.tr('wifi_setup_desc'), style: const TextStyle(height: 1.5)))
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            Text(context.tr('wifi_ssid'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _ssidController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.wifi), 
                hintText: context.tr('wifi_ssid_hint'), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(context.tr('wifi_pass'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _passController,
              obscureText: _obscureWifiPass,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.password),
                suffixIcon: IconButton(icon: Icon(_obscureWifiPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureWifiPass = !_obscureWifiPass)),
                hintText: context.tr('wifi_pass_hint'), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(context.tr('admin_pass_opt'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _adminPassController,
              obscureText: _obscureAdminPass,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.admin_panel_settings),
                suffixIcon: IconButton(icon: Icon(_obscureAdminPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureAdminPass = !_obscureAdminPass)),
                hintText: context.tr('admin_pass_hint'), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),

            Text(context.tr('confirm_admin_pass'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmAdminPassController,
              obscureText: _obscureConfirmPass,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                suffixIcon: IconButton(icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass)),
                hintText: context.tr('confirm_admin_pass_hint'), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),

            Text(context.tr('mqtt_server_address'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _mqttServerController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.cloud_sync),
                hintText: context.tr('mqtt_server_hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),

            Text(context.tr('mqtt_user'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _mqttUserController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person),
                hintText: context.tr('mqtt_user_hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            const SizedBox(height: 20),

            Text(context.tr('mqtt_pass'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _mqttPassController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.password),
                hintText: context.tr('mqtt_pass_hint'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              ),
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A3A7C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _isLoading ? null : _sendSetupData,
                child: _isLoading ? LogoLoadingIndicator(color: Colors.white, size: 24) : Text(context.tr('btn_pump_config'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}