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
 * TỰ ĐỘNG ĐỒNG BỘ: Khi ESP32 có mạng trở lại, khôi phục lại trạng thái bật/tắt lần cuối!
 */
export async function syncDeviceStatesToEsp(
    userId: string,
    macAddress: string,
    fallbackDevices: any[] = [],
    isEn: boolean = false
): Promise<{ syncedCount: number; states: Record<string, string> }> {
    initDeviceStateBackup();

    console.log(`[BACKUP SYNC] 🔄 Bắt đầu quy trình tự động đồng bộ trạng thái cho ESP32 ${macAddress} (User: ${userId})...`);
    addLog('[BACKUP SYNC]', `Bắt đầu tự động đồng bộ trạng thái thiết bị lần cuối cho ESP32 ${macAddress}...`, 'info');

    const userBackup = backupCache[userId];
    const syncedStates: Record<string, string> = {};
    let syncedCount = 0;

    // 1. Nếu đã có dữ liệu backup trong Server Backup
    if (userBackup && Object.keys(userBackup.devices).length > 0) {
        for (const [devId, record] of Object.entries(userBackup.devices)) {
            const targetState = record.state; // '0' hoặc '1'
            syncedStates[devId] = targetState;

            // Đảm bảo topic đúng chuẩn userId/macAddress/room/devId
            const targetTopic = record.baseTopic.includes(macAddress)
                ? record.baseTopic
                : `${userId}/${macAddress}/${record.room}/${devId}`;

            console.log(`[BACKUP SYNC] ⚡ Khôi phục ${devId}: ${targetState === '1' ? 'BẬT' : 'TẮT'} -> Gửi tới: ${targetTopic}/cmd`);
            sendCommandWithRetry(targetTopic, targetState, 'backup_restore');
            record.syncStatus = 'synced';
            syncedCount++;
        }
        userBackup.lastOnlineAt = new Date().toISOString();
        userBackup.lastSyncAt = new Date().toISOString();
        persistBackupToDisk();
    } else if (fallbackDevices && fallbackDevices.length > 0) {
        // 2. Nếu chưa có lịch sử trong cache, an toàn điện: gửi 0 cho các thiết bị đã cấu hình
        for (const dev of fallbackDevices) {
            if (dev.room && dev.id) {
                const baseTopic = `${userId}/${macAddress}/${dev.room}/${dev.id}`;
                sendCommandWithRetry(baseTopic, '0', 'safety_default');
                syncedStates[dev.id] = '0';
                syncedCount++;
            }
        }
    }

    // Ghi nhận lịch sử hệ thống vào Firestore
    try {
        await db.collection('users').doc(userId).collection('history').add({
            deviceName: isEn ? 'Backup Sync Server' : 'Máy chủ Đồng Bộ Backup',
            action: isEn
                ? `Network restored. Auto-synchronized ${syncedCount} devices to their last known state.`
                : `Có mạng trở lại. Đã tự động đồng bộ ${syncedCount} thiết bị về trạng thái lần cuối.`,
            timestamp: FieldValue.serverTimestamp(),
        });

        // Bắn thông báo Push cho người dùng biết
        const notiVi = {
            title: '⚡ Kết Nối Phục Hồi & Đã Đồng Bộ',
            body: `ESP32 đã online trở lại. Hệ thống đã khôi phục thành công trạng thái ${syncedCount} thiết bị theo lần cuối!`
        };
        const notiEn = {
            title: '⚡ Connection Restored & Synced',
            body: `ESP32 is back online. Auto-synchronized ${syncedCount} devices to their last known state!`
        };
        await sendPushToUserTokens(userId, notiVi, notiEn, false, false, 'important');
    } catch (e: any) {
        console.warn('[BACKUP SYNC] Không thể lưu lịch sử đồng bộ:', e.message);
    }

    addLog('[BACKUP SYNC]', `✅ Đồng bộ hoàn tất: ${syncedCount} thiết bị đã phục hồi trạng thái cho gia chủ ${userId}!`, 'success');
    return { syncedCount, states: syncedStates };
}

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
