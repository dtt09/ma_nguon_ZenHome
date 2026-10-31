#include "ble_manager.h"
#include "config_manager.h"
#include "security_manager.h"
#include "hardware_manager.h"
#include <WiFi.h>

NimBLEServer* pBleServer = nullptr;
NimBLECharacteristic* pBleControlChar = nullptr;
NimBLECharacteristic* pBleStatusChar = nullptr;
bool isBleClientConnected = false;
bool isBleEnabled = false;
uint16_t currentBleConnHandle = 0;
bool isBleAuthenticated = false;
unsigned long bleConnectedAt = 0;
int bleFailedAuthAttempts = 0;

BleClientSlot bleSlots[BLE_MAX_CLIENTS] = {0};

bool hasAnyBleClient() {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].connHandle != 0) return true;
  }
  return false;
}

static BleClientSlot* getBleSlot(uint16_t handle) {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].connHandle == handle) return &bleSlots[i];
  }
  return nullptr;
}

static void addBleSlot(uint16_t handle) {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].connHandle == handle) {
      bleSlots[i].lastActivity = millis();
      return;
    }
  }
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].connHandle == 0) {
      bleSlots[i].connHandle = handle;
      bleSlots[i].isAuthenticated = false;
      bleSlots[i].connectedAt = millis();
      bleSlots[i].lastActivity = millis();
      bleSlots[i].failedAuthAttempts = 0;
      bleSlots[i].tokens = 12.0f;
      bleSlots[i].lastRefillMs = millis();
      bleSlots[i].cooldownUntil = 0;
      return;
    }
  }
}

static void removeBleSlot(uint16_t handle) {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].connHandle == handle) {
      bleSlots[i].connHandle = 0;
      bleSlots[i].isAuthenticated = false;
      bleSlots[i].connectedAt = 0;
      bleSlots[i].lastActivity = 0;
      bleSlots[i].failedAuthAttempts = 0;
      bleSlots[i].tokens = 0;
      bleSlots[i].lastRefillMs = 0;
      bleSlots[i].cooldownUntil = 0;
      return;
    }
  }
}

static bool isBleSlotRateLimited(BleClientSlot* slot) {
  if (!slot) return false;
  unsigned long nowMs = millis();
  if (slot->cooldownUntil > nowMs) {
    return true;
  }
  unsigned long elapsedMs = nowMs - slot->lastRefillMs;
  slot->lastRefillMs = nowMs;
  slot->tokens += (elapsedMs / 1000.0f) * 6.0f;
  if (slot->tokens > 12.0f) slot->tokens = 12.0f;

  if (slot->tokens >= 1.0f) {
    slot->tokens -= 1.0f;
    return false;
  }
  slot->cooldownUntil = nowMs + 3000;
  Serial.printf("[BLE-TOKEN-BUCKET] ⚠️ Slot Handle %d cạn kiệt Token! Khóa tạm thời 3s.\n", slot->connHandle);
  return true;
}

void checkBleSlotTimeouts() {
  if (isBleEnabled && pBleServer) {
    unsigned long currentMillis = millis();
    for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
      if (bleSlots[i].connHandle != 0) {
        if (!bleSlots[i].isAuthenticated && (currentMillis - bleSlots[i].connectedAt >= 8000)) {
          Serial.printf("\n[BLE-SECURITY] ⚠️ Handle %d không xác thực Key trong 8s! Ngắt kết nối nhường slot...\n", bleSlots[i].connHandle);
          pBleServer->disconnect(bleSlots[i].connHandle);
          bleSlots[i].connHandle = 0;
        } else if (bleSlots[i].isAuthenticated && (currentMillis - bleSlots[i].lastActivity >= 4000)) {
          Serial.printf("\n[BLE-MULTIUSER] ⏱️ Handle %d rảnh rỗi quá 4s! Tự ngắt để giải phóng slot cho máy khác...\n", bleSlots[i].connHandle);
          pBleServer->disconnect(bleSlots[i].connHandle);
          bleSlots[i].connHandle = 0;
        }
      }
    }
    isBleClientConnected = hasAnyBleClient();
  }
}

void setBleActive(bool active) {
  if (active == isBleEnabled) return;
  isBleEnabled = active;
  
  if (isBleEnabled) {
    if (NimBLEDevice::getAdvertising()) {
      NimBLEDevice::startAdvertising();
      Serial.println("\n[BLE] 🚀 [KÍCH HOẠT] Phát hiện MẤT KẾT NỐI Wi-Fi Router -> BẬT BLE Zero-Touch (3 Slots Hàng Đợi)!");
    }
  } else {
    for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
      if (bleSlots[i].connHandle != 0 && pBleServer) {
        Serial.printf("\n[BLE] 🔌 Wi-Fi Router đã phục hồi -> Ngắt kết nối Client Handle %d...\n", bleSlots[i].connHandle);
        pBleServer->disconnect(bleSlots[i].connHandle);
        bleSlots[i].connHandle = 0;
      }
    }
    isBleClientConnected = false;
    isBleAuthenticated = false;
    currentBleConnHandle = 0;
    if (NimBLEDevice::getAdvertising()) {
      NimBLEDevice::stopAdvertising();
    }
    Serial.println("\n[BLE] 💤 [VÔ HIỆU HÓA] Wi-Fi Router đang hoạt động -> TẮT BLE (Tối ưu RAM & triệt tiêu xung đột RF 2.4GHz)!");
  }
}

void notifyBleRelayState(const String& devId, const String& state) {
  if (isBleEnabled && pBleStatusChar && hasAnyBleClient()) {
    StaticJsonDocument<128> doc;
    doc["id"] = devId;
    doc["state"] = state;
    doc["uptime"] = millis() / 1000;
    String out;
    serializeJson(doc, out);
    pBleStatusChar->setValue(out.c_str());
    pBleStatusChar->notify();
  }
}

class BleServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* pServer, ble_gap_conn_desc* desc) override {
    uint16_t h = desc ? desc->conn_handle : 0;
    addBleSlot(h);
    isBleClientConnected = true;
    currentBleConnHandle = h;
    Serial.printf("[BLE] 📲 Client kết nối Slot Handle %d (Đang dùng: %d/3)\n", h, (int)pServer->getConnectedCount());

    if (pServer->getConnectedCount() < BLE_MAX_CLIENTS && WiFi.status() != WL_CONNECTED && isBleEnabled) {
      NimBLEDevice::startAdvertising();
    }
  }
  void onDisconnect(NimBLEServer* pServer, ble_gap_conn_desc* desc) override {
    uint16_t h = desc ? desc->conn_handle : 0;
    removeBleSlot(h);
    isBleClientConnected = hasAnyBleClient();
    Serial.printf("[BLE] 📴 Client ngắt Slot Handle %d (Còn lại: %d/3)\n", h, (int)pServer->getConnectedCount());

    if (WiFi.status() != WL_CONNECTED && isBleEnabled) {
      NimBLEDevice::startAdvertising();
    }
  }
};

class BleControlCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* pChar, ble_gap_conn_desc* desc) override {
    uint16_t connHandle = desc ? desc->conn_handle : 0;
    BleClientSlot* slot = connHandle != 0 ? getBleSlot(connHandle) : nullptr;
    
    if (slot) {
      slot->lastActivity = millis();
      if (isBleSlotRateLimited(slot)) {
        return;
      }
    }

    std::string rxVal = pChar->getValue();
    if (rxVal.empty()) return;

    String payload = String(rxVal.c_str());
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, payload);
    if (err) {
      return;
    }

    if (doc.containsKey("enc")) {
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
      if (decryptedJson.length() == 0) {
        Serial.printf("[BLE-CONTROL] ❌ Lỗi giải mã phong bì bảo mật từ Handle %d!\n", connHandle);
        return;
      }
      DeserializationError encErr = deserializeJson(doc, decryptedJson);
      if (encErr) {
        Serial.printf("[BLE-CONTROL] ❌ Lỗi parse JSON giải mã từ Handle %d!\n", connHandle);
        return;
      }
      Serial.printf("[BLE-CONTROL] 🔐 [AES-256 Confidential] Đã giải mã thành công gói tin bảo mật từ Handle %d!\n", connHandle);
    }

    if (!isConfigured || !isProvisioned) {
      Serial.println("[BLE] ⛔ ESP32 chưa liên kết tài khoản ZenHome! Từ chối thao tác.");
      return;
    }

    // Lệnh Reboot thủ công qua BLE
    if (doc.containsKey("cmd") && doc["cmd"] == "reboot") {
      if (doc.containsKey("sig") && doc.containsKey("ts") && doc.containsKey("nonce")) {
        String ts = doc["ts"].as<String>();
        String nonce = doc["nonce"].as<String>();
        String sig = doc["sig"].as<String>();
        String expectedSig = computeHmacSha256(currentLocalSecretKey, "reboot:" + ts + ":" + nonce);
        if (sig.equalsIgnoreCase(expectedSig)) {
          Serial.println("\n[BLE] 🔄 Nhận lệnh Reboot thủ công từ App qua BLE (Chữ ký hợp lệ)! Khởi động lại sau 1.5s...");
          rebootScheduledAt = millis();
          shouldReboot = true;
          return;
        }
      }
    }

    // Lệnh Reconfig Wi-Fi qua BLE
    if (doc.containsKey("action") && doc["action"] == "reconfig") {
      if (!doc.containsKey("wifi_ssid") || !doc.containsKey("sig") || !doc.containsKey("ts") || !doc.containsKey("nonce")) {
        Serial.println("[BLE-RECONFIG] ⛔ Gói tin thiếu tham số cấu hình!");
        return;
      }

      String newSsid = doc["wifi_ssid"].as<String>();
      String newPass = doc.containsKey("wifi_pass") ? doc["wifi_pass"].as<String>() : "";
      String sig = doc["sig"].as<String>();
      String ts = doc["ts"].as<String>();
      String nonce = doc["nonce"].as<String>();
      String user = doc.containsKey("user") ? doc["user"].as<String>() : "owner";

      if (isNonceReplayedOrInvalid(nonce) || isTimestampExpired(ts)) {
        Serial.println("[BLE-RECONFIG] ⛔ Gói tin quá hạn hoặc Replay Attack!");
        return;
      }

      String signPayload = "reconfig:" + newSsid + ":" + ts + ":" + nonce;
      String expectedSig = computeHmacSha256(currentLocalSecretKey, signPayload);
      bool authOk = sig.equalsIgnoreCase(expectedSig);

      if (!authOk && admin_pass.length() > 0) {
        String mac = WiFi.macAddress();
        mac.replace(":", "");
        mac.toUpperCase();
        String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
        authOk = sig.equalsIgnoreCase(computeHmacSha256(masterKey, signPayload));
      }

      if (!authOk) {
        Serial.println("[BLE-RECONFIG] ❌ Chữ ký bảo mật không hợp lệ cho lệnh đổi Wi-Fi!");
        return;
      }

      if (!isUserAuthorizedForDevice(user, "*")) {
        Serial.printf("[BLE-RECONFIG] 🚫 User '%s' không có quyền quản trị để đổi Wi-Fi Hub!\n", user.c_str());
        return;
      }

      pendingReconfig.ssid = newSsid;
      pendingReconfig.pass = newPass;
      pendingReconfig.mqttServer = doc.containsKey("mqtt_server") ? doc["mqtt_server"].as<String>() : "";
      pendingReconfig.adminPass = doc.containsKey("admin_pass") ? doc["admin_pass"].as<String>() : "";
      pendingReconfig.requested = true;

      Serial.println("[BLE-RECONFIG] 📡 Đã tiếp nhận cấu hình Wi-Fi mới qua BLE! Đang ủy thác ghi Flash lên Core 1...");
      if (pBleStatusChar) {
        StaticJsonDocument<128> res;
        res["status"] = "reconfig_ok";
        res["message"] = "Rebooting into new WiFi";
        String out;
        serializeJson(res, out);
        pBleStatusChar->setValue(out.c_str());
        pBleStatusChar->notify();
      }
      return;
    }

    // 1. Xác thực Key khi vừa kết nối (AUTH HANDSHAKE)
    if (doc.containsKey("action") && doc["action"] == "auth") {
      if (!doc.containsKey("ts") || !doc.containsKey("nonce") || !doc.containsKey("sig")) {
        Serial.println("[BLE-AUTH] ⛔ Gói tin Auth thiếu tham số chữ ký Key!");
        return;
      }
      String ts = doc["ts"].as<String>();
      String nonce = doc["nonce"].as<String>();
      String sig = doc["sig"].as<String>();

      if (isNonceReplayedOrInvalid(nonce)) {
        Serial.println("[BLE-AUTH] ⛔ Phát hiện Replay Attack hoặc Nonce không hợp lệ!");
        return;
      }
      if (isTimestampExpired(ts)) {
        Serial.println("[BLE-AUTH] ⛔ Gói tin Auth đã hết hạn thời gian!");
        return;
      }

      String mac = WiFi.macAddress();
      mac.replace(":", "");
      mac.toUpperCase();

      String expectedAuthPayload = "auth:" + mac + ":" + ts + ":" + nonce;
      String expectedSig = computeHmacSha256(currentLocalSecretKey, expectedAuthPayload);

      bool authOk = sig.equalsIgnoreCase(expectedSig);
      if (!authOk && admin_pass.length() > 0) {
        String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
        String expectedMasterSig = computeHmacSha256(masterKey, expectedAuthPayload);
        if (sig.equalsIgnoreCase(expectedMasterSig)) {
          authOk = true;
          currentLocalSecretKey = masterKey;
          pendingSecretKeyToSave = masterKey;
          Serial.println("[BLE-AUTH] 🔄 Đã đồng bộ currentLocalSecretKey theo Master Key của App!");
        }
      }

      if (authOk) {
        if (slot) {
          slot->isAuthenticated = true;
          slot->failedAuthAttempts = 0;
          slot->lastActivity = millis();
        }
        isBleAuthenticated = true;
        Serial.printf("[BLE-AUTH] 🔐 Xác thực Key kết nối Bluetooth thành công (Handle: %d)! Cho phép giao tiếp.\n", connHandle);

        if (pBleStatusChar) {
          StaticJsonDocument<128> res;
          res["status"] = "auth_ok";
          res["authenticated"] = true;
          res["mac"] = mac;
          String out;
          serializeJson(res, out);
          pBleStatusChar->setValue(out.c_str());
          pBleStatusChar->notify();
        }
      } else {
        if (slot) slot->failedAuthAttempts++;
        int fails = slot ? slot->failedAuthAttempts : 1;
        Serial.printf("[BLE-AUTH] ❌ Xác thực Key thất bại (Handle: %d)! (Lần %d/3)\n", connHandle, fails);
        if (fails >= 3 && pBleServer && connHandle != 0) {
          Serial.printf("[BLE-AUTH] ⛔ Handle %d quá 3 lần sai Key! Chủ động ngắt kết nối BLE...\n", connHandle);
          pBleServer->disconnect(connHandle);
        }
      }
      return;
    }

    // 2. Lệnh điều khiển thiết bị
    if (doc.containsKey("id") && doc.containsKey("cmd")) {
      String devId = doc["id"].as<String>();
      String cmd = doc["cmd"].as<String>();
      String user = doc.containsKey("user") ? doc["user"].as<String>() : "";

      if (!doc.containsKey("sig") || !doc.containsKey("ts") || !doc.containsKey("nonce")) {
        Serial.println("[BLE-CONTROL] ⛔ TỪ CHỐI LỆNH: Bắt buộc phải có chữ ký xác thực Key!");
        return;
      }

      String sig = doc["sig"].as<String>();
      String ts = doc["ts"].as<String>();
      String nonce = doc["nonce"].as<String>();

      if (isNonceReplayedOrInvalid(nonce)) {
        Serial.println("[BLE-CONTROL] ⛔ Phát hiện Replay Attack hoặc Nonce không hợp lệ!");
        return;
      }
      if (isTimestampExpired(ts)) {
        Serial.println("[BLE-CONTROL] ⛔ Gói tin BLE đã hết hạn thời gian!");
        return;
      }

      String signPayload = (user.length() > 0) ? (user + ":" + devId + ":" + cmd + ":" + ts + ":" + nonce) : (devId + ":" + cmd + ":" + ts + ":" + nonce);
      String expectedSig = computeHmacSha256(currentLocalSecretKey, signPayload);
      bool cmdSigOk = sig.equalsIgnoreCase(expectedSig);

      if (!cmdSigOk && user.length() > 0) {
        String legacyPayload = devId + ":" + cmd + ":" + ts + ":" + nonce;
        if (sig.equalsIgnoreCase(computeHmacSha256(currentLocalSecretKey, legacyPayload))) {
          cmdSigOk = true;
        }
      }

      if (!cmdSigOk && admin_pass.length() > 0) {
        String mac = WiFi.macAddress();
        mac.replace(":", "");
        mac.toUpperCase();
        String masterKey = computeSha256OfText("ZenHome_Key_Salt:" + admin_pass + ":" + mac);
        if (sig.equalsIgnoreCase(computeHmacSha256(masterKey, signPayload))) {
          cmdSigOk = true;
          currentLocalSecretKey = masterKey;
          pendingSecretKeyToSave = masterKey;
        } else if (user.length() > 0 && sig.equalsIgnoreCase(computeHmacSha256(masterKey, devId + ":" + cmd + ":" + ts + ":" + nonce))) {
          cmdSigOk = true;
          currentLocalSecretKey = masterKey;
          pendingSecretKeyToSave = masterKey;
        }
      }

      if (!cmdSigOk) {
        Serial.printf("[BLE-CONTROL] ⛔ Chữ ký Key HMAC-SHA256 không hợp lệ (Handle: %d)! Từ chối điều khiển.\n", connHandle);
        if (slot) slot->failedAuthAttempts++;
        int fails = slot ? slot->failedAuthAttempts : 1;
        if (fails >= 3 && pBleServer && connHandle != 0) {
          pBleServer->disconnect(connHandle);
        }
        return;
      }

      if (ts.length() > 0) {
        softSyncClockFromApp(ts.toInt());
      }

      if (!isUserAuthorizedForDevice(user, devId)) {
        Serial.printf("[BLE-CONTROL] 🚫 [RBAC] Người dùng '%s' không có thẩm quyền điều khiển '%s' (Handle: %d)!\n", user.c_str(), devId.c_str(), connHandle);
        if (pBleStatusChar) {
          StaticJsonDocument<128> res;
          res["id"] = devId;
          res["status"] = "forbidden";
          res["user"] = user;
          String out;
          serializeJson(res, out);
          pBleStatusChar->setValue(out.c_str());
          pBleStatusChar->notify();
        }
        return;
      }

      if (slot) {
        slot->isAuthenticated = true;
        slot->failedAuthAttempts = 0;
        slot->lastActivity = millis();
      }
      isBleAuthenticated = true;
      bool ok = applyRelayCommand(devId, cmd, "ble", 2);
      if (ok) {
        Serial.printf("[BLE-CONTROL] ⚡ [Key & RBAC OK] User '%s' đổi trạng thái %s -> %s (Handle: %d)\n", 
                      user.length() > 0 ? user.c_str() : "owner", devId.c_str(), cmd.c_str(), connHandle);
        if (pBleStatusChar) {
          StaticJsonDocument<128> res;
          res["id"] = devId;
          res["state"] = cmd;
          res["status"] = "ok";
          String out;
          serializeJson(res, out);
          pBleStatusChar->setValue(out.c_str());
          pBleStatusChar->notify();
        }
      }
      return;
    }
  }
};

void setupBLE() {
  String mac = WiFi.macAddress();
  String cleanMac = mac;
  cleanMac.replace(":", "");
  String devName = "ZenHome_" + cleanMac.substring(8);

  NimBLEDevice::init(devName.c_str());
  NimBLEDevice::setPower(ESP_PWR_LVL_P9); // Công suất phát +9dBm
  NimBLEDevice::setSecurityAuth(false, false, false);

  pBleServer = NimBLEDevice::createServer();
  pBleServer->setCallbacks(new BleServerCallbacks());

  NimBLEService* pService = pBleServer->createService(ZENHOME_BLE_SERVICE_UUID);

  pBleControlChar = pService->createCharacteristic(
    ZENHOME_BLE_CHAR_CONTROL_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
  );
  pBleControlChar->setCallbacks(new BleControlCallbacks());

  pBleStatusChar = pService->createCharacteristic(
    ZENHOME_BLE_CHAR_STATUS_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
  );

  pService->start();

  NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(ZENHOME_BLE_SERVICE_UUID);

  uint8_t macBytes[6];
  WiFi.macAddress(macBytes);
  std::string mfgData;
  mfgData.push_back(0xFF);
  mfgData.push_back(0xFF);
  for (int i = 0; i < 6; i++) mfgData.push_back(macBytes[i]);
  pAdvertising->setManufacturerData(mfgData);

  pAdvertising->setScanResponse(true);

  if (WiFi.status() != WL_CONNECTED) {
    isBleEnabled = true;
    pAdvertising->start();
    Serial.println("[BLE] 🚀 Khởi chạy BLE ở trạng thái KÍCH HOẠT (Do chưa có kết nối Wi-Fi Router). Tên: " + devName);
  } else {
    isBleEnabled = false;
    pAdvertising->stop();
    Serial.println("[BLE] 💤 Wi-Fi Router ĐÃ KẾT NỐI -> VÔ HIỆU HÓA BLE ĐỂ TIẾT KIỆM TÀI NGUYÊN (Tên: " + devName + ")");
  }
}
