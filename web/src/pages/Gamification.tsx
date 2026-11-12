import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../lib/api';
import type { Achievement, LevelInfo } from '../types';
import { Alert, Badge, Card, Loading, PageHeader, ProgressBar, StatCard } from '../components/ui';
import { RoleBadge } from '../components/statusBadges';
import { useAuth } from '../store/AuthContext';
import { useT } from '../i18n';

interface LevelThreshold {
  level: number;
  totalXp: number;
  xpForNext: number;
}

interface Rules {
  level: {
    baseXp: number;
    growth: number;
    formula: string;
    thresholds: LevelThreshold[];
  };
  actions: { action: string; label: string; xp: string }[];
  achievements: { code: string; title: string; description: string; icon: string | null; xp: number }[];
}

export default function GamificationPage() {
  const t = useT();
  const { user } = useAuth();
  const [rules, setRules] = useState<Rules | null>(null);
  const [level, setLevel] = useState<LevelInfo | null>(null);
  const [mine, setMine] = useState<Achievement[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const [rulesRes, meRes, achRes] = await Promise.all([
          api.get<Rules>('/gamification/rules'),
          api.get<LevelInfo>('/gamification/me'),
          api.get<Achievement[]>('/gamification/achievements'),
        ]);
        if (!alive) return;
        setRules(rulesRes.data);
        setLevel(meRes.data);
        setMine(achRes.data);
      } catch (err) {
        if (alive) setError((err as Error).message ?? t('gam.loadError'));
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => {
      alive = false;
    };
  }, [t]);

  if (loading) return <Loading label={t('gam.rulesLoading')} />;
  if (!rules) return <Alert>{error || t('gam.rulesUnavailable')}</Alert>;

  const unlockedCount = mine.filter((a) => a.unlocked).length;
  const nextRow = rules.level.thresholds.find((thr) => thr.level === (level?.level ?? 1) + 1);

  return (
    <div className="space-y-6">
      <PageHeader
        title={t('nav.ratingLevels')}
        subtitle={t('levels.progress')}
        action={<Link to="/rating" className="text-sm font-semibold text-brand-600 hover:underline">{t('rating.title')} →</Link>}
      />

      {error && <Alert>{error}</Alert>}

      <div className="grid gap-4 sm:grid-cols-3">
        <StatCard label={t('gam.yourLevel')} value={level?.level ?? '—'} />
        <StatCard label={t('gam.totalXp')} value={level?.xp ?? 0} tone="violet" />
        <StatCard
          label={t('gam.achievementsUnlocked')}
          value={`${unlockedCount} ${t('gam.of')} ${rules.achievements.length}`}
          tone="amber"
        />
      </div>

      <Card className="p-5">
        <h2 className="mb-2 font-bold text-slate-900">{t('gam.howLevel')}</h2>
        <p className="text-sm text-slate-600">
          Уровень — это функция от суммарного XP. Первый уровень начинается с 0 XP. Чтобы
          перейти на следующий уровень, нужно набрать <b>{rules.level.baseXp} XP</b>, а каждый
          последующий порог больше предыдущего в <b>{rules.level.growth}×</b>.
        </p>
        <pre className="mt-3 overflow-x-auto rounded-lg bg-slate-50 p-3 text-xs text-slate-700">
{`need(1) = ${rules.level.baseXp}
need(n) = round(need(n-1) × ${rules.level.growth})
level up while remaining XP >= need(current)
progress = remaining XP / need(current)`}
        </pre>
        {level && (
          <div className="mt-4 rounded-lg border border-brand-100 bg-brand-50 p-4">
            <div className="text-sm font-semibold text-slate-800">
              {t('gam.yourCalc')}: {t('gam.yourLevel').toLowerCase()} {level.level}, {level.currentLevelXp} / {level.nextLevelXp} XP
            </div>
            <ProgressBar value={level.progress * 100} className="mt-2" />
            <div className="mt-1 text-xs text-slate-500">
              {t('gam.toLevel')} {level.level + 1} {t('gam.remaining')}{' '}
              {Math.max(0, level.nextLevelXp - level.currentLevelXp)} XP
              {nextRow ? ` (${t('gam.totalNeeded')} ${nextRow.level}: ${nextRow.totalXp} XP)` : ''}
            </div>
          </div>
        )}
      </Card>

      <Card className="p-5">
        <h2 className="mb-3 font-bold text-slate-900">{t('gam.thresholds')}</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 text-left text-xs uppercase tracking-wide text-slate-400">
                <th className="py-2 pr-4">{t('gam.threshold.level')}</th>
                <th className="py-2 pr-4">{t('gam.threshold.xpPer')}</th>
                <th className="py-2 pr-4">{t('gam.threshold.xpTotal')}</th>
                <th className="py-2">{t('gam.threshold.you')}</th>
              </tr>
            </thead>
            <tbody>
              <tr className="border-b border-slate-100">
                <td className="py-2 pr-4 font-semibold">1</td>
                <td className="py-2 pr-4 text-slate-500">—</td>
                <td className="py-2 pr-4 text-slate-500">0</td>
                <td className="py-2">
                  {level?.level === 1 && <Badge tone="brand">{t('gam.youHere')}</Badge>}
                </td>
              </tr>
              {rules.level.thresholds.map((thr) => (
                <tr
                  key={thr.level}
                  className={`border-b border-slate-100 ${
                    level?.level === thr.level ? 'bg-brand-50' : ''
                  }`}
                >
                  <td className="py-2 pr-4 font-semibold">{thr.level}</td>
                  <td className="py-2 pr-4 text-slate-600">{thr.xpForNext}</td>
                  <td className="py-2 pr-4 text-slate-600">{thr.totalXp}</td>
                  <td className="py-2">
                    {level?.level === thr.level && <Badge tone="brand">{t('gam.youHere')}</Badge>}
                    {level && level.xp >= thr.totalXp && level.level !== thr.level && (
                      <span className="text-xs text-slate-400">{t('gam.passed')}</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Card className="p-5">
        <h2 className="mb-3 font-bold text-slate-900">{t('gam.xpFor')}</h2>
        <div className="space-y-2">
          {rules.actions.map((a) => (
            <div key={a.action} className="flex items-center justify-between gap-4 text-sm">
              <span className="text-slate-700">{a.label}</span>
              <span className="shrink-0 font-bold text-brand-600">{a.xp}</span>
            </div>
          ))}
        </div>
        <p className="mt-3 text-xs text-slate-400">{t('gam.xpNote')}</p>
      </Card>

      <Card className="p-5">
        <h2 className="mb-3 font-bold text-slate-900">{t('gam.achievements')}</h2>
        <div className="space-y-3">
          {rules.achievements.map((a) => {
            const mineRow = mine.find((m) => m.code === a.code);
            return (
              <div
                key={a.code}
                className={`flex items-start gap-3 rounded-lg border p-3 ${
                  mineRow?.unlocked ? 'border-brand-200 bg-brand-50' : 'border-slate-200'
                }`}
              >
                <div className="text-2xl leading-none">{a.icon ?? '🏅'}</div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-semibold text-slate-800">{a.title}</span>
                    <code className="rounded bg-slate-100 px-1 text-[11px] text-slate-500">
                      {a.code}
                    </code>
                    {mineRow?.unlocked && <Badge tone="green">{t('gam.unlocked')}</Badge>}
                  </div>
                  <div className="text-xs text-slate-500">{a.description}</div>
                </div>
                <div className="shrink-0 text-sm font-bold text-brand-600">+{a.xp} XP</div>
              </div>
            );
          })}
        </div>
      </Card>

      <Card className="p-5">
        <h2 className="mb-3 font-bold text-slate-900">{t('gam.badges')}</h2>
        <div className="space-y-3 text-sm">
          <div className="flex items-start gap-3">
            <div className="w-24 shrink-0 text-3xl font-extrabold text-slate-900">
              {level?.level ?? 7}
            </div>
            <div className="text-slate-600">
              <b>Число в карточке «Уровень»</b> — текущий уровень. Рядом показан прогресс до следующего уровня и суммарный XP.
            </div>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-24 shrink-0">
              {user ? <RoleBadge role={user.role} /> : <Badge>—</Badge>}
            </div>
            <div className="text-slate-600">
              <b>Бейдж роли</b> — права в системе (участник, гид, модератор, админ). На уровень не влияет.
            </div>
          </div>
          <div className="flex items-start gap-3">
            <div className="w-24 shrink-0 text-2xl">🏄📏🏅</div>
            <div className="text-slate-600">
              <b>Иконки достижений</b> — открытые показаны полностью, не полученные затемнены.
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}
