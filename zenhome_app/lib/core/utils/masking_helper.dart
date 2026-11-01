/// Bộ công cụ che giấu và bảo vệ thông tin nhạy cảm của người dùng (Data Masking)
class MaskingHelper {
  /// Che giấu địa chỉ Email: ví dụ 'dinhtien@gmail.com' -> 'd***n@gmail.com'
  static String maskEmail(String? email) {
    if (email == null || email.trim().isEmpty) return '';
    final trimmed = email.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 1) return trimmed;

    final name = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex);

    if (name.length <= 2) {
      return '${name[0]}*$domain';
    }
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}$domain';
  }

  /// Che giấu số điện thoại: ví dụ '0912345678' -> '09****5678'
  static String maskPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';
    final trimmed = phone.trim();
    if (trimmed.length <= 6) return trimmed;
    final prefix = trimmed.substring(0, 2);
    final suffix = trimmed.substring(trimmed.length - 4);
    return '$prefix****$suffix';
  }

  /// Che giấu địa chỉ MAC của Hub ESP32: ví dụ 'AA:BB:CC:DD:EE:FF' -> 'AA:BB:CC:**:**:FF'
  static String maskMac(String? mac) {
    if (mac == null || mac.trim().isEmpty || mac == 'unknown_mac' || mac == 'unknown') {
      return 'Chưa liên kết';
    }
    final trimmed = mac.trim();
    final parts = trimmed.split(':');
    if (parts.length == 6) {
      return '${parts[0]}:${parts[1]}:${parts[2]}:**:**:${parts[5]}';
    }
    if (trimmed.length >= 8) {
      return '${trimmed.substring(0, 4)}****${trimmed.substring(trimmed.length - 2)}';
    }
    return trimmed;
  }

  /// Che giấu địa chỉ IP: ví dụ '192.168.1.45' -> '192.168.1.***'
  static String maskIp(String? ip) {
    if (ip == null || ip.trim().isEmpty) return '';
    final trimmed = ip.trim();
    final parts = trimmed.split('.');
    if (parts.length == 4) {
      return '${parts[0]}.${parts[1]}.${parts[2]}.***';
    }
    return trimmed;
  }

  /// Che giấu mật khẩu quản trị Hub: ví dụ '123456' -> '••••••'
  static String maskPassword(String? pass) {
    if (pass == null || pass.isEmpty) return '••••••';
    return '•' * pass.length.clamp(6, 12);
  }

  /// Che giấu chuỗi token hoặc khóa bí mật
  static String maskSecret(String? secret) {
    if (secret == null || secret.isEmpty) return '';
    if (secret.length <= 8) return '****';
    return '${secret.substring(0, 4)}...${secret.substring(secret.length - 4)}';
  }
}
