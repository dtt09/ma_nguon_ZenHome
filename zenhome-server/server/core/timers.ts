import { db } from './firebase';
import { state } from './state';
import { sendCommandWithRetry } from './devices';

const MAX_TIMER_MINS = 35000; // ~24.3 ngày (giới hạn an toàn trong phạm vi 32-bit signed int cho setTimeout)
const MAX_TIMEOUT_MS = 2147483647; // 2^31 - 1

export async function loadTimersFromFirebase() {
    try {
        const snapshot = await db.collection('server_timers').get();
        let loaded = 0;
        let garbageCount = 0;
        const now = Date.now();
        const validUsers = new Set<string>();
        const invalidUsers = new Set<string>();
        
        for (const doc of snapshot.docs) {
            const data = doc.data();
            const { baseTopic, action, triggerAt } = data;
            const timerKey = `${baseTopic}_${action === '1' ? 'on' : 'off'}`;
            const userId = baseTopic.split('/')[0];

            let userExists = false;
            if (validUsers.has(userId)) {
                userExists = true;
            } else if (invalidUsers.has(userId)) {
                userExists = false;
            } else {
                const userDoc = await db.collection('users').doc(userId).get();
                if (userDoc.exists) {
                    validUsers.add(userId);
                    userExists = true;
                } else {
                    invalidUsers.add(userId);
                    userExists = false;
                }
            }

            if (!userExists) {
                console.log(`[BACKEND] 🧹 Phát hiện tài khoản rác (${userId}) không tồn tại. Xóa timer ngầm: ${doc.id}`);
                await doc.ref.delete();
                garbageCount++;
                continue;
            }
            
            const remaining = triggerAt - now;
            if (remaining > 0) {
                const safeRemaining = Math.min(remaining, MAX_TIMEOUT_MS);
                state.activeTimers[timerKey] = setTimeout(() => {
                    sendCommandWithRetry(baseTopic, action, 'timer');
                    delete state.activeTimers[timerKey];
                    deleteTimerFromFirebase(timerKey);
                }, safeRemaining);
                loaded++;
            } else if (now - triggerAt <= 5 * 60 * 1000) {
                // Chỉ thực thi bù nếu thời gian trễ không quá 5 phút
                console.log(`[TIMER] ⏱️ Hẹn giờ ${timerKey} vừa quá hạn (<5 phút), thực thi bù...`);
                sendCommandWithRetry(baseTopic, action, 'timer');
                deleteTimerFromFirebase(timerKey);
            } else {
                console.warn(`[TIMER WARNING] ⚠️ Hẹn giờ ${timerKey} đã quá hạn quá lâu (${Math.round((now - triggerAt) / 60000)} phút). Hủy bỏ an toàn tránh kích hoạt ma!`);
                deleteTimerFromFirebase(timerKey);
            }
        }
        console.log(`[FIREBASE] ⏱️ Đã nạp ${loaded} hẹn giờ (timers) từ DB vào RAM (Dọn dẹp: ${garbageCount}).`);
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
        if (state.activeTimers && state.activeTimers[timerKey]) {
            clearTimeout(state.activeTimers[timerKey]);
            delete state.activeTimers[timerKey];
        }
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
        const safeMins = Math.min(mins, MAX_TIMER_MINS);
        if (mins > MAX_TIMER_MINS) {
            console.warn(`[TIMER WARNING] ⚠️ Hẹn giờ ${mins} phút vượt quá giới hạn 32-bit của Node.js, tự động giới hạn ở ${MAX_TIMER_MINS} phút (~24.3 ngày).`);
        }

        const ms = safeMins * 60000;
        const triggerAt = Date.now() + ms;
        console.log(`[TIMER] ⏱️ Hẹn giờ ${action === '1' ? 'BẬT' : 'TẮT'} ${baseTopic} sau ${safeMins} phút (Lưu Firebase)`);
        
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
