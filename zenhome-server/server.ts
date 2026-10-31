import 'dotenv/config';
import express, { Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { createServer } from 'http';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
import { Server } from 'socket.io';
import { serverLogs, logListeners, addLog, state } from './server/zenhomeState';
import { initZenHomeWorker, sendCommandWithRetry } from './server/zenhomeWorker';
import { apiRouter } from './server/routes/api';
import { syncServerConfigToFirestore, startNetworkSyncWatcher } from './server/core/networkSync';
import { client as mqttClient } from './server/core/mqtt';
import { ADMIN_SECRET } from './server/middlewares/auth';
import { getAuth } from './server/core/firebase';


const serverStartTime = new Date();

const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 5000;

// ==========================================
// BẢO MẬT HỆ THỐNG: SECURITY HEADERS & HARDENING
// ==========================================
app.disable('x-powered-by');
app.use((req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  next();
});

// Enable CORS for frontend website (port 3000 / 5173 / all origins)
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-api-key'],
}));

// Tạo HTTP server và Socket.io instance
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
  }
});

app.use(express.json());
app.set('trust proxy', 1);

// Start ZenHome Node.js Background Worker (MQTT, Firebase, Cronjobs, Backup Observers)
initZenHomeWorker();

// API Routes
app.use('/api', apiRouter);

// Endpoint giữ nhịp tim cơ bản (Health check)
app.get('/render-heartbeat', (req: Request, res: Response) => {
  res.send('Trạm giám sát IoT & Server Backup ZenHome đang thức! (Độc lập & Bảo mật)');
});

// ==========================================
// PHỤC VỤ TÀI NGUYÊN TĨNH & FILE DOWNLOADS (APK OTA)
// ==========================================
const publicPath = path.resolve(__dirname, 'public');
if (!fs.existsSync(publicPath)) {
  fs.mkdirSync(publicPath, { recursive: true });
}
const downloadsPath = path.join(publicPath, 'downloads');
if (!fs.existsSync(downloadsPath)) {
  fs.mkdirSync(downloadsPath, { recursive: true });
}
// Tự động log và phục vụ APK với đầy đủ header (Content-Disposition, Accept-Ranges, Content-Type)
app.get(['/public/downloads/:filename', '/downloads/:filename'], (req: Request, res: Response, next) => {
  const filename = String(req.params.filename);
  console.log(`[DOWNLOAD] 📥 Nhận yêu cầu tải file APK (${filename}) từ IP: ${req.ip || req.socket.remoteAddress} (User-Agent: ${req.get('user-agent')})`);
  const targetFile = path.join(downloadsPath, filename);
  if (fs.existsSync(targetFile)) {
    res.setHeader('Content-Type', 'application/vnd.android.package-archive');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Accept-Ranges', 'bytes');
    return res.sendFile(targetFile);
  }
  next();
});

// Phục vụ Firmware OTA cho ESP32 với bảo vệ chống Path Traversal
const firmwareDir = path.join(publicPath, 'firmware', 'esp32');
if (!fs.existsSync(firmwareDir)) {
  fs.mkdirSync(firmwareDir, { recursive: true });
}
app.get(['/public/firmware/esp32/:filename', '/firmware/esp32/:filename'], (req: Request, res: Response, next) => {
  const filename = path.basename(String(req.params.filename));
  console.log(`[OTA-DOWNLOAD] 📦 ESP32 đang tải file firmware (${filename}) từ IP: ${req.ip || req.socket.remoteAddress}`);
  const targetFile = path.join(firmwareDir, filename);
  if (fs.existsSync(targetFile)) {
    res.setHeader('Content-Type', 'application/octet-stream');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Accept-Ranges', 'bytes');
    return res.sendFile(targetFile);
  }
  next();
});

app.use('/public', express.static(publicPath));

// ==========================================
// PHỤC VỤ WEBSITE REACT ADMIN TĨNH (SPA FULL-STACK)
// ==========================================
const webDistPath = path.resolve(__dirname, '../zenhome-web/dist');

if (fs.existsSync(webDistPath)) {
  // 1. Phục vụ các tài nguyên tĩnh (js, css, images)
  app.use(express.static(webDistPath));

  // 2. Mọi route không bắt đầu bằng /api, /public hoặc /render-heartbeat đều trả về index.html (SPA Router)
  app.get(/^(?!\/api|\/public|\/render-heartbeat).*$/, (req: Request, res: Response) => {
    res.sendFile(path.join(webDistPath, 'index.html'));
  });
} else {
  // Nếu chưa có bản build của web, chuyển hướng về Swagger API Docs
  app.get('/', (req: Request, res: Response) => {
    res.redirect('/api/docs');
  });
}

import { getCpuMetrics, getRamMetrics, getDiskMetrics, formatUptimeString } from './server/core/systemTelemetry';

// ==========================================
// TRÌNH THU THẬP TELEMETRY THỜI GIAN THỰC (Bi-directional Telemetry Engine)
// ==========================================
export function getServerTelemetry() {
  const now = new Date();
  const uptimeSec = Math.floor(process.uptime());
  const cpu = getCpuMetrics();
  const ram = getRamMetrics();
  const disk = getDiskMetrics();

  return {
    serverTimestamp: now.getTime(),
    serverTimeIso: now.toISOString(),
    serverTimeFormatted: now.toLocaleString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' }),
    bootTime: serverStartTime.toISOString(),
    uptime: uptimeSec,
    uptimeFormatted: formatUptimeString(uptimeSec),
    cpu,
    ram: ram.system,
    disk,
    memory: ram.process,
    subsystems: {
      mqtt: {
        connected: Boolean(mqttClient && mqttClient.connected),
        broker: 'HiveMQ Cloud TLS 8883',
        lastMessageAt: state.mqttStatus?.lastMessageAt || null,
        reconnectCount: state.mqttStatus?.reconnectCount || 0,
      },
      firestore: {
        connected: true,
        projectId: 'smarthome-98dd7',
        region: 'asia-southeast1',
      },
      cron: {
        active: true,
        timezone: 'Asia/Ho_Chi_Minh',
        lastRunAt: state.cronStatus?.lastRunAt || null,
      },
    },
    processInfo: {
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch,
      pid: process.pid,
    },
    pendingTasksCount: Object.keys(state.pendingTasks || {}).length,
    activeTimersCount: Object.keys(state.activeTimers || {}).length,
    activeSchedulesCount: Object.keys(state.activeSchedules || {}).length,
    latestIndoorTemp: state.latestIndoorTemp,
    espOnlineStatus: state.espOnlineStatus,
    connectedClients: io.engine.clientsCount,
  };
}

// ==========================================
// THỰC THI WEBSOCKETS (Real-time Logs & Bi-directional Telemetry)
// Bắt buộc xác thực Socket.io Handshake chống rò rỉ Logs và bắn lệnh trái phép (SEC-03)
// ==========================================
io.use(async (socket, next) => {
  const token = (socket.handshake.auth?.token as string)?.trim() ||
                (socket.handshake.headers['x-api-key'] as string)?.trim() ||
                socket.handshake.headers['authorization']?.replace(/^Bearer\s+/i, '').trim();

  if (!token) {
    return next(new Error('Unauthorized: Vui lòng cung cấp mã xác thực cho kết nối WebSocket.'));
  }

  // 1. Chấp nhận nếu là Admin Secret
  if (ADMIN_SECRET && token === ADMIN_SECRET) {
    socket.data.user = { uid: 'admin', role: 'admin' };
    return next();
  }

  // 2. Chấp nhận nếu là Firebase ID Token hợp lệ
  try {
    const auth = getAuth();
    if (auth) {
      const decoded = await auth.verifyIdToken(token);
      const configuredAdminEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
      const isAdmin = (decoded.admin === true || decoded.role === 'admin' || 
                       Boolean(configuredAdminEmail && decoded.email && decoded.email.trim().toLowerCase() === configuredAdminEmail));
      socket.data.user = {
        uid: decoded.uid,
        email: decoded.email,
        role: isAdmin ? 'admin' : 'user',
      };
      return next();
    }
  } catch (err: any) {
    return next(new Error('Unauthorized: Token xác thực WebSocket không hợp lệ.'));
  }

  return next(new Error('Unauthorized: Kết nối WebSocket bị từ chối.'));
});

io.on('connection', (socket) => {
  const isAdmin = socket.data.user && socket.data.user.role === 'admin';

  // PHÂN QUYỀN WEBSOCKET NÂNG CAO (SEC-SOCKET-01):
  // Chỉ tài khoản Quản trị viên (Admin) mới được tham gia admin_room để nhận Logs và Telemetry
  if (isAdmin) {
    socket.join('admin_room');

    // Gửi lô log ban đầu cho admin vừa kết nối (tối đa 300 dòng)
    socket.emit('init_logs', serverLogs.slice(-300));

    // Gửi telemetry ban đầu ngay khi kết nối
    socket.emit('telemetry_update', getServerTelemetry());

    // Admin yêu cầu tải lại logs bất cứ lúc nào
    socket.on('request_logs', () => {
      socket.emit('init_logs', serverLogs.slice(-300));
    });

    // Admin yêu cầu đồng bộ telemetry tức thì
    socket.on('request_telemetry', () => {
      socket.emit('telemetry_update', getServerTelemetry());
    });
  }

  // Client gửi ping để đo độ trễ hai chiều (Round-Trip Latency / RTT Ping-Pong)
  socket.on('client_ping', (data: any, ack?: (res: any) => void) => {
    const telemetry = isAdmin ? getServerTelemetry() : { timestamp: Date.now() };
    const pongData = {
      ...telemetry,
      clientTimestamp: data?.clientTimestamp || Date.now(),
      serverAckTime: Date.now(),
    };
    if (typeof ack === 'function') {
      ack(pongData);
    } else {
      socket.emit('server_pong', pongData);
    }
  });

  // Client gửi lệnh điều khiển thiết bị qua WebSocket siêu tốc (Kiểm tra quyền sở hữu topic)
  socket.on('device_cmd', (data: { topic: string; state: string; source?: string }) => {
    if (!socket.data.user) return;
    
    // Nếu không phải admin, chỉ được điều khiển thiết bị thuộc userId của chính mình
    if (socket.data.user.role !== 'admin' && data && data.topic) {
      const topicUser = data.topic.split('/')[0];
      if (topicUser !== socket.data.user.uid) {
        console.warn(`[SOCKET SECURITY] ⚠️ User ${socket.data.user.uid} cố tình gửi lệnh tới thiết bị của người khác (${data.topic})!`);
        return;
      }
    }

    if (data && data.topic && data.state !== undefined) {
      sendCommandWithRetry(data.topic, String(data.state), data.source || 'web_socket');
    }
  });

  socket.on('disconnect', () => {
    // Tự động dọn dẹp khi ngắt kết nối
  });
});

// Broadcast log mới theo thời gian thực (CHỈ gửi cho các client trong admin_room)
const broadcastNewLog = (entry: any) => {
  io.to('admin_room').emit('new_log', entry);
};
logListeners.add(broadcastNewLog);

// Broadcast telemetry định kỳ CHỈ KHI có client đang kết nối trong admin_room (Demand-Driven Telemetry)
// Tiết kiệm 100% CPU/RAM thu thập telemetry khi không có người theo dõi dashboard
setInterval(() => {
  const adminRoom = io.sockets.adapter.rooms.get('admin_room');
  if (adminRoom && adminRoom.size > 0) {
    io.to('admin_room').emit('telemetry_update', getServerTelemetry());
  }
}, 3000);

// Khởi chạy server thống nhất (Full-Stack Unified)
httpServer.listen(PORT, '0.0.0.0', async () => {
  // 1. Tự động nhận diện IPv4 máy chủ và đồng bộ lên Database Cloud Firestore
  const netConfig = await syncServerConfigToFirestore(PORT);
  
  // 2. Khởi chạy bộ lắng nghe thay đổi IP mạng (30s/lần)
  startNetworkSyncWatcher(PORT, 30000);

  console.log(`========================================================`);
  console.log(`🚀 ZenHome Full-Stack Unified System running at:`);
  console.log(`   ➜ Local Access:     http://localhost:${PORT}`);
  console.log(`   ➜ LAN Web/Admin:    http://${netConfig.localIp}:${PORT}`);
  console.log(`   ➜ Direct APK (OTA): ${netConfig.directApkUrl}`);
  console.log(`   ➜ Interactive Docs: http://${netConfig.localIp}:${PORT}/api/docs`);
  console.log(`   ➜ RESTful API Base: http://${netConfig.localIp}:${PORT}/api/v1`);
  console.log(`   ➜ WebSockets:       Port ${PORT} (Socket.io Ready)`);
  console.log(`========================================================`);
  addLog('[BACKEND]', `✅ Server ZenHome (IP: ${netConfig.localIp}:${PORT}) đã khởi chạy & đồng bộ Database thành công!`, 'success');
});

