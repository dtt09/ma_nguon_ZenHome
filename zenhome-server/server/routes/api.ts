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
import { systemRouter, invalidateDashboardCache } from './v1/system.routes';
import { usersRouter } from './v1/users.routes';
import { authRouter } from './v1/auth.routes';

// Existing state & worker imports for backwards compatibility
import { state, serverLogs, addLog, storedBackups, addBackup, BackupRecord } from '../zenhomeState';
import { cleanJunkAccounts, sendCommandWithRetry, executeDeleteAccountRequest } from '../zenhomeWorker';
import { requireAdminAuth, requireAuth } from '../middlewares/auth';
import { apiLimiter, actionLimiter } from '../middlewares/rateLimiter';
import { client as mqttClient } from '../core/mqtt';
import { getCpuMetrics, getRamMetrics, getDiskMetrics, formatUptimeString } from '../core/systemTelemetry';
import { createRealDatabaseBackup, getBackupFilePath, restoreDatabaseFromBackup } from '../core/backupEngine';
import path from 'path';
import net from 'net';
import dns from 'dns';

function isPrivateIp(ip: string): boolean {
  const cleanIp = ip.replace(/^\[|\]$/g, '');
  const ipType = net.isIP(cleanIp);
  if (ipType === 4) {
    const parts = cleanIp.split('.').map(p => parseInt(p, 10));
    if (parts.length !== 4 || parts.some(isNaN)) return true;
    // 0.0.0.0/8 (Mạng hiện tại)
    if (parts[0] === 0) return true;
    // 127.0.0.0/8 (Loopback)
    if (parts[0] === 127) return true;
    // 10.0.0.0/8 (Private RFC 1918)
    if (parts[0] === 10) return true;
    // 172.16.0.0/12 (Private RFC 1918)
    if (parts[0] === 172 && parts[1] >= 16 && parts[1] <= 31) return true;
    // 192.168.0.0/16 (Private RFC 1918)
    if (parts[0] === 192 && parts[1] === 168) return true;
    // 169.254.0.0/16 (Link-local / Cloud metadata)
    if (parts[0] === 169 && parts[1] === 254) return true;
    // 100.64.0.0/10 (Carrier-Grade NAT)
    if (parts[0] === 100 && parts[1] >= 64 && parts[1] <= 127) return true;
    // 224.0.0.0/4 (Multicast và Reserved)
    if (parts[0] >= 224) return true;
  } else if (ipType === 6) {
    if (cleanIp === '::1' || cleanIp === '::') return true;
    if (cleanIp.startsWith('fc') || cleanIp.startsWith('fd')) return true;
    if (/^fe[89ab]/i.test(cleanIp)) return true;
    if (cleanIp.startsWith('::ffff:')) {
      return isPrivateIp(cleanIp.substring(7));
    }
  }
  return false;
}

async function isSafePublicHost(hostname: string): Promise<boolean> {
  const host = hostname.toLowerCase().replace(/^\[|\]$/g, '');
  // 1. Chặn các tên miền cục bộ, metadata và DNS đặc biệt
  if (
    host === 'localhost' ||
    host === 'metadata.google.internal' ||
    host.endsWith('.internal') ||
    host.endsWith('.local') ||
    host.endsWith('.localhost') ||
    host.endsWith('.lan')
  ) {
    return false;
  }

  // 2. Nếu là IP literal, kiểm tra dải IP
  if (net.isIP(host)) {
    return !isPrivateIp(host);
  }

  // 3. Phân giải DNS nhằm chống triệt để kỹ thuật DNS Rebinding (127.0.0.1.nip.io, v.v.)
  try {
    const records = await dns.promises.lookup(host, { all: true });
    if (!records || records.length === 0) return false;
    for (const record of records) {
      if (isPrivateIp(record.address)) {
        return false;
      }
    }
    return true;
  } catch {
    return false;
  }
}


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
apiRouter.use('/v1/auth', authRouter);

// ==========================================
// TƯƠNG THÍCH NGƯỢC CHO GIAO DIỆN WEB CŨ (BACKWARD COMPATIBILITY)
// ==========================================
apiRouter.get('/node-server/state', requireAuth, apiLimiter, (req: Request, res: Response) => {
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

apiRouter.get('/node-server/logs', requireAdminAuth, apiLimiter, (req: Request, res: Response) => {
  res.json({ logs: serverLogs });
});

apiRouter.post('/node-server/action', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  const { action, payload } = req.body;

  if (action === 'check_auth' || action === 'verify_admin') {
    return res.json({ success: true, message: 'Xác thực Quản trị viên hợp lệ.' });
  }

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

apiRouter.post('/backup-server/proxy-ping', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  const { serverUrl } = req.body;
  if (!serverUrl || typeof serverUrl !== 'string') {
    return res.status(400).json({ connected: false, error: 'Thiếu serverUrl' });
  }
  try {
    const parsed = new URL(serverUrl);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
      return res.status(400).json({ connected: false, error: 'Giao thức serverUrl không hợp lệ (chỉ chấp nhận http hoặc https)' });
    }
    const host = parsed.hostname.toLowerCase();
    // Chống SSRF & DNS Rebinding: cấm truy cập dải địa chỉ nội bộ, loopback, private IP và metadata (ZH-09)
    const isSafe = await isSafePublicHost(host);
    if (!isSafe) {
      return res.status(400).json({ connected: false, error: 'Địa chỉ IP hoặc tên miền không an toàn (Chống SSRF / DNS Rebinding)' });
    }
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
  invalidateDashboardCache();
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

apiRouter.post('/backup-server/trigger-backup', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  try {
    const record = await createRealDatabaseBackup();
    res.json({
      success: true,
      backup: record,
      message: 'Tạo bản sao lưu dữ liệu Firestore thực tế thành công trên Server (Đã lưu vào Disk)!',
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

apiRouter.get('/backup-server/backups', requireAdminAuth, apiLimiter, (req: Request, res: Response) => {
  res.json({ backups: storedBackups });
});

apiRouter.get('/backup-server/download/:backupId', requireAdminAuth, (req: Request, res: Response) => {
  const backupId = String(req.params.backupId);
  const filePath = getBackupFilePath(backupId);
  if (!filePath) {
    return res.status(404).json({ success: false, error: 'Không tìm thấy file sao lưu trên đĩa' });
  }
  res.download(filePath, path.basename(filePath));
});
apiRouter.post('/backup-server/restore/:backupId', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  try {
    const backupId = String(req.params.backupId);
    const result = await restoreDatabaseFromBackup(backupId);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});