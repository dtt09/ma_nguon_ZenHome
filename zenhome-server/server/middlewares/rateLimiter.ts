import rateLimit from 'express-rate-limit';
import { ADMIN_SECRET, safeCompare } from './auth';

const isWhitelisted = (req: any) => {
  // ZH-HIGH-09: Xóa bỏ ip.includes('127.0.0.1') bypassable qua X-Forwarded-For
  // Kiểm tra trực tiếp IP của socket TCP, chỉ cho phép kết nối loopback nội bộ thực sự khi không có header proxy giả mạo
  const socketIp = req.socket?.remoteAddress || req.connection?.remoteAddress || '';
  const isDirectLoopback = (socketIp === '127.0.0.1' || socketIp === '::1' || socketIp === '::ffff:127.0.0.1') && !req.headers['x-forwarded-for'];
  const token = req.headers['authorization']?.replace(/^Bearer\s+/i, '').trim() || (req.headers['x-api-key'] as string)?.trim();
  const hasAdminSecret = Boolean(ADMIN_SECRET && token && safeCompare(token, ADMIN_SECRET));
  return isDirectLoopback || hasAdminSecret;
};

// Giới hạn 2000 requests mỗi 15 phút cho các API thông thường (Bỏ qua cho Localhost & Admin Web)
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 2000,
  skip: isWhitelisted,
  message: { success: false, error: 'Quá nhiều yêu cầu từ IP của bạn, vui lòng thử lại sau 15 phút.' },
  standardHeaders: true,
  legacyHeaders: false,
});

// Giới hạn cho các hành động nhạy cảm (300 requests mỗi 10 phút, Bỏ qua cho Localhost & Admin Web)
export const actionLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 300,
  skip: isWhitelisted,
  message: { success: false, error: 'Vượt quá giới hạn gọi lệnh hành động, vui lòng thử lại sau 10 phút.' },
  standardHeaders: true,
  legacyHeaders: false,
});
