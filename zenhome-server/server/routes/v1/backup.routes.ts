import { Router, Request, Response } from 'express';
import path from 'path';
import { storedBackups, BackupRecord } from '../../zenhomeState';
import { executeDeleteAccountRequest } from '../../zenhomeWorker';
import { requireAdminAuth, requireAuth } from '../../middlewares/auth';
import { createRealDatabaseBackup, getBackupFilePath, restoreDatabaseFromBackup } from '../../core/backupEngine';

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
 * @desc    Khởi tạo một bản Snapshot sao lưu dữ liệu toàn hệ thống lưu vào Disk (Yêu cầu Admin Auth)
 */
backupRouter.post('/trigger', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const record = await createRealDatabaseBackup();

    res.json({
      success: true,
      message: 'Tạo bản sao lưu dữ liệu Firestore thực tế thành công trên Server Backup (Đã lưu trữ an toàn vào Disk)!',
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
backupRouter.get('/list', requireAdminAuth, (req: Request, res: Response) => {
  res.json({
    success: true,
    totalBackups: storedBackups.length,
    backups: storedBackups,
    timestamp: new Date().toISOString(),
  });

/**
 * @route   GET /api/v1/backup/download/:backupId
 * @desc    Tải file snapshot JSON sao lưu trực tiếp về máy tính (Yêu cầu Admin Auth)
 */
backupRouter.get('/download/:backupId', requireAdminAuth, (req: Request, res: Response) => {
  const backupId = String(req.params.backupId);
  const filePath = getBackupFilePath(backupId);
  if (!filePath) {
    return res.status(404).json({ success: false, error: 'Không tìm thấy file sao lưu trên đĩa' });
  }
  res.download(filePath, path.basename(filePath));
});

/**
 * @route   POST /api/v1/backup/restore/:backupId
 * @desc    Khôi phục cơ sở dữ liệu Firestore từ bản sao lưu (Yêu cầu Admin Auth)
 */
backupRouter.post('/restore/:backupId', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const backupId = String(req.params.backupId);
    const result = await restoreDatabaseFromBackup(backupId);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
});

/**
 * @route   POST /api/v1/backup/delete-request
 * @desc    Tiếp nhận yêu cầu dọn dẹp và xóa triệt để tài khoản (Yêu cầu Admin Auth)
 */
backupRouter.post('/delete-request', requireAdminAuth, async (req: Request, res: Response) => {
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

/**
 * @route   GET /api/v1/backup/device-states
 * @desc    Lấy toàn bộ trạng thái thiết bị được lưu trữ trong Mini Server Backup
 */
backupRouter.get('/device-states', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const { getAllDeviceBackupStates } = await import('../../core/deviceStateBackup');
    const allStates = getAllDeviceBackupStates();
    res.json({
      success: true,
      totalUsers: Object.keys(allStates).length,
      data: allStates,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/backup/device-states/:userId
 * @desc    Lấy trạng thái thiết bị của một gia chủ cụ thể
 */
backupRouter.get('/device-states/:userId', requireAuth, async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    if (req.user?.role !== 'admin' && req.user?.uid !== userId) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền truy cập trạng thái của tài khoản khác.' });
    }
    const { getUserDeviceBackup } = await import('../../core/deviceStateBackup');
    const userBackup = getUserDeviceBackup(String(userId));
    if (!userBackup) {
      return res.status(404).json({ success: false, message: 'Chưa có bản ghi backup nào cho user này' });
    }
    res.json({
      success: true,
      userId,
      backup: userBackup,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/backup/device-states/sync
 * @desc    Kích hoạt đồng bộ trạng thái từ Server Backup xuống ESP32
 */
backupRouter.post('/device-states/sync', requireAuth, async (req: Request, res: Response) => {
  try {
    const { userId, macAddress } = req.body;
    if (!userId) {
      return res.status(400).json({ success: false, error: 'Thiếu tham số userId' });
    }
    if (req.user?.role !== 'admin' && req.user?.uid !== userId) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền kích hoạt đồng bộ của tài khoản khác.' });
    }
    const { syncDeviceStatesToEsp } = await import('../../core/deviceStateBackup');
    const result = await syncDeviceStatesToEsp(String(userId), String(macAddress || 'unknown'));
    res.json({
      success: true,
      message: `Đã kích hoạt đồng bộ ${result.syncedCount} thiết bị xuống ESP32 thành công`,
      syncedCount: result.syncedCount,
      states: result.states,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/backup/device-states/save
 * @desc    Lưu thủ công trạng thái thiết bị vào Server Backup
 */
backupRouter.post('/device-states/save', requireAuth, async (req: Request, res: Response) => {
  try {
    const { baseTopic, state, source } = req.body;
    if (!baseTopic || (state !== '0' && state !== '1')) {
      return res.status(400).json({ success: false, error: 'Cần baseTopic và state (0 hoặc 1)' });
    }
    const { recordDeviceState } = await import('../../core/deviceStateBackup');
    await recordDeviceState(String(baseTopic), state, source || 'manual_api');
    res.json({
      success: true,
      message: `Đã lưu trạng thái thiết bị [${baseTopic}] -> ${state} vào Server Backup`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
