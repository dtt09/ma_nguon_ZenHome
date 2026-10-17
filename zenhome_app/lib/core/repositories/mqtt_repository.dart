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

  // Streams to notify Riverpod providers
  final _connectionStateController = StreamController<int>.broadcast();
  final _espOnlineController = StreamController<bool>.broadcast();
  final _indoorTempController = StreamController<String>.broadcast();
  final _notificationController = StreamController<String>.broadcast();
  final _deviceStateController = StreamController<Map<String, bool>>.broadcast();
  
  StreamSubscription? _updatesSubscription;

  Stream<int> get connectionStateStream => _connectionStateController.stream;
  Stream<bool> get espOnlineStream => _espOnlineController.stream;
  Stream<String> get indoorTempStream => _indoorTempController.stream;
  Stream<String> get notificationStream => _notificationController.stream;
  Stream<Map<String, bool>> get deviceStateStream => _deviceStateController.stream;

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
      LoggerService.i('Đang kết nối broker MQTT: $mqttServer (TLS/8883) ...');
      if (mqttUser != null && mqttUser.isNotEmpty && mqttPass != null && mqttPass.isNotEmpty) {
        await client!.connect(mqttUser, mqttPass);
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
    LoggerService.i('Kết nối MQTT thành công!');
    _connectionStateController.add(2);
    _isHardDisconnected = false;
    _silentRetryTimer?.cancel();

    for (String baseTopic in dynamicTopics) {
      client!.subscribe('$baseTopic/state', MqttQos.atLeastOnce);
    }
    
    client!.subscribe('$mqttPrefix/nhiet_do_trong_nha', MqttQos.atLeastOnce);
    client!.subscribe('$mqttPrefix/thong_bao', MqttQos.atLeastOnce);
    client!.subscribe('$mqttPrefix/esp_status', MqttQos.atLeastOnce);

    _updatesSubscription?.cancel();
    _updatesSubscription = client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      for (var item in c) {
        final recMess = item.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        final currentTopic = item.topic;
        
        if (currentTopic.startsWith(mqttPrefix)) {
          if (currentTopic == '$mqttPrefix/esp_status') {
            _isEspOnline = (payload.trim() == 'online');
            _espOnlineController.add(_isEspOnline);
          } else {
            _isEspOnline = true;
            _espOnlineController.add(true);
          }
        }
        
        if (currentTopic == '$mqttPrefix/nhiet_do_trong_nha') {
          _indoorTempController.add(payload.trim());
        } else if (currentTopic == '$mqttPrefix/thong_bao') {
          _notificationController.add('${payload.trim()}|${DateTime.now().millisecondsSinceEpoch}');
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

  void _onDisconnected() {
    LoggerService.w('Bị ngắt khỏi server MQTT!');
    _isEspOnline = false;
    _espOnlineController.add(false);
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
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client?.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void disconnect() {
    _isIntentionalDisconnect = true;
    _isEspOnline = false;
    _silentRetryTimer?.cancel();
    client?.disconnect();
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _espOnlineController.close();
    _indoorTempController.close();
    _notificationController.close();
    _deviceStateController.close();
  }
}
