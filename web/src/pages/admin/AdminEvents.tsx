import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../../lib/api';
import type { AdminList, Event } from '../../types';
import { EVENT_STATUSES, type EventStatus } from '../../lib/lists';
import { Alert, Button, Card, Input, Loading, Select } from '../../components/ui';
import { EventStatusBadge } from '../../components/statusBadges';
import { formatDateTime } from '../../lib/format';
import { eventStatusLabel } from '../../lib/labels';
import { AdminHeader, Pagination, StatusSelect } from './shared';
import AdminEventForm from './AdminEventForm';
import { useT } from '../../i18n';

const LIMIT = 25;

export default function AdminEvents() {
  const t = useT(); void t;
  const [items, setItems] = useState<Event[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [editing, setEditing] = useState<Event | null>(null);
  const [deleting, setDeleting] = useState<Event | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
      if (q.trim()) params.set('q', q.trim());
      if (status) params.set('status', status);
      const { data } = await api.get<AdminList<Event>>(`/admin/events?${params.toString()}`);
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

  const setEventStatus = async (id: string, next: EventStatus) => {
    try {
      const { data } = await api.patch<Event>(`/admin/events/${id}/status`, { status: next });
      setItems((prev) => prev.map((e) => (e.id === id ? { ...e, ...data } : e)));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const deleteEvent = async () => {
    if (!deleting) return;
    setDeleteBusy(true);
    setError('');
    try {
      await api.delete(`/admin/events/${deleting.id}`);
      setItems((prev) => prev.filter((e) => e.id !== deleting.id));
      setTotal((t) => Math.max(0, t - 1));
      setDeleting(null);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setDeleteBusy(false);
    }
  };

  return (
    <div className="space-y-5">
      <AdminHeader title="События" subtitle={`${total} заплывов`} />

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
          {EVENT_STATUSES.map((s) => (
            <option key={s} value={s}>
              {eventStatusLabel(s)}
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
                <th className="p-3">Событие</th>
                <th className="p-3">Организатор</th>
                <th className="p-3">Дата</th>
                <th className="p-3">Участники</th>
                <th className="p-3">Статус</th>
                <th className="p-3 text-right">Действия</th>
              </tr>
            </thead>
            <tbody>
              {items.map((e) => (
                <tr key={e.id} className="border-b border-slate-50">
                  <td className="p-3">
                    <Link to={`/events/${e.id}`} className="font-medium text-slate-800 hover:text-brand-700">
                      {e.title}
                    </Link>
                    <div className="text-xs text-slate-400">{e.waterBody?.name ?? '—'}</div>
                  </td>
                  <td className="p-3 text-slate-600">{e.organizer?.name ?? '—'}</td>
                  <td className="p-3 text-slate-600">{formatDateTime(e.eventDate)}</td>
                  <td className="p-3 text-slate-600">{e.participantCount ?? 0}</td>
                  <td className="p-3">
                    <EventStatusBadge status={e.status} />
                  </td>
                  <td className="p-3 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <StatusSelect
                        value={e.status}
                        options={EVENT_STATUSES}
                        labelFor={eventStatusLabel}
                        onChange={(v) => void setEventStatus(e.id, v)}
                      />
                      <Button size="sm" tone="outline" onClick={() => setEditing(e)}>
                        Изменить
                      </Button>
                      <Button size="sm" tone="red" onClick={() => setDeleting(e)}>
                        Удалить
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
              {items.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-6 text-center text-slate-400">
                    События не найдены
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </Card>
      )}

      <Pagination total={total} limit={LIMIT} offset={offset} onChange={setOffset} />

      {editing && (
        <AdminEventForm event={editing} onClose={() => setEditing(null)} onSaved={() => void load()} />
      )}

      {deleting && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
          onClick={() => !deleteBusy && setDeleting(null)}
        >
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold text-slate-900">Удалить событие?</h2>
            <p className="mt-2 text-sm text-slate-500">
              «{deleting.title}» будет удалено вместе с участниками и приглашениями. Действие необратимо.
            </p>
            <div className="mt-5 flex justify-end gap-3">
              <Button tone="outline" onClick={() => setDeleting(null)} disabled={deleteBusy}>
                Отмена
              </Button>
              <Button tone="red" loading={deleteBusy} onClick={() => void deleteEvent()}>
                Удалить
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}