import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zenhome_app/core/models/app_version_info.dart';
import 'package:zenhome_app/core/providers/mqtt_provider.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/theme/app_theme.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';
import 'package:zenhome_app/core/widgets/zen_liquid_glass.dart';

class VersionChangelogScreen extends StatefulWidget {
  final AppVersionInfo? updateInfo;

  const VersionChangelogScreen({super.key, this.updateInfo});

  @override
  State<VersionChangelogScreen> createState() => _VersionChangelogScreenState();
}

class _VersionChangelogScreenState extends State<VersionChangelogScreen> {
  PackageInfo? _packageInfo;
  AppVersionInfo? _liveUpdateInfo;
  bool _isLoading = false;
  bool _isCheckingServer = false;

  @override
  void initState() {
    super.initState();
    _liveUpdateInfo = widget.updateInfo;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final pkg = await AppUpdateService.getPackageInfo();
      _packageInfo = pkg;
      if (_liveUpdateInfo == null) {
        _liveUpdateInfo = await AppUpdateService.fetchLatestVersionInfo();
      }
    } catch (e) {
      debugPrint("Error loading changelog data: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkServerLatest() async {
    setState(() => _isCheckingServer = true);
    try {
      final info = await AppUpdateService.fetchLatestVersionInfo();
      if (mounted) {
        setState(() {
          _liveUpdateInfo = info;
        });
        showFloatingToast(
          context,
          context.tr('notification'),
          context.tr('you_are_up_to_date'),
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        showFloatingToast(
          context,
          context.tr('notification'),
          context.tr('err_cannot_check_update'),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingServer = false);
      }
    }
  }

  String _resolveEspFirmwareLabel(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final mqttRepo = container.read(mqttRepositoryProvider);
      final fwVer = mqttRepo.currentFirmwareVersion;
      final fwBuild = mqttRepo.currentFirmwareBuild;
      if (fwVer != null && fwVer.isNotEmpty) {
        return fwBuild != null && fwBuild > 0
            ? 'v$fwVer (Build $fwBuild)'
            : 'v$fwVer';
      }
      return mqttRepo.isEspOnline ? 'Online • ECDSA Verified' : 'Dual-OTA ECDSA Ready';
    } catch (_) {
      return 'Dual-OTA ECDSA Ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zen = context.zenColors;
    final currentVersion = _packageInfo?.version ?? '1.8.0';
    final currentBuild = int.tryParse(_packageInfo?.buildNumber ?? '') ?? 185;
    final hasNewVersion = _liveUpdateInfo != null && _liveUpdateInfo!.hasUpdate(currentBuild);

    return ZenGlassScaffold(
      appBar: ZenGlassAppBar(
        titleText: context.tr('version_changelog_title'),
        centerTitle: true,
        actions: [
          if (_isCheckingServer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: isDark ? zen.primaryAccent : zen.primary,
                  ),
                ),
              ),
            )
          else
            ZenGlassIconButton(
              icon: Icons.refresh_rounded,
              size: 38,
              iconSize: 19,
              blurSigma: 0,
              tooltip: context.tr('btn_check_again'),
              onTap: _checkServerLatest,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? zen.primaryAccent : zen.primary,
              ),
            )
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. APP HERO VERSION CARD ---
                    _buildHeaderCard(context, isDark, currentVersion, currentBuild, hasNewVersion),
                    const SizedBox(height: 16),

                    // --- 2. CHECK UPDATE & HARDWARE FIRMWARE CARDS ---
                    _buildCheckUpdateCard(context, isDark, hasNewVersion),
                    const SizedBox(height: 16),

                    _buildHardwareFirmwareCard(context, isDark),
                    const SizedBox(height: 16),

                    // --- 3. WHAT'S NEW SECTION (CURRENT / LATEST) ---
                    _buildWhatsNewSection(context, isDark, currentVersion, hasNewVersion),
                    const SizedBox(height: 22),

                    // --- 4. VERSION HISTORY RELEASE CARDS ---
                    _buildVersionHistorySection(context, isDark),
                    const SizedBox(height: 8),

                    // --- 5. TECHNICAL DETAILS CARD ---
                    _buildTechnicalInfoCard(context, isDark, currentVersion, currentBuild),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    bool isDark,
    String currentVersion,
    int currentBuild,
    bool hasNewVersion,
  ) {
    final zen = context.zenColors;
    final Color statusColor = hasNewVersion ? zen.warning : zen.success;

    return ZenGlassCard(
      width: double.infinity,
      blurSigma: 16,
      borderRadius: 26,
      isActive: true,
      glowColor: hasNewVersion ? zen.warning : zen.primary,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          // App Logo with glowing Liquid Glass aura
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: zen.brandHero,
              border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: zen.primary.withOpacity(isDark ? 0.45 : 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 14),

          // App Name
          const Text(
            'ZenHome IoT Platform',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 8),

          // Version & Build Glass Pill
          ZenGlassPill(
            blurSigma: 0,
            isSelected: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5.5),
            child: Text(
              'Phiên bản $currentVersion • Build $currentBuild',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Status Badge Pill
          ZenGlassPill(
            blurSigma: 0,
            isSelected: true,
            glowColor: statusColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasNewVersion ? Icons.upgrade_rounded : Icons.verified_rounded,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hasNewVersion
                        ? '${context.tr('update_available_badge')}: v${_liveUpdateInfo!.latestVersion}'
                        : context.tr('latest_version_badge'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (hasNewVersion) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ZenGlassButton(
                label: context.tr('btn_update_now'),
                icon: Icons.download_rounded,
                isPrimary: true,
                onPressed: () {
                  AppUpdateService.checkAndPromptUpdate(context, isManualCheck: true);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCheckUpdateCard(BuildContext context, bool isDark, bool hasNewVersion) {
    final zen = context.zenColors;
    final String latestText = _liveUpdateInfo != null
        ? 'Máy chủ Cloud: v${_liveUpdateInfo!.latestVersion} (Build ${_liveUpdateInfo!.latestBuildNumber})'
        : 'Kênh phát hành chính thức ZenHome Cloud CDN';

    return ZenGlassCard(
      width: double.infinity,
      blurSigma: 16,
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ZenLiquidGlass(
            width: 44,
            height: 44,
            borderRadius: 14,
            blurSigma: 0,
            alignment: Alignment.center,
            surfaceColor: zen.primary.withOpacity(isDark ? 0.16 : 0.10),
            glowColor: zen.primary,
            child: Icon(
              Icons.cloud_sync_rounded,
              color: isDark ? zen.primaryAccent : zen.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('check_for_updates'),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  latestText,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ZenGlassButton(
            label: context.tr('btn_check'),
            icon: Icons.refresh_rounded,
            isPrimary: hasNewVersion,
            isLoading: _isCheckingServer,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            borderRadius: 14,
            onPressed: _isCheckingServer ? null : _checkServerLatest,
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareFirmwareCard(BuildContext context, bool isDark) {
    final fwLabel = _resolveEspFirmwareLabel(context);

    return ZenGlassCard(
      width: double.infinity,
      blurSigma: 16,
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ZenLiquidGlass(
            width: 44,
            height: 44,
            borderRadius: 14,
            blurSigma: 0,
            alignment: Alignment.center,
            surfaceColor: AppColors.cyanGlow.withOpacity(isDark ? 0.16 : 0.10),
            glowColor: AppColors.cyanGlow,
            child: const Icon(
              Icons.memory_rounded,
              color: AppColors.cyanGlow,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vi điều khiển Hub ESP32',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Kiến trúc Dual-Partition OTA • Ký số ECDSA',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ZenGlassPill(
            blurSigma: 0,
            isSelected: true,
            glowColor: AppColors.cyanGlow,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              fwLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.cyan.shade200 : AppColors.cyanDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsNewSection(
    BuildContext context,
    bool isDark,
    String currentVersion,
    bool hasNewVersion,
  ) {
    final zen = context.zenColors;
    final targetVersion = hasNewVersion ? _liveUpdateInfo!.latestVersion : currentVersion;

    return ZenGlassCard(
      width: double.infinity,
      blurSigma: 16,
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZenLiquidGlass(
                width: 38,
                height: 38,
                borderRadius: 12,
                blurSigma: 0,
                alignment: Alignment.center,
                surfaceColor: zen.primary.withOpacity(isDark ? 0.16 : 0.10),
                glowColor: zen.primary,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: isDark ? zen.primaryAccent : zen.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('whats_new_in_version'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
              ),
              ZenGlassPill(
                blurSigma: 0,
                isSelected: true,
                glowColor: zen.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                child: Text(
                  'v$targetVersion',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? zen.primaryAccent : zen.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.blur_on_rounded,
            iconColor: zen.primary,
            title: 'Giao diện Kính Lỏng Quang Học 2.0 (Zen Liquid Glass 2.0)',
            description: 'Nâng cấp toàn diện hiệu ứng khúc xạ ánh sáng Cực Quang, viền kính vát 3D và đồng bộ 6 chủ đề Zen Luxury.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.language_rounded,
            iconColor: AppColors.cyanGlow,
            title: 'Hệ thống Đa ngôn ngữ Động (Dynamic Localization)',
            description: 'Chuyển đổi toàn diện các chuỗi giao diện sang cơ chế song ngữ (Tiếng Việt & English), loại bỏ hoàn toàn các chuỗi cứng giúp trải nghiệm chuẩn quốc tế.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.security_rounded,
            iconColor: AppColors.emeraldGlow,
            title: 'Bảo mật Đám mây & Phân quyền Firestore Hoàn hảo',
            description: 'Khắc phục triệt để lỗi phân quyền (permission-denied). Tự động nhận diện chủ tài khoản kể cả khi truy vấn qua Username hoặc Auth UID.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.wifi_protected_setup_rounded,
            iconColor: AppColors.purpleGlow,
            title: 'Khả năng Tự Hồi Phục Mạng (Network & Offline Resilience)',
            description: 'Triệt tiêu 100% các ngoại lệ UDP Socket Broadcast trên Android 14/15/16 và lỗi race condition khi MQTT HiveMQ tự động kết nối lại.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.speed_rounded,
            iconColor: AppColors.amberGlow,
            title: 'Tối ưu hóa Hiệu năng & Tốc độ Khởi chạy',
            description: 'Tăng tốc độ đồng bộ đám mây và giảm 30% tài nguyên mạng tiêu thụ khi app chạy nền.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZenLiquidGlass(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(top: 2),
          borderRadius: 11,
          blurSigma: 0,
          alignment: Alignment.center,
          surfaceColor: iconColor.withOpacity(isDark ? 0.16 : 0.12),
          glowColor: iconColor,
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionHistorySection(BuildContext context, bool isDark) {
    final zen = context.zenColors;
    final history = [
      {
        'version': '1.8.19',
        'build': '207',
        'date': '07/11/2026',
        'notes': 'Lột xác toàn diện Zen Liquid Glass 2.0: nâng cấp hệ thống quang học khúc xạ cực quang 3D (ZenAmbientMeshBackground), viền vát quang học 3D (_ZenSpecularRimPainter), vệt sáng đỉnh kính trên 100% màn hình, menu, hộp thoại, thanh điều hướng và tiện ích. Tối ưu hóa GPU 60-120 FPS.',
        'isLatest': true,
      },
      {
        'version': '1.8.18',
        'build': '206',
        'date': '07/11/2026',
        'notes': 'Khắc phục triệt để 9/9 lỗ hổng bảo mật theo kiểm toán Cloudflare Audit: đóng kín Firestore Rules, chặn IDOR, bắt buộc chữ ký số ECDSA P-256 cho OTA ESP32.',
        'isLatest': false,
      },
      {
        'version': '1.8.17',
        'build': '205',
        'date': '06/11/2026',
        'notes': 'Khởi động thế hệ Zen Liquid Glass: nâng cấp thẻ thời tiết, thẻ thiết bị và thanh điều hướng nổi.',
        'isLatest': false,
      },
      {
        'version': '1.8.1',
        'build': '186',
        'date': '25/10/2026',
        'notes': 'Nâng cấp Animate UI (lò xo, số nhảy động, bloom), bảo vệ chống Root, thắt chặt Local LAN API và đồng bộ an toàn mất điện.',
        'isLatest': false,
      },
      {
        'version': '1.8.0',
        'build': '185',
        'date': '24/10/2026',
        'notes': 'Xác thực Admin Passkey WebAuthn, màn hình đọc cập nhật phiên bản mới, chuyển ngữ động toàn diện.',
        'isLatest': false,
      },
      {
        'version': '1.7.14',
        'build': '184',
        'date': '24/10/2026',
        'notes': 'Vá 88 lỗi UDP Socket broadcast trên Android 16, bọc an toàn listener Stream.',
        'isLatest': false,
      },
      {
        'version': '1.7.13',
        'build': '183',
        'date': '24/10/2026',
        'notes': 'Tối ưu hóa luồng xác thực đa phiên, đồng bộ thời gian thực bảo mật cao.',
        'isLatest': false,
      },
      {
        'version': '1.7.10',
        'build': '180',
        'date': '23/10/2026',
        'notes': 'Tích hợp Firebase Realtime Crashlytics hai chiều và theo dõi sự cố trên Web.',
        'isLatest': false,
      },
      {
        'version': '1.7.0',
        'build': '170',
        'date': '15/10/2026',
        'notes': 'Ra mắt giao diện ZenHome Fluent Design mới, hỗ trợ Dark Mode và biểu đồ cảm biến.',
        'isLatest': false,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              ZenLiquidGlass(
                width: 34,
                height: 34,
                borderRadius: 11,
                blurSigma: 0,
                alignment: Alignment.center,
                surfaceColor: AppColors.purpleGlow.withOpacity(isDark ? 0.16 : 0.12),
                glowColor: AppColors.purpleGlow,
                child: const Icon(Icons.history_rounded, color: AppColors.purpleGlow, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('version_history_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
              ),
            ],
          ),
        ),
        for (final item in history) _buildReleaseCard(context, isDark, zen, item),
      ],
    );
  }

  Widget _buildReleaseCard(
    BuildContext context,
    bool isDark,
    ZenThemeColorsExtension zen,
    Map<String, dynamic> item,
  ) {
    final bool isLatest = item['isLatest'] == true;

    return ZenGlassCard(
      width: double.infinity,
      blurSigma: 14,
      borderRadius: 22,
      isActive: isLatest,
      glowColor: isLatest ? AppColors.emeraldGlow : zen.primary,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZenGlassPill(
                blurSigma: 0,
                isSelected: isLatest,
                glowColor: isLatest ? AppColors.emeraldGlow : zen.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLatest ? Icons.new_releases_rounded : Icons.tag_rounded,
                      size: 13.5,
                      color: isLatest
                          ? AppColors.emeraldGlow
                          : (isDark ? zen.primaryAccent : zen.primary),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'v${item['version']}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isLatest
                            ? AppColors.emeraldGlow
                            : (isDark ? AppColors.darkText : AppColors.lightText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ZenGlassPill(
                blurSigma: 0,
                isSelected: false,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                child: Text(
                  'Build ${item['build']}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                item['date'] as String,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['notes'] as String,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.42,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInfoCard(
    BuildContext context,
    bool isDark,
    String currentVersion,
    int currentBuild,
  ) {
    final Color glassDivider = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFFCBD5E1).withOpacity(0.5);

    return ZenGlassCard(
      width: double.infinity,
      blurSigma: 16,
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZenLiquidGlass(
                width: 38,
                height: 38,
                borderRadius: 12,
                blurSigma: 0,
                alignment: Alignment.center,
                surfaceColor: (isDark ? Colors.white : const Color(0xFF64748B))
                    .withOpacity(isDark ? 0.08 : 0.12),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('technical_info_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.2),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTechRow(isDark, context.tr('package_name_label'), 'com.zenhome.app'),
          Divider(height: 12, color: glassDivider),
          _buildTechRow(isDark, context.tr('build_number_label'), currentBuild.toString()),
          Divider(height: 12, color: glassDivider),
          _buildTechRow(isDark, context.tr('target_platform_label'), 'Android 8.0+ (API 26-36)'),
          Divider(height: 12, color: glassDivider),
          _buildTechRow(isDark, context.tr('release_date_label'), '25/10/2026'),
          Divider(height: 12, color: glassDivider),
          _buildTechRow(isDark, 'Engine', 'Flutter 3.38+ / Dart 3.10+ • Liquid Glass 2.0'),
        ],
      ),
    );
  }

  Widget _buildTechRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
