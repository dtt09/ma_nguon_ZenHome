#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <LittleFS.h>
#include <ArduinoJson.h>

#define FIRMWARE_VERSION "2.5.7 (Build 201)"
#define MAX_RELAYS 16
#define MIN_RELAY_DWELL_MS 800                // Thời gian trễ tối thiểu 800ms giữa 2 lần đổi trạng thái
#define MANUAL_OVERRIDE_MS (30 * 60 * 1000UL) // Khóa tự động hóa 30 phút khi người dùng can thiệp thủ công
#define SETUP_PHASE_TIMEOUT_MS 180000UL       // 180 giây (3 phút) tổng timeout setup ban đầu
#define SETUP_WIFI_TIMEOUT_MS   60000UL       // 60 giây timeout nếu không kết nối được WiFi lần đầu
#define SETUP_MQTT_TIMEOUT_MS   60000UL       // 60 giây timeout nếu có WiFi nhưng không kết nối được MQTT Cloud lần đầu

struct RelayDev {
  String id;
  String room;
  int pin;
  String state; // "0" hoặc "1"
  uint32_t version;
  unsigned long lastToggleTime;
  unsigned long manualOverrideUntil;
};

struct PendingReconfig {
  bool requested;
  String ssid;
  String pass;
  String mqttServer;
  String adminPass;
};

// Global variables declarations
extern RelayDev myRelays[MAX_RELAYS];
extern int relayCount;

extern bool isConfigured;
extern bool isProvisioned;
extern bool isSetupPending;
extern unsigned long setupPhaseStartTime;
extern bool isPowerOutageBoot;
extern bool hasOfflineBackup;
extern bool needsBackupToFlash;
extern unsigned long lastRelayStateChangeAt;

extern bool shouldReboot;
extern unsigned long rebootScheduledAt;

extern PendingReconfig pendingReconfig;

extern String wifi_ssid;
extern String wifi_pass;
extern String mqtt_prefix;
extern String mqtt_server;
extern String mqtt_user;
extern String mqtt_pass;
extern String admin_pass;
extern String server_url;

extern const char* const HIVEMQ_ROOT_CA PROGMEM;
extern SemaphoreHandle_t flashMutex;

// Flash Mutex Helpers
bool lockFlash(TickType_t waitTicks = pdMS_TO_TICKS(2000));
void unlockFlash();
void initFlashMutex();

// Configuration & State Functions
bool loadConfig();
void backupRelayStatesToFlash();
void loadOfflineBackupFromFlash();
void resetToFactoryDefaults();
