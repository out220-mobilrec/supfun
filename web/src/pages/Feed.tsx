import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { FeedResponse } from '../types';
import { Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { PostList } from '../components/PostList';
import { Avatar } from '../components/Avatar';
import { formatDateTime, formatDistance, formatDuration, formatPrice, relativeTime } from '../lib/format';
import { listingCategoryLabel } from '../lib/labels';
import { useT } from '../i18n';

export default function FeedPage() {
  const t = useT();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const focusPost = params.get('post') ?? undefined;
  const [feed, setFeed] = useState<FeedResponse | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    (async () => {
      try {
        const { data } = await api.get<FeedResponse>('/feed?limit=30');
        setFeed(data);
      } catch (err) {
        setError(errorMessage(err));
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  if (loading) return <Loading />;

  return (
    <div className="space-y-8">
      <PageHeader title={t('feed.title')} subtitle={t('feed.subtitle')} />
      {error && <div className="text-sm text-red-600">{error}</div>}

      <PostList title={t('feed.posts')} initialPostId={focusPost} />

      <section>
        <h2 className="mb-3 text-lg font-bold text-slate-900">🗓 {t('feed.events')}</h2>
        {feed?.events.length ? (
          <div className="grid gap-4 md:grid-cols-2">
            {feed.events.map((ev) => (
              <Card key={ev.id} className="p-4" onClick={() => navigate(`/events/${ev.id}`)}>
                <div className="font-bold text-slate-900">{ev.title}</div>
                <div className="mt-1 text-sm text-slate-500">
                  {ev.waterBodyName ?? t('dashboard.noWaterbody')} · {formatDateTime(ev.eventDate)}
                </div>
                {ev.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{ev.description}</p>}
                <div className="mt-3 flex items-center gap-2 text-sm text-slate-500">
                  <Avatar user={{ name: ev.organizerName, avatarUrl: null }} size="sm" />
                  {ev.organizerName}
                </div>
              </Card>
            ))}
          </div>
        ) : (
          <EmptyState title={t('feed.noEvents')} />
        )}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-bold text-slate-900">🧭 {t('feed.routes')}</h2>
        {feed?.routes.length ? (
          <div className="grid gap-4 md:grid-cols-3">
            {feed.routes.map((r) => (
              <Card key={r.id} className="p-4" onClick={() => navigate('/tracks')}>
                <div className="font-semibold text-slate-900">{r.name ?? t('feed.untitledRoute')}</div>
                <div className="mt-2 flex gap-4 text-sm text-slate-500">
                  <span>{formatDistance(r.distance_meters)}</span>
                  <span>{formatDuration(r.durationSeconds)}</span>
                </div>
              </Card>
            ))}
          </div>
        ) : (
          <EmptyState title={t('feed.noRoutes')} />
        )}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-bold text-slate-900">🛰 {t('feed.marketplace')}</h2>
        {feed?.listings.length ? (
          <div className="grid gap-4 md:grid-cols-3">
            {feed.listings.map((l) => (
              <Card key={l.id} className="p-4" onClick={() => navigate(`/marketplace/${l.id}`)}>
                <div className="font-semibold text-slate-900">{l.title}</div>
                <div className="mt-1 text-sm text-slate-500">{listingCategoryLabel(l.category)}</div>
                <div className="mt-2 font-bold text-brand-700">{formatPrice(l.price, l.currency)}</div>
                <div className="mt-1 text-xs text-slate-400">{relativeTime(l.createdAt)}</div>
              </Card>
            ))}
          </div>
        ) : (
          <EmptyState title={t('feed.noListings')} />
        )}
      </section>
    </div>
  );
}
