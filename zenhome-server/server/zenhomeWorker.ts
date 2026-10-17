import { createRequire } from 'module';
import { addLog } from './zenhomeState';

const require = createRequire(import.meta.url);

// Import old backend core logic
const setupMqttHandlers = require('./core/mqttHandler.cjs');
const { loadSchedulesFromFirebase, startCronJob } = require('./core/schedules.cjs');
const { sendCommandWithRetry: realSendCommandWithRetry } = require('./core/devices.cjs');
const { startListeningToAlerts, startListeningToDeleteRequests, startListeningToUnlinkRequests } = require('./core/listeners.cjs');
const { loadTimersFromFirebase } = require('./core/timers.cjs');
const { startJunkAccountCleanupCron, cleanJunkAccounts: realCleanJunkAccounts } = require('./core/cleanup.cjs');
const { db } = require('./core/firebase.cjs');

let isWorkerRunning = false;

// 1. Bridge for sendCommandWithRetry (Used by Admin Dashboard UI)
export function sendCommandWithRetry(baseTopic: string, stateStr: string, source: string = 'action') {
    // The old implementation accepts (topic, stateVal, source)
    realSendCommandWithRetry(baseTopic, stateStr, source);
}

// 2. Bridge for cleanJunkAccounts
export async function cleanJunkAccounts() {
    return await realCleanJunkAccounts();
}

// 3. Admin manual delete request
export async function executeDeleteAccountRequest(username: string, uid: string, macAddress: string) {
    try {
        addLog('[BACKEND]', `Nhận lệnh xóa tài khoản: ${username}. Chuyển giao cho Firestore Worker...`, 'info');
        // Just create a document in delete_requests collection, and let the REAL listener from `listeners.cjs` handle the ESP32 reset and cleanup!
        await db.collection('delete_requests').doc(username).set({
            uid: uid || 'NO_UID',
            username: username,
            macAddress: macAddress || 'ESP32_MAC',
            timestamp: new Date().toISOString()
        });
    } catch (e: any) {
        addLog('[ERROR]', 'Lỗi khi tạo yêu cầu xóa: ' + e.message, 'error');
    }
}

import { setupLoggerHook } from './loggerHook';

// 4. Initialize real backend
export function initZenHomeWorker() {
    if (isWorkerRunning) return;
    isWorkerRunning = true;

    // Load the custom logger hook to sync console.log to Admin UI via WebSockets
    setupLoggerHook();
    
    addLog('[SYSTEM]', `========================================================`, 'info');
    addLog('[SYSTEM]', `🚀 Khởi chạy Máy chủ Node.js ZenHome (Real Backend Integrated)`, 'success');
    addLog('[SYSTEM]', `========================================================`, 'info');

    try {
        // Run original real functions
        setupMqttHandlers();
        loadSchedulesFromFirebase();
        loadTimersFromFirebase();
        startCronJob(realSendCommandWithRetry);
        startListeningToAlerts();
        startListeningToDeleteRequests();
        startListeningToUnlinkRequests();
        startJunkAccountCleanupCron();
        addLog('[SYSTEM]', `✅ Tích hợp module backend cũ thành công!`, 'success');
    } catch (e: any) {
        addLog('[ERROR]', `❌ Lỗi khởi chạy core module: ${e.message}`, 'error');
    }
}
