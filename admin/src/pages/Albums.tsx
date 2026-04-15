import { useState, useEffect, type FormEvent } from 'react';
import api from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface Artist {
  _id: string;
  name: string;
}

interface Album {
  _id: string;
  name: string;
  artistId: string;
  albumCoverUrl: string;
  color: string;
  createdAt: string;
}

const EMPTY = { name: '', artistId: '', color: '#8b5cf6' };

export default function Albums() {
  const [albums, setAlbums] = useState<Album[]>([]);
  const [artists, setArtists] = useState<Artist[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<'create' | 'edit' | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [editId, setEditId] = useState('');
  const [saving, setSaving] = useState(false);
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const { toasts, show } = useToast();

  const limit = 20;

  const load = async (p = page) => {
    setLoading(true);
    try {
      const [albumRes, artistRes] = await Promise.all([
        api.get(`/admin/albums?page=${p}&limit=${limit}`),
        api.get('/admin/artists?page=1&limit=500'),
      ]);
      setAlbums(albumRes.data.albums || []);
      setTotal(albumRes.data.total || 0);
      setArtists(artistRes.data.artists || []);
    } catch {
      show('Erro ao carregar álbuns', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [page]);

  const artistName = (id: string) => artists.find((a) => a._id === id)?.name || '—';

  const openCreate = () => {
    setForm(EMPTY);
    setEditId('');
    setCoverFile(null);
    setModal('create');
  };

  const openEdit = (a: Album) => {
    setForm({ name: a.name, artistId: a.artistId, color: a.color || '#8b5cf6' });
    setEditId(a._id);
    setCoverFile(null);
    setModal('edit');
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const body = { name: form.name, artistId: form.artistId, color: form.color };
      let albumId = editId;
      if (modal === 'create') {
        const res = await api.post('/admin/album/create', body);
        albumId = res.data._id;
        show('Álbum criado com sucesso');
      } else {
        await api.put(`/admin/album/update/${editId}`, body);
        show('Álbum atualizado com sucesso');
      }
      if (coverFile && albumId) {
        const fd = new FormData();
        fd.append('cover', coverFile);
        await api.post(`/image/cover/${albumId}`, fd, {
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
    if (!confirm(`Deletar álbum "${name}"? Todas as músicas associadas serão removidas.`)) return;
    try {
      await api.delete(`/admin/album/delete/${id}`);
      show('Álbum removido com sucesso');
      load();
    } catch {
      show('Erro ao deletar álbum', 'error');
    }
  };

  const totalPages = Math.ceil(total / limit);

  return (
    <>
      <ToastContainer toasts={toasts} />
      <div className="page-header">
        <h1>Álbuns</h1>
        <button className="btn btn-primary" onClick={openCreate}>+ Novo Álbum</button>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading"><div className="spinner" /> Carregando...</div>
        ) : albums.length === 0 ? (
          <div className="empty-state"><p>Nenhum álbum cadastrado.</p></div>
        ) : (
          <>
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 48 }}>Capa</th>
                    <th>Nome</th>
                    <th>Artista</th>
                    <th>Cor</th>
                    <th>Criado em</th>
                    <th>Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {albums.map((a) => (
                    <tr key={a._id}>
                      <td>
                        {a.albumCoverUrl ? (
                          <img className="table-thumb" src={a.albumCoverUrl} alt={a.name} onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                        ) : (
                          <span className="table-thumb-empty">—</span>
                        )}
                      </td>
                      <td style={{ fontWeight: 500 }}>{a.name}</td>
                      <td>{artistName(a.artistId)}</td>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span className="color-swatch" style={{ background: a.color }} />
                          <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{a.color}</span>
                        </div>
                      </td>
                      <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                        {new Date(a.createdAt).toLocaleDateString('pt-BR')}
                      </td>
                      <td>
                        <div className="actions-cell">
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
                <span className="pagination-info">{total} álbum(ns) — Página {page} de {totalPages}</span>
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
              <h2>{modal === 'create' ? 'Novo Álbum' : 'Editar Álbum'}</h2>
              <button className="btn-icon" onClick={() => setModal(null)}>✕</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Nome</label>
                  <input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required placeholder="Nome do álbum" />
                </div>
                <div className="form-group">
                  <label>Artista</label>
                  <select className="form-input" value={form.artistId} onChange={(e) => setForm({ ...form, artistId: e.target.value })} required>
                    <option value="">Selecionar artista...</option>
                    {artists.map((a) => (
                      <option key={a._id} value={a._id}>{a.name}</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Cor do álbum</label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <input type="color" value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} style={{ width: 40, height: 36, border: 'none', background: 'none', cursor: 'pointer' }} />
                    <input className="form-input" style={{ flex: 1 }} value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} placeholder="#hex" />
                  </div>
                </div>
                <div className="form-group">
                  <label>Capa do álbum</label>
                  <input type="file" accept="image/*" className="form-input" onChange={(e) => setCoverFile(e.target.files?.[0] || null)} />
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
    </>
  );
}
