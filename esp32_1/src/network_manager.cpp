#include "network_manager.h"
#include "config_manager.h"
#include "security_manager.h"
#include "hardware_manager.h"
#include "mqtt_manager.h"
#include "ble_manager.h"

#include <esp_task_wdt.h>
#include <Update.h>

AsyncWebServer server(80);
WiFiUDP udpDiscovery;
bool isWebServerStarted = false;
bool isUdpStarted = false;
unsigned long lastWiFiRetry = 0;

void setupAPMode() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();
  String apName = "ZenHome_Setup_" + mac.substring(6);
  String apPass = "12345678"; 

  WiFi.mode(WIFI_AP);
  WiFi.softAP(apName.c_str(), apPass.c_str()); 

  server.on("/api/config", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    String jsonPayload((char*)data, len);
    Serial.println("\n[HTTP-SETUP] >>> Nhận gói cấu hình liên kết từ App (Thông tin nhạy cảm đã được che an toàn).");

    DynamicJsonDocument doc(2048);
    DeserializationError err = deserializeJson(doc, jsonPayload);
    if (!err && doc.containsKey("mqtt_prefix") && doc.containsKey("wifi_ssid")) {
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
          File file = LittleFS.open("/config.json", "w");
          if (file) {
            serializeJson(doc, file);
            file.close();
          }
          
          // Đảm bảo xóa cờ provisioned cũ nếu có để chờ App xác thực hoàn tất
          if (LittleFS.exists("/provisioned.txt")) {
            LittleFS.remove("/provisioned.txt");
          }

          // Kích hoạt cờ setup pending (Timeout 3 phút = 180s)
          File sp = LittleFS.open("/setup_pending.txt", "w");
          if (sp) {
            sp.print("1");
            sp.close();
          }

          // Phái sinh và lưu Secret Key từ admin_pass nếu có
          if (doc.containsKey("admin_pass")) {
            String adminPass = doc["admin_pass"].as<String>();
            String curMac = WiFi.macAddress();
            curMac.replace(":", "");
            curMac.toUpperCase();
            String keySeed = "ZenHome_Key_Salt:" + adminPass + ":" + curMac;
            saveLocalSecretKey(computeSha256OfText(keySeed));
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
  WiFi.setSleep(false); // Vô hiệu hóa Modem Sleep: Giữ ổn định kết nối RF, chống jitter và triệt tiêu xung dòng wakeup gây sụt áp Brownout
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
  
  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 25) {
    esp_task_wdt_reset();
    delay(500);
    Serial.print(".");
    retries++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi kết nối thành công! IP: " + WiFi.localIP().toString());
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
  while (now < 100000 && retries < 15) {
    esp_task_wdt_reset();
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
    String json = "{\"status\":\"ok\",\"service\":\"zenhome_hub\",\"unlinked\":false,\"mode\":\"provisioned\",\"macAddress\":\"" + mac + "\",\"ip\":\"" + WiFi.localIP().toString() + "\",\"secured\":" + String(currentLocalSecretKey.length() > 0 ? "true" : "false") + "}";
    request->send(200, "application/json", json);
  });

  // Endpoint 2: Lấy toàn diện trạng thái thiết bị & cảm biến mạng LAN
  server.on("/api/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    StaticJsonDocument<768> doc;
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
    for (int i = 0; i < relayCount; i++) {
      if (reqUser.length() > 0 && !isUserAuthorizedForDevice(reqUser, myRelays[i].id)) {
        continue;
      }
      JsonObject devObj = devsArr.createNestedObject();
      devObj["id"] = myRelays[i].id;
      devObj["state"] = myRelays[i].state;
    }

    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });

  // Endpoint 2.5: Trao đổi khóa bảo mật Zero-Knowledge giữa App và ESP32
  server.on("/api/auth/key-exchange", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    String payload((char*)data, len);
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, payload);

    if (err || !doc.containsKey("clientPublicKey")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu clientPublicKey\"}");
      return;
    }

    if (currentLocalSecretKey.length() > 0) {
      String adminPass = doc.containsKey("adminPass") ? doc["adminPass"].as<String>() : "";
      if (admin_pass.length() > 0 && adminPass != admin_pass) {
        Serial.println("[LOCAL-SEC] ⚠️ Từ chối tái tạo khóa Zero-Knowledge: Sai mật khẩu quản trị!");
        request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_ADMIN\",\"message\":\"Yêu cầu bị từ chối: Cần mật khẩu quản trị để tái tạo khóa!\"}");
        return;
      }
    }

    String clientPub = doc["clientPublicKey"].as<String>();
    clientPub.toLowerCase();

    // 1. Sinh khóa bí mật b (256-bit)
    char bBuf[65];
    for (int i = 0; i < 8; i++) {
      uint32_t r = esp_random();
      sprintf(bBuf + i * 8, "%08x", r);
    }
    bBuf[64] = 0;
    String privateB = String(bBuf);

    // 2. Tính khóa công khai B = g^b mod p
    String serverPub = dhModPow("2", privateB, DH_PRIME_1536);

    // 3. Tính khóa chia sẻ chung S = A^b mod p
    String sharedSecret = dhModPow(clientPub, privateB, DH_PRIME_1536);

    // 4. Băm SHA-256 để tạo khóa đối xứng K
    String derivedKey = computeSha256Hex(sharedSecret);

    // 5. Lưu khóa bí mật vào Flash nội bộ ESP32
    saveLocalSecretKey(derivedKey);

    // 6. Tính bằng chứng xác thực Proof = HMAC(K, clientPub + ":" + serverPub)
    String proof = computeHmacSha256(derivedKey, clientPub + ":" + serverPub);

    StaticJsonDocument<768> resDoc;
    resDoc["status"] = "ok";
    resDoc["serverPublicKey"] = serverPub;
    resDoc["proof"] = proof;

    String resStr;
    serializeJson(resDoc, resStr);
    request->send(200, "application/json", resStr);
    Serial.println("[LOCAL-SEC] 🤝 Trao đổi khóa Zero-Knowledge với App thành công! Khóa an toàn 100%.");
  });

  // Endpoint 2.6: Kiểm tra trạng thái bảo mật của Hub
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

    String payload((char*)data, len);
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, payload);

    if (!err && doc.containsKey("enc")) {
      String decrypted = decryptStorageString(doc["enc"].as<String>());
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

    if (isNonceReplayedOrInvalid(nonce) || isTimestampExpired(ts)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"REPLAY_DETECTED\",\"message\":\"Gói tin quá hạn hoặc Replay!\"}");
      return;
    }

    if (!isUserAuthorizedForDevice(user, "*")) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Chỉ Chủ nhà mới có quyền luân chuyển khóa!\"}");
      return;
    }

    String signPayload = "rotate:" + user + ":" + ts + ":" + nonce;
    bool authOk = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);

    if (!authOk && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      authOk = verifyHmacSha256(masterKey, signPayload, sig);
    }

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

    saveLocalSecretKey(newKey);
    Serial.println("[LOCAL-SEC] 🔄 Luân chuyển khóa bí mật thành công! Khóa mới: " + newKey.substring(0, 8) + "...");

    String encryptedNewKey = encryptStorageString(newKey);
    StaticJsonDocument<512> resDoc;
    resDoc["status"] = "ok";
    resDoc["rotated"] = true;
    resDoc["encKey"] = encryptedNewKey;
    resDoc["keyPrefix"] = newKey.substring(0, 8);
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

    String payload((char*)data, len);
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, payload);

    if (!err && doc.containsKey("enc")) {
      String encData = doc["enc"].as<String>();
      String decryptedJson = "";
      if (currentLocalSecretKey.length() > 0) {
        decryptedJson = decryptEnvelopeWithKeyHex(encData, currentLocalSecretKey);
      }
      if (decryptedJson.length() == 0 && admin_pass.length() > 0) {
        String mac = WiFi.macAddress();
        mac.replace(":", "");
        mac.toUpperCase();
        String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
        decryptedJson = decryptEnvelopeWithKeyHex(encData, masterKey);
        if (decryptedJson.length() > 0) {
          currentLocalSecretKey = masterKey;
          saveLocalSecretKey(masterKey);
        }
      }
      if (decryptedJson.length() == 0) {
        decryptedJson = decryptStorageString(encData);
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

    // Xác thực ủy quyền an toàn (Khắc phục ZH-04):
    // Chấp nhận nếu:
    // 1. Gửi đúng adminPass của Hub (constant-time compare)
    // 2. Hoặc có chữ ký số HMAC-SHA256 hợp lệ với Master Key
    bool isAuthorized = false;
    bool isAdminAuthorized = false;

    if (doc.containsKey("adminPass")) {
      String sentPass = doc["adminPass"].as<String>();
      if (admin_pass.length() > 0 && constantTimeCompare(sentPass, admin_pass)) {
        isAdminAuthorized = true;
        isAuthorized = true;
      }
    }

    String sig = request->hasHeader("X-ZenHome-Signature") ? request->getHeader("X-ZenHome-Signature")->value() : (doc.containsKey("sig") ? doc["sig"].as<String>() : "");
    String ts = request->hasHeader("X-ZenHome-Timestamp") ? request->getHeader("X-ZenHome-Timestamp")->value() : (doc.containsKey("ts") ? doc["ts"].as<String>() : "");
    String nonce = request->hasHeader("X-ZenHome-Nonce") ? request->getHeader("X-ZenHome-Nonce")->value() : (doc.containsKey("nonce") ? doc["nonce"].as<String>() : "");

    if (sig.length() > 0 && currentLocalSecretKey.length() > 0) {
      String signPayload = user + ":" + devId + ":" + cmd + ":" + ts + ":" + nonce;
      if (verifyHmacSha256(currentLocalSecretKey, signPayload, sig)) {
        isAuthorized = true;
      }
    }

    if (!isAuthorized) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED\",\"message\":\"Từ chối điều khiển\"}");
      return;
    }

    bool isOwnerUser = isAdminAuthorized || (user.length() > 0 && (user.equalsIgnoreCase("owner") || (cachedOwner.length() > 0 && user.equalsIgnoreCase(cachedOwner))));
    if (!isOwnerUser && user.length() > 0 && !isUserAuthorizedForDevice(user, devId)) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Không có quyền điều khiển thiết bị này!\"}");
      return;
    }

    String targetState = (cmd == "1" || cmd == "ON" || cmd == "true") ? "1" : "0";
    bool ok = applyRelayCommand(devId, targetState, "local_http", 2);

    if (ok) {
      String res = "{\"status\":\"ok\",\"id\":\"" + devId + "\",\"state\":\"" + targetState + "\"}";
      request->send(200, "application/json", res);
    } else {
      // Tìm xem thiết bị có tồn tại không
      String curState = "0";
      bool devExists = false;
      for (int i = 0; i < relayCount; i++) {
        if (myRelays[i].id == devId) {
          devExists = true;
          curState = myRelays[i].state;
          break;
        }
      }
      if (devExists) {
        // Thiết bị tồn tại nhưng bị chặn gạt quá nhanh (Relay Guard): Trả về 200 kèm trạng thái hiện tại
        String res = "{\"status\":\"guard_blocked\",\"id\":\"" + devId + "\",\"state\":\"" + curState + "\",\"message\":\"Thao tác quá nhanh, đã phản hồi trạng thái hiện tại\"}";
        request->send(200, "application/json", res);
      } else {
        request->send(404, "application/json", "{\"status\":\"error\",\"message\":\"Không tìm thấy thiết bị\"}");
      }
    }
  });

  // Endpoint 3.5: Cập nhật phân quyền thành viên qua mạng LAN
  server.on("/api/members", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    String payload((char*)data, len);

    if (currentLocalSecretKey.length() == 0 && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      currentLocalSecretKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      saveLocalSecretKey(currentLocalSecretKey);
    }

    if (!request->hasHeader("X-ZenHome-Signature") || !request->hasHeader("X-ZenHome-Timestamp") || !request->hasHeader("X-ZenHome-Nonce")) {
      request->send(401, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu chữ ký bảo mật Local!\"}");
      return;
    }
    String sig = request->getHeader("X-ZenHome-Signature")->value();
    String ts = request->getHeader("X-ZenHome-Timestamp")->value();
    String nonce = request->getHeader("X-ZenHome-Nonce")->value();

    if (isTimestampExpired(ts) || isNonceReplayedOrInvalid(nonce)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"message\":\"Gói tin quá hạn hoặc replay attack!\"}");
      return;
    }

    String signPayload = "members:" + ts + ":" + nonce;
    bool sigValid = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);
    if (!sigValid && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      sigValid = verifyHmacSha256(masterKey, signPayload, sig);
    }
    if (!sigValid) {
      request->send(401, "application/json", "{\"status\":\"error\",\"message\":\"Chữ ký bảo mật không hợp lệ!\"}");
      return;
    }

    saveMembersToFlash(payload);
    parseMembersJson(payload);
    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Đã cập nhật phân quyền thành viên thành công!\"}");
    Serial.println("[LOCAL-HTTP] 📋 Đã nhận và cập nhật danh sách phân quyền thành viên qua LAN!");
  });

  // Endpoint 4: Khởi động lại
  server.on("/api/reboot", HTTP_POST, [](AsyncWebServerRequest *request) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Quá nhiều yêu cầu. Vui lòng thử lại sau!\"}");
      return;
    }

    if (currentLocalSecretKey.length() == 0 && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      currentLocalSecretKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      saveLocalSecretKey(currentLocalSecretKey);
    }

    if (currentLocalSecretKey.length() == 0) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_UNCONFIGURED\",\"message\":\"Hub chưa được cấu hình khóa bảo mật!\"}");
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

    if (isNonceReplayedOrInvalid(nonce)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"REPLAY_DETECTED\",\"message\":\"Phát hiện gói tin trùng lặp!\"}");
      return;
    }

    String signPayload = "reboot:" + ts + ":" + nonce;
    bool authOk = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);
    if (!authOk && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      authOk = verifyHmacSha256(masterKey, signPayload, sig);
    }

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

    String payload((char*)data, len);
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err || !doc.containsKey("wifi_ssid")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu thông tin wifi_ssid\"}");
      return;
    }

    String newSsid = doc["wifi_ssid"].as<String>();
    String newPass = doc.containsKey("wifi_pass") ? doc["wifi_pass"].as<String>() : "";
    String user = doc.containsKey("user") ? doc["user"].as<String>() : "";

    bool authOk = false;
    if (doc.containsKey("admin_pass")) {
      String sentAdmin = doc["admin_pass"].as<String>();
      if (admin_pass.length() > 0 && constantTimeCompare(sentAdmin, admin_pass)) {
        authOk = true;
      }
    }

    if (!authOk && currentLocalSecretKey.length() == 0 && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      currentLocalSecretKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      saveLocalSecretKey(currentLocalSecretKey);
    }

    if (!authOk) {
      if (!request->hasHeader("X-ZenHome-Signature") || !request->hasHeader("X-ZenHome-Timestamp") || !request->hasHeader("X-ZenHome-Nonce")) {
        request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_NO_SIG\",\"message\":\"Thiếu chữ ký bảo mật Local hoặc mật khẩu admin!\"}");
        return;
      }

      String sig = request->getHeader("X-ZenHome-Signature")->value();
      String ts = request->getHeader("X-ZenHome-Timestamp")->value();
      String nonce = request->getHeader("X-ZenHome-Nonce")->value();

      if (isTimestampExpired(ts) || isNonceReplayedOrInvalid(nonce)) {
        request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"EXPIRED_OR_REPLAY\",\"message\":\"Gói tin quá hạn hoặc Replay attack!\"}");
        return;
      }

      String signPayload = "reconfig:" + newSsid + ":" + ts + ":" + nonce;
      if (currentLocalSecretKey.length() > 0) {
        authOk = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);
      }

      if (!authOk && admin_pass.length() > 0) {
        String mac = WiFi.macAddress();
        mac.replace(":", "");
        mac.toUpperCase();
        String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
        authOk = verifyHmacSha256(masterKey, signPayload, sig);
      }

      if (!authOk) {
        request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_BAD_SIG\",\"message\":\"Chữ ký bảo mật không hợp lệ!\"}");
        return;
      }
    }

    if (user.length() > 0 && !isUserAuthorizedForDevice(user, "*")) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Người dùng không có quyền quản trị để đổi Wi-Fi!\"}");
      return;
    }

    pendingReconfig.ssid = newSsid;
    pendingReconfig.pass = newPass;
    pendingReconfig.mqttServer = doc.containsKey("mqtt_server") ? doc["mqtt_server"].as<String>() : "";
    pendingReconfig.adminPass = doc.containsKey("admin_pass") ? doc["admin_pass"].as<String>() : "";
    pendingReconfig.requested = true;

    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Đã tiếp nhận cấu hình Wi-Fi mới! Đang khởi động lại...\"}");
    Serial.println("[LOCAL-HTTP] 📡 Đã tiếp nhận cấu hình Wi-Fi mới qua LAN! ESP32 sẽ khởi động lại...");
  });

  // Web OTA Upload
  server.on("/update", HTTP_GET, [](AsyncWebServerRequest *request) {
    static const char otaHtml[] PROGMEM = 
      "<!DOCTYPE html><html lang='vi'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
      "<title>ZenHome Hub - Nâng Cấp Firmware OTA</title>"
      "<style>"
      "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0F172A;color:#F8FAFC;margin:0;padding:24px;display:flex;justify-content:center;align-items:center;min-height:100vh;box-sizing:border-box}"
      ".card{background:#1E293B;border:1px solid rgba(255,255,255,0.1);border-radius:20px;padding:32px;max-width:440px;width:100%;box-shadow:0 20px 40px rgba(0,0,0,0.4);text-align:center}"
      "h1{font-size:22px;margin-bottom:8px;color:#38BDF8;font-weight:700}p{font-size:13.5px;color:#94A3B8;margin-top:0;margin-bottom:24px}"
      ".input-group{text-align:left;margin-bottom:18px}label{font-size:12.5px;font-weight:600;color:#CBD5E1;display:block;margin-bottom:6px}"
      "input[type=password],input[type=file]{width:100%;box-sizing:border-box;padding:12px;background:#0F172A;border:1px solid rgba(255,255,255,0.15);border-radius:12px;color:white;font-size:14px;outline:none}"
      ".btn{background:linear-gradient(135deg,#0284C7,#0369A1);color:white;border:none;border-radius:12px;padding:14px;width:100%;font-size:15px;font-weight:700;cursor:pointer;margin-top:10px}"
      ".btn:hover{opacity:0.9}.progress-bar{height:8px;width:100%;background:#334155;border-radius:4px;overflow:hidden;margin-top:20px;display:none}"
      ".progress-fill{height:100%;width:0%;background:#10B981;transition:width 0.2s}"
      "#status{margin-top:14px;font-size:13px;font-weight:600;color:#38BDF8;min-height:20px}"
      "</style></head><body><div class='card'>"
      "<h1>ZenHome Hub OTA</h1><p>Nâng cấp trực tiếp Firmware ESP32 qua mạng cục bộ</p>"
      "<form id='f' enctype='multipart/form-data'>"
      "<div class='input-group'><label>Mật Khẩu Quản Trị (Admin Pass)</label><input type='password' id='p' placeholder='Nhập mật khẩu quản trị...' required></div>"
      "<div class='input-group'><label>File Firmware (.bin)</label><input type='file' id='file' accept='.bin' required></div>"
      "<button type='submit' class='btn' id='b'>Bắt Đầu Nâng Cấp</button>"
      "<div class='progress-bar' id='pb'><div class='progress-fill' id='pf'></div></div>"
      "<div id='status'></div></form></div>"
      "<script>"
      "document.getElementById('f').onsubmit=function(e){e.preventDefault();"
      "var f=document.getElementById('file').files[0];var p=document.getElementById('p').value;"
      "if(!f)return;var fd=new FormData();fd.append('update',f);fd.append('adminPass',p);"
      "var x=new XMLHttpRequest();x.open('POST','/update',true);"
      "document.getElementById('pb').style.display='block';document.getElementById('b').disabled=true;"
      "document.getElementById('status').innerText='Đang tải lên và nạp Flash...';"
      "x.upload.onprogress=function(e){if(e.lengthComputable){var pc=Math.round((e.loaded/e.total)*100);"
      "document.getElementById('pf').style.width=pc+'%';document.getElementById('status').innerText='Đang nạp: '+pc+'%';}};"
      "x.onload=function(){if(x.status==200){document.getElementById('status').style.color='#10B981';"
      "document.getElementById('status').innerText='✅ Nạp thành công! Hub đang khởi động lại...';setTimeout(function(){location.reload();},8000);}"
      "else{document.getElementById('status').color='#EF4444';document.getElementById('status').innerText='❌ Thất bại: '+x.responseText;"
      "document.getElementById('b').disabled=false;}};"
      "x.send(fd);};"
      "</script></body></html>";
    request->send(200, "text/html", otaHtml);
  });

  server.on("/update", HTTP_POST, [](AsyncWebServerRequest *request) {
    bool shouldRestart = !Update.hasError() && Update.isFinished();
    int resCode = shouldRestart ? 200 : 401;
    AsyncWebServerResponse *response = request->beginResponse(resCode, "application/json", 
      shouldRestart ? "{\"status\":\"ok\",\"message\":\"Nâng cấp OTA thành công! ESP32 đang khởi động lại...\"}" 
                    : "{\"status\":\"error\",\"message\":\"Nâng cấp OTA thất bại hoặc chưa được ủy quyền!\"}");
    response->addHeader("Connection", "close");
    request->send(response);
    if (shouldRestart) {
      rebootScheduledAt = millis();
      shouldReboot = true;
    }
  }, [](AsyncWebServerRequest *request, String filename, size_t index, uint8_t *data, size_t len, bool final) {
    static bool isAuthorizedUpload = false;
    if (!index) {
      isAuthorizedUpload = false;
      String adminReq = request->hasParam("adminPass", true) ? request->getParam("adminPass", true)->value() : "";
      if (admin_pass.length() == 0 || !constantTimeCompare(adminReq, admin_pass)) {
        Serial.println("[WEB-OTA] ⛔ Từ chối nâng cấp firmware: Sai hoặc chưa cấu hình mật khẩu quản trị!");
        Update.abort();
        return;
      }
      isAuthorizedUpload = true;

      Serial.printf("[WEB-OTA] 🚀 Bắt đầu tiếp nhận file Firmware: %s\n", filename.c_str());
      if (!Update.begin(UPDATE_SIZE_UNKNOWN)) {
        Update.printError(Serial);
      }
    }

    if (!isAuthorizedUpload) {
      return;
    }

    if (!Update.hasError()) {
      if (Update.write(data, len) != len) {
        Update.printError(Serial);
      }
    }

    if (final) {
      if (Update.end(true)) {
        Serial.printf("[WEB-OTA] ✅ Nạp thành công: %u bytes! Khởi động lại ESP32...\n", index + len);
      } else {
        Update.printError(Serial);
      }
      isAuthorizedUpload = false;
    }
  });

  server.on("/api/ota", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    if (isOtaInProgress) {
      request->send(409, "application/json", "{\"status\":\"busy\",\"message\":\"Quá trình OTA đang diễn ra. Vui lòng đợi!\"}");
      return;
    }
    String payload((char*)data, len);
    StaticJsonDocument<256> doc;
    if (deserializeJson(doc, payload) || !doc.containsKey("url")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu url firmware\"}");
      return;
    }

    String sentAdmin = doc.containsKey("adminPass") ? doc["adminPass"].as<String>() : (doc.containsKey("admin_pass") ? doc["admin_pass"].as<String>() : "");
    if (admin_pass.length() == 0 || !constantTimeCompare(sentAdmin, admin_pass)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_ADMIN\",\"message\":\"Sai hoặc chưa cấu hình mật khẩu quản trị!\"}");
      return;
    }

    String fwUrl = doc["url"].as<String>();
    String expectedSha = doc.containsKey("sha256") ? doc["sha256"].as<String>() : "";
    String sigHex = doc.containsKey("sig") ? doc["sig"].as<String>() : "";
    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Đã tiếp nhận yêu cầu OTA. Đang bắt đầu tải firmware...\"}");
    performServerOtaUpdate(fwUrl, expectedSha, sigHex);
  });

  server.on("/api/rules", HTTP_GET, [](AsyncWebServerRequest *request) {
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
    request->send(200, "application/json", res);
  });

  server.on("/api/rules", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    uint32_t clientIp = (uint32_t)request->client()->remoteIP();
    if (isClientRateLimited(clientIp)) {
      request->send(429, "application/json", "{\"status\":\"error\",\"code\":\"TOO_MANY_REQUESTS\",\"message\":\"Thử lại sau!\"}");
      return;
    }
    String payload((char*)data, len);

    if (currentLocalSecretKey.length() == 0 && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      currentLocalSecretKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      saveLocalSecretKey(currentLocalSecretKey);
    }

    if (!request->hasHeader("X-ZenHome-Signature") || !request->hasHeader("X-ZenHome-Timestamp") || !request->hasHeader("X-ZenHome-Nonce")) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_NO_SIG\",\"message\":\"Thiếu chữ ký bảo mật Local!\"}");
      return;
    }
    String sig = request->getHeader("X-ZenHome-Signature")->value();
    String ts = request->getHeader("X-ZenHome-Timestamp")->value();
    String nonce = request->getHeader("X-ZenHome-Nonce")->value();

    if (isTimestampExpired(ts) || isNonceReplayedOrInvalid(nonce)) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"EXPIRED_OR_REPLAY\",\"message\":\"Gói tin quá hạn hoặc Replay attack!\"}");
      return;
    }

    String signPayload = "rules:" + ts + ":" + nonce;
    bool sigValid = verifyHmacSha256(currentLocalSecretKey, signPayload, sig);
    if (!sigValid && admin_pass.length() > 0) {
      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();
      String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
      sigValid = verifyHmacSha256(masterKey, signPayload, sig);
    }
    if (!sigValid) {
      request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_BAD_SIG\",\"message\":\"Chữ ký bảo mật không hợp lệ!\"}");
      return;
    }

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
    if (!isUserAuthorizedForDevice(user, "*")) {
      request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"FORBIDDEN\",\"message\":\"Chỉ Quản trị viên/Chủ nhà mới có quyền cập nhật tự động hóa!\"}");
      return;
    }

    JsonArray arr = doc["rules"].as<JsonArray>();
    localRuleCount = 0;
    for (JsonObject obj : arr) {
      if (localRuleCount >= MAX_LOCAL_RULES) break;
      LocalRule& r = localRules[localRuleCount];
      r.enabled = obj["enabled"] | true;
      strncpy(r.id, obj["id"] | "", sizeof(r.id) - 1);
      strncpy(r.type, obj["type"] | "temp_auto", sizeof(r.type) - 1);
      strncpy(r.targetDevId, obj["targetDevId"] | "", sizeof(r.targetDevId) - 1);
      r.triggerTemp = obj["triggerTemp"] | 0.0f;
      strncpy(r.tempCond, obj["tempCond"] | ">=", sizeof(r.tempCond) - 1);
      strncpy(r.actionState, obj["actionState"] | "1", sizeof(r.actionState) - 1);
      r.autoOffSec = obj["autoOffSec"] | 0;
      r.turnOnTime = 0;
      r.isCountingDown = false;
      r.lastTriggerTime = 0;
      localRuleCount++;
    }
    saveLocalRulesToFlash();
    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Đã lưu quy tắc tự động hóa vào Flash!\"}");
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
