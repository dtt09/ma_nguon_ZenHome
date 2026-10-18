import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  static final BigInt _dhPrime = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1'
    '29024E088A67CC74020BBEA63B139B22514A08798E3404DD'
    'EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245'
    'E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381'
    'FFFFFFFFFFFFFFFF',
    radix: 16,
  );
  static final BigInt _dhGenerator = BigInt.from(2);
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _inMemoryLocalKey;

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
  Future<String?> discoverHub({
    Duration timeout = const Duration(milliseconds: 1800),
    bool force = false,
  }) async {
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

  String _generateRandomNonce(int byteLength) {
    final rng = Random.secure();
    return List.generate(byteLength, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Trao đổi và đồng bộ khóa bảo mật Zero-Knowledge giữa App và ESP32
  /// Cơ chế: Diffie-Hellman 1536-bit (RFC 3526 MODP Group 5)
  /// Không ai biết khóa này, kể cả Server và quản trị viên ZenHome.
  Future<String?> getOrNegotiateLocalKey({
    required String hubIp,
    required String mac,
    bool forceRefresh = false,
  }) async {
    final cleanMac = _cleanMac(mac);
    final storageKey = 'local_sec_key_$cleanMac';

    if (!forceRefresh) {
      if (_inMemoryLocalKey != null && _inMemoryLocalKey!.isNotEmpty) {
        return _inMemoryLocalKey;
      }
      try {
        final saved = await _secureStorage.read(key: storageKey);
        if (saved != null && saved.isNotEmpty) {
          _inMemoryLocalKey = saved;
          return saved;
        }
      } catch (_) {}
    }

    // Tiến hành trao đổi khóa tự động theo giao thức Zero-Knowledge Diffie-Hellman
    try {
      final rng = Random.secure();
      final privateBytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        privateBytes[i] = rng.nextInt(256);
      }
      final a = BigInt.parse(
        privateBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );

      // Tính khóa công khai A = g^a mod p
      final A = _dhGenerator.modPow(a, _dhPrime);
      final aHex = A.toRadixString(16).toLowerCase();

      final exchangeUri = Uri.parse('http://$hubIp/api/auth/key-exchange');
      final res = await http.post(
        exchangeUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'clientPublicKey': aHex,
          'mac': cleanMac,
        }),
      ).timeout(const Duration(milliseconds: 3000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'ok' && data['serverPublicKey'] != null) {
          final bHex = (data['serverPublicKey'] as String).toLowerCase();
          final proof = (data['proof'] as String?)?.toLowerCase();
          final B = BigInt.parse(bHex, radix: 16);

          // Tính khóa chia sẻ chung S = B^a mod p
          final S = B.modPow(a, _dhPrime);
          var sHex = S.toRadixString(16).toLowerCase();
          if (sHex.length % 2 != 0) sHex = '0$sHex';

          final sBytes = <int>[];
          for (int i = 0; i < sHex.length; i += 2) {
            sBytes.add(int.parse(sHex.substring(i, i + 2), radix: 16));
          }
          final derivedKey = sha256.convert(sBytes).toString().toLowerCase();

          // Xác thực Proof = HMAC(K, clientPub + ":" + serverPub)
          final keyBytes = <int>[];
          for (int i = 0; i < derivedKey.length; i += 2) {
            keyBytes.add(int.parse(derivedKey.substring(i, i + 2), radix: 16));
          }
          final expectedProof = Hmac(sha256, keyBytes)
              .convert(utf8.encode('$aHex:$bHex'))
              .toString()
              .toLowerCase();

          if (proof != null && proof == expectedProof) {
            _inMemoryLocalKey = derivedKey;
            await _secureStorage.write(key: storageKey, value: derivedKey);
            LoggerService.i('[LocalSec] 🔐 Đã tự động trao đổi & đồng bộ khóa Zero-Knowledge với Hub ($mac) thành công!');
            return derivedKey;
          } else {
            LoggerService.w('[LocalSec] ❌ Xác thực Proof chữ ký trao đổi khóa thất bại!');
          }
        }
      }
    } catch (e) {
      LoggerService.w('[LocalSec] Lỗi trao đổi khóa Zero-Knowledge với Hub: $e');
    }
    return null;
  }

  /// Điều khiển Relay trực tiếp qua mạng LAN (HTTP POST /api/control)
  /// Tự động xác thực chữ ký HMAC-SHA256 theo chuẩn bảo mật Zero-Knowledge
  Future<bool> sendLocalControl({required String devId, required String cmd}) async {
    if (_cachedHubIp == null || !_isLocalAvailable) return false;

    try {
      final uri = Uri.parse('http://$_cachedHubIp/api/control');
      final body = jsonEncode({
        'id': devId,
        'cmd': cmd,
      });

      // Lấy hoặc tự động trao đổi khóa bảo mật với ESP32
      String? localKey;
      if (_monitoredMac != null && _monitoredMac!.isNotEmpty) {
        localKey = await getOrNegotiateLocalKey(hubIp: _cachedHubIp!, mac: _monitoredMac!);
      }

      Map<String, String> headers = {'Content-Type': 'application/json'};

      if (localKey != null && localKey.isNotEmpty) {
        final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final nonce = _generateRandomNonce(8);
        final signPayload = '$devId:$cmd:$timestamp:$nonce';
        final keyBytes = <int>[];
        for (int i = 0; i < localKey.length; i += 2) {
          keyBytes.add(int.parse(localKey.substring(i, i + 2), radix: 16));
        }
        final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

        headers['X-ZenHome-Signature'] = signature;
        headers['X-ZenHome-Timestamp'] = timestamp;
        headers['X-ZenHome-Nonce'] = nonce;
      }

      var res = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(milliseconds: 2000));

      // Nếu bị từ chối 401 (khóa lệch hoặc ESP32 mới nạp lại), tự động tái trao đổi khóa 1 lần
      if (res.statusCode == 401 && _monitoredMac != null) {
        LoggerService.w('[LocalSec] ⚠️ Khóa bảo mật bị từ chối (401). Đang tự động tái đồng bộ khóa mới...');
        localKey = await getOrNegotiateLocalKey(hubIp: _cachedHubIp!, mac: _monitoredMac!, forceRefresh: true);
        if (localKey != null && localKey.isNotEmpty) {
          final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
          final nonce = _generateRandomNonce(8);
          final signPayload = '$devId:$cmd:$timestamp:$nonce';
          final keyBytes = <int>[];
          for (int i = 0; i < localKey.length; i += 2) {
            keyBytes.add(int.parse(localKey.substring(i, i + 2), radix: 16));
          }
          final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

          headers['X-ZenHome-Signature'] = signature;
          headers['X-ZenHome-Timestamp'] = timestamp;
          headers['X-ZenHome-Nonce'] = nonce;

          res = await http.post(
            uri,
            headers: headers,
            body: body,
          ).timeout(const Duration(milliseconds: 2000));
        }
      }

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
