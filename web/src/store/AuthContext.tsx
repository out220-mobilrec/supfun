import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { api, clearSession, getRefreshToken, getToken, setSession } from '../lib/api';
import type { AuthResult, User } from '../types';

interface AuthContextValue {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (data: { name: string; email: string; password: string; city?: string; phone?: string }) => Promise<void>;
  logout: () => void;
  updateUser: (u: User) => void;
  refreshUser: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    async function bootstrap() {
      if (!getToken()) {
        setLoading(false);
        return;
      }
      try {
        const { data } = await api.get<User>('/users/me');
        if (mounted) setUser(data);
      } catch {
        // 401 redirect handled by interceptor
      } finally {
        if (mounted) setLoading(false);
      }
    }
    void bootstrap();
    return () => {
      mounted = false;
    };
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const { data } = await api.post<AuthResult>('/auth/login', { email, password });
    setSession(data.accessToken, data.user, data.refreshToken);
    setUser(data.user);
  }, []);

  const register = useCallback(
    async (payload: { name: string; email: string; password: string; city?: string; phone?: string }) => {
      const { data } = await api.post<AuthResult>('/auth/register', payload);
      setSession(data.accessToken, data.user, data.refreshToken);
      setUser(data.user);
    },
    [],
  );

  const logout = useCallback(() => {
    const refreshToken = getRefreshToken();
    if (refreshToken) {
      void api.post('/auth/logout', { refreshToken }).catch(() => undefined);
    }
    clearSession();
    setUser(null);
  }, []);

  const updateUser = useCallback((u: User) => {
    setUser(u);
    localStorage.setItem('sf_user', JSON.stringify(u));
  }, []);

  const refreshUser = useCallback(async () => {
    const { data } = await api.get<User>('/users/me');
    setUser(data);
    localStorage.setItem('sf_user', JSON.stringify(data));
  }, []);

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout, updateUser, refreshUser }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}