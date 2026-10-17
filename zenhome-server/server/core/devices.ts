import { db, FieldValue } from './firebase';
import { client } from './mqtt';
import { state } from './state';
import { notifyOffline, sendPushToUserTokens } from './notifications';

const MAX_RETRY = 10;

// ==========================================
// BỘ GỬI LỆNH CÓ RETRY (Timeout chống rò rỉ bộ nhớ)
// ==========================================
export function sendCommandWithRetry(baseTopic: string, stateStr: string, source: string = 'action') {
    const cmdTopic = `${baseTopic}/cmd`;
    const stateTopic = `${baseTopic}/state`;

    client.publish(cmdTopic, stateStr);
    console.log(`[SEND] 🚀 Bắn lệnh: ${cmdTopic} -> ${stateStr} (Nguồn: ${source})`);

    if (state.pendingTasks[stateTopic]?.intervalId) {
        clearInterval(state.pendingTasks[stateTopic].intervalId);
    }

    let retryCount = 0;
    const intervalId = setInterval(() => {
        retryCount++;
        if (state.pendingTasks[stateTopic]) {
            state.pendingTasks[stateTopic].retryCount = retryCount;
        }
        if (retryCount >= MAX_RETRY) {
            console.log(`[TIMEOUT] ⚠️ Hủy gửi lệnh cho ${baseTopic} sau ${MAX_RETRY} lần thử không phản hồi. Thiết bị offline.`);
            const topicParts = baseTopic.split('/');
            const userId = topicParts[0];
            const devId = topicParts[topicParts.length - 1];
            notifyOffline(userId, devId);

            clearInterval(intervalId);
            delete state.pendingTasks[stateTopic];
            return;
        }
        console.log(`[RETRY] 🔄 Thử lại lần ${retryCount}: ${cmdTopic} -> ${stateStr} (Nguồn: ${source})`);
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

export async function handleEspPowerRestored(userId: string, macAddress: string) {
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

export async function handleEspNetworkRestored(userId: string, macAddress: string) {
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
