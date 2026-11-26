import 'package:zenhome_app/core/services/hub_local_key.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:zenhome_app/core/services/logger_service.dart';
import 'package:zenhome_app/core/services/zenhome_crypto.dart';

enum _BleTaskType { control, reconfig }

class _BleTask {
  final _BleTaskType type;
  final String? devId;
  final String? cmd;
  final Map<String, dynamic>? reconfigData;
  final String? localKey;
  final Completer<bool> completer;

  _BleTask({
    required this.type,
    this.devId,
    this.cmd,
    this.reconfigData,
    this.localKey,
    required this.completer,
  });
}

/// Dịch vụ quản lý kết nối BLE Zero-Touch Connect-on-Demand (Có việc mới kết nối)
/// Hỗ trợ chia sẻ 3 khe kết nối phần cứng của ESP32 thông qua Hàng Đợi (Queue) và Auto-Disconnect
/// Hoạt động như kênh dự phòng ngầm khi Router Wi-Fi mất nguồn hoặc mất kết nối.
class BleLocalService {
  static final BleLocalService _instance = BleLocalService._internal();
  factory BleLocalService() => _instance;
  BleLocalService._internal();

  static const String serviceUuidStr = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String controlCharUuidStr = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String statusCharUuidStr = '19b10002-e8f2-537e-4f6c-d104768a1214';

  final Guid _serviceUuid = Guid(serviceUuidStr);
  final Guid _controlCharUuid = Guid(controlCharUuidStr);
  final Guid _statusCharUuid = Guid(statusCharUuidStr);

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? _cachedDiscoveredDevice;
  DateTime? _lastDiscoveredAt;
  BluetoothCharacteristic? _controlChar;
  BluetoothCharacteristic? _statusChar;
  StreamSubscription? _statusCharSub;
  Completer<bool>? _authCompleter;
  String? _expectedHubProof;
  String? _bootNonce;
  StreamSubscription? _connectionSub;


  bool _isScanning = false;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  String? _monitoredMac;
  String? _userId;
  String? _role;
  List<String>? _allowedDevices;

  Timer? _passiveDiscoveryTimer;
  Timer? _idleDisconnectTimer;
  static const int idleGracePeriodMs = 1200; // 1.2s ân hạn trước khi ngắt nhường sóng cho máy khác

  // Hàng đợi lệnh (Command Queue)
  final List<_BleTask> _taskQueue = [];
  bool _isProcessingQueue = false;

  final _bleAvailableController = StreamController<bool>.broadcast();
  final _bleAuthenticatedController = StreamController<bool>.broadcast();
  final _bleDeviceStateController = StreamController<Map<String, bool>>.broadcast();

  Stream<bool> get bleAvailableStream => _bleAvailableController.stream;
  Stream<bool> get bleAuthenticatedStream => _bleAuthenticatedController.stream;
  Stream<Map<String, bool>> get bleDeviceStateStream => _bleDeviceStateController.stream;

  bool get isConnected => _isConnected;
  bool get isAuthenticated => _isAuthenticated;
  bool get isHubNearby {
    if (_cachedDiscoveredDevice == null || _lastDiscoveredAt == null) return false;
    return DateTime.now().difference(_lastDiscoveredAt!) < const Duration(seconds: 45);
  }
  BluetoothCharacteristic? get statusChar => _statusChar;

  Future<String> _getLocalKey() async {
    final home = _userId;
    final mac = _monitoredMac;
    if (_role != 'owner' || home == null || mac == null) return '';
    return await HubLocalKey.read(home, mac) ?? '';
  }

  /// Khởi tạo tham số giám sát (Không kết nối sẵn mà chỉ dò tìm thụ động khi cần)
  void start({
    required String targetMac,
    String? adminPass,
    String? localKey,
    String? userId,
    String? role,
    List<String>? allowedDevices,
  }) {
    if (targetMac.isEmpty || targetMac == 'unknown_mac' || targetMac == 'unknown') {
      return;
    }
    _monitoredMac = targetMac.replaceAll(':', '').replaceAll('-', '').trim().toUpperCase();
    _userId = userId;
    _role = role ?? 'owner';
    _allowedDevices = allowedDevices;

    // Quét thụ động một lần đầu nếu mạng chưa sẵn sàng
    if (!_isNetworkOnline) {
      _passiveDiscover();
      _startPassiveDiscoveryTimer();
    }
  }

  bool _isNetworkOnline = false;

  /// Cập nhật trạng thái mạng Online (LAN hoặc MQTT).
  /// Khi mạng hoạt động tốt, ESP32 tắt hoàn toàn BLE radio -> App lập tức dừng quét để tiết kiệm pin.
  void setNetworkOnlineStatus({required bool isLanAvailable, bool isMqttConnected = false}) {
    final isOnline = isLanAvailable || isMqttConnected;
    if (_isNetworkOnline == isOnline) return;
    _isNetworkOnline = isOnline;

    if (_isNetworkOnline) {
      _passiveDiscoveryTimer?.cancel();
      _passiveDiscoveryTimer = null;
    } else {
      _startPassiveDiscoveryTimer();
      _passiveDiscover();
    }
  }

  void _startPassiveDiscoveryTimer() {
    _passiveDiscoveryTimer?.cancel();
    _passiveDiscoveryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isConnected && !_isScanning && _taskQueue.isEmpty && !_isNetworkOnline) {
        _passiveDiscover();
      }
    });
  }

  void stop() {
    _passiveDiscoveryTimer?.cancel();
    _passiveDiscoveryTimer = null;
    _idleDisconnectTimer?.cancel();
    _idleDisconnectTimer = null;
    for (final task in _taskQueue) {
      if (!task.completer.isCompleted) task.completer.complete(false);
    }
    _taskQueue.clear();
    _monitoredMac = null;
    _cachedDiscoveredDevice = null;
    _role = null;
    disconnect();
  }

  /// Quét thụ động (Passive Discovery): Không filter cứng service UUID ở tầng Native Android
  /// giúp nhận diện 100% thiết bị ESP32 kể cả khi Service UUID nằm trong Scan Response
  Future<void> _passiveDiscover() async {
    if (_isScanning || _isConnected || _isNetworkOnline) return;

    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return;

      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) return;

      _isScanning = true;

      // Quét mở rộng không ép withServices để tránh lỗi hardware filter Android với gói tin quá 31 bytes
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 3),
      );

      final subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (_matchesMonitoredMac(r)) {
            _cachedDiscoveredDevice = r.device;
            _lastDiscoveredAt = DateTime.now();
            _bleAvailableController.add(true);
            await FlutterBluePlus.stopScan();
            _isScanning = false;
            break;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 3));
      await subscription.cancel();
      _isScanning = false;
    } catch (e) {
      debugPrint('[BLE] Lỗi quét thụ động: $e');
      _isScanning = false;
    }
  }

  /// Quét nhanh theo yêu cầu khi chuẩn bị bắn lệnh
  Future<BluetoothDevice?> _scanQuickly() async {
    if (_isScanning) return _cachedDiscoveredDevice;
    try {
      _isScanning = true;
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 2),
      );
      await for (final results in FlutterBluePlus.scanResults) {
        for (ScanResult r in results) {
          if (_matchesMonitoredMac(r)) {
            _cachedDiscoveredDevice = r.device;
            _lastDiscoveredAt = DateTime.now();
            _bleAvailableController.add(true);
            await FlutterBluePlus.stopScan();
            _isScanning = false;
            return r.device;
          }
        }
      }
    } catch (_) {
      _isScanning = false;
    }
    return _cachedDiscoveredDevice;
  }

  bool _matchesMonitoredMac(ScanResult r) {
    if (_monitoredMac == null) return false;
    // 1. Kiểm tra Manufacturer Data (Chính xác tuyệt đối)
    final mfg = r.advertisementData.manufacturerData;
    for (var entry in mfg.entries) {
      if (entry.value.length >= 6) {
        final macStr = entry.value.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
        if (macStr.contains(_monitoredMac!) || _monitoredMac!.contains(macStr)) {
          return true;
        }
      }
    }
    // 2. Kiểm tra tên thiết bị (ZenHome_XXXX)
    final advName = r.advertisementData.advName;
    if (advName.startsWith('ZenHome_') && _monitoredMac!.endsWith(advName.substring(8))) {
      return true;
    }
    // 3. Fallback theo Service UUID (nếu nằm trong adv packet)
    if (r.advertisementData.serviceUuids.contains(_serviceUuid)) {
      return true;
    }
    return false;
  }

  /// Đảm bảo kết nối và xác thực Key kèm Retry & Jitter Backoff
  /// Cho phép hơn 3 máy cùng chia sẻ 3 slot kết nối phần cứng của ESP32 một cách mượt mà
  Future<bool> _ensureConnectedAndAuthenticatedWithBackoff() async {
    if (_isConnected && _isAuthenticated && _controlChar != null) {
      return true;
    }

    const maxAttempts = 3;
    final random = Random();

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final success = await _connectAndAuthenticateDirect();
      if (success) return true;

      if (attempt < maxAttempts) {
        final jitterMs = 150 + random.nextInt(250); // Chờ 150-400ms để slot trên ESP32 nhả ra
        LoggerService.w('[BLE-QUEUE] ⏳ ESP32 có thể đang bận 3 slot với các máy khác. Chờ ${jitterMs}ms và thử lại (Lần $attempt/$maxAttempts)...');
        await Future.delayed(Duration(milliseconds: jitterMs));
      }
    }
    return false;
  }

  Future<bool> _connectAndAuthenticateDirect() async {
    BluetoothDevice? target = _connectedDevice ?? _cachedDiscoveredDevice;
    target ??= await _scanQuickly();
    if (target == null) return false;

    try {
      _connectedDevice = target;
      await target.connect(
        license: License.nonprofit,
        mtu: 512,
        autoConnect: false,
        timeout: const Duration(seconds: 4),
      );

      _isConnected = true;
      LoggerService.i('[BLE] ⚡ Đã kết nối vật lý BLE tới Hub! Đang tìm kiếm GATT Service...');

      // Yêu cầu nâng MTU lên 512 byte trên Android để truyền toàn vẹn gói xác thực HMAC/JSON
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await target.requestMtu(512);
        } catch (_) {}
      }

      // Lắng nghe trạng thái ngắt kết nối
      await _connectionSub?.cancel();
      _connectionSub = target.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _isConnected = false;
          _isAuthenticated = false;
          _controlChar = null;
          _statusChar = null;
          _bleAuthenticatedController.add(false);
          LoggerService.w('[BLE] 📴 Đã ngắt kết nối BLE (Giải phóng khe cho máy khác).');
        }
      });

      // Khám phá dịch vụ
      List<BluetoothService> services = await target.discoverServices();
      for (var s in services) {
        if (s.uuid == _serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid == _controlCharUuid) {
              _controlChar = c;
            } else if (c.uuid == _statusCharUuid) {
              _statusChar = c;
              final boot = jsonDecode(utf8.decode(await c.read()))['bootNonce'];
              if (boot is! String || !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(boot)) {
                throw const FormatException('Missing BLE boot challenge');
              }
              _bootNonce = boot;
              await c.setNotifyValue(true);
              _statusCharSub?.cancel();
              _statusCharSub = c.onValueReceived.listen((value) {
                _handleStatusNotification(value);
              });
            }
          }
        }
      }

      // Bắt tay xác thực Key hai chiều có Timeout & Reactive ACK
      if (_controlChar != null) {
        if (_authCompleter?.isCompleted == false) _authCompleter!.complete(false);
        _authCompleter = Completer<bool>();
        await _authenticateWithKey();

        try {
          final authOk = await _authCompleter!.future.timeout(const Duration(milliseconds: 2500));
          _isAuthenticated = authOk;
        } catch (_) {
          _isAuthenticated = false;
        } finally {
          _authCompleter = null;
        }
      }

      if (!_isAuthenticated) {
        LoggerService.w('[BLE] ❌ Xác thực Key thất bại hoặc quá hạn 2.5s! Chủ động ngắt kết nối BLE.');
        await disconnect();
        return false;
      }

      return _isAuthenticated && _controlChar != null;
    } catch (e) {
      LoggerService.w('[BLE] Kết nối trực tiếp thất bại: $e');
      await disconnect();
      return false;
    }
  }

  /// Bắt tay xác thực Key hai chiều (HMAC-SHA256)
  Future<void> _authenticateWithKey() async {
    if (_controlChar == null || _monitoredMac == null) return;
    try {
      final key = await _getLocalKey();
      if (key.isEmpty) {
        LoggerService.w('[BLE-KEY] ⚠️ Không có khóa bảo mật hợp lệ để xác thực BLE!');
        await disconnect();
        return;
      }

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = '$_bootNonce.${_generateRandomNonce(32)}';
      final user = _userId;
      if (_role != 'owner' || user == null || user.isEmpty) return;
      final signPayload = 'auth:$_monitoredMac:$user:$timestamp:$nonce';
      _expectedHubProof = ZenHomeCrypto.sign(key, 'hub-auth:$_monitoredMac:$user:$timestamp:$nonce');

      final keyBytes = <int>[];
      for (int i = 0; i < key.length; i += 2) {
        keyBytes.add(int.parse(key.substring(i, i + 2), radix: 16));
      }
      final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

      final authMap = {
        'action': 'auth',
        'mac': _monitoredMac,
        'user': _userId ?? 'unknown',
        'role': _role ?? 'member',
        'ts': timestamp,
        'nonce': nonce,
        'sig': signature,
      };

      await _controlChar!.write(utf8.encode(jsonEncode(authMap)), withoutResponse: false, allowLongWrite: true);
      LoggerService.i('[BLE-KEY] 🔑 Đã gửi bản tin xác thực Key tới Hub qua Bluetooth!');
    } catch (e) {
      LoggerService.w('[BLE-KEY] Gửi xác thực Key thất bại: $e');
    }
  }

  void _handleStatusNotification(List<int> value) {
    try {
      final str = utf8.decode(value);
      final json = jsonDecode(str);
      if (json is Map) {
        if (json['status'] == 'auth_ok' && _authCompleter?.isCompleted == false &&
            ZenHomeCrypto.matches(_expectedHubProof ?? '', json['proof'])) {
          _isAuthenticated = true;
          _bleAuthenticatedController.add(true);
          _bleAvailableController.add(true);
          if (_authCompleter != null && !_authCompleter!.isCompleted) {
            _authCompleter!.complete(true);
          }
          LoggerService.i('[BLE-KEY] 🔐 Hub đã xác nhận Key thành công! Kênh BLE sẵn sàng.');
        } else if (json['status'] == 'auth_failed' || json['authenticated'] == false) {
          _isAuthenticated = false;
          _bleAuthenticatedController.add(false);
          if (_authCompleter != null && !_authCompleter!.isCompleted) {
            _authCompleter!.complete(false);
          }
          LoggerService.w('[BLE-KEY] ⛔ Hub từ chối xác thực Key: ${json['error'] ?? 'auth_failed'}');
        }


      }
    } catch (e) {
      debugPrint('[BLE] Lỗi đọc notify: $e');
    }
  }

  /// Xử lý Hàng Đợi Lệnh (Queue Worker):
  /// Tự động kết nối -> Gửi tất cả các lệnh trong hàng đợi -> Tự ngắt kết nối sau 1.2s rảnh rỗi
  Future<void> _processQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_taskQueue.isNotEmpty) {
        final ready = await _ensureConnectedAndAuthenticatedWithBackoff();
        if (!ready) {
          // Xả toàn bộ hàng đợi báo thất bại nếu không thể kết nối tới Hub
          while (_taskQueue.isNotEmpty) {
            final task = _taskQueue.removeAt(0);
            if (!task.completer.isCompleted) task.completer.complete(false);
          }
          break;
        }

        if (_taskQueue.isEmpty) break;
        final task = _taskQueue.removeAt(0);
        bool success = false;

        try {
          if (task.type == _BleTaskType.control) {
            success = await _executeRawControlCommand(task.devId!, task.cmd!, task.localKey);
          } else if (task.type == _BleTaskType.reconfig) {
            success = await _executeRawReconfigCommand(task.reconfigData!, task.localKey);
          }
        } catch (e) {
          LoggerService.w('[BLE-QUEUE] Lỗi thực thi lệnh trong hàng đợi: $e');
        }

        if (!task.completer.isCompleted) {
          task.completer.complete(success);
        }
      }
    } finally {
      _isProcessingQueue = false;

      // ân hạn 1.2 giây trước khi ngắt kết nối để nếu người dùng nhấn liên tiếp 2-3 nút thì không phải kết nối lại
      _idleDisconnectTimer?.cancel();
      _idleDisconnectTimer = Timer(const Duration(milliseconds: idleGracePeriodMs), () async {
        if (_taskQueue.isEmpty && _isConnected) {
          LoggerService.i('[BLE-MULTIUSER] ⏱️ Hàng đợi đã hoàn tất! Tự động ngắt kết nối BLE để nhường khe cho các thành viên khác.');
          await disconnect();
        }
      });
    }
  }

  /// Gửi lệnh điều khiển thiết bị tức thì qua BLE - Có việc mới kết nối, xếp hàng đợi và tự ngắt
  Future<bool> sendControlCommand({
    required String devId,
    required String cmd,
    String? localKey,
  }) async {
    // 1. Phân quyền thành viên (Hardware RBAC)
    if (_role == 'member' && _allowedDevices != null && !_allowedDevices!.contains(devId)) {
      LoggerService.w('[BLE-RBAC] 🚫 Thành viên không có quyền điều khiển thiết bị $devId!');
      return false;
    }

    final completer = Completer<bool>();

    _taskQueue.add(_BleTask(
      type: _BleTaskType.control,
      devId: devId,
      cmd: cmd,
      localKey: localKey,
      completer: completer,
    ));

    if (!_isProcessingQueue) {
      _processQueue();
    }
    return completer.future;
  }

  Future<bool> _executeRawControlCommand(String devId, String cmd, String? localKey) async {
    if (_controlChar == null) return false;
    try {
      final key = localKey ?? await _getLocalKey();
      if (key.isEmpty) return false;
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = '$_bootNonce.${_generateRandomNonce(32)}';
      final user = _userId;
      if (_role != 'owner' || user == null || user.isEmpty) return false;

      final signPayload = '$user:$devId:$cmd:$timestamp:$nonce';
      final keyBytes = <int>[];
      for (int i = 0; i < key.length; i += 2) {
        keyBytes.add(int.parse(key.substring(i, i + 2), radix: 16));
      }
      final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

      final Map<String, dynamic> payloadMap = {
        'id': devId,
        'cmd': cmd,
        'user': user,
        'sig': signature,
        'ts': timestamp,
        'nonce': nonce,
      };

      // Mã hóa phong bì AES-256 (Authenticated Encryption) che giấu 100% dữ liệu điều khiển qua sóng BLE
      final rawJson = jsonEncode(payloadMap);
      final encEnvelope = ZenHomeCrypto.encryptPayload(plaintext: rawJson, keyHex: key);
      final finalPayload = {'enc': encEnvelope};

      final jsonBytes = utf8.encode(jsonEncode(finalPayload));
      final applied = await _writeAndConfirm(jsonBytes, nonce, 'ok', key, user, device: devId, state: cmd);
      if (applied) _bleDeviceStateController.add({devId: cmd == '1'});
      return applied;
    } catch (e) {
      LoggerService.w('[BLE-QUEUE] Bắn lệnh điều khiển qua BLE thất bại: $e');
      return false;
    }
  }

  /// Gửi cấu hình Wi-Fi mới tới Hub qua BLE
  Future<bool> sendReconfigCommand({
    required String newSsid,
    required String newWifiPass,
    String? newServer,
    String? newAdminPass,
    String? newMqttUser,
    String? newMqttPass,
    String? localKey,
  }) async {
    final completer = Completer<bool>();
    _taskQueue.add(_BleTask(
      type: _BleTaskType.reconfig,
      reconfigData: {
        'ssid': newSsid,
        'pass': newWifiPass,
        'server': newServer,
        'adminPass': newAdminPass,
        'mqttUser': newMqttUser,
        'mqttPass': newMqttPass,
      },
      localKey: localKey,
      completer: completer,
    ));

    if (!_isProcessingQueue) {
      _processQueue();
    }
    return completer.future;
  }

  Future<bool> _executeRawReconfigCommand(Map<String, dynamic> data, String? localKey) async {
    if (_controlChar == null) return false;
    try {
      final key = localKey ?? await _getLocalKey();
      if (key.isEmpty) return false;
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = '$_bootNonce.${_generateRandomNonce(32)}';
      final user = _userId;
      if (_role != 'owner' || user == null || user.isEmpty) return false;
      final config = jsonEncode({
        'wifi_ssid': data['ssid'],
        'wifi_pass': data['pass'],
        if (data['server']?.isNotEmpty == true) 'mqtt_server': data['server'],
        if (data['mqttUser']?.isNotEmpty == true) 'mqtt_user': data['mqttUser'],
        if (data['mqttPass']?.isNotEmpty == true) 'mqtt_pass': data['mqttPass'],
        if (data['adminPass']?.isNotEmpty == true) 'admin_pass': data['adminPass'],
      });
      final signature = ZenHomeCrypto.sign(key, 'reconfig:$user:${ZenHomeCrypto.digest(config)}:$timestamp:$nonce');
      final payloadMap = {
        'action': 'reconfig',
        'data': config,
        'user': user,
        'sig': signature,
        'ts': timestamp,
        'nonce': nonce,
      };

      // SEC-FIX [ZH-CRIT-06]: Mã hóa phong bì AES-256 (Authenticated Encryption) bảo vệ toàn bộ Wi-Fi và Admin Pass qua sóng BLE
      final rawJson = jsonEncode(payloadMap);
      final encEnvelope = ZenHomeCrypto.encryptPayload(plaintext: rawJson, keyHex: key);
      final finalPayload = {'enc': encEnvelope};

      final jsonBytes = utf8.encode(jsonEncode(finalPayload));
      return await _writeAndConfirm(jsonBytes, nonce, 'reconfig_ok', key, user);
    } catch (e) {
      LoggerService.w('[BLE-RECONFIG] Bắn bản tin reconfig qua BLE thất bại: $e');
      return false;
    }
  }

  Future<bool> _writeAndConfirm(List<int> bytes, String nonce, String status, String key, String user,
      {String? device, String? state}) async {
    final ack = Completer<bool>();
    final sub = _statusChar!.onValueReceived.listen((value) {
      try {
        final reply = jsonDecode(utf8.decode(value));
        if (reply is! Map || reply['nonce'] != nonce || ack.isCompleted) return;
        if (device != null && reply['id'] != device) return;
        final proof = ZenHomeCrypto.sign(key, "ble-ack:$user:$nonce:${reply['status']}:${reply['id'] ?? ''}:${reply['state'] ?? ''}");
        if (!ZenHomeCrypto.matches(proof, reply['proof'])) return;
        ack.complete(reply['status'] == status && (state == null || reply['state'] == state));
      } on FormatException {
        // Other BLE notifications may arrive while this request is in flight.
      }
    });
    try {
      final maxWrite = min(400, (_connectedDevice?.mtuNow ?? 23) - 3);
      if (bytes.length <= maxWrite) {
        await _controlChar!.write(bytes, withoutResponse: false);
      } else {
        final size = min(300, maxWrite - 4);
        final count = (bytes.length / size).ceil();
        if (bytes.length > 3072 || count > 12) return false;
        for (var index = 0; index < count; index++) {
          final end = min(bytes.length, (index + 1) * size);
          await _controlChar!.write([0x5a, 0x48, index, count, ...bytes.sublist(index * size, end)],
              withoutResponse: false);
        }
      }
      return await ack.future.timeout(const Duration(seconds: 3), onTimeout: () => false);
    } finally {
      await sub.cancel();
    }
  }

  String _generateRandomNonce(int length) {
    const chars = '0123456789abcdef';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> disconnect() async {
    _idleDisconnectTimer?.cancel();
    _idleDisconnectTimer = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    _expectedHubProof = null;
    _bootNonce = null;
    await _statusCharSub?.cancel();
    _statusCharSub = null;
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.complete(false);
      _authCompleter = null;
    }
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _controlChar = null;
    _statusChar = null;
    _isConnected = false;
    _isAuthenticated = false;
    _bleAuthenticatedController.add(false);
  }
}
