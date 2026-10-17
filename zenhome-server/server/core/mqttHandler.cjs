const { db, FieldValue } = require('./firebase.cjs');
const client = require('./mqtt.cjs');
const state = require('./state.cjs');
const { logHistoryAndNotify, sendPushToUserTokens } = require('./notifications.cjs');
const { handleEspPowerRestored, sendCommandWithRetry } = require('./devices.cjs');
const { saveScheduleToFirebase, deleteScheduleFromFirebase } = require('./schedules.cjs');
const { setTimer } = require('./timers.cjs');

function setupMqttHandlers() {
    client.on('connect', () => {
        if (!state.mqttStatus) state.mqttStatus = { connected: true, broker: 'HiveMQ Cloud TLS 8883', reconnectCount: 0 };
        state.mqttStatus.connected = true;
        state.mqttStatus.lastConnectedAt = new Date().toISOString();
        console.log(`🔌 Background Worker NodeJS đã kết nối thành công vào MQTT Broker!`);
        client.subscribe('+/+/+/#');
    });

    client.on('error', (err) => {
        if (state.mqttStatus) state.mqttStatus.connected = false;
        console.error(`❌ Lỗi kết nối MQTT: ${err.message || err}`);
    });

    client.on('reconnect', () => {
        if (state.mqttStatus) {
            state.mqttStatus.reconnectCount = (state.mqttStatus.reconnectCount || 0) + 1;
        }
        console.log('🔄 Đang thử kết nối lại MQTT...');
    });

    client.on('offline', () => {
        if (state.mqttStatus) state.mqttStatus.connected = false;
        console.log('⚠️ MQTT đang offline.');
    });

    client.on('close', () => {
        if (state.mqttStatus) state.mqttStatus.connected = false;
    });

    client.on('message', (topic, message, packet) => {
        if (state.mqttStatus) state.mqttStatus.lastMessageAt = new Date().toISOString();
        const payload = message.toString();
        
        // Bỏ qua gói tin rỗng (dùng để xóa retained messages)
        if (payload === "") return;
        
        const topicParts = topic.split('/');

        // 0. BẮT SỰ KIỆN ESP32 ONLINE / OFFLINE (Có điện / Mất điện)
        if (topicParts[topicParts.length - 1] === 'esp_status') {
            const userId = topicParts[0];
            const macAddress = topicParts.length > 2 ? topicParts[1] : 'unknown';
            
            db.collection('users').doc(userId).get().then(userDoc => {
                if (!userDoc.exists) {
                    console.log(`[CLEANUP] 🗑️ Đã xóa bản ghi MQTT tồn đọng của user đã xóa: ${userId}`);
                    client.publish(topic, "", { retain: true }); // Xóa retained message cũ trên Broker
                    return;
                }

                const userData = userDoc.data();
                const expectedMac = userData.macAddress;

                // Xóa tin nhắn rác nếu MAC không khớp
                if (macAddress !== expectedMac || macAddress === 'unknown_mac' || macAddress === 'unknown') {
                    console.log(`[CLEANUP] 🗑️ Đã xóa bản ghi MQTT rác (${macAddress}) không hợp lệ của user: ${userId}`);
                    client.publish(topic, "", { retain: true });
                    return;
                }

                let isRetained = packet.retain;

                if (!state.espOnlineStatus) state.espOnlineStatus = {};

                if (payload === 'online') {
                    state.espOnlineStatus[macAddress] = { isOnline: true, lastSeen: new Date().toISOString() };
                    state.espOnlineStatus[userId] = { isOnline: true, lastSeen: new Date().toISOString() };

                    if (isRetained) {
                        console.log(`[ESP] ⏭️ Bỏ qua gói 'online' cũ (Retained) của ${macAddress} để tránh kích hoạt sai.`);
                        return;
                    }

                    // Nếu ESP32 kết nối lại trong thời gian ân hạn (< 35s), hủy cảnh báo offline giả mạo
                    if (state.offlineDebounceTimers && state.offlineDebounceTimers[userId]) {
                        clearTimeout(state.offlineDebounceTimers[userId]);
                        delete state.offlineDebounceTimers[userId];
                        console.log(`[ESP] 🔄 ESP32 ${macAddress} (user ${userId}) đã phục hồi kết nối trong thời gian ân hạn (WiFi chập chờn). Đã hủy cảnh báo giả!`);
                        return;
                    }

                    console.log(`[ESP] ⚡ ESP32 ${macAddress} của user ${userId} vừa online (Có điện trở lại)`);
                    handleEspPowerRestored(userId, macAddress);
                } else if (payload === 'offline') {
                    state.espOnlineStatus[macAddress] = { isOnline: false, lastSeen: new Date().toISOString() };
                    state.espOnlineStatus[userId] = { isOnline: false, lastSeen: new Date().toISOString() };

                    if (isRetained) {
                        console.log(`[ESP] ⏭️ Bỏ qua gói 'offline' cũ (Retained) của ${macAddress}.`);
                        return;
                    }

                    // Hủy hẹn giờ cũ nếu có trước đó
                    if (!state.offlineDebounceTimers) state.offlineDebounceTimers = {};
                    if (state.offlineDebounceTimers[userId]) {
                        clearTimeout(state.offlineDebounceTimers[userId]);
                    }

                    console.log(`[ESP] ⏳ ESP32 ${macAddress} (user ${userId}) ngắt kết nối. Đặt thời gian ân hạn 35s trước khi báo mất điện/mạng...`);

                    // Bộ đếm ân hạn 35 giây: Tránh báo động giả khi router WiFi khởi động lại hoặc sóng chập chờn
                    state.offlineDebounceTimers[userId] = setTimeout(async () => {
                        delete state.offlineDebounceTimers[userId];
                        console.log(`[ESP] ⚠️ ESP32 ${macAddress} của user ${userId} offline thực sự (>35s). Kích hoạt cảnh báo hệ thống.`);

                        const notificationVi = {
                            title: '⚠️ Cảnh báo Hệ Thống',
                            body: 'Hub trung tâm vừa offline. Có thể nhà bạn đang mất điện hoặc rớt mạng!'
                        };
                        const notificationEn = {
                            title: '⚠️ System Alert',
                            body: 'Central hub just went offline. Your home might have lost power or internet connection!'
                        };

                        try {
                            await db.collection('users').doc(userId).collection('history').add({
                                deviceName: 'Hub Trung Tâm (ESP32)',
                                action: 'Mất kết nối (Mất điện/Mất mạng) / Disconnected',
                                timestamp: FieldValue.serverTimestamp(),
                            });
                            await sendPushToUserTokens(userId, notificationVi, notificationEn, false, false, 'important');
                        } catch (e) {
                            console.error(`[ESP ERROR] ❌ Lỗi ghi nhận offline hoặc gửi push cho ${userId}:`, e);
                        }
                    }, 35000);
                }
            }).catch(e => console.error(e));
            return;
        }

        // 0.5 NGHE NHIỆT ĐỘ TRONG NHÀ (TÍNH NĂNG AN TOÀN CHÁY NỔ)
        if (topicParts[topicParts.length - 1] === 'nhiet_do_trong_nha') {
            const temp = parseFloat(payload);
            const userId = topicParts[0];

            if (!isNaN(temp)) {
                if (!state.latestIndoorTemp) state.latestIndoorTemp = {};
                state.latestIndoorTemp[userId] = { temp, updatedAt: new Date().toISOString() };
                if (!state.espOnlineStatus) state.espOnlineStatus = {};
                state.espOnlineStatus[userId] = { isOnline: true, lastSeen: new Date().toISOString() };
            }

            if (temp >= 50.0) { // Ngưỡng an toàn (50°C cảnh báo cháy)
                const now = Date.now();
                if (!state.lastTempAlert) state.lastTempAlert = {};
                
                // Tránh spam thông báo (chỉ gửi 1 lần mỗi 5 phút)
                if (!state.lastTempAlert[userId] || (now - state.lastTempAlert[userId] > 5 * 60 * 1000)) {
                    state.lastTempAlert[userId] = now;
                    console.log(`[ALERT] 🔥 Nhiệt độ nhà của user ${userId} quá cao: ${temp}°C`);

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

        // 1. ESP32 LÀM XONG -> GHI LỊCH SỬ & BẮN THÔNG BÁO PUSH (Hỗ trợ cả Raw String '1'/'0' và JSON Payload)
        if (action === 'state') {
            let actualState = payload;
            let ackData = null;

            if (payload.startsWith('{') && payload.endsWith('}')) {
                try {
                    const parsed = JSON.parse(payload);
                    if (parsed.state !== undefined) {
                        actualState = String(parsed.state);
                        ackData = parsed;
                    }
                } catch (e) {}
            }

            if (state.pendingTasks[topic] && state.pendingTasks[topic].targetState === actualState) {
                console.log(`[SUCCESS] ✅ ESP32 đã BẬT/TẮT xong: ${baseTopic} -> ${actualState === '1' ? 'BẬT' : 'TẮT'}${ackData && ackData.cmdId ? ` (ACK cmdId: ${ackData.cmdId})` : ''}`);

                const userId = topicParts[0];
                const devId = topicParts[topicParts.length - 1];
                const actionText = actualState === '1' ? 'BẬT' : 'TẮT';
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
                    console.log(`[SCHEDULE] ✅ Đã xóa lịch trình ${scheduleId} cho ${baseTopic}`);
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
                console.log(`[RESET] ✅ Đã hủy liên kết thiết bị cho user ${userId}`);
                
                const notificationVi = {
                    title: 'Hủy liên kết Thiết Bị',
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
