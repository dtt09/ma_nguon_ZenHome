#include "hardware_manager.h"
#include "config_manager.h"
#include "ble_manager.h"
#include "mqtt_manager.h"
#include <WiFi.h>

Adafruit_PCF8574 pcf;
bool pcfFound = false;
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

void initHardware() {
  pinMode(RESET_BTN_PIN, INPUT_PULLUP);
  pinMode(STATUS_LED_PIN, OUTPUT);
  digitalWrite(STATUS_LED_PIN, LOW);

  dht.begin();

  Wire.begin();
  Wire.setTimeOut(50); // Timeout 50ms chống treo bus I2C khi lỏng cáp hoặc nhiễu xung
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
}

void safeSetRelayPin(int pin, int level) {
  if (pcfFound && pin >= 0 && pin <= 7) {
    pcf.digitalWrite(pin, level);
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

        // Thông báo trạng thái mới tới App điện thoại qua BLE ngầm nếu đang kết nối
        notifyBleRelayState(devId, targetState);
      }

      // KIỂM TRA MẠNG & CHỐNG SPAM MQTT BROKER:
      bool isNetworkOnline = (WiFi.status() == WL_CONNECTED && mqttClient.connected());

      if (isNetworkOnline) {
        if (stateActuallyChanged) {
          String rName = myRelays[i].room.length() > 0 ? myRelays[i].room : "living_room";
          String stateTopic = mqtt_prefix + "/" + rName + "/" + devId + "/state";
          mqttClient.publish(stateTopic.c_str(), targetState.c_str(), true);
          String cleanP = mqtt_prefix;
          cleanP.replace(":", "");
          String stateTopic2 = cleanP + "/" + rName + "/" + devId + "/state";
          if (stateTopic2 != stateTopic) {
            mqttClient.publish(stateTopic2.c_str(), targetState.c_str(), true);
          }
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
      bool conditionMet = false;
      if (strcmp(localRules[i].tempCond, ">=") == 0) {
        conditionMet = (currentTemp >= localRules[i].triggerTemp);
      } else if (strcmp(localRules[i].tempCond, "<=") == 0) {
        conditionMet = (currentTemp <= localRules[i].triggerTemp);
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
