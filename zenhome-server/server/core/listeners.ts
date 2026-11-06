import { db, getAuth, FieldValue } from './firebase';
import { client } from './mqtt';
import { state } from './state';
import { processAlert } from './notifications';
import { deleteScheduleFromFirebase } from './schedules';

const lastSyncedMembersHash: Record<string, string> = {};

function syncUserMembersToEsp32(userId: string, userData: any) {
    if (!userData) return;
    const isOwner = (!userData.role || userData.role === 'owner');
    if (!isOwner) return;

    const mac = userData.macAddress;
    if (!mac || mac === 'unknown_mac' || mac === 'unknown') return;

    const cleanMac = mac.replace(/[:-]/g, '').toUpperCase();
    const membersList: Array<{ user: string; role: string; disabled: boolean; allowed: string[] }> = [];

    if (Array.isArray(userData.sharedWith)) {
        userData.sharedWith.forEach((memberUser: string) => {
            const role = (userData.memberRoles && userData.memberRoles[memberUser]) || 'member';
            const disabled = Array.isArray(userData.disabledMembers) && userData.disabledMembers.includes(memberUser);
            const allowed = (userData.memberDevicePermissions && userData.memberDevicePermissions[memberUser]) || [];
            membersList.push({
                user: memberUser,
                role,
                disabled,
                allowed
            });
        });
    }

    // Fingerprint phân quyền thành viên để chống phát sóng MQTT liên tục gây hao mòn Flash ESP32
    const membersFingerprint = JSON.stringify({
        owner: userId,
        members: membersList,
        disabled: Array.isArray(userData.disabledMembers) ? userData.disabledMembers : []
    });

    if (lastSyncedMembersHash[userId] === membersFingerprint) {
        return;
    }
    lastSyncedMembersHash[userId] = membersFingerprint;

    const payload = JSON.stringify({
        owner: userId,
        members: membersList,
        disabled: Array.isArray(userData.disabledMembers) ? userData.disabledMembers : [],
        timestamp: Math.floor(Date.now() / 1000)
    });

    const membersTopic = `${userId}/${mac}/system/members`;
    client.publish(membersTopic, payload, { qos: 1, retain: true });
    if (mac !== cleanMac) {
        client.publish(`${userId}/${cleanMac}/system/members`, payload, { qos: 1, retain: true });
    }
    console.log(`[BACKEND-RBAC] 🔄 Đã đồng bộ phân quyền thành viên tới ESP32 (${membersTopic}): ${membersList.length} thành viên`);
}

export function startListeningToAlerts() {
    console.log(`[FIREBASE] 🛡️ Đang khởi chạy trình lắng nghe Cảnh báo bảo mật tập trung (collectionGroup)...`);

    // 1. Luồng tập trung duy nhất cho toàn bộ alerts bằng collectionGroup (Tối ưu kết nối & chi phí)
    const alertsStartTime = new Date();
    db.collectionGroup('alerts')
        .where('timestamp', '>', alertsStartTime)
        .onSnapshot(alertsSnap => {
            alertsSnap.docChanges().forEach(alertChange => {
                if (alertChange.type === 'added') {
                    const userEmail = alertChange.doc.ref.parent.parent?.id;
                    if (userEmail) {
                        processAlert(alertChange.doc.data(), userEmail, userEmail);
                    }
                }
            });
        }, err => {
            console.error(`[FIREBASE ERROR] ❌ Lỗi lắng nghe collectionGroup alerts:`, err);
        });

    // 2. Lắng nghe thay đổi tài khoản users
    db.collection('users').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(async change => {
            const userEmail = change.doc.id;
            const userId = userEmail;

            if (change.type === 'added' || change.type === 'modified') {
                syncUserMembersToEsp32(userId, change.doc.data());
            }
            else if (change.type === 'removed') {
                delete lastSyncedMembersHash[userId];

                // Xử lý khi user xóa tài khoản
                const userData = change.doc.data();
                const isOwner = userData ? (!userData.role || userData.role === 'owner') : true;

                if (isOwner) {
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

                    // Dọn dẹp sạch cache trạng thái thiết bị trong Server Backup (Chống Ghost Data)
                    try {
                        const { removeUserDeviceBackup } = await import('./deviceStateBackup');
                        removeUserDeviceBackup(userId);
                    } catch (e) {}

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
                        userData.sharedWith.forEach(async (memberUsername: string) => {
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

export function startListeningToDeleteRequests() {
    console.log(`[FIREBASE] 🗑️ Đang khởi chạy trình lắng nghe lệnh xóa tài khoản...`);
    db.collection('delete_requests').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(async change => {
            if (change.type === 'added') {
                const data = change.doc.data();
                const username = change.doc.id;
                const uid = data.uid;
                
                console.log(`[BACKEND] 🗑️ Nhận lệnh xóa tài khoản cho user: ${username} (UID: ${uid})`);
                
                try {
                    // 1. Kiểm tra xác thực quyền sở hữu tài khoản (Chống lỗ hổng IDOR - ZH-03)
                    const userDoc = await db.collection('users').doc(username).get();
                    if (!userDoc.exists) {
                        console.warn(`[BACKEND WARNING] ⚠️ Bỏ qua lệnh xóa: Không tìm thấy user '${username}'.`);
                        await change.doc.ref.delete();
                        return;
                    }

                    const userData = userDoc.data() || {};
                    // BẢO VỆ CHỐNG IDOR: UID của người gửi yêu cầu bắt buộc phải trùng khớp với UID chủ sở hữu tài khoản
                    if (!userData.uid || !uid || userData.uid !== uid) {
                        console.error(`[SECURITY ALERT] 🚨 PHÁT HIỆN TẤN CÔNG IDOR hoặc YÊU CẦU KHÔNG HỢP LỆ! UID [${uid}] cố tình xóa tài khoản [${username}] thuộc về UID [${userData.uid}]!`);
                        await change.doc.ref.delete();
                        return;
                    }

                    const isOwner = (!userData.role || userData.role === 'owner');
                    const macAddress = userData.macAddress;
                    
                    if (isOwner && macAddress && macAddress !== 'unknown_mac' && macAddress !== 'unknown') {
                        const resetTopic = `${username}/${macAddress}/system/reset`;
                        const resetPayload = JSON.stringify({
                            action: 'factory_reset',
                            admin_pass: userData.adminPass || 'admin',
                            server_authorized: true,
                            timestamp: Date.now()
                        });
                        client.publish(resetTopic, resetPayload, { qos: 1, retain: true });
                        console.log(`[BACKEND] ✅ Đã gửi lệnh Factory Reset bảo mật tới ESP32 do Owner xóa tài khoản: ${resetTopic}`);
                    }

                    // 2. Xóa Firebase Auth User
                    if (uid && uid !== 'NO_UID') {
                        try {
                            await getAuth().deleteUser(uid);
                            console.log(`[BACKEND] ✅ Đã xóa tài khoản Auth của ${username}`);
                        } catch (e: any) {
                            console.error(`[BACKEND ERROR] ❌ Lỗi xóa Auth của ${username}:`, e.message || e);
                        }
                    }
                    
                    // 3. Xóa Firestore User Document
                    await db.collection('users').doc(username).delete();
                    console.log(`[BACKEND] ✅ Đã xóa document chính của ${username}`);
                    
                    try {
                        const { removeUserDeviceBackup } = await import('./deviceStateBackup');
                        removeUserDeviceBackup(username);
                    } catch (_) {}
                    
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

export function startListeningToUnlinkRequests() {
    console.log(`[FIREBASE] 🔓 Đang khởi chạy trình lắng nghe Lệnh hủy liên kết (Free Email/Phone)...`);
    db.collection('unlink_requests').onSnapshot(snapshot => {
        snapshot.docChanges().forEach(async change => {
            if (change.type === 'added') {
                const data = change.doc.data();
                const docId = change.doc.id;
                const uid = data.uid;
                const fallbackEmail = data.fallbackEmail;
                
                console.log(`[BACKEND] 🔓 Nhận lệnh giải phóng định danh cho UID: ${uid}`);
                
                try {
                    // Xác thực an toàn: uid trong payload bắt buộc phải khớp với docId hoặc tài khoản hợp lệ
                    if (!uid || typeof uid !== 'string' || (docId !== uid && !docId.startsWith(uid))) {
                        console.error(`[SECURITY ALERT] 🚨 Bỏ qua unlink_request không hợp lệ: docId [${docId}] không khớp với UID [${uid}]!`);
                        await change.doc.ref.delete();
                        return;
                    }
                    if (fallbackEmail && typeof fallbackEmail === 'string' && fallbackEmail.includes('@')) {
                        await getAuth().updateUser(uid, { email: fallbackEmail });
                        console.log(`[BACKEND] ✅ Đã cập nhật email thành ${fallbackEmail} để giải phóng email thật cho ${uid}`);
                    }
                    
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
