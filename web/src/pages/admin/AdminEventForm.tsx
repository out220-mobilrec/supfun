import { useEffect, useState } from 'react';
import type { FormEvent } from 'react';
import { api, errorMessage } from '../../lib/api';
import type { Event, WaterBody, EventStatus } from '../../types';
import {
  EVENT_ACCESSES,
  EVENT_LEVELS,
  EVENT_STATUSES,
  EVENT_VISIBILITIES,
  type EventAccess,
  type EventLevel,
  type EventVisibility,
} from '../../lib/lists';
import { eventStatusLabel } from '../../lib/labels';
import {
  Alert,
  Button,
  Field,
  Input,
  Modal,
  Select,
  Textarea,
} from '../../components/ui';
import { ImageUploader } from '../../components/ImageUploader';
import { fromDateTimeLocal, toDateTimeLocal } from '../../lib/format';
import { useT } from '../../i18n';
void useT;

const visibilityLabels: Record<EventVisibility, string> = {
  public: 'Всем',
  friends: 'Друзьям',
  private: 'Только я',
};
const accessLabels: Record<EventAccess, string> = {
  open: 'Открытый',
  invite: 'По приглашению',
};

export default function AdminEventForm({
  event,
  onClose,
  onSaved,
}: {
  event: Event;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [waterbodies, setWaterbodies] = useState<WaterBody[]>([]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const [form, setForm] = useState({
    title: event.title,
    description: event.description ?? '',
    photos: (event.photos ?? []) as string[],
    waterBodyId: event.waterBodyId ?? '',
    eventDate: toDateTimeLocal(event.eventDate),
    expectedDurationMinutes: event.expectedDurationMinutes?.toString() ?? '',
    expectedDistanceMeters: event.expectedDistanceMeters?.toString() ?? '',
    level: event.level,
    visibility: event.visibility,
    access: event.access,
    maxParticipants: event.maxParticipants?.toString() ?? '',
    status: event.status as EventStatus,
    startLat: event.startLat?.toString() ?? '',
    startLng: event.startLng?.toString() ?? '',
  });

  useEffect(() => {
    api
      .get<WaterBody[]>('/waterbodies')
      .then(({ data }) => setWaterbodies(data))
      .catch(() => undefined);
  }, []);

  const set = <K extends keyof typeof form>(key: K, value: (typeof form)[K]) =>
    setForm((f) => ({ ...f, [key]: value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');
    const eventDateIso = fromDateTimeLocal(form.eventDate);
    if (!eventDateIso) {
      setError('Укажите дату и время заплыва');
      return;
    }
    const payload: Record<string, unknown> = {
      title: form.title,
      description: form.description || undefined,
      photos: form.photos,
      waterBodyId: form.waterBodyId || null,
      eventDate: eventDateIso,
      level: form.level,
      visibility: form.visibility,
      access: form.access,
      status: form.status,
    };
    if (form.expectedDurationMinutes)
      payload.expectedDurationMinutes = Number(form.expectedDurationMinutes);
    if (form.expectedDistanceMeters)
      payload.expectedDistanceMeters = Number(form.expectedDistanceMeters);
    if (form.maxParticipants)
      payload.maxParticipants = Number(form.maxParticipants);
    if (form.startLat && form.startLng) {
      payload.startPoint = {
        lat: Number(form.startLat),
        lng: Number(form.startLng),
      };
    } else {
      payload.startPoint = null;
    }

    setSaving(true);
    try {
      await api.patch(`/admin/events/${event.id}`, payload);
      onSaved();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <Modal open onClose={onClose} title="Редактировать заплыв" wide>
      {error && (
          <div className="mb-4">
            <Alert>{error}</Alert>
          </div>
        )}
        <form onSubmit={submit} className="space-y-4">          <Field label="Название">
            <Input
              required
              maxLength={200}
              value={form.title}
              onChange={(e) => set('title', e.target.value)}
            />
          </Field>
          <Field label="Описание">
            <Textarea
              rows={3}
              value={form.description}
              onChange={(e) => set('description', e.target.value)}
            />
          </Field>
          <ImageUploader
            label="Фото"
            hint="До 6 изображений, каждое до 5 МБ"
            max={6}
            value={form.photos}
            onChange={(urls) => set('photos', urls)}
          />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Водоём">
              <Select
                value={form.waterBodyId}
                onChange={(e) => set('waterBodyId', e.target.value)}
              >
                <option value="">Не выбрано</option>
                {waterbodies.map((w) => (
                  <option key={w.id} value={w.id}>
                    {w.name}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Дата и время">
              <Input
                type="datetime-local"
                required
                value={form.eventDate}
                onChange={(e) => set('eventDate', e.target.value)}
              />
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Уровень">
              <Select
                value={form.level}
                onChange={(e) => set('level', e.target.value as EventLevel)}
              >
                {EVENT_LEVELS.map((l) => (
                  <option key={l} value={l}>
                    {l}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Видимость">
              <Select
                value={form.visibility}
                onChange={(e) =>
                  set('visibility', e.target.value as EventVisibility)
                }
              >
                {EVENT_VISIBILITIES.map((v) => (
                  <option key={v} value={v}>
                    {visibilityLabels[v]}
                  </option>
                ))}
              </Select>
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Доступ">
              <Select
                value={form.access}
                onChange={(e) => set('access', e.target.value as EventAccess)}
              >
                {EVENT_ACCESSES.map((a) => (
                  <option key={a} value={a}>
                    {accessLabels[a]}
                  </option>
                ))}
              </Select>
            </Field>
            <Field label="Длительность, мин">
              <Input
                type="number"
                min={1}
                value={form.expectedDurationMinutes}
                onChange={(e) =>
                  set('expectedDurationMinutes', e.target.value)
                }
              />
            </Field>
            <Field label="Дистанция, м">
              <Input
                type="number"
                min={1}
                value={form.expectedDistanceMeters}
                onChange={(e) =>
                  set('expectedDistanceMeters', e.target.value)
                }
              />
            </Field>
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Макс. участников">
              <Input
                type="number"
                min={1}
                value={form.maxParticipants}
                onChange={(e) => set('maxParticipants', e.target.value)}
              />
            </Field>
            <Field label="Старт: широта">
              <Input
                type="number"
                step="any"
                value={form.startLat}
                onChange={(e) => set('startLat', e.target.value)}
              />
            </Field>
            <Field label="Старт: долгота">
              <Input
                type="number"
                step="any"
                value={form.startLng}
                onChange={(e) => set('startLng', e.target.value)}
              />
            </Field>
          </div>
          <Field label="Статус">
            <Select
              value={form.status}
              onChange={(e) => set('status', e.target.value as EventStatus)}
            >
              {EVENT_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {eventStatusLabel(s)}
                </option>
              ))}
            </Select>
          </Field>
          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" tone="outline" onClick={onClose}>
              Отмена
            </Button>
            <Button type="submit" loading={saving}>
              Сохранить
            </Button>
          </div>
        </form>
    </Modal>
  );
}
