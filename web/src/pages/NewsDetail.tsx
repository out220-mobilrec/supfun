import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { News } from '../types';
import { Alert, Button, Card, EmptyState, Loading } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { formatDateTime } from '../lib/format';
import { useAuth } from '../store/AuthContext';
import { useT } from '../i18n';

export default function NewsDetailPage() {
  const t = useT();
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isStaff = user?.role === 'admin' || user?.role === 'moderator';
  const [item, setItem] = useState<News | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<News>(`/news/${id}`);
      setItem(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  const togglePublish = async () => {
    if (!item) return;
    setBusy(true);
    try {
      const endpoint = item.isPublished ? 'unpublish' : 'publish';
      await api.post(`/news/${item.id}/${endpoint}`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async () => {
    if (!item || !window.confirm(t('news.deleteConfirm'))) return;
    setBusy(true);
    try {
      await api.delete(`/news/${item.id}`);
      navigate('/news');
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  if (loading) return <Loading />;
  if (!item) {
    return (
      <EmptyState
        title={t('news.notFound')}
        action={<Button tone="outline" onClick={() => navigate('/news')}>{t('news.backToList')}</Button>}
      />
    );
  }

  return (
    <div className="space-y-5">
      {error && <Alert>{error}</Alert>}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Button tone="outline" onClick={() => navigate(-1)}>{t('common.back')}</Button>
        {isStaff && (
          <div className="flex flex-wrap gap-2">
            <Button tone="outline" onClick={() => navigate(`/news/${item.id}/edit`)}>{t('common.edit')}</Button>
            <Button tone="slate" onClick={togglePublish} loading={busy}>
              {item.isPublished ? t('news.unpublish') : t('common.publish')}
            </Button>
            <Button tone="red" onClick={remove} loading={busy}>{t('common.delete')}</Button>
          </div>
        )}
      </div>

      <Card className="overflow-hidden p-0">
        {item.coverUrl && (
          <img src={item.coverUrl} alt="" className="h-64 w-full object-cover" />
        )}
        <div className="space-y-4 p-6">
          <div className="flex flex-wrap items-center gap-2 text-sm text-slate-500">
            {!item.isPublished && (
              <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs font-semibold text-amber-800">{t('news.draft')}</span>
            )}
            <span>{formatDateTime(item.createdAt)}</span>
          </div>
          <h1 className="text-2xl font-extrabold text-slate-900 sm:text-3xl">{item.title}</h1>
          {item.author && (
            <div className="flex items-center gap-2 text-sm text-slate-600">
              <Avatar user={item.author} size="sm" />
              <span>{item.author.name}</span>
            </div>
          )}
          <div className="whitespace-pre-line text-[15px] leading-relaxed text-slate-700">{item.body}</div>
        </div>
      </Card>
    </div>
  );
}
