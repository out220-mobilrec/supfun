import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { FriendRequest, User } from '../types';
import { Alert, Button, Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { relativeTime } from '../lib/format';
import { useT } from '../i18n';

type Tab = 'friends' | 'incoming' | 'outgoing';

export default function FriendsPage() {
  const t = useT();
  const [tab, setTab] = useState<Tab>('friends');
  const [friends, setFriends] = useState<User[]>([]);
  const [incoming, setIncoming] = useState<FriendRequest[]>([]);
  const [outgoing, setOutgoing] = useState<FriendRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const [f, i, o] = await Promise.all([
        api.get<User[]>('/friends'),
        api.get<FriendRequest[]>('/friends/requests/incoming'),
        api.get<FriendRequest[]>('/friends/requests/outgoing'),
      ]);
      setFriends(f.data);
      setIncoming(i.data);
      setOutgoing(o.data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const act = async (fn: () => Promise<unknown>) => {
    try {
      await fn();
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const tabs: [Tab, string, number][] = [
    ['friends', t('friends.tab.friends'), friends.length],
    ['incoming', t('friends.tab.incoming'), incoming.length],
    ['outgoing', t('friends.tab.outgoing'), outgoing.length],
  ];

  return (
    <div className="space-y-5">
      <PageHeader title={t('friends.title')} subtitle={t('friends.subtitle')} />

      <div className="flex flex-wrap gap-2">
        {tabs.map(([value, label, count]) => (
          <button
            key={value}
            onClick={() => setTab(value)}
            className={`rounded-full border px-3 py-1 text-sm font-medium transition ${
              tab === value ? 'border-brand-500 bg-brand-50 text-brand-700' : 'border-slate-200 text-slate-600 hover:bg-slate-50'
            }`}
          >
            {label} {count > 0 && <span className="text-slate-400">({count})</span>}
          </button>
        ))}
      </div>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && tab === 'friends' && (
        friends.length === 0 ? (
          <EmptyState title={t('friends.empty')} hint={t('friends.emptyHint')} action={<Link to="/users" className="text-sm font-semibold text-brand-600">{t('friends.findPeople')}</Link>} />
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {friends.map((f) => (
              <Card key={f.id} className="flex items-center gap-3 p-4">
                <Avatar user={f} size="lg" />
                <div className="min-w-0 flex-1">
                  <Link to={`/users/${f.id}`} className="block truncate font-semibold text-slate-900 hover:text-brand-700">
                    {f.name}
                  </Link>
                  <div className="text-sm text-slate-500">{f.city ?? '—'}</div>
                </div>
                <Button size="sm" tone="outline" onClick={() => act(() => api.delete(`/friends/${f.id}`))}>
                  {t('common.delete')}
                </Button>
              </Card>
            ))}
          </div>
        )
      )}

      {!loading && tab === 'incoming' && (
        incoming.length === 0 ? (
          <EmptyState title={t('friends.noIncoming')} />
        ) : (
          <div className="space-y-3">
            {incoming.map((r) => (
              <Card key={r.id} className="flex flex-wrap items-center gap-3 p-4">
                <Avatar user={r.requester} size="lg" />
                <div className="min-w-0 flex-1">
                  <Link to={`/users/${r.requesterId}`} className="font-semibold text-slate-900 hover:text-brand-700">
                    {r.requester?.name}
                  </Link>
                  <div className="text-sm text-slate-500">{relativeTime(r.createdAt)}</div>
                </div>
                <Button size="sm" tone="green" onClick={() => act(() => api.post(`/friends/requests/${r.id}/accept`))}>
                  {t('friends.accept')}
                </Button>
                <Button size="sm" tone="outline" onClick={() => act(() => api.post(`/friends/requests/${r.id}/reject`))}>
                  {t('friends.reject')}
                </Button>
              </Card>
            ))}
          </div>
        )
      )}

      {!loading && tab === 'outgoing' && (
        outgoing.length === 0 ? (
          <EmptyState title={t('friends.noOutgoing')} />
        ) : (
          <div className="space-y-3">
            {outgoing.map((r) => (
              <Card key={r.id} className="flex flex-wrap items-center gap-3 p-4">
                <Avatar user={r.addressee} size="lg" />
                <div className="min-w-0 flex-1">
                  <Link to={`/users/${r.addresseeId}`} className="font-semibold text-slate-900 hover:text-brand-700">
                    {r.addressee?.name}
                  </Link>
                  <div className="text-sm text-slate-500">{t('friends.requestSent')} {relativeTime(r.createdAt)}</div>
                </div>
                <Button size="sm" tone="outline" onClick={() => act(() => api.delete(`/friends/requests/${r.id}`))}>
                  {t('common.cancel')}
                </Button>
              </Card>
            ))}
          </div>
        )
      )}
    </div>
  );
}
