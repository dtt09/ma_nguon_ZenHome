import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  KeyRound,
  Fingerprint,
  Smartphone,
  Laptop,
  ShieldCheck,
  Plus,
  Trash2,
  Edit2,
  Check,
  X,
  AlertCircle,
  Sparkles,
  CloudCheck,
  RefreshCw,
  Info
} from 'lucide-react';
import {
  PasskeyItem,
  getRegisteredPasskeys,
  registerCurrentDevicePasskey,
  deletePasskeyById,
  renamePasskeyById,
  checkPasskeySupport,
} from '../../services/passkeyService';

interface PasskeyManagerModalProps {
  isOpen: boolean;
  onClose: () => void;
  onShowToast?: (msg: string) => void;
}

export const PasskeyManagerModal: React.FC<PasskeyManagerModalProps> = ({
  isOpen,
  onClose,
  onShowToast,
}) => {
  const [passkeys, setPasskeys] = useState<PasskeyItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isRegistering, setIsRegistering] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingName, setEditingName] = useState('');
  const [newDeviceName, setNewDeviceName] = useState('');
  const [showAddForm, setShowAddForm] = useState(false);
  const [browserSupport, setBrowserSupport] = useState({ supported: true, hasPlatformAuthenticator: true });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const fetchPasskeys = async () => {
    setIsLoading(true);
    setErrorMessage(null);
    try {
      const list = await getRegisteredPasskeys();
      setPasskeys(list);
    } catch (e: any) {
      setErrorMessage('Không thể tải danh sách Passkey: ' + e.message);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      fetchPasskeys();
      checkPasskeySupport().then(setBrowserSupport);
    }
  }, [isOpen]);

  const [targetType, setTargetType] = useState<'platform' | 'cross-platform'>('cross-platform');

  const handleRegisterNew = async (forcedType?: 'platform' | 'cross-platform') => {
    const type = forcedType || targetType;
    setIsRegistering(true);
    setErrorMessage(null);
    try {
      const defaultName = type === 'cross-platform' ? 'Điện thoại (Face ID / Vân tay)' : undefined;
      const res = await registerCurrentDevicePasskey(newDeviceName.trim() || defaultName, type);
      if (res.success) {
        if (onShowToast) onShowToast(res.message || '✅ Đăng ký Passkey thành công!');
        setNewDeviceName('');
        setShowAddForm(false);
        await fetchPasskeys();
      } else {
        setErrorMessage(res.error || 'Đăng ký Passkey không thành công.');
      }
    } catch (e: any) {
      setErrorMessage(e.message || 'Lỗi khi kích hoạt thiết bị Passkey.');
    } finally {
      setIsRegistering(false);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!window.confirm(`Bạn có chắc chắn muốn hủy liên kết Passkey "${name}"?`)) return;
    try {
      const ok = await deletePasskeyById(id);
      if (ok) {
        if (onShowToast) onShowToast(`🗑️ Đã xóa Passkey "${name}"`);
        await fetchPasskeys();
      } else {
        alert('Không thể xóa Passkey. Vui lòng thử lại.');
      }
    } catch (e: any) {
      alert('Lỗi: ' + e.message);
    }
  };

  const handleSaveRename = async (id: string) => {
    if (!editingName.trim()) return;
    try {
      const ok = await renamePasskeyById(id, editingName.trim());
      if (ok) {
        setEditingId(null);
        await fetchPasskeys();
        if (onShowToast) onShowToast('Đã đổi tên thiết bị thành công');
      }
    } catch (e: any) {
      alert('Lỗi khi đổi tên: ' + e.message);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-in fade-in duration-200">
      <motion.div
        initial={{ opacity: 0, scale: 0.95, y: 15 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 15 }}
        transition={{ type: 'spring', stiffness: 450, damping: 30 }}
        className="w-full max-w-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
      >
        {/* Header */}
        <div className="p-6 border-b border-slate-200 dark:border-slate-800 bg-gradient-to-r from-teal-500/10 via-emerald-500/5 to-transparent flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-2xl bg-teal-500/10 dark:bg-teal-500/20 text-teal-600 dark:text-teal-400 flex items-center justify-center shadow-inner">
              <Fingerprint className="w-6 h-6" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                <span>Quản Lý Xác Thực Passkey</span>
                <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-teal-100 text-teal-800 dark:bg-teal-950 dark:text-teal-300 border border-teal-200 dark:border-teal-800">
                  FIDO2 / W3C
                </span>
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                Đăng nhập một chạm bằng Vân tay, Face ID, Windows Hello hoặc Khóa bảo mật phần cứng
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-xl text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Body Content */}
        <div className="p-6 overflow-y-auto space-y-5 scrollbar-thin">
          {/* Security Banner */}
          <div className="p-4 rounded-2xl bg-teal-50 dark:bg-teal-950/40 border border-teal-200 dark:border-teal-800/60 text-xs text-teal-900 dark:text-teal-200 space-y-1.5">
            <div className="font-bold flex items-center gap-1.5 text-teal-700 dark:text-teal-300">
              <ShieldCheck className="w-4 h-4 shrink-0" />
              <span>Tiêu chuẩn bảo mật hiện đại không cần mật khẩu</span>
            </div>
            <p className="leading-relaxed opacity-90">
              Khóa riêng tư (Private Key) được lưu mã hóa an toàn tuyệt đối trong chip TPM / Secure Enclave của máy bạn và không bao giờ rời khỏi thiết bị. Miễn nhiễm 100% với các cuộc tấn công lừa đảo (Phishing) hay lộ lọt mật khẩu.
            </p>
          </div>

          {/* Browser compatibility check */}
          {!browserSupport.supported && (
            <div className="p-3.5 rounded-xl bg-amber-50 dark:bg-amber-950/40 border border-amber-200 dark:border-amber-800 text-xs text-amber-800 dark:text-amber-300 flex items-start gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span>
                Trình duyệt của bạn có thể chưa bật hỗ trợ WebAuthn. Hãy cập nhật Chrome, Edge, Safari phiên bản mới nhất hoặc bật Windows Hello trong cài đặt máy tính.
              </span>
            </div>
          )}

          {/* Error Message */}
          {errorMessage && (
            <div className="p-3.5 rounded-xl bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-800 text-xs text-rose-700 dark:text-rose-300 flex items-start gap-2">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span className="flex-1">{errorMessage}</span>
            </div>
          )}

          {/* Add Passkey Actions: Phone (QR Code) & PC */}
          <div className="space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {/* Nút 1: Đăng ký Passkey từ Điện thoại */}
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => handleRegisterNew('cross-platform')}
                disabled={isRegistering}
                className="p-4 rounded-2xl border-2 border-dashed border-indigo-500/50 hover:border-indigo-500 bg-gradient-to-br from-indigo-500/10 via-purple-500/5 to-transparent text-left flex flex-col justify-between gap-3 transition shadow-xs disabled:opacity-50"
              >
                <div className="flex items-center justify-between">
                  <div className="p-2.5 rounded-xl bg-indigo-500/20 text-indigo-600 dark:text-indigo-400">
                    <Smartphone className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-indigo-100 dark:bg-indigo-950 text-indigo-700 dark:text-indigo-300 border border-indigo-300 dark:border-indigo-800">
                    Mã QR Sinh trắc học
                  </span>
                </div>
                <div>
                  <h4 className="font-bold text-xs text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                    <span>📱 Dùng Điện Thoại (Quét QR)</span>
                  </h4>
                  <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">
                    Dùng iPhone / Android quét mã QR trên màn hình. Mở khóa máy tính bằng Face ID hoặc Vân tay trên điện thoại.
                  </p>
                </div>
              </motion.button>

              {/* Nút 2: Đăng ký Passkey máy tính hiện tại */}
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => handleRegisterNew('platform')}
                disabled={isRegistering}
                className="p-4 rounded-2xl border-2 border-dashed border-teal-500/50 hover:border-teal-500 bg-gradient-to-br from-teal-500/10 via-emerald-500/5 to-transparent text-left flex flex-col justify-between gap-3 transition shadow-xs disabled:opacity-50"
              >
                <div className="flex items-center justify-between">
                  <div className="p-2.5 rounded-xl bg-teal-500/20 text-teal-600 dark:text-teal-400">
                    <Laptop className="w-5 h-5" />
                  </div>
                  <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-100 dark:bg-teal-950 text-teal-700 dark:text-teal-300 border border-teal-300 dark:border-teal-800">
                    Windows Hello / Mac
                  </span>
                </div>
                <div>
                  <h4 className="font-bold text-xs text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                    <span>💻 Dùng Máy Tính Này</span>
                  </h4>
                  <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 leading-relaxed">
                    Lưu Passkey trực tiếp vào chip bảo mật TPM của máy tính để chạm vân tay trên bàn phím hoặc nhận diện khuôn mặt.
                  </p>
                </div>
              </motion.button>
            </div>

            {/* Hướng dẫn chi tiết cách kết nối điện thoại */}
            <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-800 text-[11px] text-slate-600 dark:text-slate-300 space-y-1.5">
              <div className="font-bold text-indigo-600 dark:text-indigo-400 flex items-center gap-1">
                <span>⚡ 3 Bước dùng điện thoại làm Passkey cho máy tính:</span>
              </div>
              <ol className="list-decimal list-inside space-y-1 pl-1 opacity-90 text-[11px] leading-relaxed">
                <li>Bấm nút <b>"Dùng Điện Thoại (Quét QR)"</b> ở trên. Trình duyệt máy tính sẽ hiện cửa sổ mã QR.</li>
                <li>Mở ứng dụng <b>Camera</b> trên iPhone hoặc điện thoại Android, đưa ống kính hướng vào mã QR.</li>
                <li>Chạm xác nhận <b>Face ID</b> hoặc <b>Vân tay</b> trên điện thoại. Hai thiết bị sẽ tự động liên kết an toàn qua Bluetooth!</li>
              </ol>
            </div>
          </div>

          {/* List of Registered Passkeys */}
          <div className="space-y-2.5">
            <div className="flex items-center justify-between text-xs font-bold text-slate-700 dark:text-slate-300">
              <span className="flex items-center gap-1.5">
                <KeyRound className="w-3.5 h-3.5 text-slate-400" />
                DANH SÁCH THIẾT BỊ ĐÃ LIÊN KẾT ({passkeys.length})
              </span>
              <button
                onClick={fetchPasskeys}
                disabled={isLoading}
                className="text-slate-400 hover:text-teal-600 dark:hover:text-teal-400 p-1"
                title="Làm mới danh sách"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
              </button>
            </div>

            {passkeys.length === 0 && !isLoading && (
              <div className="p-8 text-center rounded-2xl border border-dashed border-slate-300 dark:border-slate-700 text-xs text-slate-500 space-y-2">
                <Fingerprint className="w-8 h-8 text-slate-300 dark:text-slate-600 mx-auto" />
                <p className="font-semibold text-slate-700 dark:text-slate-300">
                  Chưa có Passkey nào được đăng ký
                </p>
                <p className="text-[11px] text-slate-400 max-w-xs mx-auto">
                  Hãy nhấn vào nút thêm ở trên để liên kết vân tay máy tính hoặc điện thoại của bạn ngay hôm nay.
                </p>
              </div>
            )}

            <div className="space-y-2">
              {passkeys.map((p) => {
                const isEditing = editingId === p.id;
                return (
                  <div
                    key={p.id}
                    className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-800 flex items-center justify-between gap-3 text-xs hover:border-slate-300 dark:hover:border-slate-700 transition"
                  >
                    <div className="flex items-center gap-3 min-w-0 flex-1">
                      <div className="p-2.5 rounded-xl bg-teal-50 dark:bg-teal-950/60 text-teal-600 dark:text-teal-400 shrink-0">
                        {p.name.toLowerCase().includes('phone') || p.name.toLowerCase().includes('iphone') ? (
                          <Smartphone className="w-4 h-4" />
                        ) : (
                          <Laptop className="w-4 h-4" />
                        )}
                      </div>

                      <div className="min-w-0 flex-1">
                        {isEditing ? (
                          <div className="flex items-center gap-1.5">
                            <input
                              type="text"
                              value={editingName}
                              onChange={(e) => setEditingName(e.target.value)}
                              className="px-2 py-1 text-xs rounded-lg bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 outline-none focus:ring-1 focus:ring-teal-500 w-full"
                              autoFocus
                            />
                            <button
                              onClick={() => handleSaveRename(p.id)}
                              className="p-1 rounded-lg text-emerald-600 hover:bg-emerald-50 dark:hover:bg-emerald-950/50"
                            >
                              <Check className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => setEditingId(null)}
                              className="p-1 rounded-lg text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700"
                            >
                              <X className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        ) : (
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-bold text-slate-900 dark:text-slate-100 truncate">
                              {p.name}
                            </span>
                            {p.backedUp && (
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-medium bg-indigo-50 text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800">
                                <CloudCheck className="w-3 h-3" />
                                Cloud Passkey
                              </span>
                            )}
                          </div>
                        )}

                        <div className="text-[11px] text-slate-400 flex items-center gap-2 mt-0.5">
                          <span>
                            Dùng gần nhất: {p.lastUsedAt ? new Date(p.lastUsedAt).toLocaleDateString('vi-VN') : 'Mới tạo'}
                          </span>
                          <span>•</span>
                          <span className="font-mono text-[10px]">
                            ID: {p.id.slice(0, 8)}...
                          </span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      {!isEditing && (
                        <button
                          onClick={() => {
                            setEditingId(p.id);
                            setEditingName(p.name);
                          }}
                          className="p-1.5 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-200 dark:hover:bg-slate-700 transition"
                          title="Đổi tên thiết bị"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                      <button
                        onClick={() => handleDelete(p.id, p.name)}
                        className="p-1.5 rounded-lg text-slate-400 hover:text-rose-600 dark:hover:text-rose-400 hover:bg-rose-50 dark:hover:bg-rose-950/40 transition"
                        title="Hủy liên kết Passkey này"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950/50 flex items-center justify-between text-xs text-slate-500">
          <span className="flex items-center gap-1.5 text-[11px]">
            <Info className="w-3.5 h-3.5 text-slate-400" />
            Khóa Master Secret vẫn luôn có hiệu lực dự phòng khẩn cấp
          </span>
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-semibold bg-slate-200 hover:bg-slate-300 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-800 dark:text-slate-200 transition"
          >
            Đóng
          </button>
        </div>
      </motion.div>
    </div>
  );
};
