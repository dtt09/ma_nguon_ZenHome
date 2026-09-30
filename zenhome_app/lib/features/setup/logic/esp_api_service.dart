import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:zenhome_app/core/models/smart_config.dart';

class EspApiService {
  static String get espIp => dotenv.env['ESP_IP'] ?? 'http://192.168.4.1';

  static Future<bool> sendConfigToESP({
    required String wifiSsid,
    required String wifiPass,
    required String adminPass,
    required SmartConfig config,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'wifi_ssid': wifiSsid,
        'wifi_pass': wifiPass,
        'admin_pass': adminPass,
        'mqtt_prefix': config.mqttPrefix,
        'mqtt_server': config.mqttServer, 
        if (config.mqttUser != null && config.mqttUser!.isNotEmpty) 'mqtt_user': config.mqttUser,
        if (config.mqttPass != null && config.mqttPass!.isNotEmpty) 'mqtt_pass': config.mqttPass,
        'devices': config.devices.map((e) => e.toJson()).toList(),
      };
      
      final response = await http.post(
        Uri.parse('$espIp/api/config'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> pingESP() async {
    try {
      final response = await http.get(Uri.parse('$espIp/ping')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['macAddress'] != null && data['macAddress'].toString().isNotEmpty) {
            return data['macAddress'];
          }
        } catch (e) {}
        return "unknown_mac_fallback";
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}