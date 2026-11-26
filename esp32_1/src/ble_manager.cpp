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

BleClientSlot bleSlots[BLE_MAX_CLIENTS]{};

bool hasAnyBleClient() {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].occupied) return true;
  }
  return false;
}

static BleClientSlot* getBleSlot(uint16_t handle) {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].occupied && bleSlots[i].connHandle == handle) return &bleSlots[i];
  }
  return nullptr;
}

static void addBleSlot(uint16_t handle) {
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (bleSlots[i].occupied && bleSlots[i].connHandle == handle) {
      bleSlots[i].lastActivity = millis();
      return;
    }
  }
  for (int i = 0; i < BLE_MAX_CLIENTS; i++) {
    if (!bleSlots[i].occupied) {
      bleSlots[i].connHandle = handle;
      bleSlots[i].occupied = true;
      bleSlots[i].fragments.clear();
      bleSlots[i].partsReceived = 0;
      bleSlots[i].partCount = 0;
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
    if (bleSlots[i].occupied && bleSlots[i].connHandle == handle) {
      bleSlots[i].occupied = false;
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
      if (bleSlots[i].occupied) {
        if (!bleSlots[i].isAuthenticated && (currentMillis - bleSlots[i].connectedAt >= 8000)) {
          Serial.printf("\n[BLE-SECURITY] ⚠️ Handle %d không xác thực Key trong 8s! Ngắt kết nối nhường slot...\n", bleSlots[i].connHandle);
          pBleServer->disconnect(bleSlots[i].connHandle);
          bleSlots[i].occupied = false;
        } else if (bleSlots[i].isAuthenticated && (currentMillis - bleSlots[i].lastActivity >= 15000)) {
          Serial.printf("\n[BLE-MULTIUSER] ⏱️ Handle %d rảnh rỗi quá 15s! Tự ngắt để giải phóng slot cho máy khác...\n", bleSlots[i].connHandle);
          pBleServer->disconnect(bleSlots[i].connHandle);
          bleSlots[i].occupied = false;
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
      if (bleSlots[i].occupied && pBleServer) {
        Serial.printf("\n[BLE] 🔌 Wi-Fi Router đã phục hồi -> Ngắt kết nối Client Handle %d...\n", bleSlots[i].connHandle);
        pBleServer->disconnect(bleSlots[i].connHandle);
        bleSlots[i].occupied = false;
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

static void notifyBleClient(uint16_t handle, const String& message) {
  if (!pBleStatusChar) return;
  os_mbuf* buffer = ble_hs_mbuf_from_flat(message.c_str(), message.length());
  if (buffer) ble_gattc_notify_custom(handle, pBleStatusChar->getHandle(), buffer);
}

void notifyBleRelayState(const String& devId, const String& state) {
  if (isBleEnabled && pBleStatusChar && hasAnyBleClient()) {
    StaticJsonDocument<128> doc;
    doc["id"] = devId;
    doc["state"] = state;
    doc["uptime"] = millis() / 1000;
    String out;
    serializeJson(doc, out);
    for (const auto& slot : bleSlots) {
      if (slot.occupied && slot.isAuthenticated) notifyBleClient(slot.connHandle, out);
    }
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
  void onWrite(NimBLECharacteristic* characteristic, ble_gap_conn_desc* peer) override {
    if (!peer || !isConfigured || !isProvisioned || currentLocalSecretKey.isEmpty()) return;
    auto* slot = getBleSlot(peer->conn_handle);
    if (!slot || isBleSlotRateLimited(slot)) return;
    slot->lastActivity = millis();

    std::string raw = characteristic->getValue();
    if (raw.size() >= 4 && raw[0] == 0x5a && raw[1] == 0x48) {
      uint8_t index = raw[2], total = raw[3];
      if (!slot->isAuthenticated || !total || total > 12 || raw.size() > 304) return;
      if (index == 0) {
        slot->fragments.clear();
        slot->partsReceived = 0;
        slot->partCount = total;
      }
      if (slot->partCount != total || index != slot->partsReceived ||
          slot->fragments.size() + raw.size() - 4 > 3072) return;
      slot->fragments.append(raw, 4, std::string::npos);
      if (++slot->partsReceived < total) return;
      raw.swap(slot->fragments);
      slot->fragments.clear();
      slot->partCount = 0;
    }
    DynamicJsonDocument packet(4096);
    if (raw.empty() || deserializeJson(packet, raw)) return;
    if (packet.containsKey("enc")) {
      String envelope = packet["enc"] | "";
      if (!envelope.startsWith("ZHENC1:")) return;
      String plain = decryptEnvelopeWithKeyHex(envelope, currentLocalSecretKey);
      if (plain.isEmpty() || deserializeJson(packet, plain)) return;
    }
    String action = packet["action"] | "";
    String user = packet["user"] | "";
    String ts = packet["ts"].as<String>();
    String nonce = packet["nonce"] | "";
    String sig = packet["sig"] | "";
    String cmd = packet["cmd"] | "";
    String id = packet["id"] | "";
    String data = packet["data"] | "";
    String mac = WiFi.macAddress();
    mac.replace(":", "");
    mac.toUpperCase();
    String fields;
    if (action == "auth") fields = "auth:" + mac + ":" + user + ":" + ts + ":" + nonce;
    else if (action == "reconfig") fields = signedLocalPayload(action, user, data, ts, nonce);
    else if (cmd == "reboot") fields = "reboot:" + ts + ":" + nonce;
    else if (id.length() && (cmd == "0" || cmd == "1")) fields = user + ":" + id + ":" + cmd + ":" + ts + ":" + nonce;
    else return;

    StaticJsonDocument<512> response;
    response["nonce"] = nonce;
    if (!id.isEmpty()) response["id"] = id;
    if (!isLocalOwner(user) || isTimestampExpired(ts) ||
        !verifyHmacSha256(currentLocalSecretKey, fields, sig) || isInvalidLocalNonce(nonce)) {
      response["status"] = action == "auth" ? "auth_failed" : "cmd_failed";
      response["error"] = "unauthorized";
      if (++slot->failedAuthAttempts >= 3) { pBleServer->disconnect(slot->connHandle); return; }
    } else if (action == "auth") {
      slot->isAuthenticated = true;
      slot->failedAuthAttempts = 0;
      isBleAuthenticated = true;
      softSyncClockFromApp(ts.toInt());
      response["status"] = "auth_ok";
      response["authenticated"] = true;
      response["mac"] = mac;
      response["proof"] = computeHmacSha256(currentLocalSecretKey, "hub-auth:" + mac + ":" + user + ":" + ts + ":" + nonce);
    } else if (!slot->isAuthenticated) {
      response["status"] = "cmd_failed";
      response["error"] = "unauthenticated";
    } else if (action == "reconfig") {
      DynamicJsonDocument config(1024);
      if (deserializeJson(config, data) || !config["wifi_ssid"].is<const char*>()) {
        response["status"] = "cmd_failed";
      } else {
        pendingReconfig.mqttUser = config["mqtt_user"] | "";
        pendingReconfig.mqttPass = config["mqtt_pass"] | "";
        pendingReconfig.ssid = config["wifi_ssid"].as<String>();
        pendingReconfig.pass = config["wifi_pass"] | "";
        pendingReconfig.mqttServer = config["mqtt_server"] | "";
        pendingReconfig.adminPass = config["admin_pass"] | "";
        pendingReconfig.requested = true;
        response["status"] = "reconfig_ok";
      }
    } else if (cmd == "reboot") {
      shouldReboot = true;
      rebootScheduledAt = millis();
      response["status"] = "ok";
    } else if (applyRelayCommand(id, cmd, "ble", 2)) {
      response["status"] = "ok";
      response["state"] = cmd;
      response["proof"] = computeHmacSha256(currentLocalSecretKey, "ack:" + user + ":" + id + ":" + cmd + ":" + nonce);
    } else {
      response["status"] = "cmd_failed";
    }
    if (action != "auth") {
      String status = response["status"] | "";
      String state = response["state"] | "";
      response["proof"] = computeHmacSha256(currentLocalSecretKey, "ble-ack:" + user + ":" + nonce + ":" + status + ":" + id + ":" + state);
    }
    String reply;
    serializeJson(response, reply);
    notifyBleClient(peer->conn_handle, reply);
  }
};

void setupBLE() {
  String mac = WiFi.macAddress();
  String cleanMac = mac;
  cleanMac.replace(":", "");
  String devName = "ZenHome_" + cleanMac.substring(8);

  NimBLEDevice::init(devName.c_str());
  NimBLEDevice::setPower(ESP_PWR_LVL_P9); // Công suất phát +9dBm
  // [ZH-HIGH-04] Cấu hình BLE Security: Secure Connections, Bonding, MITM Protection
  NimBLEDevice::setSecurityAuth(true, false, true);
  NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);
  NimBLEDevice::setSecurityInitKey(BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID);
  NimBLEDevice::setSecurityRespKey(BLE_SM_PAIR_KEY_DIST_ENC | BLE_SM_PAIR_KEY_DIST_ID);
  NimBLEDevice::setMTU(512);

  pBleServer = NimBLEDevice::createServer();
  pBleServer->setCallbacks(new BleServerCallbacks());

  NimBLEService* pService = pBleServer->createService(ZENHOME_BLE_SERVICE_UUID);

  pBleControlChar = pService->createCharacteristic(
    ZENHOME_BLE_CHAR_CONTROL_UUID,
    NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR | NIMBLE_PROPERTY::WRITE_ENC
  );
  pBleControlChar->setCallbacks(new BleControlCallbacks());

  pBleStatusChar = pService->createCharacteristic(
    ZENHOME_BLE_CHAR_STATUS_UUID,
    NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY | NIMBLE_PROPERTY::READ_ENC
  );

  String hello = "{\"bootNonce\":\"" + localBootNonce() + "\"}";
  pBleStatusChar->setValue(hello.c_str());
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
