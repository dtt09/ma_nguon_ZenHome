import { db } from './firebase';
import { state } from './state';
import { sendCommandWithRetry } from './devices';

export async function loadTimersFromFirebase() {
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

export async function saveTimerToFirebase(timerKey: string, baseTopic: string, action: string, triggerAt: number) {
    try {
        const docId = timerKey.replace(/\//g, '___');
        await db.collection('server_timers').doc(docId).set({ baseTopic, action, triggerAt });
    } catch (e) {
        console.error("[FIREBASE ERROR] ❌ Lỗi lưu timer:", e);
    }
}

export async function deleteTimerFromFirebase(timerKey: string) {
    try {
        const docId = timerKey.replace(/\//g, '___');
        await db.collection('server_timers').doc(docId).delete();
    } catch (e) {
        console.error("[FIREBASE ERROR] ❌ Lỗi xóa timer:", e);
    }
}

export function setTimer(baseTopic: string, action: string, mins: number) {
    const timerKey = `${baseTopic}_${action === '1' ? 'on' : 'off'}`;
    
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
        console.log(`[TIMER] ⏱️ Hủy hẹn giờ ${action === '1' ? 'BẬT' : 'TẮT'} cho ${baseTopic}`);
        deleteTimerFromFirebase(timerKey);
    }
}
