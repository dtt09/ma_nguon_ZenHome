const { db, getAuth, FieldValue } = require('./firebase.cjs');
const client = require('./mqtt.cjs');
const state = require('./state.cjs');
const { processAlert } = require('./notifications.cjs');
const { deleteScheduleFromFirebase } = require('./schedules.cjs');

const userAlertsUnsubscribers = {};

function startListeningToAlerts() {
    console.log(`[FIREBASE] 🛡️ Đang khởi chạy trình lắng nghe Cảnh báo bảo mật...`);
    db.collection('users').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(async change => {
            const userEmail = change.doc.id; // Document ID là username
            const userId = userEmail;

            if (change.type === 'added') {
                if (userAlertsUnsubscribers[userEmail]) {
                    userAlertsUnsubscribers[userEmail]();
                    delete userAlertsUnsubscribers[userEmail];
                }
                const now = new Date();
                const unsub = db.collection('users').doc(userEmail).collection('alerts')
                    .where('timestamp', '>', now)
                    .onSnapshot(alertsSnap => {
                        alertsSnap.docChanges().forEach(alertChange => {
                            if (alertChange.type === 'added') {
                                processAlert(alertChange.doc.data(), userEmail, userId);
                            }
                        });
                    }, err => {
                        console.error(`[FIREBASE ERROR] ❌ Lỗi lắng nghe alerts của ${userEmail}:`, err);
                    });
                userAlertsUnsubscribers[userEmail] = unsub;
            }
            else if (change.type === 'removed') {
                if (userAlertsUnsubscribers[userEmail]) {
                    userAlertsUnsubscribers[userEmail]();
                    delete userAlertsUnsubscribers[userEmail];
                }

                // Xử lý khi user xóa tài khoản
                const userData = change.doc.data();
                const isOwner = userData ? (!userData.role || userData.role === 'owner') : true;

                if (isOwner) {
                    // Xóa toàn bộ subcollections (history, sessions, alerts, timers, scenes, schedules)
                    const subcollections = ['history', 'sessions', 'alerts', 'timers', 'scenes', 'schedules'];
                    for (const sub of subcollections) {
                        try {
                            let subSnap = await db.collection('users').doc(userId).collection(sub).limit(400).get();
                            let totalDeleted = 0;
                            while (!subSnap.empty) {
                                const batch = db.batch();
                                subSnap.docs.forEach(doc => batch.delete(doc.ref));
                                await batch.commit();
                                totalDeleted += subSnap.docs.length;
                                subSnap = await db.collection('users').doc(userId).collection(sub).limit(400).get();
                            }
                            if (totalDeleted > 0) {
                                console.log(`[BACKEND] ✅ Đã xóa ${totalDeleted} bản ghi trong subcollection '${sub}' của user ${userId}`);
                            }
                        } catch (err) {
                            console.error(`[BACKEND ERROR] ❌ Lỗi xóa subcollection ${sub}:`, err);
                        }
                    }

                    // Dọn dẹp schedules trong RAM & server_schedules
                    let schedCount = 0;
                    Object.keys(state.activeSchedules || {}).forEach(schedKey => {
                        if (schedKey.startsWith(`${userId}___`)) {
                            delete state.activeSchedules[schedKey];
                            deleteScheduleFromFirebase(schedKey);
                            schedCount++;
                        }
                    });
                    if (schedCount > 0) {
                        console.log(`[BACKEND] ✅ Đã dọn dẹp ${schedCount} lịch trình của user ${userId}`);
                    }

                    // Dọn dẹp timers trong RAM
                    let timerCount = 0;
                    Object.keys(state.activeTimers || {}).forEach(timerKey => {
                        if (timerKey.startsWith(`${userId}/`)) {
                            clearTimeout(state.activeTimers[timerKey]);
                            delete state.activeTimers[timerKey];
                            timerCount++;
                        }
                    });
                    if (timerCount > 0) {
                        console.log(`[BACKEND] ✅ Đã dọn dẹp ${timerCount} bộ hẹn giờ (timer) khỏi RAM của user ${userId}`);
                    }
                    (async () => {
                        try {
                            const snap = await db.collection('server_timers').get();
                            const timerDocs = snap.docs.filter(doc => doc.id.startsWith(userId + '___'));
                            let count = 0;
                            const batch = db.batch();
                            timerDocs.forEach(doc => {
                                batch.delete(doc.ref);
                                count++;
                            });
                            await batch.commit();
                            if (count > 0) console.log(`[BACKEND] ✅ Đã xóa ${count} timer ngầm (server_timers) của user ${userId}`);
                        } catch (e) {}
                    })();

                    // Dọn dẹp members (xóa liên kết khỏi nhà ảo)
                    if (userData && userData.sharedWith && Array.isArray(userData.sharedWith)) {
                        userData.sharedWith.forEach(async (memberUsername) => {
                            try {
                                await db.collection('users').doc(memberUsername).update({
                                    ownerUsername: FieldValue.delete(),
                                    ownerEmail: FieldValue.delete()
                                });
                                console.log(`[BACKEND] ✅ Đã xóa liên kết nhà của thành viên ${memberUsername} do Chủ nhà ${userId} xóa tài khoản`);
                            } catch (err) {
                                console.error(`[BACKEND ERROR] ❌ Lỗi xóa liên kết nhà của thành viên ${memberUsername}:`, err);
                            }
                        });
                    }
                } else {
                    console.log(`[BACKEND] ℹ️ Thành viên ${userId} xóa tài khoản. Không reset ESP32 của Owner.`);
                    if (userData && userData.ownerUsername) {
                        try {
                            const ownerRef = db.collection('users').doc(userData.ownerUsername);
                            await ownerRef.update({
                                sharedWith: FieldValue.arrayRemove(userId),
                                [`memberRoles.${userId}`]: FieldValue.delete()
                            });
                            console.log(`[BACKEND] ✅ Đã gỡ thành viên ${userId} khỏi danh sách của chủ nhà ${userData.ownerUsername}`);
                        } catch (err) {
                            console.error(`[BACKEND ERROR] ❌ Lỗi gỡ thành viên ${userId} khỏi chủ nhà:`, err);
                        }
                    }
                }
            }
        });
    }, err => {
        console.error('[FIREBASE ERROR] ❌ Lỗi lắng nghe danh sách users:', err);
    });
}

function startListeningToDeleteRequests() {
    console.log(`[FIREBASE] 🗑️ Đang khởi chạy trình lắng nghe lệnh xóa tài khoản...`);
    db.collection('delete_requests').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(async change => {
            if (change.type === 'added') {
                const data = change.doc.data();
                const username = change.doc.id;
                const uid = data.uid;
                
                console.log(`[BACKEND] 🗑️ Nhận lệnh xóa tài khoản cho user: ${username} (UID: ${uid})`);
                
                try {
                    // 1. Gửi lệnh Factory Reset tới ESP32 (nếu có liên kết)
                    const userDoc = await db.collection('users').doc(username).get();
                    if (userDoc.exists) {
                        const userData = userDoc.data();
                        const isOwner = (!userData.role || userData.role === 'owner');
                        const macAddress = userData.macAddress;
                        
                        if (isOwner && macAddress && macAddress !== 'unknown_mac' && macAddress !== 'unknown') {
                            const resetTopic = `${username}/${macAddress}/system/reset`;
                            client.publish(resetTopic, '1', { qos: 1, retain: true });
                            console.log(`[BACKEND] ✅ Đã gửi lệnh Factory Reset tới ESP32 do Owner xóa tài khoản: ${resetTopic}`);
                        }
                    }

                    // 2. Xóa Firebase Auth User
                    if (uid) {
                        try {
                            await getAuth().deleteUser(uid);
                            console.log(`[BACKEND] ✅ Đã xóa tài khoản Auth của ${username}`);
                        } catch (e) {
                            console.error(`[BACKEND ERROR] ❌ Lỗi xóa Auth của ${username}:`, e);
                        }
                    }
                    
                    // 3. Xóa Firestore User Document
                    await db.collection('users').doc(username).delete();
                    console.log(`[BACKEND] ✅ Đã xóa document chính của ${username}`);
                    
                    // 4. Xóa chính request này
                    await change.doc.ref.delete();
                } catch (err) {
                    console.error(`[BACKEND ERROR] ❌ Lỗi khi xử lý lệnh xóa tài khoản ${username}:`, err);
                }
            }
        });
    }, err => {
        console.error('[FIREBASE ERROR] ❌ Lỗi lắng nghe delete_requests:', err);
    });
}

function startListeningToUnlinkRequests() {
    console.log(`[FIREBASE] 🔓 Đang khởi chạy trình lắng nghe Lệnh hủy liên kết (Free Email/Phone)...`);
    db.collection('unlink_requests').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(async change => {
            if (change.type === 'added') {
                const data = change.doc.data();
                const requestId = change.doc.id;
                const uid = data.uid;
                const fallbackEmail = data.fallbackEmail;
                
                console.log(`[BACKEND] 🔓 Nhận lệnh giải phóng định danh cho UID: ${uid}`);
                
                try {
                    if (fallbackEmail) {
                        await getAuth().updateUser(uid, { email: fallbackEmail });
                        console.log(`[BACKEND] ✅ Đã cập nhật email thành ${fallbackEmail} để giải phóng email thật cho ${uid}`);
                    }
                    
                    // Xóa request
                    await change.doc.ref.delete();
                } catch (err) {
                    console.error(`[BACKEND ERROR] ❌ Lỗi khi xử lý lệnh giải phóng cho ${uid}:`, err);
                    await change.doc.ref.delete();
                }
            }
        });
    }, err => {
        console.error('[FIREBASE ERROR] ❌ Lỗi lắng nghe unlink_requests:', err);
    });
}

module.exports = {
    startListeningToAlerts,
    startListeningToDeleteRequests,
    startListeningToUnlinkRequests
};
