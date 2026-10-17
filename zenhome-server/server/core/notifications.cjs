const { db, FieldValue, getMessaging } = require('./firebase.cjs');
const state = require('./state.cjs');
const { deleteScheduleFromFirebase } = require('./schedules.cjs');

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
                tokens: tokensVi,
            }));
        }

        if (tokensEn.length > 0) {
            promises.push(getMessaging().sendEachForMulticast({
                notification: messageContentEn,
                data: { category: category, homeId: actualHomeId },
                tokens: tokensEn,
            }));
        }

        await Promise.all(promises);
    } catch (error) {
        console.error('[FIREBASE ERROR] ❌ Lỗi gửi thông báo FCM:', error);
    }
}

async function logHistoryAndNotify(userId, devId, actionText, source) {
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
                action: actionText,
                source: source,
                timestamp: FieldValue.serverTimestamp(),
            });

            // Giữ lại 100 bản ghi mới nhất
            try {
                const snapshot = await historyRef.orderBy('timestamp', 'desc').offset(100).get();
                if (!snapshot.empty) {
                    const batch = db.batch();
                    snapshot.docs.forEach(doc => batch.delete(doc.ref));
                    await batch.commit();
                }
            } catch(e) {}
        }

        const bodyVi = `${deviceName} vừa được ${actionText} (Nguồn: ${source})`;
        const bodyEn = `${deviceName} was just turned ${actionText === 'BẬT' ? 'ON' : 'OFF'} (Source: ${source})`;

        const notificationVi = {
            title: 'ZenHome',
            body: bodyVi
        };

        const notificationEn = {
            title: 'ZenHome',
            body: bodyEn
        };

        await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, source);
        console.log(`[FIREBASE] 📝 Đã ghi lịch sử & bắn Push cho ${deviceName}: ${actionText} (Nguồn: ${source})`);

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
            
            try {
                const snapshot = await historyRef.orderBy('timestamp', 'desc').offset(100).get();
                if (!snapshot.empty) {
                    const batch = db.batch();
                    snapshot.docs.forEach(doc => batch.delete(doc.ref));
                    await batch.commit();
                }
            } catch(e) {}
        } else {
            console.log(`[FIREBASE] ⚠️ Không tìm thấy user ${userId}, dọn dẹp tài khoản rác khỏi luồng kiểm tra.`);
            // Dọn dẹp khỏi RAM
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
            Object.keys(state.activeTimers || {}).forEach(timerKey => {
                if (timerKey.startsWith(`${userId}/`)) {
                    clearTimeout(state.activeTimers[timerKey]);
                    delete state.activeTimers[timerKey];
                }
            });
            return;
        }

        const notificationVi = {
            title: '⚠️ Cảnh báo Ngoại Tuyến',
            body: `${deviceName} không phản hồi lệnh. Thiết bị có thể đang offline!`
        };

        const notificationEn = {
            title: '⚠️ Offline Warning',
            body: `${deviceName} is unresponsive. The device might be offline!`
        };

        await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
        console.log(`[FIREBASE] ⚠️ Đã bắn Push Cảnh báo Offline cho ${deviceName}`);

    } catch (error) {
        console.error("[FIREBASE ERROR] ❌ Lỗi khi ghi Cảnh báo offline:", error);
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
                title: '🛡️ Cảnh báo bảo mật',
                body: `Có thiết bị mới (${deviceName}) vừa đăng nhập vào tài khoản của bạn từ ${location}.`
            };
            const notificationEn = {
                title: '🛡️ Security Alert',
                body: `A new device (${deviceName}) just logged into your account from ${location}.`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, true, 'important');
            console.log(`[FIREBASE] 🛡️ Đã gửi FCM Cảnh báo đăng nhập mới cho ${userId} (Chỉ thiết bị tin cậy)`);
        }
        else if (data.type === 'trust_request') {
            const deviceName = data.deviceName || 'Thiết bị';
            const notificationVi = {
                title: '🔑 Yêu cầu cấp quyền',
                body: `Thiết bị "${deviceName}" đang xin cấp quyền Tin cậy. Mở app để phê duyệt.`
            };
            const notificationEn = {
                title: '🔑 Trust Request',
                body: `Device "${deviceName}" is requesting Trusted access. Open the app to approve.`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, true, 'important');
            console.log(`[FIREBASE] 🔑 Đã gửi FCM Yêu cầu Tin cậy cho ${userId} (Chỉ thiết bị tin cậy)`);
        }
        else if (data.type === 'automation_edit') {
            const author = data.author || 'Một thành viên';
            const actionName = data.actionName || 'đã chỉnh sửa thiết lập tự động hóa';
            const notificationVi = {
                title: '⚙️ Cập nhật Tự động hóa',
                body: `${author} ${actionName}.`
            };
            const notificationEn = {
                title: '⚙️ Automation Update',
                body: `${author} ${actionName}.`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
            console.log(`[FIREBASE] ⚙️ Đã gửi FCM Cập nhật Tự động hóa cho ${userId}`);
        }
        else if (data.type === 'new_invite') {
            const inviter = data.inviter || 'Một ai đó';
            const notificationVi = {
                title: '📩 Lời mời Tham gia nhà',
                body: `${inviter} vừa mời bạn tham gia và điều khiển nhà của họ. Hãy mở app để xác nhận!`
            };
            const notificationEn = {
                title: '📩 Home Invitation',
                body: `${inviter} has invited you to join and control their home. Open the app to respond!`
            };

            await sendPushToUserTokens(userId, notificationVi, notificationEn, isEn, false, 'important');
            console.log(`[FIREBASE] 📩 Đã gửi FCM Lời mời vào nhà cho ${userId}`);
        }
    } catch (error) {
        console.error('[FIREBASE ERROR] ❌ Lỗi gửi thông báo Cảnh báo:', error);
    }
}

/**
 * ==============================================================================
 * GỬI THÔNG BÁO ĐẨY FCM ĐA NGÔN NGỮ (VIE / ENG) CHO BẢN CẬP NHẬT PHIÊN BẢN MỚI
 * ==============================================================================
 */
async function sendAppVersionUpdateFCM(versionData) {
    try {
        const {
            latestVersion,
            latestBuildNumber,
            titleVi,
            titleEn,
            releaseNotesVi,
            releaseNotesEn,
            isForceUpdate,
            downloadUrl,
            directApkUrl
        } = versionData;

        const vTitleVi = titleVi || `🚀 Bản Cập Nhật ZenHome v${latestVersion}`;
        const vTitleEn = titleEn || `🚀 ZenHome Update v${latestVersion}`;
        
        // Trích dòng đầu tiên làm body tóm tắt dễ đọc trên Notification Bar
        const rawNoteVi = releaseNotesVi ? String(releaseNotesVi).split('\n')[0].replace(/^[•\-\*]\s*/, '').trim() : '';
        const vBodyVi = rawNoteVi ? `${rawNoteVi} (Build ${latestBuildNumber})` : `Phiên bản mới v${latestVersion} (Build ${latestBuildNumber}) đã sẵn sàng. Nhấn để nâng cấp!`;

        const rawNoteEn = releaseNotesEn ? String(releaseNotesEn).split('\n')[0].replace(/^[•\-\*]\s*/, '').trim() : '';
        const vBodyEn = rawNoteEn ? `${rawNoteEn} (Build ${latestBuildNumber})` : `New version v${latestVersion} (Build ${latestBuildNumber}) is available. Tap to update!`;

        const payloadData = {
            category: 'app_update',
            type: 'version_update',
            version: String(latestVersion || '1.7.0'),
            buildNumber: String(latestBuildNumber || '170'),
            isForceUpdate: String(Boolean(isForceUpdate)),
            downloadUrl: String(downloadUrl || ''),
            directApkUrl: String(directApkUrl || ''),
            publishedAt: new Date().toISOString(),
        };

        console.log(`[FCM BROADCAST] 🚀 Bắt đầu phát sóng thông báo v${latestVersion} (Build ${latestBuildNumber}) tới toàn bộ thiết bị...`);

        // 1. Gửi qua FCM Topics
        // Tiếng Việt
        const pVi = getMessaging().send({
            topic: 'all_users_vi',
            notification: {
                title: vTitleVi,
                body: vBodyVi,
            },
            data: {
                ...payloadData,
                lang: 'vi',
            },
        }).then(() => console.log('[FCM TOPIC] ✅ Đã gửi tới topic all_users_vi'))
          .catch(err => console.warn('[FCM TOPIC] all_users_vi:', err.message));

        // Tiếng Anh
        const pEn = getMessaging().send({
            topic: 'all_users_en',
            notification: {
                title: vTitleEn,
                body: vBodyEn,
            },
            data: {
                ...payloadData,
                lang: 'en',
            },
        }).then(() => console.log('[FCM TOPIC] ✅ Đã gửi tới topic all_users_en'))
          .catch(err => console.warn('[FCM TOPIC] all_users_en:', err.message));

        // Topic all_users chung (Fallback tương thích ngược)
        const pAll = getMessaging().send({
            topic: 'all_users',
            notification: {
                title: vTitleVi,
                body: vBodyVi,
            },
            data: {
                ...payloadData,
                lang: 'vi',
            },
        }).then(() => console.log('[FCM TOPIC] ✅ Đã gửi tới topic all_users'))
          .catch(err => console.warn('[FCM TOPIC] all_users:', err.message));

        // 2. Gửi trực tiếp Multicast tới Tokens của các thiết bị có Session đang hoạt động
        const pTokens = (async () => {
            try {
                const usersSnap = await db.collection('users').get();
                const tokensVi = [];
                const tokensEn = [];

                for (const userDoc of usersSnap.docs) {
                    const userData = userDoc.data() || {};
                    const userLang = (userData.language || 'vi').toLowerCase();

                    const sessionsSnap = await userDoc.ref.collection('sessions').where('isActive', '==', true).get();
                    sessionsSnap.forEach(sDoc => {
                        const token = sDoc.data()?.fcmToken;
                        if (token && typeof token === 'string' && token.trim().length > 15) {
                            if (userLang === 'en') {
                                tokensEn.push(token.trim());
                            } else {
                                tokensVi.push(token.trim());
                            }
                        }
                    });
                }

                const uniqueVi = [...new Set(tokensVi)];
                const uniqueEn = [...new Set(tokensEn)];

                const directSends = [];
                if (uniqueVi.length > 0) {
                    directSends.push(
                        getMessaging().sendEachForMulticast({
                            tokens: uniqueVi,
                            notification: {
                                title: vTitleVi,
                                body: vBodyVi,
                            },
                            data: {
                                ...payloadData,
                                lang: 'vi',
                            },
                        }).then(r => console.log(`[FCM DIRECT] ✅ Đã gửi thông báo tới ${r.successCount}/${uniqueVi.length} tokens thiết bị tiếng Việt`))
                          .catch(e => console.warn('[FCM DIRECT] Lỗi gửi tokens VI:', e.message))
                    );
                }

                if (uniqueEn.length > 0) {
                    directSends.push(
                        getMessaging().sendEachForMulticast({
                            tokens: uniqueEn,
                            notification: {
                                title: vTitleEn,
                                body: vBodyEn,
                            },
                            data: {
                                ...payloadData,
                                lang: 'en',
                            },
                        }).then(r => console.log(`[FCM DIRECT] ✅ Đã gửi thông báo tới ${r.successCount}/${uniqueEn.length} tokens thiết bị tiếng Anh`))
                          .catch(e => console.warn('[FCM DIRECT] Lỗi gửi tokens EN:', e.message))
                    );
                }

                await Promise.all(directSends);
            } catch (err) {
                console.warn('[FCM DIRECT TOKENS] Lỗi thu thập sessions:', err.message);
            }
        })();

        await Promise.all([pVi, pEn, pAll, pTokens]);
        console.log(`[FCM BROADCAST] 🌟 Đã hoàn tất gửi thông báo phiên bản mới v${latestVersion} đa ngôn ngữ.`);
        return { success: true };
    } catch (err) {
        console.error('[FCM BROADCAST ERROR] ❌ Lỗi phát hành thông báo:', err);
        return { success: false, error: err.message };
    }
}

module.exports = {
    sendPushToUserTokens,
    logHistoryAndNotify,
    notifyOffline,
    processAlert,
    sendAppVersionUpdateFCM
};
