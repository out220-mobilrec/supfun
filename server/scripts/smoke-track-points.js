// Runtime smoke-test: route point editor (GET/PUT /tracks/:id/points).
// Run: node scripts/smoke-track-points.js
// Requires: running backend on BASE (default http://localhost:3000/api).
const BASE = process.env.BASE || 'http://localhost:3000/api';
const LOG = process.env.SMOKE_LOG || `${__dirname}/../smoke-server.out`;
const PASSWORD = 'password123';

let pass = 0;
let fail = 0;

function check(name, ok, extra = '') {
  if (ok) {
    pass += 1;
    console.log(`  OK   ${name}`);
  } else {
    fail += 1;
    console.log(`  FAIL ${name} ${extra}`);
  }
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function req(method, path, body, token) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = null;
  try {
    data = await res.json();
  } catch {
    /* empty body */
  }
  return { status: res.status, data };
}

function findCodeInLog(email) {
  const text = require('fs').readFileSync(LOG, 'utf8');
  const BS = String.fromCharCode(92);
  const escaped = email.replace(/[^a-zA-Z0-9@_-]/g, (c) => BS + c);
  const re = new RegExp(`${escaped}[^0-9]{0,500}?([0-9]{6})[^0-9]`, 'g');
  let last = null;
  let m;
  while ((m = re.exec(text)) !== null) last = m[1];
  return last;
}

/// Register a throwaway user, verify with the dev code from the server log, return its token.
async function newUser(email) {
  const reg = await req('POST', '/auth/register', { name: 'Stranger', email, password: PASSWORD });
  if (reg.status >= 400) throw new Error(`register ${email}: ${reg.status}`);
  let code = null;
  for (let i = 0; i < 10 && !code; i += 1) {
    await sleep(700);
    try {
      code = findCodeInLog(email);
    } catch {
      /* log not flushed yet */
    }
  }
  if (!code) throw new Error(`no verification code in log for ${email}`);
  const ver = await req('POST', '/auth/verify-email', { email, code });
  if (ver.status >= 400) throw new Error(`verify ${email}: ${ver.status}`);
  return ver.data.accessToken;
}

// Haversine, mirrors TracksService.haversine
function haversine(a, b) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

function totalDistance(pts) {
  let d = 0;
  for (let i = 1; i < pts.length; i += 1) d += haversine(pts[i - 1], pts[i]);
  return d;
}

async function main() {
  const login = await req('POST', '/auth/login', {
    email: 'admin@supfun.app',
    password: 'password123',
  });
  if (login.status >= 400) throw new Error(`login failed: ${login.status}`);
  const token = login.data.accessToken;
  console.log('signed in as admin');

  // 1. Fresh track without points
  const created = await req('POST', '/tracks', { name: 'Editor smoke', startedAt: new Date().toISOString() }, token);
  check('POST /tracks creates track', created.status === 201 || created.status === 200, `status ${created.status}`);
  const id = created.data.id;

  const empty = await req('GET', `/tracks/${id}/points`, null, token);
  check('GET /tracks/:id/points on empty track -> []', empty.status === 200 && Array.isArray(empty.data) && empty.data.length === 0, `status ${empty.status}`);

  // 2. Append two points the way the mobile client does
  const t0 = Date.parse('2026-01-01T10:00:00Z');
  const seed = [
    { lat: 55.7, lng: 37.6, recordedAt: new Date(t0).toISOString() },
    { lat: 55.8, lng: 37.7, recordedAt: new Date(t0 + 600000).toISOString() },
  ];
  const appended = await req('POST', `/tracks/${id}/points`, { points: seed }, token);
  check('POST /tracks/:id/points appends 2', appended.status === 201 && appended.data.added === 2, JSON.stringify(appended.data));

  // 3. Replace with 5 points (what the web editor sends)
  const drawn = [
    { lat: 55.700000, lng: 37.600000, altitude: 120, speedKph: 5 },
    { lat: 55.702000, lng: 37.605000, altitude: 121, speedKph: 6 },
    { lat: 55.705000, lng: 37.610000, altitude: 122, speedKph: 7 },
    { lat: 55.708000, lng: 37.613000, altitude: 123, speedKph: 8 },
    { lat: 55.712000, lng: 37.615000, altitude: 124, speedKph: 9 },
  ].map((p, i) => ({ ...p, recordedAt: new Date(t0 + i * 120000).toISOString() }));

  const replaced = await req('PUT', `/tracks/${id}/points`, { points: drawn }, token);
  check('PUT /tracks/:id/points replaces all', replaced.status === 200 && replaced.data.replaced === 5, JSON.stringify(replaced.data));

  const after = await req('GET', `/tracks/${id}/points`, null, token);
  check('old points removed, 5 remain', after.data.length === 5, `got ${after.data.length}`);

  // 4. Server orders points by recordedAt -> editor order must survive
  const orderOk = after.data.every((p, i) => Math.abs(p.lat - drawn[i].lat) < 1e-9);
  check('points returned in editor order', orderOk, JSON.stringify(after.data.map((p) => p.lat)));

  // 5. Stats recalculated from the new geometry
  const track = await req('GET', `/tracks/${id}`, null, token);
  const expected = totalDistance(drawn);
  const distOk = Math.abs(track.data.distanceMeters - expected) < 1;
  check('distance recalculated', distOk, `got ${track.data.distanceMeters}, want ~${expected.toFixed(1)}`);
  check('duration preserved from timestamps', track.data.durationSeconds === 480, `got ${track.data.durationSeconds}`);
  check('max speed recalculated', track.data.maxSpeedKph === 9, `got ${track.data.maxSpeedKph}`);
  check('elevation gain recalculated', track.data.elevationGainMeters === 4, `got ${track.data.elevationGainMeters}`);

  // 6. route_line rebuilt as a LineString with all vertices
  const line = track.data.routeLine;
  check('route_line is a LineString', !!line && line.type === 'LineString', JSON.stringify(line && line.type));
  check('route_line has all 5 vertices', !!line && Array.isArray(line.coordinates) && line.coordinates.length === 5, `coords ${line && line.coordinates && line.coordinates.length}`);
  const lineStartOk = !!line && Math.abs(line.coordinates[0][1] - drawn[0].lat) < 1e-9;
  check('route_line starts at first point', lineStartOk);

  // 7. Reordering in the editor must survive a save. Order is defined by recordedAt,
  //    so the editor re-stamps points by position (strictly increasing) — same here.
  const restamp = (pts) =>
    pts.map((p, i) => ({ ...p, recordedAt: new Date(t0 + i * 120000).toISOString() }));
  const reordered = restamp([...drawn].reverse());
  const moved = await req('PUT', `/tracks/${id}/points`, { points: reordered }, token);
  check('PUT accepts reordered points', moved.status === 200 && moved.data.replaced === 5, JSON.stringify(moved.data));
  const afterMove = await req('GET', `/tracks/${id}/points`, null, token);
  const reverseOk = afterMove.data.every((p, i) => Math.abs(p.lat - reordered[i].lat) < 1e-9);
  check('reordered points kept their order', reverseOk, JSON.stringify(afterMove.data.map((p) => p.lat)));

  // 8. Validation: single point rejected by the editor contract is still accepted by API,
  //    but empty array must not wipe stats silently -> we only assert the API stays consistent.
  const single = await req('PUT', `/tracks/${id}/points`, { points: [drawn[0]] }, token);
  check('PUT with 1 point accepted', single.status === 200, `status ${single.status}`);
  const singleTrack = await req('GET', `/tracks/${id}`, null, token);
  check('single point -> zero distance', singleTrack.data.distanceMeters === 0, `got ${singleTrack.data.distanceMeters}`);

  const bad = await req('PUT', `/tracks/${id}/points`, { points: [{ lat: 1000, lng: 0, recordedAt: new Date().toISOString() }] }, token);
  check('invalid latitude rejected', bad.status === 400, `status ${bad.status}`);

  // 8b. The web editor sends altitude/speed as null for hand-placed points
  const handPlaced = [
    { lat: 55.75, lng: 37.62, altitude: null, speedKph: null, recordedAt: new Date(t0).toISOString() },
    { lat: 55.752, lng: 37.625, altitude: null, speedKph: null, recordedAt: new Date(t0 + 60000).toISOString() },
  ];
  const nulled = await req('PUT', `/tracks/${id}/points`, { points: handPlaced }, token);
  check('PUT accepts null altitude/speed', nulled.status === 200 && nulled.data.replaced === 2, `status ${nulled.status} ${JSON.stringify(nulled.data)}`);

  // 9. A stranger cannot rewrite someone else's route
  const stranger = `points-stranger-${Date.now()}@supfun.test`;
  let otherToken = null;
  try {
    otherToken = await newUser(stranger);
  } catch (e) {
    console.log(`  SKIP non-owner check (${e.message})`);
  }
  if (otherToken) {
    const denied = await req('PUT', `/tracks/${id}/points`, { points: drawn }, otherToken);
    check('non-owner non-staff cannot replace points', denied.status === 403 || denied.status === 404, `status ${denied.status}`);
    const deniedRead = await req('GET', `/tracks/${id}/points`, null, otherToken);
    check('non-owner non-staff cannot read points', deniedRead.status === 403 || deniedRead.status === 404, `status ${deniedRead.status}`);
  }

  // 10. No token -> 401
  const anon = await req('GET', `/tracks/${id}/points`);
  check('GET points without token -> 401', anon.status === 401, `status ${anon.status}`);

  // 11. recalc=false keeps manually edited stats untouched
  await req('PUT', `/tracks/${id}/points`, { points: drawn }, token);
  const manual = {
    distanceMeters: 4211.4,
    durationSeconds: 3600,
    avgSpeedKph: 4.21,
    maxSpeedKph: 7.7,
    elevationGainMeters: 11,
    elevationLossMeters: 9,
    calories: 126,
  };
  const patched = await req('PATCH', `/tracks/${id}`, manual, token);
  check('PATCH accepts manual stats', patched.status === 200 && patched.data.distanceMeters === 4211.4, JSON.stringify(patched.data && patched.data.distanceMeters));

  const norecalc = await req('PUT', `/tracks/${id}/points?recalc=false`, { points: drawn }, token);
  check('PUT points?recalc=false -> 200', norecalc.status === 200, `status ${norecalc.status}`);
  const afterNoRecalc = await req('GET', `/tracks/${id}`, null, token);
  const statsKept =
    afterNoRecalc.data.distanceMeters === 4211.4 &&
    afterNoRecalc.data.durationSeconds === 3600 &&
    afterNoRecalc.data.calories === 126;
  check('manual stats survive points save with recalc=false', statsKept, JSON.stringify(afterNoRecalc.data.distanceMeters));

  const withRecalc = await req('PUT', `/tracks/${id}/points?recalc=true`, { points: drawn }, token);
  check('PUT points?recalc=true -> 200', withRecalc.status === 200, `status ${withRecalc.status}`);
  const afterRecalc = await req('GET', `/tracks/${id}`, null, token);
  check('recalc=true overwrites stats from geometry', Math.abs(afterRecalc.data.distanceMeters - totalDistance(drawn)) < 1, `got ${afterRecalc.data.distanceMeters}`);

  // 12. Catalog with filters
  const catalog = await req('GET', '/tracks?scope=public&limit=100', null, token);
  check('GET /tracks -> 200 array', catalog.status === 200 && Array.isArray(catalog.data), `status ${catalog.status}`);

  const mine = await req('GET', '/tracks?scope=mine&limit=100', null, token);
  const mineOk = Array.isArray(mine.data) && mine.data.every((t) => t.userId === login.data.user.id);
  check('GET /tracks?scope=mine returns own only', mine.status === 200 && mineOk, `count ${mine.data && mine.data.length}`);

  const hard = await req('GET', '/tracks?scope=all&difficulty=hard&limit=100', null, token);
  const hardOk = Array.isArray(hard.data) && hard.data.every((t) => t.difficulty === 'hard');
  check('GET /tracks?difficulty=hard filters', hard.status === 200 && hardOk, JSON.stringify(hard.data && hard.data.map((t) => t.difficulty)));

  const dur = await req('GET', '/tracks?scope=all&minDurationSec=400&maxDurationSec=500&limit=100', null, token);
  const durOk = Array.isArray(dur.data) && dur.data.every((t) => t.durationSeconds >= 400 && t.durationSeconds <= 500);
  check('GET /tracks duration range filters', dur.status === 200 && durOk, JSON.stringify(dur.data && dur.data.map((t) => t.durationSeconds)));

  const badQuery = await req('GET', '/tracks?difficulty=nope', null, token);
  check('invalid difficulty -> 400', badQuery.status === 400, `status ${badQuery.status}`);

  // 13. Water body filter (uses the waterbody_id column)
  const wbs = await req('GET', '/waterbodies', null, token);
  const wbId = Array.isArray(wbs.data) && wbs.data.length ? wbs.data[0].id : null;
  if (wbId) {
    const withWb = await req('PATCH', `/tracks/${id}`, { waterBodyId: wbId }, token);
    check('PATCH sets water body', withWb.status === 200 && withWb.data.waterBodyId === wbId, `status ${withWb.status}`);
    const byWb = await req('GET', `/tracks?scope=all&waterBodyId=${wbId}&limit=100`, null, token);
    const wbOk = Array.isArray(byWb.data) && byWb.data.length > 0 && byWb.data.every((t) => t.waterBodyId === wbId);
    check('GET /tracks?waterBodyId filters', byWb.status === 200 && wbOk, `count ${byWb.data && byWb.data.length}`);
    const otherWb = await req('GET', `/tracks?scope=all&waterBodyId=${'0'.repeat(8)}-0000-0000-0000-000000000000`, null, token);
    check('unknown water body -> empty list', otherWb.status === 200 && otherWb.data.length === 0, `count ${otherWb.data && otherWb.data.length}`);
  } else {
    console.log('  SKIP water body filter (no water bodies in DB)');
  }

  await req('DELETE', `/tracks/${id}`, null, token);

  console.log(`\n${pass} passed, ${fail} failed`);
  if (fail > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
