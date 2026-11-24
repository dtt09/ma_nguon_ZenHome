import React from 'react';
import { 
  AlertTriangle, 
  ShieldAlert, 
  ShieldCheck, 
  Zap, 
  X, 
  Clock, 
  Radio, 
  CheckCircle2, 
  RefreshCw 
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { SystemAlert } from '../../types/admin';

interface HardwareAnomalyBannerProps {
  alerts: SystemAlert[];
  onDismissAlert: (id: string) => void;
  onClearAll?: () => void;
  onNavigateToFleet?: () => void;
  isSocketConnected?: boolean;
}

export const HardwareAnomalyBanner: React.FC<HardwareAnomalyBannerProps> = ({
  alerts,
  onDismissAlert,
  onClearAll,
  onNavigateToFleet,
  isSocketConnected = true,
}) => {
  const activeAlerts = alerts.filter(a => !a.acknowledged);

  if (activeAlerts.length === 0) {
    return (
      <div className="p-3 sm:p-4 rounded-2xl bg-emerald-50/80 dark:bg-emerald-950/20 border border-emerald-200 dark:border-emerald-900/40 flex items-center justify-between text-xs text-emerald-800 dark:text-emerald-300">
        <div className="flex items-center gap-2.5">
          <div className="p-1.5 rounded-lg bg-emerald-500/20 text-emerald-600 dark:text-emerald-400">
            <ShieldCheck className="w-4 h-4" />
          </div>
          <div>
            <span className="font-bold">Hệ Thống Rơ-le & Phần Cứng Hoạt Động Bình Thường:</span>
            <span className="text-emerald-700/80 dark:text-emerald-400/80 ml-1.5">
              Edge Anomaly Detector trên ESP32 đang giám sát tần suất đóng/ngắt 24/7. Không phát hiện hiện tượng chattering hay chập tải.
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2 shrink-0">
          <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
            {isSocketConnected ? 'WebSocket Live' : 'Polling'}
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className="rounded-3xl border-2 border-rose-500/80 dark:border-rose-600 bg-rose-50/90 dark:bg-rose-950/40 p-5 shadow-lg shadow-rose-500/10 backdrop-blur-md space-y-3.5 animate-in fade-in slide-in-from-top-2 duration-300">
      
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-rose-200 dark:border-rose-900/60">
        <div className="flex items-center gap-2.5">
          <div className="p-2 rounded-xl bg-rose-500 text-white shadow-md shadow-rose-500/30 animate-bounce">
            <AlertTriangle className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <h3 className="font-extrabold text-sm sm:text-base text-rose-950 dark:text-rose-100 tracking-tight">
                Cảnh Báo Dị Thường Phần Cứng Thời Gian Thực (Edge Anomaly Alert)
              </h3>
              <span className="px-2 py-0.5 rounded-full bg-rose-600 text-white text-[10px] font-black uppercase tracking-wider animate-pulse">
                {activeAlerts.length} Sự Cố
              </span>
            </div>
            <p className="text-xs text-rose-800 dark:text-rose-300 mt-0.5">
              ESP32 đã phát hiện bất thường đóng/ngắt tiếp điểm và tự động kích hoạt cơ chế khóa an toàn.
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          {onClearAll && (
            <button
              onClick={onClearAll}
              className="px-3 py-1.5 text-xs font-semibold rounded-xl bg-rose-200/80 dark:bg-rose-900/60 hover:bg-rose-300 dark:hover:bg-rose-800 text-rose-900 dark:text-rose-100 transition-colors"
            >
              Bỏ qua tất cả
            </button>
          )}
          {onNavigateToFleet && (
            <button
              onClick={onNavigateToFleet}
              className="px-3.5 py-1.5 text-xs font-bold rounded-xl bg-rose-600 hover:bg-rose-700 text-white shadow-sm transition-all"
            >
              Kiểm tra Fleet ESP32 ↗
            </button>
          )}
        </div>
      </div>

      {/* Alert items list */}
      <div className="space-y-2.5">
        <AnimatePresence>
          {activeAlerts.map((alert) => (
            <motion.div
              key={alert.id}
              initial={{ opacity: 0, height: 0 }}
              animate={{ opacity: 1, height: 'auto' }}
              exit={{ opacity: 0, height: 0 }}
              className="p-3.5 rounded-2xl bg-white dark:bg-slate-900 border border-rose-300 dark:border-rose-900/70 shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs"
            >
              <div className="flex items-start gap-3">
                <div className="p-2 rounded-xl bg-rose-100 dark:bg-rose-950 text-rose-600 dark:text-rose-400 shrink-0 mt-0.5">
                  <Zap className="w-4 h-4" />
                </div>
                <div className="space-y-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-extrabold text-slate-900 dark:text-slate-100 text-xs">
                      {alert.title || 'Phát hiện Chattering / Chập Rơ-le'}
                    </span>
                    <span className="px-2 py-0.2 rounded text-[10px] font-bold font-mono bg-rose-100 dark:bg-rose-950 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-800">
                      {alert.type}
                    </span>
                    {alert.level && (
                      <span className="px-1.5 py-0.2 rounded text-[9px] font-black uppercase bg-red-600 text-white">
                        {alert.level}
                      </span>
                    )}
                  </div>

                  <p className="text-slate-600 dark:text-slate-300 text-xs">
                    {alert.message || 'Rơ-le bị kích hoạt liên tục > 6 lần / 2 giây. Thiết bị tự động ngắt SAFE OFF và khóa 30 giây.'}
                  </p>

                  <div className="flex flex-wrap items-center gap-3 text-[11px] font-mono text-slate-500 dark:text-slate-400 pt-0.5">
                    {alert.mac && (
                      <span className="flex items-center gap-1 font-semibold text-rose-700 dark:text-rose-400">
                        <Radio className="w-3 h-3" /> MAC: {alert.mac}
                      </span>
                    )}
                    {typeof alert.pin === 'number' && (
                      <span>Chân GPIO: {alert.pin}</span>
                    )}
                    {alert.action && (
                      <span className="text-amber-700 dark:text-amber-400 font-bold">
                        Hành động: {alert.action}
                      </span>
                    )}
                    <span className="flex items-center gap-1 text-slate-400">
                      <Clock className="w-3 h-3" />
                      {typeof alert.timestamp === 'string' ? new Date(alert.timestamp).toLocaleTimeString('vi-VN') : alert.timestamp}
                    </span>
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-2 self-end sm:self-center shrink-0">
                <button
                  onClick={() => onDismissAlert(alert.id)}
                  className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 flex items-center gap-1 transition-colors"
                  title="Xác nhận đã xử lý cảnh báo này"
                >
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-500" />
                  <span>Đã kiểm tra</span>
                </button>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>

    </div>
  );
};
