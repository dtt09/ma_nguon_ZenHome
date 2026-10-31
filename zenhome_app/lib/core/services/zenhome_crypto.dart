import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Bộ tiện ích mã hóa AES-256 đối xứng có xác thực toàn vẹn (Authenticated Encryption)
/// Thiết lập đường hầm bảo mật thông tin (Confidentiality & Integrity) cho các kênh LAN & BLE
/// Tương thích 100% với hàm decryptStorageString trên vi điều khiển ESP32
class ZenHomeCrypto {
  /// Mã hóa payload thành phong bì an toàn: `ZHENC1:<ivHex>:<cipherHex>:<hmacTag>`
  static String encryptPayload({required String plaintext, required String keyHex}) {
    if (plaintext.isEmpty || keyHex.isEmpty) return '';
    final keyBytes = _hexToBytes(keyHex);
    final key = enc.Key(keyBytes);

    // Sinh 16 byte IV ngẫu nhiên bảo mật bằng TRNG
    final random = Random.secure();
    final ivBytes = Uint8List.fromList(List<int>.generate(16, (_) => random.nextInt(256)));
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final ivHex = _bytesToHex(ivBytes);
    final cipherHex = encrypted.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    // Tính toán HMAC-SHA256 trên (IV + Ciphertext) để bảo vệ tính toàn vẹn (Tamper-Proof)
    final payloadToAuth = '$ivHex:$cipherHex';
    final tag = Hmac(sha256, keyBytes).convert(utf8.encode(payloadToAuth)).toString();

    return 'ZHENC1:$payloadToAuth:$tag';
  }

  /// Giải mã phong bì an toàn: `ZHENC1:<ivHex>:<cipherHex>:<hmacTag>`
  static String? decryptPayload({required String envelope, required String keyHex}) {
    if (!envelope.startsWith('ZHENC1:')) return envelope; // Fallback plaintext
    final parts = envelope.split(':');
    if (parts.length != 4) return null;

    final ivHex = parts[1];
    final cipherHex = parts[2];
    final receivedTag = parts[3];

    final keyBytes = _hexToBytes(keyHex);
    final payloadToAuth = '$ivHex:$cipherHex';
    final expectedTag = Hmac(sha256, keyBytes).convert(utf8.encode(payloadToAuth)).toString();

    // So khớp chữ ký xác thực
    if (receivedTag.toLowerCase() != expectedTag.toLowerCase()) {
      return null; // Giả mạo hoặc sai khóa
    }

    final key = enc.Key(keyBytes);
    final iv = enc.IV(_hexToBytes(ivHex));
    final cipherBytes = _hexToBytes(cipherHex);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
