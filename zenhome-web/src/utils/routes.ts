import { AdminTab } from '../components/admin/AdminSidebar';

export const ADMIN_BASE_PATH = '/admin';

export const TAB_TO_PATH: Record<AdminTab, string> = {
  overview: '/admin/overview',
  customers: '/admin/customers',
  bug_reports: '/admin/reports',
  crash_logs: '/admin/crashes',
  database: '/admin/database',
  fleet: '/admin/hardware',
  backup_server: '/admin/backup',
  api_system: '/admin/api-docs',
};

const PATH_ALIASES: Record<string, AdminTab> = {
  '': 'overview',
  '/': 'overview',
  '/admin': 'overview',
  '/admin/': 'overview',
  '/overview': 'overview',
  '/admin/overview': 'overview',

  '/customers': 'customers',
  '/admin/customers': 'customers',
  '/users': 'customers',
  '/admin/users': 'customers',

  '/reports': 'bug_reports',
  '/admin/reports': 'bug_reports',
  '/bug-reports': 'bug_reports',
  '/admin/bug-reports': 'bug_reports',

  '/crashes': 'crash_logs',
  '/admin/crashes': 'crash_logs',
  '/errors': 'crash_logs',
  '/admin/errors': 'crash_logs',
  '/crash-logs': 'crash_logs',
  '/admin/crash-logs': 'crash_logs',

  '/database': 'database',
  '/admin/database': 'database',
  '/firestore': 'database',
  '/admin/firestore': 'database',

  '/hardware': 'fleet',
  '/admin/hardware': 'fleet',
  '/fleet': 'fleet',
  '/admin/fleet': 'fleet',
  '/devices': 'fleet',
  '/admin/devices': 'fleet',

  '/backup': 'backup_server',
  '/admin/backup': 'backup_server',
  '/backups': 'backup_server',
  '/admin/backups': 'backup_server',

  '/api-docs': 'api_system',
  '/admin/api-docs': 'api_system',
  '/api': 'api_system',
  '/admin/api': 'api_system',
  '/swagger': 'api_system',
  '/admin/swagger': 'api_system',
};

/**
 * Phân tích đường dẫn URL (pathname hoặc hash) để trả về AdminTab tương ứng
 */
export function getTabFromPath(pathname: string, hash: string = ''): AdminTab {
  // 1. Kiểm tra hash nếu có dùng hash routing (ví dụ: /#/admin/crashes)
  if (hash && hash.startsWith('#')) {
    const hashClean = hash.replace(/^#/, '').trim();
    if (hashClean && PATH_ALIASES[hashClean]) {
      return PATH_ALIASES[hashClean];
    }
  }

  // 2. Chuẩn hóa pathname
  const cleanPath = pathname.toLowerCase().replace(/\/+$/, '') || '/';
  if (PATH_ALIASES[cleanPath]) {
    return PATH_ALIASES[cleanPath];
  }

  // 3. Fallback mặc định
  return 'overview';
}

/**
 * Lấy đường dẫn chuẩn cho từng tab
 */
export function getPathForTab(tab: AdminTab): string {
  return TAB_TO_PATH[tab] || '/admin/overview';
}

/**
 * Điều hướng mượt mà không tải lại trang (HTML5 History API)
 */
export function navigateToTab(tab: AdminTab, replace: boolean = false): void {
  const targetPath = getPathForTab(tab);
  if (window.location.pathname !== targetPath) {
    if (replace) {
      window.history.replaceState({ tab }, '', targetPath);
    } else {
      window.history.pushState({ tab }, '', targetPath);
    }
  }
}
