import React from 'react';
import { Search, Sun, Moon, RefreshCw, Activity, Zap, Radio, Server, ChevronRight } from 'lucide-react';
import { RealCustomerUser } from '../../types/admin';

interface AdminHeaderProps {
  searchQuery: string;
  onSearchChange: (q: string) => void;
  isDark: boolean;
  onToggleTheme: () => void;
  lastSyncTime: string;
  secondsAgo: number;
  pingMs: number;
  syncCount: number;
  isLiveStreaming: boolean;
  onToggleLiveStreaming: () => void;
  onTriggerManualSync: () => void;
  autoRefreshInterval: number;
  onSelectInterval: (interval: number) => void;
  onNavigateToBackupServer?: () => void;
  isSyncing: boolean;
  customers: RealCustomerUser[];
  onSelectCustomer: (c: RealCustomerUser) => void;
  activeTab: string;
}

export const AdminHeader: React.FC<AdminHeaderProps> = ({
  searchQuery,
  onSearchChange,
  isDark,
  onToggleTheme,
  lastSyncTime,
  secondsAgo,
  pingMs,
  syncCount,
  isLiveStreaming,
  onToggleLiveStreaming,
  onTriggerManualSync,
  autoRefreshInterval,
  onSelectInterval,
  onNavigateToBackupServer,
  isSyncing,
  customers,
  onSelectCustomer,
  activeTab
}) => {
  const searchInputRef = React.useRef<HTMLInputElement>(null);
  const [localQuery, setLocalQuery] = React.useState(searchQuery);

  React.useEffect(() => {
    setLocalQuery(searchQuery);
  }, [searchQuery]);

  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  const searchResults = React.useMemo(() => {
    if (activeTab === 'customers' || !localQuery.trim()) return [];
    const q = localQuery.toLowerCase();
    return customers.filter(c => 
      (c.displayName || '').toLowerCase().includes(q) ||
      (c.email || '').toLowerCase().includes(q) ||
      (c.phoneNumber || '').includes(q) ||
      (c.macAddress || '').toLowerCase().includes(q) ||
      (c.id || '').toLowerCase().includes(q)
    ).slice(0, 5); // Giới hạn 5 kết quả
  }, [localQuery, customers, activeTab]);

  return (
    <header className="h-16 px-6 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800/60 flex items-center justify-between gap-4 transition-colors relative z-40">
      
      {/* Search Bar */}
      <div className="flex-1 max-w-md relative transition-all duration-300 focus-within:max-w-xl group">
        <Search className="w-4 h-4 text-slate-500 dark:text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 group-focus-within:text-blue-500 transition-colors" />
        <input
          ref={searchInputRef}
          type="text"
          value={localQuery}
          onChange={(e) => setLocalQuery(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              onSearchChange(localQuery);
            } else if (e.key === 'Escape') {
              setLocalQuery('');
              onSearchChange('');
              searchInputRef.current?.blur();
            }
          }}
          placeholder="Nhập từ khóa và nhấn Enter để tìm..."
          className="w-full pl-9 pr-14 py-2 text-xs rounded-xl bg-slate-100 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-800/60/80 text-slate-900 dark:text-slate-50 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/50 focus:border-blue-500 transition-all shadow-sm"
        />
        
        {/* Clear Button */}
        {localQuery && (
          <button 
            onClick={() => {
              setLocalQuery('');
              onSearchChange('');
              searchInputRef.current?.focus();
            }}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 bg-slate-200/50 dark:bg-slate-700/50 p-1 rounded-full transition-colors"
            title="Xóa tìm kiếm (Esc)"
          >
            <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
          </button>
        )}

        {/* Keyboard Shortcut Hint (Hidden when typing or focused) */}
        {!searchQuery && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2 hidden sm:flex items-center gap-1 pointer-events-none opacity-60 group-focus-within:opacity-0 transition-opacity">
            <kbd className="px-1.5 py-0.5 text-[10px] font-mono font-semibold text-slate-500 bg-slate-200 dark:bg-slate-700 dark:text-slate-400 rounded border border-slate-300 dark:border-slate-600 shadow-sm">Ctrl</kbd>
            <span className="text-[10px] text-slate-400">+</span>
            <kbd className="px-1.5 py-0.5 text-[10px] font-mono font-semibold text-slate-500 bg-slate-200 dark:bg-slate-700 dark:text-slate-400 rounded border border-slate-300 dark:border-slate-600 shadow-sm">K</kbd>
          </div>
        )}

        {/* Global Search Dropdown Results */}
        {activeTab !== 'customers' && localQuery.trim() !== '' && (
          <div className="absolute top-full left-0 right-0 mt-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-xl shadow-2xl z-50 overflow-hidden divide-y divide-slate-100 dark:divide-slate-800/60 animate-in fade-in slide-in-from-top-2">
            {searchResults.length === 0 ? (
              <div className="p-4 text-center text-xs text-slate-500 dark:text-slate-400">
                Không tìm thấy khách hàng nào.
              </div>
            ) : (
              searchResults.map(c => (
                <button
                  key={c.id}
                  onClick={() => {
                    onSelectCustomer(c);
                    setLocalQuery('');
                    onSearchChange('');
                  }}
                  className="w-full flex items-center justify-between p-3 text-left hover:bg-slate-50 dark:hover:bg-slate-800/80 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-blue-500 to-sky-600 flex items-center justify-center text-slate-50 font-bold text-xs shrink-0">
                      {(c.displayName || '?').charAt(0).toUpperCase()}
                    </div>
                    <div>
                      <div className="text-xs font-bold text-slate-900 dark:text-slate-50">{c.displayName || 'Khách hàng ẩn danh'}</div>
                      <div className="text-[10px] text-slate-500 dark:text-slate-400">{c.phoneNumber || 'Không có SĐT'} • {c.macAddress || 'Chưa liên kết MAC'}</div>
                    </div>
                  </div>
                  <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-indigo-500" />
                </button>
              ))
            )}
            
            {searchResults.length > 0 && (
              <button
                onClick={() => {
                  onSearchChange(localQuery);
                }}
                className="w-full p-2.5 text-xs text-center font-semibold text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/20 hover:bg-indigo-100 dark:hover:bg-indigo-900/40 transition-colors"
              >
                Nhấn Enter để mở danh sách chi tiết
              </button>
            )}
          </div>
        )}
      </div>

      {/* Right Controls: Live Continuous Status Monitor & Backup Server Status */}
      <div className="flex items-center gap-2.5">
        
        {/* Server Backup Connection Badge */}
        <button
          onClick={onNavigateToBackupServer}
          className="hidden sm:flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl border border-blue-300  bg-indigo-50 dark:bg-indigo-900/20  text-[11px] font-bold text-blue-800  hover:bg-indigo-100 dark:bg-indigo-900/40  transition-colors"
          title="Bấm để xem chi tiết kết nối Server Backup Node.js"
        >
          <Server className="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400 shrink-0" />
          <span>Server Backup: Đã kết nối</span>
        </button>

        {/* Continuous Stream Live Ticker */}
        <div 
          onClick={onToggleLiveStreaming}
          className={`flex items-center gap-2 px-3 py-1.5 rounded-xl border text-xs cursor-pointer select-none transition-all ${
            isLiveStreaming
              ? 'bg-indigo-50 dark:bg-indigo-900/20  border-blue-300  shadow-sm'
              : 'bg-slate-100 dark:bg-slate-800/50  border-slate-300 dark:border-slate-700  text-slate-500 dark:text-slate-400'
          }`}
          title="Bấm để Tạm dừng / Tiếp tục cập nhật liên tục"
        >
          <span className="relative flex h-2.5 w-2.5">
            {isLiveStreaming && (
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75"></span>
            )}
            <span className={`relative inline-flex rounded-full h-2.5 w-2.5 ${isLiveStreaming ? 'bg-indigo-600 dark:bg-indigo-500' : 'bg-slate-400'}`}></span>
          </span>

          <div className="flex items-center gap-1.5">
            <span className="font-bold text-blue-800 ">
              {isLiveStreaming ? 'LIÊN TỤC' : 'TẠM DỪNG'}
            </span>
            <span className="text-slate-600 dark:text-slate-400 ">|</span>
            <span className="text-[11px] font-mono text-slate-600 dark:text-slate-400 ">
              {secondsAgo === 0 ? 'Vừa đồng bộ' : `${secondsAgo}s trước`}
            </span>
            <span className="text-slate-600 dark:text-slate-400 ">|</span>
            <span className="text-[10px] font-mono px-1 rounded bg-indigo-100 dark:bg-indigo-900/40  text-indigo-700 dark:text-indigo-400 ">
              #{syncCount}
            </span>
            <span className="text-slate-600 dark:text-slate-400  hidden md:inline">|</span>
            <span className="text-[11px] font-mono font-semibold text-indigo-700 dark:text-indigo-500  hidden md:inline">
              {pingMs}ms
            </span>
          </div>
        </div>

        {/* Refresh Interval Selector */}
        <div className="hidden lg:flex items-center gap-1 text-[11px] font-mono border border-slate-200 dark:border-slate-800/60  rounded-xl p-0.5 bg-slate-50 dark:bg-slate-950 ">
          {[2, 5, 10].map((sec) => (
            <button
              key={sec}
              onClick={() => onSelectInterval(sec)}
              className={`px-2 py-1 rounded-lg transition-colors ${
                autoRefreshInterval === sec
                  ? 'bg-indigo-700 dark:bg-indigo-600 text-white font-bold'
                  : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 dark:text-slate-200 '
              }`}
            >
              {sec}s
            </button>
          ))}
        </div>

        {/* Manual Instant Sync Button */}
        <button
          onClick={onTriggerManualSync}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-800/60  hover:bg-slate-100 dark:hover:bg-slate-800/80 dark:bg-slate-800/50  text-slate-700 dark:text-slate-300  text-xs font-semibold transition-colors"
          title="Lấy dữ liệu mới nhất từ Firestore ngay bây giờ"
        >
          <RefreshCw className={`w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400 ${isSyncing || secondsAgo === 0 ? 'animate-spin' : ''}`} />
          <span className="hidden md:inline">Đồng bộ</span>
        </button>

        {/* Theme toggle */}
        <button
          onClick={onToggleTheme}
          aria-label="Toggle theme"
          className="p-2 rounded-xl text-slate-600 dark:text-slate-400  hover:bg-slate-100 dark:hover:bg-slate-800/80 dark:bg-slate-800/50  transition-colors"
        >
          {isDark ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4 text-slate-600 dark:text-slate-400" />}
        </button>

      </div>

    </header>
  );
};
