export interface LogEntry {
  id: string;
  timestamp: string;
  tag: string;
  message: string;
  rawFormatted: string;
  level: 'info' | 'warn' | 'error' | 'success';
}

export interface ZenHomeServerState {
  pendingTasks: Record<string, {
    targetState: string;
    intervalId?: any;
    source: string;
    retryCount: number;
    startedAt: string;
  }>;
  activeTimers: Record<string, any>;
  activeSchedules: Record<string, {
    baseTopic: string;
    timeOn?: string;
    timeOff?: string;
    days: any;
    isTriggeredOn?: boolean;
    isTriggeredOff?: boolean;
  }>;
  lastTempAlert: Record<string, number>;
  latestIndoorTemp: Record<string, { temp: number; updatedAt: string }>;
  espOnlineStatus: Record<string, { isOnline: boolean; lastSeen: string }>;
  offlineDebounceTimers?: Record<string, any>;
  mqttStatus?: {
    connected: boolean;
    broker: string;
    lastConnectedAt?: string | null;
    lastMessageAt?: string | null;
    reconnectCount: number;
  };
  cronStatus?: {
    active: boolean;
    timezone: string;
    lastRunAt?: string | null;
    pattern?: string;
  };
}

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { state as coreState } from './core/state';
import { db } from './core/firebase';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.resolve(__dirname, 'data');
const BACKUPS_FILE = path.join(DATA_DIR, 'backups.json');
const LOGS_FILE = path.join(DATA_DIR, 'logs.json');

export const state: ZenHomeServerState = coreState as any;
if (!state.lastTempAlert) state.lastTempAlert = {};

// Rolling buffer of the latest logs for real-time web streaming
export let serverLogs: LogEntry[] = [];

export interface BackupRecord {
  id: string;
  timestamp: string;
  docCount: number;
  sizeBytes: number;
  collections: string[];
}

export let storedBackups: BackupRecord[] = [];

// Khởi tạo thư mục data và load dữ liệu cục bộ
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

if (fs.existsSync(BACKUPS_FILE)) {
  try {
    const data = fs.readFileSync(BACKUPS_FILE, 'utf-8');
    storedBackups = JSON.parse(data);
  } catch (e) {
    console.error('[BACKEND] Lỗi đọc file backups.json', e);
  }
}

if (fs.existsSync(LOGS_FILE)) {
  try {
    const data = fs.readFileSync(LOGS_FILE, 'utf-8');
    serverLogs = JSON.parse(data);
  } catch (e) {
    console.error('[BACKEND] Lỗi đọc file logs.json', e);
  }
}

// Đồng bộ Backup từ Firestore (đảm bảo không mất dữ liệu khi deploy lên Docker / Render / Cloud)
export async function syncBackupsFromCloud() {
  try {
    const snapshot = await db.collection('system_backups').orderBy('timestamp', 'desc').limit(20).get();
    if (!snapshot.empty) {
      const cloudBackups: BackupRecord[] = [];
      snapshot.forEach(doc => {
        cloudBackups.push(doc.data() as BackupRecord);
      });
      // Kết hợp với storedBackups, loại bỏ trùng lặp id
      const backupMap = new Map<string, BackupRecord>();
      [...storedBackups, ...cloudBackups].forEach(b => backupMap.set(b.id, b));
      storedBackups = Array.from(backupMap.values()).sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
      
      // Cập nhật lại file cache cục bộ
      try {
        fs.writeFileSync(BACKUPS_FILE, JSON.stringify(storedBackups, null, 2), 'utf-8');
      } catch (err) {}
    }
  } catch (e: any) {
    // Firestore có thể chưa có collection hoặc offline khi mới khởi động
  }
}
// Chạy đồng bộ ngầm khi khởi động
syncBackupsFromCloud().catch(() => {});

// Listeners for SSE (Server-Sent Events) / WebSockets live log stream
type LogListener = (entry: LogEntry) => void;
export const logListeners: Set<LogListener> = new Set();

let logSaveTimeout: NodeJS.Timeout | null = null;

export function addLog(tag: string, message: string, level: LogEntry['level'] = 'info') {
  const now = new Date();
  const timeStr = now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
  
  const rawFormatted = `[${timeStr}] ${tag} ${message}`;

  const entry: LogEntry = {
    id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    timestamp: timeStr,
    tag,
    message,
    rawFormatted,
    level
  };

  serverLogs.push(entry);
  if (serverLogs.length > 1500) {
    serverLogs.shift();
  }

  // Throttle save logs to disk
  if (!logSaveTimeout) {
    logSaveTimeout = setTimeout(() => {
      try {
        fs.writeFileSync(LOGS_FILE, JSON.stringify(serverLogs, null, 2), 'utf-8');
      } catch (e) {
        console.error('[BACKEND] Lỗi ghi file logs.json', e);
      }
      logSaveTimeout = null;
    }, 2000);
  }

  // Broadcast to all active web clients
  logListeners.forEach(listener => {
    try {
      listener(entry);
    } catch (e) {
      logListeners.delete(listener);
    }
  });

  // Also print to stdout using console.log so logger can colorize it
  (global as any).__IS_ADDLOG__ = true;
  console.log(tag === '[SYSTEM]' ? message : `${tag} ${message}`);
  (global as any).__IS_ADDLOG__ = false;
}

export function addBackup(record: BackupRecord) {
  storedBackups.unshift(record);
  try {
    fs.writeFileSync(BACKUPS_FILE, JSON.stringify(storedBackups, null, 2), 'utf-8');
  } catch (e) {
    console.error('[BACKEND] Lỗi lưu file backups.json', e);
  }

  // Đồng thời lưu lên Firestore để bền vững trên môi trường Cloud / Container
  db.collection('system_backups').doc(record.id).set(record).catch(err => {
    console.error('[BACKEND] ❌ Lỗi lưu bản sao backup lên Firestore:', err.message);
  });
}
