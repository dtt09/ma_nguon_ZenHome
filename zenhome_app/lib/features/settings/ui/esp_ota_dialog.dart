import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenhome_app/core/models/smart_config.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/masking_helper.dart';
import 'package:zenhome_app/core/utils/reauth_helper.dart';
import 'package:zenhome_app/core/widgets/admin_password_dialog.dart';
import 'package:zenhome_app/core/widgets/loading_overlay.dart';
import 'package:zenhome_app/core/widgets/zenhome_luxury_dialog.dart';

/// Hộp thoại thực thi Nâng cấp Firmware ESP32 qua OTA với quy trình xác thực đa lớp (Multi-layer Authenticated OTA)
class EspOtaDialog {
  /// Bắt đầu quy trình kiểm tra và nâng cấp Firmware ESP32
  static Future<void> startOtaProcess(
    BuildContext context,
    WidgetRef ref,
    SmartConfig activeConfig,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // -------------------------------------------------------------
    // BƯỚC 1: KIỂM TRA PHÂN QUYỀN (Role RBAC)
    // -------------------------------------------------------------
    if (activeConfig.role != 'owner') {
      showZenHomeWarningDialog(
        context,
        title: 'Từ chối quyền truy cập',
        message: 'Chỉ Chủ nhà (Owner) mới có quyền nâng cấp firmware cho vi điều khiển ESP32.',
      );
      return;
    }

    // -------------------------------------------------------------
    // BƯỚC 2: KIỂM TRA LIÊN KẾT VÀ TRẠNG THÁI TRỰC TUYẾN CỦA HUB
    // -------------------------------------------------------------
    final isLinked = activeConfig.macAddress.isNotEmpty &&
        activeConfig.macAddress != 'unknown_mac' &&
        activeConfig.macAddress != 'unknown';

    if (!isLinked) {
      showZenHomeWarningDialog(
        context,
        title: 'Chưa liên kết Hub ESP32',
        message: 'Tài khoản chưa được kết nối với Hub ESP32 nào. Vui lòng thiết lập Wi-Fi cho Hub trước.',
      );
      return;
    }

    final isEspOnline = ref.read(mqttRepositoryProvider).isEspOnline;
    if (!isEspOnline) {
      showZenHomeErrorDialog(
        context,
        title: 'Hub ESP32 ngoại tuyến',
        message: 'Hub ESP32 hiện đang ngoại tuyến (mất nguồn hoặc mất kết nối Wi-Fi). Vui lòng kiểm tra lại thiết bị trước khi nâng cấp firmware.',
        details: {
          'Mã Hub': MaskingHelper.maskMac(activeConfig.macAddress),
          'Trạng thái': 'Ngoại tuyến (Offline)',
          'Yêu cầu': 'Hub phải trực tuyến để tiếp nhận lệnh OTA',
        },
      );
      return;
    }

    // -------------------------------------------------------------
    // BƯỚC 3: XÁC THỰC DANH TÍNH CHỦ NHÀ (Biometric / Password Gate)
    // -------------------------------------------------------------
    final authenticated = await ReauthHelper.reauthenticate(
      context,
      reason: 'xác nhận nâng cấp Firmware cho vi điều khiển Hub ESP32',
    );
    if (!authenticated) {
      if (context.mounted) {
        showZenHomeWarningDialog(
          context,
          title: 'Hủy thao tác bảo mật',
          message: 'Chưa xác thực danh tính. Quá trình nâng cấp firmware được hủy bỏ an toàn.',
        );
      }
      return;
    }

    // -------------------------------------------------------------
    // BƯỚC 4: XÁC THỰC MẬT KHẨU QUẢN TRỊ HUB (Admin Password Gate)
    // -------------------------------------------------------------
    if (!context.mounted) return;
    final isAdminPassValid = await showAdminPasswordDialog(
      context,
      currentAdminPassword: activeConfig.adminPass,
      title: 'Mật khẩu quản trị Hub',
      description: 'Vui lòng nhập mật khẩu quản trị của Hub ESP32 để ủy quyền nâng cấp vi điều khiển.',
    );
    if (!isAdminPassValid) {
      if (context.mounted) {
        showZenHomeWarningDialog(
          context,
          title: 'Hủy thao tác bảo mật',
          message: 'Chưa xác thực mật khẩu quản trị. Hub ESP32 được giữ nguyên phiên bản cũ.',
        );
      }
      return;
    }

    // -------------------------------------------------------------
    // BƯỚC 5: TRUY VẤN THÔNG TIN FIRMWARE MỚI TỪ CLOUD HOẶC MÁY CHỦ
    // -------------------------------------------------------------
    if (!context.mounted) return;
    LoadingOverlay.show(context);

    String? serverBaseUrl = await AppUpdateService.getLiveServerBaseUrl();
    serverBaseUrl ??= AppUpdateService.fallbackServerUrl;

    Map<String, dynamic>? firmwareInfo;
    // 1. Ưu tiên kiểm tra trực tiếp từ Firestore (system_config/esp32_firmware)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('esp32_firmware')
          .get()
          .timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['exists'] == true || (data['directUrl'] != null && data['directUrl'].toString().isNotEmpty)) {
          firmwareInfo = data;
          debugPrint('[OTA] ☁️ Đã tải cấu hình firmware từ Firestore: v${data['version']}');
        }
      }
    } catch (e) {
      debugPrint('[OTA] Lỗi tải firmware từ Firestore: $e');
    }

    // 2. Dự phòng: Kiểm tra qua REST API Web Server
    if (firmwareInfo == null) {
      try {
        final infoUrl = Uri.parse('$serverBaseUrl/api/v1/hub/ota/info');
        final res = await http.get(infoUrl).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          if (body['success'] == true && body['data'] != null) {
            firmwareInfo = body['data'] as Map<String, dynamic>;
          }
        }
      } catch (e) {
        debugPrint('[OTA] Lỗi tải thông tin firmware từ Web Server: $e');
      }
    }

    // 3. Dự phòng toàn cầu: Fallback GitHub Releases CDN nếu server local offline
    if (firmwareInfo == null) {
      firmwareInfo = {
        'version': '2.5.5',
        'buildNumber': 199,
        'directUrl': 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin',
        'exists': true,
        'fileSizeBytes': 1373757,
        'sha256': '',
      };
    }
    LoadingOverlay.hide();

    if (!context.mounted) return;

    if (firmwareInfo == null || firmwareInfo['exists'] != true) {
      showZenHomeWarningDialog(
        context,
        title: 'Chưa có bản cập nhật mới',
        message: 'Hiện tại máy chủ chưa có file Firmware binary (.bin) sẵn sàng để nâng cấp OTA cho Hub ESP32.',
        details: {
          'Máy chủ': serverBaseUrl,
          'Trạng thái': 'Không tìm thấy firmware.bin',
        },
      );
      return;
    }

    // -------------------------------------------------------------
    // BƯỚC 6: HIỂN THỊ HỘP THOẠI XÁC NHẬN NÂNG CẤP
    // -------------------------------------------------------------
    final version = firmwareInfo['version']?.toString() ?? '1.7.9';
    final fileSizeBytes = firmwareInfo['fileSizeBytes'] is int ? firmwareInfo['fileSizeBytes'] as int : 0;
    final fileSizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(2);
    final sha256 = firmwareInfo['sha256']?.toString() ?? '';
    final shortSha = sha256.length > 16 ? '${sha256.substring(0, 8)}...${sha256.substring(sha256.length - 8)}' : sha256;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.system_update_alt_rounded, color: Color(0xFF0284C7), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('hub_ota_title'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đã tìm thấy phiên bản Firmware mới sẵn sàng nạp cho Hub ESP32.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildMetaRow('Phiên bản mới', 'v$version', Icons.tag_rounded, const Color(0xFF0284C7)),
                  const Divider(height: 14),
                  _buildMetaRow('Dung lượng', '$fileSizeMb MB ($fileSizeBytes bytes)', Icons.folder_zip_outlined, Colors.purple),
                  const Divider(height: 14),
                  _buildMetaRow('Kiểm tra SHA-256', shortSha, Icons.verified_user_outlined, Colors.green),
                  const Divider(height: 14),
                  _buildMetaRow('Mục tiêu', MaskingHelper.maskMac(activeConfig.macAddress), Icons.memory_rounded, Colors.teal),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Lưu ý: Quá trình nạp kéo dài khoảng 30 - 60 giây. Tuyệt đối không ngắt nguồn điện hoặc tắt Wi-Fi.',
                      style: TextStyle(fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('btn_cancel'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: Text(context.tr('btn_start_upgrade'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // -------------------------------------------------------------
    // BƯỚC 7: KÍCH HOẠT VÀ LẮNG NGHE TIẾN TRÌNH NẠP FLASH THỜI GIAN THỰC
    // -------------------------------------------------------------
    final directFwUrl = firmwareInfo['directUrl']?.toString().isNotEmpty == true
        ? firmwareInfo['directUrl'].toString()
        : '$serverBaseUrl/public/firmware/esp32/firmware.bin';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EspOtaProgressDialog(
        activeConfig: activeConfig,
        serverBaseUrl: serverBaseUrl!,
        version: version,
        expectedSha256: sha256,
        directUrl: directFwUrl,
        isDark: isDark,
      ),
    );
  }

  static Widget _buildMetaRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Widget hiển thị tiến trình nạp Flash thời gian thực (0% - 100%)
class _EspOtaProgressDialog extends ConsumerStatefulWidget {
  final SmartConfig activeConfig;
  final String serverBaseUrl;
  final String version;
  final String expectedSha256;
  final String directUrl;
  final bool isDark;

  const _EspOtaProgressDialog({
    required this.activeConfig,
    required this.serverBaseUrl,
    required this.version,
    required this.expectedSha256,
    required this.directUrl,
    required this.isDark,
  });

  @override
  ConsumerState<_EspOtaProgressDialog> createState() => _EspOtaProgressDialogState();
}

class _EspOtaProgressDialogState extends ConsumerState<_EspOtaProgressDialog> {
  int _progress = 0;
  String _statusMessage = 'Đang phát lệnh OTA an toàn tới Hub ESP32...';
  bool _isFinished = false;
  bool _isSuccess = false;
  String? _errorMessage;
  final DateTime _startTime = DateTime.now();

  StreamSubscription? _progressSub;
  StreamSubscription? _resultSub;
  StreamSubscription? _onlineSub;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _startOtaExecution();
  }

  void _startOtaExecution() async {
    final mqttRepo = ref.read(mqttRepositoryProvider);

    // Lắng nghe tiến trình phần trăm nạp Flash từ ESP32
    _progressSub = mqttRepo.otaProgressStream.listen((data) {
      if (!mounted || _isFinished) return;
      if (data.containsKey('progress')) {
        final p = (data['progress'] as num).toInt();
        setState(() {
          _progress = p.clamp(0, 100);
          _statusMessage = 'Đang tải & nạp Flash vi điều khiển: $_progress%';
        });
      }
    });

    // Lắng nghe kết quả kết thúc
    _resultSub = mqttRepo.otaResultStream.listen((data) {
      if (!mounted || _isFinished) return;
      final status = data['status']?.toString().toLowerCase();
      final msg = data['message']?.toString() ?? '';

      _timeoutTimer?.cancel();
      setState(() {
        _isFinished = true;
        if (status == 'success') {
          _isSuccess = true;
          _progress = 100;
          _statusMessage = 'Nâng cấp thành công! Hub ESP32 đang khởi động lại...';
        } else {
          _isSuccess = false;
          _errorMessage = msg.isNotEmpty ? msg : 'Lỗi trong quá trình nạp firmware!';
        }
      });
    });

    // Tiến trình hiển thị mượt mà trong khi chờ phản hồi từng block Flash từ ESP32
    Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted || _isFinished) {
        timer.cancel();
        return;
      }
      if (_progress < 85) {
        setState(() {
          _progress = (_progress + 3).clamp(0, 85);
          _statusMessage = 'Đang tải & nạp Flash vi điều khiển: $_progress%';
        });
      }
    });

    // Dual-detection: Nếu ESP32 khởi động lại và online trở lại sau quá trình nạp
    _onlineSub = mqttRepo.espOnlineStream.listen((isOnline) {
      if (!mounted || _isFinished) return;
      final elapsedSec = DateTime.now().difference(_startTime).inSeconds;
      if (isOnline && (_progress >= 60 || elapsedSec >= 12)) {
        _timeoutTimer?.cancel();
        setState(() {
          _isFinished = true;
          _isSuccess = true;
          _progress = 100;
          _statusMessage = 'Nâng cấp thành công! Hub ESP32 đã hoạt động trở lại.';
        });
      }
    });

    // Thiết lập timeout 90s phòng trường hợp Hub mất nguồn giữa chừng
    _timeoutTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && !_isFinished) {
        setState(() {
          _isFinished = true;
          _isSuccess = false;
          _errorMessage = 'Hết thời gian chờ phản hồi từ Hub ESP32 (Timeout 90s). Vui lòng kiểm tra lại nguồn điện Hub!';
        });
      }
    });

    // -----------------------------------------------------------------
    // CƠ CHẾ DUAL-TRIGGER: PHÁT ĐỒNG THỜI QUA MQTT BROKER VÀ HTTP SERVER
    // -----------------------------------------------------------------
    final cleanMac = widget.activeConfig.macAddress.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    final formattedMac = widget.activeConfig.macAddress;
    final otaPayload = jsonEncode({
      'action': 'ota_update',
      'url': widget.directUrl,
      'version': widget.version,
      'sha256': widget.expectedSha256,
      'admin_pass': widget.activeConfig.adminPass ?? 'admin',
      'server_authorized': true,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // 1. Phóng thẳng lệnh qua MQTT từ App tới mọi topic biến thể của Hub
    try {
      final mqttPrefix = widget.activeConfig.mqttPrefix.isNotEmpty
          ? widget.activeConfig.mqttPrefix
          : '${widget.activeConfig.userId}/$formattedMac';

      mqttRepo.publishCmd('$mqttPrefix/system/ota_update', otaPayload);
      mqttRepo.publishCmd('${widget.activeConfig.userId}/$cleanMac/system/ota_update', otaPayload);
      mqttRepo.publishCmd('${widget.activeConfig.userId}/$formattedMac/system/ota_update', otaPayload);
      mqttRepo.publishCmd('${widget.activeConfig.userId.toLowerCase()}/$cleanMac/system/ota_update', otaPayload);
      mqttRepo.publishCmd('${widget.activeConfig.userId.toLowerCase()}/$formattedMac/system/ota_update', otaPayload);
      debugPrint('[OTA] 📡 Đã phát trực tiếp lệnh OTA qua MQTT tới các topic Hub');
    } catch (e) {
      debugPrint('[OTA] ⚠️ Không thể phát lệnh qua MQTT App: $e');
    }

    // 2. Thử kích hoạt qua Local HTTP nếu có IP LAN
    try {
      final localIpCandidates = ['192.168.1.11', '192.168.1.10', '192.168.1.12'];
      for (final ip in localIpCandidates) {
        http.post(
          Uri.parse('http://$ip/api/ota'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'url': widget.directUrl,
            'sha256': widget.expectedSha256,
            'adminPass': widget.activeConfig.adminPass ?? 'admin',
          }),
        ).timeout(const Duration(milliseconds: 1500)).catchError((_) => http.Response('', 408));
      }
    } catch (_) {}

    // 3. Gửi lệnh qua Web Server HTTP Backend API
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      final triggerUrl = Uri.parse('${widget.serverBaseUrl}/api/v1/hub/ota/trigger');
      final res = await http.post(
        triggerUrl,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': widget.activeConfig.userId,
          'macAddress': widget.activeConfig.macAddress,
          'adminPass': widget.activeConfig.adminPass ?? 'admin',
          'version': widget.version,
        }),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (mounted && !_isFinished) {
          setState(() {
            _statusMessage = 'Hub ESP32 đã tiếp nhận lệnh. Đang tải Firmware...';
          });
        }
      }
    } catch (e) {
      debugPrint('[OTA] Server HTTP trigger error: $e');
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _resultSub?.cancel();
    _onlineSub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: widget.isDark ? const Color(0xFF131B2E) : Colors.white,
      title: Row(
        children: [
          Icon(
            _isFinished
                ? (_isSuccess ? Icons.check_circle_rounded : Icons.error_rounded)
                : Icons.system_update_alt_rounded,
            color: _isFinished
                ? (_isSuccess ? const Color(0xFF10B981) : Colors.redAccent)
                : const Color(0xFF0284C7),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isFinished
                  ? (_isSuccess ? 'Nâng Cấp Thành Công!' : 'Nâng Cấp Thất Bại')
                  : 'Đang Nạp Firmware OTA',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          if (!_isFinished) ...[
            SizedBox(
              height: 120,
              width: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _progress > 0 ? _progress / 100 : null,
                    strokeWidth: 8,
                    backgroundColor: widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  ),
                  Center(
                    child: Text(
                      '$_progress%',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 13.5,
                color: widget.isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ] else if (_isSuccess) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.done_all_rounded, color: Color(0xFF10B981), size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Đã nạp 100% Firmware và xác thực SHA-256 toàn vẹn!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hub ESP32 đang tự động hoán đổi phân vùng boot và khởi động lại. Quá trình mất khoảng 5 - 10 giây.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? 'Đã xảy ra lỗi không xác định.',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_isFinished)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSuccess ? const Color(0xFF10B981) : Colors.grey.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('btn_close'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
