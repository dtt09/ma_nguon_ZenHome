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
import { dbRun, encryptPayload } from './core/database';

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
  timestamp: string; // Chuẩn ISO 8601
  displayTime?: string; // Định dạng hiển thị tiếng Việt
  docCount: number;
  sizeBytes: number;
  collections: string[];
}

export let storedBackups: BackupRecord[] = [];

/**
 * Phân tích thời gian an toàn cho cả chuẩn ISO và chuỗi tiếng Việt cũ (Chống lỗi NaN)
 */
export function parseBackupTime(ts: string): number {
  if (!ts) return 0;
  const d = new Date(ts);
  const time = d.getTime();
  if (!isNaN(time)) return time;
  // Hỗ trợ định dạng lịch sử cũ: "HH:mm:ss DD/MM/YYYY"
  const parts = ts.split(' ');
  if (parts.length === 2) {
    const dateParts = parts[1].split('/');
    if (dateParts.length === 3) {
      const reconstructed = `${dateParts[2]}-${dateParts[1].padStart(2, '0')}-${dateParts[0].padStart(2, '0')}T${parts[0]}`;
      const parsed = new Date(reconstructed).getTime();
      if (!isNaN(parsed)) return parsed;
    }
  }
  return 0;
}

// Khởi tạo thư mục data và load dữ liệu cục bộ
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

if (fs.existsSync(BACKUPS_FILE)) {
  try {
    const data = fs.readFileSync(BACKUPS_FILE, 'utf-8');
    storedBackups = JSON.parse(data);
    if (!Array.isArray(storedBackups)) storedBackups = [];
    // Sắp xếp lại đảm bảo thứ tự mới nhất lên đầu
    storedBackups.sort((a, b) => parseBackupTime(b.timestamp) - parseBackupTime(a.timestamp));
    if (storedBackups.length > 30) storedBackups = storedBackups.slice(0, 30);
  } catch (e) {
    console.error('[BACKEND] Lỗi đọc file backups.json', e);
    storedBackups = [];
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
    // Lấy danh sách snapshot mà không phụ thuộc vào Firestore Index composite
    const snapshot = await db.collection('system_backups').limit(50).get();
    if (!snapshot.empty) {
      const cloudBackups: BackupRecord[] = [];
      snapshot.forEach(doc => {
        cloudBackups.push(doc.data() as BackupRecord);
      });
      // Kết hợp với storedBackups, loại bỏ trùng lặp id
      const backupMap = new Map<string, BackupRecord>();
      [...storedBackups, ...cloudBackups].forEach(b => backupMap.set(b.id, b));
      storedBackups = Array.from(backupMap.values())
        .sort((a, b) => parseBackupTime(b.timestamp) - parseBackupTime(a.timestamp))
        .slice(0, 30); // Giới hạn tối đa 30 bản ghi để chống rò rỉ RAM
      
      // Cập nhật lại file cache cục bộ an toàn
      try {
        const tmpFile = `${BACKUPS_FILE}.${Date.now()}.tmp`;
        fs.writeFileSync(tmpFile, JSON.stringify(storedBackups, null, 2), 'utf-8');
        fs.renameSync(tmpFile, BACKUPS_FILE);
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

// ==========================================
// BỘ LỌC CHỐNG SPAM LOG TRÙNG LẶP (Log Suppression Engine)
// Ngăn chặn lũ lụt console/RAM/disk khi sự kiện mạng hoặc cảm biến lặp lại liên tục
// ==========================================
let lastLogTag = '';
let lastLogMsg = '';
let lastLogLevel: LogEntry['level'] = 'info';
let lastLogTime = 0;
let repeatCount = 0;
let repeatFlushTimer: NodeJS.Timeout | null = null;

/**
 * Tự động che giấu các trường thông tin nhạy cảm trong nhật ký hệ thống (Log Sanitization Engine)
 */
function sanitizeLogText(text: string): string {
  if (!text) return text;
  return text
    // Che mật khẩu trong chuỗi JSON/Key-Value: admin_pass, wifi_pass, password, secretKey
    .replace(/(["']?(?:admin_pass|wifi_pass|password|secretKey|masterKey|token)["']?\s*[:=]\s*["'])([^"'\s]+)(["'])/gi, '$1********$3')
    // Che Authorization Bearer token
    .replace(/(Bearer\s+)[A-Za-z0-9\-_]{15,}/gi, '$1[MASKED_TOKEN]')
    // Che gói tin mã hóa ZHENC1
    .replace(/ZHENC1:[A-Za-z0-9+/=]{16,}/g, 'ZHENC1:[ENCRYPTED_PAYLOAD]');
}

function commitLog(tag: string, message: string, level: LogEntry['level'] = 'info') {
  const safeMessage = sanitizeLogText(message);
  const now = new Date();
  const timeStr = now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
  
  const rawFormatted = `[${timeStr}] ${tag} ${safeMessage}`;

  const entry: LogEntry = {
    id: `log_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
    timestamp: timeStr,
    tag,
    message: safeMessage,
    rawFormatted,
    level
  };

  serverLogs.push(entry);
  if (serverLogs.length > 1500) {
    serverLogs.shift();
  }

  // Ghi bền vững vào SQLite WAL (không chặn luồng chính)
  dbRun(
    `INSERT OR REPLACE INTO server_logs (id, timestamp, tag, message, rawFormatted, level, createdAt)
     VALUES (?, ?, ?, ?, ?, ?, ?);`,
    [entry.id, entry.timestamp, entry.tag, entry.message, entry.rawFormatted, entry.level, Date.now()]
  ).catch(() => {});

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

export function addLog(tag: string, message: string, level: LogEntry['level'] = 'info') {
  const now = Date.now();
  // Nếu thông điệp giống hệt trong vòng 2.5 giây -> gom nhóm, không spam log
  if (tag === lastLogTag && message === lastLogMsg && (now - lastLogTime) < 2500) {
    repeatCount++;
    lastLogTime = now;
    if (!repeatFlushTimer) {
      repeatFlushTimer = setTimeout(() => {
        if (repeatCount > 0) {
          commitLog(lastLogTag, `${lastLogMsg} (lặp lại ${repeatCount} lần)`, lastLogLevel);
          repeatCount = 0;
        }
        repeatFlushTimer = null;
      }, 2500);
    }
    return;
  }

  // Nếu có log lặp lại trước đó, xả (flush) trước khi ghi log mới
  if (repeatCount > 0) {
    if (repeatFlushTimer) {
      clearTimeout(repeatFlushTimer);
      repeatFlushTimer = null;
    }
    commitLog(lastLogTag, `${lastLogMsg} (lặp lại ${repeatCount} lần)`, lastLogLevel);
    repeatCount = 0;
  }

  lastLogTag = tag;
  lastLogMsg = message;
  lastLogLevel = level;
  lastLogTime = now;

  commitLog(tag, message, level);
}

export function addBackup(record: BackupRecord) {
  storedBackups.unshift(record);
  // Giới hạn bộ đệm RAM tối đa 30 bản ghi gần nhất (Chống Memory Leak)
  if (storedBackups.length > 30) {
    storedBackups = storedBackups.slice(0, 30);
  }

  // Ghi nguyên tử an toàn chống hỏng file
  try {
    const tmpFile = `${BACKUPS_FILE}.${Date.now()}.tmp`;
    fs.writeFileSync(tmpFile, JSON.stringify(storedBackups, null, 2), 'utf-8');
    fs.renameSync(tmpFile, BACKUPS_FILE);
  } catch (e) {
    console.error('[BACKEND] Lỗi lưu file backups.json', e);
  }

  // Đồng thời lưu lên Firestore để bền vững trên môi trường Cloud / Container
  db.collection('system_backups').doc(record.id).set(record).catch(err => {
    console.error('[BACKEND] ❌ Lỗi lưu bản sao backup lên Firestore:', err.message);
  });

  // Ghi vào SQLite WAL cục bộ (Mã hóa an toàn Storage at Rest AES-256-GCM)
  const collectionsJson = JSON.stringify(record.collections || []);
  const encryptedCollections = encryptPayload(collectionsJson);
  dbRun(
    `INSERT OR REPLACE INTO system_backups (id, timestamp, displayTime, docCount, sizeBytes, collections, createdAt)
     VALUES (?, ?, ?, ?, ?, ?, ?);`,
    [record.id, record.timestamp, record.displayTime || '', record.docCount || 0, record.sizeBytes || 0, encryptedCollections, Date.now()]
  ).catch((err: any) => {
    console.error('[BACKEND] ❌ Lỗi lưu backup vào SQLite:', err.message);
  });
}
