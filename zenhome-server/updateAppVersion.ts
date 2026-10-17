import { db } from './server/core/firebase';

async function updateVersion() {
  if (!db) {
    console.error('No DB connection');
    process.exit(1);
  }

  const appVersionRef = db.collection('system_config').doc('app_version');
  const doc = await appVersionRef.get();
  console.log('Current DB app_version:', doc.data());

  const newVersionData = {
    latestVersion: '1.7.4',
    latestBuildNumber: 174,
    minVersion: '1.6.0',
    minBuildNumber: 160,
    titleVi: 'Bản Cập Nhật ZenHome 1.7.4',
    titleEn: 'ZenHome 1.7.4 Update',
    releaseNotesVi: '• Tối ưu điều khiển ưu tiên mạng Local LAN: Phản hồi siêu tốc ~5-15ms khi cùng mạng nội bộ\n• Tích hợp Mini Backup Server tự động lưu trữ và đồng bộ trạng thái khi có kết nối mạng trở lại\n• Cơ chế phân biệt mất điện (ngắt toàn bộ relay an toàn khi có điện lại) và mất mạng (đồng bộ trạng thái lần cuối)\n• Nâng cấp giao diện hiển thị trạng thái kết nối Local ⚡ / Cloud trực quan trên từng thiết bị',
    releaseNotesEn: '• Local-First LAN control optimization: Ultra-fast response (~5-15ms) on local network\n• Integrated Mini Backup Server: Automatically stores and syncs states when network restores\n• Smart distinction between power outage (safety relay shutdown upon recovery) and network outage (sync last known states)\n• Enhanced connection badges displaying Local ⚡ vs Cloud seamlessly on each device',
    downloadUrl: 'http://192.168.1.6:5000/public/downloads/zenhome-app-release.apk',
    directApkUrl: 'http://192.168.1.6:5000/public/downloads/zenhome-app-release.apk',
    serverBaseUrl: 'http://192.168.1.6:5000',
    isForceUpdate: false,
    fileSizeBytes: 67910441,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  await appVersionRef.set(newVersionData, { merge: true });
  console.log('Successfully updated system_config/app_version to 1.7.4:');
  console.log(JSON.stringify(newVersionData, null, 2));
  process.exit(0);
}

updateVersion().catch(err => {
  console.error('Error updating app version:', err);
  process.exit(1);
});
