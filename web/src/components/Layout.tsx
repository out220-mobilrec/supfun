import { useCallback, useEffect, useMemo, useState } from 'react';
import type { FormEvent, ReactNode } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../store/AuthContext';
import { useSocketEvent } from '../store/SocketContext';
import { useT } from '../i18n';
import { api } from '../lib/api';
import { Avatar } from './Avatar';

interface NavItem {
  to: string;
  label: string;
  icon: ReactNode;
  end?: boolean;
}

const icon = (d: string) => (
  <svg className="h-5 w-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
    <path d={d} />
  </svg>
);

function useClientNav(t: (k: string) => string) {
  return useMemo<{ group: string; items: NavItem[] }[]>(
    () => [
      {
        group: t('nav.group.overview'),
        items: [
          { to: '/', label: t('nav.home'), end: true, icon: icon('M3 12l9-9 9 9M5 10v10a1 1 0 001 1h4v-6h4v6h4a1 1 0 001-1V10') },
          { to: '/feed', label: t('nav.feed'), icon: icon('M4 4h16v12H4zM4 16h16M4 4a12 12 0 008 8') },
        ],
      },
      {
        group: t('nav.group.activity'),
        items: [
          { to: '/events', label: t('nav.events'), icon: icon('M8 2v4M16 2v4M2 10h20M4 6h16a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V8a2 2 0 012-2z') },
          { to: '/tracks', label: t('nav.tracks'), icon: icon('M8 18l-1 4M12 18l-1 4M16 18l-1 4M4 7h16M4 11h16M4 15h16M6 3c0 0-4 2-4 6s4 2 4 2M18 3c0 0-4 2-4 6s4 2 4 2') },
          { to: '/waterbodies', label: t('nav.waterbodies'), icon: icon('M3 20c2 0 3-1 5-1s3 1 5 1 3-1 5-1 3 1 5 1M4 15c2 0 3-1 5-1s3 1 5 1 3-1 5-1M5 10c2 0 3-1 5-1s3 1 5 1 3-1 5-1M6 5c2 0 3-1 5-1s3 1 5 1') },
          { to: '/gamification', label: t('nav.ratingLevels'), icon: icon('M12 15a7 7 0 100-14 7 7 0 000 14zM8.21 13.89L7 23l5-3 5 3-1.21-9.12M13 2L4.09 12.97A1 1 0 005 14.5h6') },
        ],
      },
      {
        group: t('nav.group.marketplace'),
        items: [
          { to: '/marketplace', label: t('marketplace.title'), icon: icon('M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16zM3.27 6.96L12 12.1l8.73-5.14M12 22.08V12.1') },
        ],
      },
      {
        group: t('nav.group.community'),
        items: [
          { to: '/chats', label: t('nav.chats'), icon: icon('M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z') },
          { to: '/friends', label: t('nav.friends'), icon: icon('M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM22 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75') },
          { to: '/channels', label: t('nav.channels'), icon: icon('M4 5a2 2 0 012-2h12a2 2 0 012 2v11a2 2 0 01-2 2h-5l-4.5 4V18H6a2 2 0 01-2-2V5z') },
          { to: '/news', label: t('nav.news'), icon: icon('M4 4h16v14a2 2 0 01-2 2H6a2 2 0 01-2-2V4zM8 8h8M8 12h8M8 16h5') },
        ],
      },
    ],
    [t],
  );
}

function useAdminNav(t: (k: string) => string) {
  return useMemo<NavItem[]>(
    () => [
      { to: '/admin', label: t('nav.admin.dashboard'), end: true, icon: icon('M3 13h8V3H3v10zM13 21h8V11h-8v10zM3 21h8v-6H3v6z') },
      { to: '/admin/users', label: t('nav.admin.users'), icon: icon('M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM22 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75') },
      { to: '/admin/listings', label: t('nav.admin.listings'), icon: icon('M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z') },
      { to: '/admin/events', label: t('nav.admin.events'), icon: icon('M8 2v4M16 2v4M2 10h20M4 6h16a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V8a2 2 0 012-2z') },
      { to: '/admin/events/stats', label: t('nav.admin.stats'), icon: icon('M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z') },
      { to: '/admin/waterbodies', label: t('nav.admin.waterbodies'), icon: icon('M3 20c2 0 3-1 5-1s3 1 5 1 3-1 5-1 3 1 5-1M4 15c2 0 3-1 5-1s3 1 5 1 3-1 5-1') },
    ],
    [t],
  );
}

function SearchForm({ onClose }: { onClose?: () => void }) {
  const navigate = useNavigate();
  const t = useT();
  const [q, setQ] = useState('');
  const submit = (e: FormEvent) => {
    e.preventDefault();
    const needle = q.trim();
    if (!needle) return;
    navigate(`/search?q=${encodeURIComponent(needle)}`);
    setQ('');
    onClose?.();
  };
  return (
    <form onSubmit={submit} className="relative flex-1 max-w-md">
      <input
        value={q}
        onChange={(e) => setQ(e.target.value)}
        placeholder={t('layout.searchPlaceholder')}
        className="w-full rounded-full border border-slate-300 bg-slate-50 px-4 py-1.5 pl-10 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400"
      />
      <span className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400">
        <svg className="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <circle cx="11" cy="11" r="7" />
          <path d="M21 21l-4.3-4.3" />
        </svg>
      </span>
    </form>
  );
}

function UnreadBell() {
  const navigate = useNavigate();
  const t = useT();
  const [count, setCount] = useState(0);

  const refresh = useCallback(async () => {
    try {
      const { data } = await api.get<{ count: number }>('/notifications/unread-count');
      setCount(data.count);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useSocketEvent('notify:new', () => {
    setCount((c) => c + 1);
    void refresh();
  });

  return (
    <button onClick={() => navigate('/notifications')} className="relative rounded-full p-2 text-slate-600 hover:bg-slate-100" aria-label={t('nav.notifications')}>
      <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
        <path d="M18 8a6 6 0 10-12 0c0 7-3 8-3 8h18s-3-1-3-8M10 21a2 2 0 004 0" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      {count > 0 && (
        <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white">
          {count > 99 ? '99+' : count}
        </span>
      )}
    </button>
  );
}

function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  const { user } = useAuth();
  const t = useT();
  const clientNav = useClientNav(t);
  const adminNav = useAdminNav(t);
  const isStaff = user?.role === 'admin' || user?.role === 'moderator';
  return (
    <div className="flex h-full flex-col overflow-y-auto">
      <div className="flex items-center gap-3 px-5 py-5">
        <span className="flex h-11 w-11 items-center justify-center rounded-xl bg-white shadow-sm ring-1 ring-white/10">
          <img src="/logo.png" alt="SUP FUN" className="h-9 w-9 rounded-lg object-contain" />
        </span>
        <div className="leading-tight">
          <div className="text-base font-extrabold text-white">SUP FUN</div>
        </div>
      </div>
      <nav className="flex-1 space-y-5 px-3 pb-6">
        {clientNav.map((section) => (
          <div key={section.group}>
            <div className="px-2 pb-1.5 text-[10px] font-semibold uppercase tracking-widest text-slate-500">{section.group}</div>
            <div className="space-y-0.5">
              {section.items.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.end}
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    `flex items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-medium transition ${
                      isActive ? 'bg-brand-600/20 text-white' : 'text-slate-400 hover:bg-white/5 hover:text-white'
                    }`
                  }
                >
                  {item.icon}
                  {item.label}
                </NavLink>
              ))}
            </div>
          </div>
        ))}
        {isStaff && (
          <div>
            <div className="flex items-center gap-2 px-2 pb-1.5 text-[10px] font-semibold uppercase tracking-widest text-violet-400">
              <svg className="h-3 w-3" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2l9 4v6c0 5.5-3.8 9.7-9 12-5.2-2.3-9-6.5-9-12V6l9-4z" />
              </svg>
              {t('nav.group.admin')}
            </div>
            <div className="space-y-0.5">
              {adminNav.map((item) => (
                <NavLink
                  key={item.to}
                  to={item.to}
                  end={item.end}
                  onClick={onNavigate}
                  className={({ isActive }) =>
                    `flex items-center gap-3 rounded-lg px-2.5 py-2 text-sm font-medium transition ${
                      isActive ? 'bg-violet-600/25 text-white' : 'text-slate-400 hover:bg-white/5 hover:text-white'
                    }`
                  }
                >
                  {item.icon}
                  {item.label}
                </NavLink>
              ))}
            </div>
          </div>
        )}
      </nav>
      <div className="border-t border-white/10 p-3">
        {user && (
          <div className="flex items-center gap-3 rounded-lg px-2 py-2">
            <Avatar user={user} size="md" />
            <div className="min-w-0 leading-tight">
              <div className="truncate text-sm font-semibold text-white">{user.name}</div>
              <div className="text-xs text-slate-400">{user.email}</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default function Layout() {
  const { user, logout } = useAuth();
  const t = useT();
  const navigate = useNavigate();
  const location = useLocation();
  const [sidebarOpen, setSidebarOpen] = useState(false);

  useEffect(() => {
    setSidebarOpen(false);
  }, [location.pathname, location.search]);

  return (
    <div className="min-h-screen bg-slate-50">
      {/* desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 bg-slate-900 lg:block">
        <SidebarContent />
      </aside>
      {/* mobile sidebar */}
      {sidebarOpen && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-slate-900/60" onClick={() => setSidebarOpen(false)} />
          <aside className="absolute inset-y-0 left-0 w-72 bg-slate-900 shadow-2xl">
            <SidebarContent onNavigate={() => setSidebarOpen(false)} />
          </aside>
        </div>
      )}

      <div className="lg:pl-64">
        <header className="sticky top-0 z-20 border-b border-slate-200 bg-white/90 backdrop-blur">
          <div className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-2.5">
            <button className="rounded-lg p-2 text-slate-600 hover:bg-slate-100 lg:hidden" onClick={() => setSidebarOpen(true)} aria-label={t('layout.menu')}>
              <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M4 6h16M4 12h16M4 18h16" strokeLinecap="round" />
              </svg>
            </button>
            <div className="hidden sm:block">
              <SearchForm />
            </div>
            <div className="ml-auto flex items-center gap-1">
              <UnreadBell />
              <button
                className="rounded-lg p-2 text-slate-600 hover:bg-slate-100"
                onClick={() => navigate('/profile')}
                aria-label={t('nav.profile')}
              >
                <Avatar user={user} size="sm" />
              </button>
              <button
                className="rounded-lg p-2 text-slate-500 hover:bg-slate-100"
                onClick={() => {
                  logout();
                  navigate('/login');
                }}
                title={t('layout.logout')}
                aria-label={t('layout.logout')}
              >
                <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8">
                  <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
              </button>
            </div>
          </div>
          <div className="px-4 pb-2 sm:hidden">
            <SearchForm />
          </div>
        </header>
        <main className="mx-auto max-w-6xl px-4 py-6">
          <Outlet />
        </main>
        <footer className="mx-auto max-w-6xl px-4 pb-8 text-xs text-slate-400">
          {t('layout.footer')}
        </footer>
      </div>
    </div>
  );
}