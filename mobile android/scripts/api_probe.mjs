// Dev tool: prints real backend response shapes so the Flutter models match.
// Usage: node scripts/api_probe.mjs [BASE]
// Requires a running backend and server/scripts/dbq.js (used to force email
// verification in dev, since codes are only logged, never returned).
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const BASE = process.argv[2] || 'http://localhost:3000/api';
const DBQ = process.env.DBQ || '../server/scripts/dbq.js';
const PASSWORD = 'password123';
const CODE = '123456';
const email = `mob.probe.${Date.now()}@supfun.app`;

function sql(query) {
  const out = execFileSync('node', [DBQ, query], { encoding: 'utf8' });
  try {
    return JSON.parse(out);
  } catch {
    return [];
  }
}

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

function shape(value, depth = 0) {
  if (value === null) return 'null';
  if (Array.isArray(value)) {
    if (value.length === 0) return '[]';
    return `[${shape(value[0], depth + 1)}]`;
  }
  if (typeof value === 'object') {
    if (depth > 2) return '{...}';
    const parts = Object.entries(value).map(([k, v]) => `${k}:${shape(v, depth + 1)}`);
    return `{${parts.join(', ')}}`;
  }
  return typeof value;
}

const reg = await req('POST', '/auth/register', {
  name: 'Mobile Probe',
  email,
  password: PASSWORD,
  city: 'Хабаровск',
});
console.log('register', reg.status, JSON.stringify(reg.data));

const [row] = sql(`SELECT id FROM users WHERE email='${email}'`);
if (!row) throw new Error('user not created');
sql(
  `DELETE FROM auth_tokens WHERE user_id='${row.id}' AND type='email_verify';` +
    `INSERT INTO auth_tokens (id, user_id, type, token_hash, expires_at, attempt_count, created_at)` +
    ` VALUES (gen_random_uuid(), '${row.id}', 'email_verify',` +
    ` '${createHash('sha256').update(CODE).digest('hex')}',` +
    ` now() + interval '15 minutes', 0, now())`,
);

const ver = await req('POST', '/auth/verify-email', { email, code: CODE });
console.log('verify', ver.status);
if (ver.status >= 400) throw new Error('verify failed: ' + JSON.stringify(ver.data));
const token = ver.data.accessToken;

const endpoints = [
  ['GET', '/users/me'],
  ['GET', '/gamification/me'],
  ['GET', '/gamification/achievements'],
  ['GET', '/gamification/points'],
  ['GET', '/gamification/rules'],
  ['GET', '/feed?limit=5'],
  ['GET', '/waterbodies?limit=3'],
  ['GET', '/waterbodies/nearby?lat=48.48&lng=135.08&radius=50000'],
  ['GET', '/events?limit=3'],
  ['GET', '/tracks?limit=3'],
  ['GET', '/tracks/mine'],
  ['GET', '/marketplace/listings?limit=3'],
  ['GET', '/marketplace/categories'],
  ['GET', '/conversations'],
  ['GET', '/notifications'],
  ['GET', '/ratings/leaderboard?scope=all&limit=3'],
  ['GET', '/gear/mine'],
  ['GET', '/news?limit=3'],
  ['GET', '/channels'],
  ['GET', '/friends'],
  ['GET', '/search?q=a&limit=3'],
  ['GET', '/reference/countries'],
];

for (const [method, path] of endpoints) {
  const r = await req(method, path, undefined, token);
  console.log(`\n${method} ${path} -> ${r.status}`);
  console.log(shape(r.data));
}

const wb = await req('GET', '/waterbodies?limit=1', undefined, token);
const wbId = wb.data?.[0]?.id;
if (wbId) {
  const one = await req('GET', `/waterbodies/${wbId}`, undefined, token);
  console.log('\nGET /waterbodies/:id ->', one.status);
  console.log(JSON.stringify(one.data));
}

const created = await req(
  'POST',
  '/tracks',
  { name: 'Probe track', startedAt: new Date(Date.now() - 60000).toISOString() },
  token,
);
console.log('\nPOST /tracks ->', created.status, JSON.stringify(created.data).slice(0, 400));
const trackId = created.data?.id;
if (trackId) {
  const pts = [];
  for (let i = 0; i < 6; i += 1) {
    pts.push({
      seq: i,
      lat: 48.48 + i * 0.0006,
      lng: 135.08 + i * 0.0006,
      altitude: 40 + i,
      speedKph: 4 + i * 0.1,
      recordedAt: new Date(Date.now() - (6 - i) * 10000).toISOString(),
    });
  }
  const added = await req('POST', `/tracks/${trackId}/points`, { points: pts }, token);
  console.log('POST /tracks/:id/points ->', added.status, JSON.stringify(added.data));
  const dup = await req('POST', `/tracks/${trackId}/points`, { points: pts }, token);
  console.log('POST points again ->', dup.status, JSON.stringify(dup.data));
  const done = await req(
    'POST',
    `/tracks/${trackId}/complete`,
    { endedAt: new Date().toISOString(), name: 'Probe track', difficulty: 'easy' },
    token,
  );
  console.log('POST /tracks/:id/complete ->', done.status);
  console.log(JSON.stringify(done.data));
}

console.log('\nrefresh token check');
const refreshed = await req('POST', '/auth/refresh', { refreshToken: ver.data.refreshToken });
console.log('POST /auth/refresh ->', refreshed.status, shape(refreshed.data));
const reused = await req('POST', '/auth/refresh', { refreshToken: ver.data.refreshToken });
console.log('reuse old refresh ->', reused.status, JSON.stringify(reused.data));
