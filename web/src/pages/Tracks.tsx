import { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { Track, TrackPoint, WaterBody } from '../types';
import { Alert, Button, Card, EmptyState, Field, Input, Loading, Select } from '../components/ui';
import { TrackStatusBadge } from '../components/statusBadges';
import { TRACK_DIFFICULTIES, type TrackDifficulty } from '../lib/lists';
import { trackDifficultyLabel } from '../lib/labels';
import { formatDistance, formatDuration, formatSpeed } from '../lib/format';
import { useT } from '../i18n';

export default function TracksPage() {
  const { user: me } = useAuth();
  const t = useT();
  const [tracks, setTracks] = useState<Track[]>([]);
  const [waterbodies, setWaterbodies] = useState<WaterBody[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const [onlyMine, setOnlyMine] = useState(false);
  const [waterBodyId, setWaterBodyId] = useState('');
  const [difficulty, setDifficulty] = useState<TrackDifficulty | ''>('');
  const [farEast, setFarEast] = useState(false);
  const [minMinutes, setMinMinutes] = useState('');
  const [maxMinutes, setMaxMinutes] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      params.set('scope', onlyMine ? 'mine' : 'all');
      if (waterBodyId) params.set('waterBodyId', waterBodyId);
      if (difficulty) params.set('difficulty', difficulty);
      if (farEast) params.set('farEast', 'true');
      const minSec = Number(minMinutes);
      const maxSec = Number(maxMinutes);
      if (minMinutes !== '' && Number.isFinite(minSec)) params.set('minDurationSec', String(Math.round(minSec * 60)));
      if (maxMinutes !== '' && Number.isFinite(maxSec)) params.set('maxDurationSec', String(Math.round(maxSec * 60)));
      params.set('limit', '100');
      const { data } = await api.get<Track[]>(`/tracks?${params.toString()}`);
      setTracks(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [onlyMine, waterBodyId, difficulty, farEast, minMinutes, maxMinutes]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    api
      .get<WaterBody[]>('/waterbodies')
      .then(({ data }) => setWaterbodies(data))
      .catch(() => undefined);
  }, []);

  const resetFilters = () => {
    setOnlyMine(false);
    setWaterBodyId('');
    setDifficulty('');
    setFarEast(false);
    setMinMinutes('');
    setMaxMinutes('');
  };

  const filtersActive = onlyMine || waterBodyId || difficulty || farEast || minMinutes !== '' || maxMinutes !== '';

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold text-slate-900">{t('tracks.title')}</h1>
        <Button size="sm" tone={farEast ? 'brand' : 'outline'} onClick={() => setFarEast((v) => !v)}>
          {t('tracks.farEast')}
        </Button>
      </div>

      {/* Фильтры */}
      <Card className="p-4">
        <div className="grid items-end gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <Field label={t('label.waterbody')}>
            <Select value={waterBodyId} onChange={(e) => setWaterBodyId(e.target.value)}>
              <option value="">Все водоемы</option>
              {waterbodies.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                </option>
              ))}
            </Select>
          </Field>

          <Field label={t('label.difficulty')}>
            <Select value={difficulty} onChange={(e) => setDifficulty(e.target.value as TrackDifficulty | '')}>
              <option value="">Любая</option>
              {TRACK_DIFFICULTIES.map((d) => (
                <option key={d} value={d}>
                  {trackDifficultyLabel(d)}
                </option>
              ))}
            </Select>
          </Field>

          <Field label="Время в пути, мин">
            <div className="flex items-center gap-2">
              <Input
                type="number"
                min={0}
                placeholder="от"
                value={minMinutes}
                onChange={(e) => setMinMinutes(e.target.value)}
              />
              <span className="text-slate-400">—</span>
              <Input
                type="number"
                min={0}
                placeholder="до"
                value={maxMinutes}
                onChange={(e) => setMaxMinutes(e.target.value)}
              />
            </div>
          </Field>

          <div className="flex items-center justify-between gap-3">
            <label className="flex cursor-pointer items-center gap-2 text-sm font-medium text-slate-700">
              <input
                type="checkbox"
                checked={onlyMine}
                onChange={(e) => setOnlyMine(e.target.checked)}
                className="h-4 w-4 rounded border-slate-300 text-brand-600"
              />
              Только мои
            </label>
            {filtersActive && (
              <button onClick={resetFilters} className="text-sm text-slate-500 hover:text-slate-700">
                Сбросить
              </button>
            )}
          </div>
        </div>
      </Card>

      {error && <Alert>{error}</Alert>}
      {loading && <Loading />}

      {!loading && !error && (
        tracks.length === 0 ? (
          <EmptyState
            title="Маршруты не найдены"
            hint={filtersActive ? 'Попробуйте ослабить фильтры.' : 'Маршруты создаются при трекинге заплывов.'}
          />
        ) : (
          <div className="grid gap-5 md:grid-cols-2">
            {tracks.map((t) => (
              <TrackCard key={t.id} track={t} currentUserId={me?.id} currentRole={me?.role} />
            ))}
          </div>
        )
      )}
    </div>
  );
}

function TrackCard({
  track,
  currentUserId,
  currentRole,
}: {
  track: Track;
  currentUserId?: string;
  currentRole?: string;
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const [pointCount, setPointCount] = useState<number | null>(null);

  const isOwner = track.userId === currentUserId;
  const isStaff = currentRole === 'admin' || currentRole === 'moderator';
  const canEdit = isOwner || isStaff;

  // Линия маршрута по его точкам
  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    const map = L.map(containerRef.current, {
      zoomControl: false,
      dragging: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      touchZoom: false,
      attributionControl: false,
    }).setView([55.75, 37.62], 5);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19 }).addTo(map);
    mapRef.current = map;

    let cancelled = false;
    void (async () => {
      try {
        const { data } = await api.get<TrackPoint[]>(`/tracks/${track.id}/points`);
        if (cancelled || data.length === 0) return;
        const coords = data.map((p) => [p.lat, p.lng] as L.LatLngTuple);
        const line = L.polyline(coords, { color: '#2563eb', weight: 3 }).addTo(map);
        L.circleMarker(coords[0], { radius: 5, color: '#16a34a', fillColor: '#22c55e', fillOpacity: 1 }).addTo(map);
        L.circleMarker(coords[coords.length - 1], { radius: 5, color: '#dc2626', fillColor: '#ef4444', fillOpacity: 1 }).addTo(map);
        if (coords.length > 1) map.fitBounds(line.getBounds(), { padding: [12, 12] });
        else map.setView(coords[0], 13);
        setPointCount(data.length);
      } catch {
        /* нет доступа к точкам — оставляем пустую карту */
      }
    })();

    return () => {
      cancelled = true;
      map.remove();
      mapRef.current = null;
    };
  }, [track.id]);

  return (
    <Card className="overflow-hidden p-0">
      {/* Класс контейнера Leaflet не должен меняться между рендерами */}
      <div className="relative h-36 w-full bg-slate-100">
        <div ref={containerRef} className="h-full w-full" />
        <div className="absolute bottom-1 right-1 rounded bg-white/80 px-1.5 py-0.5 text-[10px] text-slate-500">
          {pointCount === null ? 'нет точек' : `${pointCount} тчк`}
        </div>
      </div>

      <div className="p-4">
        <div className="flex items-start justify-between gap-2">
          <Link to={`/tracks/${track.id}`} className="font-bold text-slate-900 hover:underline">
            {track.name ?? 'Без названия'}
          </Link>
          {isOwner && track.status !== 'published' ? (
            <TrackStatusBadge status={track.status} />
          ) : isOwner ? (
            <span className="rounded bg-brand-50 px-2 py-0.5 text-xs font-medium text-brand-700">мой</span>
          ) : null}
        </div>

        <div className="mt-1 text-sm text-slate-500">
          {track.waterBody?.name ?? 'Водоём не указан'}
          {track.difficulty ? ` · ${trackDifficultyLabel(track.difficulty)}` : ''}
        </div>

        <div className="mt-1 text-xs text-slate-400">
          Автор: <span className="font-medium text-slate-600">{track.user?.name ?? '—'}</span>
        </div>

        <div className="mt-2 flex flex-wrap gap-3 text-sm text-slate-600">
          <span>{formatDistance(track.distanceMeters)}</span>
          <span>{formatDuration(track.durationSeconds)}</span>
          <span>{formatSpeed(track.avgSpeedKph)}</span>
        </div>

        <div className="mt-3 flex flex-wrap gap-2">
          <Link
            to={`/tracks/${track.id}`}
            className="inline-flex items-center rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50"
          >
            Подробнее
          </Link>
          {canEdit && (
            <Link
              to={`/tracks/${track.id}/edit`}
              className="inline-flex items-center rounded-lg border border-brand-300 bg-brand-50 px-3 py-1.5 text-sm font-medium text-brand-700 hover:bg-brand-100"
            >
              Редактировать
            </Link>
          )}
        </div>
      </div>
    </Card>
  );
}
