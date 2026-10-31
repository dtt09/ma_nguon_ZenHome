import React, { useState } from 'react';
import { 
  Cpu, 
  Radio, 
  Search, 
  Layers, 
  RotateCcw, 
  Smartphone,
  ExternalLink,
  UploadCloud 
} from 'lucide-react';
import { RealCustomerUser } from '../../types/admin';
import { Esp32OtaModal } from './Esp32OtaModal';

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
  const [isOtaModalOpen, setIsOtaModalOpen] = useState(false);

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
        
        <div className="flex items-center gap-2.5 w-full md:w-auto">
          <button
            onClick={() => setIsOtaModalOpen(true)}
            className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-bold rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-700 hover:from-indigo-700 hover:to-indigo-800 text-white shadow-sm transition-all shrink-0"
          >
            <UploadCloud className="w-4 h-4" />
            <span>Nâng Cấp Firmware (OTA)</span>
          </button>

          <div className="relative w-full md:w-64">
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
                  <div className="p-2.5 rounded-xl bg-indigo-50 dark:bg-indigo-900/20 text-indigo-700 dark:text-indigo-500">
                    <Radio className="w-5 h-5 animate-pulse" />
                  </div>
                  <div>
                    <div className="font-mono text-xs font-bold text-slate-900 dark:text-slate-50">
                      {c.macAddress || 'CHƯA GÁN MAC'}
                    </div>
                    <div className="text-[11px] font-semibold text-indigo-700 dark:text-indigo-500">
                      {c.displayName || c.id}
                    </div>
                  </div>
                </div>

                <span className="px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">
                  ESP32
                </span>
              </div>

              <div className="space-y-1.5 text-xs">
                <div className="flex items-center justify-between text-slate-600 dark:text-slate-300">
                  <span className="font-sans text-slate-500 dark:text-slate-400">Số lượng rơ le:</span>
                  <span className="font-bold text-slate-900 dark:text-slate-100">{c.devices?.length || 0} thiết bị</span>
                </div>
                <div className="flex items-center justify-between text-slate-600 dark:text-slate-300">
                  <span className="font-sans text-slate-500 dark:text-slate-400">Email:</span>
                  <span className="truncate max-w-[160px] text-slate-800 dark:text-slate-200">{c.email}</span>
                </div>
                <div className="flex items-center justify-between text-slate-600 dark:text-slate-300">
                  <span className="font-sans text-slate-500 dark:text-slate-400">Thiết bị App chạy:</span>
                  <span className="text-slate-800 dark:text-slate-200">{c.sessions[0]?.deviceName || 'Chưa mở session'}</span>
                </div>
              </div>

              <div className="pt-2 flex items-center justify-between border-t border-slate-100 dark:border-slate-800">
                <button
                  onClick={() => onSelectCustomer(c)}
                  className="text-xs font-semibold text-indigo-700 dark:text-indigo-500 hover:underline"
                >
                  Xem chi tiết khách hàng
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* ESP32 OTA Modal */}
      <Esp32OtaModal
        isOpen={isOtaModalOpen}
        onClose={() => setIsOtaModalOpen(false)}
        customers={customers}
      />

    </div>
  );
};
