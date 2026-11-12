import axios, { AxiosError } from 'axios';

const TOKEN_KEY = 'sf_token';
const REFRESH_KEY = 'sf_refresh';
const USER_KEY = 'sf_user';

const baseURL = import.meta.env.VITE_API_BASE || '/api';
const PUBLIC_PATHS = [
  '/login',
  '/register',
  '/forgot-password',
  '/reset-password',
  '/verify-email',
];

export const api = axios.create({
  baseURL,
  headers: { 'Content-Type': 'application/json' },
});

const refreshClient = axios.create({
  baseURL,
  headers: { 'Content-Type': 'application/json' },
});

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = localStorage.getItem(REFRESH_KEY);
  if (!refreshToken) return null;
  if (!refreshPromise) {
    refreshPromise = refreshClient
      .post<{ accessToken: string; refreshToken: string; user: unknown }>(
        '/auth/refresh',
        { refreshToken },
      )
      .then(({ data }) => {
        setSession(data.accessToken, data.user, data.refreshToken);
        return data.accessToken;
      })
      .catch(() => {
        clearSession();
        return null;
      })
      .finally(() => {
        refreshPromise = null;
      });
  }
  return refreshPromise;
}

api.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const original = error.config as (typeof error.config & { _retry?: boolean }) | undefined;
    const status = error.response?.status;
    const isAuthCall = original?.url?.startsWith('/auth/') ?? false;

    if (status === 401 && original && !original._retry && !isAuthCall) {
      original._retry = true;
      const token = await refreshAccessToken();
      if (token) {
        original.headers = original.headers ?? {};
        original.headers.Authorization = `Bearer ${token}`;
        return api(original);
      }
    }

    if (status === 401 && original && !isAuthCall) {
      const path = window.location.pathname;
      if (!PUBLIC_PATHS.includes(path)) {
        clearSession();
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  },
);

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setSession(token: string, user: unknown, refreshToken?: string): void {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
  if (refreshToken) {
    localStorage.setItem(REFRESH_KEY, refreshToken);
  }
}

export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_KEY);
}

export function clearSession(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_KEY);
  localStorage.removeItem(USER_KEY);
}

export function getStoredUser<T>(): T | null {
  const raw = localStorage.getItem(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

export async function uploadImage(file: File): Promise<string> {
  const formData = new FormData();
  formData.append('file', file);
  const { data } = await api.post<{ url: string }>('/uploads/image', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return data.url;
}

export function errorMessage(error: unknown, fallback = 'Не удалось выполнить запрос'): string {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { message?: string | string[] } | undefined;
    const statusCode = error.response?.status;
    if (Array.isArray(data?.message)) {
      return data!.message!.join(', ');
    }
    if (typeof data?.message === 'string') {
      return data.message;
    }
    if (statusCode === 401) return 'Не авторизован';
    if (statusCode === 403) return 'Недостаточно прав';
    if (statusCode === 404) return 'Не найдено';
    if (statusCode === 429) return 'Слишком много запросов. Подождите.';
    if (statusCode && statusCode >= 500) return 'Ошибка сервера';
  }
  return fallback;
}