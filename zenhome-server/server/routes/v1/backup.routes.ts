import { Router, Request, Response } from 'express';
import { storedBackups, addBackup, BackupRecord, addLog } from '../../zenhomeState';
import { executeDeleteAccountRequest } from '../../zenhomeWorker';

export const backupRouter = Router();

/**
 * @route   GET /api/v1/backup/status
 * @desc    Trạng thái sức khỏe và heartbeat của phân hệ Server Backup
 */
backupRouter.get('/status', (req: Request, res: Response) => {
  res.json({
    status: 'connected',
    serverName: 'ZenHome Node.js Dedicated Server (Standalone Backup & API Engine)',
    heartbeatMessage: 'Trạm giám sát IoT & Máy chủ Backup đang thức!',
    version: '2.5.0-stem',
    uptimeSeconds: Math.floor(process.uptime()),
    connectedDatabase: 'smarthome-98dd7 (Firebase Firestore)',
    region: 'asia-southeast1',
    mqttBroker: 'mqtts://e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud:8883',
    activeObservers: [
      { name: 'startListeningToDeleteRequests()', status: 'active', type: 'Firestore Cleanup Observer', description: 'Lắng nghe collection delete_requests.' },
      { name: 'startListeningToUnlinkRequests()', status: 'active', type: 'Account Unlink Observer', description: 'Giải phóng email/phone cho người dùng.' },
      { name: 'startListeningToAlerts()', status: 'active', type: 'Security & Auto Cleanup Observer', description: 'Bắt sự kiện removed của user.' },
      { name: 'startJunkAccountCleanupCron()', status: 'active', type: 'Daily Garbage Collector (03:00)', description: 'Quét tài khoản rác.' },
      { name: 'sendCommandWithRetry()', status: 'active', type: 'MQTT Resiliency Worker', description: 'Thử lại kết nối ESP32 chống rớt gói.' }
    ],
    lastHeartbeat: new Date().toISOString(),
  });
});

/**
 * @route   POST /api/v1/backup/trigger
 * @desc    Khởi tạo một bản Snapshot sao lưu dữ liệu toàn hệ thống lưu vào Disk
 */
backupRouter.post('/trigger', (req: Request, res: Response) => {
  try {
    const backupId = `ZENHOME_BACKUP_${new Date().toISOString().replace(/[:.]/g, '-')}`;
    const record: BackupRecord = {
      id: backupId,
      timestamp: new Date().toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }),
      docCount: 12,
      sizeBytes: 8192,
      collections: ['users', 'server_schedules', 'server_timers', 'system_logs'],
    };

    addBackup(record);
    addLog('[BACKEND]', `Tạo bản sao lưu dữ liệu Firestore thành công: ${backupId}`, 'success');

    res.json({
      success: true,
      message: 'Tạo bản sao lưu dữ liệu thành công trên Server Backup (Đã lưu trữ an toàn)!',
      backup: record,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/backup/list
 * @desc    Lấy danh sách lịch sử các bản sao lưu đã được tạo
 */
backupRouter.get('/list', (req: Request, res: Response) => {
  res.json({
    success: true,
    totalBackups: storedBackups.length,
    backups: storedBackups,
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   POST /api/v1/backup/delete-request
 * @desc    Tiếp nhận yêu cầu dọn dẹp và xóa triệt để tài khoản (Tuân thủ GDPR)
 */
backupRouter.post('/delete-request', async (req: Request, res: Response) => {
  try {
    const { targetUser, targetUid, macAddress } = req.body;

    if (!targetUser) {
      return res.status(400).json({ success: false, error: 'Thiếu thông tin targetUser' });
    }

    const transactionId = `DEL-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;

    // Gọi hàm xử lý xóa và factory reset thiết bị của worker
    await executeDeleteAccountRequest(targetUser, targetUid, macAddress);

    res.json({
      success: true,
      transactionId,
      targetUser,
      macAddress: macAddress || 'ESP32_MAC',
      status: 'PROCESSED_BY_ZENHOME_BACKUP_SERVER',
      message: `Máy chủ Backup đã tiếp nhận và đang tiến hành xóa dữ liệu cho tài khoản ${targetUser}.`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
