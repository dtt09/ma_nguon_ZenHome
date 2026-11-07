#include "hardware_manager.h"
#include "config_manager.h"
#include "ble_manager.h"
#include "mqtt_manager.h"
#include <WiFi.h>

Adafruit_PCF8574 pcf;
bool pcfFound = false;
uint8_t activePcfAddress = 0;
DHT dht(DHTPIN, DHTTYPE);

float cachedTemperature = NAN;
float cachedHumidity = NAN;
unsigned long lastRuleEvalTime = 0;
unsigned long lastDHTRead = 0;

LocalRule localRules[MAX_LOCAL_RULES];
int localRuleCount = 0;

PhysicalSwitch physicalSwitches[] = {
  { 32, 0, HIGH, HIGH, 0, 0 }, // GPIO 32 -> Relay 0 (Internal Pull-Up)
  { 33, 1, HIGH, HIGH, 0, 0 }, // GPIO 33 -> Relay 1 (Internal Pull-Up)
  { 25, 2, HIGH, HIGH, 0, 0 }  // GPIO 25 -> Relay 2 (Internal Pull-Up)
};
const int physicalSwitchCount = sizeof(physicalSwitches) / sizeof(physicalSwitches[0]);
const unsigned long SWITCH_DEBOUNCE_MS = 200;
const unsigned long SWITCH_MIN_TOGGLE_INTERVAL = 1500;

static SemaphoreHandle_t i2cMutex = NULL;

static LedStatusPattern currentLedPattern = LED_PATTERN_AP_MODE;
static unsigned long ledBlipUntil = 0;
static unsigned long lastLedPatternStep = 0;
static uint8_t ledStepIndex = 0;

void setLedPattern(LedStatusPattern pattern) {
  if (currentLedPattern != pattern) {
    currentLedPattern = pattern;
    ledStepIndex = 0;
    lastLedPatternStep = 0;
  }
}

void triggerLedActionBlip() {
  ledBlipUntil = millis() + 65; // Chớp 65ms phản hồi thao tác tức thì
  digitalWrite(STATUS_LED_PIN, !digitalRead(STATUS_LED_PIN)); // Đảo trạng thái hiện tại
}

void updateLedIndicator() {
  unsigned long now = millis();

  // 1. Ưu tiên xử lý Action Blip (phản hồi thị giác khi relay bật/tắt hoặc BLE handshake)
  if (ledBlipUntil > 0) {
    if (now < ledBlipUntil) {
      return; // Giữ trạng thái blip
    } else {
      ledBlipUntil = 0; // Hết hạn blip, quay về pattern bình thường
    }
  }

  // 2. Xử lý mẫu chớp theo trạng thái hệ thống
  switch (currentLedPattern) {
    case LED_PATTERN_ONLINE_ALL:
      // Solid ON: Sáng liên tục báo hiệu hệ thống đã hoàn toàn online (Wi-Fi + Cloud MQTT)
      digitalWrite(STATUS_LED_PIN, HIGH);
      break;

    case LED_PATTERN_WIFI_CONNECTING:
      // Nhấp nháy nhanh đều 100ms ON / 100ms OFF: Đang kết nối hoặc reconnect Wi-Fi
      if (now - lastLedPatternStep >= 100) {
        lastLedPatternStep = now;
        ledStepIndex = (ledStepIndex + 1) % 2;
        digitalWrite(STATUS_LED_PIN, (ledStepIndex == 0) ? HIGH : LOW);
      }
      break;

    case LED_PATTERN_WIFI_CONNECTED:
      // Nhấp nháy vừa 250ms ON / 250ms OFF: Đã có Wi-Fi, đang đợi kết nối MQTT Broker
      if (now - lastLedPatternStep >= 250) {
        lastLedPatternStep = now;
        ledStepIndex = (ledStepIndex + 1) % 2;
        digitalWrite(STATUS_LED_PIN, (ledStepIndex == 0) ? HIGH : LOW);
      }
      break;

    case LED_PATTERN_OFFLINE_LOCAL:
      // Nhấp nháy chậm 500ms ON / 500ms OFF: Router Wi-Fi mất kết nối, hệ thống chạy tự trị + BLE Fallback
      if (now - lastLedPatternStep >= 500) {
        lastLedPatternStep = now;
        ledStepIndex = (ledStepIndex + 1) % 2;
        digitalWrite(STATUS_LED_PIN, (ledStepIndex == 0) ? HIGH : LOW);
      }
      break;

    case LED_PATTERN_AP_MODE:
    default:
      // Nháy đúp (Double-Blink): ON 100ms -> OFF 100ms -> ON 100ms -> OFF 700ms (Tổng chu kỳ 1000ms)
      // Thể hiện trực quan ESP32 đang phát Wi-Fi AP Setup chờ cài đặt
      if (ledStepIndex == 0 && (now - lastLedPatternStep >= 100)) {
        lastLedPatternStep = now;
        ledStepIndex = 1;
        digitalWrite(STATUS_LED_PIN, LOW);
      } else if (ledStepIndex == 1 && (now - lastLedPatternStep >= 100)) {
        lastLedPatternStep = now;
        ledStepIndex = 2;
        digitalWrite(STATUS_LED_PIN, HIGH);
      } else if (ledStepIndex == 2 && (now - lastLedPatternStep >= 100)) {
        lastLedPatternStep = now;
        ledStepIndex = 3;
        digitalWrite(STATUS_LED_PIN, LOW);
      } else if (ledStepIndex == 3 && (now - lastLedPatternStep >= 700)) {
        lastLedPatternStep = now;
        ledStepIndex = 0;
        digitalWrite(STATUS_LED_PIN, HIGH);
      } else if (lastLedPatternStep == 0) {
        lastLedPatternStep = now;
        ledStepIndex = 0;
        digitalWrite(STATUS_LED_PIN, HIGH);
      }
      break;
  }
}

void initHardwareMutex() {
  if (i2cMutex == NULL) {
    i2cMutex = xSemaphoreCreateMutex();
  }
}

bool lockI2C(TickType_t waitTicks) {
  if (i2cMutex == NULL) return true;
  return xSemaphoreTake(i2cMutex, waitTicks) == pdTRUE;
}

void unlockI2C() {
  if (i2cMutex != NULL) {
    xSemaphoreGive(i2cMutex);
  }
}

static uint8_t scanAndDetectI2CDevice() {
  pinMode(21, INPUT_PULLUP);
  pinMode(22, INPUT_PULLUP);
  delay(10);
  int sdaLevel = digitalRead(21);
  int sclLevel = digitalRead(22);
  Serial.printf("\n[I2C-DIAG] 🔍 Kiểm tra vật lý: SDA (GPIO 21) = %s | SCL (GPIO 22) = %s\n",
                sdaLevel ? "HIGH (OK - Có nguồn/trở kéo)" : "LOW (LỖI - Kẹt Mass/Đứt nguồn)",
                sclLevel ? "HIGH (OK - Có nguồn/trở kéo)" : "LOW (LỖI - Kẹt Mass/Đứt nguồn)");

  Wire.begin(21, 22, 100000);
  Wire.setTimeOut(50);

  Serial.println("[I2C-SCAN] 📡 Đang quét toàn bộ 127 địa chỉ I2C (0x01 -> 0x7F)...");
  uint8_t detectedAddr = 0;
  int foundCount = 0;

  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    uint8_t error = Wire.endTransmission();
    if (error == 0) {
      Serial.printf("[I2C-SCAN] 🎯 TÌM THẤY THIẾT BỊ I2C TẠI ĐỊA CHỈ: 0x%02X (%d)\n", addr, addr);
      foundCount++;
      // Ưu tiên dải PCF8574 (0x20..0x27) hoặc PCF8574A (0x38..0x3F)
      if ((addr >= 0x20 && addr <= 0x27) || (addr >= 0x38 && addr <= 0x3F)) {
        detectedAddr = addr;
      } else if (detectedAddr == 0) {
        detectedAddr = addr; // Gán tạm nếu không có chip chuẩn
      }
    }
  }

  if (foundCount == 0) {
    Serial.println("[I2C-SCAN] ❌ Không phát hiện bất kỳ thiết bị I2C nào phản hồi!");
  }
  return detectedAddr;
}

void initHardware() {
  initHardwareMutex();
  pinMode(RESET_BTN_PIN, INPUT_PULLUP);
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);

  dht.begin();

  if (lockI2C(pdMS_TO_TICKS(1000))) {
    uint8_t pcfAddr = scanAndDetectI2CDevice();
    if (pcfAddr != 0 && pcf.begin(pcfAddr, &Wire)) {
      pcfFound = true;
      activePcfAddress = pcfAddr;
      Serial.printf("[HARDWARE] ✅ Khởi tạo thành công PCF8574 tại địa chỉ 0x%02X!\n", pcfAddr);
      for (int i = 0; i < 8; i++) {
        pcf.pinMode(i, OUTPUT);
        pcf.digitalWrite(i, HIGH); // Mặc định tắt (Active-Low)
      }
    } else {
      pcfFound = false;
      Serial.println("[HARDWARE] ⚠️ Không tìm thấy hoặc không khởi tạo được PCF8574!");
    }
    unlockI2C();
  }
}

static void recoverI2CBusInternal() {
  Serial.println("[HARDWARE] 🔄 Tiến hành khôi phục I2C Bus Recovery (9 xung SCL clock)...");
  Wire.end();
  pinMode(21, INPUT_PULLUP);
  pinMode(22, OUTPUT);
  for (int i = 0; i < 9; i++) {
    digitalWrite(22, HIGH);
    delayMicroseconds(10);
    digitalWrite(22, LOW);
    delayMicroseconds(10);
  }
  digitalWrite(22, HIGH);

  uint8_t pcfAddr = scanAndDetectI2CDevice();
  if (pcfAddr != 0 && pcf.begin(pcfAddr, &Wire)) {
    pcfFound = true;
    activePcfAddress = pcfAddr;
    Serial.printf("[HARDWARE] ✅ Phục hồi bus I2C và tái kết nối PCF8574 tại 0x%02X thành công!\n", pcfAddr);
    for (int i = 0; i < relayCount; i++) {
      if (myRelays[i].pin <= 7) {
        pcf.pinMode(myRelays[i].pin, OUTPUT);
        pcf.digitalWrite(myRelays[i].pin, (myRelays[i].state == "1") ? LOW : HIGH);
      }
    }
  } else {
    Serial.println("[HARDWARE] ⚠️ Phục hồi bus thất bại. Sẽ thử lại ở lần thao tác kế tiếp.");
  }
}

void recoverI2CBus() {
  if (lockI2C(pdMS_TO_TICKS(1000))) {
    recoverI2CBusInternal();
    unlockI2C();
  }
}

void safeSetRelayPin(int pin, int level) {
  if (pin >= 0 && pin <= 7) {
    if (!lockI2C(pdMS_TO_TICKS(1000))) {
      Serial.println("[HARDWARE] ⚠️ Hết thời gian chờ Mutex I2C khi điều khiển relay!");
      return;
    }
    if (!pcfFound) {
      recoverI2CBusInternal();
    }
    if (pcfFound) {
      // Chống sụt áp nguồn (Brownout Protection): Nếu đóng cuộn hút rơ-le (Active-Low LOW),
      // chèn độ trễ nhỏ 50ms giữa các lần kích hoạt để triệt tiêu sốc dòng tức thời (Inrush Current)
      static unsigned long lastRelayOnTime = 0;
      if (level == LOW) {
        unsigned long now = millis();
        if (now - lastRelayOnTime < 50) {
          delay(50 - (now - lastRelayOnTime));
        }
        lastRelayOnTime = millis();
      }
      pcf.digitalWrite(pin, level);
    }
    unlockI2C();
  } else if (pin >= 8 && pin <= 33 && !(pin >= 6 && pin <= 11)) {
    // Hỗ trợ điều khiển trực tiếp GPIO trên ESP32 nếu pin > 7 (ví dụ GPIO 12, 13, 14, 15, 16, 17, 18, 19, 23, 25, 26, 27, 32, 33)
    pinMode(pin, OUTPUT);
    digitalWrite(pin, level);
    Serial.printf("[HARDWARE] ⚡ Điều khiển trực tiếp chân GPIO %d -> %s\n", pin, level == LOW ? "BẬT (LOW)" : "TẮT (HIGH)");
  }
}

bool applyRelayCommand(const String& devId, const String& targetState, const String& source, uint8_t priority) {
  if (!isConfigured || !isProvisioned) {
    Serial.println("[SECURITY] ⛔ ESP32 chưa liên kết tài khoản ZenHome! Từ chối điều khiển relay.");
    return false;
  }
  bool found = false;
  unsigned long now = millis();

  for (int i = 0; i < relayCount; i++) {
    if (myRelays[i].id == devId) {
      found = true;
      bool stateActuallyChanged = (myRelays[i].state != targetState);

      // 1. TÔN TRỌNG THAO TÁC THỦ CÔNG: Nếu lệnh phát từ Rule Engine (Priority 4), kiểm tra Holdoff
      if (priority >= 4) {
        if (now < myRelays[i].manualOverrideUntil) {
          Serial.printf("[RULE-ENGINE] ⏳ %s đang trong thời gian can thiệp thủ công (%lus còn lại). Tôn trọng lệnh người dùng!\n",
                        devId.c_str(), (myRelays[i].manualOverrideUntil - now) / 1000);
          return false;
        }
      }

      // 2. BẢO VỆ TIẾP ĐIỂM RƠ-LE: Chặn gạt quá nhanh (<800ms) chống hồ quang đánh lửa
      if (stateActuallyChanged && (now - myRelays[i].lastToggleTime < MIN_RELAY_DWELL_MS)) {
        static unsigned long lastRelayGuardLog = 0;
        if (now - lastRelayGuardLog >= 2000) {
          lastRelayGuardLog = now;
          Serial.printf("[RELAY-GUARD] 🛡️ Chặn thao tác quá nhanh trên %s (Cách lần trước %lums < %dms). Chống cháy tiếp điểm!\n",
                        devId.c_str(), now - myRelays[i].lastToggleTime, MIN_RELAY_DWELL_MS);
        }
        // Phản hồi ngay trạng thái hiện tại về MQTT để App / Server giải phóng pending, không bị treo 3.5s
        if (WiFi.status() == WL_CONNECTED && mqttClient.connected()) {
          String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
          String stateTopic = mqtt_prefix + "/" + rName + "/" + devId + "/state";
          safeMqttPublish(stateTopic.c_str(), myRelays[i].state.c_str(), true);
        }
        return false;
      }

      if (stateActuallyChanged) {
        myRelays[i].state = targetState;
        myRelays[i].lastToggleTime = now;
        myRelays[i].version++;

        // Khi người dùng (Priority <= 3) thao tác, kích hoạt Holdoff 30 phút khóa Rule Engine
        if (priority <= 3) {
          myRelays[i].manualOverrideUntil = now + MANUAL_OVERRIDE_MS;
        }

        if (targetState == "1") {
          safeSetRelayPin(myRelays[i].pin, LOW); // Active-Low BẬT
        } else {
          safeSetRelayPin(myRelays[i].pin, HIGH); // Active-Low TẮT
        }

        // Cập nhật bộ đếm lùi tự ngắt (Micro Rule Engine)
        updateRelayCountdownTimer(devId, targetState);

        // Chớp đèn LED trạng thái phản hồi thị giác tức thì
        triggerLedActionBlip();

        // Thông báo trạng thái mới tới App điện thoại qua BLE ngầm nếu đang kết nối
        notifyBleRelayState(devId, targetState);
      }

      // KIỂM TRA MẠNG & PHẢN HỒI XÁC NHẬN (ACK) TỚI MQTT BROKER:
      bool isNetworkOnline = (WiFi.status() == WL_CONNECTED && mqttClient.connected());

      if (isNetworkOnline) {
        // Luôn gửi xác nhận trạng thái thực tế về MQTT để giải phóng pending trên App/Server
        String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
        String stateTopic = mqtt_prefix + "/" + rName + "/" + devId + "/state";
        safeMqttPublish(stateTopic.c_str(), myRelays[i].state.c_str(), true);
        String cleanP = mqtt_prefix;
        cleanP.replace(":", "");
        String stateTopic2 = cleanP + "/" + rName + "/" + devId + "/state";
        if (stateTopic2 != stateTopic) {
          safeMqttPublish(stateTopic2.c_str(), myRelays[i].state.c_str(), true);
        }
      } else {
        if (stateActuallyChanged) {
          needsBackupToFlash = true;
          lastRelayStateChangeAt = millis();
        }
      }
      break;
    }
  }
  return found;
}

void setupPhysicalSwitches() {
  if (!isConfigured || !isProvisioned) return;
  unsigned long now = millis();
  for (int i = 0; i < physicalSwitchCount; i++) {
    pinMode(physicalSwitches[i].pin, INPUT_PULLUP);
    delay(5);
    int initVal = digitalRead(physicalSwitches[i].pin);
    physicalSwitches[i].lastReading = initVal;
    physicalSwitches[i].debouncedState = initVal;
    physicalSwitches[i].lastChangeTime = now;
    physicalSwitches[i].lastToggleTime = 0;
  }
}

void checkPhysicalSwitches() {
  if (!isConfigured || !isProvisioned) return;
  unsigned long now = millis();
  static unsigned long lastSwitchScan = 0;
  if (now - lastSwitchScan < 15) return; // Chu kỳ quét 15ms (66Hz)
  lastSwitchScan = now;

  for (int i = 0; i < physicalSwitchCount; i++) {
    int reading = digitalRead(physicalSwitches[i].pin);

    if (reading != physicalSwitches[i].lastReading) {
      physicalSwitches[i].lastReading = reading;
      physicalSwitches[i].lastChangeTime = now;
    }

    if ((now - physicalSwitches[i].lastChangeTime) >= SWITCH_DEBOUNCE_MS) {
      if (reading != physicalSwitches[i].debouncedState) {
        if ((now - physicalSwitches[i].lastToggleTime) >= SWITCH_MIN_TOGGLE_INTERVAL) {
          physicalSwitches[i].debouncedState = reading;
          physicalSwitches[i].lastToggleTime = now;
          int rIdx = physicalSwitches[i].relayIndex;
          if (rIdx >= 0 && rIdx < relayCount) {
            String nextState = (myRelays[rIdx].state == "1") ? "0" : "1";
            applyRelayCommand(myRelays[rIdx].id, nextState, "physical_switch", 1);
            Serial.printf("\n[PHYSICAL-SW] ⚡ Công tắc cơ chân %d gạt -> Đổi Relay %s sang %s (Priority 1: Human Switch)\n",
                          physicalSwitches[i].pin, myRelays[rIdx].id.c_str(), nextState.c_str());
          }
        } else {
          physicalSwitches[i].debouncedState = reading;
        }
      }
    }
  }
}

void loadLocalRulesFromFlash() {
  localRuleCount = 0;
  if (!lockFlash()) return;
  if (!LittleFS.exists("/rules.json")) {
    Serial.println("[RULES] ℹ️ Chưa có file cấu hình /rules.json. Khởi tạo rỗng.");
    unlockFlash();
    return;
  }
  File f = LittleFS.open("/rules.json", "r");
  if (!f) {
    unlockFlash();
    return;
  }
  DynamicJsonDocument doc(2048);
  DeserializationError err = deserializeJson(doc, f);
  f.close();
  unlockFlash();
  if (err) {
    Serial.println("[RULES] ⚠️ Lỗi đọc /rules.json");
    return;
  }
  JsonArray arr = doc["rules"].as<JsonArray>();
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
  Serial.printf("[RULES] 📜 Đã nạp %d quy tắc tự động hóa cục bộ từ Flash LittleFS!\n", localRuleCount);
}

void saveLocalRulesToFlash() {
  if (!lockFlash()) return;
  File f = LittleFS.open("/rules.json", "w");
  if (!f) {
    unlockFlash();
    return;
  }
  DynamicJsonDocument doc(2048);
  JsonArray arr = doc.createNestedArray("rules");
  for (int i = 0; i < localRuleCount; i++) {
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
  }
  serializeJson(doc, f);
  f.close();
  unlockFlash();
  Serial.printf("[RULES] 💾 Đã lưu %d quy tắc tự động hóa vào Flash LittleFS!\n", localRuleCount);
}

void evaluateLocalRules(float currentTemp) {
  if (!isConfigured || !isProvisioned || localRuleCount == 0) return;
  unsigned long now = millis();

  for (int i = 0; i < localRuleCount; i++) {
    if (!localRules[i].enabled) continue;

    // 1. QUY TẮC NHIỆT ĐỘ TỰ ĐỘNG
    if (strcmp(localRules[i].type, "temp_auto") == 0 && !isnan(currentTemp)) {
      const float HYSTERESIS = 0.4f; // Trễ nhiệt 0.4°C chống đóng ngắt relay liên tục quanh ngưỡng
      bool conditionMet = false;
      if (strcmp(localRules[i].tempCond, ">=") == 0) {
        conditionMet = (currentTemp >= (localRules[i].triggerTemp + HYSTERESIS));
      } else if (strcmp(localRules[i].tempCond, "<=") == 0) {
        conditionMet = (currentTemp <= (localRules[i].triggerTemp - HYSTERESIS));
      }

      if (conditionMet) {
        if (now - localRules[i].lastTriggerTime >= 60000) { // Chu kỳ kích hoạt cách nhau tối thiểu 60s
          String target(localRules[i].actionState);
          String devId(localRules[i].targetDevId);
          for (int r = 0; r < relayCount; r++) {
            if (myRelays[r].id == devId) {
              if (myRelays[r].state != target) {
                Serial.printf("\n[MICRO-RULES] 🌡️ Quy tắc nhiệt độ '%s' khớp (%.1f°C %s %.1f°C)! Chuyển %s sang %s (Priority 4)\n",
                              localRules[i].id, currentTemp, localRules[i].tempCond, localRules[i].triggerTemp, devId.c_str(), target.c_str());
                applyRelayCommand(devId, target, "rule_engine", 4);
                localRules[i].lastTriggerTime = now;
              }
              break;
            }
          }
        }
      }
    }

    // 2. QUY TẮC ĐẾM LÙI TỰ NGẮT (COUNTDOWN AUTO-OFF)
    if (strcmp(localRules[i].type, "countdown") == 0 && localRules[i].isCountingDown) {
      uint32_t elapsedSec = (now - localRules[i].turnOnTime) / 1000;
      if (elapsedSec >= localRules[i].autoOffSec) {
        localRules[i].isCountingDown = false;
        String devId(localRules[i].targetDevId);
        Serial.printf("\n[MICRO-RULES] ⏱️ Quy tắc đếm lùi '%s' hết giờ (%us)! Tự động TẮT %s (Priority 4)\n",
                      localRules[i].id, localRules[i].autoOffSec, devId.c_str());
        applyRelayCommand(devId, "0", "countdown_timer", 4);
      }
    }
  }
}

void updateRelayCountdownTimer(const String& devId, const String& targetState) {
  unsigned long now = millis();
  for (int i = 0; i < localRuleCount; i++) {
    if (localRules[i].enabled && strcmp(localRules[i].type, "countdown") == 0) {
      if (devId.equals(localRules[i].targetDevId)) {
        if (targetState == "1") {
          localRules[i].turnOnTime = now;
          localRules[i].isCountingDown = true;
          Serial.printf("[MICRO-RULES] ⏳ Bắt đầu đếm lùi tự ngắt cho %s: %u giây\n", devId.c_str(), localRules[i].autoOffSec);
        } else {
          localRules[i].isCountingDown = false;
        }
      }
    }
  }
}

void readSensors() {
  float h = dht.readHumidity();
  float t = dht.readTemperature();
  if (!isnan(t) && !isnan(h) && t > -40.0 && t < 85.0 && h >= 0.0 && h <= 100.0) {
    cachedTemperature = t;
    cachedHumidity = h;
  }
}
