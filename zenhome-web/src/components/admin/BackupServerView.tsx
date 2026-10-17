import React, { useState, useEffect, useRef } from 'react';
import { 
  Server, 
  CheckCircle2, 
  AlertCircle, 
  RefreshCw, 
  HardDrive, 
  Terminal, 
  Activity, 
  Download, 
  Radio, 
  Zap, 
  Play, 
  Trash2, 
  Layers,
  Database,
  Cpu,
  Clock,
  Send,
  Sparkles,
  Wifi,
  WifiOff,
  Smartphone,
  Gauge,
  ArrowUpRight
} from 'lucide-react';
import { io, Socket } from 'socket.io-client';
import { 
  BackupServerStatus, 
  BackupRecord, 
  ServerTelemetryPayload,
  ServerMemoryInfo,
  ServerCpuInfo,
  ServerSystemRamInfo,
  ServerDiskInfo,
  SubsystemsInfo,
  ServerProcessInfo,
  checkBackupServerHealth, 
  triggerDatabaseBackupSnapshot, 
  fetchBackupRecords, 
} from '../../services/backupServerService';
import { AppVersionModal } from './AppVersionModal';

interface LiveLogEntry {
  id: string;
  timestamp: string;
  tag: string;
  message: string;
  rawFormatted: string;
  level: 'info' | 'warn' | 'error' | 'success';
}

interface ServerRamState {
  uptime: number;
  uptimeFormatted?: string;
  serverTimestamp?: number;
  serverTimeIso?: string;
  serverTimeFormatted?: string;
  cpu?: ServerCpuInfo;
  ram?: ServerSystemRamInfo;
  disk?: ServerDiskInfo;
  memory?: ServerMemoryInfo;
  subsystems?: SubsystemsInfo;
  processInfo?: ServerProcessInfo;
  pendingTasksCount: number;
  pendingTasks: Record<string, any>;
  activeTimersCount: number;
  activeTimers: Record<string, any>;
  activeSchedulesCount: number;
  activeSchedules: Record<string, any>;
  latestIndoorTemp?: Record<string, { temp: number; updatedAt: string }>;
  espOnlineStatus?: Record<string, { isOnline: boolean; lastSeen: string }>;
  connectedClients?: number;
}

export const BackupServerView: React.FC = () => {
  const [status, setStatus] = useState<BackupServerStatus | null>(null);
  const [telemetry, setTelemetry] = useState<ServerTelemetryPayload | null>(null);
  const [ramState, setRamState] = useState<ServerRamState | null>(null);
  const [logs, setLogs] = useState<LiveLogEntry[]>([]);
  const [backups, setBackups] = useState<BackupRecord[]>([]);

  // Telemetry & Real-time Live Clock / Ping State
  const [latencyMs, setLatencyMs] = useState<number | null>(null);
  const [isSocketConnected, setIsSocketConnected] = useState<boolean>(false);
  const [liveServerTime, setLiveServerTime] = useState<Date | null>(null);
  const [liveUptimeSeconds, setLiveUptimeSeconds] = useState<number>(0);
  const [isManualPinging, setIsManualPinging] = useState<boolean>(false);

  // Reference hooks to keep sync accurate without drift
  const serverTimeOffsetRef = useRef<number>(0);
  const baseUptimeRef = useRef<number>(0);
  const baseUptimeReceivedAtRef = useRef<number>(Date.now());
  const socketRef = useRef<Socket | null>(null);

  const [isChecking, setIsChecking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [autoScroll, setAutoScroll] = useState(true);
  const [searchLog, setSearchLog] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [notification, setNotification] = useState<string | null>(null);
  const [showVersionModal, setShowVersionModal] = useState(false);

  const terminalContainerRef = useRef<HTMLDivElement>(null);

  const showNotify = (msg: string) => {
    setNotification(msg);
    setTimeout(() => setNotification(null), 3500);
  };

  const SERVER_BASE = import.meta.env.VITE_API_URL || (typeof window !== 'undefined' ? window.location.origin : 'http://localhost:5000');

  // Helper formatters
  const formatUptime = (totalSec: number) => {
    if (!totalSec || totalSec <= 0) return '0 giây';
    const days = Math.floor(totalSec / 86400);
    const hours = Math.floor((totalSec % 86400) / 3600);
    const minutes = Math.floor((totalSec % 3600) / 60);
    const seconds = totalSec % 60;
    const parts = [];
    if (days > 0) parts.push(`${days} ngày`);
    if (hours > 0 || days > 0) parts.push(`${hours.toString().padStart(2, '0')} giờ`);
    parts.push(`${minutes.toString().padStart(2, '0')} phút`);
    parts.push(`${seconds.toString().padStart(2, '0')} giây`);
    return parts.join(' ');
  };

  const formatLiveClock = (d: Date | null) => {
    if (!d) return '--:--:--';
    return d.toLocaleTimeString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    });
  };

  const formatLiveDate = (d: Date | null) => {
    if (!d) return 'Đang đồng bộ máy chủ...';
    return d.toLocaleDateString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      weekday: 'long',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    });
  };

  const applyTelemetryData = (data: any) => {
    if (!data) return;

    if (typeof data.serverTimestamp === 'number') {
      serverTimeOffsetRef.current = data.serverTimestamp - Date.now();
    }
    if (typeof data.uptime === 'number') {
      baseUptimeRef.current = data.uptime;
      baseUptimeReceivedAtRef.current = Date.now();
      setLiveUptimeSeconds(data.uptime);
    }

    setTelemetry((prev: any) => ({
      ...(prev || {}),
      ...data,
    }));

    setRamState((prev: any) => ({
      ...prev,
      uptime: data.uptime ?? prev?.uptime ?? 0,
      uptimeFormatted: data.uptimeFormatted ?? prev?.uptimeFormatted,
      cpu: data.cpu ?? prev?.cpu,
      ram: data.ram ?? prev?.ram,
      disk: data.disk ?? prev?.disk,
      pendingTasksCount: data.pendingTasksCount ?? prev?.pendingTasksCount ?? 0,
      activeTimersCount: data.activeTimersCount ?? prev?.activeTimersCount ?? 0,
      activeSchedulesCount: data.activeSchedulesCount ?? prev?.activeSchedulesCount ?? 0,
      latestIndoorTemp: data.latestIndoorTemp ?? prev?.latestIndoorTemp,
      espOnlineStatus: data.espOnlineStatus ?? prev?.espOnlineStatus,
      memory: data.memory ?? prev?.memory,
      subsystems: data.subsystems ?? prev?.subsystems,
      processInfo: data.processInfo ?? prev?.processInfo,
      connectedClients: data.connectedClients ?? prev?.connectedClients,
    }));

    if (data.subsystems || data.memory || data.cpu || data.ram || data.disk) {
      setStatus((prev: any) => ({
        ...(prev || {}),
        cpu: data.cpu ?? prev?.cpu,
        ram: data.ram ?? prev?.ram,
        disk: data.disk ?? prev?.disk,
        memory: data.memory ?? prev?.memory,
        subsystems: data.subsystems ?? prev?.subsystems,
        processInfo: data.processInfo ?? prev?.processInfo,
        uptimeSeconds: data.uptime ?? prev?.uptimeSeconds ?? 0,
        uptimeFormatted: data.uptimeFormatted ?? prev?.uptimeFormatted,
        serverTimeFormatted: data.serverTimeFormatted ?? prev?.serverTimeFormatted,
      }));
    }
  };

  const fetchInitialLogs = async () => {
    try {
      const res = await fetch(`${SERVER_BASE}/api/node-server/logs`);
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data.logs)) {
          setLogs(data.logs);
        }
      }
    } catch (e) {
      console.warn('Lỗi fetch logs từ server:', e);
    }
  };

  // 1. Live 1-second Clock & Ticking Uptime Interval
  useEffect(() => {
    const tick = () => {
      const nowServerMs = Date.now() + serverTimeOffsetRef.current;
      setLiveServerTime(new Date(nowServerMs));
      if (baseUptimeRef.current > 0) {
        const elapsed = Math.floor((Date.now() - baseUptimeReceivedAtRef.current) / 1000);
        setLiveUptimeSeconds(baseUptimeRef.current + elapsed);
      }
    };
    tick();
    const clockInterval = setInterval(tick, 1000);
    return () => clearInterval(clockInterval);
  }, []);

  // 2. Connect to Real-time WebSockets & Bi-directional Ping-Pong
  useEffect(() => {
    fetchInitialLogs();

    const socket = io(SERVER_BASE, {
      reconnectionDelayMax: 5000,
      transports: ['websocket', 'polling'],
    });
    socketRef.current = socket;

    socket.on('connect', () => {
      console.log('Socket.io connected to ZenHome Server');
      setIsSocketConnected(true);
      setError(null);
      socket.emit('request_logs');
      socket.emit('request_telemetry');

      // Do initial ping immediately upon connect
      const pingStart = Date.now();
      socket.emit('client_ping', { clientTimestamp: pingStart }, (pong: any) => {
        const rtt = Math.max(1, Date.now() - pingStart);
        setLatencyMs(rtt);
        if (pong) applyTelemetryData(pong);
      });
    });

    socket.on('init_logs', (initialLogs: LiveLogEntry[]) => {
      if (Array.isArray(initialLogs)) {
        setLogs(initialLogs);
      }
    });

    socket.on('new_log', (logEntry: LiveLogEntry) => {
      if (logEntry) {
        setLogs((prev) => {
          if (prev.some(l => l.id === logEntry.id)) return prev;
          return [...prev.slice(-1500), logEntry];
        });
      }
    });

    socket.on('telemetry_update', (telemetryData: any) => {
      if (telemetryData) {
        applyTelemetryData(telemetryData);
      }
    });

    socket.on('server_pong', (pong: any) => {
      if (pong?.clientTimestamp) {
        const rtt = Math.max(1, Date.now() - pong.clientTimestamp);
        setLatencyMs(rtt);
      }
      if (pong) applyTelemetryData(pong);
    });

    socket.on('disconnect', () => {
      console.log('Socket.io disconnected');
      setIsSocketConnected(false);
      setLatencyMs(null);
    });

    socket.on('connect_error', (err) => {
      console.warn('Socket connect error:', err);
      setIsSocketConnected(false);
      setLatencyMs(null);
    });

    // Định kỳ gửi client_ping mỗi 3 giây để đo độ trễ truyền tin hai chiều
    const pingTimer = setInterval(() => {
      if (socket.connected) {
        const pingStart = Date.now();
        socket.emit('client_ping', { clientTimestamp: pingStart }, (pong: any) => {
          const rtt = Math.max(1, Date.now() - pingStart);
          setLatencyMs(rtt);
          if (pong) applyTelemetryData(pong);
        });
      }
    }, 3000);

    return () => {
      clearInterval(pingTimer);
      socket.disconnect();
    };
  }, []);

  // 3. Manual Ping Trigger
  const triggerManualPing = () => {
    if (!socketRef.current || !socketRef.current.connected) {
      showNotify('Máy chủ chưa kết nối WebSocket!');
      return;
    }
    setIsManualPinging(true);
    const pingStart = Date.now();
    socketRef.current.emit('client_ping', { clientTimestamp: pingStart }, (pong: any) => {
      const rtt = Math.max(1, Date.now() - pingStart);
      setLatencyMs(rtt);
      if (pong) applyTelemetryData(pong);
      setTimeout(() => setIsManualPinging(false), 300);
      showNotify(`Độ trễ hai chiều hiện tại: ${rtt} ms`);
    });
  };

  // 4. Load Status, RAM State & Backups via REST (Fallback & sync)
  const loadStatusAndState = async () => {
    setIsChecking(true);
    try {
      const [serverStatus, ramRes, loadedBackups] = await Promise.all([
        checkBackupServerHealth(),
        fetch(`${SERVER_BASE}/api/node-server/state`).then(r => r.json()),
        fetchBackupRecords(),
      ]);

      setStatus(serverStatus);
      applyTelemetryData(ramRes);
      setBackups(loadedBackups);
      setError(null);
    } catch (err: any) {
      setError(`Không thể kết nối máy chủ Node.js: ${err.message}`);
    } finally {
      setIsChecking(false);
    }
  };

  useEffect(() => {
    loadStatusAndState();
    // Giãn chu kỳ kiểm tra REST lên 30s vì WebSockets đã nhận telemetry thời gian thực
    const interval = setInterval(loadStatusAndState, 30000);
    return () => clearInterval(interval);
  }, []);

  // Auto scroll terminal
  useEffect(() => {
    if (autoScroll && terminalContainerRef.current) {
      terminalContainerRef.current.scrollTop = terminalContainerRef.current.scrollHeight;
    }
  }, [logs, autoScroll]);

  // Execute Node Server actions
  const handleTriggerAction = async (action: string, payload?: any) => {
    setActionLoading(action);
    try {
      const res = await fetch(`${SERVER_BASE}/api/node-server/action`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'Authorization': 'Bearer zenhome-admin-secret-2026'
        },
        body: JSON.stringify({ action, payload }),
      });
      const data = await res.json();
      if (data.success) {
        if (action === 'clear_logs') {
          setLogs([]);
        }
        showNotify(data.message);
      }
      await loadStatusAndState();
    } catch (e: any) {
      alert(`Lỗi thực thi: ${e.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const handleCreateBackup = async () => {
    setActionLoading('backup');
    try {
      const res = await triggerDatabaseBackupSnapshot();
      showNotify(res.message);
      await loadStatusAndState();
    } catch (err: any) {
      alert(`Lỗi khi tạo sao lưu: ${err.message}`);
    } finally {
      setActionLoading(null);
    }
  };

  const filteredLogs = logs.filter(l => {
    if (searchLog === '') return true;
    const q = searchLog.toLowerCase();
    
    if (q === 'error') {
      return l.level === 'error' || l.message.toLowerCase().includes('error');
    }

    return l.message.toLowerCase().includes(q) || l.tag.toLowerCase().includes(q);
  });

  return (
    <div className="space-y-6">
      
      {/* Top Banner - Real-time Synchronized UX */}
      <div className="rounded-3xl bg-gradient-to-br from-indigo-950 via-slate-900 to-blue-950 text-white p-8 border border-indigo-500/20 shadow-2xl relative overflow-hidden">
        {/* Abstract background elements */}
        <div className="absolute top-0 right-0 -mr-20 -mt-20 w-96 h-96 bg-indigo-700 dark:bg-indigo-600/10 rounded-full blur-3xl pointer-events-none"></div>
        <div className="absolute bottom-0 left-0 -ml-20 -mb-20 w-80 h-80 bg-indigo-600/10 rounded-full blur-3xl pointer-events-none"></div>
        
        <div className="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-8">
          <div className="flex-1">
            <div className="flex flex-wrap items-center gap-2 mb-4">
              <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-indigo-500/20 border border-indigo-400/30 text-xs font-semibold text-indigo-300 backdrop-blur-sm">
                {!isSocketConnected && error ? (
                  <>
                    <WifiOff className="w-3.5 h-3.5 text-rose-400" />
                    <span className="text-rose-300">Mất Kết Nối Máy Chủ</span>
                  </>
                ) : (
                  <>
                    <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse shadow-[0_0_8px_rgba(52,211,153,0.8)]" />
                    <span className="text-emerald-300">Live Engine Đang Hoạt Động (2 Chiều)</span>
                  </>
                )}
              </div>

              {/* Ping / Latency Badge */}
              <div className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-mono font-semibold backdrop-blur-sm border ${
                latencyMs === null 
                  ? 'bg-slate-800/60 border-slate-700 text-slate-300'
                  : latencyMs < 50
                  ? 'bg-emerald-500/20 border-emerald-400/30 text-emerald-300'
                  : latencyMs < 150
                  ? 'bg-sky-500/20 border-sky-400/30 text-sky-300'
                  : 'bg-amber-500/20 border-amber-400/30 text-amber-300'
              }`}>
                <Activity className="w-3.5 h-3.5" />
                <span>{latencyMs !== null ? `${latencyMs} ms • Siêu tốc` : 'Đang đo ping...'}</span>
              </div>

              {/* Connected clients pill */}
              <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-slate-800/50 border border-white/10 text-xs font-medium text-slate-300">
                <Radio className="w-3.5 h-3.5 text-indigo-400" />
                <span>{ramState?.connectedClients ?? 1} Web Admin đang mở</span>
              </div>
            </div>

            <h1 className="text-3xl font-extrabold tracking-tight text-white mb-2 drop-shadow-md">
              Node.js Worker & Backup Server
            </h1>
            <p className="text-sm text-slate-300 max-w-2xl leading-relaxed font-medium">
              Trung tâm giám sát và giao tiếp thời gian thực hai chiều (Bi-directional Telemetry): Lắng nghe sự kiện MQTT HiveMQ TLS, đồng bộ giờ chuẩn <code>Asia/Ho_Chi_Minh</code>, đo độ trễ mạng WebSocket, và duy trì tác vụ <code>node-cron</code>.
            </p>
          </div>

          <div className="flex flex-col gap-3 p-5 rounded-2xl bg-slate-900/70 border border-white/10 backdrop-blur-md min-w-[320px] shadow-2xl text-sm">
            {/* Live Server Clock Row */}
            <div className="flex items-center justify-between border-b border-white/10 pb-3">
              <span className="text-slate-400 flex items-center gap-1.5">
                <Clock className="w-4 h-4 text-indigo-400" /> Giờ Máy Chủ Thực
              </span>
              <div className="text-right">
                <div className="text-emerald-400 font-mono text-lg font-extrabold tracking-wider drop-shadow-[0_0_8px_rgba(52,211,153,0.4)]">
                  {formatLiveClock(liveServerTime)}
                </div>
                <div className="text-[11px] text-slate-400 font-medium">
                  Asia/Ho_Chi_Minh (GMT+7)
                </div>
              </div>
            </div>

            {/* Live Dynamic Uptime */}
            <div className="flex items-center justify-between border-b border-white/10 pb-2">
              <span className="text-slate-400 flex items-center gap-1.5">
                <Cpu className="w-4 h-4 text-cyan-400" /> Thời gian chạy
              </span>
              <span className="text-white font-mono font-medium text-xs">
                {liveUptimeSeconds > 0 ? formatUptime(liveUptimeSeconds) : 'Đang tính...'}
              </span>
            </div>

            {/* MQTT Subsystem Live State */}
            <div className="flex items-center justify-between border-b border-white/10 pb-2">
              <span className="text-slate-400 flex items-center gap-1.5">
                <Radio className="w-4 h-4 text-amber-400" /> MQTT HiveMQ TLS
              </span>
              {ramState?.subsystems?.mqtt?.connected ? (
                <span className="text-emerald-400 font-semibold text-xs flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                  ĐÃ KẾT NỐI
                </span>
              ) : (
                <span className="text-rose-400 font-semibold text-xs flex items-center gap-1">
                  <span className="w-2 h-2 rounded-full bg-rose-400" />
                  MẤT KẾT NỐI
                </span>
              )}
            </div>

            {/* Interactive Ping Button & Status */}
            <div className="flex items-center justify-between pt-1">
              <span className="text-slate-400 flex items-center gap-1.5">
                <Server className="w-4 h-4 text-fuchsia-400" /> Nhịp tim hai chiều
              </span>
              <button
                onClick={triggerManualPing}
                disabled={isManualPinging || !isSocketConnected}
                className="inline-flex items-center gap-1.5 px-3 py-1 text-xs font-semibold rounded-lg bg-indigo-500/30 hover:bg-indigo-500/50 text-indigo-200 border border-indigo-400/30 hover:border-indigo-400/60 transition-all active:scale-95 disabled:opacity-50"
                title="Bấm để gửi gói tin ping đo độ trễ ngay lập tức"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isManualPinging ? 'animate-spin' : ''}`} />
                <span>{isManualPinging ? 'Đang ping...' : 'Ping Test'}</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* ================================================================= */}
      {/* 1. BẢNG ĐIỀU KHIỂN TÀI NGUYÊN PHẦN CỨNG THỜI GIAN THỰC (HARDWARE METRICS) */}
      {/* ================================================================= */}
      <div>
        <div className="flex items-center justify-between mb-3 px-1">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 flex items-center gap-2">
            <Gauge className="w-4 h-4 text-indigo-500" />
            Giám Sát Mức Dùng Tài Nguyên Phần Cứng (Thời Gian Thực)
          </h3>
          <span className="text-[11px] font-mono text-slate-400 dark:text-slate-500">
            Node: {ramState?.processInfo?.nodeVersion || 'v22.x'} • {ramState?.processInfo?.platform || 'win32'} ({ramState?.processInfo?.arch || 'x64'})
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          
          {/* Card 1: MỨC DÙNG CPU (%) */}
          <div className="p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm hover:border-blue-400/50 hover:shadow-md transition-all flex flex-col justify-between">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="p-2 rounded-xl bg-blue-50 dark:bg-blue-950/60 text-blue-600 dark:text-blue-400">
                  <Cpu className="w-4 h-4" />
                </div>
                <span>Mức Dùng CPU</span>
              </span>
              {(() => {
                const cpuVal = ramState?.cpu?.usagePercent ?? 0;
                const badgeColor = cpuVal < 50 
                  ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400 border-emerald-500/20'
                  : cpuVal < 80
                  ? 'bg-amber-50 text-amber-600 dark:bg-amber-950/40 dark:text-amber-400 border-amber-500/20'
                  : 'bg-rose-50 text-rose-600 dark:bg-rose-950/40 dark:text-rose-400 border-rose-500/20';
                const label = cpuVal < 50 ? 'Êm ái' : cpuVal < 80 ? 'Vừa phải' : 'Tải cao';
                return (
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${badgeColor}`}>
                    {label}
                  </span>
                );
              })()}
            </div>

            <div className="my-2">
              <div className="flex items-baseline justify-between mb-1">
                <div className="flex items-baseline gap-1.5">
                  <span className="text-4xl font-extrabold font-mono text-slate-900 dark:text-slate-50">
                    {ramState?.cpu?.usagePercent ?? 0}
                  </span>
                  <span className="text-xl font-bold font-mono text-blue-600 dark:text-blue-400">%</span>
                </div>
                <span className="text-xs font-mono text-slate-500 dark:text-slate-400">
                  {ramState?.cpu?.cores ?? 8} Cores • {ramState?.cpu?.speedMhz ? `${(ramState.cpu.speedMhz / 1000).toFixed(1)} GHz` : 'Multi-core'}
                </span>
              </div>

              {/* Progress bar CPU */}
              <div className="w-full h-2.5 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden mt-2">
                <div 
                  className={`h-full rounded-full transition-all duration-700 ${
                    (ramState?.cpu?.usagePercent ?? 0) < 50
                      ? 'bg-gradient-to-r from-blue-500 to-indigo-500'
                      : (ramState?.cpu?.usagePercent ?? 0) < 80
                      ? 'bg-gradient-to-r from-amber-500 to-orange-500'
                      : 'bg-gradient-to-r from-rose-500 to-red-600'
                  }`}
                  style={{ width: `${Math.min(100, Math.max(3, ramState?.cpu?.usagePercent ?? 0))}%` }}
                />
              </div>
            </div>

            <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
              <span className="truncate max-w-[210px]" title={ramState?.cpu?.model || 'Vi xử lý hệ thống'}>
                {ramState?.cpu?.model || 'Bộ xử lý trung tâm'}
              </span>
              <span className="font-mono text-[11px] text-blue-500">Live delta 1.5s</span>
            </div>
          </div>

          {/* Card 2: MỨC DÙNG RAM (HỆ THỐNG & PROCESS) */}
          <div className="p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm hover:border-purple-400/50 hover:shadow-md transition-all flex flex-col justify-between">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="p-2 rounded-xl bg-purple-50 dark:bg-purple-950/60 text-purple-600 dark:text-purple-400">
                  <HardDrive className="w-4 h-4" />
                </div>
                <span>Mức Dùng RAM</span>
              </span>
              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-purple-50 text-purple-600 dark:bg-purple-950/40 dark:text-purple-400 border border-purple-500/20">
                {ramState?.ram?.usedPercent ?? (ramState?.memory?.heapPercent ?? 0)}% Bộ nhớ
              </span>
            </div>

            <div className="my-2">
              <div className="flex items-baseline justify-between mb-1">
                <div className="flex items-baseline gap-1.5">
                  <span className="text-3xl font-extrabold font-mono text-slate-900 dark:text-slate-50">
                    {ramState?.ram?.usedGB ?? (ramState?.memory?.heapUsedMB ? (ramState.memory.heapUsedMB / 1024).toFixed(1) : 0)}
                  </span>
                  <span className="text-sm font-semibold text-slate-400 dark:text-slate-500 font-mono">
                    / {ramState?.ram?.totalGB ?? 8} GB
                  </span>
                </div>
                <span className="text-xs font-mono text-purple-600 dark:text-purple-400 font-semibold">
                  Trống: {ramState?.ram?.freeGB ?? 0} GB
                </span>
              </div>

              {/* Progress bar System RAM */}
              <div className="w-full h-2.5 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden mt-2">
                <div 
                  className="h-full bg-gradient-to-r from-indigo-500 via-purple-500 to-fuchsia-500 rounded-full transition-all duration-700"
                  style={{ width: `${Math.min(100, Math.max(5, ramState?.ram?.usedPercent ?? ramState?.memory?.heapPercent ?? 15))}%` }}
                />
              </div>
            </div>

            <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
              <span title="Bộ nhớ Node.js Heap">
                Node Heap: <strong className="text-slate-700 dark:text-slate-200 font-mono">{ramState?.memory?.heapUsedMB ?? 0} MB</strong>
              </span>
              <span className="font-mono text-[11px]">RSS: {ramState?.memory?.rssMB ?? 0} MB</span>
            </div>
          </div>

          {/* Card 3: DUNG LƯỢNG Ổ CỨNG (DISK STORAGE) */}
          <div className="p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm hover:border-emerald-400/50 hover:shadow-md transition-all flex flex-col justify-between">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="p-2 rounded-xl bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400">
                  <Database className="w-4 h-4" />
                </div>
                <span>Dung Lượng Ổ Cứng</span>
              </span>
              {(() => {
                const diskVal = ramState?.disk?.usedPercent ?? 0;
                const badgeColor = diskVal < 70
                  ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400 border-emerald-500/20'
                  : diskVal < 90
                  ? 'bg-amber-50 text-amber-600 dark:bg-amber-950/40 dark:text-amber-400 border-amber-500/20'
                  : 'bg-rose-50 text-rose-600 dark:bg-rose-950/40 dark:text-rose-400 border-rose-500/20';
                const label = diskVal < 70 ? 'Dồi dào' : diskVal < 90 ? 'Vừa phải' : 'Sắp đầy';
                return (
                  <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold border ${badgeColor}`}>
                    {label}
                  </span>
                );
              })()}
            </div>

            <div className="my-2">
              <div className="flex items-baseline justify-between mb-1">
                <div className="flex items-baseline gap-1.5">
                  <span className="text-3xl font-extrabold font-mono text-slate-900 dark:text-slate-50">
                    {ramState?.disk?.usedGB ?? 0}
                  </span>
                  <span className="text-sm font-semibold text-slate-400 dark:text-slate-500 font-mono">
                    / {ramState?.disk?.totalGB ?? 100} GB
                  </span>
                </div>
                <span className="text-xs font-mono text-emerald-600 dark:text-emerald-400 font-semibold">
                  {ramState?.disk?.usedPercent ?? 0}% Đã dùng
                </span>
              </div>

              {/* Progress bar Disk */}
              <div className="w-full h-2.5 rounded-full bg-slate-100 dark:bg-slate-800 overflow-hidden mt-2">
                <div 
                  className={`h-full rounded-full transition-all duration-700 ${
                    (ramState?.disk?.usedPercent ?? 0) < 70
                      ? 'bg-gradient-to-r from-emerald-500 to-teal-500'
                      : (ramState?.disk?.usedPercent ?? 0) < 90
                      ? 'bg-gradient-to-r from-amber-500 to-orange-500'
                      : 'bg-gradient-to-r from-rose-500 to-red-600'
                  }`}
                  style={{ width: `${Math.min(100, Math.max(3, ramState?.disk?.usedPercent ?? 0))}%` }}
                />
              </div>
            </div>

            <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
              <span>Ổ đĩa: <strong className="text-slate-700 dark:text-slate-200 font-mono">{ramState?.disk?.drive || 'D:\\'}</strong></span>
              <span className="font-mono text-emerald-600 dark:text-emerald-400">Khả dụng: {ramState?.disk?.freeGB ?? 0} GB</span>
            </div>
          </div>

        </div>
      </div>

      {/* ================================================================= */}
      {/* 2. TRẠNG THÁI GIAO TIẾP HAI CHIỀU & THỜI GIAN THỰC (BI-DIRECTIONAL HEALTH) */}
      {/* ================================================================= */}
      <div>
        <div className="flex items-center justify-between mb-3 px-1">
          <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 flex items-center gap-2">
            <Radio className="w-4 h-4 text-emerald-500" />
            Trạng Thái Giao Tiếp Hai Chiều & Thời Gian Thực (Bi-directional Telemetry)
          </h3>
          <span className="text-[11px] font-mono text-emerald-500 flex items-center gap-1">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
            Live WebSocket Song Công
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          
          {/* Card 4: Độ Trễ Hai Chiều (Ping / Latency) */}
          <div className="p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm hover:border-indigo-400/40 transition-all flex flex-col justify-between">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="p-2 rounded-xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400">
                  <Activity className="w-4 h-4" />
                </div>
                <span>Độ Trễ Truyền Tin (RTT)</span>
              </span>
              <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold ${
                latencyMs === null 
                  ? 'bg-slate-100 text-slate-500 dark:bg-slate-800 dark:text-slate-400' 
                  : latencyMs < 50
                  ? 'bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400 border border-emerald-500/20'
                  : 'bg-amber-50 text-amber-600 dark:bg-amber-950/40 dark:text-amber-400'
              }`}>
                {latencyMs !== null ? (latencyMs < 50 ? '⚡ Siêu tốc' : latencyMs < 150 ? '✓ Ổn định' : '⚠ Chậm') : 'Đang kiểm tra'}
              </span>
            </div>

            <div className="my-2">
              <div className="flex items-baseline gap-2">
                <span className="text-3xl font-extrabold font-mono text-slate-900 dark:text-slate-50">
                  {latencyMs !== null ? latencyMs : '--'}
                </span>
                <span className="text-sm font-semibold text-slate-500 dark:text-slate-400">ms</span>
              </div>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                Giao tiếp hai chiều Socket.io (WebSocket TCP)
              </p>
            </div>

            <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs">
              <span className="text-slate-500">Chu kỳ đo: 3s/lần</span>
              <button
                onClick={triggerManualPing}
                disabled={isManualPinging}
                className="text-indigo-600 dark:text-indigo-400 font-semibold hover:underline flex items-center gap-1"
              >
                <RefreshCw className={`w-3 h-3 ${isManualPinging ? 'animate-spin' : ''}`} />
                Đo lại ngay
              </button>
            </div>
          </div>

          {/* Card 5: Đồng Hồ Thời Gian Thực Máy Chủ */}
          <div className="p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm hover:border-emerald-400/40 transition-all flex flex-col justify-between">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="p-2 rounded-xl bg-emerald-50 dark:bg-emerald-950/60 text-emerald-600 dark:text-emerald-400">
                  <Clock className="w-4 h-4" />
                </div>
                <span>Đồng Hồ Thực Máy Chủ</span>
              </span>
              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-emerald-50 text-emerald-600 dark:bg-emerald-950/40 dark:text-emerald-400 border border-emerald-500/20">
                GMT+7
              </span>
            </div>

            <div className="my-2">
              <div className="text-3xl font-extrabold font-mono text-emerald-600 dark:text-emerald-400 tracking-wider">
                {formatLiveClock(liveServerTime)}
              </div>
              <p className="text-xs font-medium text-slate-600 dark:text-slate-300 mt-1 capitalize">
                {formatLiveDate(liveServerTime)}
              </p>
            </div>

            <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs text-slate-500">
              <span>Múi giờ: Asia/Ho_Chi_Minh</span>
              <span className="text-emerald-500 font-medium">● Khớp 100%</span>
            </div>
          </div>

          {/* Card 6: Thời Gian Hoạt Động (Uptime) & Subsystems */}
          <div className="p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm hover:border-cyan-400/40 transition-all flex flex-col justify-between">
            <div className="flex items-center justify-between mb-3">
              <span className="text-xs font-bold text-slate-600 dark:text-slate-300 uppercase tracking-wider flex items-center gap-2">
                <div className="p-2 rounded-xl bg-cyan-50 dark:bg-cyan-950/60 text-cyan-600 dark:text-cyan-400">
                  <Zap className="w-4 h-4" />
                </div>
                <span>Thời Gian Chạy Liên Tục</span>
              </span>
              <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-cyan-50 text-cyan-600 dark:bg-cyan-950/40 dark:text-cyan-400 border border-cyan-500/20">
                Live Ticking
              </span>
            </div>

            <div className="my-2">
              <div className="text-lg font-bold font-mono text-slate-900 dark:text-slate-50 leading-snug">
                {liveUptimeSeconds > 0 ? formatUptime(liveUptimeSeconds) : 'Đang tính...'}
              </div>
              <div className="flex items-center gap-2 mt-1.5 text-xs text-slate-500 dark:text-slate-400">
                <span className="inline-flex items-center gap-1 text-emerald-500 font-medium">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500" /> MQTT HiveMQ: Online
                </span>
                <span>•</span>
                <span className="inline-flex items-center gap-1 text-violet-500 font-medium">
                  Firestore: Online
                </span>
              </div>
            </div>

            <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs text-slate-500">
              <span>Hẹn giờ: {ramState?.activeTimersCount ?? 0} • Lịch: {ramState?.activeSchedulesCount ?? 0}</span>
              <span className="font-mono text-slate-700 dark:text-slate-300">#{ramState?.processInfo?.pid || 'NodeJS'}</span>
            </div>
          </div>

        </div>
      </div>

      {/* Notification toast */}
      {notification && (
        <div className="p-4 rounded-2xl bg-emerald-500 text-white font-medium text-sm flex items-center gap-3 shadow-xl shadow-emerald-500/20 animate-in fade-in slide-in-from-top-4">
          <CheckCircle2 className="w-5 h-5 shrink-0" />
          <span>{notification}</span>
        </div>
      )}

      {/* Quick Interactive Worker Actions Bar - Redesigned to Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <button
          onClick={() => setShowVersionModal(true)}
          className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 hover:border-indigo-400 hover:shadow-md text-slate-700 dark:text-slate-300 transition-all group"
        >
          <div className="p-3 bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 dark:text-indigo-400 rounded-full group-hover:scale-110 transition-transform">
            <Smartphone className="w-6 h-6" />
          </div>
          <div className="text-center">
            <h4 className="font-bold text-sm group-hover:text-indigo-600 transition-colors">Phát Hành App OTA</h4>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Đẩy update lên App</p>
          </div>
        </button>

        <button
          onClick={() => handleTriggerAction('test_command', { topic: 'Dtthuat/ESP32_MAC/phong_khach/den_tran', state: '1' })}
          disabled={actionLoading !== null}
          className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 hover:border-indigo-300 hover:shadow-md text-slate-700 dark:text-slate-300 transition-all group disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <div className="p-3 bg-indigo-50 text-indigo-600 rounded-full group-hover:scale-110 transition-transform">
            <Send className="w-6 h-6" />
          </div>
          <div className="text-center">
            <h4 className="font-bold text-sm">Gửi Lệnh Test</h4>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Gửi lệnh MQTT Retry</p>
          </div>
        </button>

        <button
          onClick={() => handleTriggerAction('clean_junk')}
          disabled={actionLoading !== null}
          className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 hover:border-amber-300 hover:shadow-md text-slate-700 dark:text-slate-300 transition-all group disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <div className="p-3 bg-amber-50 text-amber-500 rounded-full group-hover:scale-110 transition-transform">
            <Sparkles className="w-6 h-6" />
          </div>
          <div className="text-center">
            <h4 className="font-bold text-sm">Dọn Rác DB</h4>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Xóa tài khoản ảo</p>
          </div>
        </button>

        <button
          onClick={handleCreateBackup}
          disabled={actionLoading !== null}
          className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 hover:border-emerald-400 hover:shadow-md text-slate-700 dark:text-slate-300 transition-all group disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <div className="p-3 bg-emerald-50 text-emerald-600 rounded-full group-hover:scale-110 transition-transform relative">
            <Database className="w-6 h-6" />
            {actionLoading === 'backup' && (
              <div className="absolute inset-0 border-2 border-emerald-400 rounded-full animate-ping"></div>
            )}
          </div>
          <div className="text-center">
            <h4 className="font-bold text-sm">Tạo Snapshot</h4>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Sao lưu Firestore</p>
          </div>
        </button>

        <button
          onClick={() => handleTriggerAction('clear_logs')}
          className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 hover:border-rose-300 hover:shadow-md text-slate-700 dark:text-slate-300 transition-all group"
        >
          <div className="p-3 bg-slate-100 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400 group-hover:bg-rose-50 group-hover:text-rose-500 rounded-full group-hover:scale-110 transition-transform">
            <Trash2 className="w-6 h-6" />
          </div>
          <div className="text-center">
            <h4 className="font-bold text-sm group-hover:text-rose-600 transition-colors">Xóa Terminal</h4>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Làm sạch Console</p>
          </div>
        </button>

        <button
          onClick={() => {
            if (window.confirm('Cảnh báo: Hành động này sẽ TẮT máy chủ Node.js ngay lập tức. Nếu bạn không chạy qua PM2 hoặc Docker, máy chủ sẽ không tự khởi động lại được. Tiếp tục?')) {
              handleTriggerAction('restart_server');
            }
          }}
          disabled={actionLoading !== null}
          className="flex flex-col items-center justify-center gap-3 p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 hover:border-fuchsia-400 hover:shadow-md text-slate-700 dark:text-slate-300 transition-all group disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <div className="p-3 bg-fuchsia-50 text-fuchsia-600 rounded-full group-hover:scale-110 transition-transform">
            <RefreshCw className="w-6 h-6" />
          </div>
          <div className="text-center">
            <h4 className="font-bold text-sm">Restart Server</h4>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">Gửi lệnh Reboot</p>
          </div>
        </button>
      </div>

      {/* Real-time Streaming Terminal (DARK THEME UX IMPROVED) */}
      <div className="rounded-2xl border border-slate-800 shadow-2xl overflow-hidden flex flex-col font-mono text-sm bg-[#0A0A0B]">
        
        {/* Terminal Header */}
        <div className="px-5 py-3 bg-[#18181B] border-b border-slate-800 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <span className="w-3 h-3 rounded-full bg-rose-500 shadow-[0_0_5px_rgba(244,63,94,0.5)]" />
              <span className="w-3 h-3 rounded-full bg-amber-500 shadow-[0_0_5px_rgba(245,158,11,0.5)]" />
              <span className="w-3 h-3 rounded-full bg-emerald-500 shadow-[0_0_5px_rgba(16,185,129,0.5)]" />
            </div>
            <div className="flex items-center gap-2 text-slate-300 text-xs font-semibold tracking-wide uppercase">
              <Terminal className="w-4 h-4 text-slate-400" />
              <span>zenhome-worker-stdout</span>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row items-center gap-3 w-full lg:w-auto mt-3 lg:mt-0">
            {/* Tag Filter Chips */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0 hide-scrollbar w-full sm:w-auto">
              {['ALL', 'CRON', 'FIREBASE', 'ERROR', 'BACKEND'].map(tag => (
                <button
                  key={tag}
                  onClick={() => setSearchLog(tag === 'ALL' ? '' : tag === 'ERROR' ? 'error' : `[${tag}]`)}
                  className={`px-2.5 py-1 text-[10px] font-bold rounded-md transition-colors whitespace-nowrap ${
                    (tag === 'ALL' && searchLog === '') || (searchLog.toUpperCase().includes(tag))
                      ? 'bg-indigo-500 text-white'
                      : 'bg-[#27272A] text-slate-400 hover:bg-[#3F3F46] hover:text-slate-200'
                  }`}
                >
                  {tag}
                </button>
              ))}
            </div>

            <div className="w-px h-5 bg-slate-700 hidden sm:block"></div>
            {/* Search Filter */}
            <div className="relative">
              <input
                type="text"
                value={searchLog}
                onChange={(e) => setSearchLog(e.target.value)}
                placeholder="Lọc log..."
                className="px-3 py-1.5 pl-8 text-xs rounded-md bg-[#27272A] border border-slate-700 text-slate-200 placeholder-slate-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 w-48 transition-all"
              />
              <svg className="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
            </div>

            {/* Auto scroll toggle */}
            <label className="flex items-center gap-2 text-xs text-slate-400 cursor-pointer select-none hover:text-slate-200 transition-colors">
              <div className="relative flex items-center">
                <input
                  type="checkbox"
                  checked={autoScroll}
                  onChange={(e) => setAutoScroll(e.target.checked)}
                  className="sr-only"
                />
                <div className={`block w-8 h-4.5 rounded-full transition-colors ${autoScroll ? 'bg-indigo-500' : 'bg-slate-600'}`}></div>
                <div className={`absolute left-0.5 top-0.5 bg-white dark:bg-slate-900 w-3.5 h-3.5 rounded-full transition-transform ${autoScroll ? 'transform translate-x-3.5' : ''}`}></div>
              </div>
              <span>Cuộn tự động</span>
            </label>

            <span className="px-2.5 py-1 rounded-md bg-indigo-500/20 text-xs text-indigo-300 font-semibold">
              {filteredLogs.length} lines
            </span>
          </div>
        </div>

        {/* Terminal Stream Body */}
        <div 
          ref={terminalContainerRef}
          className="p-5 h-[40rem] overflow-y-auto space-y-1 text-slate-300 font-mono text-xs leading-snug custom-scrollbar"
        >
          {filteredLogs.length === 0 ? (
            <div className="flex flex-col items-center justify-center h-full text-slate-500 dark:text-slate-400 space-y-4">
              <Activity className="w-8 h-8 animate-pulse opacity-50" />
              <p className="italic">Đang chờ tín hiệu từ Worker Engine...</p>
            </div>
          ) : (
            filteredLogs.map((item) => {
              const isCron = item.tag === '[CRON]' || item.tag === '[CRON-QA]';
              const isFirebase = item.tag === '[FIREBASE]';
              const isEsp = item.tag === '[ESP]';
              const isSend = item.tag === '[SEND]';
              const isRetry = item.tag === '[RETRY]' || item.tag === '[TIMEOUT]';
              const isBackend = item.tag === '[BACKEND]' || item.tag === '[CLEANUP]';

              return (
                <div key={item.id} className="flex items-start gap-3 hover:bg-white dark:bg-slate-900/5 p-0.5 rounded-sm transition-colors group">
                  <span className="text-slate-500 dark:text-slate-400 select-none shrink-0 border-r border-slate-700 pr-3 font-mono">
                    {(() => {
                      if (!item.timestamp) return '';
                      const parts = item.timestamp.split(' ');
                      if (parts[0] && parts[0].includes(':')) return parts[0];
                      if (parts[1] && parts[1].includes(':')) return parts[1];
                      return item.timestamp;
                    })()}
                  </span>
                  
                  <span className={`font-bold shrink-0 w-24 ${
                    isCron ? 'text-fuchsia-400' :
                    isFirebase ? 'text-amber-400' :
                    isEsp ? 'text-cyan-400' :
                    isSend ? 'text-blue-400' :
                    isRetry ? 'text-rose-400' :
                    isBackend ? 'text-indigo-400' :
                    'text-slate-400'
                  }`}>
                    {item.tag}
                  </span>

                  <span className={`flex-1 break-words ${
                    item.level === 'error' ? 'text-rose-400' :
                    item.level === 'warn' ? 'text-amber-300' :
                    item.level === 'success' ? 'text-emerald-400' :
                    'text-slate-300'
                  }`}>
                    {item.level === 'error' || item.level === 'warn' ? item.message : (
                      item.message.split(/(Dtthuat\/[^\s]+|[0-9A-F]{2}(?::[0-9A-F]{2}){5}|\b\d+\b)/g).map((part, i) => {
                        if (part.startsWith('Dtthuat/')) return <span key={i} className="text-teal-400 font-bold">{part}</span>;
                        if (/^[0-9A-F]{2}(?::[0-9A-F]{2}){5}$/.test(part)) return <span key={i} className="text-purple-400 font-bold">{part}</span>;
                        if (/^\d+$/.test(part) && part.length < 8) return <span key={i} className="text-blue-300 font-bold">{part}</span>;
                        return <span key={i}>{part}</span>;
                      })
                    )}
                  </span>
                </div>
              );
            })
          )}
        </div>

        {/* Terminal Footer */}
        <div className="px-5 py-3 bg-[#18181B] border-t border-slate-800 flex flex-wrap items-center justify-between text-xs text-slate-400">
          <div className="flex items-center gap-6">
            <span className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              Lịch trình: Hỏi - Trả Lời (Yên lặng khi rảnh)
            </span>
            <span className="flex items-center gap-2">
              <Layers className="w-3.5 h-3.5" />
              Schedules in RAM: <strong className="text-white">{ramState?.activeSchedulesCount || 0}</strong>
            </span>
            <span className="flex items-center gap-2">
              <Activity className="w-3.5 h-3.5" />
              Pending Retry: <strong className="text-white">{ramState?.pendingTasksCount || 0}</strong>
            </span>
          </div>
          <div className="opacity-70">
            Node.js v22 • Express • node-cron
          </div>
        </div>

      </div>

      {/* Database Backup Snapshots Archive - Full Width UX */}
      <div className="rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 p-6 shadow-sm">
        <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-4">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-emerald-100 text-emerald-600 rounded-lg">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-base text-slate-900 dark:text-slate-50">Lịch Sử Sao Lưu (Snapshots)</h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">Kho lưu trữ các bản backup cơ sở dữ liệu hệ thống</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-sm font-semibold px-3 py-1 bg-slate-100 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400 rounded-full">
              Tổng cộng: <span className="text-emerald-600">{backups.length}</span> bản
            </span>
            <button 
              onClick={loadStatusAndState}
              className="p-2 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 rounded-lg transition-colors"
              title="Làm mới danh sách"
            >
              <RefreshCw className={`w-4 h-4 ${isChecking ? 'animate-spin' : ''}`} />
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 max-h-[400px] overflow-y-auto pr-2 custom-scrollbar">
          {backups.length === 0 ? (
            <div className="col-span-full py-12 flex flex-col items-center justify-center text-slate-500 dark:text-slate-400 bg-slate-50 dark:bg-slate-950 rounded-xl border border-dashed border-slate-200 dark:border-slate-800/60">
              <Database className="w-10 h-10 text-slate-300 mb-3" />
              <p className="font-medium text-sm">Chưa có bản sao lưu nào</p>
              <p className="text-xs mt-1">Bấm nút "Tạo Snapshot Backup" ở trên để khởi tạo.</p>
            </div>
          ) : (
            backups.map((b) => (
              <div key={b.id} className="p-4 rounded-xl border border-slate-200 dark:border-slate-800/60 bg-white dark:bg-slate-900 hover:border-emerald-300 hover:shadow-md transition-all group flex flex-col justify-between gap-4">
                <div>
                  <div className="flex items-center justify-between mb-2">
                    <div className="font-mono font-bold text-slate-900 dark:text-slate-50 text-sm truncate" title={b.id}>
                      {b.id}
                    </div>
                    <span className="px-2 py-0.5 text-[10px] font-bold bg-emerald-50 text-emerald-600 rounded">
                      SUCCESS
                    </span>
                  </div>
                  <div className="space-y-1.5 text-xs text-slate-600 dark:text-slate-400">
                    <div className="flex items-center gap-2">
                      <Clock className="w-3.5 h-3.5 text-slate-400" />
                      <span>{b.timestamp}</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <Layers className="w-3.5 h-3.5 text-slate-400" />
                      <span>{b.docCount.toLocaleString()} tài liệu</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <HardDrive className="w-3.5 h-3.5 text-slate-400" />
                      <span>{(b.sizeBytes / 1024).toFixed(2)} KB</span>
                    </div>
                  </div>
                </div>
                <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex justify-end">
                  <button
                    onClick={() => alert(`Bản sao lưu ${b.id} đã sẵn sàng trong thư mục backups của Server.`)}
                    className="flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-lg transition-colors"
                  >
                    <Download className="w-3.5 h-3.5" />
                    Tải về máy
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      <AppVersionModal
        isOpen={showVersionModal}
        onClose={() => setShowVersionModal(false)}
        onSuccessNotification={(msg) => showNotify(msg)}
      />

    </div>
  );
};
