import React, { useState } from 'react';
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
  RefreshCw 
} from 'lucide-react';
import { RealCrashLog } from '../../types/admin';

interface ErrorLogsViewProps {
  crashLogs: RealCrashLog[];
  onSelectCustomerById: (userId: string) => void;
}

export const ErrorLogsView: React.FC<ErrorLogsViewProps> = ({
  crashLogs,
  onSelectCustomerById
}) => {
  const [search, setSearch] = useState('');
  const [expandedCrashId, setExpandedCrashId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const filtered = crashLogs.filter(log => {
    return (
      log.errorTitle.toLowerCase().includes(search.toLowerCase()) ||
      log.errorMessage.toLowerCase().includes(search.toLowerCase()) ||
      log.userName.toLowerCase().includes(search.toLowerCase()) ||
      log.userId.toLowerCase().includes(search.toLowerCase())
    );
  });

  const handleCopyTrace = (id: string, text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="space-y-4">
      
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50  flex items-center gap-2">
            <AlertOctagon className="w-5 h-5 text-rose-500" />
            <span>Nhật ký lỗi & Crash Logs thực tế trên Firebase</span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400  mt-0.5">
            Dữ liệu ghi nhận từ các sự cố runtime của ứng dụng di động Flutter/Dart lưu trữ trên Firestore.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono font-bold px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800/50  text-slate-700 dark:text-slate-300 ">
            {crashLogs.length} bản ghi lỗi
          </span>
        </div>
      </div>

      {/* Search Input */}
      {crashLogs.length > 0 && (
        <div className="relative">
          <Search className="w-4 h-4 text-slate-500 dark:text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Lọc lỗi theo tên khách hàng, mã lỗi, hoặc stack trace..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-white dark:bg-slate-900  border border-slate-200 dark:border-slate-800/60  text-slate-900 dark:text-slate-50  placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
      )}

      {/* Logs List */}
      <div className="space-y-3">
        {filtered.map((log) => {
          const isExpanded = expandedCrashId === log.id;

          return (
            <div
              key={log.id}
              className="rounded-2xl border border-rose-200  bg-white dark:bg-slate-900  p-4 transition-all shadow-sm"
            >
              <div 
                className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 cursor-pointer"
                onClick={() => setExpandedCrashId(isExpanded ? null : log.id)}
              >
                <div>
                  <div className="font-bold text-sm text-rose-700  font-mono">
                    {log.errorTitle}
                  </div>
                  <div className="text-xs text-slate-500 dark:text-slate-400  mt-0.5 line-clamp-1">
                    {log.errorMessage}
                  </div>

                  <div className="flex items-center gap-3 mt-2 text-[11px] text-slate-500 dark:text-slate-400">
                    <button
                      onClick={(e) => {
                        e.stopPropagation();
                        onSelectCustomerById(log.userId);
                      }}
                      className="font-semibold text-indigo-700 dark:text-indigo-500  hover:underline flex items-center gap-1"
                    >
                      <User className="w-3 h-3" />
                      <span>{log.userName}</span>
                    </button>
                    <span>•</span>
                    <span className="flex items-center gap-1 font-mono">
                      <Clock className="w-3 h-3" />
                      <span>{log.timestamp}</span>
                    </span>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  {isExpanded ? <ChevronUp className="w-4 h-4 text-slate-500 dark:text-slate-400" /> : <ChevronDown className="w-4 h-4 text-slate-500 dark:text-slate-400" />}
                </div>
              </div>

              {isExpanded && (
                <div className="pt-3 mt-3 border-t border-slate-100 dark:border-slate-800  space-y-2">
                  <div className="flex items-center justify-between text-xs">
                    <span className="font-mono text-[10px] text-slate-500 dark:text-slate-400 uppercase">
                      Dart Stack Trace
                    </span>
                    <button
                      onClick={() => handleCopyTrace(log.id, log.stackTrace)}
                      className="flex items-center gap-1 text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 dark:text-slate-200 text-xs"
                    >
                      <Copy className="w-3.5 h-3.5" />
                      <span>{copiedId === log.id ? 'Đã sao chép!' : 'Sao chép'}</span>
                    </button>
                  </div>
                  <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-950 font-mono text-xs text-rose-300 overflow-x-auto border border-slate-200 dark:border-slate-800/60">
                    <pre>{log.stackTrace}</pre>
                  </div>
                </div>
              )}
            </div>
          );
        })}

        {/* Real Status: When 0 crashes exist on Firebase */}
        {crashLogs.length === 0 && (
          <div className="p-10 text-center rounded-3xl bg-white dark:bg-slate-900  border border-slate-200 dark:border-slate-800/60  shadow-sm space-y-3">
            <div className="w-12 h-12 rounded-2xl bg-indigo-50 dark:bg-indigo-900/20  text-indigo-700 dark:text-indigo-500  flex items-center justify-center mx-auto">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <h3 className="font-bold text-base text-slate-900 dark:text-slate-50 ">
              Không có lỗi nào được ghi nhận trên Firebase
            </h3>
            <p className="text-xs text-slate-500 dark:text-slate-400  max-w-md mx-auto leading-relaxed">
              Các subcollection <code>/crash_logs</code> và <code>/logs</code> trên Cloud Firestore hiện tại không có bản ghi sự cố nào. Ứng dụng di động Dart/Flutter của khách hàng đang vận hành ổn định.
            </p>
          </div>
        )}
      </div>

    </div>
  );
};
