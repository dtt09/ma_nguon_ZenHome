#include "security_manager.h"
#include "config_manager.h"
#include "mqtt_manager.h"

#include <mbedtls/bignum.h>
#include <mbedtls/md.h>
#include <mbedtls/sha256.h>
#include <mbedtls/aes.h>
#include <mbedtls/pk.h>
#include "firmware_signer_pubkey.h"
#include <WiFi.h>

const char* DH_PRIME_1536 = 
  "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"
  "29024E088A67CC74020BBEA63B139B22514A08798E3404DD"
  "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"
  "E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
  "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE65381"
  "FFFFFFFFFFFFFFFF";

const char* DH_GENERATOR = "2";

String currentLocalSecretKey = "";
String pendingSecretKeyToSave = "";
std::vector<MemberRule> cachedMembers;
String cachedOwner = "";

static uint32_t recentNonceHashCache[NONCE_CACHE_SIZE] = {0};
static int nonceCacheIndex = 0;
static ClientTokenBucket clientRateLimits[RATE_LIMIT_CLIENTS] = {0};

uint8_t hexNibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return 0;
}

void bytesToHex(const uint8_t* in, size_t len, char* out) {
  static const char hexChars[] = "0123456789abcdef";
  for (size_t i = 0; i < len; i++) {
    out[i * 2]     = hexChars[(in[i] >> 4) & 0x0F];
    out[i * 2 + 1] = hexChars[in[i] & 0x0F];
  }
  out[len * 2] = '\0';
}

inline uint32_t fnv1a_32(const char* str) {
  uint32_t hash = 2166136261u;
  while (*str) {
    hash ^= (uint8_t)(*str++);
    hash *= 16777619u;
  }
  return hash;
}

String dhModPow(const String& baseHex, const String& expHex, const String& modHex) {
  mbedtls_mpi base, exp, mod, result;
  mbedtls_mpi_init(&base);
  mbedtls_mpi_init(&exp);
  mbedtls_mpi_init(&mod);
  mbedtls_mpi_init(&result);

  mbedtls_mpi_read_string(&base, 16, baseHex.c_str());
  mbedtls_mpi_read_string(&exp, 16, expHex.c_str());
  mbedtls_mpi_read_string(&mod, 16, modHex.c_str());

  mbedtls_mpi_exp_mod(&result, &base, &exp, &mod, NULL);

  char buf[512];
  size_t olen = 0;
  mbedtls_mpi_write_string(&result, 16, buf, sizeof(buf), &olen);

  mbedtls_mpi_free(&base);
  mbedtls_mpi_free(&exp);
  mbedtls_mpi_free(&mod);
  mbedtls_mpi_free(&result);

  return String(buf);
}

String computeSha256Hex(const String& inputHex) {
  size_t len = inputHex.length() / 2;
  if (len == 0) return "";

  uint8_t stackBuf[128];
  uint8_t* bytes = (len <= sizeof(stackBuf)) ? stackBuf : (uint8_t*)malloc(len);
  if (!bytes) return "";

  const char* inStr = inputHex.c_str();
  for (size_t i = 0; i < len; i++) {
    bytes[i] = (hexNibble(inStr[i * 2]) << 4) | hexNibble(inStr[i * 2 + 1]);
  }

  uint8_t output[32];
  const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md(md_info, bytes, len, output);
  if (bytes != stackBuf) free(bytes);

  char outHex[65];
  bytesToHex(output, 32, outHex);
  return String(outHex);
}

String computeSha256OfText(const String& text) {
  if (text.length() == 0) return "";
  uint8_t output[32];
  const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md(md_info, (const unsigned char*)text.c_str(), text.length(), output);
  char outHex[65];
  bytesToHex(output, 32, outHex);
  return String(outHex);
}

String computeHmacSha256(const String& keyHex, const String& message) {
  size_t keyLen = keyHex.length() / 2;
  if (keyLen == 0) return "";

  uint8_t keyBytes[64];
  if (keyLen > sizeof(keyBytes)) keyLen = sizeof(keyBytes);

  const char* kStr = keyHex.c_str();
  for (size_t i = 0; i < keyLen; i++) {
    keyBytes[i] = (hexNibble(kStr[i * 2]) << 4) | hexNibble(kStr[i * 2 + 1]);
  }

  uint8_t output[32];
  const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md_hmac(md_info, keyBytes, keyLen, (const unsigned char*)message.c_str(), message.length(), output);

  char outHex[65];
  bytesToHex(output, 32, outHex);
  return String(outHex);
}

bool constantTimeCompare(const String& a, const String& b) {
  if (a.length() != b.length()) return false;
  unsigned char result = 0;
  for (size_t i = 0; i < a.length(); i++) {
    result |= (a[i] ^ b[i]);
  }
  return result == 0;
}

bool verifyHmacSha256(const String& keyHex, const String& message, const String& sig) {
  if (sig.length() < 32 || keyHex.length() < 32) {
    return false;
  }
  String expected = computeHmacSha256(keyHex, message);
  if (expected.length() < 32) return false;
  return sig.equalsIgnoreCase(expected);
}

bool verifyFirmwareEcdsaSignature(const uint8_t* sha256Bytes, const String& sigHex) {
  if (sigHex.length() < 64) {
    return false;
  }

  // Chuyển đổi mã hex signature thành buffer nhị phân DER
  size_t sigLen = sigHex.length() / 2;
  std::vector<uint8_t> derSig(sigLen);
  for (size_t i = 0; i < sigLen; i++) {
    derSig[i] = (hexNibble(sigHex[i * 2]) << 4) | hexNibble(sigHex[i * 2 + 1]);
  }

  mbedtls_pk_context pk;
  mbedtls_pk_init(&pk);

  int ret = mbedtls_pk_parse_public_key(&pk, (const unsigned char*)FIRMWARE_SIGNER_PUBLIC_KEY, strlen(FIRMWARE_SIGNER_PUBLIC_KEY) + 1);
  if (ret != 0) {
    Serial.printf("[SECURITY] ❌ Lỗi phân tích Public Key nhà phát triển (mbedtls: -0x%04x)\n", -ret);
    mbedtls_pk_free(&pk);
    return false;
  }

  // Xác thực băm SHA-256 với chữ ký điện tử ECDSA DER bằng khóa công khai
  ret = mbedtls_pk_verify(&pk, MBEDTLS_MD_SHA256, sha256Bytes, 32, derSig.data(), sigLen);
  mbedtls_pk_free(&pk);

  return (ret == 0);
}

void getHardwareStorageKey(uint8_t outKey[32]) {
  uint8_t macBytes[6];
  WiFi.macAddress(macBytes);
  char seed[128];
  // Khắc phục ZH-08: Tăng cường entropy bằng cách kết hợp MAC phần cứng cùng admin_pass
  if (admin_pass.length() > 0) {
    snprintf(seed, sizeof(seed), "ZenHome_Storage_Vault_Salt_2026_%02X%02X%02X%02X%02X%02X_%s",
             macBytes[0], macBytes[1], macBytes[2], macBytes[3], macBytes[4], macBytes[5], admin_pass.c_str());
  } else {
    snprintf(seed, sizeof(seed), "ZenHome_Storage_Vault_Salt_2026_%02X%02X%02X%02X%02X%02X",
             macBytes[0], macBytes[1], macBytes[2], macBytes[3], macBytes[4], macBytes[5]);
  }
  const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md(md_info, (const unsigned char*)seed, strlen(seed), outKey);
}

String encryptStorageString(const String& plaintext) {
  if (plaintext.length() == 0) return "";
  uint8_t key[32];
  getHardwareStorageKey(key);

  uint8_t iv[16];
  for (int i = 0; i < 4; i++) {
    uint32_t r = esp_random();
    memcpy(iv + i * 4, &r, 4);
  }

  size_t len = plaintext.length();
  uint8_t* cipherBuf = (uint8_t*)malloc(len);
  if (!cipherBuf) return "";

  mbedtls_aes_context aes;
  mbedtls_aes_init(&aes);
  mbedtls_aes_setkey_enc(&aes, key, 256);
  size_t nc_off = 0;
  uint8_t nonce_counter[16];
  uint8_t stream_block[16] = {0};
  memcpy(nonce_counter, iv, 16);

  mbedtls_aes_crypt_ctr(&aes, len, &nc_off, nonce_counter, stream_block,
                        (const unsigned char*)plaintext.c_str(), cipherBuf);
  mbedtls_aes_free(&aes);

  char ivHex[33];
  bytesToHex(iv, 16, ivHex);

  char* cipherHex = (char*)malloc(len * 2 + 1);
  if (!cipherHex) {
    free(cipherBuf);
    return "";
  }
  bytesToHex(cipherBuf, len, cipherHex);
  free(cipherBuf);

  char keyHexBuf[65];
  bytesToHex(key, 32, keyHexBuf);
  String keyHex = String(keyHexBuf);

  String payloadToAuth = String(ivHex) + ":" + String(cipherHex);
  String tag = computeHmacSha256(keyHex, payloadToAuth);
  String envelope = "ZHENC1:" + payloadToAuth + ":" + tag;

  free(cipherHex);
  return envelope;
}

String decryptEnvelopeWithKeyHex(const String& envelope, const String& keyHex) {
  if (envelope.length() == 0) return "";
  if (!envelope.startsWith("ZHENC1:")) {
    return envelope; // Tương thích ngược với file cũ chưa mã hóa
  }

  int firstColon = envelope.indexOf(':');
  int secondColon = envelope.indexOf(':', firstColon + 1);
  int thirdColon = envelope.indexOf(':', secondColon + 1);
  if (firstColon < 0 || secondColon < 0 || thirdColon < 0) {
    return "";
  }

  String ivHex = envelope.substring(firstColon + 1, secondColon);
  String cipherHex = envelope.substring(secondColon + 1, thirdColon);
  String receivedTag = envelope.substring(thirdColon + 1);

  if (ivHex.length() != 32 || cipherHex.length() == 0 || (cipherHex.length() % 2 != 0) || keyHex.length() != 64) {
    return "";
  }

  String payloadToAuth = ivHex + ":" + cipherHex;
  String expectedTag = computeHmacSha256(keyHex, payloadToAuth);
  if (!receivedTag.equalsIgnoreCase(expectedTag)) {
    return "";
  }

  uint8_t iv[16];
  for (int i = 0; i < 16; i++) {
    iv[i] = (hexNibble(ivHex[i * 2]) << 4) | hexNibble(ivHex[i * 2 + 1]);
  }

  uint8_t key[32];
  for (int i = 0; i < 32; i++) {
    key[i] = (hexNibble(keyHex[i * 2]) << 4) | hexNibble(keyHex[i * 2 + 1]);
  }

  size_t cipherLen = cipherHex.length() / 2;
  uint8_t* cipherBytes = (uint8_t*)malloc(cipherLen);
  if (!cipherBytes) return "";
  for (size_t i = 0; i < cipherLen; i++) {
    cipherBytes[i] = (hexNibble(cipherHex[i * 2]) << 4) | hexNibble(cipherHex[i * 2 + 1]);
  }

  uint8_t* plainBytes = (uint8_t*)malloc(cipherLen + 1);
  if (!plainBytes) {
    free(cipherBytes);
    return "";
  }

  mbedtls_aes_context aes;
  mbedtls_aes_init(&aes);
  mbedtls_aes_setkey_enc(&aes, key, 256);
  size_t nc_off = 0;
  uint8_t nonce_counter[16];
  uint8_t stream_block[16] = {0};
  memcpy(nonce_counter, iv, 16);

  mbedtls_aes_crypt_ctr(&aes, cipherLen, &nc_off, nonce_counter, stream_block, cipherBytes, plainBytes);
  mbedtls_aes_free(&aes);
  plainBytes[cipherLen] = '\0';

  String plaintext((char*)plainBytes);
  free(cipherBytes);
  free(plainBytes);
  return plaintext;
}

String decryptStorageString(const String& envelope) {
  if (envelope.length() == 0) return "";
  if (!envelope.startsWith("ZHENC1:")) {
    return envelope;
  }
  uint8_t key[32];
  getHardwareStorageKey(key);
  char keyHexBuf[65];
  bytesToHex(key, 32, keyHexBuf);
  String keyHex(keyHexBuf);
  String res = decryptEnvelopeWithKeyHex(envelope, keyHex);
  if (res.length() > 0) return res;

  // Fallback sang legacy key (trước khi có admin_pass salt) nếu cần
  if (admin_pass.length() > 0) {
    uint8_t macBytes[6];
    WiFi.macAddress(macBytes);
    char legacySeed[96];
    snprintf(legacySeed, sizeof(legacySeed), "ZenHome_Storage_Vault_Salt_2026_%02X%02X%02X%02X%02X%02X",
             macBytes[0], macBytes[1], macBytes[2], macBytes[3], macBytes[4], macBytes[5]);
    uint8_t legacyKey[32];
    const mbedtls_md_info_t *md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    mbedtls_md(md_info, (const unsigned char*)legacySeed, strlen(legacySeed), legacyKey);
    char legacyKeyHexBuf[65];
    bytesToHex(legacyKey, 32, legacyKeyHexBuf);
    return decryptEnvelopeWithKeyHex(envelope, String(legacyKeyHexBuf));
  }
  return "";
}

void saveLocalSecretKey(const String& key) {
  currentLocalSecretKey = key;
  if (!lockFlash()) return;
  File f = LittleFS.open("/local_sec_key.dat", "w");
  if (f) {
    String encrypted = encryptStorageString(key);
    f.print(encrypted);
    f.close();
    Serial.println("[LOCAL-SEC] 🔐 Đã lưu khóa bảo mật mã hóa phần cứng vào Flash LittleFS!");
  }
  unlockFlash();
}

void loadLocalSecretKey() {
  if (lockFlash()) {
    if (LittleFS.exists("/local_sec_key.dat")) {
      File f = LittleFS.open("/local_sec_key.dat", "r");
      if (f) {
        String content = f.readString();
        f.close();
        unlockFlash();
        String decrypted = decryptStorageString(content);
        decrypted.trim();
        if (decrypted.length() == 64) {
          currentLocalSecretKey = decrypted;
          Serial.println("[LOCAL-SEC] 🔐 Đã tải và giải mã thành công khóa bảo mật từ Flash LittleFS!");
          if (!content.startsWith("ZHENC1:")) {
            saveLocalSecretKey(decrypted);
          }
          return;
        }
      } else {
        unlockFlash();
      }
    } else {
      unlockFlash();
    }
  }

  String mac = WiFi.macAddress();
  mac.replace(":", "");
  mac.toUpperCase();

  String adminPass = (admin_pass.length() > 0) ? admin_pass : "admin";
  String keySeed = "ZenHome_Key_Salt:" + adminPass + ":" + mac;
  currentLocalSecretKey = computeSha256OfText(keySeed);
  saveLocalSecretKey(currentLocalSecretKey);
  Serial.println("[LOCAL-SEC] 🔐 Đã khởi tạo và mã hóa lưu khóa bảo mật đồng bộ với App: " + currentLocalSecretKey.substring(0, 8) + "...");
}

bool isNonceReplayedOrInvalid(const String& nonce) {
  if (nonce.length() < 8) return true;
  uint32_t h = fnv1a_32(nonce.c_str());
  for (int i = 0; i < NONCE_CACHE_SIZE; i++) {
    if (recentNonceHashCache[i] != 0 && recentNonceHashCache[i] == h) {
      return true; // Phát hiện Nonce trùng lặp
    }
  }
  recentNonceHashCache[nonceCacheIndex] = h;
  nonceCacheIndex = (nonceCacheIndex + 1) % NONCE_CACHE_SIZE;
  return false;
}

bool isTimestampExpired(const String& tsStr) {
  time_t now = time(nullptr);
  if (now > 1700000000) {
    long reqTs = tsStr.toInt();
    if (reqTs <= 0) return true;
    long diff = labs((long)now - reqTs);
    if (diff > 300) { // Lệch quá 300 giây (5 phút) -> Hết hạn
      return true;
    }
  }
  return false;
}

void softSyncClockFromApp(long validTs) {
  if (validTs < 1700000000) return;
  time_t now = time(nullptr);
  if (now < 1700000000 || (labs((long)now - validTs) > 30 && WiFi.status() != WL_CONNECTED)) {
    struct timeval tv;
    tv.tv_sec = validTs;
    tv.tv_usec = 0;
    settimeofday(&tv, NULL);
    Serial.printf("[RTC-SYNC] ⏰ Đã đồng bộ đồng hồ nội bộ ESP32 từ Client đã xác thực: %ld\n", validTs);
  }
}

bool isClientRateLimited(uint32_t clientIp) {
  if (clientIp == 0) return false;
  unsigned long nowMs = millis();
  int emptySlot = -1;

  for (int i = 0; i < RATE_LIMIT_CLIENTS; i++) {
    if (clientRateLimits[i].ip == clientIp) {
      if (clientRateLimits[i].cooldownUntil > nowMs) {
        return true; // Vẫn đang trong thời gian phạt Cooldown
      }

      unsigned long elapsedMs = nowMs - clientRateLimits[i].lastRefillMs;
      clientRateLimits[i].lastRefillMs = nowMs;
      clientRateLimits[i].tokens += (elapsedMs / 1000.0f) * TOKEN_BUCKET_REFILL_RATE;
      if (clientRateLimits[i].tokens > TOKEN_BUCKET_CAPACITY) {
        clientRateLimits[i].tokens = TOKEN_BUCKET_CAPACITY;
      }

      if (clientRateLimits[i].tokens >= 1.0f) {
        clientRateLimits[i].tokens -= 1.0f;
        if (clientRateLimits[i].violationCount > 0) clientRateLimits[i].violationCount--;
        return false;
      } else {
        clientRateLimits[i].violationCount++;
        if (clientRateLimits[i].violationCount >= 4) {
          clientRateLimits[i].cooldownUntil = nowMs + 4000; // Khóa phạt 4 giây
          clientRateLimits[i].violationCount = 0;
          Serial.printf("[LAN-TOKEN-BUCKET] ⚠️ IP 0x%08X cạn kiệt Token liên tiếp! Khóa phạt 4s.\n", clientIp);
        }
        return true;
      }
    }

    if (emptySlot == -1 && (clientRateLimits[i].ip == 0 || (nowMs - clientRateLimits[i].lastRefillMs > 60000))) {
      emptySlot = i;
    }
  }

  // Cấp phát slot mới
  if (emptySlot != -1) {
    clientRateLimits[emptySlot].ip = clientIp;
    clientRateLimits[emptySlot].tokens = TOKEN_BUCKET_CAPACITY - 1.0f;
    clientRateLimits[emptySlot].lastRefillMs = nowMs;
    clientRateLimits[emptySlot].cooldownUntil = 0;
    clientRateLimits[emptySlot].violationCount = 0;
    return false;
  }
  return false;
}

void triggerIntrusionTrap(AsyncWebServerRequest *request, const char* trapName) {
  uint32_t clientIp = (uint32_t)request->client()->remoteIP();
  String ipStr = request->client()->remoteIP().toString();
  Serial.printf("[INTRUSION-TRAP] 🚨 PHÁT HIỆN DÒ QUÉT XÂM NHẬP! IP: %s gõ vào Honey-Token '%s'\n", ipStr.c_str(), trapName);

  unsigned long nowMs = millis();
  for (int i = 0; i < RATE_LIMIT_CLIENTS; i++) {
    if (clientRateLimits[i].ip == clientIp) {
      clientRateLimits[i].cooldownUntil = nowMs + 86400000UL; // Khóa 24 giờ
      clientRateLimits[i].tokens = 0;
      break;
    }
  }

  if (mqttClient.connected()) {
    String alertTopic = mqtt_prefix + "/security/alert";
    StaticJsonDocument<256> alertDoc;
    alertDoc["type"] = "INTRUSION_DETECTED";
    alertDoc["attackerIp"] = ipStr;
    alertDoc["trap"] = trapName;
    alertDoc["timestamp"] = time(nullptr);
    alertDoc["action"] = "IP_BLOCKED_24H";
    String alertMsg;
    serializeJson(alertDoc, alertMsg);
    safeMqttPublish(alertTopic.c_str(), alertMsg.c_str(), true);
  }

  request->send(403, "application/json", "{\"status\":\"error\",\"code\":\"ACCESS_DENIED\",\"message\":\"Intrusion detected. Your IP has been blacklisted.\"}");
}

void parseMembersJson(const String& jsonStr) {
  DynamicJsonDocument doc(1536);
  DeserializationError err = deserializeJson(doc, jsonStr);
  if (err) {
    Serial.println("[RBAC] ⚠️ Lỗi phân tích cú pháp JSON danh sách thành viên!");
    return;
  }
  cachedMembers.clear();
  if (doc.containsKey("owner")) {
    cachedOwner = doc["owner"].as<String>();
  } else if (mqtt_prefix.indexOf('/') > 0) {
    cachedOwner = mqtt_prefix.substring(0, mqtt_prefix.indexOf('/'));
  }

  JsonArray arr = doc["members"].as<JsonArray>();
  for (JsonObject mObj : arr) {
    MemberRule m;
    m.user = mObj["user"] | "";
    m.role = mObj["role"] | "member";
    m.disabled = mObj["disabled"] | false;
    JsonArray devArr = mObj.containsKey("allowedDevices") ? mObj["allowedDevices"].as<JsonArray>() : mObj["allowed"].as<JsonArray>();
    if (!devArr.isNull()) {
      for (JsonVariant d : devArr) {
        m.allowedDevices.push_back(d.as<String>());
      }
    }
    if (m.user.length() > 0) {
      cachedMembers.push_back(m);
    }
  }
  Serial.printf("[RBAC] 👥 Đã đồng bộ RBAC: Chủ nhà = %s, %d thành viên phụ.\n", 
                cachedOwner.c_str(), (int)cachedMembers.size());
}

static String lastSavedMembersJson = "";

void saveMembersToFlash(const String& jsonStr) {
  if (jsonStr.length() == 0) return;
  if (lastSavedMembersJson.length() > 0 && lastSavedMembersJson == jsonStr) {
    Serial.println("[FLASH] ⏭️ Phân quyền thành viên không thay đổi, bỏ qua ghi Flash LittleFS để bảo vệ tuổi thọ chip!");
    return;
  }
  if (!lockFlash()) return;
  File f = LittleFS.open("/members.json", "w");
  if (f) {
    String encrypted = encryptStorageString(jsonStr);
    f.print(encrypted);
    f.close();
    lastSavedMembersJson = jsonStr;
    Serial.println("[FLASH] 💾 Đã lưu cấu hình phân quyền /members.json (Mã hóa phần cứng) vào Flash!");
  } else {
    Serial.println("[FLASH] ❌ Lỗi mở file /members.json để ghi!");
  }
  unlockFlash();
}

void loadMembersFromFlash() {
  if (lockFlash()) {
    if (LittleFS.exists("/members.json")) {
      File f = LittleFS.open("/members.json", "r");
      if (f) {
        String content = f.readString();
        f.close();
        unlockFlash();
        if (content.length() > 0) {
          String decrypted = decryptStorageString(content);
          if (decrypted.length() > 0) {
            parseMembersJson(decrypted);
            lastSavedMembersJson = decrypted;
            if (!content.startsWith("ZHENC1:")) {
              saveMembersToFlash(decrypted);
            }
            return;
          }
        }
      } else {
        unlockFlash();
      }
    } else {
      unlockFlash();
    }
  }

  if (mqtt_prefix.indexOf('/') > 0) {
    cachedOwner = mqtt_prefix.substring(0, mqtt_prefix.indexOf('/'));
    Serial.printf("[RBAC] ℹ️ Chưa có /members.json, thiết lập Owner mặc định: %s\n", cachedOwner.c_str());
  }
}

bool isUserAuthorizedForDevice(const String& user, const String& devId) {
  // 1. Kiểm tra danh tính Chủ sở hữu thật sự (khớp với cachedOwner hoặc prefix tài khoản)
  if (cachedOwner.length() > 0 && user.equalsIgnoreCase(cachedOwner)) {
    return true;
  }
  if (mqtt_prefix.indexOf('/') > 0) {
    String owner = mqtt_prefix.substring(0, mqtt_prefix.indexOf('/'));
    if (owner.length() > 0 && user.equalsIgnoreCase(owner)) {
      return true;
    }
  }

  // Chế độ tương thích ngược: Cho phép lệnh khuyết danh (user rỗng) chỉ khi nhà chưa cấu hình thành viên nào
  if (cachedMembers.empty() && user.length() == 0) {
    return true;
  }

  // 2. Chặn các chuỗi mạo danh rỗng hoặc "owner" / "admin" giả mạo
  if (user.length() == 0) {
    Serial.printf("[RBAC] ⛔ Từ chối lệnh khuyết danh tính trên thiết bị '%s'!\n", devId.c_str());
    return false;
  }
  if (user.equalsIgnoreCase("owner") || user.equalsIgnoreCase("admin")) {
    Serial.printf("[RBAC] ⛔ CẢNH BÁO BẢO MẬT: Phát hiện chuỗi mạo danh '%s' không hợp lệ!\n", user.c_str());
    return false;
  }

  if (cachedMembers.empty()) {
    Serial.printf("[RBAC] ⛔ Từ chối user '%s': Chưa có thành viên phụ nào được cấu hình!\n", user.c_str());
    return false;
  }

  for (const auto& m : cachedMembers) {
    if (m.user.equalsIgnoreCase(user)) {
      if (m.disabled) {
        Serial.printf("[RBAC] 🚫 Từ chối user '%s': Tài khoản đang bị Chủ nhà vô hiệu hóa!\n", user.c_str());
        return false;
      }
      if (m.role.equalsIgnoreCase("admin") || m.role.equalsIgnoreCase("owner")) {
        return true;
      }
      if (m.allowedDevices.empty()) {
        return true;
      }
      for (const auto& allowedId : m.allowedDevices) {
        if (allowedId == "*" || allowedId.equalsIgnoreCase(devId)) {
          return true;
        }
      }
      Serial.printf("[RBAC] 🚫 Từ chối user '%s': Không có quyền điều khiển thiết bị '%s'!\n", user.c_str(), devId.c_str());
      return false;
    }
  }

  Serial.printf("[RBAC] ⛔ Từ chối user '%s': Người dùng đã bị gỡ khỏi nhà!\n", user.c_str());
  return false;
}
