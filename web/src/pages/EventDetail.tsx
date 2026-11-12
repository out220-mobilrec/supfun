import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { Conversation, Event, EventParticipant, ParticipantStatus } from '../types';
import { Badge, Button, Card, Loading, PageHeader, Alert, Select } from '../components/ui';
import { Avatar } from '../components/Avatar';
import { EventLevelBadge, EventStatusBadge, ParticipantStatusBadge } from '../components/statusBadges';
import { ReviewsSection } from '../components/ReviewsSection';
import { EventTracks } from '../components/EventTracks';
import WeatherCard from '../components/WeatherCard';
import { formatDateTime, formatDistance, formatDuration } from '../lib/format';
import { useT } from '../i18n';

export default function EventDetailPage() {
  const t = useT();
  const { id } = useParams();
  const navigate = useNavigate();
  const { user } = useAuth();
  const [event, setEvent] = useState<Event | null>(null);
  const [participants, setParticipants] = useState<EventParticipant[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    if (!id) return;
    setError('');
    try {
      const [evRes, partRes] = await Promise.all([
        api.get<Event>(`/events/${id}`),
        api.get<EventParticipant[]>(`/events/${id}/participants`),
      ]);
      setEvent(evRes.data);
      setParticipants(partRes.data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  const myStatus = participants.find((p) => p.userId === user?.id)?.status ?? null;

  const join = async (status: ParticipantStatus) => {
    if (!id) return;
    setBusy(true);
    try {
      await api.post(`/events/${id}/join`, { status });
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const openChat = async () => {
    if (!id) return;
    setBusy(true);
    try {
      const { data } = await api.post<Conversation>('/conversations', { type: 'event', eventId: id, title: event?.title });
      navigate(`/chats/${data.id}`);
    } catch (err) {
      setError(errorMessage(err, t('event.chatOpenError')));
    } finally {
      setBusy(false);
    }
  };

  const manageParticipant = async (userId: string, status: ParticipantStatus) => {
    if (!id) return;
    setBusy(true);
    try {
      await api.patch(`/events/${id}/participants/${userId}`, { status });
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const removeParticipant = async (userId: string) => {
    if (!id || !window.confirm(t('event.removeParticipantConfirm'))) return;
    setBusy(true);
    try {
      await api.delete(`/events/${id}/participants/${userId}`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const cancel = async () => {
    if (!id || !window.confirm(t('event.confirmCancel'))) return;
    setBusy(true);
    try {
      await api.delete(`/events/${id}`);
      await load();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  if (loading) return <Loading />;
  if (!event) return <Alert>{error || t('event.notFound')}</Alert>;

  const isOrganizer = event.organizerId === user?.id;
  const weatherLat = event.startLat ?? event.waterBody?.latitude ?? null;
  const weatherLon = event.startLng ?? event.waterBody?.longitude ?? null;

  const participationLabel = (s: ParticipantStatus) =>
    s === 'going' ? t('event.going') : s === 'maybe' ? t('event.interested') : t('event.notGoing');
  const statusLabel = (s: ParticipantStatus) =>
    s === 'going' ? t('participant.goingStatus') : s === 'maybe' ? t('participant.maybeStatus') : t('participant.notGoingStatus');

  return (
    <div className="space-y-5">
      <PageHeader
        title={event.title}
        subtitle={`${event.waterBody?.name ?? t('event.waterbodyUnknown')} · ${formatDateTime(event.eventDate)}`}
        action={
          isOrganizer ? (
            <div className="flex gap-2">
              <Button tone="outline" onClick={() => navigate(`/events/${event.id}/edit`)}>
                {t('event.editAction')}
              </Button>
              <Button tone="red" onClick={cancel} loading={busy}>
                {t('event.cancelAction')}
              </Button>
            </div>
          ) : (
            <Button tone="outline" onClick={openChat} loading={busy}>
              {t('event.openChat')}
            </Button>
          )
        }
      />

      {error && <Alert>{error}</Alert>}

      <div className="grid gap-5 lg:grid-cols-3">
        <div className="space-y-5 lg:col-span-2">
          <Card className="space-y-4 p-5">
            <div className="flex flex-wrap items-center gap-2">
              <EventStatusBadge status={event.status} />
              <EventLevelBadge level={event.level} />
              <Badge tone="outline">{event.access === 'open' ? t('event.access.open') : t('event.access.invite')}</Badge>
            </div>
            {event.description && <p className="whitespace-pre-line text-sm text-slate-700">{event.description}</p>}
            {event.photos?.length > 0 && (
              <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                {event.photos.map((photo) => (
                  <a
                    key={photo}
                    href={photo}
                    target="_blank"
                    rel="noreferrer"
                    className="overflow-hidden rounded-xl border border-slate-200"
                  >
                    <img
                      src={photo}
                      alt={event.title}
                      loading="lazy"
                      className="aspect-square w-full object-cover transition duration-300 hover:scale-105"
                    />
                  </a>
                ))}
              </div>
            )}
            <div className="grid grid-cols-2 gap-4 border-t border-slate-100 pt-4 text-sm sm:grid-cols-4">
              <Info label={t('label.date')} value={formatDateTime(event.eventDate)} />
              <Info label={t('event.distanceLabel')} value={event.expectedDistanceMeters ? formatDistance(event.expectedDistanceMeters) : '—'} />
              <Info label={t('event.durationLabel')} value={event.expectedDurationMinutes ? formatDuration(event.expectedDurationMinutes * 60) : '—'} />
              <Info label={t('event.participants')} value={`${event.participantCount ?? participants.length} / ${event.maxParticipants ?? '∞'}`} />
            </div>
            <div className="border-t border-slate-100 pt-4 text-sm">
              <div className="text-xs uppercase tracking-wide text-slate-400">{t('event.routeLabel')}</div>
              {event.track ? (
                <Link
                  to={`/tracks/${event.track.id}`}
                  className="mt-1 inline-block font-semibold text-brand-600 hover:underline"
                >
                  {event.track.name ?? t('event.form.untitledRoute')}
                  {event.track.waterBody?.name ? ` — ${event.track.waterBody.name}` : ''}
                </Link>
              ) : (
                <div className="mt-1 text-slate-400">{t('event.notSelected')}</div>
              )}
            </div>
            <div className="flex items-center gap-3 border-t border-slate-100 pt-4">
              <Avatar user={event.organizer} />
              <div>
                <div className="text-xs uppercase tracking-wide text-slate-400">{t('event.organizer')}</div>
                <Link to={`/users/${event.organizerId}`} className="font-semibold text-slate-900 hover:text-brand-700">
                  {event.organizer?.name}
                </Link>
              </div>
            </div>
          </Card>

          {weatherLat != null && weatherLon != null ? (
            <div className="lg:col-span-2">
              <WeatherCard lat={weatherLat} lon={weatherLon} />
            </div>
          ) : null}
        </div>

        <div className="space-y-5">
          <Card className="p-5">
            <h3 className="mb-3 font-bold text-slate-900">{t('event.participation')}</h3>
            <div className="space-y-2">
              {(['going', 'maybe', 'not_going'] as ParticipantStatus[]).map((s) => (
                <button
                  key={s}
                  disabled={busy}
                  onClick={() => join(s)}
                  className={`w-full rounded-lg border px-3 py-2 text-sm font-semibold transition ${
                    myStatus === s
                      ? 'border-brand-500 bg-brand-50 text-brand-700'
                      : 'border-slate-200 text-slate-600 hover:bg-slate-50'
                  }`}
                >
                  {participationLabel(s)}
                </button>
              ))}
            </div>
            <Button tone="outline" className="mt-3 w-full" onClick={openChat} loading={busy}>
              {t('event.openChat')}
            </Button>
          </Card>

          <Card className="p-5">
            <h3 className="mb-3 font-bold text-slate-900">{t('event.participants')} ({participants.length})</h3>
            <div className="space-y-3">
              {participants.map((p) => (
                <div key={p.id} className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <Avatar user={p.user} size="sm" />
                    <Link to={`/users/${p.userId}`} className="text-sm font-medium text-slate-800 hover:text-brand-700">
                      {p.user?.name}
                    </Link>
                    {p.userId === event.organizerId && <Badge tone="brand">{t('event.organizerBadge')}</Badge>}
                  </div>
                  {isOrganizer && p.userId !== event.organizerId ? (
                    <div className="flex items-center gap-2">
                      <Select
                        value={p.status}
                        disabled={busy}
                        onChange={(e) => manageParticipant(p.userId, e.target.value as ParticipantStatus)}
                      >
                        <option value="going">{statusLabel('going')}</option>
                        <option value="maybe">{statusLabel('maybe')}</option>
                        <option value="not_going">{statusLabel('not_going')}</option>
                      </Select>
                      <button
                        type="button"
                        disabled={busy}
                        onClick={() => removeParticipant(p.userId)}
                        className="rounded-lg border border-red-200 px-2 py-1 text-xs font-semibold text-red-600 hover:bg-red-50 disabled:opacity-50"
                      >
                        {t('common.delete')}
                      </button>
                    </div>
                  ) : (
                    <ParticipantStatusBadge status={p.status} />
                  )}
                </div>
              ))}
              {participants.length === 0 && <div className="text-sm text-slate-400">{t('event.noParticipants')}</div>}
            </div>
            {!isOrganizer && myStatus && (
              <Button
                tone="red"
                className="mt-4 w-full"
                onClick={() => user && removeParticipant(user.id)}
                loading={busy}
              >
                {t('event.leave')}
              </Button>
            )}
          </Card>
        </div>
      </div>

      <EventTracks eventId={event.id} />

      <ReviewsSection targetType="event" targetId={event.id} title={t('event.reviews')} />
    </div>
  );
}

function Info({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="text-xs uppercase tracking-wide text-slate-400">{label}</div>
      <div className="font-semibold text-slate-800">{value}</div>
    </div>
  );
}
