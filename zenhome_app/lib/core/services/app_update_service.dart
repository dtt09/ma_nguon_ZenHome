import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:zenhome_app/core/models/app_version_info.dart';
import 'package:zenhome_app/core/widgets/app_update_dialog.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/features/notifications/logic/notification_helper.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';

class AppUpdateService {
  static const String fallbackServerUrl = 'http://192.168.1.6:5000'; // Default host LAN fallback
  static const String _prefKeyLastServerUrl = 'last_known_server_base_url';

  /// Lấy thông tin phiên bản hiện tại của ứng dụng
  static Future<PackageInfo> getPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (e) {
      return PackageInfo(
        appName: 'ZenHome',
        packageName: 'com.zenhome.app',
        version: '1.7.3',
        buildNumber: '173',
      );
    }
  }

  /// Lấy URL máy chủ thực tế được Server tự động đồng bộ lên Firestore (system_config/server_config hoặc app_version)
  static Future<String?> getLiveServerBaseUrl() async {
    // 1. Kiểm tra system_config/server_config
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('server_config')
          .get()
          .timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final base = doc.data()!['serverBaseUrl']?.toString().trim();
        if (base != null && base.isNotEmpty && !base.contains('127.0.0.1') && !base.contains('localhost')) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefKeyLastServerUrl, base);
          } catch (_) {}
          return base;
        }
      }
    } catch (e) {
      debugPrint("getLiveServerBaseUrl server_config error: $e");
    }

    // 2. Dự phòng: Kiểm tra system_config/app_version
    try {
      final vDoc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_version')
          .get()
          .timeout(const Duration(seconds: 4));
      if (vDoc.exists && vDoc.data() != null) {
        final base = vDoc.data()!['serverBaseUrl']?.toString().trim();
        if (base != null && base.isNotEmpty && !base.contains('127.0.0.1') && !base.contains('localhost')) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_prefKeyLastServerUrl, base);
          } catch (_) {}
          return base;
        }
      }
    } catch (e) {
      debugPrint("getLiveServerBaseUrl app_version error: $e");
    }

    // 3. Dự phòng bộ nhớ đệm máy (SharedPreferences)
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefKeyLastServerUrl);
      if (cached != null && cached.isNotEmpty && !cached.contains('127.0.0.1') && !cached.contains('localhost')) {
        return cached;
      }
    } catch (_) {}

    return fallbackServerUrl;
  }

  /// Tự động chuyển đổi và chuẩn hóa URL tải APK theo đúng IP máy chủ thực tế
  static Future<String> resolveDownloadUrl(String url) async {
    String trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final liveBaseUrl = await getLiveServerBaseUrl();

    if (liveBaseUrl != null && liveBaseUrl.isNotEmpty) {
      if (trimmed.startsWith('/')) {
        return '$liveBaseUrl$trimmed';
      }
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final isLocalOrDownloads = uri.path.contains('/public/downloads/') ||
            uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '10.0.2.2' ||
            uri.host.startsWith('192.168.');
        if (isLocalOrDownloads) {
          final liveUri = Uri.tryParse(liveBaseUrl);
          if (liveUri != null) {
            return uri.replace(
              scheme: liveUri.scheme,
              host: liveUri.host,
              port: liveUri.port,
            ).toString();
          }
        }
      }
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      if (trimmed.startsWith('/')) {
        final base = liveBaseUrl ?? fallbackServerUrl;
        return '$base$trimmed';
      }
      return 'https://$trimmed';
    }

    return trimmed;
  }

  /// Truy vấn phiên bản mới nhất từ Firestore (ưu tiên) hoặc REST API Server
  static Future<AppVersionInfo?> fetchLatestVersionInfo({String? customServerUrl}) async {
    // 1. Thử lấy từ Firestore trước
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('app_version')
          .get()
          .timeout(const Duration(seconds: 4));
      
      if (doc.exists && doc.data() != null) {
        var info = AppVersionInfo.fromJson(doc.data()!);
        if (info.directApkUrl != null && info.directApkUrl!.isNotEmpty) {
          final resolvedDirect = await resolveDownloadUrl(info.directApkUrl!);
          info = info.copyWith(directApkUrl: resolvedDirect);
        }
        if (info.downloadUrl.isNotEmpty) {
          final resolvedDownload = await resolveDownloadUrl(info.downloadUrl);
          info = info.copyWith(downloadUrl: resolvedDownload);
        }
        return info;
      }
    } catch (e) {
      debugPrint("Firestore app_version check failed, trying REST API: $e");
    }

    // 2. Dự phòng: Thử lấy từ REST API Server (Port 5000)
    try {
      final liveBase = await getLiveServerBaseUrl();
      final baseUrl = customServerUrl ?? liveBase ?? fallbackServerUrl;
      final uri = Uri.parse('$baseUrl/api/v1/system/app-version');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['success'] == true && decoded['data'] != null) {
          var info = AppVersionInfo.fromJson(decoded['data']);
          if (info.directApkUrl != null && info.directApkUrl!.isNotEmpty) {
            final resolvedDirect = await resolveDownloadUrl(info.directApkUrl!);
            info = info.copyWith(directApkUrl: resolvedDirect);
          }
          if (info.downloadUrl.isNotEmpty) {
            final resolvedDownload = await resolveDownloadUrl(info.downloadUrl);
            info = info.copyWith(downloadUrl: resolvedDownload);
          }
          return info;
        }
      }
    } catch (e) {
      debugPrint("REST API app-version check failed: $e");
    }

    return null;
  }

  /// Mở liên kết tải bản cập nhật qua trình duyệt hoặc kho ứng dụng
  static Future<bool> launchDownloadUrl(String url) async {
    try {
      final resolvedUrl = await resolveDownloadUrl(url);
      final uri = Uri.parse(resolvedUrl);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) return true;
      } catch (e) {
        debugPrint("externalApplication mode failed, fallback to default: $e");
      }

      return await launchUrl(uri);
    } catch (e) {
      debugPrint("Could not launch update URL: $e");
    }
    return false;
  }

  /// Xóa sạch các file APK và file .part tạm cũ không thuộc phiên bản đang tải
  static Future<void> cleanOldApkFiles({String? keepVersion}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(tempDir.path);
      if (await dir.exists()) {
        final list = await dir.list().toList();
        final sanitizedKeep = keepVersion?.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        for (final item in list) {
          if (item is File) {
            final p = item.path.toLowerCase();
            final isApkOrPart = p.endsWith('.apk') || p.endsWith('.apk.part') || p.contains('zenhome_update');
            if (isApkOrPart) {
              // Giữ lại file của phiên bản đang tải để phục vụ tính năng tải nối tiếp (Breakpoint Resume)
              if (sanitizedKeep != null && sanitizedKeep.isNotEmpty && item.path.contains(sanitizedKeep)) {
                continue;
              }
              try {
                await item.delete();
                debugPrint("[UPDATE] Đã dọn dẹp file cũ: ${item.path}");
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint("cleanOldApkFiles error: $e");
    }
  }

  /// Lấy số byte đã tải dở dang của phiên bản [version] (nếu có)
  static Future<int> getExistingPartialBytes(String version) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedVer = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final partFile = File('${tempDir.path}/zenhome_update_$sanitizedVer.apk.part');
      if (await partFile.exists()) {
        return await partFile.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Kiểm tra xem file APK đầy đủ đã có sẵn trên máy chưa
  static Future<bool> isApkAlreadyDownloaded(String version, int? expectedTotalBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedVer = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final apkFile = File('${tempDir.path}/zenhome_update_$sanitizedVer.apk');
      if (await apkFile.exists()) {
        final len = await apkFile.length();
        if (expectedTotalBytes != null && expectedTotalBytes > 0) {
          return len == expectedTotalBytes;
        }
        return len > 1000000;
      }
    } catch (_) {}
    return false;
  }

  /// Cài đặt trực tiếp file APK đã tải xong của phiên bản [version]
  static Future<bool> installCompletedApk(String version) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedVer = version.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final apkFile = File('${tempDir.path}/zenhome_update_$sanitizedVer.apk');
      if (await apkFile.exists()) {
        return await installApkFile(apkFile.path);
      }
    } catch (_) {}
    return false;
  }

  // --- Trạng thái & thông số tải bản cập nhật ---
  static final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<double> downloadProgressNotifier = ValueNotifier<double>(0.0);
  static final ValueNotifier<String> downloadStatusNotifier = ValueNotifier<String>('');
  static final ValueNotifier<String> downloadSpeedNotifier = ValueNotifier<String>('');
  static final ValueNotifier<int> downloadReceivedBytesNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> downloadTotalBytesNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String?> downloadErrorNotifier = ValueNotifier<String?>(null);
  static String? currentDownloadingVersion;
  static http.Client? _activeDownloadClient;
  static HttpClient? _activeIoClient;
  static bool _isCancelled = false;

  /// Định dạng tốc độ tải sang chuỗi trực quan (KB/s, MB/s)
  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec <= 0) return '0 KB/s';
    if (bytesPerSec >= 1048576) {
      return '${(bytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSec.toInt()} B/s';
  }

  /// Ước tính thời gian tải còn lại (ETA)
  static String formatEta(int receivedBytes, int totalBytes, double speedBytesPerSec) {
    if (totalBytes <= 0 || receivedBytes >= totalBytes || speedBytesPerSec < 1024) {
      return '';
    }
    final remainingBytes = totalBytes - receivedBytes;
    final remainingSeconds = (remainingBytes / speedBytesPerSec).round();
    if (remainingSeconds <= 0) return '';
    if (remainingSeconds < 60) {
      return '~$remainingSeconds s';
    }
    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    return '~${mins}m ${secs}s';
  }

  /// Hủy quá trình tải xuống (bảo lưu dữ liệu dở dang để tải tiếp trừ khi deletePartial = true)
  static Future<void> cancelDownload({bool deletePartial = false}) async {
    _isCancelled = true;
    try {
      _activeIoClient?.close(force: true);
    } catch (_) {}
    _activeIoClient = null;
    try {
      _activeDownloadClient?.close();
    } catch (_) {}
    _activeDownloadClient = null;

    if (deletePartial && currentDownloadingVersion != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final sanitizedVer = currentDownloadingVersion!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final partFile = File('${tempDir.path}/zenhome_update_$sanitizedVer.apk.part');
        if (await partFile.exists()) {
          await partFile.delete();
        }
      } catch (_) {}
    }

    try {
      await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_KEEP_SCREEN_ON);
    } catch (_) {}

    isDownloadingNotifier.value = false;
    downloadProgressNotifier.value = 0.0;
    downloadSpeedNotifier.value = '';
    downloadReceivedBytesNotifier.value = 0;
    downloadTotalBytesNotifier.value = 0;
    downloadStatusNotifier.value = '';
    NotificationHelper.cancelNotification(NotificationHelper.downloadNotificationId);
  }

  /// Tải file APK trực tiếp với cơ chế:
  /// 1. Tải nối tiếp HTTP Range (Resume download): Không bao giờ mất tiến trình cũ khi gián đoạn
  /// 2. Tự động kết nối lại khi mạng nghẽn / mất sóng / khóa máy (Auto-Retry với 15 lần thử)
  /// 3. Lưu dạng .apk.part và chỉ đổi thành .apk khi đã kiểm chứng 100% dung lượng
  static Future<String?> downloadApkWithProgress({
    required String url,
    String? version,
    int? expectedTotalBytes,
    required Function(int received, int total, double progress, double speedBytesPerSec) onProgress,
  }) async {
    _isCancelled = false;
    downloadErrorNotifier.value = null;

    try {
      final targetVersion = version ?? currentDownloadingVersion ?? 'latest';
      final sanitizedVer = targetVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      // 1. Dọn các file cũ nhưng bảo lưu file dở dang của bản hiện tại
      await cleanOldApkFiles(keepVersion: sanitizedVer);

      final tempDir = await getTemporaryDirectory();
      final partFilePath = '${tempDir.path}/zenhome_update_$sanitizedVer.apk.part';
      final finalFilePath = '${tempDir.path}/zenhome_update_$sanitizedVer.apk';
      final partFile = File(partFilePath);
      final finalFile = File(finalFilePath);

      // 2. Nếu file hoàn chỉnh đã tồn tại và đúng kích thước -> dùng luôn
      if (await finalFile.exists()) {
        final existingFullLen = await finalFile.length();
        if ((expectedTotalBytes != null && expectedTotalBytes > 0 && existingFullLen == expectedTotalBytes) ||
            (expectedTotalBytes == null && existingFullLen > 1000000)) {
          debugPrint("[UPDATE] APK $sanitizedVer đã tải trọn vẹn trước đó ($existingFullLen bytes).");
          onProgress(existingFullLen, existingFullLen, 1.0, 0.0);
          return finalFilePath;
        }
      }

      final resolvedUrl = await resolveDownloadUrl(url);
      String activeUrl = resolvedUrl;
      debugPrint("[UPDATE] Bắt đầu tải APK từ: $activeUrl (Bản: $sanitizedVer)");

      int contentLength = expectedTotalBytes ?? 0;
      int existingBytes = 0;
      if (await partFile.exists()) {
        existingBytes = await partFile.length();
        debugPrint("[UPDATE] Tiếp tục tải nối tiếp từ vị trí: $existingBytes bytes");
      }

      int retryCount = 0;
      const int maxRetries = 15;
      double currentSpeed = 0.0;
      int lastSpeedBytes = existingBytes;
      DateTime lastSpeedTime = DateTime.now();
      DateTime lastUiUpdateTime = DateTime.now();

      while (!_isCancelled && retryCount < maxRetries) {
        HttpClient? ioClient;
        IOSink? sink;

        try {
          if (await partFile.exists()) {
            existingBytes = await partFile.length();
          } else {
            existingBytes = 0;
          }

          // Nếu đã đủ dung lượng cần tải
          if (contentLength > 0 && existingBytes >= contentLength) {
            if (await finalFile.exists()) {
              try { await finalFile.delete(); } catch (_) {}
            }
            await partFile.rename(finalFilePath);
            onProgress(contentLength, contentLength, 1.0, currentSpeed);
            return finalFilePath;
          }

          ioClient = HttpClient()
            ..connectionTimeout = const Duration(seconds: 20)
            ..idleTimeout = const Duration(seconds: 45)
            ..badCertificateCallback = ((X509Certificate cert, String host, int port) => true);
          _activeIoClient = ioClient;

          HttpClientResponse? response;
          try {
            final request = await ioClient.getUrl(Uri.parse(activeUrl));
            request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

            // Gửi Range Header nếu đã có dữ liệu trước đó
            if (existingBytes > 0) {
              request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
              debugPrint("[UPDATE] Gửi yêu cầu HTTP Range: bytes=$existingBytes-");
            }

            response = await request.close();
          } catch (connErr) {
            if (activeUrl != url && url.startsWith('http')) {
              activeUrl = url;
              debugPrint("[UPDATE] Thử kết nối URL dự phòng: $activeUrl");
              final fbRequest = await ioClient.getUrl(Uri.parse(activeUrl));
              fbRequest.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
              if (existingBytes > 0) {
                fbRequest.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
              }
              response = await fbRequest.close();
            } else {
              rethrow;
            }
          }

          final statusCode = response.statusCode;

          if (statusCode == HttpStatus.partialContent) {
            // 206: Server hỗ trợ Range tải tiếp
            debugPrint("[UPDATE] Máy chủ phản hồi 206 Partial Content (Tải nối tiếp)");
            sink = partFile.openWrite(mode: FileMode.append);

            final cr = response.headers.value(HttpHeaders.contentRangeHeader);
            if (cr != null && cr.contains('/')) {
              final totalStr = cr.split('/').last.trim();
              final parsed = int.tryParse(totalStr);
              if (parsed != null && parsed > 0) {
                contentLength = parsed;
              }
            }
            if (contentLength <= 0 && response.contentLength > 0) {
              contentLength = existingBytes + response.contentLength;
            }
          } else if (statusCode == HttpStatus.ok) {
            // 200: Server tải từ đầu
            debugPrint("[UPDATE] Máy chủ phản hồi 200 OK (Tải toàn bộ file từ đầu)");
            sink = partFile.openWrite(mode: FileMode.write);
            existingBytes = 0;
            if (response.contentLength > 0) {
              contentLength = response.contentLength;
            }
          } else if (statusCode == HttpStatus.requestedRangeNotSatisfiable) {
            // 416: File tạm đã vượt quá kích thước, xóa và làm lại
            debugPrint("[UPDATE] Mã 416 Range Not Satisfiable. Xóa file tạm và tải lại.");
            if (await partFile.exists()) {
              await partFile.delete();
            }
            existingBytes = 0;
            retryCount++;
            await Future.delayed(const Duration(milliseconds: 800));
            continue;
          } else {
            throw HttpException("Máy chủ phản hồi mã lỗi HTTP $statusCode");
          }

          if (contentLength <= 0 && expectedTotalBytes != null && expectedTotalBytes > 0) {
            contentLength = expectedTotalBytes;
          }

          int receivedBytes = existingBytes;
          lastSpeedBytes = receivedBytes;
          lastSpeedTime = DateTime.now();

          // Cập nhật ngay tiến trình hiện có lên giao diện
          if (contentLength > 0) {
            final initialProgress = (receivedBytes / contentLength).clamp(0.0, 1.0);
            onProgress(receivedBytes, contentLength, initialProgress, 0.0);
          }

          await for (final chunk in response) {
            if (_isCancelled) {
              debugPrint("[UPDATE] Người dùng đã hủy quá trình tải APK.");
              try { await sink.flush(); } catch (_) {}
              try { await sink.close(); } catch (_) {}
              ioClient.close(force: true);
              _activeIoClient = null;
              return null;
            }

            sink.add(chunk);
            receivedBytes += chunk.length;

            final now = DateTime.now();
            final speedMs = now.difference(lastSpeedTime).inMilliseconds;
            if (speedMs >= 350) {
              final deltaBytes = receivedBytes - lastSpeedBytes;
              final deltaSec = speedMs / 1000.0;
              if (deltaSec > 0) {
                final instantSpeed = deltaBytes / deltaSec;
                currentSpeed = currentSpeed == 0.0
                    ? instantSpeed
                    : (currentSpeed * 0.65 + instantSpeed * 0.35);
              }
              lastSpeedBytes = receivedBytes;
              lastSpeedTime = now;
            }

            final uiMs = now.difference(lastUiUpdateTime).inMilliseconds;
            if (uiMs >= 200 || (contentLength > 0 && receivedBytes >= contentLength)) {
              lastUiUpdateTime = now;
              final progress = contentLength > 0
                  ? (receivedBytes / contentLength).clamp(0.0, 1.0)
                  : 0.0;
              onProgress(receivedBytes, contentLength, progress, currentSpeed);
            }
          }

          await sink.flush();
          await sink.close();
          sink = null;
          ioClient.close(force: true);
          _activeIoClient = null;

          final finalPartLen = await partFile.length();
          if (contentLength > 0 && finalPartLen < contentLength) {
            throw SocketException("Kết nối mạng bị gián đoạn giữa luồng tải ($finalPartLen / $contentLength bytes)");
          }

          // Hoàn tất 100%: Đổi tên sang .apk chính thức
          if (await finalFile.exists()) {
            try { await finalFile.delete(); } catch (_) {}
          }
          await partFile.rename(finalFilePath);

          onProgress(
            finalPartLen,
            contentLength > 0 ? contentLength : finalPartLen,
            1.0,
            currentSpeed,
          );

          debugPrint("[UPDATE] Tải APK hoàn tất 100%: $finalFilePath ($finalPartLen bytes)");
          return finalFilePath;
        } catch (e) {
          if (_isCancelled) {
            try { await sink?.close(); } catch (_) {}
            ioClient?.close(force: true);
            _activeIoClient = null;
            return null;
          }

          retryCount++;
          debugPrint("[UPDATE] Mạng gián đoạn hoặc ngắt kết nối (lần $retryCount/$maxRetries): $e");

          try { await sink?.flush(); } catch (_) {}
          try { await sink?.close(); } catch (_) {}
          sink = null;
          ioClient?.close(force: true);
          _activeIoClient = null;

          if (await partFile.exists()) {
            existingBytes = await partFile.length();
          }

          if (retryCount >= maxRetries) {
            final err = "Mất kết nối máy chủ sau $maxRetries lần thử lại ($e). Dữ liệu đã tải ($existingBytes bytes) được lưu an toàn để tải tiếp.";
            debugPrint("[UPDATE] $err");
            downloadErrorNotifier.value = err;
            return null;
          }

          final pct = contentLength > 0 ? ((existingBytes / contentLength) * 100).toInt().clamp(0, 99) : 0;
          downloadSpeedNotifier.value = 'Mạng yếu, nối lại...';
          downloadStatusNotifier.value = 'Mạng gián đoạn ($pct%). Đang tự động kết nối lại (lần $retryCount/$maxRetries)...';

          final delayMs = (1500 + retryCount * 400).clamp(1500, 4500);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
      return null;
    } catch (e) {
      debugPrint("downloadApkWithProgress fatal error: $e");
      downloadErrorNotifier.value = e.toString();
      _activeIoClient?.close(force: true);
      _activeIoClient = null;
      return null;
    }
  }

  /// Khởi chạy quá trình tải bản cập nhật trong nền và hiển thị thanh tiến trình notification
  static Future<bool> startBackgroundDownload({
    required String url,
    required String version,
    required String title,
    required String downloadingText,
    required String completeText,
    required String failedText,
    required String openingInstallerText,
    int? expectedTotalBytes,
  }) async {
    if (isDownloadingNotifier.value) return false;

    isDownloadingNotifier.value = true;
    downloadProgressNotifier.value = 0.0;
    downloadSpeedNotifier.value = 'Đang kết nối...';
    downloadReceivedBytesNotifier.value = 0;
    downloadTotalBytesNotifier.value = expectedTotalBytes ?? 0;
    downloadErrorNotifier.value = null;
    currentDownloadingVersion = version;
    downloadStatusNotifier.value = downloadingText;

    // Giữ màn hình luôn sáng trong lúc tải để tránh Android tự tắt socket hoặc CPU ngủ
    try {
      await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_KEEP_SCREEN_ON);
    } catch (e) {
      debugPrint("Keep screen on flag error: $e");
    }

    try {
      await NotificationHelper.showDownloadProgressNotification(
        title: title,
        body: '$downloadingText (0%)',
        progress: 0,
        maxProgress: 100,
        indeterminate: true,
      );

      int lastReportedPercent = -1;
      DateTime lastNotifTime = DateTime.now();

      final apkFilePath = await downloadApkWithProgress(
        url: url,
        version: version,
        expectedTotalBytes: expectedTotalBytes,
        onProgress: (received, total, progress, speedBytesPerSec) {
          final pct = (progress * 100).clamp(0, 100).toInt();
          downloadProgressNotifier.value = progress;
          downloadReceivedBytesNotifier.value = received;
          downloadTotalBytesNotifier.value = total;

          final speedStr = formatSpeed(speedBytesPerSec);
          downloadSpeedNotifier.value = speedStr;

          final mbRec = (received / 1048576).toStringAsFixed(1);
          final mbTot = total > 0 ? (total / 1048576).toStringAsFixed(1) : '?';
          final etaStr = formatEta(received, total, speedBytesPerSec);

          downloadStatusNotifier.value = etaStr.isNotEmpty
              ? '$downloadingText $pct% • $speedStr ($mbRec / $mbTot MB, $etaStr)'
              : '$downloadingText $pct% • $speedStr ($mbRec / $mbTot MB)';

          final now = DateTime.now();
          if (pct == 100 || (pct != lastReportedPercent && now.difference(lastNotifTime).inMilliseconds >= 1200)) {
            lastReportedPercent = pct;
            lastNotifTime = now;
            NotificationHelper.showDownloadProgressNotification(
              title: title,
              body: '$pct% • $speedStr ($mbRec / $mbTot MB${etaStr.isNotEmpty ? " • $etaStr" : ""})',
              progress: pct,
              maxProgress: 100,
              indeterminate: false,
            );
          }
        },
      );

      if (apkFilePath != null) {
        downloadStatusNotifier.value = openingInstallerText;
        await NotificationHelper.showDownloadProgressNotification(
          title: title,
          body: completeText,
          progress: 100,
          maxProgress: 100,
          indeterminate: false,
        );

        final installed = await installApkFile(apkFilePath);

        Future.delayed(const Duration(seconds: 4), () {
          NotificationHelper.cancelNotification(NotificationHelper.downloadNotificationId);
        });

        if (!installed) {
          await launchDownloadUrl(url);
        }
        return true;
      } else {
        if (!_isCancelled) {
          final err = downloadErrorNotifier.value ?? failedText;
          downloadStatusNotifier.value = err;
          await NotificationHelper.cancelNotification(NotificationHelper.downloadNotificationId);
          await NotificationHelper.showLocalNotification(title, err);
        }
        return false;
      }
    } finally {
      isDownloadingNotifier.value = false;
      // Trả lại cài đặt màn hình bình thường khi hoàn thành hoặc hủy
      try {
        await FlutterWindowManagerPlus.clearFlags(FlutterWindowManagerPlus.FLAG_KEEP_SCREEN_ON);
      } catch (_) {}
    }
  }

  /// Mở trình cài đặt PackageInstaller của Android để cài đặt bản cập nhật
  static Future<bool> installApkFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint("APK file does not exist: $filePath");
        return false;
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      debugPrint("OpenFilex result: ${result.type} - ${result.message}");
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint("installApkFile error: $e");
      return false;
    }
  }

  /// Hàm tiện ích: Tự động kiểm tra và hiển thị Dialog cập nhật
  /// [isManualCheck]: Nếu người dùng bấm từ màn hình Cài đặt, sẽ hiện thông báo ngay cả khi đã là mới nhất.
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool isManualCheck = false,
    String? customServerUrl,
  }) async {
    final packageInfo = await getPackageInfo();
    final currentVersion = packageInfo.version;
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 10;

    final updateInfo = await fetchLatestVersionInfo(customServerUrl: customServerUrl);
    if (!context.mounted) return;

    if (updateInfo == null) {
      if (isManualCheck) {
        showFloatingToast(
          context,
          context.tr('notification'),
          context.tr('err_cannot_check_update'),
          isError: true,
        );
      }
      return;
    }

    final hasUpdate = updateInfo.hasUpdate(currentBuild);
    final isForce = updateInfo.isMustUpdate(currentBuild);

    if (hasUpdate) {
      final notifTitle = context.tr('new_version_available_title');
      final notifBody = 'v${updateInfo.latestVersion}: ${context.tr('new_version_available_body')}';

      // Tự động kích hoạt Push Notification và lưu vào Lịch sử thông báo khi có bản mới
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastNotifiedBuild = prefs.getInt('last_notified_update_build') ?? 0;
        if (lastNotifiedBuild < updateInfo.latestBuildNumber) {
          await prefs.setInt('last_notified_update_build', updateInfo.latestBuildNumber);
          
          await NotificationHelper.showLocalNotification(notifTitle, notifBody);

          List<String> hist = prefs.getStringList('notification_history') ?? [];
          final newNotif = {
            'title': notifTitle,
            'body': notifBody,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'isRead': false,
            'category': 'update',
            'homeId': '',
          };
          hist.insert(0, jsonEncode(newNotif));
          if (hist.length > 100) hist = hist.sublist(0, 100);
          await prefs.setStringList('notification_history', hist);
        }
      } catch (e) {
        debugPrint("Lỗi gửi thông báo update: $e");
      }

      // Nếu là kiểm tra ngầm và là cập nhật tùy chọn: Kiểm tra xem người dùng đã bấm "Để sau" phiên bản này chưa
      if (!isManualCheck && !isForce) {
        final prefs = await SharedPreferences.getInstance();
        final dismissedVersion = prefs.getString('dismissed_update_version');
        if (dismissedVersion == updateInfo.latestVersion) {
          // Bỏ qua để không làm phiền người dùng mỗi lần đổi tab
          return;
        }
      }

      if (!context.mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: !isForce,
        builder: (ctx) => AppUpdateDialog(
          updateInfo: updateInfo,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuild,
        ),
      );

      // Nếu người dùng đóng dialog (không bắt buộc), lưu lại phiên bản để không hỏi lại liên tục trong ngày
      if (!isForce) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dismissed_update_version', updateInfo.latestVersion);
      }
    } else {
      if (isManualCheck) {
        showFloatingToast(
          context,
          context.tr('toast_success'),
          '${context.tr('msg_app_up_to_date')} (v$currentVersion)',
          isError: false,
        );
      }
    }
  }

  /// Kiểm tra nhanh xem hiện tại có bản cập nhật đang chờ hay không (dùng để hiển thị Badge)
  static Future<AppVersionInfo?> getPendingUpdateInfo() async {
    try {
      final packageInfo = await getPackageInfo();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 10;
      final latest = await fetchLatestVersionInfo();
      if (latest != null && latest.hasUpdate(currentBuild)) {
        return latest;
      }
    } catch (_) {}
    return null;
  }
}
