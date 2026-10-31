import { db, FieldValue } from './server/core/firebase';

async function updateFirestore() {
  if (!db) {
    console.error('Firestore not initialized!');
    process.exit(1);
  }

  console.log('🔄 Đang cập nhật cấu hình hệ thống trên Cloud Firestore...');

  // 1. Cập nhật app_version lên v1.8.11 (Build 197)
  await db.collection('system_config').doc('app_version').set({
    latestVersion: '1.8.11',
    latestBuildNumber: 197,
    minVersion: '1.8.0',
    minBuildNumber: 180,
    titleVi: 'Bản Cập Nhật ZenHome v1.8.11 (Global Sync)',
    titleEn: 'ZenHome Update v1.8.11 (Global Sync)',
    releaseNotesVi: '• Đồng bộ tải trực tiếp toàn cầu qua GitHub Releases CDN\n• Tối ưu hóa OTA Hub ESP32 không phụ thuộc IP máy chủ\n• Phản hồi công tắc tức thời 0ms & triệt tiêu hoàn toàn log thừa',
    releaseNotesEn: '• Global direct download via GitHub Releases CDN\n• Autonomous ESP32 OTA without local server\n• 0ms instant switch reaction & zero log spam',
    downloadUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest',
    directApkUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    isForceUpdate: false,
    publishedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/app_version -> v1.8.11 (Build 197)');

  // 2. Cập nhật esp32_firmware lên v2.5.5 (Build 199)
  await db.collection('system_config').doc('esp32_firmware').set({
    version: '2.5.5',
    buildNumber: 199,
    directUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin',
    fileSizeBytes: 1380048,
    sha256: '3B4F069E0A74D34C6E38BF3037EB329F5DCAF32A0F90391F8722D0AE3D0E4F4D',
    exists: true,
    changelog: 'Bản cập nhật v2.5.5: Nạp OTA độc lập qua GitHub Releases CDN, wildcard MQTT OTA topic, triệt tiêu log spam',
    lastDeployedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/esp32_firmware -> v2.5.5 (Build 199)');

  process.exit(0);
}

updateFirestore().catch(err => {
  console.error('Lỗi cập nhật Firestore:', err);
  process.exit(1);
});
