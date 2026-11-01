import React, { useState, useEffect } from 'react';
import { 
  Cpu, 
  X, 
  UploadCloud, 
  CheckCircle2, 
  AlertCircle, 
  Sparkles, 
  RefreshCw,
  ExternalLink,
  Layers,
  ShieldCheck,
  Radio,
  FileCode,
  ArrowRight,
  Send,
  Globe,
  Server,
  Zap,
  Info
} from 'lucide-react';
import { 
  fetchEsp32OtaInfo, 
  triggerEsp32Ota, 
  deployPlatformIoBuild, 
  uploadEsp32Firmware,
  publishEsp32Firmware,
  Esp32FirmwareInfo 
} from '../../services/backupServerService';
import { RealCustomerUser } from '../../types/admin';

interface Esp32OtaModalProps {
  isOpen: boolean;
  onClose: () => void;
  customers?: RealCustomerUser[];
  onSuccessNotification?: (msg: string) => void;
}

export const Esp32OtaModal: React.FC<Esp32OtaModalProps> = ({
  isOpen,
  onClose,
  customers = [],
  onSuccessNotification
}) => {
  const [activeTab, setActiveTab] = useState<'publish' | 'deploy'>('publish');
  const [loading, setLoading] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [deploying, setDeploying] = useState(false);
  const [triggeringMac, setTriggeringMac] = useState<string | null>(null);
  const [info, setInfo] = useState<Esp32FirmwareInfo | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);

  // Form phát hành firmware mới
  const [versionInput, setVersionInput] = useState('2.5.7');
  const [buildInput, setBuildInput] = useState(201);
  const [directUrlInput, setDirectUrlInput] = useState('https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin');
  const [sha256Input, setSha256Input] = useState('04ED702ED910C47346753980E5A551AAE6CF871D36CFC39BE5934FB071D610C2');
  const [fileSizeInput, setFileSizeInput] = useState(1381760);
  const [releaseNotesVi, setReleaseNotesVi] = useState(
    '• Tối ưu hóa luồng truyền nhận trạng thái MQTT thời gian thực\n• Tích hợp đường dẫn tải firmware GitHub Releases toàn cầu không phụ thuộc IP LAN\n• Nâng cấp cơ chế Dual-Boot A/B Safe Rollback chống brick bo mạch 100%\n• Đồng bộ xác thực bảo mật 2 chiều User & MAC với Cloud Firestore'
  );
  const [triggerFleetOta, setTriggerFleetOta] = useState(false);

  // Upload file state
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);

  const defaultGithubUrl = 'https://github.com/dtt09/ma_nguon_ZenHome/releases/latest/download/firmware.bin';
  const defaultLocalUrl = typeof window !== 'undefined'
    ? `${window.location.origin}/public/firmware/esp32/firmware.bin`
    : '/public/firmware/esp32/firmware.bin';

  const loadInfo = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchEsp32OtaInfo();
      if (data) {
        setInfo(data);
        if (data.version) setVersionInput(data.version);
        if (data.buildNumber) setBuildInput(data.buildNumber);
        if (data.directUrl) setDirectUrlInput(data.directUrl);
        if (data.sha256) setSha256Input(data.sha256);
        if (data.fileSizeBytes) setFileSizeInput(data.fileSizeBytes);
        if (data.releaseNotesVi) setReleaseNotesVi(data.releaseNotesVi);
      }
    } catch (e: any) {
      setError(e.message || 'Lỗi tải thông tin firmware');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen) {
      loadInfo();
      setError(null);
      setSuccessMsg(null);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  // Xử lý Phát hành phiên bản mới lên Cloud & Server
  const handlePublishFirmware = async (e: React.FormEvent) => {
    e.preventDefault();
    setPublishing(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const res = await publishEsp32Firmware({
        version: versionInput.trim(),
        buildNumber: Number(buildInput),
        directUrl: directUrlInput.trim(),
        sha256: sha256Input.trim(),
        fileSizeBytes: Number(fileSizeInput),
        releaseNotesVi: releaseNotesVi.trim(),
        triggerFleetOta,
      });

      setSuccessMsg(res.message || 'Đã xuất bản phiên bản Firmware ESP32 thành công!');
      await loadInfo();

      if (onSuccessNotification) {
        onSuccessNotification(`Đã phát hành Firmware ESP32 v${versionInput} (Build ${buildInput}) thành công!`);
      }
    } catch (err: any) {
      setError(err.message || 'Lỗi khi phát hành firmware ESP32');
    } finally {
      setPublishing(false);
    }
  };

  // Xử lý 1-Click triển khai từ PlatformIO build
  const handleDeployPlatformIo = async () => {
    setDeploying(true);
    setError(null);
    setSuccessMsg(null);
    try {
      const res = await deployPlatformIoBuild({
        version: versionInput,
        buildNumber: Number(buildInput),
      });
      setSuccessMsg(res.message || 'Đã triển khai bản build mới lên server!');
      await loadInfo();
      if (onSuccessNotification) {
        onSuccessNotification('Đã xuất bản firmware ESP32 mới lên Web Server thành công!');
      }
    } catch (e: any) {
      setError(e.message || 'Lỗi triển khai firmware');
    } finally {
      setDeploying(false);
    }
  };

  // Kích hoạt OTA cho 1 Hub khách hàng
  const handleTriggerOta = async (customer: RealCustomerUser) => {
    if (!customer.macAddress) return;
    setTriggeringMac(customer.macAddress);
    setError(null);
    setSuccessMsg(null);
    try {
      const res = await triggerEsp32Ota({
        userId: customer.id,
        macAddress: customer.macAddress,
        version: versionInput,
      });
      setSuccessMsg(res.message);
      if (onSuccessNotification) {
        onSuccessNotification(`Đã phát tín hiệu OTA tới Hub ${customer.macAddress}!`);
      }
    } catch (e: any) {
      setError(e.message || 'Lỗi phát lệnh OTA');
    } finally {
      setTriggeringMac(null);
    }
  };

  // Upload file .bin tùy ý
  const handleFileUpload = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedFile) return;
    setUploading(true);
    setError(null);
    setSuccessMsg(null);

    try {
      const reader = new FileReader();
      reader.onload = async () => {
        try {
          const base64 = (reader.result as string).split(',')[1];
          const res = await uploadEsp32Firmware({
            base64Data: base64,
            version: versionInput,
            buildNumber: Number(buildInput),
          });
          setSuccessMsg(res.message);
          setSelectedFile(null);
          await loadInfo();
          if (onSuccessNotification) {
            onSuccessNotification('Đã upload firmware .bin thành công!');
          }
        } catch (err: any) {
          setError(err.message || 'Lỗi upload firmware');
        } finally {
          setUploading(false);
        }
      };
      reader.readAsDataURL(selectedFile);
    } catch (err: any) {
      setError(err.message || 'Lỗi đọc file');
      setUploading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-sm animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-3xl bg-white dark:bg-slate-900 rounded-3xl border border-slate-200 dark:border-slate-800 shadow-2xl overflow-hidden flex flex-col max-h-[92vh]"
        onClick={(e) => e.stopPropagation()}
      >
        
        {/* Header */}
        <div className="p-6 bg-gradient-to-r from-violet-950 via-indigo-950 to-slate-950 text-white flex items-center justify-between border-b border-violet-500/20">
          <div className="flex items-center gap-3">
            <div className="p-3 bg-violet-500/20 border border-violet-400/30 rounded-2xl text-violet-300">
              <Cpu className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-extrabold text-lg tracking-tight">
                  Phát Hành & Nâng Cấp Firmware ESP32
                </h3>
                <span className="px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-bold border border-emerald-400/30">
                  v{versionInput} ({buildInput})
                </span>
                <span className="hidden sm:inline-block px-2 py-0.5 rounded-full bg-violet-500/20 text-violet-300 text-[10px] font-semibold border border-violet-400/30">
                  Dual-Boot Safe Rollback
                </span>
              </div>
              <p className="text-xs text-violet-200/80 mt-0.5">
                Đồng bộ hóa firmware Hub ESP32 qua GitHub Releases & lệnh MQTT OTA thời gian thực
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

        {/* Tab Selector Navigation */}
        <div className="flex border-b border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/60 px-6 pt-3 gap-2">
          <button
            type="button"
            onClick={() => setActiveTab('publish')}
            className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold rounded-t-xl transition-all border-b-2 ${
              activeTab === 'publish'
                ? 'border-violet-500 text-violet-600 dark:text-violet-400 bg-white dark:bg-slate-900 shadow-xs'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <Send className="w-4 h-4" />
            <span>Phát Hành Phiên Bản (Publish OTA)</span>
          </button>

          <button
            type="button"
            onClick={() => setActiveTab('deploy')}
            className={`flex items-center gap-2 px-4 py-2.5 text-xs font-bold rounded-t-xl transition-all border-b-2 ${
              activeTab === 'deploy'
                ? 'border-indigo-500 text-indigo-600 dark:text-indigo-400 bg-white dark:bg-slate-900 shadow-xs'
                : 'border-transparent text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
            }`}
          >
            <Layers className="w-4 h-4" />
            <span>Nạp File Binary & Quản Lý Thiết Bị</span>
          </button>
        </div>

        {/* Content Body */}
        <div className="p-6 overflow-y-auto space-y-5 text-xs text-slate-600 dark:text-slate-300 custom-scrollbar">
          
          {error && (
            <div className="p-3.5 bg-rose-50 dark:bg-rose-950/40 border border-rose-200 dark:border-rose-900/50 text-rose-700 dark:text-rose-400 rounded-2xl flex items-center gap-2.5">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {successMsg && (
            <div className="p-3.5 bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-900/50 text-emerald-700 dark:text-emerald-400 rounded-2xl flex items-center gap-2.5">
              <CheckCircle2 className="w-4 h-4 shrink-0" />
              <span>{successMsg}</span>
            </div>
          )}

          {/* Current Firmware Status Banner */}
          <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200 dark:border-slate-800 space-y-3">
            <div className="flex items-center justify-between">
              <span className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                <FileCode className="w-4 h-4 text-violet-500" />
                Thông Tin Bản Firmware Đang Phát Hành
              </span>
              <button
                onClick={loadInfo}
                disabled={loading}
                className="text-xs text-violet-600 dark:text-violet-400 hover:underline flex items-center gap-1 font-medium"
              >
                <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
                Làm mới
              </button>
            </div>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-slate-700 dark:text-slate-300">
              <div className="p-2.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200/70 dark:border-slate-800">
                <span className="text-[10px] text-slate-400 block font-medium">Phiên Bản</span>
                <span className="font-bold text-emerald-600 dark:text-emerald-400 font-mono text-sm">
                  v{info?.version || '2.5.7'}
                </span>
                <span className="text-[10px] text-slate-400 ml-1">({info?.buildNumber || 201})</span>
              </div>

              <div className="p-2.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200/70 dark:border-slate-800">
                <span className="text-[10px] text-slate-400 block font-medium">Dung Lượng</span>
                <span className="font-bold font-mono text-sm">
                  {((info?.fileSizeBytes || 1380048) / (1024 * 1024)).toFixed(2)} MB
                </span>
              </div>

              <div className="p-2.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200/70 dark:border-slate-800 col-span-2">
                <span className="text-[10px] text-slate-400 block font-medium">Mã SHA-256 Checksum</span>
                <span className="font-mono text-[10px] truncate block text-violet-600 dark:text-violet-400 font-semibold" title={info?.sha256}>
                  {info?.sha256 || '3B4F069E0A74D34C6E38BF3037EB329F5DCAF32A0F90391F8722D0AE3D0E4F4D'}
                </span>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-1 text-[11px] pt-1 border-t border-slate-200/60 dark:border-slate-800/80">
              <span className="text-slate-400 shrink-0">Direct URL Tải Về:</span>
              <a
                href={info?.directUrl || defaultGithubUrl}
                target="_blank"
                rel="noreferrer"
                className="text-violet-600 dark:text-violet-400 hover:underline flex items-center gap-1 font-mono truncate max-w-full"
                title={info?.directUrl || defaultGithubUrl}
              >
                <span className="truncate">{info?.directUrl || defaultGithubUrl}</span>
                <ExternalLink className="w-3 h-3 shrink-0" />
              </a>
            </div>
          </div>

          {/* TAB 1: PHÁT HÀNH PHIÊN BẢN (PUBLISH OTA) */}
          {activeTab === 'publish' && (
            <form onSubmit={handlePublishFirmware} className="space-y-4">
              
              {/* Info Callout */}
              <div className="p-3.5 rounded-2xl bg-violet-50 dark:bg-violet-950/30 border border-violet-100 dark:border-violet-900/40 text-xs text-violet-900 dark:text-violet-200 space-y-1">
                <div className="font-bold flex items-center gap-1.5 text-violet-700 dark:text-violet-300">
                  <Sparkles className="w-4 h-4" /> Cơ chế nâng cấp Firmware:
                </div>
                <p>
                  Khi bấm <strong>"Xuất Bản & Phát Hành"</strong>, thông tin sẽ được lưu vào <strong>Firestore system_config/esp32_firmware</strong> và đồng bộ với Web Server. Mọi Hub ESP32 khi kiểm tra OTA sẽ so sánh số Build, nếu có bản mới sẽ tải trực tiếp từ GitHub hoặc máy chủ và tự nạp an toàn bằng phân vùng kép A/B (không phụ thuộc IP local).
                </p>
              </div>

              {/* Version & Build Number Inputs */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                    Số phiên bản Firmware (version)
                  </label>
                  <input
                    type="text"
                    value={versionInput}
                    onChange={(e) => setVersionInput(e.target.value)}
                    placeholder="Ví dụ: 2.5.7"
                    required
                    className="w-full px-3.5 py-2.5 text-sm rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-violet-500 font-mono font-bold"
                  />
                  <span className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 block">
                    Định dạng chuẩn Semantic Versioning (x.y.z)
                  </span>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                    Mã Build Number (buildNumber)
                  </label>
                  <input
                    type="number"
                    value={buildInput}
                    onChange={(e) => setBuildInput(Number(e.target.value))}
                    placeholder="Ví dụ: 199"
                    required
                    className="w-full px-3.5 py-2.5 text-sm rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-violet-500 font-mono font-bold text-violet-600 dark:text-violet-400"
                  />
                  <span className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 block">
                    Phải lớn hơn số build hiện hành trên các Hub ESP32
                  </span>
                </div>
              </div>

              {/* Direct Firmware URL */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-bold text-slate-700 dark:text-slate-300">
                    Đường dẫn tải file binary firmware.bin (Direct URL)
                  </label>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setDirectUrlInput(defaultGithubUrl)}
                      className="text-[11px] font-semibold text-violet-600 dark:text-violet-400 hover:underline flex items-center gap-1"
                    >
                      <Globe className="w-3 h-3" /> GitHub Releases (Khuyên Dùng)
                    </button>
                    <span className="text-slate-300 dark:text-slate-700">•</span>
                    <button
                      type="button"
                      onClick={() => setDirectUrlInput(defaultLocalUrl)}
                      className="text-[11px] font-semibold text-slate-600 dark:text-slate-400 hover:underline flex items-center gap-1"
                    >
                      <Server className="w-3 h-3" /> Web Server
                    </button>
                  </div>
                </div>
                <input
                  type="text"
                  value={directUrlInput}
                  onChange={(e) => setDirectUrlInput(e.target.value)}
                  placeholder="https://github.com/.../firmware.bin"
                  required
                  className="w-full px-3.5 py-2.5 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-violet-500 font-mono"
                />
                <span className="text-[11px] text-slate-500 dark:text-slate-400 mt-1 block">
                  Đường dẫn công khai HTTPS giúp thiết bị tải cập nhật từ mọi nơi mà không bị giới hạn mạng nội bộ
                </span>
              </div>

              {/* SHA-256 and File Size */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="sm:col-span-2">
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                    Mã băm toàn vẹn SHA-256
                  </label>
                  <input
                    type="text"
                    value={sha256Input}
                    onChange={(e) => setSha256Input(e.target.value)}
                    placeholder="Mã SHA-256..."
                    className="w-full px-3.5 py-2 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-violet-500 font-mono uppercase"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                    Dung lượng (Bytes)
                  </label>
                  <input
                    type="number"
                    value={fileSizeInput}
                    onChange={(e) => setFileSizeInput(Number(e.target.value))}
                    placeholder="1380048"
                    className="w-full px-3.5 py-2 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-violet-500 font-mono"
                  />
                </div>
              </div>

              {/* Release Notes */}
              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1.5">
                  Ghi chú phát hành phiên bản (Changelog Tiếng Việt)
                </label>
                <textarea
                  rows={3}
                  value={releaseNotesVi}
                  onChange={(e) => setReleaseNotesVi(e.target.value)}
                  placeholder="Nhập các cải tiến, vá lỗi của phiên bản firmware này..."
                  className="w-full p-3 text-xs rounded-xl bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-800 dark:text-slate-100 focus:outline-none focus:border-violet-500 leading-relaxed font-sans"
                />
              </div>

              {/* Auto Broadcast Fleet OTA Toggle */}
              <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700/60 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className={`p-2 rounded-xl ${triggerFleetOta ? 'bg-violet-500/20 text-violet-400' : 'bg-slate-200 dark:bg-slate-700 text-slate-500'}`}>
                    <Radio className="w-5 h-5" />
                  </div>
                  <div>
                    <h4 className="text-xs font-bold text-slate-800 dark:text-slate-200">
                      Tự động phát tín hiệu OTA toàn đội tàu (Fleet OTA Broadcast)
                    </h4>
                    <p className="text-[11px] text-slate-500 dark:text-slate-400">
                      Nếu bật, server sẽ gửi lệnh MQTT OTA tới toàn bộ các Hub ESP32 đang trực tuyến ngay sau khi phát hành
                    </p>
                  </div>
                </div>

                <label className="relative inline-flex items-center cursor-pointer">
                  <input
                    type="checkbox"
                    checked={triggerFleetOta}
                    onChange={(e) => setTriggerFleetOta(e.target.checked)}
                    className="sr-only peer"
                  />
                  <div className="w-11 h-6 bg-slate-300 dark:bg-slate-700 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-violet-600"></div>
                </label>
              </div>

              {/* Submit Button */}
              <div className="pt-2 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={onClose}
                  className="px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                >
                  Hủy bỏ
                </button>

                <button
                  type="submit"
                  disabled={publishing || loading}
                  className="px-6 py-2.5 rounded-xl bg-violet-600 hover:bg-violet-700 text-white text-xs font-bold shadow-lg shadow-violet-600/30 flex items-center gap-2 transition-all hover:scale-[1.02] disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {publishing ? (
                    <>
                      <RefreshCw className="w-4 h-4 animate-spin" />
                      <span>Đang phát hành...</span>
                    </>
                  ) : (
                    <>
                      <UploadCloud className="w-4 h-4" />
                      <span>🚀 Phát Hành Bản Firmware ESP32</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          )}

          {/* TAB 2: TRIỂN KHAI BINARY & QUẢN LÝ THIẾT BỊ */}
          {activeTab === 'deploy' && (
            <div className="space-y-5">
              {/* Deploy or Upload Actions */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* 1-Click Deploy Build from PlatformIO */}
                <div className="p-4 rounded-2xl bg-violet-50/50 dark:bg-violet-950/20 border border-violet-100 dark:border-violet-900/40 space-y-3">
                  <h4 className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                    <Sparkles className="w-4 h-4 text-violet-500" />
                    1-Click Triển Khai Bản Build PlatformIO
                  </h4>
                  <p className="text-[11px] text-slate-500 dark:text-slate-400">
                    Lấy trực tiếp file firmware vừa biên dịch từ <code>esp32_1/.pio/build/esp32dev/firmware.bin</code> để xuất bản vào kho của Server.
                  </p>
                  <button
                    onClick={handleDeployPlatformIo}
                    disabled={deploying}
                    className="w-full py-2.5 px-4 rounded-xl bg-violet-600 hover:bg-violet-700 text-white font-bold flex items-center justify-center gap-2 shadow-sm transition-all disabled:opacity-50"
                  >
                    <UploadCloud className={`w-4 h-4 ${deploying ? 'animate-bounce' : ''}`} />
                    {deploying ? 'Đang triển khai...' : 'Triển Khai Vào Kho OTA'}
                  </button>
                </div>

                {/* Custom Upload Form */}
                <form onSubmit={handleFileUpload} className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-800/40 border border-slate-200/80 dark:border-slate-800 space-y-3">
                  <h4 className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-1.5">
                    <FileCode className="w-4 h-4 text-slate-500" />
                    Tải Lên File .bin Tùy Chọn
                  </h4>
                  <input
                    type="file"
                    accept=".bin"
                    onChange={(e) => setSelectedFile(e.target.files?.[0] || null)}
                    className="w-full text-xs text-slate-500 file:mr-2 file:py-1 file:px-2.5 file:rounded-lg file:border-0 file:text-[11px] file:font-semibold file:bg-slate-200 dark:file:bg-slate-700 file:text-slate-700 dark:file:text-slate-200 cursor-pointer"
                  />
                  <button
                    type="submit"
                    disabled={!selectedFile || uploading}
                    className="w-full py-2 px-3 rounded-xl bg-slate-800 dark:bg-slate-700 hover:bg-slate-900 text-white font-bold flex items-center justify-center gap-2 transition-all disabled:opacity-40"
                  >
                    <UploadCloud className="w-3.5 h-3.5" />
                    {uploading ? 'Đang tải lên...' : 'Tải Lên Web Server'}
                  </button>
                </form>
              </div>

              {/* Fleet Hubs Target Trigger */}
              <div className="space-y-2.5 pt-2">
                <div className="flex items-center justify-between">
                  <h4 className="font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                    <Radio className="w-4 h-4 text-emerald-500" />
                    Kích Hoạt Nâng Cấp Tới Từng Hub ESP32 Cụ Thể
                  </h4>
                  <span className="text-[11px] text-slate-400 font-mono">
                    {customers.filter(c => Boolean(c.macAddress)).length} Hubs đã liên kết
                  </span>
                </div>

                <div className="max-h-56 overflow-y-auto space-y-2 pr-1 custom-scrollbar">
                  {customers.filter(c => Boolean(c.macAddress)).length === 0 ? (
                    <div className="p-4 rounded-xl border border-dashed border-slate-300 dark:border-slate-700 text-center text-slate-400">
                      Chưa có Hub nào được liên kết hoặc đang tải danh sách khách hàng...
                    </div>
                  ) : (
                    customers.filter(c => Boolean(c.macAddress)).map(c => {
                      const isTriggering = triggeringMac === c.macAddress;
                      return (
                        <div
                          key={c.id}
                          className="p-3 rounded-xl bg-white dark:bg-slate-900 border border-slate-200/70 dark:border-slate-800 flex items-center justify-between"
                        >
                          <div>
                            <div className="font-mono font-bold text-slate-900 dark:text-slate-100 text-xs">
                              {c.macAddress}
                            </div>
                            <div className="text-[11px] text-slate-400">
                              Chủ sở hữu: <span className="font-medium text-slate-600 dark:text-slate-300">{c.displayName || c.id}</span>
                            </div>
                          </div>

                          <button
                            onClick={() => handleTriggerOta(c)}
                            disabled={isTriggering}
                            className="py-1.5 px-3 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white font-bold flex items-center gap-1.5 transition-all text-xs shadow-sm disabled:opacity-40"
                          >
                            <ArrowRight className={`w-3.5 h-3.5 ${isTriggering ? 'animate-ping' : ''}`} />
                            {isTriggering ? 'Đang gửi...' : 'Nâng Cấp OTA'}
                          </button>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            </div>
          )}

        </div>

        {/* Footer */}
        <div className="px-6 py-3.5 border-t border-slate-100 dark:border-slate-800/80 bg-slate-50/50 dark:bg-slate-800/20 flex items-center justify-between">
          <span className="text-[11px] text-slate-400 flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-500" />
            Hỗ trợ phân vùng A/B Safe Rollback chống brick bo mạch vi điều khiển 100%
          </span>
          <button
            onClick={onClose}
            className="py-2 px-4 rounded-xl bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-300 font-bold hover:bg-slate-300 dark:hover:bg-slate-700 transition-colors"
          >
            Đóng
          </button>
        </div>

      </div>
    </div>
  );
};
