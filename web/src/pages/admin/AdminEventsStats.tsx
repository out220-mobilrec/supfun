import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../../lib/api';
import { Alert, Button, Card, Input, Loading, StatCard } from '../../components/ui';
import { formatDateTime, formatDistance, formatDuration } from '../../lib/format';
import { AdminHeader } from './shared';
import { useT } from '../../i18n';

interface EventStatRow {
  eventId: string;
  title: string;
  eventDate: string;
  waterBodyName: string | null;
  participantCount: number;
  trackCount: number;
  totalDistanceMeters: number;
  totalDurationSeconds: number;
}

interface EventMonthRow {
  month: string;
  eventCount: number;
  participantCount: number;
  totalDistanceMeters: number;
}

interface EventStats {
  totalEvents: number;
  scheduledEvents: number;
  completedEvents: number;
  totalParticipants: number;
  uniqueParticipants: number;
  totalTracks: number;
  totalDistanceMeters: number;
  totalDurationSeconds: number;
  avgDistanceMeters: number;
  avgDurationSeconds: number;
  totalPoints: number;
  totalReviews: number;
  avgRating: number | null;
  topEvents: EventStatRow[];
  eventsByMonth: EventMonthRow[];
}

function defaultRange(): { from: string; to: string } {
  const now = new Date();
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  const last = new Date(now.getFullYear(), now.getMonth() + 1, 0);
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  return { from: iso(first), to: iso(last) };
}

export default function AdminEventsStats() {
  const t = useT();
  const init = defaultRange();
  const [from, setFrom] = useState(init.from);
  const [to, setTo] = useState(init.to);
  const [stats, setStats] = useState<EventStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const presets = useMemo(() => [
    { label: t('admin.stats.thisMonth'), fn: () => defaultRange() },
    {
      label: t('admin.stats.lastMonth'),
      fn: () => {
        const now = new Date();
        const first = new Date(now.getFullYear(), now.getMonth() - 1, 1);
        const last = new Date(now.getFullYear(), now.getMonth(), 0);
        const iso = (d: Date) => d.toISOString().slice(0, 10);
        return { from: iso(first), to: iso(last) };
      },
    },
    {
      label: t('admin.stats.days30'),
      fn: () => {
        const now = new Date();
        const ago = new Date(now.getTime() - 30 * 24 * 3600 * 1000);
        const iso = (d: Date) => d.toISOString().slice(0, 10);
        return { from: iso(ago), to: iso(now) };
      },
    },
    {
      label: t('admin.stats.year'),
      fn: () => {
        const now = new Date();
        const jan = new Date(now.getFullYear(), 0, 1);
        const iso = (d: Date) => d.toISOString().slice(0, 10);
        return { from: iso(jan), to: iso(now) };
      },
    },
    { label: t('admin.stats.allTime'), fn: () => ({ from: '', to: '' }) },
  ], [t]);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      if (from) params.set('from', from);
      if (to) params.set('to', to);
      const qs = params.toString();
      const { data } = await api.get<EventStats>(`/admin/events/stats${qs ? `?${qs}` : ''}`);
      setStats(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [from, to]);

  useEffect(() => {
    void load();
  }, [load]);

  const applyPreset = (fn: () => { from: string; to: string }) => {
    const r = fn();
    setFrom(r.from);
    setTo(r.to);
  };

  const formatMonth = (ym: string): string => {
    const [y, m] = ym.split('-');
    const en = typeof window !== 'undefined' && localStorage.getItem('sf_locale') === 'en';
    const namesRu = ['январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь'];
    const namesEn = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    const idx = parseInt(m, 10) - 1;
    const names = en ? namesEn : namesRu;
    return `${names[idx] ?? m} ${y}`;
  };

  return (
    <div className="space-y-6">
      <AdminHeader
        title={t('admin.stats.title')}
        subtitle={t('admin.stats.subtitle')}
      />

      <Card className="p-4">
        <div className="flex flex-wrap items-end gap-3">
          <div>
            <label className="mb-1 block text-xs font-semibold uppercase text-slate-400">{t('admin.stats.from')}</label>
            <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} className="w-[150px]" />
          </div>
          <div>
            <label className="mb-1 block text-xs font-semibold uppercase text-slate-400">{t('admin.stats.to')}</label>
            <Input type="date" value={to} onChange={(e) => setTo(e.target.value)} className="w-[150px]" />
          </div>
          <div className="flex flex-wrap gap-2 pb-0.5">
            {presets.map((p) => (
              <Button key={p.label} size="sm" tone="outline" onClick={() => applyPreset(p.fn)}>
                {p.label}
              </Button>
            ))}
          </div>
        </div>
      </Card>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && stats && (
        <>
          <section>
            <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.stats.period')}</h2>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <StatCard label={t('admin.stats.events')} value={stats.totalEvents} />
              <StatCard label={t('admin.stats.participantsTotal')} value={stats.totalParticipants} tone="blue" />
              <StatCard label={t('admin.stats.participantsUnique')} value={stats.uniqueParticipants} tone="violet" />
              <StatCard label={t('admin.stats.tracksSubmitted')} value={stats.totalTracks} tone="cyan" />
              <StatCard label={t('admin.stats.totalDistance')} value={formatDistance(stats.totalDistanceMeters)} tone="green" />
              <StatCard label={t('admin.stats.totalTime')} value={formatDuration(stats.totalDurationSeconds)} tone="amber" />
              <StatCard label={t('admin.stats.gpsPoints')} value={stats.totalPoints} tone="slate" />
              <StatCard
                label={t('admin.stats.reviews')}
                value={stats.totalReviews > 0 ? `${stats.totalReviews} · ${stats.avgRating?.toFixed(1)}★` : '—'}
                tone="red"
              />
            </div>
          </section>

          <section>
            <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.stats.avgPerEvent')}</h2>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <StatCard label={t('admin.stats.distance')} value={formatDistance(stats.avgDistanceMeters)} />
              <StatCard label={t('admin.stats.duration')} value={formatDuration(stats.avgDurationSeconds)} />
              <StatCard label={t('admin.stats.participants')} value={stats.totalEvents > 0 ? (stats.totalParticipants / stats.totalEvents).toFixed(1) : '—'} />
              <StatCard label={t('admin.stats.tracks')} value={stats.totalEvents > 0 ? (stats.totalTracks / stats.totalEvents).toFixed(1) : '—'} />
            </div>
          </section>

          {stats.eventsByMonth.length > 0 && (
            <section>
              <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.stats.byMonth')}</h2>
              <Card className="overflow-x-auto">
                <table className="w-full min-w-[600px] text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                      <th className="p-3">{t('admin.stats.month')}</th>
                      <th className="p-3">{t('admin.stats.events')}</th>
                      <th className="p-3">{t('admin.stats.participants')}</th>
                      <th className="p-3">{t('admin.stats.distance')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stats.eventsByMonth.map((m) => (
                      <tr key={m.month} className="border-b border-slate-50">
                        <td className="p-3 font-medium text-slate-800">{formatMonth(m.month)}</td>
                        <td className="p-3 text-slate-600">{m.eventCount}</td>
                        <td className="p-3 text-slate-600">{m.participantCount}</td>
                        <td className="p-3 text-slate-600">{formatDistance(m.totalDistanceMeters)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </Card>
            </section>
          )}

          {stats.topEvents.length > 0 && (
            <section>
              <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">
                {t('admin.stats.topEvents')}
              </h2>
              <Card className="overflow-x-auto">
                <table className="w-full min-w-[820px] text-sm">
                  <thead>
                    <tr className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                      <th className="p-3">{t('admin.stats.event')}</th>
                      <th className="p-3">{t('admin.stats.date')}</th>
                      <th className="p-3">{t('admin.stats.waterbody')}</th>
                      <th className="p-3">{t('admin.stats.participants')}</th>
                      <th className="p-3">{t('admin.stats.tracks')}</th>
                      <th className="p-3">{t('admin.stats.distance')}</th>
                      <th className="p-3">{t('admin.stats.duration')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {stats.topEvents.map((e) => (
                      <tr key={e.eventId} className="border-b border-slate-50">
                        <td className="p-3">
                          <Link to={`/events/${e.eventId}`} className="font-medium text-slate-800 hover:text-brand-700">
                            {e.title}
                          </Link>
                        </td>
                        <td className="p-3 text-slate-600">{formatDateTime(e.eventDate)}</td>
                        <td className="p-3 text-slate-600">{e.waterBodyName ?? '—'}</td>
                        <td className="p-3 text-slate-600">{e.participantCount}</td>
                        <td className="p-3 text-slate-600">{e.trackCount}</td>
                        <td className="p-3 text-slate-600">{formatDistance(e.totalDistanceMeters)}</td>
                        <td className="p-3 text-slate-600">{formatDuration(e.totalDurationSeconds)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </Card>
            </section>
          )}
        </>
      )}
    </div>
  );
}
