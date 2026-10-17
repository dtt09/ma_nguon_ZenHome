import { Request, Response, NextFunction } from 'express';
import { getAuth } from '../core/firebase';

export interface AuthenticatedUser {
  uid: string;
  email?: string;
  role: 'admin' | 'user';
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthenticatedUser;
    }
  }
}

export const ADMIN_SECRET = process.env.ADMIN_API_SECRET || 'zenhome-admin-secret-2026';

/**
 * Middleware bắt buộc quyền Quản trị viên (Admin Secret)
 */
export const requireAdminAuth = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '').trim() || 
                (req.headers['x-api-key'] as string) || 
                (req.query.token as string);
  
  if (!token || token !== ADMIN_SECRET) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Bạn không có quyền quản trị viên (Admin).' });
  }
  
  req.user = { uid: 'admin', role: 'admin' };
  next();
};

/**
 * Middleware xác thực người dùng (Chấp nhận Firebase ID Token hoặc Admin Secret)
 * Ngăn chặn hoàn toàn các truy cập trái phép hoặc dò quét IDOR/BOLA
 */
export const requireAuth = async (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '').trim() || 
                (req.headers['x-api-key'] as string) || 
                (req.query.token as string);

  if (!token) {
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized: Vui lòng cung cấp mã xác thực (Authorization Bearer Token hoặc Admin Secret).' 
    });
  }

  // 1. Chấp nhận nếu là Admin Secret (đảm bảo Web Dashboard và script nội bộ hoạt động trơn tru)
  if (token === ADMIN_SECRET) {
    req.user = { uid: 'admin', role: 'admin' };
    return next();
  }

  // 2. Xác thực Firebase ID Token của người dùng Mobile / Web
  try {
    const auth = getAuth();
    const decoded = await auth.verifyIdToken(token);
    req.user = {
      uid: decoded.uid,
      email: decoded.email,
      role: 'user',
    };
    return next();
  } catch (err: any) {
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized: Token xác thực không hợp lệ hoặc đã hết hạn.' 
    });
  }
};
