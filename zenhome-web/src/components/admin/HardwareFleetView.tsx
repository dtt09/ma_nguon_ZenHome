import React, { useState } from 'react';
import { 
  Cpu, 
  Radio, 
  Search, 
  Layers, 
  RotateCcw, 
  Smartphone,
  ExternalLink 
} from 'lucide-react';
import { RealCustomerUser } from '../../types/admin';

interface HardwareFleetViewProps {
  customers: RealCustomerUser[];
  onSelectCustomer: (customer: RealCustomerUser) => void;
}

export const HardwareFleetView: React.FC<HardwareFleetViewProps> = ({
  customers,
  onSelectCustomer
}) => {
  const [search, setSearch] = useState('');
  const [localSearch, setLocalSearch] = useState('');

  const filtered = customers.filter(c => {
    return (
      (c.macAddress || '').toLowerCase().includes(search.toLowerCase()) ||
      (c.displayName || '').toLowerCase().includes(search.toLowerCase()) ||
      (c.id || '').toLowerCase().includes(search.toLowerCase())
    );
  });

  return (
    <div className="space-y-4">
      
      {/* Header & Local Search */}
      <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50 flex items-center gap-2">
            <Cpu className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
            <span>Danh sách Phần cứng ESP32 trên Cơ sở dữ liệu</span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Các bo mạch vi điều khiển ESP-WROOM-32 được gán trong các hồ sơ khách hàng tại Firestore.
          </p>
        </div>
        
        <div className="relative w-full md:w-72">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={localSearch}
            onChange={(e) => setLocalSearch(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                setSearch(localSearch);
              } else if (e.key === 'Escape') {
                setLocalSearch('');
                setSearch('');
              }
            }}
            placeholder="Nhập từ khóa và nhấn Enter..."
            className="w-full pl-9 pr-4 py-2 text-xs rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 text-slate-900 dark:text-slate-50 focus:outline-none focus:border-indigo-500 transition-colors shadow-sm"
          />
        </div>
      </div>

      {/* Grid of hardware boards */}
      {filtered.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-16 px-4 text-center bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800/60 shadow-sm">
          <div className="w-16 h-16 mb-4 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
            <Cpu className="w-8 h-8 text-slate-400 dark:text-slate-500" />
          </div>
          <h3 className="text-sm font-bold text-slate-900 dark:text-slate-50 mb-1">
            Thiết bị không tồn tại
          </h3>
          <p className="text-xs text-slate-500 dark:text-slate-400 max-w-sm">
            Không tìm thấy bất kỳ thiết bị ESP32 nào khớp với từ khóa "{search}".
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filtered.map((c, index) => (
            <div
              key={c.id}
              className="rounded-2xl border border-slate-200 dark:border-slate-800/60 bg-white dark:bg-slate-900 p-5 shadow-sm space-y-4 transition-all transform hover:-translate-y-1.5 hover:shadow-lg hover:border-indigo-300 dark:hover:border-indigo-500/60 hover:ring-4 ring-indigo-500/10 cursor-pointer animate-in fade-in zoom-in-95 duration-500 fill-mode-both"
              style={{ animationDelay: `${Math.min(index * 50, 600)}ms` }}
              onClick={() => onSelectCustomer(c)}
            >
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-2.5">
                  <div className="p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-900/20  text-indigo-700 dark:text-indigo-500 ">
                    <Radio className="w-5 h-5 animate-pulse" />
                  </div>
                  <div>
                    <div className="font-mono text-xs font-bold text-slate-900 dark:text-slate-50 ">
                      {c.macAddress}
                    </div>
                    <div className="text-[11px] font-semibold text-indigo-700 dark:text-indigo-500 ">
                      {c.displayName}
                    </div>
                  </div>
                </div>

                {(() => {
                  const hasError = c.crashLogs && c.crashLogs.length > 0;
                  const isOnline = c.sessions && c.sessions.length > 0;
                  
                  if (hasError) {
                    return (
                      <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-rose-100 dark:bg-rose-900/40 text-rose-700 dark:text-rose-400 font-bold border border-rose-200 dark:border-rose-800/50 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>
                        LỖI HỆ THỐNG
                      </span>
                    );
                  }
                  
                  if (isOnline) {
                    return (
                      <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-400 font-bold border border-emerald-200 dark:border-emerald-800/50 flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping"></span>
                        ONLINE
                      </span>
                    );
                  }

                  return (
                    <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 font-bold border border-slate-200 dark:border-slate-700 flex items-center gap-1">
                      <span className="w-1.5 h-1.5 rounded-full bg-slate-400"></span>
                      OFFLINE
                    </span>
                  );
                })()}
              </div>

              <div className="p-3 rounded-xl bg-slate-50 dark:bg-slate-950  border border-slate-200 dark:border-slate-800/60/60  space-y-2 text-xs font-mono">
                <div className="flex justify-between">
                  <span className="font-sans text-slate-500 dark:text-slate-400">Chủ sở hữu:</span>
                  <span className="text-slate-800 dark:text-slate-200 ">{c.displayName}</span>
                </div>
                <div className="flex justify-between">
                  <span className="font-sans text-slate-500 dark:text-slate-400">SĐT xác thực:</span>
                  <span className="text-slate-800 dark:text-slate-200 ">{c.phoneNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span className="font-sans text-slate-500 dark:text-slate-400">Số rơ-le định cấu hình:</span>
                  <strong className="text-indigo-700 dark:text-indigo-500 ">{c.devices.length} rơ-le</strong>
                </div>
                <div className="flex justify-between">
                  <span className="font-sans text-slate-500 dark:text-slate-400">Thiết bị App chạy:</span>
                  <span className="text-slate-800 dark:text-slate-200 ">{c.sessions[0]?.deviceName || 'Chưa mở session'}</span>
                </div>
              </div>

              <div className="pt-2 flex items-center justify-between border-t border-slate-100 dark:border-slate-800 ">
                <button
                  onClick={() => onSelectCustomer(c)}
                  className="text-xs font-semibold text-indigo-700 dark:text-indigo-500  hover:underline"
                >
                  Xem chi tiết khách hàng
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

    </div>
  );
};
