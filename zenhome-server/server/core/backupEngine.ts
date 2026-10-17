import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { db } from './firebase';
import { addBackup, addLog, BackupRecord } from '../zenhomeState';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const BACKUPS_DIR = path.resolve(__dirname, '../data/backups');

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
      for (const doc of snap.docs) {
        exportedData[colName].push({
          id: doc.id,
          ...doc.data()
        });
        totalDocs++;
      }
    } catch (e: any) {
      console.warn(`[BACKUP] Không thể xuất collection ${colName}:`, e.message);
    }
  }

  const filePath = path.join(BACKUPS_DIR, `${backupId}.json`);
  const jsonContent = JSON.stringify({
    backupId,
    createdAt: now.toISOString(),
    totalDocuments: totalDocs,
    data: exportedData
  }, null, 2);

  fs.writeFileSync(filePath, jsonContent, 'utf-8');
  const sizeBytes = Buffer.byteLength(jsonContent, 'utf-8');

  const record: BackupRecord = {
    id: backupId,
    timestamp: now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }),
    docCount: totalDocs,
    sizeBytes,
    collections: Object.keys(exportedData),
  };

  addBackup(record);
  addLog('[BACKEND]', `Tạo bản sao lưu dữ liệu Firestore thực tế thành công: ${backupId} (${totalDocs} tài liệu, ${sizeBytes} bytes, file: ${backupId}.json)`, 'success');

  return record;
}

export function getBackupFilePath(backupId: string): string | null {
  const filePath = path.join(BACKUPS_DIR, `${backupId}.json`);
  if (fs.existsSync(filePath)) {
    return filePath;
  }
  return null;
}
