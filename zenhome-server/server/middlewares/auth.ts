import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { getAuth } from '../core/firebase';
import { verifyAdminJwt } from '../core/passkeyService';

export function safeCompare(a: string, b: string): boolean {
  if (!a || !b) return false;
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

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

export const ADMIN_SECRET = process.env.ADMIN_API_SECRET?.trim() || '';
if (!ADMIN_SECRET) {
  console.warn('⚠️ [SECURITY WARNING] ADMIN_API_SECRET chưa được cấu hình trong .env! Vui lòng cấu hình khóa bảo mật.');
}

/**
 * Kiểm tra quyền truy cập đối tượng (Chống lỗ hổng IDOR / BOLA)
 * - Admin: Có toàn quyền trên toàn hệ thống
 * - Owner: Toàn quyền trên tài khoản của mình
 * - Member: Được phép nếu được Chủ nhà chia sẻ trong 'sharedWith' và không bị vô hiệu hóa
 */
export function checkUserPermission(req: Request, targetUser: { id: string; data?: any }): boolean {
  if (req.user?.role === 'admin') return true;
  if (!req.user) return false;

  // Chủ nhà (Owner)
  if (req.user.uid === targetUser.id || req.user.uid === targetUser.data?.uid) {
    return true;
  }

  // Thành viên phụ được chia sẻ (Shared Member)
  const sharedWith: string[] = Array.isArray(targetUser.data?.sharedWith) ? targetUser.data.sharedWith : [];
  if (sharedWith.includes(req.user.uid)) {
    const disabledMembers: string[] = Array.isArray(targetUser.data?.disabledMembers) ? targetUser.data.disabledMembers : [];
    if (!disabledMembers.includes(req.user.uid)) {
      return true;
    }
  }

  return false;
}

/**
 * Kiểm tra quyền Chủ nhà hoặc Quản trị viên (Owner / Super-Admin only)
 * Nghiêm cấm Thành viên phụ (Members) can thiệp vào các cài đặt phần cứng, cấu hình pin, reset, hoặc liên kết Hub
 */
export function checkOwnerOrAdminPermission(req: Request, targetUser: { id: string; data?: any }): boolean {
  if (req.user?.role === 'admin') return true;
  if (!req.user) return false;
  return req.user.uid === targetUser.id || req.user.uid === targetUser.data?.uid;
}

/**
 * Middleware bắt buộc quyền Quản trị viên (Admin Secret hoặc Firebase Admin Token)
 * Đã loại bỏ hoàn toàn lỗ hổng phân quyền lỏng lẻo bằng substring email (SEC-02)
 */
export const requireAdminAuth = async (req: Request, res: Response, next: NextFunction) => {
  // Chỉ nhận token qua Header (Authorization Bearer hoặc x-api-key), loại bỏ query string chống lộ trong access log
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '').trim() || 
                (req.headers['x-api-key'] as string)?.trim();
  
  if (!token) {
    return res.status(401).json({ success: false, error: 'Unauthorized: Bạn không có quyền quản trị viên (Admin).' });
  }

  // 1. Chấp nhận nếu là Admin Secret đã cấu hình (So sánh an toàn thời gian thực - Timing Attack Safe)
  if (ADMIN_SECRET && safeCompare(token, ADMIN_SECRET)) {
    req.user = { uid: 'admin', role: 'admin' };
    return next();
  }

  // 2. Chấp nhận nếu là Admin JWT hợp lệ được cấp phát qua xác thực Passkey (FIDO2 / WebAuthn)
  const passkeyAdmin = verifyAdminJwt(token);
  if (passkeyAdmin) {
    req.user = { uid: passkeyAdmin.sub, role: 'admin' };
    return next();
  }

  // 3. Chấp nhận nếu là Firebase ID Token của Admin (Kiểm tra Custom Claim hoặc Admin Email chuẩn)
  try {
    const auth = getAuth();
    if (auth) {
      const decoded = await auth.verifyIdToken(token);
      const configuredAdminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
      const isCustomClaimAdmin = decoded.admin === true || decoded.role === 'admin';
      const isConfiguredAdminEmail = Boolean(configuredAdminEmail && decoded.email && decoded.email.trim().toLowerCase() === configuredAdminEmail);

      if (isCustomClaimAdmin || isConfiguredAdminEmail) {
        req.user = {
          uid: decoded.uid,
          email: decoded.email,
          role: 'admin',
        };
        return next();
      }
    }
  } catch (err: any) {
    // Không giải mã được Firebase ID Token
  }
  
  return res.status(401).json({ success: false, error: 'Unauthorized: Bạn không có quyền quản trị viên (Admin).' });
};

/**
 * Middleware xác thực người dùng (Chấp nhận Firebase ID Token hoặc Admin Secret)
 * Ngăn chặn hoàn toàn các truy cập trái phép hoặc dò quét IDOR/BOLA
 */
export const requireAuth = async (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, '').trim() || 
                (req.headers['x-api-key'] as string)?.trim();

  if (!token) {
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized: Vui lòng cung cấp mã xác thực (Authorization Bearer Token hoặc Admin Secret).' 
    });
  }

  // 1. Chấp nhận nếu là Admin Secret (so sánh an toàn Timing-safe)
  if (ADMIN_SECRET && safeCompare(token, ADMIN_SECRET)) {
    req.user = { uid: 'admin', role: 'admin' };
    return next();
  }

  // 2. Chấp nhận nếu là Passkey JWT Token
  const passkeyAdmin = verifyAdminJwt(token);
  if (passkeyAdmin) {
    req.user = { uid: passkeyAdmin.sub, role: 'admin' };
    return next();
  }

  // 3. Xác thực Firebase ID Token của người dùng Mobile / Web
  try {
    const auth = getAuth();
    if (auth) {
      const decoded = await auth.verifyIdToken(token);
      req.user = {
        uid: decoded.uid,
        email: decoded.email,
        role: (decoded.admin === true || decoded.role === 'admin') ? 'admin' : 'user',
      };
      return next();
    }
  } catch (err: any) {
    return res.status(401).json({ 
      success: false, 
      error: 'Unauthorized: Token xác thực không hợp lệ hoặc đã hết hạn.' 
    });
  }

  return res.status(401).json({ 
    success: false, 
    error: 'Unauthorized: Dịch vụ xác thực chưa sẵn sàng.' 
  });
};
