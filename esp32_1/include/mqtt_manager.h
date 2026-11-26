#pragma once

#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

extern WiFiClientSecure espClient;
extern PubSubClient mqttClient;
extern bool wasMqttPreviouslyConnected;
extern unsigned long lastMQTTRetry;
extern bool isBindingVerified;

void initMqttMutex();
bool lockMqtt(TickType_t waitTicks = pdMS_TO_TICKS(500));
void unlockMqtt();
bool safeMqttPublish(const char* topic, const char* payload, bool retained = false);

void publishRelayState(const String& stateTopic, const String& state, const String& requestNonce = "");
void initMqttClient();
bool verifyBindingWithDatabase();
void connectMQTT();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void publishHomeAssistantDiscovery();
void performServerOtaUpdate(const String& fwUrl, const String& expectedSha256, const String& signatureHex = "", int newBuild = -1);
void checkMqttConnection();
void checkSetupTimeout();
void revertToAPMode(const String& reason);
void sendSetupHandshakeBeacon();
void unlockAllFeatures();
