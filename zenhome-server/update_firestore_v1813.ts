import { db, FieldValue } from './server/core/firebase';

async function updateFirestore() {
  if (!db) {
    console.error('Firestore not initialized!');
    process.exit(1);
  }

  console.log('🔄 Đang cập nhật cấu hình hệ thống trên Cloud Firestore cho phiên bản mới v1.8.13...');

  // 1. Cập nhật app_version lên v1.8.13 (Build 200)
  await db.collection('system_config').doc('app_version').set({
    latestVersion: '1.8.13',
    latestBuildNumber: 200,
    minVersion: '1.8.0',
    minBuildNumber: 180,
    titleVi: 'Bản Cập Nhật ZenHome v1.8.13 (Anti-Crosstalk & Brownout Protection)',
    titleEn: 'ZenHome Update v1.8.13 (Anti-Crosstalk & Brownout Protection)',
    releaseNotesVi: '• Khắc phục triệt để lỗi liên kết số điện thoại ("không tra cứu được dữ liệu")\n• Thiết kế lại toàn bộ hệ thống modal ZenHome Luxury Glassmorphism\n• Tối ưu hóa chuyển tab 60/120fps và bảo toàn cờ pending rơ-le\n• Chống giao thoa trạng thái công tắc chéo tài khoản trên Broker (Anti-Crosstalk)\n• Khử xung đột phát lệnh kép (Dual-Dispatch LAN HTTP + MQTT Cloud)\n• Chống sụt áp nguồn (Brownout Protection) khi kích hoạt ngữ cảnh',
    releaseNotesEn: '• Fixed phone number linking error with native Firebase Auth verification\n• Redesigned ZenHome Luxury Glassmorphism modal system\n• 60/120fps tab transition and preserved switch pending states\n• Eliminated multi-user MQTT cross-talk on shared broker\n• Resolved Dual-Dispatch packet collisions\n• Brownout voltage dip protection during multi-relay scene triggers',
    downloadUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest',
    directApkUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    isForceUpdate: false,
    fileSizeBytes: 72242943,
    sha256: '34A5DD06174F17814992535EE470C0F5A37BA1EABE427C9B3969FFF0FD8AD4A6',
    publishedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log('✅ Đã cập nhật system_config/app_version -> v1.8.13 (Build 200)');

  // 2. Cập nhật esp32_firmware lên v2.5.7 (Build 201)
  await db.collection('system_config').doc('esp32_firmware').set({
    version: '2.5.7',
    buildNumber: 201,
    directUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin',
    fileSizeBytes: 1381760,
    sha256: 'F847874EFD5729B2AB623EACA52D8E54F963BDBC0B422CB029A0F5D0B1A49834',
    exists: true,
    changelog: 'Bản cập nhật v2.5.7 (Build 201): Chống sụt áp nguồn Brownout Reset khi gạt rơ-le liên tiếp, đảm bảo ACK phản hồi mọi trạng thái (kể cả khi chạm Relay Guard), tối ưu WDT 45s và duy trì keep-alive trong chu kỳ nạp OTA',
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
