import { useCallback, useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { News } from '../types';
import { Alert, Button, Card, EmptyState, Field, Input, Loading, Modal, PageHeader, Textarea } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { relativeTime } from '../lib/format';
import { useAuth } from '../store/AuthContext';
import { Badge } from '../components/ui';
import { ImageUploader } from '../components/ImageUploader';
import { useT } from '../i18n';

export default function NewsPage() {
  const t = useT();
  const navigate = useNavigate();
  const { user } = useAuth();
  const isStaff = user?.role === 'admin' || user?.role === 'moderator';
  const [items, setItems] = useState<News[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [includeDrafts, setIncludeDrafts] = useState(false);
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ title: '', body: '', coverUrl: '', isPublished: true });

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ limit: '30' });
      if (includeDrafts) params.set('includeDrafts', 'true');
      const { data } = await api.get<{ items: News[]; hasMore: boolean }>(`/news?${params.toString()}`);
      setItems(data.items);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [includeDrafts]);

  useEffect(() => {
    void load();
  }, [load]);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const { data } = await api.post<News>('/news', {
        title: form.title.trim(),
        body: form.body.trim(),
        coverUrl: form.coverUrl || undefined,
        isPublished: form.isPublished,
      });
      setOpen(false);
      setForm({ title: '', body: '', coverUrl: '', isPublished: true });
      navigate(`/news/${data.id}`);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('news.title')}
        subtitle={t('news.subtitle')}
        action={
          isStaff ? (
            <div className="flex gap-2">
              <Button tone="outline" onClick={() => setIncludeDrafts((v) => !v)}>
                {includeDrafts ? t('news.hideDrafts') : t('news.showDrafts')}
              </Button>
              <Button onClick={() => setOpen(true)}>{t('news.new')}</Button>
            </div>
          ) : undefined
        }
      />
      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}
      {!loading && items.length === 0 && (
        <EmptyState title={t('news.empty')} hint={t('news.later')} />
      )}
      {!loading && items.length > 0 && (
        <div className="grid gap-4 md:grid-cols-2">
          {items.map((n) => (
            <Card key={n.id} className="overflow-hidden" onClick={() => navigate(`/news/${n.id}`)}>
              {n.coverUrl && <img src={n.coverUrl} alt="" className="h-44 w-full object-cover" />}
              <div className="p-4">
                <div className="flex items-center gap-2">
                  {!n.isPublished && <Badge tone="amber">{t('news.draft')}</Badge>}
                  {n.author && (
                    <div className="flex items-center gap-2 text-xs text-slate-400">
                      <Avatar user={n.author} size="sm" />
                      <span>{n.author.name}</span>
                    </div>
                  )}
                  <span className="text-xs text-slate-400"> · {relativeTime(n.createdAt)}</span>
                </div>
                <h2 className="mt-2 line-clamp-2 font-bold text-slate-900">{n.title}</h2>
                <p className="mt-1 line-clamp-3 text-sm text-slate-600">{n.body}</p>
              </div>
            </Card>
          ))}
        </div>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={t('news.new')} wide>
        {error && <div className="mb-3"><Alert>{error}</Alert></div>}
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('label.title')}>
            <Input required minLength={3} maxLength={200} value={form.title} onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))} />
          </Field>
          <ImageUploader
            single
            label={t('news.cover')}
            value={form.coverUrl ? [form.coverUrl] : []}
            onChange={(urls) => setForm((f) => ({ ...f, coverUrl: urls[0] ?? '' }))}
          />
          <Field label={t('news.body')}>
            <Textarea required rows={8} maxLength={10000} value={form.body} onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))} />
          </Field>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input type="checkbox" checked={form.isPublished} onChange={(e) => setForm((f) => ({ ...f, isPublished: e.target.checked }))} />
            {t('news.publishNow')}
          </label>
          <div className="flex justify-end gap-3">
            <Button tone="outline" type="button" onClick={() => setOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={saving}>
              {t('common.save')}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
