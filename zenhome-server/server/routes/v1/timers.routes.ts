import { Router, Request, Response } from 'express';
import { state, addLog } from '../../zenhomeState';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { setTimer } = require('../../core/timers.cjs');

export const timersRouter = Router();

/**
 * @route   GET /api/v1/timers
 * @desc    Lấy danh sách tất cả hẹn giờ đếm ngược đang kích hoạt
 */
timersRouter.get('/', (req: Request, res: Response) => {
  const list = Object.entries(state.activeTimers).map(([key, timer]) => ({
    timerKey: key,
    baseTopic: (timer as any)?.baseTopic || key.replace(/_(on|off)$/, ''),
    action: key.endsWith('_on') ? '1' : '0',
    type: key.endsWith('_on') ? 'BẬT' : 'TẮT',
  }));

  res.json({
    success: true,
    totalTimers: list.length,
    timers: list,
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   POST /api/v1/timers
 * @desc    Tạo hẹn giờ đếm ngược tự động Bật/Tắt thiết bị (Ví dụ: Tắt quạt sau 30 phút)
 */
timersRouter.post('/', (req: Request, res: Response) => {
  try {
    const { baseTopic, action = '0', minutes } = req.body;

    if (!baseTopic) {
      return res.status(400).json({ success: false, error: "Thiếu trường 'baseTopic' (Ví dụ: Dtthuat/ESP32_MAC/phong_khach/quat_tran)" });
    }

    const minsNum = parseInt(minutes, 10);
    if (isNaN(minsNum) || minsNum <= 0) {
      return res.status(400).json({ success: false, error: "Trường 'minutes' phải là số nguyên dương lớn hơn 0." });
    }

    const actionStr = (action === '1' || action === true) ? '1' : '0';

    // Gọi hàm setTimer của module core timers.cjs
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
 * @desc    Hủy một hẹn giờ đếm ngược
 */
timersRouter.delete('/:timerKey', (req: Request, res: Response) => {
  try {
    const { timerKey } = req.params;
    const baseTopic = timerKey.replace(/_(on|off)$/, '');
    const action = timerKey.endsWith('_on') ? '1' : '0';

    // mins = 0 để hủy timer trong core timers.cjs
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
