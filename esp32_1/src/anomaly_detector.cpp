#include "anomaly_detector.h"
#include "hardware_manager.h"
#include "config_manager.h"
#include "mqtt_manager.h"
#include <ArduinoJson.h>
#include <WiFi.h>

static RelayAnomalyRecord anomalyTable[MAX_ANOMALY_TRACKED_RELAYS];

void initAnomalyDetector() {
  memset(anomalyTable, 0, sizeof(anomalyTable));
}

static RelayAnomalyRecord* getOrAssignRecord(const String& devId, int pin) {
  for (int i = 0; i < MAX_ANOMALY_TRACKED_RELAYS; i++) {
    if (anomalyTable[i].devId[0] != '\0' && devId.equals(anomalyTable[i].devId)) {
      return &anomalyTable[i];
    }
  }
  for (int i = 0; i < MAX_ANOMALY_TRACKED_RELAYS; i++) {
    if (anomalyTable[i].devId[0] == '\0') {
      strncpy(anomalyTable[i].devId, devId.c_str(), sizeof(anomalyTable[i].devId) - 1);
      anomalyTable[i].devId[sizeof(anomalyTable[i].devId) - 1] = '\0';
      anomalyTable[i].pin = pin;
      anomalyTable[i].toggleCount = 0;
      anomalyTable[i].lockedUntil = 0;
      anomalyTable[i].isLocked = false;
      return &anomalyTable[i];
    }
  }
  return nullptr;
}

bool isRelayLockedByAnomaly(const String& devId, unsigned long* remainingMs) {
  unsigned long now = millis();
  for (int i = 0; i < MAX_ANOMALY_TRACKED_RELAYS; i++) {
    if (anomalyTable[i].devId[0] != '\0' && devId.equals(anomalyTable[i].devId)) {
      if (anomalyTable[i].isLocked) {
        if (now < anomalyTable[i].lockedUntil) {
          if (remainingMs) *remainingMs = anomalyTable[i].lockedUntil - now;
          return true;
        } else {
          // Hết hạn khóa an toàn
          anomalyTable[i].isLocked = false;
          anomalyTable[i].toggleCount = 0;
          Serial.printf("[ANOMALY-DETECTOR] 🔓 Hết thời hạn khóa 30s: Rơ-le %s được mở khóa hoạt động bình thường.\n", devId.c_str());
          return false;
        }
      }
      return false;
    }
  }
  return false;
}

bool isPinLockedByAnomaly(int pin, unsigned long* remainingMs) {
  unsigned long now = millis();
  for (int i = 0; i < MAX_ANOMALY_TRACKED_RELAYS; i++) {
    if (anomalyTable[i].devId[0] != '\0' && anomalyTable[i].pin == pin) {
      if (anomalyTable[i].isLocked) {
        if (now < anomalyTable[i].lockedUntil) {
          if (remainingMs) *remainingMs = anomalyTable[i].lockedUntil - now;
          return true;
        } else {
          anomalyTable[i].isLocked = false;
          anomalyTable[i].toggleCount = 0;
          return false;
        }
      }
      return false;
    }
  }
  return false;
}

void triggerEmergencySafeOff(const String& devId, int pin) {
  // 1. Lập tức cưỡng bức ngắt rơ-le về SAFE OFF (Active-Low HIGH)
  safeSetRelayPin(pin, HIGH);

  // 2. Cập nhật trạng thái an toàn trong bộ nhớ myRelays
  String roomName = "living_room";
  for (int i = 0; i < relayCount; i++) {
    if (myRelays[i].id == devId) {
      myRelays[i].state = "0";
      myRelays[i].lastToggleTime = millis();
      if (myRelays[i].room.length() > 0) roomName = myRelays[i].room;
      break;
    }
  }

  // 3. Chuyển LED cảnh báo lỗi
  setLedPattern(LED_PATTERN_AP_MODE);

  // 4. Phát tín hiệu khẩn cấp lên MQTT Cloud
  if (WiFi.status() == WL_CONNECTED && mqttClient.connected()) {
    String anomalyTopic = mqtt_prefix + "/system/anomaly";
    StaticJsonDocument<384> doc;
    doc["type"] = "RELAY_CHATTERING_ANOMALY";
    doc["devId"] = devId;
    doc["pin"] = pin;
    doc["action"] = "LOCKED_OFF";
    doc["lockoutSec"] = 30;
    doc["message"] = "Phát hiện đóng ngắt bất thường liên tục (>6 lần/2s), đã ngắt khẩn cấp và khóa an toàn 30 giây!";

    String payload;
    serializeJson(doc, payload);
    safeMqttPublish(anomalyTopic.c_str(), payload.c_str(), false);

    // Đồng bộ lại trạng thái tắt về topic state của thiết bị
    String stateTopic = mqtt_prefix + "/" + roomName + "/" + devId + "/state";
    safeMqttPublish(stateTopic.c_str(), "0", true);
  }

  Serial.printf("\n[ANOMALY-DETECTOR] 🚨 NGUY HIỂM: Phát hiện rơ-le %s (Pin %d) đóng ngắt bất thường liên tục (>6 lần/2s)! Đã ngắt khẩn cấp về SAFE OFF và khóa an toàn 30 giây.\n",
                devId.c_str(), pin);
}

bool checkAndRecordRelayToggle(const String& devId, int pin) {
  RelayAnomalyRecord* rec = getOrAssignRecord(devId, pin);
  if (!rec) return false;

  unsigned long now = millis();

  // Nếu đang trong thời gian bị khóa, từ chối mọi thao tác
  if (rec->isLocked) {
    if (now < rec->lockedUntil) {
      return true;
    } else {
      rec->isLocked = false;
      rec->toggleCount = 0;
    }
  }

  // Đẩy thời điểm toggle vào hàng đợi sliding window
  // Dịch chuyển các phần tử cũ
  const int maxSamples = MAX_TOGGLES_IN_WINDOW + 2;
  for (int i = maxSamples - 1; i > 0; i--) {
    rec->toggleTimestamps[i] = rec->toggleTimestamps[i - 1];
  }
  rec->toggleTimestamps[0] = now;
  if (rec->toggleCount < maxSamples) {
    rec->toggleCount++;
  }

  // Đếm số lần toggle trong cửa sổ 2 giây (CHATTERING_WINDOW_MS)
  int togglesInWindow = 0;
  for (int i = 0; i < rec->toggleCount; i++) {
    if (now - rec->toggleTimestamps[i] <= CHATTERING_WINDOW_MS) {
      togglesInWindow++;
    }
  }

  // Nếu vượt quá 6 lần trong 2 giây -> Kích hoạt Anomaly!
  if (togglesInWindow > MAX_TOGGLES_IN_WINDOW) {
    rec->isLocked = true;
    rec->lockedUntil = now + ANOMALY_LOCKOUT_MS;
    triggerEmergencySafeOff(devId, pin);
    return true;
  }

  return false;
}
