import { useCallback, useEffect, useRef, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { RouteView, Track, TrackPoint } from '../types';
import { Alert, Button, Card, Loading } from '../components/ui';
import { TrackDifficultyBadge, TrackStatusBadge } from '../components/statusBadges';
import { ReviewsSection } from '../components/ReviewsSection';
import { formatDistance, formatDuration, formatSpeed } from '../lib/format';
import { useT } from '../i18n';

export default function TrackDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user: me } = useAuth();
  const t = useT();
  const [track, setTrack] = useState<Track | null>(null);
  const [points, setPoints] = useState<TrackPoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    if (!id) return;
    setLoading(true);
    setError('');
    try {
      const [trackRes, pointsRes] = await Promise.all([
        api.get<Track>(`/tracks/${id}`),
        api.get<TrackPoint[]>(`/tracks/${id}/points`),
      ]);
      setTrack(trackRes.data);
      setPoints(pointsRes.data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  if (loading) return <Loading />;
  if (error) return <Alert>{error}</Alert>;
  if (!track) return <Alert>{t('common.notFound')}</Alert>;

  const isOwner = track.userId === me?.id;
  const isAdminOrMod = me?.role === 'admin' || me?.role === 'moderator';
  const canEdit = isOwner || isAdminOrMod;

  return (
    <div className="space-y-5">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{track.name ?? t('dashboard.untitledRoute')}</h1>
          <div className="mt-1 flex items-center gap-2 text-sm text-slate-500">
            <TrackStatusBadge status={track.status} />
            <TrackDifficultyBadge difficulty={track.difficulty} />
          </div>
        </div>
        {canEdit && (
          <Button size="sm" onClick={() => navigate(`/tracks/${id}/edit`)}>
            {t('common.edit')}
          </Button>
        )}
      </div>

      <RouteMap points={points} refRoute={track.route ?? null} />

      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">{t('nav.profile')}</div>
          <div className="mt-1 font-semibold text-slate-800">
            {track.user?.name ?? <span className="text-slate-400">—</span>}
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">Distance</div>
          <div className="mt-1 font-semibold text-slate-800">{formatDistance(track.distanceMeters)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">Duration</div>
          <div className="mt-1 font-semibold text-slate-800">{formatDuration(track.durationSeconds)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">Avg speed</div>
          <div className="mt-1 font-semibold text-slate-800">{formatSpeed(track.avgSpeedKph)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">Max speed</div>
          <div className="mt-1 font-semibold text-slate-800">{formatSpeed(track.maxSpeedKph)}</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">Elevation</div>
          <div className="mt-1 font-semibold text-slate-800">
            +{Math.round(track.elevationGainMeters)} m / -{Math.round(track.elevationLossMeters)} m
          </div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">Calories</div>
          <div className="mt-1 font-semibold text-slate-800">{track.calories} kcal</div>
        </Card>
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">{t('route.points')}</div>
          <div className="mt-1 font-semibold text-slate-800">{points.length}</div>
        </Card>
      </div>

      {track.waterBody && (
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">{t('nav.waterbodies')}</div>
          <Link to={`/waterbodies/${track.waterBody.id}`} className="mt-1 block font-semibold text-brand-600 hover:underline">
            {track.waterBody.name}
          </Link>
        </Card>
      )}

      {track.route && (
        <Card className="p-4">
          <div className="text-xs uppercase tracking-wide text-slate-400">{t('track.route')}</div>
          <Link
            to={track.route.waterbodyId ? `/waterbodies/${track.route.waterbodyId}` : '/routes'}
            className="mt-1 block font-semibold text-brand-600 hover:underline"
          >
            {track.route.name}
          </Link>
          <div className="mt-1 text-sm text-slate-500">
            {formatDistance(track.route.distanceMeters)} · {track.route.difficulty}
          </div>
          {track.route.points?.length ? (
            <div className="mt-1 text-xs text-slate-400">
              {t('route.points')}: {track.route.points.length} (reference line shown on map)
            </div>
          ) : null}
        </Card>
      )}

      <ReviewsSection targetType="track" targetId={track.id} />
    </div>
  );
}

function RouteMap({ points, refRoute }: { points: TrackPoint[]; refRoute: RouteView | null }) {
  const containerRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    if (!containerRef.current) return;
    const hasPoints = points.length > 0;
    const refPts = refRoute?.points ?? [];
    const center: [number, number] = hasPoints
      ? [points[0].lat, points[0].lng]
      : refPts.length
        ? [refPts[0].lat, refPts[0].lng]
        : [55.5, 37.5];
    const map = L.map(containerRef.current).setView(center, 14);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(map);

    const bounds: L.LatLngTuple[] = [];

    if (refPts.length >= 2) {
      const refCoords = refPts.map((p) => [p.lat, p.lng] as L.LatLngTuple);
      L.polyline(refCoords, { color: '#f59e0b', weight: 4, dashArray: '8 6', opacity: 0.9 })
        .addTo(map)
        .bindPopup(`Route: ${refRoute?.name ?? ''}`);
      bounds.push(...refCoords);
    }

    if (hasPoints) {
      const coords = points.map((p) => [p.lat, p.lng] as L.LatLngTuple);
      L.polyline(coords, { color: '#2563eb', weight: 4 }).addTo(map);
      bounds.push(...coords);

      L.marker(coords[0], {
        icon: L.divIcon({
          className: '',
          html: '<div style="background:#22c55e;width:14px;height:14px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,.4)"></div>',
          iconSize: [18, 18],
          iconAnchor: [9, 9],
        }),
      }).addTo(map).bindPopup('Start');

      L.marker(coords[coords.length - 1], {
        icon: L.divIcon({
          className: '',
          html: '<div style="background:#ef4444;width:14px;height:14px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,.4)"></div>',
          iconSize: [18, 18],
          iconAnchor: [9, 9],
        }),
      }).addTo(map).bindPopup('Finish');
    }

    if (bounds.length >= 2) {
      map.fitBounds(L.latLngBounds(bounds), { padding: [40, 40] });
    }

    return () => { map.remove(); };
  }, [points, refRoute]);

  return (
    <div className="relative">
      <div
        ref={containerRef}
        className="h-[420px] w-full rounded-xl border border-slate-200 shadow-sm"
      />
      {points.length === 0 && !(refRoute?.points?.length) && (
        <div className="absolute inset-0 flex items-center justify-center rounded-xl border border-slate-200 bg-slate-50 text-sm text-slate-400">
          —
        </div>
      )}
    </div>
  );
}
