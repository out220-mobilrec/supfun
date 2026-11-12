import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { Alert, Button, Field, Input } from '../components/ui';
import type { MessageResult } from '../types';
import { useT } from '../i18n';

export default function ForgotPassword() {
  const t = useT();
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [devToken, setDevToken] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const [loading, setLoading] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { data } = await api.post<MessageResult>('/auth/forgot-password', { email });
      setDevToken(data.devToken ?? null);
      setSent(true);
    } catch (err) {
      setError(errorMessage(err, t('auth.forgotError')));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-900 via-blue-900 to-slate-900 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-2xl">
        <h1 className="text-2xl font-extrabold text-slate-900">{t('auth.resetPassword')}</h1>
        <p className="mt-1 text-sm text-slate-500">{t('auth.forgotHint')}</p>
        {error && <div className="mt-4"><Alert>{error}</Alert></div>}
        {sent ? (
          <div className="mt-5 space-y-4">
            <Alert tone="green">{t('auth.forgotSent')}</Alert>
            {devToken && (
              <div className="rounded-lg bg-slate-50 p-3 text-xs text-slate-600">
                <p className="mb-2 font-semibold">{t('auth.devMode')}</p>
                <Link
                  to={`/reset-password?token=${devToken}`}
                  className="break-all font-mono text-brand-600 hover:underline"
                >
                  /reset-password?token={devToken}
                </Link>
              </div>
            )}
            <Link to="/login" className="block text-center text-sm font-semibold text-brand-600 hover:text-brand-700">
              {t('auth.backToLogin')}
            </Link>
          </div>
        ) : (
          <form onSubmit={submit} className="mt-5 space-y-4">
            <Field label={t('auth.email')}>
              <Input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" autoComplete="email" />
            </Field>
            <Button type="submit" className="w-full" loading={loading}>
              {t('auth.forgotSendLink')}
            </Button>
            <Link to="/login" className="block text-center text-sm font-semibold text-brand-600 hover:text-brand-700">
              {t('auth.backToLogin')}
            </Link>
          </form>
        )}
      </div>
    </div>
  );
}