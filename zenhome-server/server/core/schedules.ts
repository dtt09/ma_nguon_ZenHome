import cron from 'node-cron';
import { db } from './firebase';
import { state } from './state';

// ==========================================
// TIỆN ÍCH THỜI GIAN & NGÀY TUẦN (VIỆT NAM)
// ==========================================
export function getCurrentVietnamTimeInfo(customDate: Date | null = null) {
    const now = customDate ? new Date(customDate) : new Date();
    const formatterTime = new Intl.DateTimeFormat('en-US', {
        timeZone: 'Asia/Ho_Chi_Minh',
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
    });
    const formatterDay = new Intl.DateTimeFormat('en-US', {
        timeZone: 'Asia/Ho_Chi_Minh',
        weekday: 'short'
    });

    const timeParts = formatterTime.formatToParts(now);
    let hour = '00';
    let minute = '00';
    timeParts.forEach(p => {
        if (p.type === 'hour') hour = p.value;
        if (p.type === 'minute') minute = p.value;
    });
    if (hour === '24') hour = '00';
    const currentTime = `${hour}:${minute}`;

    // App day map: 0 = Mon (Thứ 2), ..., 6 = Sun (Chủ nhật)
    const dayStr = formatterDay.format(now);
    const dayMap: Record<string, number> = { 'Mon': 0, 'Tue': 1, 'Wed': 2, 'Thu': 3, 'Fri': 4, 'Sat': 5, 'Sun': 6 };
    const dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    const appDayIndex = dayMap[dayStr] ?? 0;

    return {
        currentTime,
        hour,
        minute,
        appDayIndex,
        dayName: dayNames[appDayIndex],
        now
    };
}

export function isDayActive(days: any, dayIndex: number): boolean {
    if (days === undefined || days === null || days === '') return true;
    if (typeof days === 'string') {
        if (days.length === 7 && /^[01]+$/.test(days)) {
            return days[dayIndex] === '1';
        }
        const parts = days.split(',').map(s => s.trim());
        return parts.includes(String(dayIndex));
    }
    if (Array.isArray(days)) {
        return Boolean(days[dayIndex]);
    }
    return true;
}

const formatTime = (t?: string | null) => t ? t.split(':').map(x => x.padStart(2, '0')).join(':') : null;

// ==========================================
// TÍNH TOÁN LỊCH TRÌNH TIẾP THEO (COUNTDOWN)
// ==========================================
export function getNextUpcomingSchedule() {
    const { hour, minute, appDayIndex } = getCurrentVietnamTimeInfo();
    const currentTotalMin = parseInt(hour, 10) * 60 + parseInt(minute, 10);
    const dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];

    let closestSchedule: any = null;
    let minDeltaMinutes = Infinity;

    for (const [key, schedule] of Object.entries(state.activeSchedules || {})) {
        const timeOnFormatted = formatTime(schedule.timeOn);
        const timeOffFormatted = formatTime(schedule.timeOff);

        const actions: { time: string; action: string; stateVal: string }[] = [];
        if (timeOnFormatted) actions.push({ time: timeOnFormatted, action: 'BẬT', stateVal: '1' });
        if (timeOffFormatted) actions.push({ time: timeOffFormatted, action: 'TẮT', stateVal: '0' });

        for (const act of actions) {
            const [hStr, mStr] = act.time.split(':');
            const targetTotalMin = parseInt(hStr, 10) * 60 + parseInt(mStr, 10);

            for (let dayOffset = 0; dayOffset < 7; dayOffset++) {
                const targetDayIndex = (appDayIndex + dayOffset) % 7;
                if (!isDayActive(schedule.days, targetDayIndex)) continue;

                let deltaMinutes = (dayOffset * 24 * 60) + (targetTotalMin - currentTotalMin);
                if (deltaMinutes <= 0) {
                    if (dayOffset === 0) {
                        deltaMinutes += 7 * 24 * 60;
                    } else {
                        continue;
                    }
                }

                if (deltaMinutes < minDeltaMinutes) {
                    minDeltaMinutes = deltaMinutes;
                    const hoursLeft = Math.floor(deltaMinutes / 60);
                    const minsLeft = deltaMinutes % 60;
                    closestSchedule = {
                        id: key,
                        baseTopic: schedule.baseTopic,
                        time: act.time,
                        action: act.action,
                        stateVal: act.stateVal,
                        targetDayIndex,
                        targetDayName: dayNames[targetDayIndex],
                        deltaMinutes,
                        countdownFormatted: hoursLeft > 0 ? `${hoursLeft} giờ ${minsLeft} phút` : `${minsLeft} phút`,
                    };
                }
            }
        }
    }

    return closestSchedule;
}

// ==========================================
// CƠ CHẾ HỎI - TRẢ LỜI LỊCH TRÌNH (QUESTION - ANSWER ENGINE)
// ==========================================
export function askScheduleStatus(options: {
    targetTime?: string;
    targetDayIndex?: number;
    execute?: boolean;
    sendCommandFn?: (baseTopic: string, stateStr: string, source: string) => void;
    filterTopic?: string | null;
    callerTag?: string;
} = {}) {
    const defaultTimeInfo = getCurrentVietnamTimeInfo();
    const targetTime = options.targetTime || defaultTimeInfo.currentTime;
    const targetDayIndex = options.targetDayIndex !== undefined ? options.targetDayIndex : defaultTimeInfo.appDayIndex;
    const dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    const targetDayName = dayNames[targetDayIndex] || 'Không xác định';
    const execute = Boolean(options.execute);
    const sendCommandFn = options.sendCommandFn || null;
    const filterTopic = options.filterTopic || null;
    const callerTag = options.callerTag || '[CRON-QA]';

    const matchedSchedules: any[] = [];

    for (const [scheduleKey, schedule] of Object.entries(state.activeSchedules || {})) {
        const baseTopic = schedule.baseTopic;
        if (filterTopic && !baseTopic.includes(filterTopic)) continue;

        const timeOnFormatted = formatTime(schedule.timeOn);
        const timeOffFormatted = formatTime(schedule.timeOff);

        if (isDayActive(schedule.days, targetDayIndex)) {
            // So sánh giờ BẬT
            if (timeOnFormatted === targetTime) {
                matchedSchedules.push({
                    scheduleId: scheduleKey,
                    baseTopic,
                    action: 'BẬT',
                    stateVal: '1',
                    scheduledTime: timeOnFormatted,
                    isAlreadyTriggered: Boolean(schedule.isTriggeredOn),
                });

                if (execute && !schedule.isTriggeredOn && sendCommandFn) {
                    console.log(`${callerTag} 💡 Trả lời: Kích hoạt lịch BẬT cho ${baseTopic}`);
                    sendCommandFn(baseTopic, '1', 'schedule_qa');
                    schedule.isTriggeredOn = true;
                }
            } else {
                schedule.isTriggeredOn = false;
            }

            // So sánh giờ TẮT
            if (timeOffFormatted === targetTime) {
                matchedSchedules.push({
                    scheduleId: scheduleKey,
                    baseTopic,
                    action: 'TẮT',
                    stateVal: '0',
                    scheduledTime: timeOffFormatted,
                    isAlreadyTriggered: Boolean(schedule.isTriggeredOff),
                });

                if (execute && !schedule.isTriggeredOff && sendCommandFn) {
                    console.log(`${callerTag} 🔌 Trả lời: Kích hoạt lịch TẮT cho ${baseTopic}`);
                    sendCommandFn(baseTopic, '0', 'schedule_qa');
                    schedule.isTriggeredOff = true;
                }
            } else {
                schedule.isTriggeredOff = false;
            }
        }
    }

    const nextUpcoming = getNextUpcomingSchedule();
    const totalActive = Object.keys(state.activeSchedules || {}).length;

    return {
        success: true,
        protocol: 'HOI_TRA_LOI_V2',
        question: {
            targetTime,
            targetDayIndex,
            targetDayName,
            filterTopic,
            execute,
            askedAt: new Date().toISOString(),
        },
        answer: {
            status: matchedSchedules.length > 0 ? 'triggered' : 'idle',
            totalActiveSchedules: totalActive,
            matchedCount: matchedSchedules.length,
            matchedSchedules,
            nextUpcoming,
            message: matchedSchedules.length > 0
                ? `Tìm thấy ${matchedSchedules.length} lịch trình khớp thời điểm ${targetTime} (${targetDayName}).`
                : `Không có lịch trình nào cần kích hoạt tại ${targetTime} (${targetDayName}). Hệ thống ở trạng thái nghỉ an toàn.`,
        }
    };
}

// ==========================================
// ĐỒNG BỘ LỊCH TRÌNH VỚI FIREBASE
// ==========================================
export async function loadSchedulesFromFirebase() {
    try {
        const snapshot = await db.collection('server_schedules').get();
        let loadedCount = 0;
        let garbageCount = 0;
        const validUsers = new Set<string>();
        const invalidUsers = new Set<string>();

        for (const doc of snapshot.docs) {
            const docId = doc.id;
            const userId = docId.split('___')[0];

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
                console.log(`[BACKEND] 🧹 Phát hiện tài khoản rác (${userId}) không tồn tại trên DB. Xóa lịch trình: ${docId}`);
                await db.collection('server_schedules').doc(docId).delete();
                garbageCount++;
                continue;
            }

            state.activeSchedules[docId] = doc.data() as any;
            state.activeSchedules[docId].isTriggeredOn = false;
            state.activeSchedules[docId].isTriggeredOff = false;
            loadedCount++;
        }

        const next = getNextUpcomingSchedule();
        const nextInfo = next ? ` | Lần chạy kế tiếp: ${next.targetDayName} ${next.time} (${next.action})` : ' | Chưa có lịch kích hoạt sắp tới';
        console.log(`[FIREBASE] ✅ Đã nạp ${loadedCount} lịch trình vào RAM (Dọn dẹp: ${garbageCount})${nextInfo}`);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi nạp lịch trình:", error);
    }
}

export async function saveScheduleToFirebase(baseTopic: string, scheduleData: any) {
    try {
        const docId = baseTopic.replace(/\//g, '___');
        await db.collection('server_schedules').doc(docId).set(scheduleData);
        const next = getNextUpcomingSchedule();
        const nextText = next ? ` (Kế tiếp: ${next.targetDayName} ${next.time} - ${next.action})` : '';
        console.log(`[CRON-QA] 📋 Đã lưu cấu hình lịch trình: ${baseTopic}${nextText}`);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi lưu lịch trình:", error);
    }
}

export async function deleteScheduleFromFirebase(baseTopic: string) {
    try {
        const docId = baseTopic.replace(/\//g, '___');
        await db.collection('server_schedules').doc(docId).delete();
        console.log(`[CRON-QA] 🗑️ Đã xóa lịch trình: ${baseTopic}`);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi xóa lịch trình:", error);
    }
}

// ==========================================
// THỰC THI THÔNG MINH - HỎI TRẢ LỜI ĐỊNH KỲ (YÊN LẶNG KHI RỖNG)
// ==========================================
export function startCronJob(sendCommandWithRetry: (baseTopic: string, stateStr: string, source: string) => void) {
    if (!state.cronStatus) {
        state.cronStatus = {
            active: true,
            timezone: 'Asia/Ho_Chi_Minh',
            mode: 'HOI_TRA_LOI_EVENT_DRIVEN',
            lastRunAt: null,
            pattern: '* * * * *'
        };
    }

    cron.schedule('* * * * *', () => {
        state.cronStatus.lastRunAt = new Date().toISOString();

        const activeCount = Object.keys(state.activeSchedules || {}).length;
        if (activeCount === 0) {
            return;
        }

        const { currentTime, dayName, appDayIndex } = getCurrentVietnamTimeInfo();

        const qaResult = askScheduleStatus({
            targetTime: currentTime,
            targetDayIndex: appDayIndex,
            execute: true,
            sendCommandFn: sendCommandWithRetry,
            callerTag: '[CRON-QA]'
        });

        if (qaResult.answer.matchedCount > 0) {
            console.log(`[CRON-QA] ❓ Hỏi: Đã đến ${currentTime} (${dayName}), có lịch trình nào cần kích hoạt?`);
            for (const item of qaResult.answer.matchedSchedules) {
                console.log(`[CRON-QA] 💬 Trả lời: Khớp lệnh [${item.baseTopic} -> ${item.action}]. Đã phát tín hiệu.`);
            }
        }
    });

    console.log('[CRON-QA] 🚀 Cơ chế Lịch trình Thông minh (Hỏi - Trả lời) đã kích hoạt: Tự động giữ yên lặng khi không có sự kiện.');
}
