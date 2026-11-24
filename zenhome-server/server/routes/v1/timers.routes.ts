import { Router, Request, Response } from 'express';
import { state, addLog } from '../../zenhomeState';
import { setTimer } from '../../core/timers';
import { requireAuth, checkUserPermission } from '../../middlewares/auth';
import { findUser } from '../../utils/firestoreHelper';

export const timersRouter = Router();

// Bắt buộc xác thực người dùng cho toàn bộ phân hệ Hẹn Giờ (Zero-Trust Security)
timersRouter.use(requireAuth);

/**
 * @route   GET /api/v1/timers
 * @desc    Lấy danh sách tất cả hẹn giờ đếm ngược đang kích hoạt của một ngôi nhà (ZH-HIGH-07: Chống IDOR)
 */
timersRouter.get('/', async (req: Request, res: Response) => {
  try {
    const homeId = (req.query.home_id as string || req.query.homeId as string || req.query.userId as string || (req.user?.role === 'user' ? req.user.uid : undefined))?.trim();

    if (!homeId && req.user?.role !== 'admin') {
      return res.status(400).json({
        success: false,
        error: "Bắt buộc cung cấp tham số 'home_id' để truy vấn danh sách hẹn giờ của ngôi nhà.",
      });
    }

    let user: any = null;
    if (homeId) {
      user = await findUser(homeId);
      if (!user) {
        return res.status(404).json({
          success: false,
          error: `Không tìm thấy ngôi nhà/người dùng '${homeId}' trong cơ sở dữ liệu.`,
        });
      }
      if (!checkUserPermission(req, user)) {
        return res.status(403).json({
          success: false,
          error: 'Forbidden: Bạn không có quyền truy cập bộ hẹn giờ của ngôi nhà này.',
        });
      }
    }

    const allTimers = Object.entries(state.activeTimers).map(([key, timer]) => ({
      timerKey: key,
      baseTopic: (timer as any)?.baseTopic || key.replace(/_(on|off)$/, ''),
      action: key.endsWith('_on') ? '1' : '0',
      type: key.endsWith('_on') ? 'BẬT' : 'TẮT',
    }));

    const list = user
      ? allTimers.filter(t => {
          const topicPrefix = t.baseTopic?.split('/')[0];
          return topicPrefix === user.id || topicPrefix === user.data?.uid || (user.data?.macAddress && t.baseTopic?.includes(user.data.macAddress));
        })
      : allTimers;

    res.json({
      success: true,
      totalTimers: list.length,
      timers: list,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/timers
 * @desc    Tạo hẹn giờ đếm ngược tự động Bật/Tắt thiết bị (ZH-HIGH-07: Xác thực quyền chủ nhà)
 */
timersRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { baseTopic, action = '0', minutes, home_id, homeId, userId } = req.body;

    if (!baseTopic) {
      return res.status(400).json({ success: false, error: "Thiếu trường 'baseTopic' (Ví dụ: Dtthuat/ESP32_MAC/phong_khach/quat_tran)" });
    }

    const minsNum = parseInt(minutes, 10);
    if (isNaN(minsNum) || minsNum <= 0) {
      return res.status(400).json({ success: false, error: "Trường 'minutes' phải là số nguyên dương lớn hơn 0." });
    }

    const targetHome = (home_id || homeId || userId || baseTopic.split('/')[0])?.trim();
    const user = await findUser(targetHome);
    if (!user) {
      return res.status(404).json({ success: false, error: `Không tìm thấy tài khoản/ngôi nhà '${targetHome}' trong cơ sở dữ liệu.` });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền đặt hẹn giờ cho ngôi nhà này.' });
    }

    const topicPrefix = baseTopic.split('/')[0];
    if (topicPrefix !== user.id && topicPrefix !== user.data?.uid && req.user?.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: `Forbidden: 'baseTopic' (${baseTopic}) không khớp với tài khoản sở hữu (${user.id}).`,
      });
    }

    const actionStr = (action === '1' || action === true) ? '1' : '0';

    setTimer(baseTopic, actionStr, minsNum);

    addLog('[TIMER]', `API tạo hẹn giờ: ${actionStr === '1' ? 'BẬT' : 'TẮT'} ${baseTopic} sau ${minsNum} phút`, 'info');

    res.json({
      success: true,
      message: `Đã thiết lập hẹn giờ ${actionStr === '1' ? 'BẬT' : 'TẮT'} sau ${minsNum} phút thành công!`,
      timer: {
        baseTopic,
        action: actionStr,
        minutes: minsNum,
        triggerAtEstimated: new Date(Date.now() + minsNum * 60000).toISOString(),
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   DELETE /api/v1/timers/:timerKey
 * @desc    Hủy một hẹn giờ đếm ngược (ZH-HIGH-07: Xác thực quyền chủ nhà)
 */
timersRouter.delete('/:timerKey', async (req: Request, res: Response) => {
  try {
    const timerKey = String(req.params.timerKey);
    const baseTopic = timerKey.replace(/_(on|off)$/, '');
    const action = timerKey.endsWith('_on') ? '1' : '0';

    const topicOwner = baseTopic.split('/')[0];
    const targetHome = (req.query.home_id as string || req.query.homeId as string || req.query.userId as string || topicOwner)?.trim();

    const user = await findUser(targetHome);
    if (!user) {
      return res.status(404).json({ success: false, error: `Không tìm thấy tài khoản/ngôi nhà '${targetHome}' liên quan đến bộ hẹn giờ này.` });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền hủy hẹn giờ của ngôi nhà này.' });
    }

    setTimer(baseTopic, action, 0);

    addLog('[TIMER]', `API hủy hẹn giờ: ${timerKey}`, 'info');

    res.json({
      success: true,
      message: `Đã hủy hẹn giờ ${timerKey} thành công!`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
