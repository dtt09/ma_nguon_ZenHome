import { Router, Request, Response } from 'express';
import { sendCommandWithRetry } from '../../zenhomeWorker';
import { state, addLog } from '../../zenhomeState';
import { findUser, FieldValue } from '../../utils/firestoreHelper';

export const devicesRouter = Router();

/**
 * @route   GET /api/v1/devices
 * @desc    Lấy danh sách tất cả thiết bị THỰC TẾ từ cơ sở dữ liệu Firestore
 */
devicesRouter.get('/', async (req: Request, res: Response) => {
  try {
    const userIdQuery = req.query.userId as string | undefined;
    const user = await findUser(userIdQuery);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: userIdQuery
          ? `Không tìm thấy tài khoản người dùng '${userIdQuery}' trong cơ sở dữ liệu.`
          : 'Hệ thống chưa có tài khoản người dùng nào trong cơ sở dữ liệu.',
      });
    }

    const userMac = user.data.macAddress || '';
    const rawDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];

    // Cập nhật trạng thái tức thời từ pendingTasks / active state trong RAM nếu đang chờ sync
    const mapped = rawDevices.map(dev => {
      const stateTopic = `${user.id}/${userMac || 'ESP32_MAC'}/${dev.room}/${dev.id}/state`;
      const isPending = state.pendingTasks && state.pendingTasks[stateTopic];
      return {
        ...dev,
        state: isPending ? isPending.targetState === '1' : Boolean(dev.state),
        isPending: Boolean(isPending),
        topic: `${user.id}/${userMac || 'ESP32_MAC'}/${dev.room}/${dev.id}`,
      };
    });

    res.json({
      success: true,
      data: {
        userId: user.id,
        userDisplayName: user.data.displayName || user.id,
        macAddress: userMac || null,
        totalDevices: mapped.length,
        devices: mapped,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/devices
 * @desc    Thêm một thiết bị mới vào Firestore cho người dùng
 */
devicesRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { userId, id, name, room, pin, icon = 'switch' } = req.body;

    if (!name || typeof name !== 'string' || name.trim() === '') {
      return res.status(400).json({ success: false, error: "Trường 'name' (Tên thiết bị) là bắt buộc." });
    }

    if (!room || typeof room !== 'string' || room.trim() === '') {
      return res.status(400).json({ success: false, error: "Trường 'room' (Phòng) là bắt buộc." });
    }

    if (pin === undefined || pin === null || isNaN(Number(pin))) {
      return res.status(400).json({ success: false, error: "Trường 'pin' (Chân relay 0-7 hoặc GPIO) là bắt buộc." });
    }

    const pinNum = Number(pin);
    const user = await findUser(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy tài khoản người dùng '${userId || 'mặc định'}' trong cơ sở dữ liệu.`,
      });
    }

    const existingDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];

    // Tạo deviceId chuẩn hóa nếu không truyền
    const devId = (id && typeof id === 'string' && id.trim() !== '')
      ? id.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_')
      : `dev_${Date.now()}`;

    // Kiểm tra trùng lặp ID
    if (existingDevices.some(d => d.id === devId)) {
      return res.status(409).json({
        success: false,
        error: `Thiết bị có mã '${devId}' đã tồn tại trong danh sách của bạn.`,
      });
    }

    // Kiểm tra trùng lặp chân Pin
    const pinConflict = existingDevices.find(d => Number(d.pin) === pinNum);
    if (pinConflict) {
      return res.status(400).json({
        success: false,
        error: `Chân Pin ${pinNum} đã được gán cho thiết bị '${pinConflict.name}'. Vui lòng chọn chân khác.`,
      });
    }

    const newDevice = {
      id: devId,
      name: name.trim(),
      room: room.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_'),
      pin: pinNum,
      icon: icon.trim(),
      state: false,
      createdAt: new Date().toISOString(),
    };

    // Lưu thiết bị thực vào Firestore
    await user.ref.update({
      devices: FieldValue.arrayUnion(newDevice),
    });

    addLog('[BACKEND]', `Thêm thiết bị mới: [${newDevice.name}] (Pin: ${newDevice.pin}, Phòng: ${newDevice.room}) cho user ${user.id}`, 'info');

    res.status(201).json({
      success: true,
      message: `Đã thêm thiết bị '${newDevice.name}' vào cơ sở dữ liệu thành công!`,
      device: newDevice,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/devices/:id
 * @desc    Lấy thông tin chi tiết một thiết bị thực tế từ cơ sở dữ liệu
 */
devicesRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const userIdQuery = req.query.userId as string | undefined;
    const user = await findUser(userIdQuery);

    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    const rawDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];
    const device = rawDevices.find(d => d.id === id);

    if (!device) {
      return res.status(404).json({
        success: false,
        error: `Thiết bị có ID '${id}' không tồn tại trong danh sách của người dùng '${user.id}'.`,
      });
    }

    const userMac = user.data.macAddress || 'ESP32_MAC';
    const baseTopic = `${user.id}/${userMac}/${device.room}/${device.id}`;
    const stateTopic = `${baseTopic}/state`;
    const isPending = state.pendingTasks && state.pendingTasks[stateTopic];

    res.json({
      success: true,
      data: {
        ...device,
        userId: user.id,
        macAddress: userMac,
        baseTopic,
        state: isPending ? isPending.targetState === '1' : Boolean(device.state),
        pendingSync: Boolean(isPending),
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   PUT /api/v1/devices/:id
 * @desc    Cập nhật thông tin thiết bị (tên, phòng, chân pin, icon) trong cơ sở dữ liệu
 */
devicesRouter.put('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { userId, name, room, pin, icon } = req.body;

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    const rawDevices: any[] = Array.isArray(user.data.devices) ? [...user.data.devices] : [];
    const index = rawDevices.findIndex(d => d.id === id);

    if (index === -1) {
      return res.status(404).json({
        success: false,
        error: `Thiết bị có ID '${id}' không tồn tại trong cơ sở dữ liệu của người dùng.`,
      });
    }

    // Nếu đổi pin, kiểm tra trùng lặp với thiết bị khác
    if (pin !== undefined && pin !== null) {
      const pinNum = Number(pin);
      const conflict = rawDevices.find((d, idx) => idx !== index && Number(d.pin) === pinNum);
      if (conflict) {
        return res.status(400).json({
          success: false,
          error: `Chân Pin ${pinNum} đã được dùng bởi thiết bị '${conflict.name}'.`,
        });
      }
      rawDevices[index].pin = pinNum;
    }

    if (name) rawDevices[index].name = name.trim();
    if (room) rawDevices[index].room = room.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_');
    if (icon) rawDevices[index].icon = icon.trim();
    rawDevices[index].updatedAt = new Date().toISOString();

    await user.ref.update({ devices: rawDevices });

    addLog('[BACKEND]', `Cập nhật thông tin thiết bị [${id}] trong cơ sở dữ liệu.`, 'info');

    res.json({
      success: true,
      message: `Đã cập nhật thiết bị '${rawDevices[index].name}' thành công!`,
      device: rawDevices[index],
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   DELETE /api/v1/devices/:id
 * @desc    Xóa thiết bị khỏi cơ sở dữ liệu Firestore
 */
devicesRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const userIdQuery = (req.query.userId || req.body.userId) as string | undefined;

    const user = await findUser(userIdQuery);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    const rawDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];
    const target = rawDevices.find(d => d.id === id);

    if (!target) {
      return res.status(404).json({
        success: false,
        error: `Thiết bị có ID '${id}' không tồn tại trong cơ sở dữ liệu để xóa.`,
      });
    }

    const remaining = rawDevices.filter(d => d.id !== id);
    await user.ref.update({ devices: remaining });

    addLog('[BACKEND]', `Đã xóa thiết bị [${target.name} - ${id}] khỏi cơ sở dữ liệu của user ${user.id}`, 'warn');

    res.json({
      success: true,
      message: `Đã xóa thiết bị '${target.name}' khỏi cơ sở dữ liệu thành công!`,
      deletedDeviceId: id,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/devices/:id/control
 * @desc    Gửi lệnh điều khiển Bật (1) hoặc Tắt (0) chỉ cho thiết bị THỰC TẾ có trong database
 */
devicesRouter.post('/:id/control', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const { state: targetState, userId, source = 'api_client' } = req.body;

    if (targetState !== '1' && targetState !== '0' && targetState !== true && targetState !== false) {
      return res.status(400).json({
        success: false,
        error: "Trường 'state' phải là '1' (Bật) hoặc '0' (Tắt), hoặc boolean true/false.",
      });
    }

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy người dùng '${userId || 'mặc định'}' trong cơ sở dữ liệu.`,
      });
    }

    // Kiểm tra tính xác thực: Thiết bị phải tồn tại trong cơ sở dữ liệu Firestore của user
    const rawDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];
    const device = rawDevices.find(d => d.id === id);

    if (!device) {
      return res.status(404).json({
        success: false,
        error: `Từ chối lệnh điều khiển: Thiết bị '${id}' không tồn tại trong danh sách thiết bị đã đăng ký của người dùng '${user.id}'. Vui lòng thêm thiết bị vào database trước.`,
      });
    }

    const stateStr = (targetState === '1' || targetState === true) ? '1' : '0';
    const macAddress = user.data.macAddress || 'ESP32_MAC';
    const baseTopic = `${user.id}/${macAddress}/${device.room}/${device.id}`;

    // Kích hoạt hàm điều khiển có Retry Engine của ZenHome
    sendCommandWithRetry(baseTopic, stateStr, source);

    addLog('[SEND]', `API gửi lệnh: ${device.name} (${baseTopic}) -> ${stateStr === '1' ? 'BẬT' : 'TẮT'} (Nguồn: ${source})`, 'info');

    res.json({
      success: true,
      message: `Đã phát lệnh điều khiển ${stateStr === '1' ? 'BẬT' : 'TẮT'} tới thiết bị '${device.name}' thành công!`,
      data: {
        id: device.id,
        name: device.name,
        room: device.room,
        pin: device.pin,
        baseTopic,
        targetState: stateStr,
        source,
        retryScheduled: true,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/devices/bulk
 * @desc    Điều khiển hàng loạt chỉ các thiết bị THỰC TẾ có trong database
 */
devicesRouter.post('/bulk', async (req: Request, res: Response) => {
  try {
    const { action, room, userId, source = 'api_bulk' } = req.body;

    if (!['all_on', 'all_off', 'room_on', 'room_off'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: "Trường 'action' phải là một trong: 'all_on', 'all_off', 'room_on', 'room_off'",
      });
    }

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    const rawDevices: any[] = Array.isArray(user.data.devices) ? user.data.devices : [];
    if (rawDevices.length === 0) {
      return res.status(400).json({
        success: false,
        error: `Người dùng '${user.id}' chưa thiết lập thiết bị nào trong cơ sở dữ liệu để thực hiện điều khiển hàng loạt.`,
      });
    }

    let targetDevices = [...rawDevices];
    if (action.startsWith('room_')) {
      if (!room) {
        return res.status(400).json({ success: false, error: "Hành động theo phòng yêu cầu cung cấp trường 'room'." });
      }
      targetDevices = targetDevices.filter(d => d.room === room);
      if (targetDevices.length === 0) {
        return res.status(400).json({
          success: false,
          error: `Không tìm thấy thiết bị nào trong phòng '${room}' trong cơ sở dữ liệu.`,
        });
      }
    }

    const targetState = action.endsWith('_on') ? '1' : '0';
    const macAddress = user.data.macAddress || 'ESP32_MAC';

    // Gửi lệnh điều khiển thực tế cho từng thiết bị
    for (const dev of targetDevices) {
      const baseTopic = `${user.id}/${macAddress}/${dev.room}/${dev.id}`;
      sendCommandWithRetry(baseTopic, targetState, source);
    }

    addLog('[SEND]', `API Điều khiển hàng loạt (${action}): Gửi lệnh tới ${targetDevices.length} thiết bị thực tế của user ${user.id}`, 'info');

    res.json({
      success: true,
      message: `Đã gửi lệnh ${targetState === '1' ? 'BẬT' : 'TẮT'} đồng loạt cho ${targetDevices.length} thiết bị thực tế!`,
      affectedDevicesCount: targetDevices.length,
      affectedDevices: targetDevices.map(d => ({ id: d.id, name: d.name, room: d.room, pin: d.pin })),
      action,
      targetState,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/devices/telemetry/status
 * @desc    Lấy dữ liệu cảm biến thời gian thực CHÍNH XÁC (không số ảo)
 */
devicesRouter.get('/telemetry/status', async (req: Request, res: Response) => {
  try {
    const userIdQuery = req.query.userId as string | undefined;
    const user = await findUser(userIdQuery);

    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    const mac = user.data.macAddress || null;
    const onlineInfo = (mac && state.espOnlineStatus[mac]) || state.espOnlineStatus[user.id];
    const isOnline = Boolean(onlineInfo && onlineInfo.isOnline);
    const tempObj = state.latestIndoorTemp[user.id] || (mac ? state.latestIndoorTemp[mac] : null);
    const lastAlertTime = state.lastTempAlert && state.lastTempAlert[user.id]
      ? new Date(state.lastTempAlert[user.id]).toISOString()
      : null;

    res.json({
      success: true,
      data: {
        userId: user.id,
        macAddress: mac,
        hubStatus: isOnline ? 'ONLINE' : (mac ? 'OFFLINE' : 'UNLINKED'),
        lastSeen: onlineInfo?.lastSeen || null,
        indoorTemperatureCelsius: tempObj ? tempObj.temp : null,
        temperatureUnit: '°C',
        safetyStatus: tempObj
          ? (tempObj.temp >= 50.0 ? 'FIRE_ALERT_DANGER' : 'SAFE_NORMAL')
          : 'WAITING_FOR_DATA',
        highTempThreshold: 50.0,
        lastTelemetryTime: tempObj ? tempObj.updatedAt : null,
        lastTempAlertTime: lastAlertTime,
        message: tempObj
          ? 'Dữ liệu nhiệt độ nhận được thời gian thực từ cảm biến DHT11.'
          : 'Chưa nhận được gói tin nhiệt độ từ phần cứng qua kênh MQTT.',
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
