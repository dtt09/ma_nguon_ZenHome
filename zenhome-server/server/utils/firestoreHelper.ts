import { db, FieldValue } from '../core/firebase';

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
 * 5. Số điện thoại (vd: '0987654321' hoặc '+84987654321')
 */
export async function findUser(userId?: string): Promise<UserLookupResult | null> {
  if (!db) {
    throw new Error('Kết nối Firestore chưa được khởi tạo.');
  }

  // 1. Bắt buộc phải có userId, không tự ý fallback về tài khoản đầu tiên
  if (!userId || userId.trim() === '') {
    return null;
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
    // Tiếp tục fallback
  }

  // 6. Thử tìm theo trường 'phoneNumber' (hỗ trợ cả định dạng +84 và 0)
  try {
    let cleanPhone = cleanId;
    if (cleanPhone.startsWith('0')) {
      const altPhone = '+84' + cleanPhone.substring(1);
      const queryPhone = await db.collection('users').where('phoneNumber', 'in', [cleanPhone, altPhone]).limit(1).get();
      if (!queryPhone.empty) {
        const doc = queryPhone.docs[0];
        return { id: doc.id, ref: doc.ref, data: doc.data() };
      }
    } else if (cleanPhone.startsWith('+84')) {
      const altPhone = '0' + cleanPhone.substring(3);
      const queryPhone = await db.collection('users').where('phoneNumber', 'in', [cleanPhone, altPhone]).limit(1).get();
      if (!queryPhone.empty) {
        const doc = queryPhone.docs[0];
        return { id: doc.id, ref: doc.ref, data: doc.data() };
      }
    } else {
      const queryPhone = await db.collection('users').where('phoneNumber', '==', cleanPhone).limit(1).get();
      if (!queryPhone.empty) {
        const doc = queryPhone.docs[0];
        return { id: doc.id, ref: doc.ref, data: doc.data() };
      }
    }
  } catch (err) {
    // Không tìm thấy
  }

  return null;
}

export { db, FieldValue };
