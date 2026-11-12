// Runtime smoke-test: справочник стран, правила геймификации, заплыв через маршрут,
// отзывы и треки участников заплыва (загрузка точек с мобильного).
// Run: node scripts/smoke-new-features.js
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

/// Регистрация временного пользователя + подтверждение кодом из лога дев-сервера.
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
      /* лог ещё не дописан */
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

  console.log('\n1. Справочник стран');
  const countries = await req('GET', '/reference/countries');
  check('GET /reference/countries без токена -> 200', countries.status === 200, `got ${countries.status}`);
  check('стран >= 200', (countries.data?.length ?? 0) >= 200, `got ${countries.data?.length}`);
  const ru = countries.data?.find((c) => c.code === 'RU');
  check('есть RU с русским названием', ru?.name === 'Россия', JSON.stringify(ru));

  console.log('\n2. Правила геймификации');
  const rules = await req('GET', '/gamification/rules');
  check('GET /gamification/rules без токена -> 200', rules.status === 200, `got ${rules.status}`);
  check('порог 2-го уровня = 200 XP', rules.data?.level?.thresholds?.[0]?.totalXp === 200);
  check('пороги растут (280 на 3-м)', rules.data?.level?.thresholds?.[1]?.totalXp === 480);
  check('достижений 7', rules.data?.achievements?.length === 7, `got ${rules.data?.achievements?.length}`);

  const author = await newUser('Route Author', `smoke_author_${stamp}@dev.sup`);
  const other = await newUser('Swim Outsider', `smoke_other_${stamp}@dev.sup`);

  console.log('\n3. Страна в профиле');
  const badCountry = await req('PATCH', '/users/me', { country: 'ZZ' }, author.accessToken);
  check('неизвестный код страны -> 400', badCountry.status === 400, `got ${badCountry.status}`);
  const okCountry = await req('PATCH', '/users/me', { country: 'ru' }, author.accessToken);
  check('валидный код страны -> 200', okCountry.status === 200 || okCountry.status === 201, `got ${okCountry.status}`);
  check('код нормализован в верхний регистр', okCountry.data?.country === 'RU', JSON.stringify(okCountry.data?.country));

  console.log('\n4. Маршрут для заплыва');
  const wb = await req('GET', '/waterbodies?limit=1', null, author.accessToken);
  const waterBodyId = wb.data?.[0]?.id;
  check('есть водоём в справочнике', Boolean(waterBodyId));

  const route = await req(
    'POST',
    '/tracks',
    { name: `Smoke маршрут ${stamp}`, startedAt: new Date().toISOString(), waterBodyId },
    author.accessToken,
  );
  check('маршрут создан', route.status < 400 && route.data?.id, `got ${route.status}`);
  const routeId = route.data.id;

  const patched = await req(
    'PATCH',
    `/tracks/${routeId}`,
    { distanceMeters: 5200, durationSeconds: 3600 },
    author.accessToken,
  );
  check('у маршрута заданы дистанция и длительность', patched.status < 400, `got ${patched.status}`);
  const published = await req('POST', `/tracks/${routeId}/publish`, {}, author.accessToken);
  check('маршрут опубликован', published.data?.status === 'published', `got ${JSON.stringify(published.data?.status)}`);

  console.log('\n5. Заплыв привязан к маршруту');
  const eventDate = new Date(Date.now() + 3 * 24 * 3600 * 1000);
  const event = await req(
    'POST',
    '/events',
    { title: `Smoke заплыв ${stamp}`, eventDate: eventDate.toISOString(), trackId: routeId },
    author.accessToken,
  );
  check('заплыв создан', event.status < 400 && event.data?.id, `got ${event.status} ${JSON.stringify(event.data)}`);
  const eventId = event.data.id;
  check('trackId сохранён', event.data?.trackId === routeId, JSON.stringify(event.data?.trackId));
  check('водоём унаследован с маршрута', event.data?.waterBodyId === waterBodyId, JSON.stringify(event.data?.waterBodyId));
  check('длительность взята из маршрута (60 мин)', event.data?.expectedDurationMinutes === 60, `got ${event.data?.expectedDurationMinutes}`);
  check('дистанция взята из маршрута (5200 м)', event.data?.expectedDistanceMeters === 5200, `got ${event.data?.expectedDistanceMeters}`);

  const badEvent = await req(
    'POST',
    '/events',
    { title: 'bad', eventDate: new Date().toISOString(), trackId: '00000000-0000-0000-0000-000000000000' },
    author.accessToken,
  );
  check('несуществующий маршрут -> 4xx', badEvent.status >= 400 && badEvent.status < 500, `got ${badEvent.status}`);

  console.log('\n6. Фильтр заплывов по дате');
  const day = eventDate.toISOString().slice(0, 10);
  const onDay = await req('GET', `/events?date=${day}`, null, author.accessToken);
  check(`есть заплыв на дату ${day}`, (onDay.data ?? []).some((e) => e.id === eventId), `got ${(onDay.data ?? []).length}`);
  const offDay = await req('GET', '/events?date=1999-01-01', null, author.accessToken);
  check('на 1999-01-01 заплывов нет', (offDay.data ?? []).every((e) => e.id !== eventId));
  const badDate = await req('GET', '/events?date=не-дата', null, author.accessToken);
  check('кривая дата -> 400', badDate.status === 400, `got ${badDate.status}`);

  console.log('\n7. Отзывы');
  const badRating = await req('POST', '/reviews', { targetType: 'event', targetId: eventId, rating: 6 }, author.accessToken);
  check('рейтинг 6 -> 400', badRating.status === 400, `got ${badRating.status}`);

  const review1 = await req(
    'POST',
    '/reviews',
    { targetType: 'event', targetId: eventId, rating: 5, comment: 'Отличный заплыв', photos: ['/uploads/a.jpg'] },
    author.accessToken,
  );
  check('отзыв создан', review1.status < 400 && review1.data?.id, `got ${review1.status}`);
  const reviewId = review1.data.id;
  check('фото сохранилось', review1.data?.photos?.length === 1, JSON.stringify(review1.data?.photos));

  const review2 = await req(
    'POST',
    '/reviews',
    { targetType: 'event', targetId: eventId, rating: 4, comment: 'Обновил отзыв' },
    author.accessToken,
  );
  check('повторный отзыв того же автора не дублируется', review2.data?.id === reviewId, `${review2.data?.id} vs ${reviewId}`);
  check('отзыв обновлён (rating 4)', review2.data?.rating === 4, `got ${review2.data?.rating}`);

  const reviewList = await req('GET', `/reviews?targetType=event&targetId=${eventId}`, null, author.accessToken);
  check('список отзывов: 1 шт', reviewList.data?.length === 1, `got ${reviewList.data?.length}`);
  check('в списке есть автор', Boolean(reviewList.data?.[0]?.author?.name));

  const summary = await req('GET', `/reviews/summary?targetType=event&targetId=${eventId}`, null, author.accessToken);
  check('summary: count=1, avg=4', summary.data?.count === 1 && Number(summary.data?.avgRating) === 4, JSON.stringify(summary.data));

  const reviewOnRoute = await req(
    'POST',
    '/reviews',
    { targetType: 'track', targetId: routeId, rating: 3, comment: 'Маршрут норм' },
    other.accessToken,
  );
  check('отзыв на маршрут создан', reviewOnRoute.status < 400, `got ${reviewOnRoute.status}`);

  const foreignDelete = await req('DELETE', `/reviews/${reviewId}`, null, other.accessToken);
  check('чужой отзыв удалить нельзя -> 403', foreignDelete.status === 403, `got ${foreignDelete.status}`);

  const badTarget = await req('POST', '/reviews', { targetType: 'track', targetId: '00000000-0000-0000-0000-000000000000', rating: 5 }, author.accessToken);
  check('отзыв на несуществующий объект -> 404', badTarget.status === 404, `got ${badTarget.status}`);

  console.log('\n8. Треки участников заплыва (мобильная загрузка)');
  const outsiderTracks = await req('GET', `/events/${eventId}/tracks`, null, other.accessToken);
  check('постороннему список треков закрыт -> 403', outsiderTracks.status === 403, `got ${outsiderTracks.status}`);

  const started = await req('POST', `/events/${eventId}/tracks`, { name: 'Трек участника' }, author.accessToken);
  check('запись трека начата', started.status < 400 && started.data?.id, `got ${started.status} ${JSON.stringify(started.data)}`);
  const eventTrackId = started.data.id;
  check('трек привязан к заплыву', started.data?.eventId === eventId);

  const again = await req('POST', `/events/${eventId}/tracks`, {}, author.accessToken);
  check('повторный старт возвращает тот же трек', again.data?.id === eventTrackId, `${again.data?.id} vs ${eventTrackId}`);

  const t0 = Date.now();
  const batch = {
    points: [0, 1, 2, 3, 4].map((seq) => ({
      seq,
      lat: 55.75 + seq * 0.001,
      lng: 37.62 + seq * 0.001,
      altitude: 120 + seq,
      speedKph: 4.5,
      recordedAt: new Date(t0 + seq * 5000).toISOString(),
    })),
  };
  const sent1 = await req('POST', `/events/${eventId}/tracks/${eventTrackId}/points`, batch, author.accessToken);
  check('пачка точек принята: added=5', sent1.data?.added === 5, JSON.stringify(sent1.data));

  const sent2 = await req('POST', `/events/${eventId}/tracks/${eventTrackId}/points`, batch, author.accessToken);
  check('повтор той же пачки: added=0, skipped=5', sent2.data?.added === 0 && sent2.data?.skipped === 5, JSON.stringify(sent2.data));
  check('дублей нет: total=5', sent2.data?.total === 5, `got ${sent2.data?.total}`);

  const partial = {
    points: [
      { seq: 3, lat: 55.759, lng: 37.629, recordedAt: new Date(t0 + 15000).toISOString() },
      { seq: 5, lat: 55.760, lng: 37.630, recordedAt: new Date(t0 + 20000).toISOString() },
    ],
  };
  const sent3 = await req('POST', `/events/${eventId}/tracks/${eventTrackId}/points`, partial, author.accessToken);
  check('частичный повтор: added=1, skipped=1', sent3.data?.added === 1 && sent3.data?.skipped === 1, JSON.stringify(sent3.data));

  const points = await req('GET', `/events/${eventId}/tracks/${eventTrackId}/points`, null, author.accessToken);
  check('точки отдаются для карты (6)', points.data?.length === 6, `got ${points.data?.length}`);

  const finished = await req(
    'POST',
    `/events/${eventId}/tracks/${eventTrackId}/finish`,
    { endedAt: new Date(t0 + 30 * 60 * 1000).toISOString() },
    author.accessToken,
  );
  check('финиш трека', finished.status < 400 && finished.data?.track?.id === eventTrackId, `got ${finished.status}`);
  check('дистанция посчитана (> 500 м)', (finished.data?.track?.distanceMeters ?? 0) > 500, `got ${finished.data?.track?.distanceMeters}`);
  check('XP начислен', (finished.data?.award?.points ?? 0) > 0, JSON.stringify(finished.data?.award));

  const afterFinish = await req('POST', `/events/${eventId}/tracks/${eventTrackId}/points`, {
    points: [{ seq: 99, lat: 55.9, lng: 37.9, recordedAt: new Date().toISOString() }],
  }, author.accessToken);
  check('после финиша точки не принимаются -> 4xx', afterFinish.status >= 400 && afterFinish.status < 500, `got ${afterFinish.status}`);

  const list = await req('GET', `/events/${eventId}/tracks`, null, author.accessToken);
  check('в списке 1 трек', list.data?.length === 1, `got ${list.data?.length}`);
  check('в списке есть автор и статистика', Boolean(list.data?.[0]?.author?.name) && list.data?.[0]?.pointsCount === 6, JSON.stringify(list.data?.[0]));

  console.log('\n9. Удаление отзыва');
  const removed = await req('DELETE', `/reviews/${reviewId}`, null, author.accessToken);
  check('свой отзыв удалён', removed.status < 400, `got ${removed.status}`);
  const afterDelete = await req('GET', `/reviews?targetType=event&targetId=${eventId}`, null, author.accessToken);
  check('список отзывов пуст', afterDelete.data?.length === 0, `got ${afterDelete.data?.length}`);

  console.log(`\n==== ${pass} passed, ${fail} failed ====`);
  process.exitCode = fail > 0 ? 1 : 0;
})().catch((err) => {
  console.error(`Смоук упал: ${err.message}`);
  process.exitCode = 1;
});
