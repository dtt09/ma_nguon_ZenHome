import { addLog } from '../zenhomeState';

const originalLog = console.log;
const originalError = console.error;

function formatLog(msg: any): any {
    if (typeof msg !== 'string') return msg;
    const now = new Date().toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
    let colorPrefix = '\x1b[37m'; // Trắng
    
    if (msg.includes('[ESP]')) colorPrefix = '\x1b[36m'; // Cyan
    else if (msg.includes('[FIREBASE]')) colorPrefix = '\x1b[33m'; // Vàng
    else if (msg.includes('[CRON]') || msg.includes('[SCHEDULE]')) colorPrefix = '\x1b[35m'; // Tím
    else if (msg.includes('[TIMER]')) colorPrefix = '\x1b[34m'; // Xanh dương
    else if (msg.includes('[SEND]') || msg.includes('[SUCCESS]')) colorPrefix = '\x1b[32m'; // Xanh lá
    else if (msg.includes('[TIMEOUT]') || msg.includes('[RETRY]') || msg.includes('Lỗi') || msg.includes('❌')) colorPrefix = '\x1b[31m'; // Đỏ
    else if (msg.includes('✅') || msg.includes('🌟')) colorPrefix = '\x1b[32m'; 
    else if (msg.includes('⚠️') || msg.includes('🛡️') || msg.includes('⚡')) colorPrefix = '\x1b[33m'; 
    else if (msg.includes('🚀')) colorPrefix = '\x1b[1m\x1b[36m'; 

    return `\x1b[90m[${now}]\x1b[0m ${colorPrefix}${msg}\x1b[0m`;
}

export function setupCustomLogger() {
    console.log = function(...args: any[]) {
        if ((global as any).__IS_ADDLOG__) {
            const formatted = args.map(arg => formatLog(arg));
            originalLog.apply(console, formatted);
            return;
        }
        const msg = args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ');
        
        let type: 'info' | 'warn' | 'error' | 'success' = 'info';
        if (msg.includes('[ESP]') || msg.includes('✅') || msg.includes('🚀') || msg.includes('[SUCCESS]')) type = 'success';
        else if (msg.includes('[FIREBASE]') || msg.includes('⚠️') || msg.includes('🛡️') || msg.includes('⚡') || msg.includes('[RETRY]')) type = 'warn';
        else if (msg.includes('[TIMEOUT]') || msg.includes('Lỗi') || msg.includes('❌') || msg.includes('Error')) type = 'error';
        
        let prefix = '[SYSTEM]';
        let cleanMsg = msg;
        const match = msg.match(/^\[(.*?)\]/);
        if (match) {
            prefix = `[${match[1]}]`;
            cleanMsg = msg.replace(`[${match[1]}]`, '').trim();
        }
        
        addLog(prefix, cleanMsg, type);
    };

    console.error = function(...args: any[]) {
        const msg = args.map(a => (typeof a === 'object' ? JSON.stringify(a) : String(a))).join(' ');
        addLog('[ERROR]', msg, 'error');
        const formatted = args.map(arg => typeof arg === 'string' ? `\x1b[90m[${new Date().toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}]\x1b[0m \x1b[31m${arg}\x1b[0m` : arg);
        originalError.apply(console, formatted);
    };
}

export default setupCustomLogger;
