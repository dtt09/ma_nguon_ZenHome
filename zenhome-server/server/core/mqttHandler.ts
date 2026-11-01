import { db, FieldValue } from './firebase';
import { client } from './mqtt';
import { state } from './state';
import { logHistoryAndNotify, sendPushToUserTokens } from './notifications';
import { handleEspPowerRestored, handleEspNetworkRestored, sendCommandWithRetry } from './devices';
import { saveScheduleToFirebase, deleteScheduleFromFirebase } from './schedules';
import { setTimer } from './timers';
import { recordDeviceState, recordEspOffline } from './deviceStateBackup';
import { addLog } from '../zenhomeState';

export function setupMqttHandlers() {
    client.on('connect', () => {
        if (!state.mqttStatus) state.mqttStatus = { connected: true, broker: 'HiveMQ Cloud TLS 8883', reconnectCount: 0, lastConnectedAt: null, lastMessageAt: null };
        state.mqttStatus.connected = true;
        state.mqttStatus.lastConnectedAt = new Date().toISOString();
        console.log(`🔌 Background Worker NodeJS đã kết nối thành công vào MQTT Broker!`);
        client.subscribe('+/+/+/#');
    });

    client.on('error', (err: any) => {
        if (state.mqttStatus) state.mqttStatus.connected = false;
        console.error(`❌ Lỗi kết nối MQTT: ${err?.message || err}`);
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

    client.on('message', (topic: string, message: Buffer, packet: any) => {
        if (state.mqttStatus) state.mqttStatus.lastMessageAt = new Date().toISOString();
        const payload = message.toString();
        
        // Bỏ qua gói tin rỗng (dùng để xóa retained messages)
        if (payload === "") return;
        
        const topicParts = topic.split('/');

        // 0.1 BẮT CẢNH BÁO BẪY XÂM NHẬP (INTRUSION DETECTION HONEY-TOKEN ALERT)
        if (topic.endsWith('/security/alert')) {
            const userId = topicParts[0];
            try {
                const alertData = JSON.parse(payload);
                console.warn(`[SECURITY ALERT] 🚨 PHÁT HIỆN DÒ QUÉT XÂM NHẬP! User: ${userId}, Attacker IP: ${alertData.attackerIp}, Trap: ${alertData.trap}`);
                addLog('BẢO MẬT', `🚨 Phát hiện thiết bị IP ${alertData.attackerIp} dò quét bẫy ${alertData.trap}! Đã tự động chặn 24h.`, 'warn');

                // Bắn thông báo đẩy khẩn cấp tới ứng dụng di động của gia chủ
                sendPushToUserTokens(
                    userId,
                    {
                        title: '🚨 CẢNH BÁO AN NINH GIA ĐÌNH',
                        body: `Phát hiện thiết bị lạ tại IP ${alertData.attackerIp} đang dò quét bẫy ${alertData.trap}! Đã tự động khóa IP này 24 giờ.`
                    },
                    {
                        title: '🚨 SECURITY ALERT',
                        body: `Intrusion scan detected from IP ${alertData.attackerIp} on trap ${alertData.trap}! IP blacklisted for 24 hours.`
                    }
                );
            } catch (err: any) {
                console.error('[SECURITY ALERT] ❌ Lỗi xử lý cảnh báo an ninh:', err.message);
            }
            return;
        }

        // 0. BẮT SỰ KIỆN ESP32 ONLINE / OFFLINE (Có điện / Mất điện)
        if (topicParts[topicParts.length - 1] === 'esp_status') {
            const userId = topicParts[0];
            const macAddress = topicParts.length > 2 ? topicParts[1] : 'unknown';
            
            db.collection('users').doc(userId).get().then(userDoc => {
                if (!userDoc.exists) {
                    console.log(`[CLEANUP] 🗑️ Đã xóa bản ghi MQTT tồn đọng của user đã xóa: ${userId}`);
                    client.publish(topic, "", { retain: true });
                    return;
                }

                const userData = userDoc.data() || {};
                const expectedMac = (userData.macAddress || '').trim();
                const cleanExpectedMac = expectedMac.replace(/[:\-]/g, '').toUpperCase();
                const cleanMac = macAddress.replace(/[:\-]/g, '').toUpperCase();
                const isExpectedUnlinked = (!cleanExpectedMac || cleanExpectedMac === 'UNKNOWN' || cleanExpectedMac === 'UNKNOWN_MAC');

                // Nếu tài khoản đang ở trạng thái CHƯA LIÊN KẾT (chưa có Hub hoặc đang trong quá trình setup)
                // Tuyệt đối không gửi lệnh reset phá hỏng quá trình ghép nối của người dùng!
                if (isExpectedUnlinked) {
                    console.log(`[BACKEND] ℹ️ Tài khoản '${userId}' đang ở trạng thái CHƯA LIÊN KẾT Hub. Bỏ qua kiểm tra đồng bộ.`);
                    return;
                }

                // Hỗ trợ kiểm tra danh sách Hub (Đa Hub / Multi-Hub): Không tự tiện gửi lệnh reset hủy hoại Flash
                const userMacList = Array.isArray(userData.macAddresses)
                    ? userData.macAddresses.map((m: string) => m.replace(/[:\-]/g, '').toUpperCase())
                    : [cleanExpectedMac];

                if (!userMacList.includes(cleanMac) && cleanExpectedMac !== cleanMac) {
                    console.warn(`[DESYNC-ALERT] ⚠️ Phát hiện ESP32 (${macAddress}) gửi trạng thái nhưng không khớp Hub chính [${expectedMac}] của user '${userId}'!`);
                    console.log(`[DESYNC-ALERT] ℹ️ Bỏ qua xử lý tự động cho Hub lạ (Bảo vệ phần cứng, không gửi lệnh reset tùy tiện).`);
                    return;
                }

                let isRetained = packet.retain;

                if (!state.espOnlineStatus) state.espOnlineStatus = {};

                if (payload === 'online' || payload === 'online_power_restored' || payload === 'online_network_restored' || payload.startsWith('online')) {
                    state.espOnlineStatus[macAddress] = { isOnline: true, lastSeen: new Date().toISOString() };
                    state.espOnlineStatus[userId] = { isOnline: true, lastSeen: new Date().toISOString() };

                    if (isRetained) {
                        console.log(`[ESP] ⏭️ Bỏ qua gói '${payload}' cũ (Retained) của ${macAddress} để tránh kích hoạt sai.`);
                        return;
                    }

                    if (state.offlineDebounceTimers && state.offlineDebounceTimers[userId]) {
                        clearTimeout(state.offlineDebounceTimers[userId]);
                        delete state.offlineDebounceTimers[userId];
                        if (payload !== 'online_power_restored') {
                            console.log(`[ESP] 🔄 ESP32 ${macAddress} (user ${userId}) đã phục hồi kết nối trong thời gian ân hạn (WiFi chập chờn). Đã hủy cảnh báo giả!`);
                            return;
                        }
                        console.log(`[ESP] ⚡ ESP32 ${macAddress} (user ${userId}) kết nối lại với tín hiệu CÓ ĐIỆN LẠI (online_power_restored). Tiếp tục quy trình an toàn điện!`);
                    }

                    if (payload === 'online_power_restored') {
                        // 1. TRƯỜNG HỢP MẤT ĐIỆN -> CÓ ĐIỆN LẠI: TẮT TOÀN BỘ THIẾT BỊ ĐỂ AN TOÀN ĐIỆN
                        console.log(`[ESP] ⚡ ESP32 ${macAddress} (user ${userId}) CÓ ĐIỆN LẠI SAU KHI MẤT ĐIỆN -> TẮT TOÀN BỘ THIẾT BỊ!`);
                        handleEspPowerRestored(userId, macAddress);
                    } else {
                        // 2. TRƯỜNG HỢP MẤT MẠNG -> CÓ MẠNG LẠI: CHỈ ĐỒNG BỘ TRẠNG THÁI LẦN CUỐI
                        console.log(`[ESP] 🌐 ESP32 ${macAddress} (user ${userId}) CÓ MẠNG LẠI SAU KHI MẤT MẠNG -> ĐỒNG BỘ TRẠNG THÁI LẦN CUỐI!`);
                        handleEspNetworkRestored(userId, macAddress);
                    }
                } else if (payload === 'offline') {
                    state.espOnlineStatus[macAddress] = { isOnline: false, lastSeen: new Date().toISOString() };
                    state.espOnlineStatus[userId] = { isOnline: false, lastSeen: new Date().toISOString() };

                    if (isRetained) {
                        console.log(`[ESP] ⏭️ Bỏ qua gói 'offline' cũ (Retained) của ${macAddress}.`);
                        return;
                    }

                    if (!state.offlineDebounceTimers) state.offlineDebounceTimers = {};
                    if (state.offlineDebounceTimers[userId]) {
                        clearTimeout(state.offlineDebounceTimers[userId]);
                    }

                    console.log(`[ESP] ⏳ ESP32 ${macAddress} (user ${userId}) ngắt kết nối. Đặt thời gian ân hạn 35s trước khi báo mất điện/mạng...`);

                    state.offlineDebounceTimers[userId] = setTimeout(async () => {
                        delete state.offlineDebounceTimers[userId];
                        console.log(`[ESP] ⚠️ ESP32 ${macAddress} của user ${userId} offline thực sự (>35s). Kích hoạt cảnh báo hệ thống.`);
                        recordEspOffline(userId, macAddress);

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

            if (temp >= 50.0) {
                const now = Date.now();
                if (!state.lastTempAlert) state.lastTempAlert = {};
                
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

        // 0.8 BẮT SỰ KIỆN HỆ THỐNG TỪ ESP32 (MẤT ĐIỆN / MẤT MẠNG)
        if (topicParts[topicParts.length - 1] === 'event' && topicParts[topicParts.length - 2] === 'system') {
            const userId = topicParts[0];
            const macAddress = topicParts.length > 3 ? topicParts[1] : 'unknown';
            try {
                const eventData = JSON.parse(payload);
                if (eventData.event === 'power_restored') {
                    console.log(`[EVENT] ⚡ Nhận sự kiện CÓ ĐIỆN LẠI từ ESP32 ${macAddress} -> Tắt toàn bộ thiết bị!`);
                    handleEspPowerRestored(userId, macAddress);
                } else if (eventData.event === 'network_restored') {
                    console.log(`[EVENT] 🌐 Nhận sự kiện CÓ MẠNG LẠI từ ESP32 ${macAddress} -> Đồng bộ trạng thái lần cuối!`);
                    handleEspNetworkRestored(userId, macAddress);
                }
            } catch (e) {}
            return;
        }

        // 0.85 BẮT HEARTBEAT TỪ ESP32 ĐỒNG BỘ PHIÊN BẢN FIRMWARE VÀ TRẠNG THÁI SỐNG
        if (topic.endsWith('/heartbeat')) {
            const userId = topicParts[0];
            try {
                const hb = JSON.parse(payload);
                if (hb.version && db) {
                    db.collection('users').doc(userId).set({
                        firmwareVersion: hb.version,
                        firmwareBuild: hb.build || 0,
                        lastHeartbeat: new Date().toISOString(),
                    }, { merge: true }).catch(() => {});
                }
            } catch (_) {}
            return;
        }

        // 0.9 BẮT TIẾN TRÌNH & KẾT QUẢ OTA TỪ ESP32
        if (topic.endsWith('/system/ota_progress')) {
            const macAddress = topicParts.length > 2 ? topicParts[1] : 'ESP32';
            try {
                const progData = JSON.parse(payload);
                if (progData.progress !== undefined) {
                    addLog('[OTA]', `⏳ Hub [${macAddress}] đang nạp Firmware: ${progData.progress}%`, 'info');
                }
            } catch (_) {}
            return;
        }

        if (topic.endsWith('/system/ota_result')) {
            const userId = topicParts[0];
            const macAddress = topicParts.length > 2 ? topicParts[1] : 'ESP32';
            try {
                const resultData = JSON.parse(payload);
                if (resultData.status === 'success') {
                    addLog('[OTA]', `🎉 Hub [${macAddress}] nâng cấp Firmware OTA thành công 100%! Đang khởi động lại...`, 'info');
                    if (db) {
                        db.collection('users').doc(userId).set({
                            firmwareVersion: resultData.version || '2.5.7',
                            firmwareBuild: resultData.build || 201,
                            lastFirmwareUpdate: new Date().toISOString(),
                        }, { merge: true }).catch(() => {});
                    }
                    sendPushToUserTokens(
                        userId,
                        {
                            title: '🎉 Nâng Cấp Firmware Thành Công',
                            body: `Hub trung tâm [${macAddress}] đã hoàn tất nạp firmware mới và đang khởi động lại.`
                        },
                        {
                            title: '🎉 Firmware Update Successful',
                            body: `Central Hub [${macAddress}] successfully updated firmware and is restarting.`
                        }
                    ).catch(() => {});
                } else {
                    addLog('[OTA]', `❌ Hub [${macAddress}] nâng cấp OTA thất bại: ${resultData.message || 'Lỗi không xác định'}`, 'warn');
                }
            } catch (_) {}
            return;
        }

        if (topicParts.length < 4) return;

        const action = topicParts.pop();
        const baseTopic = topicParts.join('/');

        // 1. ESP32 LÀM XONG -> GHI LỊCH SỬ & BẮN THÔNG BÁO PUSH
        if (action === 'state') {
            let actualState = payload;
            let ackData: any = null;

            if (payload.startsWith('{') && payload.endsWith('}')) {
                try {
                    const parsed = JSON.parse(payload);
                    if (parsed.state !== undefined) {
                        actualState = String(parsed.state);
                        ackData = parsed;
                    }
                } catch (e) {}
            }

            // Luôn ghi nhận trạng thái thực tế vào Server Backup Engine
            recordDeviceState(baseTopic, actualState === '1' ? '1' : '0', 'mqtt_state');

            // Chuẩn hóa khóa tra cứu pendingTasks (hỗ trợ cả topic có dấu hai chấm và không dấu)
            const cleanTopicKey = topic.replace(/[:\-]/g, '');
            let matchedPendingKey: string | null = null;
            if (state.pendingTasks[topic]) {
                matchedPendingKey = topic;
            } else {
                matchedPendingKey = Object.keys(state.pendingTasks).find(
                    k => k.replace(/[:\-]/g, '') === cleanTopicKey
                ) || null;
            }

            if (matchedPendingKey && state.pendingTasks[matchedPendingKey].targetState === actualState) {
                console.log(`[SUCCESS] ✅ ESP32 đã BẬT/TẮT xong: ${baseTopic} -> ${actualState === '1' ? 'BẬT' : 'TẮT'}${ackData && ackData.cmdId ? ` (ACK cmdId: ${ackData.cmdId})` : ''}`);

                const userId = topicParts[0];
                const devId = topicParts[topicParts.length - 1];
                const actionText = actualState === '1' ? 'BẬT' : 'TẮT';
                const source = state.pendingTasks[matchedPendingKey].source || 'action';

                // Chống bão thông báo (Push Storm) khi phục hồi mạng hoặc an toàn nguồn điện:
                // Gia chủ đã nhận 1 thông báo tổng quan của hệ thống, không spam push cho từng relay riêng rẽ.
                const isSilentSync = source === 'network_sync_restore' || source === 'power_safety' || source === 'safety_default';
                if (!isSilentSync) {
                    logHistoryAndNotify(userId, devId, actionText, source);
                } else {
                    console.log(`[SILENT SYNC] 🔕 Không bắn push notification riêng lẻ cho ${devId} (Nguồn: ${source})`);
                }

                if (state.pendingTasks[matchedPendingKey]?.intervalId) {
                    clearInterval(state.pendingTasks[matchedPendingKey].intervalId);
                }
                delete state.pendingTasks[matchedPendingKey];
            }
            return;
        }

        // 1.5 BÁO CÁO ĐỒNG BỘ TRẠNG THÁI TỪ ESP32 KHI CÓ MẠNG LẠI (BULK SYNC REPORT)
        if (action === 'report' && topicParts[topicParts.length - 1] === 'sync') {
            try {
                const reportData = JSON.parse(payload);
                if (Array.isArray(reportData.relays)) {
                    // Cắt bỏ phần tử 'sync' để lấy base topic chuẩn của ESP32: userId/macAddress
                    const actualPrefix = topicParts.slice(0, -1).join('/');
                    reportData.relays.forEach((item: any) => {
                        if (item.id && item.state !== undefined) {
                            const devTopic = `${actualPrefix}/${item.room || 'default'}/${item.id}`;
                            recordDeviceState(devTopic, item.state === '1' ? '1' : '0', 'esp_sync_report');
                        }
                    });
                    console.log(`[BACKUP SYNC] 📥 Đã lưu báo cáo đồng bộ trạng thái thực tế từ ESP32 (${reportData.relays.length} thiết bị).`);
                }
            } catch (e) {}
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

        // 5. NGHE TÍN HIỆU HARDWARE RESET / UNLINK TỪ ESP32 (Kiểm tra MAC xác thực)
        else if ((action === 'hardware_reset' || action === 'reset') && payload === '1') {
            const userId = topicParts[0];
            const incomingMac = topicParts.length > 1 ? topicParts[1] : 'unknown';
            console.log(`[RESET] 🚨 Nhận tín hiệu Reset/Unlink từ ESP32 (MAC: ${incomingMac}) của user ${userId}`);
            
            db.collection('users').doc(userId).get().then(userDoc => {
                if (!userDoc.exists) {
                    console.warn(`[RESET] ⚠️ Bỏ qua: User ${userId} không tồn tại.`);
                    return;
                }
                const userData = userDoc.data() || {};
                const expectedMac = userData.macAddress || '';
                const cleanIncoming = incomingMac.replace(/[:\-]/g, '').toUpperCase();
                const cleanExpected = expectedMac.replace(/[:\-]/g, '').toUpperCase();

                if (!expectedMac || (cleanIncoming !== cleanExpected && incomingMac !== expectedMac) || incomingMac === 'unknown') {
                    console.warn(`[RESET BLOCKED] ⛔ Từ chối reset: MAC gửi lên (${incomingMac}) không khớp với MAC đã đăng ký (${expectedMac}) của user ${userId}`);
                    return;
                }

                userDoc.ref.update({
                    macAddress: FieldValue.delete(),
                    devices: []
                }).then(() => {
                    console.log(`[RESET] ✅ Đã xác thực MAC hợp lệ và hủy liên kết thiết bị cho user ${userId}`);
                    
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
            }).catch(e => console.error("[RESET FETCH ERROR]", e));
        }
    });
}

export default setupMqttHandlers;
