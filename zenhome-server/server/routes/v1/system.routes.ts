import { Router, Request, Response } from 'express';
import { state, serverLogs, addLog } from '../../zenhomeState';
import { cleanJunkAccounts, sendCommandWithRetry } from '../../zenhomeWorker';
import { getCurrentServerConfig, syncServerConfigToFirestore } from '../../core/networkSync';
import { db } from '../../core/firebase';
import { sendAppVersionUpdateFCM } from '../../core/notifications';

export const systemRouter = Router();


/**
 * @route   GET /api/v1/system/server-config
 * @desc    Lấy cấu hình địa chỉ IP máy chủ và đường dẫn APK trực tiếp thời gian thực
 */
systemRouter.get('/server-config', (req: Request, res: Response) => {
  res.json({
    success: true,
    data: getCurrentServerConfig(),
  });
});

/**
 * @route   POST /api/v1/system/sync-ip
 * @desc    Chủ động kích hoạt đồng bộ IP máy chủ lên Database ngay lập tức
 */
systemRouter.post('/sync-ip', async (req: Request, res: Response) => {
  const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 5000;
  const config = await syncServerConfigToFirestore(PORT);
  res.json({
    success: true,
    message: `Đã đồng bộ IP máy chủ (${config.localIp}:${PORT}) lên Cloud Firestore.`,
    data: config,
  });
});

/**
 * @route   GET /api/v1/system/health
 * @desc    Kiểm tra tình trạng sống (Health check) của Server
 */
systemRouter.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'healthy',
    server: 'ZenHome Dedicated Backend & API Server',
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   GET /api/v1/system/state
 * @desc    Lấy trạng thái chi tiết của các bộ đệm RAM (pendingTasks, activeTimers, activeSchedules)
 */
systemRouter.get('/state', (req: Request, res: Response) => {
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

  res.json({
    success: true,
    uptime: Math.floor(process.uptime()),
    pendingTasksCount: Object.keys(sanitizedPendingTasks).length,
    pendingTasks: sanitizedPendingTasks,
    activeTimersCount: Object.keys(sanitizedActiveTimers).length,
    activeTimers: sanitizedActiveTimers,
    activeSchedulesCount: Object.keys(state.activeSchedules || {}).length,
    activeSchedules: state.activeSchedules,
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   GET /api/v1/system/logs
 * @desc    Lấy danh sách nhật ký sự kiện thời gian thực của máy chủ
 */
systemRouter.get('/logs', (req: Request, res: Response) => {
  const limit = parseInt((req.query.limit as string) || '150', 10);
  res.json({
    success: true,
    totalLogs: serverLogs.length,
    logs: serverLogs.slice(-limit),
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   POST /api/v1/system/clear-logs
 * @desc    Xóa trắng bộ đệm nhật ký hệ thống
 */
systemRouter.post('/clear-logs', (req: Request, res: Response) => {
  serverLogs.length = 0;
  addLog('[BACKEND]', 'Đã xóa trắng nhật ký màn hình thông qua API.', 'info');
  res.json({
    success: true,
    message: 'Đã xóa trắng nhật ký hệ thống thành công.',
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   POST /api/v1/system/action
 * @desc    Kích hoạt hành động bảo trì hệ thống (clean_junk, restart_server)
 */
systemRouter.post('/action', async (req: Request, res: Response) => {
  const { action, payload } = req.body;

  if (action === 'clean_junk') {
    cleanJunkAccounts();
    return res.json({ success: true, message: 'Đã kích hoạt tác vụ quét và dọn dẹp tài khoản rác ngầm.' });
  }

  if (action === 'test_command') {
    const topic = payload?.topic || 'Dtthuat/ESP32_MAC/phong_khach/den_tran';
    const stateVal = payload?.state || '1';
    sendCommandWithRetry(topic, stateVal, 'api_test_command');
    return res.json({ success: true, message: `Đã gửi lệnh điều khiển thử nghiệm tới ${topic} -> ${stateVal}` });
  }

  if (action === 'restart_server') {
    addLog('[BACKEND]', '⚠ Đã nhận lệnh Restart từ API. Đang tắt máy chủ để tiến trình tự khởi động lại...', 'warn');
    setTimeout(() => {
      process.exit(1);
    }, 1200);
    return res.json({ success: true, message: 'Đã phát tín hiệu khởi động lại Server.' });
  }

  res.status(400).json({ success: false, error: 'Hành động không hợp lệ' });
});

// ==========================================
// QUẢN LÝ CẬP NHẬT PHIÊN BẢN ỨNG DỤNG DI ĐỘNG (APP VERSION OTA)
// ==========================================
let appVersionData = {
  latestVersion: "1.7.1",
  latestBuildNumber: 171,
  minVersion: "1.6.0",
  minBuildNumber: 160,
  titleVi: "Bản Cập Nhật ZenHome v1.7.1 - Quét ESP32 Trực Tiếp",
  titleEn: "ZenHome Update v1.7.1 - In-App ESP32 Provisioning",
  releaseNotesVi: "• Dò quét sóng Wi-Fi AP của ESP32 trực tiếp trong app, không cần thoát ra Cài đặt máy\n• Nhập mật khẩu SoftAP và kết nối tự động trong app (hỗ trợ Android IoT Specifier)\n• Tự động bắt tay và nhận diện mã MAC ESP32 qua 192.168.4.1\n• Bổ sung tính năng quét và chọn nhanh Wi-Fi 2.4GHz nhà bạn\n• Tối ưu cơ chế kiểm tra nhịp tim Server thông minh (Hỏi - Trả lời)\n• Màn hình báo mất mạng trực quan, không còn màn hình trắng",
  releaseNotesEn: "• In-app ESP32 SoftAP scanning radar without switching to phone Wi-Fi settings\n• Enter SoftAP password and connect directly in-app (Android IoT Specifier)\n• Auto-handshake and detect ESP32 MAC via 192.168.4.1\n• Added quick 2.4GHz home Wi-Fi scanner in Step 1\n• Optimized Request-Response server health check\n• Visual offline screen replacing blank screen",
  downloadUrl: "https://github.com/dtthuat/zenhome/releases/latest",
  directApkUrl: "/public/downloads/zenhome-app-release.apk",
  isForceUpdate: false,
  publishedAt: new Date().toISOString(),
};

/**
 * @route   GET /api/v1/system/app-version
 * @desc    Lấy thông tin phiên bản ứng dụng di động mới nhất
 */
systemRouter.get('/app-version', async (req: Request, res: Response) => {
  try {
    if (db) {
      const snap = await db.collection('system_config').doc('app_version').get();
      if (snap.exists && snap.data()) {
        return res.json({ success: true, data: snap.data() });
      }
    }
  } catch (e) {
    // fallback to in-memory appVersionData
  }

  res.json({ success: true, data: appVersionData });
});


/**
 * @route   POST /api/v1/system/app-version
 * @desc    Cập nhật và phát hành phiên bản mới từ Web Admin
 */
systemRouter.post('/app-version', async (req: Request, res: Response) => {
  const { 
    latestVersion, 
    latestBuildNumber, 
    minVersion, 
    minBuildNumber, 
    titleVi, 
    titleEn, 
    releaseNotesVi, 
    releaseNotesEn, 
    downloadUrl, 
    directApkUrl, 
    isForceUpdate 
  } = req.body;

  if (latestVersion) appVersionData.latestVersion = latestVersion;
  if (latestBuildNumber) appVersionData.latestBuildNumber = Number(latestBuildNumber);
  if (minVersion) appVersionData.minVersion = minVersion;
  if (minBuildNumber) appVersionData.minBuildNumber = Number(minBuildNumber);
  if (titleVi) appVersionData.titleVi = titleVi;
  if (titleEn) appVersionData.titleEn = titleEn;
  if (releaseNotesVi) appVersionData.releaseNotesVi = releaseNotesVi;
  if (releaseNotesEn) appVersionData.releaseNotesEn = releaseNotesEn;
  if (downloadUrl) appVersionData.downloadUrl = downloadUrl;
  if (directApkUrl !== undefined) appVersionData.directApkUrl = directApkUrl;
  if (isForceUpdate !== undefined) appVersionData.isForceUpdate = Boolean(isForceUpdate);
  appVersionData.publishedAt = new Date().toISOString();

  try {
    if (db) {
      await db.collection('system_config').doc('app_version').set(appVersionData, { merge: true });
    }


    if (sendAppVersionUpdateFCM) {
      // Gửi ngầm thông báo FCM đa ngôn ngữ để không chặn response
      sendAppVersionUpdateFCM(appVersionData).catch((err: any) => {
        console.error('[FCM ERROR]', err);
      });
    }

  } catch (e) {
    // ignored
  }

  addLog('[SYSTEM]', `Đã phát hành bản cập nhật v${appVersionData.latestVersion} (Build ${appVersionData.latestBuildNumber}) & kích hoạt FCM đa ngôn ngữ (VIE/ENG)`, 'info');
  res.json({ success: true, message: 'Đã cập nhật thông tin phiên bản ứng dụng và gửi thông báo FCM (VIE/ENG) thành công.', data: appVersionData });
});
