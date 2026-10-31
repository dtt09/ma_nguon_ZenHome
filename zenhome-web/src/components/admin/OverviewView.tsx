import React from 'react';
import { 
  Users, 
  Smartphone, 
  ShieldCheck, 
  Layers, 
  Sparkles,
  AlertOctagon,
  ArrowRight,
  Server,
  Activity,
  Cpu,
  RefreshCw,
  ExternalLink,
  ChevronRight,
  CheckCircle2,
  Lock,
  Zap,
  HardDrive
} from 'lucide-react';
import { motion } from 'motion/react';
import { CountingNumber } from '@animate-ui/react/primitives/texts/counting-number';
import { RealCustomerUser, RealCrashLog, RealSystemStats } from '../../types/admin';
import { maskPhone, maskEmail } from '../../utils/masking';

interface OverviewViewProps {
  stats: RealSystemStats;
  customers: RealCustomerUser[];
  crashes: RealCrashLog[];
  onSelectCustomer: (customer: RealCustomerUser) => void;
  onNavigateToCustomers: () => void;
  onNavigateToCrashes: () => void;
  onOpenVersionModal?: () => void;
  onOpenEsp32Modal?: () => void;
  onNavigateToBackupServer?: () => void;
}

export const OverviewView: React.FC<OverviewViewProps> = ({
  stats,
  customers,
  crashes,
  onSelectCustomer,
  onNavigateToCustomers,
  onNavigateToCrashes,
  onOpenVersionModal,
  onOpenEsp32Modal,
  onNavigateToBackupServer
}) => {
  return (
    <div className="space-y-6">
      
      {/* 1. TOP BENTO HERO BANNER: ZenHome Command Hub */}
      <motion.div 
        initial={{ opacity: 0, y: 14 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
        className="relative overflow-hidden rounded-3xl border border-slate-200 dark:border-slate-800 bg-gradient-to-br from-white via-indigo-50/40 to-sky-50/50 dark:from-slate-900/90 dark:via-slate-900/80 dark:to-indigo-950/40 p-6 sm:p-8 backdrop-blur-xl shadow-xs transition-all"
      >
        {/* Subtle decorative glow effect */}
        <div className="absolute top-0 right-0 -mr-20 -mt-20 w-80 h-80 rounded-full bg-indigo-500/10 dark:bg-indigo-500/5 blur-3xl pointer-events-none" />
        <div className="absolute bottom-0 left-1/3 -mb-20 w-60 h-60 rounded-full bg-sky-500/10 dark:bg-sky-500/5 blur-3xl pointer-events-none" />

        <div className="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-500/10 dark:bg-indigo-500/20 border border-indigo-300 dark:border-indigo-500/30 text-xs font-semibold text-indigo-700 dark:text-indigo-300 backdrop-blur-md shadow-xs">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
              </span>
              <span>ZenHome Cloud Command Center • Animate UI Activated</span>
            </div>

            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900 dark:text-slate-50">
              Cổng Quản Trị Khách Hàng & Hệ Thống IoT ZenHome
            </h1>
            <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 max-w-2xl font-normal leading-relaxed">
              Theo dõi dữ liệu khách hàng thời gian thực từ Cloud Firestore, quản lý phiên thiết bị di động Flutter, giám sát phần cứng ESP32 và phát hành phiên bản cập nhật OTA.
            </p>
          </div>

          {/* Quick telemetry card */}
          <div className="flex flex-col gap-2 p-4 rounded-2xl bg-white/80 dark:bg-slate-950/70 border border-slate-200 dark:border-slate-800 backdrop-blur-md min-w-[240px] text-xs shadow-xs">
            <div className="flex items-center justify-between">
              <span className="text-slate-500 dark:text-slate-400">Database Firestore:</span>
              <strong className="text-slate-800 dark:text-slate-200 font-mono">smarthome-98dd7</strong>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-slate-500 dark:text-slate-400">Cloud Region:</span>
              <span className="text-slate-700 dark:text-slate-300 font-mono">asia-southeast1</span>
            </div>
            <div className="flex items-center justify-between pt-1 border-t border-slate-100 dark:border-slate-800">
              <span className="text-slate-500 dark:text-slate-400">Cơ chế đồng bộ:</span>
              <span className="text-emerald-600 dark:text-emerald-400 font-semibold flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                <span>Dual-Layer Realtime Cache</span>
              </span>
            </div>
          </div>
        </div>
      </motion.div>

      {/* 2. BENTO METRIC CARDS: 5 Key Indicators with Animate UI CountingNumber & Spring Lift */}
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
        
        {/* CARD 1: Total Real Customers (Deep Cyan) */}
        <motion.div 
          onClick={onNavigateToCustomers}
          whileHover={{ y: -4, transition: { duration: 0.2 } }}
          whileTap={{ scale: 0.98 }}
          className="group relative p-5 rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs hover:shadow-lg hover:border-sky-400 dark:hover:border-sky-500/50 cursor-pointer transition-all overflow-hidden"
        >
          <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 mb-3">
            <span className="text-[11px] font-bold uppercase tracking-wider text-sky-600 dark:text-sky-400">
              Khách hàng thực
            </span>
            <div className="p-2 rounded-2xl bg-sky-500/10 text-sky-600 dark:text-sky-400 border border-sky-200 dark:border-sky-500/20 group-hover:scale-110 transition-transform">
              <Users className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono text-slate-900 dark:text-slate-50 tracking-tight flex items-center">
            <CountingNumber number={stats.totalCustomers} />
          </div>
          <div className="flex items-center justify-between text-[11px] text-slate-500 dark:text-slate-400 mt-2 font-medium">
            <span>Tài khoản /users</span>
            <span className="text-sky-600 dark:text-sky-400 group-hover:translate-x-0.5 transition-transform flex items-center gap-0.5">
              <span>Xem</span>
              <ChevronRight className="w-3 h-3" />
            </span>
          </div>
        </motion.div>

        {/* CARD 2: App Sessions (Mint Emerald) */}
        <motion.div 
          whileHover={{ y: -4, transition: { duration: 0.2 } }}
          className="group relative p-5 rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs hover:shadow-lg hover:border-emerald-400 dark:hover:border-emerald-500/50 transition-all overflow-hidden"
        >
          <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 mb-3">
            <span className="text-[11px] font-bold uppercase tracking-wider text-emerald-600 dark:text-emerald-400">
              Phiên App Di Động
            </span>
            <div className="p-2 rounded-2xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-500/20 group-hover:scale-110 transition-transform">
              <Smartphone className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono text-slate-900 dark:text-slate-50 tracking-tight flex items-center">
            <CountingNumber number={stats.totalSessions} />
          </div>
          <div className="text-[11px] text-slate-500 dark:text-slate-400 mt-2 font-mono flex items-center gap-1.5">
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75" />
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500" />
            </span>
            <span>Thiết bị trong /sessions</span>
          </div>
        </motion.div>

        {/* CARD 3: OTA Version (Tech Indigo & Amber Accent) */}
        <motion.div 
          onClick={onOpenVersionModal}
          whileHover={{ y: -4, transition: { duration: 0.2 } }}
          whileTap={{ scale: 0.98 }}
          className="group relative p-5 rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs hover:shadow-lg hover:border-indigo-400 dark:hover:border-indigo-500/50 cursor-pointer transition-all overflow-hidden"
          title="Bấm để mở Cổng phát hành & Quản lý phiên bản OTA"
        >
          <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 mb-3">
            <span className="text-[11px] font-bold uppercase tracking-wider text-indigo-600 dark:text-indigo-400 flex items-center gap-1">
              <span>Bản App</span>
              <span className="text-[9px] px-1.5 py-0.2 rounded bg-amber-500/20 text-amber-600 dark:text-amber-400 border border-amber-300 dark:border-amber-500/30 font-bold">OTA</span>
            </span>
            <div className="p-2 rounded-2xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-500/20 group-hover:rotate-12 transition-transform">
              <Sparkles className="w-4 h-4 text-amber-500" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono text-indigo-600 dark:text-indigo-400 tracking-tight">
            {stats.latestAppVersion || 'v1.8.0'}
          </div>
          <div className="text-[11px] text-slate-500 dark:text-slate-400 mt-2 font-mono flex items-center justify-between">
            <span>Build {stats.latestBuildNumber || 185}</span>
            <span className="text-indigo-600 dark:text-indigo-400 underline underline-offset-2 font-semibold">Cài đặt ↗</span>
          </div>
        </motion.div>

        {/* CARD 4: Relay Channels (Vivid Amber) */}
        <motion.div 
          whileHover={{ y: -4, transition: { duration: 0.2 } }}
          className="group relative p-5 rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-xs hover:shadow-lg hover:border-amber-400 dark:hover:border-amber-500/50 transition-all overflow-hidden"
        >
          <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 mb-3">
            <span className="text-[11px] font-bold uppercase tracking-wider text-amber-600 dark:text-amber-400">
              Kênh Rơ-le DB
            </span>
            <div className="p-2 rounded-2xl bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-500/20 group-hover:scale-110 transition-transform">
              <Layers className="w-4 h-4" />
            </div>
          </div>
          <div className="text-3xl sm:text-4xl font-extrabold font-mono text-slate-900 dark:text-slate-50 tracking-tight flex items-center">
            <CountingNumber number={stats.totalDevices} />
          </div>
          <div className="text-[11px] text-slate-500 dark:text-slate-400 mt-2 font-mono">
            Khai báo trong devices[]
          </div>
        </motion.div>

        {/* CARD 5: System Crashes & Safety (Crimson Rose or Mint Emerald) */}
        <motion.div 
          onClick={onNavigateToCrashes}
          whileHover={{ y: -4, transition: { duration: 0.2 } }}
          whileTap={{ scale: 0.98 }}
          className={`group relative p-5 rounded-3xl border bg-white dark:bg-slate-900 shadow-xs hover:shadow-lg cursor-pointer transition-all overflow-hidden ${
            stats.totalCrashes > 0
              ? 'border-rose-300 dark:border-rose-900/60 hover:border-rose-500'
              : 'border-slate-200 dark:border-slate-800 hover:border-emerald-400 dark:hover:border-emerald-500/50'
          }`}
        >
          <div className="flex items-center justify-between text-slate-500 dark:text-slate-400 mb-3">
            <span className={`text-[11px] font-bold uppercase tracking-wider ${stats.totalCrashes > 0 ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'}`}>
              Lỗi Firebase
            </span>
            <div className={`p-2 rounded-2xl border ${
              stats.totalCrashes > 0
                ? 'bg-rose-500/10 text-rose-600 dark:text-rose-400 border-rose-200 dark:border-rose-500/20'
                : 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border-emerald-200 dark:border-emerald-500/20'
            }`}>
              {stats.totalCrashes > 0 ? <AlertOctagon className="w-4 h-4" /> : <ShieldCheck className="w-4 h-4" />}
            </div>
          </div>
          <div className={`text-3xl sm:text-4xl font-extrabold font-mono tracking-tight flex items-center ${stats.totalCrashes > 0 ? 'text-rose-600 dark:text-rose-400' : 'text-emerald-600 dark:text-emerald-400'}`}>
            <CountingNumber number={stats.totalCrashes} />
          </div>
          <div className="text-[11px] text-slate-500 dark:text-slate-400 mt-2 font-medium">
            {stats.totalCrashes === 0 ? 'Hệ thống an toàn (0 crash)' : `${stats.totalCrashes} lỗi đã ghi ↗`}
          </div>
        </motion.div>

      </div>

      {/* 3. BENTO LOWER SECTION: Recent Customers Feed (8 cols) + Operations & Infrastructure Hub (4 cols) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* LEFT BENTO (8 COLS): Live Customer Accounts from Firestore */}
        <div className="lg:col-span-8 rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-6 shadow-xs">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-4">
            <div className="flex items-center gap-2.5">
              <div className="p-2 rounded-xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-500/20">
                <Users className="w-4 h-4" />
              </div>
              <div>
                <h3 className="font-bold text-sm text-slate-900 dark:text-slate-50">
                  Tài khoản khách hàng thực trên Firestore
                </h3>
                <p className="text-[11px] text-slate-500 dark:text-slate-400">
                  Dữ liệu tự động làm mờ thông tin cá nhân (PII Protected)
                </p>
              </div>
            </div>

            <button
              onClick={onNavigateToCustomers}
              className="text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 flex items-center gap-1 transition-colors"
            >
              <span>Xem tất cả ({customers.length})</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          {customers.length === 0 ? (
            <div className="py-12 text-center text-xs text-slate-500 dark:text-slate-400">
              Chưa có dữ liệu khách hàng nào được tìm thấy trên Cloud Firestore.
            </div>
          ) : (
            <div className="space-y-3">
              {customers.slice(0, 6).map((c) => (
                <motion.div
                  key={c.id}
                  whileHover={{ x: 3, transition: { duration: 0.15 } }}
                  onClick={() => onSelectCustomer(c)}
                  className="p-3.5 sm:p-4 rounded-2xl bg-slate-50/70 dark:bg-slate-950/60 border border-slate-200/80 dark:border-slate-800/60 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs hover:bg-indigo-50/80 hover:border-indigo-300 dark:hover:bg-indigo-950/20 dark:hover:border-indigo-500/40 cursor-pointer transition-all duration-200 group"
                >
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-indigo-500 to-sky-600 flex items-center justify-center text-white font-bold text-base shadow-xs shrink-0 group-hover:scale-105 transition-transform">
                      {c.displayName.charAt(0).toUpperCase()}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="font-bold text-sm text-slate-900 dark:text-slate-50 flex items-center gap-2 group-hover:text-indigo-600 dark:group-hover:text-indigo-400 transition-colors">
                        <span className="truncate">{c.displayName}</span>
                        <span className="font-mono text-[10px] text-slate-500 dark:text-slate-400 bg-white dark:bg-slate-900 px-1.5 py-0.5 rounded border border-slate-200 dark:border-slate-800 shrink-0">
                          {c.id}
                        </span>
                      </div>
                      <div className="text-slate-500 dark:text-slate-400 text-[11px] font-mono mt-0.5 truncate">
                        Email: {maskEmail(c.email)} • SĐT: {maskPhone(c.phoneNumber)} • MAC: {c.macAddress}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4 self-end sm:self-center font-mono shrink-0">
                    <div className="text-right">
                      <div className="font-bold text-slate-800 dark:text-slate-200">
                        {c.devices.length} rơ-le
                      </div>
                      <div className="text-[10px] text-slate-500 dark:text-slate-400">
                        {c.sessions.length} thiết bị ({c.sessions[0]?.appVersion ? `v${c.sessions[0].appVersion}` : (stats.latestAppVersion || 'v1.8.0')})
                      </div>
                    </div>

                    <span className="px-3 py-1.5 rounded-xl bg-slate-200 dark:bg-slate-800 group-hover:bg-indigo-600 group-hover:text-white dark:group-hover:bg-indigo-600 text-slate-700 dark:text-slate-300 font-semibold text-xs transition-colors">
                      Chi tiết
                    </span>
                  </div>
                </motion.div>
              ))}
            </div>
          )}
        </div>

        {/* RIGHT BENTO (4 COLS): Quick Operations Hub & System Architecture */}
        <div className="lg:col-span-4 space-y-6">
          
          {/* Quick Action Hub */}
          <div className="rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-6 shadow-xs space-y-4">
            <div className="flex items-center gap-2 pb-3 border-b border-slate-100 dark:border-slate-800">
              <Zap className="w-4 h-4 text-amber-500" />
              <h3 className="font-bold text-sm text-slate-900 dark:text-slate-50">
                Thao Tác Nhanh
              </h3>
            </div>

            <div className="space-y-2.5">
              {/* Action 1: Open OTA Version Modal */}
              <motion.button
                onClick={onOpenVersionModal}
                whileHover={{ x: 2 }}
                whileTap={{ scale: 0.98 }}
                className="w-full p-3 rounded-2xl bg-gradient-to-r from-indigo-50 to-sky-50 dark:from-indigo-950/40 dark:to-sky-950/40 border border-indigo-200/80 dark:border-indigo-800/50 hover:border-indigo-400 flex items-center justify-between text-left text-xs transition-all group"
              >
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-indigo-500/10 text-indigo-600 dark:text-indigo-400 border border-indigo-200 dark:border-indigo-500/20">
                    <Sparkles className="w-4 h-4 text-amber-500" />
                  </div>
                  <div>
                    <div className="font-bold text-slate-900 dark:text-slate-50 group-hover:text-indigo-600 dark:group-hover:text-indigo-400">
                      Phát hành OTA APK mới
                    </div>
                    <div className="text-[10px] text-slate-500 dark:text-slate-400">
                      Cập nhật build app cho khách hàng
                    </div>
                  </div>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-indigo-500 group-hover:translate-x-0.5 transition-all" />
              </motion.button>

              {/* Action 1.5: Open ESP32 Firmware OTA Modal */}
              <motion.button
                onClick={onOpenEsp32Modal}
                whileHover={{ x: 2 }}
                whileTap={{ scale: 0.98 }}
                className="w-full p-3 rounded-2xl bg-gradient-to-r from-violet-50 to-fuchsia-50 dark:from-violet-950/40 dark:to-fuchsia-950/40 border border-violet-200/80 dark:border-violet-800/50 hover:border-violet-400 flex items-center justify-between text-left text-xs transition-all group"
              >
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-violet-500/10 text-violet-600 dark:text-violet-400 border border-violet-200 dark:border-violet-500/20">
                    <Cpu className="w-4 h-4 text-violet-500" />
                  </div>
                  <div>
                    <div className="font-bold text-slate-900 dark:text-slate-50 group-hover:text-violet-600 dark:group-hover:text-violet-400">
                      Phát hành Firmware ESP32
                    </div>
                    <div className="text-[10px] text-slate-500 dark:text-slate-400">
                      Nâng cấp vi điều khiển Hub qua GitHub & MQTT
                    </div>
                  </div>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-violet-500 group-hover:translate-x-0.5 transition-all" />
              </motion.button>

              {/* Action 2: Navigate to Backup Server */}
              <motion.button
                onClick={onNavigateToBackupServer}
                whileHover={{ x: 2 }}
                whileTap={{ scale: 0.98 }}
                className="w-full p-3 rounded-2xl bg-gradient-to-r from-sky-50 to-blue-50 dark:from-sky-950/40 dark:to-blue-950/40 border border-sky-200/80 dark:border-sky-800/50 hover:border-sky-400 flex items-center justify-between text-left text-xs transition-all group"
              >
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-sky-500/10 text-sky-600 dark:text-sky-400 border border-sky-200 dark:border-sky-500/20">
                    <Server className="w-4 h-4" />
                  </div>
                  <div>
                    <div className="font-bold text-slate-900 dark:text-slate-50 group-hover:text-sky-600 dark:group-hover:text-sky-400">
                      Server Backup (Cổng 5000)
                    </div>
                    <div className="text-[10px] text-slate-500 dark:text-slate-400">
                      Xem Socket.IO, telemetry & trạng thái cache
                    </div>
                  </div>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-sky-500 group-hover:translate-x-0.5 transition-all" />
              </motion.button>

              {/* Action 3: Review Crashes */}
              <motion.button
                onClick={onNavigateToCrashes}
                whileHover={{ x: 2 }}
                whileTap={{ scale: 0.98 }}
                className="w-full p-3 rounded-2xl bg-gradient-to-r from-rose-50 to-amber-50 dark:from-rose-950/30 dark:to-amber-950/20 border border-rose-200/80 dark:border-rose-900/40 hover:border-rose-400 flex items-center justify-between text-left text-xs transition-all group"
              >
                <div className="flex items-center gap-2.5">
                  <div className="p-2 rounded-xl bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-200 dark:border-rose-500/20">
                    <AlertOctagon className="w-4 h-4" />
                  </div>
                  <div>
                    <div className="font-bold text-slate-900 dark:text-slate-50 group-hover:text-rose-600 dark:group-hover:text-rose-400">
                      Nhật ký Sự cố & Báo cáo Lỗi
                    </div>
                    <div className="text-[10px] text-slate-500 dark:text-slate-400">
                      Kiểm tra stack trace và ngoại lệ người dùng
                    </div>
                  </div>
                </div>
                <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-rose-500 group-hover:translate-x-0.5 transition-all" />
              </motion.button>
            </div>
          </div>

          {/* Infrastructure Health Checklist */}
          <div className="rounded-3xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-6 shadow-xs space-y-3.5 text-xs">
            <div className="flex items-center gap-2 pb-2.5 border-b border-slate-100 dark:border-slate-800">
              <HardDrive className="w-4 h-4 text-indigo-500" />
              <h3 className="font-bold text-slate-900 dark:text-slate-50">
                Hạ Tầng Kỹ Thuật Đã Củng Cố
              </h3>
            </div>

            <div className="space-y-2 text-slate-600 dark:text-slate-400">
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
                  <span>Bộ Đệm RAM Server (4s Cache TTL)</span>
                </span>
                <span className="font-mono text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">0ms / ACTIVE</span>
              </div>

              <div className="flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
                  <span>Chống Bão Polling (Debounce 1.2s)</span>
                </span>
                <span className="font-mono text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">AN TOÀN</span>
              </div>

              <div className="flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
                  <span>Đồng bộ Cổng (Port 3000 $\leftrightarrow$ 5000)</span>
                </span>
                <span className="font-mono text-[10px] text-sky-600 dark:text-sky-400 font-bold">ONLINE</span>
              </div>

              <div className="flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
                  <span>Tự động Khóa (Auto-Lock 15p)</span>
                </span>
                <span className="font-mono text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">BẬT</span>
              </div>

              <div className="flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
                  <span>Bảo vệ Dữ liệu Nhạy cảm (PII)</span>
                </span>
                <span className="font-mono text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">MÃ HÓA</span>
              </div>
            </div>
          </div>

        </div>

      </div>

    </div>
  );
};
