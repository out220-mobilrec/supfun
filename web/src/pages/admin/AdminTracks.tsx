import { useCallback, useEffect, useState } from 'react';
import { api, errorMessage } from '../../lib/api';
import { useAuth } from '../../store/AuthContext';
import type { AdminList, AdminWaterBody, Track } from '../../types';
import {
  TRACK_DIFFICULTIES,
  TRACK_STATUSES,
  type TrackDifficulty,
  type TrackStatus,
} from '../../lib/lists';
import {
  Alert,
  Button,
  Card,
  Field,
  Input,
  Loading,
  Modal,
  Select,
} from '../../components/ui';
import { TrackStatusBadge } from '../../components/statusBadges';
import { formatDate, formatDistance } from '../../lib/format';
import { trackDifficultyLabel, trackStatusLabel } from '../../lib/labels';
import { AdminHeader, Pagination, StatusSelect } from './shared';
import { useT } from '../../i18n';

const LIMIT = 25;

interface EditState {
  name: string;
  waterBodyId: string;
  difficulty: TrackDifficulty | '';
}

export default function AdminTracks() {
  const t = useT(); void t;
  const { user: me } = useAuth();
  const isAdmin = me?.role === 'admin';
  const [items, setItems] = useState<Track[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [waterbodies, setWaterbodies] = useState<AdminWaterBody[]>([]);

  const [editing, setEditing] = useState<Track | null>(null);
  const [form, setForm] = useState<EditState>({ name: '', waterBodyId: '', difficulty: '' });
  const [formError, setFormError] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
      if (q.trim()) params.set('q', q.trim());
      if (status) params.set('status', status);
      const { data } = await api.get<AdminList<Track>>(`/admin/tracks?${params.toString()}`);
      setItems(data.items);
      setTotal(data.total);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [q, status, offset]);

  useEffect(() => {
    const t = setTimeout(() => void load(), 250);
    return () => clearTimeout(t);
  }, [load]);

  useEffect(() => {
    void api
      .get<AdminWaterBody[]>('/admin/waterbodies')
      .then(({ data }) => setWaterbodies(data))
      .catch(() => undefined);
  }, []);

  const setTrackStatus = async (id: string, next: TrackStatus) => {
    try {
      const { data } = await api.patch<Track>(`/admin/tracks/${id}/status`, { status: next });
      setItems((prev) => prev.map((t) => (t.id === id ? { ...t, ...data } : t)));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const openEdit = (track: Track) => {
    setEditing(track);
    setForm({
      name: track.name ?? '',
      waterBodyId: track.waterBodyId ?? '',
      difficulty: track.difficulty ?? '',
    });
    setFormError('');
  };

  const submitEdit = async () => {
    if (!editing) return;
    const name = form.name.trim();
    if (!name) {
      setFormError('Укажите название маршрута.');
      return;
    }
    setSaving(true);
    setFormError('');
    try {
      const payload = {
        name,
        waterBodyId: form.waterBodyId || null,
        difficulty: form.difficulty || null,
      };
      const { data } = await api.patch<Track>(`/tracks/${editing.id}`, payload);
      setItems((prev) => prev.map((t) => (t.id === editing.id ? { ...t, ...data } : t)));
      setEditing(null);
    } catch (err) {
      setFormError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (track: Track) => {
    const title = track.name ?? 'без названия';
    if (!window.confirm(`Удалить маршрут «${title}»? Действие необратимо.`)) return;
    try {
      await api.delete(`/tracks/${track.id}`);
      setItems((prev) => prev.filter((t) => t.id !== track.id));
      setTotal((prev) => Math.max(0, prev - 1));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <div className="space-y-5">
      <AdminHeader title="Треки" subtitle={`${total} маршрутов`} />

      <p className="text-xs text-slate-500">
        Править параметры чужих маршрутов могут администратор и модератор, удалять — только администратор.
      </p>

      <div className="flex flex-wrap gap-3">
        <Input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOffset(0);
          }}
          placeholder="Поиск по названию…"
          className="max-w-sm"
        />
        <Select
          value={status}
          onChange={(e) => {
            setStatus(e.target.value);
            setOffset(0);
          }}
          className="max-w-[180px]"
        >
          <option value="">Все статусы</option>
          {TRACK_STATUSES.map((s) => (
            <option key={s} value={s}>
              {trackStatusLabel(s)}
            </option>
          ))}
        </Select>
      </div>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && (
        <Card className="overflow-x-auto">
          <table className="w-full min-w-[820px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                <th className="p-3">Маршрут</th>
                <th className="p-3">Автор</th>
                <th className="p-3">Дистанция</th>
                <th className="p-3">Старт</th>
                <th className="p-3">Статус</th>
                <th className="p-3 text-right">Изменить статус</th>
                <th className="p-3 text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {items.map((t) => (
                <tr key={t.id} className="border-b border-slate-50">
                  <td className="p-3">
                    <div className="font-medium text-slate-800">{t.name ?? 'Без названия'}</div>
                    <div className="text-xs text-slate-400">{t.waterBody?.name ?? '—'}</div>
                  </td>
                  <td className="p-3 text-slate-600">{t.user?.name ?? '—'}</td>
                  <td className="p-3 text-slate-600">{formatDistance(t.distanceMeters)}</td>
                  <td className="p-3 text-slate-600">{formatDate(t.startedAt)}</td>
                  <td className="p-3">
                    <TrackStatusBadge status={t.status} />
                  </td>
                  <td className="p-3 text-right">
                    <div className="flex justify-end">
                      <StatusSelect
                        value={t.status}
                        options={TRACK_STATUSES}
                        labelFor={trackStatusLabel}
                        onChange={(v) => void setTrackStatus(t.id, v)}
                      />
                    </div>
                  </td>
                  <td className="p-3 text-right whitespace-nowrap">
                    <div className="flex justify-end gap-2">
                      <Button size="sm" tone="outline" onClick={() => openEdit(t)}>
                        Править
                      </Button>
                      {isAdmin && (
                        <Button size="sm" tone="red" onClick={() => void remove(t)}>
                          Удалить
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
              {items.length === 0 && (
                <tr>
                  <td colSpan={7} className="p-6 text-center text-slate-400">
                    Треки не найдены
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </Card>
      )}

      <Pagination total={total} limit={LIMIT} offset={offset} onChange={setOffset} />

      <Modal
        open={Boolean(editing)}
        onClose={() => setEditing(null)}
        title={editing?.name ? `Правка: ${editing.name}` : 'Правка маршрута'}
      >
        <div className="space-y-4">
          {editing && (
            <div className="text-sm text-slate-500">
              Автор: <span className="font-semibold text-slate-700">{editing.user?.name ?? '—'}</span> · Старт:{' '}
              {formatDate(editing.startedAt)} · {formatDistance(editing.distanceMeters)}
            </div>
          )}
          <Field label="Название">
            <Input
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              placeholder="Название маршрута"
            />
          </Field>
          <Field label="Водоём">
            <Select
              value={form.waterBodyId}
              onChange={(e) => setForm((f) => ({ ...f, waterBodyId: e.target.value }))}
            >
              <option value="">Не указан</option>
              {waterbodies.map((wb) => (
                <option key={wb.id} value={wb.id}>
                  {wb.name}
                  {wb.region ? ` — ${wb.region}` : ''}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Сложность">
            <Select
              value={form.difficulty}
              onChange={(e) =>
                setForm((f) => ({ ...f, difficulty: e.target.value as TrackDifficulty | '' }))
              }
            >
              <option value="">Не указана</option>
              {TRACK_DIFFICULTIES.map((d) => (
                <option key={d} value={d}>
                  {trackDifficultyLabel(d)}
                </option>
              ))}
            </Select>
          </Field>
          {formError && <Alert>{formError}</Alert>}
          <div className="flex justify-end gap-2 pt-1">
            <Button tone="outline" onClick={() => setEditing(null)} disabled={saving}>
              Отмена
            </Button>
            <Button onClick={() => void submitEdit()} loading={saving}>
              Сохранить
            </Button>
          </div>
        </div>
      </Modal>
    </div>
  );
}