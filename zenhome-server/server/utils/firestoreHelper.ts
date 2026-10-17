import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const { db, FieldValue } = require('../core/firebase.cjs');

export interface UserLookupResult {
  id: string;
  ref: any;
  data: any;
}

/**
 * Tra cứu tài khoản người dùng thực tế từ Firestore
 * Hỗ trợ tìm kiếm linh hoạt theo:
 * 1. Document ID chính xác (vd: 'dtthuat')
 * 2. Document ID chữ thường (vd: 'dtthuat' khi truyền 'Dtthuat')
 * 3. Firebase Auth UID (vd: 'UT0tnCXDGehdN25KbXtHkrTOV3q2')
 * 4. Địa chỉ Email (vd: 'dinhtuthuat2103@gmail.com')
 * 5. Mặc định lấy tài khoản đầu tiên nếu không truyền userId
 */
export async function findUser(userId?: string): Promise<UserLookupResult | null> {
  if (!db) {
    throw new Error('Kết nối Firestore chưa được khởi tạo.');
  }

  // 1. Nếu không truyền userId, tìm người dùng đầu tiên trong collection 'users'
  if (!userId || userId.trim() === '') {
    const snap = await db.collection('users').limit(1).get();
    if (snap.empty) return null;
    const doc = snap.docs[0];
    return { id: doc.id, ref: doc.ref, data: doc.data() };
  }

  const cleanId = userId.trim();

  // 2. Thử tìm theo Document ID chính xác
  try {
    const docDirect = await db.collection('users').doc(cleanId).get();
    if (docDirect.exists) {
      return { id: docDirect.id, ref: docDirect.ref, data: docDirect.data() };
    }
  } catch (err) {
    // Tiếp tục fallback
  }

  // 3. Thử tìm theo Document ID chữ thường (lowercase)
  try {
    const lowerId = cleanId.toLowerCase();
    if (lowerId !== cleanId) {
      const docLower = await db.collection('users').doc(lowerId).get();
      if (docLower.exists) {
        return { id: docLower.id, ref: docLower.ref, data: docLower.data() };
      }
    }
  } catch (err) {
    // Tiếp tục fallback
  }

  // 4. Thử tìm theo trường 'uid'
  try {
    const queryUid = await db.collection('users').where('uid', '==', cleanId).limit(1).get();
    if (!queryUid.empty) {
      const doc = queryUid.docs[0];
      return { id: doc.id, ref: doc.ref, data: doc.data() };
    }
  } catch (err) {
    // Tiếp tục fallback
  }

  // 5. Thử tìm theo trường 'email'
  try {
    const queryEmail = await db.collection('users').where('email', '==', cleanId).limit(1).get();
    if (!queryEmail.empty) {
      const doc = queryEmail.docs[0];
      return { id: doc.id, ref: doc.ref, data: doc.data() };
    }
  } catch (err) {
    // Không tìm thấy
  }

  return null;
}

export { db, FieldValue };
