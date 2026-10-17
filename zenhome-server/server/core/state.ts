export interface PendingTask {
    targetState: string;
    intervalId?: NodeJS.Timeout;
    source: string;
    retryCount: number;
    startedAt: string;
    toJSON?: () => any;
}

export interface ActiveSchedule {
    baseTopic: string;
    timeOn?: string;
    timeOff?: string;
    days: string | boolean[] | number[];
    isTriggeredOn?: boolean;
    isTriggeredOff?: boolean;
}

export interface ZenHomeCoreState {
    pendingTasks: Record<string, PendingTask>;
    activeTimers: Record<string, NodeJS.Timeout>;
    activeSchedules: Record<string, ActiveSchedule>;
    latestIndoorTemp: Record<string, { temp: number; updatedAt: string }>;
    espOnlineStatus: Record<string, { isOnline: boolean; lastSeen: string }>;
    lastTempAlert: Record<string, number>;
    offlineDebounceTimers: Record<string, NodeJS.Timeout>;
    mqttStatus: {
        connected: boolean;
        broker: string;
        lastConnectedAt: string | null;
        lastMessageAt: string | null;
        reconnectCount: number;
    };
    cronStatus: {
        active: boolean;
        timezone: string;
        mode?: string;
        lastRunAt: string | null;
        pattern: string;
    };
}

export const state: ZenHomeCoreState = {
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

export default state;
