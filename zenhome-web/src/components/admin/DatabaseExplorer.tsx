import React, { useState, useEffect } from 'react';
import { 
  Database, 
  Folder, 
  FileText, 
  Search, 
  Copy, 
  Check, 
  ExternalLink,
  Clock,
  HardDrive,
  RefreshCw,
  Radio
} from 'lucide-react';
import { RealDatabaseDoc } from '../../types/admin';

interface DatabaseExplorerProps {
  documents: RealDatabaseDoc[];
}

export const DatabaseExplorer: React.FC<DatabaseExplorerProps> = ({
  documents
}) => {
  const collectionNames = Array.from(new Set(documents.map(d => d.collection)));
  const [selectedCollection, setSelectedCollection] = useState<string>(collectionNames[0] || 'users');
  const [selectedDocPath, setSelectedDocPath] = useState<string>('');
  const [searchDoc, setSearchDoc] = useState('');
  const [copied, setCopied] = useState(false);

  // Sync selected collection when collections change
  useEffect(() => {
    if (collectionNames.length > 0 && !collectionNames.includes(selectedCollection)) {
      setSelectedCollection(collectionNames[0]);
    }
  }, [collectionNames, selectedCollection]);

  // Sync selected doc path when collection changes
  useEffect(() => {
    const firstInCol = documents.find(d => d.collection === selectedCollection);
    if (firstInCol && (!selectedDocPath || !documents.some(d => d.path === selectedDocPath))) {
      setSelectedDocPath(firstInCol.path);
    }
  }, [selectedCollection, documents, selectedDocPath]);

  const docsInCollection = documents.filter(d => 
    d.collection === selectedCollection &&
    (searchDoc === '' || d.id.toLowerCase().includes(searchDoc.toLowerCase()))
  );

  const activeDoc = documents.find(d => d.path === selectedDocPath) || docsInCollection[0];

  const handleCopyJson = () => {
    if (!activeDoc) return;
    navigator.clipboard.writeText(JSON.stringify(activeDoc.data, null, 2));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-4">
      
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-slate-50 flex items-center gap-2">
            <Database className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
            <span>Cơ sở dữ liệu đám mây (Cloud Firestore Thực tế)</span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Duyệt cây Collections và Documents thực tế đọc trực tiếp từ project <code>smarthome-98dd7</code>.
          </p>
        </div>

        {/* Live sync badge */}
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-indigo-50/80 dark:bg-indigo-950/40 border border-indigo-200 dark:border-indigo-800/60 text-xs font-semibold text-indigo-700 dark:text-indigo-300">
          <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
          <span>Cập nhật liên tục: {documents.length} Document trực tiếp</span>
        </div>
      </div>

      {/* Explorer Layout */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-4 min-h-[550px]">
        
        {/* Collections Pane (4 cols) */}
        <div className="md:col-span-4 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-4 flex flex-col justify-between shadow-xs">
          <div>
            <div className="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-2">
              Collections trên Firestore ({collectionNames.length})
            </div>

            <div className="space-y-1">
              {collectionNames.map((col) => {
                const count = documents.filter(d => d.collection === col).length;
                const isSelected = selectedCollection === col;

                return (
                  <button
                    key={col}
                    onClick={() => {
                      setSelectedCollection(col);
                      const firstInCol = documents.find(d => d.collection === col);
                      if (firstInCol) setSelectedDocPath(firstInCol.path);
                    }}
                    className={`w-full flex items-center justify-between px-3 py-2 rounded-xl text-xs font-semibold transition-all ${
                      isSelected
                        ? 'bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800/60'
                        : 'text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-800'
                    }`}
                  >
                    <div className="flex items-center gap-2 min-w-0 flex-1">
                      <Folder className={`w-4 h-4 shrink-0 ${isSelected ? 'text-indigo-600 dark:text-indigo-400 fill-indigo-500/20' : 'text-slate-400'}`} />
                      <span className="truncate">{col}</span>
                    </div>
                    <span className="font-mono text-[10px] opacity-75 shrink-0 ml-1">{count} doc</span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="pt-4 border-t border-slate-100 dark:border-slate-800 text-[11px] text-slate-500 dark:text-slate-400 space-y-1">
            <div className="flex justify-between">
              <span>Firebase Project:</span>
              <strong className="text-indigo-600 dark:text-indigo-400 font-mono">smarthome-98dd7</strong>
            </div>
            <div className="flex justify-between">
              <span>Cơ chế Real-time:</span>
              <span className="text-emerald-500 font-semibold font-mono">In-Memory Cache (4s TTL)</span>
            </div>
            <div className="flex justify-between">
              <span>Vùng Cloud:</span>
              <span className="font-mono">asia-southeast1</span>
            </div>
          </div>
        </div>

        {/* Documents List Pane (3 cols) */}
        <div className="md:col-span-3 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-4 flex flex-col shadow-xs">
          <div className="relative mb-3">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchDoc}
              onChange={(e) => setSearchDoc(e.target.value)}
              placeholder="Lọc Document ID..."
              className="w-full pl-8 pr-3 py-1.5 text-xs rounded-xl bg-slate-50 dark:bg-slate-950 border border-slate-200 dark:border-slate-800 text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div className="flex-1 overflow-y-auto space-y-1.5 pr-1 scrollbar-thin">
            {docsInCollection.map((doc) => {
              const isSelected = activeDoc?.path === doc.path;

              return (
                <div
                  key={doc.path}
                  onClick={() => setSelectedDocPath(doc.path)}
                  className={`p-3 rounded-xl border cursor-pointer transition-all ${
                    isSelected
                      ? 'bg-white dark:bg-slate-900 border-indigo-500 text-slate-900 dark:text-slate-50 shadow-xs ring-1 ring-indigo-500/30'
                      : 'bg-slate-50 dark:bg-slate-950/70 border-slate-200 dark:border-slate-800 hover:bg-slate-100 dark:hover:bg-slate-800'
                  }`}
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <FileText className={`w-3.5 h-3.5 shrink-0 ${isSelected ? 'text-indigo-600 dark:text-indigo-400' : 'text-slate-400'}`} />
                    <span className="font-mono text-xs font-bold truncate">
                      {doc.id}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-[10px] text-slate-500 dark:text-slate-400 mt-1 font-mono">
                    <span>{doc.sizeBytes} B</span>
                    <span className="truncate ml-1">{doc.updatedAt.split(' ')[1] || doc.updatedAt}</span>
                  </div>
                </div>
              );
            })}

            {docsInCollection.length === 0 && (
              <div className="text-center py-10 text-xs text-slate-500 dark:text-slate-400">
                Không có Document nào.
              </div>
            )}
          </div>
        </div>

        {/* Document JSON Inspector (5 cols) */}
        <div className="md:col-span-5 rounded-2xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-800 p-4 flex flex-col justify-between shadow-xs min-w-0">
          <div>
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800 mb-3 gap-2">
              <div className="min-w-0 flex-1">
                <div className="text-[10px] text-slate-500 dark:text-slate-400 uppercase font-bold">
                  Document Path
                </div>
                <div className="text-xs font-mono font-bold text-indigo-700 dark:text-indigo-400 truncate">
                  /{activeDoc?.path || 'chưa chọn document'}
                </div>
              </div>

              <button
                onClick={handleCopyJson}
                className="flex items-center gap-1 px-2.5 py-1 text-xs font-semibold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors shrink-0"
                title="Sao chép JSON"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copied ? 'Đã chép' : 'Copy'}</span>
              </button>
            </div>

            <div className="w-full max-w-full rounded-xl bg-slate-50 dark:bg-slate-950 p-4 font-mono text-xs text-indigo-600 dark:text-indigo-300 overflow-x-auto max-h-[420px] border border-slate-200 dark:border-slate-800 scrollbar-thin">
              <pre className="whitespace-pre font-mono">{activeDoc ? JSON.stringify(activeDoc.data, null, 2) : '// Chưa chọn document'}</pre>
            </div>
          </div>

          <div className="text-[11px] text-slate-500 dark:text-slate-400 pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between font-mono gap-2">
            <span className="truncate">Cập nhật: {activeDoc?.updatedAt}</span>
            <span className="shrink-0">{activeDoc?.sizeBytes} bytes</span>
          </div>
        </div>

      </div>

    </div>
  );
};
