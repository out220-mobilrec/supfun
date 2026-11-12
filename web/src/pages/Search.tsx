import { useEffect, useState } from 'react';
import type { FormEvent, ReactNode } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { SearchResponse } from '../types';
import { Card, EmptyState, Input, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { formatDate, formatDateTime, formatDistance, formatPrice } from '../lib/format';
import { listingCategoryLabel } from '../lib/labels';
import { useT } from '../i18n';

export default function SearchPage() {
  const t = useT();
  const [params, setParams] = useSearchParams();
  const q = params.get('q') ?? '';
  const [input, setInput] = useState(q);
  const [results, setResults] = useState<SearchResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    setInput(q);
  }, [q]);

  useEffect(() => {
    if (!q.trim()) {
      setResults(null);
      return;
    }
    let mounted = true;
    setLoading(true);
    setError('');
    api
      .get<SearchResponse>(`/search?q=${encodeURIComponent(q)}&limit=15`)
      .then(({ data }) => {
        if (mounted) setResults(data);
      })
      .catch((err) => {
        if (mounted) setError(errorMessage(err));
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, [q]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    setParams(input.trim() ? { q: input.trim() } : {});
  };

  const total =
    (results?.waterbodies.length ?? 0) +
    (results?.users.length ?? 0) +
    (results?.events.length ?? 0) +
    (results?.tracks.length ?? 0) +
    (results?.listings.length ?? 0) +
    (results?.channels?.length ?? 0) +
    (results?.news?.length ?? 0);

  return (
    <div className="space-y-6">
      <PageHeader title={t('search.title')} subtitle={t('search.subtitle')} />
      <form onSubmit={submit} className="flex gap-2">
        <Input value={input} onChange={(e) => setInput(e.target.value)} placeholder={t('search.what')} autoFocus />
        <button type="submit" className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-semibold text-white hover:bg-brand-700">
          {t('search.find')}
        </button>
      </form>

      {loading && <Loading />}
      {error && <div className="text-sm text-red-600">{error}</div>}

      {!loading && results && total === 0 && <EmptyState title={t('empty.noResults')} hint={t('search.noneHint')} />}

      {!loading && results && total > 0 && (
        <div className="space-y-6">
          {results.waterbodies.length > 0 && (
            <Group title={t('waterbodies.title')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.waterbodies.map((w) => (
                  <Link key={w.id} to={`/waterbodies/${w.id}`}>
                    <Card className="p-4">
                      <div className="font-semibold text-slate-900">{w.name}</div>
                      <div className="text-sm text-slate-500">{w.region ?? t('search.regionUnknown')}</div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}

          {results.users.length > 0 && (
            <Group title={t('search.people')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.users.map((u) => (
                  <Link key={u.id} to={`/users/${u.id}`}>
                    <Card className="flex items-center gap-3 p-4">
                      <Avatar user={{ name: u.name, avatarUrl: u.avatarUrl }} />
                      <div>
                        <div className="font-semibold text-slate-900">{u.name}</div>
                        <div className="text-sm text-slate-500">{u.city ?? '—'}</div>
                      </div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}

          {results.events.length > 0 && (
            <Group title={t('events.title')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.events.map((e) => (
                  <Link key={e.id} to={`/events/${e.id}`}>
                    <Card className="p-4">
                      <div className="font-semibold text-slate-900">{e.title}</div>
                      <div className="text-sm text-slate-500">{formatDateTime(e.eventDate)}</div>
                      <div className="mt-1 text-xs text-slate-400">{t('search.organizer')}: {e.organizerName}</div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}

          {results.tracks.length > 0 && (
            <Group title={t('tracks.title')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.tracks.map((tr) => (
                  <Link key={tr.id} to="/tracks">
                    <Card className="p-4">
                      <div className="font-semibold text-slate-900">{tr.name ?? t('search.untitledRoute')}</div>
                      <div className="text-sm text-slate-500">
                        {formatDistance(tr.distanceMeters)} · {tr.userName}
                      </div>
                      <div className="mt-1 text-xs text-slate-400">{formatDate(tr.startedAt)}</div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}

          {results.listings.length > 0 && (
            <Group title={t('search.listings')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.listings.map((l) => (
                  <Link key={l.id} to={`/marketplace/${l.id}`}>
                    <Card className="p-4">
                      <div className="flex items-start justify-between gap-2">
                        <div className="font-semibold text-slate-900">{l.title}</div>
                        <div className="font-bold text-brand-700">{formatPrice(l.price, l.currency)}</div>
                      </div>
                      <div className="text-sm text-slate-500">{listingCategoryLabel(l.category)}</div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}

          {(results.channels?.length ?? 0) > 0 && (
            <Group title={t('channels.title')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.channels.map((c) => (
                  <Link key={c.id} to={`/channels/${c.id}`}>
                    <Card className="flex items-center gap-3 p-4">
                      {c.photoUrl ? (
                        <img src={c.photoUrl} alt="" className="h-10 w-10 rounded-full object-cover" />
                      ) : (
                        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-brand-50 text-brand-700">#</div>
                      )}
                      <div className="min-w-0">
                        <div className="truncate font-semibold text-slate-900">{c.name}</div>
                        <div className="truncate text-sm text-slate-500">{c.description ?? `${c.subscriberCount} ${t('search.members')}`}</div>
                      </div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}

          {(results.news?.length ?? 0) > 0 && (
            <Group title={t('news.title')}>
              <div className="grid gap-3 md:grid-cols-2">
                {results.news.map((n) => (
                  <Link key={n.id} to={`/news/${n.id}`}>
                    <Card className="p-4">
                      <div className="font-semibold text-slate-900">{n.title}</div>
                      <div className="mt-1 text-xs text-slate-400">{formatDate(n.createdAt)}</div>
                    </Card>
                  </Link>
                ))}
              </div>
            </Group>
          )}
        </div>
      )}

      {!q.trim() && <EmptyState title={t('search.enterQuery')} hint={t('search.enterHint')} />}
    </div>
  );
}

function Group({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section>
      <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{title}</h2>
      {children}
    </section>
  );
}
