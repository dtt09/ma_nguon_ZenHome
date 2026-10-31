import { db } from '../server/core/firebase';
import { detectActiveLocalIp } from '../server/core/networkSync';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function updateVersion() {
  if (!db) {
    console.error('No DB connection');
    process.exit(1);
  }

  const localIp = await detectActiveLocalIp().catch(() => '192.168.1.9');
  console.log(`Detected active local IP: ${localIp}`);

  const rootDir = path.resolve(__dirname, '../../');
  const builtApk = path.join(rootDir, 'zenhome_app/build/app/outputs/flutter-apk/app-release.apk');
  const serverApk = path.join(__dirname, '../public/downloads/zenhome-app-release.apk');
  const serverVersionedApk = path.join(__dirname, '../public/downloads/ZenHome-1.8.3.apk');
  const rootReleaseApk = path.join(rootDir, 'ZenHome_Release.apk');
  const rootVersionedApk = path.join(rootDir, 'ZenHome-1.8.3.apk');
  const buildOutputApk = path.join(rootDir, 'build_output/ZenHome_Release.apk');

  // Copy build artifacts
  if (fs.existsSync(builtApk)) {
    console.log(`[*] Sao chép APK mới từ ${builtApk}...`);
    fs.mkdirSync(path.dirname(serverApk), { recursive: true });
    fs.mkdirSync(path.dirname(buildOutputApk), { recursive: true });

    fs.copyFileSync(builtApk, serverApk);
    fs.copyFileSync(builtApk, serverVersionedApk);
    fs.copyFileSync(builtApk, rootReleaseApk);
    fs.copyFileSync(builtApk, rootVersionedApk);
    fs.copyFileSync(builtApk, buildOutputApk);
    console.log('[*] Đã phân phối APK đến các thư mục phát hành.');
  } else if (!fs.existsSync(serverApk)) {
    console.error(`Không tìm thấy file APK tại ${builtApk} hoặc ${serverApk}`);
    process.exit(1);
  }

  const stat = fs.statSync(serverApk);
  const apkSize = stat.size;
  const buf = fs.readFileSync(serverApk);
  const apkSha256 = crypto.createHash('sha256').update(buf).digest('hex').toUpperCase();

  const baseUrl = `http://${localIp}:5000`;
  const directApk = `${baseUrl}/public/downloads/zenhome-app-release.apk`;

  const newVersionData = {
    latestVersion: '1.8.3',
    latestBuildNumber: 188,
    version: '1.8.3',
    buildNumber: 188,
    minVersion: '1.6.0',
    minBuildNumber: 160,
    titleVi: 'Bản Cập Nhật ZenHome v1.8.3 - Auto-Bind Phần Cứng, UI Wizard Phản Hồi Realtime & Triệt Tiêu Crashlytics Socket',
    titleEn: 'ZenHome Update v1.8.3 - Hardware Auto-Bind, Reactive Wizard UI & Socket Crash Filters',
    releaseNotesVi: '• Cơ chế Auto-Binding tự động gắn kết Hub ESP32 với tài khoản người dùng khi thiết lập lại hoặc sau khi hủy liên kết\n• Thanh tiến trình cài đặt Wi-Fi phản hồi Realtime (15% -> 100%) không còn bị đứng đơ\n• Phân loại chính xác các sự cố mạng/đổi Wi-Fi, ngăn báo cáo sai thành Fatal Crash trên Crashlytics\n• Khắc phục triệt để lỗi Null check setState và ref sau khi widget disposed khi đăng xuất\n• An toàn hóa luồng xuất bản MQTT với bộ đệm chống ConnectionException',
    releaseNotesEn: '• Seamless Hardware Auto-Binding when pairing or re-linking ESP32 Hub\n• Realtime reactive Wi-Fi setup progress bar (15% -> 100% smooth transitions)\n• Smart network socket disconnect filtering to prevent false fatal Crashlytics reports\n• Resolved setState null check and disposed ref access during logout flow\n• Hardened MQTT publish queue against premature ConnectionException',
    downloadUrl: directApk,
    directApkUrl: directApk,
    serverBaseUrl: baseUrl,
    isForceUpdate: false,
    fileSizeBytes: apkSize,
    sha256: apkSha256,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  await db.collection('system_config').doc('app_version').set(newVersionData, { merge: true });
  console.log('[FIRESTORE] ✅ Đã cập nhật thành công system_config/app_version lên v1.8.3 (Build 188):');
  console.log(JSON.stringify(newVersionData, null, 2));
  process.exit(0);
}

updateVersion().catch(err => {
  console.error('[FIRESTORE] ❌ Lỗi cập nhật phiên bản:', err);
  process.exit(1);
});
