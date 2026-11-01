#pragma once

#include <Arduino.h>
#include <Wire.h>
#include <Adafruit_PCF8574.h>
#include <DHT.h>

#define DHTPIN 14
#define DHTTYPE DHT11
#define RESET_BTN_PIN 0
#define STATUS_LED_PIN 2
#define WDT_TIMEOUT_SECONDS 45
#define MAX_LOCAL_RULES 8

struct PhysicalSwitch {
  int pin;
  int relayIndex;
  int lastReading;
  int debouncedState;
  unsigned long lastChangeTime;
  unsigned long lastToggleTime;
};

struct LocalRule {
  bool enabled;
  char id[16];          // "rule_1", "rule_temp", v.v.
  char type[16];        // "temp_auto" hoặc "countdown"
  char targetDevId[16]; // "rel_1", "relay_0", v.v.
  float triggerTemp;
  char tempCond[4];     // ">=", "<="
  char actionState[2];  // "1" (Bật) hoặc "0" (Tắt)
  uint32_t autoOffSec;
  uint32_t turnOnTime;
  bool isCountingDown;
  unsigned long lastTriggerTime;
};

// Global variables declarations
extern Adafruit_PCF8574 pcf;
extern bool pcfFound;
extern DHT dht;

// LED Indication State Machine
enum LedStatusPattern {
  LED_PATTERN_AP_MODE,          // Chế độ AP Setup: Nháy đúp (100ms ON, 100ms OFF, 100ms ON, 700ms OFF)
  LED_PATTERN_WIFI_CONNECTING,  // Đang dò / kết nối Wi-Fi: Nháy nhanh đều (100ms ON / 100ms OFF)
  LED_PATTERN_WIFI_CONNECTED,   // Wi-Fi OK, đang kết nối MQTT: Nháy vừa (250ms ON / 250ms OFF)
  LED_PATTERN_ONLINE_ALL,       // Wi-Fi + MQTT Cloud hoàn tất: Sáng đứng (Solid ON)
  LED_PATTERN_OFFLINE_LOCAL     // Wi-Fi rớt / Offline (BLE Fallback): Nháy chậm (500ms ON / 500ms OFF)
};

void setLedPattern(LedStatusPattern pattern);
void triggerLedActionBlip();
void updateLedIndicator();

extern float cachedTemperature;
extern float cachedHumidity;
extern unsigned long lastRuleEvalTime;
extern unsigned long lastDHTRead;

extern LocalRule localRules[MAX_LOCAL_RULES];
extern int localRuleCount;

extern PhysicalSwitch physicalSwitches[];
extern const int physicalSwitchCount;

// Functions
void initHardwareMutex();
bool lockI2C(TickType_t waitTicks = pdMS_TO_TICKS(500));
void unlockI2C();
void recoverI2CBus();
void initHardware();
void safeSetRelayPin(int pin, int level);
bool applyRelayCommand(const String& devId, const String& targetState, const String& source = "manual", uint8_t priority = 2);
void setupPhysicalSwitches();
void checkPhysicalSwitches();
void loadLocalRulesFromFlash();
void saveLocalRulesToFlash();
void evaluateLocalRules(float currentTemp);
void updateRelayCountdownTimer(const String& devId, const String& targetState);
void readSensors();
