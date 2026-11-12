import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { SearchResponse } from '../types';
import { Card, EmptyState, Input, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { useT } from '../i18n';

export default function UsersPage() {
  const t = useT();
  const [q, setQ] = useState('');
  const [users, setUsers] = useState<SearchResponse['users']>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const needle = q.trim();
    if (!needle) {
      setUsers([]);
      return;
    }
    let mounted = true;
    setLoading(true);
    const timer = setTimeout(() => {
      api
        .get<SearchResponse>(`/search?q=${encodeURIComponent(needle)}&limit=25`)
        .then(({ data }) => {
          if (mounted) setUsers(data.users);
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
  }, [q]);

  return (
    <div className="space-y-5">
      <PageHeader title={t('users.title')} subtitle={t('users.subtitle')} />
      <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('users.placeholder')} className="max-w-md" autoFocus />
      {error && <div className="text-sm text-red-600">{error}</div>}
      {loading && <Loading />}
      {!loading && q.trim() && users.length === 0 && <EmptyState title={t('users.none')} hint={t('users.noneHint')} />}
      {!q.trim() && <EmptyState title={t('users.enterName')} hint={t('users.enterHint')} />}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {users.map((u) => (
          <Link key={u.id} to={`/users/${u.id}`}>
            <Card className="flex items-center gap-3 p-4">
              <Avatar user={{ name: u.name, avatarUrl: u.avatarUrl }} size="lg" />
              <div className="min-w-0">
                <div className="truncate font-semibold text-slate-900">{u.name}</div>
                <div className="text-sm text-slate-500">{u.city ?? t('users.cityUnknown')}</div>
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
