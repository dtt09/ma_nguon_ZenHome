import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { 
  AlertOctagon, 
  Search, 
  Copy, 
  ChevronDown, 
  ChevronUp, 
  Check, 
  Smartphone, 
  User, 
  Clock, 
  ShieldCheck, 
  RefreshCw,
  CheckCircle2,
  XCircle,
  Trash2,
  FlaskConical,
  Radio,
  ExternalLink,
  Laptop,
  Sparkles,
  Bot,
  Filter,
  CheckCheck,
  Layers,
  Wand2
} from 'lucide-react';
import { RealCrashLog } from '../../types/admin';
import { getAdminSecret } from '../../services/backupServerService';

export interface AiDiagnosisResult {
  rootCause: string;
  impact: string;
  solution: string;
  severity: 'CRITICAL' | 'WARNING' | 'INFO';
  affectedComponent: string;
  suggestedAction: string;
  isAutoFixable: boolean;
  model: string;
}

interface ErrorLogsViewProps {
  crashLogs: RealCrashLog[];
  onSelectCustomerById: (userId: string) => void;
  onToggleResolved?: (crashId: string, currentResolved: boolean, path?: string) => Promise<void>;
  onDeleteCrash?: (crashId: string, path?: string) => Promise<void>;
  onSendTestCrash?: () => Promise<void>;
  onShowToast?: (msg: string) => void;
}

export const ErrorLogsView: React.FC<ErrorLogsViewProps> = ({
  crashLogs,
  onSelectCustomerById,
  onToggleResolved,
  onDeleteCrash,
  onSendTestCrash,
  onShowToast,
}) => {
  const [search, setSearch] = useState('');
  const [expandedCrashId, setExpandedCrashId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<'all' | 'unresolved' | 'resolved'>('all');
  const [userFilter, setUserFilter] = useState<string>('all');
  const [isSendingTest, setIsSendingTest] = useState(false);
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);
  const [aiDiagnosisMap, setAiDiagnosisMap] = useState<Record<string, AiDiagnosisResult>>({});
  const [loadingAiId, setLoadingAiId] = useState<string | null>(null);
  const [isBatchResolving, setIsBatchResolving] = useState(false);

  // Phân loại danh sách người dùng độc nhất từ các bản ghi Crash
  const distinctUsers = useMemo(() => {
    const map = new Map<string, { userId: string; userName: string; email: string; count: number }>();
    for (const c of crashLogs) {
      const uid = c.userId || 'Hệ thống';
      const name = c.userName || uid;
      const email = c.userEmail || '';
      const existing = map.get(uid) || { userId: uid, userName: name, email, count: 0 };
      existing.count++;
      map.set(uid, existing);
    }
    return Array.from(map.values()).sort((a, b) => b.count - a.count);
  }, [crashLogs]);

  // Lọc theo search, trạng thái giải quyết và người dùng
  const filtered = crashLogs.filter(log => {
    // 1. Lọc theo User
    if (userFilter !== 'all' && log.userId !== userFilter) {
      return false;
    }

    // 2. Lọc theo Trạng thái
    if (statusFilter === 'unresolved' && log.isResolved) return false;
    if (statusFilter === 'resolved' && !log.isResolved) return false;

    // 3. Lọc theo Từ khóa tìm kiếm
    if (search.trim()) {
      const q = search.toLowerCase();
      const matchesSearch = (
        log.errorTitle.toLowerCase().includes(q) ||
        log.errorMessage.toLowerCase().includes(q) ||
        log.userName.toLowerCase().includes(q) ||
        log.userId.toLowerCase().includes(q) ||
        (log.deviceModel && log.deviceModel.toLowerCase().includes(q)) ||
        (log.appVersion && log.appVersion.toLowerCase().includes(q))
      );
      if (!matchesSearch) return false;
    }

    return true;
  });

  const unresolvedCount = crashLogs.filter(c => !c.isResolved).length;
  const resolvedCount = crashLogs.filter(c => Boolean(c.isResolved)).length;

  // Gọi AI Chẩn đoán nguyên nhân sự cố
  const handleDiagnoseWithAi = async (log: RealCrashLog, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    if (loadingAiId === log.id) return;

    setLoadingAiId(log.id);
    try {
      const adminKey = getAdminSecret();
      const res = await fetch('/api/v1/system/ai-diagnose', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(adminKey ? { 'x-api-key': adminKey } : {}),
        },
        body: JSON.stringify({
          errorTitle: log.errorTitle,
          errorMessage: log.errorMessage,
          stackTrace: log.stackTrace,
          deviceModel: log.deviceModel,
          osVersion: log.osVersion,
          appVersion: log.appVersion,
          userId: log.userId,
          userName: log.userName,
        }),
      });

      if (!res.ok) throw new Error(`Server returned HTTP ${res.status}`);
      const data = await res.json();
      if (data.success && data.diagnosis) {
        setAiDiagnosisMap(prev => ({ ...prev, [log.id]: data.diagnosis }));
        if (onShowToast) onShowToast('🤖 AI đã phân tích xong nguyên nhân và giải pháp!');
      } else {
        throw new Error(data.error || 'Không thể tạo bản phân tích');
      }
    } catch (err: any) {
      if (onShowToast) onShowToast(`Lỗi phân tích AI: ${err.message}`);
    } finally {
      setLoadingAiId(null);
    }
  };

  // Khắc phục hàng loạt lỗi đã được vá trong bản build v1.7.14
  const handleBatchResolve = async (filterType: 'socket' | 'all') => {
    if (!window.confirm(
      filterType === 'socket' 
        ? 'Bạn có chắc muốn đánh dấu ĐÃ KHẮC PHỤC toàn bộ các lỗi UDP Socket Broadcast (đã được vá trong v1.7.14)?' 
        : 'Bạn có chắc muốn đánh dấu ĐÃ KHẮC PHỤC toàn bộ danh sách lỗi?'
    )) return;

    setIsBatchResolving(true);
    try {
      const adminKey = getAdminSecret();
      const res = await fetch('/api/v1/system/batch-resolve-crashes', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(adminKey ? { 'x-api-key': adminKey } : {}),
        },
        body: JSON.stringify({ action: 'resolve', filterType }),
      });
      const data = await res.json();
      if (data.success) {
        if (onShowToast) onShowToast(`🎉 ${data.message}`);
        for (const log of crashLogs) {
          if (filterType === 'all' || log.errorTitle.toLowerCase().includes('socket')) {
            if (onToggleResolved) await onToggleResolved(log.id, false, log.path);
          }
        }
      }
    } catch (err: any) {
      if (onShowToast) onShowToast(`Lỗi xử lý hàng loạt: ${err.message}`);
    } finally {
      setIsBatchResolving(false);
    }
  };

  const handleCopyTrace = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    if (onShowToast) onShowToast('Đã sao chép Stack Trace vào Clipboard');
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleToggleResolve = async (log: RealCrashLog) => {
    if (!onToggleResolved) return;
    setActionLoadingId(log.id);
    try {
      await onToggleResolved(log.id, Boolean(log.isResolved), log.path);
      if (onShowToast) {
        onShowToast(log.isResolved ? 'Đã mở lại sự cố chưa khắc phục' : 'Đã đánh dấu đã khắc phục sự cố thành công');
      }
    } catch (e: any) {
      if (onShowToast) onShowToast(`Lỗi: ${e.message}`);
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDelete = async (log: RealCrashLog) => {
    if (!onDeleteCrash) return;
    if (!window.confirm(`Bạn có chắc chắn muốn xóa vĩnh viễn bản ghi lỗi "${log.errorTitle}"?`)) {
      return;
    }
    setActionLoadingId(log.id);
    try {
      await onDeleteCrash(log.id, log.path);
      if (onShowToast) onShowToast('Đã xóa bản ghi lỗi khỏi Firebase thành công');
    } catch (e: any) {
      if (onShowToast) onShowToast(`Lỗi khi xóa: ${e.message}`);
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleTriggerTest = async () => {
    if (!onSendTestCrash || isSendingTest) return;
    setIsSendingTest(true);
    try {
      await onSendTestCrash();
      if (onShowToast) {
        onShowToast('🧪 Đã gửi thành công sự cố kiểm thử! Firebase Realtime đang cập nhật...');
      }
    } catch (e: any) {
      if (onShowToast) onShowToast(`Lỗi tạo test crash: ${e.message}`);
    } finally {
      setIsSendingTest(false);
    }
  };

  const getSeverityBadge = (severity: string) => {
    switch (severity.toLowerCase()) {
      case 'fatal':
        return (
          <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-rose-100 text-rose-700 dark:bg-rose-950/80 dark:text-rose-300 border border-rose-300 dark:border-rose-800 shrink-0">
            FATAL (TỬ VONG)
          </span>
        );
      case 'warning':
        return (
          <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-amber-100 text-amber-700 dark:bg-amber-950/80 dark:text-amber-300 border border-amber-300 dark:border-amber-800 shrink-0">
            WARNING
          </span>
        );
      default:
        return (
          <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-orange-100 text-orange-700 dark:bg-orange-950/80 dark:text-orange-300 border border-orange-300 dark:border-orange-800 shrink-0">
            ERROR
          </span>
        );
    }
  };

  return (
    <div className="space-y-4">
      
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-5 rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-rose-50 dark:bg-rose-950/40 text-rose-600 dark:text-rose-400 shrink-0">
              <AlertOctagon className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50 flex items-center gap-2 flex-wrap">
                <span>Nhật ký Crashlytics & Lỗi Hệ thống</span>
                <span className="flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-50 text-emerald-700 dark:bg-emerald-950/50 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800">
                  <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
                  Firebase Realtime Live
                </span>
              </h2>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                Đồng bộ hóa 2 chiều tự động: Bắt sự cố runtime từ Flutter Crashlytics và lưu trữ trực tiếp trên Cloud Firestore.
              </p>
            </div>
          </div>
        </div>

        {/* Action Controls */}
        <div className="flex items-center flex-wrap gap-2.5">
          {/* Nút vá nhanh hàng loạt lỗi Socket */}
          <button
            onClick={() => handleBatchResolve('socket')}
            disabled={isBatchResolving}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold bg-emerald-50 hover:bg-emerald-100 dark:bg-emerald-950/40 dark:hover:bg-emerald-900/60 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800 transition shadow-xs disabled:opacity-50"
            title="Đánh dấu ĐÃ KHẮC PHỤC toàn bộ lỗi UDP Socket Broadcast đã được vá trong bản v1.7.14"
          >
            <CheckCheck className={`w-4 h-4 text-emerald-600 ${isBatchResolving ? 'animate-spin' : ''}`} />
            <span>{isBatchResolving ? 'Đang cập nhật...' : 'Vá lỗi Socket (v1.7.14)'}</span>
          </button>

          {onSendTestCrash && (
            <button
              onClick={handleTriggerTest}
              disabled={isSendingTest}
              className="flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold bg-indigo-50 hover:bg-indigo-100 dark:bg-indigo-950/40 dark:hover:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800 transition shadow-xs disabled:opacity-50"
              title="Tạo một bản ghi sự cố mô phỏng để kiểm tra luồng đồng bộ Firebase Realtime"
            >
              <FlaskConical className={`w-4 h-4 ${isSendingTest ? 'animate-spin' : ''}`} />
              <span>{isSendingTest ? 'Đang gửi...' : 'Tạo lỗi kiểm thử'}</span>
            </button>
          )}

          <div className="flex items-center gap-1 bg-slate-100 dark:bg-slate-800 p-1 rounded-xl text-xs font-medium">
            <button
              onClick={() => setStatusFilter('all')}
              className={`relative px-3 py-1.5 rounded-lg transition ${
                statusFilter === 'all' 
                  ? 'text-slate-900 dark:text-slate-100 font-semibold' 
                  : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
              }`}
            >
              {statusFilter === 'all' && (
                <motion.div
                  layoutId="error-status-filter-pill"
                  className="absolute inset-0 bg-white dark:bg-slate-900 rounded-lg shadow-xs"
                  transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                />
              )}
              <span className="relative z-10">Tất cả ({crashLogs.length})</span>
            </button>
            <button
              onClick={() => setStatusFilter('unresolved')}
              className={`relative px-3 py-1.5 rounded-lg transition flex items-center gap-1.5 ${
                statusFilter === 'unresolved' 
                  ? 'text-rose-600 dark:text-rose-400 font-semibold' 
                  : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
              }`}
            >
              {statusFilter === 'unresolved' && (
                <motion.div
                  layoutId="error-status-filter-pill"
                  className="absolute inset-0 bg-white dark:bg-slate-900 rounded-lg shadow-xs"
                  transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                />
              )}
              <span className="relative z-10 flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-rose-500"></span>
                Chưa xử lý ({unresolvedCount})
              </span>
            </button>
            <button
              onClick={() => setStatusFilter('resolved')}
              className={`relative px-3 py-1.5 rounded-lg transition flex items-center gap-1.5 ${
                statusFilter === 'resolved' 
                  ? 'text-emerald-600 dark:text-emerald-400 font-semibold' 
                  : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-200'
              }`}
            >
              {statusFilter === 'resolved' && (
                <motion.div
                  layoutId="error-status-filter-pill"
                  className="absolute inset-0 bg-white dark:bg-slate-900 rounded-lg shadow-xs"
                  transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                />
              )}
              <span className="relative z-10 flex items-center gap-1.5">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>
                Đã khắc phục ({resolvedCount})
              </span>
            </button>
          </div>
        </div>
      </div>

      {/* User Classification & Filter Bar (Phân loại theo từng người dùng) */}
      {distinctUsers.length > 0 && (
        <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm space-y-2">
          <div className="flex items-center justify-between text-xs font-bold text-slate-700 dark:text-slate-300">
            <div className="flex items-center gap-1.5 text-indigo-600 dark:text-indigo-400">
              <Filter className="w-4 h-4" />
              <span>PHÂN LOẠI SỰ CỐ THEO TỪNG KHÁCH HÀNG / THIẾT BỊ:</span>
            </div>
            <span className="text-[11px] font-normal text-slate-500">
              {distinctUsers.length} người dùng đã gửi bản ghi sự cố
            </span>
          </div>

          <div className="flex items-center gap-2 overflow-x-auto pb-1 pt-1 scrollbar-thin">
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => setUserFilter('all')}
              className={`relative px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition flex items-center gap-1.5 shrink-0 ${
                userFilter === 'all'
                  ? 'text-white'
                  : 'bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-300'
              }`}
            >
              {userFilter === 'all' && (
                <motion.div
                  layoutId="error-user-filter-pill"
                  className="absolute inset-0 bg-indigo-600 rounded-xl shadow-xs"
                  transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                />
              )}
              <span className="relative z-10 flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5" />
                <span>Tất cả người dùng ({crashLogs.length})</span>
              </span>
            </motion.button>

            {distinctUsers.map((u) => {
              const isSelected = userFilter === u.userId;
              return (
                <motion.button
                  key={u.userId}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={() => setUserFilter(u.userId)}
                  className={`relative px-3 py-1.5 rounded-xl text-xs whitespace-nowrap transition flex items-center gap-2 shrink-0 ${
                    isSelected
                      ? 'text-white font-semibold'
                      : 'bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300'
                  }`}
                >
                  {isSelected && (
                    <motion.div
                      layoutId="error-user-filter-pill"
                      className="absolute inset-0 bg-indigo-600 rounded-xl shadow-xs"
                      transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                    />
                  )}
                  <span className="relative z-10 flex items-center gap-2">
                    <User className="w-3.5 h-3.5 opacity-80" />
                    <span>{u.userName}</span>
                    {u.email && <span className="opacity-70 text-[11px]">({u.email})</span>}
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                      isSelected
                        ? 'bg-white/20 text-white'
                        : 'bg-rose-100 dark:bg-rose-950/80 text-rose-700 dark:text-rose-300 border border-rose-200 dark:border-rose-900'
                    }`}>
                      {u.count} lỗi
                    </span>
                  </span>
                </motion.button>
              );
            })}
          </div>
        </div>
      )}

      {/* Search Input */}
      {crashLogs.length > 0 && (
        <div className="relative">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Lọc lỗi theo thông điệp, tên khách hàng, dòng máy hoặc mã phiên bản..."
            className="w-full pl-9 pr-4 py-2.5 text-xs rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-slate-900 dark:text-slate-50 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500 shadow-xs"
          />
        </div>
      )}

      {/* Logs List */}
      <div className="space-y-3">
        {filtered.map((log) => {
          const isExpanded = expandedCrashId === log.id;
          const isResolved = Boolean(log.isResolved);

          return (
            <div
              key={log.id}
              className={`rounded-2xl border transition-all shadow-xs overflow-hidden ${
                isResolved
                  ? 'border-emerald-200 dark:border-emerald-950/60 bg-emerald-50/20 dark:bg-slate-900/60'
                  : 'border-rose-200 dark:border-rose-900/40 bg-white dark:bg-slate-900'
              }`}
            >
              <div className="p-4 sm:p-5">
                <div 
                  className="flex flex-col sm:flex-row sm:items-start justify-between gap-3 cursor-pointer"
                  onClick={() => setExpandedCrashId(isExpanded ? null : log.id)}
                >
                  <div className="space-y-2 flex-1 min-w-0">
                    {/* Header Badges & Title */}
                    <div className="flex items-center flex-wrap gap-2">
                      {getSeverityBadge(log.severity)}

                      {isResolved ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800 shrink-0">
                          <CheckCircle2 className="w-3 h-3" />
                          ĐÃ KHẮC PHỤC
                        </span>
                      ) : (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300 border border-rose-300 dark:border-rose-800 shrink-0">
                          <XCircle className="w-3 h-3" />
                          CHƯA XỬ LÝ
                        </span>
                      )}

                      {log.source === 'flutter_app' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-medium bg-blue-50 text-blue-700 dark:bg-blue-950/50 dark:text-blue-300 border border-blue-200 dark:border-blue-900 shrink-0">
                          <Smartphone className="w-3 h-3" />
                          Flutter Mobile
                        </span>
                      ) : log.source === 'web_admin_test' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-medium bg-purple-50 text-purple-700 dark:bg-purple-950/50 dark:text-purple-300 border border-purple-200 dark:border-purple-900 shrink-0">
                          <Laptop className="w-3 h-3" />
                          Web Console
                        </span>
                      ) : null}

                      {log.appVersion && (
                        <span className="px-2 py-0.5 rounded-md text-[10px] font-mono bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 shrink-0">
                          v{log.appVersion}
                        </span>
                      )}

                      {/* AI Diagnose Trigger Button */}
                      <button
                        onClick={(e) => handleDiagnoseWithAi(log, e)}
                        disabled={loadingAiId === log.id}
                        className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-md text-[10px] font-semibold bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 text-white shadow-xs transition disabled:opacity-50 shrink-0"
                        title="Phân tích nguyên nhân sự cố bằng Trí tuệ Nhân tạo AI"
                      >
                        <Sparkles className={`w-3 h-3 ${loadingAiId === log.id ? 'animate-spin' : ''}`} />
                        <span>{loadingAiId === log.id ? 'AI đang phân tích...' : aiDiagnosisMap[log.id] ? 'Xem lại AI' : '🤖 AI Phân tích'}</span>
                      </button>
                    </div>

                    {/* Error Title - Protected against text overflow */}
                    <div className="font-bold text-sm text-slate-900 dark:text-slate-100 font-mono break-words leading-snug">
                      {log.errorTitle}
                    </div>

                    {/* Error Message */}
                    <div className="text-xs text-slate-600 dark:text-slate-300 line-clamp-2 leading-relaxed font-sans break-words">
                      {log.errorMessage}
                    </div>

                    {/* AI Diagnosis Insights Card */}
                    {aiDiagnosisMap[log.id] && (
                      <div className="mt-3 p-4 rounded-2xl bg-gradient-to-br from-indigo-50/90 via-purple-50/40 to-white dark:from-slate-800/95 dark:via-purple-950/25 dark:to-slate-900 border border-indigo-200 dark:border-indigo-800/60 shadow-xs space-y-2.5 animate-in fade-in duration-200">
                        <div className="flex items-center justify-between flex-wrap gap-2">
                          <div className="flex items-center gap-2 text-xs font-bold text-indigo-700 dark:text-indigo-300">
                            <Bot className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                            <span>CHẨN ĐOÁN TRÍ TUỆ NHÂN TẠO (AI DIAGNOSTICS)</span>
                          </div>
                          <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-indigo-100 dark:bg-indigo-950 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800">
                            {aiDiagnosisMap[log.id].model}
                          </span>
                        </div>

                        <div className="text-xs space-y-2">
                          <div className="p-2.5 rounded-xl bg-white/80 dark:bg-slate-900/80 border border-indigo-100 dark:border-slate-800/60">
                            <div className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-1.5 mb-1 text-[11px] uppercase tracking-wide text-indigo-600 dark:text-indigo-400">
                              <span>🔍 Nguyên nhân gốc rễ (Root Cause):</span>
                            </div>
                            <p className="text-slate-700 dark:text-slate-200 leading-relaxed font-sans break-words">
                              {aiDiagnosisMap[log.id].rootCause}
                            </p>
                          </div>

                          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-[11px]">
                            <div className="p-2 rounded-lg bg-amber-500/10 border border-amber-500/20 text-amber-800 dark:text-amber-300 break-words">
                              <span className="font-bold">⚡ Tác động: </span>
                              <span>{aiDiagnosisMap[log.id].impact}</span>
                            </div>
                            <div className="p-2 rounded-lg bg-indigo-500/10 border border-indigo-500/20 text-indigo-800 dark:text-indigo-300 break-words">
                              <span className="font-bold">📦 Thành phần: </span>
                              <span>{aiDiagnosisMap[log.id].affectedComponent}</span>
                            </div>
                          </div>

                          <div className="p-3 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-800 dark:text-emerald-300 text-xs">
                            <div className="font-bold flex items-center gap-1 mb-1">
                              <span>🛠️ Giải pháp kỹ thuật & Đoạn code đã sửa:</span>
                            </div>
                            <p className="leading-relaxed break-words font-sans">
                              {aiDiagnosisMap[log.id].solution}
                            </p>
                          </div>

                          <div className="text-[11px] text-slate-500 dark:text-slate-400 flex items-center gap-1.5 pt-0.5 break-words">
                            <Wand2 className="w-3.5 h-3.5 text-indigo-500 shrink-0" />
                            <span><b>Hành động gợi ý cho Admin:</b> {aiDiagnosisMap[log.id].suggestedAction}</span>
                          </div>
                        </div>
                      </div>
                    )}

                    {/* Context Meta */}
                    <div className="flex items-center flex-wrap gap-x-3 gap-y-1 pt-1 text-[11px] text-slate-500 dark:text-slate-400">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          if (log.userId && log.userId !== 'Hệ thống') {
                            onSelectCustomerById(log.userId);
                          }
                        }}
                        className={`font-semibold flex items-center gap-1 ${
                          log.userId && log.userId !== 'Hệ thống' 
                            ? 'text-indigo-600 dark:text-indigo-400 hover:underline' 
                            : 'text-slate-500 dark:text-slate-400'
                        }`}
                      >
                        <User className="w-3 h-3" />
                        <span className="truncate max-w-[150px]">{log.userName}</span>
                        {log.userEmail && <span className="opacity-70 truncate max-w-[150px]">({log.userEmail})</span>}
                      </button>

                      <span>•</span>

                      <span className="flex items-center gap-1">
                        <Smartphone className="w-3 h-3" />
                        <span className="truncate max-w-[160px]">{log.deviceModel || 'Thiết bị di động'}</span>
                        {log.osVersion && <span className="opacity-70">({log.osVersion})</span>}
                      </span>

                      <span>•</span>

                      <span className="flex items-center gap-1 font-mono">
                        <Clock className="w-3 h-3" />
                        <span>{log.timestamp}</span>
                      </span>
                    </div>
                  </div>

                  {/* Actions Right */}
                  <div className="flex items-center gap-2 self-start sm:self-center shrink-0">
                    {onToggleResolved && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleToggleResolve(log);
                        }}
                        disabled={actionLoadingId === log.id}
                        className={`px-3 py-1.5 rounded-xl text-xs font-semibold flex items-center gap-1.5 transition ${
                          isResolved
                            ? 'bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300'
                            : 'bg-emerald-600 hover:bg-emerald-700 text-white shadow-xs'
                        }`}
                        title={isResolved ? 'Mở lại lỗi này' : 'Đánh dấu sự cố đã được sửa chữa'}
                      >
                        <Check className="w-3.5 h-3.5" />
                        <span>{isResolved ? 'Mở lại' : 'Đã sửa'}</span>
                      </button>
                    )}

                    {onDeleteCrash && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDelete(log);
                        }}
                        disabled={actionLoadingId === log.id}
                        className="p-1.5 rounded-xl text-slate-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/40 transition"
                        title="Xóa vĩnh viễn bản ghi lỗi này"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    )}

                    <div className="p-1 text-slate-400">
                      {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                    </div>
                  </div>
                </div>

                {/* Expanded Stack Trace - Safe Overflow Wrapper */}
                <AnimatePresence>
                  {isExpanded && (
                    <motion.div
                      initial={{ opacity: 0, height: 0 }}
                      animate={{ opacity: 1, height: 'auto' }}
                      exit={{ opacity: 0, height: 0 }}
                      transition={{ duration: 0.22, ease: 'easeOut' }}
                      className="overflow-hidden pt-4 mt-4 border-t border-slate-100 dark:border-slate-800 space-y-2"
                    >
                      <div className="flex items-center justify-between text-xs">
                        <span className="font-mono text-[11px] font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider flex items-center gap-1.5 truncate max-w-[70%]">
                          <span>Dart / Runtime Stack Trace</span>
                          {log.path && (
                            <span className="font-mono text-[10px] text-slate-400 lowercase truncate">
                              ({log.path})
                            </span>
                          )}
                        </span>
                        <motion.button
                          whileHover={{ scale: 1.05 }}
                          whileTap={{ scale: 0.95 }}
                          onClick={() => handleCopyTrace(log.id, log.stackTrace)}
                          className="flex items-center gap-1 px-2.5 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 text-xs transition shrink-0"
                        >
                          <Copy className="w-3.5 h-3.5" />
                          <span>{copiedId === log.id ? 'Đã sao chép!' : 'Sao chép Trace'}</span>
                        </motion.button>
                      </div>
                      <div className="w-full max-w-full overflow-x-auto rounded-xl bg-slate-950 p-4 border border-slate-800 font-mono text-[11px] text-rose-300 dark:text-rose-200 leading-relaxed shadow-inner max-h-64 scrollbar-thin">
                        <pre className="whitespace-pre font-mono">{log.stackTrace || 'Không có stack trace chi tiết đi kèm.'}</pre>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>
          );
        })}

        {/* Empty State */}
        {crashLogs.length === 0 && (
          <div className="p-12 text-center rounded-3xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-sm space-y-4">
            <div className="w-14 h-14 rounded-2xl bg-emerald-50 dark:bg-emerald-950/40 text-emerald-600 dark:text-emerald-400 flex items-center justify-center mx-auto">
              <ShieldCheck className="w-7 h-7" />
            </div>
            <div>
              <h3 className="font-bold text-base text-slate-900 dark:text-slate-50">
                Hệ thống ZenHome Vận Hành Tuyệt Đối Ổn Định
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 max-w-md mx-auto mt-1 leading-relaxed">
                Không phát hiện lỗi runtime nào trên Cloud Firestore. Khi thiết bị di động của khách hàng phát sinh ngoại lệ, CrashSyncService sẽ lập tức đẩy dữ liệu realtime về đây.
              </p>
            </div>
            {onSendTestCrash && (
              <div className="pt-2">
                <button
                  onClick={handleTriggerTest}
                  disabled={isSendingTest}
                  className="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-700 text-white shadow-xs transition"
                >
                  <FlaskConical className="w-4 h-4" />
                  <span>Tạo bản ghi kiểm thử ngay</span>
                </button>
              </div>
            )}
          </div>
        )}

        {crashLogs.length > 0 && filtered.length === 0 && (
          <div className="p-8 text-center rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-xs text-slate-500">
            Không tìm thấy bản ghi lỗi nào phù hợp với bộ lọc hiện tại.
          </div>
        )}
      </div>

    </div>
  );
};
