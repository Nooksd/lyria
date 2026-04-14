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
}

interface Music {
  _id: string;
  name: string;
  url: string;
  artistId: string;
  albumId: string;
  genre: string;
  createdAt: string;
}

const EMPTY = { name: '', url: '', artistId: '', albumId: '', genre: '' };

export default function Musics() {
  const [musics, setMusics] = useState<Music[]>([]);
  const [artists, setArtists] = useState<Artist[]>([]);
  const [albums, setAlbums] = useState<Album[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState<'create' | 'edit' | null>(null);
  const [form, setForm] = useState(EMPTY);
  const [editId, setEditId] = useState('');
  const [saving, setSaving] = useState(false);
  const { toasts, show } = useToast();

  const limit = 20;

  const load = async (p = page) => {
    setLoading(true);
    try {
      const [musicRes, artistRes, albumRes] = await Promise.all([
        api.get(`/admin/musics?page=${p}&limit=${limit}`),
        api.get('/admin/artists?page=1&limit=500'),
        api.get('/admin/albums?page=1&limit=500'),
      ]);
      setMusics(musicRes.data.musics || []);
      setTotal(musicRes.data.total || 0);
      setArtists(artistRes.data.artists || []);
      setAlbums(albumRes.data.albums || []);
    } catch {
      show('Erro ao carregar músicas', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [page]);

  const artistName = (id: string) => artists.find((a) => a._id === id)?.name || '—';
  const albumName = (id: string) => albums.find((a) => a._id === id)?.name || '—';

  const filteredAlbums = form.artistId
    ? albums.filter((a) => a.artistId === form.artistId)
    : albums;

  const openCreate = () => {
    setForm(EMPTY);
    setEditId('');
    setModal('create');
  };

  const openEdit = (m: Music) => {
    setForm({ name: m.name, url: '', artistId: m.artistId, albumId: m.albumId, genre: m.genre || '' });
    setEditId(m._id);
    setModal('edit');
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      if (modal === 'create') {
        if (!form.url) {
          show('URL do YouTube é obrigatória', 'error');
          setSaving(false);
          return;
        }
        await api.post('/admin/music/create', {
          name: form.name,
          url: form.url,
          artistId: form.artistId,
          albumId: form.albumId,
          genre: form.genre,
        });
        show('Música criada com sucesso. O download pode levar alguns segundos.');
      } else {
        await api.put(`/admin/music/update/${editId}`, {
          name: form.name,
          artistId: form.artistId,
          albumId: form.albumId,
          genre: form.genre,
        });
        show('Música atualizada com sucesso');
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
    if (!confirm(`Deletar música "${name}"?`)) return;
    try {
      await api.delete(`/admin/music/delete/${id}`);
      show('Música removida com sucesso');
      load();
    } catch {
      show('Erro ao deletar música', 'error');
    }
  };

  const totalPages = Math.ceil(total / limit);

  return (
    <>
      <ToastContainer toasts={toasts} />
      <div className="page-header">
        <h1>Músicas</h1>
        <button className="btn btn-primary" onClick={openCreate}>+ Nova Música</button>
      </div>

      <div className="card">
        {loading ? (
          <div className="loading"><div className="spinner" /> Carregando...</div>
        ) : musics.length === 0 ? (
          <div className="empty-state"><p>Nenhuma música cadastrada.</p></div>
        ) : (
          <>
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th>Nome</th>
                    <th>Artista</th>
                    <th>Álbum</th>
                    <th>Gênero</th>
                    <th>Criado em</th>
                    <th>Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {musics.map((m) => (
                    <tr key={m._id}>
                      <td style={{ fontWeight: 500 }}>{m.name}</td>
                      <td>{artistName(m.artistId)}</td>
                      <td>{albumName(m.albumId)}</td>
                      <td>
                        {m.genre ? <span className="badge badge-genre">{m.genre}</span> : '—'}
                      </td>
                      <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                        {new Date(m.createdAt).toLocaleDateString('pt-BR')}
                      </td>
                      <td>
                        <div className="actions-cell">
                          <button className="btn-icon" title="Editar" onClick={() => openEdit(m)}>
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                          </button>
                          <button className="btn-icon danger" title="Deletar" onClick={() => handleDelete(m._id, m.name)}>
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
                <span className="pagination-info">{total} música(s) — Página {page} de {totalPages}</span>
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
              <h2>{modal === 'create' ? 'Nova Música' : 'Editar Música'}</h2>
              <button className="btn-icon" onClick={() => setModal(null)}>✕</button>
            </div>
            <form onSubmit={handleSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Nome</label>
                  <input className="form-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required placeholder="Nome da música" />
                </div>
                {modal === 'create' && (
                  <div className="form-group">
                    <label>URL do YouTube</label>
                    <input className="form-input" value={form.url} onChange={(e) => setForm({ ...form, url: e.target.value })} required placeholder="https://youtube.com/watch?v=..." />
                    <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>O áudio será baixado automaticamente via yt-dlp</span>
                  </div>
                )}
                <div className="form-group">
                  <label>Artista</label>
                  <select className="form-input" value={form.artistId} onChange={(e) => setForm({ ...form, artistId: e.target.value, albumId: '' })} required>
                    <option value="">Selecionar artista...</option>
                    {artists.map((a) => (
                      <option key={a._id} value={a._id}>{a.name}</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Álbum</label>
                  <select className="form-input" value={form.albumId} onChange={(e) => setForm({ ...form, albumId: e.target.value })} required>
                    <option value="">Selecionar álbum...</option>
                    {filteredAlbums.map((a) => (
                      <option key={a._id} value={a._id}>{a.name}</option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>Gênero</label>
                  <input className="form-input" value={form.genre} onChange={(e) => setForm({ ...form, genre: e.target.value })} placeholder="Ex: Rock, Pop, Hip-Hop..." />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setModal(null)}>Cancelar</button>
                <button type="submit" className="btn btn-primary" disabled={saving}>
                  {saving ? (modal === 'create' ? 'Baixando...' : 'Salvando...') : modal === 'create' ? 'Criar' : 'Salvar'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
