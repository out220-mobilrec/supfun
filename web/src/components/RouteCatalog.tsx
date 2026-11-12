import { useCallback, useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { api, errorMessage } from '../lib/api';
import { useAuth } from '../store/AuthContext';
import type { CreateRouteInput, RouteDifficulty, RouteView, WaterBody } from '../types';
import {
  Alert,
  Badge,
  Button,
  Card,
  EmptyState,
  Field,
  Input,
  Loading,
  Select,
  Textarea,
} from '../components/ui';
import { formatDistance, formatSpeed } from '../lib/format';
import { useT } from '../i18n';
import WeatherCard from './WeatherCard';

type LatLng = [number, number];
type Mode = 'view' | 'draw';

const difficultyTone: Record<RouteDifficulty, 'green' | 'amber' | 'red'> = {
  easy: 'green',
  medium: 'amber',
  hard: 'red',
};

export default function RouteCatalog({ admin = false }: { admin?: boolean }) {
  const { user } = useAuth();
  const t = useT();
  const diffLabel = (d: RouteDifficulty) => (d === 'easy' ? 'Easy' : d === 'medium' ? 'Medium' : 'Hard');

  const [routes, setRoutes] = useState<RouteView[]>([]);
  const [waterbodies, setWaterbodies] = useState<WaterBody[]>([]);
  const [waterbodyId, setWaterbodyId] = useState('');
  const [farEast, setFarEast] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // form
  const [formOpen, setFormOpen] = useState(false);
  const [editing, setEditing] = useState<RouteView | null>(null);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [formWaterbodyId, setFormWaterbodyId] = useState('');
  const [difficulty, setDifficulty] = useState<RouteDifficulty>('easy');
  const [published, setPublished] = useState(true);
  const [maxSpeed, setMaxSpeed] = useState('');
  const [expectedDuration, setExpectedDuration] = useState('');
  const [draftPoints, setDraftPoints] = useState<{ lat: number; lng: number }[]>([]);
  const [saving, setSaving] = useState(false);

  // leaflet refs
  const mapElRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<L.Map | null>(null);
  const linesRef = useRef<L.LayerGroup | null>(null);
  const draftRef = useRef<L.LayerGroup | null>(null);
  const modeRef = useRef<Mode>('view');
  const [mapReady, setMapReady] = useState(false);

  const load = useCallback(async (wbId: string, fe: boolean) => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams();
      if (wbId) params.set('waterbodyId', wbId);
      if (fe) params.set('farEast', 'true');
      if (admin) params.set('all', 'true');
      const { data } = await api.get<RouteView[]>(`/routes?${params.toString()}`);
      setRoutes(data);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoading(false);
    }
  }, [admin]);

  useEffect(() => {
    api.get<WaterBody[]>('/waterbodies').then(({ data }) => setWaterbodies(data)).catch(() => {});
  }, []);

  useEffect(() => {
    void load(waterbodyId, farEast);
  }, [waterbodyId, farEast, load]);

  useEffect(() => {
    const el = mapElRef.current;
    if (!el || mapRef.current) return;
    const map = L.map(el, { zoomControl: true }).setView([55.5, 37.5], 4);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(map);
    linesRef.current = L.layerGroup().addTo(map);
    draftRef.current = L.layerGroup().addTo(map);

    const onClick = (e: L.LeafletMouseEvent) => {
      if (modeRef.current !== 'draw') return;
      setDraftPoints((prev) => [...prev, { lat: e.latlng.lat, lng: e.latlng.lng }]);
    };
    map.on('click', onClick);

    const ro = new ResizeObserver(() => map.invalidateSize());
    ro.observe(el);

    mapRef.current = map;
    setMapReady(true);
    return () => {
      ro.disconnect();
      map.off('click', onClick);
      map.remove();
      mapRef.current = null;
      linesRef.current = null;
      draftRef.current = null;
      setMapReady(false);
    };
  }, []);

  useEffect(() => {
    const layer = linesRef.current;
    if (!layer) return;
    layer.clearLayers();
    for (const r of routes) {
      if (r.points.length < 2) continue;
      const latlngs = r.points.map((p): LatLng => [p.lat, p.lng]);
      const isSel = r.id === selectedId;
      L.polyline(latlngs, {
        color: isSel ? '#dc2626' : '#2563eb',
        weight: isSel ? 5 : 3,
        opacity: isSel ? 1 : 0.75,
      })
        .bindPopup(`<b>${r.name}</b><br/>${formatDistance(r.distanceMeters)} · ${r.waterbody?.name ?? ''}`)
        .on('click', () => setSelectedId(r.id))
        .addTo(layer);
      const start = latlngs[0];
      const finish = latlngs[latlngs.length - 1];
      L.circleMarker(start, { radius: 5, color: '#16a34a', weight: 2, fillColor: '#16a34a', fillOpacity: 1 })
        .bindTooltip('Start')
        .addTo(layer);
      L.circleMarker(finish, { radius: 5, color: '#dc2626', weight: 2, fillColor: '#dc2626', fillOpacity: 1 })
        .bindTooltip('Finish')
        .addTo(layer);
    }
  }, [routes, selectedId, mapReady]);

  useEffect(() => {
    const layer = draftRef.current;
    if (!layer) return;
    layer.clearLayers();
    if (draftPoints.length < 2) return;
    const latlngs = draftPoints.map((p): LatLng => [p.lat, p.lng]);
    L.polyline(latlngs, { color: '#f59e0b', weight: 4, dashArray: '6 4', opacity: 0.9 }).addTo(layer);
    latlngs.forEach((pt, i) => {
      L.marker(pt, {
        icon: L.divIcon({
          className: '',
          html: `<div style="background:#f59e0b;color:#fff;width:20px;height:20px;border-radius:9999px;display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;">${i + 1}</div>`,
          iconSize: [20, 20],
          iconAnchor: [10, 10],
        }),
      }).addTo(layer);
    });
  }, [draftPoints, mapReady]);

  useEffect(() => {
    modeRef.current = formOpen ? 'draw' : 'view';
  }, [formOpen]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map || !selectedId) return;
    const r = routes.find((x) => x.id === selectedId);
    if (!r || r.points.length < 2) return;
    const latlngs = r.points.map((p): LatLng => [p.lat, p.lng]);
    map.fitBounds(L.latLngBounds(latlngs), { padding: [40, 40], maxZoom: 13 });
  }, [selectedId, routes]);

  // fit to all routes when filter changes and nothing selected
  useEffect(() => {
    const map = mapRef.current;
    if (!map || selectedId || routes.length === 0) return;
    const all = routes.flatMap((r) => r.points.map((p): LatLng => [p.lat, p.lng]));
    if (all.length >= 2) map.fitBounds(L.latLngBounds(all), { padding: [30, 30], maxZoom: 8 });
  }, [routes, selectedId, mapReady]);

  const openCreate = () => {
    setEditing(null);
    setName('');
    setDescription('');
    setDifficulty('easy');
    setPublished(true);
    setMaxSpeed('');
    setExpectedDuration('');
    setDraftPoints([]);
    setFormWaterbodyId(waterbodyId);
    setFormOpen(true);
  };

  const openEdit = (r: RouteView) => {
    setEditing(r);
    setName(r.name);
    setDescription(r.description ?? '');
    setDifficulty(r.difficulty);
    setPublished(r.published);
    setMaxSpeed(r.maxSpeedKph ? String(r.maxSpeedKph) : '');
    setExpectedDuration(r.expectedDurationMinutes ? String(r.expectedDurationMinutes) : '');
    setFormWaterbodyId(r.waterbodyId);
    setDraftPoints(r.points);
    setFormOpen(true);
  };

  const closeForm = () => {
    setFormOpen(false);
    setEditing(null);
    setDraftPoints([]);
  };

  const removeDraftPoint = () => setDraftPoints((prev) => prev.slice(0, -1));
  const clearDraft = () => setDraftPoints([]);

  const save = async () => {
    if (!name.trim()) { setError(t('routes.name')); return; }
    if (!formWaterbodyId) { setError(t('routes.waterbody')); return; }
    if (draftPoints.length < 2) { setError(t('routes.pointsHint')); return; }
    const payload: CreateRouteInput = {
      name: name.trim(),
      description: description.trim() || undefined,
      waterbodyId: formWaterbodyId,
      difficulty,
      maxSpeedKph: maxSpeed ? Number(maxSpeed) : 0,
      expectedDurationMinutes: expectedDuration ? Number(expectedDuration) : null,
      published,
      points: draftPoints,
    };
    setSaving(true);
    setError('');
    try {
      if (editing) await api.patch(`/routes/${editing.id}`, payload);
      else await api.post('/routes', payload);
      closeForm();
      await load(waterbodyId, farEast);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  const remove = async (r: RouteView) => {
    if (!window.confirm(`${t('common.delete')} "${r.name}"?`)) return;
    try {
      await api.delete(`/routes/${r.id}`);
      if (selectedId === r.id) setSelectedId(null);
      await load(waterbodyId, farEast);
    } catch (err) {
      setError(errorMessage(err));
    }
  };

  const canManage = (r: RouteView) =>
    admin || user?.role === 'admin' || user?.role === 'moderator' || r.authorId === user?.id;

  const selected = routes.find((r) => r.id === selectedId) ?? null;

  return (
    <div className="space-y-5">
      {error && <Alert>{error}</Alert>}

      {formOpen && (
        <Card className="p-4">
          <div className="grid gap-4 md:grid-cols-2">
            <Field label={t('routes.name')}>
              <Input value={name} onChange={(e) => setName(e.target.value)} />
            </Field>
            <Field label={t('routes.waterbody')}>
              <Select value={formWaterbodyId} onChange={(e) => setFormWaterbodyId(e.target.value)}>
                <option value="">{t('routes.selectWaterbody')}</option>
                {waterbodies.map((w) => (
                  <option key={w.id} value={w.id}>{w.name}</option>
                ))}
              </Select>
            </Field>
            <Field label={t('routes.difficulty')}>
              <Select value={difficulty} onChange={(e) => setDifficulty(e.target.value as RouteDifficulty)}>
                <option value="easy">Easy</option>
                <option value="medium">Medium</option>
                <option value="hard">Hard</option>
              </Select>
            </Field>
            <div className="flex items-end">
              <label className="flex items-center gap-2 text-sm text-slate-700">
                <input
                  type="checkbox"
                  checked={published}
                  onChange={(e) => setPublished(e.target.checked)}
                  className="h-4 w-4 rounded border-slate-300 text-brand-600"
                />
                {t('routes.publish')}
              </label>
            </div>
            <div className="md:col-span-2">
              <Field label={t('routes.description')}>
                <Textarea rows={2} value={description} onChange={(e) => setDescription(e.target.value)} />
              </Field>
            </div>
          </div>
          <div className="mt-4 rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
            {t('routes.pointsHint')}
            <div className="mt-2 flex flex-wrap items-center gap-2">
              <span className="text-xs text-amber-700">{t('routes.pointsCount')}: {draftPoints.length}</span>
              <Button size="sm" tone="outline" onClick={removeDraftPoint} disabled={draftPoints.length === 0}>
                {t('routes.undoPoint')}
              </Button>
              <Button size="sm" tone="outline" onClick={clearDraft} disabled={draftPoints.length === 0}>
                {t('routes.clearPoints')}
              </Button>
              <Button size="sm" onClick={save} loading={saving} className="ml-auto">
                {t('routes.save')}
              </Button>
            </div>
          </div>
        </Card>
      )}

      <div className="flex flex-wrap items-center gap-3">
        <Select value={waterbodyId} onChange={(e) => setWaterbodyId(e.target.value)} className="max-w-xs">
          <option value="">{t('routes.allWaterbodies')}</option>
          {waterbodies.map((w) => (
            <option key={w.id} value={w.id}>{w.name}</option>
          ))}
        </Select>
        <Button size="sm" tone={farEast ? 'brand' : 'outline'} onClick={() => setFarEast((v) => !v)}>
          {t('routes.farEast')}
        </Button>
        <span className="text-sm text-slate-500">
          {loading ? t('common.loading') : `${routes.length}`}
        </span>
        <Button className="ml-auto" onClick={formOpen ? closeForm : openCreate}>
          {formOpen ? t('routes.close') : `+ ${t('routes.create')}`}
        </Button>
      </div>

      {selected?.startPoint && (
        <WeatherCard
          lat={selected.startPoint.lat}
          lon={selected.startPoint.lng}
          title={`${t('route.weatherStart')}: ${selected.name}`}
        />
      )}

      <div className="grid gap-5 lg:grid-cols-[1.15fr_1fr]">
        <Card className="overflow-hidden p-0">
          <div ref={mapElRef} className="h-[560px] w-full" />
        </Card>

        <div className="max-h-[560px] space-y-3 overflow-y-auto pr-1">
          {loading ? (
            <Loading />
          ) : routes.length === 0 ? (
            <EmptyState
              title={t('routes.empty')}
              hint={t('routes.pointsHint')}
              action={<Button size="sm" onClick={openCreate}>+ {t('routes.create')}</Button>}
            />
          ) : (
            routes.map((r) => (
              <Card
                key={r.id}
                className={`p-4 ${selectedId === r.id ? 'border-brand-400 ring-1 ring-brand-300' : ''}`}
                onClick={() => setSelectedId(r.id)}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <div className="truncate font-semibold text-slate-900">{r.name}</div>
                    <div className="mt-0.5 text-sm text-slate-500">
                      {r.waterbody?.name ?? '—'}
                      {r.waterbody?.region ? ` · ${r.waterbody.region}` : ''}
                    </div>
                  </div>
                  {!r.published && <Badge tone="slate">draft</Badge>}
                </div>
                <div className="mt-2 flex flex-wrap items-center gap-3 text-sm text-slate-600">
                  <Badge tone={difficultyTone[r.difficulty]}>{diffLabel(r.difficulty)}</Badge>
                  <span>{formatDistance(r.distanceMeters)}</span>
                  {r.maxSpeedKph > 0 && <span>{formatSpeed(r.maxSpeedKph)}</span>}
                  {r.expectedDurationMinutes != null && <span>~{r.expectedDurationMinutes} min</span>}
                </div>
                {r.author && (
                  <div className="mt-2 text-xs text-slate-400">{r.author.name}</div>
                )}
                <div className="mt-3 flex flex-wrap gap-2">
                  {canManage(r) && (
                    <Button size="sm" tone="outline" onClick={(e) => { e.stopPropagation(); openEdit(r); }}>
                      {t('common.edit')}
                    </Button>
                  )}
                  {canManage(r) && (
                    <Button size="sm" tone="red" onClick={(e) => { e.stopPropagation(); void remove(r); }}>
                      {t('common.delete')}
                    </Button>
                  )}
                </div>
              </Card>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
