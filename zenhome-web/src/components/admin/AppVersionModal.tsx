import React, { useState, useEffect } from 'react';
import { 
  Smartphone, 
  X, 
  UploadCloud, 
  CheckCircle2, 
  AlertCircle, 
  Sparkles, 
  ShieldAlert, 
  RefreshCw,
  ExternalLink,
  Layers
} from 'lucide-react';
import { fetchAppVersionInfo, updateAppVersionInfo } from '../../services/backupServerService';

interface AppVersionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccessNotification?: (msg: string) => void;
}

export const AppVersionModal: React.FC<AppVersionModalProps> = ({
  isOpen,
  onClose,
  onSuccessNotification
}) => {
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    latestVersion: '1.4.0',
    latestBuildNumber: 140,
    minVersion: '1.3.0',
    minBuildNumber: 10,
    titleVi: 'Bản Cập Nhật ZenHome Mới',
    titleEn: 'New ZenHome Update',
    releaseNotesVi: '• Đồng bộ dữ liệu Cloud Firestore thời gian thực 100%\n• Tăng tốc đăng nhập mượt mà, loại bỏ độ trễ sau khi hoàn tất\n• Tích hợp cơ chế kiểm tra và cập nhật phiên bản OTA\n• Nâng cấp giao diện RESTful API & Swagger UI Dark Mode',
    releaseNotesEn: '• 100% Realtime Firestore synchronization\n• Superfast login flow without delay\n• In-app OTA version update checker\n• Revamped RESTful API & Swagger UI',
    downloadUrl: 'https://github.com/dtthuat/zenhome/releases/latest',
    directApkUrl: typeof window !== 'undefined'
      ? `${window.location.origin}/public/downloads/zenhome-app-release.apk`
      : '/public/downloads/zenhome-app-release.apk',
    isForceUpdate: false,
    publishedAt: '',
  });

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchAppVersionInfo();
      if (data) {
        setFormData({
          latestVersion: data.latestVersion || '1.4.0',
          latestBuildNumber: Number(data.latestBuildNumber) || 140,
          minVersion: data.minVersion || '1.3.0',
          minBuildNumber: Number(data.minBuildNumber) || 10,
          titleVi: data.titleVi || 'Bản Cập Nhật ZenHome Mới',
          titleEn: data.titleEn || 'New ZenHome Update',
          releaseNotesVi: data.releaseNotesVi || '',
          releaseNotesEn: data.releaseNotesEn || '',
          downloadUrl: data.downloadUrl || 'https://github.com/dtthuat/zenhome/releases/latest',
          directApkUrl: data.directApkUrl || '/public/downloads/zenhome-app-release.apk',
          isForceUpdate: Boolean(data.isForceUpdate),
          publishedAt: data.publishedAt || '',
        });
      }
    } catch (err: any) {
      setError(err.message || 'Không thể tải thông tin phiên bản hiện tại.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      loadData();
    }
  }, [isOpen]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    setError(null);

    try {
      const res = await updateAppVersionInfo(formData);
      if (res.success) {
        if (onSuccessNotification) {
          onSuccessNotification(`Đã phát hành bản cập nhật v${formData.latestVersion} (Build ${formData.latestBuildNumber}) thành công!`);
        }
        onClose();
      } else {
        setError(res.message || 'Đẩy phiên bản thất bại.');
      }
    } catch (err: any) {
      setError(err.message || 'Lỗi khi kết nối đến máy chủ.');
    } finally {
      setSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="w-full max-w-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-6 bg-gradient-to-r from-indigo-900 via-indigo-950 to-slate-900 text-white flex items-center justify-between border-b border-indigo-500/20">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-indigo-500/20 border border-indigo-400/30 rounded-2xl text-indigo-300">
              <Smartphone className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-extrabold text-lg flex items-center gap-2">
                Phát Hành Cập Nhật Ứng Dụng (App OTA)
                <span className="px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-semibold border border-emerald-400/30">
                  v{formData.latestVersion}
                </span>
              </h3>
              <p className="text-xs text-indigo-200/80">
                Tự động gửi thông báo cập nhật tới mọi thiết bị di động đã cài App ZenHome
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 text-slate-400 hover:text-white rounded-xl hover:bg-white/10 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content Body */}
        <form onSubmit={handleSubmit} className="p-6 overflow-y-auto space-y-5 custom-scrollbar">
          {error && (
            <div className="p-4 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-xs flex items-center gap-2.5">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Quick Notice */}
          <div className="p-4 rounded-2xl bg-indigo-50 dark:bg-indigo-950/40 border border-indigo-100 dark:border-indigo-800/40 text-xs text-indigo-900 dark:text-indigo-200 space-y-1">
            <div className="font-bold flex items-center gap-1.5 text-indigo-700 dark:text-indigo-300">
              <Sparkles className="w-4 h-4" /> Cơ chế hoạt động:
            </div>
            <p>
              Khi bạn bấm <strong>"Phát Hành Bản Cập Nhật"</strong>, thông tin sẽ được ghi vào <strong>Cloud Firestore</strong> và bộ nhớ đệm API. App di động khi mở lên sẽ so sánh Build Number, nếu máy người dùng nhỏ hơn Build Number mới sẽ hiện ngay popup thông báo nâng cấp.
            </p>
          </div>

          {/* Version Inputs */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                Số phiên bản hiển thị (latestVersion)
              </label>
              <input
                type="text"
                value={formData.latestVersion}
                onChange={(e) => setFormData({ ...formData, latestVersion: e.target.value })}
                placeholder="Ví dụ: 1.4.0"
                required
                className="w-full px-3.5 py-2.5 text-sm rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-indigo-500 font-mono"
              />
              <span className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 block">Tên phiên bản hiển thị cho người dùng</span>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                Mã Build Number (latestBuildNumber)
              </label>
              <input
                type="number"
                value={formData.latestBuildNumber}
                onChange={(e) => setFormData({ ...formData, latestBuildNumber: Number(e.target.value) })}
                placeholder="Ví dụ: 140"
                required
                className="w-full px-3.5 py-2.5 text-sm rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-indigo-500 font-mono font-bold text-indigo-600 dark:text-indigo-400"
              />
              <span className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 block">Phải lớn hơn số build hiện tại trên máy client</span>
            </div>
          </div>

          {/* Force Update Switch */}
          <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className={`p-2 rounded-xl ${formData.isForceUpdate ? 'bg-rose-500/20 text-rose-400' : 'bg-slate-200 dark:bg-slate-700 text-slate-500'}`}>
                <ShieldAlert className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200">
                  Bắt buộc cập nhật (Force Update)
                </h4>
                <p className="text-[11px] text-slate-500 dark:text-slate-400">
                  Nếu bật, người dùng không thể đóng dialog để dùng tiếp cho tới khi cập nhật xong
                </p>
              </div>
            </div>

            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                checked={formData.isForceUpdate}
                onChange={(e) => setFormData({ ...formData, isForceUpdate: e.target.checked })}
                className="sr-only peer"
              />
              <div className="w-11 h-6 bg-slate-300 dark:bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-rose-600"></div>
            </label>
          </div>

          {/* Release Notes */}
          <div>
            <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
              Nội dung cập nhật (Ghi chú thay đổi Tiếng Việt)
            </label>
            <textarea
              rows={4}
              value={formData.releaseNotesVi}
              onChange={(e) => setFormData({ ...formData, releaseNotesVi: e.target.value })}
              placeholder="Nhập các điểm mới, tính năng cải tiến..."
              className="w-full p-3 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-indigo-500 leading-relaxed font-sans"
            />
          </div>

          {/* Download URLs */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                Đường dẫn tải APK trực tiếp
              </label>
              <input
                type="text"
                value={formData.directApkUrl}
                onChange={(e) => setFormData({ ...formData, directApkUrl: e.target.value })}
                placeholder="/public/downloads/zenhome-app-release.apk"
                className="w-full px-3.5 py-2 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-indigo-500 font-mono"
              />
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                Link tải ngoài / GitHub Release
              </label>
              <input
                type="text"
                value={formData.downloadUrl}
                onChange={(e) => setFormData({ ...formData, downloadUrl: e.target.value })}
                placeholder="https://github.com/..."
                className="w-full px-3.5 py-2 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-indigo-500 font-mono"
              />
            </div>
          </div>

          {/* Footer Action Buttons */}
          <div className="pt-3 border-t border-slate-200 dark:border-slate-800 flex items-center justify-between">
            <span className="text-[11px] text-slate-500 dark:text-slate-400 font-mono">
              {formData.publishedAt ? `Đã phát hành lúc: ${new Date(formData.publishedAt).toLocaleString('vi-VN')}` : 'Chưa lưu phiên bản'}
            </span>

            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
              >
                Hủy bỏ
              </button>

              <button
                type="submit"
                disabled={submitting || loading}
                className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold shadow-lg shadow-indigo-600/30 flex items-center gap-2 transition-all hover:scale-[1.02] disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {submitting ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    <span>Đang phát hành...</span>
                  </>
                ) : (
                  <>
                    <UploadCloud className="w-4 h-4" />
                    <span>🚀 Phát Hành Bản Cập Nhật</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
