/// Сид: водоёмы Дальнего Востока России + справочные маршруты (routes) по ним.
///
///   node scripts/seed-far-east.js           — показать план (без записи)
///   node scripts/seed-far-east.js --apply   — записать в БД
///
/// Идемпотентно: водоёмы upsert по name; маршруты создаются, если нет маршрута
/// с тем же name+waterbody. Автор маршрутов — первый admin (иначе первый user).
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const APPLY = process.argv.includes('--apply');

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

// Смещение в градусах от центра (lat0,lng0). dy/dx в км, грубо для широт ДВ.
function off(lat0, lng0, dxKm, dyKm) {
  const dLat = dyKm / 110.574;
  const dLng = dxKm / (111.320 * Math.cos(rad(lat0)) || 1);
  return { lat: +(lat0 + dLat).toFixed(6), lng: +(lng0 + dLng).toFixed(6) };
}

function route(name, description, difficulty, maxSpeedKph, points) {
  const distanceMeters = lineMeters(points);
  const expectedDurationMinutes = maxSpeedKph > 0 ? Math.round((distanceMeters / 1000 / maxSpeedKph) * 60 * 1.15) : null;
  return { name, description, difficulty, maxSpeedKph, distanceMeters, expectedDurationMinutes, published: true, points };
}

/** Генерация набора маршрутов вокруг точки водоёма. */
function makeRoutes(wb) {
  const [lat, lng] = wb.center;
  const p = (dx, dy) => off(lat, lng, dx, dy);
  // Базовые формы: прогулочный, радиальный, береговой — масштабируем под водоём.
  const s = wb.scale ?? 1;
  const routes = [
    route(
      `${wb.short}: прогулочный круг`,
      `Спокойный маршрут для ознакомления с акваторией «${wb.name}». Рекомендуется при слабом ветре.`,
      'easy', 5.5,
      [p(-0.8 * s, -0.2 * s), p(-0.3 * s, 0.4 * s), p(0.5 * s, 0.5 * s), p(1.0 * s, 0.1 * s), p(0.6 * s, -0.5 * s), p(-0.2 * s, -0.6 * s), p(-0.8 * s, -0.2 * s)],
    ),
    route(
      `${wb.short}: береговая линия`,
      `Маршрут вдоль береговой линии с видами на «${wb.name}». Контролируйте ветер и течение.`,
      'medium', 6.5,
      [p(-1.6 * s, 0), p(-1.0 * s, 0.3 * s), p(-0.2 * s, 0.5 * s), p(0.6 * s, 0.4 * s), p(1.4 * s, 0.1 * s), p(2.0 * s, -0.2 * s)],
    ),
    route(
      `${wb.short}: дальний радиал`,
      `Протяжённый маршрут для подготовленных сапбордистов по акватории «${wb.name}».`,
      'hard', 7.0,
      [p(0, -0.2 * s), p(0.4 * s, 0.6 * s), p(1.2 * s, 1.2 * s), p(2.2 * s, 1.5 * s), p(3.0 * s, 1.1 * s), p(3.4 * s, 0.4 * s)],
    ),
  ];
  if (wb.extraRoute) routes.push(wb.extraRoute(lat, lng, p, route, s));
  return routes;
}

const WATERBODIES = [
  { name: 'Амурский залив', short: 'Амурский залив', region: 'Приморский край', center: [43.1000, 131.7500], scale: 1.2,
    description: 'Внутренний залив залива Петра Великого у Владивостока. Защищённые участки у береговой линии подходят для прогулочных SUP-маршрутов.' },
  { name: 'Уссурийский залив', short: 'Уссурийский залив', region: 'Приморский край', center: [43.1500, 132.0500], scale: 1.3,
    description: 'Восточный залив залива Петра Великого. Просторная акватория, живописные бухты острова Русский и полуострова Муравьёва-Амурского.' },
  { name: 'Бухта Золотой Рог', short: 'Золотой Рог', region: 'Приморский край, Владивосток', center: [43.1086, 131.8936], scale: 0.45,
    description: 'Узкая бухта в центре Владивостока. Городские SUP-прогулки в тихую погоду, виды на мосты и набережные.' },
  { name: 'Бухта Новик', short: 'Новик', region: 'Приморский край, остров Русский', center: [43.0500, 131.8500], scale: 0.8,
    description: 'Длинная узкая бухта острова Русский с относительно защищённой водой — удобное место для тренировок и прогулок.' },
  { name: 'Река Амур (Хабаровск)', short: 'Амур', region: 'Хабаровский край', center: [48.4800, 135.0700], scale: 1.4,
    description: 'Участок Амура у Хабаровска. Широкая река с протоками и островами; выход только при оценке течения и ветра.' },
  { name: 'Озеро Лотосов (Ханка)', short: 'Лотосы', region: 'Приморский край', center: [44.6830, 132.4500], scale: 0.6,
    description: 'Заливная система у озера Ханка, известная цветением лотосов (комарова). Сезонные прогулочные маршруты в тихую погоду.' },
  { name: 'Авачинская бухта', short: 'Авачинская бухта', region: 'Камчатский край', center: [52.9833, 158.5500], scale: 1.5,
    description: 'Одна из крупнейших бухт мира у Петропавловска-Камчатского. Виды на вулканы; маршруты планировать по погоде и течениям.' },
  { name: 'Бухта Моховая', short: 'Моховая', region: 'Камчатский край', center: [53.0330, 158.6000], scale: 0.5,
    description: 'Небольшая бухта в акватории Авачинской губы с более спокойной водой у берега.' },
  { name: 'Озеро Култучное', short: 'Култучное', region: 'Камчатский край, Петропавловск-Камчатский', center: [53.0350, 158.6450], scale: 0.35,
    description: 'Городское озеро в Петропавловске-Камчатском. Компактная акватория для коротких тренировок.' },
  { name: 'Бухта Буссе', short: 'Буссе', region: 'Сахалинская область', center: [46.5300, 143.3200], scale: 1.1,
    description: 'Лагуна на юге Сахалина с относительно тёплой водой летом и богатой природой.' },
  { name: 'Залив Анива', short: 'Анива', region: 'Сахалинская область', center: [46.3000, 142.7000], scale: 1.6,
    description: 'Южный залив Сахалина. Открытая акватория — маршруты выбирать в безветренные окна и у защищённых участков берега.' },
  { name: 'Озеро Тунайча', short: 'Тунайча', region: 'Сахалинская область', center: [46.8300, 143.1500], scale: 1.2,
    description: 'Крупное лагунное озеро на восточном побережье Сахалина. Протяжённые маршруты по зеркалу воды в calm-условиях.' },
  { name: 'Татарский пролив (Советская Гавань)', short: 'Совгавань', region: 'Хабаровский край', center: [48.9660, 140.2850], scale: 1.0,
    description: 'Акватория у Советской Гавани. Прибрежные маршруты при благоприятном прогнозе ветра и волны.' },
  { name: 'Река Уссури (Лесозаводск)', short: 'Уссури', region: 'Приморский край', center: [45.4780, 133.4280], scale: 1.1,
    description: 'Спокойные плёсы Уссури в районе Лесозаводска. Подходит для прогулок при контроле течения.' },
  { name: 'Залив Находка', short: 'Находка', region: 'Приморский край', center: [42.8000, 132.8830], scale: 1.3,
    description: 'Залив у города Находка с бухтами и островами. Живописные прибрежные маршруты в тихую погоду.' },
  { name: 'Бухта Врангеля', short: 'Врангеля', region: 'Приморский край', center: [42.7500, 133.0700], scale: 0.7,
    description: 'Бухта восточнее Находки с песчаными берегами и относительно закрытой акваторией.' },
  { name: 'Озеро Большое Кизи', short: 'Кизи', region: 'Хабаровский край', center: [51.6000, 140.4500], scale: 1.4,
    description: 'Крупное озеро в низовьях Амура, соединённое протокой с рекой. Обширная акватория для дальних переходов в calm.' },
  { name: 'Залив Владимира', short: 'Владимира', region: 'Приморский край', center: [43.9000, 135.5200], scale: 1.0,
    description: 'Открытый залив восточного побережья Приморья с чистой водой. Маршруты у берега при спокойном море.' },
  { name: 'Бухта Ольга', short: 'Ольга', region: 'Приморский край', center: [43.7440, 135.2870], scale: 0.8,
    description: 'Живописная бухта посёлка Ольга, защищённая от части ветров. Удобна для прогулочного SUP.' },
  { name: 'Река Зея (Благовещенск)', short: 'Зея', region: 'Амурская область', center: [50.2900, 127.5300], scale: 1.2,
    description: 'Акватория Зеи у Благовещенска. Широкие плёсы в летний сезон; учитывать течение и судоходство.' },
  { name: 'Бухта Провидения', short: 'Провидения', region: 'Чукотский автономный округ', center: [64.4280, -173.2260], scale: 0.9,
    description: 'Фьордообразная бухта Берингова моря. Арктический SUP-маршрут для опытных, только в короткий летний сезон и при безопасной погоде.',
    extraRoute: (lat, lng, p, route, s) => route(
      'Провидения: арктический траверс',
      'Короткий маршрут вдоль берега при стабильной погоде. Требуется опыт холодной воды и сопровождение.',
      'hard', 5.0,
      [p(-0.6 * s, -0.1 * s), p(-0.2 * s, 0.2 * s), p(0.3 * s, 0.3 * s), p(0.8 * s, 0.1 * s), p(1.1 * s, -0.2 * s)],
    ) },
  { name: 'Бухта Нагаева', short: 'Нагаева', region: 'Магаданская область', center: [59.5660, 150.8000], scale: 0.9,
    description: 'Бухта Охотского моря у Магадана. Холодная вода и переменчивая погода — планировать маршруты у берега в calm.' },
  { name: 'Озеро Джека Лондона', short: 'Джека Лондона', region: 'Магаданская область', center: [62.0800, 149.5300], scale: 0.9,
    description: 'Живописное горное озеро в Ягоднинском районе. Сезонный SUP в тёплые безветренные дни.' },
  { name: 'Река Лена (Якутск)', short: 'Лена', region: 'Республика Саха (Якутия)', center: [62.0280, 129.7330], scale: 1.6,
    description: 'Акватория Лены у Якутска. Огромная река с протоками; маршруты только при оценке течения, ветра и навигации.' },
];

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    user: process.env.DB_USER ?? 'postgres',
    password: process.env.DB_PASSWORD ?? 'postgres',
    database: process.env.DB_NAME ?? 'sup_fun',
  });

  // Автор справочных маршрутов
  const authorRes = await pool.query(
    `SELECT id, email, role FROM users WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1`,
  );
  let author = authorRes.rows[0];
  if (!author) {
    const any = await pool.query(`SELECT id, email, role FROM users ORDER BY created_at ASC LIMIT 1`);
    author = any.rows[0];
  }
  if (!author) {
    console.error('Нет пользователей в БД — создайте хотя бы одного (нужен author_id для routes).');
    await pool.end();
    process.exit(1);
  }
  console.log(`Автор маршрутов: ${author.email} (${author.role}, ${author.id})\n`);

  const plan = WATERBODIES.map((wb) => ({ wb, routes: makeRoutes(wb) }));
  console.log(`План: ${plan.length} водоёмов, ${plan.reduce((n, x) => n + x.routes.length, 0)} маршрутов.\n`);
  for (const { wb, routes } of plan) {
    console.log(`• ${wb.name} [${wb.region}] @ ${wb.center[0]}, ${wb.center[1]} — ${routes.length} маршрута`);
    for (const r of routes) console.log(`    - ${r.name} (${r.distanceMeters} м, ${r.difficulty}, ~${r.expectedDurationMinutes ?? '?'} мин)`);
  }

  if (!APPLY) {
    console.log('\nРежим просмотра. Запустите с --apply для записи в БД.');
    await pool.end();
    return;
  }

  let wbInserted = 0, wbUpdated = 0, rtInserted = 0, rtSkipped = 0;
  for (const { wb, routes } of plan) {
    const [lat, lng] = wb.center;
    const existing = await pool.query('SELECT id FROM waterbodies WHERE name = $1', [wb.name]);
    let waterbodyId;
    if (existing.rowCount > 0) {
      waterbodyId = existing.rows[0].id;
      await pool.query(
        `UPDATE waterbodies
            SET description = $2, region = $3, active = TRUE,
                location = ST_SetSRID(ST_MakePoint($4, $5), 4326),
                updated_at = now()
          WHERE id = $1`,
        [waterbodyId, wb.description, wb.region, lng, lat],
      );
      wbUpdated += 1;
    } else {
      const ins = await pool.query(
        `INSERT INTO waterbodies (id, name, description, region, active, location, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, $3, TRUE, ST_SetSRID(ST_MakePoint($4, $5), 4326), now(), now())
         RETURNING id`,
        [wb.name, wb.description, wb.region, lng, lat],
      );
      waterbodyId = ins.rows[0].id;
      wbInserted += 1;
    }

    for (const r of routes) {
      const dup = await pool.query(
        `SELECT id FROM routes WHERE waterbody_id = $1 AND name = $2 LIMIT 1`,
        [waterbodyId, r.name],
      );
      if (dup.rowCount > 0) { rtSkipped += 1; continue; }
      const rt = await pool.query(
        `INSERT INTO routes (id, name, description, waterbody_id, author_id, distance_meters, difficulty, max_speed_kph, expected_duration_minutes, published, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, $8, $9, now(), now())
         RETURNING id`,
        [r.name, r.description, waterbodyId, author.id, r.distanceMeters, r.difficulty, r.maxSpeedKph, r.expectedDurationMinutes, r.published],
      );
      const routeId = rt.rows[0].id;
      for (let i = 0; i < r.points.length; i++) {
        const pt = r.points[i];
        await pool.query(
          `INSERT INTO route_points (id, route_id, lat, lng, seq, created_at)
           VALUES (gen_random_uuid(), $1, $2, $3, $4, now())`,
          [routeId, pt.lat, pt.lng, i + 1],
        );
      }
      rtInserted += 1;
    }
  }

  console.log(`\nГотово. Водоёмы: добавлено ${wbInserted}, обновлено ${wbUpdated}. Маршруты: создано ${rtInserted}, пропущено (уже есть) ${rtSkipped}.`);
  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});