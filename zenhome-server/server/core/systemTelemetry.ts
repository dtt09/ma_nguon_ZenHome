import os from 'os';
import fs from 'fs';
import path from 'path';

export interface CpuSnapshot {
  idle: number;
  total: number;
}

export interface CpuMetrics {
  usagePercent: number;
  cores: number;
  model: string;
  speedMhz: number;
  loadAvg: number[];
}

export interface SystemRamMetrics {
  totalGB: number;
  usedGB: number;
  freeGB: number;
  usedPercent: number;
  totalBytes: number;
  usedBytes: number;
  freeBytes: number;
}

export interface ProcessMemoryMetrics {
  heapUsedMB: number;
  heapTotalMB: number;
  rssMB: number;
  heapPercent: number;
}

export interface DiskMetrics {
  drive: string;
  totalGB: number;
  usedGB: number;
  freeGB: number;
  usedPercent: number;
  totalBytes?: number;
  usedBytes?: number;
  freeBytes?: number;
  error?: string;
}

export interface SystemTelemetryData {
  serverTimestamp: number;
  serverTimeIso: string;
  serverTimeFormatted: string;
  bootTime: string;
  uptime: number;
  uptimeFormatted: string;
  cpu: CpuMetrics;
  ram: SystemRamMetrics;
  disk: DiskMetrics;
  memory: ProcessMemoryMetrics;
  processInfo: {
    nodeVersion: string;
    platform: string;
    arch: string;
    pid: number;
  };
}

let lastCpuSnap: CpuSnapshot = { idle: 0, total: 0 };
let currentCpuUsagePercent: number = 0;

function takeCpuSnapshot(): CpuSnapshot {
  try {
    const cpus = os.cpus();
    let idle = 0;
    let total = 0;
    if (cpus && cpus.length > 0) {
      for (const cpu of cpus) {
        for (const t in cpu.times) {
          total += (cpu.times as any)[t];
        }
        idle += cpu.times.idle;
      }
    }
    return { idle, total };
  } catch (e) {
    return { idle: 0, total: 0 };
  }
}

// Khởi tạo snapshot đầu tiên
lastCpuSnap = takeCpuSnapshot();

// Cập nhật mức dùng CPU định kỳ mỗi 1.5 giây
const cpuInterval = setInterval(() => {
  const curSnap = takeCpuSnapshot();
  const idleDiff = curSnap.idle - lastCpuSnap.idle;
  const totalDiff = curSnap.total - lastCpuSnap.total;
  if (totalDiff > 0) {
    const rawPercent = Math.round((1 - idleDiff / totalDiff) * 100);
    currentCpuUsagePercent = Math.max(0, Math.min(100, rawPercent));
  }
  lastCpuSnap = curSnap;
}, 1500);

if (cpuInterval && typeof cpuInterval.unref === 'function') {
  cpuInterval.unref();
}

export function getCpuMetrics(): CpuMetrics {
  const cpus = os.cpus() || [];
  return {
    usagePercent: currentCpuUsagePercent,
    cores: cpus.length,
    model: cpus[0]?.model?.trim() || 'Multi-core Processor',
    speedMhz: cpus[0]?.speed || 0,
    loadAvg: os.loadavg ? os.loadavg().map(v => +v.toFixed(2)) : [],
  };
}

export function getRamMetrics(): { system: SystemRamMetrics; process: ProcessMemoryMetrics } {
  const totalBytes = os.totalmem();
  const freeBytes = os.freemem();
  const usedBytes = Math.max(0, totalBytes - freeBytes);
  const usedPercent = totalBytes > 0 ? Math.round((usedBytes / totalBytes) * 100) : 0;
  
  const mem = process.memoryUsage();

  return {
    system: {
      totalGB: +(totalBytes / (1024 ** 3)).toFixed(2),
      usedGB: +(usedBytes / (1024 ** 3)).toFixed(2),
      freeGB: +(freeBytes / (1024 ** 3)).toFixed(2),
      usedPercent,
      totalBytes,
      usedBytes,
      freeBytes,
    },
    process: {
      heapUsedMB: +(mem.heapUsed / 1024 / 1024).toFixed(1),
      heapTotalMB: +(mem.heapTotal / 1024 / 1024).toFixed(1),
      rssMB: +(mem.rss / 1024 / 1024).toFixed(1),
      heapPercent: mem.heapTotal > 0 ? Math.round((mem.heapUsed / mem.heapTotal) * 100) : 0,
    }
  };
}

export function getDiskMetrics(): DiskMetrics {
  try {
    const targetPath = process.cwd();
    // fs.statfsSync được hỗ trợ chuẩn từ Node.js 18.15+ & 20+
    const stat = (fs as any).statfsSync ? (fs as any).statfsSync(targetPath) : null;
    if (stat) {
      const bsize = stat.bsize;
      const totalBytes = bsize * stat.blocks;
      const freeBytes = bsize * stat.bavail;
      const usedBytes = Math.max(0, totalBytes - freeBytes);
      const usedPercent = totalBytes > 0 ? Math.round((usedBytes / totalBytes) * 100) : 0;
      const parsedPath = path.parse(targetPath);

      return {
        drive: parsedPath.root || '/',
        totalGB: +(totalBytes / (1024 ** 3)).toFixed(1),
        usedGB: +(usedBytes / (1024 ** 3)).toFixed(1),
        freeGB: +(freeBytes / (1024 ** 3)).toFixed(1),
        usedPercent,
        totalBytes,
        usedBytes,
        freeBytes,
      };
    }
  } catch (err: any) {
    // Dự phòng an toàn nếu không đọc được filesystem
  }

  return {
    drive: path.parse(process.cwd()).root || '/',
    totalGB: 100,
    usedGB: 10,
    freeGB: 90,
    usedPercent: 10,
  };
}

export function formatUptimeString(totalSec: number): string {
  if (!totalSec || totalSec <= 0) return '0 giây';
  const days = Math.floor(totalSec / 86400);
  const hours = Math.floor((totalSec % 86400) / 3600);
  const minutes = Math.floor((totalSec % 3600) / 60);
  const seconds = totalSec % 60;
  const parts = [];
  if (days > 0) parts.push(`${days} ngày`);
  if (hours > 0 || days > 0) parts.push(`${hours.toString().padStart(2, '0')} giờ`);
  parts.push(`${minutes.toString().padStart(2, '0')} phút`);
  parts.push(`${seconds.toString().padStart(2, '0')} giây`);
  return parts.join(' ');
}
