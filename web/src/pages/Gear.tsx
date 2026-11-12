import { useCallback, useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { api, errorMessage } from '../lib/api';
import type { GearItem, GearCategory } from '../types';
import { Alert, Button, Card, EmptyState, Field, Input, Loading, Modal, PageHeader, Select, Textarea } from '../components/ui';
import { Badge } from '../components/ui';
import { useT } from '../i18n';

const CATEGORIES: GearCategory[] = ['board', 'paddle', 'wetsuit', 'vest', 'leash', 'pump', 'drybag', 'other'];

const emptyForm = {
  category: 'board' as GearCategory,
  brand: '',
  model: '',
  lengthCm: '',
  widthCm: '',
  volumeL: '',
  weightKg: '',
  material: '',
  notes: '',
};

export default function GearPage() {
  const t = useT();
  const categoryLabel = (c: GearCategory) => t(`gear.cat.${c}` as any);
  const [items, setItems] = useState<GearItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [open, setOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [form, setForm] = useState(emptyForm);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<GearItem[]>('/gear/mine');
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

  const openNew = () => {
    setEditId(null);
    setForm(emptyForm);
    setOpen(true);
  };

  const openEdit = (item: GearItem) => {
    setEditId(item.id);
    setForm({
      category: item.category,
      brand: item.brand ?? '',
      model: item.model ?? '',
      lengthCm: item.lengthCm ? String(item.lengthCm) : '',
      widthCm: item.widthCm ? String(item.widthCm) : '',
      volumeL: item.volumeL ? String(item.volumeL) : '',
      weightKg: item.weightKg ? String(item.weightKg) : '',
      material: item.material ?? '',
      notes: item.notes ?? '',
    });
    setOpen(true);
  };

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    const payload = {
      category: form.category,
      brand: form.brand || undefined,
      model: form.model || undefined,
      lengthCm: form.lengthCm ? Number(form.lengthCm) : undefined,
      widthCm: form.widthCm ? Number(form.widthCm) : undefined,
      volumeL: form.volumeL ? Number(form.volumeL) : undefined,
      weightKg: form.weightKg ? Number(form.weightKg) : undefined,
      material: form.material || undefined,
      notes: form.notes || undefined,
    };
    try {
      if (editId) {
        await api.patch(`/gear/${editId}`, payload);
      } else {
        await api.post('/gear', payload);
      }
      setOpen(false);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (id: string) => {
    if (!window.confirm(t('gear.deleteConfirm'))) return;
    try {
      await api.delete(`/gear/${id}`);
      setItems((prev) => prev.filter((x) => x.id !== id));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const num = (value: string, suffix = '') => (value ? `${value}${suffix}` : '—');

  return (
    <div className="space-y-5">
      <PageHeader
        title={t('gear.title')}
        subtitle={t('gear.subtitle')}
        action={<Button onClick={openNew}>{t('gear.add')}</Button>}
      />
      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}
      {!loading && items.length === 0 && (
        <EmptyState
          title={t('gear.empty')}
          hint={t('gear.emptyHint')}
        />
      )}
      {!loading && items.length > 0 && (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {items.map((item) => (
            <Card key={item.id} className="flex flex-col p-4">
              <div className="flex items-start justify-between gap-2">
                <Badge tone="brand">{categoryLabel(item.category)}</Badge>
                <div className="flex gap-1">
                  <button onClick={() => openEdit(item)} className="text-xs font-semibold text-brand-600 hover:underline">
                    {t('common.edit')}
                  </button>
                  <button onClick={() => remove(item.id)} className="text-xs font-semibold text-red-500 hover:underline">
                    {t('common.delete')}
                  </button>
                </div>
              </div>
              <div className="mt-2 text-lg font-bold text-slate-900">
                {[item.brand, item.model].filter(Boolean).join(' ') || t('gear.unnamed')}
              </div>
              <div className="mt-1 grid grid-cols-2 gap-x-3 gap-y-1 text-sm text-slate-600">
                {item.lengthCm && <div>{t('gear.lenLabel')}: {num(String(item.lengthCm), ' cm')}</div>}
                {item.widthCm && <div>{t('gear.widLabel')}: {num(String(item.widthCm), ' cm')}</div>}
                {item.volumeL && <div>{t('gear.volLabel')}: {num(String(item.volumeL), ' L')}</div>}
                {item.weightKg && <div>{t('gear.weiLabel')}: {num(String(item.weightKg), ' kg')}</div>}
                {item.material && <div>{t('gear.matLabel')}: {item.material}</div>}
              </div>
              {item.notes && <p className="mt-2 line-clamp-2 text-sm text-slate-500">{item.notes}</p>}
            </Card>
          ))}
        </div>
      )}

      <Modal open={open} onClose={() => setOpen(false)} title={editId ? t('gear.edit') : t('gear.new')}>
        {error && <div className="mb-3"><Alert>{error}</Alert></div>}
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('label.category')}>
            <Select value={form.category} onChange={(e) => setForm((f) => ({ ...f, category: e.target.value as GearCategory }))}>
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {categoryLabel(c)}
                </option>
              ))}
            </Select>
          </Field>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t('gear.brand')}>
              <Input value={form.brand} onChange={(e) => setForm((f) => ({ ...f, brand: e.target.value }))} />
            </Field>
            <Field label={t('gear.model')}>
              <Input value={form.model} onChange={(e) => setForm((f) => ({ ...f, model: e.target.value }))} />
            </Field>
            <Field label={t('gear.length')}>
              <Input type="number" min={1} value={form.lengthCm} onChange={(e) => setForm((f) => ({ ...f, lengthCm: e.target.value }))} />
            </Field>
            <Field label={t('gear.width')}>
              <Input type="number" min={1} value={form.widthCm} onChange={(e) => setForm((f) => ({ ...f, widthCm: e.target.value }))} />
            </Field>
            <Field label={t('gear.volume')}>
              <Input type="number" min={1} value={form.volumeL} onChange={(e) => setForm((f) => ({ ...f, volumeL: e.target.value }))} />
            </Field>
            <Field label={t('gear.weight')}>
              <Input type="number" min={0} step="0.1" value={form.weightKg} onChange={(e) => setForm((f) => ({ ...f, weightKg: e.target.value }))} />
            </Field>
          </div>
          <Field label={t('gear.material')}>
            <Input value={form.material} onChange={(e) => setForm((f) => ({ ...f, material: e.target.value }))} />
          </Field>
          <Field label={t('gear.notes')}>
            <Textarea rows={3} value={form.notes} onChange={(e) => setForm((f) => ({ ...f, notes: e.target.value }))} />
          </Field>
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
