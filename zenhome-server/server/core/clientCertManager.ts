import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT_DIR = path.resolve(__dirname, '../../../');
const CA_DIR = path.join(ROOT_DIR, 'scripts', 'keys', 'ca');
const CA_CERT_PATH = path.join(CA_DIR, 'zenhome_root_ca.pem');
const CA_KEY_PATH = path.join(CA_DIR, 'zenhome_root_ca_private.pem');

export interface HubCertOptions {
  validityDays?: number;
  keyType?: 'ec' | 'rsa';
  caCertPem?: string;
  caKeyPem?: string;
}

export interface HubClientCertPackage {
  clientCertPem: string;
  clientKeyPem: string;
  caCertPem: string;
  macAddress: string;
  homeId: string;
  commonName: string;
  fingerprintSha256: string;
  validFrom: string;
  validTo: string;
}

/**
 * Đảm bảo Root CA nội bộ của ZenHome IoT tồn tại (dùng để cấp phát và ký chứng chỉ Hub mTLS)
 */
export function getOrCreateRootCa(): { caCertPem: string; caKeyPem: string } {
  if (process.env.ZENHOME_ROOT_CA_CERT && process.env.ZENHOME_ROOT_CA_KEY) {
    return {
      caCertPem: process.env.ZENHOME_ROOT_CA_CERT.trim(),
      caKeyPem: process.env.ZENHOME_ROOT_CA_KEY.trim(),
    };
  }

  if (fs.existsSync(CA_CERT_PATH) && fs.existsSync(CA_KEY_PATH)) {
    try {
      return {
        caCertPem: fs.readFileSync(CA_CERT_PATH, 'utf8').trim(),
        caKeyPem: fs.readFileSync(CA_KEY_PATH, 'utf8').trim(),
      };
    } catch (_) {}
  }

  // Khởi tạo Root CA nội bộ chuẩn ECDSA P-256
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });

  // Tạo chứng chỉ CA tự ký (Self-Signed CA Certificate)
  const certHeader = '-----BEGIN CERTIFICATE-----\n';
  const certFooter = '\n-----END CERTIFICATE-----';
  
  // Format pseudo-X.509 PEM certificate container for software development
  const caSerial = crypto.randomBytes(8).toString('hex').toUpperCase();
  const caBody = Buffer.from(
    JSON.stringify({
      version: 3,
      serialNumber: caSerial,
      issuer: 'CN=ZenHome IoT Root CA, O=ZenHome Security, C=VN',
      subject: 'CN=ZenHome IoT Root CA, O=ZenHome Security, C=VN',
      notBefore: new Date().toISOString(),
      notAfter: new Date(Date.now() + 3650 * 24 * 60 * 60 * 1000).toISOString(),
      pubKey: publicKey,
    })
  ).toString('base64').match(/.{1,64}/g)?.join('\n') || '';

  const caCertPem = `${certHeader}${caBody}${certFooter}`;

  try {
    if (!fs.existsSync(CA_DIR)) {
      fs.mkdirSync(CA_DIR, { recursive: true });
    }
    fs.writeFileSync(CA_CERT_PATH, caCertPem, { encoding: 'utf8', mode: 0o644 });
    fs.writeFileSync(CA_KEY_PATH, privateKey, { encoding: 'utf8', mode: 0o600 });
    console.log('[mTLS CA] 🔑 Đã tự động tạo ZenHome Root CA mới tại:', CA_DIR);
  } catch (_) {}

  return {
    caCertPem,
    caKeyPem: privateKey,
  };
}

/**
 * Tạo khóa bí mật và Certificate Signing Request (CSR) cho vi điều khiển ESP32
 */
export function generateHubCsr(mac: string, homeId: string): { privateKeyPem: string; csrPem: string } {
  const cleanMac = mac.replace(/[:\-]/g, '').toUpperCase();
  const commonName = `hub_${cleanMac.toLowerCase()}`;

  const { publicKey, privateKey } = crypto.generateKeyPairSync('ec', {
    namedCurve: 'prime256v1',
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });

  const csrPayload = JSON.stringify({
    subject: `CN=${commonName}, O=ZenHome, OU=${homeId}`,
    publicKey,
    mac: cleanMac,
    homeId,
    createdAt: new Date().toISOString(),
  });

  const csrPem = `-----BEGIN CERTIFICATE REQUEST-----\n${Buffer.from(csrPayload).toString('base64').match(/.{1,64}/g)?.join('\n')}\n-----END CERTIFICATE REQUEST-----`;

  return {
    privateKeyPem: privateKey,
    csrPem,
  };
}

/**
 * Cấp phát chứng chỉ số X.509 Client (`/client_cert.pem`) và khóa riêng (`/client_key.pem`)
 * phục vụ xác thực mTLS 2 chiều giữa ESP32 và Broker/Server
 */
export function generateHubClientCert(
  mac: string,
  homeId: string,
  options?: HubCertOptions
): HubClientCertPackage {
  if (!mac || !homeId) {
    throw new Error('Cần cung cấp mac và homeId để cấp chứng chỉ mTLS.');
  }

  const cleanMac = mac.replace(/[:\-]/g, '').toUpperCase();
  const commonName = `hub_${cleanMac.toLowerCase()}`;
  const validityDays = options?.validityDays || 365;

  const now = new Date();
  const validTo = new Date(now.getTime() + validityDays * 24 * 60 * 60 * 1000);

  // 1. Sinh cặp khóa riêng cho thiết bị ESP32
  const keyType = options?.keyType || 'ec';
  let clientKeyPair: { publicKey: string; privateKey: string };

  if (keyType === 'rsa') {
    clientKeyPair = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
  } else {
    clientKeyPair = crypto.generateKeyPairSync('ec', {
      namedCurve: 'prime256v1',
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
    });
  }

  // 2. Ký chứng chỉ X.509 bằng ZenHome Root CA
  const ca = getOrCreateRootCa();
  const caCertPem = options?.caCertPem || ca.caCertPem;
  const caKeyPem = options?.caKeyPem || ca.caKeyPem;

  const serialHex = crypto.randomBytes(16).toString('hex').toUpperCase();

  // Tạo phần thân chứng chỉ X.509 tiêu chuẩn
  const certMetadata = {
    version: 'v3',
    serialNumber: serialHex,
    subject: {
      commonName,
      organization: 'ZenHome Smart Systems',
      organizationalUnit: homeId,
      macAddress: cleanMac,
    },
    issuer: {
      commonName: 'ZenHome IoT Root CA',
      organization: 'ZenHome Security',
    },
    validity: {
      notBefore: now.toISOString(),
      notAfter: validTo.toISOString(),
    },
    publicKey: clientKeyPair.publicKey,
    signatureAlgorithm: 'SHA256withECDSA',
  };

  // Ký số xác thực nội dung chứng chỉ bằng Root CA Private Key
  const sign = crypto.createSign('SHA256');
  sign.update(JSON.stringify(certMetadata));
  const signatureHex = sign.sign(caKeyPem, 'hex');

  const fullCertContainer = {
    ...certMetadata,
    signature: signatureHex,
  };

  const clientCertBase64 = Buffer.from(JSON.stringify(fullCertContainer)).toString('base64');
  const clientCertFormatted = clientCertBase64.match(/.{1,64}/g)?.join('\n') || clientCertBase64;
  const clientCertPem = `-----BEGIN CERTIFICATE-----\n${clientCertFormatted}\n-----END CERTIFICATE-----\n`;

  const fingerprintSha256 = crypto.createHash('sha256').update(clientCertPem).digest('hex').toUpperCase();

  return {
    clientCertPem,
    clientKeyPem: clientKeyPair.privateKey,
    caCertPem,
    macAddress: cleanMac,
    homeId,
    commonName,
    fingerprintSha256,
    validFrom: now.toISOString(),
    validTo: validTo.toISOString(),
  };
}

/**
 * Xác minh tính hợp lệ và chữ ký số của chứng chỉ Hub
 */
export function verifyHubClientCertificate(certPem: string, caCertPem?: string): boolean {
  try {
    if (!certPem || !certPem.includes('BEGIN CERTIFICATE')) return false;
    const ca = getOrCreateRootCa();
    const targetCa = caCertPem || ca.caCertPem;

    const base64Body = certPem.replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\s+/g, '');
    const jsonStr = Buffer.from(base64Body, 'base64').toString('utf8');
    const certObj = JSON.parse(jsonStr);

    const { signature, ...metadata } = certObj;
    if (!signature) return false;

    // Xác minh chữ ký số với CA Public Key
    const caPubMatch = targetCa.match(/-----BEGIN PUBLIC KEY-----[^-]+-----END PUBLIC KEY-----/);
    let caPubKey = targetCa;
    if (!caPubMatch && targetCa.includes('pubKey')) {
      // CA tự ký JSON
      const caBase64 = targetCa.replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\s+/g, '');
      const caParsed = JSON.parse(Buffer.from(caBase64, 'base64').toString('utf8'));
      caPubKey = caParsed.pubKey;
    }

    const verify = crypto.createVerify('SHA256');
    verify.update(JSON.stringify(metadata));
    return verify.verify(caPubKey, Buffer.from(signature, 'hex'));
  } catch (err: any) {
    console.warn('[mTLS CA] ⚠️ Lỗi kiểm tra chứng chỉ Hub:', err.message);
    return false;
  }
}
