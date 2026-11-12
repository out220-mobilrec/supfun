/// Улучшение геометрии маршрутов Дальнего Востока: попытка взять контур водоёма
/// через Overpass (OSM), построить маршруты вдоль/по акватории; при недоступности
/// сети — fallback на текущую (синтетическую) генерацию.
/// Перезаписывает route_points и distance_meters для найденных Far East маршрутов.
///
///   node scripts/seed-far-east-routes-real.js           — просмотр (сеть по возможности)
///   node scripts/seed-far-east-routes-real.js --apply   — запись
///   node scripts/seed-far-east-routes-real.js --offline — только fallback (без Overpass)
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const https = require('https');
const http = require('http');
const { Pool } = require('pg');

const APPLY = process.argv.includes('--apply');
const OFFLINE = process.argv.includes('--offline');

const OVERPASS_ENDPOINTS = [
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://overpass.nchc.org.tw/api/interpreter',
];

const R = 6371000;
const rad = (d) => (d * Math.PI) / 180;
function haversine(a, b) {
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const la1 = rad(a.lat);
  const la2 = rad(b.lat);
  const h = Math.sin(dLat / 2) ** 2 + Math.sin(dLng / 2) ** 2 * Math.cos(la1) * Math.cos(la2);
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}
function lineMeters(points) {
  let t = 0;
  for (let i = 1; i < points.length; i++) t += haversine(points[i - 1], points[i]);
  return Math.round(t);
}
function off(lat0, lng0, dxKm, dyKm) {
  const dLat = dyKm / 110.574;
  const dLng = dxKm / (111.320 * Math.cos(rad(lat0)) || 1);
  return { lat: +(lat0 + dLat).toFixed(6), lng: +(lng0 + dLng).toFixed(6) };
}

function requestText(url, { method = 'GET', body = null, headers = {}, timeoutMs = 20000 } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request(
      u,
      {
        method,
        headers: { 'User-Agent': 'SUPFUN-seed/1.0', ...headers },
        timeout: timeoutMs,
      },
      (res) => {
        let data = '';
        res.setEncoding('utf8');
        res.on('data', (c) => (data += c));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) resolve(data);
          else reject(new Error(`HTTP ${res.statusCode} ${url}`));
        });
      },
    );
    req.on('timeout', () => req.destroy(new Error(`timeout ${url}`)));
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function overpass(query) {
  if (OFFLINE) throw new Error('offline');
  const body = `data=${encodeURIComponent(query)}`;
  let last;
  for (const ep of OVERPASS_ENDPOINTS) {
    try {
      const txt = await requestText(ep, {
        method: 'POST',
        body,
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        timeoutMs: 25000,
      });
      return JSON.parse(txt);
    } catch (e) {
      last = e;
    }
  }
  throw last || new Error('overpass unavailable');
}

// Собирает полилинии (outer ways) из ответа Overpass (out geom) и выбирает
// самую длинную/подходящую — даёт приближение береговой линии/контура.
function extractOutline(osm, center) {
  const els = Array.isArray(osm?.elements) ? osm.elements : [];
  let best = null;
  let bestScore = -1;
  for (const el of els) {
    let coords = null;
    if (el.type === 'way' && Array.isArray(el.geometry)) {
      coords = el.geometry.map((g) => ({ lat: g.lat, lng: g.lon }));
    } else if (el.type === 'relation' && Array.isArray(el.members)) {
      // берем самый длинный outer way
      for (const m of el.members) {
        if (m.role === 'outer' && Array.isArray(m.geometry)) {
          const c = m.geometry.map((g) => ({ lat: g.lat, lng: g.lon }));
          const len = lineMeters(c);
          if (len > bestScore) { bestScore = len; best = c; }
        }
      }
      continue;
    }
    if (coords && coords.length >= 4) {
      const len = lineMeters(coords);
      // предпочитаем контуры, не слишком далеко от центра
      const mid = coords[Math.floor(coords.length / 2)];
      const d = haversine(mid, center);
      const score = len - d * 0.2;
      if (score > bestScore) { bestScore = score; best = coords; }
    }
  }
  return best && best.length >= 4 ? best : null;
}

// Упрощение/даунсэмпл до ~N точек, сохраняя форму.
function resample(points, maxN) {
  if (points.length <= maxN) return points;
  const step = (points.length - 1) / (maxN - 1);
  const out = [];
  for (let i = 0; i < maxN; i++) out.push(points[Math.round(i * step)]);
  return out;
}

// Слегка «внутрь» относительно центра — грубая инсет-аппроксимация, чтобы
// маршрут не шёл строго по берегу.
function inset(points, center, factor = 0.12) {
  return points.map((p) => ({
    lat: +(p.lat + (center.lat - p.lat) * factor).toFixed(6),
    lng: +(p.lng + (center.lng - p.lng) * factor).toFixed(6),
  }));
}

function routeObj(name, description, difficulty, maxSpeedKph, points) {
  const distanceMeters = lineMeters(points);
  const expectedDurationMinutes =
    maxSpeedKph > 0 ? Math.round((distanceMeters / 1000 / maxSpeedKph) * 60 * 1.15) : null;
  return { name, description, difficulty, maxSpeedKph, distanceMeters, expectedDurationMinutes, points };
}

// Генерация 3 маршрутов из реального контура.
function routesFromOutline(wb, outline) {
  const c = { lat: wb.center[0], lng: wb.center[1] };
  const base = resample(inset(outline, c, 0.15), 24);
  const n = base.length;
  const seg = (fromFrac, toFrac, close = false) => {
    let a = Math.floor(fromFrac * (n - 1));
    let b = Math.floor(toFrac * (n - 1));
    if (b <= a) b = Math.min(n - 1, a + 4);
    const pts = base.slice(a, b + 1);
    if (close && pts.length > 2) pts.push(pts[0]);
    return pts.length >= 2 ? pts : null;
  };
  const walk = seg(0, 0.35, true) || resample(base, 8).concat([base[0]]);
  const coastal = seg(0.05, 0.75, false) || resample(base, 12);
  const radial = (() => {
    const a = base[0];
    const m = base[Math.floor(n * 0.5)];
    const z = base[n - 1];
    return [a, base[Math.floor(n * 0.2)], m, base[Math.floor(n * 0.75)], z];
  })();
  return [
    routeObj(`${wb.short}: прогулочный круг`, `Спокойный маршрут по акватории «${wb.name}» (геометрия по OSM/контуру). Рекомендуется при слабом ветре.`, 'easy', 5.5, walk),
    routeObj(`${wb.short}: береговая линия`, `Маршрут вдоль береговой линии «${wb.name}» (по контуру акватории). Контролируйте ветер и течение.`, 'medium', 6.5, coastal),
    routeObj(`${wb.short}: дальний радиал`, `Протяжённый маршрут для подготовленных сапбордистов по акватории «${wb.name}».`, 'hard', 7.0, radial),
  ];
}

// Fallback — синтетика как в seed-far-east.js
function syntheticRoutes(wb) {
  const [lat, lng] = wb.center;
  const s = wb.scale ?? 1;
  const p = (dx, dy) => off(lat, lng, dx, dy);
  return [
    routeObj(`${wb.short}: прогулочный круг`, `Спокойный маршрут для ознакомления с акваторией «${wb.name}». Рекомендуется при слабом ветре.`, 'easy', 5.5,
      [p(-0.8*s,-0.2*s),p(-0.3*s,0.4*s),p(0.5*s,0.5*s),p(1.0*s,0.1*s),p(0.6*s,-0.5*s),p(-0.2*s,-0.6*s),p(-0.8*s,-0.2*s)]),
    routeObj(`${wb.short}: береговая линия`, `Маршрут вдоль береговой линии с видами на «${wb.name}». Контролируйте ветер и течение.`, 'medium', 6.5,
      [p(-1.6*s,0),p(-1.0*s,0.3*s),p(-0.2*s,0.5*s),p(0.6*s,0.4*s),p(1.4*s,0.1*s),p(2.0*s,-0.2*s)]),
    routeObj(`${wb.short}: дальний радиал`, `Протяжённый маршрут для подготовленных сапбордистов по акватории «${wb.name}».`, 'hard', 7.0,
      [p(0,-0.2*s),p(0.4*s,0.6*s),p(1.2*s,1.2*s),p(2.2*s,1.5*s),p(3.0*s,1.1*s),p(3.4*s,0.4*s)]),
  ];
}

// Конфиг водоёмов ДВ (имя в БД -> параметры поиска Overpass)
const TARGETS = [
  { name: 'Амурский залив', short: 'Амурский залив', center: [43.1, 131.75], scale: 1.2, q: '["name"~"Амурский залив",i]["natural"~"bay|water"]' },
  { name: 'Уссурийский залив', short: 'Уссурийский залив', center: [43.15, 132.05], scale: 1.3, q: '["name"~"Уссурийский залив",i]["natural"~"bay|water"]' },
  { name: 'Бухта Золотой Рог', short: 'Золотой Рог', center: [43.1086, 131.8936], scale: 0.45, q: '["name"~"Золотой Рог",i]["natural"~"bay"]' },
  { name: 'Бухта Новик', short: 'Новик', center: [43.05, 131.85], scale: 0.8, q: '["name"~"Новик",i]["natural"~"bay"]' },
  { name: 'Река Амур (Хабаровск)', short: 'Амур', center: [48.48, 135.07], scale: 1.4, q: '["name"="Амур"]["waterway"="river"]' },
  { name: 'Озеро Лотосов (Ханка)', short: 'Лотосы', center: [44.683, 132.45], scale: 0.6, q: '["name"~"Ханка",i]["natural"="water"]' },
  { name: 'Авачинская бухта', short: 'Авачинская бухта', center: [52.9833, 158.55], scale: 1.5, q: '["name"~"Авачинская",i]["natural"~"bay"]' },
  { name: 'Бухта Моховая', short: 'Моховая', center: [53.033, 158.6], scale: 0.5, q: '["name"~"Моховая",i]["natural"~"bay"]' },
  { name: 'Озеро Култучное', short: 'Култучное', center: [53.035, 158.645], scale: 0.35, q: '["name"~"Култучное",i]["natural"="water"]' },
  { name: 'Бухта Буссе', short: 'Буссе', center: [46.53, 143.32], scale: 1.1, q: '["name"~"Буссе",i]["natural"~"bay|water"]' },
  { name: 'Залив Анива', short: 'Анива', center: [46.3, 142.7], scale: 1.6, q: '["name"~"Анива",i]["natural"~"bay"]' },
  { name: 'Озеро Тунайча', short: 'Тунайча', center: [46.83, 143.15], scale: 1.2, q: '["name"~"Тунайча",i]["natural"="water"]' },
  { name: 'Татарский пролив (Советская Гавань)', short: 'Совгавань', center: [48.966, 140.285], scale: 1.0, q: '["name"~"Советская Гавань",i]["natural"~"bay|water"]' },
  { name: 'Река Уссури (Лесозаводск)', short: 'Уссури', center: [45.478, 133.428], scale: 1.1, q: '["name"="Уссури"]["waterway"="river"]' },
  { name: 'Залив Находка', short: 'Находка', center: [42.8, 132.883], scale: 1.3, q: '["name"~"Находка",i]["natural"~"bay"]' },
  { name: 'Бухта Врангеля', short: 'Врангеля', center: [42.75, 133.07], scale: 0.7, q: '["name"~"Врангеля",i]["natural"~"bay"]' },
  { name: 'Озеро Большое Кизи', short: 'Кизи', center: [51.6, 140.45], scale: 1.4, q: '["name"~"Кизи",i]["natural"="water"]' },
  { name: 'Залив Владимира', short: 'Владимира', center: [43.9, 135.52], scale: 1.0, q: '["name"~"Владимира",i]["natural"~"bay"]' },
  { name: 'Бухта Ольга', short: 'Ольга', center: [43.744, 135.287], scale: 0.8, q: '["name"~"Ольга",i]["natural"~"bay"]' },
  { name: 'Река Зея (Благовещенск)', short: 'Зея', center: [50.29, 127.53], scale: 1.2, q: '["name"="Зея"]["waterway"="river"]' },
  { name: 'Бухта Провидения', short: 'Провидения', center: [64.428, -173.226], scale: 0.9, q: '["name"~"Провидения",i]["natural"~"bay"]' },
  { name: 'Бухта Нагаева', short: 'Нагаева', center: [59.566, 150.8], scale: 0.9, q: '["name"~"Нагаева",i]["natural"~"bay"]' },
  { name: 'Озеро Джека Лондона', short: 'Джека Лондона', center: [62.08, 149.53], scale: 0.9, q: '["name"~"Джека Лондона",i]["natural"="water"]' },
  { name: 'Река Лена (Якутск)', short: 'Лена', center: [62.028, 129.733], scale: 1.6, q: '["name"="Лена"]["waterway"="river"]' },
];

async function fetchOutline(wb) {
  const [lat, lng] = wb.center;
  const around = `around:${Math.round((wb.scale ?? 1) * 6000)},${lat},${lng}`;
  // relation/way с геометрией
  const query = `[out:json][timeout:25];
(
  nwr${wb.q}(${around});
  nwr["natural"~"water|bay|strait|coastline"](${around});
);
out geom 40;`;
  const osm = await overpass(query);
  return extractOutline(osm, { lat, lng });
}

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST ?? '127.0.0.1',
    port: Number(process.env.DB_PORT ?? 5432),
    user: process.env.DB_USERNAME ?? process.env.DB_USER ?? 'postgres',
    password: process.env.DB_PASSWORD ?? 'postgres',
    database: process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'sup_fun',
  });

  let real = 0, fallback = 0, updatedRoutes = 0, createdRoutes = 0;
  for (const wb of TARGETS) {
    const row = await pool.query('SELECT id FROM waterbodies WHERE name=$1', [wb.name]);
    if (row.rowCount === 0) { console.log(`skip (no waterbody): ${wb.name}`); continue; }
    const waterbodyId = row.rows[0].id;

    let routes;
    let source = 'fallback';
    try {
      const outline = await fetchOutline(wb);
      if (outline) { routes = routesFromOutline(wb, outline); source = 'osm'; real++; }
      else { routes = syntheticRoutes(wb); fallback++; }
    } catch (e) {
      routes = syntheticRoutes(wb); fallback++;
      if (!OFFLINE) console.log(`  ${wb.name}: Overpass недоступен (${e.message}) -> fallback`);
    }

    console.log(`• ${wb.name} [${source}] — ${routes.length} маршрута`);
    for (const r of routes) console.log(`    - ${r.name} (${r.distanceMeters} м)`);

    if (!APPLY) continue;
    for (const r of routes) {
      const ex = await pool.query('SELECT id FROM routes WHERE waterbody_id=$1 AND name=$2 LIMIT 1', [waterbodyId, r.name]);
      let routeId;
      if (ex.rowCount > 0) {
        routeId = ex.rows[0].id;
        await pool.query(
          `UPDATE routes SET description=$2, difficulty=$3, max_speed_kph=$4, expected_duration_minutes=$5, distance_meters=$6, updated_at=now() WHERE id=$1`,
          [routeId, r.description, r.difficulty, r.maxSpeedKph, r.expectedDurationMinutes, r.distanceMeters],
        );
        await pool.query('DELETE FROM route_points WHERE route_id=$1', [routeId]);
        updatedRoutes++;
      } else {
        // нужен author_id — возьмём из любого существующего маршрута этого водоёма или admin
        const ar = await pool.query('SELECT author_id FROM routes WHERE waterbody_id=$1 LIMIT 1', [waterbodyId]);
        let authorId = ar.rows[0]?.author_id;
        if (!authorId) {
          const u = await pool.query(`SELECT id FROM users WHERE role='admin' ORDER BY created_at LIMIT 1`);
          authorId = u.rows[0]?.id;
        }
        if (!authorId) { console.log('    ! нет автора, пропуск создания'); continue; }
        const ins = await pool.query(
          `INSERT INTO routes (id,name,description,waterbody_id,author_id,distance_meters,difficulty,max_speed_kph,expected_duration_minutes,published,created_at,updated_at)
           VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8,TRUE,now(),now()) RETURNING id`,
          [r.name, r.description, waterbodyId, authorId, r.distanceMeters, r.difficulty, r.maxSpeedKph, r.expectedDurationMinutes],
        );
        routeId = ins.rows[0].id;
        createdRoutes++;
      }
      for (let i = 0; i < r.points.length; i++) {
        const pt = r.points[i];
        await pool.query(
          `INSERT INTO route_points (id,route_id,lat,lng,seq,created_at) VALUES (gen_random_uuid(),$1,$2,$3,$4,now())`,
          [routeId, pt.lat, pt.lng, i + 1],
        );
      }
    }
  }

  console.log(`\nИтог: геометрия по OSM=${real}, fallback=${fallback}. ${APPLY ? `Обновлено маршрутов: ${updatedRoutes}, создано: ${createdRoutes}.` : 'Режим просмотра (добавьте --apply).'} `);
  if (!APPLY && !OFFLINE && fallback > 0) console.log('Подсказка: на машине с доступом к Overpass запустите с --apply для реальных контуров.');
  await pool.end();
}

main().catch((e) => { console.error(e); process.exit(1); });
