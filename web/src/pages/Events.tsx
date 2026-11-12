import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Event, WaterBody } from '../types';
import { EVENT_STATUSES, type EventStatus } from '../lib/lists';
import { Card, EmptyState, Loading, PageHeader, Select } from '../components/ui';
import { EventLevelBadge, EventStatusBadge } from '../components/statusBadges';
import { Avatar } from '../components/Avatar';
import { formatDateTime, formatDistance, formatDuration } from '../lib/format';
import { eventStatusLabel } from '../lib/labels';
import { useT } from '../i18n';

type Tab = 'upcoming' | 'all' | 'mine';

export default function EventsPage() {
  const t = useT();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const tab = (params.get('tab') as Tab) || 'upcoming';
  const status = (params.get('status') as EventStatus | null) ?? '';
  const waterBodyId = params.get('waterBodyId') ?? '';
  const date = params.get('date') ?? '';

  const [events, setEvents] = useState<Event[]>([]);
  const [waterbodies, setWaterbodies] = useState<WaterBody[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    api.get<WaterBody[]>('/waterbodies').then(({ data }) => setWaterbodies(data)).catch(() => undefined);
  }, []);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError('');
    (async () => {
      try {
        let data: Event[];
        if (tab === 'mine') {
          const res = await api.get<Event[]>('/events/mine/going');
          data = res.data;
          if (date) data = data.filter((e) => e.eventDate.slice(0, 10) === date);
        } else {
          const query = new URLSearchParams();
          if (status) query.set('status', status);
          if (waterBodyId) query.set('waterBodyId', waterBodyId);
          if (date) query.set('date', date);
          if (tab === 'upcoming') query.set('from', new Date().toISOString());
          const res = await api.get<Event[]>(`/events?${query.toString()}`);
          data = res.data;
        }
        if (mounted) setEvents(data);
      } catch (err) {
        if (mounted) setError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [tab, status, waterBodyId, date]);

  const waterBodyName = useMemo(() => {
    const map = new Map(waterbodies.map((w) => [w.id, w.name]));
    return (id: string | null) => (id ? map.get(id) ?? null : null);
  }, [waterbodies]);

  const setParam = (key: string, value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next);
  };

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('events.title')}
        subtitle={t('events.subtitle')}
        action={
          <button onClick={() => navigate('/events/new')} className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700">
            + {t('events.createAction')}
          </button>
        }
      />

      <div className="flex flex-wrap items-center gap-3">
        <div className="flex rounded-lg border border-slate-200 bg-white p-0.5">
          {(
            [
              ['upcoming', t('events.tab.upcoming')],
              ['all', t('events.tab.all')],
              ['mine', t('events.tab.mine')],
            ] as [Tab, string][]
          ).map(([value, label]) => (
            <button
              key={value}
              onClick={() => setParam('tab', value)}
              className={`rounded-md px-3 py-1.5 text-sm font-semibold transition ${
                tab === value ? 'bg-brand-600 text-white' : 'text-slate-600 hover:bg-slate-100'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {tab !== 'mine' && (
          <>
            <Select value={status} onChange={(e) => setParam('status', e.target.value)} className="max-w-[180px]">
              <option value="">{t('events.anyStatus')}</option>
              {EVENT_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {eventStatusLabel(s)}
                </option>
              ))}
            </Select>
            <Select value={waterBodyId} onChange={(e) => setParam('waterBodyId', e.target.value)} className="max-w-[220px]">
              <option value="">{t('events.allWaterbodies')}</option>
              {waterbodies.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </Select>
            <div className="flex items-center gap-2">
              <input
                type="date"
                value={date}
                onChange={(e) => setParam('date', e.target.value)}
                className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-700 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-200"
                aria-label={t('events.date')}
              />
              {date && (
                <button
                  onClick={() => setParam('date', '')}
                  className="text-xs font-semibold text-slate-500 hover:text-slate-700"
                >
                  {t('action.clear')}
                </button>
              )}
            </div>
          </>
        )}
      </div>

      {loading && <Loading />}
      {error && <div className="text-sm text-red-600">{error}</div>}

      {!loading && events.length === 0 && (
        <EmptyState
          title={t('events.notFound')}
          hint={t('events.notFoundHint')}
          action={<Link to="/events/new" className="text-sm font-semibold text-brand-600">{t('events.createAction')}</Link>}
        />
      )}

      <div className="grid gap-4 md:grid-cols-2">
        {events.map((ev) => (
          <Card key={ev.id} className="p-4" onClick={() => navigate(`/events/${ev.id}`)}>
            <div className="flex items-start justify-between gap-2">
              <div className="font-bold text-slate-900">{ev.title}</div>
              <EventStatusBadge status={ev.status} />
            </div>
            <div className="mt-1 text-sm text-slate-500">
              {ev.track?.name
                ? `${t('events.routePrefix')}: ${ev.track.name}`
                : ev.waterBody?.name ?? waterBodyName(ev.waterBodyId) ?? t('dashboard.noWaterbody')}{' '}
              · {formatDateTime(ev.eventDate)}
            </div>
            <div className="mt-2 flex flex-wrap items-center gap-2 text-sm text-slate-500">
              <EventLevelBadge level={ev.level} />
              {ev.expectedDistanceMeters ? <span>{formatDistance(ev.expectedDistanceMeters)}</span> : null}
              {ev.expectedDurationMinutes ? <span>{formatDuration(ev.expectedDurationMinutes * 60)}</span> : null}
              <span>· {ev.participantCount ?? 0} {t('events.goingCount')}</span>
            </div>
            <div className="mt-3 flex items-center gap-2 text-sm text-slate-500">
              <Avatar user={ev.organizer} size="sm" />
              {ev.organizer?.name}
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
