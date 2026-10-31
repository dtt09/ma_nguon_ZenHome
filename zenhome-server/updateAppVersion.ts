import { db } from './server/core/firebase';
import { detectActiveLocalIp } from './server/core/networkSync';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

async function updateVersion() {
  if (!db) {
    console.error('No DB connection');
    process.exit(1);
  }

  const localIp = await detectActiveLocalIp().catch(() => '192.168.1.9');
  console.log(`Detected active local IP: ${localIp}`);

  const apkFile = path.resolve(process.cwd(), 'public/downloads/zenhome-app-release.apk');
  let apkSha256 = '1FD2DE979349FA906565DF8865602144B0B219C7027CAA7F45F4F05357C4A553';
  let apkSize = 68770633;

  if (fs.existsSync(apkFile)) {
    const stat = fs.statSync(apkFile);
    apkSize = stat.size;
    const buf = fs.readFileSync(apkFile);
    apkSha256 = crypto.createHash('sha256').update(buf).digest('hex').toUpperCase();
  }

  const appVersionRef = db.collection('system_config').doc('app_version');

  const newVersionData = {
    latestVersion: '1.7.12',
    latestBuildNumber: 182,
    minVersion: '1.6.0',
    minBuildNumber: 160,
    titleVi: 'Bản Cập Nhật ZenHome v1.7.12 - Nâng Cấp An Ninh & Bảo Vệ Dữ Liệu Khẩn Cấp',
    titleEn: 'ZenHome Update v1.7.12 - Critical Security Patch & Data Protection',
    releaseNotesVi: '• Vá lỗ hổng Cloud Firestore: Khóa chặt quyền đọc hồ sơ, bảo vệ tuyệt đối thông tin MQTT Broker, mật khẩu và MAC Hub\n• Nâng cấp cơ chế phân quyền chia sẻ nhà (Family Sharing) an toàn không rò rỉ dữ liệu\n• Bắt buộc xác thực mật khẩu quản trị cho lệnh Factory Reset và kiểm định chữ ký băm SHA-256 Firmware OTA trên ESP32\n• Khởi tạo tự động Master Key Zero-Knowledge ngay khi vi điều khiển ESP32 khởi động',
    releaseNotesEn: '• Patched Cloud Firestore rules: Strictly protected user profiles and shielded MQTT broker credentials and Hub MAC\n• Secure Family Sharing invite workflow without sensitive data exposure\n• Mandated Admin Password verification for Factory Reset & realtime SHA-256 streaming verification for ESP32 OTA\n• Automatic Zero-Knowledge Master Key derivation upon ESP32 boot',
    downloadUrl: `http://${localIp}:5000/public/downloads/zenhome-app-release.apk`,
    directApkUrl: `http://${localIp}:5000/public/downloads/zenhome-app-release.apk`,
    serverBaseUrl: `http://${localIp}:5000`,
    isForceUpdate: false,
    fileSizeBytes: apkSize,
    sha256: apkSha256,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  await appVersionRef.set(newVersionData, { merge: true });
  console.log('Successfully updated system_config/app_version to 1.7.12:');
  console.log(JSON.stringify(newVersionData, null, 2));
  process.exit(0);
}

updateVersion().catch(err => {
  console.error('Error updating app version:', err);
  process.exit(1);
});
