import { useState } from 'react';
import api from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface OrphanFile {
  path: string;
  category: string;
  size: number;
}

interface CategoryInfo {
  files: number;
  size: number;
}

interface ScanResult {
  orphans: OrphanFile[];
  totalSize: number;
  totalFiles: number;
  byCategory: Record<string, CategoryInfo>;
}

const categoryLabels: Record<string, string> = {
  music: 'Músicas (.m4a)',
  avatar: 'Avatares (artistas)',
  banner: 'Banners (artistas)',
  cover: 'Capas (álbuns)',
  music_cover: 'Capas (singles)',
  lyrics: 'Letras (.lrc)',
};

function formatBytes(bytes: number) {
  if (bytes === 0) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export default function Cleanup() {
  const [scanResult, setScanResult] = useState<ScanResult | null>(null);
  const [scanning, setScanning] = useState(false);
  const [cleaning, setCleaning] = useState(false);
  const { toasts, show } = useToast();

  const handleScan = async () => {
    setScanning(true);
    setScanResult(null);
    try {
      const res = await api.get('/admin/cleanup/scan');
      setScanResult(res.data);
      if (res.data.totalFiles === 0) {
        show('Nenhum arquivo órfão encontrado', 'success');
      } else {
        show(`${res.data.totalFiles} arquivos órfãos encontrados (${formatBytes(res.data.totalSize)})`);
      }
    } catch {
      show('Erro ao escanear arquivos', 'error');
    } finally {
      setScanning(false);
    }
  };

  const handleClean = async () => {
    if (!scanResult || scanResult.totalFiles === 0) return;
    if (!confirm(`Tem certeza que deseja remover ${scanResult.totalFiles} arquivos órfãos (${formatBytes(scanResult.totalSize)})?`)) return;

    setCleaning(true);
    try {
      const res = await api.delete('/admin/cleanup/clean');
      show(`${res.data.deleted} arquivos removidos — ${formatBytes(res.data.freedBytes)} liberados`, 'success');
      if (res.data.errors?.length > 0) {
        show(`${res.data.errors.length} erros ao remover`, 'error');
      }
      setScanResult(null);
    } catch {
      show('Erro ao limpar arquivos', 'error');
    } finally {
      setCleaning(false);
    }
  };

  return (
    <>
      <ToastContainer toasts={toasts} />

      <div className="page-header">
        <h1>Limpeza de Arquivos</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn btn-primary" onClick={handleScan} disabled={scanning || cleaning}>
            {scanning ? 'Escaneando...' : 'Escanear'}
          </button>
          {scanResult && scanResult.totalFiles > 0 && (
            <button className="btn btn-danger" onClick={handleClean} disabled={cleaning}>
              {cleaning ? 'Limpando...' : `Limpar ${scanResult.totalFiles} arquivos`}
            </button>
          )}
        </div>
      </div>

      {/* Info card */}
      <div className="card" style={{ marginBottom: 24, padding: 20 }}>
        <div style={{ color: 'var(--text-muted)', fontSize: 14 }}>
          <p>
            Escaneia as pastas de uploads em busca de arquivos que não possuem objetos correspondentes no banco de dados.
            Esses arquivos são restos de artistas, álbuns ou músicas que foram deletados.
          </p>
          <p style={{ marginTop: 8 }}>
            Categorias verificadas: músicas, avatares, banners, capas de álbum, capas de singles e letras.
          </p>
        </div>
      </div>

      {/* Results */}
      {scanResult && (
        <>
          {/* Summary cards */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 16, marginBottom: 24 }}>
            <div className="card" style={{ padding: 20, textAlign: 'center' }}>
              <div style={{ fontSize: 28, fontWeight: 700, color: scanResult.totalFiles > 0 ? '#ef4444' : '#22c55e' }}>
                {scanResult.totalFiles}
              </div>
              <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>Arquivos Órfãos</div>
            </div>
            <div className="card" style={{ padding: 20, textAlign: 'center' }}>
              <div style={{ fontSize: 28, fontWeight: 700, color: 'var(--primary)' }}>
                {formatBytes(scanResult.totalSize)}
              </div>
              <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 4 }}>Espaço Recuperável</div>
            </div>
          </div>

          {/* By category */}
          {Object.keys(scanResult.byCategory).length > 0 && (
            <div className="card" style={{ marginBottom: 24 }}>
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)', fontWeight: 600 }}>
                Por Categoria
              </div>
              <div style={{ padding: 0 }}>
                {Object.entries(scanResult.byCategory).map(([cat, info]) => (
                  <div
                    key={cat}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      padding: '12px 20px',
                      borderBottom: '1px solid var(--border)',
                    }}
                  >
                    <span>{categoryLabels[cat] || cat}</span>
                    <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                      {info.files} {info.files === 1 ? 'arquivo' : 'arquivos'} — {formatBytes(info.size)}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* File list */}
          {scanResult.orphans.length > 0 && (
            <div className="card">
              <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)', fontWeight: 600 }}>
                Arquivos ({scanResult.orphans.length})
              </div>
              <div style={{ maxHeight: 400, overflow: 'auto' }}>
                {scanResult.orphans.map((o, i) => (
                  <div
                    key={i}
                    style={{
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                      padding: '8px 20px',
                      borderBottom: '1px solid var(--border)',
                      fontSize: 13,
                      fontFamily: 'monospace',
                    }}
                  >
                    <span style={{ color: 'var(--text-muted)' }}>{o.path}</span>
                    <span style={{ whiteSpace: 'nowrap', marginLeft: 16 }}>{formatBytes(o.size)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {scanResult.totalFiles === 0 && (
            <div className="card" style={{ padding: 40, textAlign: 'center' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>✓</div>
              <div style={{ fontSize: 16, fontWeight: 600 }}>Tudo limpo!</div>
              <div style={{ color: 'var(--text-muted)', marginTop: 4 }}>
                Não há arquivos órfãos nas pastas de uploads.
              </div>
            </div>
          )}
        </>
      )}
    </>
  );
}
