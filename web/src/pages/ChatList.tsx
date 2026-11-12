import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import { useSocketEvent, useSocket } from '../store/SocketContext';
import type { ChatNewEvent, ConversationSummary } from '../types';
import { Card, EmptyState, Loading, PageHeader } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { relativeTime } from '../lib/format';
import { useT } from '../i18n';

function conversationTitle(c: ConversationSummary, meId: string | undefined, t: (k: string) => string): { name: string; avatarUser: ConversationSummary['participants'][number]['user'] | null } {
  if (c.type === 'direct') {
    const other = c.participants.find((p) => p.userId !== meId);
    return { name: other?.user?.name ?? t('chat.direct'), avatarUser: other?.user ?? null };
  }
  const first = c.participants[0]?.user ?? null;
  return { name: c.title ?? (c.type === 'event' ? t('chat.eventChat') : t('chat.group')), avatarUser: first };
}

export default function ChatListPage() {
  const t = useT();
  const navigate = useNavigate();
  const { user } = useAuth();
  const { onlineUsers } = useSocket();
  const [items, setItems] = useState<ConversationSummary[]>([]);
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    try {
      const { data } = await api.get<ConversationSummary[]>('/conversations');
      setItems(data);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  useSocketEvent<ChatNewEvent>('chat:new', () => {
    void load();
  });

  if (loading) return <Loading />;

  return (
    <div>
      <PageHeader title={t('nav.chats')} subtitle={t('chat.listSubtitle')} />
      {items.length === 0 ? (
        <EmptyState title={t('chats.empty')} hint={t('chat.listEmptyHint')} />
      ) : (
        <Card className="divide-y divide-slate-100 overflow-hidden p-0">
          {items.map((c) => {
            const { name, avatarUser } = conversationTitle(c, user?.id, t);
            const otherOnline =
              c.type === 'direct' &&
              c.participants.some((p) => p.userId !== user?.id && Boolean((onlineUsers as Record<string, boolean>)[p.userId]));
            return (
              <button
                key={c.id}
                onClick={() => navigate(`/chats/${c.id}`)}
                className="flex w-full items-center gap-3 px-4 py-3 text-left hover:bg-slate-50"
              >
                <div className="relative">
                  <Avatar user={avatarUser} size="md" />
                  {otherOnline && (
                    <span className="absolute -bottom-0.5 -right-0.5 h-3 w-3 rounded-full border-2 border-white bg-green-500" />
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <span className="truncate font-semibold text-slate-900">{name}</span>
                    {c.lastMessage && (
                      <span className="shrink-0 text-xs text-slate-400">{relativeTime(c.lastMessage.createdAt)}</span>
                    )}
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="truncate text-sm text-slate-500">
                      {c.lastMessage?.content ?? t('chat.noMessages')}
                    </span>
                    {c.unreadCount > 0 && (
                      <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-brand-600 px-1.5 text-[10px] font-bold text-white">
                        {c.unreadCount}
                      </span>
                    )}
                  </div>
                </div>
              </button>
            );
          })}
        </Card>
      )}
    </div>
  );
}
