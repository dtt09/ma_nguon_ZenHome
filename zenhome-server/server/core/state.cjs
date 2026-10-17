module.exports = {
    pendingTasks: {},
    activeTimers: {},
    activeSchedules: {},
    latestIndoorTemp: {},
    espOnlineStatus: {},
    lastTempAlert: {},
    offlineDebounceTimers: {},
    mqttStatus: {
        connected: false,
        broker: 'HiveMQ Cloud TLS 8883',
        lastConnectedAt: null,
        lastMessageAt: null,
        reconnectCount: 0
    },
    cronStatus: {
        active: true,
        timezone: 'Asia/Ho_Chi_Minh',
        lastRunAt: null,
        pattern: '* * * * *'
    }
};
