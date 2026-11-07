import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

/// Provider theo dõi trạng thái kết nối Internet thực tế (true: có mạng, false: mất mạng)
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
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
      final socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(milliseconds: 2000),
      ).catchError(
        (_) => Socket.connect(
          '8.8.8.8',
          53,
          timeout: const Duration(milliseconds: 2000),
        ),
      );
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
/// Tự động hiển thị thanh thông báo Kính Lỏng trạng thái mạng mượt mà
class ConnectivityBannerWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const ConnectivityBannerWrapper({super.key, required this.child});

  @override
  ConsumerState<ConnectivityBannerWrapper> createState() =>
      _ConnectivityBannerWrapperState();
}

class _ConnectivityBannerWrapperState
    extends ConsumerState<ConnectivityBannerWrapper> {
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
    final zen = context.zenColors;

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

        // 1. Banner KÍNH LỎNG MẤT KẾT NỐI INTERNET
        if (!isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: ZenLiquidGlass(
                    borderRadius: 20,
                    blurSigma: 22,
                    glowColor: AppColors.amberGlow,
                    rimWidth: 1.3,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    surfaceColor: isDark
                        ? const Color(0xFF1A140E).withOpacity(0.74)
                        : const Color(0xFFFFFBEB).withOpacity(0.84),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.amberGlow.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.amberGlow.withOpacity(0.42),
                            ),
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
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.amber.shade200
                                      : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('no_internet_banner'),
                                style: TextStyle(
                                  fontSize: 11.2,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ZenGlassPill(
                          blurSigma: 0,
                          isSelected: true,
                          glowColor: AppColors.amberGlow,
                          customGradient: const LinearGradient(
                            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          borderRadius: 12,
                          onTap: () {
                            ref
                                .read(connectivityProvider.notifier)
                                .checkConnectivity();
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // 2. Banner KÍNH LỎNG ĐÃ KHÔI PHỤC KẾT NỐI (Tự tắt sau 2.5s)
        if (_showRestoredBanner && isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Material(
                  color: Colors.transparent,
                  child: ZenLiquidGlass(
                    borderRadius: 20,
                    blurSigma: 22,
                    glowColor: AppColors.emeraldGlow,
                    rimWidth: 1.3,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    surfaceColor: isDark
                        ? const Color(0xFF0A211D).withOpacity(0.76)
                        : Colors.white.withOpacity(0.84),
                    customGradient: LinearGradient(
                      colors: [
                        zen.primary.withOpacity(isDark ? 0.55 : 0.85),
                        AppColors.emeraldGlow.withOpacity(isDark ? 0.45 : 0.80),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('internet_restored_banner'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
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

/// Màn hình Offline toàn diện với Nền Cực Quang & Thẻ Kính Lỏng
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
    final hasNet =
        await ref.read(connectivityProvider.notifier).checkConnectivity();
    if (mounted) {
      setState(() => _isChecking = false);
    }
    if (hasNet) {
      widget.onRetry?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final mutedColor =
        isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return ZenGlassScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26.0),
            child: ZenGlassCard(
              borderRadius: 30,
              blurSigma: 22,
              isActive: true,
              glowColor: AppColors.amberGlow,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.amberGlow.withOpacity(0.24),
                          AppColors.amberGlow.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.amberGlow.withOpacity(0.45),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberGlow.withOpacity(0.24),
                          blurRadius: 26,
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
                  Text(
                    context.tr('no_internet_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('no_internet_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: mutedColor,
                      height: 1.48,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ZenGlassButton(
                      label: context.tr('btn_retry'),
                      icon: Icons.refresh_rounded,
                      isLoading: _isChecking,
                      onPressed: _isChecking ? null : _handleRetry,
                    ),
                  ),
                  if (widget.onContinueOffline != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ZenGlassButton(
                        label: context.tr('btn_continue_offline'),
                        isPrimary: false,
                        onPressed: widget.onContinueOffline,
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
