import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:zenhome_app/core/services/logger_service.dart';

enum DeviceRiskLevel {
  secure,
  medium,
  critical,
}

class DeviceIntegrityReport {
  final bool isJailbroken;
  final bool isEmulator;
  final bool isDebugMode;
  final DeviceRiskLevel riskLevel;
  final List<String> detectedThreats;

  const DeviceIntegrityReport({
    required this.isJailbroken,
    required this.isEmulator,
    required this.isDebugMode,
    required this.riskLevel,
    required this.detectedThreats,
  });

  bool get isSafeForCriticalOperations => riskLevel != DeviceRiskLevel.critical;
}

/// Dịch vụ kiểm tra tính toàn vẹn và mức độ an toàn của thiết bị (Mobile RASP)
class DeviceSecurityService {
  /// Đánh giá toàn diện các chỉ số an ninh môi trường thực thi của thiết bị
  static Future<DeviceIntegrityReport> evaluateDeviceIntegrity() async {
    final threats = <String>[];
    bool isJailbroken = false;
    bool isEmulator = false;
    final isDebugMode = kDebugMode;

    if (isDebugMode) {
      threats.add('Ứng dụng đang chạy trong chế độ Debug');
    }

    // 1. Kiểm tra Root / Jailbreak
    try {
      isJailbroken = await JailbreakRootDetection.instance.isJailBroken;
      if (isJailbroken) {
        threats.add('Phát hiện thiết bị đã bị Root / Jailbreak');
      }
    } catch (_) {}

    // 2. Kiểm tra thiết bị giả lập (Emulator / Simulator)
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        isEmulator = !androidInfo.isPhysicalDevice;
        if (isEmulator) {
          threats.add('Ứng dụng đang chạy trên máy ảo Android (Emulator)');
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        isEmulator = !iosInfo.isPhysicalDevice;
        if (isEmulator) {
          threats.add('Ứng dụng đang chạy trên máy ảo iOS (Simulator)');
        }
      }
    } catch (_) {}

    // 3. Phân loại cấp độ rủi ro (Risk Level)
    DeviceRiskLevel level = DeviceRiskLevel.secure;
    if (isJailbroken) {
      level = DeviceRiskLevel.critical;
    } else if (isEmulator || isDebugMode) {
      level = DeviceRiskLevel.medium;
    }

    final report = DeviceIntegrityReport(
      isJailbroken: isJailbroken,
      isEmulator: isEmulator,
      isDebugMode: isDebugMode,
      riskLevel: level,
      detectedThreats: threats,
    );

    if (level == DeviceRiskLevel.critical) {
      LoggerService.w('[RASP] 🚨 CẢNH BÁO BẢO MẬT: Môi trường thiết bị có nguy cơ cao: ${threats.join(", ")}');
    }

    return report;
  }
}
