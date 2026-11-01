import { db } from '../server/core/firebase';

async function backfillPhoneLookup() {
  if (!db) {
    console.error('❌ Không thể kết nối Firebase Admin DB');
    process.exit(1);
  }

  console.log('🔍 Đang quét toàn bộ người dùng trong collection users...');
  const snapshot = await db.collection('users').get();
  console.log(`📊 Tìm thấy tổng cộng ${snapshot.size} tài khoản.`);

  let syncedCount = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const username = doc.id;
    let phone = data.phoneNumber;

    if (phone && typeof phone === 'string' && phone.trim().length > 0) {
      phone = phone.trim().replace(/\s+/g, '');
      if (phone.startsWith('0')) {
        phone = '+84' + phone.substring(1);
      } else if (!phone.startsWith('+')) {
        phone = '+' + phone;
      }

      const email = data.email || `${phone.replace('+', '')}@zenhome.local`;
      const uid = data.uid || '';

      console.log(`➡️ Đồng bộ: [${username}] SĐT: ${phone} -> Email: ${email}`);

      await db.collection('phone_lookup').doc(phone).set({
        email: email,
        username: username,
        uid: uid,
        syncedAt: new Date(),
      }, { merge: true });

      syncedCount++;
    }
  }

  console.log(`✅ Hoàn tất! Đã đồng bộ thành công ${syncedCount} bản ghi vào phone_lookup.`);
  process.exit(0);
}

backfillPhoneLookup().catch((err) => {
  console.error('❌ Lỗi:', err);
  process.exit(1);
});
