/**
 * ==============================================================================
 *  ZENHOME - ONE-CLICK AUTO RELEASE & GITHUB ASSET PUBLISHER
 * ==============================================================================
 *  Tự động hóa 100% quy trình:
 *  1. Biên dịch Firmware ESP32 (PlatformIO) -> firmware.bin
 *  2. Biên dịch ZenHome Android App (Flutter) -> ZenHome_Release.apk
 *  3. Tính mã băm SHA-256 & kích thước tệp
 *  4. Tự động tạo / cập nhật GitHub Release trên repo dtt09/ma_nguon_ZenHome
 *  5. Tải trực tiếp 2 file nhị phân lên GitHub Releases Asset qua REST API
 *  6. Đồng bộ metadata phiên bản mới lên Cloud Firestore & Server
 * ==============================================================================
 */

const fs = require('fs');
const path = require('path');
const https = require('https');
const crypto = require('crypto');
const { execSync } = require('child_process');
const readline = require('readline');
const { signFirmwareBinary, ensureKeysExist } = require('./generate_firmware_keys');

const ROOT_DIR = path.resolve(__dirname, '..');
const REPO_OWNER = 'dtt09';
const REPO_NAME = 'ma_nguon_ZenHome';

// Đảm bảo git trong mingit luôn có trong PATH khi chạy các tiến trình Flutter/Gradle
process.env.PATH = 'C:\\Users\\dinht\\AppData\\Local\\Programs\\flutter\\bin\\mingit\\cmd;' + (process.env.PATH || '');

// Đọc token từ .env nếu có, hoặc lấy từ Windows Credential Helper
function loadEnvToken() {
  const envPaths = [
    path.join(ROOT_DIR, 'zenhome-server', '.env'),
    path.join(ROOT_DIR, '.env')
  ];
  for (const ep of envPaths) {
    if (fs.existsSync(ep)) {
      const content = fs.readFileSync(ep, 'utf8');
      const match = content.match(/^GITHUB_TOKEN\s*=\s*([^\r\n]+)/m);
      if (match && match[1]) {
        return match[1].trim();
      }
    }
  }
  if (process.env.GITHUB_TOKEN) return process.env.GITHUB_TOKEN;

  // Fallback: Tự động trích xuất token từ Windows Credential Manager thông qua git
  try {
    const gitBin = 'C:\\Users\\dinht\\AppData\\Local\\Programs\\flutter\\bin\\mingit\\cmd\\git.exe';
    const { spawnSync } = require('child_process');
    const p = spawnSync(gitBin, ['credential', 'fill'], { input: 'protocol=https\nhost=github.com\n\n', encoding: 'utf8', timeout: 4000 });
    if (p.stdout) {
      for (const line of p.stdout.split('\n')) {
        if (line.startsWith('password=')) {
          const pass = line.substring(9).trim();
          if (pass.startsWith('gh') || pass.length >= 30) {
            console.log('🔑 Đã tự động nhận GitHub Token từ Windows Credential Manager.');
            return pass;
          }
        }
      }
    }
  } catch (_) {}

  return '';
}

function saveTokenToEnv(token) {
  const envPath = path.join(ROOT_DIR, 'zenhome-server', '.env');
  let content = fs.existsSync(envPath) ? fs.readFileSync(envPath, 'utf8') : '';
  if (/^GITHUB_TOKEN\s*=/m.test(content)) {
    content = content.replace(/^GITHUB_TOKEN\s*=.*$/m, `GITHUB_TOKEN=${token}`);
  } else {
    content += `\nGITHUB_TOKEN=${token}\n`;
  }
  fs.writeFileSync(envPath, content, 'utf8');
  console.log(`💾 Đã lưu GITHUB_TOKEN vào ${envPath}`);
}

function ask(question, defaultVal = '') {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => {
    const prompt = defaultVal ? `${question} [Mặc định: ${defaultVal}]: ` : `${question}: `;
    rl.question(prompt, answer => {
      rl.close();
      resolve(answer.trim() || defaultVal);
    });
  });
}

function computeSha256(filePath) {
  const buf = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(buf).digest('hex').toUpperCase();
}

function githubRequest(method, endpoint, token, data = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = endpoint.startsWith('http') ? endpoint : `https://api.github.com${endpoint}`;
    const uri = new URL(url);

    const defaultHeaders = {
      'User-Agent': 'ZenHome-AutoRelease-Tool',
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github+json',
      ...headers
    };

    if (data && Buffer.isBuffer(data)) {
      defaultHeaders['Content-Length'] = data.length;
    } else if (data && typeof data === 'object') {
      defaultHeaders['Content-Type'] = 'application/json';
      data = JSON.stringify(data);
      defaultHeaders['Content-Length'] = Buffer.byteLength(data);
    }

    const options = {
      method,
      hostname: uri.hostname,
      path: uri.pathname + uri.search,
      headers: defaultHeaders
    };

    const req = https.request(options, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        let json = null;
        try { json = JSON.parse(body); } catch (_) {}
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(json || body);
        } else {
          reject(new Error(`GitHub API [${res.statusCode}] ${endpoint}: ${body}`));
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function uploadReleaseAsset(uploadUrlTemplate, token, filePath, assetName) {
  const fileBuf = fs.readFileSync(filePath);
  const size = fileBuf.length;
  // uploadUrlTemplate dạng: https://uploads.github.com/repos/owner/repo/releases/123/assets{?name,label}
  const cleanUrl = uploadUrlTemplate.replace(/\{.*?\}$/, '') + `?name=${encodeURIComponent(assetName)}`;

  console.log(`   ⏳ Đang tải lên ${assetName} (${(size / (1024 * 1024)).toFixed(1)} MB)...`);

  const uri = new URL(cleanUrl);
  return new Promise((resolve, reject) => {
    const req = https.request({
      method: 'POST',
      hostname: uri.hostname,
      path: uri.pathname + uri.search,
      headers: {
        'User-Agent': 'ZenHome-AutoRelease-Tool',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/octet-stream',
        'Content-Length': size
      }
    }, res => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(body));
        } else {
          reject(new Error(`Lỗi upload asset ${assetName} [${res.statusCode}]: ${body}`));
        }
      });
    });
    req.on('error', reject);
    req.write(fileBuf);
    req.end();
  });
}

async function main() {
  console.log('\n=================================================================');
  console.log('    🚀 ZENHOME - TỰ ĐỘNG XUẤT BẢN & ĐẨY LÊN GITHUB RELEASES     ');
  console.log('=================================================================\n');

  const args = process.argv.slice(2);
  const skipBuild = args.includes('--skip-build') || args.includes('-s');
  const onlyEsp = args.includes('--only-esp');
  const onlyApk = args.includes('--only-apk');

  // 1. Kiểm tra Token GitHub
  let token = loadEnvToken();
  if (!token) {
    console.log('⚠️  Chưa tìm thấy GitHub Personal Access Token (PAT).');
    console.log('👉 Hướng dẫn tạo Token trong 30s:');
    console.log('   1. Mở: https://github.com/settings/tokens/new');
    console.log('   2. Chọn Note: "ZenHome Auto Release"');
    console.log('   3. Tích chọn quyền: [x] repo (Full control of private repositories)');
    console.log('   4. Nhấn Generate token và dán vào đây:\n');
    token = await ask('Nhập GitHub Personal Access Token (ghp_...)');
    if (!token) {
      console.error('❌ Cần có GitHub Token để tải file lên Releases! Hủy tiến trình.');
      process.exit(1);
    }
    saveTokenToEnv(token);
  }

  // 2. Xác định phiên bản
  let pubspecVersion = '1.8.12';
  let pubspecBuild = 198;
  const pubspecPath = path.join(ROOT_DIR, 'zenhome_app', 'pubspec.yaml');
  if (fs.existsSync(pubspecPath)) {
    const raw = fs.readFileSync(pubspecPath, 'utf8');
    const m = raw.match(/^version:\s*([^\r\n]+)/m);
    if (m && m[1]) {
      const parts = m[1].trim().split('+');
      pubspecVersion = parts[0];
      pubspecBuild = parseInt(parts[1] || '1', 10);
    }
  }

  // 2.1 Đọc phiên bản ESP32
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

  let tagVersion = `v${pubspecVersion}`;
  const tagIdx = args.indexOf('--tag');
  if (tagIdx !== -1 && args[tagIdx + 1]) {
    tagVersion = args[tagIdx + 1].trim();
  } else if (!args.includes('-y') && !args.includes('--yes') && process.stdin.isTTY) {
    tagVersion = await ask('Phiên bản tag Release phát hành', `v${pubspecVersion}`);
  }

  const releaseTitle = `ZenHome ${tagVersion} - BLE MTU 512, Fast Wi-Fi Sync & SQLite Concurrency`;
  const releaseNotes = `## 🌟 Điểm nổi bật trong bản phát hành ${tagVersion} (App Build ${pubspecBuild} / ESP32 v${espVersion} Build ${espBuild})

### 📱 Ứng dụng Di động (Mobile App v${pubspecVersion}+${pubspecBuild}):
- 📶 **Nâng cấp BLE MTU lên 512 byte (Android & ESP32)**:
  - Tự động thương lượng MTU 512 byte ngay sau khi kết nối BLE, cho phép truyền toàn vẹn gói xác thực hai chiều HMAC-SHA256 (150+ byte) và gói cấu hình nhanh (200+ byte) trong 1 chu kỳ ATT duy nhất.
- 🏠 **Cách ly triệt để bộ nhớ trạng thái Đa Gia Đình (Multi-Home State Isolation)**:
  - Khi chuyển đổi không gian nhà trong MainLayout, tự động dọn sạch \`GlobalDeviceStates\` và giải phóng \`PendingDeviceOperations\`, triệt tiêu hoàn toàn hiện tượng hiển thị lẫn lộn trạng thái công tắc của nhà cũ sang nhà mới.
- 🛡️ **Bịt kín lỗ hổng phân quyền mạng cục bộ LAN (RBAC LAN Permission Enforcement)**:
  - Truyền đầy đủ cờ \`isDisabled\` vào tiến trình giám sát mạng cục bộ, ngăn chặn thành viên gia đình bị vô hiệu hóa gửi lệnh điều khiển phần cứng qua LAN HTTP.
- 🔔 **Lưu trữ toàn diện thông báo đẩy ngầm (Data-only Push Persistence)**:
  - Xử lý lưu lịch sử cả khi thông báo FCM gửi dưới dạng \`data\` payload mà không có \`notification\`, bảo đảm không bao giờ thất lạc cảnh báo nhiệt độ khẩn cấp, honeytoken hay trạng thái ngoại tuyến.

### ⚡ Firmware ESP32 (v${espVersion} Build ${espBuild}):
- 📶 **Hỗ trợ BLE MTU 512 byte (\`NimBLEDevice::setMTU(512)\`)**:
  - Tương thích tối đa với điện thoại Android/iOS khi trao đổi dữ liệu mã hóa mật mã học và gói cấu hình Wi-Fi/MQTT.
- 🔒 **Đồng bộ khóa FreeRTOS Mutex bảo vệ phần cứng (\`i2cMutex\` & \`mqttMutex\`)**:
  - Cách ly thread-safe tuyệt đối giữa Core 0 (AsyncTCP HTTP) và Core 1 (Main Loop, PCF8574 I2C, PubSubClient loop), ngăn chặn triệt để xung đột bus I2C và ngắt kết nối TLS do gọi đè socket.
- ⚡ **Thuật toán phục hồi bus I2C 9 xung xung nhịp (9-Pulse Recovery)**:
  - Tự động phát hiện và giải phóng thiết bị ngoại vi treo chân SDA mà không gây deadlock mutex.

### 🖥️ Backend Server & Cloud Sync:
- 🌐 **Mở rộng cơ chế lắng nghe đa tầng MQTT Wildcard (\`+/+/+/#\`, \`+/+/#\`, \`+\`)**:
  - Không bao giờ bỏ sót các topic 2 cấp như \`<userId>/esp_status\`, \`<userId>/heartbeat\`.
- ⏱️ **Khắc phục bẫy hủy ân hạn ngoại tuyến (Offline Debounce Early Return)**:
  - Khi ESP32 khôi phục mạng Wi-Fi nhanh trong 35s, Server hủy cảnh báo mất điện giả và lập tức đồng bộ hóa trạng thái công tắc vật lý qua \`handleEspNetworkRestored()\`.
- 💾 **Khử triệt để lỗi khóa SQLite (\`SQLITE_BUSY: database is locked\`)**:
  - Cấu hình \`PRAGMA busy_timeout = 5000;\` và \`dbInstance.configure('busyTimeout', 5000)\` chịu tải ghi nhật ký và sao lưu đồng thời.
- 🧹 **Tự động dọn dẹp Lịch trình & Hẹn giờ mồ côi (Orphaned Schedules/Timers Purge)**:
  - Đồng bộ RAM và Firestore, dọn sạch tác vụ hẹn giờ của tài khoản đã xóa.

---
*Phát hành chính thức bởi ZenHome Automation Release Engine*`;

  // 3. Biên dịch nếu không skip-build
  const espBin = path.join(ROOT_DIR, 'firmware.bin');
  const apkBin = path.join(ROOT_DIR, 'ZenHome_Release.apk');

  if (!skipBuild) {
    if (!onlyApk) {
      console.log('\n[1/2] ⚙️ Đang biên dịch Firmware ESP32 qua PlatformIO...');
      try {
        const pioCmd = `C:\\Users\\dinht\\.platformio\\penv\\Scripts\\pio.exe run -d "${path.join(ROOT_DIR, 'esp32_1')}"`;
        execSync(pioCmd, { stdio: 'inherit' });
        const compiledBin = path.join(ROOT_DIR, 'esp32_1', '.pio', 'build', 'esp32dev', 'firmware.bin');
        if (fs.existsSync(compiledBin)) {
          fs.copyFileSync(compiledBin, espBin);
          const srvEspPath = path.join(ROOT_DIR, 'zenhome-server', 'public', 'firmware', 'esp32', 'firmware.bin');
          fs.mkdirSync(path.dirname(srvEspPath), { recursive: true });
          fs.copyFileSync(compiledBin, srvEspPath);
          console.log(`   ✅ Đã sao chép firmware.bin (${fs.statSync(espBin).size} bytes) vào root & server`);
        }
      } catch (e) {
        console.error('❌ Lỗi biên dịch ESP32 Firmware:', e.message);
        process.exit(1);
      }
    }

    if (!onlyEsp) {
      console.log('\n[2/2] 📱 Đang biên dịch ZenHome Android App qua Flutter Release...');
      try {
        execSync(`flutter build apk --release`, { cwd: path.join(ROOT_DIR, 'zenhome_app'), stdio: 'inherit' });
        const compiledApk = path.join(ROOT_DIR, 'zenhome_app', 'build', 'app', 'outputs', 'flutter-apk', 'app-release.apk');
        const altApk = path.join(ROOT_DIR, 'zenhome_app', 'build', 'app', 'outputs', 'apk', 'release', 'app-release.apk');
        const srcApk = fs.existsSync(compiledApk) ? compiledApk : altApk;
        if (fs.existsSync(srcApk)) {
          fs.copyFileSync(srcApk, apkBin);
          const rootAltApk = path.join(ROOT_DIR, 'zenhome-app-release.apk');
          fs.copyFileSync(srcApk, rootAltApk);
          const srvApk1 = path.join(ROOT_DIR, 'zenhome-server', 'public', 'downloads', 'ZenHome_Release.apk');
          const srvApk2 = path.join(ROOT_DIR, 'zenhome-server', 'public', 'downloads', 'zenhome-app-release.apk');
          fs.mkdirSync(path.dirname(srvApk1), { recursive: true });
          fs.copyFileSync(srcApk, srvApk1);
          fs.copyFileSync(srcApk, srvApk2);
          console.log(`   ✅ Đã sao chép ZenHome_Release.apk (${fs.statSync(apkBin).size} bytes) vào root & server public downloads`);
        }
      } catch (e) {
        console.error('❌ Lỗi biên dịch Flutter APK:', e.message);
        process.exit(1);
      }
    }
  } else {
    console.log('\n⏩ Bỏ qua bước biên dịch, sử dụng file có sẵn tại thư mục gốc.');
  }

  // 4. Kiểm tra sự tồn tại của file nhị phân
  if (!onlyApk && !fs.existsSync(espBin)) {
    console.error(`❌ Không tìm thấy ${espBin}! Vui lòng build trước.`);
    process.exit(1);
  }
  if (!onlyEsp && !fs.existsSync(apkBin)) {
    console.error(`❌ Không tìm thấy ${apkBin}! Vui lòng build trước.`);
    process.exit(1);
  }

  const espSha = fs.existsSync(espBin) ? computeSha256(espBin) : '';
  const apkSha = fs.existsSync(apkBin) ? computeSha256(apkBin) : '';
  let espSig = '';
  if (fs.existsSync(espBin)) {
    try {
      ensureKeysExist();
      const signed = signFirmwareBinary(espBin);
      espSig = signed.sigHex;
    } catch (e) {
      console.warn('   ⚠️ Không thể tạo chữ ký số ECDSA:', e.message);
    }
  }

  console.log('\n📋 THÔNG TIN GÓI PHÁT HÀNH:');
  if (espSha) console.log(`   - Firmware:  ${espBin} (${fs.statSync(espBin).size} bytes | SHA: ${espSha})`);
  if (espSig) console.log(`   - Chữ ký số: ECDSA P-256 (${espSig.substring(0, 32)}...)`);
  if (apkSha) console.log(`   - App APK:   ${apkBin} (${fs.statSync(apkBin).size} bytes | SHA: ${apkSha})`);

  // 5. Tìm hoặc tạo GitHub Release
  console.log(`\n☁️  Đang kết nối GitHub Repository ${REPO_OWNER}/${REPO_NAME}...`);
  let release = null;
  try {
    release = await githubRequest('GET', `/repos/${REPO_OWNER}/${REPO_NAME}/releases/tags/${tagVersion}`, token);
    console.log(`   🔍 Đã tìm thấy Release có sẵn (${tagVersion}, ID: ${release.id})`);
  } catch (err) {
    console.log(`   ✨ Chưa có Release ${tagVersion}. Đang tạo Release mới trên GitHub...`);
    release = await githubRequest('POST', `/repos/${REPO_OWNER}/${REPO_NAME}/releases`, token, {
      tag_name: tagVersion,
      name: releaseTitle,
      body: releaseNotes,
      draft: false,
      prerelease: false,
      make_latest: 'true'
    });
    console.log(`   ✅ Đã tạo mới Release thành công (ID: ${release.id})`);
  }

  // 6. Dọn dẹp asset cũ trùng tên nếu có
  if (release.assets && release.assets.length > 0) {
    const metaPath = path.join(ROOT_DIR, 'release_metadata.json');
    fs.writeFileSync(metaPath, JSON.stringify({
      version: pubspecVersion,
      build: pubspecBuild,
      tag: tagVersion,
      sha256: espSha,
      sig: espSig,
      fileSizeBytes: fs.existsSync(espBin) ? fs.statSync(espBin).size : 0,
      updatedAt: new Date().toISOString()
    }, null, 2), 'utf8');

    for (const asset of release.assets) {
      const isTarget = (!onlyApk && asset.name === 'firmware.bin') || 
                       (!onlyEsp && asset.name === 'ZenHome_Release.apk') ||
                       (asset.name === 'release_metadata.json');
      if (isTarget) {
        console.log(`   🗑️  Xóa asset cũ [${asset.name}] (ID: ${asset.id}) để tải lên bản mới...`);
        try {
          await githubRequest('DELETE', `/repos/${REPO_OWNER}/${REPO_NAME}/releases/assets/${asset.id}`, token);
        } catch (_) {}
      }
    }
  }

  // 7. Tải file nhị phân lên GitHub Releases
  console.log(`\n📤 BẮT ĐẦU ĐẨY TỆP LÊN GITHUB RELEASES ASSETS:`);
  if (!onlyApk && fs.existsSync(espBin)) {
    await uploadReleaseAsset(release.upload_url, token, espBin, 'firmware.bin');
    console.log(`   🎉 Đã đẩy thành công firmware.bin lên GitHub Releases!`);
  }
  const metaPath = path.join(ROOT_DIR, 'release_metadata.json');
  if (fs.existsSync(metaPath)) {
    await uploadReleaseAsset(release.upload_url, token, metaPath, 'release_metadata.json');
    console.log(`   🎉 Đã đẩy thành công release_metadata.json lên GitHub Releases!`);
  }
  if (!onlyEsp && fs.existsSync(apkBin)) {
    await uploadReleaseAsset(release.upload_url, token, apkBin, 'ZenHome_Release.apk');
    console.log(`   🎉 Đã đẩy thành công ZenHome_Release.apk lên GitHub Releases!`);
  }

  // 8. Cập nhật Cloud Firestore & Server Metadata
  console.log('\n🔥 ĐANG ĐỒNG BỘ PHIÊN BẢN LÊN CLOUD FIRESTORE & SERVER...');
  try {
    execSync('npx tsx update_firestore_release.ts', { cwd: path.join(ROOT_DIR, 'zenhome-server'), stdio: 'inherit' });
    console.log('   ✅ Đã cập nhật thành công Metadata lên Cloud Firestore & Server!');
  } catch (err) {
    console.warn('   ⚠️ Lỗi khi chạy update_firestore_release.ts:', err.message);
  }

  console.log('\n=================================================================');
  console.log('       🎉 TỰ ĐỘNG XUẤT BẢN LÊN GITHUB THÀNH CÔNG RỰC RỠ! 🎉      ');
  console.log('=================================================================');
  console.log(`🌐 Link Release Web:    https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/tag/${tagVersion}`);
  console.log(`⬇️  Link tải APK:       https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download/ZenHome_Release.apk`);
  console.log(`⬇️  Link tải Firmware:  https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/latest/download/firmware.bin`);
  console.log('=================================================================\n');
}

main().catch(err => {
  console.error('\n❌ LỖI TRONG QUÁ TRÌNH TỰ ĐỘNG XUẤT BẢN:', err.message);
  process.exit(1);
});
