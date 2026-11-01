#include "config_manager.h"
#include "hardware_manager.h"

// Biến quản lý thiết bị rơ-le
RelayDev myRelays[MAX_RELAYS];
int relayCount = 0;

// Trạng thái vận hành hệ thống
bool isConfigured = false;
bool isProvisioned = false;
bool isSetupPending = false;
unsigned long setupPhaseStartTime = 0;
bool isPowerOutageBoot = false;
bool hasOfflineBackup = false;
bool needsBackupToFlash = false;
bool isOtaInProgress = false;
unsigned long lastRelayStateChangeAt = 0;

// Trạng thái khởi động lại theo lịch
bool shouldReboot = false;
unsigned long rebootScheduledAt = 0;

// Cấu trúc lệnh cấu hình lại trong nền
PendingReconfig pendingReconfig = {false, "", "", "", ""};

// Thông số mạng Wi-Fi và MQTT Broker HiveMQ Cloud
String wifi_ssid = "";
String wifi_pass = "";
String mqtt_prefix = "";
String mqtt_server = "e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud";
String mqtt_user = "DTC_ZenHome";
String mqtt_pass = "DTC_ZenHome2103";
String admin_pass = "admin";
String server_url = "";

// Mutex bảo vệ truy cập bộ nhớ Flash LittleFS đa luồng (Core 0 vs Core 1)
SemaphoreHandle_t flashMutex = NULL;

// ISRG Root X1 CA Certificate cho HiveMQ Cloud TLS Port 8883
const char* const HIVEMQ_ROOT_CA PROGMEM =
"-----BEGIN CERTIFICATE-----\n"
"MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw\n"
"TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh\n"
"cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4\n"
"WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu\n"
"ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY\n"
"MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc\n"
"h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+\n"
"0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U\n"
"A5/TR5d8S5JlCd893DZ2RH22xmW26ukG0hAS3838MHhoJa71rGcSUyst6vUiHxNn\n"
"Glb8DXaeMV0XZKCe4GXxIIUCb+FcVMy/RE5hPJShHDQWbFF95DP26ro93RdwTxZc\n"
"GyZifhkRFJVidtMH6NNGO3zRzI6UlBlcrUnuv5R4P4UhyWY0NYK7756ReYehAbmA\n"
"Nps6ZMuoWOYoZFgcdKSt4qPpKbFgYWWAVV3UDbhmBEB56cV9yFGmzEGnLHD694J3\n"
"Q8Y0GzdaVCrL3NyZMx861zkwhuqdiPRxFUksvttF6tRnA/tMpXH8nowWa5DM5THr\n"
"hnUSJKG5jER8ZGUXUrMp98R22w37K8nHm8LEhmOtT2278nRSp2NFocKS3BpKitqT\n"
"+OW5lAg9nXIBPWCReV34R/3dKWNyOO6Wh2/8occTZ3TLJW4POUEACS8qoPVU5V00\n"
"uoUSXIZr86Xd1r+79HYH3knAc5P/63UT428NzkJi8V71DXfqMAhUKOtHgniyd33G\n"
"/6KUqAjZtAoMaZxg8mmT5mqhAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV\n"
"HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgBlfgBp26xDBtDANBgkq\n"
"hkiG9w0BAQsFAAOCAgEAVR9YqbyhurdtUSUxGtPGsjgkiDxV6aUtrL0Qg48EV4U5\n"
"48aTCDMtProU4KLIXNHGQKqm5whTr0m3qNY2HA2nkMQTV+XNKddjmdfGtOMwNzpP\n"
"o6Pymv521/W4EbqvnAKnGgh6nqk3PAGU4+/G8LQKn5xFTYXAYNmdNTwtZZr/TxGWD\n"
"BxTenPdgd8f6pem35zLtTW61YTdkgk78SbXOj2Y0QISKRSLhxTDgrDKgOpSi4EL\n"
"pnZOO95QaPB8vjWbDYretPr8LBi/EEmeREaTuNxpyokN68KWqTWgykxQsKS475XH\n"
"hCd5gvL/VLWcDUm62e2v665OwEKUengl50bQ5nUG059OX9gmg8S7WGEWmuL06OXf\n"
"no5WtrB2zkDn042xB8kMQE84n369Ux5EhkP62SwqL4HZu3U4URMddX8oFvM0eptFU\n"
"ee8cLb27CrL70Cesq5KiCWuhashzG8hfKb2Nu/P6vCW6olSwZWYEG49JYAC5wkvY\n"
"DYVw63WMY6DuoecaSTIVbOVfvBigCrgSpQgrQsETtIT90CG295m6aLd60AoiYXl9\n"
"50NgLqCLZZppi1VQ/xQtFXwQGkWz8R3qlPXoACTYG4CmR0OYnL78k5y4TGxYTmpY\n"
"dlFCWAx6eRe2174CXPeMKFuzT2xDQHYU30Sm3FlLg853NWZYz75LhSfSCRtqrG8=\n"
"-----END CERTIFICATE-----\n";

void initFlashMutex() {
  if (flashMutex == NULL) {
    flashMutex = xSemaphoreCreateMutex();
  }
}

bool lockFlash(TickType_t waitTicks) {
  if (flashMutex == NULL) return true;
  return xSemaphoreTake(flashMutex, waitTicks) == pdTRUE;
}

void unlockFlash() {
  if (flashMutex != NULL) {
    xSemaphoreGive(flashMutex);
  }
}

bool loadConfig() {
  if (!LittleFS.exists("/config.json")) return false;
  File configFile = LittleFS.open("/config.json", "r");
  if (!configFile) return false;

  DynamicJsonDocument doc(2048); 
  DeserializationError err = deserializeJson(doc, configFile);
  configFile.close();
  if (err) return false;

  if (doc.containsKey("admin_pass")) {
    admin_pass = doc["admin_pass"].as<String>();
  } else {
    admin_pass = "admin";
  }

  wifi_ssid = doc["wifi_ssid"].as<String>();
  wifi_pass = doc["wifi_pass"].as<String>();
  mqtt_prefix = doc["mqtt_prefix"].as<String>();

  if (doc.containsKey("mqtt_server")) {
    String parsedServer = doc["mqtt_server"].as<String>();
    if (parsedServer.length() > 10) {
      mqtt_server = parsedServer;
      if (mqtt_server.endsWith(".s1.eu.")) {
        mqtt_server += "hivemq.cloud";
      } else if (mqtt_server.endsWith(".s1.eu")) {
        mqtt_server += ".hivemq.cloud";
      }
    }
  }
  if (doc.containsKey("mqtt_user")) {
    String u = doc["mqtt_user"].as<String>();
    if (u.length() > 0) mqtt_user = u;
  }
  if (doc.containsKey("mqtt_pass")) {
    String p = doc["mqtt_pass"].as<String>();
    if (p.length() > 0) mqtt_pass = p;
  }

  // Tự động bảo vệ HiveMQ Cloud: cluster yêu cầu tài khoản xác thực DTC_ZenHome chuẩn
  if (mqtt_server.indexOf("hivemq.cloud") >= 0) {
    if (mqtt_user.length() == 0 || mqtt_user.startsWith("user_") || mqtt_pass.length() == 0) {
      mqtt_user = "DTC_ZenHome";
      mqtt_pass = "DTC_ZenHome2103";
      Serial.println("[CONFIG] 🛡️ Tự động đồng bộ tài khoản HiveMQ Cloud chuẩn: DTC_ZenHome");
    }
  }

  if (doc.containsKey("server_url")) {
    server_url = doc["server_url"].as<String>();
  }

  // BẮT BUỘC: ESP32 PHẢI LIÊN KẾT VỚI 1 TÀI KHOẢN ZENHOME VÀ ĐÚNG ĐỊA CHỈ MAC PHẦN CỨNG MỚI ĐƯỢC PHÉP HOẠT ĐỘNG
  if (wifi_ssid.length() == 0 || wifi_ssid == "null") {
    Serial.println("[CONFIG] ⛔ Thiếu SSID WiFi! Thiết bị chưa sẵn sàng.");
    return false;
  }
  if (mqtt_prefix.length() == 0 || mqtt_prefix == "null" || mqtt_prefix.indexOf('/') <= 0) {
    Serial.println("[CONFIG] ⛔ ESP32 chưa có tài khoản ZenHome liên kết (mqtt_prefix không hợp lệ)!");
    return false;
  }
  String linkedUser = mqtt_prefix.substring(0, mqtt_prefix.indexOf('/'));
  linkedUser.trim();
  if (linkedUser.length() == 0 || linkedUser == "guest" || linkedUser == "undefined" || linkedUser == "null") {
    Serial.println("[CONFIG] ⛔ Tài khoản ZenHome liên kết không hợp lệ: " + linkedUser);
    return false;
  }

  // KIỂM TRA ĐỒNG NHẤT: MAC trong mqtt_prefix PHẢI TRÙNG VỚI MAC PHẦN CỨNG ESP32
  String macInPrefix = mqtt_prefix.substring(mqtt_prefix.indexOf('/') + 1);
  macInPrefix.trim();
  String cleanPrefixMac = macInPrefix;
  cleanPrefixMac.replace(":", "");
  cleanPrefixMac.replace("-", "");
  cleanPrefixMac.toUpperCase();

  String hwMac = WiFi.macAddress();
  String cleanHwMac = hwMac;
  cleanHwMac.replace(":", "");
  cleanHwMac.replace("-", "");
  cleanHwMac.toUpperCase();

  if (cleanPrefixMac == "UNKNOWN_MAC" || cleanPrefixMac == "UNKNOWN" || cleanPrefixMac.length() == 0) {
    Serial.println("[CONFIG] ⛔ mqtt_prefix chứa MAC không xác định (" + macInPrefix + ")! Cấu hình bị hủy để về chế độ AP.");
    return false;
  }

  if (cleanPrefixMac != cleanHwMac) {
    Serial.println("[CONFIG] ⛔ MAC trong cấu hình [" + cleanPrefixMac + "] không trùng khớp với phần cứng ESP32 [" + cleanHwMac + "]!");
    Serial.println("[CONFIG] 👉 Cấu hình không hợp lệ, chuyển về chế độ AP Setup.");
    return false;
  }

  // Kiểm tra cờ đang chờ xác nhận setup lần đầu
  if (LittleFS.exists("/setup_pending.txt")) {
    isSetupPending = true;
    isProvisioned = false;
    setupPhaseStartTime = millis();
    Serial.println("[SETUP] ⏳ ESP32 đang trong giai đoạn Setup xác nhận kết nối (Timeout 3 phút)...");
  } else {
    isSetupPending = false;
    if (LittleFS.exists("/provisioned.txt")) {
      isProvisioned = true;
    } else {
      isProvisioned = false;
    }
  }

  JsonArray devs = doc["devices"].as<JsonArray>();
  relayCount = 0;
  for (JsonObject dev : devs) {
    if (relayCount >= MAX_RELAYS) {
      Serial.print("CẢNH BÁO: Số lượng thiết bị vượt quá giới hạn tối đa (");
      Serial.print(MAX_RELAYS);
      Serial.println(")! Bỏ qua các thiết bị còn lại.");
      break;
    }
    myRelays[relayCount].id = dev["id"].as<String>();
    myRelays[relayCount].room = dev.containsKey("room") ? dev["room"].as<String>() : "living_room";
    myRelays[relayCount].pin = dev["pin"].as<int>();
    myRelays[relayCount].state = "0"; // Mặc định tắt (Active-Low)
    myRelays[relayCount].version = 1;
    myRelays[relayCount].lastToggleTime = 0;
    myRelays[relayCount].manualOverrideUntil = 0;
    
    if (myRelays[relayCount].pin > 7) {
      Serial.print("CẢNH BÁO: Chân relay ");
      Serial.print(myRelays[relayCount].pin);
      Serial.println(" lớn hơn 7! PCF8574 chỉ hỗ trợ chân từ 0-7.");
    }

    if (pcfFound && myRelays[relayCount].pin <= 7) {
      pcf.pinMode(myRelays[relayCount].pin, OUTPUT);
      safeSetRelayPin(myRelays[relayCount].pin, HIGH); // Mặc định tắt (Active-Low)
    }
    relayCount++;
  }

  if (isPowerOutageBoot) {
    // TH1: MẤT ĐIỆN -> KHI CÓ ĐIỆN LẠI: PHẢI TẮT TOÀN BỘ THIẾT BỊ ĐỂ AN TOÀN ĐIỆN!
    Serial.println("\n[AN TOÀN ĐIỆN] ⚡ CÓ ĐIỆN LẠI SAU KHI MẤT ĐIỆN: TẮT TOÀN BỘ RELAY!");
    for (int i = 0; i < relayCount; i++) {
      myRelays[i].state = "0";
      safeSetRelayPin(myRelays[i].pin, HIGH); // Active-Low TẮT
    }
    if (LittleFS.exists("/offline_backup.json")) {
      LittleFS.remove("/offline_backup.json");
    }
    hasOfflineBackup = false;
  } else {
    // TH2: KHÔNG PHẢI MẤT ĐIỆN (Mất mạng, reboot phần mềm) -> Khôi phục trạng thái lần cuối (nếu có backup)
    loadOfflineBackupFromFlash();
  }
  return true;
}

void backupRelayStatesToFlash() {
  static unsigned long lastFlashWrite = 0;
  static String lastBackupSignature = "";
  unsigned long now = millis();
  if (now - lastFlashWrite < 3000) {
    needsBackupToFlash = true; // Giữ cờ để thử lại ở vòng lặp kế tiếp khi hết 3000ms cooldown
    return; // Giới hạn tần suất: Chống ghi dồn dập vào Flash LittleFS
  }

  String currentSig = "";
  for (int i = 0; i < relayCount; i++) {
    currentSig += myRelays[i].id + ":" + myRelays[i].state + ";";
  }
  if (currentSig == lastBackupSignature) {
    return; // Trạng thái thực tế không đổi -> Không ghi Flash, triệt tiêu 100% spam log!
  }

  lastFlashWrite = now;
  lastBackupSignature = currentSig;

  if (!lockFlash()) return;

  StaticJsonDocument<512> doc;
  JsonArray arr = doc.createNestedArray("relays");
  for (int i = 0; i < relayCount; i++) {
    JsonObject obj = arr.createNestedObject();
    obj["id"] = myRelays[i].id;
    obj["state"] = myRelays[i].state;
    obj["room"] = myRelays[i].room;
  }
  // Mở file chế độ "w" -> Xóa dữ liệu cũ, ghi đè toàn bộ trạng thái mới nhất
  File f = LittleFS.open("/offline_backup.json", "w");
  if (f) {
    serializeJson(doc, f);
    f.close();
    hasOfflineBackup = true;
    Serial.println("[OFFLINE-BACKUP] 💾 Đã lưu trạng thái thiết bị ngoại tuyến vào Flash ESP32.");
  }
  unlockFlash();
}

void loadOfflineBackupFromFlash() {
  if (!lockFlash()) return;
  if (!LittleFS.exists("/offline_backup.json")) {
    unlockFlash();
    return;
  }
  File f = LittleFS.open("/offline_backup.json", "r");
  if (!f) {
    unlockFlash();
    return;
  }
  StaticJsonDocument<512> doc;
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  unlockFlash();
  if (err) return;

  JsonArray arr = doc["relays"].as<JsonArray>();
  for (JsonObject obj : arr) {
    String devId = obj["id"].as<String>();
    String st = obj["state"].as<String>();
    for (int i = 0; i < relayCount; i++) {
      if (myRelays[i].id == devId) {
        myRelays[i].state = st;
        if (st == "1") safeSetRelayPin(myRelays[i].pin, LOW);
        else safeSetRelayPin(myRelays[i].pin, HIGH);
        break;
      }
    }
  }
  hasOfflineBackup = true;
  Serial.println("[OFFLINE-BACKUP] OK: Đã khôi phục trạng thái lần cuối trước khi khởi động lại từ Flash!");
}

void resetToFactoryDefaults() {
  if (LittleFS.exists("/config.json")) LittleFS.remove("/config.json");
  if (LittleFS.exists("/provisioned.txt")) LittleFS.remove("/provisioned.txt");
  if (LittleFS.exists("/setup_pending.txt")) LittleFS.remove("/setup_pending.txt");
  if (LittleFS.exists("/local_sec_key.dat")) LittleFS.remove("/local_sec_key.dat");
  if (LittleFS.exists("/offline_backup.json")) LittleFS.remove("/offline_backup.json");
  if (LittleFS.exists("/members.json")) LittleFS.remove("/members.json");
  if (LittleFS.exists("/rules.json")) LittleFS.remove("/rules.json");

  for (int i = 0; i < relayCount; i++) {
    safeSetRelayPin(myRelays[i].pin, HIGH);
  }
  Serial.println("[FACTORY-RESET] 🔄 Đã xóa toàn bộ cấu hình trong Flash và tắt tất cả thiết bị.");
}
