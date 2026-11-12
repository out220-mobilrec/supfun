import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../../lib/api';
import type { AdminStats } from '../../types';
import { Alert, Card, Loading, StatCard } from '../../components/ui';
import { Avatar } from '../../components/Avatar';
import { RoleBadge } from '../../components/statusBadges';
import { formatDate } from '../../lib/format';
import { AdminHeader } from './shared';
import { useT } from '../../i18n';

export default function AdminDashboard() {
  const t = useT();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let mounted = true;
    api
      .get<AdminStats>('/admin/stats')
      .then(({ data }) => {
        if (mounted) setStats(data);
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
  }, []);

  if (loading) return <Loading />;
  if (!stats) return <Alert>{error || t('admin.loadError')}</Alert>;

  return (
    <div className="space-y-6">
      <AdminHeader title={t('admin.panel')} subtitle={t('admin.summary')} />
      {error && <Alert>{error}</Alert>}

      <section>
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.users')}</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label={t('admin.total')} value={stats.users.total} />
          <StatCard label={t('admin.banned')} value={stats.users.banned} tone="red" />
          <StatCard label={t('admin.admins')} value={stats.users.admins} tone="violet" />
          <StatCard label={t('admin.moderators')} value={stats.users.moderators} tone="blue" />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.events')}</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <StatCard label={t('admin.total')} value={stats.events.total} />
          <StatCard label={t('admin.scheduled')} value={stats.events.scheduled} tone="green" />
          <StatCard label={t('admin.onWater')} value={stats.events.onWater} tone="blue" />
          <StatCard label={t('admin.completed')} value={stats.events.completed} tone="slate" />
          <StatCard label={t('admin.cancelled')} value={stats.events.cancelled} tone="red" />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.marketplace')}</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label={t('admin.listings')} value={stats.listings.total} />
          <StatCard label={t('admin.active')} value={stats.listings.active} tone="green" />
          <StatCard label={t('admin.sold')} value={stats.listings.completed} tone="blue" />
          <StatCard label={t('admin.leadsNew')} value={`${stats.leads.total} (${stats.leads.new})`} tone="amber" />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.routesWater')}</h2>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard label={t('admin.tracks')} value={stats.tracks.total} />
          <StatCard label={t('admin.published')} value={stats.tracks.published} tone="green" />
          <StatCard label={t('admin.onModeration')} value={stats.tracks.moderation} tone="amber" />
          <StatCard label={t('admin.waterbodiesActive')} value={`${stats.waterbodies.total} (${stats.waterbodies.active})`} tone="cyan" />
        </div>
      </section>

      <section>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-sm font-bold uppercase tracking-wide text-slate-500">{t('admin.newUsers')}</h2>
          <Link to="/admin/users" className="text-sm font-semibold text-brand-600">
            {t('admin.allUsers')} →
          </Link>
        </div>
        <Card className="divide-y divide-slate-100">
          {stats.recentUsers.map((u) => (
            <div key={u.id} className="flex items-center gap-3 p-3">
              <Avatar user={u} size="sm" />
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium text-slate-800">{u.name}</div>
                <div className="truncate text-xs text-slate-400">{u.email}</div>
              </div>
              <RoleBadge role={u.role} />
              <span className="text-xs text-slate-400">{formatDate(u.createdAt)}</span>
            </div>
          ))}
          {stats.recentUsers.length === 0 && <div className="p-4 text-sm text-slate-400">{t('admin.noData')}</div>}
        </Card>
      </section>
    </div>
  );
}
