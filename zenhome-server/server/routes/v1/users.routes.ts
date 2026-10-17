import { Router, Request, Response } from 'express';
import { db, findUser } from '../../utils/firestoreHelper';
import { addLog } from '../../zenhomeState';

export const usersRouter = Router();

/**
 * @route   GET /api/v1/users
 * @desc    Lấy danh sách tất cả tài khoản người dùng thực tế trong hệ thống Firestore
 */
usersRouter.get('/', async (req: Request, res: Response) => {
  try {
    const snap = await db.collection('users').get();
    const users = snap.docs.map(doc => {
      const data = doc.data();
      const devices = Array.isArray(data.devices) ? data.devices : [];
      return {
        id: doc.id,
        uid: data.uid || null,
        displayName: data.displayName || doc.id,
        email: data.email || null,
        phoneNumber: data.phoneNumber || null,
        macAddress: data.macAddress || null,
        deviceCount: devices.length,
        devices: devices.map((d: any) => ({ id: d.id, name: d.name, room: d.room, pin: d.pin })),
        birthday: data.birthday || null,
        createdAt: data.createdAt || null,
      };
    });

    res.json({
      success: true,
      totalUsers: users.length,
      users,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/users/:userId
 * @desc    Lấy hồ sơ chi tiết người dùng và danh sách phiên đăng nhập (sessions) từ Firestore
 */
usersRouter.get('/:userId', async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const user = await findUser(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy tài khoản người dùng '${userId}' trong cơ sở dữ liệu.`,
      });
    }

    const userData = user.data;
    const devices = Array.isArray(userData.devices) ? userData.devices : [];

    // Lấy các phiên đăng nhập di động thực tế từ subcollection 'sessions'
    let sessions: any[] = [];
    try {
      const sessSnap = await user.ref.collection('sessions').get();
      sessions = sessSnap.docs.map(s => ({
        sessionId: s.id,
        ...s.data(),
      }));
    } catch (err) {
      // Bỏ qua nếu chưa có subcollection
    }

    res.json({
      success: true,
      data: {
        id: user.id,
        uid: userData.uid || null,
        displayName: userData.displayName || user.id,
        email: userData.email || null,
        phoneNumber: userData.phoneNumber || null,
        macAddress: userData.macAddress || null,
        birthday: userData.birthday || null,
        totalDevices: devices.length,
        devices,
        totalSessions: sessions.length,
        sessions,
        createdAt: userData.createdAt || null,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   PUT /api/v1/users/:userId
 * @desc    Cập nhật thông tin hồ sơ người dùng trong Firestore
 */
usersRouter.put('/:userId', async (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const { displayName, phoneNumber, macAddress, birthday, language } = req.body;

    const user = await findUser(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy tài khoản người dùng '${userId}' trong cơ sở dữ liệu.`,
      });
    }

    const updates: any = { updatedAt: new Date().toISOString() };
    if (displayName !== undefined) updates.displayName = displayName.trim();
    if (phoneNumber !== undefined) updates.phoneNumber = phoneNumber.trim();
    if (macAddress !== undefined) updates.macAddress = macAddress.trim();
    if (birthday !== undefined) updates.birthday = birthday.trim();
    if (language !== undefined) {
      const normalizedLang = String(language).trim().toLowerCase();
      if (normalizedLang === 'vi' || normalizedLang === 'en') {
        updates.language = normalizedLang;
      }
    }

    await user.ref.update(updates);

    addLog('[BACKEND]', `Cập nhật hồ sơ người dùng [${user.id}] trong Firestore.`, 'info');

    res.json({
      success: true,
      message: `Đã cập nhật hồ sơ người dùng '${user.id}' thành công!`,
      data: {
        id: user.id,
        ...user.data,
        ...updates,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
