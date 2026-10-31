import { db } from '../server/core/firebase';
import { getCurrentServerConfig } from '../server/core/networkSync';

async function updateVersion() {
  const config = getCurrentServerConfig();
  const baseUrl = config.serverBaseUrl || 'http://192.168.1.10:5000';
  const directApk = `${baseUrl}/public/downloads/zenhome-app-release.apk`;
  
  const versionData = {
    latestVersion: "1.7.8",
    latestBuildNumber: 178,
    minVersion: "1.6.0",
    minBuildNumber: 160,
    titleVi: "Bản Cập Nhật ZenHome v1.7.8 - Kết Nối Ngầm BLE & Công Tắc Cơ",
    titleEn: "ZenHome Update v1.7.8 - Zero-Touch BLE Link & Wall Switch",
    releaseNotesVi: "• Tích hợp giao thức kết nối ngầm qua Bluetooth Low Energy (Zero-Touch BLE), điều khiển tức thì khi Router Wi-Fi mất nguồn\n• Bổ sung hỗ trợ công tắc cơ gắn tường (GPIO 32, 33, 34) với bộ lọc chống rung phím\n• Bảng trạng thái Hub 3 tầng: Local LAN, BLE ngầm, Cloud MQTT\n• Đồng bộ và bản địa hóa đa ngôn ngữ toàn diện",
    releaseNotesEn: "• Integrated Zero-Touch BLE background link, instant control when Wi-Fi router loses power\n• Added physical wall switch support (GPIO 32, 33, 34) with debounce filter\n• Upgraded 3-Tier Hub connection status panel: Local LAN, BLE, Cloud MQTT\n• Comprehensive multi-language synchronization",
    downloadUrl: directApk,
    directApkUrl: directApk,
    serverBaseUrl: baseUrl,
    fileSizeBytes: 68606617,
    sha256: "8BFB492BFAEEF9A49AD1EDBFE3B68FB9718EB3EE71CBC006AE06875D7B5621B4",
    isForceUpdate: false,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  if (db) {
    await db.collection('system_config').doc('app_version').set(versionData, { merge: true });
    console.log('[FIRESTORE] Successfully updated system_config/app_version to v1.7.8 (build 178)');
  } else {
    console.log('[FIRESTORE] DB not connected.');
  }
  process.exit(0);
}

updateVersion().catch(err => {
  console.error(err);
  process.exit(1);
});
