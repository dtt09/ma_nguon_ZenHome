import React, { useState, useEffect } from 'react';
import { useFirebaseRealtimeData } from './hooks/useFirebaseRealtimeData';
import { AdminSidebar, AdminTab } from './components/admin/AdminSidebar';
import { AdminHeader } from './components/admin/AdminHeader';
import { OverviewView } from './components/admin/OverviewView';
import { CustomerList } from './components/admin/CustomerList';
import { CustomerDetailModal } from './components/admin/CustomerDetailModal';
import { DeleteCustomerModal } from './components/admin/DeleteCustomerModal';
import { ErrorLogsView } from './components/admin/ErrorLogsView';
import { BugReportsView } from './components/admin/BugReportsView';
import { DatabaseExplorer } from './components/admin/DatabaseExplorer';
import { HardwareFleetView } from './components/admin/HardwareFleetView';
import { BackupServerView } from './components/admin/BackupServerView';
import { ApiDocsView } from './components/admin/ApiDocsView';
import { AppVersionModal } from './components/admin/AppVersionModal';
import { Esp32OtaModal } from './components/admin/Esp32OtaModal';
import { PasskeyManagerModal } from './components/admin/PasskeyManagerModal';
import { RealCustomerUser } from './types/admin';
import { AdminLoginView } from './components/admin/AdminLoginView';
import { getTabFromPath, getPathForTab, navigateToTab } from './utils/routes';
import { getAdminSecret } from './services/backupServerService';
import { AlertCircle, CheckCircle2, X } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';

export const App: React.FC = () => {
  // Authentication Guard State (SEC-04: Master Key Gate)
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(() => {
    return Boolean(getAdminSecret());
  });

  const handleLogout = () => {
    sessionStorage.removeItem('zenhome_admin_key');
    localStorage.removeItem('zenhome_admin_key');
    setIsAuthenticated(false);
  };

  // Tự động khóa bảng điều khiển sau 15 phút không thao tác (Security Auto-Lock)
  useEffect(() => {
    if (!isAuthenticated) return;
    const INACTIVITY_TIMEOUT = 15 * 60 * 1000;
    let timer: any;
    const resetTimer = () => {
      clearTimeout(timer);
      timer = setTimeout(() => {
        handleLogout();
        showToast('🔒 Bảng điều khiển đã tự động khóa do không hoạt động trong 15 phút.');
      }, INACTIVITY_TIMEOUT);
    };
    const events = ['mousemove', 'keydown', 'mousedown', 'touchstart', 'scroll'];
    events.forEach(evt => window.addEventListener(evt, resetTimer, { passive: true }));
    resetTimer();
    return () => {
      clearTimeout(timer);
      events.forEach(evt => window.removeEventListener(evt, resetTimer));
    };
  }, [isAuthenticated]);

  // Theme
  const [isDark, setIsDark] = useState<boolean>(() => {
    const saved = localStorage.getItem('zenhome_admin_theme');
    return saved !== null ? saved === 'dark' : true;
  });

  // Active tab
  const [activeTab, setActiveTab] = useState<AdminTab>(() => {
    return getTabFromPath(window.location.pathname, window.location.hash);
  });

  // Search query
  
  // Đồng bộ hóa URL Browser và Tab hiển thị (HTML5 History API)
  const handleTabSelect = (tab: AdminTab) => {
    setActiveTab(tab);
    navigateToTab(tab);
  };

  useEffect(() => {
    // Chuẩn hóa URL khi vừa mở trang (nếu ở '/' hoặc '/admin' thì đưa về '/admin/overview')
    const canonical = getPathForTab(activeTab);
    if (window.location.pathname !== canonical && !window.location.hash) {
      navigateToTab(activeTab, true);
    }

    // Lắng nghe sự kiện Back / Forward của trình duyệt
    const onPopState = () => {
      const tab = getTabFromPath(window.location.pathname, window.location.hash);
      setActiveTab(tab);
    };

    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, [activeTab]);

  const [searchQuery, setSearchQuery] = useState('');

  // Selected customer for modal
  const [selectedCustomer, setSelectedCustomer] = useState<RealCustomerUser | null>(null);

  // Customer selected for GDPR Deletion
  const [customerToDelete, setCustomerToDelete] = useState<RealCustomerUser | null>(null);

  // Toast banner
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // App Version OTA Modal
  const [showVersionModal, setShowVersionModal] = useState<boolean>(false);

  // ESP32 Firmware OTA Modal
  const [showEsp32OtaModal, setShowEsp32OtaModal] = useState<boolean>(false);

  // Passkey FIDO2 Management Modal
  const [showPasskeyModal, setShowPasskeyModal] = useState<boolean>(false);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => {
      setToastMessage(null);
    }, 3200);
  };

  // Real-time Firebase data hook with Continuous Updates
  const {
    customers,
    crashLogs,
    bugReports,
    databaseDocs,
    stats,
    isLoading,
    error,
    lastSyncTime,
    secondsAgo,
    pingMs,
    syncCount,
    isLiveStreaming,
    setIsLiveStreaming,
    autoRefreshInterval,
    setAutoRefreshInterval,
    triggerManualSync,
    updateReportStatus,
    deleteReport,
    toggleCrashResolved,
    deleteCrashLog,
    sendTestCrash,
    markCustomerDeleted
  } = useFirebaseRealtimeData(isAuthenticated);

  // Sync theme
  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('zenhome_admin_theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('zenhome_admin_theme', 'light');
    }
  }, [isDark]);

  // Keep selectedCustomer in sync with real-time updates
  useEffect(() => {
    if (selectedCustomer) {
      const updated = customers.find(c => c.id === selectedCustomer.id);
      if (updated) {
        setSelectedCustomer(updated);
      } else {
        setSelectedCustomer(null);
      }
    }
  }, [customers]);

  // Handle Deletion Finished
  const handleCustomerDeleted = (customerId: string, auditLog: string) => {
    markCustomerDeleted(customerId);
    setCustomerToDelete(null);
    if (selectedCustomer?.id === customerId) {
      setSelectedCustomer(null);
    }
    showToast(`Đã hoàn tất quy trình xóa tài khoản ${customerId}! ${auditLog}`);
  };

  // Cổng bảo vệ xác thực: Nếu chưa đăng nhập, hiển thị màn hình Đăng nhập
  if (!isAuthenticated) {
    return (
      <AdminLoginView 
        onLoginSuccess={() => {
          setIsAuthenticated(true);
          showToast('Xác thực Quản trị viên thành công! Chào mừng quay trở lại.');
        }} 
      />
    );
  }

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 antialiased font-sans transition-colors">
      
      {/* Sidebar Navigation */}
      <AdminSidebar
        activeTab={activeTab}
        onSelectTab={handleTabSelect}
        totalCustomers={customers.length}
        totalCrashes={crashLogs.length}
        totalReports={bugReports.length}
        totalDocs={databaseDocs.length}
        onLogout={handleLogout}
      />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        
        {/* Top Header with Continuous Stream Ticker */}
        <AdminHeader
          searchQuery={searchQuery}
          onSearchChange={(q) => {
            setSearchQuery(q);
          }}
          isDark={isDark}
          onToggleTheme={() => setIsDark(!isDark)}
          lastSyncTime={lastSyncTime}
          secondsAgo={secondsAgo}
          pingMs={pingMs}
          syncCount={syncCount}
          isLiveStreaming={isLiveStreaming}
          onToggleLiveStreaming={() => setIsLiveStreaming(!isLiveStreaming)}
          onTriggerManualSync={triggerManualSync}
          autoRefreshInterval={autoRefreshInterval}
          onSelectInterval={setAutoRefreshInterval}
          onNavigateToBackupServer={() => handleTabSelect('backup_server')}
          isSyncing={isLoading}
          customers={customers}
          onSelectCustomer={setSelectedCustomer}
          activeTab={activeTab}
          onLogout={handleLogout}
          onOpenPasskeyManager={() => setShowPasskeyModal(true)}
        />

        {/* Global Error Banner if Firebase error occurs */}
        {error && (
          <div className="mx-6 mt-4 p-3 rounded-2xl bg-rose-50 dark:bg-rose-950/50 border border-rose-300 dark:border-rose-900/50 text-rose-700 dark:text-rose-400 text-xs flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-500 shrink-0" />
              <span>{error}</span>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="px-2.5 py-1 rounded bg-rose-200 dark:bg-rose-900 text-rose-900 dark:text-rose-100 font-semibold"
            >
              Tải lại
            </button>
          </div>
        )}

        {/* Scrollable Main Views with Animate UI Fluid Transitions */}
        <main className="flex-1 overflow-y-auto p-4 sm:p-6 scrollbar-thin">
          <AnimatePresence mode="wait">
            <motion.div 
              key={activeTab} 
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
              className="max-w-7xl mx-auto"
            >
            
            {activeTab === 'overview' && (
              <OverviewView
                stats={stats}
                customers={customers}
                crashes={crashLogs}
                onSelectCustomer={(c) => setSelectedCustomer(c)}
                onNavigateToCustomers={() => handleTabSelect('customers')}
                onNavigateToCrashes={() => handleTabSelect('crash_logs')}
                onOpenVersionModal={() => setShowVersionModal(true)}
                onOpenEsp32Modal={() => setShowEsp32OtaModal(true)}
                onNavigateToBackupServer={() => handleTabSelect('backup_server')}
              />
            )}

            {activeTab === 'customers' && (
              <CustomerList
                customers={customers}
                onSelectCustomer={(c) => setSelectedCustomer(c)}
                onDeleteCustomer={(c) => setCustomerToDelete(c)}
                searchQuery={searchQuery}
                isLoading={isLoading}
              />
            )}

            {activeTab === 'bug_reports' && (
              <BugReportsView
                reports={bugReports}
                onUpdateStatus={updateReportStatus}
                onDeleteReport={deleteReport}
              />
            )}

            {activeTab === 'crash_logs' && (
              <ErrorLogsView
                crashLogs={crashLogs}
                onSelectCustomerById={(userId) => {
                  const found = customers.find(c => c.id === userId);
                  if (found) setSelectedCustomer(found);
                }}
                onToggleResolved={toggleCrashResolved}
                onDeleteCrash={deleteCrashLog}
                onSendTestCrash={sendTestCrash}
                onShowToast={showToast}
              />
            )}

            {activeTab === 'database' && (
              <DatabaseExplorer
                documents={databaseDocs}
              />
            )}

            {activeTab === 'fleet' && (
              <HardwareFleetView
                customers={customers}
                onSelectCustomer={(c) => setSelectedCustomer(c)}
              />
            )}

            {activeTab === 'backup_server' && (
              <BackupServerView customers={customers} />
            )}

            {activeTab === 'api_system' && (
              <ApiDocsView />
            )}

            </motion.div>
          </AnimatePresence>
        </main>

      </div>

      {/* Real Customer Detail Drawer Modal */}
      <CustomerDetailModal
        customer={selectedCustomer}
        onClose={() => setSelectedCustomer(null)}
        onRequestDelete={(c) => {
          setSelectedCustomer(null);
          setCustomerToDelete(c);
        }}
      />

      {/* Delete Customer GDPR Modal */}
      <DeleteCustomerModal
        customer={customerToDelete}
        onClose={() => setCustomerToDelete(null)}
        onCustomerDeleted={handleCustomerDeleted}
      />

      {/* App Version OTA Publisher Modal */}
      <AppVersionModal
        isOpen={showVersionModal}
        onClose={() => setShowVersionModal(false)}
        onSuccessNotification={(msg) => showToast(msg)}
      />

      {/* ESP32 Firmware OTA Publisher Modal */}
      <Esp32OtaModal
        isOpen={showEsp32OtaModal}
        onClose={() => setShowEsp32OtaModal(false)}
        customers={customers}
        onSuccessNotification={(msg) => showToast(msg)}
      />

      {/* Passkey FIDO2 Management Modal */}
      <PasskeyManagerModal
        isOpen={showPasskeyModal}
        onClose={() => setShowPasskeyModal(false)}
        onShowToast={(msg) => showToast(msg)}
      />

      {/* Toast Notification with Animate UI Spring Motion */}
      <AnimatePresence>
        {toastMessage && (
          <motion.div 
            initial={{ opacity: 0, y: 20, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: 20, scale: 0.95 }}
            transition={{ type: "spring", stiffness: 450, damping: 30 }}
            className="fixed bottom-6 right-6 z-50 flex items-center gap-2.5 px-4 py-2.5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 text-slate-900 dark:text-slate-100 shadow-2xl text-xs sm:text-sm font-semibold max-w-md"
          >
            <CheckCircle2 className="w-4 h-4 text-emerald-500 shrink-0" />
            <span className="flex-1">{toastMessage}</span>
            <button onClick={() => setToastMessage(null)} className="ml-1 text-slate-400 hover:text-slate-900 dark:hover:text-white transition-colors">
              <X className="w-3.5 h-3.5" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>

    </div>
  );
};

export default App;
