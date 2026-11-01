#include "mqtt_manager.h"
#include "config_manager.h"
#include "security_manager.h"
#include "hardware_manager.h"
#include "network_manager.h"
#include "ble_manager.h"

#include <WiFi.h>
#include <HTTPClient.h>
#include <Update.h>
#include <esp_task_wdt.h>
#include <mbedtls/md.h>

WiFiClientSecure espClient;
PubSubClient mqttClient(espClient);
bool wasMqttPreviouslyConnected = false;
unsigned long lastMQTTRetry = 0;
bool isBindingVerified = false;
static unsigned long currentMqttRetryInterval = 5000; // Khởi đầu thử lại sau 5s

void initMqttClient() {
  espClient.setInsecure(); // Sử dụng TLS Encryption (Port 8883) tương thích HiveMQ Cloud cross-signed chain
  espClient.setTimeout(15); // 15 giây timeout cho phiên bắt tay TLS
  mqttClient.setServer(mqtt_server.c_str(), 8883);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(1024);
  mqttClient.setKeepAlive(15); // Giảm KeepAlive xuống 15s (Broker kích hoạt LWT 'offline' sau tối đa 22s khi mất điện)
  mqttClient.setSocketTimeout(15); // 15 giây timeout cho MQTT CONNACK và Ping
}

/**
 * Xác thực đồng nhất User & MAC giữa ESP32 và Database Firestore
 * Nếu Database báo không khớp (đã hủy liên kết hoặc gán MAC khác) -> reset về AP Setup.
 * Chỉ khi hợp lệ mới cho phép kết nối MQTT!
 */
bool verifyBindingWithDatabase() {
  if (WiFi.status() != WL_CONNECTED) return false;

  int slashIdx = mqtt_prefix.indexOf('/');
  if (slashIdx <= 0) {
    Serial.println("[VERIFY] ⛔ mqtt_prefix không hợp lệ: " + mqtt_prefix);
    resetToFactoryDefaults();
    delay(500);
    ESP.restart();
    return false;
  }

  String linkedUser = mqtt_prefix.substring(0, slashIdx);
  linkedUser.trim();
  String myMac = WiFi.macAddress();
  String cleanHwMac = myMac;
  cleanHwMac.replace(":", "");
  cleanHwMac.replace("-", "");
  cleanHwMac.toUpperCase();

  static unsigned long lastVerifyLogTime = 0;
  if (millis() - lastVerifyLogTime >= 15000) {
    lastVerifyLogTime = millis();
    Serial.println("\n[VERIFY] 🔍 Đang xác thực User [" + linkedUser + "] và MAC [" + cleanHwMac + "] với Database...");
  }

  // Thử các địa chỉ Server ứng viên
  String candidates[3];
  int candidateCount = 0;
  if (server_url.length() > 5) {
    candidates[candidateCount++] = server_url;
  }
  candidates[candidateCount++] = "http://" + WiFi.gatewayIP().toString() + ":5000";
  candidates[candidateCount++] = "http://192.168.1.9:5000";

  bool serverResponded = false;
  HTTPClient http;

  for (int i = 0; i < candidateCount; i++) {
    esp_task_wdt_reset();
    String verifyUrl = candidates[i] + "/api/v1/hub/verify-binding?userId=" + linkedUser + 
                       "&macAddress=" + cleanHwMac + 
                       "&setup=" + (isSetupPending ? "1" : "0") + 
                       "&adminPass=" + admin_pass;
    http.begin(verifyUrl);
    http.setTimeout(3500);
    int httpCode = http.GET();

    if (httpCode == 200) {
      serverResponded = true;
      String resPayload = http.getString();
      http.end();

      DynamicJsonDocument resDoc(512);
      DeserializationError err = deserializeJson(resDoc, resPayload);
      if (!err && resDoc.containsKey("valid")) {
        bool isValid = resDoc["valid"].as<bool>();
        if (isValid) {
          Serial.println("[VERIFY] ✅ XÁC THỰC THÀNH CÔNG: User và MAC hợp lệ với Database!");
          isBindingVerified = true;
          return true;
        } else {
          String reason = resDoc.containsKey("reason") ? resDoc["reason"].as<String>() : "UNKNOWN";
          String msg = resDoc.containsKey("message") ? resDoc["message"].as<String>() : "";
          Serial.println("\n[BẢO MẬT] ❌ XÁC THỰC THẤT BẠI TRÊN DATABASE!");
          Serial.println("[BẢO MẬT] ❌ Lý do: " + reason + " - " + msg);

          // Nếu đang trong giai đoạn Setup xác nhận (90s) và Database tạm thời báo UNLINKED:
          // Không xóa cấu hình ngay lập tức mà để vòng lặp Setup 90s tiếp tục chờ hoặc xử lý timeout!
          if (isSetupPending && reason == "UNLINKED_IN_DATABASE") {
            Serial.println("[SETUP] ⏳ Đang trong 90s Setup: Chờ App/Database hoàn tất ghi dữ liệu...");
            return false;
          }

          Serial.println("[BẢO MẬT] 🔄 Tài khoản trên Database không hợp lệ hoặc sai khác phần cứng.");
          Serial.println("[BẢO MẬT] 👉 Reset toàn bộ cấu hình ESP32 và quay về chế độ AP Setup...\n");
          resetToFactoryDefaults();
          delay(600);
          ESP.restart();
          return false;
        }
      }
      break;
    }
    http.end();
  }

  // Nếu Server nội bộ chưa phản hồi (máy tính tắt server hoặc kết nối trực tiếp HiveMQ Cloud):
  if (!serverResponded) {
    Serial.println("[VERIFY] ℹ️ Server nội bộ chưa phản hồi. Kiểm tra tính toàn vẹn cục bộ...");
    String prefixMac = mqtt_prefix.substring(slashIdx + 1);
    prefixMac.replace(":", "");
    prefixMac.replace("-", "");
    prefixMac.toUpperCase();

    if (prefixMac == cleanHwMac && linkedUser.length() > 0 && linkedUser != "guest" && prefixMac != "UNKNOWN_MAC") {
      Serial.println("[VERIFY] ⚠️ Cục bộ hợp lệ (User: " + linkedUser + ", MAC: " + cleanHwMac + "). Cho phép kết nối MQTT.");
      isBindingVerified = true;
      return true;
    } else {
      Serial.println("[VERIFY] ⛔ MAC trong cấu hình không khớp phần cứng! Hủy cấu hình về AP Setup.");
      resetToFactoryDefaults();
      delay(500);
      ESP.restart();
      return false;
    }
  }

  return false;
}

void connectMQTT() {
  static bool isConnectingMqtt = false;
  if (isConnectingMqtt) return;
  isConnectingMqtt = true;

  // BƯỚC 1: XÁC THỰC VỚI DATABASE TRƯỚC KHI KẾT NỐI MQTT
  if (!isBindingVerified) {
    if (!verifyBindingWithDatabase()) {
      isConnectingMqtt = false;
      return;
    }
  }

  Serial.println("\n[MQTT] 📡 Đang kết nối MQTT TLS (8883) tới: " + mqtt_server + " (User: " + mqtt_user + ")");
  Serial.printf("[MQTT] ℹ️ Bộ nhớ Heap khả dụng: %u bytes\n", ESP.getFreeHeap());
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  String clientId = "ESP32_" + mac;
  String statusTopic = mqtt_prefix + "/esp_status";

  // Dọn dẹp triệt để TLS Socket cũ trước khi khởi tạo phiên bắt tay mới
  if (espClient.connected()) {
    espClient.stop();
    delay(50);
  }
  espClient.setInsecure(); // Bỏ qua kiểm tra độ sâu chuỗi chứng chỉ trung gian YR1 nhưng vẫn mã hóa TLS AES-256

  bool connected = false;
  if (mqtt_user != "" && mqtt_pass != "") {
    connected = mqttClient.connect(clientId.c_str(), mqtt_user.c_str(), mqtt_pass.c_str(), statusTopic.c_str(), 1, true, "offline");
  } else {
    connected = mqttClient.connect(clientId.c_str(), statusTopic.c_str(), 1, true, "offline");
  }

  if (connected) {
    Serial.println("[MQTT] ✅ Kết nối MQTT TLS Thành công!");
    currentMqttRetryInterval = 5000; // Reset khoảng thời gian thử lại về 5s

    // NẾU ĐANG TRONG GIAI ĐOẠN SETUP LIÊN KẾT:
    // ESP32 CHƯA MỞ KHÓA TÍNH NĂNG VỘI MÀ BẮT TÍN HIỆU (HANDSHAKE) CHO APP VÀ CHỜ PHẢN HỒI XÁC NHẬN!
    if (isSetupPending) {
      Serial.println("\n[SETUP] ☁️ ĐÃ KẾT NỐI MQTT CLOUD LẦN ĐẦU THÀNH CÔNG!");
      Serial.println("[SETUP] 📡 Bắt đầu phát tín hiệu Handshake cho App và đăng ký chờ phản hồi xác nhận...");

      String setupConfirmTopic = mqtt_prefix + "/setup/confirm";
      mqttClient.subscribe(setupConfirmTopic.c_str(), 1);
      mqttClient.subscribe("+/+/setup/confirm", 1);

      sendSetupHandshakeBeacon();
      isConnectingMqtt = false;
      return;
    }
    
    if (isPowerOutageBoot) {
      Serial.println("\n[HỆ THỐNG] ⚡ Báo cáo sự kiện: CÓ ĐIỆN LẠI SAU MẤT ĐIỆN (Tắt toàn bộ thiết bị)");
      mqttClient.publish(statusTopic.c_str(), "online_power_restored", true);

      String eventTopic = mqtt_prefix + "/system/event";
      mqttClient.publish(eventTopic.c_str(), "{\"event\":\"power_restored\",\"action\":\"all_off\",\"reason\":\"power_outage\"}", false);

      for (int i = 0; i < relayCount; i++) {
        String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
        String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
        mqttClient.publish(stateTopic.c_str(), "0", true);
      }
      if (LittleFS.exists("/offline_backup.json")) {
        LittleFS.remove("/offline_backup.json");
      }
      hasOfflineBackup = false;
      isPowerOutageBoot = false;
    } else {
      Serial.println("\n[HỆ THỐNG] 🌐 Báo cáo sự kiện: CÓ MẠNG LẠI SAU MẤT MẠNG (Đồng bộ trạng thái lần cuối)");
      mqttClient.publish(statusTopic.c_str(), "online", true);

      String eventTopic = mqtt_prefix + "/system/event";
      mqttClient.publish(eventTopic.c_str(), "{\"event\":\"network_restored\",\"action\":\"sync_last_state\",\"reason\":\"network_loss\"}", false);

      StaticJsonDocument<512> syncDoc;
      syncDoc["mac"] = mac;
      syncDoc["event"] = "network_restored";
      JsonArray relayArr = syncDoc.createNestedArray("relays");
      for (int i = 0; i < relayCount; i++) {
        String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
        String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
        mqttClient.publish(stateTopic.c_str(), myRelays[i].state.c_str(), true);

        JsonObject rObj = relayArr.createNestedObject();
        rObj["id"] = myRelays[i].id;
        rObj["state"] = myRelays[i].state;
        rObj["room"] = rName;
      }
      String syncPayload;
      serializeJson(syncDoc, syncPayload);
      String syncReportTopic = mqtt_prefix + "/sync/report";
      mqttClient.publish(syncReportTopic.c_str(), syncPayload.c_str(), false);

      if (LittleFS.exists("/offline_backup.json")) {
        LittleFS.remove("/offline_backup.json");
      }
      hasOfflineBackup = false;
      Serial.println("[SYNC] ✅ Đã đẩy tín hiệu backup trạng thái lần cuối lên Cloud & xóa backup tạm trên ESP32!");
    }

    String listenTopic = mqtt_prefix + "/+/+/cmd";
    mqttClient.subscribe(listenTopic.c_str());
    String cleanMacPrefix = mqtt_prefix;
    cleanMacPrefix.replace(":", "");
    String cleanListenTopic = cleanMacPrefix + "/+/+/cmd";
    if (cleanListenTopic != listenTopic) {
      mqttClient.subscribe(cleanListenTopic.c_str());
    }
    
    String systemConfigTopic = mqtt_prefix + "/system/config";
    mqttClient.subscribe(systemConfigTopic.c_str());

    String systemResetTopic = mqtt_prefix + "/system/reset";
    mqttClient.subscribe(systemResetTopic.c_str());

    String systemRebootTopic = mqtt_prefix + "/system/reboot";
    String systemRestartTopic = mqtt_prefix + "/system/restart";
    mqttClient.subscribe(systemRebootTopic.c_str());
    mqttClient.subscribe(systemRestartTopic.c_str());

    String systemOtaTopic = mqtt_prefix + "/system/ota_update";
    mqttClient.subscribe(systemOtaTopic.c_str());
    String cleanMacOtaTopic = mqtt_prefix;
    cleanMacOtaTopic.replace(":", "");
    cleanMacOtaTopic += "/system/ota_update";
    if (cleanMacOtaTopic != systemOtaTopic) {
      mqttClient.subscribe(cleanMacOtaTopic.c_str());
    }

    String systemMembersTopic = mqtt_prefix + "/system/members";
    mqttClient.subscribe(systemMembersTopic.c_str());

    // Phát Heartbeat ban đầu thông báo phiên bản Firmware ngay khi kết nối
    {
      String heartbeatTopic = mqtt_prefix + "/heartbeat";
      StaticJsonDocument<256> hbDoc;
      hbDoc["online"] = true;
      hbDoc["uptime"] = millis() / 1000;
      hbDoc["heap"] = ESP.getFreeHeap();
      hbDoc["version"] = FIRMWARE_VERSION_STR;
      hbDoc["build"] = FIRMWARE_BUILD_NUM;
      String hbPayload;
      serializeJson(hbDoc, hbPayload);
      mqttClient.publish(heartbeatTopic.c_str(), hbPayload.c_str(), false);
      String cleanP = mqtt_prefix;
      cleanP.replace(":", "");
      if (cleanP != mqtt_prefix) {
        String cleanHbTopic = cleanP + "/heartbeat";
        mqttClient.publish(cleanHbTopic.c_str(), hbPayload.c_str(), false);
      }
    }

    publishHomeAssistantDiscovery();
  } else {
    int state = mqttClient.state();
    unsigned long now = millis();
    static int lastReportedMqttState = 999;
    static unsigned long lastMqttErrorLogTime = 0;

    if (state != lastReportedMqttState || (now - lastMqttErrorLogTime >= 30000)) {
      lastReportedMqttState = state;
      lastMqttErrorLogTime = now;
      Serial.printf("[MQTT] ❌ LỖI kết nối MQTT! Mã lỗi (rc): %d", state);
      if (state == -4) {
        Serial.println(" (MQTT_CONNECTION_TIMEOUT: Quá thời gian bắt tay TLS hoặc chờ phản hồi từ HiveMQ Cloud)");
        Serial.println("[MQTT] 🔄 Giải phóng socket TLS và sẽ thử lại với thời gian thích ứng...");
      } else if (state == -2) {
        char errBuf[128] = {0};
        espClient.lastError(errBuf, sizeof(errBuf));
        Serial.printf(" (MQTT_CONNECT_FAILED: Lỗi kết nối Socket TCP/TLS - %s)\n", errBuf);
      } else if (state == 4 || state == 5) {
        Serial.println(" (MQTT_UNAUTHORIZED: Sai tên đăng nhập hoặc mật khẩu)");
      } else {
        Serial.println();
      }
    }
    // Dọn dẹp sạch socket để không bị nghẽn ở lần thử tiếp theo
    mqttClient.disconnect();
    espClient.stop();
  }

  isConnectingMqtt = false;
}

void checkMqttConnection() {
  unsigned long currentMillis = millis();

  // 1. Tự phục hồi TLS Socket MQTT khi mất kết nối kéo dài (Làm mới Socket, KHÔNG reboot phần cứng)
  static unsigned long mqttDisconnectStartTime = 0;
  if (isConfigured && isProvisioned && WiFi.status() == WL_CONNECTED && !mqttClient.connected()) {
    if (mqttDisconnectStartTime == 0) mqttDisconnectStartTime = currentMillis;
    if (currentMillis - mqttDisconnectStartTime >= 60000) {
      Serial.println("[MQTT] 🔄 Làm mới kết nối TLS Socket...");
      mqttClient.disconnect();
      espClient.stop();
      mqttDisconnectStartTime = currentMillis;
    }
  } else {
    mqttDisconnectStartTime = 0;
  }

  // 2. Duy trì kết nối MQTT với Adaptive Backoff chống chập chờn
  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      if (wasMqttPreviouslyConnected) {
        Serial.println("\n[MẠNG] ⚠️ Phát hiện mất kết nối MQTT trong khi nguồn điện vẫn duy trì!");
        wasMqttPreviouslyConnected = false;
      }
      if (currentMillis - lastMQTTRetry >= currentMqttRetryInterval) {
        lastMQTTRetry = currentMillis;
        connectMQTT();
        if (!mqttClient.connected()) {
          // Tăng khoảng thời gian thử lại: 5s -> 10s -> 20s -> tối đa 35s
          currentMqttRetryInterval = min(currentMqttRetryInterval * 2, 35000UL);
          static unsigned long lastRetryLogTime = 0;
          if (currentMillis - lastRetryLogTime >= 30000) {
            lastRetryLogTime = currentMillis;
            Serial.printf("[MQTT] ⏳ Sẽ tự động thử lại sau %lu giây...\n", currentMqttRetryInterval / 1000);
          }
        }
      }
    } else {
      wasMqttPreviouslyConnected = true;
      mqttClient.loop();

      // Định kỳ gửi Heartbeat mỗi 15s để App và Broker luôn nhận biết ESP32 đang hoạt động thực tế
      static unsigned long lastHeartbeatTime = 0;
      if (currentMillis - lastHeartbeatTime >= 15000) {
        lastHeartbeatTime = currentMillis;
        String heartbeatTopic = mqtt_prefix + "/heartbeat";
        StaticJsonDocument<256> hbDoc;
        hbDoc["online"] = true;
        hbDoc["uptime"] = millis() / 1000;
        hbDoc["heap"] = ESP.getFreeHeap();
        hbDoc["version"] = FIRMWARE_VERSION_STR;
        hbDoc["build"] = FIRMWARE_BUILD_NUM;
        String hbPayload;
        serializeJson(hbDoc, hbPayload);
        mqttClient.publish(heartbeatTopic.c_str(), hbPayload.c_str(), false);
        String cleanP = mqtt_prefix;
        cleanP.replace(":", "");
        if (cleanP != mqtt_prefix) {
          String cleanHbTopic = cleanP + "/heartbeat";
          mqttClient.publish(cleanHbTopic.c_str(), hbPayload.c_str(), false);
        }
      }
    }
  }
}

void sendSetupHandshakeBeacon() {
  if (!mqttClient.connected() || !isSetupPending) return;

  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();

  StaticJsonDocument<256> doc;
  doc["mac"] = mac;
  doc["status"] = "ready_confirm";
  doc["ip"] = WiFi.localIP().toString();
  doc["uptime"] = millis() / 1000;

  String payload;
  serializeJson(doc, payload);

  String setupHandshakeTopic = mqtt_prefix + "/setup/handshake";
  mqttClient.publish(setupHandshakeTopic.c_str(), payload.c_str(), false);
  Serial.println("[SETUP] 📡 Đã phát tín hiệu Handshake tới App: " + setupHandshakeTopic);
}

void unlockAllFeatures() {
  Serial.println("\n========================================================");
  Serial.println("[SETUP] 🎉 HOÀN TẤT THIẾT LẬP! MỞ KHÓA TOÀN BỘ TÍNH NĂNG!");
  Serial.println("========================================================");

  // 1. Khởi tạo công tắc cơ gắn tường
  setupPhysicalSwitches();

  // 2. Khởi tạo BLE Zero-Touch (chế độ sẵn sàng)
  setupBLE();

  // 3. Khởi tạo Web Server nội bộ & UDP Discovery nếu đã có Wi-Fi
  if (WiFi.status() == WL_CONNECTED && !isWebServerStarted) {
    setupStationWebServer();
    setupUdpDiscovery();
    isWebServerStarted = true;
  }

  // 4. Báo cáo trạng thái online lên Cloud
  String statusTopic = mqtt_prefix + "/esp_status";
  mqttClient.publish(statusTopic.c_str(), "online", true);

  String eventTopic = mqtt_prefix + "/system/event";
  mqttClient.publish(eventTopic.c_str(), "{\"event\":\"setup_completed\",\"status\":\"unlocked\"}", false);

  // 5. Đăng ký toàn bộ topic điều khiển & quản trị
  String listenTopic = mqtt_prefix + "/+/+/cmd";
  mqttClient.subscribe(listenTopic.c_str());

  String systemConfigTopic = mqtt_prefix + "/system/config";
  mqttClient.subscribe(systemConfigTopic.c_str());

  String systemResetTopic = mqtt_prefix + "/system/reset";
  mqttClient.subscribe(systemResetTopic.c_str());

  String systemRebootTopic = mqtt_prefix + "/system/reboot";
  String systemRestartTopic = mqtt_prefix + "/system/restart";
  mqttClient.subscribe(systemRebootTopic.c_str());
  mqttClient.subscribe(systemRestartTopic.c_str());

  String systemOtaTopic = mqtt_prefix + "/system/ota_update";
  mqttClient.subscribe(systemOtaTopic.c_str());
  String cleanMacOtaTopic = mqtt_prefix;
  cleanMacOtaTopic.replace(":", "");
  cleanMacOtaTopic += "/system/ota_update";
  if (cleanMacOtaTopic != systemOtaTopic) {
    mqttClient.subscribe(cleanMacOtaTopic.c_str());
  }

  String systemMembersTopic = mqtt_prefix + "/system/members";
  mqttClient.subscribe(systemMembersTopic.c_str());

  // 6. Phát hiện Home Assistant
  publishHomeAssistantDiscovery();

  // 7. Đồng bộ trạng thái Relay ban đầu (Tắt an toàn)
  for (int i = 0; i < relayCount; i++) {
    String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
    String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
    mqttClient.publish(stateTopic.c_str(), "0", true);
  }
}

void revertToAPMode(const String& reason) {
  Serial.println("\n========================================================");
  Serial.println("[SETUP-TIMEOUT] ⚠️ HỦY THIẾT LẬP VÀ TỰ ĐỘNG VỀ CHẾ ĐỘ AP SETUP!");
  Serial.println("[SETUP-TIMEOUT] 👉 Lý do: " + reason);
  Serial.println("[SETUP-TIMEOUT] 🔄 Đang xóa cấu hình tạm và khởi động lại...");
  Serial.println("========================================================");

  if (LittleFS.exists("/setup_pending.txt")) LittleFS.remove("/setup_pending.txt");
  if (LittleFS.exists("/provisioned.txt")) LittleFS.remove("/provisioned.txt");
  if (LittleFS.exists("/config.json")) LittleFS.remove("/config.json");

  isProvisioned = false;
  isConfigured = false;
  isSetupPending = false;

  delay(600);
  ESP.restart();
}

static bool hasWifiConnectedInSetup = false;
static unsigned long wifiConnectedStartTime = 0;
static bool hasMqttConnectedInSetup = false;

void checkSetupTimeout() {
  if (!isSetupPending) return;

  unsigned long currentMillis = millis();
  unsigned long elapsedTotal = currentMillis - setupPhaseStartTime;

  // 1. Theo dõi kết nối Wi-Fi lần đầu
  if (WiFi.status() == WL_CONNECTED) {
    if (!hasWifiConnectedInSetup) {
      hasWifiConnectedInSetup = true;
      wifiConnectedStartTime = currentMillis;
      Serial.println("\n[SETUP] 🌐 ĐÃ KẾT NỐI WI-FI LẦN ĐẦU THÀNH CÔNG! IP: " + WiFi.localIP().toString());
    }
  }

  // 2. Theo dõi kết nối MQTT Cloud lần đầu
  if (mqttClient.connected()) {
    if (!hasMqttConnectedInSetup) {
      hasMqttConnectedInSetup = true;
      Serial.println("[SETUP] ☁️ ĐÃ KẾT NỐI MQTT CLOUD LẦN ĐẦU THÀNH CÔNG!");
    }
  }

  // TRƯỜNG HỢP 1: Không thể kết nối Wi-Fi lần đầu sau 60 giây (Sai mật khẩu hoặc mất sóng)
  if (!hasWifiConnectedInSetup && (elapsedTotal >= SETUP_WIFI_TIMEOUT_MS)) {
    revertToAPMode("Không thể kết nối Wi-Fi lần đầu sau 60s (Sai mật khẩu hoặc sóng Wi-Fi yếu)");
    return;
  }

  // TRƯỜNG HỢP 2: Đã có Wi-Fi nhưng không thể kết nối MQTT Cloud sau 60 giây (Mất Internet hoặc Broker lỗi)
  if (hasWifiConnectedInSetup && !hasMqttConnectedInSetup && (currentMillis - wifiConnectedStartTime >= SETUP_MQTT_TIMEOUT_MS)) {
    revertToAPMode("Không thể kết nối MQTT Cloud lần đầu sau 60s (Mạng không có Internet hoặc Broker lỗi)");
    return;
  }

  // TRƯỜNG HỢP 3: Hết tổng thời gian 3 phút mà không nhận được phản hồi confirm từ App
  if (elapsedTotal >= SETUP_PHASE_TIMEOUT_MS) {
    revertToAPMode("Hết tổng thời gian chờ xác nhận từ App (Timeout 3 phút)");
    return;
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message((char*)payload, length);
  String topicStr = String(topic);

  // Lệnh xác nhận thiết lập từ App (Setup Handshake Confirm)
  String setupConfirmTopic = mqtt_prefix + "/setup/confirm";
  if ((topicStr == setupConfirmTopic || topicStr.endsWith("/setup/confirm")) && isSetupPending) {
    Serial.println("\n[SETUP] 🤝 ĐÃ NHẬN TÍN HIỆU PHẢN HỒI XÁC NHẬN TỪ APP: " + topicStr);

    DynamicJsonDocument confirmDoc(256);
    DeserializationError cErr = deserializeJson(confirmDoc, message);
    bool isConfirmed = (!cErr && confirmDoc.containsKey("confirm")) ? confirmDoc["confirm"].as<bool>() : true;

    if (isConfirmed) {
      // Tự động đồng bộ userId theo App nếu có
      if (!cErr && confirmDoc.containsKey("userId")) {
        String newUid = confirmDoc["userId"].as<String>();
        if (newUid.length() > 0 && newUid != "guest") {
          String curMac = WiFi.macAddress();
          mqtt_prefix = newUid + "/" + curMac;
          Serial.println("[SETUP] 🔄 Đã đồng bộ mqtt_prefix theo App: " + mqtt_prefix);
        }
      }
      // 1. Gỡ cờ pending và tạo provisioned.txt
      isSetupPending = false;
      if (LittleFS.exists("/setup_pending.txt")) {
        LittleFS.remove("/setup_pending.txt");
      }
      isProvisioned = true;
      isConfigured = true;
      File provFile = LittleFS.open("/provisioned.txt", "w");
      if (provFile) {
        provFile.print("1");
        provFile.close();
      }

      // 2. Phát tín hiệu báo hoàn thành thiết lập cho App
      String setupCompleteTopic = mqtt_prefix + "/setup/complete";
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      String completeMsg = "{\"status\":\"completed\",\"mac\":\"" + mac + "\"}";
      mqttClient.publish(setupCompleteTopic.c_str(), completeMsg.c_str(), true);

      // 3. Mở khóa toàn bộ tính năng của ESP32
      unlockAllFeatures();
      return;
    }
  }

  // Lệnh Reboot / Restart
  String systemRebootTopic = mqtt_prefix + "/system/reboot";
  String systemRestartTopic = mqtt_prefix + "/system/restart";
  if ((topicStr == systemRebootTopic || topicStr == systemRestartTopic) && message == "1") {
    Serial.println("\n[!] NHẬN ĐƯỢC LỆNH KHỞI ĐỘNG LẠI (REBOOT) TỪ APP!");
    mqttClient.publish(systemRebootTopic.c_str(), "", true);
    mqttClient.publish(systemRestartTopic.c_str(), "", true);
    Serial.println("ESP32 sẽ khởi động lại sau 1 giây...");
    rebootScheduledAt = millis();
    shouldReboot = true;
    return;
  }

  // Lệnh OTA
  String systemOtaTopic = mqtt_prefix + "/system/ota_update";
  String cleanMacOtaTopic = mqtt_prefix;
  cleanMacOtaTopic.replace(":", "");
  cleanMacOtaTopic += "/system/ota_update";

  if (topicStr == systemOtaTopic || topicStr == cleanMacOtaTopic) {
    if (isOtaInProgress) {
      Serial.println("\n[OTA] ⚠️ Đang có tiến trình nạp OTA chạy trong nền. Bỏ qua lệnh trùng lặp!");
      return;
    }
    Serial.println("\n[!] 🚀 NHẬN ĐƯỢC LỆNH NÂNG CẤP FIRMWARE OTA TỪ SERVER/APP! Topic: " + topicStr);
    StaticJsonDocument<512> otaDoc;
    DeserializationError err = deserializeJson(otaDoc, message);
    if (!err && otaDoc.containsKey("url")) {
      bool authorized = false;
      if (otaDoc.containsKey("admin_pass")) {
        String sentPass = otaDoc["admin_pass"].as<String>();
        if (admin_pass.length() == 0 || sentPass == admin_pass) {
          authorized = true;
        }
      }
      if (otaDoc.containsKey("server_authorized") && otaDoc["server_authorized"].as<bool>() == true) {
        authorized = true;
      }

      if (!authorized) {
        Serial.println("[OTA] ❌ Từ chối nâng cấp firmware: Sai mật khẩu quản trị hoặc thiếu ủy quyền!");
        if (mqttClient.connected()) {
          String resTopic = mqtt_prefix + "/system/ota_result";
          mqttClient.publish(resTopic.c_str(), "{\"status\":\"error\",\"message\":\"Từ chối nâng cấp: Sai mật khẩu quản trị!\"}", false);
        }
        return;
      }

      String fwUrl = otaDoc["url"].as<String>();
      String expectedSha = otaDoc.containsKey("sha256") ? otaDoc["sha256"].as<String>() : "";
      performServerOtaUpdate(fwUrl, expectedSha);
    } else {
      Serial.println("[OTA] ❌ Gói tin OTA thiếu trường URL hoặc JSON không hợp lệ!");
    }
    return;
  }

  // Lệnh Reset hệ thống
  String systemResetTopic = mqtt_prefix + "/system/reset";
  if (topicStr == systemResetTopic) {
    bool authorized = false;
    DynamicJsonDocument resetDoc(384);
    DeserializationError err = deserializeJson(resetDoc, message);
    if (!err && resetDoc.is<JsonObject>()) {
      String sentPass = resetDoc.containsKey("admin_pass") ? resetDoc["admin_pass"].as<String>() : "";
      if (admin_pass.length() > 0 && sentPass == admin_pass) {
        authorized = true;
      } else {
        Serial.println("\n[!] ⛔ TỪ CHỐI FACTORY RESET: Sai mật khẩu quản trị (admin_pass)!");
      }
    } else if (message == "1" || message == "force_reset" || message == "reset") {
      authorized = true;
      Serial.println("\n[!] 🔐 Nhận lệnh Reset hợp lệ từ Server/Quản trị viên!");
    }

    if (!authorized) {
      mqttClient.publish(systemResetTopic.c_str(), "", true);
      return;
    }

    Serial.println("\n[!] 🔐 ĐÃ XÁC THỰC THÀNH CÔNG YÊU CẦU FACTORY RESET!");
    mqttClient.publish(systemResetTopic.c_str(), "", true);
    
    resetToFactoryDefaults();
    Serial.println("Hệ thống sẽ khởi động lại và vào chế độ AP Setup sau 2 giây...");
    rebootScheduledAt = millis();
    shouldReboot = true;
    return;
  }

  // Lệnh Cấu hình hệ thống qua MQTT
  String systemConfigTopic = mqtt_prefix + "/system/config";
  if (topicStr == systemConfigTopic) {
    Serial.println("\n[!] NHẬN ĐƯỢC CẬP NHẬT CẤU HÌNH TỪ APP!");
    
    File file = LittleFS.open("/config.json", "r");
    if (file) {
      size_t size = file.size();
      std::unique_ptr<char[]> buf(new char[size + 1]);
      file.readBytes(buf.get(), size);
      buf.get()[size] = '\0';
      file.close();
      
      DynamicJsonDocument doc(2048);
      if (!deserializeJson(doc, buf.get())) {
        DynamicJsonDocument newConfigDoc(1536);
        if (!deserializeJson(newConfigDoc, message)) {
          if (newConfigDoc.is<JsonArray>()) {
            doc["devices"] = newConfigDoc.as<JsonArray>();
          } else if (newConfigDoc.is<JsonObject>()) {
            String currentAdminPass = doc.containsKey("admin_pass") ? doc["admin_pass"].as<String>() : "admin";
            String sentAdminPass = newConfigDoc.containsKey("admin_pass") ? newConfigDoc["admin_pass"].as<String>() : "";

            if (currentAdminPass.length() > 0 && sentAdminPass != currentAdminPass) {
              Serial.println("\n[!] BẢO MẬT: Sai mật khẩu quản trị! Từ chối ghi đè cấu hình ESP32.");
              return;
            }

            if (newConfigDoc.containsKey("wifi_ssid")) {
              String s = newConfigDoc["wifi_ssid"].as<String>();
              if (s.length() > 0) doc["wifi_ssid"] = s;
            }
            if (newConfigDoc.containsKey("wifi_pass")) {
              doc["wifi_pass"] = newConfigDoc["wifi_pass"].as<String>();
            }
            if (newConfigDoc.containsKey("mqtt_server")) {
              String s = newConfigDoc["mqtt_server"].as<String>();
              if (s.length() > 0) doc["mqtt_server"] = s;
            }
            if (newConfigDoc.containsKey("mqtt_user")) {
              doc["mqtt_user"] = newConfigDoc["mqtt_user"].as<String>();
            }
            if (newConfigDoc.containsKey("mqtt_pass")) {
              doc["mqtt_pass"] = newConfigDoc["mqtt_pass"].as<String>();
            }
            if (newConfigDoc.containsKey("mqtt_prefix")) {
              String p = newConfigDoc["mqtt_prefix"].as<String>();
              if (p.length() > 0) doc["mqtt_prefix"] = p;
            }
            if (newConfigDoc.containsKey("admin_pass")) {
              doc["admin_pass"] = newConfigDoc["admin_pass"].as<String>();
            }
            if (newConfigDoc.containsKey("devices") && newConfigDoc["devices"].is<JsonArray>()) {
              doc["devices"] = newConfigDoc["devices"].as<JsonArray>();
            }
          }
          
          File outFile = LittleFS.open("/config.json", "w");
          if (outFile) {
            serializeJson(doc, outFile);
            outFile.close();
            Serial.println("Đã lưu cấu hình mới vào /config.json thành công!");
            Serial.println("ESP32 sẽ tự khởi động lại sau 1 giây để áp dụng...");
            rebootScheduledAt = millis();
            shouldReboot = true;
          } else {
            Serial.println("Lỗi mở /config.json để ghi!");
          }
        }
      }
    }
    return;
  }

  // Đồng bộ RBAC thành viên qua MQTT
  String systemMembersTopic = mqtt_prefix + "/system/members";
  if (topicStr == systemMembersTopic) {
    Serial.println("\n[RBAC] 📥 Nhận cập nhật danh sách thành viên từ Cloud (system/members)!");
    saveMembersToFlash(message);
    parseMembersJson(message);
    return;
  }

  // Lệnh điều khiển rơ-le
  int lastSlash = topicStr.lastIndexOf('/');
  int secondLastSlash = topicStr.lastIndexOf('/', lastSlash - 1);
  if (lastSlash == -1 || secondLastSlash == -1) return;
  
  String devId = topicStr.substring(secondLastSlash + 1, lastSlash); 
  String targetState = "";

  if (message.startsWith("{") && message.endsWith("}")) {
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, message);
    if (!err) {
      if (doc.containsKey("action")) {
        String act = doc["action"].as<String>();
        targetState = (act == "1" || act == "ON" || act == "on") ? "1" : "0";
      } else if (doc.containsKey("state")) {
        targetState = doc["state"].as<String>();
      }
    }
  } else {
    targetState = message;
  }

  applyRelayCommand(devId, targetState, "mqtt", 2);
}

void publishHomeAssistantDiscovery() {
  if (!mqttClient.connected()) return;

  String cleanMac = WiFi.macAddress();
  cleanMac.replace(":", "");
  cleanMac.toUpperCase();

  Serial.println("[HASS] 📡 Đang phát bản tin Home Assistant MQTT Auto-Discovery...");

  // 1. Discovery cho các Rơ-le (Switches)
  for (int i = 0; i < relayCount; i++) {
    String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
    String cmdTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/cmd";
    String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
    String discTopic = "homeassistant/switch/zenhome_" + cleanMac + "/" + myRelays[i].id + "/config";

    StaticJsonDocument<512> discDoc;
    discDoc["name"] = "ZenHome " + myRelays[i].id;
    discDoc["unique_id"] = cleanMac + "_" + myRelays[i].id;
    discDoc["command_topic"] = cmdTopic;
    discDoc["state_topic"] = stateTopic;
    discDoc["payload_on"] = "1";
    discDoc["payload_off"] = "0";

    JsonObject dev = discDoc.createNestedObject("device");
    JsonArray ids = dev.createNestedArray("identifiers");
    ids.add("zenhome_" + cleanMac);
    dev["name"] = "ZenHome Hub (" + cleanMac + ")";
    dev["model"] = "ESP32 DevKit V1";
    dev["manufacturer"] = "ZenHome STEM";
    dev["sw_version"] = "2.5.7";

    String payload;
    serializeJson(discDoc, payload);
    mqttClient.publish(discTopic.c_str(), payload.c_str(), true);
  }

  // 2. Discovery cho Cảm biến Nhiệt độ
  String tempStateTopic = mqtt_prefix + "/nhiet_do_trong_nha";
  String tempDiscTopic = "homeassistant/sensor/zenhome_" + cleanMac + "/temperature/config";

  StaticJsonDocument<512> tempDoc;
  tempDoc["name"] = "ZenHome Indoor Temperature";
  tempDoc["unique_id"] = cleanMac + "_indoor_temperature";
  tempDoc["state_topic"] = tempStateTopic;
  tempDoc["unit_of_measurement"] = "°C";
  tempDoc["device_class"] = "temperature";
  tempDoc["state_class"] = "measurement";

  JsonObject dev = tempDoc.createNestedObject("device");
  JsonArray ids = dev.createNestedArray("identifiers");
  ids.add("zenhome_" + cleanMac);
  dev["name"] = "ZenHome Hub (" + cleanMac + ")";
  dev["model"] = "ESP32 DevKit V1";
  dev["manufacturer"] = "ZenHome STEM";
  dev["sw_version"] = "2.5.7";

  String tempPayload;
  serializeJson(tempDoc, tempPayload);
  mqttClient.publish(tempDiscTopic.c_str(), tempPayload.c_str(), true);

  Serial.println("[HASS] ✅ Đã công bố xong cấu hình Home Assistant Auto-Discovery!");
}

void publishOtaMessage(const String& subTopic, const String& payload) {
  if (!mqttClient.connected()) {
    if (WiFi.status() == WL_CONNECTED) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      String clientId = "ESP32_" + mac;
      String statusTopic = mqtt_prefix + "/esp_status";
      if (mqtt_user != "" && mqtt_pass != "") {
        mqttClient.connect(clientId.c_str(), mqtt_user.c_str(), mqtt_pass.c_str(), statusTopic.c_str(), 1, true, "offline");
      } else {
        mqttClient.connect(clientId.c_str(), statusTopic.c_str(), 1, true, "offline");
      }
    }
  }
  if (!mqttClient.connected()) return;
  String t1 = mqtt_prefix + subTopic;
  mqttClient.publish(t1.c_str(), payload.c_str(), false);
  String cleanP = mqtt_prefix;
  cleanP.replace(":", "");
  String t2 = cleanP + subTopic;
  if (t2 != t1) {
    mqttClient.publish(t2.c_str(), payload.c_str(), false);
  }
  mqttClient.loop();
}

void performServerOtaUpdate(const String& fwUrl, const String& expectedSha256) {
  if (fwUrl.length() < 10) return;
  if (isOtaInProgress) {
    Serial.println("[SERVER-OTA] ⚠️ Đang có tiến trình nạp OTA chạy trong nền, bỏ qua yêu cầu trùng lặp!");
    return;
  }
  isOtaInProgress = true;
  Serial.println("\n[SERVER-OTA] 🚀 Bắt đầu quá trình nâng cấp Firmware: " + fwUrl);

  publishOtaMessage("/system/ota_progress", "{\"progress\":0,\"status\":\"starting\"}");

  bool isHttps = fwUrl.startsWith("https://");
  WiFiClient plainClient;
  WiFiClientSecure secureClient;
  if (isHttps) {
    secureClient.setInsecure(); // Bỏ qua kiểm tra CA root cert để tương thích GitHub Releases / Cloud CDN
  }

  HTTPClient http;
  http.setConnectTimeout(10000);
  http.setTimeout(30000);
  http.setFollowRedirects(HTTPC_FORCE_FOLLOW_REDIRECTS); // Theo sát chuyển hướng 302 của GitHub Releases

  bool beginOk = isHttps ? http.begin(secureClient, fwUrl) : http.begin(plainClient, fwUrl);
  if (!beginOk) {
    Serial.println("[SERVER-OTA] ❌ Không thể khởi tạo kết nối HTTP/HTTPS!");
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Không thể kết nối tới URL tải firmware!\"}");
    isOtaInProgress = false;
    return;
  }

  int httpCode = http.GET();
  if (httpCode != HTTP_CODE_OK) {
    Serial.printf("[SERVER-OTA] ❌ Server trả về lỗi HTTP: %d\n", httpCode);
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"httpCode\":" + String(httpCode) + "}");
    http.end();
    isOtaInProgress = false;
    return;
  }

  int contentLength = http.getSize();
  Serial.printf("[SERVER-OTA] 📦 Kích thước file Firmware: %d bytes\n", contentLength);

  if (contentLength <= 0 || contentLength > 1900000) {
    Serial.println("[SERVER-OTA] ❌ Dung lượng firmware không hợp lệ (vượt quá 1.9MB partition)!");
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Dung lượng firmware không hợp lệ!\"}");
    http.end();
    isOtaInProgress = false;
    return;
  }

  bool canBegin = Update.begin(contentLength, U_FLASH);
  if (!canBegin) {
    Serial.println("[SERVER-OTA] ❌ Không thể phân bổ phân vùng Flash OTA!");
    Update.printError(Serial);
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Không thể phân bổ phân vùng Flash OTA!\"}");
    http.end();
    isOtaInProgress = false;
    return;
  }

  WiFiClient *stream = http.getStreamPtr();
  size_t written = 0;
  uint8_t buff[1024];
  int lastProgress = 0;
  unsigned long lastWdt = millis();

  mbedtls_md_context_t md_ctx;
  mbedtls_md_init(&md_ctx);
  mbedtls_md_setup(&md_ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 0);
  mbedtls_md_starts(&md_ctx);

  while (http.connected() && (written < (size_t)contentLength)) {
    size_t sizeAvailable = stream->available();
    if (sizeAvailable > 0) {
      int c = stream->readBytes(buff, ((sizeAvailable > sizeof(buff)) ? sizeof(buff) : sizeAvailable));
      Update.write(buff, c);
      mbedtls_md_update(&md_ctx, buff, c);
      written += c;

      int progress = (written * 100) / contentLength;
      if (progress - lastProgress >= 5 || written == (size_t)contentLength) {
        lastProgress = progress;
        Serial.printf("[SERVER-OTA] ⏳ Tiến trình tải & nạp Flash: %d%% (%u / %d bytes)\n", progress, written, contentLength);
        String msg = "{\"progress\":" + String(progress) + ",\"written\":" + String(written) + ",\"total\":" + String(contentLength) + "}";
        publishOtaMessage("/system/ota_progress", msg);
      }
    }
    if (millis() - lastWdt >= 1000) {
      lastWdt = millis();
      esp_task_wdt_reset();
      mqttClient.loop();
    }
    delay(1);
  }

  http.end();

  uint8_t calculatedShaBytes[32];
  mbedtls_md_finish(&md_ctx, calculatedShaBytes);
  mbedtls_md_free(&md_ctx);

  char calculatedShaHex[65];
  bytesToHex(calculatedShaBytes, 32, calculatedShaHex);
  String calculatedSha = String(calculatedShaHex);

  if (expectedSha256.length() == 64 && !expectedSha256.equalsIgnoreCase(calculatedSha)) {
    Serial.println("[SERVER-OTA] ❌ BẢO MẬT: Kiểm tra tính toàn vẹn thất bại! Từ chối firmware không hợp lệ.");
    Update.abort();
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Xác thực tính toàn vẹn thất bại! Firmware có thể bị sửa đổi hoặc lỗi mạng.\"}");
    isOtaInProgress = false;
    return;
  }

  if (written == (size_t)contentLength) {
    Serial.println("[SERVER-OTA] 📥 Đã nhận đủ 100% Firmware và xác thực tính toàn vẹn hợp lệ! Đang hoán đổi phân vùng boot...");
    if (Update.end(true)) {
      Serial.println("[SERVER-OTA] ✅ NÂNG CẤP THÀNH CÔNG RỰC RỠ! ESP32 sẽ khởi động lại vào Firmware mới sau 2 giây...");
      publishOtaMessage("/system/ota_result", "{\"status\":\"success\",\"version\":\"" FIRMWARE_VERSION_STR "\",\"build\":" + String(FIRMWARE_BUILD_NUM) + ",\"message\":\"Nâng cấp Firmware OTA thành công 100%! Đang khởi động lại.\"}");
      for (int i = 0; i < 15; i++) {
        mqttClient.loop();
        delay(100);
      }
      delay(1500);
      ESP.restart();
    } else {
      Serial.println("[SERVER-OTA] ❌ Lỗi Update.end()!");
      Update.printError(Serial);
      publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Lỗi ghi phân vùng boot Update.end()\"}");
      isOtaInProgress = false;
    }
  } else {
    Serial.printf("[SERVER-OTA] ❌ Quá trình tải bị đứt quãng (%u / %d bytes). Hủy cập nhật phòng ngừa lỗi!\n", written, contentLength);
    Update.abort();
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Quá trình tải bị đứt quãng\"}");
    isOtaInProgress = false;
  }
}
