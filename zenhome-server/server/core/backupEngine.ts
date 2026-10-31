import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { db } from './firebase';
import { addBackup, addLog, BackupRecord } from '../zenhomeState';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const BACKUPS_DIR = path.resolve(__dirname, '../data/backups');

/**
 * Xoay vòng và dọn dẹp các tệp backup cũ, giữ lại tối đa maxKeep bản (Mặc định: 15)
 * Ngăn chặn tuyệt đối việc tràn bộ nhớ đĩa cứng (Disk Exhaustion)
 */
export function pruneOldBackupFiles(maxKeep: number = 15): void {
  try {
    if (!fs.existsSync(BACKUPS_DIR)) return;
    const files = fs.readdirSync(BACKUPS_DIR)
      .filter(f => f.startsWith('ZENHOME_BACKUP_') && f.endsWith('.json'))
      .map(f => {
        const fullPath = path.join(BACKUPS_DIR, f);
        const stat = fs.statSync(fullPath);
        return { name: f, fullPath, mtime: stat.mtimeMs };
      })
      .sort((a, b) => b.mtime - a.mtime);

    if (files.length > maxKeep) {
      const toDelete = files.slice(maxKeep);
      for (const item of toDelete) {
        try {
          fs.unlinkSync(item.fullPath);
          console.log(`[BACKUP RETENTION] 🗑️ Đã xoay vòng xóa bản backup cũ trên đĩa: ${item.name}`);
        } catch (_) {}
      }
    }
  } catch (err: any) {
    console.warn('[BACKUP RETENTION] Lỗi khi dọn dẹp file backup cũ:', err.message);
  }
}

export async function createRealDatabaseBackup(): Promise<BackupRecord> {
  const now = new Date();
  const backupId = `ZENHOME_BACKUP_${now.toISOString().replace(/[:.]/g, '-')}`;

  if (!fs.existsSync(BACKUPS_DIR)) {
    fs.mkdirSync(BACKUPS_DIR, { recursive: true });
  }

  const exportedData: Record<string, any[]> = {};
  let totalDocs = 0;
  const targetCollections = ['users', 'server_schedules', 'server_timers'];

  for (const colName of targetCollections) {
    try {
      const snap = await db.collection(colName).get();
      exportedData[colName] = [];

      if (colName === 'users') {
        const userSubcollections = ['device_states', 'scenes', 'schedules', 'alerts', 'history'];
        // Tối ưu hóa: Truy vấn song song tất cả user documents và subcollections (Giảm độ trễ 10x)
        const userDocsResults = await Promise.all(
          snap.docs.map(async (doc) => {
            const userDocData: any = {
              id: doc.id,
              ...doc.data(),
              subcollections: {}
            };
            let count = 1;

            const subPromises = userSubcollections.map(async (subCol) => {
              try {
                let subQuery: any = doc.ref.collection(subCol);
                if (subCol === 'history') {
                  subQuery = subQuery.orderBy('timestamp', 'desc').limit(50);
                }
                const subSnap = await subQuery.get();
                if (!subSnap.empty) {
                  return {
                    subCol,
                    docs: subSnap.docs.map((sDoc: any) => ({
                      id: sDoc.id,
                      ...sDoc.data()
                    }))
                  };
                }
              } catch (_) {}
              return null;
            });

            const subResults = await Promise.all(subPromises);
            for (const r of subResults) {
              if (r) {
                userDocData.subcollections[r.subCol] = r.docs;
                count += r.docs.length;
              }
            }

            return { userDocData, count };
          })
        );

        for (const item of userDocsResults) {
          exportedData[colName].push(item.userDocData);
          totalDocs += item.count;
        }
      } else {
        for (const doc of snap.docs) {
          exportedData[colName].push({
            id: doc.id,
            ...doc.data()
          });
          totalDocs++;
        }
      }
    } catch (e: any) {
      console.warn(`[BACKUP] Không thể xuất collection ${colName}:`, e.message);
    }
  }

  const filePath = path.join(BACKUPS_DIR, `${backupId}.json`);
  const tmpFilePath = path.join(BACKUPS_DIR, `.${backupId}.${Date.now()}.tmp`);

  const jsonContent = JSON.stringify({
    backupId,
    createdAt: now.toISOString(),
    displayTime: now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }),
    totalDocuments: totalDocs,
    data: exportedData
  }, null, 2);

  // Ghi nguyên tử (Atomic Write)
  fs.writeFileSync(tmpFilePath, jsonContent, 'utf-8');
  fs.renameSync(tmpFilePath, filePath);

  const sizeBytes = Buffer.byteLength(jsonContent, 'utf-8');
  const isoTime = now.toISOString();
  const displayTime = now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' });

  const record: BackupRecord = {
    id: backupId,
    timestamp: isoTime,
    displayTime,
    docCount: totalDocs,
    sizeBytes,
    collections: Object.keys(exportedData),
  };

  addBackup(record);
  pruneOldBackupFiles(15);

  addLog('[BACKEND]', `Tạo bản sao lưu dữ liệu Firestore thực tế thành công: ${backupId} (${totalDocs} tài liệu, ${sizeBytes} bytes, file: ${backupId}.json)`, 'success');

  return record;
}

export function getBackupFilePath(backupId: string): string | null {
  // Sanitize backupId để ngăn chặn Path Traversal
  const cleanId = path.basename(backupId).replace(/[^a-zA-Z0-9_\-\.]/g, '');
  const filePath = path.join(BACKUPS_DIR, cleanId.endsWith('.json') ? cleanId : `${cleanId}.json`);
  if (fs.existsSync(filePath)) {
    return filePath;
  }
  return null;
}

/**
 * Loại bỏ triệt để các trường undefined trước khi ghi vào Firestore
 */
function sanitizeFirestoreData(data: any): any {
  if (data === null || data === undefined) return null;
  if (Array.isArray(data)) {
    return data.map(sanitizeFirestoreData).filter(v => v !== undefined);
  }
  if (typeof data === 'object') {
    const clean: Record<string, any> = {};
    for (const [k, v] of Object.entries(data)) {
      if (v !== undefined) {
        clean[k] = sanitizeFirestoreData(v);
      }
    }
    return clean;
  }
  return data;
}

/**
 * Khôi phục cơ sở dữ liệu Firestore từ bản sao lưu JSON (Restore Engine)
 */
export async function restoreDatabaseFromBackup(backupId: string): Promise<{
  success: boolean;
  restoredDocuments: number;
  message: string;
}> {
  const filePath = getBackupFilePath(backupId);
  if (!filePath || !fs.existsSync(filePath)) {
    throw new Error(`Không tìm thấy file sao lưu trên máy chủ: ${backupId}`);
  }

  const raw = fs.readFileSync(filePath, 'utf-8');
  const backupJson = JSON.parse(raw);
  const data = backupJson.data || {};
  let restoredCount = 0;

  // 1. Phục hồi users và toàn bộ subcollections
  if (Array.isArray(data.users)) {
    for (const user of data.users) {
      const { id: userId, subcollections, ...userData } = user;
      if (!userId) continue;

      // Phục hồi root user document (đã lọc sạch undefined)
      await db.collection('users').doc(userId).set(sanitizeFirestoreData(userData), { merge: true });
      restoredCount++;

      // Phục hồi các subcollections (device_states, scenes, schedules, alerts, history)
      if (subcollections && typeof subcollections === 'object') {
        for (const [subColName, subDocs] of Object.entries(subcollections)) {
          if (Array.isArray(subDocs)) {
            let batch = db.batch();
            let batchOps = 0;
            for (const sDoc of subDocs) {
              const { id: docId, ...sData } = sDoc;
              if (docId) {
                const docRef = db.collection('users').doc(userId).collection(subColName).doc(docId);
                batch.set(docRef, sanitizeFirestoreData(sData), { merge: true });
                batchOps++;
                restoredCount++;
                if (batchOps >= 350) {
                  await batch.commit();
                  batch = db.batch();
                  batchOps = 0;
                }
              }
            }
            if (batchOps > 0) {
              await batch.commit();
            }
          }
        }
      }
    }
  }

  // 2. Phục hồi server_schedules & server_timers
  for (const rootCol of ['server_schedules', 'server_timers']) {
    if (Array.isArray(data[rootCol])) {
      let batch = db.batch();
      let batchOps = 0;
      for (const item of data[rootCol]) {
        const { id: docId, ...itemData } = item;
        if (docId) {
          const docRef = db.collection(rootCol).doc(docId);
          batch.set(docRef, itemData, { merge: true });
          batchOps++;
          restoredCount++;
          if (batchOps >= 350) {
            await batch.commit();
            batch = db.batch();
            batchOps = 0;
          }
        }
      }
      if (batchOps > 0) {
        await batch.commit();
      }
    }
  }

  addLog('[BACKEND]', `Khôi phục thành công ${restoredCount} tài liệu Firestore từ bản sao lưu: ${backupId}`, 'success');
  return {
    success: true,
    restoredDocuments: restoredCount,
    message: `Đã khôi phục thành công ${restoredCount} tài liệu từ bản sao lưu ${backupId} vào Firestore!`
  };
}

