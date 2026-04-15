import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Layout() {
  const { logout } = useAuth();

  return (
    <>
      <aside className="sidebar">
        <div className="sidebar-logo">Lyria Admin</div>
        <nav className="sidebar-nav">
          <NavLink to="/artists" className={({ isActive }) => `sidebar-link ${isActive ? 'active' : ''}`}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
              <circle cx="12" cy="7" r="4" />
            </svg>
            Artistas
          </NavLink>
        </nav>
        <div className="sidebar-footer">
          <button className="btn btn-ghost" style={{ width: '100%' }} onClick={logout}>
            Sair
          </button>
        </div>
      </aside>
      <main className="main-content">
        <Outlet />
      </main>
    </>
  );
}
