import React from 'react';
import { 
  Users, 
  Cpu, 
  AlertOctagon, 
  Smartphone, 
  Server, 
  ShieldCheck, 
  Layers, 
  Clock, 
  ExternalLink,
  Sparkles,
  UploadCloud
} from 'lucide-react';
import { RealCustomerUser, RealCrashLog, RealSystemStats } from '../../types/admin';

interface OverviewViewProps {
  stats: RealSystemStats;
  customers: RealCustomerUser[];
  crashes: RealCrashLog[];
  onSelectCustomer: (customer: RealCustomerUser) => void;
  onNavigateToCustomers: () => void;
  onNavigateToCrashes: () => void;
  onOpenVersionModal?: () => void;
}

export const OverviewView: React.FC<OverviewViewProps> = ({
  stats,
  customers,
  crashes,
  onSelectCustomer,
  onNavigateToCustomers,
  onNavigateToCrashes,
  onOpenVersionModal
}) => {
  return (
    <div className="space-y-6">
      
      {/* Top Welcome Banner */}
      <div className="rounded-3xl bg-gradient-to-r from-indigo-600 via-blue-600 to-sky-600 dark:from-slate-900 dark:via-indigo-950 dark:to-slate-900 text-white p-6 sm:p-8 shadow-xl shadow-blue-500/20 relative overflow-hidden">
        <div className="relative z-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-white/20 border border-white/30 text-xs font-semibold text-white mb-3 backdrop-blur-sm shadow-sm">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
              <span>Dữ liệu thực tế từ Cloud Firestore (smarthome-98dd7)</span>
            </div>
            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight drop-shadow-sm">
              Cổng Quản trị Khách hàng & Cơ sở dữ liệu ZenHome
            </h1>
            <p className="mt-1 text-sm text-blue-100 max-w-2xl font-medium">
              Hệ thống kết nối trực tiếp với Firebase Firestore, đồng bộ các tài khoản khách hàng, phiên ứng dụng di động Dart/Flutter và kiểm tra lỗi thời gian thực.
            </p>
          </div>

          <div className="flex flex-col gap-2 p-4 rounded-2xl bg-black/20 border border-white/20 backdrop-blur-md min-w-[210px] text-xs shadow-inner">
            <div className="flex items-center justify-between">
              <span className="text-blue-100">Firebase DB:</span>
              <strong className="text-white font-mono">smarthome-98dd7</strong>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-blue-100">Cloud Region:</span>
              <span className="text-white font-mono">asia-southeast1</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-blue-100">Cơ chế đồng bộ:</span>
              <span className="text-emerald-300 font-bold">onSnapshot (Real-time)</span>
            </div>
          </div>
        </div>
      </div>

      {/* Real KPI Cards - Phối màu rực rỡ & Đầy đủ 5 chỉ số then chốt */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        
        {/* 1. Total Real Customers */}
        <div 
          onClick={onNavigateToCustomers}
          className="p-5 rounded-3xl bg-gradient-to-br from-indigo-500 to-blue-600 border border-indigo-400/30 shadow-lg shadow-indigo-500/20 cursor-pointer hover:scale-[1.05] transition-transform text-white animate-in zoom-in-95 fade-in duration-500 fill-mode-both"
          style={{ animationDelay: '0ms' }}
        >
          <div className="flex items-center justify-between text-indigo-100 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider">Khách hàng thực</span>
            <div className="p-2 rounded-xl bg-white/20 text-white backdrop-blur-sm">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono">
            {stats.totalCustomers}
          </div>
          <div className="text-[11px] text-indigo-100 mt-2 font-medium opacity-90">
            Tài khoản trong /users
          </div>
        </div>

        {/* 2. Real App Sessions (Thiết bị đăng nhập) */}
        <div className="p-5 rounded-3xl bg-gradient-to-br from-sky-400 to-cyan-600 border border-sky-400/30 shadow-lg shadow-sky-500/20 text-white hover:scale-[1.05] transition-transform animate-in zoom-in-95 fade-in duration-500 fill-mode-both" style={{ animationDelay: '100ms' }}>
          <div className="flex items-center justify-between text-sky-100 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider">Phiên đăng nhập</span>
            <div className="p-2 rounded-xl bg-white/20 text-white backdrop-blur-sm">
              <Smartphone className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono">
            {stats.totalSessions}
          </div>
          <div className="text-[11px] text-sky-100 mt-2 font-mono opacity-90">
            Thiết bị trong /sessions
          </div>
        </div>

        {/* 3. Real App Release Version (Phiên bản App OTA) */}
        <div 
          onClick={onOpenVersionModal}
          className="p-5 rounded-3xl bg-gradient-to-br from-violet-600 to-indigo-700 border border-violet-400/30 shadow-lg shadow-violet-500/20 cursor-pointer hover:scale-[1.05] transition-transform text-white animate-in zoom-in-95 fade-in duration-500 fill-mode-both relative group"
          style={{ animationDelay: '150ms' }}
          title="Bấm để mở Cổng phát hành & Quản lý phiên bản OTA"
        >
          <div className="flex items-center justify-between text-violet-100 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider flex items-center gap-1">
              <span>Phiên bản App</span>
              <span className="text-[9px] px-1.5 py-0.2 rounded bg-amber-400 text-slate-900 font-extrabold">OTA</span>
            </span>
            <div className="p-2 rounded-xl bg-white/20 text-white backdrop-blur-sm group-hover:rotate-12 transition-transform">
              <Sparkles className="w-5 h-5 text-amber-300" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono text-amber-300">
            {stats.latestAppVersion || 'v1.5.0'}
          </div>
          <div className="text-[11px] text-violet-200 mt-2 font-mono flex items-center justify-between opacity-95">
            <span>Build {stats.latestBuildNumber || 150}</span>
            <span className="underline underline-offset-2 text-white font-semibold">Cài đặt ↗</span>
          </div>
        </div>

        {/* 4. Real Relays */}
        <div className="p-5 rounded-3xl bg-gradient-to-br from-amber-400 to-orange-500 border border-amber-400/30 shadow-lg shadow-amber-500/20 text-white hover:scale-[1.05] transition-transform animate-in zoom-in-95 fade-in duration-500 fill-mode-both" style={{ animationDelay: '200ms' }}>
          <div className="flex items-center justify-between text-amber-100 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider">Kênh Rơ-le DB</span>
            <div className="p-2 rounded-xl bg-white/20 text-white backdrop-blur-sm">
              <Layers className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono">
            {stats.totalDevices}
          </div>
          <div className="text-[11px] text-amber-100 mt-2 opacity-90">
            Khai báo trong devices[]
          </div>
        </div>

        {/* 5. Real Crashes */}
        <div 
          onClick={onNavigateToCrashes}
          className="p-5 rounded-3xl bg-gradient-to-br from-rose-500 to-red-600 border border-rose-400/30 shadow-lg shadow-rose-500/20 cursor-pointer hover:scale-[1.05] transition-transform text-white animate-in zoom-in-95 fade-in duration-500 fill-mode-both"
          style={{ animationDelay: '250ms' }}
        >
          <div className="flex items-center justify-between text-rose-100 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider">Lỗi Firebase</span>
            <div className="p-2 rounded-xl bg-white/20 text-white backdrop-blur-sm">
              <AlertOctagon className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono">
            {stats.totalCrashes}
          </div>
          <div className="text-[11px] text-rose-100 mt-2 opacity-90">
            {stats.totalCrashes === 0 ? 'Hệ thống an toàn (0 crash)' : `${stats.totalCrashes} lỗi đã ghi`}
          </div>
        </div>

      </div>

      {/* Customer List Preview */}
      <div className="rounded-2xl bg-white dark:bg-slate-900  border border-slate-200 dark:border-slate-800/60  p-5 shadow-sm">
        <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800  mb-4">
          <div className="flex items-center gap-2">
            <Users className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
            <h3 className="font-bold text-sm text-slate-900 dark:text-slate-50 ">
              Tài khoản khách hàng thực trên Firestore
            </h3>
          </div>
          <span className="text-xs font-mono text-slate-500 dark:text-slate-400">
            {customers.length} tài khoản
          </span>
        </div>

        <div className="space-y-3">
          {customers.map((c, index) => (
            <div
              key={c.id}
              onClick={() => onSelectCustomer(c)}
              className="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800/60 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs hover:bg-indigo-50 hover:border-indigo-300 dark:hover:bg-indigo-900/30 dark:hover:border-indigo-500/50 cursor-pointer transition-all transform hover:-translate-y-1 shadow-sm hover:shadow-md animate-in slide-in-from-bottom-2 fade-in duration-300 fill-mode-both"
              style={{ animationDelay: `${Math.min(index * 50, 500)}ms` }}
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-500 to-sky-600 flex items-center justify-center text-slate-900 dark:text-slate-50 font-bold text-base shadow-sm">
                  {c.displayName.charAt(0).toUpperCase()}
                </div>
                <div>
                  <div className="font-bold text-sm text-slate-900 dark:text-slate-50  flex items-center gap-2">
                    <span>{c.displayName}</span>
                    <span className="font-mono text-[10px] text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-900  px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-800/60 ">
                      ID: {c.id}
                    </span>
                  </div>
                  <div className="text-slate-500 dark:text-slate-400 text-[11px] font-mono mt-0.5">
                    Email: {c.email} • SĐT: {c.phoneNumber} • MAC: {c.macAddress}
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-4 self-end sm:self-center font-mono">
                <div className="text-right">
                  <div className="font-bold text-slate-700 dark:text-slate-300 ">
                    {c.devices.length} rơ-le
                  </div>
                  <div className="text-[10px] text-slate-500 dark:text-slate-400">
                    {c.sessions.length} thiết bị ({c.sessions[0]?.appVersion ? `v${c.sessions[0].appVersion}` : (stats.latestAppVersion || 'v1.5.0')})
                  </div>
                </div>

                <span className="px-3 py-1.5 rounded-lg bg-indigo-700 dark:bg-indigo-600 text-white font-semibold text-xs">
                  Xem chi tiết
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>

    </div>
  );
};
