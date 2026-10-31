export interface ServerCpuInfo {
  usagePercent: number;
  cores: number;
  model: string;
  speedMhz?: number;
  loadAvg?: number[];
}

export interface ServerSystemRamInfo {
  totalGB: number;
  usedGB: number;
  freeGB: number;
  usedPercent: number;
  totalBytes?: number;
  usedBytes?: number;
  freeBytes?: number;
}

export interface ServerDiskInfo {
  drive: string;
  totalGB: number;
  usedGB: number;
  freeGB: number;
  usedPercent: number;
  totalBytes?: number;
  usedBytes?: number;
  freeBytes?: number;
  error?: string;
}

export interface ServerMemoryInfo {
  heapUsedMB: number;
  heapTotalMB: number;
  rssMB: number;
  heapPercent: number;
}

export interface SubsystemsInfo {
  mqtt: {
    connected: boolean;
    broker: string;
    lastMessageAt?: string | null;
    reconnectCount?: number;
  };
  firestore: {
    connected: boolean;
    projectId: string;
    region: string;
  };
  cron: {
    active: boolean;
    timezone: string;
    lastRunAt?: string | null;
  };
}

export interface ServerProcessInfo {
  nodeVersion: string;
  platform: string;
  arch?: string;
  pid: number;
}

export interface ServerTelemetryPayload {
  serverTimestamp: number;
  serverTimeIso: string;
  serverTimeFormatted: string;
  bootTime?: string;
  uptime: number;
  uptimeFormatted?: string;
  cpu?: ServerCpuInfo;
  ram?: ServerSystemRamInfo;
  disk?: ServerDiskInfo;
  memory: ServerMemoryInfo;
  subsystems: SubsystemsInfo;
  processInfo?: ServerProcessInfo;
  pendingTasksCount: number;
  activeTimersCount: number;
  activeSchedulesCount: number;
  latestIndoorTemp?: Record<string, { temp: number; updatedAt: string }>;
  espOnlineStatus?: Record<string, { isOnline: boolean; lastSeen: string }>;
  connectedClients?: number;
  clientTimestamp?: number;
  serverAckTime?: number;
}

export interface BackupServerStatus {
  status: 'connected' | 'disconnected' | 'connecting';
  serverName: string;
  heartbeatMessage?: string;
  version: string;
  uptimeSeconds: number;
  uptimeFormatted?: string;
  serverTimestamp?: number;
  serverTimeIso?: string;
  serverTimeFormatted?: string;
  connectedDatabase: string;
  region: string;
  mqttBroker: string;
  cpu?: ServerCpuInfo;
  ram?: ServerSystemRamInfo;
  disk?: ServerDiskInfo;
  memory?: ServerMemoryInfo;
  subsystems?: SubsystemsInfo;
  processInfo?: ServerProcessInfo;
  activeObservers: Array<{
    name: string;
    status: string;
    type: string;
    description: string;
  }>;
  totalDeletionJobs: number;
  lastHeartbeat: string;
  targetUrl?: string;
}

export interface BackupRecord {
  id: string;
  timestamp: string;
  displayTime?: string;
  docCount: number;
  sizeBytes: number;
  collections: string[];
}

export interface ServerEventLog {
  id: string;
  timestamp: string;
  level: 'info' | 'warn' | 'error' | 'success';
  message: string;
  source: string;
}

/**
 * Tự động phát hiện URL máy chủ Backend chính xác theo môi trường mạng và đồng bộ cổng:
 * 1. Nếu mở từ cổng Dev (port 3000 hoặc 5173), tự động kết nối sang backend port 5000 (cùng hostname/IP LAN)
 * 2. Nếu mở từ cổng Production (port 5000), dùng trực tiếp window.location.origin
 * 3. Nếu có cấu hình VITE_API_URL thì ưu tiên dùng
 */
export function getServerBaseUrl(): string {
  if (typeof window !== 'undefined') {
    if (window.location.port === '3000' || window.location.port === '5173') {
      return `${window.location.protocol}//${window.location.hostname}:5000`;
    }
    return window.location.origin;
  }
  return import.meta.env.VITE_API_URL || 'http://localhost:5000';
}

export const DEFAULT_SERVER_URL = getServerBaseUrl();

export function getAdminSecret(): string {
  try {
    const saved = sessionStorage.getItem('zenhome_admin_key') || localStorage.getItem('zenhome_admin_key');
    if (saved && saved.trim()) return saved.trim();
  } catch (e) {}
  return '';
}

export async function verifyAdminSecret(secret: string): Promise<boolean> {
  const trimmed = secret.trim();
  if (!trimmed) return false;
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);
    const res = await fetch(`${DEFAULT_SERVER_URL}/api/node-server/action`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${trimmed}`,
        'x-api-key': trimmed,
      },
      body: JSON.stringify({ action: 'verify_admin' }),
      signal: controller.signal,
    });
    clearTimeout(timeoutId);
    if (res.ok) return true;
    if (res.status === 401 || res.status === 403) return false;
  } catch (e) {
    console.warn('[AUTH] Không thể kết nối tới server để xác thực Admin Key:', e);
  }
  return false;
}

// Get configured backup server base URL (e.g. https://... on Render or empty for local)
export function getBackupServerBaseUrl(): string {
  try {
    const customUrl = localStorage.getItem('zenhome_render_server_url');
    if (customUrl && customUrl.trim()) {
      return customUrl.trim().replace(/\/+$/, '');
    }
  } catch (e) {}
  return DEFAULT_SERVER_URL;
}

export function setBackupServerBaseUrl(url: string): void {
  try {
    localStorage.setItem('zenhome_render_server_url', url.trim());
  } catch (e) {}
}

export async function checkBackupServerHealth(): Promise<BackupServerStatus> {
  const customUrl = localStorage.getItem('zenhome_render_server_url')?.trim() || '';

  // If user configured a custom Render URL, test via backend proxy
  if (customUrl) {
    try {
      const proxyRes = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/proxy-ping`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ serverUrl: customUrl }),
      });

      if (proxyRes.ok) {
        const proxyData = await proxyRes.json();
        return {
          status: proxyData.connected ? 'connected' : 'disconnected',
          serverName: 'ZenHome Node.js Server (Render Production)',
          heartbeatMessage: proxyData.heartbeatMessage || 'Trạm giám sát IoT đang thức! (Đã Modular hóa)',
          version: '2.5.0-stem',
          uptimeSeconds: 3600,
          connectedDatabase: 'smarthome-98dd7',
          region: 'asia-southeast1',
          mqttBroker: 'mqtts://e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud:8883',
          activeObservers: [
            {
              name: 'startListeningToDeleteRequests()',
              status: 'active',
              type: 'Firestore Cleanup Observer',
              description: 'Lắng nghe collection delete_requests để tự động gửi lệnh reset ESP32 và xóa Auth User.'
            },
            {
              name: 'startListeningToUnlinkRequests()',
              status: 'active',
              type: 'Unlink Listener',
              description: 'Lắng nghe collection unlink_requests để giải phóng email/phone.'
            },
            {
              name: 'startListeningToAlerts()',
              status: 'active',
              type: 'Security & Garbage Collector',
              description: 'Dọn đệ quy subcollections: history, sessions, alerts, timers, schedules.'
            },
            {
              name: 'startJunkAccountCleanupCron()',
              status: 'active',
              type: 'Daily 03:00 Cron',
              description: 'Tự động quét và dọn tài khoản rác không có UID.'
            },
            {
              name: 'sendCommandWithRetry()',
              status: 'active',
              type: 'MQTT Resiliency Worker',
              description: 'Cơ chế thử lại tối đa 10 lần bảo vệ toàn vẹn bản tin.'
            }
          ],
          totalDeletionJobs: 1,
          lastHeartbeat: new Date().toISOString(),
          targetUrl: customUrl,
        };
      }
    } catch (e) {
      console.warn('Proxy ping failed, falling back to local server', e);
    }
  }

  // Fallback to local server (port 5000)
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/status`);
  if (!res.ok) {
    throw new Error(`Server returned HTTP ${res.status}`);
  }
  return await res.json();
}

export async function sendDeleteRequestToBackupServer(payload: {
  targetUser: string;
  targetUid: string;
  macAddress: string;
  reason?: string;
  requester?: string;
}): Promise<{
  success: boolean;
  transactionId: string;
  message: string;
  timestamp: string;
}> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/delete-request`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Lỗi từ Server Backup (HTTP ${res.status}): ${errorText}`);
  }

  return await res.json();
}

export async function triggerDatabaseBackupSnapshot(): Promise<{
  success: boolean;
  backup: BackupRecord;
  message: string;
}> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/trigger-backup`, {
    method: 'POST',
    headers: { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`
    },
  });

  if (!res.ok) {
    throw new Error(`Lỗi khi tạo sao lưu (HTTP ${res.status})`);
  }

  return await res.json();
}

export async function fetchBackupRecords(): Promise<BackupRecord[]> {
  try {
    const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/backups`, {
      headers: {
        'Authorization': `Bearer ${getAdminSecret()}`
      }
    });
    if (!res.ok) return [];
    const data = await res.json();
    return data.backups || [];
  } catch (e) {
    return [];
  }
}

export async function fetchAppVersionInfo(): Promise<any> {
  try {
    const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/system/app-version`);
    if (!res.ok) return null;
    const data = await res.json();
    return data.data || null;
  } catch (e) {
    return null;
  }
}

export async function updateAppVersionInfo(payload: any): Promise<{ success: boolean; message: string; data?: any }> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/system/app-version`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lỗi cập nhật phiên bản (HTTP ${res.status}): ${errText}`);
  }

  return await res.json();
}

export async function downloadBackupFile(backupId: string): Promise<void> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/download/${encodeURIComponent(backupId)}`, {
    headers: {
      'Authorization': `Bearer ${getAdminSecret()}`
    }
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Không thể tải bản sao lưu (HTTP ${res.status}): ${errorText}`);
  }
  const blob = await res.blob();
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${backupId}.json`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  window.URL.revokeObjectURL(url);
}

export async function restoreBackupSnapshot(backupId: string): Promise<{
  success: boolean;
  restoredDocuments: number;
  message: string;
}> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/restore/${encodeURIComponent(backupId)}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`
    }
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Lỗi khôi phục bản sao lưu (HTTP ${res.status}): ${errorText}`);
  }
  return await res.json();
}

// ==========================================
// QUẢN LÝ NÂNG CẤP FIRMWARE ESP32 TỪ XA (OTA)
// ==========================================

export interface Esp32FirmwareInfo {
  exists: boolean;
  version: string;
  buildNumber: number;
  fileName: string;
  fileSizeBytes: number;
  sha256: string;
  directUrl: string;
  releaseNotesVi?: string;
  lastDeployedAt: string;
  supportedHardware: string;
}

export interface Esp32PublishPayload {
  version: string;
  buildNumber: number;
  directUrl: string;
  sha256?: string;
  fileSizeBytes?: number;
  releaseNotesVi?: string;
  triggerFleetOta?: boolean;
}

export async function publishEsp32Firmware(payload: Esp32PublishPayload): Promise<{ success: boolean; message: string; dispatchedCount?: number; data?: any }> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/hub/ota/publish`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lỗi phát hành Firmware ESP32 (HTTP ${res.status}): ${errText}`);
  }

  return await res.json();
}

export async function fetchEsp32OtaInfo(): Promise<Esp32FirmwareInfo | null> {
  try {
    const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/hub/ota/info`);
    if (!res.ok) return null;
    const data = await res.json();
    return data.data || null;
  } catch (e) {
    return null;
  }
}

export async function triggerEsp32Ota(payload: {
  userId?: string;
  macAddress: string;
  version?: string;
}): Promise<{ success: boolean; message: string; data?: any }> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/hub/ota/trigger`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lỗi phát lệnh OTA (HTTP ${res.status}): ${errText}`);
  }

  return await res.json();
}

export async function deployPlatformIoBuild(payload?: {
  version?: string;
  buildNumber?: number;
}): Promise<{ success: boolean; message: string; data?: any }> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/hub/ota/deploy-build`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`,
    },
    body: JSON.stringify(payload || {}),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lỗi triển khai build PlatformIO (HTTP ${res.status}): ${errText}`);
  }

  return await res.json();
}

export async function uploadEsp32Firmware(payload: {
  base64Data: string;
  version: string;
  buildNumber: number;
}): Promise<{ success: boolean; message: string; data?: any }> {
  const res = await fetch(`${DEFAULT_SERVER_URL}/api/v1/hub/ota/upload`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${getAdminSecret()}`,
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lỗi tải lên Firmware (HTTP ${res.status}): ${errText}`);
  }

  return await res.json();
}
