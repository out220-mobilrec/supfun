import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { useSocketEvent } from '../store/SocketContext';
import type { Notification } from '../types';
import { Alert, Button, Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { notificationTypeLabel } from '../lib/labels';
import { relativeTime } from '../lib/format';
import { useT } from '../i18n';

const typeIcon: Record<string, string> = {
  message: '💬',
  friend_request: '🤝',
  friend_accepted: '✅',
  achievement: '🏆',
  event_invite: '📣',
  event_joined: '🏄',
  event_reminder: '⏰',
  system: '🔔',
};

export default function NotificationsPage() {
  const t = useT();
  const navigate = useNavigate();
  const [items, setItems] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setError('');
    try {
      const { data } = await api.get<Notification[]>('/notifications?limit=50');
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

  useSocketEvent('notify:new', () => {
    void load();
  });

  const openNotification = async (n: Notification) => {
    if (!n.isRead) {
      try {
        await api.post('/notifications/read', { id: n.id });
        setItems((prev) => prev.map((x) => (x.id === n.id ? { ...x, isRead: true } : x)));
      } catch {
        /* ignore */
      }
    }
    const data = (n.data ?? {}) as Record<string, string | undefined>;
    if (data.conversationId) navigate(`/chats/${data.conversationId}`);
    else if (data.eventId) navigate(`/events/${data.eventId}`);
    else if (data.listingId) navigate(`/marketplace/${data.listingId}`);
    else if (data.userId) navigate(`/users/${data.userId}`);
  };

  const markAll = async () => {
    try {
      await api.post('/notifications/read', {});
      setItems((prev) => prev.map((x) => ({ ...x, isRead: true })));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const remove = async (id: string) => {
    try {
      await api.delete(`/notifications/${id}`);
      setItems((prev) => prev.filter((x) => x.id !== id));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const unread = items.filter((n) => !n.isRead).length;

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('notifications.title')}
        subtitle={unread > 0 ? `${unread} ${t('notifications.unread')}` : t('notifications.allRead')}
        action={
          items.length > 0 && unread > 0 ? (
            <Button tone="outline" onClick={markAll}>
              {t('notifications.markAll')}
            </Button>
          ) : undefined
        }
      />

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}
      {!loading && items.length === 0 && <EmptyState title={t('notifications.empty')} hint={t('notifications.emptyHint')} />}

      <div className="space-y-2">
        {items.map((n) => (
          <Card key={n.id} className={`flex items-start gap-3 p-4 ${n.isRead ? '' : 'border-brand-200 bg-brand-50/40'}`}>
            <div className="text-2xl">{typeIcon[n.type] ?? '🔔'}</div>
            <button className="min-w-0 flex-1 text-left" onClick={() => openNotification(n)}>
              <div className="flex items-center gap-2">
                <span className="font-semibold text-slate-900">{n.title}</span>
                <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-medium text-slate-500">
                  {notificationTypeLabel(n.type)}
                </span>
                {!n.isRead && <span className="h-2 w-2 rounded-full bg-brand-500" />}
              </div>
              {n.body && <p className="mt-0.5 text-sm text-slate-600">{n.body}</p>}
              <div className="mt-1 text-xs text-slate-400">{relativeTime(n.createdAt)}</div>
            </button>
            <button onClick={() => remove(n.id)} className="text-slate-300 hover:text-red-500" aria-label={t('common.delete')}>
              <svg className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </Card>
        ))}
      </div>
    </div>
  );
}
