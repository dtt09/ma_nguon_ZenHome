#include <mbedtls/sha256.h>
#include "network_manager.h"
#include "config_manager.h"
#include "security_manager.h"
#include "hardware_manager.h"
#include "mqtt_manager.h"
#include "ble_manager.h"
#include "anomaly_detector.h"

#include <esp_task_wdt.h>
#include <Update.h>
#include <HTTPClient.h>
#include <mbedtls/md.h>

AsyncWebServer server(80);
WiFiUDP udpDiscovery;
bool isWebServerStarted = false;
bool isUdpStarted = false;
unsigned long lastWiFiRetry = 0;

void setupAPMode() {
  WiFi.mode(WIFI_AP);
  String rawMac = WiFi.macAddress();
  String apPass;
  File saved = LittleFS.open("/setup_code.txt", "r");
  if (saved) { apPass = saved.readString(); saved.close(); }
  if (apPass.length() != 16) {
    uint8_t random[8];
    esp_fill_random(random, sizeof(random));
    char code[17];
    bytesToHex(random, sizeof(random), code);
    apPass = code;
    File file = LittleFS.open("/setup_code.txt", "w");
    if (file) { file.print(apPass); file.close(); }
  }
  Serial.println("[USB SETUP] Wi-Fi setup code: " + apPass);
  String mac = rawMac;
  mac.replace(":", "");
  mac.toUpperCase();
  String apName = "ZenHome_Setup_" + mac.substring(6);

  WiFi.softAP(apName.c_str(), apPass.c_str()); 

  server.on("/api/config", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    constexpr size_t maxConfigSize = 4096;
    if (total == 0 || total > maxConfigSize || index > total || len > total - index) {
      if (!index) request->send(413);
      return;
    }
    if (!index) request->_tempObject = calloc(1, total + 1);
    auto* buffer = static_cast<char*>(request->_tempObject);
    if (!buffer) { if (!index) request->send(503); return; }
    memcpy(buffer + index, data, len);
    if (index + len != total) return;
    String jsonPayload(buffer, total);
    Serial.println("\n[HTTP-SETUP] >>> Nhận gói cấu hình liên kết từ App (Thông tin nhạy cảm đã được che an toàn).");

    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, jsonPayload);
    const String setupKey = doc["local_key"] | "";
    doc.remove("local_key");
    const String setupPass = doc["admin_pass"] | "";
    const String url = doc["server_url"] | "";
    const String token = doc["binding_token"] | "";
    bool keyValid = setupKey.length() == 64;
    for (size_t i = 0; keyValid && i < setupKey.length(); ++i) keyValid = isxdigit(setupKey[i]);
    if (!err && keyValid && setupPass.length() >= 8 && url.startsWith("https://") && token.length() == 43 &&
        doc["mqtt_user"].is<const char*>() && strlen(doc["mqtt_user"]) &&
        doc["mqtt_pass"].is<const char*>() && strlen(doc["mqtt_pass"]) &&
        doc.containsKey("mqtt_prefix") && doc.containsKey("wifi_ssid")) {
      String prefix = doc["mqtt_prefix"].as<String>();
      String ssid = doc["wifi_ssid"].as<String>();
      
      if (prefix.indexOf('/') > 0 && ssid.length() > 0) {
        String uid = prefix.substring(0, prefix.indexOf('/'));
        uid.trim();
        String macPart = prefix.substring(prefix.indexOf('/') + 1);
        macPart.trim();

        String curMac = WiFi.macAddress();

        // Tự động chuẩn hóa MAC: Nếu App gửi unknown_mac, gán lại chính xác bằng MAC phần cứng ESP32
        if (macPart.equalsIgnoreCase("unknown_mac") || macPart.equalsIgnoreCase("unknown") || macPart.length() == 0) {
          prefix = uid + "/" + curMac;
          doc["mqtt_prefix"] = prefix;
          Serial.println("[HTTP-SETUP] ⚠️ Sửa mqtt_prefix từ 'unknown_mac' thành MAC phần cứng thực tế: " + prefix);
        }

        if (uid.length() > 0 && uid != "guest" && uid != "undefined" && uid != "null") {
          if (!saveConfig(doc)) {
            request->send(500, "application/json", R"({"status":"error","message":"Configuration write failed"})");
            return;
          }
          
          // Đảm bảo xóa cờ provisioned cũ nếu có để chờ App xác thực hoàn tất
          if (LittleFS.exists("/provisioned.txt")) {
            LittleFS.remove("/provisioned.txt");
          }

          // Kích hoạt cờ setup pending (Timeout 3 phút = 180s)
          File sp = LittleFS.open("/setup_pending.txt", "w");
          if (!sp || sp.print("1") != 1) {
            request->send(500, "application/json", R"({"status":"error","message":"Provisioning marker write failed"})");
            return;
          }
          sp.close();

          admin_pass = setupPass;
          bindingToken = token;
          if (!saveLocalSecretKey(setupKey)) {
            LittleFS.remove("/setup_pending.txt");
            request->send(500, "application/json", R"({"status":"error","message":"Owner key write failed"})");
            return;
          }

          String curMac = WiFi.macAddress();
          Serial.println("[HTTP-SETUP] 🔐 Liên kết tài khoản [" + uid + "] thành công! Khởi động lại vào chế độ hoạt động sau 1.5s...");
          request->send(200, "application/json", "{\"status\":\"ok\",\"macAddress\":\"" + curMac + "\"}");
          rebootScheduledAt = millis();
          shouldReboot = true; 
          return;
        }
      }
    }

    Serial.println("[HTTP-SETUP] ❌ Gói cấu hình thiếu thông tin liên kết tài khoản ZenHome!");
    request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu thông tin tài khoản ZenHome\"}");
  });

  server.on("/ping", HTTP_GET, [](AsyncWebServerRequest *request) {
    String mac = WiFi.macAddress();
    request->send(200, "application/json", "{\"status\":\"ok\",\"mode\":\"unlinked\",\"unlinked\":true,\"reset\":true,\"macAddress\":\"" + mac + "\"}");
  });

  server.on("/api/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    String mac = WiFi.macAddress();
    request->send(200, "application/json", "{\"status\":\"unlinked\",\"mode\":\"unlinked\",\"unlinked\":true,\"reset\":true,\"macAddress\":\"" + mac + "\"}");
  });

  server.begin();
  Serial.println("Đã mở chế độ AP Setup: " + apName);
  Serial.println("[AP-SECURITY] Chế độ phát Wi-Fi cấu hình: WPA2-PSK (Được bảo vệ)");
}

void connectToWiFi() {
  Serial.println("Đang kết nối WiFi: " + wifi_ssid);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
  
  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 25) {
    esp_task_wdt_reset();
    vTaskDelay(pdMS_TO_TICKS(15)); // [ZH-MED-04] Nhường CPU cho FreeRTOS Task WDT
    delay(500);
    Serial.print(".");
    retries++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi kết nối thành công! IP: " + WiFi.localIP().toString());
    // Thiết lập Public DNS dự phòng (Google 8.8.8.8 & Cloudflare 1.1.1.1) chống lỗi phân giải tên miền từ Router
    WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE, IPAddress(8, 8, 8, 8), IPAddress(1, 1, 1, 1));
    syncTime();
    if (!isWebServerStarted) {
      setupStationWebServer();
      setupUdpDiscovery();
      isWebServerStarted = true;
    }
  } else {
    Serial.print("\nLỖI: Chưa kết nối được WiFi (Mã trạng thái: ");
    Serial.print(WiFi.status());
    Serial.println("). Tiếp tục thử ở vòng lặp nền...");
  }
}

void syncTime() {
  configTime(7 * 3600, 0, "pool.ntp.org", "time.google.com", "time.nist.gov");
  Serial.print("Đang đồng bộ thời gian NTP...");
  time_t now = time(nullptr);
  int retries = 0;
  while (now < 100000 && retries < 10) {
    esp_task_wdt_reset();
    vTaskDelay(pdMS_TO_TICKS(15)); // [ZH-MED-04] Nhường CPU cho FreeRTOS Task WDT
    delay(400);
    Serial.print(".");
    now = time(nullptr);
    retries++;
  }

  if (now >= 100000) {
    Serial.println("\nĐồng bộ thời gian hoàn tất. Unix timestamp: " + String((long)now));
  } else {
    Serial.println("\n[NTP] ⚠️ Chưa đồng bộ được thời gian qua NTP. Tiếp tục thử trong nền.");
  }
}

void checkWiFiConnection() {
  if (((isConfigured && isProvisioned) || isSetupPending) && WiFi.status() != WL_CONNECTED) {
    unsigned long currentMillis = millis();
    static unsigned long lastWiFiLogTime = 0;
    unsigned long retryInterval = isSetupPending ? 4000 : 15000;
    if (currentMillis - lastWiFiRetry >= retryInterval) {
      lastWiFiRetry = currentMillis;
      if (currentMillis - lastWiFiLogTime >= (isSetupPending ? 8000 : 60000) || lastWiFiLogTime == 0) {
        lastWiFiLogTime = currentMillis;
        if (isSetupPending) {
          Serial.println("[WiFi-SETUP] 📡 Đang tự động thử kết nối lại WiFi (" + wifi_ssid + ")...");
        } else {
          Serial.println("[WiFi] 📡 Đang tự động kết nối lại WiFi trong nền (non-blocking)...");
        }
      }
      WiFi.disconnect();
      WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
    }
  }
}

static bool readJsonBody(AsyncWebServerRequest* request, uint8_t* data, size_t len,
                         size_t index, size_t total, String& payload) {
  const size_t maxSize = 8192;
  if (!total || total > maxSize || index > total || len > total - index) {
    if (!index) request->send(413);
    return false;
  }
  if (!index && total == len) {
    payload = String((char*)data, len);
    return true;
  }
  if (!index) request->_tempObject = calloc(total + 1, 1);
  char* buffer = static_cast<char*>(request->_tempObject);
  if (!buffer) { if (!index) request->send(503); return false; }
  memcpy(buffer + index, data, len);
  if (index + len != total) return false;
  payload = String(buffer, total);
  return true;
}

static bool authorizeOwnerRequest(AsyncWebServerRequest* request, const String& op, const String& data) {
  auto header = [request](const char* name) -> String {
    return request->hasHeader(name) ? request->getHeader(name)->value() : String();
  };
  String user = header("X-ZenHome-User");
  String ts = header("X-ZenHome-Timestamp");
  String nonce = header("X-ZenHome-Nonce");
  String sig = header("X-ZenHome-Signature");
  if (isLocalOwner(user) && !isTimestampExpired(ts) &&
      verifyHmacSha256(currentLocalSecretKey, signedLocalPayload(op, user, data, ts, nonce), sig) &&
      !isInvalidLocalNonce(nonce)) {
    softSyncClockFromApp(ts.toInt());
    return true;
  }
  request->send(403, "application/json", R"({"status":"error","code":"FORBIDDEN"})");
  return false;
}

static void sendOwnerReply(AsyncWebServerRequest* request, const String& op, const String& data) {
  String nonce = request->getHeader("X-ZenHome-Nonce")->value();
  DynamicJsonDocument doc(data.length() + 384);
  doc["data"] = data;
  doc["proof"] = computeHmacSha256(currentLocalSecretKey, "reply:" + op + ":" + nonce + ":" + computeSha256OfText(data));
  if (doc.overflowed()) { request->send(503); return; }
  String response;
  serializeJson(doc, response);
  request->send(200, "application/json", response);
}

void setupStationWebServer() {
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Origin", "*");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Headers", "Content-Type, X-ZenHome-Signature, X-ZenHome-Timestamp, X-ZenHome-Nonce");

  // Thiết lập các bẫy Honey-Tokens ẩn đón đầu kẻ quét mạng
  server.on("/.env", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/.env"); });
  server.on("/admin.php", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/admin.php"); });
  server.on("/wp-login.php", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/wp-login.php"); });
  server.on("/api/root", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/api/root"); });
  server.on("/api/admin/debug", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/api/admin/debug"); });
  server.on("/api/system/shell", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/api/system/shell"); });
  server.on("/config.json", HTTP_ANY, [](AsyncWebServerRequest *req) { triggerIntrusionTrap(req, "/config.json"); });

  server.onNotFound([](AsyncWebServerRequest *request) {
    if (request->method() == HTTP_OPTIONS) {
      request->send(200);
    } else {
      request->send(404, "application/json", "{\"status\":\"error\",\"message\":\"Not found\"}");
    }
  });

  // Endpoint 1: Ping / Health check
  server.on("/ping", HTTP_GET, [](AsyncWebServerRequest *request) {
    String mac = WiFi.macAddress();
    String json = "{\"bootNonce\":\"" + localBootNonce() + "\",\"status\":\"ok\",\"service\":\"zenhome_hub\",\"unlinked\":false,\"mode\":\"provisioned\",\"macAddress\":\"" + mac + "\",\"ip\":\"" + WiFi.localIP().toString() + "\",\"secured\":" + String(currentLocalSecretKey.length() > 0 ? "true" : "false") + "}";
    request->send(200, "application/json", json);
  });

  // Endpoint: Quét chẩn đoán xe buýt I2C thời gian thực qua mạng LAN
  server.on("/api/i2c-scan", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!authorizeOwnerRequest(request, "i2c-scan", "")) return;
    if (!lockI2C(pdMS_TO_TICKS(1500))) {
      request->send(503, "application/json", "{\"status\":\"error\",\"message\":\"I2C bus busy\"}");
      return;
    }
    pinMode(21, INPUT_PULLUP);
    pinMode(22, INPUT_PULLUP);
    delay(5);
    int sda = digitalRead(21);
    int scl = digitalRead(22);

    Wire.begin(21, 22, 100000);
    Wire.setTimeOut(50);

    DynamicJsonDocument doc(1024);
    doc["status"] = "ok";
    doc["sdaPin"] = 21;
    doc["sclPin"] = 22;
    doc["sdaLevel"] = sda ? "HIGH" : "LOW";
    doc["sclLevel"] = scl ? "HIGH" : "LOW";
    doc["busHealthy"] = (sda == 1 && scl == 1);

    JsonArray devs = doc.createNestedArray("devicesFound");
    int count = 0;
    for (uint8_t addr = 1; addr < 127; addr++) {
      Wire.beginTransmission(addr);
      if (Wire.endTransmission() == 0) {
        char hex[8];
        snprintf(hex, sizeof(hex), "0x%02X", addr);
        devs.add(hex);
        count++;
      }
    }
    doc["count"] = count;
    doc["pcfFound"] = pcfFound;
    if (pcfFound && activePcfAddress != 0) {
      char hex[8];
      snprintf(hex, sizeof(hex), "0x%02X", activePcfAddress);
      doc["activePcfAddress"] = hex;
    } else {
      doc["activePcfAddress"] = "none";
    }

    unlockI2C();
    String resp;
    serializeJson(doc, resp);
    sendOwnerReply(request, "i2c-scan", resp);
  });

  // [ZH-CRIT-04] XÓA BỎ HOÀN TOÀN backdoor /api/relay-direct không xác thực.
  // Thay thế bằng endpoint /api/relay-secure bắt buộc chữ ký HMAC-SHA256 hoặc mật khẩu quản trị adminPass.
  server.on("/api/relay-secure", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Too many requests\"}");
      return;
    }

    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    StaticJsonDocument<384> doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc.containsKey("pin") || !doc.containsKey("level")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing pin or level\"}");
      return;
    }

    int pin = doc["pin"].as<int>();
    int level = doc["level"].as<int>();
    if (level != 0 && level != 1) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Invalid level (0 or 1)\"}");
      return;
    }

    if (!authorizeOwnerRequest(request, "relay-secure", payload)) return;
    bool applied = false;
    for (int i = 0; i < relayCount; ++i) {
      if (myRelays[i].pin == pin) {
        applied = applyRelayCommand(myRelays[i].id, level == LOW ? "1" : "0", "local_http", 2);
        break;
      }
    }
    if (!applied) {
      request->send(503, "application/json", R"({"status":"error","message":"Relay write failed"})");
      return;
    }
    sendOwnerReply(request, "relay-secure", "{\"status\":\"ok\",\"pin\":" + String(pin) + ",\"level\":" + String(level) + ",\"action\":\"" + (level == 0 ? "BAT (LOW)" : "TAT (HIGH)") + "\"}");
  });

  // Endpoint 1.7: Cập nhật danh sách thiết bị và chân Pin trực tiếp qua LAN (áp dụng tức thì)
  server.on("/api/config/devices", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    DynamicJsonDocument newDoc(2048);
    DeserializationError err = deserializeJson(newDoc, payload);
    if (err) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"JSON khong hop le\"}");
      return;
    }

    if (!authorizeOwnerRequest(request, "config-devices", payload)) return;


    File file = LittleFS.open("/config.json", "r");
    if (!file) {
      request->send(500, "application/json", "{\"status\":\"error\",\"message\":\"Khong mo duoc /config.json\"}");
      return;
    }
    DynamicJsonDocument doc(2048);
    deserializeJson(doc, file);
    file.close();

    if (newDoc.is<JsonArray>()) {
      doc["devices"] = newDoc.as<JsonArray>();
    } else if (newDoc.is<JsonObject>() && newDoc.containsKey("devices")) {
      doc["devices"] = newDoc["devices"].as<JsonArray>();
    } else {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thieu danh sach devices\"}");
      return;
    }

    if (saveConfig(doc)) {
      loadConfig(); // Nạp lại ngay vào RAM myRelays và khởi tạo lại pin PCF8574
      Serial.println("[CONFIG] ✅ Đã cập nhật danh sách thiết bị và chân pin mới vào Flash và RAM!");
      sendOwnerReply(request, "config-devices", "{\"status\":\"ok\",\"message\":\"Da cap nhat devices thanh cong!\"}");
    } else {
      request->send(500, "application/json", "{\"status\":\"error\",\"message\":\"Loi ghi /config.json\"}");
    }
  });

  // Endpoint 2: Lấy toàn diện trạng thái thiết bị & cảm biến mạng LAN
  server.on("/api/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!authorizeOwnerRequest(request, "status", "")) return;
    DynamicJsonDocument doc(1024);
    doc["status"] = "ok";
    doc["service"] = "zenhome_hub";
    doc["unlinked"] = false;
    doc["mode"] = "provisioned";
    doc["macAddress"] = WiFi.macAddress();
    doc["ip"] = WiFi.localIP().toString();
    doc["version"] = FIRMWARE_VERSION_STR;
    doc["build"] = FIRMWARE_BUILD_NUM;
    doc["rssi"] = WiFi.RSSI();
    doc["mqttConnected"] = mqttClient.connected();
    doc["uptime"] = millis() / 1000;
    doc["secured"] = (currentLocalSecretKey.length() > 0);
    doc["bleActive"] = isBleEnabled;

    if (!isnan(cachedTemperature)) {
      doc["temp"] = String(cachedTemperature, 1);
    } else {
      doc["temp"] = "--";
    }

    String reqUser = "";
    if (request->hasHeader("X-ZenHome-User")) {
      reqUser = request->getHeader("X-ZenHome-User")->value();
    } else if (request->hasParam("user")) {
      reqUser = request->getParam("user")->value();
    }

    JsonArray devsArr = doc.createNestedArray("devices");
    if (lockRelayMutex(pdMS_TO_TICKS(500))) {
      for (int i = 0; i < relayCount; i++) {
        if (reqUser.length() > 0 && !isUserAuthorizedForDevice(reqUser, myRelays[i].id)) {
          continue;
        }
        JsonObject devObj = devsArr.createNestedObject();
        devObj["id"] = myRelays[i].id;
        devObj["pin"] = myRelays[i].pin;
        devObj["state"] = myRelays[i].state;
        devObj["anomalyLocked"] = isRelayLockedByAnomaly(myRelays[i].id);
      }
      unlockRelayMutex();
    }

    String response;
    serializeJson(doc, response);
    sendOwnerReply(request, "status", response);
  });

  // Endpoint 2.5: Trao đổi khóa bảo mật Zero-Knowledge giữa App và ESP32
  server.on("/api/auth/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    bool hasKey = (currentLocalSecretKey.length() > 0);
    String res = "{\"status\":\"ok\",\"secured\":" + String(hasKey ? "true" : "false") + "}";
    request->send(200, "application/json", res);
  });

  // Endpoint 2.7: Tự động luân chuyển khóa bí mật
  server.on("/api/auth/rotate-key", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, payload);

    if (!err && doc.containsKey("enc")) {
      String decrypted = decryptEnvelopeWithKeyHex(doc["enc"].as<String>(), currentLocalSecretKey);
      if (decrypted.length() > 0) {
        err = deserializeJson(doc, decrypted);
      }
    }

    if (err || !doc.containsKey("user") || !doc.containsKey("sig") || !doc.containsKey("ts") || !doc.containsKey("nonce")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu tham số chữ ký luân chuyển khóa!\"}");
      return;
    }

    String user = doc["user"].as<String>();
    String sig = doc["sig"].as<String>();
    String ts = doc["ts"].as<String>();
    String nonce = doc["nonce"].as<String>();

    if (isInvalidLocalNonce(nonce) || isTimestampExpired(ts)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"REPLAY_DETECTED\",\"message\":\"Gói tin quá hạn hoặc Replay!\"}");
      return;
    }

    if (!isLocalOwner(user)) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Chỉ Chủ nhà mới có quyền luân chuyển khóa!\"}");
      return;
    }

    String signPayload = "rotate:" + user + ":" + ts + ":" + nonce;
    bool authOk = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);

    if (!authOk) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_BAD_SIG\",\"message\":\"Chữ ký luân chuyển khóa không hợp lệ!\"}");
      return;
    }

    uint8_t newKeyBytes[32];
    for (int i = 0; i < 8; i++) {
      uint32_t r = esp_random();
      memcpy(newKeyBytes + i * 4, &r, 4);
    }
    char newKeyHex[65];
    bytesToHex(newKeyBytes, 32, newKeyHex);
    String newKey = String(newKeyHex);

    String encryptedNewKey = encryptEnvelopeWithKeyHex(newKey, currentLocalSecretKey);
    if (encryptedNewKey.isEmpty() || !saveLocalSecretKey(newKey)) { request->send(500); return; }
    StaticJsonDocument<512> resDoc;
    resDoc["status"] = "ok";
    resDoc["rotated"] = true;
    resDoc["encKey"] = encryptedNewKey;
    resDoc["timestamp"] = time(nullptr);

    String resStr;
    serializeJson(resDoc, resStr);
    request->send(200, "application/json", resStr);
  });

  // Endpoint 3: Điều khiển thiết bị tức thì qua mạng LAN
  server.on("/api/control", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, payload);

    if (!err && doc.containsKey("enc")) {
      String encData = doc["enc"].as<String>();
      String decryptedJson = "";
      if (currentLocalSecretKey.length() > 0) {
        decryptedJson = decryptEnvelopeWithKeyHex(encData, currentLocalSecretKey);
      }
      if (decryptedJson.length() > 0) {
        deserializeJson(doc, decryptedJson);
      }
    }

    if (!doc.containsKey("id") || !doc.containsKey("cmd")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu id hoặc cmd\"}");
      return;
    }

    String devId = doc["id"].as<String>();
    String cmd = doc["cmd"].as<String>();
    String user = doc.containsKey("user") ? doc["user"].as<String>() : (request->hasHeader("X-ZenHome-User") ? request->getHeader("X-ZenHome-User")->value() : "");

    bool isAuthorized = false;
    String sig = request->hasHeader("X-ZenHome-Signature") ? request->getHeader("X-ZenHome-Signature")->value() : (doc.containsKey("sig") ? doc["sig"].as<String>() : "");
    String ts = request->hasHeader("X-ZenHome-Timestamp") ? request->getHeader("X-ZenHome-Timestamp")->value() : (doc.containsKey("ts") ? doc["ts"].as<String>() : "");
    String nonce = request->hasHeader("X-ZenHome-Nonce") ? request->getHeader("X-ZenHome-Nonce")->value() : (doc.containsKey("nonce") ? doc["nonce"].as<String>() : "");

    if (sig.length() > 0 && currentLocalSecretKey.length() > 0) {
      String signPayload = user + ":" + devId + ":" + cmd + ":" + ts + ":" + nonce;
      if (!isTimestampExpired(ts) && verifyHmacSha256(currentLocalSecretKey, signPayload, sig) && !isInvalidLocalNonce(nonce)) {
        softSyncClockFromApp(ts.toInt());
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED\",\"message\":\"Từ chối điều khiển\"}");
      return;
    }

    if (!isLocalOwner(user)) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Không có quyền điều khiển thiết bị này!\"}");
      return;
    }

    unsigned long remainMs = 0;
    if (isRelayLockedByAnomaly(devId, &remainMs)) {
      String res = "{\"status\":\"anomaly_locked\",\"id\":\"" + devId + "\",\"remainSec\":" + String(remainMs / 1000) + ",\"message\":\"Rơ-le đang bị khóa an toàn do chattering/chập tải!\"}";
      request->send(423, "application/json", res);
      return;
    }

    if (cmd != "1" && cmd != "0") { request->send(400); return; }
    if (!applyRelayCommand(devId, cmd, "local_http", 2)) {
      request->send(409, "application/json", R"({"status":"command_failed"})");
      return;
    }
    StaticJsonDocument<384> response;
    response["status"] = "ok";
    response["id"] = devId;
    response["state"] = cmd;
    response["nonce"] = nonce;
    response["proof"] = computeHmacSha256(currentLocalSecretKey, "ack:" + user + ":" + devId + ":" + cmd + ":" + nonce);
    String ack;
    serializeJson(response, ack);
    request->send(200, "application/json", ack);
  });

  // Endpoint 3.5: Cập nhật phân quyền thành viên qua mạng LAN
  server.on("/api/members", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    if (!authorizeOwnerRequest(request, "members", payload)) return;
    saveMembersToFlash(payload);
    parseMembersJson(payload);
    sendOwnerReply(request, "members", "{\"status\":\"ok\",\"message\":\"Đã cập nhật phân quyền thành viên thành công!\"}");
    Serial.println("[LOCAL-HTTP] 📋 Đã nhận và cập nhật danh sách phân quyền thành viên qua LAN!");
  });

  // Endpoint 4: Khởi động lại
  server.on("/api/reboot", HTTP_POST, [](AsyncWebServerRequest *request) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    if (!request->hasHeader("X-ZenHome-Signature") || !request->hasHeader("X-ZenHome-Timestamp") || !request->hasHeader("X-ZenHome-Nonce")) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_NO_SIG\",\"message\":\"Yêu cầu bị từ chối: Thiếu chữ ký bảo mật Local!\"}");
      return;
    }

    String sig = request->getHeader("X-ZenHome-Signature")->value();
    String ts = request->getHeader("X-ZenHome-Timestamp")->value();
    String nonce = request->getHeader("X-ZenHome-Nonce")->value();

    if (isTimestampExpired(ts)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"EXPIRED_TIMESTAMP\",\"message\":\"Gói tin đã quá hạn!\"}");
      return;
    }

    if (isInvalidLocalNonce(nonce)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"REPLAY_DETECTED\",\"message\":\"Phát hiện gói tin trùng lặp!\"}");
      return;
    }

    String signPayload = "reboot:" + ts + ":" + nonce;
    bool authOk = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);
    if (!authOk) {
      Serial.println("[LOCAL-SEC] ❌ Chữ ký bảo mật Local không hợp lệ cho lệnh reboot!");
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_BAD_SIG\",\"message\":\"Chữ ký HMAC không hợp lệ!\"}");
      return;
    }

    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Rebooting...\"}");
    rebootScheduledAt = millis();
    shouldReboot = true;
  });

  // Endpoint 4.5: Cấu hình lại Wi-Fi qua mạng LAN
  server.on("/api/reconfig", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    DynamicJsonDocument body(2048);
    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    if (deserializeJson(body, payload) || !body["data"].is<const char*>()) { request->send(400); return; }
    String envelope = body["data"].as<String>();
    if (!envelope.startsWith("ZHENC1:")) { request->send(400); return; }
    if (!authorizeOwnerRequest(request, "reconfig", envelope)) return;
    String plain = decryptEnvelopeWithKeyHex(envelope, currentLocalSecretKey);
    DynamicJsonDocument doc(1024);
    if (deserializeJson(doc, plain) || !doc["wifi_ssid"].is<const char*>()) { request->send(400); return; }
    String newSsid = doc["wifi_ssid"].as<String>();
    String newPass = doc["wifi_pass"] | "";
    pendingReconfig.mqttUser = doc["mqtt_user"] | "";
    pendingReconfig.mqttPass = doc["mqtt_pass"] | "";
    pendingReconfig.ssid = newSsid;
    pendingReconfig.pass = newPass;
    pendingReconfig.mqttServer = doc.containsKey("mqtt_server") ? doc["mqtt_server"].as<String>() : "";
    pendingReconfig.adminPass = doc.containsKey("admin_pass") ? doc["admin_pass"].as<String>() : "";
    pendingReconfig.requested = true;

    sendOwnerReply(request, "reconfig", "{\"status\":\"ok\",\"message\":\"Đã tiếp nhận cấu hình Wi-Fi mới! Đang khởi động lại...\"}");
    Serial.println("[LOCAL-HTTP] 📡 Đã tiếp nhận cấu hình Wi-Fi mới qua LAN! ESP32 sẽ khởi động lại...");
  });

  // Web OTA Upload
  server.on("/update", HTTP_GET, [](AsyncWebServerRequest* request) {
    request->send(200, "text/plain; charset=utf-8", "Cập nhật firmware qua ZenHome bằng tài khoản chủ sở hữu.");
  });

  // Each upload owns the flash writer until completion or disconnect.
  static AsyncWebServerRequest* uploadOwner = nullptr;
  static mbedtls_sha256_context uploadHash;
  static size_t uploadSize;
  static bool uploadVerified;
  static auto releaseUpload = [](AsyncWebServerRequest* request) {
    if (uploadOwner != request) return;
    if (!uploadVerified) Update.abort();
    mbedtls_sha256_free(&uploadHash);
    uploadOwner = nullptr;
    isOtaInProgress = false;
  };
  server.on("/update", HTTP_POST, [](AsyncWebServerRequest *request) {
    bool ok = uploadOwner == request && uploadVerified;
    releaseUpload(request);
    request->send(ok ? 200 : 400, "application/json", ok ? R"({"status":"ok"})" : R"({"status":"error"})");
    if (ok) { rebootScheduledAt = millis(); shouldReboot = true; }
  }, [](AsyncWebServerRequest *request, String, size_t index, uint8_t *data, size_t len, bool final) {
    if (index == 0) {
      if (uploadOwner == request) { releaseUpload(request); return; }
      if (uploadOwner ||
          !request->hasParam("build", true) || request->getParam("build", true)->value().toInt() < FIRMWARE_BUILD_NUM ||
          !request->hasParam("signatureHex", true)) return;
      String manifest = request->getParam("build", true)->value() + ":" + request->getParam("signatureHex", true)->value();
      if (!authorizeOwnerRequest(request, "ota-upload", manifest) || isOtaInProgress.exchange(true)) return;
      uploadOwner = request;
      uploadVerified = false;
      uploadSize = 0;
      mbedtls_sha256_init(&uploadHash);
      request->onDisconnect([request]() { releaseUpload(request); });
      if (mbedtls_sha256_starts_ret(&uploadHash, 0) || !Update.begin(UPDATE_SIZE_UNKNOWN)) {
        releaseUpload(request);
        return;
      }
    }
    if (uploadOwner != request) return;
    if (uploadVerified || uploadSize != index || mbedtls_sha256_update_ret(&uploadHash, data, len) ||
        Update.write(data, len) != len) { releaseUpload(request); return; }
    uploadSize += len;
    if (final) {
      uint8_t digest[32];
      const String& signature = request->getParam("signatureHex", true)->value();
      if (mbedtls_sha256_finish_ret(&uploadHash, digest) ||
          !verifyFirmwareEcdsaSignature(digest, signature) || !Update.end(true)) {
        releaseUpload(request);
        return;
      }
      uploadVerified = true;
    }
  });

  server.on("/api/ota", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    if (isOtaInProgress) {
      request->send(409, "application/json", "{\"status\":\"busy\",\"message\":\"Quá trình OTA đang diễn ra. Vui lòng đợi!\"}");
      return;
    }
    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    DynamicJsonDocument doc(1536);
    if (deserializeJson(doc, payload) || !doc.containsKey("url")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu url firmware\"}");
      return;
    }

    if (!authorizeOwnerRequest(request, "ota", payload)) return;

    // [ZH-HIGH-19] Anti-Rollback firmware check: Bắt buộc build >= FIRMWARE_BUILD_NUM
    int newBuild = -1;
    if (doc.containsKey("build")) {
      newBuild = doc["build"].as<int>();
    } else if (doc.containsKey("newBuild")) {
      newBuild = doc["newBuild"].as<int>();
    } else if (doc.containsKey("buildNumber")) {
      newBuild = doc["buildNumber"].as<int>();
    }
    if (newBuild < FIRMWARE_BUILD_NUM) {
      Serial.printf("[OTA] ⛔ ANTI-ROLLBACK: Từ chối hạ cấp firmware! Bản hiện tại: %d, bản yêu cầu: %d\n", FIRMWARE_BUILD_NUM, newBuild);
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"ANTI_ROLLBACK\",\"message\":\"Từ chối hạ cấp firmware về phiên bản cũ có lỗ hổng!\"}");
      return;
    }

    String fwUrl = doc["url"].as<String>();
    String expectedSha = doc.containsKey("sha256") ? doc["sha256"].as<String>() : "";
    String sigHex = doc.containsKey("sig") ? doc["sig"].as<String>() : "";
    if (!fwUrl.startsWith("https://") || expectedSha.length() != 64 || sigHex.isEmpty()) {
      request->send(400, "application/json", R"({"status":"error","message":"Invalid OTA manifest"})");
      return;
    }
    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Đã tiếp nhận yêu cầu OTA. Đang bắt đầu tải firmware...\"}");
    performServerOtaUpdate(fwUrl, expectedSha, sigHex, newBuild);
  });

  server.on("/api/rules", HTTP_GET, [](AsyncWebServerRequest *request) {
    if (!authorizeOwnerRequest(request, "rules-get", "")) return;
    DynamicJsonDocument doc(2048);
    doc["status"] = "ok";

    String reqUser = "";
    if (request->hasHeader("X-ZenHome-User")) {
      reqUser = request->getHeader("X-ZenHome-User")->value();
    } else if (request->hasParam("user")) {
      reqUser = request->getParam("user")->value();
    }

    JsonArray arr = doc.createNestedArray("rules");
    int visibleCount = 0;
    for (int i = 0; i < localRuleCount; i++) {
      if (reqUser.length() > 0 && !isUserAuthorizedForDevice(reqUser, localRules[i].targetDevId)) {
        continue;
      }
      JsonObject obj = arr.createNestedObject();
      obj["id"] = localRules[i].id;
      obj["enabled"] = localRules[i].enabled;
      obj["type"] = localRules[i].type;
      obj["targetDevId"] = localRules[i].targetDevId;
      if (strcmp(localRules[i].type, "temp_auto") == 0) {
        obj["triggerTemp"] = localRules[i].triggerTemp;
        obj["tempCond"] = localRules[i].tempCond;
        obj["actionState"] = localRules[i].actionState;
      } else if (strcmp(localRules[i].type, "countdown") == 0) {
        obj["autoOffSec"] = localRules[i].autoOffSec;
      }
      visibleCount++;
    }
    doc["ruleCount"] = visibleCount;
    String res;
    serializeJson(doc, res);
    sendOwnerReply(request, "rules-get", res);
  });

  server.on("/api/rules", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Thử lại sau!\"}");
      return;
    }
    String payload;
    if (!readJsonBody(request, data, len, index, total, payload)) return;
    if (!authorizeOwnerRequest(request, "rules-set", payload)) return;
    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc.containsKey("rules")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Payload không hợp lệ\"}");
      return;
    }

    String user = doc.containsKey("user") ? doc["user"].as<String>() : "";
    if (request->hasHeader("X-ZenHome-User")) {
      user = request->getHeader("X-ZenHome-User")->value();
    }
    if (!isLocalOwner(user)) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Chỉ Quản trị viên/Chủ nhà mới có quyền cập nhật tự động hóa!\"}");
      return;
    }

    JsonArray arr = doc["rules"].as<JsonArray>();
    localRuleCount = 0;
    for (JsonObject obj : arr) {
      if (localRuleCount >= MAX_LOCAL_RULES) break;
      LocalRule& r = localRules[localRuleCount];
      r.enabled = obj["enabled"] | true;
      // [ZH-MED-02] Bổ sung kết thúc chuỗi \0 tường minh chống tràn bộ đệm
      strncpy(r.id, obj["id"] | "", sizeof(r.id) - 1);
      r.id[sizeof(r.id) - 1] = '\0';
      strncpy(r.type, obj["type"] | "temp_auto", sizeof(r.type) - 1);
      r.type[sizeof(r.type) - 1] = '\0';
      strncpy(r.targetDevId, obj["targetDevId"] | "", sizeof(r.targetDevId) - 1);
      r.targetDevId[sizeof(r.targetDevId) - 1] = '\0';
      r.triggerTemp = obj["triggerTemp"] | 0.0f;
      strncpy(r.tempCond, obj["tempCond"] | ">=", sizeof(r.tempCond) - 1);
      r.tempCond[sizeof(r.tempCond) - 1] = '\0';
      strncpy(r.actionState, obj["actionState"] | "1", sizeof(r.actionState) - 1);
      r.actionState[sizeof(r.actionState) - 1] = '\0';
      r.autoOffSec = obj["autoOffSec"] | 0;
      r.turnOnTime = 0;
      r.isCountingDown = false;
      r.lastTriggerTime = 0;
      localRuleCount++;
    }
    saveLocalRulesToFlash();
    sendOwnerReply(request, "rules-set", "{\"status\":\"ok\",\"message\":\"Đã lưu quy tắc tự động hóa vào Flash!\"}");
  });

  server.begin();
  Serial.println("[HTTP] Web Server cục bộ (Local LAN) đã khởi động trên cổng 80!");
}

void setupUdpDiscovery() {
  if (!isUdpStarted) {
    if (udpDiscovery.begin(UDP_DISCOVERY_PORT)) {
      isUdpStarted = true;
      Serial.printf("[UDP] Lắng nghe phát hiện thiết bị mạng LAN trên cổng %d\n", UDP_DISCOVERY_PORT);
    }
  }
}

void checkUdpDiscovery() {
  if (!isUdpStarted) return;
  int packetSize = udpDiscovery.parsePacket();
  if (packetSize) {
    char packetBuffer[255];
    int len = udpDiscovery.read(packetBuffer, 254);
    if (len > 0) {
      packetBuffer[len] = 0;
    }
    String message = String(packetBuffer);
    message.trim();

    if (message.indexOf("ZENHOME_DISCOVER") != -1) {
      IPAddress remoteIp = udpDiscovery.remoteIP();
      uint16_t remotePort = udpDiscovery.remotePort();
      String mac = WiFi.macAddress();
      mac.replace(":", "");

      StaticJsonDocument<256> resDoc;
      resDoc["service"] = "zenhome_hub";
      resDoc["macAddress"] = mac;
      resDoc["ip"] = WiFi.localIP().toString();
      resDoc["port"] = 80;
      resDoc["name"] = "ZenHome Hub";
      resDoc["mqtt_prefix"] = mqtt_prefix;
      
      if (!isnan(cachedTemperature)) {
        resDoc["temp"] = String(cachedTemperature, 1);
      } else {
        resDoc["temp"] = "--";
      }

      String reply;
      serializeJson(resDoc, reply);

      udpDiscovery.beginPacket(remoteIp, remotePort);
      udpDiscovery.print(reply);
      udpDiscovery.endPacket();

      static unsigned long lastUdpLogTime = 0;
      if (millis() - lastUdpLogTime >= 60000) {
        lastUdpLogTime = millis();
        Serial.println("[UDP] Đã phản hồi vị trí Hub tới App (" + remoteIp.toString() + ")");
      }
    }
  }
}
