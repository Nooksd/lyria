import { useState, useEffect, useRef, useCallback } from 'react';
import api, { API_BASE } from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface ImportJob {
  _id: string;
  spotifyUrl: string;
  artistName: string;
  status: string;
  progress: number;
  total: number;
  albums: number;
  musics: number;
  failed: number;
  failedItems?: { trackName: string; reason: string }[];
  createdAt: string;
  finishedAt?: string;
}

interface LogEntry {
  type: string;
  message: string;
  time: string;
}

export default function Imports() {
  const [jobs, setJobs] = useState<ImportJob[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedJob, setSelectedJob] = useState<string | null>(null);
  const [jobDetail, setJobDetail] = useState<ImportJob | null>(null);
  const [logs, setLogs] = useState<LogEntry[]>([]);
  const [streaming, setStreaming] = useState(false);
  const [autoImportEnabled, setAutoImportEnabled] = useState(false);
  const [autoImportGenre, setAutoImportGenre] = useState('');
  const [autoImportLoading, setAutoImportLoading] = useState(false);
  const [fingerprintLoading, setFingerprintLoading] = useState(false);
  const logRef = useRef<HTMLDivElement>(null);
  const eventSourceRef = useRef<AbortController | null>(null);
  const { toasts, show } = useToast();

  const loadJobs = useCallback(async () => {
    try {
      const res = await api.get('/admin/import/jobs');
      setJobs(res.data.jobs || []);
    } catch {
      show('Erro ao carregar importações', 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  const loadAutoImportStatus = useCallback(async () => {
    try {
      const res = await api.get('/admin/autoimport/status');
      setAutoImportEnabled(res.data.enabled);
      setAutoImportGenre(res.data.genre || '');
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    loadJobs();
    loadAutoImportStatus();
    const interval = setInterval(() => {
      loadJobs();
      loadAutoImportStatus();
    }, 5000);
    return () => clearInterval(interval);
  }, [loadJobs, loadAutoImportStatus]);

  const toggleAutoImport = async () => {
    setAutoImportLoading(true);
    try {
      const res = await api.post('/admin/autoimport/toggle', { enabled: !autoImportEnabled });
      setAutoImportEnabled(res.data.enabled);
      show(res.data.enabled ? 'Autoimport ativado' : 'Autoimport desativado');
    } catch {
      show('Erro ao alterar autoimport', 'error');
    } finally {
      setAutoImportLoading(false);
    }
  };

  const generateAllFingerprints = async () => {
    if (fingerprintLoading) {
      return;
    }

    const confirmed = confirm(
      'Isso vai recriar as fingerprints de todas as músicas cadastradas. Deseja continuar?'
    );

    if (!confirmed) {
      return;
    }

    setFingerprintLoading(true);
    try {
      const res = await api.post('/admin/fingerprint/generate-all');
      const total = res.data?.total;
      show(
        typeof total === 'number'
          ? `Geração iniciada para ${total} músicas`
          : 'Geração de fingerprints iniciada'
      );
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao iniciar geração de fingerprints', 'error');
    } finally {
      setFingerprintLoading(false);
    }
  };

  const openJob = async (jobId: string) => {
    // Close previous stream
    if (eventSourceRef.current) {
      eventSourceRef.current.abort();
      eventSourceRef.current = null;
    }

    setSelectedJob(jobId);
    setLogs([]);
    setStreaming(false);

    try {
      const res = await api.get(`/admin/import/jobs/${jobId}`);
      setJobDetail(res.data);
    } catch {
      show('Erro ao carregar detalhes', 'error');
      return;
    }

    // Start SSE stream
    const abortController = new AbortController();
    eventSourceRef.current = abortController;

    try {
      const token = localStorage.getItem('admin_token') || '';
      const response = await fetch(`${API_BASE}/admin/import/jobs/${jobId}/logs`, {
        headers: { Authorization: token },
        signal: abortController.signal,
      });

      if (!response.ok || !response.body) return;

      setStreaming(true);
      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        buffer += decoder.decode(value, { stream: true });
        const parts = buffer.split('\n\n');
        buffer = parts.pop() || '';

        for (const part of parts) {
          const lines = part.split('\n');
          let eventType = '';
          let data = '';

          for (const line of lines) {
            if (line.startsWith('event: ')) eventType = line.slice(7);
            else if (line.startsWith('data: ')) data = line.slice(6);
          }

          if (!data) continue;

          try {
            const parsed = JSON.parse(data);

            if (eventType === 'log') {
              setLogs((prev) => [...prev, parsed]);
            } else if (eventType === 'status') {
              setJobDetail((prev) => prev ? { ...prev, ...parsed } : prev);
              // Refresh job list when status changes
              loadJobs();
            }
          } catch {
            // skip malformed events
          }
        }
      }
    } catch (err: any) {
      if (err.name !== 'AbortError') {
        console.error('SSE error:', err);
      }
    } finally {
      setStreaming(false);
    }
  };

  const cancelJob = async (jobId: string) => {
    if (!confirm('Cancelar esta importação?')) return;
    try {
      await api.post(`/admin/import/jobs/${jobId}/cancel`);
      show('Cancelamento solicitado');
      loadJobs();
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao cancelar', 'error');
    }
  };

  const closeDetail = () => {
    if (eventSourceRef.current) {
      eventSourceRef.current.abort();
      eventSourceRef.current = null;
    }
    setSelectedJob(null);
    setJobDetail(null);
    setLogs([]);
    setStreaming(false);
  };

  useEffect(() => {
    if (logRef.current) {
      logRef.current.scrollTop = logRef.current.scrollHeight;
    }
  }, [logs]);

  useEffect(() => {
    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.abort();
      }
    };
  }, []);

  const statusBadge = (status: string) => {
    const colors: Record<string, { bg: string; text: string }> = {
      queued: { bg: '#3b3b00', text: '#f59e0b' },
      running: { bg: '#002244', text: '#38bdf8' },
      completed: { bg: '#003300', text: '#22c55e' },
      failed: { bg: '#330000', text: '#ef4444' },
      cancelled: { bg: '#2a2a2a', text: '#888' },
    };
    const labels: Record<string, string> = {
      queued: 'Na fila',
      running: 'Em andamento',
      completed: 'Concluído',
      failed: 'Falhou',
      cancelled: 'Cancelado',
    };
    const c = colors[status] || colors.queued;
    return (
      <span style={{
        padding: '2px 10px',
        borderRadius: 12,
        fontSize: 12,
        fontWeight: 600,
        background: c.bg,
        color: c.text,
      }}>
        {labels[status] || status}
      </span>
    );
  };

  return (
    <>
      <ToastContainer toasts={toasts} />
      <div className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <h1>Importações</h1>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button
            className="btn btn-primary"
            onClick={generateAllFingerprints}
            disabled={fingerprintLoading}
            style={{ opacity: fingerprintLoading ? 0.7 : 1 }}
          >
            {fingerprintLoading ? 'Gerando fingerprints...' : 'Gerar fingerprints'}
          </button>
          {autoImportEnabled && autoImportGenre && (
            <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>
              Gênero atual: <strong style={{ color: 'var(--accent)' }}>{autoImportGenre}</strong>
            </span>
          )}
          <label
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              cursor: autoImportLoading ? 'wait' : 'pointer',
              userSelect: 'none',
              fontSize: 14,
              fontWeight: 500,
            }}
          >
            <span>Autoimport</span>
            <div
              onClick={autoImportLoading ? undefined : toggleAutoImport}
              style={{
                width: 44,
                height: 24,
                borderRadius: 12,
                background: autoImportEnabled ? 'var(--accent)' : 'var(--bg-input)',
                position: 'relative',
                transition: 'background 0.2s ease',
                border: '1px solid var(--border)',
                opacity: autoImportLoading ? 0.5 : 1,
              }}
            >
              <div style={{
                width: 18,
                height: 18,
                borderRadius: '50%',
                background: '#fff',
                position: 'absolute',
                top: 2,
                left: autoImportEnabled ? 22 : 2,
                transition: 'left 0.2s ease',
                boxShadow: '0 1px 3px rgba(0,0,0,.3)',
              }} />
            </div>
          </label>
        </div>
      </div>

      {selectedJob && jobDetail ? (
        <div className="card" style={{ padding: 24 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
            <div>
              <button className="btn btn-ghost btn-sm" onClick={closeDetail} style={{ marginRight: 12 }}>← Voltar</button>
              <span style={{ fontSize: 18, fontWeight: 600 }}>{jobDetail.artistName || 'Importação'}</span>
              <span style={{ marginLeft: 12 }}>{statusBadge(jobDetail.status)}</span>
            </div>
            {(jobDetail.status === 'queued' || jobDetail.status === 'running') && (
              <button className="btn btn-sm" style={{ background: 'var(--danger)', color: '#fff' }} onClick={() => cancelJob(selectedJob)}>
                Cancelar
              </button>
            )}
          </div>

          <div style={{ display: 'flex', gap: 16, marginBottom: 16, flexWrap: 'wrap' }}>
            <div style={{ background: 'var(--bg-input)', padding: '10px 16px', borderRadius: 8, fontSize: 13 }}>
              <span style={{ color: 'var(--text-muted)' }}>URL:</span>{' '}
              <span style={{ wordBreak: 'break-all' }}>{jobDetail.spotifyUrl}</span>
            </div>
            {jobDetail.total > 0 && (
              <div style={{ background: 'var(--bg-input)', padding: '10px 16px', borderRadius: 8, fontSize: 13 }}>
                <span style={{ color: 'var(--text-muted)' }}>Progresso:</span>{' '}
                {jobDetail.progress}/{jobDetail.total}
              </div>
            )}
            {(jobDetail.status === 'completed' || jobDetail.status === 'cancelled' || jobDetail.status === 'failed') && (
              <>
                <div style={{ background: 'var(--bg-input)', padding: '10px 16px', borderRadius: 8, fontSize: 13 }}>
                  <span style={{ color: 'var(--text-muted)' }}>Álbuns:</span> {jobDetail.albums}
                </div>
                <div style={{ background: 'var(--bg-input)', padding: '10px 16px', borderRadius: 8, fontSize: 13 }}>
                  <span style={{ color: 'var(--text-muted)' }}>Músicas:</span> {jobDetail.musics}
                </div>
                <div style={{ background: 'var(--bg-input)', padding: '10px 16px', borderRadius: 8, fontSize: 13 }}>
                  <span style={{ color: 'var(--text-muted)' }}>Falhas:</span>{' '}
                  <span style={{ color: jobDetail.failed > 0 ? 'var(--danger)' : 'var(--success)' }}>{jobDetail.failed}</span>
                </div>
              </>
            )}
          </div>

          {jobDetail.total > 0 && (jobDetail.status === 'running' || jobDetail.status === 'completed') && (
            <div style={{ marginBottom: 16 }}>
              <div style={{ height: 6, background: 'var(--bg)', borderRadius: 3, overflow: 'hidden' }}>
                <div style={{
                  height: '100%',
                  width: `${Math.round((jobDetail.progress / jobDetail.total) * 100)}%`,
                  background: jobDetail.status === 'completed' ? 'var(--success)' : 'var(--accent)',
                  borderRadius: 3,
                  transition: 'width 0.3s ease',
                }} />
              </div>
            </div>
          )}

          {/* Logs or Summary */}
          {(jobDetail.status === 'completed' || jobDetail.status === 'failed' || jobDetail.status === 'cancelled') && jobDetail.failedItems && jobDetail.failedItems.length > 0 ? (
            <div>
              <h3 style={{ fontSize: 15, marginBottom: 12 }}>Faixas com falha ({jobDetail.failedItems.length})</h3>
              <div style={{
                maxHeight: 300,
                overflowY: 'auto',
                background: '#0a0a0a',
                borderRadius: 8,
                border: '1px solid var(--border)',
              }}>
                <table style={{ width: '100%', fontSize: 13 }}>
                  <thead>
                    <tr>
                      <th style={{ padding: '8px 12px', textAlign: 'left', borderBottom: '1px solid var(--border)', color: 'var(--text-muted)' }}>Faixa</th>
                      <th style={{ padding: '8px 12px', textAlign: 'left', borderBottom: '1px solid var(--border)', color: 'var(--text-muted)' }}>Motivo</th>
                    </tr>
                  </thead>
                  <tbody>
                    {jobDetail.failedItems.map((item, i) => (
                      <tr key={i}>
                        <td style={{ padding: '8px 12px', borderBottom: '1px solid var(--border)' }}>{item.trackName}</td>
                        <td style={{ padding: '8px 12px', borderBottom: '1px solid var(--border)', color: 'var(--danger)', fontSize: 12, wordBreak: 'break-all' }}>{item.reason}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ) : (
            <div>
              <h3 style={{ fontSize: 15, marginBottom: 12 }}>
                {streaming ? 'Logs em tempo real' : 'Logs'}
              </h3>
              <div
                ref={logRef}
                style={{
                  height: 400,
                  overflowY: 'auto',
                  background: '#0a0a0a',
                  borderRadius: 8,
                  padding: 12,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  lineHeight: 1.6,
                  border: '1px solid var(--border)',
                }}
              >
                {logs.map((log, i) => (
                  <div key={i} style={{
                    color:
                      log.type === 'error' ? '#ef4444' :
                      log.type === 'done' ? '#22c55e' :
                      '#a3a3a3',
                  }}>
                    {log.message}
                  </div>
                ))}
                {streaming && (
                  <div style={{ color: 'var(--accent)', marginTop: 4 }}>⏳ Processando...</div>
                )}
                {logs.length === 0 && !streaming && (
                  <div style={{ color: 'var(--text-muted)' }}>Nenhum log disponível.</div>
                )}
              </div>
            </div>
          )}
        </div>
      ) : (
        <div className="card">
          {loading ? (
            <div className="loading"><div className="spinner" /> Carregando...</div>
          ) : jobs.length === 0 ? (
            <div className="empty-state"><p>Nenhuma importação realizada.</p></div>
          ) : (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>Artista</th>
                    <th>URL</th>
                    <th>Status</th>
                    <th>Progresso</th>
                    <th>Álbuns</th>
                    <th>Músicas</th>
                    <th>Falhas</th>
                    <th>Criado em</th>
                    <th>Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {jobs.map((job) => (
                    <tr key={job._id}>
                      <td style={{ fontWeight: 500 }}>{job.artistName || '—'}</td>
                      <td>
                        <span className="truncate" style={{ maxWidth: 200 }}>{job.spotifyUrl}</span>
                      </td>
                      <td>{statusBadge(job.status)}</td>
                      <td>
                        {job.total > 0
                          ? `${job.progress}/${job.total}`
                          : '—'
                        }
                      </td>
                      <td>{job.albums || 0}</td>
                      <td>{job.musics || 0}</td>
                      <td style={{ color: job.failed > 0 ? 'var(--danger)' : undefined }}>
                        {job.failed || 0}
                      </td>
                      <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                        {new Date(job.createdAt).toLocaleString('pt-BR')}
                      </td>
                      <td>
                        <div className="actions-cell">
                          <button className="btn btn-sm btn-primary" onClick={() => openJob(job._id)}>
                            Ver
                          </button>
                          {(job.status === 'queued' || job.status === 'running') && (
                            <button className="btn-icon danger" title="Cancelar" onClick={() => cancelJob(job._id)}>
                              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}
    </>
  );
}
