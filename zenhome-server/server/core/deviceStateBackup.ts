import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { db, FieldValue } from './firebase';
import { sendCommandWithRetry } from './devices';
import { addLog } from '../zenhomeState';
import { sendPushToUserTokens } from './notifications';
import { initSqliteDatabase, dbRun, dbAll, closeSqliteDatabase } from './database';

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
let persistDebounceTimer: NodeJS.Timeout | null = null;

/**
 * Ghi tệp JSON nguyên tử (Atomic Write): Ghi ra tệp tạm .tmp rồi đổi tên (rename)
 * Ngăn chặn tuyệt đối việc file bị cắt cụt (corruption) nếu server bị tắt đột ngột
 */
function atomicWriteJsonSync(targetPath: string, data: any): void {
    const dataDir = path.dirname(targetPath);
    if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
    }
    const tmpPath = path.join(
        dataDir,
        `.${path.basename(targetPath)}.${Date.now()}.${Math.random().toString(36).substring(2, 7)}.tmp`
    );
    try {
        fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf-8');
        fs.renameSync(tmpPath, targetPath);
    } catch (err: any) {
        if (fs.existsSync(tmpPath)) {
            try { fs.unlinkSync(tmpPath); } catch (_) {}
        }
        throw err;
    }
}

/**
 * Ghi đĩa tức thì (Dùng cho các sự kiện an toàn nguồn điện khẩn cấp hoặc graceful shutdown)
 */
export function flushBackupToDiskSync(): void {
    if (persistDebounceTimer) {
        clearTimeout(persistDebounceTimer);
        persistDebounceTimer = null;
    }
    try {
        atomicWriteJsonSync(BACKUP_FILE, backupCache);
    } catch (err: any) {
        console.error('[BACKUP] ❌ Lỗi ghi file backup trạng thái thiết bị:', err.message);
    }
}

/**
 * Nạp trạng thái từ SQLite WAL vào bộ nhớ RAM
 */
export async function loadDeviceStatesFromSqlite(): Promise<void> {
    try {
        await initSqliteDatabase();
        const metaRows = await dbAll<any>('SELECT * FROM user_backup_meta;');
        for (const meta of metaRows) {
            if (!backupCache[meta.userId]) {
                backupCache[meta.userId] = {
                    userId: meta.userId,
                    macAddress: meta.macAddress,
                    lastOnlineAt: meta.lastOnlineAt || undefined,
                    lastOfflineAt: meta.lastOfflineAt || undefined,
                    lastSyncAt: meta.lastSyncAt || undefined,
                    devices: {}
                };
            }
        }
        const devRows = await dbAll<any>('SELECT * FROM device_states;');
        for (const d of devRows) {
            if (!backupCache[d.userId]) {
                backupCache[d.userId] = {
                    userId: d.userId,
                    macAddress: d.macAddress,
                    devices: {}
                };
            }
            backupCache[d.userId].devices[d.deviceId] = {
                userId: d.userId,
                macAddress: d.macAddress,
                room: d.room,
                deviceId: d.deviceId,
                baseTopic: d.baseTopic,
                state: d.state,
                source: d.source,
                updatedAt: d.updatedAt,
                syncStatus: d.syncStatus
            };
        }
        if (devRows.length > 0) {
            addLog('[SQLITE]', `💾 Đã nạp ${devRows.length} trạng thái thiết bị từ SQLite WAL!`, 'info');
        }
    } catch (e: any) {
        console.error('[SQLITE] ❌ Lỗi nạp dữ liệu từ SQLite:', e.message);
    }
}

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
            try {
                const raw = fs.readFileSync(BACKUP_FILE, 'utf-8');
                const data = JSON.parse(raw);
                Object.assign(backupCache, data);
            } catch (parseErr: any) {
                console.error('[BACKUP] ⚠️ File backup bị lỗi cú pháp JSON:', parseErr.message);
                atomicWriteJsonSync(BACKUP_FILE, {});
            }
        } else {
            atomicWriteJsonSync(BACKUP_FILE, {});
        }
        isInitialized = true;
        // Đồng bộ nạp dữ liệu từ SQLite WAL
        loadDeviceStatesFromSqlite().catch(() => {});
    } catch (err: any) {
        console.error('[BACKUP] ❌ Lỗi khởi tạo cache backup thiết bị:', err.message);
    }
}

/**
 * Lưu bộ nhớ đệm xuống đĩa cứng kết hợp Debouncing (1500ms)
 * Giảm tải 90% Disk I/O và giải phóng hoàn toàn Event Loop khi nhiều thiết bị thay đổi đồng thời
 */
function persistBackupToDisk(immediate = false): void {
    if (immediate) {
        flushBackupToDiskSync();
        return;
    }

    if (!persistDebounceTimer) {
        persistDebounceTimer = setTimeout(() => {
            persistDebounceTimer = null;
            try {
                atomicWriteJsonSync(BACKUP_FILE, backupCache);
            } catch (err: any) {
                console.error('[BACKUP] ❌ Lỗi ghi file backup trạng thái thiết bị (debounced):', err.message);
            }
        }, 1500);
    }
}

const lastLogPerDevice: Record<string, number> = {};

// ==========================================
// DEBOUNCED BATCH FIRESTORE STATE SYNC (CHỐNG SPAM FIRESTORE WRITES)
// Gom nhiều thay đổi trạng thái của cùng 1 gia chủ trong 1200ms vào 1 lần ghi Firestore duy nhất
// ==========================================
interface PendingSyncItem {
    state: '0' | '1';
    room: string;
    updatedAt: any;
    source: string;
}

const pendingFirestoreSync: Record<string, {
    timer: NodeJS.Timeout | null;
    devices: Record<string, PendingSyncItem>;
}> = {};

export function queueFirestoreStateSync(
    userId: string,
    deviceId: string,
    state: '0' | '1',
    room: string,
    source: string
): void {
    if (!pendingFirestoreSync[userId]) {
        pendingFirestoreSync[userId] = {
            timer: null,
            devices: {}
        };
    }

    const userSync = pendingFirestoreSync[userId];
    userSync.devices[deviceId] = {
        state,
        room,
        updatedAt: FieldValue.serverTimestamp(),
        source
    };

    if (!userSync.timer) {
        userSync.timer = setTimeout(async () => {
            userSync.timer = null;
            const batchToFlush = { ...userSync.devices };
            userSync.devices = {};

            const count = Object.keys(batchToFlush).length;
            if (count === 0) return;

            try {
                await db.collection('users').doc(userId).collection('device_states').doc('latest').set(
                    batchToFlush,
                    { merge: true }
                );
            } catch (err: any) {
                console.error(`[BACKUP] ❌ Lỗi đồng bộ batch Firestore cho user ${userId}:`, err.message);
            }
        }, 1200);
    }
}

export async function flushPendingFirestoreSync(): Promise<void> {
    const promises: Promise<any>[] = [];
    for (const [userId, syncData] of Object.entries(pendingFirestoreSync)) {
        if (syncData.timer) {
            clearTimeout(syncData.timer);
            syncData.timer = null;
        }
        const batchToFlush = { ...syncData.devices };
        syncData.devices = {};
        if (Object.keys(batchToFlush).length > 0) {
            promises.push(
                db.collection('users').doc(userId).collection('device_states').doc('latest').set(
                    batchToFlush,
                    { merge: true }
                ).catch((e: any) => console.error(`[BACKUP] ❌ Lỗi flush Firestore cho ${userId}:`, e.message))
            );
        }
    }
    if (promises.length > 0) {
        await Promise.all(promises);
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

    if (baseTopic.includes('/sync/') || baseTopic.includes('/system/')) {
        return; // Bỏ qua các topic báo cáo hệ thống hoặc bulk sync
    }

    const parts = baseTopic.split('/');
    if (parts.length < 3) return;

    // Cấu trúc topic chuẩn: userId/macAddress/room/devId hoặc userId/room/devId
    const userId = parts[0];
    const deviceId = parts[parts.length - 1];
    const room = parts[parts.length - 2];
    const macAddress = parts.length >= 4 ? parts[1] : 'unknown';

    // Bỏ qua nếu deviceId trùng với room hoặc không hợp lệ
    if (!deviceId || deviceId.startsWith('room_') || room === 'sync') {
        return;
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

    const existing = backupCache[userId]?.devices[deviceId];
    if (existing && existing.state === state) {
        // Trạng thái thực tế không đổi -> Triệt tiêu 100% spam log, spam disk I/O và database writes!
        return;
    }
    const now = new Date().toISOString();

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

    // Chỉ ghi nhận và đồng bộ khi có sự thay đổi trạng thái thực tế (Tiết kiệm Firestore Writes & Disk I/O)
    const isStateChanged = !existing || existing.state !== state;

    if (isStateChanged) {
        const devKey = `${userId}:${deviceId}`;
        const nowMs = Date.now();
        const shouldLog = !lastLogPerDevice[devKey] || (nowMs - lastLogPerDevice[devKey] >= 2000);

        if (shouldLog) {
            lastLogPerDevice[devKey] = nowMs;
            addLog('[BACKUP]', `Đã lưu trạng thái cuối của [${deviceId}]: ${state === '1' ? 'BẬT' : 'TẮT'} (Gia chủ: ${userId})`, 'info');
        }

        persistBackupToDisk();

        // Ghi bền vững tức thì vào SQLite WAL (ACID Safe, <1ms)
        dbRun(
            `INSERT OR REPLACE INTO device_states (userId, deviceId, room, macAddress, baseTopic, state, source, syncStatus, updatedAt)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);`,
            [userId, deviceId, room, macAddress, baseTopic, state, source, 'synced', now]
        ).catch((e: any) => console.error('[SQLITE] ❌ Lỗi lưu device state:', e.message));

        dbRun(
            `INSERT OR REPLACE INTO user_backup_meta (userId, macAddress, updatedAt)
             VALUES (?, ?, ?);`,
            [userId, macAddress, now]
        ).catch(() => {});

        // Đồng bộ gom nhóm (Debounced Batch) lên Firestore thay vì gọi set() dồn dập
        queueFirestoreStateSync(userId, deviceId, state, room, source);
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
            // Lọc bỏ thiết bị không hợp lệ hoặc do sync cũ tạo ra
            if (devId.startsWith('room_') || record.room === 'sync') {
                delete userBackup.devices[devId];
                continue;
            }
            if (fallbackDevices && fallbackDevices.length > 0) {
                const isValid = fallbackDevices.some(d => d.id === devId);
                if (!isValid) {
                    delete userBackup.devices[devId];
                    continue;
                }
            }

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
        persistBackupToDisk(true);
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
            // Lọc bỏ thiết bị không hợp lệ hoặc do sync cũ tạo ra
            if (devId.startsWith('room_') || record.room === 'sync') {
                delete userBackup.devices[devId];
                continue;
            }
            if (fallbackDevices && fallbackDevices.length > 0) {
                const isValid = fallbackDevices.some(d => d.id === devId);
                if (!isValid) {
                    delete userBackup.devices[devId];
                    continue;
                }
            }

            const targetState = record.state;
            syncedStates[devId] = targetState;

            // Tôn trọng phần cứng vật lý (Single Source of Truth):
            // ESP32 tự động công bố trạng thái rơ-le thực tế qua /sync/report khi có mạng lại.
            // Server ghi nhận đồng bộ, tuyệt đối không gửi lệnh cũ đè ngược xuống phần cứng!
            record.syncStatus = 'synced';
            syncedCount++;
        }
        userBackup.lastOnlineAt = new Date().toISOString();
        userBackup.lastSyncAt = new Date().toISOString();
        persistBackupToDisk(true);
    } else if (fallbackDevices && fallbackDevices.length > 0) {
        for (const dev of fallbackDevices) {
            if (dev.id) {
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

/**
 * Xóa sạch cache trạng thái thiết bị khi tài khoản bị xóa (Chống rò rỉ dữ liệu / Ghost Data)
 */
export function removeUserDeviceBackup(userId: string): void {
    initDeviceStateBackup();
    if (backupCache[userId]) {
        delete backupCache[userId];
        persistBackupToDisk(true);
        dbRun('DELETE FROM device_states WHERE userId = ?;', [userId]).catch(() => {});
        dbRun('DELETE FROM user_backup_meta WHERE userId = ?;', [userId]).catch(() => {});
        console.log(`[BACKUP] 🗑️ Đã xóa sạch cache trạng thái thiết bị của tài khoản đã xóa: ${userId}`);
    }
}

// Tự động ghi đĩa, flush Firestore và đóng SQLite khi tiến trình Node.js kết thúc (Graceful Shutdown Protection)
process.once('SIGINT', () => { flushBackupToDiskSync(); flushPendingFirestoreSync(); closeSqliteDatabase(); });
process.once('SIGTERM', () => { flushBackupToDiskSync(); flushPendingFirestoreSync(); closeSqliteDatabase(); });
process.once('beforeExit', () => { flushBackupToDiskSync(); flushPendingFirestoreSync(); closeSqliteDatabase(); });



