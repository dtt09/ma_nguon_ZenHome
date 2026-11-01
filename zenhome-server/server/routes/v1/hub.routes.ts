import { Router, Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

import { addLog, state } from '../../zenhomeState';
import { findUser } from '../../utils/firestoreHelper';
import { client } from '../../core/mqtt';
import { requireAuth, requireAdminAuth, checkUserPermission, checkOwnerOrAdminPermission } from '../../middlewares/auth';
import { validateMacAddress } from '../../middlewares/validation';
import { getCurrentServerConfig } from '../../core/networkSync';
import { db, FieldValue } from '../../core/firebase';

export const hubRouter = Router();

/**
 * @route   GET /api/v1/hub/ota/info
 * @desc    Lấy thông tin file binary firmware ESP32 hiện có trên Web Server (Công khai cho App & Thiết bị)
 */
hubRouter.get('/ota/info', async (req: Request, res: Response) => {
  try {
    const config = getCurrentServerConfig();
    const firmwareDir = path.resolve(__dirname, '../../../public/firmware/esp32');
    const firmwareFile = path.join(firmwareDir, 'firmware.bin');

    let exists = fs.existsSync(firmwareFile);
    let size = 0;
    let sha256 = '';
    let updatedAt = '';

    if (exists) {
      const stat = fs.statSync(firmwareFile);
      size = stat.size;
      updatedAt = stat.mtime.toISOString();
      const fileBuf = fs.readFileSync(firmwareFile);
      sha256 = crypto.createHash('sha256').update(fileBuf).digest('hex').toUpperCase();
    }

    let firestoreMeta: any = null;
    if (db) {
      try {
        const snap = await db.collection('system_config').doc('esp32_firmware').get();
        if (snap.exists) firestoreMeta = snap.data();
      } catch (e: any) {
        console.warn('[OTA] Không thể đọc Firestore esp32_firmware:', e.message);
      }
    }

    const directUrl = firestoreMeta?.directUrl || 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin';

    res.json({
      success: true,
      data: {
        exists: exists || Boolean(firestoreMeta?.directUrl),
        version: firestoreMeta?.version || '2.5.5',
        buildNumber: firestoreMeta?.buildNumber || 199,
        fileName: 'firmware.bin',
        fileSizeBytes: size || firestoreMeta?.fileSizeBytes || 1380048,
        sha256: sha256 || firestoreMeta?.sha256 || '3B4F069E0A74D34C6E38BF3037EB329F5DCAF32A0F90391F8722D0AE3D0E4F4D',
        directUrl,
        releaseNotesVi: firestoreMeta?.releaseNotesVi || '• Tối ưu luồng truyền nhận trạng thái MQTT thời gian thực\n• Cập nhật URL tải firmware GitHub Releases toàn cầu\n• Nâng cấp Dual-Boot A/B Safe Rollback chống brick vi điều khiển\n• Đảm bảo xác thực User & MAC bảo mật hai chiều',
        lastDeployedAt: firestoreMeta?.lastDeployedAt || updatedAt || new Date().toISOString(),
        supportedHardware: 'ESP32 (min_spiffs.csv dual OTA)',
      },
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @route   GET /api/v1/hub/verify-binding
 * @desc    Xác thực đồng nhất User & MAC giữa phần cứng ESP32 và cơ sở dữ liệu Firestore
 *          (Công khai cho vi điều khiển ESP32 gọi khi boot / kết nối Wi-Fi)
 */
hubRouter.get('/verify-binding', async (req: Request, res: Response) => {
  try {
    const userId = (req.query.userId as string || '').trim();
    const macAddress = (req.query.macAddress as string || req.query.mac as string || '').trim();

    if (!userId || !macAddress) {
      return res.status(400).json({
        success: false,
        valid: false,
        reason: 'MISSING_PARAMS',
        error: 'Thiếu tham số userId hoặc macAddress',
      });
    }

    const cleanMac = macAddress.replace(/[:\-]/g, '').toUpperCase();
    const isSetup = req.query.setup === '1';
    const reqAdminPass = (req.query.adminPass as string || req.query.pass as string || '').trim();
    const user = await findUser(userId);

    if (!user) {
      return res.json({
        success: true,
        valid: false,
        reason: 'USER_NOT_FOUND',
        message: `Tài khoản '${userId}' không tồn tại trong cơ sở dữ liệu.`,
        reqUser: userId,
        reqMac: cleanMac,
      });
    }

    const dbMacRaw = (user.data?.macAddress || '').trim();
    const dbMac = dbMacRaw.replace(/[:\-]/g, '').toUpperCase();
    const isDbUnlinked = (!dbMac || dbMac.length === 0 || dbMac === 'UNKNOWN' || dbMac === 'UNKNOWN_MAC');

    // Trường hợp 1: Database đang ở trạng thái CHƯA LIÊN KẾT (hoặc vừa hủy liên kết)
    if (isDbUnlinked) {
      const expectedPass = (user.data?.adminPass || '').trim();
      // Nếu tài khoản trong DB có mật khẩu admin và ESP32 truyền lên sai mật khẩu -> từ chối
      if (expectedPass && reqAdminPass && expectedPass !== reqAdminPass) {
        return res.json({
          success: true,
          valid: false,
          reason: 'ADMIN_PASS_INVALID',
          message: `Mật khẩu quản trị Hub không chính xác với tài khoản '${user.id}'.`,
          userId: user.id,
          reqMac: cleanMac,
        });
      }

      // ĐANG TRONG GIAI ĐOẠN SETUP PENDING:
      // Chỉ xác thực tài khoản & mật khẩu admin là hợp lệ, TUYỆT ĐỐI KHÔNG tự động ghi MAC
      // lên Firestore trước khi App và ESP32 hoàn tất Handshake 2 chiều (tránh liên kết ảo khi thất bại)!
      if (isSetup) {
        console.log(`[BACKEND] ⏳ [SETUP-VERIFY] ESP32 [${cleanMac}] đang trong tiến trình setup cho '${user.id}'. Xác thực hợp lệ (Chờ App hoàn tất Handshake).`);
        return res.json({
          success: true,
          valid: true,
          userId: user.id,
          macAddress: cleanMac,
          isPendingSetup: true,
          message: `Xác thực hợp lệ cho tài khoản '${user.id}'. Đang chờ App hoàn tất Handshake.`,
        });
      }

      // Tự động cập nhật MAC phần cứng lên Firestore cho User khi thiết bị đã provisioned trước đó
      if (db) {
        await db.collection('users').doc(user.id).set({
          macAddress: cleanMac,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        console.log(`[BACKEND] 🔗 [AUTO-BIND] Đã tự động gắn kết Hub [${cleanMac}] vào tài khoản '${user.id}' thành công!`);
      }

      return res.json({
        success: true,
        valid: true,
        userId: user.id,
        macAddress: cleanMac,
        isNewBinding: true,
        message: `Liên kết thành công! Phần cứng ESP32 [${cleanMac}] đã được gán làm Hub chính thức của tài khoản '${user.id}'.`,
      });
    }

    // Trường hợp 2: Database đã có MAC của một Hub khác
    if (dbMac !== cleanMac) {
      return res.json({
        success: true,
        valid: false,
        reason: 'MAC_MISMATCH',
        message: `Địa chỉ MAC trên Database [${dbMac}] không trùng khớp với phần cứng ESP32 [${cleanMac}]!`,
        userId: user.id,
        dbMac,
        reqMac: cleanMac,
      });
    }

    // Trường hợp 3: Trùng khớp 100%
    return res.json({
      success: true,
      valid: true,
      userId: user.id,
      macAddress: dbMac,
      message: `Xác thực thành công! Phần cứng ESP32 [${cleanMac}] thuộc sở hữu hợp lệ của tài khoản '${user.id}'.`,
    });
  } catch (error: any) {
    res.status(500).json({ success: false, valid: false, error: error.message });
  }
});

// Bắt buộc xác thực người dùng cho toàn bộ các thao tác quản lý Hub ESP32 (Zero-Trust Security - SEC-FIND-02)
hubRouter.use(requireAuth);

/**
 * @route   POST /api/v1/hub/notify-reset
 * @desc    Tiếp nhận thông báo ESP32 đã boot lại / Factory Reset về trạng thái chưa liên kết để tự động hủy liên kết trên Firestore & App
 *          YÊU CẦU XÁC THỰC: Chỉ Chủ sở hữu tài khoản (Owner) hoặc Quản trị viên (Admin) mới có quyền hủy liên kết!
 */
hubRouter.post('/notify-reset', async (req: Request, res: Response) => {
  try {
    const { macAddress } = req.body;
    if (!macAddress) {
      return res.status(400).json({ success: false, error: 'Thiếu thông tin macAddress' });
    }

    const cleanMac = macAddress.replace(/[:\-]/g, '').toUpperCase();
    if (!db) {
      return res.status(503).json({ success: false, error: 'Cơ sở dữ liệu Firestore chưa kết nối.' });
    }

    // Tìm tất cả các tài khoản đang gắn với MAC này
    const usersSnap = await db.collection('users').where('macAddress', '==', cleanMac).get();
    let unlinkedCount = 0;

    for (const doc of usersSnap.docs) {
      // BẢO VỆ CHỐNG IDOR / BOLA (SEC-FIND-02):
      // Chỉ chủ sở hữu tài khoản đó hoặc Quản trị viên mới được hủy liên kết Hub
      const isAuthorized = req.user?.role === 'admin' || req.user?.uid === doc.id || req.user?.uid === doc.data()?.uid;
      if (!isAuthorized) {
        console.warn(`[SECURITY VIOLATION] ⚠️ User [${req.user?.uid}] cố tình gửi yêu cầu hủy liên kết Hub của tài khoản khác [${doc.id}]!`);
        continue;
      }

      await doc.ref.update({
        macAddress: '',
        devices: [],
        updatedAt: new Date().toISOString(),
      });
      unlinkedCount++;
      addLog('[RESET-NOTIFY]', `⚡ Đã hủy liên kết Hub [${cleanMac}] khỏi tài khoản [${doc.id}] theo yêu cầu được xác thực của người dùng [${req.user?.uid}]!`, 'warn');
    }

    // Cũng kiểm tra tìm dạng MAC có dấu hai chấm nếu có
    const macWithColons = cleanMac.match(/.{1,2}/g)?.join(':') || cleanMac;
    if (macWithColons !== cleanMac) {
      const snap2 = await db.collection('users').where('macAddress', '==', macWithColons).get();
      for (const doc of snap2.docs) {
        const isAuthorized = req.user?.role === 'admin' || req.user?.uid === doc.id || req.user?.uid === doc.data()?.uid;
        if (!isAuthorized) {
          console.warn(`[SECURITY VIOLATION] ⚠️ User [${req.user?.uid}] cố tình gửi yêu cầu hủy liên kết Hub của tài khoản khác [${doc.id}]!`);
          continue;
        }

        await doc.ref.update({
          macAddress: '',
          devices: [],
          updatedAt: new Date().toISOString(),
        });
        unlinkedCount++;
        addLog('[RESET-NOTIFY]', `⚡ Đã hủy liên kết Hub [${macWithColons}] khỏi tài khoản [${doc.id}]!`, 'warn');
      }
    }

    res.json({
      success: true,
      message: `Đã xử lý thông báo boot lại / reset của Hub [${cleanMac}]. Hủy liên kết ${unlinkedCount} tài khoản.`,
      unlinkedCount,
      macAddress: cleanMac,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/hub/status
 * @desc    Lấy trạng thái kết nối THỰC TẾ của Hub ESP32 trung tâm (dựa trên DB và MQTT heartbeat)
 */
hubRouter.get('/status', async (req: Request, res: Response) => {
  try {
    const userIdQuery = (req.query.userId as string | undefined) || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(userIdQuery);

    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền truy cập trạng thái Hub của tài khoản này.' });
    }

    const mac = user.data.macAddress;
    const configuredDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];

    if (!mac || mac.trim() === '') {
      return res.json({
        success: true,
        hub: {
          userId: user.id,
          macAddress: null,
          connectionStatus: 'UNLINKED',
          message: 'Tài khoản chưa được liên kết với phần cứng ESP32 nào trong cơ sở dữ liệu.',
          totalConfiguredDevices: configuredDevices.length,
          activeSchedulesCount: Object.keys(state.activeSchedules || {}).length,
          activeTimersCount: Object.keys(state.activeTimers || {}).length,
        },
        timestamp: new Date().toISOString(),
      });
    }

    const onlineInfo = (mac && state.espOnlineStatus[mac]) || state.espOnlineStatus[user.id];
    const isOnline = Boolean(onlineInfo && onlineInfo.isOnline);
    const tempObj = state.latestIndoorTemp[user.id] || (mac ? state.latestIndoorTemp[mac] : null);

    res.json({
      success: true,
      hub: {
        userId: user.id,
        macAddress: mac,
        connectionStatus: isOnline ? 'ONLINE' : 'OFFLINE',
        lastSeen: onlineInfo?.lastSeen || null,
        indoorTemperatureCelsius: tempObj ? tempObj.temp : null,
        lastTelemetryTime: tempObj ? tempObj.updatedAt : null,
        totalConfiguredDevices: configuredDevices.length,
        configuredDevices: configuredDevices.map(d => ({
          id: d.id,
          name: d.name,
          room: d.room,
          ...(req.user?.role === 'admin' ? { pin: d.pin } : {}),
        })),
        activeSchedulesCount: Object.keys(state.activeSchedules || {}).length,
        activeTimersCount: Object.keys(state.activeTimers || {}).length,
        mqttBroker: 'ZenHome Secure IoT Gateway (TLS)',
        message: isOnline
          ? 'Hub ESP32 đang trực tuyến và giao tiếp ổn định qua kênh MQTT.'
          : 'Hub ESP32 đang ngoại tuyến (có thể đang mất điện hoặc mất kết nối Wi-Fi).',
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/hub/link
 * @desc    Liên kết địa chỉ MAC của phần cứng ESP32 vào tài khoản người dùng trong Firestore
 */
hubRouter.post('/link', async (req: Request, res: Response) => {
  try {
    const { userId, macAddress } = req.body;

    const macValidation = validateMacAddress(macAddress);
    if (!macValidation.valid) {
      return res.status(400).json({ success: false, error: macValidation.error });
    }
    const cleanMac = macValidation.normalized!;

    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkOwnerOrAdminPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Chỉ Chủ nhà hoặc Quản trị viên mới có quyền liên kết thiết bị cho tài khoản này.' });
    }

    await user.ref.update({
      macAddress: cleanMac,
      updatedAt: new Date().toISOString(),
    });

    addLog('[BACKEND]', `Đã liên kết MAC [${cleanMac}] với tài khoản [${user.id}] trong Firestore`, 'info');

    res.json({
      success: true,
      message: `Đã liên kết thành công Hub ESP32 (${cleanMac}) với tài khoản '${user.id}'!`,
      userId: user.id,
      macAddress: cleanMac,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/hub/unlink
 * @desc    Hủy liên kết Hub ESP32 khỏi tài khoản trong Firestore
 */
hubRouter.post('/unlink', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);

    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkOwnerOrAdminPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Chỉ Chủ nhà hoặc Quản trị viên mới có quyền hủy liên kết phần cứng của tài khoản này.' });
    }

    const oldMac = user.data.macAddress;
    await user.ref.update({
      macAddress: '',
      updatedAt: new Date().toISOString(),
    });

    addLog('[BACKEND]', `Đã hủy liên kết MAC [${oldMac}] khỏi tài khoản [${user.id}] trong Firestore`, 'warn');

    res.json({
      success: true,
      message: `Đã hủy liên kết Hub ESP32 khỏi tài khoản '${user.id}' thành công!`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/hub/reset
 * @desc    Gửi lệnh Factory Reset từ xa tới thiết bị ESP32 thực tế qua kênh MQTT bảo mật
 */
hubRouter.post('/reset', async (req: Request, res: Response) => {
  try {
    const { userId } = req.body;
    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);

    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkOwnerOrAdminPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Chỉ Chủ nhà hoặc Quản trị viên mới có quyền gửi lệnh Factory Reset tới phần cứng của tài khoản này.' });
    }

    const mac = user.data.macAddress;
    if (!mac || mac.trim() === '') {
      return res.status(400).json({
        success: false,
        error: `Tài khoản '${user.id}' chưa liên kết với Hub ESP32 nào để có thể gửi lệnh Reset.`,
      });
    }

    const prefix = `${user.id}/${mac}`;
    const resetTopic = `${prefix}/system/reset`;

    if (client && client.connected) {
      const resetPayload = JSON.stringify({
        action: 'factory_reset',
        admin_pass: user.data?.adminPass || 'admin',
        server_authorized: true,
        timestamp: Date.now(),
      });
      client.publish(resetTopic, resetPayload);
      addLog('[RESET]', `Gửi tín hiệu Factory Reset bảo mật xuống ESP32 qua topic: ${resetTopic} bởi ${req.user?.uid || 'Admin'}`, 'warn');
    } else {
      return res.status(503).json({ success: false, error: 'Máy chủ hiện chưa kết nối được tới MQTT Broker để phát lệnh reset.' });
    }

    res.json({
      success: true,
      message: `Đã phát lệnh Factory Reset từ xa tới thiết bị ESP32 (${prefix}) thành công!`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/hub/config
 * @desc    Đẩy cấu hình ánh xạ chân linh hoạt (Dynamic Pin Mapping) xuống LittleFS của ESP32
 */
hubRouter.post('/config', async (req: Request, res: Response) => {
  try {
    const { userId, devices } = req.body;

    if (!devices || !Array.isArray(devices)) {
      return res.status(400).json({ success: false, error: "Trường 'devices' phải là mảng cấu hình thiết bị [{ id, pin }]" });
    }

    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkOwnerOrAdminPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Chỉ Chủ nhà hoặc Quản trị viên mới có quyền nạp cấu hình phần cứng cho tài khoản này.' });
    }

    const mac = user.data.macAddress;
    if (!mac || mac.trim() === '') {
      return res.status(400).json({
        success: false,
        error: `Tài khoản '${user.id}' chưa liên kết với Hub ESP32 nào để nạp cấu hình phần cứng.`,
      });
    }

    const prefix = `${user.id}/${mac}`;
    const configTopic = `${prefix}/system/config`;
    const payload = JSON.stringify(devices);

    if (client && client.connected) {
      client.publish(configTopic, payload);
      addLog('[ESP]', `Đẩy bản đồ cấu hình chân mới xuống LittleFS của ESP32 (${devices.length} thiết bị)`, 'info');
    } else {
      return res.status(503).json({ success: false, error: 'MQTT Broker đang ngoại tuyến.' });
    }

    res.json({
      success: true,
      message: `Đã nạp bản đồ chân phần cứng mới xuống ESP32 thành công! ESP32 sẽ tự cập nhật flash LittleFS và khởi động lại.`,
      devicesCount: devices.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/hub/ota/trigger
 * @desc    Phát lệnh qua MQTT yêu cầu Hub ESP32 tải firmware từ Web Server và nâng cấp OTA
 */
hubRouter.post('/ota/trigger', async (req: Request, res: Response) => {
  try {
    const { userId, macAddress, version } = req.body;
    const config = getCurrentServerConfig();
    const firmwareDir = path.resolve(__dirname, '../../../public/firmware/esp32');
    const firmwareFile = path.join(firmwareDir, 'firmware.bin');

    if (!fs.existsSync(firmwareFile)) {
      return res.status(404).json({
        success: false,
        error: 'Chưa có file firmware.bin trên máy chủ. Vui lòng tải lên firmware trước!',
      });
    }

    const stat = fs.statSync(firmwareFile);
    const fileBuf = fs.readFileSync(firmwareFile);
    const sha256 = crypto.createHash('sha256').update(fileBuf).digest('hex').toUpperCase();

    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(targetUserId);

    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkOwnerOrAdminPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Chỉ Chủ nhà hoặc Quản trị viên mới có quyền kích hoạt OTA cho tài khoản này.' });
    }

    const targetMac = macAddress || user.data.macAddress;
    if (!targetMac || targetMac.trim() === '') {
      return res.status(400).json({ success: false, error: 'Hub chưa liên kết địa chỉ MAC để gửi lệnh OTA!' });
    }

    const cleanMac = targetMac.replace(/[:\-]/g, '').toUpperCase();
    const formattedMac = cleanMac.match(/.{1,2}/g)?.join(':') || targetMac;
    let firestoreFwMeta: any = null;
    if (db) {
      try {
        const snap = await db.collection('system_config').doc('esp32_firmware').get();
        if (snap.exists) firestoreFwMeta = snap.data();
      } catch (e: any) {
        console.warn('[OTA] Không thể đọc Firestore esp32_firmware:', e.message);
      }
    }
    const directUrl = req.body.url || firestoreFwMeta?.directUrl || 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin';

    const adminPass = req.body.adminPass || user.data?.adminPass || 'admin';
    const otaPayload = {
      action: 'ota_update',
      url: directUrl,
      version: version || firestoreFwMeta?.version || '2.5.5',
      sha256: sha256 || firestoreFwMeta?.sha256 || '3B4F069E0A74D34C6E38BF3037EB329F5DCAF32A0F90391F8722D0AE3D0E4F4D',
      size: stat.size,
      admin_pass: adminPass,
      server_authorized: true,
      timestamp: new Date().toISOString(),
    };

    if (client && client.connected) {
      const payloadStr = JSON.stringify(otaPayload);
      // Phát đa topic để ESP32 bắt được 100% bất kể prefix dùng MAC có dấu hai chấm hay không
      const topics = [
        `${user.id}/${cleanMac}/system/ota_update`,
        `${user.id}/${formattedMac}/system/ota_update`,
        `${user.id.toLowerCase()}/${cleanMac}/system/ota_update`,
        `${user.id.toLowerCase()}/${formattedMac}/system/ota_update`,
      ];
      if (userId && userId !== user.id) {
        topics.push(`${userId}/${cleanMac}/system/ota_update`);
        topics.push(`${userId}/${formattedMac}/system/ota_update`);
      }
      for (const t of topics) {
        client.publish(t, payloadStr);
      }
      addLog('[OTA]', `🚀 Đã phát lệnh nâng cấp Firmware OTA tới Hub [${cleanMac}] (${directUrl})`, 'info');
    } else {
      return res.status(503).json({ success: false, error: 'MQTT Broker đang ngoại tuyến.' });
    }

    res.json({
      success: true,
      message: `Đã phát lệnh nâng cấp Firmware OTA tới Hub (${cleanMac}) thành công! Hub sẽ tự động tải và flash.`,
      data: otaPayload,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @route   POST /api/v1/hub/ota/upload
 * @desc    Tải lên file firmware binary (.bin) mới lên Server (Yêu cầu Admin Auth)
 */
hubRouter.post('/ota/upload', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const { base64Data, version, buildNumber } = req.body;
    if (!base64Data) {
      return res.status(400).json({ success: false, error: 'Thiếu dữ liệu base64Data của file firmware' });
    }

    const firmwareDir = path.resolve(__dirname, '../../../public/firmware/esp32');
    if (!fs.existsSync(firmwareDir)) {
      fs.mkdirSync(firmwareDir, { recursive: true });
    }

    const firmwareFile = path.join(firmwareDir, 'firmware.bin');
    const buffer = Buffer.from(base64Data, 'base64');
    fs.writeFileSync(firmwareFile, buffer);

    const sha256 = crypto.createHash('sha256').update(buffer).digest('hex').toUpperCase();
    const config = getCurrentServerConfig();
    const directUrl = `${config.serverBaseUrl}/public/firmware/esp32/firmware.bin`;

    const meta = {
      version: version || '1.7.9',
      buildNumber: Number(buildNumber) || 178,
      fileName: 'firmware.bin',
      fileSizeBytes: buffer.length,
      sha256,
      directUrl,
      lastDeployedAt: new Date().toISOString(),
    };

    if (db) {
      await db.collection('system_config').doc('esp32_firmware').set(meta, { merge: true });
    }

    addLog('[OTA]', `📦 Đã tải lên và lưu trữ Firmware ESP32 mới (v${meta.version}, ${buffer.length} bytes)`, 'info');

    res.json({
      success: true,
      message: 'Đã tải lên và xuất bản Firmware ESP32 thành công!',
      data: meta,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @route   POST /api/v1/hub/ota/deploy-build
 * @desc    Tự động triển khai file build gần nhất từ PlatformIO lên Server OTA pool (Yêu cầu Admin Auth)
 */
hubRouter.post('/ota/deploy-build', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const buildPath = path.resolve(__dirname, '../../../../esp32_1/.pio/build/esp32dev/firmware.bin');
    if (!fs.existsSync(buildPath)) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy file firmware.bin được biên dịch trong esp32_1/.pio/build' });
    }

    const firmwareDir = path.resolve(__dirname, '../../../public/firmware/esp32');
    if (!fs.existsSync(firmwareDir)) {
      fs.mkdirSync(firmwareDir, { recursive: true });
    }

    const firmwareFile = path.join(firmwareDir, 'firmware.bin');
    fs.copyFileSync(buildPath, firmwareFile);

    const buffer = fs.readFileSync(firmwareFile);
    const sha256 = crypto.createHash('sha256').update(buffer).digest('hex').toUpperCase();
    const config = getCurrentServerConfig();
    const directUrl = `${config.serverBaseUrl}/public/firmware/esp32/firmware.bin`;

    const meta = {
      version: req.body?.version || '1.7.9',
      buildNumber: req.body?.buildNumber || 179,
      fileName: 'firmware.bin',
      fileSizeBytes: buffer.length,
      sha256,
      directUrl,
      lastDeployedAt: new Date().toISOString(),
    };

    if (db) {
      await db.collection('system_config').doc('esp32_firmware').set(meta, { merge: true });
    }

    addLog('[OTA]', `⚡ Triển khai bản build PlatformIO gần nhất vào kho OTA Server (${buffer.length} bytes)`, 'info');

    res.json({
      success: true,
      message: 'Đã triển khai bản build PlatformIO vào kho OTA Server thành công!',
      data: meta,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

/**
 * @route   POST /api/v1/hub/ota/publish
 * @desc    Xuất bản và phát hành phiên bản Firmware ESP32 mới từ Web Admin (Yêu cầu Admin Auth)
 */
hubRouter.post('/ota/publish', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const { 
      version, 
      buildNumber, 
      directUrl, 
      sha256: reqSha256, 
      fileSizeBytes: reqSize, 
      releaseNotesVi, 
      triggerFleetOta 
    } = req.body;

    const firmwareDir = path.resolve(__dirname, '../../../public/firmware/esp32');
    const firmwareFile = path.join(firmwareDir, 'firmware.bin');
    let localExists = fs.existsSync(firmwareFile);
    let localSize = 0;
    let localSha256 = '';

    if (localExists) {
      try {
        const stat = fs.statSync(firmwareFile);
        localSize = stat.size;
        const buf = fs.readFileSync(firmwareFile);
        localSha256 = crypto.createHash('sha256').update(buf).digest('hex').toUpperCase();
      } catch (readErr: any) {
        console.warn('[OTA] Không thể đọc file firmware local:', readErr.message);
      }
    }

    const finalVersion = (version || '2.5.5').trim();
    const finalBuildNumber = Number(buildNumber) || 199;
    const finalDirectUrl = (directUrl || 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin').trim();
    const finalSha256 = (reqSha256 || localSha256 || '3B4F069E0A74D34C6E38BF3037EB329F5DCAF32A0F90391F8722D0AE3D0E4F4D').trim();
    const finalSize = Number(reqSize) || localSize || 1380048;
    const finalNotes = (releaseNotesVi || '').trim();
    const nowIso = new Date().toISOString();

    const meta = {
      version: finalVersion,
      buildNumber: finalBuildNumber,
      directUrl: finalDirectUrl,
      sha256: finalSha256,
      fileSizeBytes: finalSize,
      fileName: 'firmware.bin',
      releaseNotesVi: finalNotes,
      lastDeployedAt: nowIso,
      supportedHardware: 'ESP32 (min_spiffs.csv dual OTA)',
      publishedAt: nowIso,
    };

    if (db) {
      try {
        await db.collection('system_config').doc('esp32_firmware').set(meta, { merge: true });
      } catch (dbErr: any) {
        console.warn('[OTA] Không thể ghi metadata vào Firestore esp32_firmware:', dbErr.message);
      }
    }

    addLog('[OTA]', `🚀 Đã phát hành phiên bản Firmware ESP32 v${finalVersion} (Build ${finalBuildNumber})!`, 'success');

    let dispatchedCount = 0;
    if (triggerFleetOta && client && client.connected) {
      try {
        let customersToNotify: { userId: string; macAddress: string }[] = [];
        if (db) {
          const snap = await db.collection('users').get();
          for (const doc of snap.docs) {
            const data = doc.data();
            if (data.macAddress && data.macAddress.trim() !== '') {
              customersToNotify.push({ userId: doc.id, macAddress: data.macAddress.trim() });
            }
          }
        }

        const otaPayload = JSON.stringify({
          action: 'ota_update',
          url: finalDirectUrl,
          version: finalVersion,
          sha256: finalSha256,
          size: finalSize,
          admin_pass: 'admin',
          server_authorized: true,
          timestamp: nowIso,
        });

        for (const item of customersToNotify) {
          const cleanMac = item.macAddress.replace(/[:\-]/g, '').toUpperCase();
          const formattedMac = cleanMac.match(/.{1,2}/g)?.join(':') || item.macAddress;
          const topics = [
            `${item.userId}/${cleanMac}/system/ota_update`,
            `${item.userId}/${formattedMac}/system/ota_update`,
            `${item.userId.toLowerCase()}/${cleanMac}/system/ota_update`,
            `${item.userId.toLowerCase()}/${formattedMac}/system/ota_update`,
          ];
          for (const t of topics) {
            client.publish(t, otaPayload);
          }
          dispatchedCount++;
        }

        addLog('[OTA]', `📡 Đã phát tín hiệu OTA toàn đội tàu (Fleet OTA) tới ${dispatchedCount} Hub ESP32`, 'info');
      } catch (fleetErr: any) {
        console.warn('[OTA] Lỗi khi broadcast Fleet OTA:', fleetErr.message);
      }
    }

    res.json({
      success: true,
      message: `Đã phát hành Firmware ESP32 v${finalVersion} (Build ${finalBuildNumber}) thành công!${dispatchedCount > 0 ? ` Đã gửi lệnh OTA tới ${dispatchedCount} Hub.` : ''}`,
      data: meta,
      dispatchedCount,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});
