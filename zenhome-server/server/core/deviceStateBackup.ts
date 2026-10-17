import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { db, FieldValue } from './firebase';
import { sendCommandWithRetry } from './devices';
import { addLog } from '../zenhomeState';
import { sendPushToUserTokens } from './notifications';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const BACKUP_FILE = path.resolve(__dirname, '../data/device_states_backup.json');

export interface DeviceStateRecord {
    userId: string;
    macAddress: string;
    room: string;
    deviceId: string;
    baseTopic: string;
    state: '0' | '1';
    source: string;
    updatedAt: string;
    syncStatus: 'synced' | 'pending_sync';
}

export interface UserDeviceBackup {
    userId: string;
    macAddress: string;
    lastOnlineAt?: string;
    lastOfflineAt?: string;
    lastSyncAt?: string;
    devices: Record<string, DeviceStateRecord>; // key: deviceId
}

// Bộ nhớ đệm RAM của Mini Server Backup
const backupCache: Record<string, UserDeviceBackup> = {}; // key: userId
let isInitialized = false;

/**
 * Khởi tạo hệ thống Backup: Đọc trạng thái cuối cùng từ đĩa cứng (Disk Persistence)
 */
export function initDeviceStateBackup(): void {
    if (isInitialized) return;
    try {
        const dataDir = path.dirname(BACKUP_FILE);
        if (!fs.existsSync(dataDir)) {
            fs.mkdirSync(dataDir, { recursive: true });
        }

        if (fs.existsSync(BACKUP_FILE)) {
            const raw = fs.readFileSync(BACKUP_FILE, 'utf-8');
            const data = JSON.parse(raw);
            Object.assign(backupCache, data);
            addLog('[BACKUP]', `💾 Đã nạp thành công trạng thái thiết bị từ file backup cục bộ (${Object.keys(backupCache).length} nhà)`, 'info');
        } else {
            fs.writeFileSync(BACKUP_FILE, JSON.stringify({}, null, 2), 'utf-8');
        }
        isInitialized = true;
    } catch (err: any) {
        console.error('[BACKUP] ❌ Lỗi khởi tạo cache backup thiết bị:', err.message);
    }
}

/**
 * Lưu bộ nhớ đệm xuống đĩa cứng (chống mất dữ liệu khi server restart / mất điện)
 */
function persistBackupToDisk(): void {
    try {
        fs.writeFileSync(BACKUP_FILE, JSON.stringify(backupCache, null, 2), 'utf-8');
    } catch (err: any) {
        console.error('[BACKUP] ❌ Lỗi ghi file backup trạng thái thiết bị:', err.message);
    }
}

/**
 * Ghi nhận trạng thái Bật/Tắt cuối cùng của thiết bị vào Server Backup
 */
export async function recordDeviceState(
    baseTopic: string,
    state: '0' | '1',
    source: string = 'mqtt_state'
): Promise<void> {
    initDeviceStateBackup();

    const parts = baseTopic.split('/');
    if (parts.length < 3) return;

    // Cấu trúc topic phổ biến: userId/macAddress/room/devId hoặc userId/room/devId
    let userId = parts[0];
    let macAddress = 'unknown';
    let room = 'default';
    let deviceId = parts[parts.length - 1];

    if (parts.length >= 4) {
        macAddress = parts[1];
        room = parts[2];
        deviceId = parts[3];
    } else {
        room = parts[1];
        deviceId = parts[2];
    }

    if (!backupCache[userId]) {
        backupCache[userId] = {
            userId,
            macAddress,
            devices: {}
        };
    }

    if (macAddress !== 'unknown' && macAddress.length > 0) {
        backupCache[userId].macAddress = macAddress;
    }

    const now = new Date().toISOString();
    const existing = backupCache[userId].devices[deviceId];

    // Cập nhật bản ghi trạng thái
    backupCache[userId].devices[deviceId] = {
        userId,
        macAddress: backupCache[userId].macAddress,
        room,
        deviceId,
        baseTopic,
        state,
        source,
        updatedAt: now,
        syncStatus: 'synced'
    };

    // Chỉ log khi có sự thay đổi trạng thái thực tế
    if (!existing || existing.state !== state) {
        console.log(`[BACKUP] 💾 Đã lưu trạng thái cuối: ${deviceId} (${room}) -> ${state === '1' ? 'BẬT' : 'TẮT'} (Nguồn: ${source})`);
        addLog('[BACKUP]', `Đã lưu trạng thái cuối của [${deviceId}]: ${state === '1' ? 'BẬT' : 'TẮT'} (Gia chủ: ${userId})`, 'info');
    }

    persistBackupToDisk();

    // Đồng bộ lên Firestore để App và Web theo dõi tức thì
    try {
        await db.collection('users').doc(userId).collection('device_states').doc('latest').set({
            [deviceId]: {
                state,
                room,
                updatedAt: FieldValue.serverTimestamp(),
                source
            }
        }, { merge: true });
    } catch (e: any) {
        // Không block luồng chính nếu Firestore chậm
    }
}

/**
 * Ghi nhận ESP32 chuyển sang trạng thái Offline
 */
export function recordEspOffline(userId: string, macAddress: string): void {
    initDeviceStateBackup();
    if (!backupCache[userId]) {
        backupCache[userId] = { userId, macAddress, devices: {} };
    }
    backupCache[userId].lastOfflineAt = new Date().toISOString();

    // Đánh dấu toàn bộ thiết bị đang cần đồng bộ khi mạng phục hồi
    Object.keys(backupCache[userId].devices).forEach(devId => {
        backupCache[userId].devices[devId].syncStatus = 'pending_sync';
    });
    persistBackupToDisk();
    console.log(`[BACKUP] ⚠️ Đã ghi nhận ESP32 ${macAddress} (user ${userId}) OFFLINE. Sẵn sàng đồng bộ khi có mạng lại.`);
}

/**
 * TRƯỜNG HỢP 1: MẤT ĐIỆN -> KHI CÓ ĐIỆN LẠI PHẢI TẮT TOÀN BỘ THIẾT BỊ ĐỂ AN TOÀN ĐIỆN
 */
export async function handlePowerRestored(
    userId: string,
    macAddress: string,
    fallbackDevices: any[] = [],
    isEn: boolean = false
): Promise<{ shutCount: number }> {
    initDeviceStateBackup();

    console.log(`[POWER RESTORED] ⚡ PHÁT HIỆN CÓ ĐIỆN LẠI: TẮT TOÀN BỘ THIẾT BỊ CỦA GIA CHỦ ${userId} (ESP: ${macAddress}) ĐỂ AN TOÀN!`);
    addLog('[POWER]', `⚡ Phát hiện có điện lại: Tiến hành TẮT TOÀN BỘ thiết bị của gia chủ ${userId} để chống sốc điện/chập cháy!`, 'warn');

    let shutCount = 0;
    const userBackup = backupCache[userId];

    // 1. Cập nhật trong cache backup và gửi lệnh 0 (TẮT) cho tất cả thiết bị đã lưu
    if (userBackup && Object.keys(userBackup.devices).length > 0) {
        for (const [devId, record] of Object.entries(userBackup.devices)) {
            record.state = '0';
            record.source = 'power_restored_safety';
            record.updatedAt = new Date().toISOString();
            record.syncStatus = 'synced';

            const targetTopic = record.baseTopic.includes(macAddress)
                ? record.baseTopic
                : `${userId}/${macAddress}/${record.room}/${devId}`;

            console.log(`[POWER SAFETY] 🔌 TẮT AN TOÀN ${devId} -> ${targetTopic}/cmd: 0`);
            sendCommandWithRetry(targetTopic, '0', 'power_safety');
            shutCount++;
        }
        userBackup.lastOnlineAt = new Date().toISOString();
        persistBackupToDisk();
    } else if (fallbackDevices && fallbackDevices.length > 0) {
        // Nếu chưa có cache, duyệt qua danh sách devices cấu hình
        for (const dev of fallbackDevices) {
            if (dev.room && dev.id) {
                const baseTopic = `${userId}/${macAddress}/${dev.room}/${dev.id}`;
                sendCommandWithRetry(baseTopic, '0', 'power_safety');
                shutCount++;
            }
        }
    }

    // 2. Ghi đè trạng thái toàn bộ là 0 trên Firestore
    try {
        const resetStates: Record<string, any> = {};
        if (userBackup) {
            Object.keys(userBackup.devices).forEach(devId => {
                resetStates[devId] = {
                    state: '0',
                    room: userBackup.devices[devId].room,
                    updatedAt: FieldValue.serverTimestamp(),
                    source: 'power_restored_safety'
                };
            });
            await db.collection('users').doc(userId).collection('device_states').doc('latest').set(resetStates, { merge: true });
        }

        // Ghi lịch sử Firestore
        await db.collection('users').doc(userId).collection('history').add({
            deviceName: isEn ? 'Power Supply System' : 'Hệ Thống Nguồn Điện',
            action: isEn
                ? 'Power restored after outage. All devices auto-turned off for electrical safety!'
                : 'Có điện trở lại sau khi mất điện. Đã tự động TẮT TOÀN BỘ thiết bị để đảm bảo an toàn điện!',
            timestamp: FieldValue.serverTimestamp(),
        });

        // Bắn Push Notification cho gia chủ
        const notiVi = {
            title: '⚡ Thông Báo Nguồn Điện',
            body: 'Hệ thống vừa có điện trở lại. Toàn bộ thiết bị đã được tự động tắt để đảm bảo an toàn!'
        };
        const notiEn = {
            title: '⚡ Power Supply Notification',
            body: 'Power has been restored. All devices were automatically turned off for safety!'
        };
        await sendPushToUserTokens(userId, notiVi, notiEn, isEn, false, 'important');
    } catch (e: any) {
        console.warn('[POWER RESTORED] Không thể cập nhật lịch sử Firestore:', e.message);
    }

    addLog('[POWER]', `✅ Đã tắt an toàn thành công ${shutCount} thiết bị cho gia chủ ${userId}!`, 'success');
    return { shutCount };
}

/**
 * TRƯỜNG HỢP 2: MẤT MẠNG -> KHI CÓ MẠNG LẠI: CHỈ ĐỒNG BỘ TRẠNG THÁI LẦN CUỐI
 */
export async function handleNetworkRestored(
    userId: string,
    macAddress: string,
    fallbackDevices: any[] = [],
    isEn: boolean = false
): Promise<{ syncedCount: number; states: Record<string, string> }> {
    initDeviceStateBackup();

    console.log(`[NETWORK RESTORED] 🌐 PHÁT HIỆN CÓ MẠNG LẠI: ĐỒNG BỘ TRẠNG THÁI LẦN CUỐI CHO ESP32 ${macAddress} (User: ${userId})...`);
    addLog('[NETWORK SYNC]', `🌐 Có mạng lại: Bắt đầu đồng bộ trạng thái thiết bị lần cuối cho ESP32 ${macAddress}...`, 'info');

    const userBackup = backupCache[userId];
    const syncedStates: Record<string, string> = {};
    let syncedCount = 0;

    // Chỉ đồng bộ trạng thái lần cuối cho các thiết bị
    if (userBackup && Object.keys(userBackup.devices).length > 0) {
        for (const [devId, record] of Object.entries(userBackup.devices)) {
            const targetState = record.state; // Giữ nguyên '0' hoặc '1' lần cuối
            syncedStates[devId] = targetState;

            const targetTopic = record.baseTopic.includes(macAddress)
                ? record.baseTopic
                : `${userId}/${macAddress}/${record.room}/${devId}`;

            console.log(`[NETWORK SYNC] 🔄 Đồng bộ ${devId}: ${targetState === '1' ? 'BẬT' : 'TẮT'} -> Gửi tới: ${targetTopic}/cmd`);
            sendCommandWithRetry(targetTopic, targetState, 'network_sync_restore');
            record.syncStatus = 'synced';
            syncedCount++;
        }
        userBackup.lastOnlineAt = new Date().toISOString();
        userBackup.lastSyncAt = new Date().toISOString();
        persistBackupToDisk();
    } else if (fallbackDevices && fallbackDevices.length > 0) {
        for (const dev of fallbackDevices) {
            if (dev.room && dev.id) {
                const baseTopic = `${userId}/${macAddress}/${dev.room}/${dev.id}`;
                sendCommandWithRetry(baseTopic, '0', 'safety_default');
                syncedStates[dev.id] = '0';
                syncedCount++;
            }
        }
    }

    // Ghi nhận lịch sử phục hồi mạng
    try {
        await db.collection('users').doc(userId).collection('history').add({
            deviceName: isEn ? 'Network Connectivity' : 'Kết Nối Mạng Internet',
            action: isEn
                ? `Network connection restored. Auto-synchronized ${syncedCount} devices to their last known state.`
                : `Kết nối mạng được khôi phục. Đã tự động đồng bộ ${syncedCount} thiết bị theo trạng thái lần cuối.`,
            timestamp: FieldValue.serverTimestamp(),
        });

        // Bắn Push Notification cho gia chủ
        const notiVi = {
            title: '🌐 Kết Nối Mạng Phục Hồi',
            body: `Mạng đã kết nối lại. Hệ thống đã đồng bộ thành công trạng thái ${syncedCount} thiết bị theo lần cuối!`
        };
        const notiEn = {
            title: '🌐 Network Restored & Synced',
            body: `Network reconnected. Auto-synchronized ${syncedCount} devices to their last known state!`
        };
        await sendPushToUserTokens(userId, notiVi, notiEn, isEn, false, 'normal');
    } catch (e: any) {
        console.warn('[NETWORK SYNC] Không thể lưu lịch sử đồng bộ mạng:', e.message);
    }

    addLog('[NETWORK SYNC]', `✅ Đồng bộ mạng hoàn tất: ${syncedCount} thiết bị đã phục hồi trạng thái cho gia chủ ${userId}!`, 'success');
    return { syncedCount, states: syncedStates };
}

// Giữ lại alias syncDeviceStatesToEsp để tương thích ngược
export const syncDeviceStatesToEsp = handleNetworkRestored;

/**
 * Lấy toàn bộ dữ liệu trạng thái backup của một User
 */
export function getUserDeviceBackup(userId: string): UserDeviceBackup | null {
    initDeviceStateBackup();
    return backupCache[userId] || null;
}

/**
 * Lấy toàn bộ danh sách trạng thái backup trên Server
 */
export function getAllDeviceBackupStates(): Record<string, UserDeviceBackup> {
    initDeviceStateBackup();
    return backupCache;
}

