import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Channel } from '../types';
import { Alert, Button, Card, EmptyState, Field, Input, Loading, Modal, PageHeader, Textarea } from '../components/ui';
import { Badge } from '../components/ui';
import { useT } from '../i18n';

export default function ChannelsPage() {
  const t = useT();
  const navigate = useNavigate();
  const [items, setItems] = useState<Channel[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [open, setOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({ name: '', description: '', isPublic: true });

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<Channel[]>('/channels?limit=50');
      setItems(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    try {
      const { data } = await api.post<Channel>('/channels', {
        name: form.name.trim(),
        description: form.description.trim() || undefined,
        isPublic: form.isPublic,
      });
      setOpen(false);
      setForm({ name: '', description: '', isPublic: true });
      navigate(`/channels/${data.id}`);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('channels.title')}
        subtitle={t('channels.subtitle')}
        action={<Button onClick={() => setOpen(true)}>{t('channels.create')}</Button>}
      />
      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}
      {!loading && items.length === 0 && (
        <EmptyState title={t('channels.empty')} hint={t('channels.emptyHint')} />
      )}
      {!loading && items.length > 0 && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {items.map((c) => (
            <Card key={c.id} className="p-4" onClick={() => navigate(`/channels/${c.id}`)}>
              <div className="flex items-center gap-3">
                {c.photoUrl ? (
                  <img src={c.photoUrl} alt="" className="h-10 w-10 rounded-xl object-cover" />
                ) : (
                  <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-100 text-lg font-bold text-brand-700">
                    {c.name.charAt(0).toUpperCase()}
                  </div>
                )}
                <div className="min-w-0">
                  <div className="truncate font-bold text-slate-900">{c.name}</div>
                  <div className="text-xs text-slate-400">{c.subscriberCount} {t('channel.subscribers')}</div>
                </div>
                {!c.isPublic && <Badge tone="amber">{t('channel.private')}</Badge>}
                {c.isMember && <Badge tone="green">{t('channel.subscribed')}</Badge>}
              </div>
              {c.description && <p className="mt-2 line-clamp-2 text-sm text-slate-600">{c.description}</p>}
            </Card>
          ))}
        </div>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={t('channels.new')}>
        {error && <div className="mb-3"><Alert>{error}</Alert></div>}
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('label.title')}>
            <Input required minLength={3} maxLength={100} value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
          </Field>
          <Field label={t('label.description')}>
            <Textarea rows={3} maxLength={500} value={form.description} onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))} />
          </Field>
          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input type="checkbox" checked={form.isPublic} onChange={(e) => setForm((f) => ({ ...f, isPublic: e.target.checked }))} />
            {t('channels.public')}
          </label>
          <div className="flex justify-end gap-3">
            <Button tone="outline" type="button" onClick={() => setOpen(false)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={saving}>
              {t('common.create')}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
