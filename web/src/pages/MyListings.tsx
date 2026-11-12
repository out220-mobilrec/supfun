import { useCallback, useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Listing } from '../types';
import { LISTING_STATUSES, type ListingStatus } from '../lib/lists';
import { Alert, Button, Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { ListingStatusBadge } from '../components/statusBadges';
import { formatPrice, relativeTime } from '../lib/format';
import { listingCategoryLabel, listingStatusLabel } from '../lib/labels';
import { useT } from '../i18n';

export default function MyListingsPage() {
  const t = useT();
  const navigate = useNavigate();
  const [items, setItems] = useState<Listing[]>([]);
  const [filter, setFilter] = useState<ListingStatus | 'all'>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const { data } = await api.get<Listing[]>('/marketplace/listings/mine');
      setItems(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const togglePublish = async (l: Listing) => {
    try {
      if (l.status === 'active') await api.delete(`/marketplace/listings/${l.id}`);
      else await api.post(`/marketplace/listings/${l.id}/publish`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const remove = async (id: string) => {
    if (!window.confirm(t('myListings.removeConfirm'))) return;
    try {
      await api.delete(`/marketplace/listings/${id}`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const visible = filter === 'all' ? items : items.filter((i) => i.status === filter);

  return (
    <div>
      <PageHeader
        title={t('nav.myListings')}
        subtitle={t('myListings.subtitle')}
        action={<Button onClick={() => navigate('/marketplace/new')}>{t('myListings.new')}</Button>}
      />

      <div className="mb-4 flex flex-wrap gap-2">
        <FilterPill active={filter === 'all'} onClick={() => setFilter('all')}>
          {t('common.all')}
        </FilterPill>
        {LISTING_STATUSES.map((s) => (
          <FilterPill key={s} active={filter === s} onClick={() => setFilter(s)}>
            {listingStatusLabel(s)}
          </FilterPill>
        ))}
      </div>

      {error && <div className="mb-4"><Alert>{error}</Alert></div>}
      {loading ? (
        <Loading />
      ) : visible.length === 0 ? (
        <EmptyState
          title={t('myListings.none')}
          hint={t('myListings.noneHint')}
          action={<Button onClick={() => navigate('/marketplace/new')}>{t('myListings.createAction')}</Button>}
        />
      ) : (
        <div className="space-y-3">
          {visible.map((l) => (
            <Card key={l.id} className="flex flex-wrap items-center gap-4 p-4">
              <button
                onClick={() => navigate(`/marketplace/${l.id}`)}
                className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-slate-100"
              >
                {l.photos?.[0] ? (
                  <img src={l.photos[0]} alt="" className="h-full w-full object-cover" />
                ) : (
                  <span className="text-2xl">🏄</span>
                )}
              </button>
              <div className="min-w-0 flex-1">
                <button onClick={() => navigate(`/marketplace/${l.id}`)} className="font-semibold text-slate-900 hover:underline">
                  {l.title}
                </button>
                <div className="mt-0.5 text-sm text-slate-500">
                  {listingCategoryLabel(l.category)} · {formatPrice(l.price, l.currency)} · {relativeTime(l.createdAt)}
                </div>
                {l.status === 'moderation' && (
                  <div className="mt-1 text-xs font-medium text-amber-700">{t('myListings.onModeration')}</div>
                )}
                {l.moderationComment && (
                  <div className="mt-1 text-xs text-red-600">{t('myListings.modComment')}: {l.moderationComment}</div>
                )}
              </div>
              <ListingStatusBadge status={l.status} />
              <div className="flex gap-2">
                <Button size="sm" tone="outline" onClick={() => navigate(`/marketplace/${l.id}/edit`)}>
                  {t('common.edit')}
                </Button>
                <Button size="sm" tone={l.status === 'active' ? 'red' : 'green'} onClick={() => togglePublish(l)}>
                  {l.status === 'active' ? t('action.hide') : t('common.publish')}
                </Button>
                <Button size="sm" tone="outline" onClick={() => remove(l.id)}>
                  {t('common.delete')}
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

function FilterPill({ active, onClick, children }: { active: boolean; onClick: () => void; children: ReactNode }) {
  return (
    <button
      onClick={onClick}
      className={`rounded-full px-3 py-1.5 text-sm font-medium ${active ? 'bg-brand-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}
    >
      {children}
    </button>
  );
}
