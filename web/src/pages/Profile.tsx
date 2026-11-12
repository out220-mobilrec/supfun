import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { api, errorMessage, setSession } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import { useT } from '../i18n';
import type {
  Achievement,
  LevelInfo,
  NotificationSetting,
  PointLog,
  VisibilityScope,
  WaterBody,
} from '../types';
import { Alert, Button, Card, Field, Input, Loading, ProgressBar, Select, Textarea } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { ImageUploader } from '../components/ImageUploader';
import { RoleBadge } from '../components/statusBadges';
import { formatDate, relativeTime } from '../lib/format';
import { notificationCategoryLabel } from '../lib/labels';
import { DEFAULT_COUNTRY, useCountries } from '../lib/countries';

export default function ProfilePage() {
  const { user, updateUser, logout } = useAuth();
  const t = useT();
  const navigate = useNavigate();
  const countries = useCountries();
  const [level, setLevel] = useState<LevelInfo | null>(null);
  const [points, setPoints] = useState<PointLog[]>([]);
  const [achievements, setAchievements] = useState<Achievement[]>([]);
  const [waterbodies, setWaterbodies] = useState<WaterBody[]>([]);
  const [notifSettings, setNotifSettings] = useState<NotificationSetting[]>([]);
  const [notifBusy, setNotifBusy] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');

  const [form, setForm] = useState({
    name: user?.name ?? '',
    phone: user?.phone ?? '',
    city: user?.city ?? '',
    region: user?.region ?? '',
    country: user?.country || DEFAULT_COUNTRY,
    avatarUrl: user?.avatarUrl ?? '',
    bio: user?.bio ?? '',
    homeWaterBodyId: user?.homeWaterBodyId ?? '',
    locale: (user?.locale === 'en' ? 'en' : 'ru') as 'ru' | 'en',
    profileVisibility: (user?.profileVisibility ?? 'public') as VisibilityScope,
    activityVisibility: (user?.activityVisibility ?? 'public') as VisibilityScope,
    geoVisibility: (user?.geoVisibility ?? 'private') as VisibilityScope,
    showOnline: user?.showOnline ?? true,
  });

  const [pwd, setPwd] = useState({ current: '', next: '', confirm: '' });
  const [pwdSaving, setPwdSaving] = useState(false);
  const [pwdError, setPwdError] = useState('');
  const [pwdOk, setPwdOk] = useState('');
  const [resending, setResending] = useState(false);
  const [resendOk, setResendOk] = useState('');
  const [resendErr, setResendErr] = useState('');

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const [levelRes, pointsRes, achRes, wbRes, notifRes] = await Promise.all([
          api.get<LevelInfo>('/gamification/me'),
          api.get<PointLog[]>('/gamification/points'),
          api.get<Achievement[]>('/gamification/achievements'),
          api.get<WaterBody[]>('/waterbodies'),
          api.get<NotificationSetting[]>('/notifications/settings'),
        ]);
        if (!mounted) return;
        setLevel(levelRes.data);
        setPoints(pointsRes.data);
        setAchievements(achRes.data);
        setWaterbodies(wbRes.data);
        setNotifSettings(notifRes.data);
      } catch (err) {
        if (mounted) setError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, []);

  const set = <K extends keyof typeof form>(key: K, value: (typeof form)[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    setOk('');
    try {
      const payload: Record<string, unknown> = {
        name: form.name,
        phone: form.phone || undefined,
        city: form.city || undefined,
        region: form.region || undefined,
        country: form.country || undefined,
        avatarUrl: form.avatarUrl || null,
        bio: form.bio || undefined,
        locale: form.locale,
        profileVisibility: form.profileVisibility,
        activityVisibility: form.activityVisibility,
        geoVisibility: form.geoVisibility,
        showOnline: form.showOnline,
      };
      if (form.homeWaterBodyId) payload.homeWaterBodyId = form.homeWaterBodyId;
      const { data } = await api.patch('/users/me', payload);
      updateUser(data);
      setOk(t('profile.saved'));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const resendVerification = async () => {
    setResending(true);
    setResendOk('');
    setResendErr('');
    try {
      const { data } = await api.post('/auth/resend-verification');
      setResendOk(
        data?.devToken
          ? t('profile.verifySentDev') + data.devToken
          : t('profile.verifySent'),
      );
    } catch (err) {
      setResendErr(errorMessage(err, t('profile.verifySendError')));
    } finally {
      setResending(false);
    }
  };

  const changePassword = async (e: FormEvent) => {
    e.preventDefault();
    setPwdError('');
    setPwdOk('');
    if (pwd.next !== pwd.confirm) {
      setPwdError(t('profile.passwordMismatch'));
      return;
    }
    setPwdSaving(true);
    try {
      const { data } = await api.post('/auth/change-password', {
        currentPassword: pwd.current,
        newPassword: pwd.next,
      });
      setSession(data.accessToken, data.user, data.refreshToken);
      setPwd({ current: '', next: '', confirm: '' });
      setPwdOk(t('profile.passwordChanged'));
    } catch (err) {
      setPwdError(errorMessage(err, t('profile.passwordChangeError')));
    } finally {
      setPwdSaving(false);
    }
  };

  const toggleSetting = async (
    category: NotificationSetting['category'],
    key: 'inApp' | 'push',
    value: boolean,
  ) => {
    setNotifBusy(`${category}:${key}`);
    try {
      const { data } = await api.patch<NotificationSetting>(
        `/notifications/settings/${category}`,
        { [key]: value },
      );
      setNotifSettings((prev) => prev.map((s) => (s.category === category ? data : s)));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setNotifBusy('');
    }
  };

  const removeAccount = async () => {
    if (!window.confirm('Удалить аккаунт? Это действие необратимо.')) return;
    try {
      await api.delete('/users/me');
      logout();
      navigate('/login');
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  if (loading) return <Loading />;

  const unlocked = achievements.filter((a) => a.unlocked);

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-slate-900">Мой профиль</h1>
      {error && <Alert>{error}</Alert>}
      {ok && <Alert tone="green">{ok}</Alert>}

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-5 lg:col-span-2">
          <Card className="p-6">
            <div className="mb-5 flex items-center gap-4">
              <Avatar user={user} size="xl" />
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-lg font-bold text-slate-900">{user?.name}</span>
                  {user && <RoleBadge role={user.role} />}
                </div>
                <div className="text-sm text-slate-500">
                  {user?.email} · с {formatDate(user?.createdAt)}
                </div>
              </div>
            </div>

            <form onSubmit={submit} className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={t('profile.name')}>
                  <Input required minLength={2} value={form.name} onChange={(e) => set('name', e.target.value)} />
                </Field>
                <Field label={t('profile.city')}>
                  <Input value={form.city} onChange={(e) => set('city', e.target.value)} />
                </Field>
                <Field label={t('profile.region')}>
                  <Input value={form.region} onChange={(e) => set('region', e.target.value)} />
                </Field>
          <Field label={t('profile.country')}>
            <Select
              value={form.country || DEFAULT_COUNTRY}
              onChange={(e) => setForm({ ...form, country: e.target.value })}
            >
              {countries.length === 0 && <option value={DEFAULT_COUNTRY}>Россия</option>}
              {countries.map((c) => (
                <option key={c.code} value={c.code}>
                  {c.name}
                </option>
              ))}
            </Select>
          </Field>
              </div>
              <Field label={t('profile.phone')}>
                <Input value={form.phone} onChange={(e) => set('phone', e.target.value)} />
              </Field>
              <ImageUploader
                single
                label={t('profile.avatar')}
                hint="JPEG, PNG, WEBP до 5 МБ"
                value={form.avatarUrl ? [form.avatarUrl] : []}
                onChange={(urls) => set('avatarUrl', urls[0] ?? '')}
              />
              <Field label={t('profile.homeWaterbody')}>
                <Select value={form.homeWaterBodyId} onChange={(e) => set('homeWaterBodyId', e.target.value)}>
                  <option value="">{t('profile.notSelected')}</option>
                  {waterbodies.map((w) => (
                    <option key={w.id} value={w.id}>
                      {w.name}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label={t('profile.about')}>
                <Textarea rows={3} value={form.bio} onChange={(e) => set('bio', e.target.value)} />
              </Field>

              <div className="border-t border-slate-100 pt-4">
                <h3 className="mb-3 font-semibold text-slate-900">{t('profile.privacy')}</h3>
                <div className="grid gap-4 sm:grid-cols-2">
                  <Field label={t('profile.whoSeesProfile')}>
                    <Select
                      value={form.profileVisibility}
                      onChange={(e) => set('profileVisibility', e.target.value as VisibilityScope)}
                    >
                      <option value="public">{t('profile.visibility.public')}</option>
                      <option value="friends">{t('profile.visibility.friends')}</option>
                      <option value="private">{t('profile.visibility.private')}</option>
                    </Select>
                  </Field>
                  <Field label={t('profile.whoSeesActivity')}>
                    <Select
                      value={form.activityVisibility}
                      onChange={(e) => set('activityVisibility', e.target.value as VisibilityScope)}
                    >
                      <option value="public">{t('profile.visibility.public')}</option>
                      <option value="friends">{t('profile.visibility.friends')}</option>
                      <option value="private">{t('profile.visibility.private')}</option>
                    </Select>
                  </Field>
                  <Field label={t('profile.geoVisibility')}>
                    <Select
                      value={form.geoVisibility}
                      onChange={(e) => set('geoVisibility', e.target.value as VisibilityScope)}
                    >
                      <option value="public">{t('profile.visibility.publicGeo')}</option>
                      <option value="friends">{t('profile.visibility.friendsGeo')}</option>
                      <option value="private">{t('profile.visibility.hidden')}</option>
                    </Select>
                  </Field>
                </div>
                <label className="mt-3 flex items-center gap-2 text-sm text-slate-700">
                  <input
                    type="checkbox"
                    checked={form.showOnline}
                    onChange={(e) => set('showOnline', e.target.checked)}
                  />
                  {t('profile.showOnline')}
                </label>
                <div className="mt-4 grid gap-4 sm:grid-cols-2">
                  <Field label={t('profile.language')} hint={t('profile.languageHint')}>
                    <Select
                      value={form.locale}
                      onChange={(e) => set('locale', e.target.value === 'en' ? 'en' : 'ru')}
                    >
                      <option value="ru">Русский</option>
                      <option value="en">English</option>
                    </Select>
                  </Field>
                </div>
              </div>

              <div className="flex justify-end gap-3">
                <Button type="submit" loading={saving}>
                  Сохранить
                </Button>
              </div>
            </form>
          </Card>

          <Card className="p-6">
            <h2 className="mb-4 font-bold text-slate-900">{t('profile.pointsHistory')}</h2>
            {points.length === 0 ? (
              <p className="text-sm text-slate-400">{t('profile.noPoints')}</p>
            ) : (
              <div className="divide-y divide-slate-100">
                {points.slice(0, 15).map((p) => (
                  <div key={p.id} className="flex items-center justify-between py-2 text-sm">
                    <div>
                      <div className="font-medium text-slate-800">{p.action}</div>
                      <div className="text-xs text-slate-400">{relativeTime(p.createdAt)}</div>
                    </div>
                    <div className="font-bold text-emerald-600">+{p.points}</div>
                  </div>
                ))}
              </div>
            )}
          </Card>

          <Card className="p-6">
            <h2 className="mb-4 font-bold text-slate-900">{t('profile.changePassword')}</h2>
            {pwdError && <div className="mb-3"><Alert>{pwdError}</Alert></div>}
            {pwdOk && <div className="mb-3"><Alert tone="green">{pwdOk}</Alert></div>}
            <form onSubmit={changePassword} className="space-y-4">
              <Field label={t('profile.currentPassword')}>
                <Input
                  type="password"
                  required
                  value={pwd.current}
                  onChange={(e) => setPwd((p) => ({ ...p, current: e.target.value }))}
                  autoComplete="current-password"
                />
              </Field>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label={t('profile.newPassword')} hint={t('auth.passwordMinHint2')}>
                  <Input
                    type="password"
                    required
                    minLength={8}
                    value={pwd.next}
                    onChange={(e) => setPwd((p) => ({ ...p, next: e.target.value }))}
                    autoComplete="new-password"
                  />
                </Field>
                <Field label={t('profile.confirmPassword')}>
                  <Input
                    type="password"
                    required
                    minLength={8}
                    value={pwd.confirm}
                    onChange={(e) => setPwd((p) => ({ ...p, confirm: e.target.value }))}
                    autoComplete="new-password"
                  />
                </Field>
              </div>
              <div className="flex justify-end">
                <Button type="submit" loading={pwdSaving}>
                  Изменить пароль
                </Button>
              </div>
            </form>
          </Card>
        </div>

        <div className="space-y-5">
          {level && (
            <Card className="p-5">
              <div className="text-xs font-semibold uppercase tracking-wide text-slate-400">Уровень</div>
              <div className="mt-1 text-4xl font-extrabold text-slate-900">{level.level}</div>
              <div className="mt-1 text-sm text-slate-500">{level.xp} XP всего</div>
              <ProgressBar value={level.progress * 100} className="mt-3" />
              <div className="mt-1 text-xs text-slate-400">
                {level.currentLevelXp} / {level.nextLevelXp} XP до уровня {level.level + 1}
              </div>
            </Card>
          )}

          {user && !user.isEmailVerified && (
            <Card className="p-5">
              <h2 className="mb-2 font-bold text-slate-900">Email не подтверждён</h2>
              <p className="mb-3 text-sm text-slate-500">
                Подтвердите адрес, чтобы не потерять доступ к аккаунту.
              </p>
              {resendOk && <div className="mb-2"><Alert tone="green">{resendOk}</Alert></div>}
              {resendErr && <div className="mb-2"><Alert>{resendErr}</Alert></div>}
              <Button onClick={resendVerification} loading={resending}>
                Отправить письмо
              </Button>
            </Card>
          )}

          <Card className="p-5">
            <h2 className="mb-3 font-bold text-slate-900">Достижения</h2>
            <div className="space-y-3">
              {achievements.map((a) => (
                <div key={a.code} className={`flex items-center gap-3 ${a.unlocked ? '' : 'opacity-40'}`}>
                  <div className="text-2xl">{a.icon ?? '🏅'}</div>
                  <div className="min-w-0">
                    <div className="text-sm font-semibold text-slate-800">{a.title}</div>
                    <div className="text-xs text-slate-500">{a.description}</div>
                  </div>
                  <div className="ml-auto text-xs font-bold text-brand-600">+{a.xp}</div>
                </div>
              ))}
            </div>
            <div className="mt-3 text-xs text-slate-400">{t('profile.achievementsOpen')}: {unlocked.length} / {achievements.length}</div>
          </Card>

          <Card className="p-5">
            <h2 className="mb-3 font-bold text-slate-900">{t('profile.notifications')}</h2>
            <div className="space-y-3">
              {notifSettings.map((s) => (
                <div key={s.category} className="flex items-center justify-between gap-3 text-sm">
                  <span className="text-slate-700">{notificationCategoryLabel(s.category)}</span>
                  <div className="flex items-center gap-3 text-xs text-slate-500">
                    <label className="flex items-center gap-1">
                      <input
                        type="checkbox"
                        checked={s.inApp}
                        disabled={notifBusy === `${s.category}:inApp`}
                        onChange={(e) => toggleSetting(s.category, 'inApp', e.target.checked)}
                      />
                      в приложении
                    </label>
                    <label className="flex items-center gap-1">
                      <input
                        type="checkbox"
                        checked={s.push}
                        disabled={notifBusy === `${s.category}:push`}
                        onChange={(e) => toggleSetting(s.category, 'push', e.target.checked)}
                      />
                      push
                    </label>
                  </div>
                </div>
              ))}
            </div>
          </Card>

          <Card className="p-5">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h2 className="font-bold text-slate-900">{t('nav.gear')}</h2>
                <p className="mt-1 text-sm text-slate-500">{t('gear.empty')}</p>
              </div>
              <Button size="sm" tone="outline" onClick={() => navigate('/gear')}>{t('common.open')}</Button>
            </div>
          </Card>

          <Card className="p-5">
            <h2 className="mb-2 font-bold text-slate-900">Опасная зона</h2>
            <p className="mb-3 text-sm text-slate-500">Удаление аккаунта необратимо.</p>
            <Button tone="red" onClick={removeAccount}>
              Удалить аккаунт
            </Button>
          </Card>
        </div>
      </div>
    </div>
  );
}