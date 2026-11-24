import React, { useState } from 'react';
import { 
  Cpu, 
  Radio, 
  Search, 
  Layers, 
  RotateCcw, 
  Smartphone,
  ExternalLink,
  UploadCloud,
  ShieldCheck,
  ShieldAlert,
  Lock,
  AlertTriangle,
  Zap,
  CheckCircle2
} from 'lucide-react';
import { RealCustomerUser, SystemAlert } from '../../types/admin';
import { Esp32OtaModal } from './Esp32OtaModal';

interface HardwareFleetViewProps {
  customers: RealCustomerUser[];
  onSelectCustomer: (customer: RealCustomerUser) => void;
  alerts?: SystemAlert[];
  onDismissAlert?: (id: string) => void;
}

export const HardwareFleetView: React.FC<HardwareFleetViewProps> = ({
  customers,
  onSelectCustomer,
  alerts = [],
  onDismissAlert
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

  // Fleet cryptographic & hardware trust statistics
  const totalFleet = customers.length;
  const flashEncCount = customers.filter(c => {
    const hw = c.rawDoc?.hw_sec || c.rawDoc?.telemetry?.hw_sec || c.rawDoc?.esp_status?.hw_sec;
    return Boolean(hw?.flashEnc || hw?.flash_enc);
  }).length;

  const secBootCount = customers.filter(c => {
    const hw = c.rawDoc?.hw_sec || c.rawDoc?.telemetry?.hw_sec || c.rawDoc?.esp_status?.hw_sec;
    return Boolean(hw?.secBoot || hw?.sec_boot);
  }).length;

  const mtlsCount = customers.filter(c => {
    const hw = c.rawDoc?.hw_sec || c.rawDoc?.telemetry?.hw_sec || c.rawDoc?.esp_status?.hw_sec;
    return Boolean(hw?.mtls || c.rawDoc?.hasMtls || c.rawDoc?.clientCert || c.rawDoc?.telemetry?.mtls);
  }).length;

  const activeAnomaliesCount = alerts.filter(a => !a.acknowledged).length;

  return (
    <div className="space-y-5">
      
      {/* Header & Local Search */}
      <div className="flex flex-col md:flex-row md:items-start justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50 flex items-center gap-2">
            <Cpu className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
            <span>Quản Lý Đội Tàu Phần Cứng ESP32 & An Toàn Thiết Bị</span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Giám sát trạng thái mã hóa Flash, Secure Boot v2, chứng chỉ mTLS X.509 và cảnh báo Edge Anomaly Detection.
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

      {/* P3: Fleet Cryptographic Trust & Hardware Security KPI Summary */}
      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-5 gap-3">
        <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-slate-400 block tracking-wider">Tổng Bo Mạch</span>
          <div className="text-2xl font-black font-mono text-slate-800 dark:text-slate-100 mt-0.5">{totalFleet}</div>
          <span className="text-[10px] text-slate-500 dark:text-slate-400 font-medium">Hubs trong DB</span>
        </div>

        <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-emerald-600 dark:text-emerald-400 block tracking-wider flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5" /> Flash Encrypted
          </span>
          <div className="text-2xl font-black font-mono text-emerald-600 dark:text-emerald-400 mt-0.5">{flashEncCount}/{totalFleet}</div>
          <span className="text-[10px] text-slate-500 dark:text-slate-400 font-medium">AES-256 eFuse</span>
        </div>

        <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-emerald-600 dark:text-emerald-400 block tracking-wider flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5" /> Secure Boot v2
          </span>
          <div className="text-2xl font-black font-mono text-emerald-600 dark:text-emerald-400 mt-0.5">{secBootCount}/{totalFleet}</div>
          <span className="text-[10px] text-slate-500 dark:text-slate-400 font-medium">Khóa ký số RSA/ECDSA</span>
        </div>

        <div className="p-3.5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 shadow-xs">
          <span className="text-[10px] uppercase font-bold text-sky-600 dark:text-sky-400 block tracking-wider flex items-center gap-1">
            <Lock className="w-3.5 h-3.5" /> mTLS Client Cert
          </span>
          <div className="text-2xl font-black font-mono text-sky-600 dark:text-sky-400 mt-0.5">{mtlsCount}/{totalFleet}</div>
          <span className="text-[10px] text-slate-500 dark:text-slate-400 font-medium">Chứng chỉ 2 chiều X.509</span>
        </div>

        <div className={`p-3.5 rounded-2xl border shadow-xs col-span-2 sm:col-span-1 ${
          activeAnomaliesCount > 0 
            ? 'bg-rose-50 dark:bg-rose-950/40 border-rose-300 dark:border-rose-900' 
            : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800'
        }`}>
          <span className={`text-[10px] uppercase font-bold block tracking-wider flex items-center gap-1 ${
            activeAnomaliesCount > 0 ? 'text-rose-600 dark:text-rose-400' : 'text-slate-400'
          }`}>
            <AlertTriangle className="w-3.5 h-3.5" /> Dị Thường Tiếp Điểm
          </span>
          <div className={`text-2xl font-black font-mono mt-0.5 ${
            activeAnomaliesCount > 0 ? 'text-rose-600 dark:text-rose-400 animate-pulse' : 'text-slate-800 dark:text-slate-100'
          }`}>
            {activeAnomaliesCount}
          </div>
          <span className="text-[10px] text-slate-500 dark:text-slate-400 font-medium">
            {activeAnomaliesCount === 0 ? '0 Chattering Anomaly' : 'Cần xử lý ngay!'}
          </span>
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
          {filtered.map((c, index) => {
            const hwSec = c.rawDoc?.hw_sec || c.rawDoc?.telemetry?.hw_sec || c.rawDoc?.esp_status?.hw_sec;
            const isFlashEnc = Boolean(hwSec?.flashEnc || hwSec?.flash_enc);
            const isSecBoot = Boolean(hwSec?.secBoot || hwSec?.sec_boot);
            const hasMtls = Boolean(hwSec?.mtls || c.rawDoc?.hasMtls || c.rawDoc?.clientCert || c.rawDoc?.telemetry?.mtls);

            // Kiểm tra Hub này có đang gặp sự cố chattering hay anomaly nào không
            const hubAnomalies = alerts.filter(a => 
              (a.mac || '').replace(/[:-]/g, '').toLowerCase() === (c.macAddress || '').replace(/[:-]/g, '').toLowerCase() &&
              !a.acknowledged
            );

            return (
              <div
                key={c.id}
                className={`rounded-2xl border bg-white dark:bg-slate-900 p-5 shadow-sm space-y-4 transition-all transform hover:-translate-y-1.5 hover:shadow-lg cursor-pointer animate-in fade-in zoom-in-95 duration-500 fill-mode-both ${
                  hubAnomalies.length > 0 
                    ? 'border-rose-400 dark:border-rose-700 ring-4 ring-rose-500/10' 
                    : 'border-slate-200 dark:border-slate-800/60 hover:border-indigo-300 dark:hover:border-indigo-500/60 hover:ring-4 ring-indigo-500/10'
                }`}
                style={{ animationDelay: `${Math.min(index * 50, 600)}ms` }}
                onClick={() => onSelectCustomer(c)}
              >
                {/* Header of Board Card */}
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-2.5">
                    <div className={`p-2.5 rounded-xl ${
                      hubAnomalies.length > 0 
                        ? 'bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 animate-bounce' 
                        : 'bg-indigo-50 dark:bg-indigo-900/20 text-indigo-700 dark:text-indigo-500'
                    }`}>
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

                {/* In-Card Anomaly Alert Banner (P3 Edge Anomaly Detection) */}
                {hubAnomalies.length > 0 && (
                  <div className="p-2.5 rounded-xl bg-rose-50 dark:bg-rose-950/60 border border-rose-300 dark:border-rose-800 text-[11px] text-rose-800 dark:text-rose-300 space-y-1">
                    <div className="font-bold flex items-center justify-between">
                      <span className="flex items-center gap-1 text-rose-600 dark:text-rose-400">
                        <AlertTriangle className="w-3.5 h-3.5" />
                        PHÁT HIỆN DỊ THƯỜNG RƠ-LE!
                      </span>
                      {onDismissAlert && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            onDismissAlert(hubAnomalies[0].id);
                          }}
                          className="hover:underline text-[10px] text-slate-500"
                        >
                          Xóa cảnh báo
                        </button>
                      )}
                    </div>
                    <p className="text-[10px]">
                      Rơ-le pin {hubAnomalies[0].pin ?? 'tải'} bị chattering liên tục. Đã kích hoạt LOCKED_OFF 30s.
                    </p>
                  </div>
                )}

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

                {/* Hardware Security Trust Badges (Flash Enc + SecBoot + mTLS) */}
                <div className="pt-2 border-t border-slate-100 dark:border-slate-800/80 flex flex-wrap items-center gap-1.5">
                  {/* 1. Flash Encryption */}
                  {isFlashEnc ? (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-50 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800" title="ESP32 eFuse AES-256 Flash Encryption đã được kích hoạt">
                      <ShieldCheck className="w-3 h-3 text-emerald-500" />
                      Flash Encrypted (AES-256)
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-semibold bg-amber-50 dark:bg-amber-950/50 text-amber-700 dark:text-amber-300 border border-amber-300 dark:border-amber-800" title="Cảnh báo: Flash Encryption chưa bật trên eFuse">
                      <ShieldAlert className="w-3 h-3 text-amber-500" />
                      Flash Unencrypted (Cảnh báo)
                    </span>
                  )}

                  {/* 2. Secure Boot v2 */}
                  {isSecBoot ? (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-emerald-50 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800" title="ESP32 Secure Boot v2 (RSA/ECDSA Signature Verified)">
                      <ShieldCheck className="w-3 h-3 text-emerald-500" />
                      Secure Boot v2 (Verified)
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-semibold bg-amber-50 dark:bg-amber-950/50 text-amber-700 dark:text-amber-300 border border-amber-300 dark:border-amber-800" title="Cảnh báo: Secure Boot v2 chưa kích hoạt">
                      <ShieldAlert className="w-3 h-3 text-amber-500" />
                      Secure Boot v2 (Chưa bật)
                    </span>
                  )}

                  {/* 3. P3: mTLS Client Certificate */}
                  {hasMtls ? (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-sky-50 dark:bg-sky-950/60 text-sky-700 dark:text-sky-300 border border-sky-300 dark:border-sky-800" title="ESP32 mTLS: Chứng chỉ số X.509 Client đã cấp phát">
                      <Lock className="w-3 h-3 text-sky-500" />
                      mTLS Client Cert: Active
                    </span>
                  ) : (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-semibold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border border-slate-300 dark:border-slate-700" title="ESP32 mTLS: Chưa có Client Cert riêng (Chạy Standard 1-way TLS)">
                      <Lock className="w-3 h-3 text-slate-400" />
                      mTLS Client Cert: None
                    </span>
                  )}
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
            );
          })}
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
