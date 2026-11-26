import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Ngoại lệ ném ra khi phong bì mã hóa không đúng định dạng an toàn hoặc bị giả mạo
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Bộ tiện ích mã hóa AES-256 đối xứng có xác thực toàn vẹn (Authenticated Encryption)
/// Thiết lập đường hầm bảo mật thông tin (Confidentiality & Integrity) cho các kênh LAN & BLE
/// Tương thích 100% với hàm decryptStorageString trên vi điều khiển ESP32
class ZenHomeCrypto {
  static String sign(String keyHex, String message) =>
      Hmac(sha256, _hexToBytes(keyHex)).convert(utf8.encode(message)).toString();

  static String digest(String message) => sha256.convert(utf8.encode(message)).toString();

  static bool matches(String expected, Object? received) {
    if (received is! String || received.length != expected.length || expected.isEmpty) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= expected.codeUnitAt(i) ^ received.codeUnitAt(i);
    }
    return difference == 0;
  }

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
    if (envelope.isEmpty || keyHex.isEmpty) return null;
    // SEC-FIX [ZH-CRIT-05]: Xóa bỏ hoàn toàn fallback plaintext. Bắt buộc ném SecurityException nếu thiếu tiền tố ZHENC1:
    if (!envelope.startsWith('ZHENC1:')) {
      throw SecurityException('Invalid encrypted payload format: Missing ZHENC1 prefix');
    }
    final parts = envelope.split(':');
    if (parts.length != 4) return null;

    final ivHex = parts[1];
    final cipherHex = parts[2];
    final receivedTag = parts[3];

    final keyBytes = _hexToBytes(keyHex);
    final payloadToAuth = '$ivHex:$cipherHex';
    final expectedTag = Hmac(sha256, keyBytes).convert(utf8.encode(payloadToAuth)).toString();

    // SEC-FIX [ZH-CRIT-05]: So khớp chữ ký xác thực bằng thuật toán Constant-Time chống Side-Channel Timing Attack
    if (!constantTimeEquals(receivedTag.toLowerCase(), expectedTag.toLowerCase())) {
      return null; // Giả mạo hoặc sai khóa
    }

    final key = enc.Key(keyBytes);
    final iv = enc.IV(_hexToBytes(ivHex));
    final cipherBytes = _hexToBytes(cipherHex);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.ctr, padding: null));
    return encrypter.decrypt(enc.Encrypted(cipherBytes), iv: iv);
  }

  /// So sánh hai chuỗi ký tự với thời gian hằng số (Constant-Time Equality) chống tấn công Timing Attack
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
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
