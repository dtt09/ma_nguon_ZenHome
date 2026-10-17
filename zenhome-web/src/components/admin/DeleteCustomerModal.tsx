import React, { useState } from 'react';
import { 
  X, 
  Server, 
  Send, 
  CheckCircle2, 
  AlertTriangle, 
  AlertCircle,
  Cpu, 
  Smartphone, 
  Database, 
  Loader2, 
  Radio, 
  ShieldAlert,
  ArrowRight,
  Terminal
} from 'lucide-react';
import { RealCustomerUser } from '../../types/admin';
import { sendDeleteRequestToBackupServer, getBackupServerBaseUrl } from '../../services/backupServerService';

interface DeleteCustomerModalProps {
  customer: RealCustomerUser | null;
  onClose: () => void;
  onCustomerDeleted: (customerId: string, auditLog: string) => void;
}

export const DeleteCustomerModal: React.FC<DeleteCustomerModalProps> = ({
  customer,
  onClose,
  onCustomerDeleted
}) => {
  if (!customer) return null;

  const [confirmInput, setConfirmInput] = useState('');
  const [isSendingCommand, setIsSendingCommand] = useState(false);
  const [commandSent, setCommandSent] = useState(false);
  const [serverLog, setServerLog] = useState<string[]>([]);
  const [serverError, setServerError] = useState<string | null>(null);

  const isConfirmed = 
    confirmInput.trim().toLowerCase() === customer.displayName.trim().toLowerCase() ||
    confirmInput.trim().toLowerCase() === customer.id.trim().toLowerCase() ||
    confirmInput.trim().toUpperCase() === 'XÓA';

  const handleSendCommandToServer = async () => {
    if (!isConfirmed || isSendingCommand) return;

    setIsSendingCommand(true);
    setServerError(null);
    const targetUrl = getBackupServerBaseUrl() || window.location.origin;

    setServerLog([
      `[${new Date().toLocaleTimeString('vi-VN')}] Đang gửi HTTP POST tới Server Backup tại ${targetUrl}/api/backup-server/delete-request...`,
    ]);

    try {
      // Send real HTTP POST to ZenHome Backup Server
      const result = await sendDeleteRequestToBackupServer({
        targetUser: customer.id,
        targetUid: customer.uid,
        macAddress: customer.macAddress,
        reason: 'Quản trị viên yêu cầu xóa tài khoản',
        requester: 'Admin (dtthuat009@gmail.com)'
      });

      setServerLog(prev => [
        ...prev,
        `[${new Date().toLocaleTimeString('vi-VN')}] [HTTP 200 OK] Server Backup đã tiếp nhận! Mã giao dịch: ${result.transactionId}`,
        `[${new Date().toLocaleTimeString('vi-VN')}] Worker startListeningToDeleteRequests() đang tự động:`,
        `   • Gửi Hardware Reset qua MQTT tới ESP32 (${customer.macAddress})`,
        `   • Xóa Auth User bằng Firebase Admin SDK`,
        `   • Batch delete các collection con và document /users/${customer.id}`,
      ]);

      setCommandSent(true);
      setIsSendingCommand(false);

      const auditDetail = `Đã gửi lệnh xóa tài khoản ${customer.displayName} (${customer.id}) lên Server Backup ZenHome (Mã GD: ${result.transactionId}). Hệ thống máy chủ đang tự động dọn dẹp.`;

      setTimeout(() => {
        onCustomerDeleted(customer.id, auditDetail);
      }, 1800);
    } catch (err: any) {
      setIsSendingCommand(false);
      setServerError(`Không thể gửi lệnh lên Server Backup: ${err.message}. Vui lòng kiểm tra tab "Server Backup" để đảm bảo kết nối.`);
      setServerLog(prev => [
        ...prev,
        `[${new Date().toLocaleTimeString('vi-VN')}] [LỖI KẾT NỐI] ${err.message}`,
      ]);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm animate-in fade-in" onClick={!isSendingCommand ? onClose : undefined}>
      <div 
        className="w-full max-w-xl bg-white dark:bg-slate-900  border border-slate-200 dark:border-slate-800/60  rounded-3xl shadow-2xl overflow-hidden animate-in zoom-in-95 flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        
        {/* Modal Header */}
        <div className="p-6 bg-rose-50  border-b border-rose-200  flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-rose-600 text-slate-900 dark:text-slate-50 flex items-center justify-center shadow-lg shadow-rose-600/30 shrink-0">
              <Server className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-base text-rose-900 ">
                Gửi lệnh Xóa tài khoản lên Server Backup ZenHome
              </h3>
              <p className="text-xs text-rose-700  mt-0.5">
                Chỉ cần gửi lệnh lên Server Backup, toàn bộ quy trình xóa và reset thiết bị do hệ thống tự động xử lý.
              </p>
            </div>
          </div>

          {!isSendingCommand && (
            <button 
              onClick={onClose}
              className="p-2 text-slate-500 dark:text-slate-400 hover:text-slate-600 dark:text-slate-400  rounded-xl"
            >
              <X className="w-5 h-5" />
            </button>
          )}
        </div>

        {/* Modal Body */}
        <div className="p-6 space-y-5 flex-1 overflow-y-auto">
          
          {/* Target Customer Info */}
          <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-950  border border-slate-200 dark:border-slate-800/60  flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-500 to-sky-600 flex items-center justify-center text-slate-900 dark:text-slate-50 font-bold text-base">
                {customer.displayName.charAt(0).toUpperCase()}
              </div>
              <div>
                <div className="font-bold text-sm text-slate-900 dark:text-slate-50  flex items-center gap-1.5">
                  <span>{customer.displayName}</span>
                  <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-slate-200 dark:bg-slate-800  text-slate-600 dark:text-slate-400 ">
                    ID: {customer.id}
                  </span>
                </div>
                <div className="text-xs text-slate-500 dark:text-slate-400 font-mono">
                  {customer.email} • {customer.phoneNumber}
                </div>
              </div>
            </div>

            <div className="text-right font-mono text-xs">
              <div className="font-bold text-slate-700 dark:text-slate-300 ">
                MAC: {customer.macAddress}
              </div>
              <div className="text-[11px] text-slate-500 dark:text-slate-400">
                UID: {customer.uid.substring(0, 10)}...
              </div>
            </div>
          </div>

          {/* System Deletion Flow Architecture Explanation */}
          <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-950  border border-slate-200 dark:border-slate-800/60  space-y-2 text-xs">
            <div className="font-bold text-slate-700 dark:text-slate-300  flex items-center gap-2">
              <Terminal className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
              <span>Cơ chế Xóa Tự động của Server Backup (Mục 3.4 STEM Report):</span>
            </div>
            <p className="text-slate-500 dark:text-slate-400  leading-relaxed text-[11px]">
              Ứng dụng web phát lệnh HTTP POST trực tiếp lên Máy chủ Backup. Worker Background Observer <code className="text-indigo-600 dark:text-indigo-400 font-bold">startListeningToDeleteRequests()</code> trên Server sẽ tiếp nhận và tự động thực thi:
            </p>
            <ul className="space-y-1.5 text-[11px] text-slate-600 dark:text-slate-400  pl-4 list-disc">
              <li>
                <strong>1. Gửi Hardware Reset:</strong> Bắn lệnh Reset xuống mạch vi điều khiển ESP32 ({customer.macAddress}) để xóa cấu hình và ngắt liên kết.
              </li>
              <li>
                <strong>2. Xóa Auth User:</strong> Dùng Firebase Admin SDK trên Server Backup để hủy tài khoản xác thực.
              </li>
              <li>
                <strong>3. Garbage Collector Firestore:</strong> Duyệt đệ quy (Batch delete) xóa sạch toàn bộ subcollections và document người dùng.
              </li>
            </ul>
          </div>

          {/* Error Message if connection fails */}
          {serverError && (
            <div className="p-3.5 rounded-xl bg-rose-50  border border-rose-300  text-rose-700  text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-500 shrink-0" />
              <span>{serverError}</span>
            </div>
          )}

          {/* Live Dispatch Logs */}
          {serverLog.length > 0 && (
            <div className="space-y-1.5">
              <div className="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider font-mono">
                Nhật ký truyền lệnh Server:
              </div>
              <div className="p-3.5 rounded-xl bg-slate-50 dark:bg-slate-950 font-mono text-xs text-blue-400 border border-slate-200 dark:border-slate-800/60 space-y-1 max-h-36 overflow-y-auto">
                {serverLog.map((log, idx) => (
                  <div key={idx}>{log}</div>
                ))}
              </div>
            </div>
          )}

          {/* Confirmation Input Guard if not sent */}
          {!commandSent && !isSendingCommand && (
            <div className="p-4 rounded-2xl bg-rose-50/50  border border-rose-200  space-y-2">
              <label className="block text-xs font-bold text-rose-900 ">
                Để kích hoạt lệnh gửi lên Server Backup, vui lòng nhập "<span className="text-rose-600  select-all font-mono">{customer.displayName}</span>" hoặc "<span className="text-rose-600  select-all font-mono">XÓA</span>":
              </label>
              <input
                type="text"
                value={confirmInput}
                onChange={(e) => setConfirmInput(e.target.value)}
                placeholder={`Nhập ${customer.displayName} hoặc XÓA để xác nhận`}
                className="w-full px-3.5 py-2 text-xs rounded-xl border border-rose-300  bg-white dark:bg-slate-900  text-slate-900 dark:text-slate-50  placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-rose-500 font-medium"
              />
            </div>
          )}

          {commandSent && (
            <div className="p-3.5 rounded-xl bg-indigo-50 dark:bg-indigo-900/20  border border-blue-300  text-blue-800  text-xs font-semibold animate-in fade-in flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-indigo-600 dark:text-indigo-400 shrink-0" />
              <span>Đã gửi lệnh lên Server Backup thành công! Hệ thống máy chủ đang tự động thực hiện quy trình xóa.</span>
            </div>
          )}

        </div>

        {/* Modal Footer */}
        {!commandSent && (
          <div className="p-5 border-t border-slate-100 dark:border-slate-800  flex items-center justify-between">
            <button
              type="button"
              onClick={onClose}
              disabled={isSendingCommand}
              className="px-4 py-2 text-xs font-semibold text-slate-500 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 dark:text-slate-200  rounded-xl transition-colors"
            >
              Hủy bỏ
            </button>

            <button
              type="button"
              onClick={handleSendCommandToServer}
              disabled={!isConfirmed || isSendingCommand}
              className={`px-5 py-2.5 rounded-xl text-xs font-bold flex items-center gap-2 transition-all ${
                isConfirmed && !isSendingCommand
                  ? 'bg-rose-600 hover:bg-rose-500 text-white shadow-lg shadow-rose-600/30'
                  : 'bg-slate-200 dark:bg-slate-800  text-slate-500 dark:text-slate-400 cursor-not-allowed'
              }`}
            >
              {isSendingCommand ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Đang gửi lệnh tới Server...</span>
                </>
              ) : (
                <>
                  <Send className="w-4 h-4" />
                  <span>Gửi lệnh Xóa lên Server Backup</span>
                </>
              )}
            </button>
          </div>
        )}

      </div>
    </div>
  );
};
