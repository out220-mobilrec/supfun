import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';
import { useAuth } from '../store/AuthContext';
import { en } from './en';
import { ru } from './ru';
import type { I18nKey } from './ru';

export type Locale = 'ru' | 'en';

const DICTS: Record<Locale, Record<string, string>> = { ru, en };
const STORAGE_KEY = 'sf_locale';

function normalizeLocale(v: unknown): Locale {
  return v === 'en' ? 'en' : 'ru';
}

interface I18nValue {
  locale: Locale;
  t: (key: I18nKey | string, fallback?: string) => string;
}

const I18nContext = createContext<I18nValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const { user } = useAuth();
  const [local, setLocal] = useState<Locale>(() => normalizeLocale(localStorage.getItem(STORAGE_KEY)));

  useEffect(() => {
    if (user?.locale) {
      const next = normalizeLocale(user.locale);
      setLocal(next);
      localStorage.setItem(STORAGE_KEY, next);
    }
  }, [user?.locale]);

  const locale = useMemo<Locale>(() => normalizeLocale(user?.locale ?? local), [user?.locale, local]);

  const t = useCallback(
    (key: string, fallback?: string) => {
      const dict = DICTS[locale];
      return dict[key] ?? DICTS.ru[key] ?? fallback ?? key;
    },
    [locale],
  );

  const value = useMemo(() => ({ locale, t }), [locale, t]);
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nValue {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n must be used within I18nProvider');
  return ctx;
}

export function useT() {
  return useI18n().t;
}

export type { I18nKey };