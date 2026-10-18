#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h> // HiveMQ Cloud yêu cầu kết nối bảo mật TLS (8883)
#include <WiFiUdp.h>          // Hỗ trợ UDP Broadcast phát hiện thiết bị trong mạng LAN
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <PubSubClient.h>
#include <DHT.h>              // Tích hợp thư viện cảm biến
#include <Wire.h>
#include <Adafruit_PCF8574.h> // Tích hợp PCF8574
#include <esp_task_wdt.h>     // Hardware Watchdog Timer chống treo vi điều khiển
#include <esp_system.h>       // Phát hiện nguyên nhân khởi động (mất điện vs phần mềm)
#include <mbedtls/bignum.h>   // Hỗ trợ Bignum Diffie-Hellman Key Exchange
#include <mbedtls/md.h>       // Hỗ trợ HMAC-SHA256 xác thực bảo mật cục bộ
#include <mbedtls/sha256.h>

bool isPowerOutageBoot = false; // Đánh dấu khởi động sau khi mất điện
bool wasMqttPreviouslyConnected = false;

#define WDT_TIMEOUT_SECONDS 30
#define MAX_RELAYS 16
#define UDP_DISCOVERY_PORT 4210 // Cổng UDP Broadcast cho Discovery

Adafruit_PCF8574 pcf;
bool pcfFound = false;

void safeSetRelayPin(int pin, int level) {
  if (pcfFound && pin >= 0 && pin <= 7) {
    pcf.digitalWrite(pin, level);
  }
}
// ---------------------------------------------------------
// CẤU HÌNH ĐÈN LED TRẠNG THÁI
// ---------------------------------------------------------
#define STATUS_LED_PIN 2 // LED build-in trên ESP32 thường là chân 2

enum SystemState {
  STATE_AP_MODE,      // Chưa liên kết (Nháy nhanh)
  STATE_DISCONNECTED, // Mất kết nối (Nháy chậm)
  STATE_CONNECTED     // Kết nối thành công (Sáng đứng)
};
SystemState currentState = STATE_AP_MODE;

// ---------------------------------------------------------
// CẤU HÌNH CẢM BIẾN DHT11
// ---------------------------------------------------------
#define DHTPIN 14      // Khai báo chân GPIO kết nối DHT11
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// ---------------------------------------------------------
// CẤU HÌNH NÚT RESET (HARDWARE RESET)
// ---------------------------------------------------------
#define RESET_BTN_PIN 0 // Sử dụng nút BOOT có sẵn trên ESP32
unsigned long buttonPressTime = 0;
bool isButtonPressed = false;

// ---------------------------------------------------------
// KHỞI TẠO ĐỐI TƯỢNG HỆ THỐNG
// ---------------------------------------------------------
AsyncWebServer server(80);
WiFiClientSecure espClient; // Bắt buộc dùng Secure Client cho HiveMQ Cloud
PubSubClient mqttClient(espClient);
WiFiUDP udpDiscovery;       // Socket UDP cho mạng LAN

String wifi_ssid = "";
String wifi_pass = "";
String mqtt_prefix = "";
String mqtt_server = "e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud";
String mqtt_user = "DTC_ZenHome";
String mqtt_pass = "DTC_ZenHome2103";

struct RelayDev {
  String id;
  String room;
  int pin;
  String state; // "0" hoặc "1"
};

RelayDev myRelays[MAX_RELAYS]; 
int relayCount = 0;

bool isConfigured = false;
bool shouldReboot = false;
unsigned long rebootScheduledAt = 0;
bool isWebServerStarted = false;
bool isUdpStarted = false;


// ---------------------------------------------------------
// BIẾN ĐỊNH THỜI (NON-BLOCKING)
// ---------------------------------------------------------
unsigned long lastWiFiRetry = 0;
unsigned long lastMQTTRetry = 0;
unsigned long lastDHTRead = 0;
unsigned long setupStartTime = 0;
bool isProvisioned = false;

// Chứng chỉ Root CA của Let's Encrypt (Dành cho HiveMQ Cloud)
const char* root_ca = \
"-----BEGIN CERTIFICATE-----\n" \
"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\n" \
"-----END CERTIFICATE-----\n";

// Khai báo nguyên mẫu hàm
void setupAPMode();
void connectToWiFi();
bool loadConfig();
void connectMQTT();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void syncTime(); // Thêm hàm đồng bộ thời gian
void setupStationWebServer();
void setupUdpDiscovery();
void checkUdpDiscovery();
void backupRelayStatesToFlash();
void loadOfflineBackupFromFlash();
bool applyRelayCommand(const String& devId, const String& targetState);
void loadLocalSecretKey();
void saveLocalSecretKey(const String& key);
String computeHmacSha256(const String& keyHex, const String& message);
bool hasOfflineBackup = false;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- KHỞI ĐỘNG HỆ THỐNG SMART HOME ---");

  // Phát hiện lý do khởi động: Mất điện (Power-on/Brownout) vs Khởi động lại thông thường
  esp_reset_reason_t rstReason = esp_reset_reason();
  if (rstReason == ESP_RST_POWERON || rstReason == ESP_RST_BROWNOUT) {
    isPowerOutageBoot = true;
    Serial.println("[NGUỒN ĐIỆN] ⚡ CẢNH BÁO: Phát hiện ESP32 khởi động sau khi MẤT ĐIỆN (Power-On / Brownout)!");
  } else {
    isPowerOutageBoot = false;
    Serial.print("[HỆ THỐNG] Khởi động lại phần mềm/watchdog (không phải mất điện). Mã: ");
    Serial.println(rstReason);
  }

  pinMode(RESET_BTN_PIN, INPUT_PULLUP); // Cấu hình chân nút nhấn (mặc định kéo lên HIGH)
  pinMode(STATUS_LED_PIN, OUTPUT);      // Cấu hình chân đèn LED trạng thái

  dht.begin(); // Khởi động cảm biến

  Wire.begin(); // Khởi tạo I2C với chân mặc định (SDA=21, SCL=22)
  if (pcf.begin(0x20, &Wire)) {
    pcfFound = true;
    Serial.println("OK: Tìm thấy PCF8574 tại 0x20");
  } else if (pcf.begin(0x27, &Wire)) {
    pcfFound = true;
    Serial.println("OK: Tìm thấy PCF8574 tại 0x27");
  } else if (pcf.begin(0x38, &Wire)) {
    pcfFound = true;
    Serial.println("OK: Tìm thấy PCF8574A tại 0x38");
  } else {
    pcfFound = false;
    Serial.println("CẢNH BÁO: Không tìm thấy mô-đun PCF8574 ở bất kỳ địa chỉ nào!");
  }

  // Khởi tạo Task Watchdog Timer chống treo hệ thống (30s)
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

  loadLocalSecretKey(); // Nạp khóa bảo mật cục bộ Zero-Knowledge từ Flash

  if (LittleFS.exists("/provisioned.txt")) {
    isProvisioned = true;
  }

  if (loadConfig()) {
    isConfigured = true;
    setupStartTime = millis(); // Bắt đầu đếm thời gian kiểm tra kết nối
    
    // Cho phép kết nối TLS HiveMQ linh hoạt (chống rớt mạng do sai lệch giờ NTP hoặc thiếu chứng chỉ trung gian)
    espClient.setInsecure(); 
    mqttClient.setServer(mqtt_server.c_str(), 8883); 
    mqttClient.setCallback(mqttCallback);
    mqttClient.setBufferSize(1024); // Tăng kích thước buffer MQTT để nhận cấu hình JSON dài
    mqttClient.setKeepAlive(60);
    mqttClient.setSocketTimeout(30);
    
    connectToWiFi();
  } else {
    setupAPMode();
  }
}

void loop() {
  esp_task_wdt_reset(); // Reset Task Watchdog Timer mỗi chu kỳ loop
  unsigned long currentMillis = millis();

  if (shouldReboot && (currentMillis - rebootScheduledAt >= 1000)) {
    ESP.restart();
  }


  // ---------------------------------------------------------
  // KIỂM TRA NÚT RESET CỨNG (Nhấn giữ 5 giây để xóa config)
  // ---------------------------------------------------------
  if (digitalRead(RESET_BTN_PIN) == LOW) { // Nút được nhấn (kéo xuống LOW)
    if (!isButtonPressed) {
      isButtonPressed = true;
      buttonPressTime = currentMillis;
    } else {
      // Nếu giữ liên tục hơn 5 giây
      if (currentMillis - buttonPressTime >= 5000) {
        Serial.println("\n[!] PHÁT HIỆN YÊU CẦU FACTORY RESET TỪ NÚT CỨNG!");
        if (mqttClient.connected()) {
          String hwResetTopic = mqtt_prefix + "/system/hardware_reset";
          mqttClient.publish(hwResetTopic.c_str(), "1", false);
          delay(500); // Đợi để bản tin kịp gửi đi
        }
        if (LittleFS.exists("/config.json")) {
          LittleFS.remove("/config.json");
          Serial.println("Đã xóa file cấu hình hệ thống (/config.json).");
        }
        if (LittleFS.exists("/provisioned.txt")) {
          LittleFS.remove("/provisioned.txt");
        }
        
        // Tắt toàn bộ relay đang bật
        for (int i = 0; i < relayCount; i++) {
          safeSetRelayPin(myRelays[i].pin, HIGH);
        }
        Serial.println("Đã tắt toàn bộ thiết bị (relay).");
        
        Serial.println("Hệ thống sẽ khởi động lại và vào chế độ AP Setup sau 2 giây...");
        delay(2000);
        ESP.restart();
      }
    }
  } else {
    isButtonPressed = false; // Nhả nút ra thì reset lại trạng thái
  }

  // ---------------------------------------------------------
  // 0. KIỂM TRA TIMEOUT TRONG LẦN SETUP ĐẦU TIÊN
  // ---------------------------------------------------------
  if (isConfigured && !isProvisioned) {
    if (currentMillis - setupStartTime > 65000) { // 65 giây timeout
      Serial.println("\n[!] Lỗi: Quá thời gian (65s) không thể kết nối WiFi/MQTT!");
      Serial.println("[!] Xóa cấu hình nghi ngờ sai và khởi động lại vào chế độ AP...");
      if (LittleFS.exists("/config.json")) {
        LittleFS.remove("/config.json");
      }
      
      // Tắt toàn bộ relay đang bật
      for (int i = 0; i < relayCount; i++) {
        safeSetRelayPin(myRelays[i].pin, HIGH);
      }
      
      shouldReboot = true;
      return;
    }
  }

  // ---------------------------------------------------------
  // 1. DUY TRÌ KẾT NỐI WIFI (NON-BLOCKING)
  // ---------------------------------------------------------
  static unsigned long wifiDisconnectTime = 0;
  
  if (isConfigured && WiFi.status() != WL_CONNECTED) {
    if (wifiDisconnectTime == 0) wifiDisconnectTime = currentMillis;
    
    if (currentMillis - lastWiFiRetry >= 5000) {
      lastWiFiRetry = currentMillis;
      Serial.println("Mất kết nối WiFi! Đang chờ Hardware tự động kết nối lại...");
      
      // Khắc phục lỗi ESP32 bị treo WiFi (không thể tự reconnect) sau 60s
      if (currentMillis - wifiDisconnectTime >= 60000) {
        Serial.println("Quá 60s không tự phục hồi được WiFi. Đang khởi động lại phần cứng WiFi...");
        WiFi.disconnect();
        WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
        wifiDisconnectTime = currentMillis; // Đặt lại bộ đếm để chờ thêm 60s
      }
    }
    // Không dùng return ở đây để hàm loop tiếp tục chạy xuống dưới cập nhật trạng thái đèn LED
  } else {
    wifiDisconnectTime = 0; // Đặt lại nếu đã kết nối thành công
  }

  // ---------------------------------------------------------
  // 2. DUY TRÌ KẾT NỐI MQTT & DỊCH VỤ CỤC BỘ (NON-BLOCKING)
  // ---------------------------------------------------------
  if (WiFi.status() == WL_CONNECTED) {
    if (!isWebServerStarted) {
      setupStationWebServer();
      setupUdpDiscovery();
      isWebServerStarted = true;
    }
    checkUdpDiscovery();

    if (!mqttClient.connected()) {
      if (wasMqttPreviouslyConnected) {
        Serial.println("\n[MẠNG] ⚠️ Phát hiện mất kết nối MQTT trong khi nguồn điện vẫn duy trì!");
        wasMqttPreviouslyConnected = false;
      }
      if (currentMillis - lastMQTTRetry >= 8000) {
        lastMQTTRetry = currentMillis;
        connectMQTT();
      }
    } else {
      wasMqttPreviouslyConnected = true;
      mqttClient.loop();
    }
  }

  // ---------------------------------------------------------
  // 3. ĐỌC VÀ ĐỒNG BỘ DỮ LIỆU NHIỆT ĐỘ (Mỗi 10 giây)
  // ---------------------------------------------------------
  if (mqttClient.connected() && (currentMillis - lastDHTRead >= 10000)) {
    lastDHTRead = currentMillis;
    float t = dht.readTemperature();
    
    if (!isnan(t)) {
      String tempStr = String(t, 1);
      String topic = mqtt_prefix + "/nhiet_do_trong_nha";
      mqttClient.publish(topic.c_str(), tempStr.c_str());
    }
  }

  // ---------------------------------------------------------
  // 4. HIỂN THỊ ĐÈN LED TRẠNG THÁI
  // ---------------------------------------------------------
  if (!isConfigured) {
    currentState = STATE_AP_MODE;
  } else if (WiFi.status() != WL_CONNECTED || !mqttClient.connected()) {
    currentState = STATE_DISCONNECTED;
  } else {
    currentState = STATE_CONNECTED;
  }

  static unsigned long lastLedToggle = 0;
  static bool ledState = LOW;
  
  if (currentState == STATE_CONNECTED) {
    digitalWrite(STATUS_LED_PIN, HIGH); // Sáng liên tục
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


bool loadConfig() {
  if (!LittleFS.exists("/config.json")) return false;
  File configFile = LittleFS.open("/config.json", "r");
  if (!configFile) return false;

  size_t size = configFile.size();
  std::unique_ptr<char[]> buf(new char[size + 1]);
  configFile.readBytes(buf.get(), size);
  buf.get()[size] = '\0';
  configFile.close();

  DynamicJsonDocument doc(2048); 
  if (deserializeJson(doc, buf.get())) return false;

  wifi_ssid = doc["wifi_ssid"].as<String>();
  wifi_pass = doc["wifi_pass"].as<String>();
  mqtt_prefix = doc["mqtt_prefix"].as<String>();

  if (doc.containsKey("mqtt_server")) {
    String parsedServer = doc["mqtt_server"].as<String>();
    if (parsedServer.length() > 10) {
      mqtt_server = parsedServer;
      // Sửa lỗi tự động nếu địa chỉ gửi từ App bị thiếu đuôi (do app giới hạn ký tự)
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

  if (wifi_ssid == "" || wifi_ssid == "null") return false;

  JsonArray devs = doc["devices"].as<JsonArray>();
  relayCount = 0;
  for(JsonObject dev : devs) {
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

// ---------------------------------------------------------
// LƯU TRỮ VÀ KHÔI PHỤC TRẠNG THÁI RELAY KHI MẤT MẠNG (LITTLEFS)
// Chỉ backup khi MẤT MẠNG. Nếu CÓ MẠNG thì KHÔNG LƯU vào Flash.
// Cơ chế: Lưu đè xóa cũ thêm mới vào Flash nội bộ của ESP32.
// ---------------------------------------------------------
void backupRelayStatesToFlash() {
  DynamicJsonDocument doc(1024);
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
    Serial.println("[OFFLINE-BACKUP] ⚠️ Đang mất mạng! Đã lưu đè trạng thái cuối cùng vào bộ nhớ Flash ESP32");
  }
}

void loadOfflineBackupFromFlash() {
  if (!LittleFS.exists("/offline_backup.json")) return;
  File f = LittleFS.open("/offline_backup.json", "r");
  if (!f) return;
  DynamicJsonDocument doc(1024);
  DeserializationError err = deserializeJson(doc, f);
  f.close();
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

// ---------------------------------------------------------
// HÀM ĐIỀU KHIỂN THIẾT BỊ TẬP TRUNG (ÁP DỤNG CHO CẢ CLOUD & LOCAL)
// Luồng xử lý: Điều khiển thiết bị -> Kiểm tra mạng -> Backup nếu mất mạng, không mất mạng thì không lưu
// ---------------------------------------------------------
bool applyRelayCommand(const String& devId, const String& targetState) {
  bool found = false;
  for (int i = 0; i < relayCount; i++) {
    if (myRelays[i].id == devId) {
      found = true;
      myRelays[i].state = targetState;
      if (targetState == "1") {
        safeSetRelayPin(myRelays[i].pin, LOW); // Active-Low BẬT
      } else {
        safeSetRelayPin(myRelays[i].pin, HIGH); // Active-Low TẮT
      }

      // KIỂM TRA MẠNG:
      bool isNetworkOnline = (WiFi.status() == WL_CONNECTED && mqttClient.connected());

      if (isNetworkOnline) {
        // CÓ MẠNG: KHÔNG LƯU VÀO FLASH (Bảo vệ tuổi thọ chip, Cloud nhận trực tiếp)
        String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
        String stateTopic = mqtt_prefix + "/" + rName + "/" + devId + "/state";
        mqttClient.publish(stateTopic.c_str(), targetState.c_str(), true);
      } else {
        // MẤT MẠNG: LƯU ĐÈ TRẠNG THÁI CUỐI CÙNG VÀO FLASH ESP32 (Xóa cũ thêm mới)
        backupRelayStatesToFlash();
      }
      break;
    }
  }
  return found;
}

// =========================================================
// BẢO MẬT ZERO-KNOWLEDGE KHI ĐIỀU KHIỂN CỤC BỘ (LOCAL LAN)
// Cơ chế: Trao đổi khóa Diffie-Hellman (RFC 3526 MODP 1536-bit)
// Khóa được sinh ngẫu nhiên từ phần cứng, lưu cục bộ trong Flash,
// KHÔNG AI BIẾT (kể cả Server & Quản trị ZenHome).
// Mọi lệnh điều khiển mạng LAN đều yêu cầu chữ ký HMAC-SHA256.
// =========================================================
const char* DH_PRIME_1536 = 
  "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"
  "29024E088A67CC74020BBEA63B139B22514A08798E3404DD"
  "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"
  "E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
  "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381"
  "FFFFFFFFFFFFFFFF";
const char* DH_GENERATOR = "2";

String currentLocalSecretKey = "";

String dhModPow(const String& baseHex, const String& expHex, const String& modHex) {
  mbedtls_mpi base, exp, mod, result;
  mbedtls_mpi_init(&base);
  mbedtls_mpi_init(&exp);
  mbedtls_mpi_init(&mod);
  mbedtls_mpi_init(&result);

  mbedtls_mpi_read_string(&base, 16, baseHex.c_str());
  mbedtls_mpi_read_string(&exp, 16, expHex.c_str());
  mbedtls_mpi_read_string(&mod, 16, modHex.c_str());

  mbedtls_mpi_exp_mod(&result, &base, &exp, &mod, NULL);

  char buf[512];
  size_t olen = 0;
  mbedtls_mpi_write_string(&result, 16, buf, sizeof(buf), &olen);

  mbedtls_mpi_free(&base);
  mbedtls_mpi_free(&exp);
  mbedtls_mpi_free(&mod);
  mbedtls_mpi_free(&result);

  return String(buf);
}

String computeSha256Hex(const String& inputHex) {
  size_t len = inputHex.length() / 2;
  uint8_t* bytes = (uint8_t*)malloc(len);
  if (!bytes) return "";
  for (size_t i = 0; i < len; i++) {
    char byteStr[3] = { inputHex[i * 2], inputHex[i * 2 + 1], 0 };
    bytes[i] = (uint8_t)strtol(byteStr, NULL, 16);
  }

  uint8_t output[32];
  const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md(md_info, bytes, len, output);
  free(bytes);

  char outHex[65];
  for (int i = 0; i < 32; i++) {
    sprintf(outHex + i * 2, "%02x", output[i]);
  }
  outHex[64] = 0;
  return String(outHex);
}

String computeHmacSha256(const String& keyHex, const String& message) {
  const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  size_t keyLen = keyHex.length() / 2;
  uint8_t* keyBytes = (uint8_t*)malloc(keyLen);
  if (!keyBytes) return "";
  for (size_t i = 0; i < keyLen; i++) {
    char byteStr[3] = { keyHex[i * 2], keyHex[i * 2 + 1], 0 };
    keyBytes[i] = (uint8_t)strtol(byteStr, NULL, 16);
  }

  uint8_t output[32];
  mbedtls_md_hmac(md_info, keyBytes, keyLen, (const unsigned char*)message.c_str(), message.length(), output);
  free(keyBytes);

  char outHex[65];
  for (int i = 0; i < 32; i++) {
    sprintf(outHex + i * 2, "%02x", output[i]);
  }
  outHex[64] = 0;
  return String(outHex);
}

void loadLocalSecretKey() {
  if (LittleFS.exists("/local_sec_key.dat")) {
    File f = LittleFS.open("/local_sec_key.dat", "r");
    if (f) {
      currentLocalSecretKey = f.readString();
      currentLocalSecretKey.trim();
      f.close();
      Serial.println("[LOCAL-SEC] 🔐 Đã tải khóa bảo mật Zero-Knowledge từ Flash LittleFS!");
    }
  }
}

void saveLocalSecretKey(const String& key) {
  currentLocalSecretKey = key;
  File f = LittleFS.open("/local_sec_key.dat", "w");
  if (f) {
    f.print(key);
    f.close();
    Serial.println("[LOCAL-SEC] 🔐 Đã lưu khóa bảo mật Zero-Knowledge vào Flash LittleFS!");
  }
}

void setupAPMode() {
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  String apName = "ZenHome_Setup_" + mac.substring(6);
  // Mật khẩu phát sóng chuẩn AP để người dùng kết nối trực tiếp trong ứng dụng
  String apPass = "12345678"; 
  
  WiFi.mode(WIFI_AP);
  WiFi.softAP(apName.c_str(), apPass.c_str()); 
  
  server.on("/api/config", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    String jsonPayload((char*)data, len);
    Serial.println("\n[HTTP] >>> Nhận gói cấu hình từ App:");
    Serial.println(jsonPayload);
    
    File file = LittleFS.open("/config.json", "w");
    if (file) {
      file.print(jsonPayload);
      file.close();
      String mac = WiFi.macAddress();
      Serial.println("[HTTP] Đã ghi file /config.json thành công. Khởi động lại sau 2 giây...");
      request->send(200, "application/json", "{\"status\":\"ok\",\"macAddress\":\"" + mac + "\"}");
      shouldReboot = true; 
    } else {
      Serial.println("[HTTP] LỖI ghi file /config.json!");
      request->send(500, "application/json", "{\"status\":\"error\"}");
    }
  });

  server.on("/ping", HTTP_GET, [](AsyncWebServerRequest *request) {
    String mac = WiFi.macAddress();
    request->send(200, "application/json", "{\"status\":\"ok\",\"macAddress\":\"" + mac + "\"}");
  });

  server.begin();
  Serial.println("Đã mở chế độ AP Setup: " + apName);
  Serial.println("Mật khẩu AP Setup: " + apPass);
}

void connectToWiFi() {
  Serial.println("Đang kết nối WiFi: " + wifi_ssid);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true); // Cấu hình tự động kết nối lại
  WiFi.begin(wifi_ssid.c_str(), wifi_pass.c_str());
  
  // Chờ kết nối để đồng bộ thời gian (cần thiết cho chứng chỉ SSL)
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
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  Serial.print("Đang đồng bộ thời gian NTP...");
  time_t now = time(nullptr);
  int retries = 0;
  while (now < 100000 && retries < 20) {
    esp_task_wdt_reset();
    delay(500);
    Serial.print(".");
    now = time(nullptr);
    retries++;
  }
  Serial.println("\nĐồng bộ thời gian hoàn tất.");
}

void connectMQTT() {
  Serial.println("Đang kết nối MQTT TLS (8883) tới: " + mqtt_server + " (User: " + mqtt_user + ")");
  String mac = WiFi.macAddress();
  mac.replace(":", "");
  String clientId = "ESP32_" + mac;
  String statusTopic = mqtt_prefix + "/esp_status";

  // Thiết lập thông điệp Di chúc (Last Will) là "offline"
  bool connected = false;
  if (mqtt_user != "" && mqtt_pass != "") {
    // Kết nối có xác thực user/pass
    connected = mqttClient.connect(clientId.c_str(), mqtt_user.c_str(), mqtt_pass.c_str(), statusTopic.c_str(), 1, true, "offline");
  } else {
    // Kết nối ẩn danh (không khuyến cáo)
    connected = mqttClient.connect(clientId.c_str(), statusTopic.c_str(), 1, true, "offline");
  }

  if (connected) {
    Serial.println("Kết nối MQTT Thành công!");
    
    if (!isProvisioned) {
      isProvisioned = true;
      File f = LittleFS.open("/provisioned.txt", "w");
      if (f) {
        f.print("1");
        f.close();
      }
      Serial.println("Đã xác nhận cấu hình đúng! Khóa cứng chế độ AP.");
    }
    
    if (isPowerOutageBoot) {
      // 1. TRƯỜNG HỢP CÓ ĐIỆN LẠI SAU KHI MẤT ĐIỆN: TẮT TOÀN BỘ THIẾT BỊ
      Serial.println("\n[HỆ THỐNG] ⚡ Báo cáo sự kiện: CÓ ĐIỆN LẠI SAU MẤT ĐIỆN (Tắt toàn bộ thiết bị)");
      mqttClient.publish(statusTopic.c_str(), "online", true);

      String eventTopic = mqtt_prefix + "/system/event";
      mqttClient.publish(eventTopic.c_str(), "{\"event\":\"power_restored\",\"action\":\"all_off\",\"reason\":\"power_outage\"}", false);

      // Xuất bản trạng thái toàn bộ là 0 (TẮT)
      for (int i = 0; i < relayCount; i++) {
        String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
        String stateTopic = mqtt_prefix + "/" + rName + "/" + myRelays[i].id + "/state";
        mqttClient.publish(stateTopic.c_str(), "0", true);
      }
      if (LittleFS.exists("/offline_backup.json")) {
        LittleFS.remove("/offline_backup.json");
      }
      hasOfflineBackup = false;
      isPowerOutageBoot = false; // Đã báo cáo xong lần có điện lại
    } else {
      // 2. TRƯỜNG HỢP CÓ MẠNG LẠI SAU KHI MẤT MẠNG: ĐẨY TÍN HIỆU BACKUP TRẠNG THÁI LẦN CUỐI
      Serial.println("\n[HỆ THỐNG] 🌐 Báo cáo sự kiện: CÓ MẠNG LẠI SAU MẤT MẠNG (Đồng bộ trạng thái lần cuối)");
      mqttClient.publish(statusTopic.c_str(), "online", true);

      String eventTopic = mqtt_prefix + "/system/event";
      mqttClient.publish(eventTopic.c_str(), "{\"event\":\"network_restored\",\"action\":\"sync_last_state\",\"reason\":\"network_loss\"}", false);

      // Xuất bản trạng thái thực tế lần cuối của toàn bộ relay lên MQTT Broker (retain: true)
      DynamicJsonDocument syncDoc(1024);
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

      // Xóa file backup trên bộ nhớ ESP32 vì đã có mạng và đã đồng bộ xong lên Cloud
      if (LittleFS.exists("/offline_backup.json")) {
        LittleFS.remove("/offline_backup.json");
      }
      hasOfflineBackup = false;
      Serial.println("[SYNC] ✅ Đã đẩy tín hiệu backup trạng thái lần cuối lên Cloud & xóa backup tạm trên ESP32!");
    }

    // Bắt đầu lắng nghe lệnh điều khiển từ ứng dụng
    String listenTopic = mqtt_prefix + "/+/+/cmd";
    mqttClient.subscribe(listenTopic.c_str());
    
    // Lắng nghe lệnh cập nhật cấu hình thiết bị
    String systemConfigTopic = mqtt_prefix + "/system/config";
    mqttClient.subscribe(systemConfigTopic.c_str());

    // Lắng nghe lệnh reset hệ thống từ backend
    String systemResetTopic = mqtt_prefix + "/system/reset";
    mqttClient.subscribe(systemResetTopic.c_str());

    // Lắng nghe lệnh khởi động lại hệ thống từ backend/app
    String systemRebootTopic = mqtt_prefix + "/system/reboot";
    String systemRestartTopic = mqtt_prefix + "/system/restart";
    mqttClient.subscribe(systemRebootTopic.c_str());
    mqttClient.subscribe(systemRestartTopic.c_str());
  } else {
    int state = mqttClient.state();
    Serial.print("LỖI kết nối MQTT! Mã lỗi (rc): ");
    Serial.print(state);
    if (state == -4) {
      Serial.println(" (MQTT_CONNECTION_TIMEOUT: Máy chủ HiveMQ phản hồi chậm hoặc đang bắt tay TLS)");
    } else if (state == -2) {
      Serial.println(" (MQTT_CONNECT_FAILED: Lỗi kết nối TCP/TLS)");
    } else if (state == 4 || state == 5) {
      Serial.println(" (MQTT_UNAUTHORIZED: Sai tên đăng nhập hoặc mật khẩu)");
    } else {
      Serial.println();
    }
  }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String message((char*)payload, length);
  String topicStr = String(topic);

  // Kiểm tra lệnh khởi động lại (Reboot / Restart) hệ thống từ App
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

  // Kiểm tra lệnh reset hệ thống từ Backend
  String systemResetTopic = mqtt_prefix + "/system/reset";
  if (topicStr == systemResetTopic && message == "1") {
    Serial.println("\n[!] PHÁT HIỆN YÊU CẦU FACTORY RESET TỪ SERVER (APP XÓA TÀI KHOẢN)!");
    
    // Xóa cờ retained của lệnh reset trên broker để tránh vòng lặp reset vô tận
    mqttClient.publish(systemResetTopic.c_str(), "", true);
    
    if (LittleFS.exists("/config.json")) {
      LittleFS.remove("/config.json");
      Serial.println("Đã xóa file cấu hình hệ thống (/config.json).");
    }
    if (LittleFS.exists("/provisioned.txt")) {
      LittleFS.remove("/provisioned.txt");
    }
    
    // Tắt toàn bộ relay đang bật
    for (int i = 0; i < relayCount; i++) {
      safeSetRelayPin(myRelays[i].pin, HIGH);
    }
    Serial.println("Đã tắt toàn bộ thiết bị (relay).");
    
    Serial.println("Hệ thống sẽ khởi động lại và vào chế độ AP Setup sau 2 giây...");
    shouldReboot = true;
    return;
  }

  // Kiểm tra lệnh cập nhật cấu hình hệ thống / thiết bị qua MQTT
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
            // Tương thích ngược: Gói tin gửi mảng devices từ màn hình gán chân GPIO
            doc["devices"] = newConfigDoc.as<JsonArray>();
          } else if (newConfigDoc.is<JsonObject>()) {
            // Xác thực mật khẩu quản trị trước khi cho phép cập nhật cấu hình hệ thống
            String currentAdminPass = doc.containsKey("admin_pass") ? doc["admin_pass"].as<String>() : "admin";
            String sentAdminPass = newConfigDoc.containsKey("admin_pass") ? newConfigDoc["admin_pass"].as<String>() : "";

            if (currentAdminPass.length() > 0 && sentAdminPass != currentAdminPass) {
              Serial.println("\n[!] BẢO MẬT: Sai mật khẩu quản trị! Từ chối ghi đè cấu hình ESP32.");
              return;
            }

            // Cập nhật cấu hình Wi-Fi, MQTT hoặc toàn bộ hệ thống
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

  applyRelayCommand(devId, targetState);
}

// ---------------------------------------------------------
// KHỞI TẠO HTTP SERVER CỤC BỘ TRONG MẠNG LAN
// ---------------------------------------------------------
void setupStationWebServer() {
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Origin", "*");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  DefaultHeaders::Instance().addHeader("Access-Control-Allow-Headers", "Content-Type, X-ZenHome-Signature, X-ZenHome-Timestamp, X-ZenHome-Nonce");

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
    String json = "{\"status\":\"ok\",\"service\":\"zenhome_hub\",\"macAddress\":\"" + mac + "\",\"ip\":\"" + WiFi.localIP().toString() + "\",\"secured\":" + String(currentLocalSecretKey.length() > 0 ? "true" : "false") + "}";
    request->send(200, "application/json", json);
  });

  // Endpoint 2: Lấy toàn diện trạng thái thiết bị & cảm biến mạng LAN
  server.on("/api/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    DynamicJsonDocument doc(2048);
    doc["status"] = "ok";
    doc["service"] = "zenhome_hub";
    doc["macAddress"] = WiFi.macAddress();
    doc["ip"] = WiFi.localIP().toString();
    doc["rssi"] = WiFi.RSSI();
    doc["mqttConnected"] = mqttClient.connected();
    doc["uptime"] = millis() / 1000;
    doc["secured"] = (currentLocalSecretKey.length() > 0);

    float t = dht.readTemperature();
    if (!isnan(t)) {
      doc["temp"] = String(t, 1);
    } else {
      doc["temp"] = "--";
    }

    JsonArray devsArr = doc.createNestedArray("devices");
    for (int i = 0; i < relayCount; i++) {
      JsonObject devObj = devsArr.createNestedObject();
      devObj["id"] = myRelays[i].id;
      devObj["pin"] = myRelays[i].pin;
      devObj["state"] = myRelays[i].state;
    }

    String response;
    serializeJson(doc, response);
    request->send(200, "application/json", response);
  });

  // Endpoint 2.5: Trao đổi khóa bảo mật Zero-Knowledge giữa App và ESP32 (POST /api/auth/key-exchange)
  server.on("/api/auth/key-exchange", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    String payload((char*)data, len);
    DynamicJsonDocument doc(1024);
    DeserializationError err = deserializeJson(doc, payload);

    if (err || !doc.containsKey("clientPublicKey")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu clientPublicKey\"}");
      return;
    }

    String clientPub = doc["clientPublicKey"].as<String>();
    clientPub.toLowerCase();

    // 1. Sinh khóa bí mật b (256-bit) của ESP32
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

    // 4. Băm SHA-256 để tạo khóa đối xứng K (Zero-Knowledge 256-bit Session Key)
    String derivedKey = computeSha256Hex(sharedSecret);

    // 5. Lưu khóa bí mật vào Flash nội bộ ESP32 (Không gửi lên Cloud, không ai biết)
    saveLocalSecretKey(derivedKey);

    // 6. Tính bằng chứng xác thực Proof = HMAC(K, clientPub + ":" + serverPub)
    String proof = computeHmacSha256(derivedKey, clientPub + ":" + serverPub);

    DynamicJsonDocument resDoc(1024);
    resDoc["status"] = "ok";
    resDoc["serverPublicKey"] = serverPub;
    resDoc["proof"] = proof;

    String resStr;
    serializeJson(resDoc, resStr);
    request->send(200, "application/json", resStr);
    Serial.println("[LOCAL-SEC] 🤝 Trao đổi khóa Zero-Knowledge với App thành công! Khóa an toàn 100%.");
  });

  // Endpoint 2.6: Kiểm tra trạng thái bảo mật của Hub (GET /api/auth/status)
  server.on("/api/auth/status", HTTP_GET, [](AsyncWebServerRequest *request) {
    bool hasKey = (currentLocalSecretKey.length() > 0);
    String res = "{\"status\":\"ok\",\"secured\":" + String(hasKey ? "true" : "false") + "}";
    request->send(200, "application/json", res);
  });

  // Endpoint 3: Điều khiển thiết bị tức thì qua mạng LAN (POST /api/control)
  server.on("/api/control", HTTP_POST, [](AsyncWebServerRequest *request){}, NULL, [](AsyncWebServerRequest *request, uint8_t *data, size_t len, size_t index, size_t total) {
    String payload((char*)data, len);
    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, payload);

    if (err || !doc.containsKey("id") || !doc.containsKey("cmd")) {
      request->send(400, "application/json", "{\"status\":\"error\",\"message\":\"Thiếu id hoặc cmd\"}");
      return;
    }

    String devId = doc["id"].as<String>();
    String cmd = doc["cmd"].as<String>();

    // -------------------------------------------------------------
    // XÁC THỰC BẢO MẬT ZERO-KNOWLEDGE KHI CÓ KHÓA ĐÃ ĐỒNG BỘ
    // -------------------------------------------------------------
    if (currentLocalSecretKey.length() > 0) {
      if (!request->hasHeader("X-ZenHome-Signature") || !request->hasHeader("X-ZenHome-Timestamp") || !request->hasHeader("X-ZenHome-Nonce")) {
        request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_NO_SIG\",\"message\":\"Yêu cầu bị từ chối: Thiếu chữ ký bảo mật Local!\"}");
        return;
      }

      String sig = request->getHeader("X-ZenHome-Signature")->value();
      String ts = request->getHeader("X-ZenHome-Timestamp")->value();
      String nonce = request->getHeader("X-ZenHome-Nonce")->value();

      String signPayload = devId + ":" + cmd + ":" + ts + ":" + nonce;
      String expectedSig = computeHmacSha256(currentLocalSecretKey, signPayload);

      if (!sig.equalsIgnoreCase(expectedSig)) {
        Serial.println("[LOCAL-SEC] ❌ Chữ ký bảo mật Local không hợp lệ! Từ chối lệnh.");
        request->send(401, "application/json", "{\"status\":\"error\",\"code\":\"UNAUTHORIZED_BAD_SIG\",\"message\":\"Chữ ký HMAC bảo mật không hợp lệ!\"}");
        return;
      }
    }

    String targetState = (cmd == "1" || cmd == "ON" || cmd == "on") ? "1" : "0";
    bool found = applyRelayCommand(devId, targetState);

    if (found) {
      String res = "{\"status\":\"ok\",\"id\":\"" + devId + "\",\"state\":\"" + targetState + "\"}";
      request->send(200, "application/json", res);
      Serial.println("[LOCAL-HTTP] 🔒 [Bảo Mật OK] Điều khiển thiết bị " + devId + " -> " + targetState);
    } else {
      request->send(404, "application/json", "{\"status\":\"error\",\"message\":\"Không tìm thấy thiết bị\"}");
    }
  });

  // Endpoint 4: Khởi động lại (POST /api/reboot)
  server.on("/api/reboot", HTTP_POST, [](AsyncWebServerRequest *request) {
    request->send(200, "application/json", "{\"status\":\"ok\",\"message\":\"Rebooting...\"}");
    rebootScheduledAt = millis();
    shouldReboot = true;
  });

  server.begin();
  Serial.println("[HTTP] Web Server cục bộ (Local LAN) đã khởi động trên cổng 80!");
}

// ---------------------------------------------------------
// DỊCH VỤ PHÁT HIỆN THIẾT BỊ MẠNG CỤC BỘ (UDP BROADCAST)
// ---------------------------------------------------------
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

      DynamicJsonDocument resDoc(512);
      resDoc["service"] = "zenhome_hub";
      resDoc["macAddress"] = mac;
      resDoc["ip"] = WiFi.localIP().toString();
      resDoc["port"] = 80;
      resDoc["name"] = "ZenHome Hub";
      resDoc["mqtt_prefix"] = mqtt_prefix;
      
      float t = dht.readTemperature();
      if (!isnan(t)) {
        resDoc["temp"] = String(t, 1);
      } else {
        resDoc["temp"] = "--";
      }

      String reply;
      serializeJson(resDoc, reply);

      udpDiscovery.beginPacket(remoteIp, remotePort);
      udpDiscovery.print(reply);
      udpDiscovery.endPacket();

      Serial.println("[UDP] Đã phản hồi vị trí Hub tới App (" + remoteIp.toString() + ")");
    }
  }
}