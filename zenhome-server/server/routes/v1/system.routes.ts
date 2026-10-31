import { Router, Request, Response } from 'express';
import { state, serverLogs, addLog } from '../../zenhomeState';
import { cleanJunkAccounts, sendCommandWithRetry } from '../../zenhomeWorker';
import { getCurrentServerConfig, syncServerConfigToFirestore } from '../../core/networkSync';
import { db, FieldValue } from '../../core/firebase';
import { sendAppVersionUpdateFCM } from '../../core/notifications';
import { requireAdminAuth, requireAuth } from '../../middlewares/auth';
import { diagnoseCrashWithAi } from '../../core/aiDiagnostics';

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
 * @desc    Chủ động kích hoạt đồng bộ IP máy chủ lên Database ngay lập tức (Yêu cầu Admin Auth)
 */
systemRouter.post('/sync-ip', requireAdminAuth, async (req: Request, res: Response) => {
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
 * @desc    Lấy trạng thái chi tiết của các bộ đệm RAM (pendingTasks, activeTimers, activeSchedules) (Yêu cầu Xác thực)
 */
systemRouter.get('/state', requireAuth, (req: Request, res: Response) => {
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
 * @desc    Lấy danh sách nhật ký sự kiện thời gian thực của máy chủ (Yêu cầu Admin Auth)
 */
systemRouter.get('/logs', requireAdminAuth, (req: Request, res: Response) => {
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
 * @desc    Xóa trắng bộ đệm nhật ký hệ thống (Yêu cầu Admin Auth)
 */
systemRouter.post('/clear-logs', requireAdminAuth, (req: Request, res: Response) => {
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
 * @desc    Kích hoạt hành động bảo trì hệ thống (clean_junk, restart_server) (Yêu cầu Admin Auth)
 */
systemRouter.post('/action', requireAdminAuth, async (req: Request, res: Response) => {
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
  latestVersion: "1.8.11",
  latestBuildNumber: 197,
  minVersion: "1.8.0",
  minBuildNumber: 180,
  titleVi: "Bản Cập Nhật ZenHome v1.8.11 (Global Sync)",
  titleEn: "ZenHome Update v1.8.11 (Global Sync)",
  releaseNotesVi: "• Đồng bộ tải trực tiếp toàn cầu qua GitHub Releases CDN\n• Tối ưu hóa OTA Hub ESP32 không phụ thuộc IP máy chủ\n• Phản hồi công tắc tức thời 0ms & triệt tiêu hoàn toàn log thừa",
  releaseNotesEn: "• Global direct download via GitHub Releases CDN\n• Autonomous ESP32 OTA without local server\n• 0ms instant switch reaction & zero log spam",
  downloadUrl: "https://github.com/dtt09/ma_nguon_ZenHome/releases/latest",
  directApkUrl: "https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/ZenHome_Release.apk",
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
 * @desc    Cập nhật và phát hành phiên bản mới từ Web Admin (Yêu cầu Admin Auth)
 */
systemRouter.post('/app-version', requireAdminAuth, async (req: Request, res: Response) => {
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
    invalidateDashboardCache();

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

// ==========================================
// ĐỒNG BỘ HÓA NHẬT KÝ SỰ CỐ (CRASHLYTICS & FIRESTORE REALTIME BRIDGE)
// ==========================================

/**
 * @route   GET /api/v1/system/crash-logs
 * @desc    Lấy danh sách nhật ký sự cố runtime từ Firestore
 */
systemRouter.get('/crash-logs', async (req: Request, res: Response) => {
  try {
    const limit = parseInt((req.query.limit as string) || '100', 10);
    if (!db) {
      return res.json({ success: true, crashLogs: [] });
    }

    const snap = await db.collection('crash_logs').orderBy('timestamp', 'desc').limit(limit).get();
    const logs: any[] = [];
    snap.forEach(doc => {
      const data = doc.data();
      logs.push({
        id: doc.id,
        userId: data.userId || 'Hệ thống',
        userName: data.userName || data.userId || 'Người dùng',
        userEmail: data.userEmail || '',
        timestamp: data.timestamp ? (data.timestamp.toDate ? data.timestamp.toDate().toLocaleString('vi-VN') : new Date(data.timestamp).toLocaleString('vi-VN')) : 'Chưa cập nhật',
        errorTitle: data.errorTitle || 'Lỗi runtime',
        errorMessage: data.errorMessage || '',
        severity: data.severity || 'error',
        stackTrace: data.stackTrace || '',
        deviceModel: data.deviceModel || 'N/A',
        osVersion: data.osVersion || 'N/A',
        appVersion: data.appVersion || 'N/A',
        isResolved: data.isResolved ?? false,
        raw: data,
      });
    });

    res.json({ success: true, total: logs.length, crashLogs: logs });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   POST /api/v1/system/crash-logs
 * @desc    Tiếp nhận crash log từ ứng dụng Flutter di động hoặc Web Admin và ghi vào Firestore
 */
systemRouter.post('/crash-logs', async (req: Request, res: Response) => {
  try {
    const {
      userId = 'guest',
      userName = 'Người dùng ZenHome',
      userEmail = '',
      errorTitle = 'Lỗi không xác định',
      errorMessage = '',
      stackTrace = '',
      severity = 'error',
      deviceModel = 'Thiết bị di động',
      osVersion = 'OS',
      appVersion = '1.7.9',
      buildNumber = 179,
      reason = '',
      source = 'api',
    } = req.body;

    const crashPayload = {
      userId,
      userName,
      userEmail,
      errorTitle,
      errorMessage,
      stackTrace,
      severity,
      deviceModel,
      osVersion,
      appVersion,
      buildNumber: Number(buildNumber) || 179,
      reason,
      source,
      isResolved: false,
      createdAt: new Date().toISOString(),
      timestamp: FieldValue ? FieldValue.serverTimestamp() : new Date(),
    };

    let docId = `crash_${Date.now()}`;
    if (db) {
      const ref = await db.collection('crash_logs').add(crashPayload);
      docId = ref.id;

      if (userId && userId !== 'guest' && userId !== 'unauthenticated') {
        try {
          await db.collection('users').doc(userId).collection('crash_logs').doc(docId).set(crashPayload);
        } catch (_) {}
      }
    }

    addLog('[CRASH-REPORT]', `⚡ Ghi nhận sự cố [${severity.toUpperCase()}]: ${errorTitle} (${deviceModel} - ${userName})`, 'error');
    res.json({ success: true, message: 'Đã lưu bản ghi sự cố thành công.', id: docId });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   PATCH /api/v1/system/crash-logs/:id/resolve
 * @desc    Cập nhật trạng thái giải quyết của crash log
 */
systemRouter.patch('/crash-logs/:id/resolve', async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const { isResolved = true, path: customPath } = req.body;

    if (db) {
      if (customPath) {
        await db.doc(customPath).update({ isResolved: Boolean(isResolved) });
      } else {
        await db.collection('crash_logs').doc(id).update({ isResolved: Boolean(isResolved) });
      }
    }

    addLog('[CRASH-RESOLVE]', `Đã cập nhật trạng thái lỗi ${id} -> ${isResolved ? 'ĐÃ KHẮC PHỤC' : 'CHƯA XỬ LÝ'}`, 'info');
    res.json({ success: true, id, isResolved: Boolean(isResolved) });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   DELETE /api/v1/system/crash-logs/:id
 * @desc    Xóa bản ghi crash log khỏi Firestore
 */
systemRouter.delete('/crash-logs/:id', async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const { path: customPath } = req.body || {};

    if (db) {
      if (customPath) {
        await db.doc(customPath).delete();
      } else {
        await db.collection('crash_logs').doc(id).delete();
      }
    }

    addLog('[CRASH-DELETE]', `Đã xóa bản ghi lỗi ${id}`, 'info');
    res.json({ success: true, message: `Đã xóa bản ghi ${id} thành công.` });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   POST /api/v1/system/crash-logs/test
 * @desc    Tạo bản ghi sự cố mô phỏng kiểm tra luồng Crashlytics & Firestore Realtime
 */
systemRouter.post('/crash-logs/test', async (req: Request, res: Response) => {
  try {
    const testCrash = {
      userId: 'admin_test',
      userName: 'ZenHome Administrator',
      userEmail: 'admin@zenhome.io',
      errorTitle: 'ZenHomeTestException: Kiểm thử đồng bộ Crashlytics Realtime',
      errorMessage: 'Lỗi mô phỏng từ Hệ thống để xác nhận luồng Crashlytics & Cloud Firestore hoạt động ổn định.',
      stackTrace: '#0   AdminConsole.triggerTestCrash (admin_dashboard.ts:42)\n#1   SystemController.handleTestCrash (system.routes.ts:310)\n#2   Express.dispatch (router.js:150)',
      severity: 'fatal',
      deviceModel: 'ZenHome Test Platform',
      osVersion: 'Test Runtime Environment',
      appVersion: '1.7.9',
      buildNumber: 179,
      isResolved: false,
      source: 'server_test',
      createdAt: new Date().toISOString(),
      timestamp: FieldValue ? FieldValue.serverTimestamp() : new Date(),
    };

    let docId = `test_${Date.now()}`;
    if (db) {
      const ref = await db.collection('crash_logs').add(testCrash);
      docId = ref.id;
    }

    addLog('[CRASH-TEST]', '🧪 Đã kích hoạt bản ghi lỗi thử nghiệm thành công.', 'warn');
    res.json({ success: true, message: 'Đã tạo bản ghi kiểm thử Crashlytics thành công!', id: docId, data: testCrash });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

function sanitizeTimestamp(val: any): string {
  if (!val) return 'Chưa cập nhật';
  if (typeof val?.toDate === 'function') {
    return val.toDate().toLocaleString('vi-VN');
  }
  if (typeof val === 'object') {
    const sec = val._seconds ?? val.seconds;
    if (typeof sec === 'number') {
      return new Date(sec * 1000).toLocaleString('vi-VN');
    }
    return 'Chưa cập nhật';
  }
  if (typeof val === 'string') {
    if (val.includes('T') || val.includes('-')) {
      const d = new Date(val);
      if (!isNaN(d.getTime())) return d.toLocaleString('vi-VN');
    }
    return val;
  }
  if (typeof val === 'number') {
    return new Date(val).toLocaleString('vi-VN');
  }
  return String(val);
}

// In-memory cache for dashboard-sync to protect Firestore quota and eliminate polling conflicts
interface DashboardSyncCache {
  data: any;
  cachedAt: number;
}
let dashboardSyncCache: DashboardSyncCache | null = null;
const SYNC_CACHE_TTL_MS = 4000; // 4 seconds TTL for background poll protection
let activeSyncPromise: Promise<any> | null = null;

export function invalidateDashboardCache(): void {
  dashboardSyncCache = null;
}

/**
 * Hàm thực thi đồng bộ dữ liệu toàn diện từ Cloud Firestore
 */
async function fetchFullDashboardData(): Promise<any> {
  const fetchedCustomers: any[] = [];
  const rawDocsList: any[] = [];
  let totalSessionsCount = 0;
  let totalDevicesCount = 0;
  const allCrashes: any[] = [];
  const allReports: any[] = [];

  if (db) {
    // 1. Lấy danh sách toàn bộ người dùng
    const usersSnap = await db.collection('users').get();
    for (const uDoc of usersSnap.docs) {
      const uData = uDoc.data();
      const userId = uDoc.id;

      rawDocsList.push({
        collection: 'users',
        id: userId,
        path: `users/${userId}`,
        data: uData,
        updatedAt: sanitizeTimestamp(uData.createdAt),
        sizeBytes: JSON.stringify(uData).length,
      });

      // Sessions subcollection
      const sessions: any[] = [];
      try {
        const sessSnap = await uDoc.ref.collection('sessions').get();
        sessSnap.forEach(sDoc => {
          const sData = sDoc.data();
          totalSessionsCount++;
          rawDocsList.push({
            collection: `users/${userId}/sessions`,
            id: sDoc.id,
            path: `users/${userId}/sessions/${sDoc.id}`,
            data: sData,
            updatedAt: sanitizeTimestamp(sData.lastAccess || sData.lastLogin),
            sizeBytes: JSON.stringify(sData).length,
          });
          sessions.push({
            id: sDoc.id,
            deviceName: sData.deviceName || 'Không rõ thiết bị',
            os: sData.os || 'Android/iOS',
            location: sData.location || 'Chưa cập nhật',
            isActive: sData.isActive ?? true,
            isTrusted: sData.isTrusted ?? true,
            fcmToken: sData.fcmToken || 'Chưa tạo',
            lastLogin: sanitizeTimestamp(sData.lastLogin),
            firstSeen: sanitizeTimestamp(sData.firstSeen),
            lastAccess: sanitizeTimestamp(sData.lastAccess),
            appVersion: sData.appVersion || '1.7.14',
            buildNumber: sData.buildNumber || 184,
            raw: sData,
          });
        });
      } catch (_) {}

      // Crash logs subcollection
      try {
        const uCrashSnap = await uDoc.ref.collection('crash_logs').get();
        uCrashSnap.forEach(cDoc => {
          const cData = cDoc.data();
          allCrashes.push({
            id: cDoc.id,
            path: `users/${userId}/crash_logs/${cDoc.id}`,
            userId,
            userName: uData.displayName || userId,
            userEmail: uData.email || '',
            timestamp: sanitizeTimestamp(cData.timestamp || cData.createdAt),
            errorTitle: cData.errorTitle || 'Ngoại lệ không xác định',
            errorMessage: cData.errorMessage || String(cData),
            severity: cData.severity || 'error',
            stackTrace: cData.stackTrace || '',
            deviceModel: cData.deviceModel || sessions[0]?.deviceName || 'Thiết bị di động',
            osVersion: cData.osVersion || sessions[0]?.os || 'OS',
            appVersion: cData.appVersion || '1.7.14',
            source: cData.source || 'flutter_app',
            isResolved: cData.isResolved ?? false,
            raw: cData,
          });
        });
      } catch (_) {}

      const rawDevicesList = Array.isArray(uData.devices) ? uData.devices : [];
      totalDevicesCount += rawDevicesList.length;
      const parsedDevices = rawDevicesList.map((d: any, idx: number) => ({
        id: d.id || `dev_${idx}`,
        name: d.name || `Kênh ${idx + 1}`,
        pin: typeof d.pin === 'number' ? d.pin : idx,
        type: d.type || 'relay',
        isOn: d.isOn ?? false,
        room: d.room || 'Phòng chính',
        powerWatts: d.powerWatts || 45,
      }));

      fetchedCustomers.push({
        id: userId,
        uid: uData.uid || userId,
        displayName: uData.displayName || userId,
        email: uData.email || 'Không có email',
        phoneNumber: uData.phoneNumber || 'Chưa cập nhật',
        macAddress: uData.macAddress || 'Chưa liên kết',
        createdAt: sanitizeTimestamp(uData.createdAt),
        devices: parsedDevices,
        sessions,
        crashLogs: allCrashes.filter(c => c.userId === userId),
        rawDoc: uData,
      });
    }

    // 2. Top-level crash_logs
    try {
      const topCrashSnap = await db.collection('crash_logs').orderBy('timestamp', 'desc').limit(100).get();
      topCrashSnap.forEach(cd => {
        const cdData = cd.data();
        if (!allCrashes.some(c => c.id === cd.id)) {
          allCrashes.push({
            id: cd.id,
            path: `crash_logs/${cd.id}`,
            userId: cdData.userId || 'Hệ thống',
            userName: cdData.userName || cdData.userId || 'Người dùng',
            userEmail: cdData.userEmail || '',
            timestamp: sanitizeTimestamp(cdData.timestamp || cdData.createdAt),
            errorTitle: cdData.errorTitle || 'Lỗi hệ thống',
            errorMessage: cdData.errorMessage || '',
            severity: cdData.severity || 'error',
            stackTrace: cdData.stackTrace || '',
            deviceModel: cdData.deviceModel || 'N/A',
            osVersion: cdData.osVersion || 'N/A',
            appVersion: cdData.appVersion || '1.7.14',
            source: cdData.source || 'flutter_app',
            isResolved: cdData.isResolved ?? false,
            raw: cdData,
          });
        }
      });
    } catch (_) {}

    // 3. Top-level bug_reports
    try {
      const repSnap = await db.collection('bug_reports').get();
      repSnap.forEach(rd => {
        const rData = rd.data();
        rawDocsList.push({
          collection: 'bug_reports',
          id: rd.id,
          path: `bug_reports/${rd.id}`,
          data: rData,
          updatedAt: sanitizeTimestamp(rData.createdAt),
          sizeBytes: JSON.stringify(rData).length,
        });
        allReports.push({
          id: rd.id,
          userId: rData.userId || 'Ẩn danh',
          authorName: rData.authorName || 'Người dùng ZenHome',
          contactInfo: rData.contactInfo || 'Chưa cung cấp',
          category: rData.category || 'other',
          title: rData.title || 'Báo cáo sự cố',
          description: rData.description || '',
          deviceModel: rData.deviceModel || 'N/A',
          appVersion: rData.appVersion || 'N/A',
          buildNumber: rData.buildNumber,
          status: rData.status || 'open',
          createdAt: sanitizeTimestamp(rData.createdAt),
          raw: rData,
        });
      });
    } catch (_) {}
  }

  let latestAppVersion = appVersionData.latestVersion;
  let latestBuildNumber = appVersionData.latestBuildNumber;
  try {
    if (db) {
      const verSnap = await db.collection('system_config').doc('app_version').get();
      if (verSnap.exists && verSnap.data()) {
        const vData = verSnap.data()!;
        latestAppVersion = vData.latestVersion || latestAppVersion;
        latestBuildNumber = Number(vData.latestBuildNumber) || latestBuildNumber;
      }
    }
  } catch (_) {}

  const stats = {
    totalCustomers: fetchedCustomers.length,
    totalSessions: totalSessionsCount,
    totalDevices: totalDevicesCount,
    totalCrashes: allCrashes.length,
    totalReports: allReports.length,
    onlineEspCount: fetchedCustomers.filter(c => c.macAddress && c.macAddress !== 'Chưa liên kết').length,
    latestAppVersion: `v${latestAppVersion}`,
    latestBuildNumber: latestBuildNumber,
  };

  return {
    success: true,
    customers: fetchedCustomers,
    crashLogs: allCrashes,
    bugReports: allReports,
    databaseDocs: rawDocsList,
    stats,
  };
}

/**
 * @route   GET /api/v1/system/dashboard-sync
 * @desc    Đồng bộ dữ liệu quản trị toàn diện (Users, Sessions, Devices, Crash Logs, Bug Reports) cho Web Admin
 *          Được bảo vệ bởi bộ đệm in-memory (4s TTL) và cơ chế khử trùng lặp Request (Deduplication)
 */
systemRouter.get('/dashboard-sync', requireAdminAuth, async (req: Request, res: Response) => {
  const startTime = Date.now();
  const isForced = req.query.force === 'true' || req.headers['cache-control'] === 'no-cache';

  // 1. Phục vụ ngay từ bộ đệm RAM nếu còn trong thời hạn TTL (tiết kiệm 100% quota Firestore & CPU)
  if (!isForced && dashboardSyncCache && (Date.now() - dashboardSyncCache.cachedAt < SYNC_CACHE_TTL_MS)) {
    return res.json({
      ...dashboardSyncCache.data,
      cached: true,
      elapsedMs: Date.now() - startTime,
    });
  }

  try {
    // 2. Cơ chế khử trùng lặp: Nếu đang có một yêu cầu đọc Firestore đang chạy, tái sử dụng cùng Promise
    if (!activeSyncPromise) {
      activeSyncPromise = fetchFullDashboardData().finally(() => {
        activeSyncPromise = null;
      });
    }

    const result = await activeSyncPromise;

    // Cập nhật bộ đệm
    dashboardSyncCache = {
      data: result,
      cachedAt: Date.now(),
    };

    res.json({
      ...result,
      cached: false,
      elapsedMs: Date.now() - startTime,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @route   PATCH /api/v1/system/bug-reports/:id
 * @desc    Cập nhật trạng thái của bản ghi bug report
 */
systemRouter.patch('/bug-reports/:id', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    const { status = 'resolved' } = req.body;
    if (db) {
      await db.collection('bug_reports').doc(id).update({ status });
    }
    invalidateDashboardCache();
    res.json({ success: true, id, status });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   DELETE /api/v1/system/bug-reports/:id
 * @desc    Xóa bản ghi bug report khỏi Firestore
 */
systemRouter.delete('/bug-reports/:id', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const id = req.params.id as string;
    if (db) {
      await db.collection('bug_reports').doc(id).delete();
    }
    invalidateDashboardCache();
    res.json({ success: true, message: `Đã xóa báo cáo sự cố ${id}` });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   POST /api/v1/system/ai-diagnose
 * @desc    Phân tích nguyên nhân sự cố bằng Trí tuệ Nhân tạo (AI Diagnostics)
 */
systemRouter.post('/ai-diagnose', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const { errorTitle, errorMessage, stackTrace, deviceModel, osVersion, appVersion, userId, userName } = req.body;
    const diagnosis = await diagnoseCrashWithAi({
      errorTitle,
      errorMessage,
      stackTrace,
      deviceModel,
      osVersion,
      appVersion,
      userId,
      userName,
    });
    res.json({ success: true, diagnosis });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});

/**
 * @route   POST /api/v1/system/batch-resolve-crashes
 * @desc    Đánh dấu đã giải quyết hoặc xóa hàng loạt các lỗi đã được vá trong bản build mới
 */
systemRouter.post('/batch-resolve-crashes', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const { action = 'resolve', filterType = 'all' } = req.body;
    let modifiedCount = 0;

    if (db) {
      // 1. Top-level crash_logs
      const snap = await db.collection('crash_logs').get();
      const batch = db.batch();
      
      for (const doc of snap.docs) {
        const data = doc.data();
        const title = (data.errorTitle || '').toLowerCase();
        const msg = (data.errorMessage || '').toLowerCase();

        let shouldTouch = filterType === 'all';
        if (filterType === 'socket') {
          shouldTouch = title.includes('socket') || msg.includes('socket') || msg.includes('network');
        } else if (filterType === 'mqtt') {
          shouldTouch = title.includes('mqtt') || msg.includes('mqtt');
        }

        if (shouldTouch) {
          if (action === 'delete') {
            batch.delete(doc.ref);
          } else {
            batch.update(doc.ref, { isResolved: true, resolvedAt: new Date().toISOString() });
          }
          modifiedCount++;
        }
      }

      await batch.commit();

      // 2. User subcollections
      const userSnap = await db.collection('users').get();
      for (const u of userSnap.docs) {
        const uCrashes = await u.ref.collection('crash_logs').get();
        if (uCrashes.docs.length > 0) {
          const uBatch = db.batch();
          for (const cDoc of uCrashes.docs) {
            const data = cDoc.data();
            const title = (data.errorTitle || '').toLowerCase();
            const msg = (data.errorMessage || '').toLowerCase();

            let shouldTouch = filterType === 'all';
            if (filterType === 'socket') {
              shouldTouch = title.includes('socket') || msg.includes('socket');
            } else if (filterType === 'mqtt') {
              shouldTouch = title.includes('mqtt') || msg.includes('mqtt');
            }

            if (shouldTouch) {
              if (action === 'delete') {
                uBatch.delete(cDoc.ref);
              } else {
                uBatch.update(cDoc.ref, { isResolved: true, resolvedAt: new Date().toISOString() });
              }
              modifiedCount++;
            }
          }
          await uBatch.commit();
        }
      }
    }

    invalidateDashboardCache();
    addLog('[AI-CLEANUP]', `Đã ${action === 'delete' ? 'xóa' : 'đánh dấu khắc phục'} hàng loạt ${modifiedCount} bản ghi sự cố theo bộ lọc [${filterType}]`, 'info');
    res.json({ success: true, modifiedCount, message: `Đã xử lý ${modifiedCount} bản ghi sự cố thành công.` });
  } catch (e: any) {
    res.status(500).json({ success: false, error: e.message });
  }
});
