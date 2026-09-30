const originalLog = console.log;
const originalError = console.error;

function formatLog(msg) {
    if (typeof msg !== 'string') return msg;
    const now = new Date().toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });
    let colorPrefix = '\x1b[37m'; // White
    
    if (msg.includes('[ESP]')) colorPrefix = '\x1b[36m'; // Cyan
    else if (msg.includes('[FIREBASE]')) colorPrefix = '\x1b[33m'; // Yellow
    else if (msg.includes('[CRON]') || msg.includes('[SCHEDULE]')) colorPrefix = '\x1b[35m'; // Magenta
    else if (msg.includes('[TIMER]')) colorPrefix = '\x1b[34m'; // Blue
    else if (msg.includes('[SEND]') || msg.includes('[SUCCESS]')) colorPrefix = '\x1b[32m'; // Green
    else if (msg.includes('[TIMEOUT]') || msg.includes('[RETRY]') || msg.includes('❌') || msg.includes('🚨')) colorPrefix = '\x1b[31m'; // Red
    else if (msg.includes('✅') || msg.includes('🟢')) colorPrefix = '\x1b[32m'; // Green
    else if (msg.includes('⚠️') || msg.includes('🗑️') || msg.includes('🔴')) colorPrefix = '\x1b[33m'; // Yellow
    else if (msg.includes('🚀')) colorPrefix = '\x1b[1m\x1b[36m'; // Bright Cyan

    return `\x1b[90m[${now}]\x1b[0m ${colorPrefix}${msg}\x1b[0m`;
}

console.log = function(...args) {
    const formatted = args.map(arg => formatLog(arg));
    originalLog.apply(console, formatted);
};

console.error = function(...args) {
    const formatted = args.map(arg => typeof arg === 'string' ? `\x1b[90m[${new Date().toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })}]\x1b[0m \x1b[31m${arg}\x1b[0m` : arg);
    originalError.apply(console, formatted);
};
