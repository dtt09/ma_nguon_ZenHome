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
import { RealCustomerUser } from './types/admin';
import { AlertCircle, CheckCircle2, X } from 'lucide-react';

export const App: React.FC = () => {
  // Theme
  const [isDark, setIsDark] = useState<boolean>(() => {
    return localStorage.getItem('zenhome_admin_theme') === 'dark' || true;
  });

  // Active tab
  const [activeTab, setActiveTab] = useState<AdminTab>('overview');

  // Search query
  const [searchQuery, setSearchQuery] = useState('');

  // Selected customer for modal
  const [selectedCustomer, setSelectedCustomer] = useState<RealCustomerUser | null>(null);

  // Customer selected for GDPR Deletion
  const [customerToDelete, setCustomerToDelete] = useState<RealCustomerUser | null>(null);

  // Toast banner
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // App Version OTA Modal
  const [showVersionModal, setShowVersionModal] = useState<boolean>(false);

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
    markCustomerDeleted
  } = useFirebaseRealtimeData();

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

  return (
    <div className="flex h-screen overflow-hidden bg-slate-50 dark:bg-slate-950  text-slate-900 dark:text-slate-50 dark:text-slate-100  antialiased font-sans transition-colors">
      
      {/* Sidebar Navigation */}
      <AdminSidebar
        activeTab={activeTab}
        onSelectTab={setActiveTab}
        totalCustomers={customers.length}
        totalCrashes={crashLogs.length}
        totalReports={bugReports.length}
        totalDocs={databaseDocs.length}
      />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        
        {/* Top Header with Continuous Stream Ticker */}
        <AdminHeader
          searchQuery={searchQuery}
          onSearchChange={(q) => {
            setSearchQuery(q);
            if (q.trim() !== '' && activeTab !== 'customers') {
              setActiveTab('customers');
            }
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
          onNavigateToBackupServer={() => setActiveTab('backup_server')}
          isSyncing={isLoading}
          customers={customers}
          onSelectCustomer={setSelectedCustomer}
          activeTab={activeTab}
        />

        {/* Global Error Banner if Firebase error occurs */}
        {error && (
          <div className="mx-6 mt-4 p-3 rounded-2xl bg-rose-50 dark:bg-rose-950/50  border border-rose-300  text-rose-700  text-xs flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-500 shrink-0" />
              <span>{error}</span>
            </div>
            <button
              onClick={() => window.location.reload()}
              className="px-2.5 py-1 rounded bg-rose-200  text-rose-900  font-semibold"
            >
              Tải lại
            </button>
          </div>
        )}

        {/* Scrollable Main Views */}
        <main className="flex-1 overflow-y-auto p-6">
          <div key={activeTab} className="max-w-7xl mx-auto animate-in fade-in zoom-in-95 slide-in-from-bottom-4 duration-300 ease-out fill-mode-both">
            
            {activeTab === 'overview' && (
              <OverviewView
                stats={stats}
                customers={customers}
                crashes={crashLogs}
                onSelectCustomer={(c) => setSelectedCustomer(c)}
                onNavigateToCustomers={() => setActiveTab('customers')}
                onNavigateToCrashes={() => setActiveTab('crash_logs')}
                onOpenVersionModal={() => setShowVersionModal(true)}
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
              <BackupServerView />
            )}

            {activeTab === 'api_system' && (
              <ApiDocsView />
            )}

          </div>
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

      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 flex items-center gap-2.5 px-4 py-2.5 rounded-2xl bg-white dark:bg-slate-900 dark:border-slate-800 text-slate-900 dark:text-slate-50  shadow-2xl animate-in slide-in-from-bottom-3 fade-in duration-200 text-xs sm:text-sm font-semibold max-w-md">
          <CheckCircle2 className="w-4 h-4 text-blue-400  shrink-0" />
          <span className="flex-1">{toastMessage}</span>
          <button onClick={() => setToastMessage(null)} className="ml-1 text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-50 dark:text-slate-50 dark:text-slate-400 dark:hover:text-slate-200">
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

    </div>
  );
};

export default App;
