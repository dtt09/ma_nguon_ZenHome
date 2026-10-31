#pragma once

#include <Arduino.h>
#include <NimBLEDevice.h>

#define ZENHOME_BLE_SERVICE_UUID        "19b10000-e8f2-537e-4f6c-d104768a1214"
#define ZENHOME_BLE_CHAR_CONTROL_UUID   "19b10001-e8f2-537e-4f6c-d104768a1214"
#define ZENHOME_BLE_CHAR_STATUS_UUID    "19b10002-e8f2-537e-4f6c-d104768a1214"
#define BLE_MAX_CLIENTS 3

struct BleClientSlot {
  uint16_t connHandle;
  bool isAuthenticated;
  unsigned long connectedAt;
  unsigned long lastActivity;
  int failedAuthAttempts;
  float tokens;
  unsigned long lastRefillMs;
  unsigned long cooldownUntil;
};

// Global variables declarations
extern NimBLEServer* pBleServer;
extern NimBLECharacteristic* pBleControlChar;
extern NimBLECharacteristic* pBleStatusChar;
extern bool isBleClientConnected;
extern bool isBleEnabled;
extern uint16_t currentBleConnHandle;
extern bool isBleAuthenticated;
extern unsigned long bleConnectedAt;
extern int bleFailedAuthAttempts;
extern BleClientSlot bleSlots[BLE_MAX_CLIENTS];

// Functions
void setupBLE();
void setBleActive(bool active);
bool hasAnyBleClient();
void notifyBleRelayState(const String& devId, const String& state);
void checkBleSlotTimeouts();
