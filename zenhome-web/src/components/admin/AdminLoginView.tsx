import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import {
  Lock,
  Key,
  ShieldCheck,
  Eye,
  EyeOff,
  AlertCircle,
  ArrowRight,
  Sparkles,
  Fingerprint,
  ChevronDown,
  ChevronUp,
  Laptop,
  CheckCircle2,
  Info,
  Smartphone
} from 'lucide-react';
import { verifyAdminSecret } from '../../services/backupServerService';
import {
  checkPasskeySupport,
  getPasskeyStatus,
  loginWithPasskey,
} from '../../services/passkeyService';

interface AdminLoginViewProps {
  onLoginSuccess: (secret: string) => void;
}

export const AdminLoginView: React.FC<AdminLoginViewProps> = ({ onLoginSuccess }) => {
  const [secretKey, setSecretKey] = useState('');
  const [showKey, setShowKey] = useState(false);
  const [rememberMe, setRememberMe] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [isPasskeyLoading, setIsPasskeyLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Trạng thái Passkey trên thiết bị & máy chủ
  const [hasPasskeys, setHasPasskeys] = useState<boolean>(false);
  const [passkeyCount, setPasskeyCount] = useState<number>(0);
  const [isCheckingPasskey, setIsCheckingPasskey] = useState(true);
  const [isPasskeySupported, setIsPasskeySupported] = useState(true);
  const [loginMode, setLoginMode] = useState<'passkey' | 'secret'>('secret');

  // Cơ chế chống Brute-force: Khóa tạm 60s nếu nhập sai 5 lần liên tiếp
  const [failedAttempts, setFailedAttempts] = useState<number>(0);
  const [lockedUntil, setLockedUntil] = useState<number | null>(null);
  const [countdown, setCountdown] = useState<number>(0);

  useEffect(() => {
    // Kiểm tra xem máy tính/trình duyệt có hỗ trợ WebAuthn và máy chủ đã có Passkey chưa
    const initAuthStatus = async () => {
      setIsCheckingPasskey(true);
      try {
        const support = await checkPasskeySupport();
        setIsPasskeySupported(support.supported);

        const status = await getPasskeyStatus();
        setHasPasskeys(status.hasPasskeys);
        setPasskeyCount(status.count);

        if (status.hasPasskeys && support.supported) {
          setLoginMode('passkey');
        } else {
          setLoginMode('secret');
        }
      } catch (e) {
        console.warn('Lỗi kiểm tra Passkey:', e);
      } finally {
        setIsCheckingPasskey(false);
      }
    };

    initAuthStatus();
  }, []);

  useEffect(() => {
    if (!lockedUntil) return;
    const interval = setInterval(() => {
      const remaining = Math.max(0, Math.ceil((lockedUntil - Date.now()) / 1000));
      setCountdown(remaining);
      if (remaining <= 0) {
        setLockedUntil(null);
        setFailedAttempts(0);
        setErrorMessage(null);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [lockedUntil]);

  // Đăng nhập một chạm bằng Passkey
  const handlePasskeyLogin = async () => {
    if (isPasskeyLoading) return;
    setIsPasskeyLoading(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    try {
      const res = await loginWithPasskey();
      if (res.success && res.token) {
        setSuccessMessage(`✅ Xác thực Passkey thành công [${res.deviceName || 'Thiết bị bảo mật'}]! Đang chuyển hướng...`);
        setTimeout(() => {
          onLoginSuccess(res.token!);
        }, 600);
      } else {
        setErrorMessage(res.error || 'Xác thực Passkey thất bại. Bạn có thể sử dụng Mã Master Secret.');
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Lỗi trong quá trình xác thực Passkey.');
    } finally {
      setIsPasskeyLoading(false);
    }
  };

  // Đăng nhập bằng Secret Key (dự phòng)
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (lockedUntil && Date.now() < lockedUntil) {
      setErrorMessage(`⛔ Cổng đăng nhập đang bị khóa do nhập sai nhiều lần. Vui lòng chờ ${countdown}s.`);
      return;
    }

    const trimmed = secretKey.trim();
    if (!trimmed) {
      setErrorMessage('Vui lòng nhập Mã Khóa Bí Mật Quản Trị Viên (Admin Secret Key).');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const isValid = await verifyAdminSecret(trimmed);
      if (isValid) {
        setFailedAttempts(0);
        setLockedUntil(null);
        if (rememberMe) {
          localStorage.setItem('zenhome_admin_key', trimmed);
          localStorage.setItem('zenhome_auth_method', 'secret');
        } else {
          sessionStorage.setItem('zenhome_admin_key', trimmed);
          sessionStorage.setItem('zenhome_auth_method', 'secret');
        }
        onLoginSuccess(trimmed);
      } else {
        const nextAttempts = failedAttempts + 1;
        setFailedAttempts(nextAttempts);
        if (nextAttempts >= 5) {
          const lockTime = Date.now() + 60000;
          setLockedUntil(lockTime);
          setCountdown(60);
          setErrorMessage('⛔ Bạn đã nhập sai 5 lần liên tiếp. Cổng đăng nhập tạm thời bị khóa 60 giây.');
        } else {
          setErrorMessage(`Mã Khóa Bí Mật không chính xác hoặc đã bị từ chối (${nextAttempts}/5 lần thử).`);
        }
      }
    } catch (err: any) {
      setErrorMessage('Không thể kết nối đến Máy chủ ZenHome Server. Vui lòng kiểm tra cổng mạng 5000.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center p-4 bg-gradient-to-br from-slate-950 via-slate-900 to-teal-950 text-slate-100 relative overflow-hidden font-sans">
      {/* Background ambient lighting */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-teal-500/10 rounded-full blur-3xl pointer-events-none animate-pulse duration-1000" />
      <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-md relative z-10 animate-in fade-in zoom-in-95 duration-300">
        <div className="backdrop-blur-2xl bg-slate-900/85 border border-slate-700/60 rounded-3xl p-8 shadow-2xl shadow-teal-950/40">
          {/* Logo & Header */}
          <div className="text-center mb-6">
            <motion.div
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-tr from-teal-500 to-emerald-400 p-0.5 shadow-lg shadow-teal-500/30 mb-4"
            >
              <div className="w-full h-full bg-slate-900 rounded-[14px] flex items-center justify-center">
                {loginMode === 'passkey' ? (
                  <Fingerprint className="w-8 h-8 text-teal-400 animate-pulse" />
                ) : (
                  <ShieldCheck className="w-8 h-8 text-teal-400" />
                )}
              </div>
            </motion.div>
            <h1 className="text-2xl font-bold tracking-tight bg-gradient-to-r from-white via-slate-200 to-teal-200 bg-clip-text text-transparent">
              ZenHome Cloud Admin
            </h1>
            <p className="text-xs text-slate-400 mt-1 flex items-center justify-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-teal-400" />
              <span>Hệ thống Giám sát & Điều phối IoT Toàn quyền</span>
            </p>
          </div>

          {/* Authentication Mode Tabs */}
          <div className="mb-6 flex rounded-xl bg-slate-950/80 p-1 border border-slate-800 text-xs font-semibold">
            <button
              onClick={() => {
                setLoginMode('passkey');
                setErrorMessage(null);
              }}
              className={`flex-1 py-2 rounded-lg transition flex items-center justify-center gap-2 relative ${
                loginMode === 'passkey'
                  ? 'text-white'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              {loginMode === 'passkey' && (
                <motion.div
                  layoutId="admin-auth-tab"
                  className="absolute inset-0 bg-teal-600 rounded-lg shadow-sm"
                  transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                />
              )}
              <span className="relative z-10 flex items-center gap-1.5">
                <Fingerprint className="w-4 h-4" />
                <span>Passkey (FIDO2)</span>
              </span>
            </button>

            <button
              onClick={() => {
                setLoginMode('secret');
                setErrorMessage(null);
              }}
              className={`flex-1 py-2 rounded-lg transition flex items-center justify-center gap-2 relative ${
                loginMode === 'secret'
                  ? 'text-white'
                  : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              {loginMode === 'secret' && (
                <motion.div
                  layoutId="admin-auth-tab"
                  className="absolute inset-0 bg-slate-800 rounded-lg shadow-sm"
                  transition={{ type: 'spring', stiffness: 450, damping: 30 }}
                />
              )}
              <span className="relative z-10 flex items-center gap-1.5">
                <Key className="w-3.5 h-3.5" />
                <span>Master Secret</span>
              </span>
            </button>
          </div>

          {/* Messages */}
          {errorMessage && (
            <div className="mb-5 p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-start gap-2 animate-in fade-in duration-200">
              <AlertCircle className="w-4 h-4 shrink-0 text-rose-400 mt-0.5" />
              <span>{errorMessage}</span>
            </div>
          )}

          {successMessage && (
            <div className="mb-5 p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-start gap-2 animate-in fade-in duration-200">
              <CheckCircle2 className="w-4 h-4 shrink-0 text-emerald-400 mt-0.5" />
              <span>{successMessage}</span>
            </div>
          )}

          {/* Passkey Mode */}
          <AnimatePresence mode="wait">
            {loginMode === 'passkey' ? (
              <motion.div
                key="passkey-mode"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
                className="space-y-5"
              >
                <div className="p-4 rounded-2xl bg-teal-950/30 border border-teal-500/20 text-center space-y-3">
                  <div className="w-16 h-16 rounded-2xl bg-teal-500/10 border border-teal-500/30 text-teal-400 flex items-center justify-center mx-auto shadow-inner">
                    <Fingerprint className="w-8 h-8 animate-pulse" />
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white">
                      Xác thực sinh trắc học không cần mật khẩu
                    </h3>
                    <p className="text-xs text-slate-400 mt-1 leading-relaxed">
                      Chạm cảm biến vân tay, Face ID hoặc mã PIN Windows Hello của máy tính để đăng nhập ngay lập tức.
                    </p>
                  </div>

                  {hasPasskeys ? (
                    <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-medium bg-emerald-500/10 text-emerald-300 border border-emerald-500/30">
                      <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                      <span>Đã liên kết {passkeyCount} thiết bị Passkey</span>
                    </div>
                  ) : (
                    <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-300 text-xs text-left flex items-start gap-2">
                      <Info className="w-4 h-4 shrink-0 mt-0.5" />
                      <span>
                        Chưa có Passkey nào được lưu trên máy chủ. Bạn hãy đăng nhập bằng <b>Master Secret</b> một lần để tạo Passkey cho thiết bị này.
                      </span>
                    </div>
                  )}
                </div>

                <motion.button
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.98 }}
                  onClick={handlePasskeyLogin}
                  disabled={isPasskeyLoading || !isPasskeySupported}
                  className="w-full py-4 px-4 rounded-2xl font-bold text-sm text-slate-950 bg-gradient-to-r from-teal-400 via-emerald-400 to-teal-300 hover:from-teal-300 hover:to-emerald-300 transition-all shadow-xl shadow-teal-500/25 flex items-center justify-center gap-3 disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
                >
                  {isPasskeyLoading ? (
                    <>
                      <div className="w-5 h-5 border-2 border-slate-950 border-t-transparent rounded-full animate-spin" />
                      <span>Đang chờ bạn chạm cảm biến...</span>
                    </>
                  ) : (
                    <>
                      <Fingerprint className="w-5 h-5" />
                      <span>Quét Passkey để Mở Khóa</span>
                      <ArrowRight className="w-4 h-4 ml-1" />
                    </>
                  )}
                </motion.button>

                {/* Phone QR Scan Guidance Tip */}
                <div className="p-3 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-300 text-xs flex items-start gap-2.5">
                  <Smartphone className="w-4 h-4 text-indigo-400 shrink-0 mt-0.5" />
                  <div className="space-y-0.5 text-left">
                    <span className="font-semibold text-slate-200">Muốn dùng điện thoại quét mã?</span>
                    <p className="text-[11px] text-slate-400 leading-relaxed">
                      Khi bấm nút trên, nếu trình duyệt hiện hộp thoại, bạn có thể chọn <b>"Sử dụng điện thoại hoặc máy tính bảng"</b> để quét mã QR bằng camera iPhone hoặc Android.
                    </p>
                  </div>
                </div>

                <div className="text-center pt-1">
                  <button
                    type="button"
                    onClick={() => setLoginMode('secret')}
                    className="text-xs text-slate-400 hover:text-teal-300 transition underline underline-offset-4"
                  >
                    Hoặc đăng nhập bằng Mã Khóa Master Secret dự phòng
                  </button>
                </div>
              </motion.div>
            ) : (
              /* Secret Key Mode (Fallback) */
              <motion.form
                key="secret-mode"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                transition={{ duration: 0.2 }}
                onSubmit={handleSubmit}
                className="space-y-5"
              >
                <div>
                  <label className="block text-xs font-semibold text-slate-300 mb-2 uppercase tracking-wider">
                    Mã Khóa Bí Mật Quản Trị (Master Secret)
                  </label>
                  <div className="relative">
                    <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400">
                      <Key className="w-4 h-4" />
                    </div>
                    <input
                      type={showKey ? 'text' : 'password'}
                      value={secretKey}
                      onChange={(e) => {
                        setSecretKey(e.target.value);
                        if (errorMessage) setErrorMessage(null);
                      }}
                      placeholder="Nhập ADMIN_API_SECRET..."
                      className="w-full pl-10 pr-10 py-3 rounded-xl bg-slate-950/60 border border-slate-700/80 focus:border-teal-500 focus:ring-2 focus:ring-teal-500/20 text-sm text-white placeholder-slate-500 outline-none transition-all"
                      autoFocus
                    />
                    <button
                      type="button"
                      onClick={() => setShowKey(!showKey)}
                      className="absolute inset-y-0 right-0 pr-3.5 flex items-center text-slate-400 hover:text-slate-200 transition-colors"
                    >
                      {showKey ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                    </button>
                  </div>
                </div>

                {/* Remember Me */}
                <div className="flex items-center justify-between text-xs text-slate-400">
                  <label className="flex items-center gap-2 cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={rememberMe}
                      onChange={(e) => setRememberMe(e.target.checked)}
                      className="w-4 h-4 rounded bg-slate-950 border-slate-700 text-teal-500 focus:ring-teal-500/20"
                    />
                    <span>Ghi nhớ phiên đăng nhập trên trình duyệt</span>
                  </label>
                </div>

                {/* Submit Button */}
                <motion.button
                  whileHover={{ scale: 1.01 }}
                  whileTap={{ scale: 0.99 }}
                  type="submit"
                  disabled={isLoading}
                  className="w-full py-3.5 px-4 rounded-xl font-semibold text-sm text-slate-950 bg-gradient-to-r from-teal-400 to-emerald-400 hover:from-teal-300 hover:to-emerald-300 transition-all shadow-lg shadow-teal-500/25 flex items-center justify-center gap-2 disabled:opacity-60 disabled:cursor-not-allowed cursor-pointer"
                >
                  {isLoading ? (
                    <>
                      <div className="w-4 h-4 border-2 border-slate-950 border-t-transparent rounded-full animate-spin" />
                      <span>Đang xác thực bảo mật...</span>
                    </>
                  ) : (
                    <>
                      <Lock className="w-4 h-4" />
                      <span>Mở Khóa Bảng Điều Khiển</span>
                      <ArrowRight className="w-4 h-4 ml-1" />
                    </>
                  )}
                </motion.button>

                {hasPasskeys && (
                  <div className="text-center pt-1">
                    <button
                      type="button"
                      onClick={() => setLoginMode('passkey')}
                      className="text-xs text-teal-400 hover:text-teal-300 transition flex items-center justify-center gap-1.5 mx-auto"
                    >
                      <Fingerprint className="w-3.5 h-3.5" />
                      <span>Đổi sang đăng nhập nhanh bằng Passkey</span>
                    </button>
                  </div>
                )}
              </motion.form>
            )}
          </AnimatePresence>

          {/* Footer note */}
          <div className="mt-6 pt-5 border-t border-slate-800 text-center text-[11px] text-slate-500 flex items-center justify-center gap-1.5">
            <ShieldCheck className="w-3.5 h-3.5 text-teal-500/70" />
            <span>Xác thực FIDO2 / WebAuthn & Token 2 lớp ZenHome Guard</span>
          </div>
        </div>
      </div>
    </div>
  );
};
