const { getAuth } = require('firebase-admin/auth');
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json.cjs');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function run() {
  const email = process.argv[2];
  if (!email) {
    console.log("Usage: node delete_user_by_email.js <email>");
    process.exit(1);
  }
  try {
    const user = await getAuth().getUserByEmail(email);
    await getAuth().deleteUser(user.uid);
    console.log(`Deleted user ${email} (UID: ${user.uid})`);
  } catch (e) {
    console.log("Error:", e.message);
  }
}
run();



