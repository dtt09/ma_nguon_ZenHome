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
  const serverVersionedApk = path.join(__dirname, '../public/downloads/ZenHome-1.8.2.apk');
  const rootReleaseApk = path.join(rootDir, 'ZenHome_Release.apk');
  const rootVersionedApk = path.join(rootDir, 'ZenHome-1.8.2.apk');
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
    latestVersion: '1.8.2',
    latestBuildNumber: 187,
    version: '1.8.2',
    buildNumber: 187,
    minVersion: '1.6.0',
    minBuildNumber: 160,
    titleVi: 'Bản Cập Nhật ZenHome v1.8.2 - Đồng Bộ Khóa Phần Cứng & Kết Nối MQTT Ổn Định',
    titleEn: 'ZenHome Update v1.8.2 - Hardware Binding & Reliable MQTT Connection',
    releaseNotesVi: '• Khắc phục triệt để lỗi timeout kết nối MQTT (-4) trên ESP32 nhờ thuật toán Adaptive Backoff\n• Xác thực đồng nhất User & MAC giữa ESP32 và Database Firestore trước khi kết nối Cloud\n• Tự động đồng bộ MAC phần cứng lên Database trong quá trình thiết lập Wi-Fi\n• Cơ chế bảo mật Zero-Trust: Tự động xóa cấu hình và quay về AP Setup khi phát hiện bị hủy liên kết',
    releaseNotesEn: '• Fixed intermittent MQTT connection timeout (-4) on ESP32 with Adaptive Backoff\n• Mandatory hardware MAC & User validation with Firestore before MQTT connection\n• Early synchronization of hardware MAC to Database during WiFi provisioning\n• Zero-Trust security: Automatic factory reset to AP Setup upon account desynchronization',
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
  console.log('[FIRESTORE] ✅ Đã cập nhật thành công system_config/app_version lên v1.8.2 (Build 187):');
  console.log(JSON.stringify(newVersionData, null, 2));
  process.exit(0);
}

updateVersion().catch(err => {
  console.error('[FIRESTORE] ❌ Lỗi cập nhật phiên bản:', err);
  process.exit(1);
});
