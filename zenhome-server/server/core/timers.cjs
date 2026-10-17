const { db } = require('./firebase.cjs');
const state = require('./state.cjs');
const { sendCommandWithRetry } = require('./devices.cjs');

// Hàm load timers từ Firebase khi khởi động
async function loadTimersFromFirebase() {
    try {
        const snapshot = await db.collection('server_timers').get();
        let loaded = 0;
        const now = Date.now();
        
        for (const doc of snapshot.docs) {
            const data = doc.data();
            const { baseTopic, action, triggerAt } = data;
            const timerKey = `${baseTopic}_${action === '1' ? 'on' : 'off'}`;
            
            const remaining = triggerAt - now;
            if (remaining > 0) {
                state.activeTimers[timerKey] = setTimeout(() => {
                    sendCommandWithRetry(baseTopic, action, 'timer');
                    delete state.activeTimers[timerKey];
                    deleteTimerFromFirebase(timerKey);
                }, remaining);
                loaded++;
            } else {
                // Đã quá hạn trong lúc server down, thực thi luôn và xóa
                console.log(`[TIMER] ⏱️ Hẹn giờ ${timerKey} đã quá hạn, thực thi bắn lệnh ngay...`);
                sendCommandWithRetry(baseTopic, action, 'timer');
                deleteTimerFromFirebase(timerKey);
            }
        }
        console.log(`[FIREBASE] ⏱️ Đã nạp ${loaded} hẹn giờ (timers) từ DB vào RAM.`);
    } catch (e) {
        console.error("[FIREBASE ERROR] ❌ Lỗi nạp timers:", e);
    }
}

async function saveTimerToFirebase(timerKey, baseTopic, action, triggerAt) {
    try {
        const docId = timerKey.replace(/\//g, '___');
        await db.collection('server_timers').doc(docId).set({ baseTopic, action, triggerAt });
    } catch (e) {
        console.error("[FIREBASE ERROR] ❌ Lỗi lưu timer:", e);
    }
}

async function deleteTimerFromFirebase(timerKey) {
    try {
        const docId = timerKey.replace(/\//g, '___');
        await db.collection('server_timers').doc(docId).delete();
    } catch (e) {
        console.error("[FIREBASE ERROR] ❌ Lỗi xóa timer:", e);
    }
}

function setTimer(baseTopic, action, mins) {
    const timerKey = `${baseTopic}_${action === '1' ? 'on' : 'off'}`;
    
    // Clear cũ nếu có
    if (state.activeTimers[timerKey]) {
        clearTimeout(state.activeTimers[timerKey]);
        delete state.activeTimers[timerKey];
    }
    
    if (mins > 0) {
        const ms = mins * 60000;
        const triggerAt = Date.now() + ms;
        console.log(`[TIMER] ⏱️ Hẹn giờ ${action === '1' ? 'BẬT' : 'TẮT'} ${baseTopic} sau ${mins} phút (Lưu Firebase)`);
        
        state.activeTimers[timerKey] = setTimeout(() => {
            sendCommandWithRetry(baseTopic, action, 'timer');
            delete state.activeTimers[timerKey];
            deleteTimerFromFirebase(timerKey);
        }, ms);
        
        saveTimerToFirebase(timerKey, baseTopic, action, triggerAt);
    } else {
        // Hủy hẹn giờ
        console.log(`[TIMER] ⏱️ Hủy hẹn giờ ${action === '1' ? 'BẬT' : 'TẮT'} cho ${baseTopic}`);
        deleteTimerFromFirebase(timerKey);
    }
}

module.exports = {
    loadTimersFromFirebase,
    setTimer,
    deleteTimerFromFirebase
};
