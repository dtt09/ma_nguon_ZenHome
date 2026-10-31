#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <ESPAsyncWebServer.h>

#define UDP_DISCOVERY_PORT 4210

extern AsyncWebServer server;
extern WiFiUDP udpDiscovery;
extern bool isWebServerStarted;
extern bool isUdpStarted;
extern unsigned long lastWiFiRetry;

void setupAPMode();
void connectToWiFi();
void syncTime();
void setupStationWebServer();
void setupUdpDiscovery();
void checkUdpDiscovery();
void checkWiFiConnection();
