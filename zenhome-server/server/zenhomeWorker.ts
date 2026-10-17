import { addLog } from './zenhomeState';
import { setupMqttHandlers } from './core/mqttHandler';
import { loadSchedulesFromFirebase, startCronJob } from './core/schedules';
import { sendCommandWithRetry as realSendCommandWithRetry } from './core/devices';
import { startListeningToAlerts, startListeningToDeleteRequests, startListeningToUnlinkRequests } from './core/listeners';
import { loadTimersFromFirebase } from './core/timers';
import { startJunkAccountCleanupCron, cleanJunkAccounts as realCleanJunkAccounts } from './core/cleanup';
import { db } from './core/firebase';
import { setupLoggerHook } from './loggerHook';

let isWorkerRunning = false;

// 1. Bridge for sendCommandWithRetry (Used by Admin Dashboard UI)
export function sendCommandWithRetry(baseTopic: string, stateStr: string, source: string = 'action') {
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
        setupMqttHandlers();
        loadSchedulesFromFirebase();
        loadTimersFromFirebase();
        startCronJob(realSendCommandWithRetry);
        startListeningToAlerts();
        startListeningToDeleteRequests();
        startListeningToUnlinkRequests();
        startJunkAccountCleanupCron();
        addLog('[SYSTEM]', `✅ Tích hợp module backend TypeScript thành công!`, 'success');
    } catch (e: any) {
        addLog('[ERROR]', `❌ Lỗi khởi chạy core module: ${e.message}`, 'error');
    }
}
