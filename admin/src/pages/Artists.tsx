import { useState, useEffect, useRef, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import api, { API_BASE } from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface Artist {
  _id: string;
  name: string;
  genres: string[];
  avatarUrl: string;
  bannerUrl: string;
  bio: string;
  color: string;
  createdAt: string;
}

const EMPTY: Partial<Artist> & { genreInput?: string } = {
  name: '',
  genres: [],
  bio: '',
  color: '#8b5cf6',
  genreInput: '',
};

export default function Artists() {
  const navigate = useNavigate();
  const [artists, setArtists] = useState<Artist[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<'create' | 'edit' | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [editId, setEditId] = useState('');
  const [saving, setSaving] = useState(false);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null);
  const { toasts, show } = useToast();

  // Spotify import state
  const [importModal, setImportModal] = useState(false);
  const [spotifyUrl, setSpotifyUrl] = useState('');
  const [importing, setImporting] = useState(false);
  const [importDone, setImportDone] = useState(false);
  const [importLog, setImportLog] = useState<{ type: string; message: string }[]>([]);
  const [importProgress, setImportProgress] = useState<{ current: number; total: number } | null>(null);
  const logRef = useRef<HTMLDivElement>(null);

  const limit = 20;

  const load = async (p = page) => {
    setLoading(true);
    try {
      const res = await api.get(`/admin/artists?page=${p}&limit=${limit}`);
      setArtists(res.data.artists || []);
      setTotal(res.data.total || 0);
    } catch {
      show('Erro ao carregar artistas', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [page]);

  const openCreate = () => {
    setForm(EMPTY);
    setEditId('');
    setAvatarFile(null);
    setAvatarPreview(null);
    setModal('create');
  };

  const openEdit = (a: Artist) => {
    setForm({ name: a.name, genres: a.genres || [], bio: a.bio || '', color: a.color || '#8b5cf6', genreInput: '' });
    setEditId(a._id);
    setAvatarFile(null);
    setAvatarPreview(a.avatarUrl || null);
    setModal('edit');
  };

  const addGenre = () => {
    const g = (form.genreInput || '').trim();
    if (g && !form.genres?.includes(g)) {
      setForm({ ...form, genres: [...(form.genres || []), g], genreInput: '' });
    }
  };

  const removeGenre = (g: string) => {
    setForm({ ...form, genres: (form.genres || []).filter((x) => x !== g) });
  };

  const handleAvatarChange = (file: File | null) => {
    setAvatarFile(file);
    if (file) {
      const url = URL.createObjectURL(file);
      setAvatarPreview(url);
    } else {
      setAvatarPreview(null);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const body = { name: form.name, genres: form.genres, bio: form.bio, color: form.color };
      let artistId = editId;
      if (modal === 'create') {
        const res = await api.post('/admin/artist/create', body);
        artistId = res.data._id;
        show('Artista criado com sucesso');
      } else {
        await api.put(`/admin/artist/update/${editId}`, body);
        show('Artista atualizado com sucesso');
      }
      if (avatarFile && artistId) {
        const fd = new FormData();
        fd.append('avatar', avatarFile);
        await api.post(`/admin/image/artist/${artistId}`, fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }
      setModal(null);
      load();
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao salvar', 'error');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Deletar artista "${name}"? Todos os álbuns e músicas associados serão removidos.`)) return;
    try {
      await api.delete(`/admin/artist/delete/${id}`);
      show('Artista removido com sucesso');
      load();
    } catch {
      show('Erro ao deletar artista', 'error');
    }
  };

  const totalPages = Math.ceil(total / limit);

  const startImport = async () => {
    if (!spotifyUrl.trim()) return;
    setImporting(true);
    setImportDone(false);
    setImportLog([]);
    setImportProgress(null);

    try {
      const token = localStorage.getItem('admin_token') || '';
      const response = await fetch(
        `${API_BASE}/admin/import/spotify?url=${encodeURIComponent(spotifyUrl.trim())}`,
        { headers: { Authorization: token } }
      );

      if (!response.ok || !response.body) {
        setImportLog([{ type: 'error', message: 'Erro de conexão com o servidor' }]);
        setImporting(false);
        setImportDone(true);
        return;
      }

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
          let eventType = 'progress';
          let data = '';

          for (const line of lines) {
            if (line.startsWith('event: ')) eventType = line.slice(7);
            else if (line.startsWith('data: ')) data = line.slice(6);
          }

          if (!data) continue;

          try {
            const parsed = JSON.parse(data);
            setImportLog((prev) => [...prev, { type: eventType, message: parsed.message || '' }]);

            if (parsed.current && parsed.total) {
              setImportProgress({ current: parsed.current, total: parsed.total });
            }

            if (eventType === 'done' || eventType === 'error') {
              setImportDone(true);
              setImporting(false);
              if (eventType === 'done') load();
            }
          } catch {
            // skip malformed events
          }
        }

        if (logRef.current) {
          logRef.current.scrollTop = logRef.current.scrollHeight;
        }
      }
    } catch (err: any) {
      setImportLog((prev) => [...prev, { type: 'error', message: 'Conexão perdida: ' + (err.message || 'erro desconhecido') }]);
      setImporting(false);
      setImportDone(true);
    }
  };

  return (
    <>
      <ToastContainer toasts={toasts} />
      <div className="page-header">
        <h1>Artistas</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn btn-ghost" onClick={() => { setImportModal(true); setSpotifyUrl(''); setImportLog([]); setImporting(false); setImportDone(false); setImportProgress(null); }}>🎵 Importar do Spotify</button>
          <button className="btn btn-primary" onClick={openCreate}>+ Novo Artista</button>
        </div>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading"><div className="spinner" /> Carregando...</div>
        ) : artists.length === 0 ? (
          <div className="empty-state"><p>Nenhum artista cadastrado.</p></div>
        ) : (
          <>
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 48 }}>Foto</th>
                    <th>Nome</th>
                    <th>Gêneros</th>
                    <th>Cor</th>
                    <th>Bio</th>
                    <th>Criado em</th>
                    <th>Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {artists.map((a) => (
                    <tr key={a._id}>
                      <td>
                        <img className="table-thumb" src={a.avatarUrl} alt={a.name} onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                      </td>
                      <td style={{ fontWeight: 500 }}>{a.name}</td>
                      <td>
                        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                          {(a.genres || []).map((g) => (
                            <span key={g} className="badge badge-genre">{g}</span>
                          ))}
                        </div>
                      </td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span className="color-swatch" style={{ background: a.color || '#8b5cf6' }} />
                          <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{a.color || '—'}</span>
                        </div>
                      </td>
                      <td><span className="truncate">{a.bio || '—'}</span></td>
                      <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                        {new Date(a.createdAt).toLocaleDateString('pt-BR')}
                      </td>
                      <td>
                        <div className="actions-cell">
                          <button className="btn btn-sm btn-primary" title="Acessar" onClick={() => navigate(`/artists/${a._id}`)}>
                            Acessar
                          </button>
                          <button className="btn-icon" title="Editar" onClick={() => openEdit(a)}>
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                          </button>
                          <button className="btn-icon danger" title="Deletar" onClick={() => handleDelete(a._id, a.name)}>
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            {totalPages > 1 && (
              <div className="pagination">
                <span className="pagination-info">{total} artista(s) — Página {page} de {totalPages}</span>
                <div className="pagination-btns">
                  <button className="btn btn-ghost btn-sm" disabled={page <= 1} onClick={() => setPage(page - 1)}>Anterior</button>
                  <button className="btn btn-ghost btn-sm" disabled={page >= totalPages} onClick={() => setPage(page + 1)}>Próxima</button>
                </div>
              </div>
            )}
          </>
        )}
      </div>

      {modal && (
        <div className="modal-overlay" onClick={() => setModal(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{modal === 'create' ? 'Novo Artista' : 'Editar Artista'}</h2>
              <button className="btn-icon" onClick={() => setModal(null)}>✕</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Nome</label>
                  <input className="form-input" value={form.name || ''} onChange={(e) => setForm({ ...form, name: e.target.value })} required placeholder="Nome do artista" />
                </div>
                <div className="form-group">
                  <label>Bio</label>
                  <textarea className="form-input" rows={3} value={form.bio || ''} onChange={(e) => setForm({ ...form, bio: e.target.value })} placeholder="Biografia do artista" />
                </div>
                <div className="form-group">
                  <label>Gêneros</label>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <input
                      className="form-input"
                      style={{ flex: 1 }}
                      value={form.genreInput || ''}
                      onChange={(e) => setForm({ ...form, genreInput: e.target.value })}
                      placeholder="Ex: Rock, Pop..."
                      onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); addGenre(); } }}
                    />
                    <button type="button" className="btn btn-ghost btn-sm" onClick={addGenre}>Adicionar</button>
                  </div>
                  {(form.genres || []).length > 0 && (
                    <div className="genres-tags">
                      {form.genres!.map((g) => (
                        <span key={g} className="genre-tag">
                          {g}
                          <button type="button" onClick={() => removeGenre(g)}>×</button>
                        </span>
                      ))}
                    </div>
                  )}
                </div>
                <div className="form-group">
                  <label>Cor do artista</label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <input type="color" value={form.color || '#8b5cf6'} onChange={(e) => setForm({ ...form, color: e.target.value })} style={{ width: 40, height: 36, border: 'none', background: 'none', cursor: 'pointer' }} />
                    <input className="form-input" style={{ flex: 1 }} value={form.color || ''} onChange={(e) => setForm({ ...form, color: e.target.value })} placeholder="#hex" />
                  </div>
                </div>
                <div className="form-group">
                  <label>Foto do artista</label>
                  {avatarPreview && (
                    <div className="image-preview">
                      <img src={avatarPreview} alt="Preview" />
                    </div>
                  )}
                  <input type="file" accept="image/*" className="form-input" onChange={(e) => handleAvatarChange(e.target.files?.[0] || null)} />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setModal(null)}>Cancelar</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? 'Salvando...' : modal === 'create' ? 'Criar' : 'Salvar'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {importModal && (
        <div className="modal-overlay" onClick={() => { if (!importing) setImportModal(false); }}>
          <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 640 }}>
            <div className="modal-header">
              <h2>🎵 Importar do Spotify</h2>
              {!importing && <button className="btn-icon" onClick={() => setImportModal(false)}>✕</button>}
            </div>

            {!importing && !importDone ? (
              <form onSubmit={(e) => { e.preventDefault(); startImport(); }}>
                <div className="modal-body">
                  <div className="form-group">
                    <label>URL do Artista no Spotify</label>
                    <input
                      className="form-input"
                      value={spotifyUrl}
                      onChange={(e) => setSpotifyUrl(e.target.value)}
                      placeholder="https://open.spotify.com/artist/..."
                      required
                    />
                    <small style={{ color: 'var(--text-muted)', marginTop: 4, display: 'block' }}>
                      Cole o link do perfil do artista no Spotify. Todos os álbuns, singles e músicas serão importados automaticamente.
                    </small>
                  </div>
                </div>
                <div className="modal-footer">
                  <button type="button" className="btn btn-ghost" onClick={() => setImportModal(false)}>Cancelar</button>
                  <button type="submit" className="btn btn-primary">Importar</button>
                </div>
              </form>
            ) : (
              <div className="modal-body">
                {importProgress && (
                  <div style={{ marginBottom: 12 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, color: 'var(--text-muted)', marginBottom: 4 }}>
                      <span>Progresso</span>
                      <span>{importProgress.current} / {importProgress.total}</span>
                    </div>
                    <div style={{ height: 6, background: 'var(--bg-secondary)', borderRadius: 3, overflow: 'hidden' }}>
                      <div style={{
                        height: '100%',
                        width: `${Math.round((importProgress.current / importProgress.total) * 100)}%`,
                        background: 'var(--primary)',
                        borderRadius: 3,
                        transition: 'width 0.3s ease',
                      }} />
                    </div>
                  </div>
                )}
                <div
                  ref={logRef}
                  style={{
                    height: 350,
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
                  {importLog.map((line, i) => (
                    <div
                      key={i}
                      style={{
                        color:
                          line.type === 'error' ? '#ef4444' :
                          line.type === 'done' ? '#22c55e' :
                          '#a3a3a3',
                      }}
                    >
                      {line.message}
                    </div>
                  ))}
                  {importing && !importDone && (
                    <div style={{ color: 'var(--primary)', marginTop: 4 }}>⏳ Processando...</div>
                  )}
                </div>
                <div className="modal-footer" style={{ marginTop: 16 }}>
                  {importDone ? (
                    <button className="btn btn-primary" onClick={() => { setImportModal(false); load(); }}>Fechar</button>
                  ) : (
                    <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>Não feche esta janela durante a importação.</span>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
