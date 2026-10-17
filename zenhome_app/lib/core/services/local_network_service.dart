import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/core/services/logger_service.dart';

/// Dịch vụ quản lý tìm kiếm và điều khiển thiết bị ESP32 trực tiếp qua mạng cục bộ (LAN / Wi-Fi)
class LocalNetworkService {
  static final LocalNetworkService _instance = LocalNetworkService._internal();
  factory LocalNetworkService() => _instance;
  LocalNetworkService._internal();

  static const int udpDiscoveryPort = 4210;
  static const int hubHttpPort = 80;

  String? _cachedHubIp;
  bool _isLocalAvailable = false;
  Timer? _monitoringTimer;
  String? _monitoredMac;
  bool _isChecking = false;

  final _localAvailableController = StreamController<bool>.broadcast();
  final _hubIpController = StreamController<String?>.broadcast();
  final _localTempController = StreamController<String?>.broadcast();
  final _localDeviceStateController = StreamController<Map<String, bool>>.broadcast();

  Stream<bool> get localAvailableStream => _localAvailableController.stream;
  Stream<String?> get hubIpStream => _hubIpController.stream;
  Stream<String?> get localTempStream => _localTempController.stream;
  Stream<Map<String, bool>> get localDeviceStateStream => _localDeviceStateController.stream;

  String? get cachedHubIp => _cachedHubIp;
  bool get isLocalAvailable => _isLocalAvailable;

  /// Bắt đầu giám sát kết nối mạng cục bộ với Hub
  void startMonitoring({required String targetMac}) {
    if (targetMac.isEmpty || targetMac == 'unknown_mac' || targetMac == 'unknown') {
      _setLocalAvailable(false);
      return;
    }

    _monitoredMac = _cleanMac(targetMac);
    _monitoringTimer?.cancel();

    // Tải IP lưu trong cache và thử ping ngay
    _loadCachedIpAndCheck();

    // Định kỳ ping/tìm kiếm mỗi 6 giây
    _monitoringTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      checkConnectivity();
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _setLocalAvailable(false);
  }

  String _cleanMac(String mac) {
    return mac.replaceAll(':', '').replaceAll('-', '').trim().toUpperCase();
  }

  Future<void> _loadCachedIpAndCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_ip_${_monitoredMac ?? "default"}';
      final savedIp = prefs.getString(key);
      if (savedIp != null && savedIp.isNotEmpty) {
        _cachedHubIp = savedIp;
        _hubIpController.add(_cachedHubIp);
        final bool isAlive = await pingHub(savedIp);
        if (isAlive) {
          _setLocalAvailable(true);
          fetchAndSyncLocalStatus(savedIp);
          return;
        }
      }
    } catch (e) {
      debugPrint('[LocalNet] Lỗi tải cache IP: $e');
    }

    // Nếu IP cũ không phản hồi, thử phát hiện mới bằng UDP
    await discoverHub();
  }

  /// Kiểm tra định kỳ xem kết nối cục bộ còn hoạt động không
  Future<void> checkConnectivity() async {
    if (_isChecking) return;
    if (_monitoredMac == null || _monitoredMac!.isEmpty) return;
    _isChecking = true;

    try {
      if (_cachedHubIp != null && _cachedHubIp!.isNotEmpty) {
        final isAlive = await pingHub(_cachedHubIp!);
        if (isAlive) {
          _setLocalAvailable(true);
          await fetchAndSyncLocalStatus(_cachedHubIp!);
          _isChecking = false;
          return;
        }
      }

      // Nếu ping thất bại hoặc chưa có IP, chạy tìm kiếm UDP
      final discoveredIp = await discoverHub();
      if (discoveredIp != null) {
        _setLocalAvailable(true);
        await fetchAndSyncLocalStatus(discoveredIp);
      } else {
        _setLocalAvailable(false);
      }
    } catch (_) {
      _setLocalAvailable(false);
    } finally {
      _isChecking = false;
    }
  }

  void _setLocalAvailable(bool available) {
    if (_isLocalAvailable != available) {
      _isLocalAvailable = available;
      _localAvailableController.add(available);
      LoggerService.i(available
          ? '[LocalNet] Đã kết nối mạng LAN với Hub ($_cachedHubIp)!'
          : '[LocalNet] Mất kết nối mạng LAN với Hub.');
    }
  }

  /// Gửi gói tin UDP Broadcast tìm kiếm ESP32 trong mạng nội bộ
  Future<String?> discoverHub({Duration timeout = const Duration(milliseconds: 1800)}) async {
    RawDatagramSocket? socket;
    final completer = Completer<String?>();

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Gửi bản tin Discovery
      final message = utf8.encode('ZENHOME_DISCOVER');
      socket.send(message, InternetAddress('255.255.255.255'), udpDiscoveryPort);

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final payload = utf8.decode(datagram.data);
              final json = jsonDecode(payload);

              if (json is Map<String, dynamic> && json['service'] == 'zenhome_hub') {
                final receivedMac = _cleanMac(json['macAddress'] ?? '');
                final receivedIp = json['ip'] ?? datagram.address.address;

                // Khớp MAC address nếu có thiết lập
                if (_monitoredMac == null || _monitoredMac!.isEmpty || receivedMac == _monitoredMac) {
                  _cachedHubIp = receivedIp.toString();
                  _hubIpController.add(_cachedHubIp);
                  _saveCachedIp(_cachedHubIp!);

                  if (!completer.isCompleted) {
                    completer.complete(_cachedHubIp);
                  }
                }
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      debugPrint('[LocalNet] Lỗi tạo socket UDP Discovery: $e');
      if (!completer.isCompleted) completer.complete(null);
    }

    final result = await completer.future;
    socket?.close();
    return result;
  }

  Future<void> _saveCachedIp(String ip) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_ip_${_monitoredMac ?? "default"}';
      await prefs.setString(key, ip);
    } catch (_) {}
  }

  /// Gửi kiểm tra Ping nhanh đến Hub
  Future<bool> pingHub(String ip) async {
    try {
      final uri = Uri.parse('http://$ip/ping');
      final res = await http.get(uri).timeout(const Duration(milliseconds: 1200));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'ok') {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Điều khiển Relay trực tiếp qua mạng LAN (HTTP POST /api/control)
  /// Trả về true nếu thành công trong vòng vài mili-giây
  Future<bool> sendLocalControl({required String devId, required String cmd}) async {
    if (_cachedHubIp == null || !_isLocalAvailable) return false;

    try {
      final uri = Uri.parse('http://$_cachedHubIp/api/control');
      final body = jsonEncode({
        'id': devId,
        'cmd': cmd,
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(milliseconds: 2000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'ok') {
          final String stateStr = data['state'] ?? cmd;
          _localDeviceStateController.add({devId: stateStr == '1'});
          return true;
        }
      }
    } catch (e) {
      LoggerService.w('[LocalNet] Gửi lệnh cục bộ thất bại: $e');
    }
    return false;
  }

  /// Lấy toàn bộ trạng thái thiết bị và cảm biến qua mạng LAN
  Future<Map<String, dynamic>?> fetchAndSyncLocalStatus(String ip) async {
    try {
      final uri = Uri.parse('http://$ip/api/status');
      final res = await http.get(uri).timeout(const Duration(milliseconds: 2000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // Cập nhật nhiệt độ phòng nếu có
        if (data.containsKey('temp')) {
          final tempVal = data['temp']?.toString();
          if (tempVal != null && tempVal != '--') {
            _localTempController.add(tempVal);
          }
        }

        // Cập nhật trạng thái các relay
        if (data.containsKey('devices') && data['devices'] is List) {
          final Map<String, bool> states = {};
          for (var d in (data['devices'] as List)) {
            if (d is Map && d.containsKey('id') && d.containsKey('state')) {
              states[d['id'].toString()] = d['state'].toString() == '1';
            }
          }
          if (states.isNotEmpty) {
            _localDeviceStateController.add(states);
          }
        }

        return data;
      }
    } catch (e) {
      debugPrint('[LocalNet] Lỗi tải trạng thái local: $e');
    }
    return null;
  }

  void dispose() {
    stopMonitoring();
    _localAvailableController.close();
    _hubIpController.close();
    _localTempController.close();
    _localDeviceStateController.close();
  }
}
