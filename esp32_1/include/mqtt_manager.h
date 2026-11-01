#pragma once

#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>

extern WiFiClientSecure espClient;
extern PubSubClient mqttClient;
extern bool wasMqttPreviouslyConnected;
extern unsigned long lastMQTTRetry;
extern bool isBindingVerified;

void initMqttClient();
bool verifyBindingWithDatabase();
void connectMQTT();
void mqttCallback(char* topic, byte* payload, unsigned int length);
void publishHomeAssistantDiscovery();
void performServerOtaUpdate(const String& fwUrl, const String& expectedSha256, const String& signatureHex = "");
void checkMqttConnection();
void checkSetupTimeout();
void revertToAPMode(const String& reason);
void sendSetupHandshakeBeacon();
void unlockAllFeatures();
