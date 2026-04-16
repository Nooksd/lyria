import { useState, useEffect, useRef } from 'react';
import api from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface CookiesInfo {
  exists: boolean;
  content: string;
  size: number;
  modifiedAt?: string;
}

export default function Cookies() {
  const [info, setInfo] = useState<CookiesInfo | null>(null);
  const [loading, setLoading] = useState(true);
  const [uploading, setUploading] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editContent, setEditContent] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { toasts, show } = useToast();

  const loadCookies = async () => {
    try {
      const res = await api.get('/admin/cookies');
      setInfo(res.data);
    } catch {
      show('Erro ao carregar cookies', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadCookies();
  }, []);

  const handleUploadFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // Validate it looks like a cookies file
    const text = await file.text();
    if (!text.trim()) {
      show('Arquivo vazio', 'error');
      return;
    }

    setUploading(true);
    try {
      const formData = new FormData();
      formData.append('file', file);
      await api.post('/admin/cookies', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      show('Cookies atualizados com sucesso', 'success');
      await loadCookies();
      setEditing(false);
    } catch {
      show('Erro ao enviar cookies', 'error');
    } finally {
      setUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const handleSaveEdit = async () => {
    if (!editContent.trim()) {
      show('Conteúdo vazio', 'error');
      return;
    }
    setUploading(true);
    try {
      await api.post('/admin/cookies', { content: editContent });
      show('Cookies atualizados com sucesso', 'success');
      await loadCookies();
      setEditing(false);
    } catch {
      show('Erro ao salvar cookies', 'error');
    } finally {
      setUploading(false);
    }
  };

  const handleDelete = async () => {
    if (!confirm('Tem certeza que deseja remover o cookies.txt? Importações podem falhar sem ele.')) return;
    try {
      await api.delete('/admin/cookies');
      show('Cookies removidos', 'success');
      await loadCookies();
      setEditing(false);
    } catch {
      show('Erro ao remover cookies', 'error');
    }
  };

  const startEdit = () => {
    setEditContent(info?.content || '');
    setEditing(true);
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    return `${(bytes / 1024).toFixed(1)} KB`;
  };

  if (loading) {
    return <div className="loading"><div className="spinner" /> Carregando...</div>;
  }

  return (
    <>
      <ToastContainer toasts={toasts} />

      <div className="page-header">
        <h1>Cookies (yt-dlp)</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button
            className="btn btn-primary"
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
          >
            Enviar arquivo
          </button>
          {info?.exists && !editing && (
            <button className="btn" onClick={startEdit}>
              Editar
            </button>
          )}
          {!info?.exists && !editing && (
            <button className="btn" onClick={startEdit}>
              Criar manualmente
            </button>
          )}
          {info?.exists && (
            <button className="btn btn-danger" onClick={handleDelete}>
              Remover
            </button>
          )}
        </div>
        <input
          ref={fileInputRef}
          type="file"
          accept=".txt"
          style={{ display: 'none' }}
          onChange={handleUploadFile}
        />
      </div>

      {/* Status card */}
      <div className="card" style={{ marginBottom: 24, padding: 20 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
          <div
            style={{
              width: 10,
              height: 10,
              borderRadius: '50%',
              background: info?.exists ? '#22c55e' : '#ef4444',
            }}
          />
          <span style={{ fontWeight: 600 }}>
            {info?.exists ? 'cookies.txt presente' : 'cookies.txt ausente'}
          </span>
          {info?.exists && (
            <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>
              — {formatSize(info.size)}
              {info.modifiedAt && ` · Modificado em ${new Date(info.modifiedAt).toLocaleString('pt-BR')}`}
            </span>
          )}
        </div>

        {!info?.exists && !editing && (
          <div style={{ color: 'var(--text-muted)', fontSize: 14 }}>
            <p>Nenhum arquivo de cookies configurado. As importações podem falhar com erro de bot do YouTube.</p>
            <p style={{ marginTop: 8 }}>
              Para exportar cookies do YouTube, use uma extensão como{' '}
              <strong>Get cookies.txt LOCALLY</strong> no Chrome/Firefox enquanto logado no YouTube.
            </p>
          </div>
        )}
      </div>

      {/* Edit mode */}
      {editing && (
        <div className="card" style={{ padding: 20, marginBottom: 24 }}>
          <div style={{ marginBottom: 12, fontWeight: 600 }}>
            {info?.exists ? 'Editar cookies.txt' : 'Criar cookies.txt'}
          </div>
          <textarea
            value={editContent}
            onChange={(e) => setEditContent(e.target.value)}
            style={{
              width: '100%',
              minHeight: 300,
              fontFamily: 'monospace',
              fontSize: 12,
              padding: 12,
              borderRadius: 8,
              border: '1px solid var(--border)',
              background: 'var(--bg-secondary)',
              color: 'var(--text)',
              resize: 'vertical',
            }}
            placeholder="Cole aqui o conteúdo do cookies.txt exportado do navegador..."
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <button className="btn btn-primary" onClick={handleSaveEdit} disabled={uploading}>
              {uploading ? 'Salvando...' : 'Salvar'}
            </button>
            <button className="btn" onClick={() => setEditing(false)}>
              Cancelar
            </button>
          </div>
        </div>
      )}

      {/* Preview (read-only) */}
      {info?.exists && !editing && (
        <div className="card" style={{ padding: 0 }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)' }}>
            <h2 style={{ fontSize: 16, fontWeight: 600 }}>Conteúdo do arquivo</h2>
          </div>
          <pre
            style={{
              padding: 16,
              margin: 0,
              fontFamily: 'monospace',
              fontSize: 12,
              maxHeight: 400,
              overflow: 'auto',
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-all',
              color: 'var(--text-muted)',
            }}
          >
            {info.content}
          </pre>
        </div>
      )}

      {/* Help section */}
      <div className="card" style={{ marginTop: 24, padding: 20 }}>
        <h3 style={{ fontSize: 14, fontWeight: 600, marginBottom: 12 }}>Como obter cookies do YouTube</h3>
        <ol style={{ paddingLeft: 20, fontSize: 13, color: 'var(--text-muted)', lineHeight: 1.8 }}>
          <li>Instale a extensão <strong>Get cookies.txt LOCALLY</strong> no Chrome ou Firefox</li>
          <li>Acesse <strong>youtube.com</strong> e faça login com uma conta Google</li>
          <li>Clique na extensão e exporte os cookies como <strong>.txt</strong></li>
          <li>Envie o arquivo aqui usando o botão "Enviar arquivo"</li>
        </ol>
        <div style={{ marginTop: 12, padding: 12, borderRadius: 8, background: 'var(--bg-secondary)', fontSize: 13 }}>
          <strong>Dica:</strong> Quando o yt-dlp detecta bloqueio de bot durante a importação, ele pausa automaticamente
          e aguarda. Se você atualizar o cookies.txt aqui enquanto ele espera, a importação continua imediatamente
          com os novos cookies.
        </div>
      </div>
    </>
  );
}
