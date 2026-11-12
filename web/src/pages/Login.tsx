import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../store/AuthContext';
import { errorMessage } from '../lib/api';
import { Alert, Button, Field, Input } from '../components/ui';
import { useT } from '../i18n';

export default function Login() {
  const { login } = useAuth();
  const t = useT();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      setError(errorMessage(err, t('auth.loginError')));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-900 via-blue-900 to-slate-900 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 shadow-2xl">
        <div className="mb-6 text-center">
          <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-brand-400 to-blue-600 text-2xl font-black text-white">
            S
          </div>
          <h1 className="mt-4 text-2xl font-extrabold text-slate-900">SUP FUN</h1>
          <p className="text-sm text-slate-500">{t('auth.loginSubtitle')}</p>
        </div>
        {error && <div className="mb-4"><Alert>{error}</Alert></div>}
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('auth.email')}>
            <Input type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" autoComplete="email" />
          </Field>
          <Field label={t('auth.password')}>
            <Input type="password" required value={password} onChange={(e) => setPassword(e.target.value)} placeholder="••••••••" autoComplete="current-password" />
          </Field>
          <div className="text-right">
            <Link to="/forgot-password" className="text-sm font-medium text-brand-600 hover:text-brand-700">
              {t('auth.forgotPassword')}
            </Link>
          </div>
          <Button type="submit" className="w-full" loading={loading}>
            {t('auth.login')}
          </Button>
        </form>
        <p className="mt-5 text-center text-sm text-slate-500">
          {t('auth.noAccount')}{' '}
          <Link to="/register" className="font-semibold text-brand-600 hover:text-brand-700">
            {t('auth.createAccount')}
          </Link>
        </p>
      </div>
    </div>
  );
}