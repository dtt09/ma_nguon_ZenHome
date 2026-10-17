export interface RealSessionDoc {
  id: string;
  deviceName: string;
  os: string;
  location: string;
  isActive: boolean;
  isTrusted: boolean;
  fcmToken: string;
  lastLogin: string;
  firstSeen: string;
  lastAccess: string;
  appVersion?: string;
  buildNumber?: number;
  raw?: Record<string, any>;
}

export interface RealDeviceItem {
  id: string;
  name: string;
  pin: number;
  type: string;
  isOn?: boolean;
  room?: string;
  powerWatts?: number;
}

export interface RealCustomerUser {
  id: string; // Document ID (e.g. 'Dtthuat')
  uid: string;
  displayName: string;
  email: string;
  phoneNumber: string;
  macAddress: string;
  createdAt: string;
  devices: RealDeviceItem[];
  sessions: RealSessionDoc[];
  crashLogs: RealCrashLog[];
  rawDoc: Record<string, any>;
}

export interface RealCrashLog {
  id: string;
  userId: string;
  userEmail: string;
  userName: string;
  timestamp: string;
  errorTitle: string;
  errorMessage: string;
  severity: 'fatal' | 'error' | 'warning' | 'info';
  stackTrace: string;
  deviceModel?: string;
  osVersion?: string;
  appVersion?: string;
  isResolved?: boolean;
  resolutionNote?: string;
  raw?: Record<string, any>;
}

export interface RealDatabaseDoc {
  collection: string;
  id: string;
  data: Record<string, any>;
  path: string;
  updatedAt: string;
  sizeBytes: number;
}

export interface RealSystemStats {
  totalCustomers: number;
  totalSessions: number;
  totalDevices: number;
  totalCrashes: number;
  totalReports?: number;
  onlineEspCount: number;
  latestAppVersion?: string;
  latestBuildNumber?: number;
}

export interface RealBugReport {
  id: string;
  userId: string;
  authorName: string;
  contactInfo: string;
  category: 'ui' | 'mqtt' | 'device' | 'automation' | 'other';
  title: string;
  description: string;
  deviceModel?: string;
  appVersion?: string;
  buildNumber?: number;
  status: 'open' | 'investigating' | 'resolved';
  createdAt: string;
  raw?: Record<string, any>;
}

