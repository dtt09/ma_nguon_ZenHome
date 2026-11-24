#pragma once

#include <Arduino.h>

#define CHATTERING_WINDOW_MS 2000
#define MAX_TOGGLES_IN_WINDOW 6
#define ANOMALY_LOCKOUT_MS 30000
#define MAX_ANOMALY_TRACKED_RELAYS 16

struct RelayAnomalyRecord {
  char devId[16];
  int pin;
  unsigned long toggleTimestamps[MAX_TOGGLES_IN_WINDOW + 4];
  uint8_t toggleCount;
  unsigned long lockedUntil;
  bool isLocked;
};

void initAnomalyDetector();
bool isRelayLockedByAnomaly(const String& devId, unsigned long* remainingMs = nullptr);
bool isPinLockedByAnomaly(int pin, unsigned long* remainingMs = nullptr);
bool checkAndRecordRelayToggle(const String& devId, int pin);
void triggerEmergencySafeOff(const String& devId, int pin);
