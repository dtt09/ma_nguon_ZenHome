import { db, FieldValue } from './server/core/firebase';

async function updateFirestore() {
  if (!db) {
    console.error('Firestore not initialized!');
    process.exit(1);
  }

  console.log('🔄 Đang cập nhật cấu hình hệ thống trên Cloud Firestore...');

  // 1. Cập nhật app_version lên v1.8.12 (Build 198)
  await db.collection('system_config').doc('app_version').set({
    latestVersion: '1.8.12',
    latestBuildNumber: 198,
    minVersion: '1.8.0',
    minBuildNumber: 180,
    titleVi: 'Bản Cập Nhật ZenHome v1.8.12 (Luxury UI & Instant Sync)',
    titleEn: 'ZenHome Update v1.8.12 (Luxury UI & Instant Sync)',
    releaseNotesVi: '• Khắc phục hoàn toàn lỗi treo nút công tắc khi chuyển đổi qua lại giữa các tab Tiện ích / Cài đặt\n• Đồng bộ phản hồi phần cứng thực tế (chỉ đổi nút khi nhận xác nhận từ ESP32, chống sai lệch trạng thái)\n• Nâng cấp giao diện Luxury UI/UX cao cấp cho Ngữ cảnh, Lịch trình & Bộ thanh trượt đa tầng sang trọng\n• Firmware ESP32 v2.5.6 (Build 200): Tối ưu phần cứng, nhịp tim Heartbeat 15s, triệt tiêu log spam và tự động ngắt kết nối an toàn khi mất điện',
    releaseNotesEn: '• Completely fixed switch freezing when switching between tabs\n• Strict physical hardware state confirmation before switch toggle\n• Luxury UI/UX overhaul for Scenes, Schedules, and Multi-layer Glow Sliders\n• ESP32 Firmware v2.5.6 (Build 200): 15s Heartbeat, rate-limited logging, zero log spam, and power outage safety',
    downloadUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest',
    directApkUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    isForceUpdate: false,
    fileSizeBytes: 72226547,
    sha256: '75F35E85E150411EDEC21022C5F356B125E73480CEFAFA3340E60FDE65E09D10',
    publishedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/app_version -> v1.8.12 (Build 198)');

  // 2. Cập nhật esp32_firmware lên v2.5.6 (Build 200)
  await db.collection('system_config').doc('esp32_firmware').set({
    version: '2.5.6',
    buildNumber: 200,
    directUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin',
    fileSizeBytes: 1380720,
    sha256: '6BA5CFB759F9132EA868282F822A9D8E9FB63AA471824C73B803EBF26DF52C19',
    exists: true,
    changelog: 'Bản cập nhật v2.5.6 (Build 200): Nhịp tim Heartbeat 15s, rate-limit log spam, bộ lọc dwell-time tiếp điểm rơ-le, xác thực User-MAC Firestore chuẩn hóa',
    lastDeployedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/esp32_firmware -> v2.5.6 (Build 200)');

  process.exit(0);
}

updateFirestore().catch(err => {
  console.error('Lỗi cập nhật Firestore:', err);
  process.exit(1);
});
