import { Router, Request, Response } from 'express';
import { sendCommandWithRetry } from '../../zenhomeWorker';
import { addLog } from '../../zenhomeState';
import { findUser } from '../../utils/firestoreHelper';
import { requireAuth, checkUserPermission } from '../../middlewares/auth';

export const scenesRouter = Router();

// Bắt buộc xác thực người dùng cho toàn bộ phân hệ Ngữ Cảnh Tự Động (Zero-Trust Security)
scenesRouter.use(requireAuth);

interface SceneAction {
  deviceId: string;
  room: string;
  state: '1' | '0' | boolean;
}

/**
 * @route   GET /api/v1/scenes
 * @desc    Lấy danh sách các kịch bản / ngữ cảnh thông minh THỰC TẾ từ Firestore
 */
scenesRouter.get('/', async (req: Request, res: Response) => {
  try {
    const userIdQuery = (req.query.userId as string | undefined) || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(userIdQuery);

    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền truy cập danh sách ngữ cảnh của tài khoản này.' });
    }

    const snap = await user.ref.collection('scenes').get();
    const scenes = snap.docs.map((doc: any) => ({
      id: doc.id,
      ...doc.data(),
    }));

    res.json({
      success: true,
      userId: user.id,
      totalScenes: scenes.length,
      scenes,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/scenes
 * @desc    Tạo mới một ngữ cảnh thông minh và lưu trực tiếp vào Firestore
 */
scenesRouter.post('/', async (req: Request, res: Response) => {
  try {
    const { userId, id, name, description, icon = 'home', color = '#10B981', actions } = req.body;

    if (!name || typeof name !== 'string' || name.trim() === '') {
      return res.status(400).json({ success: false, error: "Trường 'name' (Tên kịch bản) là bắt buộc." });
    }

    if (!actions || !Array.isArray(actions) || actions.length === 0) {
      return res.status(400).json({ success: false, error: "Trường 'actions' phải là mảng chứa ít nhất một hành động [{ deviceId, room, state }]." });
    }

    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);
    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền tạo ngữ cảnh cho tài khoản này.' });
    }

    const sceneId = (id && typeof id === 'string' && id.trim() !== '')
      ? id.trim().toLowerCase().replace(/[^a-z0-9_]/g, '_')
      : `scene_${Date.now()}`;

    const formattedActions = actions.map((act: SceneAction) => ({
      deviceId: act.deviceId,
      room: act.room,
      state: (act.state === '1' || act.state === true) ? '1' : '0',
    }));

    const sceneData = {
      name: name.trim(),
      description: description ? description.trim() : '',
      icon: icon.trim(),
      color: color.trim(),
      actions: formattedActions,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await user.ref.collection('scenes').doc(sceneId).set(sceneData);

    addLog('[BACKEND]', `Tạo ngữ cảnh mới: [${sceneData.name}] (${formattedActions.length} hành động) cho user ${user.id}`, 'info');

    res.status(201).json({
      success: true,
      message: `Đã lưu ngữ cảnh '${sceneData.name}' vào cơ sở dữ liệu thành công!`,
      scene: {
        id: sceneId,
        ...sceneData,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   GET /api/v1/scenes/:sceneId
 * @desc    Lấy chi tiết một ngữ cảnh thông minh từ Firestore
 */
scenesRouter.get('/:sceneId', async (req: Request, res: Response) => {
  try {
    const { sceneId } = req.params;
    const userIdQuery = (req.query.userId as string | undefined) || (req.user?.role === 'user' ? req.user.uid : undefined);

    const user = await findUser(userIdQuery);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền xem ngữ cảnh của tài khoản này.' });
    }

    const doc = await user.ref.collection('scenes').doc(sceneId).get();
    if (!doc.exists) {
      return res.status(404).json({
        success: false,
        error: `Không tìm thấy ngữ cảnh '${sceneId}' trong cơ sở dữ liệu của người dùng.`,
      });
    }

    res.json({
      success: true,
      data: {
        id: doc.id,
        ...doc.data(),
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   PUT /api/v1/scenes/:sceneId
 * @desc    Cập nhật ngữ cảnh trong Firestore
 */
scenesRouter.put('/:sceneId', async (req: Request, res: Response) => {
  try {
    const { sceneId } = req.params;
    const { userId, name, description, icon, color, actions } = req.body;
    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);

    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền cập nhật ngữ cảnh của tài khoản này.' });
    }

    const docRef = user.ref.collection('scenes').doc(sceneId);
    const doc = await docRef.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, error: `Ngữ cảnh '${sceneId}' không tồn tại trong database.` });
    }

    const updates: any = { updatedAt: new Date().toISOString() };
    if (name) updates.name = name.trim();
    if (description !== undefined) updates.description = description.trim();
    if (icon) updates.icon = icon.trim();
    if (color) updates.color = color.trim();
    if (actions && Array.isArray(actions)) {
      updates.actions = actions.map((act: SceneAction) => ({
        deviceId: act.deviceId,
        room: act.room,
        state: (act.state === '1' || act.state === true) ? '1' : '0',
      }));
    }

    await docRef.update(updates);

    res.json({
      success: true,
      message: `Đã cập nhật ngữ cảnh '${sceneId}' thành công!`,
      data: { id: sceneId, ...doc.data(), ...updates },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   DELETE /api/v1/scenes/:sceneId
 * @desc    Xóa một ngữ cảnh khỏi Firestore
 */
scenesRouter.delete('/:sceneId', async (req: Request, res: Response) => {
  try {
    const { sceneId } = req.params;
    const userIdQuery = (req.query.userId || req.body.userId || (req.user?.role === 'user' ? req.user.uid : undefined)) as string | undefined;

    const user = await findUser(userIdQuery);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền xóa ngữ cảnh của tài khoản này.' });
    }

    const docRef = user.ref.collection('scenes').doc(sceneId);
    const doc = await docRef.get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, error: `Ngữ cảnh '${sceneId}' không tồn tại để xóa.` });
    }

    await docRef.delete();

    addLog('[BACKEND]', `Đã xóa ngữ cảnh [${sceneId}] khỏi database của user ${user.id}`, 'info');

    res.json({
      success: true,
      message: `Đã xóa ngữ cảnh '${sceneId}' khỏi cơ sở dữ liệu thành công!`,
      deletedSceneId: sceneId,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});

/**
 * @route   POST /api/v1/scenes/:sceneId/execute
 * @desc    Kích hoạt thực thi ngữ cảnh thông minh thực tế từ Firestore
 */
scenesRouter.post('/:sceneId/execute', async (req: Request, res: Response) => {
  try {
    const { sceneId } = req.params;
    const { userId, source = 'api_scene' } = req.body;
    const targetUserId = userId || (req.user?.role === 'user' ? req.user.uid : undefined);

    const user = await findUser(targetUserId);
    if (!user) {
      return res.status(404).json({ success: false, error: 'Không tìm thấy người dùng trong cơ sở dữ liệu.' });
    }

    if (!checkUserPermission(req, user)) {
      return res.status(403).json({ success: false, error: 'Forbidden: Bạn không có quyền kích hoạt ngữ cảnh của tài khoản này.' });
    }

    const doc = await user.ref.collection('scenes').doc(sceneId).get();
    if (!doc.exists) {
      return res.status(404).json({ success: false, error: `Không tìm thấy ngữ cảnh với ID '${sceneId}' trong cơ sở dữ liệu.` });
    }

    const scene = doc.data();
    const actions: SceneAction[] = scene.actions || [];

    if (actions.length === 0) {
      return res.status(400).json({ success: false, error: `Ngữ cảnh '${scene.name}' không có hành động nào để thực thi.` });
    }

    const macAddress = user.data.macAddress || 'ESP32_MAC';
    addLog('[SEND]', `Kích hoạt Ngữ cảnh [${scene.name}] (${actions.length} hành động) cho user ${user.id}`, 'info');

    // Thực thi tuần tự từng hành động qua MQTT Retry Engine
    for (const action of actions) {
      const baseTopic = `${user.id}/${macAddress}/${action.room}/${action.deviceId}`;
      sendCommandWithRetry(baseTopic, String(action.state), `${source}_${sceneId}`);
    }

    res.json({
      success: true,
      message: `Đã kích hoạt thành công ngữ cảnh: ${scene.name}!`,
      scene: {
        id: sceneId,
        name: scene.name,
        actionsExecuted: actions.length,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ success: false, error: error.message });
  }
});
