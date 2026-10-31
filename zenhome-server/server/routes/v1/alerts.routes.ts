import { Router, Request, Response } from 'express';
import { findUser, FieldValue } from '../../utils/firestoreHelper';
import { addLog } from '../../zenhomeState';
import { requireAuth, checkUserPermission } from '../../middlewares/auth';

export const alertsRouter = Router();

// Bắt buộc xác thực người dùng cho toàn bộ phân hệ Cảnh báo & Lịch sử (Zero-Trust Security)
alertsRouter.use(requireAuth);

/**
 * @route   GET /api/v1/alerts
 * @desc    Lấy danh sách các cảnh báo an toàn hỏa hoạn và hệ thống THỰC TẾ từ Firestore
 */
alertsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const userIdQuery = (req.query.userId as string | undefined) || (req.user?.role === 'user' ? req.user.uid : undefined);
    const limitNum = Math.min(parseInt(req.query.limit as string, 10) || 50, 100);

    const user = await findUser(userIdQuery);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền truy cập cảnh báo của tài khoản này.' });
    }

    let alerts: any[] = [];
    try {
      const snapshot = await user.ref.collection('alerts').orderBy('timestamp', 'desc').limit(limitNum).get();
      alerts = snapshot.docs.map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (err) {
      // Fallback nếu chưa có index
      const snapshot = await user.ref.collection('alerts').limit(limitNum).get();
      alerts = snapshot.docs.map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      }));
    }

    res.json({
      success: true,
      userId: user.id,
      totalAlerts: alerts.length,
      alerts,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/alerts
 * @desc    Tạo bản ghi cảnh báo an toàn mới vào Firestore
 */
alertsRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { userId, type = 'SECURITY_FIRE', title, message, level = 'warning' } = req.body;

    if (!title || !message) {
      return res.status(400).json({ success: false, error: "Các trường 'title' và 'message' là bắt buộc." });
    }

    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền tạo cảnh báo cho tài khoản này.' });
    }

    const newAlert = {
      type,
      title: title.trim(),
      message: message.trim(),
      level,
      createdAt: new Date().toISOString(),
      timestamp: FieldValue.serverTimestamp(),
    };

    const docRef = await user.ref.collection('alerts').add(newAlert);

    addLog('[ALERT]', `Ghi nhận cảnh báo mới cho user ${user.id}: [${title}]`, level === 'danger' ? 'error' : 'warn');

    res.status(201).json({
      success: true,
      message: 'Đã lưu cảnh báo vào cơ sở dữ liệu thành công!',
      alert: {
        id: docRef.id,
        ...newAlert,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   DELETE /api/v1/alerts/:id
 * @desc    Xóa một bản ghi cảnh báo khỏi Firestore
 */
alertsRouter.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const userIdQuery = (req.query.userId || req.body.userId || (req.user?.role === 'user' ? req.user.uid : undefined)) as string | undefined;

    const user = await findUser(userIdQuery);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền xóa cảnh báo của tài khoản này.' });
    }

    const docRef = user.ref.collection('alerts').doc(id);
    const doc = await docRef.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, error: `Bản ghi cảnh báo '${id}' không tồn tại trong database.` });
    }

    await docRef.delete();

    res.json({
      success: true,
      message: `Đã xóa cảnh báo ${id} khỏi cơ sở dữ liệu thành công!`,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/alerts/history
 * @desc    Lấy nhật ký lịch sử đóng/ngắt thiết bị THỰC TẾ của người dùng từ Firestore
 */
alertsRouter.get('/history', async (req: Request, res: Response) => {
  try {
    const userIdQuery = (req.query.userId as string | undefined) || (req.user?.role === 'user' ? req.user.uid : undefined);
    const limitNum = Math.min(parseInt(req.query.limit as string, 10) || 50, 100);

    const user = await findUser(userIdQuery);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền truy cập lịch sử của tài khoản này.' });
    }

    let history: any[] = [];
    try {
      const snapshot = await user.ref.collection('history').orderBy('timestamp', 'desc').limit(limitNum).get();
      history = snapshot.docs.map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      }));
    } catch (err) {
      // Fallback nếu chưa có index
      const snapshot = await user.ref.collection('history').limit(limitNum).get();
      history = snapshot.docs.map((doc: any) => ({
        id: doc.id,
        ...doc.data(),
      }));
    }

    res.json({
      success: true,
      userId: user.id,
      totalRecords: history.length,
      history,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
