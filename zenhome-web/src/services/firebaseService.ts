import { initializeApp, getApps, getApp } from 'firebase/app';
import { 
  getFirestore, 
  initializeFirestore,
  collection, 
  getDocs, 
  onSnapshot, 
  doc, 
  getDoc,
  Timestamp,
  collectionGroup
} from 'firebase/firestore';

export const firebaseConfig = {
  apiKey: "AIzaSyCsLwYgFIS6D0hkaQzPGYc7gqab8wAH0dQ",
  authDomain: "smarthome-98dd7.firebaseapp.com",
  databaseURL: "https://smarthome-98dd7-default-rtdb.asia-southeast1.firebasedatabase.app",
  projectId: "smarthome-98dd7",
  storageBucket: "smarthome-98dd7.firebasestorage.app",
  messagingSenderId: "645075290078",
  appId: "1:645075290078:web:zenhome_admin"
};

export const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);

// Initialize Firestore with Auto-detect Long-Polling to guarantee reliable real-time streaming inside web iframes
export const db = initializeFirestore(app, {
  experimentalAutoDetectLongPolling: true,
});

// Helper to format Firestore Timestamps into readable strings
export function formatFirestoreTimestamp(val: any): string {
  if (!val) return 'Chưa cập nhật';
  if (val instanceof Timestamp) {
    return val.toDate().toLocaleString('vi-VN');
  }
  if (typeof val?.toDate === 'function') {
    return val.toDate().toLocaleString('vi-VN');
  }
  if (typeof val === 'object') {
    const sec = val._seconds ?? val.seconds;
    if (typeof sec === 'number') {
      return new Date(sec * 1000).toLocaleString('vi-VN');
    }
    return 'Chưa cập nhật';
  }
  if (typeof val === 'string') {
    if (val.includes('T') || val.includes('-')) {
      const d = new Date(val);
      if (!isNaN(d.getTime())) return d.toLocaleString('vi-VN');
    }
    return val;
  }
  if (typeof val === 'number') {
    return new Date(val).toLocaleString('vi-VN');
  }
  return String(val);
}
