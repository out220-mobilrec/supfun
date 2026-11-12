import { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Listing } from '../types';
import { LISTING_CATEGORIES } from '../lib/lists';
import { Button, Card, EmptyState, Input, Loading, PageHeader, Select } from '../components/ui';
import { ListingStatusBadge } from '../components/statusBadges';
import { formatPrice, relativeTime } from '../lib/format';
import { listingCategoryLabel } from '../lib/labels';
import { useT } from '../i18n';

export default function MarketplacePage() {
  const t = useT();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const category = params.get('category') ?? '';
  const q = params.get('q') ?? '';
  const city = params.get('city') ?? '';
  const sort = params.get('sort') ?? '';
  const [input, setInput] = useState(q);
  const [cityInput, setCityInput] = useState(city);
  const [items, setItems] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    setInput(q);
  }, [q]);

  useEffect(() => {
    setCityInput(city);
  }, [city]);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    setError('');
    const query = new URLSearchParams();
    if (category) query.set('category', category);
    if (q) query.set('q', q);
    if (city) query.set('city', city);
    if (sort) query.set('sort', sort);
    api
      .get<Listing[]>(`/marketplace/listings?${query.toString()}`)
      .then(({ data }) => {
        if (mounted) setItems(data);
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
  }, [category, q, city, sort]);

  const setParam = (key: string, value: string) => {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    setParams(next);
  };

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('marketplace.title')}
        subtitle={t('marketplace.catalog')}
        action={<Button onClick={() => navigate('/marketplace/new')}>+ {t('action.createNew')}</Button>}
      />
      <div className="flex flex-wrap gap-2">
        <Link to="/marketplace/my" className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:border-brand-300 hover:text-brand-700">{t('nav.myListings')}</Link>
        <Link to="/marketplace/leads" className="rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:border-brand-300 hover:text-brand-700">{t('nav.myLeads')}</Link>
      </div>

      <div className="flex flex-wrap gap-3">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setParam('q', input.trim());
          }}
          className="flex-1 min-w-[220px]"
        >
          <Input value={input} onChange={(e) => setInput(e.target.value)} placeholder={t('marketplace.search')} />
        </form>
        <Select value={category} onChange={(e) => setParam('category', e.target.value)} className="max-w-[220px]">
          <option value="">{t('marketplace.allCategories')}</option>
          {LISTING_CATEGORIES.map((c) => (
            <option key={c} value={c}>
              {listingCategoryLabel(c)}
            </option>
          ))}
        </Select>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setParam('city', cityInput.trim());
          }}
          className="max-w-[180px]"
        >
          <Input value={cityInput} onChange={(e) => setCityInput(e.target.value)} placeholder={t('marketplace.city')} />
        </form>
        <Select value={sort} onChange={(e) => setParam('sort', e.target.value)} className="max-w-[200px]">
          <option value="">{t('marketplace.sortNew')}</option>
          <option value="price_asc">{t('marketplace.sortPriceAsc')}</option>
          <option value="price_desc">{t('marketplace.sortPriceDesc')}</option>
        </Select>
      </div>

      {loading && <Loading />}
      {error && <div className="text-sm text-red-600">{error}</div>}

      {!loading && items.length === 0 && <EmptyState title={t('marketplace.notFound')} hint={t('marketplace.notFoundHint')} />}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {items.map((l) => (
          <Card key={l.id} className="overflow-hidden" onClick={() => navigate(`/marketplace/${l.id}`)}>
            <div className="aspect-[4/3] w-full bg-slate-100">
              {l.photos?.[0] ? (
                <img src={l.photos[0]} alt={l.title} className="h-full w-full object-cover" loading="lazy" />
              ) : (
                <div className="flex h-full items-center justify-center text-3xl text-slate-300">🏄</div>
              )}
            </div>
            <div className="p-4">
              <div className="flex items-start justify-between gap-2">
                <div className="font-semibold text-slate-900">{l.title}</div>
                <ListingStatusBadge status={l.status} />
              </div>
              <div className="mt-1 text-sm text-slate-500">
                {listingCategoryLabel(l.category)} {l.city ? `· ${l.city}` : ''}
              </div>
              <div className="mt-2 flex items-center justify-between">
                <span className="font-bold text-brand-700">{formatPrice(l.price, l.currency)}</span>
                <span className="text-xs text-slate-400">{relativeTime(l.createdAt)}</span>
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}
