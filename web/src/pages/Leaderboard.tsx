import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { RatingResponse, RatingScope } from '../types';
import { Alert, Badge, Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { countryName, useCountries } from '../lib/countries';
import { useT } from '../i18n';

export default function LeaderboardPage() {
  const t = useT();
  const navigate = useNavigate();
  const countries = useCountries();
  const [scope, setScope] = useState<RatingScope>('all');
  const [data, setData] = useState<RatingResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const scopes = useMemo<{ value: RatingScope; label: string }[]>(() => [
    { value: 'all', label: t('rating.scope.all') },
    { value: 'friends', label: t('rating.scope.friends') },
    { value: 'city', label: t('rating.scope.city') },
    { value: 'region', label: t('rating.scope.region') },
    { value: 'country', label: t('rating.scope.country') },
    { value: 'season', label: t('rating.scope.season') },
  ], [t]);

  const load = useCallback(async (s: RatingScope) => {
    setLoading(true);
    setError('');
    try {
      const { data: res } = await api.get<RatingResponse>(`/ratings/leaderboard?scope=${s}&limit=100`);
      setData(res);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load(scope);
  }, [scope, load]);

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('rating.title')}
        subtitle={data?.seasonYear ? String(data.seasonYear) : ''}
        action={<Link to="/gamification" className="text-sm font-semibold text-brand-600 hover:underline">{t('levels.title')} →</Link>}
      />
      <div className="flex flex-wrap gap-2">
        {scopes.map((s) => (
          <button
            key={s.value}
            onClick={() => setScope(s.value)}
            className={`rounded-full border px-3 py-1.5 text-sm font-medium transition ${
              scope === s.value
                ? 'border-brand-500 bg-brand-600 text-white'
                : 'border-slate-300 bg-white text-slate-600 hover:border-brand-300'
            }`}
          >
            {s.label}
          </button>
        ))}
      </div>
      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}
      {!loading && (!data || data.entries.length === 0) && (
        <EmptyState title={t('rating.empty')} hint={t('rating.emptyHint')} />
      )}
      {!loading && data && data.me && (
        <div className="flex items-center gap-3 rounded-2xl border border-brand-200 bg-brand-50/60 p-4 text-sm">
          <Avatar user={{ name: data.me.name, avatarUrl: data.me.avatarUrl }} size="sm" />
          <div>
            <span className="font-semibold text-slate-900">{t('rating.me')}: {data.me.rank}</span>
            <span className="text-slate-500"> · {data.me.xp} XP · {t('rating.lvl')} {data.me.level}</span>
          </div>
        </div>
      )}
      {!loading && data && data.entries.length > 0 && (
        <Card className="overflow-hidden">
          <div className="divide-y divide-slate-100">
            {data.entries.map((e, i) => {
              const medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : null;
              return (
                <button
                  key={e.id}
                  onClick={() => navigate(`/users/${e.id}`)}
                  className="flex w-full items-center gap-3 px-4 py-3 text-left transition hover:bg-slate-50"
                >
                  <div className="w-10 text-center text-lg font-bold text-slate-400">{medal ?? e.rank}</div>
                  <Avatar user={{ name: e.name, avatarUrl: e.avatarUrl }} size="sm" />
                  <div className="min-w-0 flex-1">
                    <div className="truncate font-semibold text-slate-900">{e.name}</div>
                    <div className="truncate text-xs text-slate-400">
                      {[e.city, e.region, countryName(countries, e.country)].filter(Boolean).join(' · ') || t('rating.geoUnknown')}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-bold text-brand-600">{e.xp} XP</div>
                    <Badge tone="slate">{t('rating.lvl')} {e.level}</Badge>
                  </div>
                </button>
              );
            })}
          </div>
        </Card>
      )}
    </div>
  );
}
