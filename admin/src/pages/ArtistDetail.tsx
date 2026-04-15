import { useState, useEffect, type FormEvent } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api, { API_BASE } from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface Artist {
  _id: string;
  name: string;
  genres: string[];
  avatarUrl: string;
  bio: string;
  color: string;
}

interface Album {
  _id: string;
  name: string;
  albumCoverUrl: string;
  color: string;
  createdAt: string;
}

interface Music {
  _id: string;
  name: string;
  url: string;
  genre: string;
  coverUrl: string;
  color: string;
  albumId: string;
  createdAt: string;
}

const ALBUM_EMPTY = { name: '', color: '#8b5cf6' };
const MUSIC_EMPTY = { name: '', url: '', genre: '', color: '#8b5cf6', coverUrl: '' };

export default function ArtistDetail() {
  const { artistId } = useParams<{ artistId: string }>();
  const navigate = useNavigate();
  const { toasts, show } = useToast();

  const [artist, setArtist] = useState<Artist | null>(null);
  const [albums, setAlbums] = useState<Album[]>([]);
  const [musics, setMusics] = useState<Music[]>([]);
  const [loading, setLoading] = useState(true);

  // Album modal
  const [albumModal, setAlbumModal] = useState<'create' | 'edit' | null>(null);
  const [albumForm, setAlbumForm] = useState(ALBUM_EMPTY);
  const [albumEditId, setAlbumEditId] = useState('');
  const [albumCoverFile, setAlbumCoverFile] = useState<File | null>(null);
  const [albumCoverPreview, setAlbumCoverPreview] = useState<string | null>(null);
  const [albumSaving, setAlbumSaving] = useState(false);

  // Music modal
  const [musicModal, setMusicModal] = useState<'create' | 'edit' | null>(null);
  const [musicForm, setMusicForm] = useState(MUSIC_EMPTY);
  const [musicEditId, setMusicEditId] = useState('');
  const [musicCoverFile, setMusicCoverFile] = useState<File | null>(null);
  const [musicCoverPreview, setMusicCoverPreview] = useState<string | null>(null);
  const [musicSaving, setMusicSaving] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const [artistRes, albumsRes, musicsRes] = await Promise.all([
        api.get(`/admin/artist/${artistId}`),
        api.get(`/admin/artist/${artistId}/albums`),
        api.get(`/admin/artist/${artistId}/musics`),
      ]);
      setArtist(artistRes.data.artist);
      setAlbums(albumsRes.data.albums || []);
      setMusics(musicsRes.data.musics || []);
    } catch {
      show('Erro ao carregar dados do artista', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [artistId]);

  // Singles = musics with no albumId or empty albumId
  const singles = musics.filter((m) => !m.albumId || m.albumId === '000000000000000000000000');

  // --- Album handlers ---
  const openCreateAlbum = () => {
    setAlbumForm(ALBUM_EMPTY);
    setAlbumEditId('');
    setAlbumCoverFile(null);
    setAlbumCoverPreview(null);
    setAlbumModal('create');
  };

  const openEditAlbum = (a: Album) => {
    setAlbumForm({ name: a.name, color: a.color || '#8b5cf6' });
    setAlbumEditId(a._id);
    setAlbumCoverFile(null);
    setAlbumCoverPreview(a.albumCoverUrl || null);
    setAlbumModal('edit');
  };

  const handleAlbumCoverChange = (file: File | null) => {
    setAlbumCoverFile(file);
    if (file) {
      setAlbumCoverPreview(URL.createObjectURL(file));
    } else {
      setAlbumCoverPreview(null);
    }
  };

  const handleAlbumSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setAlbumSaving(true);
    try {
      const body = { name: albumForm.name, artistId, color: albumForm.color };
      let id = albumEditId;
      if (albumModal === 'create') {
        const res = await api.post('/admin/album/create', body);
        id = res.data._id;
        show('Álbum criado com sucesso');
      } else {
        await api.put(`/admin/album/update/${albumEditId}`, body);
        show('Álbum atualizado com sucesso');
      }
      if (albumCoverFile && id) {
        const fd = new FormData();
        fd.append('cover', albumCoverFile);
        await api.post(`/admin/image/cover/${id}`, fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }
      setAlbumModal(null);
      load();
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao salvar álbum', 'error');
    } finally {
      setAlbumSaving(false);
    }
  };

  const handleDeleteAlbum = async (id: string, name: string) => {
    if (!confirm(`Deletar álbum "${name}"? Todas as músicas do álbum serão removidas.`)) return;
    try {
      await api.delete(`/admin/album/delete/${id}`);
      show('Álbum removido com sucesso');
      load();
    } catch {
      show('Erro ao deletar álbum', 'error');
    }
  };

  // --- Music (singles) handlers ---
  const openCreateMusic = () => {
    setMusicForm(MUSIC_EMPTY);
    setMusicEditId('');
    setMusicCoverFile(null);
    setMusicCoverPreview(null);
    setMusicModal('create');
  };

  const openEditMusic = (m: Music) => {
    setMusicForm({ name: m.name, url: '', genre: m.genre || '', color: m.color || '#8b5cf6', coverUrl: m.coverUrl || '' });
    setMusicEditId(m._id);
    setMusicCoverFile(null);
    setMusicCoverPreview(m.coverUrl || null);
    setMusicModal('edit');
  };

  const handleMusicCoverChange = (file: File | null) => {
    setMusicCoverFile(file);
    if (file) {
      setMusicCoverPreview(URL.createObjectURL(file));
    } else {
      setMusicCoverPreview(null);
    }
  };

  const handleMusicSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setMusicSaving(true);
    try {
      let id = musicEditId;
      if (musicModal === 'create') {
        if (!musicForm.url) {
          show('URL do YouTube é obrigatória', 'error');
          setMusicSaving(false);
          return;
        }
        const res = await api.post('/admin/music/create', {
          name: musicForm.name,
          url: musicForm.url,
          artistId,
          genre: musicForm.genre,
          color: musicForm.color,
        });
        id = res.data.music?._id || res.data._id;
        show('Música criada com sucesso. O download pode levar alguns segundos.');
      } else {
        await api.put(`/admin/music/update/${musicEditId}`, {
          name: musicForm.name,
          artistId,
          genre: musicForm.genre,
          color: musicForm.color,
        });
        show('Música atualizada com sucesso');
      }
      if (musicCoverFile && id) {
        const fd = new FormData();
        fd.append('music_cover', musicCoverFile);
        await api.post(`/admin/image/music/${id}`, fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }
      setMusicModal(null);
      load();
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao salvar música', 'error');
    } finally {
      setMusicSaving(false);
    }
  };

  const handleDeleteMusic = async (id: string, name: string) => {
    if (!confirm(`Deletar música "${name}"?`)) return;
    try {
      await api.delete(`/admin/music/delete/${id}`);
      show('Música removida com sucesso');
      load();
    } catch {
      show('Erro ao deletar música', 'error');
    }
  };

  if (loading) {
    return <div className="loading"><div className="spinner" /> Carregando...</div>;
  }

  if (!artist) {
    return <div className="empty-state"><p>Artista não encontrado.</p></div>;
  }

  return (
    <>
      <ToastContainer toasts={toasts} />

      {/* Back + Artist header */}
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button className="btn btn-ghost btn-sm" onClick={() => navigate('/artists')}>← Voltar</button>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span className="color-swatch" style={{ background: artist.color || '#8b5cf6', width: 20, height: 20 }} />
            <h1 style={{ margin: 0 }}>{artist.name}</h1>
          </div>
        </div>
      </div>

      {/* Albums section */}
      <div className="card" style={{ marginBottom: 24 }}>
        <div className="section-header">
          <h2>Álbuns</h2>
          <button className="btn btn-primary btn-sm" onClick={openCreateAlbum}>+ Novo Álbum</button>
        </div>
        {albums.length === 0 ? (
          <div className="empty-state"><p>Nenhum álbum cadastrado.</p></div>
        ) : (
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th style={{ width: 48 }}>Capa</th>
                  <th>Nome</th>
                  <th>Cor</th>
                  <th>Criado em</th>
                  <th>Ações</th>
                </tr>
              </thead>
              <tbody>
                {albums.map((a) => (
                  <tr key={a._id}>
                    <td>
                      <img className="table-thumb" src={a.albumCoverUrl} alt={a.name} onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                    </td>
                    <td style={{ fontWeight: 500 }}>{a.name}</td>
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
                        <button className="btn btn-sm btn-primary" onClick={() => navigate(`/artists/${artistId}/albums/${a._id}`)}>
                          Acessar
                        </button>
                        <button className="btn-icon" title="Editar" onClick={() => openEditAlbum(a)}>
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                        </button>
                        <button className="btn-icon danger" title="Deletar" onClick={() => handleDeleteAlbum(a._id, a.name)}>
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Singles section */}
      <div className="card">
        <div className="section-header">
          <h2>Músicas Avulsas (sem álbum)</h2>
          <button className="btn btn-primary btn-sm" onClick={openCreateMusic}>+ Nova Música</button>
        </div>
        {singles.length === 0 ? (
          <div className="empty-state"><p>Nenhuma música avulsa cadastrada.</p></div>
        ) : (
          <div className="table-wrapper">
            <table>
              <thead>
                <tr>
                  <th style={{ width: 48 }}>Capa</th>
                  <th>Nome</th>
                  <th>Gênero</th>
                  <th>Cor</th>
                  <th>Criado em</th>
                  <th>Ações</th>
                </tr>
              </thead>
              <tbody>
                {singles.map((m) => (
                  <tr key={m._id}>
                    <td>
                      {m.coverUrl ? (
                        <img className="table-thumb" src={m.coverUrl.startsWith('http') ? m.coverUrl : `${API_BASE}${m.coverUrl}`} alt={m.name} onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }} />
                      ) : (
                        <span className="table-thumb-empty">—</span>
                      )}
                    </td>
                    <td style={{ fontWeight: 500 }}>{m.name}</td>
                    <td>
                      {m.genre ? <span className="badge badge-genre">{m.genre}</span> : '—'}
                    </td>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span className="color-swatch" style={{ background: m.color || '#8b5cf6' }} />
                        <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{m.color || '—'}</span>
                      </div>
                    </td>
                    <td style={{ color: 'var(--text-muted)', fontSize: 13 }}>
                      {new Date(m.createdAt).toLocaleDateString('pt-BR')}
                    </td>
                    <td>
                      <div className="actions-cell">
                        <button className="btn-icon" title="Editar" onClick={() => openEditMusic(m)}>
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                        </button>
                        <button className="btn-icon danger" title="Deletar" onClick={() => handleDeleteMusic(m._id, m.name)}>
                          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Album modal */}
      {albumModal && (
        <div className="modal-overlay" onClick={() => setAlbumModal(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{albumModal === 'create' ? 'Novo Álbum' : 'Editar Álbum'}</h2>
              <button className="btn-icon" onClick={() => setAlbumModal(null)}>✕</button>
            </div>
            <form onSubmit={handleAlbumSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Nome</label>
                  <input className="form-input" value={albumForm.name} onChange={(e) => setAlbumForm({ ...albumForm, name: e.target.value })} required placeholder="Nome do álbum" />
                </div>
                <div className="form-group">
                  <label>Cor do álbum</label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <input type="color" value={albumForm.color} onChange={(e) => setAlbumForm({ ...albumForm, color: e.target.value })} style={{ width: 40, height: 36, border: 'none', background: 'none', cursor: 'pointer' }} />
                    <input className="form-input" style={{ flex: 1 }} value={albumForm.color} onChange={(e) => setAlbumForm({ ...albumForm, color: e.target.value })} placeholder="#hex" />
                  </div>
                </div>
                <div className="form-group">
                  <label>Capa do álbum</label>
                  {albumCoverPreview && (
                    <div className="image-preview">
                      <img src={albumCoverPreview} alt="Preview" />
                    </div>
                  )}
                  <input type="file" accept="image/*" className="form-input" onChange={(e) => handleAlbumCoverChange(e.target.files?.[0] || null)} />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setAlbumModal(null)}>Cancelar</button>
                <button type="submit" className="btn btn-primary" disabled={albumSaving}>
                  {albumSaving ? 'Salvando...' : albumModal === 'create' ? 'Criar' : 'Salvar'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Music (singles) modal */}
      {musicModal && (
        <div className="modal-overlay" onClick={() => setMusicModal(null)}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h2>{musicModal === 'create' ? 'Nova Música Avulsa' : 'Editar Música Avulsa'}</h2>
              <button className="btn-icon" onClick={() => setMusicModal(null)}>✕</button>
            </div>
            <form onSubmit={handleMusicSubmit}>
              <div className="modal-body">
                <div className="form-group">
                  <label>Nome</label>
                  <input className="form-input" value={musicForm.name} onChange={(e) => setMusicForm({ ...musicForm, name: e.target.value })} required placeholder="Nome da música" />
                </div>
                {musicModal === 'create' && (
                  <div className="form-group">
                    <label>URL do YouTube</label>
                    <input className="form-input" value={musicForm.url} onChange={(e) => setMusicForm({ ...musicForm, url: e.target.value })} required placeholder="https://youtube.com/watch?v=..." />
                    <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>O áudio será baixado automaticamente via yt-dlp</span>
                  </div>
                )}
                <div className="form-group">
                  <label>Gênero</label>
                  <input className="form-input" value={musicForm.genre} onChange={(e) => setMusicForm({ ...musicForm, genre: e.target.value })} placeholder="Ex: Rock, Pop, Hip-Hop..." />
                </div>
                <div className="form-group">
                  <label>Cor da música <span className="required-badge">obrigatório</span></label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <input type="color" value={musicForm.color} onChange={(e) => setMusicForm({ ...musicForm, color: e.target.value })} style={{ width: 40, height: 36, border: 'none', background: 'none', cursor: 'pointer' }} />
                    <input className="form-input" style={{ flex: 1 }} value={musicForm.color} onChange={(e) => setMusicForm({ ...musicForm, color: e.target.value })} placeholder="#hex" />
                  </div>
                </div>
                <div className="form-group">
                  <label>Capa da música <span className="required-badge">obrigatório</span></label>
                  {musicCoverPreview && (
                    <div className="image-preview">
                      <img src={musicCoverPreview} alt="Preview" />
                    </div>
                  )}
                  <input type="file" accept="image/*" className="form-input" onChange={(e) => handleMusicCoverChange(e.target.files?.[0] || null)} />
                </div>
              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-ghost" onClick={() => setMusicModal(null)}>Cancelar</button>
                <button type="submit" className="btn btn-primary" disabled={musicSaving}>
                  {musicSaving ? (musicModal === 'create' ? 'Baixando...' : 'Salvando...') : musicModal === 'create' ? 'Criar' : 'Salvar'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
