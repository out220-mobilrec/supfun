import { useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import { useT } from '../i18n';
import type { FeedResponse, LevelInfo, News } from '../types';
import { Card, EmptyState, Loading } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { formatDate, formatDistance, formatDuration, formatPrice, relativeTime } from '../lib/format';
import { listingCategoryLabel } from '../lib/labels';

interface DashboardData {
  feed: FeedResponse | null;
  level: LevelInfo | null;
  unread: number;
  news: News[];
}

export default function Dashboard() {
  const { user } = useAuth();
  const t = useT();
  const navigate = useNavigate();
  const [data, setData] = useState<DashboardData>({ feed: null, level: null, unread: 0, news: [] });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let mounted = true;
    (async () => {
      const [feedRes, levelRes, unreadRes, newsRes] = await Promise.allSettled([
        api.get<FeedResponse>('/feed?limit=12'),
        api.get<LevelInfo>('/gamification/me'),
        api.get<{ count: number }>('/notifications/unread-count'),
        api.get<News[]>('/news', { params: { limit: 3 } }),
      ]);
      if (!mounted) return;
      setData({
        feed: feedRes.status === 'fulfilled' ? feedRes.value.data : null,
        level: levelRes.status === 'fulfilled' ? levelRes.value.data : null,
        unread: unreadRes.status === 'fulfilled' ? (unreadRes.value.data?.count ?? 0) : 0,
        news: newsRes.status === 'fulfilled' && Array.isArray(newsRes.value.data) ? newsRes.value.data.slice(0, 3) : [],
      });
      if (feedRes.status === 'rejected' && levelRes.status === 'rejected') {
        setError(errorMessage((feedRes as PromiseRejectedResult).reason));
      }
      setLoading(false);
    })();
    return () => {
      mounted = false;
    };
  }, []);

  const greeting = useMemo(() => {
    const h = new Date().getHours();
    if (h < 5) return t('dashboard.greeting.night');
    if (h < 12) return t('dashboard.greeting.morning');
    if (h < 18) return t('dashboard.greeting.day');
    return t('dashboard.greeting.evening');
  }, [t]);

  if (loading) return <Loading />;

  const { feed, level, unread, news } = data;
  const firstName = user?.name?.split(' ')[0] ?? '';
  const events = feed?.events?.slice(0, 4) ?? [];
  const routes = feed?.routes?.slice(0, 5) ?? [];
  const listings = feed?.listings?.slice(0, 4) ?? [];

  return (
    <div className="space-y-6 pb-4">
      {/* Hero */}
      <section className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-brand-700 via-cyan-700 to-blue-800 p-6 text-white shadow-lg md:p-8">
        <div className="pointer-events-none absolute -right-10 -top-10 h-48 w-48 rounded-full bg-white/10 blur-2xl" />
        <div className="pointer-events-none absolute bottom-0 left-1/3 h-32 w-64 rounded-full bg-cyan-300/10 blur-3xl" />
        <div className="relative flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-2xl">
            <div className="text-sm font-medium text-cyan-100/90">{formatDate(new Date().toISOString())}</div>
            <h1 className="mt-1 text-2xl font-extrabold tracking-tight md:text-3xl">
              {greeting}{firstName ? `, ${firstName}` : ''}
            </h1>
            <p className="mt-2 text-sm text-cyan-50/90 md:text-base">{t('dashboard.subtitle')}</p>
            <div className="mt-5 flex flex-wrap gap-3">
              <button
                onClick={() => navigate('/events/new')}
                className="inline-flex items-center gap-2 rounded-xl bg-white px-4 py-2.5 text-sm font-bold text-brand-800 shadow-sm transition hover:bg-cyan-50"
              >
                <span>🗓</span>{t('dashboard.cta.event')}
              </button>
              <button
                onClick={() => navigate('/tracks')}
                className="inline-flex items-center gap-2 rounded-xl bg-white/15 px-4 py-2.5 text-sm font-semibold text-white ring-1 ring-white/25 transition hover:bg-white/20"
              >
                <span>📍</span>{t('dashboard.cta.route')}
              </button>
              <button
                onClick={() => navigate('/search')}
                className="inline-flex items-center gap-2 rounded-xl bg-white/15 px-4 py-2.5 text-sm font-semibold text-white ring-1 ring-white/25 transition hover:bg-white/20"
              >
                <span>🔎</span>{t('dashboard.cta.explore')}
              </button>
            </div>
          </div>
          {level && (
            <div className="w-full shrink-0 rounded-2xl bg-white/12 p-4 ring-1 ring-white/20 backdrop-blur-sm lg:w-72">
              <div className="flex items-center justify-between">
                <div className="text-xs font-semibold uppercase tracking-wider text-cyan-100">{t('dashboard.level')}</div>
                <div className="rounded-full bg-white/20 px-2.5 py-0.5 text-sm font-extrabold">{level.level}</div>
              </div>
              <div className="mt-2 flex items-end justify-between">
                <div className="text-2xl font-extrabold">{level.xp} <span className="text-sm font-semibold text-cyan-100">XP</span></div>
                <div className="text-right text-xs text-cyan-100">
                  {t('dashboard.levelNext')} {level.level + 1}: {Math.max(0, (level.nextLevelXp ?? 0) - (level.currentLevelXp ?? 0))} XP
                </div>
              </div>
              <div className="mt-3 h-2 overflow-hidden rounded-full bg-white/20">
                <div className="h-full rounded-full bg-white" style={{ width: `${Math.min(100, (level.progress ?? 0) * 100)}%` }} />
              </div>
              <div className="mt-3 flex gap-2">
                <Link to="/profile" className="flex-1 rounded-lg bg-white/15 px-2 py-1.5 text-center text-xs font-semibold hover:bg-white/20">
                  {t('dashboard.points')}
                </Link>
                <Link to="/rating" className="flex-1 rounded-lg bg-white/15 px-2 py-1.5 text-center text-xs font-semibold hover:bg-white/20">
                  {t('nav.rating')}
                </Link>
              </div>
            </div>
          )}
        </div>
      </section>

      {error && <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}

      {/* Stats */}
      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <Stat onClick={() => navigate('/events')} icon="🗓" value={feed?.events?.length ?? '—'} label={t('dashboard.stat.events')} tone="brand" />
        <Stat onClick={() => navigate('/tracks')} icon="📍" value={feed?.routes?.length ?? '—'} label={t('dashboard.stat.routes')} tone="cyan" />
        <Stat onClick={() => navigate('/marketplace')} icon="🏄" value={feed?.listings?.length ?? '—'} label={t('dashboard.stat.listings')} tone="blue" />
        <Stat onClick={() => navigate('/notifications')} icon="🔔" value={unread} label={t('dashboard.stat.unread')} tone={unread > 0 ? 'amber' : 'slate'} highlight={unread > 0} />
      </section>

      {/* Quick actions */}
      <section className="grid grid-cols-3 gap-3 sm:grid-cols-6">
        <QuickAction icon="🗓" label={t('dashboard.quick.createEvent')} onClick={() => navigate('/events/new')} />
        <QuickAction icon="🏄" label={t('dashboard.quick.listing')} onClick={() => navigate('/marketplace/new')} />
        <QuickAction icon="🤝" label={t('dashboard.quick.findCompany')} onClick={() => navigate('/events')} />
        <QuickAction icon="🌊" label={t('dashboard.quick.map')} onClick={() => navigate('/waterbodies')} />
        <QuickAction icon="💬" label={t('dashboard.quick.chat')} onClick={() => navigate('/chats')} />
        <QuickAction icon="🔎" label={t('dashboard.quick.search')} onClick={() => navigate('/search')} />
      </section>

      <div className="grid gap-6 xl:grid-cols-3">
        {/* Events - main column */}
        <section className="space-y-6 xl:col-span-2">
          <Block title={t('dashboard.section.events')} to="/events" actionLabel={t('dashboard.all')}>
            {events.length ? (
              <div className="grid gap-3 sm:grid-cols-2">
                {events.map((ev) => (
                  <Card key={ev.id} className="group overflow-hidden p-0 transition hover:-translate-y-0.5" onClick={() => navigate(`/events/${ev.id}`)}>
                    <div className="flex">
                      <div className="flex w-20 shrink-0 flex-col items-center justify-center bg-gradient-to-b from-brand-50 to-cyan-50 px-2 py-4 text-brand-800">
                        <div className="text-[10px] font-bold uppercase tracking-wide text-brand-600">{monthShort(ev.eventDate)}</div>
                        <div className="text-2xl font-extrabold leading-none">{dayNum(ev.eventDate)}</div>
                        <div className="mt-1 text-[10px] font-semibold text-slate-500">{timeShort(ev.eventDate)}</div>
                      </div>
                      <div className="min-w-0 flex-1 p-4">
                        <div className="truncate font-bold text-slate-900 group-hover:text-brand-700">{ev.title}</div>
                        <div className="mt-1 flex items-center gap-1.5 text-xs text-slate-500">
                          <span>📍</span>
                          <span className="truncate">{ev.waterBodyName ?? t('dashboard.noWaterbody')}</span>
                        </div>
                        <div className="mt-2 flex items-center gap-2 text-xs text-slate-600">
                          <Avatar user={{ name: ev.organizerName, avatarUrl: null }} size="sm" />
                          <span className="truncate">{ev.organizerName}</span>
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            ) : (
              <EmptyState
                title={t('dashboard.noEvents')}
                hint={t('dashboard.noEventsHint')}
                action={<Link to="/events/new" className="text-sm font-semibold text-brand-600">{t('dashboard.cta.event')}</Link>}
              />
            )}
          </Block>

          <Block title={t('dashboard.section.routes')} to="/tracks" actionLabel={t('dashboard.all')}>
            {routes.length ? (
              <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-2 2xl:grid-cols-3">
                {routes.map((r) => (
                  <Card key={r.id} className="group p-4 transition hover:-translate-y-0.5" onClick={() => navigate('/tracks')}>
                    <div className="flex items-start gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-cyan-50 text-lg">🗺</div>
                      <div className="min-w-0">
                        <div className="truncate font-semibold text-slate-900 group-hover:text-brand-700">{r.name || t('dashboard.untitledRoute')}</div>
                        <div className="mt-1 flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-slate-500">
                          <span className="font-medium text-cyan-700">{formatDistance(r.distance_meters)}</span>
                          {r.durationSeconds ? <span>⏱ {formatDuration(r.durationSeconds)}</span> : null}
                        </div>
                      </div>
                    </div>
                  </Card>
                ))}
              </div>
            ) : (
              <EmptyState title={t('dashboard.noRoutes')} hint={t('dashboard.noRoutesHint')} />
            )}
          </Block>
        </section>

        {/* Sidebar column */}
        <aside className="space-y-6">
          {news.length > 0 && (
            <Block title={t('dashboard.section.news')} to="/news" actionLabel={t('dashboard.all')}>
              <div className="space-y-3">
                {news.map((n) => (
                  <button
                    key={n.id}
                    onClick={() => navigate(`/news/${n.id}`)}
                    className="flex w-full gap-3 rounded-xl border border-slate-100 bg-white p-3 text-left transition hover:border-brand-200 hover:bg-slate-50"
                  >
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-amber-50 text-lg">📰</div>
                    <div className="min-w-0">
                      <div className="line-clamp-2 text-sm font-semibold text-slate-900">{n.title}</div>
                      <div className="mt-0.5 text-xs text-slate-400">{relativeTime(n.createdAt)}</div>
                    </div>
                  </button>
                ))}
              </div>
            </Block>
          )}

          <Block title={t('dashboard.section.listings')} to="/marketplace" actionLabel={t('dashboard.catalog')}>
            {listings.length ? (
              <div className="space-y-3">
                {listings.map((l) => (
                  <Card key={l.id} className="p-3 transition hover:-translate-y-0.5" onClick={() => navigate(`/marketplace/${l.id}`)}>
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="truncate text-sm font-semibold text-slate-900">{l.title}</div>
                        <div className="mt-0.5 text-xs text-slate-500">{listingCategoryLabel(l.category)}</div>
                      </div>
                      <div className="shrink-0 text-sm font-extrabold text-brand-700">{formatPrice(l.price, l.currency)}</div>
                    </div>
                  </Card>
                ))}
              </div>
            ) : (
              <EmptyState title={t('dashboard.noListings')} hint={t('dashboard.noListingsHint')} action={<Link to="/marketplace/new" className="text-sm font-semibold text-brand-600">{t('dashboard.quick.listing')}</Link>} />
            )}
          </Block>

          <Card className="overflow-hidden p-0">
            <div className="bg-gradient-to-r from-slate-800 to-slate-900 p-4 text-white">
              <div className="text-xs font-semibold uppercase tracking-wider text-slate-300">{t('dashboard.pulse')}</div>
              <div className="mt-2 grid grid-cols-3 gap-2 text-center">
                <Pulse value={feed?.events?.length ?? 0} label={t('nav.events')} />
                <Pulse value={feed?.routes?.length ?? 0} label={t('nav.tracks')} />
                <Pulse value={feed?.listings?.length ?? 0} label={t('nav.catalog')} />
              </div>
            </div>
            <div className="flex divide-x divide-slate-100">
              <Link to="/channels" className="flex-1 px-3 py-3 text-center text-xs font-semibold text-slate-700 hover:bg-slate-50">{t('nav.channels')}</Link>
              <Link to="/friends" className="flex-1 px-3 py-3 text-center text-xs font-semibold text-slate-700 hover:bg-slate-50">{t('nav.friends')}</Link>
              <Link to="/feed" className="flex-1 px-3 py-3 text-center text-xs font-semibold text-slate-700 hover:bg-slate-50">{t('nav.feed')}</Link>
            </div>
          </Card>
        </aside>
      </div>
    </div>
  );
}

function Block({ title, to, actionLabel, children }: { title: string; to: string; actionLabel: string; children: ReactNode }) {
  return (
    <div>
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-base font-extrabold text-slate-900 md:text-lg">{title}</h2>
        <Link to={to} className="rounded-lg px-2 py-1 text-xs font-bold text-brand-700 hover:bg-brand-50">
          {actionLabel} →
        </Link>
      </div>
      {children}
    </div>
  );
}

function Stat({
  icon, value, label, onClick, tone, highlight,
}: {
  icon: string; value: React.ReactNode; label: string; onClick: () => void; tone: string; highlight?: boolean;
}) {
  const ring = highlight ? 'ring-2 ring-amber-300 border-amber-200' : 'border-slate-200';
  const tones: Record<string, string> = {
    brand: 'bg-brand-50 text-brand-700',
    cyan: 'bg-cyan-50 text-cyan-700',
    blue: 'bg-blue-50 text-blue-700',
    amber: 'bg-amber-50 text-amber-700',
    slate: 'bg-slate-100 text-slate-600',
  };
  return (
    <button onClick={onClick} className={`flex items-center gap-3 rounded-2xl border bg-white p-3 text-left shadow-sm transition hover:-translate-y-0.5 hover:shadow-md ${ring}`}>
      <div className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-xl text-lg ${tones[tone] ?? tones.slate}`}>{icon}</div>
      <div className="min-w-0">
        <div className="text-xl font-extrabold leading-none text-slate-900">{value}</div>
        <div className="mt-1 truncate text-[11px] font-semibold text-slate-500">{label}</div>
      </div>
    </button>
  );
}

function QuickAction({ icon, label, onClick }: { icon: string; label: string; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className="group flex flex-col items-center justify-center gap-1.5 rounded-2xl border border-slate-200 bg-white px-2 py-4 shadow-sm transition hover:-translate-y-0.5 hover:border-brand-300 hover:shadow-md"
    >
      <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-slate-50 text-xl transition group-hover:bg-brand-50">{icon}</span>
      <span className="text-center text-[11px] font-bold leading-tight text-slate-700">{label}</span>
    </button>
  );
}

function Pulse({ value, label }: { value: number; label: string }) {
  return (
    <div className="rounded-xl bg-white/10 px-2 py-2">
      <div className="text-lg font-extrabold">{value}</div>
      <div className="text-[10px] font-medium text-slate-300">{label}</div>
    </div>
  );
}

function monthShort(iso: string): string {
  const loc = typeof window !== 'undefined' && localStorage.getItem('sf_locale') === 'en' ? 'en-US' : 'ru-RU';
  return new Intl.DateTimeFormat(loc, { month: 'short' }).format(new Date(iso)).replace('.', '');
}
function dayNum(iso: string): string {
  return String(new Date(iso).getDate());
}
function timeShort(iso: string): string {
  const loc = typeof window !== 'undefined' && localStorage.getItem('sf_locale') === 'en' ? 'en-US' : 'ru-RU';
  return new Intl.DateTimeFormat(loc, { hour: '2-digit', minute: '2-digit' }).format(new Date(iso));
}