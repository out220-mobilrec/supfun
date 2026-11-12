import { useCallback, useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Channel, ChannelPost, ChannelPostComment, ChannelPostListResult } from '../types';
import { Alert, Button, Card, EmptyState, Input, Loading, Textarea } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { relativeTime } from '../lib/format';
import { Badge } from '../components/ui';
import { useT } from '../i18n';

export default function ChannelDetailPage() {
  const t = useT();
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const [channel, setChannel] = useState<Channel | null>(null);
  const [posts, setPosts] = useState<ChannelPost[]>([]);
  const [comments, setComments] = useState<Record<string, ChannelPostComment[]>>({});
  const [openComments, setOpenComments] = useState<Record<string, boolean>>({});
  const [commentDraft, setCommentDraft] = useState<Record<string, string>>({});
  const [postTitle, setPostTitle] = useState('');
  const [postBody, setPostBody] = useState('');
  const [loading, setLoading] = useState(true);
  const [posting, setPosting] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const [chRes, postsRes] = await Promise.all([
        api.get<Channel>(`/channels/${id}`),
        api.get<ChannelPostListResult>(`/channels/${id}/posts`),
      ]);
      setChannel(chRes.data);
      setPosts(postsRes.data.items);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  const toggleSubscribe = async () => {
    if (!channel) return;
    const ch = channel as any;
    try {
      if (ch.isMember ?? ch.isSubscribed) await api.delete(`/channels/${channel.id}/subscribe`);
      else await api.post(`/channels/${channel.id}/subscribe`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const createPost = async (e: FormEvent) => {
    e.preventDefault();
    if (!channel || !postBody.trim()) return;
    setPosting(true);
    setError('');
    try {
      await api.post(`/channels/${channel.id}/posts`, {
        title: postTitle.trim() || undefined,
        body: postBody.trim(),
      });
      setPostTitle('');
      setPostBody('');
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setPosting(false);
    }
  };

  const toggleLike = async (post: ChannelPost) => {
    try {
      const { data } = await api.post<{ liked: boolean; likesCount: number }>(`/channels/posts/${post.id}/like`);
      setPosts((prev) => prev.map((p) => (p.id === post.id ? { ...p, likedByMe: data.liked, likeCount: data.likesCount } : p)));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const togglePin = async (post: ChannelPost) => {
    try {
      await api.patch(`/channels/posts/${post.id}/pin`, { pinned: !post.isPinned });
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const deletePost = async (postId: string) => {
    if (!window.confirm(t('channel.deletePostConfirm'))) return;
    try {
      await api.delete(`/channels/posts/${postId}`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const loadComments = async (postId: string) => {
    const { data } = await api.get<{ items: ChannelPostComment[] }>(`/channels/posts/${postId}/comments`);
    setComments((prev) => ({ ...prev, [postId]: data.items }));
  };

  const toggleComments = async (postId: string) => {
    const next = !openComments[postId];
    setOpenComments((prev) => ({ ...prev, [postId]: next }));
    if (next && !comments[postId]) await loadComments(postId);
  };

  const sendComment = async (postId: string) => {
    const body = (commentDraft[postId] ?? '').trim();
    if (!body) return;
    try {
      await api.post(`/channels/posts/${postId}/comments`, { body });
      setCommentDraft((prev) => ({ ...prev, [postId]: '' }));
      await loadComments(postId);
      setPosts((prev) => prev.map((p) => (p.id === postId ? { ...p, commentCount: p.commentCount + 1 } : p)));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  if (loading) return <Loading />;
  if (!channel) return <EmptyState title={t('channel.notFound')} action={<Button tone="outline" onClick={() => navigate('/channels')}>{t('channel.backToList')}</Button>} />;

  return (
    <div className="space-y-5">
      {error && <Alert>{error}</Alert>}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <button onClick={() => navigate('/channels')} className="mb-2 text-sm text-slate-500 hover:text-slate-700">← {t('nav.channels')}</button>
          <div className="flex items-center gap-3">
            <Avatar user={{ name: channel.name ?? (channel as any).title ?? 'SUP', avatarUrl: channel.photoUrl ?? (channel as any).avatarUrl ?? null }} size="lg" />
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-2xl font-extrabold text-slate-900">{channel.name ?? (channel as any).title}</h1>
                {!channel.isPublic && <Badge tone="slate">{t('channel.private')}</Badge>}
              </div>
              <div className="text-sm text-slate-500">
                {channel.owner?.name ?? 'SUP'} · {(channel.subscriberCount ?? (channel as any).subscribersCount ?? 0)} {t('channel.subscribers')} · {t('channel.created')} {relativeTime(channel.createdAt)}
              </div>
            </div>
          </div>
          {channel.description && <p className="mt-3 text-sm text-slate-600">{channel.description}</p>}
        </div>
        <Button tone={(channel as any).isMember ?? (channel as any).isSubscribed ? 'slate' : 'brand'} onClick={toggleSubscribe}>
          {(channel as any).isMember ?? (channel as any).isSubscribed ? t('channel.subscribed') : t('action.subscribe')}
        </Button>
      </div>

      {((channel as any).canPost ?? (channel as any).isMember) && (
        <Card className="p-4">
          <form onSubmit={createPost} className="space-y-3">
            <div className="text-sm font-semibold text-slate-800">{t('channel.newPost')}</div>
            <Input value={postTitle} onChange={(e) => setPostTitle(e.target.value)} placeholder={t('channel.postTitle')} maxLength={220} />
            <Textarea value={postBody} onChange={(e) => setPostBody(e.target.value)} placeholder={t('channel.postBody')} rows={3} required />
            <div className="flex justify-end">
              <Button type="submit" loading={posting} disabled={!postBody.trim()}>{t('common.publish')}</Button>
            </div>
          </form>
        </Card>
      )}

      <div className="space-y-4">
        {posts.map((post) => (
          <Card key={post.id} className="p-5">
            <div className="flex items-start justify-between gap-3">
              <div className="flex items-center gap-3">
                <Avatar user={post.author} size="sm" />
                <div>
                  <div className="text-sm font-semibold text-slate-900">{post.author?.name ?? '—'}</div>
                  <div className="text-xs text-slate-400">
                    {relativeTime(post.createdAt)}
                    {post.isPinned && <span className="ml-2 font-semibold text-brand-600">· {t('channel.pinned')}</span>}
                  </div>
                </div>
              </div>
              {((channel as any).canModerate || post.canPin || post.canDelete) && (
                <div className="flex gap-1">
                  {(post.canPin || (channel as any).canModerate) && (
                    <button onClick={() => togglePin(post)} className="rounded px-2 py-1 text-xs text-slate-500 hover:bg-slate-100">
                      {post.isPinned ? t('channel.unpin') : t('channel.pin')}
                    </button>
                  )}
                  {(post.canDelete || (channel as any).canModerate) && (
                    <button onClick={() => deletePost(post.id)} className="rounded px-2 py-1 text-xs text-red-500 hover:bg-red-50">
                      {t('common.delete')}
                    </button>
                  )}
                </div>
              )}
            </div>
            {post.title && <h3 className="mt-3 text-base font-bold text-slate-900">{post.title}</h3>}
            <p className="mt-2 whitespace-pre-line text-sm leading-relaxed text-slate-700">{post.body}</p>
            <div className="mt-4 flex items-center gap-4 border-t border-slate-100 pt-3 text-sm">
              <button onClick={() => toggleLike(post)} className={`flex items-center gap-1.5 font-medium ${post.likedByMe ? 'text-red-600' : 'text-slate-500 hover:text-slate-700'}`}>
                <span>{post.likedByMe ? '♥' : '♡'}</span> {post.likeCount}
              </button>
              <button onClick={() => toggleComments(post.id)} className="flex items-center gap-1.5 font-medium text-slate-500 hover:text-slate-700">
                💬 {post.commentCount}
              </button>
            </div>
            {openComments[post.id] && (
              <div className="mt-3 space-y-3 border-t border-slate-100 pt-3">
                {(comments[post.id] ?? []).map((c) => (
                  <div key={c.id} className="flex gap-2">
                    <Avatar user={c.author} size="sm" />
                    <div className="min-w-0 rounded-xl bg-slate-50 px-3 py-2">
                      <div className="text-xs font-semibold text-slate-700">{c.author?.name} <span className="font-normal text-slate-400">· {relativeTime(c.createdAt)}</span></div>
                      <div className="text-sm text-slate-700">{c.body}</div>
                    </div>
                  </div>
                ))}
                <div className="flex gap-2">
                  <Input
                    value={commentDraft[post.id] ?? ''}
                    onChange={(e) => setCommentDraft((prev) => ({ ...prev, [post.id]: e.target.value }))}
                    placeholder={t('channel.writeComment')}
                    className="flex-1"
                    onKeyDown={(e) => e.key === 'Enter' && !e.shiftKey && (e.preventDefault(), void sendComment(post.id))}
                  />
                  <Button tone="slate" onClick={() => sendComment(post.id)} disabled={!commentDraft[post.id]?.trim()}>
                    {t('common.send')}
                  </Button>
                </div>
              </div>
            )}
          </Card>
        ))}
        {posts.length === 0 && <EmptyState title={t('channel.noPosts')} />}
      </div>
    </div>
  );
}
