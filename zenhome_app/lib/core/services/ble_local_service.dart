import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  BluetoothDevice? _connectedDevice;
  BluetoothDevice? _cachedDiscoveredDevice;
  DateTime? _lastDiscoveredAt;
  BluetoothCharacteristic? _controlChar;
  BluetoothCharacteristic? _statusChar;

  bool _isScanning = false;
  bool _isConnected = false;
  bool _isAuthenticated = false;
  String? _monitoredMac;
  String? _adminPass;
  String? _explicitLocalKey;
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

  /// Phái sinh Master Key chuẩn mã hóa từ adminPass và MAC phần cứng (Đồng bộ với ESP32)
  static String deriveMasterKey({required String mac, String? adminPass}) {
    final effectivePass = (adminPass != null && adminPass.isNotEmpty) ? adminPass : 'admin';
    final clean = mac.replaceAll(':', '').replaceAll('-', '').trim().toUpperCase();
    final keySeed = 'ZenHome_Key_Salt:$effectivePass:$clean';
    return sha256.convert(utf8.encode(keySeed)).toString().toLowerCase();
  }

  /// Lấy khóa bí mật đã lưu hoặc tự động phái sinh từ thông tin cấu hình
  Future<String> _getOrDeriveKey() async {
    if (_explicitLocalKey != null && _explicitLocalKey!.isNotEmpty) {
      return _explicitLocalKey!;
    }
    if (_monitoredMac != null && _monitoredMac!.isNotEmpty && _monitoredMac != 'unknown_mac') {
      try {
        final saved = await _secureStorage.read(key: 'local_sec_key_$_monitoredMac');
        if (saved != null && saved.isNotEmpty) {
          return saved;
        }
      } catch (_) {}
      return deriveMasterKey(mac: _monitoredMac!, adminPass: _adminPass);
    }
    return '';
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
    _adminPass = adminPass;
    _explicitLocalKey = localKey;
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
    _taskQueue.clear();
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
      target.connectionState.listen((state) {
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
              await c.setNotifyValue(true);
              c.onValueReceived.listen((value) {
                _handleStatusNotification(value);
              });
            }
          }
        }
      }

      // Bắt tay xác thực Key
      if (_controlChar != null) {
        await _authenticateWithKey();
        int elapsed = 0;
        while (!_isAuthenticated && elapsed < 3000) {
          await Future.delayed(const Duration(milliseconds: 100));
          elapsed += 100;
        }
      }

      return _isAuthenticated && _controlChar != null;
    } catch (e) {
      LoggerService.w('[BLE] Kết nối trực tiếp thất bại: $e');
      _isConnected = false;
      _isAuthenticated = false;
      return false;
    }
  }

  /// Bắt tay xác thực Key hai chiều (HMAC-SHA256)
  Future<void> _authenticateWithKey() async {
    if (_controlChar == null || _monitoredMac == null) return;
    try {
      final key = await _getOrDeriveKey();
      if (key.isEmpty) {
        LoggerService.w('[BLE-KEY] ⚠️ Không có khóa bảo mật hợp lệ để xác thực BLE!');
        await disconnect();
        return;
      }

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateRandomNonce(8);
      final signPayload = 'auth:$_monitoredMac:$timestamp:$nonce';

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

      await _controlChar!.write(utf8.encode(jsonEncode(authMap)), withoutResponse: false);
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
        if (json['status'] == 'auth_ok' || json['authenticated'] == true) {
          _isAuthenticated = true;
          _bleAuthenticatedController.add(true);
          _bleAvailableController.add(true);
          LoggerService.i('[BLE-KEY] 🔐 Hub đã xác nhận Key thành công! Kênh BLE sẵn sàng.');
        }

        if (json.containsKey('id') && json.containsKey('state')) {
          final devId = json['id'].toString();
          final state = json['state'].toString() == '1';
          _bleDeviceStateController.add({devId: state});
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

    // Queue Collapsing (Chống spam hàng đợi BLE):
    // Nếu trong hàng đợi đã có lệnh cho cùng thiết bị này chưa kịp gửi,
    // gom lệnh cũ lại và thay bằng lệnh mới nhất để chỉ bắn 1 gói tin cuối cùng tới ESP32
    _taskQueue.removeWhere((task) {
      if (task.type == _BleTaskType.control && task.devId == devId) {
        if (!task.completer.isCompleted) task.completer.complete(true);
        return true;
      }
      return false;
    });

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
      final key = localKey ?? await _getOrDeriveKey();
      if (key.isEmpty) return false;
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateRandomNonce(8);
      final user = _userId ?? 'owner';

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
      await _controlChar!.write(jsonBytes, withoutResponse: false);

      _bleDeviceStateController.add({devId: cmd == '1'});
      LoggerService.i('[BLE-QUEUE] ⚡ Lệnh $devId -> $cmd đã bắn thành công qua BLE (Mã hóa AES-256 & HMAC-SHA256)!');
      return true;
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
      final key = localKey ?? await _getOrDeriveKey();
      if (key.isEmpty) return false;
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final nonce = _generateRandomNonce(8);
      final user = _userId ?? 'owner';
      final newSsid = data['ssid'] ?? '';

      final signPayload = 'reconfig:$newSsid:$timestamp:$nonce';
      final keyBytes = <int>[];
      for (int i = 0; i < key.length; i += 2) {
        keyBytes.add(int.parse(key.substring(i, i + 2), radix: 16));
      }
      final signature = Hmac(sha256, keyBytes).convert(utf8.encode(signPayload)).toString();

      final Map<String, dynamic> payloadMap = {
        'action': 'reconfig',
        'wifi_ssid': newSsid,
        'wifi_pass': data['pass'] ?? '',
        if (data['server'] != null && data['server'].toString().isNotEmpty) 'mqtt_server': data['server'],
        if (data['adminPass'] != null && data['adminPass'].toString().isNotEmpty) 'admin_pass': data['adminPass'],
        'user': user,
        'sig': signature,
        'ts': timestamp,
        'nonce': nonce,
      };

      final jsonBytes = utf8.encode(jsonEncode(payloadMap));
      await _controlChar!.write(jsonBytes, withoutResponse: false);
      LoggerService.i('[BLE-RECONFIG] 📡 Đã gửi bản tin cấu hình Wi-Fi mới qua BLE!');
      return true;
    } catch (e) {
      LoggerService.w('[BLE-RECONFIG] Bắn bản tin reconfig qua BLE thất bại: $e');
      return false;
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
