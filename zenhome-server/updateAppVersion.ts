import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const { db } = require('./server/core/firebase.cjs');

async function updateVersion() {
  if (!db) {
    console.error('No DB connection');
    process.exit(1);
  }

  const appVersionRef = db.collection('system_config').doc('app_version');
  const doc = await appVersionRef.get();
  console.log('Current DB app_version:', doc.data());

  const newVersionData = {
    latestVersion: '1.7.2',
    latestBuildNumber: 172,
    minVersion: '1.6.0',
    minBuildNumber: 160,
    titleVi: 'Bản Cập Nhật ZenHome 1.7.2',
    titleEn: 'ZenHome 1.7.2 Update',
    releaseNotesVi: '• Tăng cường bảo mật hủy liên kết Hub ESP32: Kiểm tra kết nối mạng, xác thực đa phương thức và bắn tín hiệu Factory Reset tự động từ xa\n• Nút khởi động lại Hub trung tâm từ xa qua MQTT an toàn với bảng xác nhận thận trọng\n• Thiết kế giao diện chuyển tab Tiện ích (Ngữ cảnh - Tự động hóa) hiệu ứng trượt kính (Glassmorphism Pill) cao cấp đồng bộ thanh menu chính\n• Cơ chế thông minh chặn trùng lặp chân GPIO, trùng tên thiết bị trong cùng phòng và trùng mã ID\n• Chuẩn hóa toàn bộ hộp thoại thông báo thành công / thất bại / cảnh báo theo phong cách giao dịch ZaloPay hiện đại\n• Tính năng vuốt xuống để đồng bộ (Pull-to-Refresh) toàn diện trên mọi màn hình chính trong ứng dụng\n• Đồng bộ và chuẩn hóa 100% song ngữ Việt - Anh',
    releaseNotesEn: '• Enhanced ESP32 Hub Unlink Security: Online status check, multi-factor re-authentication, and remote factory reset trigger\n• Remote ESP32 restart button over MQTT with caution modals\n• Upgraded Utilities menu (Scenes - Automations) with glassmorphism sliding pill effect matching main navigation\n• Smart conflict prevention blocking duplicate GPIO pins and room device names\n• Modern ZaloPay-style transaction status dialogs for success, failure, and warnings\n• Full pull-to-refresh synchronization across all main application screens\n• Complete bilingual synchronization (Vietnamese - English)',
    downloadUrl: 'http://192.168.1.6:5000/public/downloads/zenhome-app-release.apk',
    directApkUrl: 'http://192.168.1.6:5000/public/downloads/zenhome-app-release.apk',
    serverBaseUrl: 'http://192.168.1.6:5000',
    isForceUpdate: false,
    fileSizeBytes: 67335905,
    publishedAt: new Date().toISOString(),
    lastServerSyncAt: new Date().toISOString(),
  };

  await appVersionRef.set(newVersionData, { merge: true });
  console.log('Successfully updated system_config/app_version to 1.7.2:');
  console.log(JSON.stringify(newVersionData, null, 2));
  process.exit(0);
}

updateVersion().catch(err => {
  console.error('Error updating app version:', err);
  process.exit(1);
});
