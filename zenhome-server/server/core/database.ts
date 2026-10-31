import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';
import sqlite3 from 'sqlite3';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const DATA_DIR = path.resolve(__dirname, '../data');
const DB_FILE = path.join(DATA_DIR, 'zenhome_backup.sqlite');

if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Khóa bảo vệ dữ liệu tĩnh cấp trường (Field-Level Storage Encryption AES-256-GCM)
const BACKUP_ENCRYPTION_SECRET = process.env.BACKUP_ENCRYPTION_KEY?.trim() || 'ZenHome_Master_Vault_Key_2026_SecureSalt';
const ENCRYPTION_KEY_BUFFER = crypto.createHash('sha256').update(BACKUP_ENCRYPTION_SECRET).digest();

/**
 * Mã hóa payload bằng AES-256-GCM bảo vệ dữ liệu sao lưu tĩnh (Storage at Rest)
 */
export function encryptPayload(plaintext: string): string {
  if (!plaintext) return '';
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', ENCRYPTION_KEY_BUFFER, iv);
  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag().toString('hex');
  return `ZHENC1:${iv.toString('hex')}:${encrypted}:${tag}`;
}

/**
 * Giải mã payload AES-256-GCM với cơ chế tương thích ngược nếu là dữ liệu plaintext cũ
 */
export function decryptPayload(ciphertextEnvelope: string): string {
  if (!ciphertextEnvelope) return '';
  if (!ciphertextEnvelope.startsWith('ZHENC1:')) {
    return ciphertextEnvelope; // Tương thích ngược với bản ghi cũ chưa mã hóa
  }
  const parts = ciphertextEnvelope.split(':');
  if (parts.length !== 4) return ciphertextEnvelope;
  const [_, ivHex, encryptedHex, tagHex] = parts;
  try {
    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(tagHex, 'hex');
    const decipher = crypto.createDecipheriv('aes-256-gcm', ENCRYPTION_KEY_BUFFER, iv);
    decipher.setAuthTag(authTag);
    let decrypted = decipher.update(encryptedHex, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    return decrypted;
  } catch (err: any) {
    console.warn('[STORAGE SECURITY] ❌ Lỗi giải mã payload sao lưu SQLite:', err.message);
    return '';
  }
}

let dbInstance: sqlite3.Database | null = null;
let isInitialized = false;

export function getDb(): sqlite3.Database {
  if (!dbInstance) {
    dbInstance = new sqlite3.Database(DB_FILE, (err) => {
      if (err) {
        console.error('[SQLITE] ❌ Không thể mở cơ sở dữ liệu SQLite:', err.message);
      }
    });
  }
  return dbInstance;
}

export function dbRun(sql: string, params: any[] = []): Promise<{ lastID: number; changes: number }> {
  const db = getDb();
  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

export function dbGet<T = any>(sql: string, params: any[] = []): Promise<T | undefined> {
  const db = getDb();
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => {
      if (err) reject(err);
      else resolve(row as T);
    });
  });
}

export function dbAll<T = any>(sql: string, params: any[] = []): Promise<T[]> {
  const db = getDb();
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => {
      if (err) reject(err);
      else resolve((rows || []) as T[]);
    });
  });
}

/**
 * Khởi tạo bảng và cấu hình tối ưu hiệu năng WAL (Write-Ahead Logging) cho SQLite
 */
export async function initSqliteDatabase(): Promise<void> {
  if (isInitialized) return;

  try {
    // 1. Kích hoạt chế độ WAL & tối ưu I/O đĩa
    await dbRun('PRAGMA journal_mode = WAL;');
    await dbRun('PRAGMA synchronous = NORMAL;');
    await dbRun('PRAGMA temp_store = MEMORY;');
    await dbRun('PRAGMA cache_size = -8000;'); // ~8MB bộ nhớ đệm trang

    // 2. Tạo bảng quản lý trạng thái thiết bị
    await dbRun(`
      CREATE TABLE IF NOT EXISTS device_states (
        userId TEXT NOT NULL,
        deviceId TEXT NOT NULL,
        room TEXT NOT NULL,
        macAddress TEXT NOT NULL,
        baseTopic TEXT NOT NULL,
        state TEXT NOT NULL,
        source TEXT NOT NULL,
        syncStatus TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (userId, deviceId)
      );
    `);
    await dbRun(`CREATE INDEX IF NOT EXISTS idx_dev_user ON device_states (userId);`);

    // 3. Tạo bảng siêu dữ liệu gia chủ / hub
    await dbRun(`
      CREATE TABLE IF NOT EXISTS user_backup_meta (
        userId TEXT PRIMARY KEY,
        macAddress TEXT NOT NULL,
        lastOnlineAt TEXT,
        lastOfflineAt TEXT,
        lastSyncAt TEXT,
        updatedAt TEXT NOT NULL
      );
    `);

    // 4. Tạo bảng lưu trữ nhật ký hệ thống
    await dbRun(`
      CREATE TABLE IF NOT EXISTS server_logs (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        tag TEXT NOT NULL,
        message TEXT NOT NULL,
        rawFormatted TEXT NOT NULL,
        level TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      );
    `);
    await dbRun(`CREATE INDEX IF NOT EXISTS idx_logs_created ON server_logs (createdAt);`);

    // 5. Tạo bảng lưu trữ bản sao lưu hệ thống (Backups)
    await dbRun(`
      CREATE TABLE IF NOT EXISTS system_backups (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        displayTime TEXT,
        docCount INTEGER NOT NULL,
        sizeBytes INTEGER NOT NULL,
        collections TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      );
    `);
    await dbRun(`CREATE INDEX IF NOT EXISTS idx_backups_created ON system_backups (createdAt);`);

    // 6. Tạo bảng lưu trữ khóa xác thực Quản trị viên Passkey (FIDO2 / WebAuthn)
    await dbRun(`
      CREATE TABLE IF NOT EXISTS admin_passkeys (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        publicKey TEXT NOT NULL,
        counter INTEGER NOT NULL DEFAULT 0,
        deviceType TEXT NOT NULL DEFAULT 'singleDevice',
        backedUp INTEGER NOT NULL DEFAULT 0,
        transports TEXT,
        createdAt TEXT NOT NULL,
        lastUsedAt TEXT NOT NULL
      );
    `);
    await dbRun(`CREATE INDEX IF NOT EXISTS idx_passkeys_last_used ON admin_passkeys (lastUsedAt);`);

    isInitialized = true;
    console.log('[SQLITE] ✅ Cơ sở dữ liệu SQLite WAL Mode & Bảng Passkey đã sẵn sàng!');

    // 7. Tự động di chuyển dữ liệu từ file JSON cũ nếu bảng đang trống
    await migrateLegacyJsonData();
  } catch (err: any) {
    console.error('[SQLITE] ❌ Lỗi khởi tạo SQLite:', err.message);
  }
}

/**
 * Tự động di chuyển dữ liệu từ các file JSON cũ sang SQLite (Không mất dữ liệu lịch sử)
 */
async function migrateLegacyJsonData(): Promise<void> {
  try {
    // A. Migrate device_states_backup.json
    const backupJson = path.join(DATA_DIR, 'device_states_backup.json');
    if (fs.existsSync(backupJson)) {
      const countRow = await dbGet<{ count: number }>('SELECT COUNT(*) as count FROM device_states;');
      if (countRow && countRow.count === 0) {
        try {
          const raw = fs.readFileSync(backupJson, 'utf-8');
          const cache = JSON.parse(raw);
          if (cache && typeof cache === 'object') {
            for (const [userId, userObj] of Object.entries<any>(cache)) {
              if (!userObj) continue;
              await dbRun(
                `INSERT OR REPLACE INTO user_backup_meta (userId, macAddress, lastOnlineAt, lastOfflineAt, lastSyncAt, updatedAt)
                 VALUES (?, ?, ?, ?, ?, ?);`,
                [
                  userId,
                  userObj.macAddress || 'unknown',
                  userObj.lastOnlineAt || null,
                  userObj.lastOfflineAt || null,
                  userObj.lastSyncAt || null,
                  new Date().toISOString()
                ]
              );
              if (userObj.devices && typeof userObj.devices === 'object') {
                for (const [devId, dev] of Object.entries<any>(userObj.devices)) {
                  if (!dev || devId.startsWith('room_')) continue;
                  await dbRun(
                    `INSERT OR REPLACE INTO device_states (userId, deviceId, room, macAddress, baseTopic, state, source, syncStatus, updatedAt)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);`,
                    [
                      userId,
                      devId,
                      dev.room || 'default',
                      dev.macAddress || userObj.macAddress || 'unknown',
                      dev.baseTopic || '',
                      dev.state || '0',
                      dev.source || 'migration',
                      dev.syncStatus || 'synced',
                      dev.updatedAt || new Date().toISOString()
                    ]
                  );
                }
              }
            }
            console.log('[SQLITE-MIGRATION] 💾 Đã chuyển đổi thành công device_states_backup.json vào SQLite!');
          }
        } catch (e: any) {
          console.warn('[SQLITE-MIGRATION] ⚠️ Không thể migrate device_states_backup.json:', e.message);
        }
      }
    }

    // B. Migrate backups.json
    const backupsJson = path.join(DATA_DIR, 'backups.json');
    if (fs.existsSync(backupsJson)) {
      const bCount = await dbGet<{ count: number }>('SELECT COUNT(*) as count FROM system_backups;');
      if (bCount && bCount.count === 0) {
        try {
          const raw = fs.readFileSync(backupsJson, 'utf-8');
          const backups = JSON.parse(raw);
          if (Array.isArray(backups)) {
            for (const b of backups) {
              const created = new Date(b.timestamp).getTime() || Date.now();
              await dbRun(
                `INSERT OR REPLACE INTO system_backups (id, timestamp, displayTime, docCount, sizeBytes, collections, createdAt)
                 VALUES (?, ?, ?, ?, ?, ?, ?);`,
                [
                  b.id,
                  b.timestamp,
                  b.displayTime || '',
                  b.docCount || 0,
                  b.sizeBytes || 0,
                  encryptPayload(JSON.stringify(b.collections || [])),
                  created
                ]
              );
            }
            console.log('[SQLITE-MIGRATION] 💾 Đã chuyển đổi thành công backups.json vào SQLite!');
          }
        } catch (e: any) {
          console.warn('[SQLITE-MIGRATION] ⚠️ Không thể migrate backups.json:', e.message);
        }
      }
    }

    // C. Migrate logs.json
    const logsJson = path.join(DATA_DIR, 'logs.json');
    if (fs.existsSync(logsJson)) {
      const lCount = await dbGet<{ count: number }>('SELECT COUNT(*) as count FROM server_logs;');
      if (lCount && lCount.count === 0) {
        try {
          const raw = fs.readFileSync(logsJson, 'utf-8');
          const logs = JSON.parse(raw);
          if (Array.isArray(logs)) {
            const recentLogs = logs.slice(-300); // Lưu 300 log gần nhất
            for (const l of recentLogs) {
              await dbRun(
                `INSERT OR REPLACE INTO server_logs (id, timestamp, tag, message, rawFormatted, level, createdAt)
                 VALUES (?, ?, ?, ?, ?, ?, ?);`,
                [
                  l.id,
                  l.timestamp,
                  l.tag,
                  l.message,
                  l.rawFormatted || `[${l.timestamp}] ${l.tag} ${l.message}`,
                  l.level || 'info',
                  Date.now()
                ]
              );
            }
            console.log('[SQLITE-MIGRATION] 💾 Đã chuyển đổi thành công logs.json vào SQLite!');
          }
        } catch (e: any) {
          console.warn('[SQLITE-MIGRATION] ⚠️ Không thể migrate logs.json:', e.message);
        }
      }
    }
  } catch (err: any) {
    console.error('[SQLITE-MIGRATION] ❌ Lỗi quá trình di chuyển dữ liệu:', err.message);
  }
}

/**
 * Đóng an toàn kết nối cơ sở dữ liệu khi server tắt
 */
export function closeSqliteDatabase(): Promise<void> {
  return new Promise((resolve) => {
    if (dbInstance) {
      dbInstance.close((err) => {
        if (err) console.error('[SQLITE] ❌ Lỗi đóng kết nối database:', err.message);
        else console.log('[SQLITE] 🔒 Đã đóng an toàn kết nối SQLite.');
        dbInstance = null;
        resolve();
      });
    } else {
      resolve();
    }
  });
}
