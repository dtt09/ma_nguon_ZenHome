const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getAuth } = require('firebase-admin/auth');

// ==========================================
// KHỞI TẠO FIREBASE ADMIN (Hệ Mới Nhất)
// ==========================================
const serviceAccount = require("../firebase-key.json");
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
db.settings({ preferRest: true });

module.exports = { db, FieldValue, getMessaging, getAuth };
