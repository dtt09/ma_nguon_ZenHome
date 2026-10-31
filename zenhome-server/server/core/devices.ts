import { db, FieldValue } from './firebase';
import { client } from './mqtt';
import { state } from './state';
import { notifyOffline, sendPushToUserTokens } from './notifications';

const MAX_RETRY = 3;
const MAX_PENDING_TASKS = 25; // Giới hạn hàng đợi chống tràn RAM (Anti Queue Overflow)

// ==========================================
// BỘ GỬI LỆNH CÓ RETRY (Timeout chống rò rỉ bộ nhớ & chống spam log & chống tràn hàng đợi)
// ==========================================
export function sendCommandWithRetry(baseTopic: string, stateStr: string, source: string = 'action') {
    const cmdTopic = `${baseTopic}/cmd`;
    const stateTopic = `${baseTopic}/state`;

    client.publish(cmdTopic, stateStr);
    console.log(`[SEND] 🚀 Bắn lệnh: ${cmdTopic} -> ${stateStr} (Nguồn: ${source})`);

    const topicParts = baseTopic.split('/');
    const userId = topicParts[0];
    const devId = topicParts[topicParts.length - 1];

    if (state.pendingTasks[stateTopic]?.intervalId) {
        clearInterval(state.pendingTasks[stateTopic].intervalId);
    }

    // Nếu Hub đã biết là đang Offline trên MQTT, không chạy vòng lặp retry gây spam log & notification
    if (state.espOnlineStatus[userId]?.isOnline === false) {
        return;
    }

    // CHỐNG TRÀN HÀNG ĐỢI (Queue Overflow Protection): Giải phóng tác vụ cũ nhất nếu hàng đợi đạt ngưỡng
    const pendingKeys = Object.keys(state.pendingTasks);
    if (pendingKeys.length >= MAX_PENDING_TASKS) {
        const oldestKey = pendingKeys[0];
        if (state.pendingTasks[oldestKey]?.intervalId) {
            clearInterval(state.pendingTasks[oldestKey].intervalId);
        }
        delete state.pendingTasks[oldestKey];
        console.warn(`[QUEUE OVERFLOW PROTECTION] ⚠️ Hàng đợi retry vượt ngưỡng (${MAX_PENDING_TASKS}). Đã tự động giải phóng tác vụ cũ: ${oldestKey}`);
    }

    let retryCount = 0;
    const intervalId = setInterval(() => {
        retryCount++;
        if (state.pendingTasks[stateTopic]) {
            state.pendingTasks[stateTopic].retryCount = retryCount;
        }
        if (retryCount >= MAX_RETRY) {
            console.log(`[TIMEOUT] ⚠️ Hủy gửi lệnh cho ${baseTopic} sau ${MAX_RETRY} lần thử không phản hồi.`);
            const isSilentSync = source === 'network_sync_restore' || source === 'power_safety' || source === 'safety_default';
            if (!isSilentSync) {
                notifyOffline(userId, devId);
            }
            clearInterval(intervalId);
            delete state.pendingTasks[stateTopic];
            return;
        }
        client.publish(cmdTopic, stateStr);
    }, 3000);

    state.pendingTasks[stateTopic] = {
        targetState: stateStr,
        intervalId,
        source,
        retryCount: 0,
        startedAt: new Date().toISOString(),
        toJSON() {
            return {
                targetState: this.targetState,
                source: this.source,
                retryCount: this.retryCount,
                startedAt: this.startedAt
            };
        }
    };
}

const lastPowerRestorePerUser: Record<string, number> = {};

export async function handleEspPowerRestored(userId: string, macAddress: string) {
    const now = Date.now();
    if (lastPowerRestorePerUser[userId] && (now - lastPowerRestorePerUser[userId] < 10000)) {
        console.log(`[ESP] ⏭️ Đã xử lý sự kiện có điện lại cho ${userId} gần đây (<10s). Bỏ qua sự kiện trùng lặp.`);
        return;
    }
    lastPowerRestorePerUser[userId] = now;

    try {
        let targetEmail: string | null = null;
        let devices: any[] = [];
        let language = 'vi';

        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
            targetEmail = userDoc.id;
            const data = userDoc.data() || {};
            if (data.language) language = data.language;
            devices = data.devices || [];
        }

        if (!targetEmail) return;
        const isEn = language === 'en';

        // TH1: MẤT ĐIỆN -> CÓ ĐIỆN LẠI PHẢI TẮT TOÀN BỘ THIẾT BỊ ĐỂ AN TOÀN ĐIỆN
        const { handlePowerRestored } = await import('./deviceStateBackup');
        await handlePowerRestored(userId, macAddress, devices, isEn);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi khi xử lý ESP power restored:", error);
    }
}

const lastNetworkRestorePerUser: Record<string, number> = {};

export async function handleEspNetworkRestored(userId: string, macAddress: string) {
    const now = Date.now();
    if (lastNetworkRestorePerUser[userId] && (now - lastNetworkRestorePerUser[userId] < 10000)) {
        console.log(`[ESP] ⏭️ Đã xử lý phục hồi mạng cho ${userId} gần đây (<10s). Bỏ qua sự kiện trùng lặp.`);
        return;
    }
    lastNetworkRestorePerUser[userId] = now;

    try {
        let targetEmail: string | null = null;
        let devices: any[] = [];
        let language = 'vi';

        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
            targetEmail = userDoc.id;
            const data = userDoc.data() || {};
            if (data.language) language = data.language;
            devices = data.devices || [];
        }

        if (!targetEmail) return;
        const isEn = language === 'en';

        // TH2: MẤT MẠNG -> CÓ MẠNG LẠI: CHỈ ĐỒNG BỘ TRẠNG THÁI LẦN CUỐI
        const { handleNetworkRestored } = await import('./deviceStateBackup');
        await handleNetworkRestored(userId, macAddress, devices, isEn);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi khi xử lý ESP network restored:", error);
    }
}
