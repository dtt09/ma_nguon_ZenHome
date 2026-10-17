import React, { useState } from 'react';
import { 
  MessageSquareWarning, 
  Search, 
  Clock, 
  Smartphone, 
  User, 
  Mail, 
  CheckCircle2, 
  AlertCircle, 
  HelpCircle, 
  Trash2, 
  RefreshCw,
  Palette,
  Wifi,
  Sliders,
  Layers
} from 'lucide-react';
import { RealBugReport } from '../../types/admin';

interface BugReportsViewProps {
  reports: RealBugReport[];
  onUpdateStatus: (id: string, status: 'open' | 'investigating' | 'resolved') => Promise<void>;
  onDeleteReport: (id: string) => Promise<void>;
}

export const BugReportsView: React.FC<BugReportsViewProps> = ({
  reports,
  onUpdateStatus,
  onDeleteReport
}) => {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'all' | 'open' | 'investigating' | 'resolved'>('all');
  const [actionLoadingId, setActionLoadingId] = useState<string | null>(null);

  const getCategoryBadge = (category: string) => {
    switch (category) {
      case 'ui':
        return {
          label: 'Giao diện & UI/UX',
          icon: <Palette className="w-3.5 h-3.5 text-purple-500" />,
          color: 'bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-950/40 dark:text-purple-400 dark:border-purple-800/50'
        };
      case 'mqtt':
        return {
          label: 'Kết nối mạng & MQTT',
          icon: <Wifi className="w-3.5 h-3.5 text-amber-500" />,
          color: 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/40 dark:text-amber-400 dark:border-amber-800/50'
        };
      case 'device':
        return {
          label: 'Điều khiển thiết bị',
          icon: <Sliders className="w-3.5 h-3.5 text-blue-500" />,
          color: 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/40 dark:text-blue-400 dark:border-blue-800/50'
        };
      case 'automation':
        return {
          label: 'Ngữ cảnh & Tự động hóa',
          icon: <Layers className="w-3.5 h-3.5 text-emerald-500" />,
          color: 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/40 dark:text-emerald-400 dark:border-emerald-800/50'
        };
      default:
        return {
          label: 'Vấn đề khác',
          icon: <HelpCircle className="w-3.5 h-3.5 text-slate-500" />,
          color: 'bg-slate-50 text-slate-700 border-slate-200 dark:bg-slate-800/40 dark:text-slate-400 dark:border-slate-700/50'
        };
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'resolved':
        return {
          label: 'Đã giải quyết',
          badgeColor: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-400 border-emerald-200 dark:border-emerald-800/60',
          dotColor: 'bg-emerald-500'
        };
      case 'investigating':
        return {
          label: 'Đang xử lý',
          badgeColor: 'bg-blue-100 text-blue-800 dark:bg-blue-950/60 dark:text-blue-400 border-blue-200 dark:border-blue-800/60',
          dotColor: 'bg-blue-500 animate-pulse'
        };
      default:
        return {
          label: 'Mới ghi nhận',
          badgeColor: 'bg-rose-100 text-rose-800 dark:bg-rose-950/60 dark:text-rose-400 border-rose-200 dark:border-rose-800/60',
          dotColor: 'bg-rose-500'
        };
    }
  };

  const filtered = reports.filter(item => {
    const matchesStatus = statusFilter === 'all' || item.status === statusFilter;
    const matchesSearch = 
      item.title.toLowerCase().includes(search.toLowerCase()) ||
      item.description.toLowerCase().includes(search.toLowerCase()) ||
      item.authorName.toLowerCase().includes(search.toLowerCase()) ||
      item.contactInfo.toLowerCase().includes(search.toLowerCase()) ||
      (item.deviceModel && item.deviceModel.toLowerCase().includes(search.toLowerCase()));
    return matchesStatus && matchesSearch;
  });

  const openCount = reports.filter(r => r.status === 'open').length;
  const investigatingCount = reports.filter(r => r.status === 'investigating').length;
  const resolvedCount = reports.filter(r => r.status === 'resolved').length;

  const handleStatusChange = async (id: string, newStatus: 'open' | 'investigating' | 'resolved') => {
    setActionLoadingId(id);
    try {
      await onUpdateStatus(id, newStatus);
    } finally {
      setActionLoadingId(null);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Bạn có chắc chắn muốn xóa báo cáo lỗi này?')) return;
    setActionLoadingId(id);
    try {
      await onDeleteReport(id);
    } finally {
      setActionLoadingId(null);
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50 flex items-center gap-2">
            <MessageSquareWarning className="w-5 h-5 text-indigo-500" />
            <span>Báo cáo sự cố & Phản hồi từ Người dùng</span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Dữ liệu phản hồi thực tế từ người dùng ứng dụng di động ZenHome gửi về hệ thống Firestore.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono font-bold px-3 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-800/50 text-slate-700 dark:text-slate-300">
            {reports.length} phản hồi
          </span>
        </div>
      </div>

      {/* Tabs Filter & Search */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 p-1 bg-slate-100 dark:bg-slate-800/60 rounded-xl overflow-x-auto text-xs font-medium">
          <button
            onClick={() => setStatusFilter('all')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'all'
                ? 'bg-white dark:bg-slate-900 text-slate-900 dark:text-slate-100 shadow-sm font-semibold'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
            }`}
          >
            Tất cả ({reports.length})
          </button>
          <button
            onClick={() => setStatusFilter('open')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'open'
                ? 'bg-white dark:bg-slate-900 text-rose-600 dark:text-rose-400 shadow-sm font-semibold'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
            }`}
          >
            Mới ({openCount})
          </button>
          <button
            onClick={() => setStatusFilter('investigating')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'investigating'
                ? 'bg-white dark:bg-slate-900 text-blue-600 dark:text-blue-400 shadow-sm font-semibold'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
            }`}
          >
            Đang xử lý ({investigatingCount})
          </button>
          <button
            onClick={() => setStatusFilter('resolved')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              statusFilter === 'resolved'
                ? 'bg-white dark:bg-slate-900 text-emerald-600 dark:text-emerald-400 shadow-sm font-semibold'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
            }`}
          >
            Đã giải quyết ({resolvedCount})
          </button>
        </div>

        <div className="relative min-w-[260px]">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Tìm theo tiêu đề, người gửi, thiết bị..."
            className="w-full pl-9 pr-4 py-1.5 text-xs rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800/60 text-slate-900 dark:text-slate-50 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>
      </div>

      {/* Reports List */}
      <div className="space-y-3">
        {filtered.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-200 dark:border-slate-800 p-8 text-center bg-white dark:bg-slate-900">
            <CheckCircle2 className="w-8 h-8 text-emerald-500 mx-auto mb-2" />
            <h3 className="font-semibold text-sm text-slate-900 dark:text-slate-100">Không có báo cáo lỗi nào</h3>
            <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
              Tất cả sự cố đã được xử lý hoặc chưa có phản hồi nào được ghi nhận.
            </p>
          </div>
        ) : (
          filtered.map((item) => {
            const cat = getCategoryBadge(item.category);
            const status = getStatusBadge(item.status);
            const isLoading = actionLoadingId === item.id;

            return (
              <div
                key={item.id}
                className="rounded-2xl border border-slate-200 dark:border-slate-800/80 bg-white dark:bg-slate-900 p-4 transition-all shadow-sm hover:border-indigo-300 dark:hover:border-indigo-800/80 space-y-3"
              >
                {/* Top Row: Category + Status + Timestamp */}
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium border ${cat.color}`}>
                      {cat.icon}
                      <span>{cat.label}</span>
                    </span>

                    <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-semibold border ${status.badgeColor}`}>
                      <span className={`w-1.5 h-1.5 rounded-full ${status.dotColor}`} />
                      <span>{status.label}</span>
                    </span>
                  </div>

                  <div className="flex items-center gap-1.5 text-xs text-slate-400">
                    <Clock className="w-3.5 h-3.5" />
                    <span>{item.createdAt || 'Vừa xong'}</span>
                  </div>
                </div>

                {/* Title & Description */}
                <div>
                  <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">
                    {item.title}
                  </h3>
                  <p className="text-xs text-slate-600 dark:text-slate-300 mt-1 whitespace-pre-wrap leading-relaxed bg-slate-50 dark:bg-slate-800/40 p-3 rounded-xl border border-slate-100 dark:border-slate-800/60">
                    {item.description}
                  </p>
                </div>

                {/* Footer Metadata & Actions */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pt-2 border-t border-slate-100 dark:border-slate-800/60">
                  {/* Reporter Meta */}
                  <div className="flex flex-wrap items-center gap-3 text-xs text-slate-500 dark:text-slate-400">
                    <span className="flex items-center gap-1">
                      <User className="w-3.5 h-3.5 text-slate-400" />
                      <span className="font-medium text-slate-700 dark:text-slate-300">{item.authorName}</span>
                    </span>

                    {item.contactInfo && (
                      <span className="flex items-center gap-1">
                        <Mail className="w-3.5 h-3.5 text-slate-400" />
                        <span>{item.contactInfo}</span>
                      </span>
                    )}

                    <span className="flex items-center gap-1">
                      <Smartphone className="w-3.5 h-3.5 text-slate-400" />
                      <span>{item.deviceModel || 'Di động'} {item.appVersion ? `(v${item.appVersion})` : ''}</span>
                    </span>
                  </div>

                  {/* Action Buttons */}
                  <div className="flex items-center gap-2">
                    {item.status !== 'investigating' && (
                      <button
                        disabled={isLoading}
                        onClick={() => handleStatusChange(item.id, 'investigating')}
                        className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-blue-50 text-blue-700 hover:bg-blue-100 dark:bg-blue-950/40 dark:text-blue-300 border border-blue-200 dark:border-blue-800/60 transition-colors"
                      >
                        Đang xử lý
                      </button>
                    )}

                    {item.status !== 'resolved' && (
                      <button
                        disabled={isLoading}
                        onClick={() => handleStatusChange(item.id, 'resolved')}
                        className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-emerald-50 text-emerald-700 hover:bg-emerald-100 dark:bg-emerald-950/40 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800/60 transition-colors"
                      >
                        Đã xong
                      </button>
                    )}

                    {item.status !== 'open' && (
                      <button
                        disabled={isLoading}
                        onClick={() => handleStatusChange(item.id, 'open')}
                        className="px-2.5 py-1 text-xs font-semibold rounded-lg bg-slate-100 text-slate-700 hover:bg-slate-200 dark:bg-slate-800 dark:text-slate-300 transition-colors"
                      >
                        Mở lại
                      </button>
                    )}

                    <button
                      disabled={isLoading}
                      onClick={() => handleDelete(item.id)}
                      className="p-1 text-slate-400 hover:text-rose-500 rounded-lg hover:bg-rose-50 dark:hover:bg-rose-950/40 transition-colors"
                      title="Xóa báo cáo"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
};
