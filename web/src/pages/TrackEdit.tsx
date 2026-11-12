import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { Track, TrackPoint, WaterBody } from '../types';
import { Alert, Button, Card, Field, Input, Loading, Select } from '../components/ui';
import { TRACK_DIFFICULTIES, type TrackDifficulty } from '../lib/lists';
import { trackDifficultyLabel } from '../lib/labels';
import { formatDistance, formatDuration } from '../lib/format';
import { useT } from '../i18n';

interface EditablePoint {
  id: string;
  lat: number;
  lng: number;
  altitude: number | null;
  speedKph: number | null;
  recordedAt: string;
}

let nextPointId = 1;

function haversine(a: EditablePoint, b: EditablePoint): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function deriveStats(pts: EditablePoint[]) {
  let distance = 0;
  let gain = 0;
  let loss = 0;
  let maxSpeed = 0;
  for (let i = 1; i < pts.length; i += 1) {
    distance += haversine(pts[i - 1], pts[i]);
    const dAlt = (pts[i].altitude ?? 0) - (pts[i - 1].altitude ?? 0);
    if (dAlt > 0) gain += dAlt;
    else loss += Math.abs(dAlt);
    if ((pts[i].speedKph ?? 0) > maxSpeed) maxSpeed = pts[i].speedKph ?? 0;
  }
  const times = pts.map((p) => Date.parse(p.recordedAt)).filter((t) => Number.isFinite(t));
  const duration = times.length > 1 ? Math.round((Math.max(...times) - Math.min(...times)) / 1000) : 0;
  const avgSpeed = duration > 0 ? (distance / duration) * 3.6 : 0;
  return {
    distanceMeters: Math.round(distance * 10) / 10,
    durationSeconds: duration,
    avgSpeedKph: Math.round(avgSpeed * 100) / 100,
    maxSpeedKph: Math.round(maxSpeed * 100) / 100,
    elevationGainMeters: Math.round(gain),
    elevationLossMeters: Math.round(loss),
    calories: Math.round((distance / 1000) * 30),
  };
}

export default function TrackEditPage() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { user: me } = useAuth();

  const [track, setTrack] = useState<Track | null>(null);
  const [points, setPoints] = useState<EditablePoint[]>([]);
  const [waterbodies, setWaterbodies] = useState<WaterBody[]>([]);
  const [editMode, setEditMode] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const [form, setForm] = useState({
    name: '',
    waterBodyId: '',
    difficulty: '' as TrackDifficulty | '',
    distanceMeters: '0',
    durationSeconds: '0',
    avgSpeedKph: '0',
    maxSpeedKph: '0',
    elevationGainMeters: '0',
    elevationLossMeters: '0',
    calories: '0',
  });

  const mapContainerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const layersRef = useRef<L.LayerGroup | null>(null);
  const editModeRef = useRef(false);
  const fittedRef = useRef(false);

  useEffect(() => {
    editModeRef.current = editMode;
  }, [editMode]);

  const load = useCallback(async (opts?: { silent?: boolean }) => {
    if (!id) return;
    if (!opts?.silent) setLoading(true);
    setError('');
    fittedRef.current = false;
    try {
      const [trackRes, pointsRes] = await Promise.all([
        api.get<Track>(`/tracks/${id}`),
        api.get<TrackPoint[]>(`/tracks/${id}/points`),
      ]);
      const trackData = trackRes.data;
      setTrack(trackData);
      setForm({
        name: trackData.name ?? '',
        waterBodyId: trackData.waterBodyId ?? '',
        difficulty: trackData.difficulty ?? '',
        distanceMeters: String(trackData.distanceMeters ?? 0),
        durationSeconds: String(trackData.durationSeconds ?? 0),
        avgSpeedKph: String(trackData.avgSpeedKph ?? 0),
        maxSpeedKph: String(trackData.maxSpeedKph ?? 0),
        elevationGainMeters: String(trackData.elevationGainMeters ?? 0),
        elevationLossMeters: String(trackData.elevationLossMeters ?? 0),
        calories: String(trackData.calories ?? 0),
      });
      setPoints(
        pointsRes.data.map((p) => ({
          id: p.id,
          lat: p.lat,
          lng: p.lng,
          altitude: p.altitude,
          speedKph: p.speedKph,
          recordedAt: p.recordedAt,
        })),
      );
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      if (!opts?.silent) setLoading(false);
    }
  }, [id]);

  useEffect(() => {
    void load();
    api.get<WaterBody[]>('/waterbodies').then(({ data }) => setWaterbodies(data)).catch(() => undefined);
  }, [load]);

  const ready = !loading && !!track;
  useEffect(() => {
    if (!ready || !mapContainerRef.current || mapRef.current) return;
    const map = L.map(mapContainerRef.current).setView([55.75, 37.62], 13);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(map);
    layersRef.current = L.layerGroup().addTo(map);

    map.on('click', (e: L.LeafletMouseEvent) => {
      if (!editModeRef.current) return;
      setPoints((prev) => [
        ...prev,
        {
          id: `new-${nextPointId++}`,
          lat: e.latlng.lat,
          lng: e.latlng.lng,
          altitude: null,
          speedKph: null,
          recordedAt: new Date().toISOString(),
        },
      ]);
    });

    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
      layersRef.current = null;
    };
  }, [ready]);

  useEffect(() => {
    const map = mapRef.current;
    const layer = layersRef.current;
    if (!map || !layer) return;

    layer.clearLayers();
    if (points.length === 0) return;

    const coords = points.map((p) => [p.lat, p.lng] as L.LatLngTuple);

    L.polyline(coords, {
      color: '#2563eb',
      weight: 4,
      dashArray: editMode ? '8 4' : undefined,
      interactive: false,
    }).addTo(layer);

    points.forEach((pt, idx) => {
      const isStart = idx === 0;
      const isEnd = idx === points.length - 1;
      const color = isStart ? '#22c55e' : isEnd ? '#ef4444' : '#3b82f6';
      const marker = L.marker([pt.lat, pt.lng], {
        draggable: editMode,
        icon: L.divIcon({
          className: '',
          html: `<div style="background:${color};width:14px;height:14px;border-radius:50%;border:2px solid white;box-shadow:0 0 4px rgba(0,0,0,.4)"></div>`,
          iconSize: [18, 18],
          iconAnchor: [9, 9],
        }),
      }).addTo(layer);

      marker.bindTooltip(String(idx + 1), { direction: 'top', offset: [0, -8] });

      if (editMode) {
        marker.on('dragend', () => {
          const pos = marker.getLatLng();
          setPoints((prev) =>
            prev.map((p, i) => (i === idx ? { ...p, lat: pos.lat, lng: pos.lng } : p)),
          );
        });
      }
    });

    if (!fittedRef.current) {
      if (coords.length > 1) {
        map.fitBounds(L.latLngBounds(coords), { padding: [40, 40] });
      } else {
        map.setView(coords[0], 15);
      }
      fittedRef.current = true;
    }
  }, [points, editMode]);

  const removePoint = (idx: number) => setPoints((prev) => prev.filter((_, i) => i !== idx));

  const movePoint = (idx: number, dir: -1 | 1) => {
    setPoints((prev) => {
      const target = idx + dir;
      if (target < 0 || target >= prev.length) return prev;
      const arr = [...prev];
      [arr[idx], arr[target]] = [arr[target], arr[idx]];
      return arr;
    });
  };

  const setField = (key: keyof typeof form) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) =>
    setForm((prev) => ({ ...prev, [key]: e.target.value }));

  const derived = useMemo(() => deriveStats(points), [points]);

  const applyDerived = () => {
    setForm((prev) => ({
      ...prev,
      distanceMeters: String(derived.distanceMeters),
      durationSeconds: String(derived.durationSeconds),
      avgSpeedKph: String(derived.avgSpeedKph),
      maxSpeedKph: String(derived.maxSpeedKph),
      elevationGainMeters: String(derived.elevationGainMeters),
      elevationLossMeters: String(derived.elevationLossMeters),
      calories: String(derived.calories),
    }));
  };

  const num = (v: string) => {
    const n = Number(v);
    return Number.isFinite(n) && n >= 0 ? n : 0;
  };

  const save = async () => {
    if (!id || !track) return;
    if (points.length < 2) {
      setError(t('trackEdit.minPoints'));
      return;
    }
    setSaving(true);
    setError('');
    setSuccess('');
    try {
      const existingTimes = points
        .map((p) => Date.parse(p.recordedAt))
        .filter((tt) => Number.isFinite(tt));
      const startMs = existingTimes.length ? Math.min(...existingTimes) : Date.parse(track.startedAt);
      const endMs = existingTimes.length ? Math.max(...existingTimes) : Date.now();
      const spanMs = Math.max(endMs - startMs, (points.length - 1) * 1000);
      const stepMs = spanMs / (points.length - 1);

      await api.put(`/tracks/${id}/points?recalc=false`, {
        points: points.map((p, i) => ({
          lat: p.lat,
          lng: p.lng,
          altitude: p.altitude,
          speedKph: p.speedKph,
          recordedAt: new Date(startMs + stepMs * i).toISOString(),
        })),
      });

      await api.patch(`/tracks/${id}`, {
        name: form.name || null,
        waterBodyId: form.waterBodyId || null,
        difficulty: form.difficulty || null,
        distanceMeters: num(form.distanceMeters),
        durationSeconds: Math.round(num(form.durationSeconds)),
        avgSpeedKph: num(form.avgSpeedKph),
        maxSpeedKph: num(form.maxSpeedKph),
        elevationGainMeters: num(form.elevationGainMeters),
        elevationLossMeters: num(form.elevationLossMeters),
        calories: Math.round(num(form.calories)),
      });

      setSuccess(t('trackEdit.saved'));
      setEditMode(false);
      await load({ silent: true });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <Loading />;
  if (!track) return <Alert>{error || t('trackEdit.notFound')}</Alert>;

  const isOwner = track.userId === me?.id;
  const isAdminOrMod = me?.role === 'admin' || me?.role === 'moderator';
  if (!isOwner && !isAdminOrMod) {
    return <Alert>{t('trackEdit.noRights')}</Alert>;
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-slate-900">{t('trackEdit.title')}</h1>
          <p className="mt-1 text-sm text-slate-500">
            {editMode ? t('trackEdit.hintEdit') : t('trackEdit.hintView')}
          </p>
        </div>
        <div className="flex gap-2">
          <Button size="sm" tone={editMode ? 'red' : 'outline'} onClick={() => setEditMode((v) => !v)}>
            {editMode ? t('trackEdit.finish') : t('trackEdit.editOnMap')}
          </Button>
          <Button size="sm" onClick={() => navigate(`/tracks/${id}`)}>{t('common.cancel')}</Button>
          <Button size="sm" onClick={() => void save()} loading={saving}>{t('common.save')}</Button>
        </div>
      </div>

      {error && <Alert>{error}</Alert>}
      {success && <Alert tone="green">{success}</Alert>}

      <div
        className={`relative rounded-xl border-2 shadow-sm ${
          editMode ? 'border-brand-400' : 'border-slate-200'
        }`}
      >
        <div ref={mapContainerRef} className="h-[500px] w-full rounded-[10px]" />
        {editMode && (
          <div className="pointer-events-none absolute left-1/2 top-3 z-[500] -translate-x-1/2 rounded-full bg-brand-600/90 px-3 py-1 text-xs font-medium text-white shadow">
            {t('trackEdit.mapAddHint')}
          </div>
        )}
      </div>

      <Card className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-semibold text-slate-800">{t('trackEdit.params')}</h2>
          <Button size="sm" tone="outline" onClick={applyDerived} disabled={points.length < 2}>
            {t('trackEdit.recalc')}
          </Button>
        </div>

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Field label={t('label.title')}>
            <Input value={form.name} onChange={setField('name')} placeholder={t('trackEdit.namePlaceholder')} />
          </Field>

          <Field label={t('label.waterbody')}>
            <Select value={form.waterBodyId} onChange={setField('waterBodyId')}>
              <option value="">{t('trackEdit.notSpecified')}</option>
              {waterbodies.map((w) => (
                <option key={w.id} value={w.id}>
                  {w.name}
                  {w.region ? ` — ${w.region}` : ''}
                </option>
              ))}
            </Select>
          </Field>

          <Field label={t('label.difficulty')}>
            <Select value={form.difficulty} onChange={setField('difficulty')}>
              <option value="">{t('trackEdit.difficultyNone')}</option>
              {TRACK_DIFFICULTIES.map((d) => (
                <option key={d} value={d}>
                  {trackDifficultyLabel(d)}
                </option>
              ))}
            </Select>
          </Field>

          <Field label={t('trackEdit.distMeters')} hint={`≈ ${formatDistance(num(form.distanceMeters))}`}>
            <Input type="number" min={0} step={10} value={form.distanceMeters} onChange={setField('distanceMeters')} />
          </Field>

          <Field
            label={t('trackEdit.durationMin')}
            hint={`≈ ${formatDuration(Math.round(num(form.durationSeconds)))}`}
          >
            <Input
              type="number"
              min={0}
              step={5}
              value={form.durationSeconds ? String(Math.round(num(form.durationSeconds) / 60)) : ''}
              onChange={(e) =>
                setForm((f) => ({
                  ...f,
                  durationSeconds: e.target.value
                    ? String(Math.round(num(e.target.value) * 60))
                    : '',
                }))
              }
            />
          </Field>

          <Field label={t('trackEdit.calories')}>
            <Input type="number" min={0} step={10} value={form.calories} onChange={setField('calories')} />
          </Field>

          <Field label={t('trackEdit.avgSpeed')}>
            <Input type="number" min={0} step={0.1} value={form.avgSpeedKph} onChange={setField('avgSpeedKph')} />
          </Field>

          <Field label={t('trackEdit.maxSpeed')}>
            <Input type="number" min={0} step={0.1} value={form.maxSpeedKph} onChange={setField('maxSpeedKph')} />
          </Field>

          <Field label={t('trackEdit.elevation')}>
            <div className="flex gap-2">
              <Input type="number" min={0} value={form.elevationGainMeters} onChange={setField('elevationGainMeters')} />
              <Input type="number" min={0} value={form.elevationLossMeters} onChange={setField('elevationLossMeters')} />
            </div>
          </Field>
        </div>
      </Card>

      <Card className="p-4">
        <div className="mb-3 flex items-center justify-between">
          <h2 className="font-semibold text-slate-800">{t('trackEdit.points')} ({points.length})</h2>
          {editMode && points.length > 0 && (
            <Button size="sm" tone="red" onClick={() => setPoints([])}>
              {t('trackEdit.clearAll')}
            </Button>
          )}
        </div>
        {points.length === 0 ? (
          <p className="text-sm text-slate-400">
            {editMode ? t('trackEdit.noPointsEdit') : t('trackEdit.noPointsView')}
          </p>
        ) : (
          <ul className="max-h-[300px] space-y-1 overflow-y-auto text-sm">
            {points.map((p, idx) => (
              <li key={p.id} className="flex items-center gap-2 rounded-md bg-slate-50 px-3 py-1.5">
                <span className="w-6 text-center font-mono text-xs text-slate-400">{idx + 1}</span>
                <span className="flex-1 text-slate-700">
                  {p.lat.toFixed(6)}, {p.lng.toFixed(6)}
                </span>
                {idx === 0 && <span className="text-xs font-medium text-emerald-600">{t('trackEdit.start')}</span>}
                {idx === points.length - 1 && <span className="text-xs font-medium text-red-500">{t('trackEdit.finishPt')}</span>}
                {editMode && (
                  <div className="flex gap-1">
                    <button onClick={() => movePoint(idx, -1)} disabled={idx === 0} className="rounded px-1.5 py-0.5 text-xs text-slate-500 hover:bg-slate-200 disabled:opacity-30">↑</button>
                    <button onClick={() => movePoint(idx, 1)} disabled={idx === points.length - 1} className="rounded px-1.5 py-0.5 text-xs text-slate-500 hover:bg-slate-200 disabled:opacity-30">↓</button>
                    <button onClick={() => removePoint(idx)} className="rounded px-1.5 py-0.5 text-xs text-red-500 hover:bg-red-50">✕</button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
