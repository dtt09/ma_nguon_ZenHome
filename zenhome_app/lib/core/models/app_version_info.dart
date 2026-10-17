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
      latestVersion: json['latestVersion']?.toString() ?? '1.4.0',
      latestBuildNumber: int.tryParse(json['latestBuildNumber']?.toString() ?? '') ?? 140,
      minVersion: json['minVersion']?.toString() ?? '1.3.0',
      minBuildNumber: int.tryParse(json['minBuildNumber']?.toString() ?? '') ?? 130,
      titleVi: json['titleVi']?.toString() ?? 'Bản Cập Nhật ZenHome Mới',
      titleEn: json['titleEn']?.toString() ?? 'New ZenHome Update',
      releaseNotesVi: json['releaseNotesVi']?.toString() ??
          '• Đồng bộ dữ liệu Firestore thời gian thực 100%\n• Đăng nhập siêu tốc và mượt mà\n• Nâng cấp giao diện RESTful API mới\n• Tối ưu hóa hiệu năng và sửa lỗi',
      releaseNotesEn: json['releaseNotesEn']?.toString() ??
          '• 100% Realtime Firestore synchronization\n• Superfast and responsive login flow\n• Revamped RESTful API Console\n• Performance optimizations and bug fixes',
      downloadUrl: json['downloadUrl']?.toString() ??
          'https://github.com/dtthuat/zenhome/releases/latest',
      directApkUrl: json['directApkUrl']?.toString(),
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
