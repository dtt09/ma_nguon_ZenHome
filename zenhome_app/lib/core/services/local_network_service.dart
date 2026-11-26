import 'package:zenhome_app/core/services/hub_local_key.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenhome_app/core/services/logger_service.dart';
import 'package:zenhome_app/core/services/ble_local_service.dart';
import 'package:zenhome_app/core/services/zenhome_crypto.dart';

/// Dịch vụ quản lý tìm kiếm và điều khiển thiết bị ESP32 trực tiếp qua mạng cục bộ (LAN / Wi-Fi)
class LocalNetworkService {
  static final LocalNetworkService _instance = LocalNetworkService._internal();
  factory LocalNetworkService() => _instance;
  LocalNetworkService._internal();

  static const int udpDiscoveryPort = 4210;
  static const int hubHttpPort = 80;




  String? _cachedHubIp;
  bool _isLocalAvailable = false;
  bool _isLanAvailable = false;
  Timer? _monitoringTimer;
  String? _monitoredMac;
  String? _currentUserId;
  String? _currentUserRole;
  String? _bootNonce;
  bool _isDisabled = false;
  bool _isChecking = false;
  String? _cachedAdminPass;
  StreamSubscription? _bleStateSub;
  StreamSubscription? _bleAvailSub;
  Map<String, bool> _lastKnownStates = {};
  String? _lastKnownTemp;

  final _localAvailableController = StreamController<bool>.broadcast();
  final _lanAvailableController = StreamController<bool>.broadcast();
  final _hubIpController = StreamController<String?>.broadcast();
  final _localTempController = StreamController<String?>.broadcast();
  final _localDeviceStateController = StreamController<Map<String, bool>>.broadcast();

  Stream<bool> get localAvailableStream => _localAvailableController.stream;
  Stream<bool> get lanAvailableStream => _lanAvailableController.stream;
  Stream<String?> get hubIpStream => _hubIpController.stream;
  Stream<String?> get localTempStream => _localTempController.stream;
  Stream<Map<String, bool>> get localDeviceStateStream => _localDeviceStateController.stream;

  String? get cachedHubIp => _cachedHubIp;
  bool get isLocalAvailable => _isLocalAvailable;
  bool get isLanAvailable => _isLanAvailable;

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
    _currentUserRole = role;
    _isDisabled = isDisabled;

    if (role != 'owner' || isDisabled) {
      stopMonitoring();
      return;
    }
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

    _bootNonce = null;
    _lastKnownStates.clear();
    _lastKnownTemp = null;
    BleLocalService().stop();
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

  void _setLocalAvailable(bool lanAvailable) {
    final lanChanged = (_isLanAvailable != lanAvailable);
    _isLanAvailable = lanAvailable;
    if (lanChanged) {
      _lanAvailableController.add(lanAvailable);
      if (!lanAvailable) {
        _hubIpController.add(null);
      } else if (_cachedHubIp != null) {
        _hubIpController.add(_cachedHubIp);
      }
    }

    // Báo cho BLE Service biết trạng thái LAN để tạm dừng quét BLE vô ích khi mạng LAN hoạt động tốt
    BleLocalService().setNetworkOnlineStatus(isLanAvailable: lanAvailable);

    // Khả dụng cục bộ khi: hoặc mạng LAN ping thành công, hoặc BLE Hub sẵn sàng kết nối theo yêu cầu (Connect-on-Demand)
    final effectiveAvailable = lanAvailable || BleLocalService().isHubNearby || BleLocalService().isAuthenticated;
    if (_isLocalAvailable != effectiveAvailable) {
      _isLocalAvailable = effectiveAvailable;
      _localAvailableController.add(effectiveAvailable);
      LoggerService.i(effectiveAvailable
          ? '[LocalNet] Đã kết nối cục bộ an toàn với Hub (LAN: ${lanAvailable ? _cachedHubIp : "Mất Wi-Fi"}, BLE Sẵn sàng: ${BleLocalService().isHubNearby})!'
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

      // Thu thập danh sách các địa chỉ Broadcast (Cả toàn cục 255.255.255.255 lẫn Subnet Broadcast riêng từng Interface mạng)
      final Set<String> targetBroadcastIps = {'255.255.255.255'};
      try {
        final interfaces = await NetworkInterface.list(
          includeLoopback: false,
          type: InternetAddressType.IPv4,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              // Đối với mạng gia đình IPv4 (/24), tính địa chỉ directed subnet broadcast ví dụ: 192.168.1.255
              final subnetBcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              targetBroadcastIps.add(subnetBcast);
            }
          }
        }
      } catch (ifaceErr) {
        debugPrint('[LocalNet] Không thể liệt kê NetworkInterface: $ifaceErr');
      }

      // Gửi bản tin Discovery an toàn (bảo vệ chống ngoại lệ Network is unreachable / Operation not permitted trên Android)
      final message = utf8.encode('ZENHOME_DISCOVER');
      void sendBroadcasts() {
        for (final ipStr in targetBroadcastIps) {
          try {
            socket?.send(message, InternetAddress(ipStr), udpDiscoveryPort);
          } catch (_) {}
        }
      }

      // Phát đợt 1 ngay lập tức
      sendBroadcasts();

      // Phát đợt 2 sau 80ms để bù đắp tỉ lệ rớt gói tin trên Wi-Fi sóng yếu
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!completer.isCompleted && socket != null) {
          sendBroadcasts();
        }
      });

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

            _setLocalAvailable(false);
            return false;
          }
          if (data['status'] == 'ok' && _cleanMac(data['macAddress']?.toString() ?? '') == _monitoredMac) {
            final boot = data['bootNonce'];
            if (boot is! String || !RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(boot)) return false;
            _bootNonce = boot;
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

  String _requestNonce() {
    final boot = _bootNonce;
    if (boot == null) throw StateError('Hub handshake required');
    return '$boot.${_generateRandomNonce(16)}';
  }

  Future<String?> _localKey() async {
    final mac = _monitoredMac;
    if (_isDisabled || _currentUserRole != 'owner' || mac == null || mac.isEmpty) return null;
    final home = _currentUserId;
    if (home == null) return null;
    return HubLocalKey.read(home, mac);
  }

  Future<String?> sealSystemCommand(String homeId, String mac, String op, Map<String, dynamic> fields) async {
    if (_currentUserId != homeId || _monitoredMac != _cleanMac(mac)) return null;
    final key = await _localKey();
    if (key == null || _currentUserId != homeId || _monitoredMac != _cleanMac(mac)) return null;
    final inner = {...fields, 'action': op, 'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'nonce': _generateRandomNonce(16)};
    return jsonEncode({'enc': ZenHomeCrypto.encryptPayload(plaintext: jsonEncode(inner), keyHex: key)});
  }

  Future<Map<String, dynamic>?> _verifiedReply(http.Response response, String op, Map<String,String> request) async {
    final key = await _localKey();
    if (response.statusCode != 200 || key == null) return null;
    final outer = jsonDecode(response.body);
    if (outer is! Map || outer['data'] is! String) return null;
    final data = outer['data'] as String;
    final proof = ZenHomeCrypto.sign(key, "reply:$op:${request['X-ZenHome-Nonce']}:${ZenHomeCrypto.digest(data)}");
    if (!ZenHomeCrypto.matches(proof, outer['proof'])) return null;
    return jsonDecode(data) as Map<String, dynamic>;
  }

  Future<Map<String, String>> _signedHeaders(String op, [String body = '']) async {
    final user = _currentUserId;
    final key = await _localKey();
    if (user == null || user.isEmpty || key == null) throw StateError('Hub credentials unavailable');
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = _requestNonce();
    return {
      'Content-Type': 'application/json',
      'X-ZenHome-User': user,
      'X-ZenHome-Timestamp': '$timestamp',
      'X-ZenHome-Nonce': nonce,
      'X-ZenHome-Signature': ZenHomeCrypto.sign(key, '$op:$user:${ZenHomeCrypto.digest(body)}:$timestamp:$nonce'),
    };
  }

  /// Điều khiển Relay trực tiếp qua mạng nội bộ (LAN HTTP hoặc BLE GATT Zero-Touch)
  /// Tự động xác thực chữ ký HMAC-SHA256 theo chuẩn bảo mật Zero-Knowledge và Phân quyền RBAC
  Future<bool> sendLocalControl({required String devId, required String cmd}) async {
    final user = _currentUserId;
    final key = await _localKey();
    if (user == null || user.isEmpty || key == null) return false;
    if (_cachedHubIp != null && _cachedHubIp!.isNotEmpty) {
      try {
        final uri = Uri.parse('http://$_cachedHubIp/api/control');
        final ver = DateTime.now().millisecondsSinceEpoch;
        final timestamp = ver ~/ 1000;
        final nonce = _requestNonce();
        final body = jsonEncode({'id': devId, 'cmd': cmd, 'user': user, 'ver': ver, 'ts': timestamp, 'nonce': nonce});
        final headers = {
          'Content-Type': 'application/json',
          'X-ZenHome-User': user,
          'X-ZenHome-Timestamp': '$timestamp',
          'X-ZenHome-Nonce': nonce,
          'X-ZenHome-Signature': ZenHomeCrypto.sign(key, '$user:$devId:$cmd:$timestamp:$nonce'),
        };
        var res = await http.post(
          uri,
          headers: headers,
          body: body,
        ).timeout(const Duration(milliseconds: 1000));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is Map && data['status'] == 'ok' && data['state'] == cmd &&
              ZenHomeCrypto.matches(ZenHomeCrypto.sign(key, 'ack:$user:$devId:$cmd:$nonce'), data['proof'])) {
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
      final bleSuccess = await BleLocalService().sendControlCommand(
        devId: devId,
        cmd: cmd,
        localKey: key,
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

      final headers = await _signedHeaders('members', body);
      final res = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(milliseconds: 2000));

      if (await _verifiedReply(res, 'members', headers) != null) {
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
    String? newMqttUser,
    String? newMqttPass,
  }) async {
    final effectiveAdmin = newAdminPass ?? _cachedAdminPass;
    final key = await _localKey();
    if (key == null) return false;
    if (_cachedHubIp != null && _cachedHubIp!.isNotEmpty) {
      try {
        final uri = Uri.parse('http://$_cachedHubIp/api/reconfig');
        final config = jsonEncode({
          'wifi_ssid': newSsid,
          'wifi_pass': newWifiPass,
          if (newServer != null && newServer.isNotEmpty) 'mqtt_server': newServer,
          if (newMqttUser?.isNotEmpty == true) 'mqtt_user': newMqttUser,
          if (newMqttPass?.isNotEmpty == true) 'mqtt_pass': newMqttPass,
          if (effectiveAdmin != null && effectiveAdmin.isNotEmpty) 'admin_pass': effectiveAdmin,
        });
        final data = ZenHomeCrypto.encryptPayload(plaintext: config, keyHex: key);
        final body = jsonEncode({'data': data});
        final headers = await _signedHeaders('reconfig', data);
        final res = await http.post(
          uri,
          headers: headers,
          body: body,
        ).timeout(const Duration(milliseconds: 2500));

        if (await _verifiedReply(res, 'reconfig', headers) != null) {
          LoggerService.i('[LocalNet] 📡 Đã gửi cấu hình Wi-Fi mới thành công qua mạng LAN HTTP!');
          return true;
        }
      } catch (e) {
        LoggerService.w('[LocalNet] Gửi reconfig qua Wi-Fi LAN thất bại: $e. Thử fallback BLE...');
      }
    }

    // 2. Fallback sang BLE Zero-Touch (Kể cả khi Hub mất Wi-Fi hoàn toàn)
    try {
      final bleSuccess = await BleLocalService().sendReconfigCommand(
        newSsid: newSsid,
        newWifiPass: newWifiPass,
        newServer: newServer,
        newAdminPass: effectiveAdmin,
        newMqttUser: newMqttUser,
        newMqttPass: newMqttPass,
        localKey: key,
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
      final headers = await _signedHeaders('status');
      final res = await http.get(uri, headers: headers).timeout(const Duration(milliseconds: 2000));

      final data = await _verifiedReply(res, 'status', headers);
      if (data != null) {

        // Phát hiện nếu Hub đang ở chế độ unlinked / reset
        if (data['unlinked'] == true || data['status'] == 'unlinked' || data['mode'] == 'unlinked' || data['reset'] == true) {
          LoggerService.w('[LocalNet] ⚠️ Hub phản hồi trạng thái CHƯA LIÊN KẾT / FACTORY RESET!');

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
      final headers = await _signedHeaders('rules-get');
      final res = await http.get(uri, headers: headers).timeout(const Duration(milliseconds: 2000));
      final data = await _verifiedReply(res, 'rules-get', headers);
      if (data != null) {
        if (data['rules'] is List) {
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
      final headers = await _signedHeaders('rules-set', body);
      final res = await http.post(
        uri,
        headers: headers,
        body: body,
      ).timeout(const Duration(milliseconds: 2500));
      if (await _verifiedReply(res, 'rules-set', headers) != null) {
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
      final localKey = await _localKey();
      if (localKey == null || localKey.isEmpty) return false;

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _requestNonce();
      final user = _currentUserId;
      if (user == null || user.isEmpty) return false;
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
            await HubLocalKey.save(user, _monitoredMac!, decryptedNewKey);
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
