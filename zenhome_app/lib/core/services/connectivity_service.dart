import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';

/// Provider theo dõi trạng thái kết nối Internet thực tế (true: có mạng, false: mất mạng)
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  Timer? _timer;
  bool _isChecking = false;

  ConnectivityNotifier() : super(true) {
    // Kiểm tra ngay khi khởi tạo
    checkConnectivity();
    // Định kỳ kiểm tra kết nối mạng mỗi 4 giây
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      checkConnectivity();
    });
  }

  Future<bool> checkConnectivity() async {
    if (_isChecking) return state;
    _isChecking = true;

    bool hasInternet = false;
    try {
      // 1. Thử kết nối TCP Socket tới Cloudflare DNS (1.1.1.1:53) hoặc Google DNS (8.8.8.8:53)
      final socket = await Socket.connect('1.1.1.1', 53, timeout: const Duration(milliseconds: 2000))
          .catchError((_) => Socket.connect('8.8.8.8', 53, timeout: const Duration(milliseconds: 2000)));
      socket.destroy();
      hasInternet = true;
    } catch (_) {
      try {
        // Dự phòng: DNS Lookup
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(milliseconds: 2000));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          hasInternet = true;
        }
      } catch (_) {
        hasInternet = false;
      }
    } finally {
      _isChecking = false;
    }

    if (mounted && state != hasInternet) {
      state = hasInternet;
    }
    return hasInternet;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Widget bọc toàn bộ ứng dụng (MaterialApp.builder)
/// Tự động hiển thị thanh thông báo trạng thái mạng mượt mà, sang trọng thay vì màn hình trắng xóa
class ConnectivityBannerWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityBannerWrapper({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBannerWrapper> createState() => _ConnectivityBannerWrapperState();
}

class _ConnectivityBannerWrapperState extends ConsumerState<ConnectivityBannerWrapper> {
  bool _showRestoredBanner = false;
  Timer? _restoredTimer;
  bool _wasOffline = false;

  @override
  void dispose() {
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Khi vừa khôi phục kết nối từ trạng thái offline -> hiện banner xanh trong 2.5s
    if (isOnline && _wasOffline) {
      _wasOffline = false;
      _showRestoredBanner = true;
      _restoredTimer?.cancel();
      _restoredTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showRestoredBanner = false);
      });
    } else if (!isOnline) {
      _wasOffline = true;
    }

    return Stack(
      children: [
        widget.child,

        // 1. Banner MẤT KẾT NỐI INTERNET (Animated Slide-down)
        if (!isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F1612) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.amberGlow.withOpacity(0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberGlow.withOpacity(isDark ? 0.25 : 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.amberGlow.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            color: AppColors.amberGlow,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('no_internet_title'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('no_internet_banner'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nút Thử lại
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            ref.read(connectivityProvider.notifier).checkConnectivity();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('btn_retry'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 2. Banner ĐÃ KHÔI PHỤC KẾT NỐI (Tự tắt sau 2.5s)
        if (_showRestoredBanner && isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandHero,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('internet_restored_banner'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Màn hình Offline toàn diện (Hiển thị khi cần thông báo rõ ràng thay vì để trắng xóa)
class NoInternetScreen extends ConsumerStatefulWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onContinueOffline;

  const NoInternetScreen({
    super.key,
    this.onRetry,
    this.onContinueOffline,
  });

  @override
  ConsumerState<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends ConsumerState<NoInternetScreen> {
  bool _isChecking = false;

  void _handleRetry() async {
    setState(() => _isChecking = true);
    final hasNet = await ref.read(connectivityProvider.notifier).checkConnectivity();
    setState(() => _isChecking = false);
    if (hasNet) {
      widget.onRetry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Glowing
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.amberGlow.withOpacity(0.2),
                          AppColors.amberGlow.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amberGlow.withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberGlow.withOpacity(0.2),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: AppColors.amberGlow,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    context.tr('no_internet_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  Text(
                    context.tr('no_internet_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: mutedColor,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Nút Thử lại
                  Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandHero,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isChecking ? null : _handleRetry,
                      child: _isChecking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr('btn_retry'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Nút Tiếp tục ngoại tuyến
                  if (widget.onContinueOffline != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: widget.onContinueOffline,
                      child: Text(
                        context.tr('btn_continue_offline'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
