import { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { Alert, Button } from '../components/ui';
import { useT } from '../i18n';

type Status = 'loading' | 'ok' | 'error';

export default function VerifyEmail() {
  const [params] = useSearchParams();
  const t = useT();
  const token = params.get('token') ?? '';
  const [status, setStatus] = useState<Status>(token ? 'loading' : 'error');
  const [error, setError] = useState(token ? '' : t('auth.invalidToken'));

  useEffect(() => {
    if (!token) return;
    let mounted = true;
    api
      .post('/auth/verify-email', { token })
      .then(() => {
        if (mounted) setStatus('ok');
      })
      .catch((err) => {
        if (mounted) {
          setError(errorMessage(err, t('auth.verifyError')));
          setStatus('error');
        }
      });
    return () => {
      mounted = false;
    };
  }, [token, t]);

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-brand-900 via-blue-900 to-slate-900 p-4">
      <div className="w-full max-w-md rounded-2xl bg-white p-8 text-center shadow-2xl">
        <h1 className="text-2xl font-extrabold text-slate-900">{t('auth.verifyEmail')}</h1>
        <div className="mt-5">
          {status === 'loading' && <p className="text-sm text-slate-500">{t('auth.verifyChecking')}</p>}
          {status === 'ok' && <Alert tone="green">{t('auth.verifyOk')}</Alert>}
          {status === 'error' && <Alert>{error}</Alert>}
        </div>
        <div className="mt-6">
          <Link to="/login">
            <Button type="button" className="w-full">{t('auth.goToLogin')}</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}