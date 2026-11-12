function locale(): string {
  try {
    return localStorage.getItem('sf_locale') === 'en' ? 'en-US' : 'ru-RU';
  } catch {
    return 'ru-RU';
  }
}
function isEn() {
  return locale().startsWith('en');
}

function df(opts: Intl.DateTimeFormatOptions) {
  return new Intl.DateTimeFormat(locale(), opts);
}

export function formatDate(value: string | Date | null | undefined): string {
  if (!value) return '—';
  return df({ day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(value));
}

export function formatDateTime(value: string | Date | null | undefined): string {
  if (!value) return '—';
  const d = new Date(value);
  return `${df({ day: 'numeric', month: 'short', year: 'numeric' }).format(d)}, ${df({ hour: '2-digit', minute: '2-digit' }).format(d)}`;
}

export function formatTime(value: string | Date | null | undefined): string {
  if (!value) return '—';
  return df({ hour: '2-digit', minute: '2-digit' }).format(new Date(value));
}

export function relativeTime(value: string | Date | null | undefined): string {
  if (!value) return '—';
  const en = isEn();
  const diff = Date.now() - new Date(value).getTime();
  const sec = Math.floor(diff / 1000);
  if (sec < 60) return en ? 'just now' : 'только что';
  const min = Math.floor(sec / 60);
  if (min < 60) return en ? `${min} min ago` : `${min} мин назад`;
  const h = Math.floor(min / 60);
  if (h < 24) return en ? `${h} h ago` : `${h} ч назад`;
  const d = Math.floor(h / 24);
  if (d < 30) return en ? `${d} d ago` : `${d} дн назад`;
  return formatDate(value);
}

export function formatKm(meters: number | null | undefined): string {
  if (meters == null) return '—';
  return isEn() ? `${(meters / 1000).toFixed(1)} km` : `${(meters / 1000).toFixed(1)} км`;
}

export function formatDistance(meters: number | null | undefined): string {
  return formatKm(meters);
}

export function formatDuration(seconds: number | null | undefined): string {
  if (seconds == null) return '—';
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  const mm = String(m).padStart(2, '0');
  const ss = String(s).padStart(2, '0');
  return h > 0 ? `${h}:${mm}:${ss}` : `${m}:${ss}`;
}

export function formatSpeed(kph: number | null | undefined): string {
  if (kph == null) return '—';
  return isEn() ? `${kph.toFixed(1)} km/h` : `${kph.toFixed(1)} км/ч`;
}

export function formatPrice(price: number | null | undefined, currency = 'RUB'): string {
  if (price == null) return isEn() ? 'Price on request' : 'Цена по запросу';
  const symbols: Record<string, string> = { RUB: '₽', USD: '$', EUR: '€' };
  const sym = symbols[currency] ?? ` ${currency}`;
  return `${new Intl.NumberFormat(locale()).format(price)} ${sym}`;
}

export function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

/** ISO -> значение для <input type="datetime-local"> (в локальном времени) */
export function toDateTimeLocal(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** значение <input type="datetime-local"> -> ISO */
export function fromDateTimeLocal(value: string): string | null {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}