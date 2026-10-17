import rateLimit from 'express-rate-limit';

const isWhitelisted = (req: any) => {
  const ip = req.ip || req.connection?.remoteAddress || '';
  const isLocal = ip === '127.0.0.1' || ip === '::1' || ip === '::ffff:127.0.0.1' || ip.includes('127.0.0.1');
  const hasAdminSecret = req.headers['authorization'] === 'Bearer zenhome-admin-secret-2026' || req.headers['x-api-key'] === 'zenhome-admin-secret-2026';
  return isLocal || hasAdminSecret;
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

// Giới hạn cho các hành động nguy hiểm (300 requests mỗi 10 phút, Bỏ qua cho Localhost & Admin Web)
export const actionLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 300,
  skip: isWhitelisted,
  message: { success: false, error: 'Vượt quá giới hạn gọi lệnh hành động, vui lòng thử lại sau 10 phút.' },
  standardHeaders: true,
  legacyHeaders: false,
});
