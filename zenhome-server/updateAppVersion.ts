import { db } from './server/core/firebase';
import { detectActiveLocalIp } from './server/core/networkSync';

async function updateVersion() {
  if (!db) {
    console.error('No DB connection');
    process.exit(1);
  }

  const localIp = await detectActiveLocalIp().catch(() => '192.168.1.10');
  console.log(`Detected active local IP: ${localIp}`);

  const appVersionRef = db.collection('system_config').doc('app_version');
  const doc = await appVersionRef.get();
  console.log('Current DB app_version:', doc.data());

  const newVersionData = {
    latestVersion: '1.7.5',
    latestBuildNumber: 175,
    minVersion: '1.6.0',
    minBuildNumber: 160,
    titleVi: 'Bản Cập Nhật ZenHome 1.7.5',
    titleEn: 'ZenHome 1.7.5 Update',
    releaseNotesVi: '• Bảo mật cấp cao Zero-Knowledge (Diffie-Hellman + HMAC-SHA256): Tự động trao đổi khoá bảo mật riêng biệt giữa App và ESP32 qua LAN, không ai có thể can thiệp\n• Đồng bộ điều khiển Local LAN cho các thành viên trong nhà theo quyền thiết bị\n• Nâng cấp các hiệu ứng vi mô (Micro-interactions) & phản hồi rung: Thanh kéo thời gian động, chuyển đổi giao diện sáng/tối/hệ thống & ngôn ngữ dạng viên con nhộng\n• Bổ sung bảng chọn màu sắc trực quan khi tạo và tuỳ biến ngữ cảnh (Scene)',
    releaseNotesEn: '• High-Grade Zero-Knowledge Security (Diffie-Hellman + HMAC-SHA256): Secure auto key exchange between App and ESP32 over LAN\n• Synchronized Local LAN control for family members with permission controls\n• Polished micro-interactions & haptics: Dynamic counter on timer slider, capsule segmented selectors for theme & language\n• Added vibrant color palette picker for smart scenes',
    downloadUrl: `http://${localIp}:5000/public/downloads/zenhome-app-release.apk`,
    directApkUrl: `http://${localIp}:5000/public/downloads/zenhome-app-release.apk`,
    serverBaseUrl: `http://${localIp}:5000`,
    isForceUpdate: false,
    fileSizeBytes: 67960421,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  await appVersionRef.set(newVersionData, { merge: true });
  console.log('Successfully updated system_config/app_version to 1.7.5:');
  console.log(JSON.stringify(newVersionData, null, 2));
  process.exit(0);
}

updateVersion().catch(err => {
  console.error('Error updating app version:', err);
  process.exit(1);
});
