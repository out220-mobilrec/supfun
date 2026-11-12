import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../store/AuthContext';
import { Spinner } from './ui';

export function RequireAuth({ children }: { children: ReactNode }) {
  const { user, loading } = useAuth();
  const location = useLocation();
  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-slate-50 text-brand-600">
        <Spinner className="h-8 w-8" />
      </div>
    );
  }
  if (!user) {
    return <Navigate to="/login" state={{ from: location.pathname }} replace />;
  }
  return <>{children}</>;
}

export function StaffGate({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  if (user?.role !== 'admin' && user?.role !== 'moderator') {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}

export function AdminOnlyGate({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  if (user?.role !== 'admin') {
    return <Navigate to="/admin" replace />;
  }
  return <>{children}</>;
}