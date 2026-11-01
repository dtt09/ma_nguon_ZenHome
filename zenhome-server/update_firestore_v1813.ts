import { db, FieldValue } from './server/core/firebase';

async function updateFirestore() {
  if (!db) {
    console.error('Firestore not initialized!');
    process.exit(1);
  }

  console.log('🔄 Đang cập nhật cấu hình hệ thống trên Cloud Firestore cho phiên bản mới v1.8.13...');

  // 1. Cập nhật app_version lên v1.8.13 (Build 199)
  await db.collection('system_config').doc('app_version').set({
    latestVersion: '1.8.13',
    latestBuildNumber: 199,
    minVersion: '1.8.0',
    minBuildNumber: 180,
    titleVi: 'Bản Cập Nhật ZenHome v1.8.13 (Luxury Glassmorphism & Fast Switch)',
    titleEn: 'ZenHome Update v1.8.13 (Luxury Glassmorphism & Fast Switch)',
    releaseNotesVi: '• Khắc phục triệt để lỗi liên kết số điện thoại ("không tra cứu được dữ liệu") bằng xác thực Firebase Auth nguyên tử\n• Thiết kế lại toàn bộ hệ thống thông báo thành công / thất bại sang phong cách ZenHome Luxury Glassmorphism đẳng cấp (loại bỏ ZaloPay cũ)\n• Tối ưu chuyển tab siêu mượt mà với PageView 60/120fps và giữ nguyên trạng thái công tắc, thanh trượt, ngữ cảnh khi chuyển trang\n• Che giấu và bảo mật toàn diện thông tin nhạy cảm: địa chỉ MAC, IP, Email, Số điện thoại và mật khẩu quản trị\n• Khắc phục dứt điểm lỗi nâng cấp OTA ESP32: Dual-detection tự động nhận diện thiết bị khởi động lại và nhịp tim MQTT\n• Firmware ESP32 v2.5.7 (Build 201): Tối ưu hóa WDT 45s, xử lý timeout TLS 15s, chống tự động restart và tự động flush hàng đợi trước khi reboot',
    releaseNotesEn: '• Completely fixed phone number linking error with atomic Firebase Auth verification\n• Redesigned success/failure modal system into ZenHome Luxury Glassmorphism (discarded legacy ZaloPay styling)\n• Ultra-smooth 60/120fps PageView tab switching with full state preservation across tabs\n• System-wide data masking for MAC, IP, Email, Phone, and Admin passwords\n• Fixed ESP32 OTA upgrade: Dual-detection for instant reboot recovery and MQTT heartbeat\n• ESP32 Firmware v2.5.7 (Build 201): WDT 45s, TLS socket timeout 15s, anti-crash, and pre-reboot queue flush',
    downloadUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest',
    directApkUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    isForceUpdate: false,
    fileSizeBytes: 72226559,
    sha256: '6C501176494F1011FDEDBCA1EC766606C3827360FB824045F30954ED9EB2AC6B',
    publishedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/app_version -> v1.8.13 (Build 199)');

  // 2. Cập nhật esp32_firmware lên v2.5.7 (Build 201)
  await db.collection('system_config').doc('esp32_firmware').set({
    version: '2.5.7',
    buildNumber: 201,
    directUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin',
    fileSizeBytes: 1381248,
    sha256: 'E793258CD040FFD6E3EF4FE528F605D894EB86173841213E8CE5DA7CF9AD72CA',
    exists: true,
    changelog: 'Bản cập nhật v2.5.7 (Build 201): Tăng WDT lên 45s, giảm socket timeout TLS xuống 15s, chống quá tải/treo khởi động lại, tự động loop MQTT và flush bộ đệm khi nạp OTA',
    lastDeployedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/esp32_firmware -> v2.5.7 (Build 201)');

  process.exit(0);
}

updateFirestore().catch(err => {
  console.error('Lỗi cập nhật Firestore:', err);
  process.exit(1);
});
