import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../../lib/api';
import { useAuth } from '../../store/AuthContext';
import type { AdminList, User } from '../../types';
import { USER_ROLES, type UserRole } from '../../lib/lists';
import { Alert, Button, Card, Input, Loading, Select } from '../../components/ui';
import { Avatar } from '../../components/Avatar';
import { BannedBadge, RoleBadge } from '../../components/statusBadges';
import { formatDate } from '../../lib/format';
import { roleLabel } from '../../lib/labels';
import { AdminHeader, Pagination } from './shared';
import { useT } from '../../i18n';

const LIMIT = 25;

export default function AdminUsers() {
  const t = useT(); void t;
  const { user: me } = useAuth();
  const isAdmin = me?.role === 'admin';
  const [items, setItems] = useState<User[]>([]);
  const [total, setTotal] = useState(0);
  const [offset, setOffset] = useState(0);
  const [q, setQ] = useState('');
  const [role, setRole] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ limit: String(LIMIT), offset: String(offset) });
      if (q.trim()) params.set('q', q.trim());
      if (role) params.set('role', role);
      const { data } = await api.get<AdminList<User>>(`/admin/users?${params.toString()}`);
      setItems(data.items);
      setTotal(data.total);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [q, role, offset]);

  useEffect(() => {
    const t = setTimeout(() => void load(), 250);
    return () => clearTimeout(t);
  }, [load]);

  const setUserRole = async (id: string, next: UserRole) => {
    setBusyId(id);
    try {
      const { data } = await api.patch<User>(`/admin/users/${id}/role`, { role: next });
      setItems((prev) => prev.map((u) => (u.id === id ? data : u)));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusyId('');
    }
  };

  const toggleBan = async (u: User) => {
    setBusyId(u.id);
    try {
      const { data } = await api.post<User>(`/admin/users/${u.id}/${u.isBanned ? 'unban' : 'ban'}`);
      setItems((prev) => prev.map((x) => (x.id === u.id ? data : x)));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusyId('');
    }
  };

  return (
    <div className="space-y-5">
      <AdminHeader title="Пользователи" subtitle={`${total} аккаунтов`} />

      <div className="flex flex-wrap gap-3">
        <Input
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOffset(0);
          }}
          placeholder="Поиск по имени или email…"
          className="max-w-sm"
        />
        <Select
          value={role}
          onChange={(e) => {
            setRole(e.target.value);
            setOffset(0);
          }}
          className="max-w-[180px]"
        >
          <option value="">Все роли</option>
          {USER_ROLES.map((r) => (
            <option key={r} value={r}>
              {roleLabel(r)}
            </option>
          ))}
        </Select>
      </div>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && (
        <Card className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs uppercase tracking-wide text-slate-400">
                <th className="p-3">Пользователь</th>
                <th className="p-3">Роль</th>
                <th className="p-3">Статус</th>
                <th className="p-3">XP</th>
                <th className="p-3">Регистрация</th>
                {isAdmin && <th className="p-3 text-right">Действия</th>}
              </tr>
            </thead>
            <tbody>
              {items.map((u) => (
                <tr key={u.id} className="border-b border-slate-50">
                  <td className="p-3">
                    <Link to={`/users/${u.id}`} className="flex items-center gap-2">
                      <Avatar user={u} size="sm" />
                      <div className="min-w-0">
                        <div className="truncate font-medium text-slate-800">{u.name}</div>
                        <div className="truncate text-xs text-slate-400">{u.email}</div>
                      </div>
                    </Link>
                  </td>
                  <td className="p-3">
                    {isAdmin && u.id !== me?.id ? (
                      <Select
                        value={u.role}
                        disabled={busyId === u.id}
                        onChange={(e) => void setUserRole(u.id, e.target.value as UserRole)}
                        className="max-w-[140px] !py-1 !text-xs"
                      >
                        {USER_ROLES.map((r) => (
                          <option key={r} value={r}>
                            {roleLabel(r)}
                          </option>
                        ))}
                      </Select>
                    ) : (
                      <RoleBadge role={u.role} />
                    )}
                  </td>
                  <td className="p-3">
                    <BannedBadge banned={u.isBanned} />
                    {!u.isBanned && <span className="text-xs text-emerald-600">Активен</span>}
                  </td>
                  <td className="p-3 text-slate-600">{u.xp}</td>
                  <td className="p-3 text-slate-500">{formatDate(u.createdAt)}</td>
                  {isAdmin && (
                    <td className="p-3 text-right">
                      {u.id !== me?.id && (
                        <Button
                          size="sm"
                          tone={u.isBanned ? 'green' : 'red'}
                          loading={busyId === u.id}
                          onClick={() => void toggleBan(u)}
                        >
                          {u.isBanned ? 'Разбанить' : 'Забанить'}
                        </Button>
                      )}
                    </td>
                  )}
                </tr>
              ))}
              {items.length === 0 && (
                <tr>
                  <td colSpan={6} className="p-6 text-center text-slate-400">
                    Пользователи не найдены
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