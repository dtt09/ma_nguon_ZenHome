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
  activeTimers: Record<string, {
    baseTopic: string;
    action: string;
    triggerAt: number;
    minutesLeft: number;
  }>;
  activeSchedules: Record<string, {
    baseTopic: string;
    timeOn?: string;
    timeOff?: string;
    days: string;
    isTriggeredOn?: boolean;
    isTriggeredOff?: boolean;
  }>;
  lastTempAlert: Record<string, number>;
  latestIndoorTemp: Record<string, { temp: number; updatedAt: string }>;
  espOnlineStatus: Record<string, { isOnline: boolean; lastSeen: string }>;
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
import { createRequire } from 'module';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_DIR = path.resolve(__dirname, 'data');
const BACKUPS_FILE = path.join(DATA_DIR, 'backups.json');
const LOGS_FILE = path.join(DATA_DIR, 'logs.json');

const require = createRequire(import.meta.url);
const coreState = require('./core/state.cjs');

export const state: ZenHomeServerState = coreState;
if (!state.lastTempAlert) state.lastTempAlert = {};

// Rolling buffer of the latest 300 logs for real-time web streaming
export let serverLogs: LogEntry[] = [];

export interface BackupRecord {
  id: string;
  timestamp: string;
  docCount: number;
  sizeBytes: number;
  collections: string[];
}

export let storedBackups: BackupRecord[] = [];

// Khởi tạo thư mục data và load dữ liệu
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

  // Also print to stdout using console.log so logger.cjs can colorize it
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
}
