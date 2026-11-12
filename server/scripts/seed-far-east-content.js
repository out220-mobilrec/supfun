/// Контент Дальнего Востока: события (events) + новости (news).
///   node scripts/seed-far-east-content.js           — просмотр
///   node scripts/seed-far-east-content.js --apply   — запись (идемпотентно по title+type)
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const APPLY = process.argv.includes('--apply');

function daysFromNow(n, hour = 10) {
  const d = new Date();
  d.setDate(d.getDate() + n);
  d.setHours(hour, 0, 0, 0);
  return d.toISOString();
}

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    user: process.env.DB_USERNAME ?? process.env.DB_USER ?? 'postgres',
    password: process.env.DB_PASSWORD ?? 'postgres',
    database: process.env.DB_DATABASE ?? process.env.DB_NAME ?? 'sup_fun',
  });

  const authorRes = await pool.query(
    `SELECT id, email, role FROM users WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1`,
  );
  let author = authorRes.rows[0];
  if (!author) {
    const any = await pool.query(`SELECT id, email, role FROM users ORDER BY created_at ASC LIMIT 1`);
    author = any.rows[0];
  }
  if (!author) { console.error('Нет пользователей для author/organizer.'); await pool.end(); process.exit(1); }

  // Координаты для стартовых точек (примерные) — подтянем из waterbodies
  const wbRes = await pool.query(
    `SELECT id,name,region, ST_Y(location::geometry) AS lat, ST_X(location::geometry) AS lng
       FROM waterbodies
      WHERE region ILIKE '%Примор%' OR region ILIKE '%Камчат%' OR region ILIKE '%Сахалин%'
         OR region ILIKE '%Хабаров%' OR region ILIKE '%Амур%' OR region ILIKE '%Магадан%'
         OR region ILIKE '%Чукот%' OR region ILIKE '%Якут%'
      ORDER BY region,name`
  );
  const wbByName = new Map(wbRes.rows.map((r) => [r.name, r]));

  const EVENTS = [
    { title: 'Рассветный SUP во Владивостоке: бухта Новик', wb: 'Бухта Новик', days: 18, hour: 6, dur: 90, dist: 4500, level: 'beginner', desc: 'Встречаем рассвет на острове Русский. Спокойная акватория, подходит новичкам. Возьмите жилет, лиш и гермочехол.' },
    { title: 'Прогулка по Золотому Рогу (городской SUP)', wb: 'Бухта Золотой Рог', days: 25, hour: 10, dur: 75, dist: 3200, level: 'beginner', desc: 'Городской маршрут по бухте Золотой Рог с видами на мосты. Выход при слабом ветре, учитываем судоходство.' },
    { title: 'Береговая линия Амурского залива', wb: 'Амурский залив', days: 32, hour: 9, dur: 120, dist: 6500, level: 'medium', desc: 'Маршрут вдоль берега Амурского залива. Для уверенных саперов; контроль прогноза ветра и волны обязателен.' },
    { title: 'Исследуем Уссурийский залив', wb: 'Уссурийский залив', days: 40, hour: 8, dur: 150, dist: 8000, level: 'medium', desc: 'Протяжённая прогулка по Уссурийскому заливу с остановкой у берега. Группа до 12 человек, темп комфортный.' },
    { title: 'SUP на Авачинской бухте с видом на вулканы', wb: 'Авачинская бухта', days: 55, hour: 11, dur: 110, dist: 6000, level: 'medium', desc: 'Камчатский маршрут в акватории Авачинской бухты. Холодная вода — рекомендован гидрокостюм; решение о выходе по погоде.' },
    { title: 'Тихая вода: озеро Култучное', wb: 'Озеро Култучное', days: 48, hour: 12, dur: 60, dist: 2500, level: 'beginner', desc: 'Короткая тренировка/прогулка на городском озере Петропавловска-Камчатского. Отлично для первого знакомства с SUP на Камчатке.' },
    { title: 'Лагуна Буссе: летний SUP на Сахалине', wb: 'Бухта Буссе', days: 70, hour: 10, dur: 120, dist: 5500, level: 'beginner', desc: 'Прогулка по лагуне Буссе — одно из самых тёплых мест Сахалина летом. Спокойная вода, наблюдение за природой.' },
    { title: 'Большая вода Тунайчи', wb: 'Озеро Тунайча', days: 78, hour: 9, dur: 150, dist: 7500, level: 'medium', desc: 'Дальний маршрут по озеру Тунайча в calm-окно. Для участников с опытом длительных гребков.' },
    { title: 'Амур у Хабаровска: острова и протоки', wb: 'Река Амур (Хабаровск)', days: 35, hour: 10, dur: 130, dist: 7000, level: 'medium', desc: 'Маршрут по широкой акватории Амура с видом на набережную. Обязательна оценка течения и ветра, спасжилеты.' },
    { title: 'Лена в Якутске: белые ночи на воде', wb: 'Река Лена (Якутск)', days: 95, hour: 19, dur: 100, dist: 6000, level: 'medium', desc: 'Вечерний заплыв по Лене (сезонный). Крупная река — строгий контроль прогноза, течения и группы.' },
  ];

  const NEWS = [
    { title: 'SUP на Дальнем Востоке: новые локации и маршруты в приложении', body: 'Мы добавили подборку водоёмов Дальнего Востока — от Владивостока и Камчатки до Сахалина, Магадана, Чукотки и Якутии. Для каждого водоёма доступны справочные маршруты с дистанцией, сложностью и расчётным временем.\n\nПланируя выход на воду, проверяйте прогноз, ветер и волну, учитывайте холодную воду и удалённость локаций. Безопасность — приоритет.' },
    { title: 'Как выбрать маршрут на незнакомой акватории', body: '1) Начните с прогулочного маршрута (easy) и короткой дистанции.\n2) Сверьте погоду, порывы ветра и волнение — для SUP критичны даже умеренные условия.\n3) Сообщите близким план, берите жилет/лиш/гермочехол и связь.\n4) На реках учитывайте течение и судоходство; в морских бухтах — приливы и смену ветра.\n\nВ каталоге маршрутов указаны дистанция, сложность и ориентировочное время — используйте их как отправную точку.' },
    { title: 'Сезон 2027: присоединяйтесь к заплывам сообщества', body: 'На главной и в разделе «Заплывы» появляются групповые выходы на воду по дальневосточным локациям. Выбирайте уровень, смотрите детали маршрута и водоёма, отмечайтесь «Иду» и общайтесь в чате события.\n\nОрганизуете свой заплыв? Создайте событие, укажите водоём/маршрут и пригласите участников.' },
  ];

  console.log(`Автор/организатор: ${author.email} (${author.id})`);
  console.log(`Водоёмов ДВ найдено: ${wbRes.rows.length}`);
  console.log(`План: ${EVENTS.length} событий, ${NEWS.length} новостей\n`);

  let evIns = 0, evSkip = 0, newsIns = 0, newsSkip = 0;

  for (const e of EVENTS) {
    const wb = wbByName.get(e.wb);
    const exists = await pool.query(`SELECT id FROM events WHERE title = $1 LIMIT 1`, [e.title]);
    if (exists.rowCount > 0) { evSkip++; console.log(`  skip event: ${e.title}`); continue; }
    console.log(`  event: ${e.title}${wb ? '' : ' (водоём не найден, без привязки)'}`);
    if (APPLY) {
      await pool.query(
        `INSERT INTO events (id, organizer_id, title, description, photos, waterbody_id, track_id, event_date,
           expected_duration_minutes, expected_distance_meters, level, visibility, access, max_participants, status,
           start_point, start_lat, start_lng, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, $3, ARRAY[]::text[], $4, NULL, $5::timestamptz,
           $6, $7, $8, 'public', 'open', $9, 'scheduled',
           NULL, $10, $11, now(), now())`,
        [author.id, e.title, e.desc, wb ? wb.id : null, daysFromNow(e.days, e.hour), e.dur, e.dist, e.level,
         e.level === 'beginner' ? 15 : 12, wb ? wb.lat : null, wb ? wb.lng : null]
      );
      evIns++;
    }
  }

  for (const n of NEWS) {
    const exists = await pool.query(`SELECT id FROM news WHERE title = $1 LIMIT 1`, [n.title]);
    if (exists.rowCount > 0) { newsSkip++; console.log(`  skip news: ${n.title}`); continue; }
    console.log(`  news: ${n.title}`);
    if (APPLY) {
      await pool.query(
        `INSERT INTO news (id, title, body, cover_url, author_id, is_published, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, NULL, $3, TRUE, now(), now())`,
        [n.title, n.body, author.id]
      );
      newsIns++;
    }
  }

  console.log(`\n${APPLY ? 'Готово' : 'Просмотр'}. События: +${evIns} / skip ${evSkip}. Новости: +${newsIns} / skip ${newsSkip}.`);
  if (!APPLY) console.log('Запустите с --apply для записи.');
  await pool.end();
}

main().catch((e) => { console.error(e); process.exit(1); });