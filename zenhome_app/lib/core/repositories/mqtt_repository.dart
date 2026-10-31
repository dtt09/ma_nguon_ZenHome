import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:zenhome_app/core/services/logger_service.dart';

class MqttRepository {
  MqttServerClient? client;
  final List<Map<String, String>> _cmdQueue = [];
  Timer? _silentRetryTimer;
  Timer? _heartbeatWatchdogTimer;

  // Streams to notify Riverpod providers
  final _connectionStateController = StreamController<int>.broadcast();
  final _espOnlineController = StreamController<bool>.broadcast();
  final _indoorTempController = StreamController<String>.broadcast();
  final _notificationController = StreamController<String>.broadcast();
  final _deviceStateController = StreamController<Map<String, bool>>.broadcast();
  final _otaProgressController = StreamController<Map<String, dynamic>>.broadcast();
  final _otaResultController = StreamController<Map<String, dynamic>>.broadcast();
  final _setupMessageController = StreamController<Map<String, String>>.broadcast();
  
  StreamSubscription? _updatesSubscription;

  Stream<int> get connectionStateStream => _connectionStateController.stream;
  Stream<bool> get espOnlineStream => _espOnlineController.stream;
  Stream<String> get indoorTempStream => _indoorTempController.stream;
  Stream<String> get notificationStream => _notificationController.stream;
  Stream<Map<String, bool>> get deviceStateStream => _deviceStateController.stream;
  Stream<Map<String, dynamic>> get otaProgressStream => _otaProgressController.stream;
  Stream<Map<String, dynamic>> get otaResultStream => _otaResultController.stream;
  Stream<Map<String, String>> get setupMessageStream => _setupMessageController.stream;

  bool _isHardDisconnected = false;
  bool get isHardDisconnected => _isHardDisconnected;

  bool _isEspOnline = false;
  bool get isEspOnline => _isEspOnline;

  Future<void> connect({
    required String userId,
    required String mqttServer,
    required String mqttPrefix,
    required List<String> dynamicTopics,
    String? mqttUser,
    String? mqttPass,
  }) async {
    if (userId == 'guest' || mqttPrefix.endsWith('/unknown_mac')) {
      LoggerService.w('Tạm ngưng kết nối MQTT do là guest hoặc chưa liên kết thiết bị.');
      _connectionStateController.add(0);
      return;
    }
    _connectionStateController.add(1);
    _isIntentionalDisconnect = false;
    String safeId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    // Rút gọn safeId nếu quá dài để tránh vượt giới hạn độ dài của một số MQTT Broker
    if (safeId.length > 10) safeId = safeId.substring(0, 10);
    String clientId = 'app_${safeId}_${DateTime.now().millisecondsSinceEpoch}';
    
    client = MqttServerClient(mqttServer, clientId);
    client!.port = 8883; // HiveMQ Cloud yêu cầu bảo mật TLS
    client!.secure = true;
    client!.securityContext = SecurityContext.defaultContext;
    client!.useWebSocket = false;
    client!.logging(on: false);
    client!.keepAlivePeriod = 30; // Giảm xuống 30s để phát hiện mất kết nối nhanh hơn
    client!.autoReconnect = true;
    client!.resubscribeOnAutoReconnect = true;

    client!.onDisconnected = _onDisconnected;
    client!.onAutoReconnected = () => _onSuccessfulConnect(mqttPrefix, dynamicTopics);
    
    final connMess = MqttConnectMessage().withClientIdentifier(clientId).startClean();
    client!.connectionMessage = connMess;

    try {
      // Tự động bảo vệ xác thực nếu dùng HiveMQ Cloud
      String effectiveUser = mqttUser ?? '';
      String effectivePass = mqttPass ?? '';
      if (mqttServer.contains('hivemq.cloud')) {
        if (effectiveUser.isEmpty || effectiveUser.startsWith('user_') || effectivePass.isEmpty) {
          effectiveUser = 'DTC_ZenHome';
          effectivePass = 'DTC_ZenHome2103';
        }
      }

      LoggerService.i('Đang kết nối broker MQTT: $mqttServer (TLS/8883) [User: $effectiveUser] ...');
      if (effectiveUser.isNotEmpty && effectivePass.isNotEmpty) {
        await client!.connect(effectiveUser, effectivePass);
      } else {
        await client!.connect();
      }
    } catch (e, stack) {
      LoggerService.e('Lỗi kết nối MQTT', e, stack);
      client!.disconnect();
      _connectionStateController.add(-1);
      return;
    }

    if (client!.connectionStatus!.state == MqttConnectionState.connected) {
      _onSuccessfulConnect(mqttPrefix, dynamicTopics);
    } else {
      _onDisconnected();
    }
  }

  void _onSuccessfulConnect(String mqttPrefix, List<String> dynamicTopics) {
    if (client == null || client!.connectionStatus == null || client!.connectionStatus!.state != MqttConnectionState.connected) {
      LoggerService.w('[MQTT] ⚠️ Chưa đạt trạng thái Connected, tạm hoãn subscribe.');
      return;
    }
    LoggerService.i('Kết nối MQTT thành công!');
    _connectionStateController.add(2);
    _isHardDisconnected = false;
    _silentRetryTimer?.cancel();

    for (String baseTopic in dynamicTopics) {
      try {
        client!.subscribe('$baseTopic/state', MqttQos.atLeastOnce);
      } catch (e) {
        LoggerService.w('[MQTT] ⚠️ Lỗi subscribe: $e');
      }
    }

    try {
      final cleanPrefix = mqttPrefix.replaceAll(':', '');
      client!.subscribe('$mqttPrefix/+/+/state', MqttQos.atLeastOnce);
      if (cleanPrefix != mqttPrefix) {
        client!.subscribe('$cleanPrefix/+/+/state', MqttQos.atLeastOnce);
      }
      client!.subscribe('+/+/+/+/state', MqttQos.atLeastOnce);
    } catch (_) {}
    
    try {
      client!.subscribe('$mqttPrefix/nhiet_do_trong_nha', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/thong_bao', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/esp_status', MqttQos.atLeastOnce);
      client!.subscribe('+/+/esp_status', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/heartbeat', MqttQos.atLeastOnce);
      client!.subscribe('+/+/heartbeat', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/system/ota_progress', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/system/ota_result', MqttQos.atLeastOnce);
      client!.subscribe('+/+/system/ota_progress', MqttQos.atLeastOnce);
      client!.subscribe('+/+/system/ota_result', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/setup/handshake', MqttQos.atLeastOnce);
      client!.subscribe('$mqttPrefix/setup/complete', MqttQos.atLeastOnce);
      // Wildcard subscribe để bắt trọn tín hiệu Setup từ Hub ngay cả khi prefix có sai biệt giữa các nhà
      client!.subscribe('+/+/setup/handshake', MqttQos.atLeastOnce);
      client!.subscribe('+/+/setup/complete', MqttQos.atLeastOnce);
    } catch (e) {
      LoggerService.w('[MQTT] ⚠️ Lỗi subscribe topics: $e');
    }

    _updatesSubscription?.cancel();
    _updatesSubscription = client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      for (var item in c) {
        final recMess = item.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final currentTopic = item.topic;
        final cleanCurrent = currentTopic.toLowerCase();
        final cleanPrefix = mqttPrefix.toLowerCase();
        final cleanPrefixNoColon = cleanPrefix.replaceAll(':', '');
        
        // Cập nhật trạng thái sống còn (Liveness / Online) của ESP32:
        // CHỈ chấp nhận từ topic chuyên trách esp_status hoặc heartbeat, TUYỆT ĐỐI không phán đoán từ retained state
        if (cleanCurrent == '$cleanPrefix/esp_status' || 
            cleanCurrent == '$cleanPrefixNoColon/esp_status' || 
            cleanCurrent.endsWith('/esp_status')) {
          final clean = payload.trim().toLowerCase();
          if (clean == 'online' || clean.startsWith('online')) {
            _isEspOnline = true;
            _espOnlineController.add(true);
            _resetHeartbeatWatchdog();
          } else if (clean == 'offline' || clean.startsWith('offline')) {
            _isEspOnline = false;
            _espOnlineController.add(false);
            _heartbeatWatchdogTimer?.cancel();
          }
        } else if (cleanCurrent == '$cleanPrefix/heartbeat' || 
                   cleanCurrent == '$cleanPrefixNoColon/heartbeat' || 
                   cleanCurrent.endsWith('/heartbeat')) {
          _isEspOnline = true;
          _espOnlineController.add(true);
          _resetHeartbeatWatchdog();
        }

        if (cleanCurrent.endsWith('/setup/handshake')) {
          _setupMessageController.add({
            'topic': 'handshake',
            'payload': payload.trim(),
            'fullTopic': currentTopic,
          });
        } else if (cleanCurrent.endsWith('/setup/complete')) {
          _setupMessageController.add({
            'topic': 'complete',
            'payload': payload.trim(),
            'fullTopic': currentTopic,
          });
        } else if (cleanCurrent == '$cleanPrefix/nhiet_do_trong_nha') {
          _indoorTempController.add(payload.trim());
        } else if (currentTopic == '$mqttPrefix/thong_bao') {
          _notificationController.add('${payload.trim()}|${DateTime.now().millisecondsSinceEpoch}');
        } else if (currentTopic == '$mqttPrefix/system/ota_progress' || currentTopic.endsWith('/system/ota_progress')) {
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            _otaProgressController.add(json);
          } catch (_) {}
        } else if (currentTopic == '$mqttPrefix/system/ota_result' || currentTopic.endsWith('/system/ota_result')) {
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            _otaResultController.add(json);
          } catch (_) {}
        } else if (currentTopic.endsWith('/state')) {
          final parts = currentTopic.split('/');
          if (parts.length >= 2) {
            String devId = parts[parts.length - 2];
            bool isOn = false;
            final trimmed = payload.trim();
            if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
              try {
                final json = jsonDecode(trimmed);
                isOn = json['state'] == 1 || json['state'] == '1' || json['action'] == '1' || json['action'] == 'ON';
              } catch (_) {
                isOn = trimmed.contains('"state":1') || trimmed.contains('"state": 1');
              }
            } else {
              isOn = trimmed == '1';
            }
            _deviceStateController.add({devId: isOn});
          }
        }
      }
    });

    if (_cmdQueue.isNotEmpty) {
      for (var cmd in _cmdQueue) {
        _sendActualPublish(cmd['topic']!, cmd['message']!);
      }
      _cmdQueue.clear();
    }
  }

  void _resetHeartbeatWatchdog() {
    _heartbeatWatchdogTimer?.cancel();
    _heartbeatWatchdogTimer = Timer(const Duration(seconds: 35), () {
      if (_isEspOnline) {
        LoggerService.w('[MQTT] ⚠️ Quá 35s không nhận được Heartbeat từ ESP32 -> Chuyển sang Offline');
        _isEspOnline = false;
        _espOnlineController.add(false);
      }
    });
  }

  /// Đánh dấu ESP32 offline ngay lập tức khi gửi lệnh điều khiển mà phần cứng không phản hồi
  void markEspOffline() {
    if (_isEspOnline) {
      LoggerService.w('[MQTT] ⚠️ Thiết bị ESP32 không phản hồi lệnh -> Đánh dấu Offline ngay lập tức');
      _isEspOnline = false;
      _espOnlineController.add(false);
      _heartbeatWatchdogTimer?.cancel();
    }
  }

  void _onDisconnected() {
    LoggerService.w('Bị ngắt khỏi server MQTT!');
    _isEspOnline = false;
    _espOnlineController.add(false);
    _heartbeatWatchdogTimer?.cancel();
    _connectionStateController.add(-1);
    _silentRetryTimer?.cancel();
    
    if (_isIntentionalDisconnect) return;

    _silentRetryTimer = Timer(const Duration(seconds: 20), () {
      if (client?.connectionStatus?.state != MqttConnectionState.connected) {
        _isHardDisconnected = true;
        _cmdQueue.clear();
        // Cập nhật state để UI hiển thị popup
        _connectionStateController.add(-2); 
      }
    });
  }

  bool _isIntentionalDisconnect = false;

  void publishCmd(String topic, String message) {
    if (client?.connectionStatus?.state != MqttConnectionState.connected) {
      if (!_isHardDisconnected) {
        // Chỉ lưu lệnh cuối cùng cho mỗi topic để tránh spam khi có mạng lại
        final existingIndex = _cmdQueue.indexWhere((cmd) => cmd['topic'] == topic);
        if (existingIndex >= 0) {
          _cmdQueue[existingIndex] = {'topic': topic, 'message': message};
        } else {
          _cmdQueue.add({'topic': topic, 'message': message});
        }
      }
      return;
    }
    _sendActualPublish(topic, message);
  }

  void _sendActualPublish(String topic, String message) {
    try {
      if (client?.connectionStatus?.state == MqttConnectionState.connected) {
        final builder = MqttClientPayloadBuilder();
        builder.addString(message);
        client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      } else {
        _cmdQueue.add({'topic': topic, 'message': message});
      }
    } catch (e) {
      LoggerService.w('[MQTT] Không thể gửi lệnh xuất bản: $e');
    }
  }

  void disconnect() {
    _isIntentionalDisconnect = true;
    _isEspOnline = false;
    _espOnlineController.add(false);
    _heartbeatWatchdogTimer?.cancel();
    _silentRetryTimer?.cancel();
    client?.disconnect();
  }

  void dispose() {
    disconnect();
    _heartbeatWatchdogTimer?.cancel();
    _connectionStateController.close();
    _espOnlineController.close();
    _indoorTempController.close();
    _notificationController.close();
    _deviceStateController.close();
    _otaProgressController.close();
    _otaResultController.close();
    _setupMessageController.close();
  }
}
