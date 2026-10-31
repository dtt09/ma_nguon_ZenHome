import {
  startAuthentication,
  startRegistration,
  browserSupportsPasskeys,
  platformAuthenticatorIsAvailable,
} from '@simplewebauthn/browser';
import { getServerBaseUrl, getAdminSecret } from './backupServerService';

export interface PasskeyItem {
  id: string;
  name: string;
  deviceType: string;
  backedUp: boolean;
  createdAt: string;
  lastUsedAt: string;
}

export interface PasskeySupportStatus {
  supported: boolean;
  hasPlatformAuthenticator: boolean;
}

/**
 * Kiểm tra xem trình duyệt hiện tại và hệ điều hành có hỗ trợ Passkey / WebAuthn hay không
 */
export async function checkPasskeySupport(): Promise<PasskeySupportStatus> {
  let supported = false;
  let hasPlatformAuthenticator = false;
  try {
    supported = await browserSupportsPasskeys();
    if (supported) {
      hasPlatformAuthenticator = await platformAuthenticatorIsAvailable();
    }
  } catch {
    supported = false;
    hasPlatformAuthenticator = false;
  }
  return { supported, hasPlatformAuthenticator };
}

/**
 * Kiểm tra xem hệ thống máy chủ đã có Passkey nào được đăng ký trước đó hay chưa
 */
export async function getPasskeyStatus(): Promise<{ hasPasskeys: boolean; count: number }> {
  try {
    const baseUrl = getServerBaseUrl();
    const res = await fetch(`${baseUrl}/api/v1/auth/passkey/status`);
    if (!res.ok) return { hasPasskeys: false, count: 0 };
    const data = await res.json();
    return {
      hasPasskeys: Boolean(data.hasPasskeys),
      count: Number(data.count || 0),
    };
  } catch (err) {
    console.warn('[PASSKEY] Không thể lấy trạng thái Passkey từ server:', err);
    return { hasPasskeys: false, count: 0 };
  }
}

/**
 * Đăng nhập Quản trị viên bằng Passkey (Vân tay / Face ID / Windows Hello / YubiKey)
 */
export async function loginWithPasskey(): Promise<{
  success: boolean;
  token?: string;
  deviceName?: string;
  error?: string;
}> {
  try {
    const baseUrl = getServerBaseUrl();

    // 1. Lấy tùy chọn xác thực và challenge từ Server
    const optsRes = await fetch(`${baseUrl}/api/v1/auth/passkey/generate-authentication-options`);
    if (!optsRes.ok) {
      const errData = await optsRes.json().catch(() => ({}));
      throw new Error(errData.error || 'Máy chủ không thể tạo phiên xác thực Passkey.');
    }

    const { options, challengeId } = await optsRes.json();

    // 2. Kích hoạt giao diện sinh trắc học / bảo mật của Trình duyệt / HĐH
    const authResponse = await startAuthentication({ optionsJSON: options });

    // 3. Gửi chữ ký sinh trắc học lên server để xác minh
    const verifyRes = await fetch(`${baseUrl}/api/v1/auth/passkey/verify-authentication`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        challengeId,
        response: authResponse,
      }),
    });

    const verifyData = await verifyRes.json();
    if (!verifyRes.ok || !verifyData.success) {
      throw new Error(verifyData.error || 'Xác thực chữ ký Passkey thất bại.');
    }

    // 4. Lưu token đăng nhập vào bộ nhớ duyệt web
    const token = verifyData.token;
    if (token) {
      localStorage.setItem('zenhome_admin_key', token);
      localStorage.setItem('zenhome_auth_method', 'passkey');
      localStorage.setItem('zenhome_passkey_name', verifyData.admin?.deviceName || 'Passkey');
    }

    return {
      success: true,
      token,
      deviceName: verifyData.admin?.deviceName,
    };
  } catch (err: any) {
    console.error('[PASSKEY AUTH ERROR]', err);
    let msg = err.message || 'Không thể hoàn tất xác thực Passkey.';
    if (err.name === 'NotAllowedError') {
      msg = 'Bạn đã hủy yêu cầu xác thực hoặc cảm biến sinh trắc học đã quá thời gian chờ.';
    } else if (err.name === 'InvalidStateError') {
      msg = 'Thiết bị bảo mật này chưa được cấp phép hoặc đã được sử dụng.';
    }
    return {
      success: false,
      error: msg,
    };
  }
}

/**
 * Đăng ký Passkey mới (thiết bị hiện tại hoặc ghép nối điện thoại qua mã QR)
 */
export async function registerCurrentDevicePasskey(
  customName?: string,
  attachment?: 'platform' | 'cross-platform'
): Promise<{
  success: boolean;
  message?: string;
  passkey?: PasskeyItem;
  error?: string;
}> {
  try {
    const baseUrl = getServerBaseUrl();
    const adminKey = getAdminSecret();

    if (!adminKey) {
      throw new Error('Bạn cần quyền quản trị viên để đăng ký thiết bị Passkey mới.');
    }

    // 1. Yêu cầu tùy chọn đăng ký từ Server
    const query = attachment ? `?attachment=${attachment}` : '';
    const optsRes = await fetch(`${baseUrl}/api/v1/auth/passkey/generate-registration-options${query}`, {
      headers: {
        'Authorization': `Bearer ${adminKey}`,
        'x-api-key': adminKey,
      },
    });

    if (!optsRes.ok) {
      const errData = await optsRes.json().catch(() => ({}));
      throw new Error(errData.error || 'Không thể tạo tùy chọn đăng ký Passkey từ server.');
    }

    const { options, challengeId } = await optsRes.json();

    // 2. Kích hoạt giao diện sinh trắc học để người dùng chạm vân tay / Face ID / PIN (hoặc quét mã QR)
    const regResponse = await startRegistration({ optionsJSON: options });

    // 3. Tự động xác định tên thiết bị phù hợp nếu không truyền vào
    let finalName = customName?.trim();
    if (!finalName) {
      if (attachment === 'cross-platform') {
        finalName = 'Điện thoại (Face ID / Vân tay)';
      } else {
        const isMac = navigator.platform?.toUpperCase().indexOf('MAC') >= 0;
        const isWin = navigator.platform?.toUpperCase().indexOf('WIN') >= 0;
        const isMobile = /Android|iPhone|iPad/i.test(navigator.userAgent);
        if (isWin) finalName = 'Windows Hello PC';
        else if (isMac) finalName = 'MacBook Touch ID';
        else if (isMobile) finalName = 'Smartphone Passkey';
        else finalName = 'Khóa bảo mật FIDO2';
      }
    }

    // 4. Gửi Public Key đã tạo lên server để lưu vào SQLite
    const verifyRes = await fetch(`${baseUrl}/api/v1/auth/passkey/verify-registration`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminKey}`,
        'x-api-key': adminKey,
      },
      body: JSON.stringify({
        challengeId,
        response: regResponse,
        name: finalName,
      }),
    });

    const verifyData = await verifyRes.json();
    if (!verifyRes.ok || !verifyData.success) {
      throw new Error(verifyData.error || 'Lỗi lưu trữ khóa Passkey mới.');
    }

    return {
      success: true,
      message: verifyData.message || 'Đăng ký Passkey thành công!',
      passkey: verifyData.passkey,
    };
  } catch (err: any) {
    console.error('[PASSKEY REG ERROR]', err);
    let msg = err.message || 'Đăng ký Passkey thất bại.';
    if (err.name === 'NotAllowedError') {
      msg = 'Bạn đã hủy đăng ký Passkey hoặc cảm biến không phản hồi.';
    }
    return {
      success: false,
      error: msg,
    };
  }
}

/**
 * Lấy danh sách các Passkey đã đăng ký trên hệ thống
 */
export async function getRegisteredPasskeys(): Promise<PasskeyItem[]> {
  try {
    const baseUrl = getServerBaseUrl();
    const adminKey = getAdminSecret();
    if (!adminKey) return [];

    const res = await fetch(`${baseUrl}/api/v1/auth/passkey/list`, {
      headers: {
        'Authorization': `Bearer ${adminKey}`,
        'x-api-key': adminKey,
      },
    });

    if (!res.ok) return [];
    const data = await res.json();
    return data.passkeys || [];
  } catch (err) {
    console.warn('[PASSKEY] Lỗi tải danh sách Passkey:', err);
    return [];
  }
}

/**
 * Xóa một Passkey khỏi hệ thống
 */
export async function deletePasskeyById(id: string): Promise<boolean> {
  try {
    const baseUrl = getServerBaseUrl();
    const adminKey = getAdminSecret();
    if (!adminKey) return false;

    const res = await fetch(`${baseUrl}/api/v1/auth/passkey/${encodeURIComponent(id)}`, {
      method: 'DELETE',
      headers: {
        'Authorization': `Bearer ${adminKey}`,
        'x-api-key': adminKey,
      },
    });

    return res.ok;
  } catch {
    return false;
  }
}

/**
 * Đổi tên một Passkey
 */
export async function renamePasskeyById(id: string, newName: string): Promise<boolean> {
  try {
    const baseUrl = getServerBaseUrl();
    const adminKey = getAdminSecret();
    if (!adminKey) return false;

    const res = await fetch(`${baseUrl}/api/v1/auth/passkey/${encodeURIComponent(id)}/rename`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${adminKey}`,
        'x-api-key': adminKey,
      },
      body: JSON.stringify({ name: newName }),
    });

    return res.ok;
  } catch {
    return false;
  }
}
