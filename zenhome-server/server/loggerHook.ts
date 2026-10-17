import { addLog, LogEntry } from './zenhomeState';

const originalLog = console.log;
const originalError = console.error;
const originalWarn = console.warn;
let isHooked = false;

/**
 * Tự động đồng bộ toàn bộ console.log, console.error từ server
 * vào hệ thống lưu trữ serverLogs và phát sóng thời gian thực qua WebSockets (Socket.io)
 * tới giao diện Website Admin
 */
export function setupLoggerHook() {
  if (isHooked) return;
  isHooked = true;

  console.log = function (...args: any[]) {
    if ((global as any).__IS_ADDLOG__) {
      originalLog.apply(console, args);
      return;
    }

    const msg = args.map(arg => (typeof arg === 'object' ? JSON.stringify(arg) : String(arg))).join(' ');

    let level: LogEntry['level'] = 'info';
    if (msg.includes('[ESP]') || msg.includes('✅') || msg.includes('🚀') || msg.includes('[SUCCESS]')) {
      level = 'success';
    } else if (msg.includes('[FIREBASE]') || msg.includes('⚠️') || msg.includes('🛡️') || msg.includes('⚡') || msg.includes('[RETRY]')) {
      level = 'warn';
    } else if (msg.includes('[TIMEOUT]') || msg.includes('Lỗi') || msg.includes('❌') || msg.includes('Error')) {
      level = 'error';
    }

    let tag: string = '[SYSTEM]';
    let cleanMsg = msg;
    const match = msg.match(/^\[(.*?)\]/);
    if (match) {
      tag = `[${match[1]}]`;
      cleanMsg = msg.replace(`[${match[1]}]`, '').trim();
    }

    addLog(tag, cleanMsg, level);
  };

  console.error = function (...args: any[]) {
    if ((global as any).__IS_ADDLOG__) {
      originalError.apply(console, args);
      return;
    }
    const msg = args.map(arg => (typeof arg === 'object' ? (arg instanceof Error ? arg.message : JSON.stringify(arg)) : String(arg))).join(' ');
    addLog('[ERROR]', msg, 'error');
  };

  console.warn = function (...args: any[]) {
    if ((global as any).__IS_ADDLOG__) {
      originalWarn.apply(console, args);
      return;
    }
    const msg = args.map(arg => (typeof arg === 'object' ? JSON.stringify(arg) : String(arg))).join(' ');
    addLog('[BACKEND]', msg, 'warn');
  };
}
