import { useCallback, useEffect, useState } from 'react';
import { api, errorMessage } from '../../lib/api';
import { useAuth } from '../../store/AuthContext';
import type { AdminWaterBody } from '../../types';
import { Alert, Badge, Button, Card, Field, Input, Loading, Modal, Textarea } from '../../components/ui';
import { formatDate } from '../../lib/format';
import { AdminHeader } from './shared';
import { useT } from '../../i18n';

type ActiveFilter = 'all' | 'true' | 'false';

interface FormState {
  name: string;
  region: string;
  description: string;
  latitude: string;
  longitude: string;
  active: boolean;
}

const emptyForm: FormState = {
  name: '',
  region: '',
  description: '',
  latitude: '',
  longitude: '',
  active: true,
};

function formFrom(wb: AdminWaterBody): FormState {
  return {
    name: wb.name,
    region: wb.region ?? '',
    description: wb.description ?? '',
    latitude: wb.latitude != null ? String(wb.latitude) : '',
    longitude: wb.longitude != null ? String(wb.longitude) : '',
    active: wb.active,
  };
}

export default function AdminWaterbodies() {
  const t = useT(); void t;
  const { user: me } = useAuth();
  const isAdmin = me?.role === 'admin';
  const [items, setItems] = useState<AdminWaterBody[]>([]);
  const [q, setQ] = useState('');
  const [active, setActive] = useState<ActiveFilter>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState('');

  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<AdminWaterBody | null>(null);
  const [form, setForm] = useState<FormState>(emptyForm);
  const [formError, setFormError] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      if (q.trim()) params.set('q', q.trim());
      if (active !== 'all') params.set('active', active);
      const { data } = await api.get<AdminWaterBody[]>(`/admin/waterbodies?${params.toString()}`);
      setItems(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [q, active]);

  useEffect(() => {
    const t = setTimeout(() => void load(), 250);
    return () => clearTimeout(t);
  }, [load]);

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setFormError('');
    setModalOpen(true);
  };

  const openEdit = (wb: AdminWaterBody) => {
    setEditing(wb);
    setForm(formFrom(wb));
    setFormError('');
    setModalOpen(true);
  };

  const submit = async () => {
    const name = form.name.trim();
    if (!name) {
      setFormError('Укажите название водоёма.');
      return;
    }
    const lat = form.latitude.trim();
    const lng = form.longitude.trim();
    if (lat || lng) {
      if (!lat || !lng) {
        setFormError('Заполните обе координаты: широту и долготу.');
        return;
      }
      if (Number.isNaN(Number(lat)) || Number.isNaN(Number(lng))) {
        setFormError('Координаты должны быть числами.');
        return;
      }
    }
    if (lat && (Number(lat) < -90 || Number(lat) > 90)) {
      setFormError('Широта должна быть в диапазоне от -90 до 90.');
      return;
    }
    if (lng && (Number(lng) < -180 || Number(lng) > 180)) {
      setFormError('Долгота должна быть в диапазоне от -180 до 180.');
      return;
    }

    const payload: Record<string, unknown> = {
      name,
      region: form.region.trim() ? form.region.trim() : null,
      description: form.description.trim() ? form.description : null,
      active: form.active,
      latitude: lat ? Number(lat) : null,
      longitude: lng ? Number(lng) : null,
    };

    setSaving(true);
    setFormError('');
    try {
      if (editing) {
        const { data } = await api.patch<AdminWaterBody>(`/admin/waterbodies/${editing.id}`, payload);
        setItems((prev) => prev.map((x) => (x.id === editing.id ? data : x)));
      } else {
        await api.post<AdminWaterBody>('/admin/waterbodies', payload);
        await load();
      }
      setModalOpen(false);
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const toggleActive = async (wb: AdminWaterBody) => {
    setBusyId(wb.id);
    try {
      const { data } = await api.patch<AdminWaterBody>(`/admin/waterbodies/${wb.id}/active`, { active: !wb.active });
      setItems((prev) => prev.map((x) => (x.id === wb.id ? data : x)));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusyId('');
    }
  };

  const remove = async (wb: AdminWaterBody) => {
    if (!window.confirm(`Удалить водоём «${wb.name}»? Действие необратимо.`)) return;
    setBusyId(wb.id);
    try {
      await api.delete(`/admin/waterbodies/${wb.id}`);
      setItems((prev) => prev.filter((x) => x.id !== wb.id));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusyId('');
    }
  };

  return (
    <div className="space-y-5">
      <AdminHeader
        title="Водоёмы"
        subtitle={`${items.length} записей`}
        action={
          <Button onClick={openCreate} tone="brand">
            + Добавить водоём
          </Button>
        }
      />

      <div className="flex flex-wrap items-center gap-3">
        <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Поиск по названию или региону…" className="max-w-sm" />
        <div className="flex rounded-lg border border-slate-200 bg-white p-0.5">
          {(
            [
              ['all', 'Все'],
              ['true', 'Активные'],
              ['false', 'Неактивные'],
            ] as [ActiveFilter, string][]
          ).map(([value, label]) => (
            <button
              key={value}
              onClick={() => setActive(value)}
              className={`rounded-md px-3 py-1.5 text-sm font-semibold transition ${
                active === value ? 'bg-brand-600 text-white' : 'text-slate-600 hover:bg-slate-100'
              }`}
            >
              {label}
            </button>
          ))}
        </div>
      </div>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && (
        <Card className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                <th className="p-3">Водоём</th>
                <th className="p-3">Регион</th>
                <th className="p-3">Координаты</th>
                <th className="p-3">Статус</th>
                <th className="p-3">Добавлен</th>
                <th className="p-3 text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {items.map((w) => (
                <tr key={w.id} className="border-b border-slate-50">
                  <td className="p-3 font-medium text-slate-800">{w.name}</td>
                  <td className="p-3 text-slate-600">{w.region ?? '—'}</td>
                  <td className="p-3 text-slate-500">
                    {w.latitude != null && w.longitude != null
                      ? `${w.latitude.toFixed(5)}, ${w.longitude.toFixed(5)}`
                      : '—'}
                  </td>
                  <td className="p-3">
                    {w.active ? <Badge tone="green">Активен</Badge> : <Badge tone="red">Неактивен</Badge>}
                  </td>
                  <td className="p-3 text-slate-500">{formatDate(w.createdAt)}</td>
                  <td className="p-3">
                    <div className="flex justify-end gap-2">
                      <Button size="sm" tone="outline" onClick={() => openEdit(w)}>
                        Изменить
                      </Button>
                      <Button
                        size="sm"
                        tone={w.active ? 'amber' : 'green'}
                        loading={busyId === w.id}
                        onClick={() => void toggleActive(w)}
                      >
                        {w.active ? 'Деактивировать' : 'Активировать'}
                      </Button>
                      {isAdmin && (
                        <Button size="sm" tone="red" loading={busyId === w.id} onClick={() => void remove(w)}>
                          Удалить
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {items.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-6 text-center text-slate-400">
                    Водоёмы не найдены
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </Card>
      )}

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editing ? `Изменить: ${editing.name}` : 'Новый водоём'}
      >
        <div className="space-y-4">
          {formError && <Alert>{formError}</Alert>}

          <Field label="Название">
            <Input value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="Амурский залив" />
          </Field>

          <Field label="Регион">
            <Input value={form.region} onChange={(e) => setForm({ ...form, region: e.target.value })} placeholder="Приморский край" />
          </Field>

          <Field label="Описание">
            <Textarea
              rows={3}
              value={form.description}
              onChange={(e) => setForm({ ...form, description: e.target.value })}
              placeholder="Краткое описание водоёма…"
            />
          </Field>

          <div className="grid grid-cols-2 gap-4">
            <Field label="Широта" hint="от -90 до 90">
              <Input
                type="number"
                step="any"
                value={form.latitude}
                onChange={(e) => setForm({ ...form, latitude: e.target.value })}
                placeholder="43.11500"
              />
            </Field>
            <Field label="Долгота" hint="от -180 до 180">
              <Input
                type="number"
                step="any"
                value={form.longitude}
                onChange={(e) => setForm({ ...form, longitude: e.target.value })}
                placeholder="131.88500"
              />
            </Field>
          </div>

          <label className="flex items-center gap-2 text-sm text-slate-700">
            <input
              type="checkbox"
              checked={form.active}
              onChange={(e) => setForm({ ...form, active: e.target.checked })}
              className="h-4 w-4 rounded border-slate-300"
            />
            Активен (доступен для выбора при создании заплывов)
          </label>

          <div className="flex justify-end gap-2 pt-2">
            <Button tone="outline" onClick={() => setModalOpen(false)} disabled={saving}>
              Отмена
            </Button>
            <Button onClick={() => void submit()} loading={saving}>
              {editing ? 'Сохранить' : 'Создать'}
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}
