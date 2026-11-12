// Runtime smoke-test: staff (admin/moderator) rights on other users' tracks.
// Run: node scripts/smoke-tracks-staff.js
// Requires: running backend + SMOKE_LOG with its stdout (dev email codes are logged there).
const fs = require('fs');

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
  const text = fs.readFileSync(LOG, 'utf8');
  const escaped = email.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const re = new RegExp(`${escaped}[\\s\\S]{0,500}?\\D(\\d{6})\\D`, 'g');
  let last = null;
  let m;
  while ((m = re.exec(text)) !== null) last = m[1];
  return last;
}

/// Register a throwaway user, then sign in with the dev code from the server log.
async function newUser(name, email) {
  const reg = await req('POST', '/auth/register', { name, email, password: PASSWORD });
  if (reg.status >= 400) {
    throw new Error(`register ${email}: ${reg.status} ${JSON.stringify(reg.data)}`);
  }
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
  if (ver.status >= 400) {
    throw new Error(`verify ${email}: ${ver.status} ${JSON.stringify(ver.data)}`);
  }
  return ver.data;
}

(async () => {
  const stamp = Date.now();
  const otherEmail = `smoke_other_${stamp}@dev.sup`;
  const adminLogin = await req('POST', '/auth/login', {
    email: 'admin@supfun.app',
    password: PASSWORD,
  });
  if (adminLogin.status >= 400) {
    throw new Error(`admin login: ${adminLogin.status} ${JSON.stringify(adminLogin.data)}`);
  }
  const admin = adminLogin.data;
  console.log(`admin role=${admin.user.role}`);

  const author = await newUser('Smoke Author', `smoke_author_${stamp}@dev.sup`);
  const other = await newUser('Smoke Outsider', otherEmail);

  const created = await req(
    'POST',
    '/tracks',
    { name: `Smoke track ${stamp}`, startedAt: new Date().toISOString() },
    author.accessToken,
  );
  const trackId = created.data?.id;
  check(
    'трек создан автором (статус private)',
    created.status === 201 && created.data?.status === 'private',
    `${created.status} ${created.data?.status}`,
  );

  const outsiderPatch = await req('PATCH', `/tracks/${trackId}`, { name: 'hacked' }, other.accessToken);
  check('обычный пользователь PATCH чужого -> 403', outsiderPatch.status === 403, `got ${outsiderPatch.status}`);
  const outsiderGet = await req('GET', `/tracks/${trackId}`, null, other.accessToken);
  check('обычный пользователь GET чужого приватного -> 403', outsiderGet.status === 403, `got ${outsiderGet.status}`);

  const adminGet = await req('GET', `/tracks/${trackId}`, null, admin.accessToken);
  check('admin GET чужого приватного -> 200', adminGet.status === 200, `got ${adminGet.status}`);

  const adminPatch = await req(
    'PATCH',
    `/tracks/${trackId}`,
    { name: `Edited by admin ${stamp}`, difficulty: 'hard' },
    admin.accessToken,
  );
  check(
    'admin PATCH чужого -> 200, поля изменены',
    adminPatch.status === 200 &&
      adminPatch.data?.name === `Edited by admin ${stamp}` &&
      adminPatch.data?.difficulty === 'hard',
    `got ${adminPatch.status} name=${adminPatch.data?.name} diff=${adminPatch.data?.difficulty}`,
  );

  const adminPublish = await req('POST', `/tracks/${trackId}/publish`, null, admin.accessToken);
  check(
    'admin POST publish -> 201, status=published',
    adminPublish.status === 201 && adminPublish.data?.status === 'published',
    `got ${adminPublish.status} ${adminPublish.data?.status}`,
  );
  const authorJournal = await req('GET', '/gamification/points', null, author.accessToken);
  const authorXp = await req('GET', '/gamification/me', null, author.accessToken);
  check(
    'публикация трека нулевой дистанции не начислила XP автору',
    (authorJournal.data ?? []).length === 0 && Number(authorXp.data?.xp ?? -1) === 0,
    `journal=${(authorJournal.data ?? []).length} xp=${authorXp.data?.xp}`,
  );

  const promote = await req(
    'PATCH',
    `/admin/users/${other.user.id}/role`,
    { role: 'moderator' },
    admin.accessToken,
  );
  check('повышение пользователя до модератора', promote.status === 200 && promote.data?.role === 'moderator', `got ${promote.status}`);
  // роль зашита в JWT, поэтому модератору нужен свежий токен
  const relogin = await req('POST', '/auth/login', { email: otherEmail, password: PASSWORD });
  check('перелогин получен с ролью moderator', relogin.status < 400 && relogin.data?.user?.role === 'moderator', `got ${relogin.status} ${relogin.data?.user?.role}`);
  const modToken = relogin.data?.accessToken;
  const modPatch = await req('PATCH', `/tracks/${trackId}`, { name: `Edited by mod ${stamp}` }, modToken);
  check('moderator PATCH чужого -> 200', modPatch.status === 200, `got ${modPatch.status}`);
  const modDelete = await req('DELETE', `/tracks/${trackId}`, null, modToken);
  check('moderator DELETE чужого -> 403', modDelete.status === 403, `got ${modDelete.status}`);

  const adminDelete = await req('DELETE', `/tracks/${trackId}`, null, admin.accessToken);
  check('admin DELETE чужого -> 200', adminDelete.status === 200, `got ${adminDelete.status}`);
  const afterDelete = await req('GET', `/tracks/${trackId}`, null, admin.accessToken);
  check('после удаления GET -> 404', afterDelete.status === 404, `got ${afterDelete.status}`);

  const own = await req('POST', '/tracks', { name: 'Own track', startedAt: new Date().toISOString() }, author.accessToken);
  const ownPatch = await req('PATCH', `/tracks/${own.data.id}`, { name: 'Own track edited' }, author.accessToken);
  check('владелец PATCH своего -> 200', ownPatch.status === 200 && ownPatch.data?.name === 'Own track edited', `got ${ownPatch.status}`);
  const ownDelete = await req('DELETE', `/tracks/${own.data.id}`, null, author.accessToken);
  check('владелец DELETE своего -> 200', ownDelete.status === 200, `got ${ownDelete.status}`);

  console.log(`\nпрошло: ${pass}, провалилось: ${fail}`);
  if (fail > 0) process.exitCode = 1;
})().catch((e) => {
  console.error('SMOKE ERROR', e.message);
  process.exitCode = 1;
});
