import { useCallback, useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { api, errorMessage } from '../lib/api';
import { Avatar } from './Avatar';
import { Card } from './ui';
import { formatDistance, formatDuration, relativeTime } from '../lib/format';

interface EventTrack {
  id: string;
  userId: string;
  author: { id: string; name: string; avatarUrl: string | null };
  name: string | null;
  status: string;
  startedAt: string;
  endedAt: string | null;
  distanceMeters: number;
  durationSeconds: number;
  avgSpeedKph: number;
  pointsCount: number;
}

interface GpsPoint {
  id: string;
  lat: number;
  lng: number;
  recordedAt: string;
}

const COLORS = ['#2563eb', '#059669', '#d97706', '#dc2626', '#7c3aed', '#0891b2', '#db2777', '#65a30d'];

/**
 * Треки участников заплыва: список «кто сколько прошёл» и карта со
 * всеми сданными линиями. Точки загружают участники из мобильного приложения.
 */
export function EventTracks({ eventId }: { eventId: string }) {
  const [tracks, setTracks] = useState<EventTrack[]>([]);
  const [pointsByTrack, setPointsByTrack] = useState<Record<string, GpsPoint[]>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<EventTrack[]>(`/events/${eventId}/tracks`);
      setTracks(data);
      const withPoints = data.filter((t) => t.pointsCount > 0);
      const entries = await Promise.all(
        withPoints.map(async (t) => {
          const res = await api.get<GpsPoint[]>(`/events/${eventId}/tracks/${t.id}/points`);
          return [t.id, res.data] as const;
        }),
      );
      setPointsByTrack(Object.fromEntries(entries));
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [eventId]);

  useEffect(() => {
    load();
  }, [load]);

  const totalPoints = tracks.reduce((sum, t) => sum + t.pointsCount, 0);

  return (
    <Card className="p-5">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <h3 className="font-bold text-slate-900">Треки участников</h3>
        <button
          onClick={load}
          className="text-xs font-semibold text-slate-500 hover:text-slate-700"
        >
          Обновить
        </button>
      </div>

      {error && <div className="mb-3 text-sm text-red-600">{error}</div>}

      {loading ? (
        <div className="text-sm text-slate-500">Загружаем треки…</div>
      ) : tracks.length === 0 ? (
        <div className="text-sm text-slate-500">
          Пока никто не записал трек. Участники передают точки из мобильного приложения:
          старт записи, пакеты точек и финиш.
        </div>
      ) : (
        <div className="space-y-5">
          <EventTracksMap tracks={tracks} pointsByTrack={pointsByTrack} />

          <div className="space-y-3">
            {tracks.map((track, i) => (
              <div key={track.id} className="flex items-center gap-3 text-sm">
                <span
                  className="h-3 w-3 shrink-0 rounded-full"
                  style={{ background: COLORS[i % COLORS.length] }}
                />
                <Avatar user={track.author} size="sm" />
                <div className="min-w-0 flex-1">
                  <div className="truncate font-semibold text-slate-800">
                    {track.author?.name}
                    <span className="ml-2 font-normal text-slate-400">
                      {track.name ?? 'без названия'}
                    </span>
                  </div>
                  <div className="text-xs text-slate-500">
                    {track.distanceMeters > 0 ? formatDistance(track.distanceMeters) : '—'}
                    {track.durationSeconds > 0 ? ` · ${formatDuration(track.durationSeconds)}` : ''}
                    {track.avgSpeedKph > 0 ? ` · ${track.avgSpeedKph.toFixed(1)} км/ч` : ''}
                    {` · ${track.pointsCount} точек`}
                    {track.endedAt ? ` · финиш ${relativeTime(track.endedAt)}` : ' · идёт запись'}
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div className="border-t border-slate-100 pt-3 text-xs text-slate-400">
            Всего треков: {tracks.length} · точек: {totalPoints}
          </div>
        </div>
      )}
    </Card>
  );
}

/** Все линии участников на одной карте, каждая своим цветом. */
function EventTracksMap({
  tracks,
  pointsByTrack,
}: {
  tracks: EventTrack[];
  pointsByTrack: Record<string, GpsPoint[]>;
}) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);

  const colored = tracks
    .map((t, i) => ({ id: t.id, color: COLORS[i % COLORS.length], points: pointsByTrack[t.id] ?? [] }))
    .filter((t) => t.points.length > 1);

  useEffect(() => {
    if (!containerRef.current || colored.length === 0) return;
    const map = L.map(containerRef.current).setView([55.75, 37.62], 4);
    mapRef.current = map;

    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(map);

    const bounds = L.latLngBounds([]);
    colored.forEach((track) => {
      const coords = track.points.map((p) => [p.lat, p.lng] as L.LatLngTuple);
      const line = L.polyline(coords, { color: track.color, weight: 4, opacity: 0.85 }).addTo(map);
      L.circleMarker(coords[0], { radius: 5, color: '#fff', weight: 2, fillColor: track.color, fillOpacity: 1 })
        .addTo(map)
        .bindPopup('Старт');
      bounds.extend(line.getBounds());
    });

    map.fitBounds(bounds, { padding: [40, 40] });

    return () => {
      map.remove();
      mapRef.current = null;
    };
    // перерисовываем только при изменении набора линий
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [JSON.stringify(Object.keys(pointsByTrack))]);

  if (colored.length === 0) {
    return (
      <div className="flex h-[280px] items-center justify-center rounded-xl border border-slate-200 bg-slate-50 text-sm text-slate-400">
        Точек пока нет — линии появятся после загрузки треков
      </div>
    );
  }

  return <div ref={containerRef} className="h-[380px] w-full rounded-xl border border-slate-200 shadow-sm" />;
}
