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
        try {
          const { removeUserDeviceBackup } = await import('./deviceStateBackup');
          removeUserDeviceBackup(doc.id);
        } catch (_) {}
      } else {
        validUidsInDb.add(uid);
      }
      // Bảo vệ UIDs của các thành viên được chia sẻ trong ngôi nhà
      if (Array.isArray(data.sharedUids)) {
        data.sharedUids.forEach((sUid: string) => {
          if (sUid) validUidsInDb.add(sUid);
        });
      }
    }

    // 2. Quét toàn bộ Firebase Auth
    const auth = getAuth();
    let pageToken: string | undefined = undefined;
    let hasMoreUsers = true;

    while (hasMoreUsers) {
      const listUsersResult = await auth.listUsers(1000, pageToken);
      
      for (const userRecord of listUsersResult.users) {
        // Ân hạn 24 giờ cho tài khoản mới tạo: Tránh xóa nhầm người dùng vừa đăng ký Google/SĐT đang chọn username
        const creationTime = userRecord.metadata?.creationTime;
        if (creationTime) {
          const ageHours = (Date.now() - new Date(creationTime).getTime()) / (1000 * 60 * 60);
          if (ageHours < 24) {
            continue; // Bỏ qua, đang trong thời gian ân hạn 24h
          }
        }

        // Nếu tài khoản Google/SĐT này không có username nào trong Database liên kết tới nó
        if (!validUidsInDb.has(userRecord.uid)) {
          console.log(`[CLEANUP] 🗑️ Đang xóa Auth User rác (>24h không có username): ${userRecord.uid}`);
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
  // Chạy vào lúc 03:00 sáng mỗi ngày theo múi giờ Việt Nam
  cron.schedule('0 3 * * *', () => {
    console.log('[CRON] ⏰ Khởi chạy tác vụ dọn dẹp tài khoản rác định kỳ...');
    cleanJunkAccounts();
  }, {
    timezone: 'Asia/Ho_Chi_Minh'
  });
  console.log('⏰ Đã thiết lập Cron Job: Dọn dẹp tài khoản rác (03:00 sáng hàng ngày theo múi giờ VN).');
}
