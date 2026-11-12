import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import type { Event, Track } from '../types';
import { EVENT_ACCESSES, EVENT_LEVELS, EVENT_VISIBILITIES, type EventAccess, type EventLevel, type EventVisibility } from '../lib/lists';
import { Alert, Button, Card, Field, Input, Loading, PageHeader, Select, Textarea } from '../components/ui';
import { ImageUploader } from '../components/ImageUploader';
import { fromDateTimeLocal, toDateTimeLocal } from '../lib/format';
import { eventLevelLabel } from '../lib/labels';
import { useT } from '../i18n';

export default function EventFormPage() {
  const t = useT();
  const { id } = useParams();
  const isEdit = Boolean(id);
  const navigate = useNavigate();
  const [routes, setRoutes] = useState<Track[]>([]);
  const [loading, setLoading] = useState(isEdit);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const visibilityLabels: Record<EventVisibility, string> = {
    public: t('event.visibility.public'),
    friends: t('event.visibility.friends'),
    private: t('event.visibility.private'),
  };
  const accessLabels: Record<EventAccess, string> = {
    open: t('event.access.open'),
    invite: t('event.access.invite'),
  };

  const [form, setForm] = useState({
    title: '',
    description: '',
    photos: [] as string[],
    trackId: '',
    eventDate: '',
    expectedDurationMinutes: '',
    expectedDistanceMeters: '',
    level: 'beginner' as EventLevel,
    visibility: 'public' as EventVisibility,
    access: 'open' as EventAccess,
    maxParticipants: '',
    startLat: '',
    startLng: '',
  });

  useEffect(() => {
    api
      .get<Track[]>('/tracks?scope=public&limit=100')
      .then(({ data }) => setRoutes(data))
      .catch(() => undefined);
  }, []);

  useEffect(() => {
    if (!id) return;
    let mounted = true;
    (async () => {
      try {
        const { data } = await api.get<Event>(`/events/${id}`);
        if (!mounted) return;
        setForm({
          title: data.title,
          description: data.description ?? '',
          photos: data.photos ?? [],
          trackId: data.trackId ?? '',
          eventDate: toDateTimeLocal(data.eventDate),
          expectedDurationMinutes: data.expectedDurationMinutes?.toString() ?? '',
          expectedDistanceMeters: data.expectedDistanceMeters?.toString() ?? '',
          level: data.level,
          visibility: data.visibility,
          access: data.access,
          maxParticipants: data.maxParticipants?.toString() ?? '',
          startLat: data.startLat?.toString() ?? '',
          startLng: data.startLng?.toString() ?? '',
        });
      } catch (err) {
        if (mounted) setError(errorMessage(err));
      } finally {
        if (mounted) setLoading(false);
      }
    })();
    return () => {
      mounted = false;
    };
  }, [id]);

  const set = <K extends keyof typeof form>(key: K, value: (typeof form)[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const selectedRoute = routes.find((r) => r.id === form.trackId) ?? null;

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    const eventDateIso = fromDateTimeLocal(form.eventDate);
    if (!eventDateIso) {
      setError(t('event.form.dateRequired'));
      return;
    }
    const payload: Record<string, unknown> = {
      title: form.title,
      description: form.description || undefined,
      photos: form.photos,
      trackId: form.trackId || undefined,
      eventDate: eventDateIso,
      level: form.level,
      visibility: form.visibility,
      access: form.access,
    };
    if (!form.trackId) {
      if (form.expectedDurationMinutes) payload.expectedDurationMinutes = Number(form.expectedDurationMinutes);
      if (form.expectedDistanceMeters) payload.expectedDistanceMeters = Number(form.expectedDistanceMeters);
    }
    if (form.maxParticipants) payload.maxParticipants = Number(form.maxParticipants);
    if (form.startLat && form.startLng) {
      payload.startPoint = { lat: Number(form.startLat), lng: Number(form.startLng) };
    }

    setSaving(true);
    try {
      if (isEdit) {
        const { data } = await api.patch<Event>(`/events/${id}`, payload);
        navigate(`/events/${data.id}`);
      } else {
        const { data } = await api.post<Event>('/events', payload);
        navigate(`/events/${data.id}`);
      }
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <Loading />;

  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader
        title={isEdit ? t('event.form.edit') : t('event.form.new')}
        subtitle={t('event.form.subtitle')}
      />
      {error && <div className="mb-4"><Alert>{error}</Alert></div>}
      <Card className="p-6">
        <form onSubmit={submit} className="space-y-4">
          <Field label={t('label.title')}>
            <Input required maxLength={200} value={form.title} onChange={(e) => set('title', e.target.value)} placeholder={t('event.form.titlePlaceholder')} />
          </Field>
          <Field label={t('label.description')}>
            <Textarea rows={3} value={form.description} onChange={(e) => set('description', e.target.value)} placeholder={t('event.form.descPlaceholder')} />
          </Field>
          <ImageUploader
            label={t('event.form.photo')}
            hint={t('event.form.photoHint')}
            max={6}
            value={form.photos}
            onChange={(urls) => set('photos', urls)}
          />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              label={t('event.form.route')}
              hint={selectedRoute?.waterBody?.name ? `${t('event.form.waterbodyLabel')}: ${selectedRoute.waterBody.name}` : undefined}
            >
              <Select
                value={form.trackId}
                onChange={(e) => {
                  const nextId = e.target.value;
                  const route = routes.find((r) => r.id === nextId);
                  setForm((f) => ({
                    ...f,
                    trackId: nextId,
                    expectedDurationMinutes: route
                      ? String(Math.round(route.durationSeconds / 60))
                      : f.expectedDurationMinutes,
                    expectedDistanceMeters: route
                      ? String(Math.round(route.distanceMeters))
                      : f.expectedDistanceMeters,
                  }));
                }}
              >
                <option value="">{t('event.form.noRoute')}</option>
                {routes.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name ?? t('event.form.untitledRoute')}
                    {r.waterBody?.name ? ` — ${r.waterBody.name}` : ''}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t('event.form.date')}>
              <Input type="datetime-local" required value={form.eventDate} onChange={(e) => set('eventDate', e.target.value)} />
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t('label.level')}>
              <Select value={form.level} onChange={(e) => set('level', e.target.value as EventLevel)}>
                {EVENT_LEVELS.map((l) => (
                  <option key={l} value={l}>
                    {eventLevelLabel(l)}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label={t('event.form.visibility')}>
              <Select value={form.visibility} onChange={(e) => set('visibility', e.target.value as EventVisibility)}>
                {EVENT_VISIBILITIES.map((v) => (
                  <option key={v} value={v}>
                    {visibilityLabels[v]}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label={t('event.form.access')}>
              <Select value={form.access} onChange={(e) => set('access', e.target.value as EventAccess)}>
                {EVENT_ACCESSES.map((a) => (
                  <option key={a} value={a}>
                    {accessLabels[a]}
                  </option>
                ))}
              </Select>
            </Field>
            <Field
              label={t('event.form.durationShort')}
              hint={selectedRoute ? t('event.form.fromRoute') : undefined}
            >
              <Input
                type="number"
                min={1}
                readOnly={Boolean(selectedRoute)}
                className={selectedRoute ? 'bg-slate-50 text-slate-500' : ''}
                value={form.expectedDurationMinutes}
                onChange={(e) => set('expectedDurationMinutes', e.target.value)}
              />
            </Field>
            <Field
              label={t('event.form.distanceShort')}
              hint={selectedRoute ? t('event.form.fromRoute') : undefined}
            >
              <Input
                type="number"
                min={1}
                readOnly={Boolean(selectedRoute)}
                className={selectedRoute ? 'bg-slate-50 text-slate-500' : ''}
                value={form.expectedDistanceMeters}
                onChange={(e) => set('expectedDistanceMeters', e.target.value)}
              />
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label={t('event.form.maxParticipants')}>
              <Input type="number" min={1} value={form.maxParticipants} onChange={(e) => set('maxParticipants', e.target.value)} />
            </Field>
            <Field label={t('event.form.startLat')}>
              <Input type="number" step="any" value={form.startLat} onChange={(e) => set('startLat', e.target.value)} placeholder="48.48" />
            </Field>
            <Field label={t('event.form.startLng')}>
              <Input type="number" step="any" value={form.startLng} onChange={(e) => set('startLng', e.target.value)} placeholder="135.07" />
            </Field>
          </div>
          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" tone="outline" onClick={() => navigate(-1)}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" loading={saving}>
              {isEdit ? t('event.form.saveBtn') : t('event.form.createBtn')}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
