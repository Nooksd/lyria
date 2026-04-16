import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Artists from './pages/Artists';
import ArtistDetail from './pages/ArtistDetail';
import AlbumDetail from './pages/AlbumDetail';
import Imports from './pages/Imports';
import Requests from './pages/Requests';
import Cookies from './pages/Cookies';
import Cleanup from './pages/Cleanup';

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? <>{children}</> : <Navigate to="/login" replace />;
}

function PublicRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth();
  return isAuthenticated ? <Navigate to="/dashboard" replace /> : <>{children}</>;
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<PublicRoute><Login /></PublicRoute>} />
      <Route element={<ProtectedRoute><Layout /></ProtectedRoute>}>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/artists" element={<Artists />} />
        <Route path="/artists/:artistId" element={<ArtistDetail />} />
        <Route path="/artists/:artistId/albums/:albumId" element={<AlbumDetail />} />
        <Route path="/imports" element={<Imports />} />
        <Route path="/requests" element={<Requests />} />
        <Route path="/cookies" element={<Cookies />} />
        <Route path="/cleanup" element={<Cleanup />} />
      </Route>
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppRoutes />
    </AuthProvider>
  );
}
