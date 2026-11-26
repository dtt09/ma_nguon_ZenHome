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

static SemaphoreHandle_t mqttMutex = NULL;

void initMqttMutex() {
  if (mqttMutex == NULL) {
    mqttMutex = xSemaphoreCreateRecursiveMutex();
  }
}

bool lockMqtt(TickType_t waitTicks) {
  if (mqttMutex == NULL) return true;
  return xSemaphoreTakeRecursive(mqttMutex, waitTicks) == pdTRUE;
}

void unlockMqtt() {
  if (mqttMutex != NULL) {
    xSemaphoreGiveRecursive(mqttMutex);
  }
}

bool safeMqttPublish(const char* topic, const char* payload, bool retained) {
  if (WiFi.status() != WL_CONNECTED || !mqttClient.connected()) return false;
  if (!lockMqtt(pdMS_TO_TICKS(1000))) return false;
  bool ok = mqttClient.publish(topic, payload, retained);
  unlockMqtt();
  return ok;
}

static uint64_t epochMillis() {
  timeval tv;
  gettimeofday(&tv, nullptr);
  return uint64_t(tv.tv_sec) * 1000 + tv.tv_usec / 1000;
}

static String cleanDeviceBase(const String& room, const String& id) {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();
  return mqtt_prefix.substring(0, mqtt_prefix.indexOf('/')) + "/" + mac + "/" + room + "/" + id;
}

void publishRelayState(const String& stateTopic, const String& state, const String& requestNonce) {
  if (bindingToken.length() != 43 || !stateTopic.endsWith("/state") || (state != "0" && state != "1")) return;
  String rawBase = stateTopic.substring(0, stateTopic.length() - 6);
  int devSlash = rawBase.lastIndexOf('/');
  int roomSlash = rawBase.lastIndexOf('/', devSlash - 1);
  String base = cleanDeviceBase(rawBase.substring(roomSlash + 1, devSlash), rawBase.substring(devSlash + 1));
  String nonce = requestNonce;
  if (nonce.isEmpty()) {
    uint8_t random[16];
    esp_fill_random(random, sizeof(random));
    char hex[33];
    bytesToHex(random, sizeof(random), hex);
    nonce = hex;
  }
  String ts = String(epochMillis());
  String proof = computeHmacSha256(computeSha256OfText(bindingToken), "state-v1\n" + base + "\n" + state + "\n" + ts + "\n" + nonce);
  StaticJsonDocument<384> ack;
  ack["v"] = 1;
  ack["state"] = state;
  ack["ts"] = ts;
  ack["nonce"] = nonce;
  ack["sig"] = proof;
  String payload;
  serializeJson(ack, payload);
  String canonical = base + "/state";
  safeMqttPublish(canonical.c_str(), payload.c_str(), true);
  if (canonical != stateTopic) safeMqttPublish(stateTopic.c_str(), payload.c_str(), true);
}

void initMqttClient() {
  initMqttMutex();
  espClient.setCACert(HIVEMQ_ROOT_CA); // [ZH-CRIT-03] Xác thực chứng chỉ X.509 Root CA cho HiveMQ Cloud TLS Port 8883
  espClient.setTimeout(15); // 15 giây timeout cho phiên bắt tay TLS
  mqttClient.setServer(mqtt_server.c_str(), 8883);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(4096);
  mqttClient.setKeepAlive(15); // Giảm KeepAlive xuống 15s (Broker kích hoạt LWT 'offline' sau tối đa 22s khi mất điện)
  mqttClient.setSocketTimeout(15); // 15 giây timeout cho MQTT CONNACK và Ping
}

/**
 * Verify an enrolled hub with its authenticated HTTPS origin.
 */
bool verifyBindingWithDatabase() {
  if (WiFi.status() != WL_CONNECTED || time(nullptr) < 1700000000 ||
      !server_url.startsWith("https://") || bindingToken.length() != 43) return false;
  int slash = mqtt_prefix.indexOf('/');
  if (slash <= 0) return false;

  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();
  StaticJsonDocument<192> doc;
  doc["userId"] = mqtt_prefix.substring(0, slash);
  doc["macAddress"] = mac;
  String body;
  serializeJson(doc, body);
  String baseUrl = server_url;
  while (baseUrl.endsWith("/")) baseUrl.remove(baseUrl.length() - 1);

  WiFiClientSecure client;
  client.setCACert(HIVEMQ_ROOT_CA);
  HTTPClient http;
  if (!http.begin(client, baseUrl + "/api/v1/hub/verify-binding")) return false;
  http.setTimeout(3500);
  http.addHeader("Authorization", "Bearer " + bindingToken);
  http.addHeader("Content-Type", "application/json");
  if (http.POST(body) == 200) {
    StaticJsonDocument<256> result;
    isBindingVerified = !deserializeJson(result, http.getString()) && result["valid"] == true;
  }
  http.end();
  return isBindingVerified;
}

static void subscribeHubCommands() {
  String canonical = cleanDeviceBase("", "");
  canonical.remove(canonical.length() - 2);
  const char* topics[] = {"/+/+/cmd", "/system/config", "/system/reset", "/system/reboot",
                          "/system/restart", "/system/ota_update", "/system/members"};
  for (const char* topic : topics) {
    mqttClient.subscribe((canonical + topic).c_str(), 1);
    if (canonical != mqtt_prefix) mqttClient.subscribe((mqtt_prefix + topic).c_str(), 1);
  }
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

  // Kiểm tra phân giải DNS trước khi bắt tay socket TLS
  IPAddress resolvedIp;
  if (!WiFi.hostByName(mqtt_server.c_str(), resolvedIp)) {
    Serial.println("[MQTT] ⚠️ Không thể phân giải DNS: " + mqtt_server + ". Thử lại với Public DNS (8.8.8.8)...");
    WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE, IPAddress(8, 8, 8, 8), IPAddress(1, 1, 1, 1));
    delay(100);
    WiFi.hostByName(mqtt_server.c_str(), resolvedIp);
  }

  Serial.println("\n[MQTT] 📡 Đang kết nối MQTT TLS (8883) tới: " + mqtt_server + " [" + resolvedIp.toString() + "] (User: " + mqtt_user + ")");
  Serial.printf("[MQTT] ℹ️ Bộ nhớ Heap khả dụng: %u bytes\n", ESP.getFreeHeap());
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  String clientId = "ESP32_" + mac;
  String statusTopic = mqtt_prefix + "/esp_status";

  // Dọn dẹp triệt để TLS Socket cũ trước khi khởi tạo phiên bắt tay mới
  espClient.stop();
  delay(30);
  espClient.setHandshakeTimeout(20);

  if (time(nullptr) < 1700000000) {
    isConnectingMqtt = false;
    return;
  }
  espClient.setCACert(HIVEMQ_ROOT_CA);

  // [Phase P3: Software Mutual TLS - mTLS] Kiểm tra nếu có certificate và private key trong LittleFS
  static String clientCertPem = "";
  static String clientKeyPem = "";
  static bool mtlsChecked = false;
  if (!mtlsChecked) {
    mtlsChecked = true;
    if (LittleFS.exists("/client_cert.pem") && LittleFS.exists("/client_key.pem")) {
      File certFile = LittleFS.open("/client_cert.pem", "r");
      if (certFile) {
        clientCertPem = certFile.readString();
        certFile.close();
      }
      File keyFile = LittleFS.open("/client_key.pem", "r");
      if (keyFile) {
        clientKeyPem = keyFile.readString();
        keyFile.close();
      }
      if (clientCertPem.length() > 0 && clientKeyPem.length() > 0) {
        Serial.println("[MQTT] 🔐 KÍCH HOẠT mTLS 2 CHIỀU (Mutual TLS): Sử dụng Client Certificate & Private Key từ Flash LittleFS!");
      }
    }
  }

  // Chỉ kích hoạt Client Cert mTLS nếu Broker hỗ trợ (Broker HiveMQ Cloud Serverless từ chối client cert nếu gửi lên)
  if (mqtt_server.indexOf("hivemq.cloud") < 0 && clientCertPem.length() > 0 && clientKeyPem.length() > 0) {
    espClient.setCertificate(clientCertPem.c_str());
    espClient.setPrivateKey(clientKeyPem.c_str());
  }

  bool connected = false;
  if (mqtt_user != "" && mqtt_pass != "") {
    connected = mqttClient.connect(clientId.c_str(), mqtt_user.c_str(), mqtt_pass.c_str(), statusTopic.c_str(), 1, true, "offline");
  } else if (mqtt_server.indexOf("hivemq.cloud") < 0 && clientCertPem.length() > 0 && clientKeyPem.length() > 0) {
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
      String compact = cleanDeviceBase("", "");
      compact.remove(compact.length() - 2);
      mqttClient.subscribe((compact + "/setup/confirm").c_str(), 1);

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
        publishRelayState(stateTopic, myRelays[i].state);
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
        publishRelayState(stateTopic, myRelays[i].state);

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

    subscribeHubCommands();

    // Phát Heartbeat ban đầu thông báo phiên bản Firmware & Trạng thái bảo mật phần cứng ngay khi kết nối
    {
      String heartbeatTopic = mqtt_prefix + "/heartbeat";
      StaticJsonDocument<384> hbDoc;
      hbDoc["online"] = true;
      hbDoc["uptime"] = millis() / 1000;
      hbDoc["heap"] = ESP.getFreeHeap();
      hbDoc["version"] = FIRMWARE_VERSION_STR;
      hbDoc["build"] = FIRMWARE_BUILD_NUM;

      // Phase P2: Hardware Security Telemetry (Flash Encryption & Secure Boot)
      bool flashEnc = false;
      bool secBoot = false;
      getHardwareSecurityInfo(flashEnc, secBoot);
      JsonObject hwSec = hbDoc.createNestedObject("hw_sec");
      hwSec["flash_enc"] = flashEnc;
      hwSec["sec_boot"] = secBoot;
      hwSec["flashEnc"] = flashEnc;
      hwSec["secBoot"] = secBoot;

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
        Serial.printf("[MQTT-DIAG] WiFi IP: %s | Server: %s | DNS: %s | Epoch: %ld | Heap: %u bytes\n",
                      WiFi.localIP().toString().c_str(),
                      mqtt_server.c_str(),
                      resolvedIp.toString().c_str(),
                      (long)time(nullptr),
                      ESP.getFreeHeap());
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
      if (lockMqtt(pdMS_TO_TICKS(100))) {
        mqttClient.loop();
        unlockMqtt();
      }

      // Định kỳ gửi Heartbeat mỗi 15s để App và Broker luôn nhận biết ESP32 đang hoạt động thực tế
      static unsigned long lastHeartbeatTime = 0;
      if (currentMillis - lastHeartbeatTime >= 15000) {
        lastHeartbeatTime = currentMillis;
        String heartbeatTopic = mqtt_prefix + "/heartbeat";
        StaticJsonDocument<384> hbDoc;
        hbDoc["online"] = true;
        hbDoc["uptime"] = millis() / 1000;
        hbDoc["heap"] = ESP.getFreeHeap();
        hbDoc["version"] = FIRMWARE_VERSION_STR;
        hbDoc["build"] = FIRMWARE_BUILD_NUM;

        // Phase P2: Hardware Security Telemetry (Flash Encryption & Secure Boot)
        bool flashEnc = false;
        bool secBoot = false;
        getHardwareSecurityInfo(flashEnc, secBoot);
        JsonObject hwSec = hbDoc.createNestedObject("hw_sec");
        hwSec["flash_enc"] = flashEnc;
        hwSec["sec_boot"] = secBoot;
        hwSec["flashEnc"] = flashEnc;
        hwSec["secBoot"] = secBoot;

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

static String setupChallenge;

void sendSetupHandshakeBeacon() {
  if (!mqttClient.connected() || !isSetupPending) return;

  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();

  StaticJsonDocument<256> doc;
  doc["mac"] = mac;
  if (setupChallenge.isEmpty()) {
    uint8_t random[16];
    esp_fill_random(random, sizeof(random));
    char challengeHex[33];
    bytesToHex(random, sizeof(random), challengeHex);
    setupChallenge = challengeHex;
  }
  doc["challenge"] = setupChallenge;
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
  subscribeHubCommands();

  // 6. Phát hiện Home Assistant
  publishHomeAssistantDiscovery();

  // 7. Đồng bộ trạng thái Relay ban đầu (Tắt an toàn)
  for (int i = 0; i < relayCount; i++) {
    String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
    String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
    publishRelayState(stateTopic, myRelays[i].state);
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
  String cleanConfirmTopic = setupConfirmTopic;
  cleanConfirmTopic.replace(":", "");
  if (isSetupPending && (topicStr == setupConfirmTopic || topicStr == cleanConfirmTopic)) {
    DynamicJsonDocument confirmDoc(512);
    String user = mqtt_prefix.substring(0, mqtt_prefix.indexOf('/'));
    String mac = WiFi.macAddress();
    mac.replace(":", "");
    mac.toUpperCase();
    String signedFields = user + ":" + mac + ":" + setupChallenge;
    if (deserializeJson(confirmDoc, message) || confirmDoc["confirm"] != true ||
        !isBindingVerified || setupChallenge.isEmpty() ||
        confirmDoc["userId"] != user || confirmDoc["challenge"] != setupChallenge ||
        !verifyHmacSha256(currentLocalSecretKey, "setup:" + signedFields, confirmDoc["sig"] | "")) return;
    {
      // 1. Gỡ cờ pending và tạo provisioned.txt
      File marker = LittleFS.open("/provisioned.txt", "w");
      if (!marker) return;
      bool written = marker.print("1") == 1;
      marker.close();
      if (!written || !LittleFS.remove("/setup_pending.txt")) return;
      isSetupPending = false;
      isProvisioned = true;
      isConfigured = true;

      StaticJsonDocument<384> result;
      result["status"] = "completed";
      result["mac"] = mac;
      result["challenge"] = setupChallenge;
      result["proof"] = computeHmacSha256(currentLocalSecretKey, "complete:" + signedFields);
      String completeMsg;
      serializeJson(result, completeMsg);
      String setupCompleteTopic = mqtt_prefix + "/setup/complete";
      mqttClient.publish(setupCompleteTopic.c_str(), completeMsg.c_str(), true);
      String cleanCompleteTopic = setupCompleteTopic;
      cleanCompleteTopic.replace(":", "");
      if (cleanCompleteTopic != setupCompleteTopic) mqttClient.publish(cleanCompleteTopic.c_str(), completeMsg.c_str(), true);
      setupChallenge = "";
      // 3. Mở khóa toàn bộ tính năng của ESP32
      unlockAllFeatures();
      return;
    }
  }

  if (!isProvisioned || isSetupPending) return;
  String cleanPrefix = mqtt_prefix;
  cleanPrefix.replace(":", "");
  if (topicStr.startsWith(cleanPrefix + "/")) topicStr = mqtt_prefix + topicStr.substring(cleanPrefix.length());
  if (!topicStr.startsWith(mqtt_prefix + "/")) return;
  String suffix = topicStr.substring(mqtt_prefix.length() + 1);
  if (suffix.startsWith("system/")) {
    DynamicJsonDocument wrapper(4096);
    if (deserializeJson(wrapper, message)) return;
    String action = suffix.substring(7);
    if (wrapper.containsKey("enc")) {
      String enc = wrapper["enc"] | "";
      if (!enc.startsWith("ZHENC1:")) return;
      message = decryptEnvelopeWithKeyHex(enc, currentLocalSecretKey);
      wrapper.clear();
      if (deserializeJson(wrapper, message) || time(nullptr) < 1700000000 ||
          wrapper["ts"].as<String>().toInt() <= time(nullptr) - esp_timer_get_time() / 1000000 ||
          wrapper["action"] != action || isTimestampExpired(wrapper["ts"].as<String>()) ||
          isNonceReplayedOrInvalid(wrapper["nonce"] | "")) return;
    } else {
      if (bindingToken.length() != 43 || wrapper["v"] != 1 ||
          (action != "config" && action != "members" && action != "ota_update" && action != "reset")) return;
      String data = wrapper["data"] | "";
      String ts = wrapper["ts"] | "";
      String nonce = wrapper["nonce"] | "";
      if (ts.length() != 13 || nonce.length() != 32) return;
      uint64_t issued = strtoull(ts.c_str(), nullptr, 10);
      uint64_t now = epochMillis();
      if (issued + 60000 < now || issued > now + 60000 || issued < now - uint64_t(esp_timer_get_time() / 1000)) return;
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      String canonical = mqtt_prefix.substring(0, mqtt_prefix.indexOf('/')) + "/" + mac + "/" + suffix;
      String fields = "admin-v1\n" + canonical + "\n" + computeSha256OfText(data) + "\n" + ts + "\n" + nonce;
      if (!verifyHmacSha256(computeSha256OfText(bindingToken), fields, wrapper["sig"] | "") ||
          isNonceReplayedOrInvalid(nonce)) return;
      message = data;
      wrapper.clear();
      if (deserializeJson(wrapper, message) || !wrapper.is<JsonObject>()) return;
      if (action == "config" && (wrapper.size() != 1 || !wrapper["devices"].is<JsonArray>())) return;
    }
    if (suffix == "system/reboot" || suffix == "system/restart") {
      rebootScheduledAt = millis();
      shouldReboot = true;
      return;
    }
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
      String sigHex = otaDoc["sig"] | "";
      // [ZH-HIGH-19] Anti-Rollback firmware check: Bắt buộc build >= FIRMWARE_BUILD_NUM
      int newBuild = -1;
      if (otaDoc.containsKey("build")) {
        newBuild = otaDoc["build"].as<int>();
      } else if (otaDoc.containsKey("newBuild")) {
        newBuild = otaDoc["newBuild"].as<int>();
      } else if (otaDoc.containsKey("buildNumber")) {
        newBuild = otaDoc["buildNumber"].as<int>();
      }
      if (newBuild < FIRMWARE_BUILD_NUM) {
        Serial.printf("[OTA] ⛔ ANTI-ROLLBACK: Từ chối hạ cấp firmware! Bản hiện tại: %d, bản yêu cầu: %d\n", FIRMWARE_BUILD_NUM, newBuild);
        if (mqttClient.connected()) {
          String resTopic = mqtt_prefix + "/system/ota_result";
          mqttClient.publish(resTopic.c_str(), "{\"status\":\"error\",\"code\":\"ANTI_ROLLBACK\",\"message\":\"Từ chối hạ cấp firmware về phiên bản cũ có lỗ hổng!\"}", false);
        }
        return;
      }

      String fwUrl = otaDoc["url"].as<String>();
      String expectedSha = otaDoc.containsKey("sha256") ? otaDoc["sha256"].as<String>() : "";
      performServerOtaUpdate(fwUrl, expectedSha, sigHex, newBuild);
    } else {
      Serial.println("[OTA] ❌ Gói tin OTA thiếu trường URL hoặc JSON không hợp lệ!");
    }
    return;
  }

  // Lệnh Reset hệ thống
  String systemResetTopic = mqtt_prefix + "/system/reset";
  if (topicStr == systemResetTopic) {
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
            // Hỗ trợ nhận trực tiếp JSON Array danh sách thiết bị từ App
            Serial.println("\n[CONFIG] 📥 Nhận mảng thiết bị trực tiếp từ App qua MQTT!");
            doc["devices"] = newConfigDoc.as<JsonArray>();
          } else if (newConfigDoc.is<JsonObject>()) {
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
            if (newConfigDoc.containsKey("admin_pass")) {
              doc["admin_pass"] = newConfigDoc["admin_pass"].as<String>();
            }
            if (newConfigDoc.containsKey("devices") && newConfigDoc["devices"].is<JsonArray>()) {
              doc["devices"] = newConfigDoc["devices"].as<JsonArray>();
            }
          } else {
            Serial.println("\n[!] BẢO MẬT: Bắt buộc gửi payload JSON Object hoặc Array thiết bị để cập nhật cấu hình!");
            return;
          }
          
          if (saveConfig(doc)) {
            Serial.println("Đã lưu an toàn nguyên tử cấu hình mới vào /config.json thành công!");
            Serial.println("ESP32 sẽ tự khởi động lại sau 1 giây để áp dụng...");
            rebootScheduledAt = millis();
            shouldReboot = true;
          } else {
            Serial.println("Lỗi lưu /config.json!");
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

  // The server signs the canonical device path and requested state.
  if (!suffix.endsWith("/cmd") || bindingToken.length() != 43) return;
  int roomSlash = suffix.indexOf('/');
  int deviceSlash = suffix.lastIndexOf('/');
  if (roomSlash <= 0 || deviceSlash <= roomSlash + 1 || suffix.indexOf('/', roomSlash + 1) != deviceSlash) return;
  String room = suffix.substring(0, roomSlash);
  String id = suffix.substring(roomSlash + 1, deviceSlash);
  String base = cleanDeviceBase(room, id);
  StaticJsonDocument<512> doc;
  if (deserializeJson(doc, message) || doc["v"] != 1) return;
  String state = doc["state"] | "";
  String ts = doc["ts"] | "";
  String nonce = doc["nonce"] | "";
  if ((state != "0" && state != "1") || ts.length() != 13 || nonce.length() != 32) return;
  for (size_t i = 0; i < nonce.length(); ++i) if (!isxdigit(nonce[i])) return;
  for (size_t i = 0; i < ts.length(); ++i) if (!isdigit(ts[i])) return;
  uint64_t issued = strtoull(ts.c_str(), nullptr, 10);
  uint64_t now = epochMillis();
  if (issued + 60000 < now || issued > now + 60000 || issued < now - (uint64_t)(esp_timer_get_time() / 1000)) return;
  const String fields = "relay-v1\n" + base + "\n" + state + "\n" + ts + "\n" + nonce;
  if (!verifyHmacSha256(computeSha256OfText(bindingToken), fields, doc["sig"] | "")) return;
  static uint64_t lastIssued[MAX_RELAYS] = {};
  static String lastNonce[MAX_RELAYS];
  for (int i = 0; i < relayCount; ++i) {
    String relayRoom = myRelays[i].room.isEmpty() ? String("living_room") : myRelays[i].room;
    if (myRelays[i].id != id || relayRoom != room) continue;
    if (issued == lastIssued[i] && lastNonce[i] == nonce && myRelays[i].state == state) {
      publishRelayState(base + "/state", state, nonce);
      return;
    }
    if (issued <= lastIssued[i]) return;
    if (applyRelayCommand(id, state, "mqtt", 2, nonce)) {
      lastIssued[i] = issued;
      lastNonce[i] = nonce;
    }
    return;
  }
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
    String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
    String discTopic = "homeassistant/switch/zenhome_" + cleanMac + "/" + myRelays[i].id + "/config";

    StaticJsonDocument<512> discDoc;
    discDoc["name"] = "ZenHome " + myRelays[i].id;
    discDoc["unique_id"] = cleanMac + "_" + myRelays[i].id;
    discDoc["value_template"] = "{{ value_json.state }}";
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
  if (!mqttClient.connected()) return;
  String t1 = mqtt_prefix + subTopic;
  mqttClient.publish(t1.c_str(), payload.c_str(), false);
  String cleanP = mqtt_prefix;
  cleanP.replace(":", "");
  String t2 = cleanP + subTopic;
  if (t2 != t1) {
    mqttClient.publish(t2.c_str(), payload.c_str(), false);
  }
  if (lockMqtt(pdMS_TO_TICKS(100))) {
    mqttClient.loop();
    unlockMqtt();
  }
}

void performServerOtaUpdate(const String& fwUrl, const String& expectedSha256, const String& signatureHex, int newBuild) {
  if (!fwUrl.startsWith("https://") || expectedSha256.length() != 64 || signatureHex.isEmpty()) return;
  if (newBuild < FIRMWARE_BUILD_NUM) {
    Serial.printf("[SERVER-OTA] ⛔ ANTI-ROLLBACK: Từ chối hạ cấp firmware! Bản hiện tại: %d, bản yêu cầu: %d\n", FIRMWARE_BUILD_NUM, newBuild);
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"code\":\"ANTI_ROLLBACK\",\"message\":\"Từ chối hạ cấp firmware về bản cũ!\"}");
    return;
  }
  if (isOtaInProgress.exchange(true)) {
    Serial.println("[SERVER-OTA] ⚠️ Đang có tiến trình nạp OTA chạy trong nền, bỏ qua yêu cầu trùng lặp!");
    return;
  }
  Serial.println("\n[SERVER-OTA] 🚀 Bắt đầu quá trình nâng cấp Firmware: " + fwUrl);

  publishOtaMessage("/system/ota_progress", "{\"progress\":0,\"status\":\"starting\"}");

  WiFiClientSecure secureClient;
  secureClient.setCACert(OTA_ROOT_CAS);

  HTTPClient http;
  http.setConnectTimeout(10000);
  http.setTimeout(30000);
  http.setFollowRedirects(HTTPC_FORCE_FOLLOW_REDIRECTS); // Theo sát chuyển hướng 302 của GitHub Releases

  bool beginOk = http.begin(secureClient, fwUrl);
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
  bool hashOk = mbedtls_md_setup(&md_ctx, mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), 0) == 0 &&
                mbedtls_md_starts(&md_ctx) == 0;
  unsigned long lastData = millis();
  while (hashOk && http.connected() && written < (size_t)contentLength && millis() - lastData < 30000) {
    size_t sizeAvailable = stream->available();
    if (sizeAvailable > 0) {
      size_t bytesToRead = std::min(sizeof(buff), std::min(sizeAvailable, (size_t)contentLength - written));
      size_t count = stream->readBytes(buff, bytesToRead);
      if (!count || Update.write(buff, count) != count || mbedtls_md_update(&md_ctx, buff, count) != 0) {
        hashOk = false;
        break;
      }
      written += count;
      lastData = millis();

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
      if (lockMqtt(pdMS_TO_TICKS(100))) {
        mqttClient.loop();
        unlockMqtt();
      }
    }
    delay(1);
  }

  http.end();

  uint8_t calculatedShaBytes[32] = {};
  hashOk = hashOk && written == (size_t)contentLength && mbedtls_md_finish(&md_ctx, calculatedShaBytes) == 0;
  mbedtls_md_free(&md_ctx);

  char calculatedShaHex[65];
  bytesToHex(calculatedShaBytes, 32, calculatedShaHex);
  String calculatedSha = String(calculatedShaHex);

  if (!hashOk || !expectedSha256.equalsIgnoreCase(calculatedSha)) {
    Serial.println("[SERVER-OTA] ❌ BẢO MẬT: Kiểm tra tính toàn vẹn thất bại! Từ chối firmware không hợp lệ.");
    Update.abort();
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Xác thực tính toàn vẹn thất bại! Firmware có thể bị sửa đổi hoặc lỗi mạng.\"}");
    isOtaInProgress = false;
    return;
  }

  // 🔐 BẢO MẬT NÂNG CAO (SECURE OTA): Bắt buộc xác thực chữ ký số phi đối xứng ECDSA P-256 (Khắc phục ZH-05)
  if (signatureHex.length() < 64) {
    Serial.println("[SERVER-OTA] ⛔ BẢO MẬT TỐI CAO: Thiếu chữ ký số phát hành firmware! Bắt buộc phải có chữ ký số ECDSA P-256 từ nhà phát hành.");
    Update.abort();
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Thiếu chữ ký số ECDSA nhà phát hành! Từ chối nạp firmware không có chữ ký.\"}");
    isOtaInProgress = false;
    return;
  }

  if (!verifyFirmwareEcdsaSignature(calculatedShaBytes, signatureHex)) {
    Serial.println("[SERVER-OTA] ⛔ BẢO MẬT TỐI CAO: Chữ ký số nhà phát triển KHÔNG HỢP LỆ! Nghi vấn firmware giả mạo.");
    Update.abort();
    publishOtaMessage("/system/ota_result", "{\"status\":\"error\",\"message\":\"Chữ ký số phát hành không hợp lệ! Từ chối nạp firmware lạ.\"}");
    isOtaInProgress = false;
    return;
  }
  Serial.println("[SERVER-OTA] 🔐 XÁC THỰC THÀNH CÔNG: Chữ ký số nhà phát triển ECDSA P-256 hợp lệ 100%!");

  if (written == (size_t)contentLength) {
    Serial.println("[SERVER-OTA] 📥 Đã nhận đủ 100% Firmware và xác thực tính toàn vẹn hợp lệ! Đang hoán đổi phân vùng boot...");
    if (Update.end(true)) {
      Serial.println("[SERVER-OTA] ✅ NÂNG CẤP THÀNH CÔNG RỰC RỠ! ESP32 sẽ khởi động lại vào Firmware mới sau 2 giây...");
      publishOtaMessage("/system/ota_result", "{\"status\":\"success\",\"version\":\"" FIRMWARE_VERSION_STR "\",\"build\":" + String(FIRMWARE_BUILD_NUM) + ",\"message\":\"Nâng cấp Firmware OTA thành công 100%! Đang khởi động lại.\"}");
      for (int i = 0; i < 15; i++) {
        if (lockMqtt(pdMS_TO_TICKS(100))) {
          mqttClient.loop();
          unlockMqtt();
        }
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
