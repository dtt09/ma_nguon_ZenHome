#pragma once

#include <Arduino.h>
#include <vector>
#include <ESPAsyncWebServer.h>

#define NONCE_CACHE_SIZE 64
#define RATE_LIMIT_CLIENTS 8
#define TOKEN_BUCKET_CAPACITY 12.0f
#define TOKEN_BUCKET_REFILL_RATE 6.0f

struct ClientTokenBucket {
  uint32_t ip;
  float tokens;
  unsigned long lastRefillMs;
  unsigned long cooldownUntil;
  uint8_t violationCount;
};

struct MemberRule {
  String user;
  String role;
  bool disabled;
  std::vector<String> allowedDevices;
};

// Global variables declarations
extern const char* DH_PRIME_1536;
extern const char* DH_GENERATOR;
extern String currentLocalSecretKey;
extern String pendingSecretKeyToSave;
extern std::vector<MemberRule> cachedMembers;
extern String cachedOwner;

// Utility Conversions
uint8_t hexNibble(char c);
void bytesToHex(const uint8_t* in, size_t len, char* out);

// Cryptographic Functions
bool constantTimeCompare(const String& a, const String& b);
String dhModPow(const String& baseHex, const String& expHex, const String& modHex);
String computeSha256Hex(const String& inputHex);
String computeSha256OfText(const String& text);
String computeHmacSha256(const String& keyHex, const String& message);
bool verifyHmacSha256(const String& keyHex, const String& message, const String& sig);
bool verifyFirmwareEcdsaSignature(const uint8_t* sha256Bytes, const String& sigHex);

// Hardware Storage at Rest Encryption
void getHardwareStorageKey(uint8_t outKey[32]);
String encryptStorageString(const String& plaintext);
String decryptStorageString(const String& envelope);
String decryptEnvelopeWithKeyHex(const String& envelope, const String& keyHex);
void saveLocalSecretKey(const String& key);
void loadLocalSecretKey();

// Security Guards (Anti-Replay, Token Bucket, Honey-Tokens)
bool isNonceReplayedOrInvalid(const String& nonce);
bool isTimestampExpired(const String& tsStr);
void softSyncClockFromApp(long validTs);
bool isClientRateLimited(uint32_t clientIp);
void triggerIntrusionTrap(AsyncWebServerRequest *request, const char* trapName);

// RBAC & Access Control
void parseMembersJson(const String& jsonStr);
void saveMembersToFlash(const String& jsonStr);
void loadMembersFromFlash();
bool isUserAuthorizedForDevice(const String& user, const String& devId);
