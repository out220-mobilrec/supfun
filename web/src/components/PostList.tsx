import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { Post, PostComment, PostListResult, VisibilityScope } from '../types';
import { Alert, Button, Card, Field, Input, Select, Spinner, Textarea } from './ui';
import { Avatar } from './Avatar';
import { ImageUploader } from './ImageUploader';
import { relativeTime } from '../lib/format';
import { postTypeLabel } from '../lib/labels';

const PAGE = 10;

const typeEmoji: Record<string, string> = {
  swim: '🏊',
  route: '🧭',
  achievement: '🏆',
  event: '🗓',
  news: '📰',
  waterbody: '📍',
};

export function PostList({
  authorId,
  title = 'Лента активности',
  showComposer = true,
  initialPostId,
}: {
  authorId?: string;
  title?: string;
  showComposer?: boolean;
  initialPostId?: string;
}) {
  const { user } = useAuth();
  const [posts, setPosts] = useState<Post[]>([]);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(
    async (offset = 0) => {
      const query = new URLSearchParams({ limit: String(PAGE), offset: String(offset) });
      if (authorId) query.set('authorId', authorId);
      const { data } = await api.get<PostListResult>(`/posts?${query.toString()}`);
      setPosts((prev) => (offset === 0 ? data.items : [...prev, ...data.items]));
      setHasMore(data.hasMore);
    },
    [authorId],
  );

  useEffect(() => {
    setLoading(true);
    load(0)
      .catch((err) => setError(errorMessage(err)))
      .finally(() => setLoading(false));
  }, [load]);

  const more = async () => {
    setLoadingMore(true);
    try {
      await load(posts.length);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoadingMore(false);
    }
  };

  const addPost = (post: Post) => setPosts((prev) => [post, ...prev]);
  const patchPost = (id: string, patch: Partial<Post>) =>
    setPosts((prev) => prev.map((p) => (p.id === id ? { ...p, ...patch } : p)));
  const dropPost = (id: string) => setPosts((prev) => prev.filter((p) => p.id !== id));

  return (
    <div className="space-y-4">
      {title && <h2 className="text-lg font-bold text-slate-900">{title}</h2>}
      {showComposer && user && <PostComposer onCreated={addPost} />}
      {error && <Alert>{error}</Alert>}
      {loading && <Spinner />}
      {!loading && posts.length === 0 && (
        <Card className="p-6 text-center text-sm text-slate-400">
          Пока нет публикаций. Поделитесь своим заплывом!
        </Card>
      )}
      {posts.map((post) => (
        <PostCard
          key={post.id}
          post={post}
          onPatch={patchPost}
          onDelete={dropPost}
          highlight={post.id === initialPostId}
        />
      ))}
      {hasMore && (
        <div className="flex justify-center">
          <Button tone="outline" onClick={more} loading={loadingMore}>
            Показать ещё
          </Button>
        </div>
      )}
    </div>
  );
}

function PostComposer({ onCreated }: { onCreated: (post: Post) => void }) {
  const [body, setBody] = useState('');
  const [photos, setPhotos] = useState<string[]>([]);
  const [visibility, setVisibility] = useState<VisibilityScope>('public');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const submit = async () => {
    if (!body.trim() && photos.length === 0) {
      setError('Добавьте текст или фото');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const { data } = await api.post<Post>('/posts', {
        type: 'swim',
        body: body.trim() || undefined,
        photos,
        visibility,
      });
      onCreated(data);
      setBody('');
      setPhotos([]);
      setVisibility('public');
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card className="space-y-3 p-4">
      <Textarea
        rows={3}
        placeholder="Что нового? Расскажите о заплыве…"
        value={body}
        onChange={(e) => setBody(e.target.value)}
      />
      {photos.length > 0 && (
        <div className="flex gap-2">
          {photos.map((p) => (
            <div key={p} className="relative h-20 w-20 overflow-hidden rounded-lg border border-slate-200">
              <img src={p} alt="" className="h-full w-full object-cover" />
            </div>
          ))}
        </div>
      )}
      {error && <p className="text-sm text-red-600">{error}</p>}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <ImageUploader value={photos} onChange={setPhotos} max={4} label="Фото" />
        <div className="flex items-center gap-3">
          <Select
            value={visibility}
            onChange={(e) => setVisibility(e.target.value as VisibilityScope)}
            className="max-w-[160px]"
          >
            <option value="public">Видно всем</option>
            <option value="friends">Только друзьям</option>
            <option value="private">Только мне</option>
          </Select>
          <Button onClick={submit} loading={busy}>
            Опубликовать
          </Button>
        </div>
      </div>
    </Card>
  );
}

function PostCard({
  post,
  onPatch,
  onDelete,
  highlight,
}: {
  post: Post;
  onPatch: (id: string, patch: Partial<Post>) => void;
  onDelete: (id: string) => void;
  highlight?: boolean;
}) {
  const { user } = useAuth();
  const [busy, setBusy] = useState(false);
  const [commentsOpen, setCommentsOpen] = useState(Boolean(highlight));
  const [comments, setComments] = useState<PostComment[]>([]);
  const [commentInput, setCommentInput] = useState('');
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [shareMsg, setShareMsg] = useState('');

  const loadComments = useCallback(async () => {
    setCommentsLoading(true);
    try {
      const { data } = await api.get<PostComment[]>(`/posts/${post.id}/comments`);
      setComments(data);
    } catch {
      /* ignore */
    } finally {
      setCommentsLoading(false);
    }
  }, [post.id]);

  useEffect(() => {
    if (commentsOpen) void loadComments();
  }, [commentsOpen, loadComments]);

  const like = async () => {
    setBusy(true);
    try {
      const { data } = await api.patch<{ liked: boolean; likeCount: number }>(`/posts/${post.id}/like`);
      onPatch(post.id, { likedByMe: data.liked, likeCount: data.likeCount });
    } catch {
      /* ignore */
    } finally {
      setBusy(false);
    }
  };

  const share = async () => {
    try {
      const { data } = await api.post<{ shareCount: number }>(`/posts/${post.id}/share`);
      onPatch(post.id, { shareCount: data.shareCount });
      const url = `${window.location.origin}/feed?post=${post.id}`;
      if (navigator.clipboard) await navigator.clipboard.writeText(url);
      setShareMsg('Ссылка скопирована');
      setTimeout(() => setShareMsg(''), 2000);
    } catch {
      /* ignore */
    }
  };

  const remove = async () => {
    if (!window.confirm('Удалить публикацию?')) return;
    setBusy(true);
    try {
      await api.delete(`/posts/${post.id}`);
      onDelete(post.id);
    } catch {
      setBusy(false);
    }
  };

  const addComment = async () => {
    if (!commentInput.trim()) return;
    setBusy(true);
    try {
      const { data } = await api.post<PostComment>(`/posts/${post.id}/comments`, {
        body: commentInput.trim(),
      });
      setComments((prev) => [...prev, data]);
      setCommentInput('');
      onPatch(post.id, { commentCount: post.commentCount + 1 });
    } catch {
      /* ignore */
    } finally {
      setBusy(false);
    }
  };

  const removeComment = async (commentId: string) => {
    try {
      await api.delete(`/posts/${post.id}/comments/${commentId}`);
      setComments((prev) => prev.filter((c) => c.id !== commentId));
      onPatch(post.id, { commentCount: Math.max(0, post.commentCount - 1) });
    } catch {
      /* ignore */
    }
  };

  const target = post.refType === 'event' ? `/events/${post.refId}` : post.refType === 'track' ? '/tracks' : undefined;

  return (
    <Card className={`p-4 ${highlight ? 'ring-2 ring-brand-400' : ''}`}>
      <div className="flex items-start gap-3">
        <Link to={`/users/${post.authorId}`}>
          <Avatar user={post.author} />
        </Link>
        <div className="min-w-0 flex-1">
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-wrap items-center gap-2">
              <Link to={`/users/${post.authorId}`} className="font-semibold text-slate-900 hover:underline">
                {post.author?.name ?? 'Пользователь'}
              </Link>
              <span className="rounded-full bg-slate-100 px-2 py-0.5 text-xs text-slate-500">
                {typeEmoji[post.type] ?? '📌'} {postTypeLabel(post.type)}
              </span>
              {post.visibility !== 'public' && (
                <span className="text-xs text-slate-400">
                  {post.visibility === 'friends' ? '👥 друзьям' : '🔒 только мне'}
                </span>
              )}
            </div>
            <span className="shrink-0 text-xs text-slate-400">{relativeTime(post.createdAt)}</span>
          </div>

          {post.title && <div className="mt-1 font-medium text-slate-900">{post.title}</div>}
          {post.body && <p className="mt-1 whitespace-pre-line text-sm text-slate-700">{post.body}</p>}

          {post.photos.length > 0 && (
            <div className="mt-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
              {post.photos.map((p) => (
                <img key={p} src={p} alt="" className="aspect-square w-full rounded-lg object-cover" loading="lazy" />
              ))}
            </div>
          )}

          <div className="mt-3 flex flex-wrap items-center gap-4 text-sm">
            <button
              onClick={like}
              disabled={busy}
              className={`flex items-center gap-1 ${post.likedByMe ? 'font-semibold text-rose-600' : 'text-slate-500 hover:text-rose-600'}`}
            >
              {post.likedByMe ? '♥' : '♡'} {post.likeCount}
            </button>
            <button
              onClick={() => setCommentsOpen((v) => !v)}
              className="flex items-center gap-1 text-slate-500 hover:text-brand-600"
            >
              💬 {post.commentCount}
            </button>
            <button onClick={share} className="flex items-center gap-1 text-slate-500 hover:text-brand-600">
              ↪ {post.shareCount}
            </button>
            {target && (
              <Link to={target} className="text-slate-500 hover:text-brand-600">
                Открыть
              </Link>
            )}
            {shareMsg && <span className="text-xs text-green-600">{shareMsg}</span>}
            {post.canDelete && (
              <button onClick={remove} disabled={busy} className="ml-auto text-slate-400 hover:text-red-600">
                Удалить
              </button>
            )}
          </div>

          {commentsOpen && (
            <div className="mt-3 space-y-3 border-t border-slate-100 pt-3">
              {commentsLoading && <Spinner className="h-4 w-4" />}
              {comments.map((c) => (
                <div key={c.id} className="flex items-start gap-2">
                  <Avatar user={c.author} size="sm" />
                  <div className="min-w-0 flex-1 rounded-lg bg-slate-50 px-3 py-2">
                    <div className="flex items-center justify-between gap-2">
                      <Link to={`/users/${c.authorId}`} className="text-sm font-medium text-slate-800 hover:underline">
                        {c.author?.name ?? 'Пользователь'}
                      </Link>
                      <span className="text-[10px] text-slate-400">{relativeTime(c.createdAt)}</span>
                    </div>
                    <p className="mt-0.5 whitespace-pre-line text-sm text-slate-700">{c.body}</p>
                  </div>
                  {user && c.authorId === user.id && (
                    <button
                      onClick={() => removeComment(c.id)}
                      className="text-xs text-slate-400 hover:text-red-600"
                      aria-label="Удалить комментарий"
                    >
                      ×
                    </button>
                  )}
                </div>
              ))}
              {comments.length === 0 && !commentsLoading && (
                <p className="text-xs text-slate-400">Комментариев пока нет.</p>
              )}
              <div className="flex items-end gap-2">
                <div className="flex-1">
                  <Field label="">
                    <Input
                      value={commentInput}
                      onChange={(e) => setCommentInput(e.target.value)}
                      placeholder="Написать комментарий…"
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') void addComment();
                      }}
                    />
                  </Field>
                </div>
                <Button onClick={addComment} loading={busy}>
                  Отправить
                </Button>
              </div>
            </div>
          )}
        </div>
      </div>
    </Card>
  );
}
