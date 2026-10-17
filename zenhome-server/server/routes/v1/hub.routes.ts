import { Router, Request, Response } from 'express';
import { addLog, state } from '../../zenhomeState';
import { findUser } from '../../utils/firestoreHelper';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const client = require('../../core/mqtt.cjs');

export const hubRouter = Router();

/**
 * @route   GET /api/v1/hub/status
 * @desc    Lấy trạng thái kết nối THỰC TẾ của Hub ESP32 trung tâm (dựa trên DB và MQTT heartbeat)
 */
hubRouter.get('/status', async (req: Request, res: Response) => {
  try {
    const userIdQuery = req.query.userId as string | undefined;
    const user = await findUser(userIdQuery);

    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
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
        configuredDevices: configuredDevices.map(d => ({ id: d.id, name: d.name, pin: d.pin, room: d.room })),
        activeSchedulesCount: Object.keys(state.activeSchedules || {}).length,
        activeTimersCount: Object.keys(state.activeTimers || {}).length,
        mqttBroker: 'HiveMQ Cloud TLS (Port 8883)',
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

    if (!macAddress || typeof macAddress !== 'string' || macAddress.trim() === '') {
      return res.status(400).json({ success: false, error: "Trường 'macAddress' là bắt buộc (Ví dụ: 'ESP32_WROOM_32_4C75' hoặc '24:6F:28:XX:XX:XX')." });
    }

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    const cleanMac = macAddress.trim();
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

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
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

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
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
      client.publish(resetTopic, '1');
      addLog('[RESET]', `Gửi tín hiệu Factory Reset xuống ESP32 qua topic: ${resetTopic}`, 'warn');
    } else {
      return res.status(503).json({ success: false, error: 'Máy chủ hiện chưa kết nối được tới MQTT Broker để phát lệnh reset.' });
    }

    res.json({
      success: true,
      message: `Đã phát lệnh Factory Reset từ xa tới thiết bị ESP32 (${prefix}) thành công!`,
      topic: resetTopic,
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

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
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
      topic: configTopic,
      devicesCount: devices.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
