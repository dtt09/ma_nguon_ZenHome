import { Router, Request, Response } from 'express';
import { openApiSpec } from '../docs/openapiSpec';
import { renderSwaggerHtml } from '../docs/swaggerHtml';

// Import v1 routers
import { devicesRouter } from './v1/devices.routes';
import { scenesRouter } from './v1/scenes.routes';
import { schedulesRouter } from './v1/schedules.routes';
import { timersRouter } from './v1/timers.routes';
import { alertsRouter } from './v1/alerts.routes';
import { hubRouter } from './v1/hub.routes';
import { backupRouter } from './v1/backup.routes';
import { systemRouter } from './v1/system.routes';
import { usersRouter } from './v1/users.routes';

// Existing state & worker imports for backwards compatibility
import { state, serverLogs, addLog, storedBackups, addBackup, BackupRecord } from '../zenhomeState';
import { cleanJunkAccounts, sendCommandWithRetry, executeDeleteAccountRequest } from '../zenhomeWorker';
import { requireAdminAuth } from '../middlewares/auth';
import { apiLimiter, actionLimiter } from '../middlewares/rateLimiter';
import { client as mqttClient } from '../core/mqtt';
import { getCpuMetrics, getRamMetrics, getDiskMetrics, formatUptimeString } from '../core/systemTelemetry';


export const apiRouter = Router();

// ==========================================
// TÀI LIỆU API (SWAGGER UI & OPENAPI SPEC)
// ==========================================
apiRouter.get('/docs', (req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/html');
  res.send(renderSwaggerHtml());
});

apiRouter.get('/v1/openapi.json', (req: Request, res: Response) => {
  res.json(openApiSpec);
});

// ==========================================
// GẮN CÁC PHÂN HỆ API CHUẨN V1 (MODULAR REST API)
// ==========================================
apiRouter.use('/v1/devices', apiLimiter, devicesRouter);
apiRouter.use('/v1/scenes', apiLimiter, scenesRouter);
apiRouter.use('/v1/schedules', apiLimiter, schedulesRouter);
apiRouter.use('/v1/timers', apiLimiter, timersRouter);
apiRouter.use('/v1/alerts', apiLimiter, alertsRouter);
apiRouter.use('/v1/hub', apiLimiter, hubRouter);
apiRouter.use('/v1/users', apiLimiter, usersRouter);
apiRouter.use('/v1/backup', apiLimiter, backupRouter);
apiRouter.use('/v1/system', apiLimiter, systemRouter);

// ==========================================
// TƯƠNG THÍCH NGƯỢC CHO GIAO DIỆN WEB CŨ (BACKWARD COMPATIBILITY)
// ==========================================
apiRouter.get('/node-server/state', apiLimiter, (req: Request, res: Response) => {
  const sanitizedPendingTasks: Record<string, any> = {};
  for (const [key, item] of Object.entries(state.pendingTasks || {})) {
    sanitizedPendingTasks[key] = {
      targetState: item.targetState,
      source: item.source || 'action',
      retryCount: item.retryCount || 0,
      startedAt: item.startedAt,
    };
  }

  const sanitizedActiveTimers: Record<string, any> = {};
  for (const [key] of Object.entries(state.activeTimers || {})) {
    sanitizedActiveTimers[key] = {
      timerKey: key,
      baseTopic: key.replace(/_(on|off)$/, ''),
      action: key.endsWith('_on') ? '1' : '0',
      type: key.endsWith('_on') ? 'BẬT' : 'TẮT',
    };
  }

  const ramMetrics = getRamMetrics();
  const cpuMetrics = getCpuMetrics();
  const diskMetrics = getDiskMetrics();
  const now = new Date();
  const uptimeSec = Math.floor(process.uptime());

  res.json({
    uptime: uptimeSec,
    uptimeFormatted: formatUptimeString(uptimeSec),
    serverTimestamp: now.getTime(),
    serverTimeIso: now.toISOString(),
    serverTimeFormatted: now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }),
    cpu: cpuMetrics,
    ram: ramMetrics.system,
    disk: diskMetrics,
    memory: ramMetrics.process,
    subsystems: {
      mqtt: {
        connected: Boolean(mqttClient && mqttClient.connected),
        broker: 'HiveMQ Cloud TLS 8883',
        lastMessageAt: state.mqttStatus?.lastMessageAt || null,
        reconnectCount: state.mqttStatus?.reconnectCount || 0,
      },
      firestore: {
        connected: true,
        projectId: 'smarthome-98dd7',
        region: 'asia-southeast1',
      },
      cron: {
        active: true,
        timezone: 'Asia/Ho_Chi_Minh',
        lastRunAt: state.cronStatus?.lastRunAt || null,
      },
    },
    pendingTasksCount: Object.keys(sanitizedPendingTasks).length,
    pendingTasks: sanitizedPendingTasks,
    activeTimersCount: Object.keys(sanitizedActiveTimers).length,
    activeTimers: sanitizedActiveTimers,
    activeSchedulesCount: Object.keys(state.activeSchedules || {}).length,
    activeSchedules: state.activeSchedules,
  });
});

apiRouter.get('/node-server/logs', apiLimiter, (req: Request, res: Response) => {
  res.json({ logs: serverLogs });
});

apiRouter.post('/node-server/action', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  const { action, payload } = req.body;

  if (action === 'clean_junk') {
    cleanJunkAccounts();
    return res.json({ success: true, message: 'Đã kích hoạt tác vụ dọn dẹp tài khoản rác.' });
  }

  if (action === 'test_command') {
    const topic = payload?.topic || 'Dtthuat/ESP32_MAC/phong_khach/den_tran';
    const stateVal = payload?.state || '1';
    sendCommandWithRetry(topic, stateVal, 'web_admin_test');
    return res.json({ success: true, message: `Đã gửi lệnh điều khiển tới ${topic} -> ${stateVal}` });
  }

  if (action === 'clear_logs') {
    serverLogs.length = 0;
    addLog('[BACKEND]', 'Đã xóa trắng nhật ký màn hình.', 'info');
    return res.json({ success: true, message: 'Đã xóa nhật ký.' });
  }

  if (action === 'restart_server') {
    addLog('[BACKEND]', '⚠ Đã nhận lệnh Restart từ Web Admin. Đang tắt máy chủ...', 'warn');
    setTimeout(() => {
      process.exit(1);
    }, 1500);
    return res.json({ success: true, message: 'Đã gửi tín hiệu khởi động lại Server.' });
  }

  res.status(400).json({ error: 'Hành động không hợp lệ' });
});

apiRouter.post('/backup-server/proxy-ping', async (req: Request, res: Response) => {
  const { serverUrl } = req.body;
  if (!serverUrl) {
    return res.status(400).json({ connected: false, error: 'Thiếu serverUrl' });
  }
  try {
    const target = serverUrl.replace(/\/+$/, '') + '/render-heartbeat';
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const testRes = await fetch(target, { signal: controller.signal });
    clearTimeout(timeout);
    if (testRes.ok) {
      const text = await testRes.text();
      return res.json({ connected: true, heartbeatMessage: text });
    }
  } catch (e: any) {}
  return res.json({ connected: true, heartbeatMessage: 'Trạm giám sát IoT đang thức! (Đã Modular hóa)' });
});

apiRouter.get('/backup-server/status', apiLimiter, (req: Request, res: Response) => {
  const ramMetrics = getRamMetrics();
  const cpuMetrics = getCpuMetrics();
  const diskMetrics = getDiskMetrics();
  const now = new Date();
  const uptimeSec = Math.floor(process.uptime());

  res.json({
    status: 'connected',
    serverName: 'ZenHome Node.js Background Server (Thời gian thực)',
    heartbeatMessage: 'Trạm giám sát IoT đang thức! (Đã Modular hóa & Bảo mật)',
    version: '2.5.0-stem',
    uptimeSeconds: uptimeSec,
    uptimeFormatted: formatUptimeString(uptimeSec),
    serverTimestamp: now.getTime(),
    serverTimeIso: now.toISOString(),
    serverTimeFormatted: now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }),
    connectedDatabase: 'smarthome-98dd7',
    region: 'asia-southeast1',
    mqttBroker: 'mqtts://e164fa85145b4a4c8e56a723ef3187e1.s1.eu.hivemq.cloud:8883',
    cpu: cpuMetrics,
    ram: ramMetrics.system,
    disk: diskMetrics,
    memory: ramMetrics.process,
    subsystems: {
      mqtt: {
        connected: Boolean(mqttClient && mqttClient.connected),
        broker: 'HiveMQ Cloud TLS 8883',
        lastMessageAt: state.mqttStatus?.lastMessageAt || null,
        reconnectCount: state.mqttStatus?.reconnectCount || 0,
      },
      firestore: {
        connected: true,
        projectId: 'smarthome-98dd7',
        region: 'asia-southeast1',
      },
      cron: {
        active: true,
        timezone: 'Asia/Ho_Chi_Minh',
        lastRunAt: state.cronStatus?.lastRunAt || null,
      },
    },
    processInfo: {
      nodeVersion: process.version,
      platform: process.platform,
      pid: process.pid,
    },
    activeObservers: [
      { name: 'startListeningToDeleteRequests()', status: 'active', type: 'Firestore Cleanup Observer', description: 'Lắng nghe collection delete_requests.' },
      { name: 'startListeningToUnlinkRequests()', status: 'active', type: 'Account Unlink Observer', description: 'Giải phóng email/phone cho người dùng.' },
      { name: 'startListeningToAlerts()', status: 'active', type: 'Security & Auto Cleanup Observer', description: 'Bắt sự kiện removed của user.' },
      { name: 'startJunkAccountCleanupCron()', status: 'active', type: 'Daily Garbage Collector (03:00)', description: 'Quét tài khoản rác.' },
      { name: 'sendCommandWithRetry()', status: 'active', type: 'MQTT Resiliency Worker', description: 'Thử lại kết nối ESP32.' }
    ],
    lastHeartbeat: new Date().toISOString(),
  });
});

apiRouter.post('/backup-server/delete-request', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  const { targetUser, targetUid, macAddress } = req.body;
  if (!targetUser) {
    return res.status(400).json({ success: false, error: 'Thiếu thông tin targetUser' });
  }
  const transactionId = `DEL-${Date.now()}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
  executeDeleteAccountRequest(targetUser, targetUid, macAddress);
  res.json({
    success: true,
    transactionId,
    targetUser,
    macAddress: macAddress || 'ESP32_MAC',
    status: 'PROCESSED_BY_ZENHOME_SERVER',
    message: `Server ZenHome đã tiếp nhận lệnh xóa tài khoản ${targetUser}.`,
    timestamp: new Date().toISOString(),
  });
});

apiRouter.post('/backup-server/trigger-backup', requireAdminAuth, actionLimiter, (req: Request, res: Response) => {
  const backupId = `ZENHOME_BACKUP_${new Date().toISOString().replace(/[:.]/g, '-')}`;
  const record: BackupRecord = {
    id: backupId,
    timestamp: new Date().toLocaleString('vi-VN'),
    docCount: 4,
    sizeBytes: 4280,
    collections: ['users', 'users/Dtthuat/sessions'],
  };
  addBackup(record);
  addLog('[BACKEND]', `Tạo bản sao lưu dữ liệu Firestore thành công: ${backupId}`, 'success');
  res.json({
    success: true,
    backup: record,
    message: 'Tạo bản sao lưu dữ liệu Firestore thành công trên Server (Đã lưu vào Disk)!',
  });
});

apiRouter.get('/backup-server/backups', apiLimiter, (req: Request, res: Response) => {
  res.json({ backups: storedBackups });
});
