import os from 'os';
import net from 'net';
import { addLog } from '../zenhomeState';
import { db, FieldValue } from './firebase';


export interface ServerNetworkInfo {
  localIp: string;
  port: number;
  serverBaseUrl: string;
  directApkUrl: string;
  apiBaseUrl: string;
  docsUrl: string;
  hostname: string;
  platform: string;
  status: 'online' | 'offline';
  lastBootAt?: string;
  updatedAt?: string;
}

let currentConfig: ServerNetworkInfo = {
  localIp: '127.0.0.1',
  port: 5000,
  serverBaseUrl: 'http://localhost:5000',
  directApkUrl: 'http://localhost:5000/public/downloads/zenhome-app-release.apk',
  apiBaseUrl: 'http://localhost:5000/api/v1',
  docsUrl: 'http://localhost:5000/api/docs',
  hostname: os.hostname(),
  platform: os.platform(),
  status: 'online',
};

let lastSyncedIp: string = '';
let syncIntervalTimer: NodeJS.Timeout | null = null;

/**
 * Tự động phát hiện địa chỉ IPv4 LAN đang hoạt động thực tế trên máy tính (Windows/Linux/Mac)
 * 1. Dùng kết nối thăm dò OS route (net.createConnection tới 8.8.8.8:53) để lấy IP gateway chính
 * 2. Fallback: Quét danh sách adapter mạng, ưu tiên Ethernet/Wi-Fi và lọc bỏ card ảo/hotspot
 */
export async function detectActiveLocalIp(): Promise<string> {
  // Phương pháp 1: Thăm dò bảng định tuyến hệ điều hành (chính xác tuyệt đối)
  try {
    const routeIp = await new Promise<string>((resolve, reject) => {
      const socket = net.createConnection({ host: '8.8.8.8', port: 53 });
      socket.setTimeout(1200);
      socket.on('connect', () => {
        const addr = socket.localAddress;
        socket.destroy();
        if (addr && addr !== '127.0.0.1' && !addr.startsWith('169.254')) {
          resolve(addr);
        } else {
          reject(new Error('Invalid local address from probe'));
        }
      });
      socket.on('timeout', () => {
        socket.destroy();
        reject(new Error('Probe timeout'));
      });
      socket.on('error', (err) => {
        socket.destroy();
        reject(err);
      });
    });
    if (routeIp) return routeIp;
  } catch (err) {
    // Tiếp tục fallback quét network interfaces
  }

  // Phương pháp 2: Quét toàn bộ network interfaces của máy tính
  try {
    const interfaces = os.networkInterfaces();
    const candidates: { name: string; address: string; score: number }[] = [];

    for (const [name, addrs] of Object.entries(interfaces)) {
      if (!addrs) continue;
      const lowerName = name.toLowerCase();
      const isVirtual = /vethernet|virtualbox|vmware|hyper-v|wsl|loopback|teredo|bluetooth|local area connection/i.test(lowerName);
      const isPreferred = /wi-?fi|wlan|wireless|ethernet|lan|en0|eth0|wlan0/i.test(lowerName);

      for (const iface of addrs) {
        const isIpv4 = iface.family === 'IPv4' || (iface.family as any) === 4;
        if (isIpv4 && !iface.internal && !iface.address.startsWith('169.254') && iface.address !== '127.0.0.1') {
          let score = 0;
          if (isPreferred) score += 60;
          if (isVirtual) score -= 40;
          // Windows Mobile Hotspot mặc định thường có dải 192.168.137.x
          if (iface.address.startsWith('192.168.137.')) score -= 30;
          // Dải mạng LAN gia đình phổ biến
          if (iface.address.startsWith('192.168.') || iface.address.startsWith('10.') || iface.address.startsWith('172.')) {
            score += 25;
          }
          candidates.push({ name, address: iface.address, score });
        }
      }
    }

    if (candidates.length > 0) {
      candidates.sort((a, b) => b.score - a.score);
      return candidates[0].address;
    }
  } catch (err) {
    // fallback
  }

  if (lastSyncedIp && lastSyncedIp !== '127.0.0.1') {
    return lastSyncedIp;
  }
  return '127.0.0.1';
}

/**
 * Đồng bộ thông tin IP máy chủ lên Cloud Firestore
 * - system_config/server_config
 * - system_config/app_version (cập nhật directApkUrl & serverBaseUrl)
 */
export async function syncServerConfigToFirestore(port: number): Promise<ServerNetworkInfo> {
  const localIp = await detectActiveLocalIp();
  if (localIp === '127.0.0.1' || !localIp) {
    console.warn('[NETWORK] ⚠️ Bỏ qua đồng bộ IP loopback 127.0.0.1 lên Firestore để tránh lỗi kết nối thiết bị.');
    return currentConfig;
  }

  const serverBaseUrl = `http://${localIp}:${port}`;
  const directApkUrl = `http://${localIp}:${port}/public/downloads/zenhome-app-release.apk`;
  const apiBaseUrl = `http://${localIp}:${port}/api/v1`;
  const docsUrl = `http://${localIp}:${port}/api/docs`;
  const nowIso = new Date().toISOString();

  currentConfig = {
    localIp,
    port,
    serverBaseUrl,
    directApkUrl,
    apiBaseUrl,
    docsUrl,
    hostname: os.hostname(),
    platform: os.platform(),
    status: 'online',
    lastBootAt: currentConfig.lastBootAt || nowIso,
    updatedAt: nowIso,
  };

  if (!db) {
    console.warn('[NETWORK] ⚠️ Không tìm thấy kết nối Firestore để đồng bộ IP.');
    return currentConfig;
  }

  try {
    // 1. Cập nhật system_config/server_config
    const serverConfigRef = db.collection('system_config').doc('server_config');
    await serverConfigRef.set(
      {
        localIp,
        port,
        serverBaseUrl,
        directApkUrl,
        apiBaseUrl,
        docsUrl,
        hostname: os.hostname(),
        platform: os.platform(),
        status: 'online',
        updatedAt: nowIso,
        lastBootAt: currentConfig.lastBootAt,
      },
      { merge: true }
    );

    // 2. Cập nhật downloadUrl, directApkUrl và serverBaseUrl trong system_config/app_version
    // để App di động và Web Admin luôn nhận link tải trực tiếp theo IP mới nhất
    const appVersionRef = db.collection('system_config').doc('app_version');
    await appVersionRef.set(
      {
        downloadUrl: directApkUrl,
        directApkUrl,
        serverBaseUrl,
        lastServerSyncAt: nowIso,
      },
      { merge: true }
    );

    lastSyncedIp = localIp;
    console.log(`[NETWORK] 📡 Đã đồng bộ IP máy chủ: ${localIp}:${port} -> Cloud Firestore (server_config & app_version)`);
    addLog('[NETWORK]', `📡 Đã đồng bộ IP máy chủ (${localIp}:${port}) lên Cloud Firestore thành công.`, 'success');
  } catch (err: any) {
    console.error('[NETWORK] ❌ Lỗi đồng bộ IP máy chủ lên Firestore:', err.message);
    addLog('[NETWORK]', `❌ Lỗi đồng bộ IP lên Firestore: ${err.message}`, 'error');
  }

  return currentConfig;
}

/**
 * Trả về thông tin mạng máy chủ hiện tại trong RAM
 */
export function getCurrentServerConfig(): ServerNetworkInfo {
  return currentConfig;
}

/**
 * Bộ giám sát ngầm: Kiểm tra định kỳ (mỗi 30s) nếu IP máy tính thay đổi
 * thì tự động đẩy IP mới lên Firestore để ứng dụng không bị mất kết nối
 */
export function startNetworkSyncWatcher(port: number, intervalMs: number = 30000) {
  if (syncIntervalTimer) {
    clearInterval(syncIntervalTimer);
  }

  syncIntervalTimer = setInterval(async () => {
    try {
      const activeIp = await detectActiveLocalIp();
      if (activeIp && activeIp !== '127.0.0.1' && activeIp !== lastSyncedIp) {
        console.log(`[NETWORK] 🔄 Phát hiện IP máy chủ thay đổi (${lastSyncedIp} ➔ ${activeIp})! Đang đồng bộ...`);
        addLog('[NETWORK]', `🔄 Phát hiện IP máy chủ thay đổi (${lastSyncedIp} ➔ ${activeIp})! Tự động cập nhật Database...`, 'info');
        await syncServerConfigToFirestore(port);
      } else if (db && activeIp && activeIp !== '127.0.0.1') {
        // Cập nhật heartbeat định kỳ để báo server vẫn đang online
        await db.collection('system_config').doc('server_config').set(
          {
            status: 'online',
            updatedAt: new Date().toISOString(),
          },
          { merge: true }
        );
      }
    } catch (e: any) {
      // Bỏ qua lỗi ngầm
    }
  }, intervalMs);
}
