import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Đường dẫn mặc định tới thư mục lưu trữ khóa ký số
const ROOT_DIR = path.resolve(__dirname, '../../../');
const DEFAULT_PRIV_KEY_PATH = path.join(ROOT_DIR, 'scripts', 'keys', 'firmware_signer_private.pem');
const DEFAULT_PUB_KEY_PATH = path.join(ROOT_DIR, 'scripts', 'keys', 'firmware_signer_public.pem');

export interface FirmwareSignatureResult {
  sha256: string;
  sigHex: string;
  fileSize: number;
  algorithm: string;
  signedAt: string;
}

/**
 * Lấy Private Key ký số firmware (Ưu tiên biến môi trường, sau đó đến file hệ thống, cuối cùng tự sinh)
 */
export function getFirmwarePrivateKeyPem(): string {
  if (process.env.FIRMWARE_SIGNING_PRIVATE_KEY) {
    return process.env.FIRMWARE_SIGNING_PRIVATE_KEY.trim();
  }

  if (fs.existsSync(DEFAULT_PRIV_KEY_PATH)) {
    try {
      return fs.readFileSync(DEFAULT_PRIV_KEY_PATH, 'utf8').trim();
    } catch (err: any) {
      console.warn('[FIRMWARE SIGNER] ⚠️ Không thể đọc file private key:', err.message);
    }
  }

  // Khởi tạo cặp khóa ECDSA P-256 động nếu chưa tồn tại
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });

  try {
    const keysDir = path.dirname(DEFAULT_PRIV_KEY_PATH);
    if (!fs.existsSync(keysDir)) {
      fs.mkdirSync(keysDir, { recursive: true });
    }
    fs.writeFileSync(DEFAULT_PRIV_KEY_PATH, privateKey, { encoding: 'utf8', mode: 0o600 });
    fs.writeFileSync(DEFAULT_PUB_KEY_PATH, publicKey, { encoding: 'utf8', mode: 0o644 });
    console.log('[FIRMWARE SIGNER] 🔑 Đã tự động sinh cặp khóa ECDSA P-256 mới cho Firmware Signer.');
  } catch (_) {
    // Không thể ghi ra đĩa trong môi trường read-only, sử dụng khóa in-memory
  }

  return privateKey.trim();
}

/**
 * Lấy Public Key tương ứng dùng để xác thực chữ ký
 */
export function getFirmwarePublicKeyPem(): string {
  if (process.env.FIRMWARE_SIGNING_PUBLIC_KEY) {
    return process.env.FIRMWARE_SIGNING_PUBLIC_KEY.trim();
  }

  if (fs.existsSync(DEFAULT_PUB_KEY_PATH)) {
    try {
      return fs.readFileSync(DEFAULT_PUB_KEY_PATH, 'utf8').trim();
    } catch (_) {}
  }

  const privPem = getFirmwarePrivateKeyPem();
  const privKeyObj = crypto.createPrivateKey(privPem);
  const pubKeyObj = crypto.createPublicKey(privKeyObj);
  return pubKeyObj.export({ type: 'spki', format: 'pem' }).toString().trim();
}

/**
 * Ký số nhị phân firmware bằng thuật toán ECDSA NIST P-256 với SHA-256
 * @param buffer Buffer nhị phân của firmware .bin
 * @param privateKeyPem Tùy chọn PEM private key, nếu không truyền sẽ lấy từ hệ thống
 */
export function signFirmwareBinary(buffer: Buffer, privateKeyPem?: string): FirmwareSignatureResult {
  if (!buffer || buffer.length === 0) {
    throw new Error('Buffer firmware rỗng, không thể ký số.');
  }

  const sha256 = crypto.createHash('sha256').update(buffer).digest('hex').toUpperCase();
  const privKey = privateKeyPem || getFirmwarePrivateKeyPem();

  const sign = crypto.createSign('SHA256');
  sign.update(buffer);
  const derSignature = sign.sign(privKey);
  const sigHex = derSignature.toString('hex').toLowerCase();

  return {
    sha256,
    sigHex,
    fileSize: buffer.length,
    algorithm: 'ECDSA-SHA256-P256',
    signedAt: new Date().toISOString(),
  };
}

/**
 * Xác minh chữ ký số ECDSA của file nhị phân firmware
 * @param buffer Buffer nhị phân của firmware
 * @param sigHex Chữ ký số dạng hex DER
 * @param publicKeyPem Tùy chọn PEM public key
 */
export function verifyFirmwareBinarySignature(buffer: Buffer, sigHex: string, publicKeyPem?: string): boolean {
  try {
    const pubKey = publicKeyPem || getFirmwarePublicKeyPem();
    const verify = crypto.createVerify('SHA256');
    verify.update(buffer);
    return verify.verify(pubKey, Buffer.from(sigHex, 'hex'));
  } catch (err: any) {
    console.error('[FIRMWARE SIGNER] ❌ Lỗi xác thực chữ ký firmware:', err.message);
    return false;
  }
}
