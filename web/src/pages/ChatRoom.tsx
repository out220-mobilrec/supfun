import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { ChangeEvent, FormEvent } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api, errorMessage, uploadImage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import { useSocket, useSocketEvent } from '../store/SocketContext';
import type { ChatNewEvent, ChatStatusEvent, ChatTypingEvent, Conversation, Message } from '../types';
import { Alert, Button, Card, Loading, Spinner } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { formatTime } from '../lib/format';
import { useT } from '../i18n';

export default function ChatRoomPage() {
  const t = useT();
  const { id } = useParams();
  const { user } = useAuth();
  const { socket, connected } = useSocket();
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [messages, setMessages] = useState<Message[]>([]);
  const [text, setText] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);
  const [typingUsers, setTypingUsers] = useState<Record<string, boolean>>({});
  const bottomRef = useRef<HTMLDivElement | null>(null);
  const typingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!id) return;
    let mounted = true;
    setLoading(true);
    (async () => {
      try {
        const [convRes, msgRes] = await Promise.all([
          api.get<Conversation>(`/conversations/${id}`),
          api.get<Message[]>(`/conversations/${id}/messages?limit=50`),
        ]);
        if (!mounted) return;
        setConversation(convRes.data);
        setMessages(msgRes.data);
        void api.post(`/conversations/${id}/read`).catch(() => undefined);
      } catch (err) {
        if (mounted) setError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [id]);

  useEffect(() => {
    if (!socket || !id) return;
    socket.emit('conversation:join', { conversationId: id });
    return () => {
      socket.emit('conversation:leave', { conversationId: id });
    };
  }, [socket, id]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  useSocketEvent<ChatNewEvent>('chat:new', (payload) => {
    if (payload.conversationId !== id) return;
    setMessages((prev) => (prev.some((m) => m.id === payload.message.id) ? prev : [...prev, payload.message]));
    setTypingUsers((prev) => ({ ...prev, [payload.message.senderId]: false }));
    void api.post(`/conversations/${id}/read`).catch(() => undefined);
  });

  useSocketEvent<ChatStatusEvent>('chat:status', (payload) => {
    if (payload.conversationId !== id) return;
    if (!payload.messageId) return;
    setMessages((prev) => prev.map((m) => (m.id === payload.messageId ? { ...m, status: payload.status } : m)));
  });

  useSocketEvent<ChatTypingEvent>('chat:typing', (payload) => {
    if (payload.conversationId !== id || payload.userId === user?.id) return;
    setTypingUsers((prev) => ({ ...prev, [payload.userId]: payload.isTyping }));
  });

  const title = useMemo(() => {
    if (!conversation) return t('chat.title');
    if (conversation.type === 'direct') {
      const other = conversation.participants.find((p) => p.userId !== user?.id);
      return other?.user?.name ?? t('chat.direct');
    }
    return conversation.title ?? (conversation.type === 'event' ? t('chat.eventChat') : t('chat.group'));
  }, [conversation, user?.id, t]);

  const applyMessage = useCallback((m: Message) => {
    setMessages((prev) => (prev.some((x) => x.id === m.id) ? prev : [...prev, m]));
  }, []);

  const sendPayload = useCallback(
    async (message: Record<string, unknown>) => {
      if (!id) return;
      setError('');
      if (socket && connected) {
        socket.emit(
          'chat:send',
          { conversationId: id, message },
          (res: { ok: boolean; message?: Message; error?: string }) => {
            if (res?.ok && res.message) applyMessage(res.message);
            else if (res?.error) setError(res.error);
          },
        );
      } else {
        const { data } = await api.post<Message>(`/conversations/${id}/messages`, message);
        applyMessage(data);
      }
    },
    [id, socket, connected, applyMessage],
  );

  const send = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();
      const content = text.trim();
      if (!content || !id) return;
      setText('');
      try {
        await sendPayload({ type: 'text', content });
      } catch (err) {
        setError(errorMessage(err));
      }
    },
    [text, id, sendPayload],
  );

  const onPickPhoto = () => fileInputRef.current?.click();

  const onPhotoChange = async (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    setSending(true);
    setError('');
    try {
      const url = await uploadImage(file);
      await sendPayload({ type: 'photo', content: url });
    } catch (err) {
      setError(errorMessage(err, t('chat.photoSendError')));
    } finally {
      setSending(false);
    }
  };

  const sendLocation = async () => {
    if (!navigator.geolocation) {
      setError(t('chat.locationUnavailable'));
      return;
    }
    setSending(true);
    setError('');
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          await sendPayload({
            type: 'location',
            latitude: pos.coords.latitude,
            longitude: pos.coords.longitude,
            content: t('chat.locationLabel'),
          });
        } catch (err) {
          setError(errorMessage(err, t('chat.locationSendError')));
        } finally {
          setSending(false);
        }
      },
      (err) => {
        setSending(false);
        setError(err.message || t('chat.locationDetectError'));
      },
      { enableHighAccuracy: true, timeout: 10000 },
    );
  };

  const onType = (value: string) => {
    setText(value);
    if (!socket || !id) return;
    socket.emit('chat:typing', { conversationId: id, isTyping: true });
    if (typingTimer.current) clearTimeout(typingTimer.current);
    typingTimer.current = setTimeout(() => {
      socket.emit('chat:typing', { conversationId: id, isTyping: false });
    }, 1500);
  };

  const typingNames = Object.entries(typingUsers)
    .filter(([uid, active]) => active && uid !== user?.id)
    .map(([uid]) => conversation?.participants.find((p) => p.userId === uid)?.user?.name ?? t('chat.someone'));

  if (loading) return <Loading />;

  return (
    <div className="mx-auto flex h-[calc(100vh-8rem)] max-w-3xl flex-col">
      <Card className="flex items-center gap-3 p-3">
        <Link to="/chats" className="rounded-lg p-2 text-slate-500 hover:bg-slate-100" aria-label={t('common.back')}>
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M15 18l-6-6 6-6" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </Link>
        <div className="min-w-0 flex-1">
          <div className="truncate font-bold text-slate-900">{title}</div>
          <div className="text-xs text-slate-400">
            {connected ? t('chat.online') : t('chat.offline')} · {conversation?.participants.length ?? 0} {t('chat.members')}
          </div>
        </div>
      </Card>

      {error && <div className="mt-3"><Alert>{error}</Alert></div>}

      <div className="mt-3 flex-1 space-y-2 overflow-y-auto rounded-2xl border border-slate-200 bg-white p-4">
        {messages.map((m) => {
          const mine = m.senderId === user?.id;
          return (
            <div key={m.id} className={`flex items-end gap-2 ${mine ? 'justify-end' : 'justify-start'}`}>
              {!mine && <Avatar user={m.sender} size="sm" />}
              <div className={`max-w-[75%] rounded-2xl px-3 py-2 text-sm ${mine ? 'bg-brand-600 text-white' : 'bg-slate-100 text-slate-800'}`}>
                {!mine && conversation?.type !== 'direct' && (
                  <div className="mb-0.5 text-xs font-semibold text-brand-700">{m.sender?.name}</div>
                )}
                <MessageBody message={m} mine={mine} />
                <div className={`mt-0.5 text-right text-[10px] ${mine ? 'text-brand-200' : 'text-slate-400'}`}>
                  {formatTime(m.createdAt)}
                  {mine && m.status === 'read' ? ' ✓✓' : mine ? ' ✓' : ''}
                </div>
              </div>
            </div>
          );
        })}
        {messages.length === 0 && <div className="py-10 text-center text-sm text-slate-400">{t('chat.startDialog')}</div>}
        <div ref={bottomRef} />
      </div>

      {typingNames.length > 0 && (
        <div className="px-2 pt-1 text-xs italic text-slate-400">{typingNames.join(', ')} {t('chat.typing')}</div>
      )}

      <form onSubmit={send} className="mt-3 flex items-center gap-2">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          className="hidden"
          onChange={onPhotoChange}
        />
        <button
          type="button"
          onClick={onPickPhoto}
          disabled={sending}
          className="rounded-full border border-slate-300 bg-white p-2.5 text-slate-500 hover:bg-slate-50 disabled:opacity-50"
          title={t('chat.sendPhotoAction')}
          aria-label={t('chat.sendPhotoAction')}
        >
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <circle cx="8.5" cy="8.5" r="1.5" />
            <path d="M21 15l-5-5L5 21" />
          </svg>
        </button>
        <button
          type="button"
          onClick={sendLocation}
          disabled={sending}
          className="rounded-full border border-slate-300 bg-white p-2.5 text-slate-500 hover:bg-slate-50 disabled:opacity-50"
          title={t('chat.sendLocationAction')}
          aria-label={t('chat.sendLocationAction')}
        >
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 21s-6-5.33-6-10a6 6 0 1112 0c0 4.67-6 10-6 10z" />
            <circle cx="12" cy="11" r="2" />
          </svg>
        </button>
        <input
          value={text}
          onChange={(e) => onType(e.target.value)}
          placeholder={t('chat.typeMessage')}
          className="flex-1 rounded-full border border-slate-300 bg-white px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-brand-400"
        />
        <Button type="submit" disabled={!text.trim() || sending} className="rounded-full">
          {sending ? <Spinner className="h-4 w-4" /> : t('action.send')}
        </Button>
      </form>
    </div>
  );
}

function MessageBody({ message: m, mine }: { message: Message; mine: boolean }) {
  const t = useT();
  if (m.type === 'photo' && m.content) {
    return (
      <a href={m.content} target="_blank" rel="noreferrer" className="block">
        <img
          src={m.content}
          alt={t('chat.photoLabel')}
          loading="lazy"
          className="max-h-64 rounded-lg object-cover"
        />
      </a>
    );
  }
  if (m.type === 'location' && m.latitude != null && m.longitude != null) {
    const href = `https://www.openstreetmap.org/?mlat=${m.latitude}&mlon=${m.longitude}#map=15/${m.latitude}/${m.longitude}`;
    return (
      <a
        href={href}
        target="_blank"
        rel="noreferrer"
        className={`flex items-center gap-2 underline ${mine ? 'text-white' : 'text-brand-700'}`}
      >
        <span>📍 {t('chat.locationLabel')}</span>
        <span className={`text-xs ${mine ? 'text-brand-100' : 'text-slate-500'}`}>
          {m.latitude.toFixed(4)}, {m.longitude.toFixed(4)}
        </span>
      </a>
    );
  }
  return <div className="whitespace-pre-line break-words">{m.content ?? `📎 ${t('chat.attachment')}`}</div>;
}
