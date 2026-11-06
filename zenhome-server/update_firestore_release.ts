import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import { db, FieldValue } from './server/core/firebase';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');

function computeSha256(filePath: string): string {
  if (!fs.existsSync(filePath)) return '';
  const buf = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(buf).digest('hex').toUpperCase();
}

async function updateFirestore() {
  if (!db) {
    console.error('❌ Cloud Firestore chưa được khởi tạo!');
    process.exit(1);
  }

  // 1. Đọc thông tin phiên bản App
  let appVersion = '1.8.14';
  let appBuild = 201;
  const pubspecPath = path.join(ROOT_DIR, 'zenhome_app', 'pubspec.yaml');
  if (fs.existsSync(pubspecPath)) {
    const raw = fs.readFileSync(pubspecPath, 'utf8');
    const m = raw.match(/^version:\s*([^\r\n]+)/m);
    if (m && m[1]) {
      const parts = m[1].trim().split('+');
      appVersion = parts[0];
      appBuild = parseInt(parts[1] || '201', 10);
    }
  }

  // 2. Đọc thông tin phiên bản Firmware ESP32
  let espVersion = '2.5.8';
  let espBuild = 202;
  const configHeaderPath = path.join(ROOT_DIR, 'esp32_1', 'include', 'config_manager.h');
  if (fs.existsSync(configHeaderPath)) {
    const raw = fs.readFileSync(configHeaderPath, 'utf8');
    const mv = raw.match(/#define\s+FIRMWARE_VERSION_STR\s+"([^"]+)"/);
    const mb = raw.match(/#define\s+FIRMWARE_BUILD_NUM\s+([0-9]+)/);
    if (mv && mv[1]) espVersion = mv[1].trim();
    if (mb && mb[1]) espBuild = parseInt(mb[1].trim(), 10);
  }

  // 3. Đường dẫn các file nhị phân
  const apkPath = path.join(ROOT_DIR, 'ZenHome_Release.apk');
  const espPath = path.join(ROOT_DIR, 'firmware.bin');

  const apkSize = fs.existsSync(apkPath) ? fs.statSync(apkPath).size : 72242943;
  const apkSha = computeSha256(apkPath);

  const espSize = fs.existsSync(espPath) ? fs.statSync(espPath).size : 1381760;
  const espSha = computeSha256(espPath);

  console.log(`🔄 Đang cập nhật Cloud Firestore & Server Metadata:`);
  console.log(`   - App: v${appVersion} (Build ${appBuild}) | Size: ${apkSize} bytes | SHA: ${apkSha.substring(0, 16)}...`);
  console.log(`   - ESP32: v${espVersion} (Build ${espBuild}) | Size: ${espSize} bytes | SHA: ${espSha.substring(0, 16)}...`);

  // 4. Cập nhật system_config/app_version
  await db.collection('system_config').doc('app_version').set({
    latestVersion: appVersion,
    latestBuildNumber: appBuild,
    minVersion: '1.8.0',
    minBuildNumber: 180,
    titleVi: `Bản Cập Nhật ZenHome v${appVersion} (Toàn Diện Bản Vá Bảo Mật & Hardened Architecture)`,
    titleEn: `ZenHome Update v${appVersion} (Hardened Security Architecture & Full Patches)`,
    releaseNotesVi: `• Khắc phục triệt để 9/9 lỗ hổng bảo mật kiểm toán Cloudflare Security Audit\n• Đóng kín Firestore Rules, chặn đọc công khai và khóa chặt IDOR xóa tài khoản / giải phóng định danh\n• Firmware ESP32 v${espVersion} (Build ${espBuild}): Bắt buộc chữ ký số ECDSA P-256 khi nạp OTA, loại bỏ bypass IP subnet LAN, nâng cấp mã hóa AES-256 CTR\n• Server Backend: Chống SSRF & DNS Rebinding trên proxy-ping, ngăn chặn auto-bind Hub trái phép\n• Ứng dụng di động: Loại bỏ toàn bộ tài khoản MQTT hardcode dự phòng`,
    releaseNotesEn: `• Fully remediated 9/9 vulnerabilities from Cloudflare Security Audit\n• Hardened Firestore Rules, blocked public profile reads, and prevented IDOR attacks\n• ESP32 Firmware v${espVersion} (Build ${espBuild}): Enforced mandatory ECDSA P-256 OTA signature verification, removed LAN subnet bypass, upgraded AES-256 CTR storage encryption\n• Server Backend: Hardened SSRF & DNS Rebinding defenses and secured Hub binding endpoints\n• Mobile App: Removed all hardcoded MQTT fallback credentials`,
    downloadUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest',
    directApkUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    isForceUpdate: false,
    fileSizeBytes: apkSize,
    sha256: apkSha,
    publishedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`✅ Đã cập nhật Firestore system_config/app_version -> v${appVersion} (Build ${appBuild})`);

  // 5. Cập nhật system_config/esp32_firmware
  await db.collection('system_config').doc('esp32_firmware').set({
    version: espVersion,
    buildNumber: espBuild,
    directUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin',
    fileSizeBytes: espSize,
    sha256: espSha,
    exists: true,
    changelog: `Bản cập nhật v${espVersion} (Build ${espBuild}): Bản vá bảo mật toàn diện Cloudflare Audit. Bắt buộc chữ ký số ECDSA P-256 khi OTA, loại bỏ bypass IP subnet LAN, nâng cấp mã hóa AES-256 CTR`,
    lastDeployedAt: new Date().toISOString(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`✅ Đã cập nhật Firestore system_config/esp32_firmware -> v${espVersion} (Build ${espBuild})`);

  // 6. Cập nhật version.json cho server
  const versionJsonPath = path.join(ROOT_DIR, 'zenhome-server', 'public', 'downloads', 'version.json');
  const versionJsonData = {
    version: appVersion,
    buildNumber: appBuild,
    minVersion: '1.8.0',
    minBuildNumber: 180,
    titleVi: `Bản Cập Nhật ZenHome v${appVersion} (Toàn Diện Bản Vá Bảo Mật & Hardened Architecture)`,
    titleEn: `ZenHome Update v${appVersion} (Hardened Security Architecture & Full Patches)`,
    releaseNotesVi: `• Khắc phục triệt để 9/9 lỗ hổng bảo mật kiểm toán Cloudflare Security Audit\n• Đóng kín Firestore Rules, chặn đọc công khai và khóa chặt IDOR xóa tài khoản / giải phóng định danh\n• Firmware ESP32 v${espVersion} (Build ${espBuild}): Bắt buộc chữ ký số ECDSA P-256 khi nạp OTA, loại bỏ bypass IP subnet LAN, nâng cấp mã hóa AES-256 CTR\n• Server Backend: Chống SSRF & DNS Rebinding trên proxy-ping, ngăn chặn auto-bind Hub trái phép\n• Ứng dụng di động: Loại bỏ toàn bộ tài khoản MQTT hardcode dự phòng`,
    releaseNotesEn: `• Fully remediated 9/9 vulnerabilities from Cloudflare Security Audit\n• Hardened Firestore Rules, blocked public profile reads, and prevented IDOR attacks\n• ESP32 Firmware v${espVersion} (Build ${espBuild}): Enforced mandatory ECDSA P-256 OTA signature verification, removed LAN subnet bypass, upgraded AES-256 CTR storage encryption\n• Server Backend: Hardened SSRF & DNS Rebinding defenses and secured Hub binding endpoints\n• Mobile App: Removed all hardcoded MQTT fallback credentials`,
    downloadUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    directApkUrl: 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk',
    isForceUpdate: false,
    fileSizeBytes: apkSize,
    sha256: apkSha,
    publishedAt: new Date().toISOString()
  };
  fs.writeFileSync(versionJsonPath, JSON.stringify(versionJsonData, null, 2), 'utf8');
  console.log(`✅ Đã đồng bộ ${versionJsonPath}`);

  process.exit(0);
}

updateFirestore().catch(err => {
  console.error('❌ Lỗi cập nhật Firestore:', err);
  process.exit(1);
});
