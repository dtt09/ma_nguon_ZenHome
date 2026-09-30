const cron = require('node-cron');
const { db } = require('./firebase');
const state = require('./state');

// ==========================================
// ĐỒNG BỘ LỊCH TRÌNH VỚI FIREBASE
// ==========================================
async function loadSchedulesFromFirebase() {
    try {
        const snapshot = await db.collection('server_schedules').get();
        let loadedCount = 0;
        let garbageCount = 0;
        const validUsers = new Set();
        const invalidUsers = new Set();

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
                console.log(`[BACKEND] 🗑️ Phát hiện tài khoản rác (${userId}) không tồn tại trên DB. Xóa lịch trình ngầm: ${docId}`);
                await db.collection('server_schedules').doc(docId).delete();
                garbageCount++;
                continue;
            }

            state.activeSchedules[docId] = doc.data();
            state.activeSchedules[docId].isTriggeredOn = false;
            state.activeSchedules[docId].isTriggeredOff = false;
            loadedCount++;
        }
        console.log(`[FIREBASE] 🔄 Đã nạp ${loadedCount} lịch trình từ Firestore vào RAM. Dọn dẹp ${garbageCount} lịch trình rác.`);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi nạp lịch trình:", error);
    }
}

async function saveScheduleToFirebase(baseTopic, scheduleData) {
    try {
        const docId = baseTopic.replace(/\//g, '___'); // Firestore ID không được chứa '/'
        await db.collection('server_schedules').doc(docId).set(scheduleData);
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi lưu lịch trình:", error);
    }
}

async function deleteScheduleFromFirebase(baseTopic) {
    try {
        const docId = baseTopic.replace(/\//g, '___');
        await db.collection('server_schedules').doc(docId).delete();
    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi xóa lịch trình:", error);
    }
}

// ==========================================
// CRON JOB - LỊCH TRÌNH THỜI GIAN THỰC
// ==========================================
function startCronJob(sendCommandWithRetry) {
    cron.schedule('* * * * *', () => {
        // 1. Ép thời gian về đúng múi giờ Việt Nam (Bỏ qua giờ của Server Render)
        const now = new Date();
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

        // 3. Quy đổi ngày trong tuần: App (0=T2, 6=CN)
        const dayStr = formatterDay.format(now);
        const dayMap = { 'Mon': 0, 'Tue': 1, 'Wed': 2, 'Thu': 3, 'Fri': 4, 'Sat': 5, 'Sun': 6 };
        const appDayIndex = dayMap[dayStr] ?? 0;
        const dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
        console.log(`[CRON] Đang quét lịch trình... (Giờ VN hiện tại: ${currentTime}, Hôm nay: ${dayNames[appDayIndex]})`);

        for (const [scheduleKey, schedule] of Object.entries(state.activeSchedules)) {
            const baseTopic = schedule.baseTopic;
            // Chuẩn hóa định dạng thời gian từ Firebase (đề phòng app gửi thiếu số 0 ở đầu)
            const formatTime = (t) => t ? t.split(':').map(x => x.padStart(2, '0')).join(':') : null;
            const timeOnFormatted = formatTime(schedule.timeOn);
            const timeOffFormatted = formatTime(schedule.timeOff);

            // Kiểm tra xem hôm nay có được phép chạy lịch không
            if (schedule.days[appDayIndex] === '1') {

                // So sánh giờ BẬT
                if (timeOnFormatted === currentTime) {
                    if (!schedule.isTriggeredOn) {
                        console.log(`[CRON] ⏰ Đã đến giờ BẬT lịch trình: ${baseTopic}`);
                        sendCommandWithRetry(baseTopic, '1', 'schedule');
                        schedule.isTriggeredOn = true; // Khóa cờ
                    }
                } else {
                    schedule.isTriggeredOn = false; // Xóa cờ khi qua phút khác
                }

                // So sánh giờ TẮT
                if (timeOffFormatted === currentTime) {
                    if (!schedule.isTriggeredOff) {
                        console.log(`[CRON] ⏰ Đã đến giờ TẮT lịch trình: ${baseTopic}`);
                        sendCommandWithRetry(baseTopic, '0', 'schedule');
                        schedule.isTriggeredOff = true;
                    }
                } else {
                    schedule.isTriggeredOff = false;
                }
            }
        }
    });
}

module.exports = {
    loadSchedulesFromFirebase,
    saveScheduleToFirebase,
    deleteScheduleFromFirebase,
    startCronJob
};
