const { db, FieldValue } = require('./firebase');
const client = require('./mqtt');
const state = require('./state');
const { logHistoryAndNotify, sendPushToUserTokens } = require('./notifications');
const { handleEspPowerRestored, sendCommandWithRetry } = require('./devices');
const { saveScheduleToFirebase, deleteScheduleFromFirebase } = require('./schedules');
const { setTimer } = require('./timers');

function setupMqttHandlers() {
    client.on('connect', () => {
        console.log('✅ Background Worker NodeJS đã cắm rễ vào MQTT!');
        client.subscribe('+/+/+/#');
    });

    client.on('error', (err) => {
        console.error('❌ Lỗi kết nối MQTT:', err);
    });

    client.on('reconnect', () => {
        console.log('🔄 Đang thử kết nối lại MQTT...');
    });

    client.on('offline', () => {
        console.log('⚠️ MQTT đang offline.');
    });

    client.on('message', (topic, message, packet) => {
        const payload = message.toString();
        
        // Ignore empty payloads (used to clear retained messages) to prevent infinite loop
        if (payload === "") return;
        
        const topicParts = topic.split('/');

        // 0. BẮT SỰ KIỆN ESP32 ONLINE / OFFLINE (Có điện / Mất điện)
        if (topicParts[topicParts.length - 1] === 'esp_status') {
            const userId = topicParts[0];
            const macAddress = topicParts.length > 2 ? topicParts[1] : 'unknown';
            // Kiểm tra DB trước khi xử lý log để tránh hiện các thông báo từ tài khoản cũ (do Retained Message)
            db.collection('users').doc(userId).get().then(userDoc => {
                if (!userDoc.exists) {
                    console.log(`[CLEANUP] 🗑️ Xóa bản ghi MQTT tồn đọng của user đã xóa: ${userId}`);
                    client.publish(topic, "", { retain: true }); // Xóa retained message cũ trên Broker
                    return;
                }

                const userData = userDoc.data();
                const expectedMac = userData.macAddress;

                // Xóa tin nhắn rác nếu: MAC trên MQTT không khớp với MAC hiện tại trong DB (user đăng ký lại)
                // hoặc đó là MAC rác (unknown_mac) do lúc test/tạo tài khoản để lại
                if (macAddress !== expectedMac || macAddress === 'unknown_mac' || macAddress === 'unknown') {
                    console.log(`[CLEANUP] 🗑️ Xóa bản ghi MQTT rác (${macAddress}) không hợp lệ của user: ${userId}`);
                    client.publish(topic, "", { retain: true });
                    return;
                }

                let isRetained = packet.retain;

                if (payload === 'online') {
                    if (isRetained) {
                        console.log(`[ESP] 🔄 Bỏ qua xử lý 'online' cũ (Retained) của ${macAddress} để tránh tắt thiết bị sai lệnh.`);
                        return;
                    }
                    console.log(`[ESP] 🟢 ESP32 ${macAddress} của user ${userId} vừa online (Có điện trở lại)`);
                    handleEspPowerRestored(userId, macAddress);
                } else if (payload === 'offline') {
                    if (isRetained) {
                        console.log(`[ESP] 🔄 Ghi nhận 'offline' cũ (Retained) của ${macAddress}, cập nhật lịch sử (Không gửi Push).`);
                        db.collection('users').doc(userId).collection('history').add({
                            deviceName: 'Hub Trung Tâm (ESP32)',
                            action: 'Mất kết nối (Mất điện/Mạng) / Disconnected',
                            timestamp: FieldValue.serverTimestamp(),
                        }).catch(e => console.error(e));
                        return;
                    }
                    console.log(`[ESP] 🔴 ESP32 ${macAddress} của user ${userId} vừa offline (Mất điện / Mất mạng)`);
                    const notificationVi = {
                        title: 'Cảnh Báo Hệ Thống',
                        body: `⚠️ Hub trung tâm vừa offline. Có thể nhà bạn đang mất điện hoặc rớt mạng!`
                    };
                    const notificationEn = {
                        title: 'System Alert',
                        body: `⚠️ Central hub just went offline. Your home might have lost power or internet connection!`
                    };
                    db.collection('users').doc(userId).collection('history').add({
                        deviceName: 'Hub Trung Tâm (ESP32)',
                        action: 'Mất kết nối (Mất điện/Mạng) / Disconnected',
                        timestamp: FieldValue.serverTimestamp(),
                    }).catch(e => console.error(e));

                    sendPushToUserTokens(userId, notificationVi, notificationEn, false, false, 'important').catch(e => console.error(e));
                }
            }).catch(e => console.error(e));
            return;
        }

        // 0.5 NGHE NHIỆT ĐỘ TRONG NHÀ (TÍNH NĂNG AN TOÀN) - Topic chỉ có 3 phần (userId/macAddress/nhiet_do_trong_nha)
        if (topicParts[topicParts.length - 1] === 'nhiet_do_trong_nha') {
            const temp = parseFloat(payload);
            const userId = topicParts[0];

            if (temp >= 50.0) { // Ngưỡng an toàn (50°C có thể cảnh báo cháy)
                const now = Date.now();
                if (!state.lastTempAlert) state.lastTempAlert = {};
                
                // Tránh spam thông báo (chỉ gửi 1 lần mỗi 5 phút)
                if (!state.lastTempAlert[userId] || (now - state.lastTempAlert[userId] > 5 * 60 * 1000)) {
                    state.lastTempAlert[userId] = now;
                    console.log(`[ALERT] 🚨 Nhiệt độ nhà của user ${userId} quá cao: ${temp}°C`);

                    const notificationVi = {
                        title: '🔥 CẢNH BÁO CHÁY / NHIỆT ĐỘ CAO',
                        body: `Nhiệt độ trong nhà đang ở mức nguy hiểm (${temp}°C). Vui lòng kiểm tra ngay!`
                    };
                    const notificationEn = {
                        title: '🔥 HIGH TEMPERATURE / FIRE ALERT',
                        body: `Indoor temperature is at a dangerous level (${temp}°C). Please check immediately!`
                    };

                    sendPushToUserTokens(userId, notificationVi, notificationEn, false, false, 'important').catch(e => console.error(e));
                }
            }
            return;
        }

        if (topicParts.length < 4) return;

        const action = topicParts.pop();
        const baseTopic = topicParts.join('/');

        // 1. ESP32 LÀM XONG -> GHI LỊCH SỬ & BẮN THÔNG BÁO PUSH
        if (action === 'state') {
            if (state.pendingTasks[topic] && state.pendingTasks[topic].targetState === payload) {
                console.log(`[SUCCESS] ESP32 đã BẬT/TẮT xong: ${baseTopic} -> ${payload}`);

                const userId = topicParts[0];
                const devId = topicParts[topicParts.length - 1];
                const actionText = payload === '1' ? 'BẬT' : 'TẮT';
                const source = state.pendingTasks[topic].source || 'action';

                logHistoryAndNotify(userId, devId, actionText, source);

                clearInterval(state.pendingTasks[topic].intervalId);
                delete state.pendingTasks[topic];
            }
            return;
        }

        // 2. NGHE HẸN GIỜ BẬT
        if (action === 'timer_on') {
            const mins = parseInt(payload);
            setTimer(baseTopic, '1', mins);
        }

        // 3. NGHE HẸN GIỜ TẮT
        else if (action === 'timer_off') {
            const mins = parseInt(payload);
            setTimer(baseTopic, '0', mins);
        }

        // 4. NGHE LỊCH TRÌNH
        else if (action === 'schedule') {
            const parts = payload.split('|');
            if (parts.length === 5) {
                const scheduleId = parts[0];
                const isActive = parts[4] === '1';
                const uniqueScheduleKey = `${baseTopic.replace(/\//g, '___')}___${scheduleId}`;
                
                if (!isActive) {
                    delete state.activeSchedules[uniqueScheduleKey];
                    deleteScheduleFromFirebase(uniqueScheduleKey);
                    console.log(`[SCHEDULE] 🗑️ Đã xóa lịch trình ${scheduleId} cho ${baseTopic}`);
                } else {
                    const scheduleData = {
                        baseTopic: baseTopic,
                        timeOn: parts[1], timeOff: parts[2], days: parts[3]
                    };
                    state.activeSchedules[uniqueScheduleKey] = {
                        ...scheduleData,
                        isTriggeredOn: false, isTriggeredOff: false
                    };
                    saveScheduleToFirebase(uniqueScheduleKey, scheduleData);
                    console.log(`[SCHEDULE] 📅 Đã lưu lịch trình ${scheduleId} cho ${baseTopic} (RAM + Firebase)`);
                }
            }
        }

        // 5. NGHE TÍN HIỆU HARDWARE RESET TỪ ESP32
        else if (action === 'hardware_reset' && payload === '1') {
            const userId = topicParts[0];
            console.log(`[RESET] 🚨 Nhận tín hiệu Factory Reset cứng từ ESP32 của user ${userId}`);
            
            // Xóa MAC và devices để hủy liên kết trong App
            db.collection('users').doc(userId).update({
                macAddress: FieldValue.delete(),
                devices: [] // Trống danh sách thiết bị
            }).then(() => {
                console.log(`[RESET] 🗑️ Đã hủy liên kết thiết bị cho user ${userId}`);
                
                const notificationVi = {
                    title: 'Hủy Liên Kết Thiết Bị',
                    body: 'Hub trung tâm đã được khôi phục cài đặt gốc bằng phím cứng và đã bị hủy liên kết khỏi tài khoản của bạn.'
                };
                const notificationEn = {
                    title: 'Device Unlinked',
                    body: 'The central hub has been factory reset via hardware button and unlinked from your account.'
                };
                sendPushToUserTokens(userId, notificationVi, notificationEn, false, false, 'important').catch(e => console.error(e));
            }).catch(e => console.error("[RESET ERROR]", e));
        }
    });
}

module.exports = setupMqttHandlers;
