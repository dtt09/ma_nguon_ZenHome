import { Router, Request, Response } from 'express';
import {
  generateRegistrationOptions,
  verifyRegistrationResponse,
  generateAuthenticationOptions,
  verifyAuthenticationResponse,
} from '@simplewebauthn/server';
import type {
  RegistrationResponseJSON,
  AuthenticationResponseJSON,
  AuthenticatorTransport,
} from '@simplewebauthn/server';
import {
  storeChallenge,
  retrieveChallenge,
  getAllPasskeys,
  getPasskeyById,
  savePasskey,
  updatePasskeyCounter,
  renamePasskey,
  deletePasskey,
  countPasskeys,
  signAdminJwt,
  getEffectiveRpID,
  getEffectiveOrigins,
} from '../../core/passkeyService';
import { requireAdminAuth } from '../../middlewares/auth';
import { apiLimiter, actionLimiter } from '../../middlewares/rateLimiter';

export const authRouter = Router();

// ==========================================
// 1. KIỂM TRA TRẠNG THÁI PASSKEY TRÊN HỆ THỐNG
// ==========================================
authRouter.get('/passkey/status', apiLimiter, async (req: Request, res: Response) => {
  try {
    const count = await countPasskeys();
    res.json({
      success: true,
      hasPasskeys: count > 0,
      count,
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ==========================================
// 2. KHỞI TẠO TÙY CHỌN ĐĂNG NHẬP BẰNG PASSKEY
// ==========================================
authRouter.get('/passkey/generate-authentication-options', apiLimiter, async (req: Request, res: Response) => {
  try {
    const rpID = getEffectiveRpID(req.get('host'));
    const allPasskeys = await getAllPasskeys();

    const allowCredentials = allPasskeys.map((p) => {
      let transports: AuthenticatorTransport[] | undefined = undefined;
      try {
        if (p.transports) transports = JSON.parse(p.transports);
      } catch {}
      return {
        id: p.id,
        transports,
      };
    });

    const options = await generateAuthenticationOptions({
      rpID,
      allowCredentials: allowCredentials.length > 0 ? allowCredentials : undefined,
      userVerification: 'preferred',
    });

    const challengeId = storeChallenge(options.challenge, 'authentication');

    res.json({
      success: true,
      challengeId,
      options,
    });
  } catch (err: any) {
    console.error('[PASSKEY] Lỗi tạo tùy chọn xác thực:', err);
    res.status(500).json({ success: false, error: 'Không thể khởi tạo phiên xác thực Passkey: ' + err.message });
  }
});

// ==========================================
// 3. XÁC MINH PHẢN HỒI ĐĂNG NHẬP PASSKEY
// ==========================================
authRouter.post('/passkey/verify-authentication', actionLimiter, async (req: Request, res: Response) => {
  try {
    const { challengeId, response } = req.body as {
      challengeId?: string;
      response: AuthenticationResponseJSON;
    };

    if (!response || !response.id) {
      return res.status(400).json({ success: false, error: 'Thiếu dữ liệu phản hồi xác thực từ trình duyệt.' });
    }

    const expectedChallenge = retrieveChallenge(challengeId, 'authentication');
    if (!expectedChallenge) {
      return res.status(400).json({
        success: false,
        error: 'Phiên xác thực Passkey đã hết hạn hoặc không hợp lệ. Vui lòng bấm thử lại.',
      });
    }

    const passkey = await getPasskeyById(response.id);
    if (!passkey) {
      return res.status(404).json({
        success: false,
        error: 'Khóa Passkey này không được ghi nhận trong danh sách quản trị viên hợp lệ.',
      });
    }

    const rpID = getEffectiveRpID(req.get('host'));
    const expectedOrigins = getEffectiveOrigins(req.get('origin'));

    let transports: AuthenticatorTransport[] | undefined = undefined;
    try {
      if (passkey.transports) transports = JSON.parse(passkey.transports);
    } catch {}

    const verification = await verifyAuthenticationResponse({
      response,
      expectedChallenge,
      expectedOrigin: expectedOrigins,
      expectedRPID: rpID,
      credential: {
        id: passkey.id,
        publicKey: new Uint8Array(Buffer.from(passkey.publicKey, 'base64url')),
        counter: passkey.counter,
        transports,
      },
      requireUserVerification: false,
    });

    if (verification.verified) {
      await updatePasskeyCounter(passkey.id, verification.authenticationInfo.newCounter);
      const token = signAdminJwt({ credentialId: passkey.id, deviceName: passkey.name });

      console.log(`[PASSKEY AUTH] ✅ Quản trị viên đã đăng nhập thành công bằng Passkey [${passkey.name}] (ID: ${passkey.id.slice(0, 10)}...)`);

      return res.json({
        success: true,
        message: `Đăng nhập thành công bằng Passkey (${passkey.name})`,
        token,
        admin: {
          role: 'admin',
          deviceName: passkey.name,
          authMethod: 'passkey',
        },
      });
    }

    res.status(401).json({ success: false, error: 'Xác thực chữ ký Passkey không thành công.' });
  } catch (err: any) {
    console.error('[PASSKEY AUTH] Lỗi xác thực chữ ký:', err);
    res.status(400).json({ success: false, error: 'Xác thực Passkey thất bại: ' + err.message });
  }
});

// ==========================================
// 4. KHỞI TẠO TÙY CHỌN ĐĂNG KÝ PASSKEY MỚI (YÊU CẦU ADMIN AUTH)
// ==========================================
authRouter.get('/passkey/generate-registration-options', requireAdminAuth, apiLimiter, async (req: Request, res: Response) => {
  try {
    const rpID = getEffectiveRpID(req.get('host'));
    const allPasskeys = await getAllPasskeys();
    const attachment = (req.query.attachment as 'platform' | 'cross-platform') || undefined;

    const excludeCredentials = allPasskeys.map((p) => {
      let transports: AuthenticatorTransport[] | undefined = undefined;
      try {
        if (p.transports) transports = JSON.parse(p.transports);
      } catch {}
      return {
        id: p.id,
        transports,
      };
    });

    const options = await generateRegistrationOptions({
      rpName: 'ZenHome Cloud Admin',
      rpID,
      userID: new TextEncoder().encode('zenhome-super-admin'),
      userName: 'admin@zenhome.local',
      userDisplayName: 'ZenHome Master Administrator',
      attestationType: 'none',
      excludeCredentials,
      authenticatorSelection: {
        authenticatorAttachment: attachment,
        residentKey: 'preferred',
        userVerification: 'preferred',
      },
    });

    const challengeId = storeChallenge(options.challenge, 'registration');

    res.json({
      success: true,
      challengeId,
      options,
    });
  } catch (err: any) {
    console.error('[PASSKEY REG] Lỗi tạo tùy chọn đăng ký:', err);
    res.status(500).json({ success: false, error: 'Không thể khởi tạo đăng ký Passkey: ' + err.message });
  }
});

// ==========================================
// 5. XÁC MINH VÀ LƯU TRỮ PASSKEY MỚI
// ==========================================
authRouter.post('/passkey/verify-registration', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  try {
    const { challengeId, response, name } = req.body as {
      challengeId?: string;
      response: RegistrationResponseJSON;
      name?: string;
    };

    if (!response || !response.id) {
      return res.status(400).json({ success: false, error: 'Thiếu dữ liệu đăng ký Passkey từ trình duyệt.' });
    }

    const expectedChallenge = retrieveChallenge(challengeId, 'registration');
    if (!expectedChallenge) {
      return res.status(400).json({
        success: false,
        error: 'Phiên đăng ký Passkey đã hết hạn. Vui lòng thử lại.',
      });
    }

    const rpID = getEffectiveRpID(req.get('host'));
    const expectedOrigins = getEffectiveOrigins(req.get('origin'));

    const verification = await verifyRegistrationResponse({
      response,
      expectedChallenge,
      expectedOrigin: expectedOrigins,
      expectedRPID: rpID,
      requireUserVerification: false,
    });

    if (verification.verified && verification.registrationInfo) {
      const { credential, credentialDeviceType, credentialBackedUp } = verification.registrationInfo;

      const deviceName = (name && name.trim()) || `Passkey (${credentialDeviceType === 'multiDevice' ? 'iCloud/Google Passkey' : 'Thiết bị bảo mật'})`;

      await savePasskey({
        id: credential.id,
        name: deviceName,
        publicKey: Buffer.from(credential.publicKey).toString('base64url'),
        counter: credential.counter,
        deviceType: credentialDeviceType,
        backedUp: credentialBackedUp ? 1 : 0,
        transports: credential.transports ? JSON.stringify(credential.transports) : null,
        createdAt: new Date().toISOString(),
        lastUsedAt: new Date().toISOString(),
      });

      console.log(`[PASSKEY REG] ✅ Đã đăng ký Passkey mới thành công: "${deviceName}" [${credential.id.slice(0, 10)}...]`);

      return res.json({
        success: true,
        message: `Đã liên kết Passkey "${deviceName}" thành công! Lần sau bạn có thể đăng nhập bằng vân tay/khuôn mặt mà không cần mật khẩu.`,
        passkey: {
          id: credential.id,
          name: deviceName,
          deviceType: credentialDeviceType,
          backedUp: credentialBackedUp,
        },
      });
    }

    res.status(400).json({ success: false, error: 'Không thể xác thực cấu trúc khóa Passkey mới.' });
  } catch (err: any) {
    console.error('[PASSKEY REG] Lỗi xác minh đăng ký:', err);
    res.status(400).json({ success: false, error: 'Đăng ký Passkey thất bại: ' + err.message });
  }
});

// ==========================================
// 6. DANH SÁCH PASSKEY ĐÃ ĐĂNG KÝ
// ==========================================
authRouter.get('/passkey/list', requireAdminAuth, apiLimiter, async (req: Request, res: Response) => {
  try {
    const list = await getAllPasskeys();
    res.json({
      success: true,
      passkeys: list.map((p) => ({
        id: p.id,
        name: p.name,
        deviceType: p.deviceType,
        backedUp: Boolean(p.backedUp),
        createdAt: p.createdAt,
        lastUsedAt: p.lastUsedAt,
      })),
    });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ==========================================
// 7. ĐỔI TÊN PASSKEY
// ==========================================
authRouter.put('/passkey/:id/rename', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const { name } = req.body;
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, error: 'Tên thiết bị không được để trống.' });
    }
    const ok = await renamePasskey(id, name.trim());
    if (ok) {
      return res.json({ success: true, message: 'Đã đổi tên Passkey thành công.' });
    }
    res.status(404).json({ success: false, error: 'Không tìm thấy Passkey cần đổi tên.' });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});

// ==========================================
// 8. HỦY LIÊN KẾT / XÓA PASSKEY
// ==========================================
authRouter.delete('/passkey/:id', requireAdminAuth, actionLimiter, async (req: Request, res: Response) => {
  try {
    const id = String(req.params.id);
    const ok = await deletePasskey(id);
    if (ok) {
      console.log(`[PASSKEY] 🗑️ Đã xóa Passkey [${id.slice(0, 10)}...]`);
      return res.json({ success: true, message: 'Đã xóa Passkey thành công.' });
    }
    res.status(404).json({ success: false, error: 'Không tìm thấy Passkey cần xóa.' });
  } catch (err: any) {
    res.status(500).json({ success: false, error: err.message });
  }
});
