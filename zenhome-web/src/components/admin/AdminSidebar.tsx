import React from 'react';
import { 
  Users, 
  AlertOctagon, 
  Database, 
  Cpu, 
  BarChart3, 
  Server,
  Zap,
  Code2,
  MessageSquareWarning,
  LogOut,
  ChevronLeft,
  ChevronRight
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { getPathForTab } from '../../utils/routes';

export type AdminTab = 'overview' | 'customers' | 'bug_reports' | 'crash_logs' | 'database' | 'fleet' | 'backup_server' | 'api_system';

interface AdminSidebarProps {
  activeTab: AdminTab;
  onSelectTab: (tab: AdminTab) => void;
  totalCustomers: number;
  totalCrashes: number;
  totalReports?: number;
  totalDocs: number;
  onLogout?: () => void;
}

export const AdminSidebar: React.FC<AdminSidebarProps> = ({
  activeTab,
  onSelectTab,
  totalCustomers,
  totalCrashes,
  totalReports = 0,
  totalDocs,
  onLogout
}) => {
  const [isCollapsed, setIsCollapsed] = React.useState(false);

  React.useEffect(() => {
    const handleResize = () => {
      if (window.innerWidth < 1024) {
        setIsCollapsed(true);
      } else {
        setIsCollapsed(false);
      }
    };

    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const navItems = [
    {
      id: 'overview' as AdminTab,
      label: 'Tổng quan hệ thống',
      icon: <BarChart3 className="w-4 h-4 shrink-0" />,
      badge: null,
    },
    {
      id: 'customers' as AdminTab,
      label: 'Khách hàng trên Firebase',
      icon: <Users className="w-4 h-4 shrink-0" />,
      badge: totalCustomers.toString(),
    },
    {
      id: 'bug_reports' as AdminTab,
      label: 'Báo cáo sự cố người dùng',
      icon: <MessageSquareWarning className="w-4 h-4 shrink-0" />,
      badge: totalReports > 0 ? `${totalReports} tin` : null,
      badgeColor: totalReports > 0 ? 'bg-amber-500 text-white' : undefined,
    },
    {
      id: 'crash_logs' as AdminTab,
      label: 'Nhật ký lỗi (Crashlytics)',
      icon: <AlertOctagon className="w-4 h-4 shrink-0" />,
      badge: totalCrashes > 0 ? `${totalCrashes} lỗi` : '0 lỗi',
      badgeColor: totalCrashes > 0 ? 'bg-rose-500 text-white' : 'bg-emerald-100 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800/50',
    },
    {
      id: 'database' as AdminTab,
      label: 'Duyệt Cloud Firestore',
      icon: <Database className="w-4 h-4 shrink-0" />,
      badge: `${totalDocs} docs`,
    },
    {
      id: 'fleet' as AdminTab,
      label: 'Phần cứng & Thiết bị ESP32',
      icon: <Cpu className="w-4 h-4 shrink-0" />,
      badge: null,
    },
    {
      id: 'backup_server' as AdminTab,
      label: 'Server Backup ZenHome',
      icon: <Server className="w-4 h-4 shrink-0" />,
      badge: 'ONLINE',
      badgeColor: 'bg-indigo-100 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800/50',
    },
    {
      id: 'api_system' as AdminTab,
      label: 'Hệ thống REST API',
      icon: <Code2 className="w-4 h-4 shrink-0" />,
      badge: 'v1.0',
      badgeColor: 'bg-emerald-100 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800/50',
    },
  ];

  return (
    <motion.aside 
      animate={{ width: isCollapsed ? 80 : 288 }}
      transition={{ type: "spring", stiffness: 350, damping: 32 }}
      className="bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-800 text-slate-600 dark:text-slate-300 flex flex-col justify-between shrink-0 select-none relative group overflow-hidden"
    >
      
      {/* Brand & System Tag - Clickable to toggle collapse */}
      <div className="overflow-hidden">
        <button 
          onClick={() => setIsCollapsed(!isCollapsed)}
          className="w-full p-4 sm:p-5 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors text-left focus:outline-none"
          title={isCollapsed ? "Mở rộng menu" : "Thu gọn menu"}
        >
          <div className="flex items-center gap-3 min-w-0">
            <motion.div 
              whileHover={{ rotate: 10, scale: 1.05 }}
              whileTap={{ scale: 0.92 }}
              className="w-10 h-10 shrink-0 drop-shadow-xs flex items-center justify-center relative"
            >
              <img 
                src="/zenhome_logo_real.png" 
                alt="ZenHome Admin" 
                className="w-full h-full object-contain"
              />
            </motion.div>
            <AnimatePresence>
              {!isCollapsed && (
                <motion.div 
                  initial={{ opacity: 0, x: -10 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -10 }}
                  transition={{ duration: 0.18 }}
                  className="min-w-0 flex-1"
                >
                  <div className="flex items-center gap-1.5">
                    <span className="font-extrabold text-base tracking-tight text-slate-900 dark:text-slate-50">
                      ZenHome
                    </span>
                    <span className="text-[10px] px-1.5 py-0.2 rounded font-mono font-bold bg-indigo-100 dark:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800/50">
                      ADMIN
                    </span>
                  </div>
                  <div className="text-xs text-slate-500 dark:text-slate-400 font-medium truncate">
                    Cổng Quản trị Khách hàng & IoT
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          <div className="hidden sm:flex text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 p-1">
            {isCollapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
          </div>
        </button>

        {/* Cloud Project Environment Indicator */}
        <AnimatePresence>
          {!isCollapsed && (
            <motion.div 
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: "auto" }}
              exit={{ opacity: 0, height: 0 }}
              transition={{ duration: 0.2 }}
              className="px-3.5 py-2.5 mx-3 mt-3 rounded-xl bg-slate-50 dark:bg-slate-950/70 border border-slate-200 dark:border-slate-800/80 text-xs overflow-hidden"
            >
              <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 text-[11px] mb-1">
                <span className="flex items-center gap-1">
                  <Server className="w-3.5 h-3.5 text-indigo-500 shrink-0" />
                  <span>Dự án Firebase thực tế:</span>
                </span>
                <span className="flex h-2 w-2 relative shrink-0">
                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                  <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
                </span>
              </div>
              <div className="font-mono text-indigo-700 dark:text-indigo-400 font-semibold truncate text-[11px]">
                smarthome-98dd7
              </div>
              <div className="text-[10px] text-slate-500 dark:text-slate-400 mt-0.5 truncate">
                Vùng: asia-southeast1 (Firestore)
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        {/* Navigation list with Animate UI Spring Floating Pill */}
        <div className="px-3 py-3 space-y-1">
          {!isCollapsed && (
            <div className="px-3 pb-1 text-[10px] font-bold text-slate-400 dark:text-slate-500 uppercase tracking-wider">
              Quản trị Vận hành & Dữ liệu
            </div>
          )}

          {navItems.map((item) => {
            const isActive = activeTab === item.id;
            return (
              <motion.a
                key={item.id}
                href={getPathForTab(item.id)}
                onClick={(e) => {
                  e.preventDefault();
                  onSelectTab(item.id);
                }}
                whileHover={{ x: 2 }}
                whileTap={{ scale: 0.98 }}
                title={isCollapsed ? item.label : undefined}
                className={`relative w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-semibold transition-colors ${
                  isActive
                    ? 'text-white'
                    : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100/80 dark:hover:bg-slate-800/60'
                }`}
              >
                {/* Animate UI Spring Active Floating Backdrop Indicator */}
                {isActive && (
                  <motion.div
                    layoutId="sidebar-active-tab-indicator"
                    className="absolute inset-0 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-700 shadow-md shadow-indigo-900/30 -z-0"
                    transition={{ type: "spring", stiffness: 450, damping: 35 }}
                  />
                )}

                <div className="relative z-10 flex items-center gap-2.5 min-w-0">
                  <span className={isActive ? 'text-white' : 'text-slate-500 dark:text-slate-400'}>
                    {item.icon}
                  </span>
                  {!isCollapsed && (
                    <span className="truncate">{item.label}</span>
                  )}
                </div>

                {item.badge && !isCollapsed && (
                  <span className={`relative z-10 text-[10px] px-2 py-0.5 rounded-full font-bold font-mono shrink-0 ml-1.5 transition-colors ${
                    item.badgeColor || (isActive ? 'bg-white/20 text-white' : 'bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300')
                  }`}>
                    {item.badge}
                  </span>
                )}
              </motion.a>
            );
          })}
        </div>
      </div>

      {/* Admin Profile Footer */}
      <div className={`p-3.5 border-t border-slate-200 dark:border-slate-800 bg-slate-50/70 dark:bg-slate-950/60 ${isCollapsed ? 'flex justify-center' : ''}`}>
        <div className="flex items-center gap-2.5 min-w-0">
          <motion.div 
            whileHover={{ scale: 1.08 }}
            className="w-8 h-8 shrink-0 rounded-xl bg-gradient-to-tr from-indigo-600 to-sky-500 flex items-center justify-center text-white font-bold text-xs shadow-xs"
          >
            TT
          </motion.div>
          {!isCollapsed && (
            <div className="flex-1 min-w-0">
              <div className="text-xs font-bold text-slate-800 dark:text-slate-200 truncate">
                Đinh Tử Thuật
              </div>
              <div className="text-[11px] text-indigo-600 dark:text-indigo-400 truncate flex items-center gap-1 font-mono">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 shrink-0"></span>
                <span className="truncate">dtthuat009@gmail.com</span>
              </div>
            </div>
          )}
        </div>
      </div>

    </motion.aside>
  );
};
