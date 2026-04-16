import { useEffect, useState } from 'react';
import api from '../services/api';
import { useToast, ToastContainer } from '../components/Toast';

const API_BASE = import.meta.env.VITE_API_URL || '';

interface TopMusic {
  _id: string;
  name: string;
  artistName: string;
  coverUrl: string;
  playCount: number;
}

interface TopArtist {
  _id: string;
  name: string;
  avatarUrl: string;
  playCount: number;
}

interface Stats {
  musicCount: number;
  artistCount: number;
  albumCount: number;
  userCount: number;
  diskUsageMB: number;
  topMusics: TopMusic[];
  topArtists: TopArtist[];
  totalPlays: number;
  playsToday: number;
  playsThisWeek: number;
  updatedAt: string;
}

export default function Dashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const { toasts, show } = useToast();

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      const res = await api.get('/admin/stats');
      if (res.data && res.data.musicCount !== undefined) {
        setStats(res.data);
      }
    } catch {
      show('Erro ao carregar estatísticas', 'error');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return <div className="loading"><div className="spinner" /> Carregando...</div>;
  }

  if (!stats) {
    return (
      <div className="empty-state">
        <p>Estatísticas ainda não foram coletadas. Aguarde alguns minutos.</p>
      </div>
    );
  }

  const formatDisk = (mb: number) => {
    if (mb >= 1024) return `${(mb / 1024).toFixed(1)} GB`;
    return `${mb.toFixed(0)} MB`;
  };

  return (
    <>
      <ToastContainer toasts={toasts} />

      <div className="page-header">
        <h1>Dashboard</h1>
        <span style={{ fontSize: 13, color: 'var(--text-muted)' }}>
          Atualizado: {new Date(stats.updatedAt).toLocaleString('pt-BR')}
        </span>
      </div>

      {/* Stat Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16, marginBottom: 32 }}>
        <StatCard label="Músicas" value={stats.musicCount} icon="🎵" />
        <StatCard label="Artistas" value={stats.artistCount} icon="🎤" />
        <StatCard label="Álbuns" value={stats.albumCount} icon="💿" />
        <StatCard label="Usuários" value={stats.userCount} icon="👤" />
        <StatCard label="Disco" value={formatDisk(stats.diskUsageMB)} icon="💾" />
        <StatCard label="Total de Plays" value={stats.totalPlays} icon="▶️" />
        <StatCard label="Plays Hoje" value={stats.playsToday} icon="📊" />
        <StatCard label="Plays Semana" value={stats.playsThisWeek} icon="📈" />
      </div>

      {/* Top Musics */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24 }}>
        <div className="card" style={{ padding: 0 }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)' }}>
            <h2 style={{ fontSize: 16, fontWeight: 600 }}>Top 10 Músicas</h2>
          </div>
          {stats.topMusics && stats.topMusics.length > 0 ? (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 40 }}>#</th>
                    <th style={{ width: 40 }}></th>
                    <th>Música</th>
                    <th>Artista</th>
                    <th style={{ textAlign: 'right' }}>Plays</th>
                  </tr>
                </thead>
                <tbody>
                  {stats.topMusics.map((m, i) => (
                    <tr key={m._id}>
                      <td style={{ color: 'var(--text-muted)', fontWeight: 600 }}>{i + 1}</td>
                      <td>
                        {m.coverUrl ? (
                          <img
                            className="table-thumb"
                            src={m.coverUrl.startsWith('http') ? m.coverUrl : `${API_BASE}${m.coverUrl}`}
                            alt={m.name}
                            style={{ width: 32, height: 32, borderRadius: 4, objectFit: 'cover' }}
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          />
                        ) : (
                          <span style={{ width: 32, height: 32, display: 'inline-block', borderRadius: 4, background: 'var(--bg-hover)' }} />
                        )}
                      </td>
                      <td style={{ fontWeight: 500 }}>{m.name}</td>
                      <td style={{ color: 'var(--text-muted)' }}>{m.artistName}</td>
                      <td style={{ textAlign: 'right', fontWeight: 600, color: 'var(--accent)' }}>{m.playCount.toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="empty-state"><p>Nenhum play registrado ainda.</p></div>
          )}
        </div>

        {/* Top Artists */}
        <div className="card" style={{ padding: 0 }}>
          <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)' }}>
            <h2 style={{ fontSize: 16, fontWeight: 600 }}>Top 10 Artistas</h2>
          </div>
          {stats.topArtists && stats.topArtists.length > 0 ? (
            <div className="table-wrapper">
              <table>
                <thead>
                  <tr>
                    <th style={{ width: 40 }}>#</th>
                    <th style={{ width: 40 }}></th>
                    <th>Artista</th>
                    <th style={{ textAlign: 'right' }}>Plays</th>
                  </tr>
                </thead>
                <tbody>
                  {stats.topArtists.map((a, i) => (
                    <tr key={a._id}>
                      <td style={{ color: 'var(--text-muted)', fontWeight: 600 }}>{i + 1}</td>
                      <td>
                        {a.avatarUrl ? (
                          <img
                            src={a.avatarUrl.startsWith('http') ? a.avatarUrl : `${API_BASE}${a.avatarUrl}`}
                            alt={a.name}
                            style={{ width: 32, height: 32, borderRadius: '50%', objectFit: 'cover' }}
                            onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }}
                          />
                        ) : (
                          <span style={{ width: 32, height: 32, display: 'inline-block', borderRadius: '50%', background: 'var(--bg-hover)' }} />
                        )}
                      </td>
                      <td style={{ fontWeight: 500 }}>{a.name}</td>
                      <td style={{ textAlign: 'right', fontWeight: 600, color: 'var(--accent)' }}>{a.playCount.toLocaleString()}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <div className="empty-state"><p>Nenhum play registrado ainda.</p></div>
          )}
        </div>
      </div>
    </>
  );
}

function StatCard({ label, value, icon }: { label: string; value: string | number; icon: string }) {
  return (
    <div className="card" style={{ padding: '20px', display: 'flex', alignItems: 'center', gap: 16 }}>
      <span style={{ fontSize: 28 }}>{icon}</span>
      <div>
        <div style={{ fontSize: 24, fontWeight: 700, lineHeight: 1.2 }}>{typeof value === 'number' ? value.toLocaleString() : value}</div>
        <div style={{ fontSize: 13, color: 'var(--text-muted)', marginTop: 2 }}>{label}</div>
      </div>
    </div>
  );
}
