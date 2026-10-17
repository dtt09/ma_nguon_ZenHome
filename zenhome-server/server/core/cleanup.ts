import cron from 'node-cron';
import { db, getAuth } from './firebase';

export async function cleanJunkAccounts() {
  console.log("[CLEANUP] 🧹 Bắt đầu dọn dẹp tài khoản rác...");
  
  let deletedFirestoreDocs = 0;
  let deletedAuthUsers = 0;

  try {
    // 1. Quét Firestore 'users' collection
    const usersSnapshot = await db.collection('users').get();
    const validUidsInDb = new Set<string>();
    
    for (const doc of usersSnapshot.docs) {
      const data = doc.data();
      const uid = data.uid;
      
      // Nếu username không có liên kết (uid rỗng/null)
      if (!uid) {
        console.log(`[CLEANUP] 🗑️ Đang xóa username rác (không có uid): ${doc.id}`);
        await doc.ref.delete();
        deletedFirestoreDocs++;
      } else {
        validUidsInDb.add(uid);
      }
    }

    // 2. Quét toàn bộ Firebase Auth
    const auth = getAuth();
    let pageToken: string | undefined = undefined;
    let hasMoreUsers = true;

    while (hasMoreUsers) {
      const listUsersResult = await auth.listUsers(1000, pageToken);
      
      for (const userRecord of listUsersResult.users) {
        // Nếu tài khoản Google/SĐT này không có username nào trong Database liên kết tới nó
        if (!validUidsInDb.has(userRecord.uid)) {
          console.log(`[CLEANUP] 🗑️ Đang xóa Auth User rác (không có username): ${userRecord.uid}`);
          await auth.deleteUser(userRecord.uid);
          deletedAuthUsers++;
        }
      }

      pageToken = listUsersResult.pageToken;
      if (!pageToken) {
        hasMoreUsers = false;
      }
    }

    console.log("[CLEANUP] ✅ Dọn dẹp hoàn tất!");
    console.log(`[CLEANUP] - Đã xóa ${deletedFirestoreDocs} username rác trong Firestore.`);
    console.log(`[CLEANUP] - Đã xóa ${deletedAuthUsers} tài khoản rác trong Firebase Auth.`);
    return { deletedFirestoreDocs, deletedAuthUsers };
  } catch (error) {
    console.error("[CLEANUP] ❌ Lỗi trong quá trình dọn dẹp:", error);
    return { error };
  }
}

export function startJunkAccountCleanupCron() {
  // Chạy vào lúc 03:00 sáng mỗi ngày
  cron.schedule('0 3 * * *', () => {
    console.log('[CRON] ⏰ Khởi chạy tác vụ dọn dẹp tài khoản rác định kỳ...');
    cleanJunkAccounts();
  });
  console.log('⏰ Đã thiết lập Cron Job: Dọn dẹp tài khoản rác (03:00 sáng hàng ngày).');
}
