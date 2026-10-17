#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h> // HiveMQ Cloud yêu cầu kết nối bảo mật TLS (8883)
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <PubSubClient.h>
#include <DHT.h>              // Tích hợp thư viện cảm biến
#include <Wire.h>
#include <Adafruit_PCF8574.h> // Tích hợp PCF8574

Adafruit_PCF8574 pcf;
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

String wifi_ssid = "";
String wifi_pass = "";
String mqtt_prefix = "";
String mqtt_server = "e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud";
String mqtt_user = "DTC_ZenHome";
String mqtt_pass = "DTC_ZenHome2103";

struct RelayDev {
  String id;
  int pin;
};

RelayDev myRelays[10]; 
int relayCount = 0;

bool isConfigured = false;
bool shouldReboot = false;
unsigned long rebootScheduledAt = 0;


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

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- KHỞI ĐỘNG HỆ THỐNG SMART HOME ---");

  pinMode(RESET_BTN_PIN, INPUT_PULLUP); // Cấu hình chân nút nhấn (mặc định kéo lên HIGH)
  pinMode(STATUS_LED_PIN, OUTPUT);      // Cấu hình chân đèn LED trạng thái

  dht.begin(); // Khởi động cảm biến

  Wire.begin(); // Khởi tạo I2C với chân mặc định (SDA=21, SCL=22)
  if (!pcf.begin(0x20, &Wire)) {
    Serial.println("Không tìm thấy PCF8574 tại 0x20, thử 0x27...");
    if (!pcf.begin(0x27, &Wire)) {
      if (!pcf.begin(0x38, &Wire)) { // Thử cả 0x38 (PCF8574A)
        Serial.println("LỖI: Không tìm thấy mô-đun PCF8574 ở bất kỳ địa chỉ nào!");
      } else {
        Serial.println("OK: Tìm thấy PCF8574A tại 0x38");
      }
    } else {
      Serial.println("OK: Tìm thấy PCF8574 tại 0x27");
    }
  } else {
    Serial.println("OK: Tìm thấy PCF8574 tại 0x20");
  }

  if (!LittleFS.begin(true)) {
    Serial.println("Lỗi mount LittleFS!");
    return;
  }

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
          pcf.digitalWrite(myRelays[i].pin, HIGH);
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
        pcf.digitalWrite(myRelays[i].pin, HIGH);
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
  // 2. DUY TRÌ KẾT NỐI MQTT (NON-BLOCKING)
  // ---------------------------------------------------------
  if (WiFi.status() == WL_CONNECTED) {
    if (!mqttClient.connected()) {
      if (currentMillis - lastMQTTRetry >= 8000) {
        lastMQTTRetry = currentMillis;
        connectMQTT();
      }
    } else {
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
    myRelays[relayCount].id = dev["id"].as<String>();
    myRelays[relayCount].pin = dev["pin"].as<int>();
    
    if (myRelays[relayCount].pin > 7) {
      Serial.print("CẢNH BÁO: Chân relay ");
      Serial.print(myRelays[relayCount].pin);
      Serial.println(" lớn hơn 7! PCF8574 chỉ hỗ trợ chân từ 0-7.");
    }

    pcf.pinMode(myRelays[relayCount].pin, OUTPUT);
    pcf.digitalWrite(myRelays[relayCount].pin, HIGH); 
    relayCount++;
  }
  return true;
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
    delay(500);
    Serial.print(".");
    retries++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi kết nối thành công! IP: " + WiFi.localIP().toString());
    syncTime();
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
    
    // Gửi tín hiệu online ngay khi kết nối
    mqttClient.publish(statusTopic.c_str(), "online", true);

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
      pcf.digitalWrite(myRelays[i].pin, HIGH);
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

  for (int i = 0; i < relayCount; i++) {
    if (myRelays[i].id == devId) {
      if (targetState == "1") pcf.digitalWrite(myRelays[i].pin, LOW);
      else if (targetState == "0") pcf.digitalWrite(myRelays[i].pin, HIGH);
      
      // Đồng bộ lại trạng thái cho ứng dụng di động
      String stateTopic = topicStr;
      stateTopic.replace("/cmd", "/state"); 
      mqttClient.publish(stateTopic.c_str(), targetState.c_str(), true); 
      break;
    }
  }
}