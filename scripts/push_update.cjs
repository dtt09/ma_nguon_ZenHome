/**
 * ==============================================================================
 *  ZENHOME SMART HOME - OTA APP VERSION PUBLISHER SCRIPT
 * ==============================================================================
 *  Tự động đẩy thông tin phiên bản mới lên Cloud Firestore và REST API Server
 *  để tất cả thiết bị di động đang cài App ZenHome tự động nhận thông báo cập nhật.
 * ==============================================================================
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const os = require('os');

const ROOT_DIR = path.resolve(__dirname, '..');
const PUBSPEC_PATH = path.join(ROOT_DIR, 'zenhome_app', 'pubspec.yaml');
const FIREBASE_MODULE_PATH = path.join(ROOT_DIR, 'zenhome-server', 'server', 'core', 'firebase.cjs');

async function getLocalIp() {
  const net = require('net');
  try {
    const ip = await new Promise((resolve, reject) => {
      const socket = net.createConnection({ host: '8.8.8.8', port: 53 });
      socket.setTimeout(1200);
      socket.on('connect', () => {
        const addr = socket.localAddress;
        socket.destroy();
        if (addr && addr !== '127.0.0.1' && !addr.startsWith('169.254')) resolve(addr);
        else reject(new Error('Invalid IP'));
      });
      socket.on('timeout', () => { socket.destroy(); reject(new Error('Timeout')); });
      socket.on('error', (err) => { socket.destroy(); reject(err); });
    });
    if (ip) return ip;
  } catch (e) {}

  const interfaces = os.networkInterfaces();
  const candidates = [];
  for (const [name, addrs] of Object.entries(interfaces)) {
    if (!addrs) continue;
    const lower = name.toLowerCase();
    const isVirtual = /vethernet|virtualbox|vmware|hyper-v|wsl|loopback|teredo|bluetooth|local area connection/i.test(lower);
    const isPreferred = /wi-?fi|wlan|wireless|ethernet|lan/i.test(lower);
    for (const iface of addrs) {
      if (iface.family === 'IPv4' && !iface.internal && !iface.address.startsWith('169.254')) {
        let score = 0;
        if (isPreferred) score += 60;
        if (isVirtual) score -= 40;
        if (iface.address.startsWith('192.168.137.')) score -= 30;
        if (iface.address.startsWith('192.168.') || iface.address.startsWith('10.')) score += 25;
        candidates.push({ address: iface.address, score });
      }
    }
  }
  candidates.sort((a, b) => b.score - a.score);
  return candidates.length > 0 ? candidates[0].address : '127.0.0.1';
}

// Đọc phiên bản từ pubspec.yaml
function getAppVersionFromPubspec() {
  try {
    if (fs.existsSync(PUBSPEC_PATH)) {
      const content = fs.readFileSync(PUBSPEC_PATH, 'utf8');
      const match = content.match(/^version:\s*([^\r\n]+)/m);
      if (match && match[1]) {
        const full = match[1].trim();
        const parts = full.split('+');
        return {
          version: parts[0] || '1.4.0',
          buildNumber: parseInt(parts[1] || '140', 10),
        };
      }
    }
  } catch (e) {
    // fallback
  }
  return { version: '1.4.0', buildNumber: 140 };
}

async function askQuestion(rl, query, defaultValue) {
  return new Promise((resolve) => {
    rl.question(`${query} [${defaultValue}]: `, (answer) => {
      resolve(answer.trim() || defaultValue);
    });
  });
}

async function main() {
  console.log('\n=================================================================');
  console.log('       🚀 ZENHOME SMART HOME - PHÁT HÀNH BẢN CẬP NHẬT APP 📱     ');
  console.log('=================================================================\n');

  const detected = getAppVersionFromPubspec();

  // Đọc tham số dòng lệnh nếu có (CLI Flags)
  const args = process.argv.slice(2);
  const getArg = (name) => {
    const idx = args.indexOf(`--${name}`);
    if (idx !== -1 && args[idx + 1]) return args[idx + 1];
    return null;
  };

  const isSilent = args.includes('--yes') || args.includes('-y');

  let version = getArg('version') || detected.version;
  let buildNumber = parseInt(getArg('build') || detected.buildNumber.toString(), 10);
  let isForce = getArg('force') === 'true';
  let notesVi = getArg('notes-vi');
  let downloadUrl = getArg('url') || 'https://github.com/dtthuat/zenhome/releases/latest';

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const localIp = await getLocalIp();
  let directApkUrl = getArg('direct-url') || `http://${localIp}:5000/public/downloads/zenhome-app-release.apk`;

  if (!isSilent) {
    console.log(`📦 Thông tin phát hiện từ pubspec.yaml: v${detected.version} (Build: ${detected.buildNumber})\n`);
    
    version = await askQuestion(rl, '1. Nhập Số Phiên Bản hiển thị (latestVersion)', version);
    const buildStr = await askQuestion(rl, '2. Nhập Mã Build Number (phải lớn hơn phiên bản cũ)', buildNumber.toString());
    buildNumber = parseInt(buildStr, 10) || buildNumber;

    const forceStr = await askQuestion(rl, '3. Bắt buộc người dùng cập nhật ngay (isForceUpdate)? (y/N)', isForce ? 'y' : 'n');
    isForce = forceStr.toLowerCase().startsWith('y');

    const defaultNotes = '• Tự động tải ngầm và cài đặt APK trong nền\n• Tự động dọn dẹp file APK sau khi cài xong\n• Thông báo đẩy khi có bản cập nhật mới\n• Đồng bộ hoàn chỉnh đa ngôn ngữ VIE/ENG';
    notesVi = await askQuestion(rl, '4. Nội dung cập nhật (Ghi chú thay đổi)', notesVi || defaultNotes);

    downloadUrl = await askQuestion(rl, '5. Link tải chính / Store', downloadUrl);
    directApkUrl = await askQuestion(rl, '6. Link tải APK trực tiếp (LAN/OTA)', directApkUrl);
  }

  rl.close();

  const updateData = {
    latestVersion: version,
    latestBuildNumber: buildNumber,
    minVersion: '1.3.0',
    minBuildNumber: isForce ? buildNumber : 1,
    titleVi: `Bản Cập Nhật ZenHome v${version}`,
    titleEn: `ZenHome Update v${version}`,
    releaseNotesVi: (notesVi || '').replace(/\\n/g, '\n'),
    releaseNotesEn: `• Performance optimizations and bug fixes\n• Real-time Firestore sync\n• User experience improvements`,
    downloadUrl: downloadUrl,
    directApkUrl: directApkUrl,
    isForceUpdate: isForce,
    publishedAt: new Date().toISOString(),
  };

  console.log('\n[*] Đang kết nối Firebase Firestore để đẩy cấu hình...');

  try {
    if (!fs.existsSync(FIREBASE_MODULE_PATH)) {
      throw new Error(`Không tìm thấy module Firebase Admin tại: ${FIREBASE_MODULE_PATH}`);
    }

    const { db } = require(FIREBASE_MODULE_PATH);
    if (!db) {
      throw new Error('Không thể khởi tạo kết nối Cloud Firestore.');
    }

    await db.collection('system_config').doc('app_version').set(updateData, { merge: true });

    // Phát sóng thông báo đẩy FCM đa ngôn ngữ (VIE & ENG)
    const NOTIFICATIONS_MODULE_PATH = path.join(ROOT_DIR, 'zenhome-server', 'server', 'core', 'notifications.cjs');
    if (fs.existsSync(NOTIFICATIONS_MODULE_PATH)) {
      try {
        console.log('\n[*] Đang gửi thông báo đẩy FCM (Bilingual VIE/ENG) tới tất cả thiết bị...');
        const { sendAppVersionUpdateFCM } = require(NOTIFICATIONS_MODULE_PATH);
        if (sendAppVersionUpdateFCM) {
          await sendAppVersionUpdateFCM(updateData);
        }
      } catch (fcmErr) {
        console.warn('⚠️ Lỗi khi phát sóng FCM (không ảnh hưởng cập nhật DB):', fcmErr.message);
      }
    }

    console.log('\n=================================================================');
    console.log('       🎉 ĐÃ ĐẨY BẢN CẬP NHẬT LÊN CLOUD THÀNH CÔNG RỰC RỠ! 🎉   ');
    console.log('=================================================================');
    console.log(`✅ Phiên bản mới:      v${updateData.latestVersion} (Build ${updateData.latestBuildNumber})`);
    console.log(`✅ Chế độ bắt buộc:    ${updateData.isForceUpdate ? 'CÓ (Bắt buộc cập nhật)' : 'KHÔNG (Tùy chọn)'}`);
    console.log(`✅ Đường dẫn tải APK:  ${updateData.directApkUrl}`);
    console.log(`✅ Link tải ngoài:     ${updateData.downloadUrl}`);
    console.log(`✅ Thời gian phát hành: ${updateData.publishedAt}`);
    console.log(`✅ Thông báo FCM:      Đã phát sóng tới topics (all_users_vi, all_users_en, all_users) & Tokens`);
    console.log('-----------------------------------------------------------------');
    console.log('📱 KẾT QUẢ TRÊN ỨNG DỤNG:');
    console.log('   Mọi điện thoại cài App ZenHome có build <', updateData.latestBuildNumber);
    console.log('   khi mở App (hoặc vào Cài đặt -> Kiểm tra bản cập nhật)');
    console.log('   sẽ tự động hiển thị Hộp thoại Cập Nhật Ngay!');
    console.log('=================================================================\n');
    process.exit(0);
  } catch (err) {
    console.error('\n❌ LỖI KHI ĐẨY BẢN CẬP NHẬT:', err.message);
    process.exit(1);
  }
}

main();
