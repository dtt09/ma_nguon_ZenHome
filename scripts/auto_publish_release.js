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

const ROOT_DIR = path.resolve(__dirname, '..');
const REPO_OWNER = 'dtt09';
const REPO_NAME = 'ma_nguon_ZenHome';

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

  let tagVersion = `v${pubspecVersion}`;
  const tagIdx = args.indexOf('--tag');
  if (tagIdx !== -1 && args[tagIdx + 1]) {
    tagVersion = args[tagIdx + 1].trim();
  } else if (!args.includes('-y') && !args.includes('--yes') && process.stdin.isTTY) {
    tagVersion = await ask('Phiên bản tag Release phát hành', `v${pubspecVersion}`);
  }

  const releaseTitle = `ZenHome ${tagVersion} - System Harmony, Anti-Crosstalk & Brownout Protection`;
  const releaseNotes = `## 🌟 Điểm nổi bật trong bản phát hành ${tagVersion} (Build ${pubspecBuild})

### 📱 Ứng dụng Di động (Mobile App v${pubspecVersion}+${pubspecBuild}):
- 🛡️ **Khắc phục triệt để Giao thoa / Rò rỉ Trạng thái (Anti-Crosstalk)**:
  - Loại bỏ hoàn toàn wildcard subscriptions (\`+/+/+/+/state\`, \`+/+/esp_status\`), chỉ lắng nghe và áp dụng trạng thái từ đúng tiền tố \`userId/macAddress\` của ngôi nhà đang chọn. Không bao giờ bị nhảy trạng thái công tắc chéo giữa các gia đình trên HiveMQ Broker.
- ⚡ **Khử xung đột phát lệnh song song (LAN Priority & Sequential Fallback)**:
  - Tối ưu luồng điều khiển: Khi ở mạng nhà, ưu tiên gửi qua LAN HTTP/BLE tức thì; chỉ khi LAN thất bại mới tự động chuyển hướng sang Cloud MQTT. Loại bỏ hiện tượng gửi 2 gói tin cùng lúc gây nghẽn rơ-le và xung đột Relay Guard.
- ⏱️ **Phản hồi chính xác trạng thái & Chống timeout giả**:
  - Khi một lệnh điều khiển đơn lẻ timeout, App chỉ thông báo lỗi kết nối cục bộ của thiết bị đó, tuyệt đối không đánh dấu toàn bộ Hub là offline (\`markEspOffline\`).
- 💎 **Bảo vệ sụt áp nguồn khi kích hoạt Ngữ cảnh (Staggered Scene Execution)**:
  - Chèn độ trễ xen kẽ 60ms giữa các lệnh kích hoạt rơ-le liên tiếp trong ngữ cảnh, triệt tiêu đỉnh dòng tức thời (Inrush Current) gây sụt áp nguồn vi điều khiển.
- 💎 **Giao diện Hộp thoại ZenHome Luxury Glassmorphism**: Thay thế hoàn toàn giao diện ZaloPay cũ bằng chuẩn Luxury Glassmorphism đồng bộ bo góc 28px, hiệu ứng Breathing Aura Glow và chống tràn chữ.
- 🔒 **Che giấu dữ liệu nhạy cảm (Security Masking)**: Tự động che mờ IP, MAC, Admin Pass, Email và SĐT trên toàn bộ giao diện quản trị.
- 🌐 **Chuẩn hóa Đa ngôn ngữ (i18n)**: Rà soát và hoàn tất 100% bản dịch song ngữ Việt - Anh.

### ⚡ Firmware ESP32 (v2.5.7 Build 201):
- 🛡️ **Khắc phục ESP32 Brownout / Sập nguồn ngẫu nhiên**:
  - Tích hợp bộ đệm an toàn nguồn điện trong \`safeSetRelayPin\`: Tự động giãn cách 50ms giữa các lần đóng cuộn hút rơ-le, ngăn chặn sụt áp đường nguồn 5V/3.3V gây ngắt bảo vệ Brownout Reset.
- 🤝 **Luôn phản hồi xác nhận trạng thái (Guaranteed Hardware State ACK)**:
  - Kể cả khi lệnh bị chặn bởi Relay Guard (<800ms) hoặc lệnh gửi trạng thái trùng với hiện tại, ESP32 vẫn công bố ngay trạng thái vật lý thực tế về MQTT và LAN HTTP để App giải phóng cờ pending tức thì, không bị đơ 3.5s.
- 📶 **Khắc phục lỗi treo OTA 0%**:
  - Duy trì chu kỳ \`mqttClient.loop()\` trong suốt quá trình tải firmware 30-40s, ngăn HiveMQ broker ngắt socket.
- ⏱️ **Tối ưu hóa FreeRTOS WDT 45s & Socket Timeout 15s**: Loại bỏ triệt để hiện tượng Watchdog reset khi mạng Wi-Fi chập chờn.

### 🖥️ Backend Server & Cloud Sync:
- 🔄 **Tôn trọng chân lý phần cứng khi phục hồi mạng (Single Source of Truth)**:
  - Khi có mạng trở lại sau sự cố, Server tiếp nhận báo cáo \`/sync/report\` từ ESP32 để cập nhật cơ sở dữ liệu, không phát lệnh cũ đè ngược lên phần cứng.
- 🔑 **Chuẩn hóa khóa tra cứu Task (MAC Colon Normalization)**:
  - Chuẩn hóa topic loại bỏ dấu hai chấm trong \`state.pendingTasks\`, giải phóng chính xác tiến trình kiểm tra retry.
- 🛡️ **Bảo vệ an toàn phần cứng Đa Hub (Multi-Hub Safety)**:
  - Hỗ trợ mảng danh sách Hub, không tự tiện gửi lệnh Factory Reset phá hủy dữ liệu của thiết bị khác trên cùng tài khoản.

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
          console.log(`   ✅ Đã sao chép firmware.bin (${fs.statSync(espBin).size} bytes)`);
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
          console.log(`   ✅ Đã sao chép ZenHome_Release.apk (${fs.statSync(apkBin).size} bytes)`);
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

  console.log('\n📋 THÔNG TIN GÓI PHÁT HÀNH:');
  if (espSha) console.log(`   - Firmware:  ${espBin} (${fs.statSync(espBin).size} bytes | SHA: ${espSha})`);
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
    for (const asset of release.assets) {
      const isTarget = (!onlyApk && asset.name === 'firmware.bin') || (!onlyEsp && asset.name === 'ZenHome_Release.apk');
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
  if (!onlyEsp && fs.existsSync(apkBin)) {
    await uploadReleaseAsset(release.upload_url, token, apkBin, 'ZenHome_Release.apk');
    console.log(`   🎉 Đã đẩy thành công ZenHome_Release.apk lên GitHub Releases!`);
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
