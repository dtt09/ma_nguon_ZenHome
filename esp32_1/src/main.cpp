#include <Arduino.h>
#include <WiFi.h>
#include <esp_task_wdt.h>
#include <esp_system.h>

#include "config_manager.h"
#include "security_manager.h"
#include "hardware_manager.h"
#include "ble_manager.h"
#include "network_manager.h"
#include "mqtt_manager.h"

// Trạng thái nút bấm cứng
static unsigned long buttonPressTime = 0;
static bool isButtonPressed = false;

// Trạng thái hiển thị LED
enum SystemState {
  STATE_AP_MODE,      // Chưa liên kết (Nháy nhanh)
  STATE_DISCONNECTED, // Mất kết nối (Nháy chậm)
  STATE_CONNECTED     // Kết nối thành công (Sáng đứng)
};
static SystemState currentState = STATE_AP_MODE;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- KHỞI ĐỘNG HỆ THỐNG SMART HOME ZENHOME ---");

  // Khởi tạo Mutex đa luồng Flash
  initFlashMutex();

  // Phát hiện nguyên nhân khởi động (Mất điện vs Khởi động lại phần mềm)
  esp_reset_reason_t rstReason = esp_reset_reason();
  if (rstReason == ESP_RST_POWERON || rstReason == ESP_RST_BROWNOUT) {
    isPowerOutageBoot = true;
    Serial.println("[NGUỒN ĐIỆN] ⚡ CẢNH BÁO: Phát hiện ESP32 khởi động sau khi MẤT ĐIỆN (Power-On / Brownout)!");
  } else {
    isPowerOutageBoot = false;
    Serial.printf("[HỆ THỐNG] Khởi động lại phần mềm/watchdog (Mã: %d)\n", (int)rstReason);
  }

  // Khởi tạo phần cứng (Pins, PCF8574, DHT11)
  initHardware();

  // Khởi tạo Hardware Watchdog Timer chống treo vi điều khiển (30s)
  #if defined(ESP_IDF_VERSION_MAJOR) && ESP_IDF_VERSION_MAJOR >= 5
    esp_task_wdt_config_t wdt_config = {
      .timeout_ms = WDT_TIMEOUT_SECONDS * 1000,
      .idle_core_mask = 0,
      .trigger_panic = true
    };
    esp_task_wdt_init(&wdt_config);
  #else
    esp_task_wdt_init(WDT_TIMEOUT_SECONDS, true);
  #endif
  esp_task_wdt_add(NULL);

  if (!LittleFS.begin(true)) {
    Serial.println("Lỗi mount LittleFS!");
    return;
  }

  if (LittleFS.exists("/provisioned.txt")) {
    isProvisioned = true;
  }

  bool configOk = loadConfig();

  if (configOk && isProvisioned && !isSetupPending) {
    isConfigured = true;
    Serial.println("\n[TÀI KHOẢN] 🔐 ESP32 đã liên kết với tài khoản ZenHome: " + mqtt_prefix);

    loadLocalSecretKey();
    loadMembersFromFlash();
    loadLocalRulesFromFlash();

    initMqttClient();
    connectToWiFi();

    setupPhysicalSwitches();
    setupBLE();
  } else if (configOk && isSetupPending) {
    isConfigured = false;
    isProvisioned = false;

    // Đảm bảo toàn bộ Relay giữ trạng thái TẮT an toàn (Active-Low HIGH)
    for (int i = 0; i < relayCount; i++) {
      safeSetRelayPin(myRelays[i].pin, HIGH);
    }

    Serial.println("\n[SETUP] ⏳ ESP32 ĐANG TRONG GIAI ĐOẠN SETUP LIÊN KẾT LẦN ĐẦU!");
    Serial.println("[SETUP] 🔒 Toàn bộ Relay, Công tắc cơ và BLE ngầm bị KHÓA chặt.");
    Serial.println("[SETUP] 📡 Đang kết nối Wi-Fi lần đầu...");

    loadLocalSecretKey();
    initMqttClient();
    connectToWiFi();
  } else {
    isConfigured = false;
    isProvisioned = false;
    isSetupPending = false;

    // Đảm bảo toàn bộ Relay giữ trạng thái TẮT an toàn (Active-Low HIGH)
    for (int i = 0; i < relayCount; i++) {
      safeSetRelayPin(myRelays[i].pin, HIGH);
    }

    Serial.println("\n[BẢO MẬT] ⚠️ ESP32 CHƯA LIÊN KẾT TÀI KHOẢN ZENHOME!");
    Serial.println("[BẢO MẬT] 👉 Toàn bộ relay, công tắc cơ và BLE ngầm bị khóa.");
    Serial.println("[BẢO MẬT] 👉 Mở chế độ AP Setup để ghép nối và liên kết tài khoản...");
    setupAPMode();
  }
}

void loop() {
  esp_task_wdt_reset();
  unsigned long currentMillis = millis();

  // 1. Quét công tắc cơ gắn tường (< 15ms)
  if (isProvisioned && !isSetupPending) {
    checkPhysicalSwitches();
  }

  // 2. Quản lý 3 khe kết nối BLE (Multi-Slot Concurrency)
  if (isProvisioned && !isSetupPending) {
    checkBleSlotTimeouts();
  }

  // 3. Xử lý ghi Flash LittleFS an toàn trên Core 1
  if (pendingSecretKeyToSave.length() > 0) {
    String keyToSave = pendingSecretKeyToSave;
    pendingSecretKeyToSave = "";
    saveLocalSecretKey(keyToSave);
  }

  if (needsBackupToFlash && (currentMillis - lastRelayStateChangeAt >= 1500)) {
    needsBackupToFlash = false;
    backupRelayStatesToFlash();
  }

  if (pendingReconfig.requested) {
    pendingReconfig.requested = false;
    File file = LittleFS.open("/config.json", "r");
    if (file) {
      DynamicJsonDocument cfgDoc(2048);
      DeserializationError err = deserializeJson(cfgDoc, file);
      file.close();
      if (!err) {
        cfgDoc["wifi_ssid"] = pendingReconfig.ssid;
        cfgDoc["wifi_pass"] = pendingReconfig.pass;
        if (pendingReconfig.mqttServer.length() > 0) cfgDoc["mqtt_server"] = pendingReconfig.mqttServer;
        if (pendingReconfig.adminPass.length() > 0) cfgDoc["admin_pass"] = pendingReconfig.adminPass;

        File outFile = LittleFS.open("/config.json", "w");
        if (outFile) {
          serializeJson(cfgDoc, outFile);
          outFile.close();
          Serial.println("[RECONFIG] 💾 Đã lưu cấu hình Wi-Fi mới vào Flash thành công! Khởi động lại sau 1.5s...");
          rebootScheduledAt = millis();
          shouldReboot = true;
        } else {
          Serial.println("[RECONFIG] ❌ Lỗi mở /config.json để ghi!");
        }
      }
    }
  }

  if (shouldReboot && (currentMillis - rebootScheduledAt >= 1000)) {
    ESP.restart();
  }

  // 4. Đánh giá Micro Rule Engine tự trị cục bộ mỗi 1000ms
  if (isProvisioned && !isSetupPending && (currentMillis - lastRuleEvalTime >= 1000)) {
    lastRuleEvalTime = currentMillis;
    evaluateLocalRules(cachedTemperature);
  }

  // 5. Cảnh báo bộ nhớ Heap khả dụng thấp
  static unsigned long lastHeapCheck = 0;
  if (currentMillis - lastHeapCheck >= 30000) {
    lastHeapCheck = currentMillis;
    uint32_t freeHeap = ESP.getFreeHeap();
    if (freeHeap < 15000) {
      Serial.printf("[SYSTEM-WARN] ⚠️ Bộ nhớ Heap khả dụng thấp: %u bytes\n", freeHeap);
    }
  }

  // 6. Kiểm tra Nút Reset cứng phần cứng (Nhấn giữ 5 giây)
  if (digitalRead(RESET_BTN_PIN) == LOW) {
    if (!isButtonPressed) {
      isButtonPressed = true;
      buttonPressTime = currentMillis;
    } else {
      if (currentMillis - buttonPressTime >= 5000) {
        Serial.println("\n[!] PHÁT HIỆN YÊU CẦU FACTORY RESET TỪ NÚT CỨNG PHẦN CỨNG!");
        if (mqttClient.connected()) {
          String hwResetTopic = mqtt_prefix + "/system/hardware_reset";
          String resetTopic = mqtt_prefix + "/system/reset";
          mqttClient.publish(hwResetTopic.c_str(), "1", true);
          mqttClient.publish(resetTopic.c_str(), "1", true);
          delay(600);
        }
        resetToFactoryDefaults();
        Serial.println("Hệ thống sẽ khởi động lại và vào chế độ AP Setup sau 2 giây...");
        delay(2000);
        ESP.restart();
      }
    }
  } else {
    isButtonPressed = false;
  }

  // 7. Duy trì kết nối Wi-Fi trong nền (non-blocking)
  checkWiFiConnection();

  // 8. Quản lý Bật/Tắt BLE theo trạng thái Wi-Fi Router
  static unsigned long wifiStateChangeTime = 0;
  static wl_status_t lastRecordedWifiStatus = WL_IDLE_STATUS;
  wl_status_t currentWifiStatus = WiFi.status();

  if (currentWifiStatus != lastRecordedWifiStatus) {
    lastRecordedWifiStatus = currentWifiStatus;
    wifiStateChangeTime = currentMillis;
  }

  if (isConfigured && isProvisioned && !isSetupPending) {
    if (currentWifiStatus == WL_CONNECTED) {
      if (isBleEnabled && (currentMillis - wifiStateChangeTime >= 3000)) {
        setBleActive(false);
      }
    } else {
      if (!isBleEnabled && (currentMillis - wifiStateChangeTime >= 5000)) {
        setBleActive(true);
      }
    }
  }

  // 9. Duy trì MQTT & UDP Discovery
  if (WiFi.status() == WL_CONNECTED && isProvisioned && !isSetupPending) {
    if (!isWebServerStarted) {
      setupStationWebServer();
      setupUdpDiscovery();
      isWebServerStarted = true;
    }
    checkUdpDiscovery();
  }
  checkMqttConnection();

  // Phát tín hiệu handshake beacon cho App định kỳ 2s khi đang trong giai đoạn Setup Pending và đã kết nối MQTT
  static unsigned long lastSetupBeaconTime = 0;
  if (isSetupPending && WiFi.status() == WL_CONNECTED && mqttClient.connected()) {
    if (currentMillis - lastSetupBeaconTime >= 2000) {
      lastSetupBeaconTime = currentMillis;
      sendSetupHandshakeBeacon();
    }
  }

  // 10. Kiểm tra Timeout giai đoạn Setup (Fallback AP Mode nếu không hoàn thành sau 3 phút)
  checkSetupTimeout();

  // 11. Đọc cảm biến mỗi 15s và lập tức cảnh báo nếu phát hiện nhiệt độ tăng vọt/nguy cơ hỏa hoạn
  static unsigned long lastDhtPublish = 0;
  static float lastPublishedTemp = NAN;
  if (isProvisioned && !isSetupPending && (lastDHTRead == 0 || (currentMillis - lastDHTRead >= 15000))) {
    lastDHTRead = currentMillis;
    readSensors();
    if (!isnan(cachedTemperature)) {
      bool isEmergencyHeat = (cachedTemperature >= 45.0f);
      bool tempSpike = (!isnan(lastPublishedTemp) && abs(cachedTemperature - lastPublishedTemp) >= 1.5f);
      bool regularInterval = (currentMillis - lastDhtPublish >= 300000) || (lastDhtPublish == 0);
      bool shouldPub = regularInterval || ((tempSpike || isEmergencyHeat) && (currentMillis - lastDhtPublish >= 10000));

      if (shouldPub && mqttClient.connected()) {
        lastDhtPublish = currentMillis;
        lastPublishedTemp = cachedTemperature;
        String tempStr = String(cachedTemperature, 1);
        String topic = mqtt_prefix + "/nhiet_do_trong_nha";
        mqttClient.publish(topic.c_str(), tempStr.c_str());
        if (isEmergencyHeat) {
          Serial.printf("[FIRE-SAFETY] 🔥 Cảnh báo nhiệt độ cao phát hiện trên ESP32: %.1f°C! Đã lập tức phát MQTT.\n", cachedTemperature);
        }
      }
    }
  }

  // 12. Hiển thị Đèn LED trạng thái
  if (!isConfigured && !isSetupPending) {
    currentState = STATE_AP_MODE;
  } else if (isSetupPending) {
    currentState = STATE_DISCONNECTED; // Nháy 500ms báo đang chờ hoàn tất thiết lập
  } else if (WiFi.status() != WL_CONNECTED || !mqttClient.connected()) {
    currentState = STATE_DISCONNECTED;
  } else {
    currentState = STATE_CONNECTED;
  }

  static unsigned long lastLedToggle = 0;
  static bool ledState = LOW;
  if (currentState == STATE_CONNECTED) {
    digitalWrite(STATUS_LED_PIN, HIGH);
  } else {
    unsigned long interval = (currentState == STATE_AP_MODE) ? 200 : 1000;
    if (currentMillis - lastLedToggle >= interval) {
      lastLedToggle = currentMillis;
      ledState = !ledState;
      digitalWrite(STATUS_LED_PIN, ledState);
    }
  }

  delay(5);
}
