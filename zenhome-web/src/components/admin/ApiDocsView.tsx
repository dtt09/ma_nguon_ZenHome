import React, { useState, useMemo } from 'react';
import { 
  Code2, 
  ExternalLink, 
  Play, 
  CheckCircle2, 
  AlertCircle, 
  Copy, 
  Server, 
  Cpu, 
  Layers, 
  Clock, 
  ShieldCheck,
  RefreshCw,
  Search,
  Terminal,
  Database,
  Activity,
  Wifi,
  Filter,
  Check,
  Sparkles,
  FileCode,
  ArrowRight,
  Maximize2
} from 'lucide-react';

interface EndpointItem {
  id: string;
  method: 'GET' | 'POST' | 'DELETE' | 'PUT';
  path: string;
  category: 'users' | 'devices' | 'scenes' | 'schedules' | 'alerts' | 'hub' | 'backup' | 'system';
  categoryLabel: string;
  summary: string;
  description: string;
  defaultBody?: string;
  queryParams?: { name: string; defaultVal: string; desc: string }[];
}

export const ApiDocsView: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'playground' | 'swagger' | 'architecture'>('playground');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [selectedMethod, setSelectedMethod] = useState<string>('all');
  
  // State for Testing Playground
  const [selectedEndpoint, setSelectedEndpoint] = useState<EndpointItem | null>(null);
  const [requestBody, setRequestBody] = useState<string>('');
  const [customPath, setCustomPath] = useState<string>('');
  const [responseOutput, setResponseOutput] = useState<string>('');
  const [responseStatus, setResponseStatus] = useState<number | null>(null);
  const [responseDuration, setResponseDuration] = useState<number | null>(null);
  const [responseSize, setResponseSize] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [copiedUrl, setCopiedUrl] = useState<boolean>(false);
  const [copiedCurl, setCopiedCurl] = useState<boolean>(false);
  const [copiedJson, setCopiedJson] = useState<boolean>(false);
  const [iframeKey, setIframeKey] = useState<number>(1);

  const serverBaseUrl = typeof window !== 'undefined' ? window.location.origin : 'http://localhost:5000';

  const endpoints: EndpointItem[] = [
    // USERS
    {
      id: 'get-users',
      method: 'GET',
      path: '/api/v1/users',
      category: 'users',
      categoryLabel: 'Người Dùng',
      summary: 'Lấy danh sách tất cả tài khoản từ Firestore',
      description: 'Truy vấn bộ sưu tập users trong Firebase Firestore thực tế, đồng bộ thông tin hồ sơ và số lượng thiết bị sở hữu.',
    },
    {
      id: 'get-user-detail',
      method: 'GET',
      path: '/api/v1/users/dtthuat',
      category: 'users',
      categoryLabel: 'Người Dùng',
      summary: 'Lấy chi tiết hồ sơ người dùng & phiên di động',
      description: 'Trả về thông tin chi tiết của tài khoản dtthuat gồm displayName, email, địa chỉ MAC ESP32 và các phiên mobile sessions.',
    },
    {
      id: 'put-user-update',
      method: 'PUT',
      path: '/api/v1/users/dtthuat',
      category: 'users',
      categoryLabel: 'Người Dùng',
      summary: 'Cập nhật thông tin tài khoản người dùng',
      description: 'Cập nhật tên hiển thị, số điện thoại, ngày sinh hoặc liên kết địa chỉ MAC cho tài khoản.',
      defaultBody: JSON.stringify({
        displayName: "Đinh Tử Thuật (Admin)",
        phoneNumber: "0912345678",
        birthday: "2006-10-21"
      }, null, 2),
    },

    // DEVICES
    {
      id: 'get-devices',
      method: 'GET',
      path: '/api/v1/devices?userId=dtthuat',
      category: 'devices',
      categoryLabel: 'Thiết Bị',
      summary: 'Lấy danh sách thiết bị THỰC TẾ từ Firestore',
      description: 'Lấy toàn bộ relay, công tắc, quạt và đèn thực tế đã đăng ký của chủ nhà. Không sinh dữ liệu ảo.',
    },
    {
      id: 'post-device-create',
      method: 'POST',
      path: '/api/v1/devices',
      category: 'devices',
      categoryLabel: 'Thiết Bị',
      summary: 'Thêm thiết bị mới vào Firestore',
      description: 'Đăng ký một thiết bị mới gán chân GPIO và phòng cụ thể trong Firestore.',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        id: "den_bep",
        name: "Đèn Chiếu Sáng Bếp",
        room: "bep",
        pin: 2,
        icon: "light"
      }, null, 2),
    },
    {
      id: 'post-device-control',
      method: 'POST',
      path: '/api/v1/devices/den_bep/control',
      category: 'devices',
      categoryLabel: 'Thiết Bị',
      summary: 'Điều khiển Bật/Tắt thiết bị qua MQTT Retry Engine',
      description: 'Gửi lệnh đóng cắt rơ-le qua HiveMQ Cloud TLS 8883 tới ESP32, tự động retry nếu mạng chập chờn và ghi log lịch sử.',
      defaultBody: JSON.stringify({
        state: "1",
        userId: "dtthuat",
        source: "web_admin"
      }, null, 2),
    },
    {
      id: 'get-device-telemetry',
      method: 'GET',
      path: '/api/v1/devices/telemetry/status',
      category: 'devices',
      categoryLabel: 'Thiết Bị',
      summary: 'Đọc chỉ số cảm biến DHT11 & An toàn hỏa hoạn',
      description: 'Truy vấn nhiệt độ, độ ẩm môi trường thời gian thực được cập nhật từ cảm biến phần cứng qua MQTT.',
    },

    // SCENES
    {
      id: 'get-scenes',
      method: 'GET',
      path: '/api/v1/scenes?userId=dtthuat',
      category: 'scenes',
      categoryLabel: 'Ngữ Cảnh',
      summary: 'Lấy danh sách ngữ cảnh tự động hóa thực tế',
      description: 'Truy vấn danh sách kịch bản thông minh (Rời nhà, Tiếp khách, Đi ngủ) từ Firestore.',
    },
    {
      id: 'post-scene-trigger',
      method: 'POST',
      path: '/api/v1/scenes/scene_roi_nha/trigger',
      category: 'scenes',
      categoryLabel: 'Ngữ Cảnh',
      summary: 'Kích hoạt chạy ngay ngữ cảnh tự động',
      description: 'Thực thi tuần tự các hành động đóng cắt relay đã lập trình trong ngữ cảnh.',
      defaultBody: JSON.stringify({
        userId: "dtthuat"
      }, null, 2),
    },

    // SCHEDULES & TIMERS
    {
      id: 'get-schedules',
      method: 'GET',
      path: '/api/v1/schedules?userId=dtthuat',
      category: 'schedules',
      categoryLabel: 'Lịch Trình',
      summary: 'Lấy danh sách lịch trình tự động tập trung (Cron)',
      description: 'Truy vấn các lịch trình bật/tắt định kỳ được đồng bộ giữa Cloud Firestore và bộ nhớ RAM máy chủ.',
    },
    {
      id: 'get-timers',
      method: 'GET',
      path: '/api/v1/timers?userId=dtthuat',
      category: 'schedules',
      categoryLabel: 'Hẹn Giờ',
      summary: 'Lấy danh sách hẹn giờ đếm ngược trong RAM',
      description: 'Truy vấn các tác vụ đếm ngược tắt/bật thiết bị đang đếm giây thực tế trên RAM server.',
    },
    {
      id: 'post-timer-create',
      method: 'POST',
      path: '/api/v1/timers',
      category: 'schedules',
      categoryLabel: 'Hẹn Giờ',
      summary: 'Tạo lệnh hẹn giờ đếm ngược tắt thiết bị',
      description: 'Lên lịch tự động tắt quạt hoặc đèn sau số phút chỉ định.',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        deviceId: "den_bep",
        action: "0",
        durationMinutes: 10
      }, null, 2),
    },

    // ALERTS & HISTORY
    {
      id: 'get-alerts',
      method: 'GET',
      path: '/api/v1/alerts?userId=dtthuat',
      category: 'alerts',
      categoryLabel: 'Cảnh Báo',
      summary: 'Lấy danh sách cảnh báo an toàn hỏa hoạn',
      description: 'Tra cứu các cảnh báo nhiệt độ cao (>= 50°C), ngắt tải khẩn cấp hoặc mất điện lưới từ Firestore.',
    },
    {
      id: 'get-alerts-history',
      method: 'GET',
      path: '/api/v1/alerts/history?userId=dtthuat&limit=20',
      category: 'alerts',
      categoryLabel: 'Lịch Sử',
      summary: 'Lấy lịch sử thao tác thiết bị chi tiết',
      description: 'Truy vấn audit trail lịch sử đóng cắt relay, thời gian, nguồn tác động (App, Web, Tự động hóa).',
    },

    // HUB ESP32
    {
      id: 'get-hub-status',
      method: 'GET',
      path: '/api/v1/hub/status',
      category: 'hub',
      categoryLabel: 'Hub ESP32',
      summary: 'Kiểm tra trạng thái kết nối phần cứng ESP32',
      description: 'Giám sát nhịp tim (Keepalive), địa chỉ IP, địa chỉ MAC, phiên bản Firmware và bộ nhớ RAM trống của ESP32.',
    },
    {
      id: 'post-hub-link',
      method: 'POST',
      path: '/api/v1/hub/link',
      category: 'hub',
      categoryLabel: 'Hub ESP32',
      summary: 'Liên kết địa chỉ MAC của ESP32 với chủ nhà',
      description: 'Gắn định danh vi điều khiển thực tế vào tài khoản người dùng trong Firestore.',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        macAddress: "24:6F:28:4C:75:A0"
      }, null, 2),
    },

    // BACKUP SERVER
    {
      id: 'get-backup-status',
      method: 'GET',
      path: '/api/v1/backup/status',
      category: 'backup',
      categoryLabel: 'Máy Chủ Backup',
      summary: 'Kiểm tra trạng thái Máy chủ Backup độc lập',
      description: 'Truy vấn tình trạng giám sát nhịp tim, RAM và các Observers đang kết nối.',
    },
    {
      id: 'post-backup-trigger',
      method: 'POST',
      path: '/api/v1/backup/trigger',
      category: 'backup',
      categoryLabel: 'Máy Chủ Backup',
      summary: 'Kích hoạt tạo bản Snapshot sao lưu Firestore',
      description: 'Tạo bản sao lưu nén tức thời toàn bộ dữ liệu người dùng và thiết bị vào thư mục backups/ an toàn.',
    },

    // SYSTEM
    {
      id: 'get-system-health',
      method: 'GET',
      path: '/api/v1/system/health',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Health check nhịp tim & Uptime máy chủ API',
      description: 'Kiểm tra độ trễ kết nối, trạng thái module MQTT, Firestore và phiên bản hệ thống.',
    },
    {
      id: 'get-system-state',
      method: 'GET',
      path: '/api/v1/system/state',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Duyệt bộ đệm RAM (Timers, Schedules, Tasks)',
      description: 'Đọc trạng thái nội bộ của ZenHome State Manager lưu trữ trên bộ nhớ RAM tốc độ cao.',
    },
    {
      id: 'get-system-app-version',
      method: 'GET',
      path: '/api/v1/system/app-version',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Lấy thông tin phiên bản App di động mới nhất',
      description: 'Cung cấp metadata phiên bản ứng dụng ZenHome (số hiệu build, liên kết tải APK, changelog tiếng Việt/tiếng Anh) cho cơ chế tự động cập nhật OTA.',
    },
    {
      id: 'post-system-app-version',
      method: 'POST',
      path: '/api/v1/system/app-version',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Phát hành phiên bản cập nhật App mới',
      description: 'Đăng ký phiên bản mới, cập nhật changelog, URL tải APK và cấu hình bắt buộc cập nhật (isForceUpdate) lên Firestore và máy chủ.',
      defaultBody: JSON.stringify({
        latestVersion: "1.4.0",
        latestBuildNumber: 140,
        minVersion: "1.3.0",
        minBuildNumber: 130,
        titleVi: "Bản Cập Nhật ZenHome v1.4.0",
        titleEn: "ZenHome Update v1.4.0",
        releaseNotesVi: "• Đồng bộ dữ liệu Cloud Firestore thời gian thực 100%\n• Tăng tốc đăng nhập mượt mà\n• Tự động kiểm tra bản cập nhật",
        releaseNotesEn: "• 100% Realtime Firestore sync\n• Fast login flow\n• In-app OTA updates",
        downloadUrl: "https://github.com/dtthuat/zenhome/releases/latest",
        directApkUrl: "/public/downloads/zenhome-app-release.apk",
        isForceUpdate: false
      }, null, 2),
    },
  ];

  // Khởi tạo endpoint mặc định
  React.useEffect(() => {
    if (!selectedEndpoint && endpoints.length > 0) {
      handleSelectEndpoint(endpoints[0]);
    }
  }, []);

  const handleSelectEndpoint = (ep: EndpointItem) => {
    setSelectedEndpoint(ep);
    setCustomPath(ep.path);
    setRequestBody(ep.defaultBody || '');
    setResponseOutput('');
    setResponseStatus(null);
    setResponseDuration(null);
    setResponseSize(null);
  };

  const filteredEndpoints = useMemo(() => {
    return endpoints.filter(ep => {
      const matchSearch = ep.path.toLowerCase().includes(searchQuery.toLowerCase()) ||
        ep.summary.toLowerCase().includes(searchQuery.toLowerCase()) ||
        ep.categoryLabel.toLowerCase().includes(searchQuery.toLowerCase());
      
      const matchCategory = selectedCategory === 'all' || ep.category === selectedCategory;
      const matchMethod = selectedMethod === 'all' || ep.method === selectedMethod;

      return matchSearch && matchCategory && matchMethod;
    });
  }, [endpoints, searchQuery, selectedCategory, selectedMethod]);

  const executeApiCall = async () => {
    if (!selectedEndpoint) return;
    setIsLoading(true);
    setResponseOutput('Đang kết nối tới ZenHome API Server...');
    setResponseStatus(null);
    setResponseDuration(null);
    setResponseSize(null);

    const startTime = performance.now();
    const targetPath = customPath || selectedEndpoint.path;
    const url = `${serverBaseUrl}${targetPath}`;
    
    const options: RequestInit = {
      method: selectedEndpoint.method,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    };

    if (['POST', 'PUT'].includes(selectedEndpoint.method) && requestBody) {
      try {
        // Validate JSON
        JSON.parse(requestBody);
        options.body = requestBody;
      } catch (e: any) {
        setIsLoading(false);
        setResponseStatus(400);
        setResponseOutput(`❌ Lỗi định dạng JSON không hợp lệ:\n${e.message}`);
        return;
      }
    }

    try {
      const res = await fetch(url, options);
      const endTime = performance.now();
      const duration = Math.round(endTime - startTime);
      setResponseDuration(duration);
      setResponseStatus(res.status);

      const rawText = await res.text();
      setResponseSize(`${(new Blob([rawText]).size / 1024).toFixed(2)} KB`);

      try {
        const jsonData = JSON.parse(rawText);
        setResponseOutput(JSON.stringify(jsonData, null, 2));
      } catch {
        setResponseOutput(rawText);
      }
    } catch (err: any) {
      const endTime = performance.now();
      setResponseDuration(Math.round(endTime - startTime));
      setResponseStatus(500);
      setResponseOutput(`❌ Lỗi kết nối tới Server (${serverBaseUrl}):\n${err.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  const getCurlCommand = () => {
    if (!selectedEndpoint) return '';
    const fullUrl = `${serverBaseUrl}${customPath || selectedEndpoint.path}`;
    let cmd = `curl -X ${selectedEndpoint.method} "${fullUrl}"`;
    cmd += ` \\\n  -H "Content-Type: application/json"`;
    if (['POST', 'PUT'].includes(selectedEndpoint.method) && requestBody) {
      const compactBody = JSON.stringify(JSON.parse(requestBody));
      cmd += ` \\\n  -d '${compactBody}'`;
    }
    return cmd;
  };

  const copyToClipboard = (text: string, type: 'url' | 'curl' | 'json') => {
    navigator.clipboard.writeText(text);
    if (type === 'url') {
      setCopiedUrl(true);
      setTimeout(() => setCopiedUrl(false), 2000);
    } else if (type === 'curl') {
      setCopiedCurl(true);
      setTimeout(() => setCopiedCurl(false), 2000);
    } else if (type === 'json') {
      setCopiedJson(true);
      setTimeout(() => setCopiedJson(false), 2000);
    }
  };

  const formatJsonBody = () => {
    try {
      const parsed = JSON.parse(requestBody);
      setRequestBody(JSON.stringify(parsed, null, 2));
    } catch {
      // Ignored if invalid
    }
  };

  return (
    <div className="p-4 sm:p-6 max-w-7xl mx-auto space-y-6">
      
      {/* ========================================================
          1. HERO HEADER BANNER (Glassmorphic Dark Theme)
          ======================================================== */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 border border-slate-800 p-6 sm:p-8 shadow-2xl text-white">
        {/* Glow ambient background elements */}
        <div className="absolute -top-24 -right-24 w-80 h-80 bg-blue-500/10 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute -bottom-24 -left-24 w-80 h-80 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />

        <div className="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2.5">
              <div className="w-11 h-11 rounded-2xl bg-blue-500/20 border border-blue-400/30 flex items-center justify-center text-blue-400 shadow-lg shadow-blue-500/20">
                <Code2 className="w-6 h-6" />
              </div>
              <span className="text-xs px-3 py-1 rounded-full font-mono font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                PORT 5000: ONLINE
              </span>
              <span className="text-xs px-3 py-1 rounded-full font-mono font-medium bg-blue-500/15 text-blue-300 border border-blue-500/30">
                REST API v1.0
              </span>
              <span className="text-xs px-3 py-1 rounded-full font-mono font-medium bg-purple-500/15 text-purple-300 border border-purple-500/30">
                MQTT TLS 8883
              </span>
            </div>

            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-white drop-shadow-sm">
              Trung Tâm Quản Trị & Thử Nghiệm RESTful API
            </h1>
            <p className="text-sm text-slate-300 max-w-2xl font-normal leading-relaxed">
              Hệ thống REST API đồng bộ hai chiều giữa Web Admin Dashboard, ứng dụng di động Flutter, cơ sở dữ liệu Cloud Firestore và phần cứng ESP32 RTOS.
            </p>
          </div>

          {/* Quick Actions & Navigation Links */}
          <div className="flex flex-wrap items-center gap-2.5 self-start lg:self-center">
            <a
              href={`${serverBaseUrl}/api/v1/openapi.json`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-slate-800/80 hover:bg-slate-700 text-slate-200 hover:text-white rounded-xl text-xs font-semibold transition-all border border-slate-700/80 shadow-md backdrop-blur-sm"
            >
              <FileCode className="w-4 h-4 text-emerald-400" />
              <span>OpenAPI Spec (.json)</span>
            </a>
            <a
              href={`${serverBaseUrl}/api/docs`}
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-blue-600 hover:bg-blue-500 text-white rounded-xl text-xs font-semibold transition-all shadow-lg shadow-blue-600/30"
            >
              <ExternalLink className="w-4 h-4" />
              <span>Mở Swagger Tab Riêng ↗</span>
            </a>
          </div>
        </div>

        {/* Feature Highlights Grid */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-6 pt-6 border-t border-slate-800/80 text-xs">
          <div className="flex items-center gap-2.5 text-slate-300">
            <Cpu className="w-4 h-4 text-emerald-400 shrink-0" />
            <span>ESP32 RTOS Dual-Core</span>
          </div>
          <div className="flex items-center gap-2.5 text-slate-300">
            <Clock className="w-4 h-4 text-blue-400 shrink-0" />
            <span>Centralized Cron & RAM Timers</span>
          </div>
          <div className="flex items-center gap-2.5 text-slate-300">
            <Database className="w-4 h-4 text-amber-400 shrink-0" />
            <span>100% Real Firestore Data</span>
          </div>
          <div className="flex items-center gap-2.5 text-slate-300">
            <ShieldCheck className="w-4 h-4 text-purple-400 shrink-0" />
            <span>Smart LWT Debounce & GDPR</span>
          </div>
        </div>
      </div>

      {/* ========================================================
          2. SEGMENTED TABS NAVIGATION (Playground / Swagger / Specs)
          ======================================================== */}
      <div className="flex items-center justify-between flex-wrap gap-4 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-2 rounded-2xl shadow-sm">
        <div className="flex items-center gap-1.5 flex-wrap">
          <button
            onClick={() => setActiveTab('playground')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'playground'
                ? 'bg-blue-600 text-white shadow-md shadow-blue-500/20'
                : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            <Play className="w-3.5 h-3.5 fill-current" />
            <span>Trình Thử Nghiệm Trực Quan (Interactive Playground)</span>
          </button>
          
          <button
            onClick={() => setActiveTab('swagger')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'swagger'
                ? 'bg-blue-600 text-white shadow-md shadow-blue-500/20'
                : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            <Terminal className="w-3.5 h-3.5" />
            <span>Swagger UI Toàn Diện (OpenAPI 3.0)</span>
          </button>

          <button
            onClick={() => setActiveTab('architecture')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'architecture'
                ? 'bg-blue-600 text-white shadow-md shadow-blue-500/20'
                : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Kiến Trúc & Luồng Dữ Liệu</span>
          </button>
        </div>

        <div className="text-xs text-slate-500 dark:text-slate-400 font-mono hidden md:block px-2">
          Origin: <strong className="text-slate-700 dark:text-slate-300">{serverBaseUrl}</strong>
        </div>
      </div>

      {/* ========================================================
          3. TAB 1: INTERACTIVE API PLAYGROUND
          ======================================================== */}
      {activeTab === 'playground' && (
        <div className="space-y-4">
          
          {/* Search & Filter Bar */}
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-4 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Tìm kiếm endpoint theo URL, chức năng (vd: /devices, users, control, telemetry)..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div className="flex items-center gap-2 overflow-x-auto pb-1 md:pb-0">
              {/* Category selector */}
              <select
                value={selectedCategory}
                onChange={e => setSelectedCategory(e.target.value)}
                className="text-xs bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-slate-700 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="all">Tất cả danh mục ({endpoints.length})</option>
                <option value="users">Người Dùng (Users)</option>
                <option value="devices">Thiết Bị (Devices)</option>
                <option value="scenes">Ngữ Cảnh (Scenes)</option>
                <option value="schedules">Lịch Trình & Timers</option>
                <option value="alerts">Cảnh Báo & Lịch Sử</option>
                <option value="hub">Hub ESP32</option>
                <option value="backup">Máy Chủ Backup</option>
                <option value="system">Hệ Thống</option>
              </select>

              {/* Method filter */}
              <select
                value={selectedMethod}
                onChange={e => setSelectedMethod(e.target.value)}
                className="text-xs bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-slate-700 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono font-semibold"
              >
                <option value="all">Tất cả Methods</option>
                <option value="GET">GET</option>
                <option value="POST">POST</option>
                <option value="PUT">PUT</option>
                <option value="DELETE">DELETE</option>
              </select>
            </div>
          </div>

          {/* Two-Column Studio Layout */}
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
            
            {/* Left Column: Categorized Endpoints List */}
            <div className="lg:col-span-5 space-y-2.5 max-h-[750px] overflow-y-auto pr-1">
              <div className="flex items-center justify-between px-1 text-xs font-semibold text-slate-500 dark:text-slate-400">
                <span>DANH SÁCH ENDPOINTS ({filteredEndpoints.length})</span>
                <span>Click để kiểm thử</span>
              </div>

              {filteredEndpoints.length === 0 ? (
                <div className="p-8 text-center text-slate-400 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 text-xs">
                  Không tìm thấy endpoint nào phù hợp với bộ lọc.
                </div>
              ) : (
                filteredEndpoints.map(ep => {
                  const isSelected = selectedEndpoint?.id === ep.id;
                  return (
                    <button
                      key={ep.id}
                      onClick={() => handleSelectEndpoint(ep)}
                      className={`w-full text-left p-3.5 rounded-2xl border transition-all flex flex-col gap-1.5 ${
                        isSelected
                          ? 'bg-blue-50/70 dark:bg-blue-950/30 border-blue-500 shadow-md ring-1 ring-blue-500/20'
                          : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2 overflow-hidden">
                          <span
                            className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded-md ${
                              ep.method === 'GET'
                                ? 'bg-blue-100 dark:bg-blue-900/50 text-blue-700 dark:text-blue-300 border border-blue-300 dark:border-blue-800'
                                : ep.method === 'POST'
                                ? 'bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800'
                                : ep.method === 'PUT'
                                ? 'bg-amber-100 dark:bg-amber-900/50 text-amber-700 dark:text-amber-300 border border-amber-300 dark:border-amber-800'
                                : 'bg-rose-100 dark:bg-rose-900/50 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-800'
                            }`}
                          >
                            {ep.method}
                          </span>
                          <span className="font-mono text-xs font-semibold text-slate-900 dark:text-slate-100 truncate">
                            {ep.path}
                          </span>
                        </div>
                        <span className="text-[10px] text-slate-400 font-medium shrink-0 bg-slate-100 dark:bg-slate-800 px-2 py-0.5 rounded-full">
                          {ep.categoryLabel}
                        </span>
                      </div>

                      <p className="text-xs text-slate-600 dark:text-slate-400 line-clamp-1 font-medium">
                        {ep.summary}
                      </p>
                    </button>
                  );
                })
              )}
            </div>

            {/* Right Column: Interactive Tester Console */}
            <div className="lg:col-span-7 space-y-4">
              {selectedEndpoint ? (
                <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-5 sm:p-6 shadow-sm space-y-5">
                  
                  {/* Endpoint Header & Description */}
                  <div className="space-y-2 pb-4 border-b border-slate-100 dark:border-slate-800">
                    <div className="flex items-center justify-between flex-wrap gap-2">
                      <div className="flex items-center gap-2.5">
                        <span
                          className={`text-xs font-mono font-bold px-2.5 py-1 rounded-lg ${
                            selectedEndpoint.method === 'GET'
                              ? 'bg-blue-500 text-white'
                              : selectedEndpoint.method === 'POST'
                              ? 'bg-emerald-600 text-white'
                              : selectedEndpoint.method === 'PUT'
                              ? 'bg-amber-600 text-white'
                              : 'bg-rose-600 text-white'
                          }`}
                        >
                          {selectedEndpoint.method}
                        </span>
                        <h2 className="text-base font-bold text-slate-900 dark:text-slate-100">
                          {selectedEndpoint.summary}
                        </h2>
                      </div>
                      <span className="text-xs font-semibold text-blue-500 bg-blue-50 dark:bg-blue-950/50 px-2.5 py-1 rounded-full border border-blue-200 dark:border-blue-900">
                        {selectedEndpoint.categoryLabel}
                      </span>
                    </div>

                    <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                      {selectedEndpoint.description}
                    </p>
                  </div>

                  {/* Interactive URL Bar */}
                  <div className="space-y-1.5">
                    <label className="text-xs font-semibold text-slate-700 dark:text-slate-300">
                      Đường dẫn gọi API (Request URL):
                    </label>
                    <div className="flex items-center gap-2">
                      <div className="flex-1 flex items-center bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 font-mono text-xs overflow-hidden">
                        <span className="text-slate-400 shrink-0 select-none">{serverBaseUrl}</span>
                        <input
                          type="text"
                          value={customPath}
                          onChange={e => setCustomPath(e.target.value)}
                          className="bg-transparent text-blue-600 dark:text-blue-400 font-semibold focus:outline-none w-full pl-0.5"
                        />
                      </div>
                      <button
                        onClick={() => copyToClipboard(`${serverBaseUrl}${customPath}`, 'url')}
                        title="Sao chép URL đầy đủ"
                        className="p-2.5 rounded-xl border border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-500 transition-all"
                      >
                        {copiedUrl ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>

                  {/* Request Body Editor (For POST/PUT) */}
                  {['POST', 'PUT'].includes(selectedEndpoint.method) && (
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <label className="text-xs font-semibold text-slate-700 dark:text-slate-300 flex items-center gap-1.5">
                          <span>Request Body (JSON Payload):</span>
                          <span className="text-[10px] text-emerald-500 font-mono">application/json</span>
                        </label>
                        <div className="flex items-center gap-2">
                          <button
                            onClick={formatJsonBody}
                            className="text-[11px] font-medium text-blue-500 hover:underline"
                          >
                            Định dạng JSON
                          </button>
                          <button
                            onClick={() => setRequestBody(selectedEndpoint.defaultBody || '')}
                            className="text-[11px] font-medium text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
                          >
                            Đặt lại mẫu
                          </button>
                        </div>
                      </div>
                      <textarea
                        value={requestBody}
                        onChange={e => setRequestBody(e.target.value)}
                        rows={6}
                        placeholder='{\n  "key": "value"\n}'
                        className="w-full font-mono text-xs p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500 shadow-inner"
                      />
                    </div>
                  )}

                  {/* Execution Control & cURL Action */}
                  <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
                    <button
                      onClick={() => copyToClipboard(getCurlCommand(), 'curl')}
                      className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 border border-slate-200 dark:border-slate-800 transition-all"
                    >
                      {copiedCurl ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Terminal className="w-3.5 h-3.5 text-blue-500" />}
                      <span>{copiedCurl ? 'Đã sao chép cURL' : 'Sao chép lệnh cURL'}</span>
                    </button>

                    <button
                      onClick={executeApiCall}
                      disabled={isLoading}
                      className="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition-all shadow-lg shadow-emerald-600/30 active:scale-95"
                    >
                      {isLoading ? (
                        <RefreshCw className="w-4 h-4 animate-spin" />
                      ) : (
                        <Play className="w-4 h-4 fill-current" />
                      )}
                      <span>{isLoading ? 'Đang gửi Request...' : 'Gửi Request Thực Tế'}</span>
                    </button>
                  </div>

                  {/* Response Console Display */}
                  <div className="space-y-2 pt-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <label className="text-xs font-semibold text-slate-700 dark:text-slate-300">
                          Kết quả phản hồi (Response):
                        </label>
                        {responseStatus !== null && (
                          <span
                            className={`text-[10px] font-mono px-2 py-0.5 rounded-md font-bold ${
                              responseStatus >= 200 && responseStatus < 300
                                ? 'bg-emerald-100 dark:bg-emerald-900/50 text-emerald-700 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800'
                                : 'bg-rose-100 dark:bg-rose-900/50 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-800'
                            }`}
                          >
                            HTTP {responseStatus}
                          </span>
                        )}
                        {responseDuration !== null && (
                          <span className="text-[10px] font-mono text-slate-400">
                            ⏱️ {responseDuration} ms
                          </span>
                        )}
                        {responseSize && (
                          <span className="text-[10px] font-mono text-slate-400">
                            📦 {responseSize}
                          </span>
                        )}
                      </div>

                      {responseOutput && (
                        <button
                          onClick={() => copyToClipboard(responseOutput, 'json')}
                          className="text-xs text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 flex items-center gap-1 font-medium"
                        >
                          {copiedJson ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                          <span>{copiedJson ? 'Đã sao chép' : 'Sao chép JSON'}</span>
                        </button>
                      )}
                    </div>

                    <pre className="font-mono text-xs p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-950 text-emerald-400 overflow-x-auto min-h-[180px] max-h-[380px] leading-relaxed shadow-inner">
                      {responseOutput || '// Bấm nút "Gửi Request Thực Tế" để xem dữ liệu trả về từ máy chủ...'}
                    </pre>
                  </div>
                </div>
              ) : (
                <div className="p-16 text-center text-slate-400 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl space-y-3">
                  <Code2 className="w-12 h-12 mx-auto opacity-30 text-blue-500" />
                  <h3 className="text-base font-bold text-slate-700 dark:text-slate-300">Chưa chọn Endpoint</h3>
                  <p className="text-xs text-slate-500 max-w-sm mx-auto">
                    Hãy bấm chọn một Endpoint trong danh mục bên trái để bắt đầu kiểm thử gọi API trực tiếp.
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ========================================================
          4. TAB 2: SWAGGER UI EMBEDDED (Seamless Dark Mode)
          ======================================================== */}
      {activeTab === 'swagger' && (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl space-y-0">
          {/* Polished Swagger Container Toolbar */}
          <div className="px-5 py-3.5 bg-slate-950/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-400 flex-wrap gap-3">
            <div className="flex items-center gap-2.5">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="font-bold text-slate-200">Swagger UI Interactive Explorer (OpenAPI 3.0)</span>
              <span className="px-2 py-0.5 rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/20 text-[10px] font-mono">
                Đồng bộ Dark Theme
              </span>
            </div>

            <div className="flex items-center gap-2">
              <button
                onClick={() => setIframeKey(k => k + 1)}
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 transition-all font-semibold"
                title="Tải lại tài liệu Swagger"
              >
                <RefreshCw className="w-3.5 h-3.5" />
                <span>Tải lại</span>
              </button>

              <a
                href={`${serverBaseUrl}/api/docs`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-blue-600/20 hover:bg-blue-600/30 text-blue-400 border border-blue-500/30 transition-all font-semibold"
              >
                <ExternalLink className="w-3.5 h-3.5" />
                <span>Mở tab độc lập</span>
              </a>
            </div>
          </div>

          {/* Embedded Iframe */}
          <iframe
            key={iframeKey}
            src={`${serverBaseUrl}/api/docs?embedded=true`}
            title="ZenHome Swagger UI Interactive Documentation"
            className="w-full h-[850px] border-0 bg-[#0b0f19]"
          />
        </div>
      )}

      {/* ========================================================
          5. TAB 3: ARCHITECTURE & SYSTEM DATA FLOW
          ======================================================== */}
      {activeTab === 'architecture' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            
            {/* Box 1 */}
            <div className="p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3 shadow-sm">
              <div className="w-10 h-10 rounded-xl bg-blue-500/10 text-blue-500 flex items-center justify-center font-bold">
                01
              </div>
              <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                Mobile App (Flutter)
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                Giao tiếp qua HTTP REST API (Port 5000) để tải hồ sơ, đăng nhập và xuất dữ liệu. Nhận phản hồi trạng thái thiết bị tức thì qua MQTT TLS 8883.
              </p>
            </div>

            {/* Box 2 */}
            <div className="p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3 shadow-sm">
              <div className="w-10 h-10 rounded-xl bg-emerald-500/10 text-emerald-500 flex items-center justify-center font-bold">
                02
              </div>
              <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                Web Admin & Socket.IO
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                Tích hợp trên cổng 5000 duy nhất, cung cấp giao diện quản trị realtime, nhận telemetry nhiệt độ DHT11 qua Socket.IO mà không cần polling liên tục.
              </p>
            </div>

            {/* Box 3 */}
            <div className="p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3 shadow-sm">
              <div className="w-10 h-10 rounded-xl bg-amber-500/10 text-amber-500 flex items-center justify-center font-bold">
                03
              </div>
              <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                ESP32 RTOS & LittleFS
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                Hỗ trợ cả định dạng JSON lẫn chuỗi nén raw, Smart LWT 35s chống báo động giả khi WiFi chập chờn, lưu bản đồ chân phần cứng trong bộ nhớ flash LittleFS.
              </p>
            </div>

            {/* Box 4 */}
            <div className="p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3 shadow-sm">
              <div className="w-10 h-10 rounded-xl bg-purple-500/10 text-purple-500 flex items-center justify-center font-bold">
                04
              </div>
              <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                Cloud Firestore & Backup
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                Lưu trữ toàn bộ dữ liệu cấu hình, kịch bản và thiết bị 100% thực tế. Định kỳ sao lưu snapshot độc lập và tự động xóa dữ liệu tuân thủ GDPR.
              </p>
            </div>
          </div>

          {/* Detailed Security & Protocol Specifications */}
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 shadow-sm space-y-4">
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-emerald-500" />
              Tiêu Chuẩn Bảo Mật & Tối Ưu Hóa Tài Nguyên
            </h3>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs text-slate-600 dark:text-slate-400">
              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2">
                <strong className="text-slate-900 dark:text-slate-200 block text-xs">
                  🛡️ Rate Limiter thông minh:
                </strong>
                <p>
                  Whitelist an toàn tuyệt đối cho localhost (127.0.0.1, ::1) và các phiên Admin Token, nâng giới hạn lên 2000 requests / 15 phút để đảm bảo không bị nghẽn HTTP 429 khi thao tác nhanh.
                </p>
              </div>

              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2">
                <strong className="text-slate-900 dark:text-slate-200 block text-xs">
                  ⚡ Smart LWT Debounce (35 giây):
                </strong>
                <p>
                  Lọc bỏ hiện tượng ESP32 bị reset WiFi thoáng qua, chỉ gửi cảnh báo Offline lên Firestore khi thiết bị thực sự ngắt kết nối quá 35 giây, tiết kiệm hàng nghìn lượt ghi cơ sở dữ liệu.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
