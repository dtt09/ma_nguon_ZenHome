import { useState, useEffect, useRef, useCallback } from 'react';
import { io, Socket } from 'socket.io-client';
import { collection, onSnapshot, query, limit, orderBy } from 'firebase/firestore';
import { db } from '../services/firebaseService';
import { DEFAULT_SERVER_URL, getAdminSecret } from '../services/backupServerService';
import { SystemAlert } from '../types/admin';

export function useSystemAlerts(enabled: boolean = true) {
  const [alerts, setAlerts] = useState<SystemAlert[]>([]);
  const [isSocketConnected, setIsSocketConnected] = useState<boolean>(false);
  const socketRef = useRef<Socket | null>(null);
  const isMountedRef = useRef<boolean>(true);

  // 1. Kết nối WebSocket Socket.io nhận sự kiện thời gian thực `system_alert`
  useEffect(() => {
    isMountedRef.current = true;
    const adminToken = getAdminSecret();
    if (!enabled || !adminToken) return;

    const socketUrl = DEFAULT_SERVER_URL || (typeof window !== 'undefined' ? window.location.origin : '');
    const socket = io(socketUrl, {
      reconnectionDelayMax: 5000,
      transports: ['polling', 'websocket'],
      auth: {
        token: adminToken,
      },
    });
    socketRef.current = socket;

    socket.on('connect', () => {
      if (isMountedRef.current) setIsSocketConnected(true);
    });

    socket.on('disconnect', () => {
      if (isMountedRef.current) setIsSocketConnected(false);
    });

    socket.on('system_alert', (newAlert: any) => {
      if (!isMountedRef.current || !newAlert) return;
      const normalizedAlert: SystemAlert = {
        id: newAlert.id || `alert_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
        type: newAlert.type || 'RELAY_CHATTERING_ANOMALY',
        level: newAlert.level || 'CRITICAL',
        title: newAlert.title || (newAlert.type === 'RELAY_CHATTERING_ANOMALY' ? 'Phát hiện Chattering / Chập Tải Rơ-le' : 'Cảnh Báo Dị Thường Phần Cứng'),
        message: newAlert.message || (newAlert.action ? `Hành động: ${newAlert.action}` : 'Rơ-le nhảy quá tần suất cho phép'),
        mac: newAlert.mac || newAlert.macAddress,
        pin: newAlert.pin,
        userId: newAlert.userId,
        action: newAlert.action || 'LOCKED_OFF',
        timestamp: newAlert.timestamp || new Date().toISOString(),
        acknowledged: false,
      };

      setAlerts(prev => {
        if (prev.some(a => a.id === normalizedAlert.id)) return prev;
        return [normalizedAlert, ...prev.slice(0, 49)];
      });
    });

    return () => {
      isMountedRef.current = false;
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
      }
    };
  }, [enabled]);

  // 2. Dự phòng: Đồng bộ collection `system_alerts` từ Firestore
  useEffect(() => {
    if (!enabled) return;

    let unsub: (() => void) | null = null;
    try {
      const colRef = collection(db, 'system_alerts');
      const q = query(colRef, limit(20));
      unsub = onSnapshot(q, (snapshot) => {
        if (!isMountedRef.current) return;
        const fetched: SystemAlert[] = [];
        snapshot.forEach(docSnap => {
          const data = docSnap.data();
          fetched.push({
            id: docSnap.id,
            type: data.type || 'SYSTEM_ANOMALY',
            level: data.level || 'CRITICAL',
            title: data.title || 'Cảnh Báo Dị Thường',
            message: data.message || '',
            mac: data.mac || data.macAddress,
            pin: data.pin,
            userId: data.userId,
            action: data.action,
            timestamp: data.timestamp || new Date().toISOString(),
            acknowledged: data.acknowledged ?? false,
          });
        });

        if (fetched.length > 0) {
          setAlerts(prev => {
            const merged = [...prev];
            fetched.forEach(f => {
              if (!merged.some(m => m.id === f.id)) {
                merged.push(f);
              }
            });
            return merged.slice(0, 50);
          });
        }
      }, (err) => {
        // Silently catch firestore rule limitations if collection not created yet
      });
    } catch (_) {}

    return () => {
      if (unsub) unsub();
    };
  }, [enabled]);

  const dismissAlert = useCallback((id: string) => {
    setAlerts(prev => prev.filter(a => a.id !== id));
  }, []);

  const clearAllAlerts = useCallback(() => {
    setAlerts([]);
  }, []);

  const activeAnomaliesCount = alerts.filter(a => !a.acknowledged).length;

  return {
    alerts,
    activeAnomaliesCount,
    isSocketConnected,
    dismissAlert,
    clearAllAlerts,
  };
}
