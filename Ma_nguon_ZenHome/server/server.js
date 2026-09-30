require('dotenv').config();
require('./src/logger');
const express = require('express');

// Khởi tạo các module
const setupMqttHandlers = require('./src/mqttHandler');
const { loadSchedulesFromFirebase, startCronJob } = require('./src/schedules');
const { sendCommandWithRetry } = require('./src/devices');
const { startListeningToAlerts, startListeningToDeleteRequests, startListeningToUnlinkRequests } = require('./src/listeners');
const { loadTimersFromFirebase } = require('./src/timers');

// 1. Gắn Listener cho MQTT
setupMqttHandlers();

// 2. Tải lịch trình và hẹn giờ từ Firebase vào RAM
loadSchedulesFromFirebase();
loadTimersFromFirebase();

// 3. Khởi chạy Cron Job (Truyền hàm sendCommandWithRetry vào để tránh vòng lặp dependencies)
startCronJob(sendCommandWithRetry);
console.log(`🚀 Bộ đếm thời gian đang chạy ngầm...`);

// 4. Khởi chạy các Firebase Listeners
startListeningToAlerts();
startListeningToDeleteRequests();
startListeningToUnlinkRequests();

// ==========================================
// MỞ CỔNG WEB GIẢ ĐỂ QUA MẶT RENDER
// ==========================================
const app = express();
app.get('/', (req, res) => res.send('Trạm giám sát IoT đang thức! (Đã Modular hóa)'));

// Render sẽ tự động cấp một cái Port vào biến process.env.PORT
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`✅ Cổng giữ nhịp tim đã mở tại Port ${PORT}`);
});