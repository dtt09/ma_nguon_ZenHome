import React, { useState } from 'react';
import { 
  Users, 
  Search, 
  Cpu, 
  ChevronRight, 
  Smartphone, 
  Zap, 
  CheckCircle2, 
  Trash2,
  Clock,
  MapPin,
  ShieldCheck,
  Radio
} from 'lucide-react';
import { RealCustomerUser } from '../../types/admin';

interface CustomerListProps {
  customers: RealCustomerUser[];
  onSelectCustomer: (customer: RealCustomerUser) => void;
  onDeleteCustomer: (customer: RealCustomerUser) => void;
  searchQuery: string;
  isLoading: boolean;
}

export const CustomerList: React.FC<CustomerListProps> = ({
  customers,
  onSelectCustomer,
  onDeleteCustomer,
  searchQuery,
  isLoading
}) => {
  const [filter, setFilter] = useState<'all' | 'has_session' | 'has_mac'>('all');

  const filtered = customers.filter(c => {
    const matchesSearch = 
      (c.displayName || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (c.email || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (c.phoneNumber || '').includes(searchQuery) ||
      (c.macAddress || '').toLowerCase().includes(searchQuery.toLowerCase()) ||
      (c.id || '').toLowerCase().includes(searchQuery.toLowerCase());

    if (!matchesSearch) return false;

    if (filter === 'has_session') return c.sessions.length > 0;
    if (filter === 'has_mac') return c.macAddress && c.macAddress !== 'Chưa liên kết';

    return true;
  });

  return (
    <div className="space-y-4">
      
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50  flex items-center gap-2">
            <Users className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
            <span>Khách hàng thực tế trên Firebase Firestore</span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400  mt-0.5">
            Dữ liệu trực tiếp từ collection <code>/users</code> và subcollection <code>/sessions</code> trên Cloud Firestore (smarthome-98dd7).
          </p>
        </div>

        {/* Filter Badges */}
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
          {[
            { id: 'all', label: `Tất cả (${customers.length})` },
            { id: 'has_session', label: `Đang có phiên App (${customers.filter(c => c.sessions.length > 0).length})` },
            { id: 'has_mac', label: `Đã liên kết ESP32 (${customers.filter(c => c.macAddress && c.macAddress !== 'Chưa liên kết').length})` },
          ].map(f => (
            <button
              key={f.id}
              onClick={() => setFilter(f.id as any)}
              className={`px-3 py-1.5 rounded-xl text-xs font-semibold whitespace-nowrap transition-colors ${
                filter === f.id
                  ? 'bg-white dark:bg-slate-900  text-slate-900 dark:text-slate-50 shadow-sm'
                  : 'bg-white dark:bg-slate-900  text-slate-600 dark:text-slate-400  hover:bg-slate-100 dark:hover:bg-slate-800/80 dark:bg-slate-800/50  border border-slate-200 dark:border-slate-800/60 '
              }`}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* Real Customers Table */}
      <div className="rounded-2xl border border-slate-200 dark:border-slate-800/60  bg-white dark:bg-slate-900  shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-200 dark:border-slate-800/60  bg-slate-50 dark:bg-slate-950  text-slate-500 dark:text-slate-400 font-semibold uppercase text-[11px]">
                <th className="py-3.5 px-4">Document ID / Họ tên</th>
                <th className="py-3.5 px-4">Số điện thoại & Email</th>
                <th className="py-3.5 px-4">Mã phần cứng ESP32</th>
                <th className="py-3.5 px-4">Thiết bị App (Từ subcollection)</th>
                <th className="py-3.5 px-4">Số rơ-le</th>
                <th className="py-3.5 px-4">Ngày tạo trên DB</th>
                <th className="py-3.5 px-4 text-right">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-800/60 ">
              {filtered.map((customer, index) => {
                const primarySession = customer.sessions[0];

                return (
                  <tr 
                    key={customer.id}
                    onClick={() => onSelectCustomer(customer)}
                    className="hover:bg-slate-50 dark:hover:bg-slate-800/50 dark:bg-slate-950/80 cursor-pointer transition-colors group animate-in fade-in slide-in-from-bottom-2 duration-300 fill-mode-both"
                    style={{ animationDelay: `${Math.min(index * 30, 500)}ms` }}
                  >
                    
                    {/* Name & ID */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-blue-500 to-sky-600 flex items-center justify-center text-slate-900 dark:text-slate-50 font-bold text-sm shadow-sm shrink-0">
                          {customer.displayName.charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <div className="font-bold text-slate-900 dark:text-slate-50  group-hover:text-indigo-600 dark:text-indigo-400 transition-colors flex items-center gap-1.5">
                            <span>{customer.displayName}</span>
                            <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-slate-100 dark:bg-slate-800/50  text-slate-500 dark:text-slate-400">
                              {customer.id}
                            </span>
                          </div>
                          <div className="text-[11px] text-slate-500 dark:text-slate-400 font-mono">
                            UID: {customer.uid.substring(0, 14)}...
                          </div>
                        </div>
                      </div>
                    </td>

                    {/* Phone & Email */}
                    <td className="py-3.5 px-4">
                      <div className="font-semibold text-slate-800 dark:text-slate-200 ">
                        {customer.phoneNumber}
                      </div>
                      <div className="text-[11px] text-slate-500 dark:text-slate-400 font-mono">
                        {customer.email}
                      </div>
                    </td>

                    {/* MAC Address */}
                    <td className="py-3.5 px-4">
                      <div className="flex items-center gap-1.5 font-mono text-[11px]">
                        <span className="w-2 h-2 rounded-full bg-indigo-600 dark:bg-indigo-500" />
                        <span className="font-bold text-indigo-700 dark:text-indigo-500 ">
                          {customer.macAddress}
                        </span>
                      </div>
                      <div className="text-[10px] text-slate-500 dark:text-slate-400">
                        ESP32 Microcontroller
                      </div>
                    </td>

                    {/* Mobile Client App (From Sessions subcollection) */}
                    <td className="py-3.5 px-4">
                      {primarySession ? (
                        <div>
                          <div className="flex items-center gap-1.5 text-[11px] font-semibold text-slate-800 dark:text-slate-200">
                            <span className="relative flex h-2 w-2">
                              {customer.crashLogs && customer.crashLogs.length > 0 ? (
                                <span className="absolute inline-flex h-full w-full rounded-full bg-rose-400 opacity-75 animate-pulse"></span>
                              ) : (
                                <span className="absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75 animate-ping"></span>
                              )}
                              <span className={`relative inline-flex rounded-full h-2 w-2 ${customer.crashLogs && customer.crashLogs.length > 0 ? 'bg-rose-500' : 'bg-emerald-500'}`}></span>
                            </span>
                            <Smartphone className="w-3.5 h-3.5 text-sky-500 shrink-0" />
                            <span>{primarySession.deviceName}</span>
                          </div>
                          <div className="text-[10px] text-slate-500 dark:text-slate-400 flex items-center gap-1 mt-0.5 ml-3.5">
                            <span>{primarySession.os}</span>
                            <span>•</span>
                            <span className="text-indigo-600 dark:text-indigo-400">{primarySession.location}</span>
                          </div>
                        </div>
                      ) : (
                        <div className="flex items-center gap-1.5 text-[11px]">
                          <span className="h-2 w-2 rounded-full bg-slate-300 dark:bg-slate-600"></span>
                          <span className="text-slate-500 dark:text-slate-400 italic">OFFLINE (Chưa kết nối)</span>
                        </div>
                      )}
                    </td>

                    {/* Devices list count */}
                    <td className="py-3.5 px-4">
                      <div className="font-bold text-xs text-slate-800 dark:text-slate-200 ">
                        {customer.devices.length} rơ-le
                      </div>
                      <div className="text-[10px] text-slate-500 dark:text-slate-400 truncate max-w-[140px]">
                        {customer.devices.map(d => d.name).join(', ')}
                      </div>
                    </td>

                    {/* CreatedAt on Firebase */}
                    <td className="py-3.5 px-4 font-mono text-[11px] text-slate-500 dark:text-slate-400 ">
                      {customer.createdAt}
                    </td>

                    {/* Actions: View detail & Delete button */}
                    <td className="py-3.5 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5" onClick={(e) => e.stopPropagation()}>
                        <button
                          onClick={() => onDeleteCustomer(customer)}
                          className="p-1.5 rounded-lg text-slate-500 dark:text-slate-400 hover:text-rose-600 hover:bg-rose-50  transition-colors"
                          title="Xóa tài khoản khách hàng (GDPR)"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>

                        <button
                          onClick={() => onSelectCustomer(customer)}
                          className="p-1.5 rounded-lg text-slate-500 dark:text-slate-400 hover:text-indigo-600 dark:text-indigo-400 hover:bg-slate-100 dark:hover:bg-slate-800/80 dark:bg-slate-800/50  transition-colors"
                          title="Xem chi tiết"
                        >
                          <ChevronRight className="w-4 h-4" />
                        </button>
                      </div>
                    </td>

                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {isLoading && (
          <div className="py-12 text-center text-xs text-slate-500 dark:text-slate-400 flex items-center justify-center gap-2">
            <span className="w-3.5 h-3.5 border-2 border-blue-500 border-t-transparent rounded-full animate-spin" />
            <span>Đang tải dữ liệu thực từ Cloud Firestore...</span>
          </div>
        )}

        {!isLoading && filtered.length === 0 && (
          <div className="flex flex-col items-center justify-center py-16 px-4 text-center">
            <div className="w-16 h-16 mb-4 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center">
              <Search className="w-8 h-8 text-slate-400 dark:text-slate-500" />
            </div>
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-50 mb-1">
              Tài khoản không tồn tại
            </h3>
            <p className="text-xs text-slate-500 dark:text-slate-400 max-w-sm">
              Không tìm thấy bất kỳ bản ghi khách hàng nào khớp với từ khóa "{searchQuery}" trên cơ sở dữ liệu Firebase. Vui lòng thử lại với tên, email hoặc SĐT khác.
            </p>
          </div>
        )}
      </div>

    </div>
  );
};
