import { useEffect, useState } from 'react';
import { api } from './api';

export interface Country {
  code: string;
  name: string;
  nameEn: string;
}

/** Страна по умолчанию — Россия. */
export const DEFAULT_COUNTRY = 'RU';

let cache: Country[] | null = null;
let inflight: Promise<Country[]> | null = null;

/**
 * Справочник стран грузится один раз на сессию и переиспользуется
 * всеми экранами (профиль, публичный профиль, выбор в форме).
 */
export function loadCountries(): Promise<Country[]> {
  if (cache) return Promise.resolve(cache);
  if (!inflight) {
    inflight = api
      .get<Country[]>('/reference/countries')
      .then((res) => {
        cache = res.data;
        return cache;
      })
      .catch(() => {
        inflight = null;
        return [] as Country[];
      });
  }
  return inflight;
}

export function useCountries() {
  const [countries, setCountries] = useState<Country[]>(cache ?? []);

  useEffect(() => {
    let alive = true;
    loadCountries().then((rows) => {
      if (alive) setCountries(rows);
    });
    return () => {
      alive = false;
    };
  }, []);

  return countries;
}

/** Название страны по коду; неизвестный код показываем как есть. */
export function countryName(countries: Country[], code?: string | null): string {
  if (!code) return '';
  return countries.find((c) => c.code === code)?.name ?? code;
}
