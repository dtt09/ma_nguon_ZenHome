import { db } from '../server/core/firebase';
import { getCurrentServerConfig } from '../server/core/networkSync';

async function updateVersion() {
  const config = getCurrentServerConfig();
  const baseUrl = config.serverBaseUrl || 'http://192.168.1.10:5000';
  const directApk = `${baseUrl}/public/downloads/zenhome-app-release.apk`;
  
  const versionData = {
    latestVersion: "1.7.9",
    latestBuildNumber: 179,
    minVersion: "1.6.0",
    minBuildNumber: 160,
    titleVi: "Bản Cập Nhật ZenHome v1.7.9 - Chuẩn Hóa Logic Liên Kết & Bảo Mật Key Toàn Diện",
    titleEn: "ZenHome Update v1.7.9 - Account Binding Logic & Hardened Security",
    releaseNotesVi: "• Bắt buộc liên kết tài khoản ZenHome: Khóa toàn bộ relay, công tắc cơ và BLE ngầm khi chưa liên kết\n• Tự động kết nối lại WiFi trong nền không bao giờ tự reboot vi điều khiển\n• Khởi động lại (Boot) được kiểm soát thủ công 100% từ phần cứng (nút cứng) hoặc phần mềm (App/Web)\n• Nâng cấp giao thức xác thực Key HMAC-SHA256 và bảo vệ Replay Attack Nonce Cache",
    releaseNotesEn: "• Mandatory ZenHome Account Binding: all relays, switches, and BLE control locked when unlinked\n• Seamless non-blocking Wi-Fi reconnect with zero spontaneous hardware reboots\n• 100% manual reboot control from hardware (reset button) or software (App/Web)\n• Hardened HMAC-SHA256 Key authentication and Replay Attack Nonce Cache",
    downloadUrl: directApk,
    directApkUrl: directApk,
    serverBaseUrl: baseUrl,
    fileSizeBytes: 68606689,
    sha256: "0A5E1E46A201A45BB84214224E1817B665DC3C185664632B9131670EBC36AB5A",
    isForceUpdate: false,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  if (db) {
    await db.collection('system_config').doc('app_version').set(versionData, { merge: true });
    console.log('[FIRESTORE] Successfully updated system_config/app_version to v1.7.9 (build 179)');
  } else {
    console.log('[FIRESTORE] DB not connected.');
  }
  process.exit(0);
}

updateVersion().catch(err => {
  console.error(err);
  process.exit(1);
});
