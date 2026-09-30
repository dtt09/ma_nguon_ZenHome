const { db, FieldValue, getMessaging } = require('./firebase');
const state = require('./state');
const { deleteScheduleFromFirebase } = require('./schedules');

// ==========================================
// HÀM GỬI PUSH THEO TOKEN THAY VÌ TOPIC
// ==========================================
async function sendPushToUserTokens(userId, messageContentVi, messageContentEn, isEn, trustedOnly = false, category = 'other', homeId = null) {
    try {
        const actualHomeId = homeId || userId;
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) return;

        let targetUsernames = [userId];
        const userData = userDoc.data();
        const disabledMembers = Array.isArray(userData.disabledMembers) ? userData.disabledMembers : [];
        if (userData.sharedWith && Array.isArray(userData.sharedWith)) {
            const activeMembers = userData.sharedWith.filter(m => !disabledMembers.includes(m));
            targetUsernames = targetUsernames.concat(activeMembers);
        }

        const tokensVi = [];
        const tokensEn = [];

        for (const targetUser of targetUsernames) {
            let userLang = 'vi';
            if (targetUser === userId) {
                userLang = userData.language || 'vi';
            } else {
                const tuDoc = await db.collection('users').doc(targetUser).get();
                if (tuDoc.exists && tuDoc.data().language) {
                    userLang = tuDoc.data().language;
                }
            }

            let query = db.collection('users').doc(targetUser).collection('sessions').where('isActive', '==', true);
            if (trustedOnly) {
                query = query.where('isTrusted', '==', true);
            }
            const sessionsSnapshot = await query.get();
            sessionsSnapshot.forEach(doc => {
                const data = doc.data();
                if (data.fcmToken) {
                    if (userLang === 'en') {
                        tokensEn.push(data.fcmToken);
                    } else {
                        tokensVi.push(data.fcmToken);
                    }
                }
            });
        }

        const promises = [];

        if (tokensVi.length > 0) {
            promises.push(getMessaging().sendEachForMulticast({
                notification: messageContentVi,
                data: { category: category, homeId: actualHomeId },
                tokens: tokensVi
            }));
        }

        if (tokensEn.length > 0) {
            promises.push(getMessaging().sendEachForMulticast({
                notification: messageContentEn,
                data: { category: category, homeId: actualHomeId },
                tokens: tokensEn
            }));
        }

        if (promises.length === 0) {
            console.log(`[FIREBASE] ⚠️ Không có token FCM nào phù hợp cho user ${userId} & family (TrustedOnly: ${trustedOnly}). Bỏ qua gửi Push.`);
            return;
        }

        const responses = await Promise.all(promises);
        const successCount = responses.reduce((acc, response) => acc + response.successCount, 0);
        console.log(`[FIREBASE] ✅ Đã gửi Push Notification tới ${successCount} thiết bị của user: ${userId} & family`);
    } catch (error) {
        console.error(`[FIREBASE ERROR] ❌ Lỗi gửi Multicast Push cho ${userId}:`, error);
    }
}

// ==========================================
// HÀM GHI LỊCH SỬ & BẮN THÔNG BÁO PUSH
// ==========================================
async function logHistoryAndNotify(userId, devId, actionText, source = 'action') {
    try {
        let targetEmail = null;
        let deviceName = `Thiết bị ${devId}`;
        let language = 'vi';

        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
            targetEmail = userDoc.id;
            const data = userDoc.data();
            if (data.language) language = data.language;
            const devices = data.devices || [];
            const dev = devices.find(d => d.id === devId);
            if (dev) deviceName = dev.name;
        }

        if (!targetEmail) return;

        const isEn = language === 'en';
        const actionTextEn = actionText === 'BẬT' ? 'TURNED ON' : 'TURNED OFF';
        
        let displaySourceVi = 'Tự động';
        let displaySourceEn = 'Auto';
        
        if (source === 'timer') { displaySourceVi = 'Hẹn giờ'; displaySourceEn = 'Timer'; }
        else if (source === 'schedule') { displaySourceVi = 'Lịch trình'; displaySourceEn = 'Schedule'; }

        const actionDisplay = isEn ? `${actionTextEn} (${displaySourceEn})` : `${actionText} (${displaySourceVi})`;

        const historyRef = db.collection('users').doc(targetEmail).collection('history');
        await historyRef.add({
            deviceName: deviceName,
            action: actionDisplay,
            timestamp: FieldValue.serverTimestamp(),
        });

        // Dọn rác: Giữ lại 100 bản ghi mới nhất
        try {
            const snapshot = await historyRef.orderBy('timestamp', 'desc').offset(100).get();
            if (!snapshot.empty) {
                const batch = db.batch();
                snapshot.docs.forEach(doc => batch.delete(doc.ref));
                await batch.commit();
            }
        } catch(e) { console.error("Lỗi dọn rác history:", e); }

        let bodyVi = `${deviceName} vừa được ${actionText.toLowerCase()} thành công!`;
        let bodyEn = `${deviceName} has been successfully ${actionTextEn.toLowerCase()}!`;
        
        if (source === 'timer') {
            bodyVi = `Đã hoàn tất hẹn giờ ${actionText.toLowerCase()} cho ${deviceName}!`;
            bodyEn = `Timer completed: ${deviceName} is now ${actionTextEn.toLowerCase()}!`;
        } else if (source === 'schedule') {
            bodyVi = `Lịch trình tự động đã ${actionText.toLowerCase()} ${deviceName}!`;
            bodyEn = `Automated schedule has ${actionTextEn.toLowerCase()} ${deviceName}!`;
        }

        const notificationVi = {
            title: 'ZenHome',
            body: bodyVi
        };

        const notificationEn = {
            title: 'ZenHome',
            body: bodyEn
        };

        await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, source);
        console.log(`[FIREBASE] ✅ Đã ghi lịch sử (Push Notification qua Token) cho ${deviceName} (Nguồn: ${source})`);

    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi khi ghi lịch sử/thông báo:", error);
    }
}

async function notifyOffline(userId, devId) {
    try {
        let targetEmail = null;
        let deviceName = `Thiết bị ${devId}`;
        let language = 'vi';

        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) {
            targetEmail = userDoc.id;
            const data = userDoc.data();
            if (data.language) language = data.language;
            const devices = data.devices || [];
            const dev = devices.find(d => d.id === devId);
            if (dev) deviceName = dev.name;
        }

        const isEn = language === 'en';

        if (targetEmail) {
            const historyRef = db.collection('users').doc(targetEmail).collection('history');
            await historyRef.add({
                deviceName: deviceName,
                action: isEn ? 'Disconnected / Unresponsive' : 'Mất kết nối / Không phản hồi',
                timestamp: FieldValue.serverTimestamp(),
            });
            
            // Dọn rác: Giữ lại 100 bản ghi mới nhất
            try {
                const snapshot = await historyRef.orderBy('timestamp', 'desc').offset(100).get();
                if (!snapshot.empty) {
                    const batch = db.batch();
                    snapshot.docs.forEach(doc => batch.delete(doc.ref));
                    await batch.commit();
                }
            } catch(e) { console.error("Lỗi dọn rác history:", e); }
        } else {
            console.log(`[FIREBASE] ⚠️ Không tìm thấy user ${userId}, dọn dẹp tài khoản rác khỏi luồng kiểm tra.`);
            // Dọn dẹp tài khoản rác khỏi RAM
            Object.keys(state.activeSchedules).forEach(topic => {
                if (topic.startsWith(`${userId}___`)) {
                    delete state.activeSchedules[topic];
                    deleteScheduleFromFirebase(topic);
                }
            });
            Object.keys(state.pendingTasks).forEach(topic => {
                if (topic.startsWith(`${userId}/`)) {
                    clearInterval(state.pendingTasks[topic].intervalId);
                    delete state.pendingTasks[topic];
                }
            });
            
            // Xóa các timer hẹn giờ
            Object.keys(state.activeTimers || {}).forEach(timerKey => {
                if (timerKey.startsWith(`${userId}/`)) {
                    clearTimeout(state.activeTimers[timerKey]);
                    delete state.activeTimers[timerKey];
                }
            });
            return; // Dừng việc bắn Push vì user không tồn tại
        }

        const notificationVi = {
            title: 'Cảnh Báo Ngoại Tuyến',
            body: `⚠️ ${deviceName} không phản hồi lệnh. Thiết bị có thể đang offline!`
        };

        const notificationEn = {
            title: 'Offline Warning',
            body: `⚠️ ${deviceName} is unresponsive. The device might be offline!`
        };

        await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
        console.log(`[FIREBASE] ⚠️ Đã Bắn Push Cảnh báo Offline cho ${deviceName}`);

    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi khi ghi cảnh báo offline:", error);
    }
}

// ==========================================
// BẮT SỰ KIỆN CẢNH BÁO BẢO MẬT (FCM BACKGROUND)
// ==========================================
async function processAlert(data, userEmail, userId) {
    try {
        let language = 'vi';
        const userDoc = await db.collection('users').doc(userEmail).get();
        if (userDoc.exists && userDoc.data().language) {
            language = userDoc.data().language;
        }
        const isEn = language === 'en';

        if (data.type === 'new_login') {
            const deviceName = data.deviceName || 'Thiết bị lạ';
            const location = data.location || 'Không rõ';

            const notificationVi = {
                title: 'Cảnh báo Bảo mật',
                body: `Có thiết bị mới (${deviceName}) vừa đăng nhập vào tài khoản của bạn từ ${location}.`
            };
            const notificationEn = {
                title: 'Security Alert',
                body: `A new device (${deviceName}) just logged into your account from ${location}.`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, true, 'important');
            console.log(`[FIREBASE] 🚨 Đã gửi FCM Cảnh báo Đăng nhập mới cho ${userId} (Chỉ thiết bị tin cậy)`);
        }
        else if (data.type === 'trust_request') {
            const deviceName = data.deviceName || 'Thiết bị';
            const notificationVi = {
                title: 'Yêu cầu cấp quyền',
                body: `Thiết bị "${deviceName}" đang xin cấp quyền Tin cậy. Mở app để phê duyệt.`
            };
            const notificationEn = {
                title: 'Trust Request',
                body: `Device "${deviceName}" is requesting Trusted access. Open the app to approve.`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, true, 'important');
            console.log(`[FIREBASE] 🚨 Đã gửi FCM Yêu cầu Tin cậy cho ${userId} (Chỉ thiết bị tin cậy)`);
        }
        else if (data.type === 'automation_edit') {
            const author = data.author || 'Một thành viên';
            const actionName = data.actionName || 'đã chỉnh sửa thiết lập tự động hóa';
            const notificationVi = {
                title: 'Cập nhật Tự động hóa',
                body: `${author} ${actionName}.`
            };
            const notificationEn = {
                title: 'Automation Update',
                body: `${author} ${actionName}.`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
            console.log(`[FIREBASE] 🚨 Đã gửi FCM Cập nhật Tự động hóa cho ${userId}`);
        }
        else if (data.type === 'new_invite') {
            const inviter = data.inviter || 'Một ai đó';
            const notificationVi = {
                title: 'Lời mời Tham gia nhà',
                body: `${inviter} vừa mời bạn tham gia và điều khiển nhà của họ. Hãy mở app để xác nhận!`
            };
            const notificationEn = {
                title: 'Home Invitation',
                body: `${inviter} has invited you to join and control their home. Open the app to respond!`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
            console.log(`[FIREBASE] 🚨 Đã gửi FCM Lời mời vào nhà cho ${userId}`);
        }
    } catch (error) {
        console.error('[FIREBASE ERROR] Lỗi gửi thông báo cảnh báo:', error);
    }
}

module.exports = {
    sendPushToUserTokens,
    logHistoryAndNotify,
    notifyOffline,
    processAlert
};
