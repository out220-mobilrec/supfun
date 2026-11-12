import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Event, RouteView, WaterBody } from '../types';
import { Alert, Badge, Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { EventLevelBadge, EventStatusBadge } from '../components/statusBadges';
import { formatDateTime, formatDistance } from '../lib/format';
import WaterbodyMap from '../components/WaterbodyMap';
import WeatherCard from '../components/WeatherCard';
import { useT } from '../i18n';

export default function WaterbodyDetailPage() {
  const { id } = useParams();
  const t = useT();
  const [waterbody, setWaterbody] = useState<WaterBody | null>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [routes, setRoutes] = useState<RouteView[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!id) return;
    let mounted = true;
    (async () => {
      try {
        const [wbRes, routesRes] = await Promise.all([
          api.get<WaterBody>(`/waterbodies/${id}`),
          api.get<RouteView[]>(`/routes?waterbodyId=${id}`).catch(() => ({ data: [] as RouteView[] })),
        ]);
        if (!mounted) return;
        setWaterbody(wbRes.data);
        setRoutes(routesRes.data);
        try {
          const evRes = await api.get<Event[]>(`/events?waterBodyId=${id}`);
          if (mounted) setEvents(evRes.data);
        } catch {
          /* events may require auth */
        }
      } catch (err) {
        if (mounted) setError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [id]);

  if (loading) return <Loading />;
  if (!waterbody) return <Alert>{error || t('common.notFound')}</Alert>;

  return (
    <div className="space-y-5">
      <PageHeader title={waterbody.name} subtitle={waterbody.region ?? t('waterbodies.regionUnknown')} />
      {error && <Alert>{error}</Alert>}

      {waterbody.latitude != null && waterbody.longitude != null ? (
        <div className="grid gap-5 lg:grid-cols-[1.2fr_1fr]">
          <Card className="p-5">
            <h2 className="mb-3 text-lg font-bold text-slate-900">{t('nav.waterbodies')}</h2>
            <WaterbodyMap
              latitude={waterbody.latitude}
              longitude={waterbody.longitude}
              name={waterbody.name}
              region={waterbody.region}
            />
          </Card>
          <WeatherCard
            lat={waterbody.latitude}
            lon={waterbody.longitude}
            title={`${t('weather.title')} · ${waterbody.name}`}
          />
        </div>
      ) : null}

      <Card className="p-5">
        {waterbody.description ? (
          <p className="whitespace-pre-line text-sm text-slate-700">{waterbody.description}</p>
        ) : (
          <p className="text-sm text-slate-400">—</p>
        )}
        <div className="mt-4 grid grid-cols-2 gap-4 border-t border-slate-100 pt-4 text-sm sm:grid-cols-3">
          <div>
            <div className="text-xs uppercase tracking-wide text-slate-400">{t('waterbodies.allRegions').replace('All ', '').replace('Все ', '') || 'Region'}</div>
            <div className="font-semibold text-slate-800">{waterbody.region ?? '—'}</div>
          </div>
          <div>
            <div className="text-xs uppercase tracking-wide text-slate-400">Status</div>
            <div className="font-semibold text-slate-800">{waterbody.active ? '✓' : t('waterbodies.inactive')}</div>
          </div>
          <div>
            <div className="text-xs uppercase tracking-wide text-slate-400">—</div>
            <div className="font-semibold text-slate-800">{formatDateTime(waterbody.createdAt)}</div>
          </div>
        </div>
      </Card>

      <section>
        <div className="mb-3 flex items-center justify-between gap-3">
          <h2 className="text-lg font-bold text-slate-900">{t('waterbody.routes')}</h2>
          <Link to="/routes" className="text-sm font-semibold text-brand-600 hover:underline">{t('tracks.routes')}</Link>
        </div>
        {routes.length === 0 ? (
          <EmptyState title={t('waterbody.noRoutes')} hint={t('dashboard.noRoutesHint')} />
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {routes.map((r) => (
              <Card key={r.id} className="p-4">
                <div className="flex items-start justify-between gap-2">
                  <div className="font-semibold text-slate-900">{r.name}</div>
                  <Badge tone={r.difficulty === 'hard' ? 'red' : r.difficulty === 'medium' ? 'amber' : 'green'}>
                    {r.difficulty}
                  </Badge>
                </div>
                <div className="mt-1 text-sm text-slate-500">
                  {formatDistance(r.distanceMeters)}
                  {r.expectedDurationMinutes != null ? ` · ~${r.expectedDurationMinutes} min` : ''}
                </div>
                {r.startPoint && waterbody.latitude == null && (
                  <div className="mt-3">
                    <WeatherCard lat={r.startPoint.lat} lon={r.startPoint.lng} title={t('route.weatherStart')} />
                  </div>
                )}
              </Card>
            ))}
          </div>
        )}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-bold text-slate-900">{t('events.title')}</h2>
        {events.length === 0 ? (
          <EmptyState
            title={t('dashboard.noEvents')}
            hint={t('dashboard.noEventsHint')}
            action={<Link to="/events/new" className="text-sm font-semibold text-brand-600">{t('common.create')}</Link>}
          />
        ) : (
          <div className="grid gap-4 md:grid-cols-2">
            {events.map((ev) => (
              <Link key={ev.id} to={`/events/${ev.id}`}>
                <Card className="p-4">
                  <div className="flex items-start justify-between gap-2">
                    <div className="font-semibold text-slate-900">{ev.title}</div>
                    <EventStatusBadge status={ev.status} />
                  </div>
                  <div className="mt-1 text-sm text-slate-500">{formatDateTime(ev.eventDate)}</div>
                  <div className="mt-2">
                    <EventLevelBadge level={ev.level} />
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
