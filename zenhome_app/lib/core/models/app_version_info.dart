class AppVersionInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String minVersion;
  final int minBuildNumber;
  final String titleVi;
  final String titleEn;
  final String releaseNotesVi;
  final String releaseNotesEn;
  final String downloadUrl;
  final String? directApkUrl;
  final bool isForceUpdate;
  final String? publishedAt;
  final int? fileSizeBytes;

  AppVersionInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minVersion,
    required this.minBuildNumber,
    required this.titleVi,
    required this.titleEn,
    required this.releaseNotesVi,
    required this.releaseNotesEn,
    required this.downloadUrl,
    this.directApkUrl,
    this.isForceUpdate = false,
    this.publishedAt,
    this.fileSizeBytes,
  });

  bool hasUpdate(int currentBuildNumber) {
    return latestBuildNumber > currentBuildNumber;
  }

  bool isMustUpdate(int currentBuildNumber) {
    return isForceUpdate || (currentBuildNumber < minBuildNumber);
  }

  AppVersionInfo copyWith({
    String? latestVersion,
    int? latestBuildNumber,
    String? minVersion,
    int? minBuildNumber,
    String? titleVi,
    String? titleEn,
    String? releaseNotesVi,
    String? releaseNotesEn,
    String? downloadUrl,
    String? directApkUrl,
    bool? isForceUpdate,
    String? publishedAt,
    int? fileSizeBytes,
  }) {
    return AppVersionInfo(
      latestVersion: latestVersion ?? this.latestVersion,
      latestBuildNumber: latestBuildNumber ?? this.latestBuildNumber,
      minVersion: minVersion ?? this.minVersion,
      minBuildNumber: minBuildNumber ?? this.minBuildNumber,
      titleVi: titleVi ?? this.titleVi,
      titleEn: titleEn ?? this.titleEn,
      releaseNotesVi: releaseNotesVi ?? this.releaseNotesVi,
      releaseNotesEn: releaseNotesEn ?? this.releaseNotesEn,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      directApkUrl: directApkUrl ?? this.directApkUrl,
      isForceUpdate: isForceUpdate ?? this.isForceUpdate,
      publishedAt: publishedAt ?? this.publishedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: json['latestVersion']?.toString() ?? '1.8.11',
      latestBuildNumber: int.tryParse(json['latestBuildNumber']?.toString() ?? '') ?? 197,
      minVersion: json['minVersion']?.toString() ?? '1.8.0',
      minBuildNumber: int.tryParse(json['minBuildNumber']?.toString() ?? '') ?? 180,
      titleVi: json['titleVi']?.toString() ?? 'Bản Cập Nhật ZenHome v1.8.11',
      titleEn: json['titleEn']?.toString() ?? 'New ZenHome Update v1.8.11',
      releaseNotesVi: json['releaseNotesVi']?.toString() ??
          '• Đồng bộ tải trực tiếp toàn cầu qua GitHub Releases CDN\n• Tối ưu hóa OTA Hub ESP32 không phụ thuộc IP máy chủ\n• Phản hồi công tắc tức thời 0ms & triệt tiêu hoàn toàn log thừa',
      releaseNotesEn: json['releaseNotesEn']?.toString() ??
          '• Global direct download via GitHub Releases CDN\n• Autonomous ESP32 OTA without local server\n• 0ms instant switch reaction & zero log spam',
      downloadUrl: json['downloadUrl']?.toString() ??
          'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest',
      directApkUrl: json['directApkUrl']?.toString() ??
          'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
      isForceUpdate: json['isForceUpdate'] == true,
      publishedAt: json['publishedAt']?.toString(),
      fileSizeBytes: int.tryParse(json['fileSizeBytes']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latestVersion': latestVersion,
      'latestBuildNumber': latestBuildNumber,
      'minVersion': minVersion,
      'minBuildNumber': minBuildNumber,
      'titleVi': titleVi,
      'titleEn': titleEn,
      'releaseNotesVi': releaseNotesVi,
      'releaseNotesEn': releaseNotesEn,
      'downloadUrl': downloadUrl,
      'directApkUrl': directApkUrl,
      'isForceUpdate': isForceUpdate,
      'publishedAt': publishedAt,
      'fileSizeBytes': fileSizeBytes,
    };
  }
}
