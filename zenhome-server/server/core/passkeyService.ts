import crypto from 'crypto';
import jwt from 'jsonwebtoken';
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
import { dbAll, dbGet, dbRun } from './database';

function getJwtSecret(): string {
  return process.env.JWT_ADMIN_SECRET || process.env.ADMIN_API_SECRET || 'zenhome_secure_fallback_salt_2026_jwt_passkey';
}

export interface AdminPasskeyRecord {
  id: string;
  name: string;
  publicKey: string;
  counter: number;
  deviceType: string;
  backedUp: number;
  transports: string | null;
  createdAt: string;
  lastUsedAt: string;
}

export interface AdminTokenPayload {
  sub: string;
  role: 'admin';
  authMethod: 'passkey';
  credentialId?: string;
  deviceName?: string;
}

// ==========================================
// THỬ THÁCH BẢO MẬT (CHALLENGE STORE CÓ TTL)
// ==========================================
interface ChallengeItem {
  challenge: string;
  type: 'registration' | 'authentication';
  expiresAt: number;
}

const challenges = new Map<string, ChallengeItem>();

function cleanupChallenges() {
  const now = Date.now();
  for (const [id, item] of challenges.entries()) {
    if (item.expiresAt < now) {
      challenges.delete(id);
    }
  }
}

export function storeChallenge(challenge: string, type: 'registration' | 'authentication'): string {
  cleanupChallenges();
  const challengeId = crypto.randomBytes(16).toString('hex');
  challenges.set(challengeId, {
    challenge,
    type,
    expiresAt: Date.now() + 5 * 60 * 1000, // 5 phút hiệu lực
  });
  return challengeId;
}

export function retrieveChallenge(challengeId?: string, type?: 'registration' | 'authentication'): string | null {
  cleanupChallenges();
  if (challengeId && challenges.has(challengeId)) {
    const item = challenges.get(challengeId)!;
    challenges.delete(challengeId);
    if (!type || item.type === type) {
      return item.challenge;
    }
  }
  // Dự phòng: Lấy challenge hợp lệ gần nhất nếu frontend không truyền challengeId
  for (const [id, item] of challenges.entries()) {
    if (!type || item.type === type) {
      challenges.delete(id);
      return item.challenge;
    }
  }
  return null;
}

// ==========================================
// CƠ SỞ DỮ LIỆU SQLITE: QUẢN LÝ PASSKEY
// ==========================================
export async function getAllPasskeys(): Promise<AdminPasskeyRecord[]> {
  try {
    return await dbAll<AdminPasskeyRecord>(
      'SELECT id, name, publicKey, counter, deviceType, backedUp, transports, createdAt, lastUsedAt FROM admin_passkeys ORDER BY lastUsedAt DESC'
    );
  } catch (err: any) {
    console.warn('[PASSKEY] Lỗi đọc danh sách Passkey:', err.message);
    return [];
  }
}

export async function getPasskeyById(id: string): Promise<AdminPasskeyRecord | null> {
  try {
    const row = await dbGet<AdminPasskeyRecord>(
      'SELECT * FROM admin_passkeys WHERE id = ?',
      [id]
    );
    return row || null;
  } catch (err: any) {
    console.warn('[PASSKEY] Lỗi tìm Passkey theo ID:', err.message);
    return null;
  }
}

export async function savePasskey(p: AdminPasskeyRecord): Promise<void> {
  await dbRun(
    `INSERT INTO admin_passkeys (id, name, publicKey, counter, deviceType, backedUp, transports, createdAt, lastUsedAt)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       name = excluded.name,
       counter = excluded.counter,
       deviceType = excluded.deviceType,
       backedUp = excluded.backedUp,
       transports = excluded.transports,
       lastUsedAt = excluded.lastUsedAt`,
    [p.id, p.name, p.publicKey, p.counter, p.deviceType, p.backedUp, p.transports, p.createdAt, p.lastUsedAt]
  );
}

export async function updatePasskeyCounter(id: string, newCounter: number): Promise<void> {
  const now = new Date().toISOString();
  await dbRun(
    'UPDATE admin_passkeys SET counter = ?, lastUsedAt = ? WHERE id = ?',
    [newCounter, now, id]
  );
}

export async function renamePasskey(id: string, newName: string): Promise<boolean> {
  const res = await dbRun('UPDATE admin_passkeys SET name = ? WHERE id = ?', [newName.trim(), id]);
  return res.changes > 0;
}

export async function deletePasskey(id: string): Promise<boolean> {
  const res = await dbRun('DELETE FROM admin_passkeys WHERE id = ?', [id]);
  return res.changes > 0;
}

export async function countPasskeys(): Promise<number> {
  try {
    const row = await dbGet<{ count: number }>('SELECT COUNT(*) as count FROM admin_passkeys');
    return row?.count || 0;
  } catch {
    return 0;
  }
}

// ==========================================
// CẤP PHÁT & KIỂM TRA ADMIN JWT (PASSKEY TOKEN)
// ==========================================
export function signAdminJwt(payload: { credentialId: string; deviceName: string }): string {
  return jwt.sign(
    {
      sub: 'admin',
      role: 'admin',
      authMethod: 'passkey',
      credentialId: payload.credentialId,
      deviceName: payload.deviceName,
    },
    getJwtSecret(),
    { expiresIn: '30d' } // Phiên đăng nhập Passkey an toàn 30 ngày
  );
}

export function verifyAdminJwt(token: string): AdminTokenPayload | null {
  try {
    const decoded = jwt.verify(token, getJwtSecret()) as any;
    if (decoded && decoded.role === 'admin') {
      return decoded as AdminTokenPayload;
    }
  } catch {
    // Token không hợp lệ hoặc hết hạn
  }
  return null;
}

// ==========================================
// XÁC ĐỊNH RP ID VÀ ORIGIN PHÙ HỢP
// ==========================================
export function getEffectiveRpID(hostHeader?: string): string {
  if (!hostHeader) return 'localhost';
  const hostname = hostHeader.split(':')[0].toLowerCase();
  if (hostname === '127.0.0.1') return '127.0.0.1';
  if (hostname === 'localhost') return 'localhost';
  return hostname;
}

export function getEffectiveOrigins(reqOrigin?: string): string[] {
  const origins = new Set<string>([
    'http://localhost:3000',
    'http://localhost:5000',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:5000',
    'https://localhost:3000',
    'https://localhost:5000',
  ]);
  if (reqOrigin) {
    origins.add(reqOrigin);
  }
  return Array.from(origins);
}
