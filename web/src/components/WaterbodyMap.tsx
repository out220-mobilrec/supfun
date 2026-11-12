import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

interface Props {
  latitude: number;
  longitude: number;
  name: string;
  region?: string | null;
}

type Status = 'loading' | 'found' | 'not-found' | 'error';

const NOMINATIM = 'https://nominatim.openstreetmap.org/search';
// Зеркала Overpass: первое упало/таймаут — пробовать следующее
const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];
const WATER_TYPES = ['lake', 'water', 'bay', 'sea', 'river', 'waterway', 'water_area'];

type LatLng = [number, number];
type Ring = LatLng[];

interface OsmRef {
  osm_type: 'way' | 'relation';
  osm_id: number;
}

/** Nominatim: найти OSM-объект (way/relation) по имени водоёма. */
async function findOsmRef(query: string): Promise<OsmRef | null> {
  const url = `${NOMINATIM}?format=geojson&limit=5&q=${encodeURIComponent(query)}`;
  const res = await fetch(url, {
    headers: { Accept: 'application/geo+json' },
    signal: AbortSignal.timeout(12_000),
  });
  if (!res.ok) throw new Error(`nominatim ${res.status}`);
  const data = (await res.json()) as {
    features: { properties: { osm_type?: string; osm_id?: number; type?: string } }[];
  };
  const cands = (data.features ?? []).filter(
    (f) =>
      (f.properties.osm_type === 'way' || f.properties.osm_type === 'relation') &&
      f.properties.osm_id != null,
  );
  const pick = cands.find((f) => WATER_TYPES.includes(f.properties.type ?? '')) ?? cands[0];
  if (!pick) return null;
  return {
    osm_type: pick.properties.osm_type as 'way' | 'relation',
    osm_id: pick.properties.osm_id as number,
  };
}

interface OverpassEl {
  type: string;
  id: number;
  geometry?: { lat: number; lon: number }[];
  members?: { type: string; ref: number; role: string }[];
}

/** Overpass: собрать внешний контур (кольцо [lat,lon]) по OSM-объекту. */
async function fetchOuterRing(ref: OsmRef): Promise<Ring | null> {
  const q =
    ref.osm_type === 'relation'
      ? `[out:json][timeout:25];(relation(${ref.osm_id});way(r););out geom;`
      : `[out:json][timeout:25];way(${ref.osm_id});out geom;`;

  let els: OverpassEl[] | null = null;
  let lastErr: unknown = null;
  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          // overpass-api.de отдаёт 406 без Accept: */*
          Accept: '*/*',
        },
        body: 'data=' + encodeURIComponent(q),
        signal: AbortSignal.timeout(30_000),
      });
      if (!res.ok) throw new Error(`overpass ${res.status}`);
      const data = (await res.json()) as { elements?: OverpassEl[] };
      els = data.elements ?? [];
      break;
    } catch (e) {
      lastErr = e;
    }
  }
  if (!els) throw lastErr instanceof Error ? lastErr : new Error('overpass failed');

  let rings: Ring[];
  if (ref.osm_type === 'way') {
    const w = els.find((e) => e.type === 'way' && e.geometry);
    if (!w || !w.geometry) return null;
    rings = [w.geometry.map((g): LatLng => [g.lat, g.lon])];
  } else {
    const rel = els.find((e) => e.type === 'relation' && e.members);
    const ways = els.filter((e) => e.type === 'way' && e.geometry);
    const outer = new Set<number>();
    (rel?.members ?? [])
      .filter((m) => m.type === 'way' && (m.role === 'outer' || m.role === ''))
      .forEach((m) => outer.add(m.ref));
    rings = ways
      .filter((w) => outer.has(w.id))
      .map((w) => w.geometry!.map((g): LatLng => [g.lat, g.lon]));
    if (!rings.length) rings = ways.map((w) => w.geometry!.map((g): LatLng => [g.lat, g.lon]));
  }
  if (!rings.length) return null;
  return chainWays(rings);
}

/** Сшить way-сегменты в одно замкнутое кольцо (внешний контур). */
function chainWays(ways: Ring[]): Ring | null {
  const pt = (p: LatLng) => p[0].toFixed(6) + ',' + p[1].toFixed(6);
  const pool = ways.map((w) => ({ pts: w, used: false }));
  const rings: Ring[] = [];

  let guard = 0;
  while (pool.some((w) => !w.used) && guard++ < 5000) {
    const start = pool.findIndex((w) => !w.used && w.pts.length >= 2);
    if (start === -1) break;
    pool[start].used = true;
    const ring = pool[start].pts.slice();

    let endPt = ring[ring.length - 1];
    let chained = true;
    while (chained) {
      chained = false;
      const idx = pool.findIndex(
        (w) =>
          !w.used &&
          w.pts.length >= 2 &&
          (pt(w.pts[0]) === pt(endPt) || pt(w.pts[w.pts.length - 1]) === pt(endPt)),
      );
      if (idx === -1) break;
      pool[idx].used = true;
      const seg =
        pt(pool[idx].pts[pool[idx].pts.length - 1]) === pt(endPt)
          ? pool[idx].pts.slice().reverse()
          : pool[idx].pts;
      ring.push(...seg.slice(1));
      endPt = ring[ring.length - 1];
      chained = true;
    }

    if (ring.length >= 4) {
      if (pt(ring[0]) !== pt(ring[ring.length - 1])) ring.push(ring[0]);
      rings.push(ring);
    }
  }
  if (!rings.length) return null;
  rings.sort((a, b) => b.length - a.length);
  return rings[0];
}

/**
 * Карта водоёма: тайлы OSM (свободные, с атрибуцией) + контур самого водоёма.
 * Контур — бесплатно и без ключей: Nominatim (найти OSM-объект) → Overpass API
 * (геометрия полигона); запросы идут из браузера. Не удалось — показана точка.
 */
export default function WaterbodyMap({ latitude, longitude, name, region }: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [status, setStatus] = useState<Status>('loading');

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    let cancelled = false;

    const map = L.map(el, { zoomControl: true }).setView([latitude, longitude], 6);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
    }).addTo(map);

    const marker = L.circleMarker([latitude, longitude], {
      radius: 8,
      color: '#1d4ed8',
      weight: 2,
      fillColor: '#3b82f6',
      fillOpacity: 0.6,
    }).addTo(map);
    marker.bindPopup(`<b>${name}</b>${region ? `<br/>${region}` : ''}`);

    const query = region ? `${name}, ${region}` : name;
    (async () => {
      try {
        const ref = await findOsmRef(query);
        if (cancelled) return;
        if (!ref) {
          setStatus('not-found');
          return;
        }
        const ring = await fetchOuterRing(ref);
        if (cancelled) return;
        if (!ring) {
          setStatus('not-found');
          return;
        }
        const layer = L.polygon(ring, {
          color: '#1d4ed8',
          weight: 3,
          fillColor: '#60a5fa',
          fillOpacity: 0.15,
          dashArray: '6 4',
        }).addTo(map);
        map.fitBounds(layer.getBounds(), { padding: [24, 24], maxZoom: 11 });
        setStatus('found');
      } catch {
        if (!cancelled) setStatus('error');
      }
    })();

    return () => {
      cancelled = true;
      map.remove();
    };
  }, [latitude, longitude, name, region]);

  return (
    <div className="relative">
      <div
        ref={containerRef}
        className="h-[420px] w-full rounded-xl border border-slate-200 shadow-sm"
      />
      <div className="absolute left-3 top-3 z-10 rounded-md bg-white/90 px-2.5 py-1 text-xs text-slate-600 shadow">
        {status === 'loading' && 'Ищем контур водоёма (OpenStreetMap)…'}
        {status === 'found' && 'Контур: OpenStreetMap (Nominatim + Overpass)'}
        {status === 'not-found' && 'Контур не найден — показана точка'}
        {status === 'error' && 'Контур недоступен — показана точка'}
      </div>
    </div>
  );
}
