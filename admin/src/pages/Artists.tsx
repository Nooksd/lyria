import { useState, useEffect, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../lib/api';
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
  const [spotifyUrls, setSpotifyUrls] = useState<string[]>(['']);
  const [importSubmitting, setImportSubmitting] = useState(false);

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

  const addUrlField = () => {
    setSpotifyUrls([...spotifyUrls, '']);
  };

  const removeUrlField = (idx: number) => {
    if (spotifyUrls.length <= 1) return;
    setSpotifyUrls(spotifyUrls.filter((_, i) => i !== idx));
  };

  const updateUrl = (idx: number, value: string) => {
    const updated = [...spotifyUrls];
    updated[idx] = value;
    setSpotifyUrls(updated);
  };

  const startImport = async () => {
    const urls = spotifyUrls.map(u => u.trim()).filter(u => u.length > 0);
    if (urls.length === 0) return;

    setImportSubmitting(true);
    try {
      await api.post('/admin/import/jobs', { urls });
      show(`${urls.length} importação(ões) adicionada(s) à fila`);
      setImportModal(false);
      navigate('/imports');
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao criar importações', 'error');
    } finally {
      setImportSubmitting(false);
    }
  };

  return (
    <>
      <ToastContainer toasts={toasts} />
      <div className="page-header">
        <h1>Artistas</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn btn-ghost" onClick={() => { setImportModal(true); setSpotifyUrls(['']); }}>🎵 Importar do Spotify</button>
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
        <div className="modal-overlay" onClick={() => { if (!importSubmitting) setImportModal(false); }}>
          <div className="modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 640 }}>
            <div className="modal-header">
              <h2>🎵 Importar do Spotify</h2>
              {!importSubmitting && <button className="btn-icon" onClick={() => setImportModal(false)}>✕</button>}
            </div>

            <form onSubmit={(e) => { e.preventDefault(); startImport(); }}>
              <div className="modal-body">
                <div className="form-group">
                  <label>URLs dos Artistas no Spotify</label>
                  {spotifyUrls.map((url, idx) => (
                    <div key={idx} style={{ display: 'flex', gap: 8, marginBottom: 8 }}>
                      <input
                        className="form-input"
                        style={{ flex: 1 }}
                        value={url}
                        onChange={(e) => updateUrl(idx, e.target.value)}
                        placeholder="https://open.spotify.com/artist/..."
                        required
                      />
                      {spotifyUrls.length > 1 && (
                        <button type="button" className="btn-icon danger" onClick={() => removeUrlField(idx)} title="Remover">
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                        </button>
                      )}
                    </div>
                  ))}
                  <button type="button" className="btn btn-ghost btn-sm" onClick={addUrlField} style={{ marginTop: 4 }}>
                    + Adicionar outro artista
                  </button>
                  <small style={{ color: 'var(--text-muted)', marginTop: 8, display: 'block' }}>
                    Cole os links dos perfis de artistas no Spotify. Cada URL cria uma importação na fila. Álbuns, singles e músicas serão importados automaticamente.
                  </small>
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setImportModal(false)} disabled={importSubmitting}>Cancelar</button>
                <button type="submit" className="btn btn-primary" disabled={importSubmitting}>
                  {importSubmitting ? 'Enviando...' : `Importar (${spotifyUrls.filter(u => u.trim()).length})`}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
