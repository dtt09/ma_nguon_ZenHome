import { getServerBaseUrl, getAdminSecret } from '../../services/backupServerService';
import React, { useState, useMemo, useEffect } from 'react';
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
  Key,
  Lock,
  User,
  ShieldAlert,
  Send,
  Zap
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

interface SubsystemPingItem {
  key: string;
  label: string;
  path: string;
  status: 'idle' | 'pinging' | 'online' | 'error';
  latencyMs?: number;
  httpStatus?: number;
}

export const ApiDocsView: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'playground' | 'swagger' | 'architecture'>('playground');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [selectedMethod, setSelectedMethod] = useState<string>('all');
  
  // Auth Mode Selector State (SEC-06: Zero-Trust Security Playground)
  const [authMode, setAuthMode] = useState<'admin' | 'user' | 'none' | 'custom'>('admin');
  const [customToken, setCustomToken] = useState<string>('');
  const [userToken, setUserToken] = useState<string>('demo_user_token_uid');

  // Code Snippet Generator Language Tab
  const [codeLang, setCodeLang] = useState<'curl' | 'dart' | 'ts' | 'python'>('curl');

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
  const [copiedSnippet, setCopiedSnippet] = useState<boolean>(false);
  const [copiedJson, setCopiedJson] = useState<boolean>(false);
  const [iframeKey, setIframeKey] = useState<number>(1);

  const serverBaseUrl = getServerBaseUrl();

  // 9 Subsystems Live Health Monitor State
  const [isPingingAll, setIsPingingAll] = useState<boolean>(false);
  const [subsystemPings, setSubsystemPings] = useState<SubsystemPingItem[]>([
    { key: 'users', label: 'Users', path: '/api/v1/users', status: 'idle' },
    { key: 'devices', label: 'Devices', path: '/api/v1/devices?userId=dtthuat', status: 'idle' },
    { key: 'scenes', label: 'Scenes', path: '/api/v1/scenes?userId=dtthuat', status: 'idle' },
    { key: 'schedules', label: 'Schedules', path: '/api/v1/schedules', status: 'idle' },
    { key: 'timers', label: 'Timers', path: '/api/v1/timers', status: 'idle' },
    { key: 'alerts', label: 'Alerts', path: '/api/v1/alerts?userId=dtthuat', status: 'idle' },
    { key: 'hub', label: 'Hub ESP32', path: '/api/v1/hub/status', status: 'idle' },
    { key: 'backup', label: 'Backup', path: '/api/v1/backup/status', status: 'idle' },
    { key: 'system', label: 'System', path: '/api/v1/system/health', status: 'idle' },
  ]);

  const endpoints: EndpointItem[] = [
    // 1. USERS
    {
      id: 'get-users',
      method: 'GET',
      path: '/api/v1/users',
      category: 'users',
      categoryLabel: 'Người Dùng',
      summary: 'Lấy danh sách tất cả tài khoản từ Firestore (Yêu cầu Admin)',
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

    // 2. DEVICES
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
      summary: 'Thêm thiết bị mới vào Firestore (Kiểm tra chân GPIO)',
      description: 'Đăng ký một thiết bị mới gán chân GPIO (0-39) và phòng cụ thể trong Firestore.',
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
      id: 'post-devices-bulk',
      method: 'POST',
      path: '/api/v1/devices/bulk',
      category: 'devices',
      categoryLabel: 'Thiết Bị',
      summary: 'Điều khiển Bật/Tắt hàng loạt thiết bị (Theo phòng hoặc toàn nhà)',
      description: 'Thực thi lệnh hàng loạt: all_on, all_off, room_on, room_off tới toàn bộ thiết bị thực tế trong phòng.',
      defaultBody: JSON.stringify({
        action: "all_off",
        userId: "dtthuat",
        source: "api_bulk"
      }, null, 2),
    },
    {
      id: 'get-device-telemetry',
      method: 'GET',
      path: '/api/v1/devices/telemetry/status?userId=dtthuat',
      category: 'devices',
      categoryLabel: 'Thiết Bị',
      summary: 'Đọc chỉ số cảm biến DHT11 & Cảnh báo cháy tự động',
      description: 'Truy vấn nhiệt độ môi trường thời gian thực được cập nhật từ phần cứng qua MQTT và trạng thái cảnh báo hỏa hoạn (>= 50°C).',
    },

    // 3. SCENES
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
      id: 'post-scene-create',
      method: 'POST',
      path: '/api/v1/scenes',
      category: 'scenes',
      categoryLabel: 'Ngữ Cảnh',
      summary: 'Tạo kịch bản / ngữ cảnh tự động hóa mới',
      description: 'Khai báo ngữ cảnh kèm danh sách hành động đóng/ngắt các rơ-le cụ thể lưu vào Firestore.',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        id: "scene_tiep_khach",
        name: "Tiếp Khách Trang Trọng",
        description: "Bật đèn phòng khách và quạt trần",
        actions: [
          { deviceId: "den_tran", room: "phong_khach", state: "1" },
          { deviceId: "quat_tran", room: "phong_khach", state: "1" }
        ]
      }, null, 2),
    },
    {
      id: 'post-scene-trigger',
      method: 'POST',
      path: '/api/v1/scenes/scene_tiep_khach/execute',
      category: 'scenes',
      categoryLabel: 'Ngữ Cảnh',
      summary: 'Kích hoạt thực thi ngữ cảnh tự động',
      description: 'Thực thi tuần tự các hành động đóng cắt relay đã lập trình trong ngữ cảnh qua MQTT.',
      defaultBody: JSON.stringify({
        userId: "dtthuat"
      }, null, 2),
    },

    // 4. SCHEDULES & TIMERS
    {
      id: 'get-schedules',
      method: 'GET',
      path: '/api/v1/schedules',
      category: 'schedules',
      categoryLabel: 'Lịch Trình',
      summary: 'Lấy danh sách lịch trình tự động tập trung (Cron)',
      description: 'Truy vấn các lịch trình bật/tắt định kỳ được đồng bộ giữa Cloud Firestore và bộ nhớ RAM máy chủ.',
    },
    {
      id: 'post-schedule-create',
      method: 'POST',
      path: '/api/v1/schedules',
      category: 'schedules',
      categoryLabel: 'Lịch Trình',
      summary: 'Tạo lịch trình bật/tắt định kỳ mới',
      description: 'Lên lịch tự động bật hoặc tắt thiết bị vào khung giờ cụ thể và lặp lại theo ngày trong tuần.',
      defaultBody: JSON.stringify({
        baseTopic: "dtthuat/ESP32_MAC/phong_khach/den_tran",
        timeOn: "06:30",
        timeOff: "22:45",
        days: "1111111"
      }, null, 2),
    },
    {
      id: 'get-timers',
      method: 'GET',
      path: '/api/v1/timers',
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
        baseTopic: "dtthuat/ESP32_MAC/phong_khach/quat_tran",
        action: "0",
        minutes: 15
      }, null, 2),
    },

    // 5. ALERTS & HISTORY
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
      id: 'post-alert-create',
      method: 'POST',
      path: '/api/v1/alerts',
      category: 'alerts',
      categoryLabel: 'Cảnh Báo',
      summary: 'Tạo bản ghi cảnh báo an toàn mới',
      description: 'Ghi nhận sự cố kỹ thuật hoặc cảnh báo an toàn vào cơ sở dữ liệu của người dùng.',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        type: "SECURITY_FIRE",
        title: "Cảnh Báo Nhiệt Độ Phòng Khách Vượt Ngưỡng",
        message: "Nhiệt độ đo được 51.5°C tại phòng khách. Tự động kích hoạt cơ chế ngắt tải.",
        level: "danger"
      }, null, 2),
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

    // 6. HUB ESP32
    {
      id: 'get-hub-status',
      method: 'GET',
      path: '/api/v1/hub/status?userId=dtthuat',
      category: 'hub',
      categoryLabel: 'Hub ESP32',
      summary: 'Kiểm tra trạng thái kết nối phần cứng ESP32',
      description: 'Giám sát nhịp tim (Keepalive), trạng thái Online/Offline, địa chỉ MAC và nhiệt độ phòng qua kênh MQTT.',
    },
    {
      id: 'post-hub-link',
      method: 'POST',
      path: '/api/v1/hub/link',
      category: 'hub',
      categoryLabel: 'Hub ESP32',
      summary: 'Liên kết địa chỉ MAC của ESP32 với chủ nhà (Bảo vệ IDOR)',
      description: 'Gắn định danh vi điều khiển thực tế vào tài khoản người dùng trong Firestore (được kiểm tra định dạng MAC chặt chẽ).',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        macAddress: "24:6F:28:4C:75:A0"
      }, null, 2),
    },
    {
      id: 'post-hub-reset',
      method: 'POST',
      path: '/api/v1/hub/reset',
      category: 'hub',
      categoryLabel: 'Hub ESP32',
      summary: 'Phát lệnh Factory Reset từ xa tới ESP32 (Bảo vệ Zero-Trust)',
      description: 'Gửi tín hiệu Factory Reset xóa cấu hình WiFi và khôi phục cài đặt gốc của vi điều khiển ESP32 qua kênh MQTT an toàn.',
      defaultBody: JSON.stringify({
        userId: "dtthuat"
      }, null, 2),
    },
    {
      id: 'post-hub-config',
      method: 'POST',
      path: '/api/v1/hub/config',
      category: 'hub',
      categoryLabel: 'Hub ESP32',
      summary: 'Đẩy cấu hình chân LittleFS xuống ESP32',
      description: 'Nạp lại bản đồ chân GPIO linh hoạt xuống bộ nhớ flash LittleFS của vi điều khiển.',
      defaultBody: JSON.stringify({
        userId: "dtthuat",
        devices: [
          { id: "den_bep", pin: 2 },
          { id: "quat_tran", pin: 4 }
        ]
      }, null, 2),
    },

    // 7. BACKUP SERVER
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
      summary: 'Kích hoạt tạo bản Snapshot sao lưu Firestore (Admin Auth)',
      description: 'Tạo bản sao lưu nén tức thời toàn bộ dữ liệu người dùng và thiết bị vào thư mục backups/ an toàn.',
    },

    // 8. SYSTEM
    {
      id: 'get-system-health',
      method: 'GET',
      path: '/api/v1/system/health',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Health check nhịp tim & Uptime máy chủ API (Công khai)',
      description: 'Kiểm tra độ trễ kết nối, trạng thái module MQTT, Firestore và phiên bản hệ thống.',
    },
    {
      id: 'get-system-state',
      method: 'GET',
      path: '/api/v1/system/state',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Duyệt bộ đệm RAM (Timers, Schedules, Tasks) (Yêu cầu Auth)',
      description: 'Đọc trạng thái nội bộ của ZenHome State Manager lưu trữ trên bộ nhớ RAM tốc độ cao.',
    },
    {
      id: 'get-system-logs',
      method: 'GET',
      path: '/api/v1/system/logs?limit=50',
      category: 'system',
      categoryLabel: 'Hệ Thống',
      summary: 'Lấy nhật ký sự kiện máy chủ thời gian thực (Yêu cầu Admin)',
      description: 'Truy vấn nhật ký sự kiện, kiểm tra log kết nối MQTT và log đóng ngắt rơ-le (Đã khóa bảo mật chống rò rỉ thông tin).',
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
      summary: 'Phát hành phiên bản cập nhật App mới (Admin Auth)',
      description: 'Đăng ký phiên bản mới, cập nhật changelog, URL tải APK và cấu hình bắt buộc cập nhật (isForceUpdate) lên Firestore và máy chủ.',
      defaultBody: JSON.stringify({
        latestVersion: "1.7.2",
        latestBuildNumber: 172,
        minVersion: "1.6.0",
        minBuildNumber: 160,
        titleVi: "Bản Cập Nhật ZenHome v1.7.2 - Củng Cố Bảo Mật API",
        titleEn: "ZenHome Update v1.7.2 - Zero-Trust API Security",
        releaseNotesVi: "• Bảo vệ Zero-Trust cho toàn bộ endpoint phần cứng\n• Chống tấn công giả mạo IDOR\n• Đồng bộ hoàn hảo cổng 3000 và 5000",
        releaseNotesEn: "• Zero-Trust security across all hardware endpoints\n• IDOR defense enabled\n• Full port 3000-5000 sync",
        downloadUrl: "https://github.com/dtthuat/zenhome/releases/latest",
        directApkUrl: "/public/downloads/zenhome-app-release.apk",
        isForceUpdate: false
      }, null, 2),
    },
  ];

  // Khởi tạo endpoint mặc định
  useEffect(() => {
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

  // Lấy chuỗi token Authorization tương ứng theo authMode
  const getActiveAuthHeader = (): string => {
    if (authMode === 'admin') {
      const secret = getAdminSecret();
      return secret ? `Bearer ${secret}` : '';
    }
    if (authMode === 'user') {
      return `Bearer ${userToken.trim()}`;
    }
    if (authMode === 'custom') {
      const trimmed = customToken.trim();
      if (!trimmed) return '';
      return trimmed.startsWith('Bearer ') ? trimmed : `Bearer ${trimmed}`;
    }
    return ''; // 'none'
  };

  // Thực thi kiểm thử API call thực tế
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
    
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    const authHeader = getActiveAuthHeader();
    if (authHeader) {
      headers['Authorization'] = authHeader;
      // Kèm header x-api-key dự phòng
      headers['x-api-key'] = authHeader.replace(/^Bearer\s+/i, '');
    }

    const options: RequestInit = {
      method: selectedEndpoint.method,
      headers,
    };

    if (['POST', 'PUT'].includes(selectedEndpoint.method) && requestBody) {
      try {
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

  // Chức năng Ping kiểm tra độ trễ 9 phân hệ đồng thời
  const pingAllSubsystems = async () => {
    setIsPingingAll(true);
    const authHeader = getAdminSecret() ? `Bearer ${getAdminSecret()}` : '';

    const updated = await Promise.all(
      subsystemPings.map(async (item) => {
        const start = performance.now();
        try {
          const controller = new AbortController();
          const timeout = setTimeout(() => controller.abort(), 4000);
          const res = await fetch(`${serverBaseUrl}${item.path}`, {
            method: 'GET',
            headers: {
              'Accept': 'application/json',
              'Authorization': authHeader,
            },
            signal: controller.signal,
          });
          clearTimeout(timeout);
          const rtt = Math.round(performance.now() - start);
          return {
            ...item,
            status: (res.ok ? 'online' : 'error') as 'online' | 'error',
            latencyMs: rtt,
            httpStatus: res.status,
          };
        } catch (e) {
          return {
            ...item,
            status: 'error' as 'error',
            latencyMs: Math.round(performance.now() - start),
            httpStatus: 0,
          };
        }
      })
    );

    setSubsystemPings(updated);
    setIsPingingAll(false);
  };

  // Trình sinh mã đa ngôn ngữ (Multi-Language Code Snippet Generator)
  const getGeneratedCode = (): string => {
    if (!selectedEndpoint) return '';
    const fullUrl = `${serverBaseUrl}${customPath || selectedEndpoint.path}`;
    const authHeader = getActiveAuthHeader();
    const hasBody = ['POST', 'PUT'].includes(selectedEndpoint.method) && requestBody;
    const bodyObj = hasBody ? (() => { try { return JSON.parse(requestBody); } catch { return {}; } })() : null;

    if (codeLang === 'curl') {
      let cmd = `curl -X ${selectedEndpoint.method} "${fullUrl}"`;
      cmd += ` \\\n  -H "Content-Type: application/json"`;
      if (authHeader) {
        cmd += ` \\\n  -H "Authorization: ${authHeader}"`;
      }
      if (hasBody) {
        cmd += ` \\\n  -d '${JSON.stringify(bodyObj)}'`;
      }
      return cmd;
    }

    if (codeLang === 'dart') {
      return `import 'dart:convert';\nimport 'package:http/http.dart' as http;\n\nFuture<void> sendApiRequest() async {\n  final url = Uri.parse('${fullUrl}');\n  final headers = {\n    'Content-Type': 'application/json',\n${authHeader ? `    'Authorization': '${authHeader}',\n` : ''}  };\n\n  final response = await http.${selectedEndpoint.method.toLowerCase()}(\n    url,\n    headers: headers,${hasBody ? `\n    body: jsonEncode(${JSON.stringify(bodyObj, null, 2)}),` : ''}\n  );\n\n  print('Status: \${response.statusCode}');\n  print('Response: \${response.body}');\n}`;
    }

    if (codeLang === 'ts') {
      return `const sendRequest = async () => {\n  const res = await fetch('${fullUrl}', {\n    method: '${selectedEndpoint.method}',\n    headers: {\n      'Content-Type': 'application/json',\n${authHeader ? `      'Authorization': '${authHeader}',\n` : ''}    },${hasBody ? `\n    body: JSON.stringify(${JSON.stringify(bodyObj, null, 2)}),` : ''}\n  });\n\n  const data = await res.json();\n  console.log('Response:', data);\n};`;
    }

    if (codeLang === 'python') {
      return `import requests\n\nurl = "${fullUrl}"\nheaders = {\n    "Content-Type": "application/json",\n${authHeader ? `    "Authorization": "${authHeader}",\n` : ''}}\n${hasBody ? `payload = ${JSON.stringify(bodyObj, null, 4)}\n` : ''}\nresponse = requests.${selectedEndpoint.method.toLowerCase()}(\n    url,\n    headers=headers,${hasBody ? `\n    json=payload` : ''}\n)\n\nprint(f"Status: {response.status_code}")\nprint(response.json())`;
    }

    return '';
  };

  const copyToClipboard = (text: string, type: 'url' | 'snippet' | 'json') => {
    navigator.clipboard.writeText(text);
    if (type === 'url') {
      setCopiedUrl(true);
      setTimeout(() => setCopiedUrl(false), 2000);
    } else if (type === 'snippet') {
      setCopiedSnippet(true);
      setTimeout(() => setCopiedSnippet(false), 2000);
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
      
      {/* 1. HERO HEADER BANNER (Glassmorphic Cyber-Minimalist Bento) */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-slate-900 via-indigo-950 to-slate-900 border border-slate-800 p-6 sm:p-8 shadow-2xl text-white">
        <div className="absolute -top-24 -right-24 w-80 h-80 bg-sky-500/10 rounded-full blur-3xl pointer-events-none" />
        <div className="absolute -bottom-24 -left-24 w-80 h-80 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />

        <div className="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div className="space-y-3">
            <div className="flex flex-wrap items-center gap-2.5">
              <div className="w-11 h-11 rounded-2xl bg-sky-500/20 border border-sky-400/30 flex items-center justify-center text-sky-400 shadow-lg shadow-sky-500/20">
                <Code2 className="w-6 h-6" />
              </div>
              <span className="text-xs px-3 py-1 rounded-full font-mono font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
                PORT 5000: ONLINE
              </span>
              <span className="text-xs px-3 py-1 rounded-full font-mono font-semibold bg-sky-500/15 text-sky-300 border border-sky-500/30">
                Zero-Trust Auth Guard
              </span>
              <span className="text-xs px-3 py-1 rounded-full font-mono font-semibold bg-indigo-500/15 text-indigo-300 border border-indigo-500/30">
                REST API v1.0
              </span>
            </div>

            <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-white drop-shadow-sm">
              Trung Tâm Quản Trị & Thử Nghiệm RESTful API
            </h1>
            <p className="text-sm text-slate-300 max-w-2xl font-normal leading-relaxed">
              Hệ thống REST API đồng bộ hai chiều giữa Web Admin Dashboard, ứng dụng di động Flutter, cơ sở dữ liệu Cloud Firestore và phần cứng ESP32 RTOS.
            </p>
          </div>

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
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-sky-600 hover:bg-sky-500 text-white rounded-xl text-xs font-semibold transition-all shadow-lg shadow-sky-600/30"
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
            <Clock className="w-4 h-4 text-sky-400 shrink-0" />
            <span>Centralized Cron & RAM Timers</span>
          </div>
          <div className="flex items-center gap-2.5 text-slate-300">
            <Database className="w-4 h-4 text-amber-400 shrink-0" />
            <span>100% Real Firestore Data</span>
          </div>
          <div className="flex items-center gap-2.5 text-slate-300">
            <ShieldCheck className="w-4 h-4 text-indigo-400 shrink-0" />
            <span>Zero-Trust Auth & IDOR Guard</span>
          </div>
        </div>
      </div>

      {/* 2. LIVE 9-SUBSYSTEM HEALTH PING BAR (Bento Ribbon) */}
      <div className="rounded-3xl border border-slate-200 dark:border-slate-800/80 bg-white/90 dark:bg-slate-900/80 backdrop-blur-xl p-4 sm:p-5 shadow-sm space-y-3">
        <div className="flex items-center justify-between flex-wrap gap-3">
          <div className="flex items-center gap-2.5">
            <div className="p-1.5 rounded-xl bg-sky-500/10 text-sky-600 dark:text-sky-400 border border-sky-200 dark:border-sky-500/20">
              <Activity className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-xs sm:text-sm font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
                <span>Trạng Thái Độ Trễ 9 Phân Hệ API Thực Tế</span>
                <span className="text-[10px] font-mono px-2 py-0.2 rounded bg-slate-100 dark:bg-slate-800 text-slate-500">RTT Ping Monitor</span>
              </h3>
            </div>
          </div>

          <button
            onClick={pingAllSubsystems}
            disabled={isPingingAll}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold bg-sky-50 dark:bg-sky-950/40 text-sky-700 dark:text-sky-300 border border-sky-200 dark:border-sky-800/60 hover:bg-sky-100 transition-all shadow-sm"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isPingingAll ? 'animate-spin' : ''}`} />
            <span>{isPingingAll ? 'Đang đo RTT...' : 'Đo Độ Trễ 9 Phân Hệ'}</span>
          </button>
        </div>

        {/* 9 Pills */}
        <div className="grid grid-cols-3 sm:grid-cols-5 lg:grid-cols-9 gap-2 pt-1">
          {subsystemPings.map((sub) => {
            const isOnline = sub.status === 'online';
            const isError = sub.status === 'error';
            return (
              <div
                key={sub.key}
                className={`p-2 rounded-2xl border text-center transition-all ${
                  isOnline
                    ? 'bg-emerald-50/60 dark:bg-emerald-950/20 border-emerald-300 dark:border-emerald-800/60 text-emerald-800 dark:text-emerald-300'
                    : isError
                    ? 'bg-rose-50/60 dark:bg-rose-950/20 border-rose-300 dark:border-rose-800/60 text-rose-800 dark:text-rose-300'
                    : 'bg-slate-50 dark:bg-slate-950 border-slate-200 dark:border-slate-800 text-slate-500 dark:text-slate-400'
                }`}
              >
                <div className="text-[11px] font-bold truncate">{sub.label}</div>
                <div className="text-[10px] font-mono mt-0.5 flex items-center justify-center gap-1">
                  <span className={`w-1.5 h-1.5 rounded-full ${isOnline ? 'bg-emerald-500 animate-ping' : isError ? 'bg-rose-500' : 'bg-slate-400'}`} />
                  <span>{sub.latencyMs !== undefined ? `${sub.latencyMs}ms` : 'Chưa đo'}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* 3. SEGMENTED TABS NAVIGATION */}
      <div className="flex items-center justify-between flex-wrap gap-4 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-2 rounded-2xl shadow-sm">
        <div className="flex items-center gap-1.5 flex-wrap">
          <button
            onClick={() => setActiveTab('playground')}
            className={`flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all ${
              activeTab === 'playground'
                ? 'bg-sky-600 text-white shadow-md shadow-sky-500/20'
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
                ? 'bg-sky-600 text-white shadow-md shadow-sky-500/20'
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
                ? 'bg-sky-600 text-white shadow-md shadow-sky-500/20'
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

      {/* 4. TAB 1: INTERACTIVE API PLAYGROUND */}
      {activeTab === 'playground' && (
        <div className="space-y-4">
          
          {/* Search & Filter Bar */}
          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-2xl p-4 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-3">
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Tìm kiếm endpoint theo URL, chức năng (vd: /devices, users, reset, telemetry)..."
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                className="w-full pl-10 pr-4 py-2 bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl text-xs text-slate-900 dark:text-slate-100 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-sky-500"
              />
            </div>

            <div className="flex items-center gap-2 overflow-x-auto pb-1 md:pb-0">
              {/* Category selector */}
              <select
                value={selectedCategory}
                onChange={e => setSelectedCategory(e.target.value)}
                className="text-xs bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-slate-700 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-sky-500 font-semibold"
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
                className="text-xs bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 rounded-xl px-3 py-2 text-slate-700 dark:text-slate-300 focus:outline-none focus:ring-2 focus:ring-sky-500 font-mono font-semibold"
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
            <div className="lg:col-span-5 space-y-2.5 max-h-[820px] overflow-y-auto pr-1">
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
                          ? 'bg-sky-50/80 dark:bg-sky-950/30 border-sky-500 shadow-md ring-1 ring-sky-500/20'
                          : 'bg-white dark:bg-slate-900 border-slate-200 dark:border-slate-800 hover:border-slate-300 dark:hover:border-slate-700'
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2">
                        <div className="flex items-center gap-2 overflow-hidden">
                          <span
                            className={`text-[10px] font-mono font-bold px-2 py-0.5 rounded-md ${
                              ep.method === 'GET'
                                ? 'bg-sky-100 dark:bg-sky-900/50 text-sky-700 dark:text-sky-300 border border-sky-300 dark:border-sky-800'
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
                              ? 'bg-sky-500 text-white'
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
                      <span className="text-xs font-semibold text-sky-500 bg-sky-50 dark:bg-sky-950/50 px-2.5 py-1 rounded-full border border-sky-200 dark:border-sky-900">
                        {selectedEndpoint.categoryLabel}
                      </span>
                    </div>

                    <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                      {selectedEndpoint.description}
                    </p>
                  </div>

                  {/* SEC-06: Dynamic Auth Mode Selector (Zero-Trust Security Workbench) */}
                  <div className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2.5 text-xs">
                    <div className="flex items-center justify-between">
                      <span className="font-bold text-slate-700 dark:text-slate-300 flex items-center gap-1.5">
                        <ShieldAlert className="w-3.5 h-3.5 text-sky-500" />
                        <span>Chế Độ Xác Thực Khi Gọi (Authorization Context):</span>
                      </span>
                      <span className="font-mono text-[10px] text-slate-500">
                        {authMode === 'admin' && '🛡️ Super Admin'}
                        {authMode === 'user' && '👤 End User'}
                        {authMode === 'none' && '🚫 Không Token (Test 401)'}
                        {authMode === 'custom' && '✏️ Custom Key'}
                      </span>
                    </div>

                    {/* Segmented Buttons for Auth Mode */}
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-1.5">
                      {[
                        { id: 'admin', label: 'Super Admin', icon: <ShieldCheck className="w-3 h-3 text-sky-500" /> },
                        { id: 'user', label: 'User Token', icon: <User className="w-3 h-3 text-indigo-500" /> },
                        { id: 'none', label: 'No Auth (401)', icon: <Lock className="w-3 h-3 text-rose-500" /> },
                        { id: 'custom', label: 'Tùy Chỉnh', icon: <Key className="w-3 h-3 text-amber-500" /> },
                      ].map((item) => (
                        <button
                          key={item.id}
                          onClick={() => setAuthMode(item.id as any)}
                          className={`p-2 rounded-xl text-xs font-semibold flex items-center justify-center gap-1.5 transition-all border ${
                            authMode === item.id
                              ? 'bg-sky-600 text-white border-sky-600 shadow-sm'
                              : 'bg-white dark:bg-slate-900 text-slate-600 dark:text-slate-400 border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800'
                          }`}
                        >
                          {item.icon}
                          <span>{item.label}</span>
                        </button>
                      ))}
                    </div>

                    {authMode === 'custom' && (
                      <input
                        type="text"
                        placeholder="Nhập Bearer Token hoặc API Key tùy ý..."
                        value={customToken}
                        onChange={(e) => setCustomToken(e.target.value)}
                        className="w-full px-3 py-1.5 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 font-mono text-xs focus:outline-none focus:ring-1 focus:ring-sky-500"
                      />
                    )}
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
                          className="bg-transparent text-sky-600 dark:text-sky-400 font-semibold focus:outline-none w-full pl-0.5"
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
                            className="text-[11px] font-medium text-sky-500 hover:underline"
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
                        className="w-full font-mono text-xs p-3.5 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-sky-500 shadow-inner"
                      />
                    </div>
                  )}

                  {/* Execution Control & Request Trigger */}
                  <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
                    <div className="flex items-center gap-2 text-xs font-mono text-slate-500">
                      <span>Header:</span>
                      <span className="bg-slate-100 dark:bg-slate-800 px-2 py-0.5 rounded text-[11px]">
                        {getActiveAuthHeader() ? 'Authorization: [Active]' : 'Authorization: [None]'}
                      </span>
                    </div>

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

                  {/* Multi-Language Code Snippet Generator */}
                  <div className="p-4 rounded-2xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2.5 text-xs">
                    <div className="flex items-center justify-between flex-wrap gap-2">
                      <div className="flex items-center gap-2 font-bold text-slate-700 dark:text-slate-300">
                        <Terminal className="w-3.5 h-3.5 text-sky-500" />
                        <span>Mã Nguồn Mẫu (Auto-generated Snippet):</span>
                      </div>

                      <div className="flex items-center gap-1 font-mono text-[11px]">
                        {[
                          { id: 'curl', label: 'cURL' },
                          { id: 'dart', label: 'Flutter / Dart' },
                          { id: 'ts', label: 'TypeScript Fetch' },
                          { id: 'python', label: 'Python requests' },
                        ].map((lang) => (
                          <button
                            key={lang.id}
                            onClick={() => setCodeLang(lang.id as any)}
                            className={`px-2 py-0.5 rounded-lg transition-colors ${
                              codeLang === lang.id
                                ? 'bg-sky-600 text-white font-bold'
                                : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
                            }`}
                          >
                            {lang.label}
                          </button>
                        ))}
                      </div>
                    </div>

                    <div className="relative group">
                      <pre className="font-mono text-[11px] p-3 rounded-xl bg-slate-900 text-slate-100 overflow-x-auto max-h-48 border border-slate-800 leading-relaxed">
                        {getGeneratedCode()}
                      </pre>
                      <button
                        onClick={() => copyToClipboard(getGeneratedCode(), 'snippet')}
                        className="absolute top-2 right-2 px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-[10px] font-semibold flex items-center gap-1 transition-all border border-slate-700"
                        title="Sao chép đoạn mã"
                      >
                        {copiedSnippet ? <Check className="w-3 h-3 text-emerald-400" /> : <Copy className="w-3 h-3" />}
                        <span>{copiedSnippet ? 'Đã sao chép' : 'Sao chép'}</span>
                      </button>
                    </div>
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
                  <Code2 className="w-12 h-12 mx-auto opacity-30 text-sky-500" />
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

      {/* 5. TAB 2: SWAGGER UI EMBEDDED */}
      {activeTab === 'swagger' && (
        <div className="bg-slate-900 border border-slate-800 rounded-3xl overflow-hidden shadow-2xl space-y-0">
          <div className="px-5 py-3.5 bg-slate-950/80 border-b border-slate-800 flex items-center justify-between text-xs text-slate-400 flex-wrap gap-3">
            <div className="flex items-center gap-2.5">
              <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="font-bold text-slate-200">Swagger UI Interactive Explorer (OpenAPI 3.0)</span>
              <span className="px-2 py-0.5 rounded-full bg-sky-500/10 text-sky-400 border border-sky-500/20 text-[10px] font-mono">
                Authorize 🔒 Ready
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
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-sky-600/20 hover:bg-sky-600/30 text-sky-400 border border-sky-500/30 transition-all font-semibold"
              >
                <ExternalLink className="w-3.5 h-3.5" />
                <span>Mở tab độc lập</span>
              </a>
            </div>
          </div>

          <iframe
            key={iframeKey}
            src={`${serverBaseUrl}/api/docs?embedded=true`}
            title="ZenHome Swagger UI Interactive Documentation"
            className="w-full h-[850px] border-0 bg-[#0b0f19]"
          />
        </div>
      )}

      {/* 6. TAB 3: ARCHITECTURE & SYSTEM DATA FLOW */}
      {activeTab === 'architecture' && (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="p-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 space-y-3 shadow-sm">
              <div className="w-10 h-10 rounded-xl bg-sky-500/10 text-sky-500 flex items-center justify-center font-bold">
                01
              </div>
              <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                Mobile App (Flutter)
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed">
                Giao tiếp qua HTTP REST API (Port 5000) để tải hồ sơ, đăng nhập và xuất dữ liệu. Nhận phản hồi trạng thái thiết bị tức thì qua MQTT TLS 8883.
              </p>
            </div>

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

          <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 rounded-3xl p-6 shadow-sm space-y-4">
            <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100 flex items-center gap-2">
              <ShieldCheck className="w-4 h-4 text-emerald-500" />
              Tiêu Chuẩn Bảo Mật Zero-Trust & Tối Ưu Hóa Tài Nguyên
            </h3>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs text-slate-600 dark:text-slate-400">
              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2">
                <strong className="text-slate-900 dark:text-slate-200 block text-xs">
                  🛡️ Zero-Trust Access Guard:
                </strong>
                <p>
                  Toàn bộ 9 phân hệ REST API được xác thực bằng Master Key (Admin Secret) hoặc Firebase ID Token. Chống triệt để các hành vi dò quét IDOR/BOLA qua hàm kiểm tra quyền sở hữu đối tượng.
                </p>
              </div>

              <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 space-y-2">
                <strong className="text-slate-900 dark:text-slate-200 block text-xs">
                  ⚡ Adaptive Rate Limiter:
                </strong>
                <p>
                  Tự động nhận diện động mã bảo mật trong file .env và so sánh an toàn Timing-safe (`crypto.timingSafeEqual`), bỏ qua chặn rate limit cho phiên Admin đang đăng nhập.
                </p>
              </div>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
