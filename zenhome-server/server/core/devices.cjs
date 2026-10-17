const { db, FieldValue } = require('./firebase.cjs');
const client = require('./mqtt.cjs');
const state = require('./state.cjs');
const { notifyOffline, sendPushToUserTokens } = require('./notifications.cjs');

const MAX_RETRY = 10;

// ==========================================
// BỘ GỬI LỆNH CÓ RETRY (Timeout chống rò rỉ bộ nhớ)
// ==========================================
function sendCommandWithRetry(baseTopic, stateStr, source = 'action') {
    const cmdTopic = `${baseTopic}/cmd`;
    const stateTopic = `${baseTopic}/state`;

    client.publish(cmdTopic, stateStr);
    console.log(`[SEND] 🚀 Bắn lệnh: ${cmdTopic} -> ${stateStr} (Nguồn: ${source})`);

    if (state.pendingTasks[stateTopic]) {
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

async function handleEspPowerRestored(userId, macAddress) {
    try {
        let targetEmail = null;
        let devices = [];
        let language = 'vi';

        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
            targetEmail = userDoc.id;
            const data = userDoc.data();
            if (data.language) language = data.language;
            devices = data.devices || [];
        }

        if (!targetEmail) return;

        const isEn = language === 'en';

        // Đồng bộ công tắc trên app và Gửi lệnh 0 (TẮT) thiết bị (an toàn điện)
        devices.forEach(dev => {
            if (dev.room && dev.id) {
                const baseTopic = `${userId}/${macAddress}/${dev.room}/${dev.id}`;
                
                // Gọi sendCommandWithRetry để đảm bảo ESP nhận được lệnh và tự phản hồi state
                sendCommandWithRetry(baseTopic, '0');
            }
        });

        // Ghi lịch sử
        await db.collection('users').doc(targetEmail).collection('history').add({
            deviceName: isEn ? 'Power System' : 'Hệ thống Điện',
            action: isEn ? 'Power restored. All devices auto-turned off for safety' : 'Có điện trở lại, Tự động Tắt tất cả thiết bị để an toàn',
            timestamp: FieldValue.serverTimestamp(),
        });

        const notificationVi = {
            title: '⚡ Thông Báo Nguồn Điện',
            body: 'Hệ thống vừa có điện trở lại. Toàn bộ thiết bị đã được tắt để đảm bảo an toàn!'
        };

        const notificationEn = {
            title: '⚡ Power Supply Notification',
            body: 'The system has just regained power. All devices have been turned off to ensure safety!'
        };

        await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
        console.log(`[FIREBASE] 🔔 Đã bắn Push báo Có điện cho user: ${userId}`);

    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi khi xử lý ESP online:", error);
    }
}

module.exports = {
    sendCommandWithRetry,
    handleEspPowerRestored
};
