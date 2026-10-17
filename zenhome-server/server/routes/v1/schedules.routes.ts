import { Router, Request, Response } from 'express';
import { state, addLog } from '../../zenhomeState';
import { sendCommandWithRetry } from '../../zenhomeWorker';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const {
  saveScheduleToFirebase,
  deleteScheduleFromFirebase,
  askScheduleStatus,
  getCurrentVietnamTimeInfo,
  getNextUpcomingSchedule,
} = require('../../core/schedules.cjs');

export const schedulesRouter = Router();

/**
 * @route   GET /api/v1/schedules
 * @desc    Lấy danh sách tất cả lịch trình tự động bật/tắt đang hoạt động
 */
schedulesRouter.get('/', (req: Request, res: Response) => {
  const list = Object.entries(state.activeSchedules).map(([key, item]) => ({
    id: key,
    baseTopic: item.baseTopic,
    timeOn: item.timeOn || null,
    timeOff: item.timeOff || null,
    days: item.days, // VD: "1111111" hoặc "0,1,2,3,4,5,6"
    isTriggeredOn: item.isTriggeredOn || false,
    isTriggeredOff: item.isTriggeredOff || false,
  }));

  const nextUpcoming = getNextUpcomingSchedule();

  res.json({
    success: true,
    totalSchedules: list.length,
    nextUpcoming,
    schedules: list,
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   GET /api/v1/schedules/query
 * @desc    Cơ chế Hỏi - Trả Lời: Hỏi trạng thái lịch trình tại thời điểm cụ thể hoặc hiện tại
 */
schedulesRouter.get('/query', (req: Request, res: Response) => {
  try {
    const timeParam = req.query.time as string;
    const dayParam = req.query.day !== undefined ? parseInt(req.query.day as string, 10) : undefined;
    const topicParam = req.query.topic as string;

    const result = askScheduleStatus({
      targetTime: timeParam,
      targetDayIndex: dayParam,
      filterTopic: topicParam,
      execute: false,
      callerTag: '[API-QA]'
    });

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/schedules/query-check
 * @desc    Cơ chế Hỏi - Trả Lời tương tác: Kiểm tra và tùy chọn kích hoạt ngay nếu có lịch khớp
 */
schedulesRouter.post('/query-check', (req: Request, res: Response) => {
  try {
    const { time, day, topic, execute = false } = req.body;

    const result = askScheduleStatus({
      targetTime: time,
      targetDayIndex: day !== undefined ? parseInt(day, 10) : undefined,
      filterTopic: topic,
      execute: Boolean(execute),
      sendCommandFn: sendCommandWithRetry,
      callerTag: '[API-QA-CHECK]'
    });

    if (execute && result.answer.matchedCount > 0) {
      addLog('[CRON-QA]', `API Hỏi - Trả lời: Kích hoạt ${result.answer.matchedCount} lịch trình tại ${result.question.targetTime}`, 'success');
    }

    res.json(result);
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/schedules/next
 * @desc    Lấy thông tin đếm ngược đến lần kích hoạt lịch trình gần nhất trong tương lai
 */
schedulesRouter.get('/next', (req: Request, res: Response) => {
  const next = getNextUpcomingSchedule();
  res.json({
    success: true,
    currentTime: getCurrentVietnamTimeInfo(),
    nextUpcoming: next,
    hasUpcoming: Boolean(next),
    timestamp: new Date().toISOString(),
  });
});

/**
 * @route   POST /api/v1/schedules
 * @desc    Tạo lịch trình tự động mới
 */
schedulesRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { baseTopic, timeOn, timeOff, days = '1111111', scheduleId = `SCH_${Date.now()}` } = req.body;

    if (!baseTopic) {
      return res.status(400).json({ success: false, error: "Thiếu trường 'baseTopic' (Ví dụ: Dtthuat/ESP32_MAC/phong_khach/den_tran)" });
    }

    if (!timeOn && !timeOff) {
      return res.status(400).json({ success: false, error: "Phải cung cấp ít nhất 'timeOn' (HH:mm) hoặc 'timeOff' (HH:mm)." });
    }

    const uniqueScheduleKey = `${baseTopic.replace(/\//g, '___')}___${scheduleId}`;
    const scheduleData = {
      baseTopic,
      timeOn,
      timeOff,
      days,
    };

    state.activeSchedules[uniqueScheduleKey] = {
      ...scheduleData,
      isTriggeredOn: false,
      isTriggeredOff: false,
    };

    // Lưu vào Firestore thông qua schedules.cjs
    await saveScheduleToFirebase(uniqueScheduleKey, scheduleData);

    addLog('[CRON-QA]', `Thêm lịch trình mới: ${baseTopic} [Bật: ${timeOn || '--'} | Tắt: ${timeOff || '--'}]`, 'info');

    res.json({
      success: true,
      message: 'Tạo lịch trình tự động thành công (Đã nạp vào RAM và đồng bộ Firestore)!',
      schedule: {
        id: uniqueScheduleKey,
        ...scheduleData,
      },
      nextUpcoming: getNextUpcomingSchedule(),
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   DELETE /api/v1/schedules/:id
 * @desc    Xóa hoặc hủy kích hoạt một lịch trình
 */
schedulesRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    if (state.activeSchedules[id]) {
      delete state.activeSchedules[id];
    }

    await deleteScheduleFromFirebase(id);

    addLog('[CRON-QA]', `Đã xóa lịch trình: ${id}`, 'info');

    res.json({
      success: true,
      message: `Đã xóa lịch trình ${id} thành công!`,
      nextUpcoming: getNextUpcomingSchedule(),
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
