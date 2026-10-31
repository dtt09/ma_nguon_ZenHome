import React from 'react';
import { Search, Sun, Moon, LogOut, RefreshCw, Activity, Zap, Radio, Server, ChevronRight, Fingerprint } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
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
  onLogout?: () => void;
  onOpenPasskeyManager?: () => void;
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
  activeTab,
  onLogout,
  onOpenPasskeyManager
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
    <header className="h-16 px-4 sm:px-6 bg-white dark:bg-slate-900 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between gap-3 sm:gap-4 transition-colors relative z-40">
      
      {/* Search Bar with Autocomplete Dropdown */}
      <div className="flex-1 max-w-xs sm:max-w-sm md:max-w-md relative transition-all duration-300 focus-within:max-w-xl group min-w-0">
        <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 group-focus-within:text-indigo-600 dark:group-focus-within:text-indigo-400 transition-colors pointer-events-none" />
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
          placeholder="Tìm khách hàng, ID, SĐT, MAC..."
          className="w-full pl-9 pr-12 py-2 text-xs rounded-xl bg-slate-100/80 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500/40 focus:border-indigo-500 transition-all shadow-xs"
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

        {/* Keyboard Shortcut Hint */}
        {!localQuery && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2 hidden md:flex items-center gap-1 pointer-events-none opacity-60 group-focus-within:opacity-0 transition-opacity">
            <kbd className="px-1.5 py-0.5 text-[10px] font-mono font-semibold text-slate-500 bg-slate-200 dark:bg-slate-700 dark:text-slate-400 rounded border border-slate-300 dark:border-slate-600 shadow-xs">Ctrl</kbd>
            <span className="text-[10px] text-slate-400">+</span>
            <kbd className="px-1.5 py-0.5 text-[10px] font-mono font-semibold text-slate-500 bg-slate-200 dark:bg-slate-700 dark:text-slate-400 rounded border border-slate-300 dark:border-slate-600 shadow-xs">K</kbd>
          </div>
        )}

        {/* Global Search Dropdown Results with Animate UI Spring Entrance */}
        <AnimatePresence>
          {activeTab !== 'customers' && localQuery.trim() !== '' && (
            <motion.div 
              initial={{ opacity: 0, y: -6, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -6, scale: 0.98 }}
              transition={{ type: "spring", stiffness: 450, damping: 30 }}
              className="absolute top-full left-0 right-0 mt-2 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl shadow-2xl z-50 overflow-hidden divide-y divide-slate-100 dark:divide-slate-800 max-w-full"
            >
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
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-indigo-500 to-sky-600 flex items-center justify-center text-white font-bold text-xs shrink-0">
                        {(c.displayName || '?').charAt(0).toUpperCase()}
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="text-xs font-bold text-slate-900 dark:text-slate-100 truncate">{c.displayName || 'Khách hàng ẩn danh'}</div>
                        <div className="text-[10px] text-slate-500 dark:text-slate-400 truncate">{c.phoneNumber || 'Không có SĐT'} • {c.macAddress || 'Chưa liên kết MAC'}</div>
                      </div>
                    </div>
                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-indigo-500 shrink-0 ml-2" />
                  </button>
                ))
              )}
              
              {searchResults.length > 0 && (
                <button
                  onClick={() => {
                    onSearchChange(localQuery);
                  }}
                  className="w-full p-2.5 text-xs text-center font-semibold text-indigo-600 dark:text-indigo-400 bg-indigo-50/80 dark:bg-indigo-950/40 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 transition-colors"
                >
                  Nhấn Enter để mở danh sách chi tiết
                </button>
              )}
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      {/* Right Controls: Live Continuous Status Monitor & Backup Server Status */}
      <div className="flex items-center gap-1.5 sm:gap-2.5 shrink-0">
        
        {/* Server Backup Connection Badge */}
        <motion.button
          onClick={onNavigateToBackupServer}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="hidden xl:flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl border border-indigo-200 dark:border-indigo-800/60 bg-indigo-50/80 dark:bg-indigo-950/40 text-[11px] font-bold text-indigo-700 dark:text-indigo-300 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 transition-colors shrink-0"
          title="Bấm để xem chi tiết kết nối Server Backup Node.js"
        >
          <Server className="w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400 shrink-0" />
          <span>Server Backup: Đã kết nối</span>
        </motion.button>

        {/* Continuous Stream Live Ticker */}
        <motion.div 
          onClick={onToggleLiveStreaming}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className={`flex items-center gap-2 px-2.5 sm:px-3 py-1.5 rounded-xl border text-xs cursor-pointer select-none transition-all shrink-0 ${
            isLiveStreaming
              ? 'bg-indigo-50/80 dark:bg-indigo-950/40 border-indigo-200 dark:border-indigo-800/60 text-indigo-700 dark:text-indigo-300 shadow-xs'
              : 'bg-slate-100 dark:bg-slate-800/50 border-slate-300 dark:border-slate-700 text-slate-500 dark:text-slate-400'
          }`}
          title="Bấm để Tạm dừng / Tiếp tục cập nhật liên tục"
        >
          <span className="relative flex h-2 w-2 shrink-0">
            {isLiveStreaming && (
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
            )}
            <span className={`relative inline-flex rounded-full h-2 w-2 ${isLiveStreaming ? 'bg-emerald-500' : 'bg-slate-400'}`}></span>
          </span>

          <div className="flex items-center gap-1.5">
            <span className="font-bold">
              {isLiveStreaming ? 'LIÊN TỤC' : 'TẠM DỪNG'}
            </span>
            <span className="text-slate-400 dark:text-slate-600">|</span>
            <span className="text-[11px] font-mono text-slate-600 dark:text-slate-300">
              {secondsAgo === 0 ? 'Vừa đồng bộ' : `${secondsAgo}s`}
            </span>
            <span className="text-slate-400 dark:text-slate-600 hidden sm:inline">|</span>
            <span className="text-[10px] font-mono px-1 rounded bg-indigo-100 dark:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 hidden sm:inline">
              #{syncCount}
            </span>
            <span className="text-slate-400 dark:text-slate-600 hidden md:inline">|</span>
            <span className="text-[11px] font-mono font-semibold text-indigo-700 dark:text-indigo-400 hidden md:inline">
              {pingMs}ms
            </span>
          </div>
        </motion.div>

        {/* Refresh Interval Selector with Animate UI Spring Floating Pill */}
        <div className="hidden lg:flex items-center gap-0.5 text-[11px] font-mono border border-slate-200 dark:border-slate-800 rounded-xl p-0.5 bg-slate-100/70 dark:bg-slate-950/60 shrink-0 relative">
          {[10, 30, 60].map((sec) => {
            const isSelected = autoRefreshInterval === sec;
            return (
              <button
                key={sec}
                onClick={() => onSelectInterval(sec)}
                className={`relative px-2.5 py-1 rounded-lg text-xs font-semibold transition-colors z-10 ${
                  isSelected
                    ? 'text-white'
                    : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100'
                }`}
              >
                {isSelected && (
                  <motion.div
                    layoutId="interval-active-pill"
                    className="absolute inset-0 rounded-lg bg-indigo-600 shadow-xs -z-10"
                    transition={{ type: "spring", stiffness: 450, damping: 30 }}
                  />
                )}
                {sec}s
              </button>
            );
          })}
        </div>

        {/* Manual Instant Sync Button with Animate UI Feedback */}
        <motion.button
          onClick={onTriggerManualSync}
          whileHover={{ scale: 1.03 }}
          whileTap={{ scale: 0.96 }}
          className="flex items-center gap-1.5 px-2.5 sm:px-3 py-1.5 rounded-xl border border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800 bg-white dark:bg-slate-900 text-slate-700 dark:text-slate-200 text-xs font-semibold transition-colors shrink-0 shadow-xs"
          title="Lấy dữ liệu mới nhất từ Firestore ngay bây giờ (Bỏ qua Cache)"
        >
          <RefreshCw className={`w-3.5 h-3.5 text-indigo-600 dark:text-indigo-400 shrink-0 ${isSyncing || secondsAgo === 0 ? 'animate-spin' : ''}`} />
          <span className="hidden sm:inline">Đồng bộ</span>
        </motion.button>

        {/* Theme toggle with Animate UI Rotation Morph */}
        <motion.button
          onClick={onToggleTheme}
          whileTap={{ rotate: 180, scale: 0.88 }}
          whileHover={{ scale: 1.08 }}
          aria-label="Toggle theme"
          className="p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors shrink-0"
        >
          {isDark ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4 text-slate-600" />}
        </motion.button>

        {/* Passkey Security Center Button with Animate UI Feedback */}
        {onOpenPasskeyManager && (
          <motion.button
            onClick={onOpenPasskeyManager}
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.96 }}
            aria-label="Quản lý Passkey"
            title="Quản lý khóa bảo mật sinh trắc học Passkey (FIDO2 / WebAuthn)"
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl border border-teal-200 dark:border-teal-900/50 bg-teal-50 dark:bg-teal-950/30 text-teal-700 dark:text-teal-300 hover:bg-teal-100 dark:hover:bg-teal-900/50 text-xs font-semibold transition-colors shrink-0 shadow-xs"
          >
            <Fingerprint className="w-3.5 h-3.5 shrink-0 text-teal-600 dark:text-teal-400" />
            <span className="hidden xl:inline">Passkey</span>
          </motion.button>
        )}

        {/* Lock Dashboard / Logout */}
        {onLogout && (
          <motion.button
            onClick={onLogout}
            whileHover={{ scale: 1.03 }}
            whileTap={{ scale: 0.96 }}
            aria-label="Khóa bảng điều khiển"
            title="Đăng xuất & Khóa Bảng điều khiển Quản trị"
            className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl border border-rose-200 dark:border-rose-900/50 bg-rose-50 dark:bg-rose-950/30 text-rose-600 dark:text-rose-400 hover:bg-rose-100 dark:hover:bg-rose-900/50 text-xs font-semibold transition-colors shrink-0"
          >
            <LogOut className="w-3.5 h-3.5 shrink-0" />
            <span className="hidden xl:inline">Khóa</span>
          </motion.button>
        )}

      </div>

    </header>
  );
};
