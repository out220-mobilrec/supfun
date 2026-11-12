import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../store/AuthContext';
import { errorMessage } from '../lib/api';
import { Alert, Button, Field, Input } from '../components/ui';
import { useT } from '../i18n';

export default function Register() {
  const { register } = useAuth();
  const t = useT();
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: '', email: '', password: '', confirm: '', city: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const set = (key: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setForm((f) => ({ ...f, [key]: e.target.value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    if (form.password.length < 8) {
      setError(t('auth.passwordMin'));
      return;
    }
    if (form.password !== form.confirm) {
      setError(t('auth.passwordsMismatch'));
      return;
    }
    setLoading(true);
    try {
      await register({
        name: form.name,
        email: form.email,
        password: form.password,
        city: form.city || undefined,
      });
      navigate('/');
    } catch (err) {
      setError(errorMessage(err, t('auth.registerError')));
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
          <h1 className="mt-4 text-2xl font-extrabold text-slate-900">{t('auth.register')}</h1>
          <p className="text-sm text-slate-500">{t('auth.registerSubtitle')}</p>
        </div>
        {error && <div className="mb-4"><Alert>{error}</Alert></div>}
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('auth.name')}>
            <Input required minLength={2} value={form.name} onChange={set('name')} placeholder="Александр" />
          </Field>
          <Field label={t('auth.email')}>
            <Input type="email" required value={form.email} onChange={set('email')} placeholder="you@example.com" />
          </Field>
          <Field label={t('auth.city')}>
            <Input value={form.city} onChange={set('city')} placeholder="Владивосток" />
          </Field>
          <Field label={t('auth.password')}>
            <Input type="password" required minLength={8} value={form.password} onChange={set('password')} placeholder={t('auth.passwordMinHint')} />
          </Field>
          <Field label={t('auth.confirmPassword')}>
            <Input type="password" required minLength={8} value={form.confirm} onChange={set('confirm')} placeholder="••••••••" />
          </Field>
          <Button type="submit" className="w-full" loading={loading}>
            {t('auth.createAccount')}
          </Button>
        </form>
        <p className="mt-5 text-center text-sm text-slate-500">
          {t('auth.hasAccount')}{' '}
          <Link to="/login" className="font-semibold text-brand-600 hover:text-brand-700">
            {t('auth.login')}
          </Link>
        </p>
      </div>
    </div>
  );
}