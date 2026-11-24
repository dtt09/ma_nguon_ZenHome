import { Router, Request, Response } from 'express';
import { state, addLog } from '../../zenhomeState';
import { sendCommandWithRetry } from '../../zenhomeWorker';
import {
  saveScheduleToFirebase,
  deleteScheduleFromFirebase,
  askScheduleStatus,
  getCurrentVietnamTimeInfo,
  getNextUpcomingSchedule,
} from '../../core/schedules';
import { requireAuth, checkUserPermission } from '../../middlewares/auth';
import { findUser } from '../../utils/firestoreHelper';

export const schedulesRouter = Router();

// Bắt buộc xác thực người dùng cho toàn bộ phân hệ Lịch Trình (Zero-Trust Security)
schedulesRouter.use(requireAuth);

/**
 * @route   GET /api/v1/schedules
 * @desc    Lấy danh sách lịch trình tự động của một ngôi nhà cụ thể (ZH-HIGH-06: Chống IDOR toàn diện)
 */
schedulesRouter.get('/', async (req: Request, res: Response) => {
  try {
    const homeId = (req.query.home_id as string || req.query.homeId as string || req.query.userId as string || (req.user?.role === 'user' ? req.user.uid : undefined))?.trim();

    if (!homeId && req.user?.role !== 'admin') {
      return res.status(400).json({
        success: false,
        error: "Bắt buộc cung cấp tham số 'home_id' để truy vấn danh sách lịch trình của ngôi nhà.",
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
          error: 'Forbidden: Bạn không có quyền truy cập lịch trình của ngôi nhà này.',
        });
      }
    }

    const allSchedules = Object.entries(state.activeSchedules).map(([key, item]) => ({
      id: key,
      baseTopic: item.baseTopic,
      timeOn: item.timeOn || null,
      timeOff: item.timeOff || null,
      days: item.days,
      isTriggeredOn: item.isTriggeredOn || false,
      isTriggeredOff: item.isTriggeredOff || false,
    }));

    // Lọc theo người dùng/ngôi nhà đã xác thực (Admin không truyền home_id sẽ xem tất cả)
    const list = user
      ? allSchedules.filter(s => {
          const topicPrefix = s.baseTopic?.split('/')[0];
          return topicPrefix === user.id || topicPrefix === user.data?.uid || s.id.startsWith(user.id) || (user.data?.macAddress && s.baseTopic?.includes(user.data.macAddress));
        })
      : allSchedules;

    const nextUpcoming = getNextUpcomingSchedule();

    res.json({
      success: true,
      totalSchedules: list.length,
      nextUpcoming,
      schedules: list,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/schedules/query
 * @desc    Cơ chế Hỏi - Trả Lời: Hỏi trạng thái lịch trình tại thời điểm cụ thể hoặc hiện tại (ZH-HIGH-06)
 */
schedulesRouter.get('/query', async (req: Request, res: Response) => {
  try {
    const timeParam = req.query.time as string;
    const dayParam = req.query.day !== undefined ? parseInt(req.query.day as string, 10) : undefined;
    const topicParam = req.query.topic as string;
    const homeId = (req.query.home_id as string || req.query.homeId as string || req.query.userId as string || (req.user?.role === 'user' ? req.user.uid : undefined))?.trim();

    if (!homeId && !topicParam && req.user?.role !== 'admin') {
      return res.status(400).json({
        success: false,
        error: "Bắt buộc cung cấp tham số 'home_id' hoặc 'topic' để truy vấn.",
      });
    }

    const targetHome = homeId || (topicParam ? topicParam.split('/')[0] : undefined);
    if (targetHome) {
      const user = await findUser(targetHome);
      if (!user) {
        return res.status(404).json({ success: false, error: `Không tìm thấy ngôi nhà/người dùng '${targetHome}'.` });
      }
      if (!checkUserPermission(req, user)) {
        return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền truy vấn lịch trình của ngôi nhà này.' });
      }
    }

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
 * @desc    Cơ chế Hỏi - Trả Lời tương tác: Kiểm tra và tùy chọn kích hoạt ngay nếu có lịch khớp (ZH-HIGH-06)
 */
schedulesRouter.post('/query-check', async (req: Request, res: Response) => {
  try {
    const { time, day, topic, home_id, homeId, userId, execute = false } = req.body;
    const targetHome = (home_id || homeId || userId || (topic ? topic.split('/')[0] : (req.user?.role === 'user' ? req.user.uid : undefined)))?.trim();

    if (!targetHome && req.user?.role !== 'admin') {
      return res.status(400).json({
        success: false,
        error: "Bắt buộc cung cấp tham số 'home_id' hoặc 'topic' để kiểm tra lịch trình.",
      });
    }

    if (targetHome) {
      const user = await findUser(targetHome);
      if (!user) {
        return res.status(404).json({ success: false, error: `Không tìm thấy ngôi nhà/người dùng '${targetHome}'.` });
      }
      if (!checkUserPermission(req, user)) {
        return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền thao tác trên ngôi nhà này.' });
      }
    }

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
 * @desc    Tạo lịch trình tự động mới (ZH-HIGH-06: Chống IDOR bằng cách xác thực quyền trên home_id và baseTopic)
 */
schedulesRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { baseTopic, timeOn, timeOff, days = '1111111', scheduleId = `SCH_${Date.now()}`, home_id, homeId, userId } = req.body;

    if (!baseTopic) {
      return res.status(400).json({ success: false, error: "Thiếu trường 'baseTopic' (Ví dụ: Dtthuat/ESP32_MAC/phong_khach/den_tran)" });
    }

    if (!timeOn && !timeOff) {
      return res.status(400).json({ success: false, error: "Phải cung cấp ít nhất 'timeOn' (HH:mm) hoặc 'timeOff' (HH:mm)." });
    }

    const targetHome = (home_id || homeId || userId || baseTopic.split('/')[0])?.trim();
    const user = await findUser(targetHome);
    if (!user) {
      return res.status(404).json({ success: false, error: `Không tìm thấy tài khoản/ngôi nhà '${targetHome}' trong cơ sở dữ liệu.` });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền tạo lịch trình cho ngôi nhà này.' });
    }

    // Xác thực baseTopic phải thuộc về người dùng/ngôi nhà này
    const topicPrefix = baseTopic.split('/')[0];
    if (topicPrefix !== user.id && topicPrefix !== user.data?.uid && req.user?.role !== 'admin') {
      return res.status(403).json({
        success: false,
        error: `Forbidden: 'baseTopic' (${baseTopic}) không khớp với tài khoản sở hữu (${user.id}).`,
      });
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

    // Lưu vào Firestore thông qua schedules core
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
 * @desc    Xóa hoặc hủy kích hoạt một lịch trình (ZH-HIGH-06: Xác thực quyền chủ nhà)
 */
schedulesRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const existing = state.activeSchedules[id];

    // Xác định chủ sở hữu từ activeSchedules hoặc từ id hoặc từ query home_id
    const scheduleTopic = existing?.baseTopic || id.replace(/___SCH_.*$/, '').replace(/___/g, '/');
    const topicOwner = scheduleTopic.split('/')[0];
    const targetHome = (req.query.home_id as string || req.query.homeId as string || req.query.userId as string || topicOwner)?.trim();

    const user = await findUser(targetHome);
    if (!user) {
      return res.status(404).json({ success: false, error: `Không tìm thấy tài khoản/ngôi nhà '${targetHome}' liên quan đến lịch trình này.` });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền xóa lịch trình của ngôi nhà này.' });
    }

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
