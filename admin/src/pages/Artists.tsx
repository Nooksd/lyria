import { useState, useEffect, type FormEvent } from 'react';
import api from '../lib/api';
import { useToast, ToastContainer } from '../components/Toast';

interface Artist {
  _id: string;
  name: string;
  genres: string[];
  avatarUrl: string;
  bannerUrl: string;
  bio: string;
  createdAt: string;
}

const EMPTY: Partial<Artist> & { genreInput?: string } = {
  name: '',
  genres: [],
  bio: '',
  genreInput: '',
};

export default function Artists() {
  const [artists, setArtists] = useState<Artist[]>([]);
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
    setModal('create');
  };

  const openEdit = (a: Artist) => {
    setForm({ name: a.name, genres: a.genres || [], bio: a.bio || '', genreInput: '' });
    setEditId(a._id);
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

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      const body = { name: form.name, genres: form.genres, bio: form.bio };
      if (modal === 'create') {
        await api.post('/admin/artist/create', body);
        show('Artista criado com sucesso');
      } else {
        await api.put(`/admin/artist/update/${editId}`, body);
        show('Artista atualizado com sucesso');
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
    if (!confirm(`Deletar artista "${name}"? Todos os álbuns associados serão removidos.`)) return;
    try {
      await api.delete(`/admin/artist/delete/${id}`);
      show('Artista removido com sucesso');
      load();
    } catch {
      show('Erro ao deletar artista', 'error');
    }
  };

  const totalPages = Math.ceil(total / limit);

  return (
    <>
      <ToastContainer toasts={toasts} />
      <div className="page-header">
        <h1>Artistas</h1>
        <button className="btn btn-primary" onClick={openCreate}>+ Novo Artista</button>
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
                    <th>Nome</th>
                    <th>Gêneros</th>
                    <th>Bio</th>
                    <th>Criado em</th>
                    <th>Ações</th>
                  </tr>
                </thead>
                <tbody>
                  {artists.map((a) => (
                    <tr key={a._id}>
                      <td style={{ fontWeight: 500 }}>{a.name}</td>
                      <td>
                        <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                          {(a.genres || []).map((g) => (
                            <span key={g} className="badge badge-genre">{g}</span>
                          ))}
                        </div>
                      </td>
                      <td><span className="truncate">{a.bio || '—'}</span></td>
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
