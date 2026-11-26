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
std::atomic<bool> isOtaInProgress(false);
unsigned long lastRelayStateChangeAt = 0;

// Trạng thái khởi động lại theo lịch
bool shouldReboot = false;
unsigned long rebootScheduledAt = 0;

// Cấu trúc lệnh cấu hình lại trong nền
PendingReconfig pendingReconfig{};

// Thông số mạng Wi-Fi và MQTT Broker HiveMQ Cloud
String wifi_ssid = "";
String wifi_pass = "";
String mqtt_prefix = "";
String mqtt_server = "e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud";
String mqtt_user = "";
String mqtt_pass = "";
String admin_pass = "";
String server_url = "";
String bindingToken;

// Mutex bảo vệ truy cập bộ nhớ Flash LittleFS đa luồng (Core 0 vs Core 1)
SemaphoreHandle_t flashMutex = NULL;

// MQTT uses ISRG Root X1. GitHub OTA also needs USERTrust ECC for github.com.
#define ISRG_ROOT_X1_PEM \
"-----BEGIN CERTIFICATE-----\n" \
"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\n" \
"-----END CERTIFICATE-----\n"

const char* const HIVEMQ_ROOT_CA PROGMEM = ISRG_ROOT_X1_PEM;
const char OTA_ROOT_CAS[] PROGMEM =
"-----BEGIN CERTIFICATE-----\n"
"MIICjzCCAhWgAwIBAgIQXIuZxVqUxdJxVt7NiYDMJjAKBggqhkjOPQQDAzCBiDEL\n"
"MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl\n"
"eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT\n"
"JVVTRVJUcnVzdCBFQ0MgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTAwMjAx\n"
"MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgT\n"
"Ck5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUg\n"
"VVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBFQ0MgQ2VydGlm\n"
"aWNhdGlvbiBBdXRob3JpdHkwdjAQBgcqhkjOPQIBBgUrgQQAIgNiAAQarFRaqflo\n"
"I+d61SRvU8Za2EurxtW20eZzca7dnNYMYf3boIkDuAUU7FfO7l0/4iGzzvfUinng\n"
"o4N+LZfQYcTxmdwlkWOrfzCjtHDix6EznPO/LlxTsV+zfTJ/ijTjeXmjQjBAMB0G\n"
"A1UdDgQWBBQ64QmG1M8ZwpZ2dEl23OA1xmNjmjAOBgNVHQ8BAf8EBAMCAQYwDwYD\n"
"VR0TAQH/BAUwAwEB/zAKBggqhkjOPQQDAwNoADBlAjA2Z6EWCNzklwBBHU6+4WMB\n"
"zzuqQhFkoJ2UOQIReVx7Hfpkue4WQrO/isIJxOzksU0CMQDpKmFHjFJKS04YcPbW\n"
"RNZu9YO6bVi9JNlWSOrvxKJGgYhqOkbRqZtNyWHa0V1Xahg=\n"
"-----END CERTIFICATE-----\n"
ISRG_ROOT_X1_PEM;
#undef ISRG_ROOT_X1_PEM

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

bool saveConfig(const JsonDocument& doc) {
  if (!lockFlash()) return false;
  File tmp = LittleFS.open("/config.json.tmp", "w");
  if (!tmp) {
    unlockFlash();
    Serial.println("[CONFIG] ❌ Lỗi mở /config.json.tmp để ghi!");
    return false;
  }
  size_t bytesWritten = serializeJson(doc, tmp);
  tmp.flush();
  tmp.close();

  if (bytesWritten < 10) {
    Serial.println("[CONFIG] ❌ Lỗi: Dữ liệu ghi vào /config.json.tmp quá ngắn hoặc rỗng!");
    LittleFS.remove("/config.json.tmp");
    unlockFlash();
    return false;
  }

  // Bước 1: Sao lưu /config.json hiện tại thành /config.json.bak (Bảo vệ Brownout cấp 2)
  if (LittleFS.exists("/config.json")) {
    if (LittleFS.exists("/config.json.bak")) {
      LittleFS.remove("/config.json.bak");
    }
    File src = LittleFS.open("/config.json", "r");
    File dst = LittleFS.open("/config.json.bak", "w");
    if (src && dst) {
      uint8_t copyBuf[256];
      while (src.available()) {
        size_t n = src.read(copyBuf, sizeof(copyBuf));
        dst.write(copyBuf, n);
      }
      dst.flush();
    }
    if (src) src.close();
    if (dst) dst.close();
  }

  // Bước 2: Hoán đổi nguyên tử /config.json.tmp thành /config.json
  if (LittleFS.exists("/config.json")) {
    LittleFS.remove("/config.json");
  }
  bool ok = LittleFS.rename("/config.json.tmp", "/config.json");
  unlockFlash();
  if (ok) {
    Serial.println("[CONFIG] 💾 Đã lưu an toàn nguyên tử /config.json thành công (Kèm bản sao /config.json.bak)!");
  } else {
    Serial.println("[CONFIG] ❌ Lỗi đổi tên /config.json.tmp sang /config.json!");
  }
  return ok;
}

// Hàm trợ giúp kiểm tra tính hợp lệ của tệp JSON cấu hình
static bool isValidConfigFile(const char* path) {
  if (!LittleFS.exists(path)) return false;
  File f = LittleFS.open(path, "r");
  if (!f || f.size() < 10) {
    if (f) f.close();
    return false;
  }
  DynamicJsonDocument testDoc(512);
  DeserializationError err = deserializeJson(testDoc, f);
  f.close();
  return (err == DeserializationError::Ok);
}

bool loadConfig() {
  // Cơ chế tự phục hồi 3 cấp (3-Tier Auto-Recovery) chống sụt áp / brownout giữa các bước ghi
  bool mainValid = isValidConfigFile("/config.json");
  if (!mainValid) {
    Serial.println("[CONFIG] ⚠️ /config.json chính không tồn tại hoặc bị lỗi cấu trúc!");
    if (isValidConfigFile("/config.json.tmp")) {
      Serial.println("[CONFIG] 🛡️ Tự động khôi phục cấu hình từ /config.json.tmp...");
      if (LittleFS.exists("/config.json")) LittleFS.remove("/config.json");
      LittleFS.rename("/config.json.tmp", "/config.json");
      mainValid = true;
    } else if (isValidConfigFile("/config.json.bak")) {
      Serial.println("[CONFIG] 🛡️ Tự động khôi phục cấu hình từ bản sao lưu /config.json.bak...");
      if (LittleFS.exists("/config.json")) LittleFS.remove("/config.json");
      LittleFS.rename("/config.json.bak", "/config.json");
      mainValid = true;
    }
  }

  if (!LittleFS.exists("/config.json")) return false;
  File configFile = LittleFS.open("/config.json", "r");
  if (!configFile) return false;

  DynamicJsonDocument doc(2048); 
  DeserializationError err = deserializeJson(doc, configFile);
  configFile.close();
  if (err) return false;

  admin_pass = doc["admin_pass"] | "";
  if (admin_pass == "admin") admin_pass = "";

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
  mqtt_user = doc["mqtt_user"] | "";
  mqtt_pass = doc["mqtt_pass"] | "";

  bindingToken = doc["binding_token"] | "";
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
    myRelays[relayCount].state = "unknown";
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
    }
    if (safeSetRelayPin(myRelays[relayCount].pin, HIGH)) myRelays[relayCount].state = "0";
    relayCount++;
  }

  if (isPowerOutageBoot) {
    // TH1: MẤT ĐIỆN -> KHI CÓ ĐIỆN LẠI: PHẢI TẮT TOÀN BỘ THIẾT BỊ ĐỂ AN TOÀN ĐIỆN!
    Serial.println("\n[AN TOÀN ĐIỆN] ⚡ CÓ ĐIỆN LẠI SAU KHI MẤT ĐIỆN: TẮT TOÀN BỘ RELAY!");
    for (int i = 0; i < relayCount; i++) {
      myRelays[i].state = safeSetRelayPin(myRelays[i].pin, HIGH) ? "0" : "unknown";
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
  if (!lockRelays(pdMS_TO_TICKS(500))) {
    unlockFlash();
    return;
  }

  StaticJsonDocument<512> doc;
  JsonArray arr = doc.createNestedArray("relays");
  for (int i = 0; i < relayCount; i++) {
    JsonObject obj = arr.createNestedObject();
    obj["id"] = myRelays[i].id;
    obj["state"] = myRelays[i].state;
    obj["room"] = myRelays[i].room;
  }
  unlockRelays();
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
        if ((st == "1" || st == "0") && safeSetRelayPin(myRelays[i].pin, st == "1" ? LOW : HIGH)) {
          myRelays[i].state = st;
        }
        break;
      }
    }
  }
  hasOfflineBackup = true;
  Serial.println("[OFFLINE-BACKUP] OK: Đã khôi phục trạng thái lần cuối trước khi khởi động lại từ Flash!");
}

void resetToFactoryDefaults() {
  if (LittleFS.exists("/config.json")) LittleFS.remove("/config.json");
  if (LittleFS.exists("/config.json.tmp")) LittleFS.remove("/config.json.tmp");
  if (LittleFS.exists("/config.json.bak")) LittleFS.remove("/config.json.bak");
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
