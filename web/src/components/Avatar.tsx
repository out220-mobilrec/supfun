import type { User } from '../types';
import { initials } from '../lib/format';

const palette = [
  'bg-cyan-500',
  'bg-sky-500',
  'bg-indigo-500',
  'bg-violet-500',
  'bg-fuchsia-500',
  'bg-rose-500',
  'bg-emerald-500',
  'bg-amber-500',
];

function colorFor(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i += 1) {
    h = (h * 31 + name.charCodeAt(i)) >>> 0;
  }
  return palette[h % palette.length];
}

export function Avatar({ user, size = 'md', online }: { user: Pick<User, 'name' | 'avatarUrl'> | null | undefined; size?: 'sm' | 'md' | 'lg' | 'xl'; online?: boolean }) {
  const sizes = {
    sm: 'h-7 w-7 text-[10px]',
    md: 'h-9 w-9 text-xs',
    lg: 'h-12 w-12 text-sm',
    xl: 'h-16 w-16 text-lg',
  } as const;
  const name = user?.name?.trim() || '?';
  const url = user?.avatarUrl;
  const cls = url ? undefined : colorFor(name);
  return (
    <div className="relative inline-flex shrink-0">
      {url ? (
        <img src={url} alt={name} className={`${sizes[size]} rounded-full object-cover ring-1 ring-slate-200`} />
      ) : (
        <div className={`${sizes[size]} flex items-center justify-center rounded-full font-bold text-white ${cls}`}>
          {initials(name)}
        </div>
      )}
      {online !== undefined && (
        <span
          className={`absolute bottom-0 right-0 block h-2.5 w-2.5 rounded-full ring-2 ring-white ${online ? 'bg-emerald-500' : 'bg-slate-300'}`}
        />
      )}
    </div>
  );
}