import React, { useState } from 'react';
import { 
  X, 
  User, 
  Cpu, 
  Smartphone, 
  Layers, 
  AlertTriangle, 
  Database, 
  Clock, 
  MapPin, 
  Mail, 
  Phone, 
  ShieldCheck, 
  Copy, 
  ExternalLink,
  Check,
  Trash2
} from 'lucide-react';
import { RealCustomerUser } from '../../types/admin';

interface CustomerDetailModalProps {
  customer: RealCustomerUser | null;
  onClose: () => void;
  onRequestDelete?: (customer: RealCustomerUser) => void;
}

export const CustomerDetailModal: React.FC<CustomerDetailModalProps> = ({
  customer,
  onClose,
  onRequestDelete
}) => {
  if (!customer) return null;

  const [activeSubTab, setActiveSubTab] = useState<'profile' | 'sessions' | 'devices' | 'crashes' | 'raw_db'>('profile');
  const [copiedJson, setCopiedJson] = useState(false);

  const handleCopyJson = () => {
    navigator.clipboard.writeText(JSON.stringify(customer.rawDoc, null, 2));
    setCopiedJson(true);
    setTimeout(() => setCopiedJson(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-in fade-in" onClick={onClose}>
      <div 
        className="w-full max-w-4xl max-h-[90vh] bg-white dark:bg-slate-900  border border-slate-200 dark:border-slate-800/60  rounded-3xl shadow-2xl overflow-hidden flex flex-col animate-in zoom-in-95"
        onClick={(e) => e.stopPropagation()}
      >
        
        {/* Header */}
        <div className="p-6 bg-gradient-to-r from-slate-900 via-slate-800 to-slate-900 text-slate-900 dark:text-slate-50 flex items-center justify-between border-b border-slate-200 dark:border-slate-800/60">
          <div className="flex items-center gap-4">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-tr from-blue-500 to-sky-600 flex items-center justify-center text-slate-900 dark:text-slate-50 text-2xl font-bold border-2 border-blue-400 shadow-md">
              {customer.displayName.charAt(0).toUpperCase()}
            </div>

            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-xl font-bold text-slate-900 dark:text-slate-50">
                  {customer.displayName}
                </h3>
                <span className="text-[10px] font-mono px-2 py-0.5 rounded-full bg-indigo-600 dark:bg-indigo-500/20 text-indigo-700 dark:text-indigo-400 border border-blue-500/30">
                  Document: {customer.id}
                </span>
              </div>

              <div className="flex items-center gap-3 text-xs text-slate-600 dark:text-slate-400 mt-1">
                <span className="font-mono text-blue-400">UID: {customer.uid}</span>
                <span>•</span>
                <span className="flex items-center gap-1">
                  <Mail className="w-3.5 h-3.5 text-slate-500 dark:text-slate-400" />
                  {customer.email}
                </span>
                <span>•</span>
                <span className="flex items-center gap-1">
                  <Phone className="w-3.5 h-3.5 text-slate-500 dark:text-slate-400" />
                  {customer.phoneNumber}
                </span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-2">
            {onRequestDelete && (
              <button
                onClick={() => onRequestDelete(customer)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold bg-rose-500/20 hover:bg-rose-500/30 text-rose-300 border border-rose-500/40 transition-colors"
                title="Xóa tài khoản khách hàng (GDPR)"
              >
                <Trash2 className="w-3.5 h-3.5" />
                <span>Xóa tài khoản</span>
              </button>
            )}

            <button
              onClick={onClose}
              className="p-2 text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-50 dark:text-slate-50 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800/80 dark:bg-slate-800/50 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Sub-tab Navigation */}
        <div className="flex items-center gap-2 px-6 border-b border-slate-200 dark:border-slate-800/60  bg-slate-50 dark:bg-slate-950  overflow-x-auto text-xs font-semibold">
          {[
            { id: 'profile', label: 'Thông tin tài khoản', icon: <User className="w-4 h-4" /> },
            { id: 'sessions', label: `Thiết bị đăng nhập (${customer.sessions.length})`, icon: <Smartphone className="w-4 h-4" /> },
            { id: 'devices', label: `Rơ-le phần cứng (${customer.devices.length})`, icon: <Layers className="w-4 h-4" /> },
            { id: 'crashes', label: `Nhật ký lỗi (${customer.crashLogs.length})`, icon: <AlertTriangle className="w-4 h-4 text-rose-500" /> },
            { id: 'raw_db', label: 'Dữ liệu Firestore (JSON gốc)', icon: <Database className="w-4 h-4" /> },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveSubTab(tab.id as any)}
              className={`py-3.5 px-3 border-b-2 flex items-center gap-1.5 whitespace-nowrap transition-all ${
                activeSubTab === tab.id
                  ? 'border-blue-500 text-indigo-700 dark:text-indigo-500 '
                  : 'border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 dark:text-slate-200 '
              }`}
            >
              {tab.icon}
              <span>{tab.label}</span>
            </button>
          ))}
        </div>

        {/* Modal Scrollable Body */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          
          {/* TAB 1: Profile & Hardware */}
          {activeSubTab === 'profile' && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-950  border border-slate-200 dark:border-slate-800/60  space-y-2.5 text-xs">
                  <h4 className="font-bold text-slate-500 dark:text-slate-400 uppercase text-[11px] mb-2">
                    Thông tin lưu trữ Firestore
                  </h4>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Document ID:</span>
                    <strong className="font-mono text-slate-800 dark:text-slate-200 ">{customer.id}</strong>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Firebase Auth UID:</span>
                    <span className="font-mono text-indigo-700 dark:text-indigo-500 ">{customer.uid}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Họ và Tên:</span>
                    <span className="font-semibold text-slate-800 dark:text-slate-200 ">{customer.displayName}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Email:</span>
                    <span className="font-mono text-slate-700 dark:text-slate-300 ">{customer.email}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Số điện thoại:</span>
                    <span className="font-semibold text-slate-800 dark:text-slate-200 ">{customer.phoneNumber}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Ngày đăng ký tạo:</span>
                    <span className="font-mono text-slate-500 dark:text-slate-400">{customer.createdAt}</span>
                  </div>
                </div>

                <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-950  border border-slate-200 dark:border-slate-800/60  space-y-2.5 text-xs">
                  <h4 className="font-bold text-slate-500 dark:text-slate-400 uppercase text-[11px] mb-2 flex items-center gap-1.5">
                    <Cpu className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                    <span>Mạch phần cứng liên kết</span>
                  </h4>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Địa chỉ MAC:</span>
                    <strong className="font-mono text-indigo-700 dark:text-indigo-500 ">{customer.macAddress}</strong>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Số lượng rơ-le nạp:</span>
                    <span className="font-bold text-slate-800 dark:text-slate-200 ">{customer.devices.length} rơ-le</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-slate-500 dark:text-slate-400">Phiên đăng nhập ứng dụng:</span>
                    <span className="font-bold text-slate-800 dark:text-slate-200 ">{customer.sessions.length} thiết bị</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: Sessions subcollection */}
          {activeSubTab === 'sessions' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase">
                  Dữ liệu thực từ subcollection <code>users/{customer.id}/sessions</code>
                </h4>
              </div>

              {customer.sessions.length === 0 ? (
                <div className="p-8 text-center text-slate-500 dark:text-slate-400 text-xs">
                  Chưa có thiết bị di động nào lưu phiên tại subcollection <code>sessions</code>.
                </div>
              ) : (
                customer.sessions.map((sess) => (
                  <div
                    key={sess.id}
                    className="p-4 rounded-2xl border border-slate-200 dark:border-slate-800/60  bg-slate-50 dark:bg-slate-950/50  space-y-3"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="font-bold text-sm text-slate-900 dark:text-slate-50  flex items-center gap-2 flex-wrap">
                          <Smartphone className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                          <span>{sess.deviceName}</span>
                          <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-indigo-100 dark:bg-indigo-900/40 text-blue-800 font-semibold">
                            {sess.isActive ? 'ĐANG HOẠT ĐỘNG' : 'OFFLINE'}
                          </span>
                          <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-100 dark:bg-emerald-950 text-emerald-700 dark:text-emerald-300 font-bold border border-emerald-300 dark:border-emerald-800">
                            v{sess.appVersion || '1.5.0'} (+{sess.buildNumber || 150})
                          </span>
                        </div>
                        <div className="text-xs text-slate-500 dark:text-slate-400  mt-1 flex items-center gap-2">
                          <span>Hệ điều hành: <strong className="font-mono text-slate-700 dark:text-slate-300 ">{sess.os}</strong></span>
                          <span>•</span>
                          <span className="flex items-center gap-1">
                            <MapPin className="w-3.5 h-3.5 text-slate-500 dark:text-slate-400" />
                            <span>{sess.location}</span>
                          </span>
                        </div>
                      </div>

                      <span className="text-[10px] font-mono text-slate-500 dark:text-slate-400">
                        Doc: {sess.id}
                      </span>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 text-[11px] font-mono text-slate-500 dark:text-slate-400 pt-2 border-t border-slate-200 dark:border-slate-800/60/60 ">
                      <div>Đăng nhập lần đầu: <span className="text-slate-700 dark:text-slate-300 ">{sess.firstSeen}</span></div>
                      <div>Đăng nhập gần nhất: <span className="text-slate-700 dark:text-slate-300 ">{sess.lastLogin}</span></div>
                      <div>Truy cập cuối: <span className="text-indigo-700 dark:text-indigo-500 ">{sess.lastAccess}</span></div>
                    </div>

                    {/* FCM Token */}
                    <div className="p-2.5 rounded-xl bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-400 font-mono text-[11px] border border-slate-200 dark:border-slate-800/60 overflow-x-auto">
                      <span className="text-slate-500 dark:text-slate-400">FCM Token: </span>
                      <span className="text-blue-400">{sess.fcmToken}</span>
                    </div>
                  </div>
                ))
              )}
            </div>
          )}

          {/* TAB 3: Devices array */}
          {activeSubTab === 'devices' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase">
                  Mảng thiết bị thực trong document (<code>devices[]</code>)
                </h4>
              </div>

              {customer.devices.length === 0 ? (
                <div className="p-8 text-center text-slate-500 dark:text-slate-400 text-xs">
                  Document này chưa khai báo mảng <code>devices</code>.
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {customer.devices.map((dev) => (
                    <div
                      key={dev.id}
                      className="p-3.5 rounded-xl border border-slate-200 dark:border-slate-800/60  bg-white dark:bg-slate-900  flex items-center justify-between"
                    >
                      <div>
                        <div className="font-semibold text-xs text-slate-800 dark:text-slate-200 ">
                          {dev.name}
                        </div>
                        <div className="flex items-center gap-2 mt-1 text-[11px] text-slate-500 dark:text-slate-400 font-mono">
                          <span className="bg-slate-100 dark:bg-slate-800/50  px-1.5 py-0.5 rounded">
                            Chân Pin: GPIO {dev.pin}
                          </span>
                          <span>•</span>
                          <span>Loại: {dev.type}</span>
                          <span>•</span>
                          <span>ID: {dev.id}</span>
                        </div>
                      </div>

                      <span className="px-2.5 py-1 rounded-lg text-xs font-mono font-bold bg-slate-100 dark:bg-slate-800/50  text-slate-600 dark:text-slate-400 ">
                        PIN {dev.pin}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* TAB 4: Crash logs */}
          {activeSubTab === 'crashes' && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <h4 className="text-xs font-bold text-slate-500 dark:text-slate-400 uppercase">
                  Nhật ký sự cố thực từ Firestore ({customer.crashLogs.length})
                </h4>
              </div>

              {customer.crashLogs.length === 0 ? (
                <div className="p-8 text-center rounded-2xl bg-indigo-50 dark:bg-indigo-900/20/50  border border-indigo-200 dark:border-indigo-800/50  text-xs text-indigo-700 dark:text-indigo-400 ">
                  <ShieldCheck className="w-8 h-8 mx-auto mb-2 text-indigo-600 dark:text-indigo-400" />
                  <div className="font-bold">Không có báo cáo lỗi nào trên cơ sở dữ liệu Firebase!</div>
                  <div className="text-[11px] text-slate-500 dark:text-slate-400  mt-1">
                    Ứng dụng Dart/Flutter của khách hàng này chưa gặp ngoại lệ hoặc sự cố sập app nào được ghi nhận.
                  </div>
                </div>
              ) : (
                customer.crashLogs.map((crash) => (
                  <div
                    key={crash.id}
                    className="rounded-2xl border border-rose-200  bg-rose-50/30  p-4 space-y-2.5"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <div className="font-bold text-xs text-rose-700  font-mono">
                          {crash.errorTitle}
                        </div>
                        <p className="text-xs text-slate-600 dark:text-slate-400  mt-0.5">
                          {crash.errorMessage}
                        </p>
                      </div>
                      <span className="text-[11px] font-mono text-slate-500 dark:text-slate-400 shrink-0">
                        {crash.timestamp}
                      </span>
                    </div>

                    <div className="rounded-xl bg-slate-50 dark:bg-slate-950 p-3 text-[11px] font-mono text-slate-600 dark:text-slate-400 overflow-x-auto border border-slate-200 dark:border-slate-800/60 max-h-40">
                      <pre>{crash.stackTrace}</pre>
                    </div>
                  </div>
                ))
              )}
            </div>
          )}

          {/* TAB 5: Raw Document JSON directly from Firestore */}
          {activeSubTab === 'raw_db' && (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-xs font-mono text-slate-500 dark:text-slate-400">
                  Đường dẫn: <strong className="text-blue-400">/users/{customer.id}</strong>
                </span>

                <button
                  onClick={handleCopyJson}
                  className="flex items-center gap-1.5 px-3 py-1 text-xs font-semibold rounded-lg bg-slate-100 dark:bg-slate-800/50  text-slate-700 dark:text-slate-300  hover:bg-slate-200 dark:bg-slate-800 transition-colors"
                >
                  <Copy className="w-3.5 h-3.5" />
                  <span>{copiedJson ? 'Đã sao chép!' : 'Sao chép JSON'}</span>
                </button>
              </div>

              <div className="rounded-2xl bg-slate-50 dark:bg-slate-950 p-4 text-xs font-mono text-blue-400 border border-slate-200 dark:border-slate-800/60 overflow-x-auto max-h-96">
                <pre>{JSON.stringify(customer.rawDoc, null, 2)}</pre>
              </div>
            </div>
          )}

        </div>

      </div>
    </div>
  );
};
