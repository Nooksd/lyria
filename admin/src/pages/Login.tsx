import { useState, type FormEvent } from 'react';
import { useAuth } from '../context/AuthContext';
import { useNavigate } from 'react-router-dom';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [secret, setSecret] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(secret);
      navigate('/artists');
    } catch {
      setError('Secret inválido');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-page">
      <div className="login-card">
        <h1>Lyria Admin</h1>
        <p>Insira o secret de administrador para acessar o painel.</p>
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Secret</label>
            <input
              type="password"
              className="form-input"
              value={secret}
              onChange={(e) => setSecret(e.target.value)}
              placeholder="Insira o admin secret"
              autoFocus
              required
            />
          </div>
          {error && <p style={{ color: 'var(--danger)', fontSize: 13, marginBottom: 16 }}>{error}</p>}
          <button type="submit" className="btn btn-primary" style={{ width: '100%' }} disabled={loading}>
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>
      </div>
    </div>
  );
}
