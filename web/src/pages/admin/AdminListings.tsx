import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../../lib/api';
import type { AdminList, Listing } from '../../types';
import { LISTING_STATUSES, type ListingStatus } from '../../lib/lists';
import { Alert, Card, Input, Loading, Select } from '../../components/ui';
import { ListingStatusBadge } from '../../components/statusBadges';
import { formatPrice } from '../../lib/format';
import { listingStatusLabel } from '../../lib/labels';
import { AdminHeader, Pagination, StatusSelect } from './shared';
import { useT } from '../../i18n';

const LIMIT = 25;

export default function AdminListings() {
  const t = useT(); void t;
  const [items, setItems] = useState<Listing[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [q, setQ] = useState('');
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
      if (q.trim()) params.set('q', q.trim());
      if (status) params.set('status', status);
      const { data } = await api.get<AdminList<Listing>>(`/admin/listings?${params.toString()}`);
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

  const setListingStatus = async (id: string, next: ListingStatus) => {
    try {
      const { data } = await api.patch<Listing>(`/admin/listings/${id}/status`, { status: next });
      setItems((prev) => prev.map((l) => (l.id === id ? data : l)));
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  return (
    <div className="space-y-5">
      <AdminHeader title="Объявления" subtitle={`${total} объявлений`} />

      <div className="flex flex-wrap gap-3">
        <Input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOffset(0);
          }}
          placeholder="Поиск по заголовку…"
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
          {LISTING_STATUSES.map((s) => (
            <option key={s} value={s}>
              {listingStatusLabel(s)}
            </option>
          ))}
        </Select>
      </div>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && (
        <Card className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                <th className="p-3">Объявление</th>
                <th className="p-3">Продавец</th>
                <th className="p-3">Цена</th>
                <th className="p-3">Статус</th>
                <th className="p-3 text-right">Изменить статус</th>
              </tr>
            </thead>
            <tbody>
              {items.map((l) => (
                <tr key={l.id} className="border-b border-slate-50">
                  <td className="p-3">
                    <Link to={`/marketplace/${l.id}`} className="font-medium text-slate-800 hover:text-brand-700">
                      {l.title}
                    </Link>
                    <div className="text-xs text-slate-400">{l.city ?? '—'}</div>
                  </td>
                  <td className="p-3 text-slate-600">{l.seller?.name ?? '—'}</td>
                  <td className="p-3 text-slate-600">{formatPrice(l.price, l.currency)}</td>
                  <td className="p-3">
                    <ListingStatusBadge status={l.status} />
                  </td>
                  <td className="p-3 text-right">
                    <div className="flex justify-end">
                      <StatusSelect
                        value={l.status}
                        options={LISTING_STATUSES}
                        labelFor={listingStatusLabel}
                        onChange={(v) => void setListingStatus(l.id, v)}
                      />
                    </div>
                  </td>
                </tr>
              ))}
              {items.length === 0 && (
                <tr>
                  <td colSpan={5} className="p-6 text-center text-slate-400">
                    Объявления не найдены
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </Card>
      )}

      <Pagination total={total} limit={LIMIT} offset={offset} onChange={setOffset} />
    </div>
  );
}