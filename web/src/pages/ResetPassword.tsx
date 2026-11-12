import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { Alert, Button, Field, Input } from '../components/ui';
import type { MessageResult } from '../types';
import { useT } from '../i18n';

export default function ResetPassword() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const t = useT();
  const token = params.get('token') ?? '';
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    if (password !== confirm) {
      setError(t('auth.passwordsMismatch'));
      return;
    }
    setLoading(true);
    try {
      await api.post<MessageResult>('/auth/reset-password', { token, password });
      navigate('/login', { replace: true });
    } catch (err) {
      setError(errorMessage(err, t('auth.resetError')));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-900 via-blue-900 to-slate-900 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-2xl">
        <h1 className="text-2xl font-extrabold text-slate-900">{t('auth.resetTitle')}</h1>
        {!token && <div className="mt-4"><Alert>{t('auth.invalidToken')}</Alert></div>}
        {error && <div className="mt-4"><Alert>{error}</Alert></div>}
        <form onSubmit={submit} className="mt-5 space-y-4">
          <Field label={t('auth.newPassword')} hint={t('auth.passwordMinHint2')}>
            <Input type="password" required minLength={8} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" autoComplete="new-password" />
          </Field>
          <Field label={t('auth.confirmPassword')}>
            <Input type="password" required minLength={8} value={confirm} onChange={(e) => setConfirm(e.target.value)} placeholder="••••••••" autoComplete="new-password" />
          </Field>
          <Button type="submit" className="w-full" loading={loading} disabled={!token}>
            {t('auth.savePassword')}
          </Button>
          <Link to="/login" className="block text-center text-sm font-semibold text-brand-600 hover:text-brand-700">
            {t('auth.backToLogin')}
          </Link>
        </form>
      </div>
    </div>
  );
}