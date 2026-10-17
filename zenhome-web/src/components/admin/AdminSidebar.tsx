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
  MessageSquareWarning
} from 'lucide-react';

export type AdminTab = 'overview' | 'customers' | 'bug_reports' | 'crash_logs' | 'database' | 'fleet' | 'backup_server' | 'api_system';

interface AdminSidebarProps {
  activeTab: AdminTab;
  onSelectTab: (tab: AdminTab) => void;
  totalCustomers: number;
  totalCrashes: number;
  totalReports?: number;
  totalDocs: number;
}

export const AdminSidebar: React.FC<AdminSidebarProps> = ({
  activeTab,
  onSelectTab,
  totalCustomers,
  totalCrashes,
  totalReports = 0,
  totalDocs
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

    // Chạy lần đầu tiên để check kích thước màn hình
    handleResize();

    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  const navItems = [
    {
      id: 'overview' as AdminTab,
      label: 'Tổng quan hệ thống',
      icon: <BarChart3 className="w-5 h-5" />,
      badge: null,
    },
    {
      id: 'customers' as AdminTab,
      label: 'Khách hàng trên Firebase',
      icon: <Users className="w-5 h-5" />,
      badge: totalCustomers.toString(),
    },
    {
      id: 'bug_reports' as AdminTab,
      label: 'Báo cáo sự cố người dùng',
      icon: <MessageSquareWarning className="w-5 h-5" />,
      badge: totalReports > 0 ? `${totalReports} tin` : null,
      badgeColor: totalReports > 0 ? 'bg-amber-500 text-white' : undefined,
    },
    {
      id: 'crash_logs' as AdminTab,
      label: 'Nhật ký lỗi (Crashlytics)',
      icon: <AlertOctagon className="w-5 h-5" />,
      badge: totalCrashes > 0 ? `${totalCrashes} lỗi` : '0 lỗi',
      badgeColor: totalCrashes > 0 ? 'bg-rose-500 text-white' : 'bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-400',
    },
    {
      id: 'database' as AdminTab,
      label: 'Duyệt Cloud Firestore',
      icon: <Database className="w-5 h-5" />,
      badge: `${totalDocs} docs`,
    },
    {
      id: 'fleet' as AdminTab,
      label: 'Phần cứng & Thiết bị ESP32',
      icon: <Cpu className="w-5 h-5" />,
      badge: null,
    },
    {
      id: 'backup_server' as AdminTab,
      label: 'Server Backup ZenHome',
      icon: <Server className="w-5 h-5" />,
      badge: 'ONLINE',
      badgeColor: 'bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-800/50',
    },
    {
      id: 'api_system' as AdminTab,
      label: 'Hệ thống REST API',
      icon: <Code2 className="w-5 h-5" />,
      badge: 'v1.0',
      badgeColor: 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800/50',
    },
  ];

  return (
    <aside className={`${isCollapsed ? 'w-20' : 'w-72'} transition-all duration-300 bg-white dark:bg-slate-900 border-r border-slate-200 dark:border-slate-800/60 text-slate-600 dark:text-slate-400 flex flex-col justify-between shrink-0 select-none relative group`}>
      
      {/* Brand & System Tag - Clickable to toggle collapse */}
      <div className="overflow-hidden">
        <button 
          onClick={() => setIsCollapsed(!isCollapsed)}
          className="w-full p-5 border-b border-slate-200 dark:border-slate-800/60 flex items-center gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors text-left focus:outline-none focus:bg-slate-100 dark:focus:bg-slate-800"
          title={isCollapsed ? "Mở rộng menu" : "Thu gọn menu"}
        >
          <div className="w-10 h-10 shrink-0 drop-shadow-sm flex items-center justify-center relative">
            <img 
              src="/zenhome_logo_real.png" 
              alt="ZenHome Admin" 
              className={`w-full h-full object-contain transition-opacity duration-300 ${isCollapsed ? 'opacity-50 group-hover:opacity-100' : 'opacity-100'}`}
            />
            {/* Show a small menu icon overlay when collapsed for better UX hint */}
            {isCollapsed && (
              <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-white/80 dark:bg-slate-900/80 rounded-lg">
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-indigo-600"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>
              </div>
            )}
          </div>
          <div className={`transition-opacity duration-300 ${isCollapsed ? 'opacity-0 w-0 hidden' : 'opacity-100'}`}>
            <div className="flex items-center gap-1.5">
              <span className="font-extrabold text-base tracking-tight text-slate-900 dark:text-slate-50">
                ZenHome
              </span>
              <span className="text-[10px] px-1.5 py-0.2 rounded font-mono font-bold bg-indigo-100 dark:bg-indigo-900/40 text-indigo-700 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-800/50">
                ADMIN
              </span>
            </div>
            <div className="text-xs text-slate-500 dark:text-slate-400 font-medium whitespace-nowrap">
              Cổng Quản trị Khách hàng & IoT
            </div>
          </div>
        </button>

        {/* Cloud Project Environment Indicator */}
        <div className={`px-4 py-3 mx-3 mt-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800/60 text-xs transition-opacity duration-300 ${isCollapsed ? 'hidden' : 'block'}`}>
          <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 text-[11px] mb-1">
            <span className="flex items-center gap-1">
              <Server className="w-3.5 h-3.5 text-blue-400" />
              <span>Dự án Firebase thực tế:</span>
            </span>
            <span className="flex h-2 w-2 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-blue-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-indigo-600 dark:bg-indigo-500"></span>
            </span>
          </div>
          <div className="font-mono text-indigo-700 dark:text-indigo-400 font-semibold truncate text-[11px]">
            smarthome-98dd7
          </div>
          <div className="text-[10px] text-slate-500 dark:text-slate-400 mt-1">
            Vùng Cloud: asia-southeast1 (Firestore)
          </div>
        </div>

        {/* Navigation list */}
        <div className="px-3 py-4 space-y-1">
          <div className={`px-3 pb-2 text-[10px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider transition-opacity duration-300 ${isCollapsed ? 'hidden' : 'block'}`}>
            Quản trị Vận hành & Dữ liệu
          </div>

          {navItems.map((item, index) => {
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => onSelectTab(item.id)}
                title={isCollapsed ? item.label : undefined}
                className={`w-full flex items-center justify-between px-3.5 py-2.5 rounded-xl text-xs font-semibold transition-all animate-in slide-in-from-left-2 fade-in duration-300 fill-mode-both ${
                  isActive
                    ? 'bg-gradient-to-r from-blue-500 to-blue-600 text-white shadow-md shadow-indigo-900/20 dark:shadow-indigo-900/50'
                    : 'text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800/80 dark:bg-slate-800/50/60'
                }`}
                style={{ animationDelay: `${index * 50}ms` }}
              >
                <div className="flex items-center gap-3">
                  <span className={isActive ? 'text-slate-900 dark:text-slate-50' : 'text-slate-500 dark:text-slate-400 group-hover:text-indigo-700 dark:text-indigo-500'}>
                    {item.icon}
                  </span>
                  <span className={`whitespace-nowrap transition-opacity duration-300 ${isCollapsed ? 'hidden' : 'block'}`}>{item.label}</span>
                </div>

                {item.badge && !isCollapsed && (
                  <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold font-mono ${
                    item.badgeColor || 'bg-slate-100 dark:bg-slate-800/50 text-slate-600 dark:text-slate-400'
                  }`}>
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Admin Profile Footer */}
      <div className={`p-4 border-t border-slate-200 dark:border-slate-800/60 bg-slate-50 dark:bg-slate-950/60 ${isCollapsed ? 'flex justify-center' : ''}`}>
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 shrink-0 rounded-xl bg-gradient-to-tr from-blue-500 to-sky-500 flex items-center justify-center text-slate-900 dark:text-slate-50 font-bold text-sm shadow-md">
            TT
          </div>
          <div className={`flex-1 min-w-0 transition-opacity duration-300 ${isCollapsed ? 'hidden' : 'block'}`}>
            <div className="text-xs font-bold text-slate-800 dark:text-slate-200 font-bold truncate">
              Đinh Tử Thuật
            </div>
            <div className="text-[11px] text-blue-400 truncate flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-blue-400"></span>
              <span>dtthuat009@gmail.com</span>
            </div>
          </div>
        </div>
      </div>

    </aside>
  );
};
