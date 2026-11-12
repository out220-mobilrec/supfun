import { useEffect } from 'react';
import type { ButtonHTMLAttributes, InputHTMLAttributes, MouseEvent, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from 'react';
import { relativeTime } from '../lib/format';

export type Tone =
  | 'brand'
  | 'green'
  | 'red'
  | 'amber'
  | 'slate'
  | 'blue'
  | 'violet'
  | 'cyan'
  | 'outline';

const toneClasses: Record<Tone, string> = {
  brand: 'bg-brand-600 text-white hover:bg-brand-700',
  green: 'bg-emerald-500 text-white hover:bg-emerald-600',
  red: 'bg-red-500 text-white hover:bg-red-600',
  amber: 'bg-amber-500 text-white hover:bg-amber-600',
  slate: 'bg-slate-200 text-slate-800 hover:bg-slate-300',
  blue: 'bg-blue-500 text-white hover:bg-blue-600',
  violet: 'bg-violet-500 text-white hover:bg-violet-600',
  cyan: 'bg-cyan-500 text-white hover:bg-cyan-600',
  outline: 'border border-slate-300 text-slate-700 bg-white hover:bg-slate-50',
};

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  tone?: Tone;
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
}

export function Button({ tone = 'brand', size = 'md', loading, className = '', children, disabled, ...rest }: ButtonProps) {
  const sizes = {
    sm: 'px-2.5 py-1.5 text-xs',
    md: 'px-4 py-2 text-sm',
    lg: 'px-5 py-2.5 text-base',
  } as const;
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-lg font-semibold transition focus:outline-none focus:ring-2 focus:ring-brand-400 focus:ring-offset-1 disabled:opacity-50 disabled:cursor-not-allowed ${toneClasses[tone]} ${sizes[size]} ${className}`}
      disabled={disabled || loading}
      {...rest}
    >
      {loading && <Spinner className="w-3.5 h-3.5" />}
      {children}
    </button>
  );
}

const fieldBase =
  'w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-900 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-brand-400 focus:border-brand-500 disabled:bg-slate-100';

export function Input(props: InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={`${fieldBase} ${props.className ?? ''}`} />;
}

export function Textarea(props: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea {...props} className={`${fieldBase} ${props.className ?? ''}`} />;
}

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return <select {...props} className={`${fieldBase} ${props.className ?? ''}`} />;
}

export function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</span>
      {children}
      {hint && <span className="mt-1 block text-xs text-slate-400">{hint}</span>}
    </label>
  );
}

const badgeTones: Record<Tone, string> = {
  brand: 'bg-brand-50 text-brand-700 border-brand-200',
  green: 'bg-emerald-50 text-emerald-700 border-emerald-200',
  red: 'bg-red-50 text-red-700 border-red-200',
  amber: 'bg-amber-50 text-amber-700 border-amber-200',
  slate: 'bg-slate-100 text-slate-600 border-slate-200',
  blue: 'bg-blue-50 text-blue-700 border-blue-200',
  violet: 'bg-violet-50 text-violet-700 border-violet-200',
  cyan: 'bg-cyan-50 text-cyan-700 border-cyan-200',
  outline: 'bg-white text-slate-600 border-slate-300',
};

export function Badge({ tone = 'slate', children, className = '' }: { tone?: Tone; children: ReactNode; className?: string }) {
  return (
    <span className={`inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-xs font-medium ${badgeTones[tone]} ${className}`}>
      {children}
    </span>
  );
}

export function Spinner({ className = 'w-5 h-5' }: { className?: string }) {
  return (
    <svg className={`animate-spin ${className}`} viewBox="0 0 24 24" fill="none" aria-label="Loading">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
    </svg>
  );
}

export function Loading({ label }: { label?: string }) {
  const fallback = typeof window !== 'undefined' && localStorage.getItem('sf_locale') === 'en' ? 'Loading…' : 'Загрузка…';
  const text = label ?? fallback;
  return (
    <div className="flex items-center justify-center gap-2 py-12 text-slate-500">
      <Spinner />
      <span className="text-sm">{text}</span>
    </div>
  );
}

export function EmptyState({ title, hint, action }: { title: string; hint?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white px-6 py-14 text-center">
      <div className="text-4xl">🌊</div>
      <h3 className="mt-3 text-base font-semibold text-slate-800">{title}</h3>
      {hint && <p className="mt-1 max-w-sm text-sm text-slate-500">{hint}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}

export function Card({ children, className = '', onClick }: { children: ReactNode; className?: string; onClick?: (e: MouseEvent<HTMLDivElement>) => void }) {
  return (
    <div
      onClick={onClick}
      className={`rounded-2xl border border-slate-200 bg-white shadow-sm ${onClick ? 'cursor-pointer transition hover:shadow-md hover:border-brand-300' : ''} ${className}`}
    >
      {children}
    </div>
  );
}

export function PageHeader({ title, subtitle, action }: { title: string; subtitle?: string; action?: ReactNode }) {
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

export function StatCard({ label, value, tone = 'brand' }: { label: string; value: ReactNode; tone?: Tone }) {
  const dot: Record<Tone, string> = {
    brand: 'bg-brand-500',
    green: 'bg-emerald-500',
    red: 'bg-red-500',
    amber: 'bg-amber-500',
    slate: 'bg-slate-400',
    blue: 'bg-blue-500',
    violet: 'bg-violet-500',
    cyan: 'bg-cyan-500',
    outline: 'bg-slate-300',
  };
  return (
    <Card className="p-4">
      <div className="flex items-center gap-2">
        <span className={`h-2.5 w-2.5 rounded-full ${dot[tone]}`} />
        <span className="text-xs font-semibold uppercase tracking-wide text-slate-500">{label}</span>
      </div>
      <div className="mt-2 text-2xl font-bold text-slate-900">{value}</div>
    </Card>
  );
}

export function ProgressBar({ value, className = '' }: { value: number; className?: string }) {
  const pct = Math.max(0, Math.min(100, value));
  return (
    <div className={`h-2 w-full overflow-hidden rounded-full bg-slate-200 ${className}`}>
      <div className="h-full rounded-full bg-brand-500 transition-all" style={{ width: `${pct}%` }} />
    </div>
  );
}

export function Modal({
  open,
  onClose,
  title,
  children,
  wide,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  wide?: boolean;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4" onClick={onClose}>
      <div
        className={`max-h-[90vh] w-full ${wide ? 'max-w-3xl' : 'max-w-lg'} overflow-y-auto rounded-2xl bg-white p-6 shadow-xl`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-bold text-slate-900">{title}</h2>
          <button className="text-slate-400 hover:text-slate-600" onClick={onClose} aria-label="Close">
            <svg className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
            </svg>
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Alert({ tone = 'red', children }: { tone?: 'red' | 'green' | 'amber' | 'slate'; children: ReactNode }) {
  const map = {
    red: 'border-red-200 bg-red-50 text-red-700',
    green: 'border-emerald-200 bg-emerald-50 text-emerald-700',
    amber: 'border-amber-200 bg-amber-50 text-amber-700',
    slate: 'border-slate-200 bg-slate-50 text-slate-600',
  } as const;
  return <div className={`rounded-lg border px-3 py-2 text-sm ${map[tone]}`}>{children}</div>;
}

export function TimeAgo({ value }: { value: string | Date | null | undefined }) {
  return <span>{relativeTime(value)}</span>;
}