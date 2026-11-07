import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zenhome_app/core/models/app_version_info.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';
import 'package:zenhome_app/features/settings/ui/version_changelog_screen.dart';

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

    final isDone =
        await AppUpdateService.isApkAlreadyDownloaded(latestVer, expectedBytes);
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

    final partialBytes =
        await AppUpdateService.getExistingPartialBytes(latestVer);
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
    AppUpdateService.isDownloadingNotifier
        .removeListener(_onDownloadStateChanged);
    AppUpdateService.downloadProgressNotifier
        .removeListener(_onProgressChanged);
    AppUpdateService.downloadStatusNotifier.removeListener(_onStatusChanged);
    AppUpdateService.downloadSpeedNotifier.removeListener(_onSpeedChanged);
    AppUpdateService.downloadReceivedBytesNotifier
        .removeListener(_onBytesChanged);
    AppUpdateService.downloadTotalBytesNotifier.removeListener(_onBytesChanged);
    AppUpdateService.downloadErrorNotifier.removeListener(_onErrorChanged);
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (mounted) {
      setState(() {
        _isDownloading = AppUpdateService.isDownloadingNotifier.value;
        if (!_isDownloading &&
            AppUpdateService.downloadProgressNotifier.value >= 1.0) {
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

  /// Bảng Kính Lỏng xác nhận khi người dùng bấm Hủy tải bản cập nhật
  Future<void> _confirmCancel() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;

    final shouldCancel = await showZenGlassDialog<bool>(
      context: context,
      barrierDismissible: false,
      accentColor: zen.warning,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: zen.warning.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: zen.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isVi ? 'Xác nhận hủy tải' : 'Confirm Cancellation',
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isVi
                ? 'Bạn có chắc chắn muốn hủy quá trình tải bản cập nhật này không? Mọi tiến trình tải về sẽ bị dừng lại.'
                : 'Are you sure you want to cancel downloading the update? Any download progress will be stopped.',
            style: TextStyle(
              fontSize: 13.8,
              height: 1.45,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ZenGlassButton(
                  label: isVi ? 'Tiếp tục tải' : 'Keep Downloading',
                  isPrimary: false,
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ZenGlassButton(
                  label: isVi ? 'Hủy tải' : 'Cancel',
                  isDanger: true,
                  onPressed: () => Navigator.of(ctx).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldCancel == true) {
      AppUpdateService.cancelDownload();
    }
  }

  /// Bảng Kính Lỏng chẩn đoán và Thử lại khi thao tác tải bản cập nhật bị lỗi
  Future<void> _showRetryDialog(String error) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final liveBase =
        await AppUpdateService.getLiveServerBaseUrl() ?? 'http://192.168.1.6:5000';

    if (!mounted) return;

    await showZenGlassDialog(
      context: context,
      barrierDismissible: true,
      accentColor: zen.danger,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: zen.danger.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.sync_problem_rounded,
                  color: zen.danger,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isVi
                      ? 'Tải cập nhật không thành công'
                      : 'Update Download Failed',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            error,
            style: TextStyle(
              fontSize: 12.8,
              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ZenLiquidGlass(
            blurSigma: 0,
            borderRadius: 16,
            padding: const EdgeInsets.all(12),
            surfaceColor: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.65),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      size: 16,
                      color: context.zenColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVi
                          ? 'Bảng kiểm tra sự cố & Thử lại'
                          : 'Troubleshooting Checklist',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? context.zenColors.primaryAccent
                            : context.zenColors.primary,
                      ),
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
                    fontSize: 11.8,
                    height: 1.45,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ZenGlassButton(
                  label: isVi ? 'Trình duyệt' : 'Browser',
                  icon: Icons.open_in_browser_rounded,
                  isPrimary: false,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    String targetUrl = widget.updateInfo.downloadUrl;
                    if (widget.updateInfo.directApkUrl != null &&
                        widget.updateInfo.directApkUrl!.trim().isNotEmpty) {
                      targetUrl = widget.updateInfo.directApkUrl!.trim();
                    }
                    AppUpdateService.launchDownloadUrl(targetUrl);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ZenGlassButton(
                  label: isVi ? 'Thử lại' : 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _startDownload();
                  },
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
      final installed =
          await AppUpdateService.installCompletedApk(updateInfo.latestVersion);
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
    if (updateInfo.directApkUrl != null &&
        updateInfo.directApkUrl!.trim().isNotEmpty) {
      final direct = updateInfo.directApkUrl!.trim();
      if (direct.startsWith('http://') || direct.startsWith('https://')) {
        targetUrl = direct;
      } else if (targetUrl.isEmpty) {
        targetUrl = direct;
      }
    }

    final isApkFile =
        targetUrl.toLowerCase().endsWith('.apk') || targetUrl.contains('/downloads/');

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
        final err = AppUpdateService.downloadErrorNotifier.value ??
            context.tr('download_error');
        setState(() {
          _errorMessage = err;
        });
        await _showRetryDialog(err);
      }
    } else {
      final launched = await AppUpdateService.launchDownloadUrl(targetUrl);
      if (!mounted) return;
      if (!launched) {
        final err = isVi
            ? 'Không thể mở liên kết: $targetUrl'
            : 'Could not open update link: $targetUrl';
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
    final zen = context.zenColors;
    final isForce = updateInfo.isMustUpdate(currentBuildNumber);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    final title = isVi ? updateInfo.titleVi : updateInfo.titleEn;
    final releaseNotes =
        isVi ? updateInfo.releaseNotesVi : updateInfo.releaseNotesEn;
    final Color accentColor = isForce ? zen.danger : zen.primary;

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
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ZenGlassDialogSurface(
          maxWidth: 420,
          accentColor: accentColor,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Liquid Luminous Banner
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: isForce
                      ? const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : zen.brandHero,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.38),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: Colors.white,
                        size: 35,
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isForce
                            ? Colors.white
                            : Colors.white.withOpacity(0.24),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isForce
                            ? context.tr('update_dialog_critical_badge')
                            : context.tr('update_dialog_new_badge'),
                        style: TextStyle(
                          color: isForce
                              ? const Color(0xFFDC2626)
                              : Colors.white,
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
                        fontWeight: FontWeight.w800,
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
                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      surfaceColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.white.withOpacity(0.68),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('current_version'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'v$currentVersion (+$currentBuildNumber)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                context.tr('latest_version'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'v${updateInfo.latestVersion} (+${updateInfo.latestBuildNumber})',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? zen.primaryAccent
                                      : zen.primary,
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
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),

                    ZenLiquidGlass(
                      blurSigma: 0,
                      borderRadius: 16,
                      padding: const EdgeInsets.all(12),
                      surfaceColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.62),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 155),
                        child: SizedBox(
                          width: double.infinity,
                          child: SingleChildScrollView(
                            child: Text(
                              releaseNotes,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.5,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (_isDownloading) ...[
                      ZenLiquidGlass(
                        blurSigma: 0,
                        borderRadius: 20,
                        glowColor: zen.primary,
                        padding: const EdgeInsets.all(16),
                        surfaceColor: isDark
                            ? Colors.white.withOpacity(0.07)
                            : Colors.white.withOpacity(0.70),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: isDark
                                              ? zen.primaryAccent
                                              : zen.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _statusText.isNotEmpty
                                              ? _statusText
                                              : context.tr('downloading_update'),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark
                                                ? AppColors.darkText
                                                : AppColors.lightText,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: zen.brandHero,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.bolt_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _speedText.isNotEmpty
                                            ? _speedText
                                            : '0 KB/s',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
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
                                backgroundColor: isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.08),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(zen.primary),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(_progress * 100).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? zen.primaryAccent
                                        : zen.primary,
                                  ),
                                ),
                                Text(
                                  _receivedBytes > 0
                                      ? '${(_receivedBytes / 1048576).toStringAsFixed(1)} MB / ${_totalBytes > 0 ? (_totalBytes / 1048576).toStringAsFixed(1) : (updateInfo.fileSizeBytes != null ? (updateInfo.fileSizeBytes! / 1048576).toStringAsFixed(1) : "?")} MB'
                                      : '0.0 MB / ${(updateInfo.fileSizeBytes != null ? (updateInfo.fileSizeBytes! / 1048576).toStringAsFixed(1) : "?")} MB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextMuted
                                        : AppColors.lightTextMuted,
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
                            child: ZenGlassButton(
                              label: context.tr('btn_download_in_background'),
                              icon: Icons.arrow_downward_rounded,
                              isPrimary: false,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
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
                          ZenGlassButton(
                            label: isVi ? 'Hủy' : 'Cancel',
                            icon: Icons.close_rounded,
                            isPrimary: false,
                            isDanger: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            onPressed: _confirmCancel,
                          ),
                        ],
                      ),
                    ] else ...[
                      if (_errorMessage != null) ...[
                        ZenLiquidGlass(
                          blurSigma: 0,
                          borderRadius: 16,
                          glowColor: zen.danger,
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(14),
                          surfaceColor: zen.danger
                              .withOpacity(isDark ? 0.14 : 0.08),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: zen.danger,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isVi
                                        ? 'Không thể tải file tự động'
                                        : 'Direct download failed',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: zen.danger,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.red.shade200
                                      : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Center(
                        child: ZenGlassPill(
                          blurSigma: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VersionChangelogScreen(
                                  updateInfo: updateInfo,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.article_rounded,
                                size: 15,
                                color:
                                    isDark ? zen.primaryAccent : zen.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('version_changelog_title'),
                                style: TextStyle(
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark ? zen.primaryAccent : zen.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (!isForce) ...[
                            Expanded(
                              child: ZenGlassButton(
                                label: context.tr('btn_later'),
                                isPrimary: false,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (_errorMessage != null) ...[
                            Expanded(
                              child: ZenGlassButton(
                                label: isVi ? 'Trình duyệt' : 'Browser',
                                icon: Icons.open_in_browser_rounded,
                                isPrimary: false,
                                onPressed: () async {
                                  String targetUrl = updateInfo.downloadUrl;
                                  if (updateInfo.directApkUrl != null &&
                                      updateInfo.directApkUrl!
                                          .trim()
                                          .isNotEmpty) {
                                    targetUrl =
                                        updateInfo.directApkUrl!.trim();
                                  }
                                  await AppUpdateService.launchDownloadUrl(
                                    targetUrl,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            flex: isForce ? 1 : 2,
                            child: ZenGlassButton(
                              label: _isAlreadyComplete
                                  ? (isVi ? 'Cài đặt ngay' : 'Install Now')
                                  : (_receivedBytes > 0 && !_isDownloading
                                      ? (isVi
                                          ? 'Tiếp tục (${(_progress * 100).toInt()}%)'
                                          : 'Resume (${(_progress * 100).toInt()}%)')
                                      : (_errorMessage != null
                                          ? (isVi ? 'Thử lại' : 'Retry')
                                          : context.tr('btn_update_now'))),
                              icon: _isAlreadyComplete
                                  ? Icons.install_mobile_rounded
                                  : (_receivedBytes > 0 && !_isDownloading
                                      ? Icons.play_arrow_rounded
                                      : (_errorMessage != null
                                          ? Icons.refresh_rounded
                                          : Icons.download_rounded)),
                              isDanger: isForce,
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
    );
  }
}
