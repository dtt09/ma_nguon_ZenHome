import { initializeApp, cert, getApps, ServiceAccount } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { getAuth } from 'firebase-admin/auth';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ==========================================
// KHỞI TẠO FIREBASE ADMIN (HỖ TRỢ ENV & FILE)
// ==========================================
let serviceAccount: ServiceAccount | null = null;

// 1. Kiểm tra biến môi trường FIREBASE_SERVICE_ACCOUNT_JSON (Production / Docker / Cloud)
if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    try {
        const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON.trim();
        const jsonStr = raw.startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf-8');
        serviceAccount = JSON.parse(jsonStr);
        console.log('[FIREBASE] 🔑 Đã nạp Firebase Service Account từ biến môi trường FIREBASE_SERVICE_ACCOUNT_JSON');
    } catch (e: any) {
        console.error('[FIREBASE] ❌ Lỗi phân tích JSON từ FIREBASE_SERVICE_ACCOUNT_JSON:', e.message);
    }
}

// 2. Kiểm tra đường dẫn file chỉ định bởi FIREBASE_KEY_PATH
if (!serviceAccount && process.env.FIREBASE_KEY_PATH) {
    const customPath = path.resolve(process.env.FIREBASE_KEY_PATH);
    if (fs.existsSync(customPath)) {
        try {
            serviceAccount = JSON.parse(fs.readFileSync(customPath, 'utf-8'));
            console.log(`[FIREBASE] 🔑 Đã nạp Firebase Service Account từ ${customPath}`);
        } catch (e: any) {
            console.error(`[FIREBASE] ❌ Lỗi đọc key từ ${customPath}:`, e.message);
        }
    }
}

// 3. Fallback tới file cục bộ trong thư mục gốc zenhome-server/firebase-key.json
if (!serviceAccount) {
    const localKeyPath = path.resolve(__dirname, '../../firebase-key.json');
    if (fs.existsSync(localKeyPath)) {
        try {
            serviceAccount = JSON.parse(fs.readFileSync(localKeyPath, 'utf-8'));
            console.log('[FIREBASE] 🔑 Đã nạp Firebase Service Account từ firebase-key.json cục bộ');
        } catch (e: any) {
            console.error('[FIREBASE] ❌ Lỗi đọc firebase-key.json cục bộ:', e.message);
        }
    }
}

if (!serviceAccount) {
    console.warn('[FIREBASE WARNING] ⚠️ Không tìm thấy Firebase Service Account! Vui lòng cung cấp FIREBASE_SERVICE_ACCOUNT_JSON hoặc file firebase-key.json');
}

if (getApps().length === 0) {
    if (serviceAccount) {
        initializeApp({ credential: cert(serviceAccount) });
    } else {
        // Fallback default app (e.g. Google Cloud Application Default Credentials)
        initializeApp();
    }
}

const db = getFirestore();
db.settings({ preferRest: true });

export { db, FieldValue, getMessaging, getAuth };
export default { db, FieldValue, getMessaging, getAuth };
