import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zenhome_app/core/models/app_version_info.dart';
import 'package:zenhome_app/core/services/app_update_service.dart';
import 'package:zenhome_app/core/utils/localization_extension.dart';
import 'package:zenhome_app/core/utils/toast_helper.dart';

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentVersion = _packageInfo?.version ?? '1.8.0';
    final currentBuild = int.tryParse(_packageInfo?.buildNumber ?? '') ?? 185;
    final hasNewVersion = _liveUpdateInfo != null && _liveUpdateInfo!.hasUpdate(currentBuild);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          context.tr('version_changelog_title'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isCheckingServer
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: context.tr('btn_check_again'),
            onPressed: _isCheckingServer ? null : _checkServerLatest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. HERO HEADER CARD ---
                  _buildHeaderCard(isDark, currentVersion, currentBuild, hasNewVersion),
                  const SizedBox(height: 16),

                  // --- 2. WHAT'S NEW SECTION (CURRENT / LATEST) ---
                  _buildWhatsNewSection(isDark, currentVersion, hasNewVersion),
                  const SizedBox(height: 16),

                  // --- 3. VERSION HISTORY TIMELINE ---
                  _buildVersionHistorySection(isDark),
                  const SizedBox(height: 16),

                  // --- 4. TECHNICAL DETAILS CARD ---
                  _buildTechnicalInfoCard(isDark, currentVersion, currentBuild),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(bool isDark, String currentVersion, int currentBuild, bool hasNewVersion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [Colors.white, const Color(0xFFF1F5F9)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        children: [
          // App Logo with glowing border
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.35),
                  blurRadius: 18,
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),

          // Version & Build Pill
          Text(
            'Phiên bản $currentVersion (Build $currentBuild)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),

          // Status Badge
          if (hasNewVersion)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.upgrade_rounded, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  Text(
                    '${context.tr('update_available_badge')}: v${_liveUpdateInfo!.latestVersion}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('latest_version_badge'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),

          if (hasNewVersion) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                onPressed: () {
                  AppUpdateService.checkAndPromptUpdate(context, isManualCheck: true);
                },
                icon: const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  context.tr('btn_update_now'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWhatsNewSection(bool isDark, String currentVersion, bool hasNewVersion) {
    final targetVersion = hasNewVersion ? _liveUpdateInfo!.latestVersion : currentVersion;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${context.tr('whats_new_in_version')} $targetVersion',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.language_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: 'Hệ thống Đa ngôn ngữ Động (Dynamic Localization)',
            description: 'Chuyển đổi toàn diện các chuỗi giao diện sang cơ chế song ngữ (Tiếng Việt & English), loại bỏ hoàn toàn các chuỗi cứng giúp trải nghiệm chuẩn quốc tế.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Bảo mật Đám mây & Phân quyền Firestore Hoàn hảo',
            description: 'Khắc phục triệt để lỗi phân quyền (permission-denied). Tự động nhận diện chủ tài khoản kể cả khi truy vấn qua Username hoặc Auth UID.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.wifi_protected_setup_rounded,
            iconColor: const Color(0xFF6366F1),
            title: 'Khả năng Tự Hồi Phục Mạng (Network & Offline Resilience)',
            description: 'Triệt tiêu 100% các ngoại lệ UDP Socket Broadcast trên Android 14/15/16 và lỗi race condition khi MQTT HiveMQ tự động kết nối lại.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.article_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: 'Màn hình Nhật ký Cập nhật Chi tiết',
            description: 'Bổ sung giao diện chuyên dụng để bạn dễ dàng tra cứu chi tiết những tính năng mới và lịch sử phát triển của ứng dụng.',
          ),
          const SizedBox(height: 12),

          _buildFeatureItem(
            isDark: isDark,
            icon: Icons.speed_rounded,
            iconColor: const Color(0xFFEC4899),
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
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionHistorySection(bool isDark) {
    final history = [
      {
        'version': '1.8.1',
        'build': '186',
        'date': '25/10/2026',
        'notes': 'Nâng cấp toàn diện Animate UI (lò xo, số nhảy động, bloom), bảo vệ chống Root, thắt chặt Local LAN API và đồng bộ an toàn mất điện.',
        'isLatest': true,
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('version_history_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          for (int i = 0; i < history.length; i++) ...[
            _buildHistoryItem(isDark, history[i], isLast: i == history.length - 1),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem(bool isDark, Map<String, dynamic> item, {required bool isLast}) {
    final isLatest = item['isLatest'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLatest ? const Color(0xFF10B981) : Colors.grey.shade400,
                  border: Border.all(
                    color: isLatest ? const Color(0xFF10B981).withOpacity(0.3) : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 48,
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'v${item['version']} (Build ${item['build']})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isLatest ? const Color(0xFF10B981) : null,
                      ),
                    ),
                    Text(
                      item['date'] as String,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item['notes'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInfoCard(bool isDark, String currentVersion, int currentBuild) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF64748B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('technical_info_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildTechRow(isDark, context.tr('package_name_label'), 'com.zenhome.app'),
          _buildTechRow(isDark, context.tr('build_number_label'), currentBuild.toString()),
          _buildTechRow(isDark, context.tr('target_platform_label'), 'Android 8.0+ (API 26-36)'),
          _buildTechRow(isDark, context.tr('release_date_label'), '24/10/2026'),
          _buildTechRow(isDark, 'Engine', 'Flutter 3.38+ / Dart 3.10+'),
        ],
      ),
    );
  }

  Widget _buildTechRow(bool isDark, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
