import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/models/app_version_info.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

import 'package:zenhome_app/core/utils/toast_helper.dart';

class AppUpdateDialog extends StatefulWidget {
  final AppVersionInfo updateInfo;
  final String currentVersion;
  final int currentBuildNumber;

  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.currentVersion,
    required this.currentBuildNumber,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = '';
  String _speedText = '';
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  bool _isAlreadyComplete = false;

  @override
  void initState() {
    super.initState();
    _isDownloading = AppUpdateService.isDownloadingNotifier.value;
    _progress = AppUpdateService.downloadProgressNotifier.value;
    _statusText = AppUpdateService.downloadStatusNotifier.value;
    _speedText = AppUpdateService.downloadSpeedNotifier.value;
    _receivedBytes = AppUpdateService.downloadReceivedBytesNotifier.value;
    _totalBytes = AppUpdateService.downloadTotalBytesNotifier.value;
    _errorMessage = AppUpdateService.downloadErrorNotifier.value;

    AppUpdateService.isDownloadingNotifier.addListener(_onDownloadStateChanged);
    AppUpdateService.downloadProgressNotifier.addListener(_onProgressChanged);
    AppUpdateService.downloadStatusNotifier.addListener(_onStatusChanged);
    AppUpdateService.downloadSpeedNotifier.addListener(_onSpeedChanged);
    AppUpdateService.downloadReceivedBytesNotifier.addListener(_onBytesChanged);
    AppUpdateService.downloadTotalBytesNotifier.addListener(_onBytesChanged);
    AppUpdateService.downloadErrorNotifier.addListener(_onErrorChanged);

    _checkExistingProgress();
  }

  Future<void> _checkExistingProgress() async {
    if (_isDownloading) return;
    final latestVer = widget.updateInfo.latestVersion;
    final expectedBytes = widget.updateInfo.fileSizeBytes;

    final isDone = await AppUpdateService.isApkAlreadyDownloaded(latestVer, expectedBytes);
    if (isDone && mounted) {
      setState(() {
        _isAlreadyComplete = true;
        _progress = 1.0;
        _receivedBytes = expectedBytes ?? 0;
        _totalBytes = expectedBytes ?? 0;
        _statusText = 'Bản cập nhật đã tải xong và sẵn sàng cài đặt';
      });
      return;
    }

    final partialBytes = await AppUpdateService.getExistingPartialBytes(latestVer);
    if (partialBytes > 0 && mounted) {
      setState(() {
        _receivedBytes = partialBytes;
        if (expectedBytes != null && expectedBytes > 0) {
          _totalBytes = expectedBytes;
          _progress = (partialBytes / expectedBytes).clamp(0.0, 1.0);
        }
      });
    }
  }

  @override
  void dispose() {
    AppUpdateService.isDownloadingNotifier.removeListener(_onDownloadStateChanged);
    AppUpdateService.downloadProgressNotifier.removeListener(_onProgressChanged);
    AppUpdateService.downloadStatusNotifier.removeListener(_onStatusChanged);
    AppUpdateService.downloadSpeedNotifier.removeListener(_onSpeedChanged);
    AppUpdateService.downloadReceivedBytesNotifier.removeListener(_onBytesChanged);
    AppUpdateService.downloadTotalBytesNotifier.removeListener(_onBytesChanged);
    AppUpdateService.downloadErrorNotifier.removeListener(_onErrorChanged);
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (mounted) {
      setState(() {
        _isDownloading = AppUpdateService.isDownloadingNotifier.value;
        if (!_isDownloading && AppUpdateService.downloadProgressNotifier.value >= 1.0) {
          _isAlreadyComplete = true;
        }
      });
    }
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {
        _progress = AppUpdateService.downloadProgressNotifier.value;
      });
    }
  }

  void _onStatusChanged() {
    if (mounted) {
      setState(() {
        _statusText = AppUpdateService.downloadStatusNotifier.value;
      });
    }
  }

  void _onSpeedChanged() {
    if (mounted) {
      setState(() {
        _speedText = AppUpdateService.downloadSpeedNotifier.value;
      });
    }
  }

  void _onBytesChanged() {
    if (mounted) {
      setState(() {
        _receivedBytes = AppUpdateService.downloadReceivedBytesNotifier.value;
        _totalBytes = AppUpdateService.downloadTotalBytesNotifier.value;
      });
    }
  }

  void _onErrorChanged() {
    if (mounted) {
      setState(() {
        _errorMessage = AppUpdateService.downloadErrorNotifier.value;
      });
    }
  }

  /// Bảng xác nhận khi người dùng bấm Hủy tải bản cập nhật
  Future<void> _confirmCancel() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isVi ? 'Xác nhận hủy tải' : 'Confirm Cancellation',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc chắn muốn hủy quá trình tải bản cập nhật này không? Mọi tiến trình tải về sẽ bị dừng lại.'
              : 'Are you sure you want to cancel downloading the update? Any download progress will be stopped.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isVi ? 'Tiếp tục tải' : 'Keep Downloading',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              isVi ? 'Hủy tải' : 'Cancel Download',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      AppUpdateService.cancelDownload();
    }
  }

  /// Bảng chẩn đoán và Thử lại khi thao tác tải bản cập nhật bị lỗi
  Future<void> _showRetryDialog(String error) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final liveBase = await AppUpdateService.getLiveServerBaseUrl() ?? 'http://192.168.1.6:5000';

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1E2433) : Colors.white,
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sync_problem_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isVi ? 'Tải cập nhật không thành công' : 'Update Download Failed',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.checklist_rounded, size: 16, color: Colors.blue.shade400),
                      const SizedBox(width: 6),
                      Text(
                        isVi ? 'Bảng kiểm tra sự cố & Thử lại' : 'Troubleshooting Checklist',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVi
                        ? '• Đảm bảo điện thoại và máy tính chạy ZenHome cùng kết nối chung một mạng Wi-Fi.\n'
                          '• Kiểm tra máy chủ ZenHome Server (IP: $liveBase) có đang hoạt động.\n'
                          '• Nếu không tải được tự động trong app, bạn có thể tải trực tiếp file APK qua Trình duyệt.'
                        : '• Ensure phone and ZenHome host are on the same Wi-Fi.\n'
                          '• Check if ZenHome Server (IP: $liveBase) is running.\n'
                          '• If direct in-app download fails, open via Browser to download.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    String targetUrl = widget.updateInfo.downloadUrl;
                    if (widget.updateInfo.directApkUrl != null &&
                        widget.updateInfo.directApkUrl!.trim().isNotEmpty) {
                      targetUrl = widget.updateInfo.directApkUrl!.trim();
                    }
                    AppUpdateService.launchDownloadUrl(targetUrl);
                  },
                  child: Text(isVi ? 'Trình duyệt' : 'Browser', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startDownload();
                  },
                  child: Text(isVi ? 'Thử lại' : 'Retry', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    final updateInfo = widget.updateInfo;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    if (_isAlreadyComplete) {
      final installed = await AppUpdateService.installCompletedApk(updateInfo.latestVersion);
      if (!installed && mounted) {
        setState(() => _isAlreadyComplete = false);
      } else {
        return;
      }
    }

    setState(() {
      _errorMessage = null;
    });

    String targetUrl = updateInfo.downloadUrl;
    if (updateInfo.directApkUrl != null && updateInfo.directApkUrl!.trim().isNotEmpty) {
      final direct = updateInfo.directApkUrl!.trim();
      if (direct.startsWith('http://') || direct.startsWith('https://')) {
        targetUrl = direct;
      } else if (targetUrl.isEmpty) {
        targetUrl = direct;
      }
    }

    final isApkFile = targetUrl.toLowerCase().endsWith('.apk') || targetUrl.contains('/downloads/');

    if (isApkFile) {
      final success = await AppUpdateService.startBackgroundDownload(
        url: targetUrl,
        version: updateInfo.latestVersion,
        expectedTotalBytes: updateInfo.fileSizeBytes,
        title: context.tr('downloading_in_background_title'),
        downloadingText: context.tr('downloading_update'),
        completeText: context.tr('download_complete_body'),
        failedText: context.tr('download_error'),
        openingInstallerText: context.tr('opening_installer'),
      );

      if (!success && mounted) {
        final err = AppUpdateService.downloadErrorNotifier.value ?? context.tr('download_error');
        setState(() {
          _errorMessage = err;
        });
        await _showRetryDialog(err);
      }
    } else {
      final launched = await AppUpdateService.launchDownloadUrl(targetUrl);
      if (!mounted) return;
      if (!launched) {
        final err = isVi ? 'Không thể mở liên kết: $targetUrl' : 'Could not open update link: $targetUrl';
        setState(() {
          _errorMessage = err;
        });
        await _showRetryDialog(err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = widget.updateInfo;
    final currentVersion = widget.currentVersion;
    final currentBuildNumber = widget.currentBuildNumber;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForce = updateInfo.isMustUpdate(currentBuildNumber);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    final title = isVi ? updateInfo.titleVi : updateInfo.titleEn;
    final releaseNotes = isVi ? updateInfo.releaseNotesVi : updateInfo.releaseNotesEn;

    return PopScope(
      canPop: !isForce && !_isDownloading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isDownloading) {
          _confirmCancel();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Gradient Graphic Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isForce
                          ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                          : (isDark
                              ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                              : [const Color(0xFF0F766E), const Color(0xFF14B8A6)]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isForce
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isForce
                              ? context.tr('update_dialog_critical_badge')
                              : context.tr('update_dialog_new_badge'),
                          style: TextStyle(
                            color: isForce ? const Color(0xFFDC2626) : Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Version Comparison Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('current_version'),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'v$currentVersion (+$currentBuildNumber)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.grey.shade400),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  context.tr('latest_version'),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'v${updateInfo.latestVersion} (+${updateInfo.latestBuildNumber})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        context.tr('whats_new_in_release'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Release Notes Container
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF243049) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            releaseNotes,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons or In-App Download Progress
                      if (_isDownloading) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF162032) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E3E5B) : const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2.2),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _statusText.isNotEmpty
                                                ? _statusText
                                                : context.tr('downloading_update'),
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.grey.shade200 : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // BADGE HIỂN THỊ TỐC ĐỘ TẢI (DOWNLOAD SPEED CHIP)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          _speedText.isNotEmpty ? _speedText : '0 KB/s',
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _progress > 0 ? _progress : null,
                                  minHeight: 10,
                                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(_progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                  Text(
                                    _receivedBytes > 0
                                        ? '${(_receivedBytes / 1048576).toStringAsFixed(1)} MB / ${_totalBytes > 0 ? (_totalBytes / 1048576).toStringAsFixed(1) : (updateInfo.fileSizeBytes != null ? (updateInfo.fileSizeBytes! / 1048576).toStringAsFixed(1) : "?")} MB'
                                        : '0.0 MB / ${(updateInfo.fileSizeBytes != null ? (updateInfo.fileSizeBytes! / 1048576).toStringAsFixed(1) : "?")} MB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  side: BorderSide(
                                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                label: Text(
                                  context.tr('btn_download_in_background'),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  showFloatingToast(
                                    context,
                                    context.tr('notification'),
                                    context.tr('downloading_in_background_title'),
                                    isError: false,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                foregroundColor: Colors.redAccent,
                              ),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: Text(
                                isVi ? 'Hủy' : 'Cancel',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _confirmCancel,
                            ),
                          ],
                        ),
                      ] else ...[
                        if (_errorMessage != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C1517) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 8),
                                    Text(
                                      isVi ? 'Không thể tải file tự động' : 'Direct download failed',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.red.shade200 : Colors.red.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            if (!isForce) ...[
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    foregroundColor: Colors.grey.shade500,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(
                                    context.tr('btn_later'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (_errorMessage != null) ...[
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                                  label: Text(
                                    isVi ? 'Trình duyệt' : 'Browser',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () async {
                                    String targetUrl = updateInfo.downloadUrl;
                                    if (updateInfo.directApkUrl != null &&
                                        updateInfo.directApkUrl!.trim().isNotEmpty) {
                                      targetUrl = updateInfo.directApkUrl!.trim();
                                    }
                                    await AppUpdateService.launchDownloadUrl(targetUrl);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              flex: isForce ? 1 : 2,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: isForce ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                ),
                                icon: Icon(
                                  _isAlreadyComplete
                                      ? Icons.install_mobile_rounded
                                      : (_receivedBytes > 0 && !_isDownloading
                                          ? Icons.play_arrow_rounded
                                          : (_errorMessage != null ? Icons.refresh_rounded : Icons.download_rounded)),
                                  size: 20,
                                ),
                                label: Text(
                                  _isAlreadyComplete
                                      ? (isVi ? 'Cài đặt ngay' : 'Install Now')
                                      : (_receivedBytes > 0 && !_isDownloading
                                          ? (isVi ? 'Tiếp tục tải (${(_progress * 100).toInt()}%)' : 'Resume Download (${(_progress * 100).toInt()}%)')
                                          : (_errorMessage != null
                                              ? (isVi ? 'Thử lại' : 'Retry')
                                              : context.tr('btn_update_now'))),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                onPressed: _startDownload,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


