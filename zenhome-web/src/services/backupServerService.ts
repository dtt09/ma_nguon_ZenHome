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

const DEFAULT_SERVER_URL = import.meta.env.VITE_API_URL || (typeof window !== 'undefined' ? window.location.origin : 'http://localhost:5000');

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
      'Authorization': 'Bearer zenhome-admin-secret-2026'
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
      'Authorization': 'Bearer zenhome-admin-secret-2026'
    },
  });

  if (!res.ok) {
    throw new Error(`Lỗi khi tạo sao lưu (HTTP ${res.status})`);
  }

  return await res.json();
}

export async function fetchBackupRecords(): Promise<BackupRecord[]> {
  try {
    const res = await fetch(`${DEFAULT_SERVER_URL}/api/backup-server/backups`);
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
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Lỗi cập nhật phiên bản (HTTP ${res.status}): ${errText}`);
  }

  return await res.json();
}
