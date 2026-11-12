import type { ReactNode } from 'react';
import { Select } from '../../components/ui';
import { useT } from '../../i18n';

export function AdminHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">{title}</h1>
        {subtitle && <p className="mt-0.5 text-sm text-slate-500">{subtitle}</p>}
      </div>
      {action}
    </div>
  );
}

export function StatusSelect<T extends string>({
  value,
  options,
  labelFor,
  onChange,
  disabled,
}: {
  value: T;
  options: T[];
  labelFor: (v: T) => string;
  onChange: (v: T) => void;
  disabled?: boolean;
}) {
  return (
    <Select
      value={value}
      disabled={disabled}
      onChange={(e) => onChange(e.target.value as T)}
      className="max-w-[180px] !py-1 !text-xs"
    >
      {options.map((o) => (
        <option key={o} value={o}>
          {labelFor(o)}
        </option>
      ))}
    </Select>
  );
}

export function Pagination({ total, limit, offset, onChange }: { total: number; limit: number; offset: number; onChange: (offset: number) => void }) {
  const t = useT();
  const pages = Math.max(1, Math.ceil(total / limit));
  const current = Math.floor(offset / limit) + 1;
  return (
    <div className="flex items-center justify-between pt-4 text-sm text-slate-500">
      <span>
        {total} {t('admin.records')} · {t('admin.page')} {current} {t('admin.of')} {pages}
      </span>
      <div className="flex gap-2">
        <button
          disabled={offset <= 0}
          onClick={() => onChange(Math.max(0, offset - limit))}
          className="rounded-lg border border-slate-300 px-3 py-1 font-medium disabled:opacity-40"
        >
          {t('admin.prev')}
        </button>
        <button
          disabled={offset + limit >= total}
          onClick={() => onChange(offset + limit)}
          className="rounded-lg border border-slate-300 px-3 py-1 font-medium disabled:opacity-40"
        >
          {t('admin.next')}
        </button>
      </div>
    </div>
  );
}
