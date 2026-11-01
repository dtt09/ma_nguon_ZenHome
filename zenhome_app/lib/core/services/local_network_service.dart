import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/core/services/logger_service.dart';
import 'package:zenhome_app/core/services/ble_local_service.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/services/zenhome_crypto.dart';

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
  bool _isLanAvailable = false;
  Timer? _monitoringTimer;
  String? _monitoredMac;
  String? _currentUserId;
  String? _currentUserRole;
  List<String>? _allowedDevices;
  bool _isDisabled = false;
  bool _isChecking = false;
  String? _cachedAdminPass;
  StreamSubscription? _bleStateSub;
  StreamSubscription? _bleAvailSub;
  Map<String, bool> _lastKnownStates = {};
  String? _lastKnownTemp;

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

  /// Bắt đầu giám sát kết nối mạng cục bộ với Hub kèm thông tin phân quyền tài khoản
  void startMonitoring({
    required String targetMac,
    String? adminPass,
    String? userId,
    String? role,
    bool isDisabled = false,
    List<String>? allowedDevices,
  }) {
    _cachedAdminPass = adminPass;
    _currentUserId = userId;
    _currentUserRole = role ?? 'owner';
    _isDisabled = isDisabled;
    _allowedDevices = allowedDevices;

    if (targetMac.isEmpty || targetMac == 'unknown_mac' || targetMac == 'unknown') {
      _setLocalAvailable(false);
      return;
    }

    _monitoredMac = _cleanMac(targetMac);
    _monitoringTimer?.cancel();

    // Khởi chạy đồng thời kết nối ngầm qua Bluetooth Low Energy (BLE) Zero-Touch kèm Key bảo mật và Phân quyền
    BleLocalService().start(
      targetMac: targetMac,
      adminPass: adminPass,
      userId: userId,
      role: role,
      allowedDevices: allowedDevices,
    );
    _bleStateSub?.cancel();
    _bleStateSub = BleLocalService().bleDeviceStateStream.listen((state) {
      if (!mapEquals(_lastKnownStates, state)) {
        _lastKnownStates = {..._lastKnownStates, ...state};
        _localDeviceStateController.add(_lastKnownStates);
      }
    });
    _bleAvailSub?.cancel();
    _bleAvailSub = BleLocalService().bleAvailableStream.listen((_) {
      _setLocalAvailable(_isLanAvailable);
    });

    // Tải IP lưu trong cache và thử ping ngay
    _loadCachedIpAndCheck();

    // Giám sát thích ứng (Adaptive Polling): 16s khi mạng ổn định, 6s khi đang tìm kiếm
    _scheduleNextCheck(6);
  }

  void _scheduleNextCheck([int delaySeconds = 6]) {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer(Duration(seconds: delaySeconds), () async {
      await checkConnectivity();
      if (_monitoringTimer != null) {
        final nextDelay = _isLanAvailable ? 16 : 6;
        _scheduleNextCheck(nextDelay);
      }
    });
  }

  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _bleStateSub?.cancel();
    _bleStateSub = null;
    _bleAvailSub?.cancel();
    _bleAvailSub = null;
    _inMemoryLocalKey = null;
    _lastKnownStates.clear();
    _lastKnownTemp = null;
    BleLocalService().stop();
    _setLocalAvailable(false);
  }

  /// Thông báo cho Server biết Hub đã bị reset / unlinked từ phía phần cứng (Có xác thực Firebase Token)
  Future<void> _notifyHubResetToServer(String mac) async {
    if (mac.isEmpty || mac == 'unknown_mac' || mac == 'unknown') return;
    try {
      final clean = _cleanMac(mac);
      final baseUrl = await AppUpdateService.getLiveServerBaseUrl() ?? AppUpdateService.fallbackServerUrl;
      final uri = Uri.parse('$baseUrl/api/v1/hub/notify-reset');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'macAddress': clean}),
      ).timeout(const Duration(seconds: 4));
      LoggerService.i('[LocalNet] ⚡ Đã báo Server hủy liên kết Hub [$clean] do Hub đã reset!');
    } catch (e) {
      debugPrint('[LocalNet] Lỗi gửi thông báo reset Hub: $e');
    }
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

  void _setLocalAvailable(bool lanAvailable) {
    _isLanAvailable = lanAvailable;
    // Báo cho BLE Service biết trạng thái LAN để tạm dừng quét BLE vô ích khi mạng LAN hoạt động tốt
    BleLocalService().setNetworkOnlineStatus(isLanAvailable: lanAvailable);

    // Khả dụng cục bộ khi: hoặc mạng LAN ping thành công, hoặc BLE Hub sẵn sàng kết nối theo yêu cầu (Connect-on-Demand)
    final effectiveAvailable = lanAvailable || BleLocalService().isHubNearby || BleLocalService().isAuthenticated;
    if (_isLocalAvailable != effectiveAvailable) {
      _isLocalAvailable = effectiveAvailable;
      _localAvailableController.add(effectiveAvailable);
      LoggerService.i(effectiveAvailable
          ? '[LocalNet] Đã kết nối cục bộ an toàn với Hub (LAN: $_cachedHubIp, BLE Sẵn sàng: ${BleLocalService().isHubNearby})!'
          : '[LocalNet] Mất toàn bộ kết nối cục bộ (cả LAN & BLE).');
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

      // Gửi bản tin Discovery an toàn (bảo vệ chống ngoại lệ Network is unreachable / Operation not permitted trên Android)
      final message = utf8.encode('ZENHOME_DISCOVER');
      try {
        socket.send(message, InternetAddress('255.255.255.255'), udpDiscoveryPort);
      } catch (sendErr) {
        debugPrint('[LocalNet] ℹ️ Không thể phát sóng UDP (máy không kết nối Wi-Fi hoặc hạn chế quyền OS): $sendErr');
        if (!completer.isCompleted) completer.complete(null);
        socket.close();
        return null;
      }

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      socket.listen(
        (RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            final datagram = socket?.receive();
            if (datagram != null) {
              try {
                final payload = utf8.decode(datagram.data);
                final json = jsonDecode(payload);

                if (json is Map<String, dynamic> && json['service'] == 'zenhome_hub') {
                  if (json['unlinked'] == true || json['mode'] == 'unlinked') {
                    LoggerService.w('[LocalNet] ⚠️ Gói tin UDP Discovery phát hiện Hub ở trạng thái unlinked!');
                    _notifyHubResetToServer(json['macAddress']?.toString() ?? '');
                    return;
                  }
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
        },
        onError: (socketErr) {
          debugPrint('[LocalNet] ℹ️ Luồng UDP Socket gặp lỗi ngắt kết nối (đã xử lý an toàn): $socketErr');
          if (!completer.isCompleted) completer.complete(null);
        },
        cancelOnError: true,
      );
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
        if (data is Map) {
          if (data['unlinked'] == true || data['status'] == 'unlinked' || data['mode'] == 'unlinked' || data['reset'] == true) {
            LoggerService.w('[LocalNet] ⚠️ Hub đang ở trạng thái CHƯA LIÊN KẾT / FACTORY RESET!');
            _notifyHubResetToServer(_monitoredMac ?? data['macAddress']?.toString() ?? '');
            _setLocalAvailable(false);
            return false;
          }
          if (data['status'] == 'ok') {
            return true;
          }
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
    String? adminPass,
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
      final effectiveAdmin = adminPass ?? _cachedAdminPass;
      final bodyMap = <String, dynamic>{
        'clientPublicKey': aHex,
        'mac': cleanMac,
      };
      if (effectiveAdmin != null && effectiveAdmin.isNotEmpty) {
        bodyMap['adminPass'] = effectiveAdmin;
      }
      final res = await http.post(
        exchangeUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyMap),
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

  /// Điều khiển Relay trực tiếp qua mạng nội bộ (LAN HTTP hoặc BLE GATT Zero-Touch)
  /// Tự động xác thực chữ ký HMAC-SHA256 theo chuẩn bảo mật Zero-Knowledge và Phân quyền RBAC
  Future<bool> sendLocalControl({required String devId, required String cmd}) async {
    // 0. Kiểm tra phân quyền thành viên (RBAC)
    if (_isDisabled || _currentUserRole == 'disabled') {
      LoggerService.w('[LocalNet-RBAC] 🚫 Tài khoản đang bị Chủ nhà tạm khóa quyền điều khiển!');
      return false;
    }
    if (_currentUserRole == 'member' && _allowedDevices != null && !_allowedDevices!.contains(devId)) {
      LoggerService.w('[LocalNet-RBAC] 🚫 Thành viên không có quyền điều khiển thiết bị $devId!');
      return false;
    }

    // 1. Thử gửi qua Wi-Fi LAN HTTP nếu có IP Hub được ghi nhận
    if (_cachedHubIp != null && _cachedHubIp!.isNotEmpty) {
      try {
        final uri = Uri.parse('http://$_cachedHubIp/api/control');
        final user = _currentUserId ?? 'owner';
        // Bảo vệ RBAC: Chỉ Chủ nhà (owner / co_owner) mới được gửi adminPass để tránh thành viên qua mặt phân quyền
        final effectiveAdmin = (_currentUserRole == 'owner' || _currentUserRole == 'co_owner') ? (_cachedAdminPass ?? 'admin') : '';
        final body = jsonEncode({
          'id': devId,
          'cmd': cmd,
          'user': user,
          if (effectiveAdmin.isNotEmpty) 'adminPass': effectiveAdmin,
        });

        // Lấy hoặc tự động trao đổi khóa bảo mật với ESP32
        String? localKey;
        if (_monitoredMac != null && _monitoredMac!.isNotEmpty) {
          localKey = await getOrNegotiateLocalKey(hubIp: _cachedHubIp!, mac: _monitoredMac!);
        }

        Map<String, String> headers = {
          'Content-Type': 'application/json',
          'X-ZenHome-User': user,
        };

        if (localKey != null && localKey.isNotEmpty) {
          final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
          final nonce = _generateRandomNonce(8);
          final signPayload = '$user:$devId:$cmd:$timestamp:$nonce';
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
        ).timeout(const Duration(milliseconds: 1000));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['status'] == 'ok') {
            final String stateStr = data['state'] ?? cmd;
            final bool isTurnOn = stateStr == '1';
            _lastKnownStates[devId] = isTurnOn;
            _localDeviceStateController.add(Map.from(_lastKnownStates));
            return true;
          }
        }
      } catch (e) {
        debugPrint('[LocalNet] Gửi qua Wi-Fi LAN HTTP không phản hồi: $e');
      }
    }

    // 2. Dự phòng tức thì qua BLE ngầm khi Router Wi-Fi mất nguồn / hỏng (Hỗ trợ Connect-on-Demand & Multi-user)
    try {
      String? localKey;
      if (_monitoredMac != null && _monitoredMac!.isNotEmpty) {
        localKey = await _secureStorage.read(key: 'local_sec_key_$_monitoredMac');
      }
      if (localKey == null || localKey.isEmpty) {
        localKey = BleLocalService.deriveMasterKey(mac: _monitoredMac!, adminPass: _cachedAdminPass);
      }
      final bleSuccess = await BleLocalService().sendControlCommand(
        devId: devId,
        cmd: cmd,
        localKey: localKey,
      );
      if (bleSuccess) {
        _lastKnownStates[devId] = cmd == '1';
        _localDeviceStateController.add(Map.from(_lastKnownStates));
        return true;
      }
    } catch (e) {
      LoggerService.w('[LocalNet] Dự phòng BLE thất bại: $e');
    }

    return false;
  }

  /// Đồng bộ danh sách phân quyền thành viên tới Hub qua mạng LAN (POST /api/members)
  Future<bool> syncMembersToHub(Map<String, dynamic> membersData) async {
    if (_cachedHubIp == null || _cachedHubIp!.isEmpty) return false;
    try {
      final uri = Uri.parse('http://$_cachedHubIp/api/members');
      final body = jsonEncode(membersData);

      String? localKey;
      if (_monitoredMac != null && _monitoredMac!.isNotEmpty) {
        localKey = await getOrNegotiateLocalKey(hubIp: _cachedHubIp!, mac: _monitoredMac!);
      }

      Map<String, String> headers = {'Content-Type': 'application/json'};

      if (localKey != null && localKey.isNotEmpty) {
        final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final nonce = _generateRandomNonce(8);
        final signPayload = 'members:$timestamp:$nonce';
        final keyBytes = <int>[];
        for (int i = 0; i < localKey.length; i += 2) {
          keyBytes.add(int.parse(localKey.substring(i, i + 2), radix: 16));
        }
        final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

        headers['X-ZenHome-Signature'] = signature;
        headers['X-ZenHome-Timestamp'] = timestamp;
        headers['X-ZenHome-Nonce'] = nonce;
      }

      final res = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(milliseconds: 2000));

      if (res.statusCode == 200) {
        LoggerService.i('[LocalNet] ✅ Đã đồng bộ phân quyền thành viên tới Hub qua LAN thành công!');
        return true;
      }
    } catch (e) {
      LoggerService.w('[LocalNet] Gửi đồng bộ members tới Hub thất bại: $e');
    }
    return false;
  }

  /// Gửi cấu hình Wi-Fi mới tới Hub trực tiếp qua LAN HTTP hoặc BLE Zero-Touch
  Future<bool> sendReconfigHub({
    required String newSsid,
    required String newWifiPass,
    String? newServer,
    String? newAdminPass,
  }) async {
    final effectiveAdmin = newAdminPass ?? _cachedAdminPass;

    // 1. Thử gửi qua Wi-Fi LAN HTTP nếu có IP Hub được ghi nhận
    if (_cachedHubIp != null && _cachedHubIp!.isNotEmpty) {
      try {
        final uri = Uri.parse('http://$_cachedHubIp/api/reconfig');
        final user = _currentUserId ?? 'owner';
        final body = jsonEncode({
          'wifi_ssid': newSsid,
          'wifi_pass': newWifiPass,
          if (newServer != null && newServer.isNotEmpty) 'mqtt_server': newServer,
          if (effectiveAdmin != null && effectiveAdmin.isNotEmpty) 'admin_pass': effectiveAdmin,
          'user': user,
        });

        String? localKey;
        if (_monitoredMac != null && _monitoredMac!.isNotEmpty) {
          localKey = await getOrNegotiateLocalKey(hubIp: _cachedHubIp!, mac: _monitoredMac!);
        }

        Map<String, String> headers = {
          'Content-Type': 'application/json',
          'X-ZenHome-User': user,
        };

        if (localKey != null && localKey.isNotEmpty) {
          final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
          final nonce = _generateRandomNonce(8);
          final signPayload = 'reconfig:$newSsid:$timestamp:$nonce';
          final keyBytes = <int>[];
          for (int i = 0; i < localKey.length; i += 2) {
            keyBytes.add(int.parse(localKey.substring(i, i + 2), radix: 16));
          }
          final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

          headers['X-ZenHome-Signature'] = signature;
          headers['X-ZenHome-Timestamp'] = timestamp;
          headers['X-ZenHome-Nonce'] = nonce;
        }

        final res = await http.post(
          uri,
          headers: headers,
          body: body,
        ).timeout(const Duration(milliseconds: 2500));

        if (res.statusCode == 200) {
          LoggerService.i('[LocalNet] 📡 Đã gửi cấu hình Wi-Fi mới thành công qua mạng LAN HTTP!');
          return true;
        }
      } catch (e) {
        LoggerService.w('[LocalNet] Gửi reconfig qua Wi-Fi LAN thất bại: $e. Thử fallback BLE...');
      }
    }

    // 2. Fallback sang BLE Zero-Touch (Kể cả khi Hub mất Wi-Fi hoàn toàn)
    try {
      String? localKey;
      if (_monitoredMac != null && _monitoredMac!.isNotEmpty) {
        localKey = await _secureStorage.read(key: 'local_sec_key_$_monitoredMac');
      }
      if (localKey == null || localKey.isEmpty) {
        localKey = BleLocalService.deriveMasterKey(mac: _monitoredMac!, adminPass: effectiveAdmin);
      }

      final bleSuccess = await BleLocalService().sendReconfigCommand(
        newSsid: newSsid,
        newWifiPass: newWifiPass,
        newServer: newServer,
        newAdminPass: effectiveAdmin,
        localKey: localKey,
      );
      if (bleSuccess) {
        LoggerService.i('[LocalNet] 📡 Đã gửi cấu hình Wi-Fi mới thành công qua BLE Zero-Touch!');
        return true;
      }
    } catch (e) {
      LoggerService.w('[LocalNet] Gửi reconfig qua BLE thất bại: $e');
    }

    return false;
  }

  /// Lấy toàn bộ trạng thái thiết bị và cảm biến qua mạng LAN (Truyền X-ZenHome-User để áp dụng RBAC)
  Future<Map<String, dynamic>?> fetchAndSyncLocalStatus(String ip) async {
    try {
      final uri = Uri.parse('http://$ip/api/status');
      final headers = <String, String>{};
      if (_currentUserId != null && _currentUserId!.isNotEmpty) {
        headers['X-ZenHome-User'] = _currentUserId!;
      }
      final res = await http.get(uri, headers: headers).timeout(const Duration(milliseconds: 2000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // Phát hiện nếu Hub đang ở chế độ unlinked / reset
        if (data['unlinked'] == true || data['status'] == 'unlinked' || data['mode'] == 'unlinked' || data['reset'] == true) {
          LoggerService.w('[LocalNet] ⚠️ Hub phản hồi trạng thái CHƯA LIÊN KẾT / FACTORY RESET!');
          _notifyHubResetToServer(_monitoredMac ?? data['macAddress']?.toString() ?? '');
          _setLocalAvailable(false);
          return null;
        }

        // Cập nhật nhiệt độ phòng nếu có thay đổi
        if (data.containsKey('temp')) {
          final tempVal = data['temp']?.toString();
          if (tempVal != null && tempVal != '--' && tempVal != _lastKnownTemp) {
            _lastKnownTemp = tempVal;
            _localTempController.add(tempVal);
          }
        }

        // Cập nhật trạng thái các relay (chỉ emit khi có sự thay đổi thực tế - chống spam widget rebuild)
        if (data.containsKey('devices') && data['devices'] is List) {
          final Map<String, bool> states = {};
          for (var d in (data['devices'] as List)) {
            if (d is Map && d.containsKey('id') && d.containsKey('state')) {
              states[d['id'].toString()] = d['state'].toString() == '1';
            }
          }
          if (states.isNotEmpty && !mapEquals(_lastKnownStates, states)) {
            _lastKnownStates = Map.from(states);
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

  /// Lấy danh sách quy tắc tự động hóa tự trị cục bộ từ Hub qua mạng LAN
  Future<List<Map<String, dynamic>>?> fetchLocalRules() async {
    if (_cachedHubIp == null || _cachedHubIp!.isEmpty) return null;
    try {
      final uri = Uri.parse('http://$_cachedHubIp/api/rules');
      final res = await http.get(uri).timeout(const Duration(milliseconds: 2000));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['rules'] is List) {
          return List<Map<String, dynamic>>.from(data['rules']);
        }
      }
    } catch (e) {
      LoggerService.w('[LocalNet] Lỗi tải rules từ Hub: $e');
    }
    return null;
  }

  /// Cập nhật danh sách quy tắc tự động hóa tự trị cục bộ tới Hub qua mạng LAN
  Future<bool> sendLocalRules(List<Map<String, dynamic>> rules) async {
    if (_cachedHubIp == null || _cachedHubIp!.isEmpty) return false;
    try {
      final uri = Uri.parse('http://$_cachedHubIp/api/rules');
      final body = jsonEncode({'rules': rules});
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(milliseconds: 2500));
      if (res.statusCode == 200) {
        LoggerService.i('[LocalNet] ✅ Đã lưu thành công ${rules.length} quy tắc tự động hóa vào Flash Hub!');
        return true;
      }
    } catch (e) {
      LoggerService.w('[LocalNet] Gửi rules tới Hub thất bại: $e');
    }
    return false;
  }

  /// Luân chuyển khóa bí mật Zero-Knowledge với Hub (Automated Key Rotation)
  Future<bool> rotateHubSecretKey() async {
    if (_cachedHubIp == null || _cachedHubIp!.isEmpty) return false;
    try {
      final uri = Uri.parse('http://$_cachedHubIp/api/auth/rotate-key');
      final localKey = await getOrNegotiateLocalKey(hubIp: _cachedHubIp!, mac: _monitoredMac!);
      if (localKey == null || localKey.isEmpty) return false;

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateRandomNonce(8);
      final user = _currentUserId ?? 'owner';
      final signPayload = 'rotate:$user:$timestamp:$nonce';

      final keyBytes = <int>[];
      for (int i = 0; i < localKey.length; i += 2) {
        keyBytes.add(int.parse(localKey.substring(i, i + 2), radix: 16));
      }
      final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

      final payload = {
        'user': user,
        'ts': timestamp,
        'nonce': nonce,
        'sig': signature,
      };

      final encEnvelope = ZenHomeCrypto.encryptPayload(plaintext: jsonEncode(payload), keyHex: localKey);
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'enc': encEnvelope}),
      ).timeout(const Duration(milliseconds: 3000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'ok' && data['encKey'] != null) {
          final decryptedNewKey = ZenHomeCrypto.decryptPayload(envelope: data['encKey'].toString(), keyHex: localKey);
          if (decryptedNewKey != null && decryptedNewKey.length == 64) {
            await _secureStorage.write(key: 'local_sec_key_$_monitoredMac', value: decryptedNewKey);
            LoggerService.i('[LocalSec] 🔄 Luân chuyển khóa thành công! Khóa mới đã được lưu an toàn vào Hardware Keystore.');
            return true;
          }
        }
      }
    } catch (e) {
      LoggerService.w('[LocalSec] Luân chuyển khóa thất bại: $e');
    }
    return false;
  }

  void dispose() {
    stopMonitoring();
    _localAvailableController.close();
    _hubIpController.close();
    _localTempController.close();
    _localDeviceStateController.close();
  }
}
