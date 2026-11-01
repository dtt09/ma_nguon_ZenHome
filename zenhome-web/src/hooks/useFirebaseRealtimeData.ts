import { useState, useEffect, useRef, useCallback } from 'react';
import { 
  collection, 
  onSnapshot, 
  getDocs, 
  getDoc, 
  doc, 
  updateDoc, 
  deleteDoc, 
  addDoc, 
  serverTimestamp 
} from 'firebase/firestore';
import { db, formatFirestoreTimestamp } from '../services/firebaseService';
import { getAdminSecret } from '../services/backupServerService';
import { 
  RealCustomerUser, 
  RealSessionDoc, 
  RealDeviceItem, 
  RealCrashLog, 
  RealDatabaseDoc, 
  RealSystemStats, 
  RealBugReport 
} from '../types/admin';

export function useFirebaseRealtimeData(enabled: boolean = true) {
  const [customers, setCustomers] = useState<RealCustomerUser[]>([]);
  const [crashLogs, setCrashLogs] = useState<RealCrashLog[]>([]);
  const [bugReports, setBugReports] = useState<RealBugReport[]>([]);
  const [databaseDocs, setDatabaseDocs] = useState<RealDatabaseDoc[]>([]);
  const [stats, setStats] = useState<RealSystemStats>({
    totalCustomers: 0,
    totalSessions: 0,
    totalDevices: 0,
    totalCrashes: 0,
    totalReports: 0,
    onlineEspCount: 0,
    latestAppVersion: 'v1.8.13',
    latestBuildNumber: 200,
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastSyncTime, setLastSyncTime] = useState<string>('');
  const [secondsAgo, setSecondsAgo] = useState<number>(0);
  const [pingMs, setPingMs] = useState<number>(24);
  const [syncCount, setSyncCount] = useState<number>(0);
  const [isLiveStreaming, setIsLiveStreaming] = useState<boolean>(true);
  const [autoRefreshInterval, setAutoRefreshInterval] = useState<number>(30); // 30s safe heartbeat interval

  const abortControllerRef = useRef<AbortController | null>(null);
  const snapshotDebounceTimerRef = useRef<any>(null);

  // Core full-sync function: Reads all users, sessions, crash logs, and bug reports
  const performFullSync = useCallback(async (isForced = false) => {
    // 0. Khử xung đột: Nếu tính năng chưa bật hoặc chưa đăng nhập, hủy ngay tránh lỗi 401
    const adminKey = getAdminSecret();
    if (!enabled || !adminKey) {
      setIsLoading(false);
      return;
    }

    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
      abortControllerRef.current = null;
    }

    const controller = new AbortController();
    abortControllerRef.current = controller;

    const startTime = Date.now();

    // 1. ƯU TIÊN SỐ 1: Đồng bộ qua Backend Unified API (với x-api-key Admin và Bearer Token)
    // Server sử dụng Firebase Admin SDK (độc quyền service account) nên vượt qua hoàn toàn các hạn chế phân quyền client-side
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'x-api-key': adminKey,
      'Authorization': `Bearer ${adminKey}`,
    };

    const url = isForced ? '/api/v1/system/dashboard-sync?force=true' : '/api/v1/system/dashboard-sync';

    try {
      const res = await fetch(url, { headers, signal: controller.signal });
      if (res.ok) {
        const json = await res.json();
        if (json.success) {
          const sanitizedCustomers = (json.customers || []).map((c: any) => ({
            ...c,
            createdAt: formatFirestoreTimestamp(c.createdAt),
            sessions: (c.sessions || []).map((s: any) => ({
              ...s,
              lastLogin: formatFirestoreTimestamp(s.lastLogin),
              firstSeen: formatFirestoreTimestamp(s.firstSeen),
              lastAccess: formatFirestoreTimestamp(s.lastAccess),
            })),
            crashLogs: (c.crashLogs || []).map((cr: any) => ({
              ...cr,
              timestamp: formatFirestoreTimestamp(cr.timestamp),
            })),
          }));

          const sanitizedCrashLogs = (json.crashLogs || []).map((cr: any) => ({
            ...cr,
            timestamp: formatFirestoreTimestamp(cr.timestamp),
          }));

          const sanitizedBugReports = (json.bugReports || []).map((b: any) => ({
            ...b,
            createdAt: formatFirestoreTimestamp(b.createdAt),
          }));

          const sanitizedDatabaseDocs = (json.databaseDocs || []).map((d: any) => ({
            ...d,
            updatedAt: formatFirestoreTimestamp(d.updatedAt),
          }));

          setCustomers(sanitizedCustomers);
          setCrashLogs(sanitizedCrashLogs);
          setBugReports(sanitizedBugReports);
          setDatabaseDocs(sanitizedDatabaseDocs);
          if (json.stats) setStats(json.stats);

          setPingMs(Math.max(12, Date.now() - startTime));
          setSecondsAgo(0);
          setLastSyncTime(new Date().toLocaleTimeString('vi-VN'));
          setSyncCount(prev => prev + 1);
          setIsLoading(false);
          setError(null);
          return;
        }
      }
    } catch (err: any) {
      if (err.name === 'AbortError') {
        // Yêu cầu bị hủy để nhường chỗ cho request mới nhất, không xử lý tiếp
        return;
      }
      // Backend API offline hoặc gặp sự cố, chuyển tiếp xuống dự phòng Firestore client-side
    }

    // 2. DỰ PHÒNG: Thử đọc trực tiếp từ Firestore qua Client SDK
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
              appVersion: sData.appVersion || '1.7.9',
              buildNumber: sData.buildNumber || 179,
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
              updatedAt: formatFirestoreTimestamp(cData.timestamp || cData.createdAt),
              sizeBytes: JSON.stringify(cData).length,
            });

            const crashItem: RealCrashLog = {
              id: cDoc.id,
              path: `users/${userId}/crash_logs/${cDoc.id}`,
              userId,
              userName: uData.displayName || userId,
              userEmail: uData.email || '',
              timestamp: formatFirestoreTimestamp(cData.timestamp || cData.createdAt),
              errorTitle: cData.errorTitle || 'Ngoại lệ không xác định',
              errorMessage: cData.errorMessage || String(cData),
              severity: cData.severity || 'error',
              stackTrace: cData.stackTrace || '',
              deviceModel: cData.deviceModel || sessions[0]?.deviceName || 'Thiết bị di động',
              osVersion: cData.osVersion || sessions[0]?.os || 'OS',
              appVersion: cData.appVersion || '1.7.9',
              source: cData.source || 'flutter_app',
              isResolved: cData.isResolved ?? false,
              raw: cData,
            };
            userCrashes.push(crashItem);
            if (!allCrashes.some(c => c.id === crashItem.id)) {
              allCrashes.push(crashItem);
            }
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
            updatedAt: formatFirestoreTimestamp(cdData.timestamp || cdData.createdAt),
            sizeBytes: JSON.stringify(cdData).length,
          });

          if (!allCrashes.some(c => c.id === cd.id)) {
            allCrashes.push({
              id: cd.id,
              path: `crash_logs/${cd.id}`,
              userId: cdData.userId || 'Hệ thống',
              userName: cdData.userName || cdData.userId || 'Người dùng',
              userEmail: cdData.userEmail || '',
              timestamp: formatFirestoreTimestamp(cdData.timestamp || cdData.createdAt),
              errorTitle: cdData.errorTitle || 'Lỗi hệ thống',
              errorMessage: cdData.errorMessage || '',
              severity: cdData.severity || 'error',
              stackTrace: cdData.stackTrace || '',
              deviceModel: cdData.deviceModel || 'N/A',
              osVersion: cdData.osVersion || 'N/A',
              appVersion: cdData.appVersion || '1.7.9',
              source: cdData.source || 'flutter_app',
              isResolved: cdData.isResolved ?? false,
              raw: cdData,
            });
          }
        });
      } catch (e) {}

      // Sắp xếp Crash Logs mới nhất lên đầu danh sách
      allCrashes.sort((a, b) => {
        const timeA = a.raw?.createdAt ? new Date(a.raw.createdAt).getTime() : 0;
        const timeB = b.raw?.createdAt ? new Date(b.raw.createdAt).getTime() : 0;
        return timeB - timeA;
      });

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
      let latestAppVersion = '1.7.9';
      let latestBuildNumber = 179;
      try {
        const verSnap = await getDoc(doc(db, 'system_config', 'app_version'));
        if (verSnap.exists()) {
          const vData = verSnap.data();
          latestAppVersion = vData.latestVersion || '1.7.9';
          latestBuildNumber = Number(vData.latestBuildNumber) || 179;
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

  // 1. Initial immediate sync on mount (Chỉ chạy khi đã xác thực admin)
  useEffect(() => {
    if (enabled && getAdminSecret()) {
      performFullSync(false);
    } else {
      setIsLoading(false);
    }
  }, [enabled, performFullSync]);

  // 2. Real-time Snapshot Listener on /users, /bug_reports & /crash_logs
  // Được Debounce 1.2s để tránh bão fetch khi nhiều documents thay đổi cùng lúc
  useEffect(() => {
    if (!enabled || !getAdminSecret()) return;

    const triggerDebouncedSync = () => {
      if (snapshotDebounceTimerRef.current) {
        clearTimeout(snapshotDebounceTimerRef.current);
      }
      snapshotDebounceTimerRef.current = setTimeout(() => {
        performFullSync(false);
      }, 1200);
    };

    const usersColRef = collection(db, 'users');
    const reportsColRef = collection(db, 'bug_reports');
    const crashesColRef = collection(db, 'crash_logs');

    const unsubUsers = onSnapshot(usersColRef, () => {
      triggerDebouncedSync();
    }, (err) => {
      if (!err.message?.includes('insufficient permissions')) {
        console.warn('Firestore users snapshot warning:', err.message);
      }
    });

    const unsubReports = onSnapshot(reportsColRef, () => {
      triggerDebouncedSync();
    }, (err) => {
      if (!err.message?.includes('insufficient permissions')) {
        console.warn('Bug reports snapshot warning:', err.message);
      }
    });

    const unsubCrashes = onSnapshot(crashesColRef, () => {
      triggerDebouncedSync();
    }, (err) => {
      if (!err.message?.includes('insufficient permissions')) {
        console.warn('Crash logs snapshot warning:', err.message);
      }
    });

    return () => {
      if (snapshotDebounceTimerRef.current) {
        clearTimeout(snapshotDebounceTimerRef.current);
      }
      unsubUsers();
      unsubReports();
      unsubCrashes();
    };
  }, [enabled, performFullSync]);

  // 3. Tab Visibility Awareness: Tạm dừng polling khi tab bị ẩn, kích hoạt lại ngay khi quay lại tab
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (!document.hidden && isLiveStreaming && enabled && getAdminSecret()) {
        performFullSync(true);
      }
    };
    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [enabled, isLiveStreaming, performFullSync]);

  // 4. Continuous Active Polling Interval (Chỉ chạy khi tab đang active & đã xác thực admin)
  useEffect(() => {
    if (!enabled || !isLiveStreaming || !getAdminSecret()) return;

    const intervalTimer = setInterval(() => {
      if (!document.hidden) {
        performFullSync(false);
      }
    }, Math.max(2000, autoRefreshInterval * 1000));

    return () => clearInterval(intervalTimer);
  }, [enabled, isLiveStreaming, autoRefreshInterval, performFullSync]);

  // 4. Seconds counter tick
  useEffect(() => {
    const ticker = setInterval(() => {
      setSecondsAgo(prev => prev + 1);
    }, 1000);
    return () => clearInterval(ticker);
  }, []);

  const updateReportStatus = async (reportId: string, status: 'open' | 'investigating' | 'resolved') => {
    setBugReports(prev => prev.map(r => r.id === reportId ? { ...r, status } : r));
    try {
      await updateDoc(doc(db, 'bug_reports', reportId), { status });
    } catch (e: any) {
      console.warn('Direct Firestore updateDoc failed, falling back to Backend API:', e);
      try {
        const adminKey = getAdminSecret();
        await fetch(`/api/v1/system/bug-reports/${reportId}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            ...(adminKey ? { 'x-api-key': adminKey } : {}),
          },
          body: JSON.stringify({ status }),
        });
      } catch (err) {
        console.error('Lỗi cập nhật trạng thái báo cáo:', err);
        throw err;
      }
    }
  };

  const deleteReport = async (reportId: string) => {
    setBugReports(prev => prev.filter(r => r.id !== reportId));
    try {
      await deleteDoc(doc(db, 'bug_reports', reportId));
    } catch (e: any) {
      console.warn('Direct Firestore deleteDoc failed, falling back to Backend API:', e);
      try {
        const adminKey = getAdminSecret();
        await fetch(`/api/v1/system/bug-reports/${reportId}`, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            ...(adminKey ? { 'x-api-key': adminKey } : {}),
          },
        });
      } catch (err) {
        console.error('Lỗi xóa báo cáo:', err);
        throw err;
      }
    }
  };

  // Cập nhật trạng thái giải quyết Crash Log (Đã xử lý / Mở lại)
  const toggleCrashResolved = async (crashId: string, currentResolved: boolean, customPath?: string) => {
    const newStatus = !currentResolved;
    // Cập nhật Optimistic UI ngay lập tức
    setCrashLogs(prev => prev.map(c => c.id === crashId ? { ...c, isResolved: newStatus } : c));

    try {
      const docPath = customPath || `crash_logs/${crashId}`;
      await updateDoc(doc(db, docPath), { isResolved: newStatus });
    } catch (e: any) {
      console.warn('Direct Firestore updateDoc failed, falling back to Backend API:', e);
      try {
        const adminKey = getAdminSecret();
        await fetch(`/api/v1/system/crash-logs/${crashId}/resolve`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            ...(adminKey ? { 'x-api-key': adminKey } : {}),
          },
          body: JSON.stringify({ isResolved: newStatus, path: customPath }),
        });
      } catch (err) {
        console.error('Lỗi cập nhật trạng thái lỗi:', err);
        performFullSync();
        throw err;
      }
    }
  };

  // Xóa bản ghi Crash Log
  const deleteCrashLog = async (crashId: string, customPath?: string) => {
    setCrashLogs(prev => prev.filter(c => c.id !== crashId));
    setDatabaseDocs(prev => prev.filter(d => d.id !== crashId));

    try {
      const docPath = customPath || `crash_logs/${crashId}`;
      await deleteDoc(doc(db, docPath));
    } catch (e: any) {
      console.warn('Direct Firestore deleteDoc failed, falling back to Backend API:', e);
      try {
        const adminKey = getAdminSecret();
        await fetch(`/api/v1/system/crash-logs/${crashId}`, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            ...(adminKey ? { 'x-api-key': adminKey } : {}),
          },
          body: JSON.stringify({ path: customPath }),
        });
      } catch (err) {
        console.error('Lỗi xóa crash log:', err);
        performFullSync();
        throw err;
      }
    }
  };

  // Tạo bản ghi lỗi kiểm thử (Test Crashlytics) để kiểm tra luồng Realtime
  const sendTestCrash = async () => {
    const testPayload = {
      userId: 'admin_test',
      userName: 'ZenHome Administrator',
      userEmail: 'admin@zenhome.io',
      errorTitle: 'ZenHomeTestException: Kiểm thử đồng bộ Crashlytics Realtime',
      errorMessage: 'Lỗi mô phỏng từ Bảng điều khiển Web Admin để xác nhận luồng Crashlytics & Firestore hoạt động.',
      severity: 'fatal',
      stackTrace: '#0   AdminConsole.triggerTestCrash (admin_dashboard.ts:42)\n#1   FirebaseRealtimeData.sendTestCrash (useFirebaseRealtimeData.ts:285)\n#2   HTMLButtonElement.onClick (ErrorLogsView.tsx:65)',
      deviceModel: 'ZenHome Web Admin Console',
      osVersion: navigator.userAgent.includes('Windows') ? 'Windows 11' : 'Web Browser',
      appVersion: '1.7.9',
      buildNumber: 179,
      isResolved: false,
      source: 'web_admin_test',
      createdAt: new Date().toISOString(),
      timestamp: serverTimestamp(),
    };

    try {
      await addDoc(collection(db, 'crash_logs'), testPayload);
      await performFullSync();
    } catch (e: any) {
      console.warn('Direct Firestore addDoc failed, falling back to Backend API:', e);
      try {
        await fetch('/api/v1/system/crash-logs/test', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
        });
        await performFullSync();
      } catch (err) {
        console.error('Lỗi gửi test crash log:', err);
        throw err;
      }
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
    triggerManualSync: () => performFullSync(true),
    updateReportStatus,
    deleteReport,
    toggleCrashResolved,
    deleteCrashLog,
    sendTestCrash,
    markCustomerDeleted: (userId: string) => {
      setCustomers(prev => prev.filter(c => c.id !== userId));
      setDatabaseDocs(prev => prev.filter(d => !d.path.startsWith(`users/${userId}`)));
    },
  };
}
