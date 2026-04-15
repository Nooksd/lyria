import { useState, useEffect, type FormEvent } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api, { API_BASE } from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface Album {
  _id: string;
  name: string;
  artistId: string;
  albumCoverUrl: string;
  color: string;
}

interface Music {
  _id: string;
  name: string;
  url: string;
  genre: string;
  coverUrl: string;
  color: string;
  createdAt: string;
}

const MUSIC_EMPTY = { name: '', url: '', genre: '', color: '', coverUrl: '' };

export default function AlbumDetail() {
  const { artistId, albumId } = useParams<{ artistId: string; albumId: string }>();
  const navigate = useNavigate();
  const { toasts, show } = useToast();

  const [album, setAlbum] = useState<Album | null>(null);
  const [musics, setMusics] = useState<Music[]>([]);
  const [loading, setLoading] = useState(true);

  const [modal, setModal] = useState<'create' | 'edit' | null>(null);
  const [form, setForm] = useState(MUSIC_EMPTY);
  const [editId, setEditId] = useState('');
  const [coverFile, setCoverFile] = useState<File | null>(null);
  const [coverPreview, setCoverPreview] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const [albumRes, musicsRes] = await Promise.all([
        api.get(`/admin/album/${albumId}`),
        api.get(`/admin/album/${albumId}/musics`),
      ]);
      setAlbum(albumRes.data.album);
      setMusics(musicsRes.data.musics || []);
    } catch {
      show('Erro ao carregar dados do álbum', 'error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [albumId]);

  const openCreate = () => {
    setForm(MUSIC_EMPTY);
    setEditId('');
    setCoverFile(null);
    setCoverPreview(null);
    setModal('create');
  };

  const openEdit = (m: Music) => {
    setForm({ name: m.name, url: '', genre: m.genre || '', color: m.color || '', coverUrl: m.coverUrl || '' });
    setEditId(m._id);
    setCoverFile(null);
    setCoverPreview(m.coverUrl || null);
    setModal('edit');
  };

  const handleCoverChange = (file: File | null) => {
    setCoverFile(file);
    if (file) {
      setCoverPreview(URL.createObjectURL(file));
    } else {
      setCoverPreview(null);
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      let id = editId;
      if (modal === 'create') {
        if (!form.url) {
          show('URL do YouTube é obrigatória', 'error');
          setSaving(false);
          return;
        }
        const res = await api.post('/admin/music/create', {
          name: form.name,
          url: form.url,
          artistId,
          albumId,
          genre: form.genre,
          color: form.color || undefined,
        });
        id = res.data.music?._id || res.data._id;
        show('Música criada com sucesso. O download pode levar alguns segundos.');
      } else {
        await api.put(`/admin/music/update/${editId}`, {
          name: form.name,
          artistId,
          albumId,
          genre: form.genre,
          color: form.color || undefined,
        });
        show('Música atualizada com sucesso');
      }
      if (coverFile && id) {
        const fd = new FormData();
        fd.append('music_cover', coverFile);
        await api.post(`/admin/image/music/${id}`, fd, {
          headers: { 'Content-Type': 'multipart/form-data' },
        });
      }
      setModal(null);
      load();
    } catch (err: any) {
      show(err.response?.data?.error || 'Erro ao salvar música', 'error');
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

  if (loading) {
    return <div className="loading"><div className="spinner" /> Carregando...</div>;
  }

  if (!album) {
    return <div className="empty-state"><p>Álbum não encontrado.</p></div>;
  }

  return (
    <>
      <ToastContainer toasts={toasts} />

      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <button className="btn btn-ghost btn-sm" onClick={() => navigate(`/artists/${artistId}`)}>← Voltar</button>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span className="color-swatch" style={{ background: album.color || '#8b5cf6', width: 20, height: 20 }} />
            <h1 style={{ margin: 0 }}>{album.name}</h1>
          </div>
        </div>
      </div>

      <div className="card">
        <div className="section-header">
          <h2>Músicas do Álbum</h2>
          <button className="btn btn-primary btn-sm" onClick={openCreate}>+ Nova Música</button>
        </div>
        <p style={{ fontSize: 13, color: 'var(--text-muted)', margin: '0 0 16px' }}>
          Capa e cor são opcionais — se não definidos, herdam do álbum.
        </p>
        {musics.length === 0 ? (
          <div className="empty-state"><p>Nenhuma música neste álbum.</p></div>
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
                {musics.map((m) => (
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
                      {m.color ? (
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                          <span className="color-swatch" style={{ background: m.color }} />
                          <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>{m.color}</span>
                        </div>
                      ) : (
                        <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>herda do álbum</span>
                      )}
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
                  <label>Gênero</label>
                  <input className="form-input" value={form.genre} onChange={(e) => setForm({ ...form, genre: e.target.value })} placeholder="Ex: Rock, Pop, Hip-Hop..." />
                </div>
                <div className="form-group">
                  <label>Cor da música <span className="optional-badge">opcional — herda do álbum</span></label>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <input type="color" value={form.color || album.color || '#8b5cf6'} onChange={(e) => setForm({ ...form, color: e.target.value })} style={{ width: 40, height: 36, border: 'none', background: 'none', cursor: 'pointer' }} />
                    <input className="form-input" style={{ flex: 1 }} value={form.color} onChange={(e) => setForm({ ...form, color: e.target.value })} placeholder="Deixe vazio para herdar do álbum" />
                    {form.color && (
                      <button type="button" className="btn btn-ghost btn-sm" onClick={() => setForm({ ...form, color: '' })}>Limpar</button>
                    )}
                  </div>
                </div>
                <div className="form-group">
                  <label>Capa da música <span className="optional-badge">opcional — herda do álbum</span></label>
                  {coverPreview && (
                    <div className="image-preview">
                      <img src={coverPreview} alt="Preview" />
                    </div>
                  )}
                  <input type="file" accept="image/*" className="form-input" onChange={(e) => handleCoverChange(e.target.files?.[0] || null)} />
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
