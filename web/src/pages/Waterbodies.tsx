import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { WaterBody } from '../types';
import { Badge, Button, Card, EmptyState, Input, Loading, PageHeader } from '../components/ui';
import { useT } from '../i18n';

export default function WaterbodiesPage() {
  const navigate = useNavigate();
  const t = useT();
  const [items, setItems] = useState<WaterBody[]>([]);
  const [q, setQ] = useState('');
  const [farEast, setFarEast] = useState(false);
  const [region, setRegion] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let mounted = true;
    const timer = setTimeout(() => {
      setLoading(true);
      const params = new URLSearchParams();
      if (q.trim()) params.set('q', q.trim());
      if (farEast) params.set('farEast', 'true');
      if (region) params.set('region', region);
      const qs = params.toString();
      api
        .get<WaterBody[]>(`/waterbodies${qs ? `?${qs}` : ''}`)
        .then(({ data }) => {
          if (mounted) setItems(data);
        })
        .catch((err) => {
          if (mounted) setError(errorMessage(err));
        })
        .finally(() => {
          if (mounted) setLoading(false);
        });
    }, 300);
    return () => {
      mounted = false;
      clearTimeout(timer);
    };
  }, [q, farEast, region]);

  const regions = useMemo(() => {
    const set = new Set<string>();
    for (const w of items) if (w.region) set.add(w.region);
    return Array.from(set).sort((a, b) => a.localeCompare(b, 'ru'));
  }, [items]);

  return (
    <div className="space-y-5">
      <PageHeader title={t('waterbodies.title')} subtitle={t('nav.waterbodies')} />
      <div className="flex flex-wrap items-center gap-3">
        <Input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder={t('waterbodies.search')}
          className="max-w-md"
        />
        <Button
          size="sm"
          tone={farEast ? 'brand' : 'outline'}
          onClick={() => setFarEast((v) => !v)}
        >
          {t('waterbodies.farEast')}
        </Button>
        {regions.length > 1 && (
          <select
            value={region}
            onChange={(e) => setRegion(e.target.value)}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm"
          >
            <option value="">{t('waterbodies.allRegions')}</option>
            {regions.map((r) => (
              <option key={r} value={r}>{r}</option>
            ))}
          </select>
        )}
      </div>
      {error && <div className="text-sm text-red-600">{error}</div>}
      {loading ? (
        <Loading />
      ) : items.length === 0 ? (
        <EmptyState title={t('waterbodies.empty')} hint={t('waterbodies.emptyHint')} />
      ) : (
        <div className="grid gap-4 md:grid-cols-3">
          {items.map((w) => (
            <Card key={w.id} className="p-4" onClick={() => navigate(`/waterbodies/${w.id}`)}>
              <div className="flex items-start justify-between gap-2">
                <div className="font-bold text-slate-900">{w.name}</div>
                {!w.active && <Badge tone="red">{t('waterbodies.inactive')}</Badge>}
              </div>
              <div className="mt-1 text-sm text-slate-500">{w.region ?? t('waterbodies.regionUnknown')}</div>
              {w.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{w.description}</p>}
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
