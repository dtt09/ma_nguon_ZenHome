import { Request, Response, NextFunction } from 'express';

export const requireAdminAuth = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.split(' ')[1] || req.query.token;
  
  // Lấy token từ biến môi trường, hoặc dùng mặc định nếu chưa cài đặt
  const ADMIN_SECRET = process.env.ADMIN_API_SECRET || 'zenhome-admin-secret-2026';
  
  if (!token || token !== ADMIN_SECRET) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Bạn không có quyền thực hiện hành động này.' });
  }
  
  next();
};
