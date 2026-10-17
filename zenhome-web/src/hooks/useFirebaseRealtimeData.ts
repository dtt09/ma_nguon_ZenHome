import { useState, useEffect, useRef, useCallback } from 'react';
import { 
  collection, 
  onSnapshot, 
  getDocs,
  getDoc,
  doc,
  updateDoc,
  deleteDoc
} from 'firebase/firestore';
import { db, formatFirestoreTimestamp } from '../services/firebaseService';
import { 
  RealCustomerUser, 
  RealSessionDoc, 
  RealDeviceItem, 
  RealCrashLog, 
  RealDatabaseDoc,
  RealSystemStats,
  RealBugReport 
} from '../types/admin';

export function useFirebaseRealtimeData() {
  const [customers, setCustomers] = useState<RealCustomerUser[]>([]);
  const [crashLogs, setCrashLogs] = useState<RealCrashLog[]>([]);
  const [bugReports, setBugReports] = useState<RealBugReport[]>([]);
  const [databaseDocs, setDatabaseDocs] = useState<RealDatabaseDoc[]>([]);
  const [stats, setStats] = useState<RealSystemStats>({
    totalCustomers: 0,
    totalSessions: 0,
    totalDevices: 0,
    totalCrashes: 0,
    onlineEspCount: 0,
    latestAppVersion: 'v1.5.0',
    latestBuildNumber: 150,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastSyncTime, setLastSyncTime] = useState<string>('');
  const [secondsAgo, setSecondsAgo] = useState<number>(0);
  const [pingMs, setPingMs] = useState<number>(24);
  const [syncCount, setSyncCount] = useState<number>(0);
  const [isLiveStreaming, setIsLiveStreaming] = useState<boolean>(true);
  const [autoRefreshInterval, setAutoRefreshInterval] = useState<number>(2); // 2s continuous interval

  // Core full-sync function: Reads all users, sessions, and crash logs from Firestore
  const performFullSync = useCallback(async () => {
    const startTime = Date.now();
    try {
      const usersSnap = await getDocs(collection(db, 'users'));
      const fetchedCustomers: RealCustomerUser[] = [];
      const rawDocsList: RealDatabaseDoc[] = [];
      let totalSessionsCount = 0;
      let totalDevicesCount = 0;
      const allCrashes: RealCrashLog[] = [];

      for (const uDoc of usersSnap.docs) {
        const uData = uDoc.data();
        const userId = uDoc.id;

        // Add user document to raw database docs
        rawDocsList.push({
          collection: 'users',
          id: userId,
          path: `users/${userId}`,
          data: uData,
          updatedAt: formatFirestoreTimestamp(uData.createdAt),
          sizeBytes: JSON.stringify(uData).length,
        });

        // 1. Fetch sessions subcollection for this user
        const sessions: RealSessionDoc[] = [];
        try {
          const sessionsSnap = await getDocs(collection(db, 'users', userId, 'sessions'));
          sessionsSnap.forEach(sDoc => {
            const sData = sDoc.data();
            totalSessionsCount++;

            rawDocsList.push({
              collection: `users/${userId}/sessions`,
              id: sDoc.id,
              path: `users/${userId}/sessions/${sDoc.id}`,
              data: sData,
              updatedAt: formatFirestoreTimestamp(sData.lastAccess || sData.lastLogin),
              sizeBytes: JSON.stringify(sData).length,
            });

            sessions.push({
              id: sDoc.id,
              deviceName: sData.deviceName || 'Không rõ thiết bị',
              os: sData.os || 'Android/iOS',
              location: sData.location || 'Chưa cập nhật',
              isActive: sData.isActive ?? true,
              isTrusted: sData.isTrusted ?? true,
              fcmToken: sData.fcmToken || 'Chưa tạo',
              lastLogin: formatFirestoreTimestamp(sData.lastLogin),
              firstSeen: formatFirestoreTimestamp(sData.firstSeen),
              lastAccess: formatFirestoreTimestamp(sData.lastAccess),
              appVersion: sData.appVersion || '1.5.0',
              buildNumber: sData.buildNumber || 150,
              raw: sData,
            });
          });
        } catch (e) {
          // ignore subcollection read errors
        }

        // 2. Fetch crash_logs subcollection for this user
        const userCrashes: RealCrashLog[] = [];
        try {
          const crashSnap = await getDocs(collection(db, 'users', userId, 'crash_logs'));
          crashSnap.forEach(cDoc => {
            const cData = cDoc.data();
            rawDocsList.push({
              collection: `users/${userId}/crash_logs`,
              id: cDoc.id,
              path: `users/${userId}/crash_logs/${cDoc.id}`,
              data: cData,
              updatedAt: formatFirestoreTimestamp(cData.timestamp),
              sizeBytes: JSON.stringify(cData).length,
            });

            const crashItem: RealCrashLog = {
              id: cDoc.id,
              userId,
              userName: uData.displayName || userId,
              userEmail: uData.email || '',
              timestamp: formatFirestoreTimestamp(cData.timestamp),
              errorTitle: cData.errorTitle || 'Ngoại lệ không xác định',
              errorMessage: cData.errorMessage || String(cData),
              severity: cData.severity || 'error',
              stackTrace: cData.stackTrace || '',
              deviceModel: cData.deviceModel || sessions[0]?.deviceName || 'Thiết bị di động',
              osVersion: cData.osVersion || sessions[0]?.os || 'OS',
              isResolved: cData.isResolved ?? false,
              raw: cData,
            };
            userCrashes.push(crashItem);
            allCrashes.push(crashItem);
          });
        } catch (e) {}

        // 3. Parse devices array from user doc
        const rawDevicesList = Array.isArray(uData.devices) ? uData.devices : [];
        totalDevicesCount += rawDevicesList.length;
        const parsedDevices: RealDeviceItem[] = rawDevicesList.map((d: any, idx: number) => ({
          id: d.id || `dev_${idx}`,
          name: d.name || `Kênh ${idx + 1}`,
          pin: typeof d.pin === 'number' ? d.pin : idx,
          type: d.type || 'relay',
          isOn: d.isOn ?? false,
          room: d.room || 'Phòng chính',
          powerWatts: d.powerWatts || 45,
        }));

        fetchedCustomers.push({
          id: userId,
          uid: uData.uid || userId,
          displayName: uData.displayName || userId,
          email: uData.email || 'Không có email',
          phoneNumber: uData.phoneNumber || 'Chưa cập nhật',
          macAddress: uData.macAddress || 'Chưa liên kết',
          createdAt: formatFirestoreTimestamp(uData.createdAt),
          devices: parsedDevices,
          sessions,
          crashLogs: userCrashes,
          rawDoc: uData,
        });
      }

      // Check top-level crash_logs
      try {
        const topCrashSnap = await getDocs(collection(db, 'crash_logs'));
        topCrashSnap.forEach(cd => {
          const cdData = cd.data();
          rawDocsList.push({
            collection: 'crash_logs',
            id: cd.id,
            path: `crash_logs/${cd.id}`,
            data: cdData,
            updatedAt: formatFirestoreTimestamp(cdData.timestamp),
            sizeBytes: JSON.stringify(cdData).length,
          });

          allCrashes.push({
            id: cd.id,
            userId: cdData.userId || 'Hệ thống',
            userName: cdData.userName || cdData.userId || 'Người dùng',
            userEmail: cdData.userEmail || '',
            timestamp: formatFirestoreTimestamp(cdData.timestamp),
            errorTitle: cdData.errorTitle || 'Lỗi hệ thống',
            errorMessage: cdData.errorMessage || '',
            severity: cdData.severity || 'error',
            stackTrace: cdData.stackTrace || '',
            deviceModel: cdData.deviceModel || 'N/A',
            isResolved: cdData.isResolved ?? false,
            raw: cdData,
          });
        });
      } catch (e) {}

      // Fetch top-level bug_reports
      const allReports: RealBugReport[] = [];
      try {
        const repSnap = await getDocs(collection(db, 'bug_reports'));
        repSnap.forEach(rd => {
          const rData = rd.data();
          rawDocsList.push({
            collection: 'bug_reports',
            id: rd.id,
            path: `bug_reports/${rd.id}`,
            data: rData,
            updatedAt: formatFirestoreTimestamp(rData.createdAt),
            sizeBytes: JSON.stringify(rData).length,
          });

          allReports.push({
            id: rd.id,
            userId: rData.userId || 'Ẩn danh',
            authorName: rData.authorName || 'Người dùng ZenHome',
            contactInfo: rData.contactInfo || 'Chưa cung cấp',
            category: rData.category || 'other',
            title: rData.title || 'Báo cáo sự cố',
            description: rData.description || '',
            deviceModel: rData.deviceModel || 'N/A',
            appVersion: rData.appVersion || 'N/A',
            buildNumber: rData.buildNumber,
            status: rData.status || 'open',
            createdAt: formatFirestoreTimestamp(rData.createdAt),
            raw: rData,
          });
        });
      } catch (e) {}

      // Fetch latest app version config from Firestore
      let latestAppVersion = '1.7.0';
      let latestBuildNumber = 170;
      try {
        const verSnap = await getDoc(doc(db, 'system_config', 'app_version'));
        if (verSnap.exists()) {
          const vData = verSnap.data();
          latestAppVersion = vData.latestVersion || '1.7.0';
          latestBuildNumber = Number(vData.latestBuildNumber) || 170;
        }
      } catch (_) {}

      setCustomers(fetchedCustomers);
      setCrashLogs(allCrashes);
      setBugReports(allReports);
      setDatabaseDocs(rawDocsList);

      setStats({
        totalCustomers: fetchedCustomers.length,
        totalSessions: totalSessionsCount,
        totalDevices: totalDevicesCount,
        totalCrashes: allCrashes.length,
        totalReports: allReports.length,
        onlineEspCount: fetchedCustomers.filter(c => c.macAddress && c.macAddress !== 'Chưa liên kết').length,
        latestAppVersion: `v${latestAppVersion}`,
        latestBuildNumber: latestBuildNumber,
      });

      const elapsed = Date.now() - startTime;
      setPingMs(Math.max(15, elapsed));
      setSecondsAgo(0);
      setLastSyncTime(new Date().toLocaleTimeString('vi-VN'));
      setSyncCount(prev => prev + 1);
      setIsLoading(false);
      setError(null);
    } catch (err: any) {
      console.warn('Lỗi khi đồng bộ Firestore:', err);
      setError(`Lỗi kết nối Firestore: ${err.message}`);
      setIsLoading(false);
    }
  }, []);

  // 1. Initial immediate sync on mount
  useEffect(() => {
    performFullSync();
  }, [performFullSync]);

  // 2. Real-time Snapshot Listener on /users & /bug_reports
  useEffect(() => {
    const usersColRef = collection(db, 'users');
    const reportsColRef = collection(db, 'bug_reports');

    const unsubUsers = onSnapshot(usersColRef, () => {
      performFullSync();
    }, (err) => {
      console.warn('Firestore snapshot warning:', err.message);
    });

    const unsubReports = onSnapshot(reportsColRef, () => {
      performFullSync();
    }, (err) => {
      console.warn('Bug reports snapshot warning:', err.message);
    });

    return () => {
      unsubUsers();
      unsubReports();
    };
  }, [performFullSync]);

  // 3. Continuous Active Polling Interval (every 2 seconds)
  useEffect(() => {
    if (!isLiveStreaming) return;

    const intervalTimer = setInterval(() => {
      performFullSync();
    }, Math.max(1500, autoRefreshInterval * 1000));

    return () => clearInterval(intervalTimer);
  }, [isLiveStreaming, autoRefreshInterval, performFullSync]);

  // 4. Seconds counter tick
  useEffect(() => {
    const ticker = setInterval(() => {
      setSecondsAgo(prev => prev + 1);
    }, 1000);
    return () => clearInterval(ticker);
  }, []);

  const updateReportStatus = async (reportId: string, status: 'open' | 'investigating' | 'resolved') => {
    try {
      await updateDoc(doc(db, 'bug_reports', reportId), { status });
      setBugReports(prev => prev.map(r => r.id === reportId ? { ...r, status } : r));
    } catch (e: any) {
      console.error('Lỗi cập nhật trạng thái báo cáo:', e);
      throw e;
    }
  };

  const deleteReport = async (reportId: string) => {
    try {
      await deleteDoc(doc(db, 'bug_reports', reportId));
      setBugReports(prev => prev.filter(r => r.id !== reportId));
    } catch (e: any) {
      console.error('Lỗi xóa báo cáo:', e);
      throw e;
    }
  };

  return {
    customers,
    crashLogs,
    bugReports,
    databaseDocs,
    stats,
    isLoading,
    error,
    lastSyncTime,
    secondsAgo,
    pingMs,
    syncCount,
    isLiveStreaming,
    setIsLiveStreaming,
    autoRefreshInterval,
    setAutoRefreshInterval,
    triggerManualSync: performFullSync,
    updateReportStatus,
    deleteReport,
    markCustomerDeleted: (userId: string) => {
      setCustomers(prev => prev.filter(c => c.id !== userId));
      setDatabaseDocs(prev => prev.filter(d => !d.path.startsWith(`users/${userId}`)));
    },
  };
}
