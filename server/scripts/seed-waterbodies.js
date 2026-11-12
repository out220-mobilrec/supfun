/// Seed для справочника водоёмов.
///
///   node scripts/seed-waterbodies.js           — только показать, что будет (геокодинг OSM/Nominatim)
///   node scripts/seed-waterbodies.js --apply   — записать в базу
///   node scripts/seed-waterbodies.js --clean   — удалить битые строки (моношибро-дубли и мусор)
///
/// Координаты берутся из OpenStreetMap (Nominatim), чтобы не хранить округлённые
/// до 0.5° и откровенно смещённые точки. Ручные значения — только как fallback.
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const APPLY = process.argv.includes('--apply');
const CLEAN = process.argv.includes('--clean');

const USER_AGENT = 'SUPFUN-dev-seed/0.5 (development data seeding)';
const NOMINATIM = 'https://nominatim.openstreetmap.org/search';

/**
 * Реальные водоёмы, пригодные для SUP: озёра, водохранилища, реки, моря.
 * `manual` — запасные координаты на случай недоступности Nominatim.
 */
const WATER_BODIES = [
  // — озёра —
  { name: 'Озеро Байкал', region: 'Иркутская область', type: 'lake', manual: [51.8558, 104.8269],
    description: 'Самое глубокое озеро планеты. Для SUP — Малое море, заливы Провал и Песчаная, дельта Селенги.' },
  { name: 'Озеро Ладожское', region: 'Ленинградская область / Карелия', type: 'lake', manual: [60.8415, 31.7116],
    description: 'Крупнейшее озеро Европы. Маршруты по шхерам Ладожских шхер и Сортавальскому району.' },
  { name: 'Озеро Онежское', region: 'Республика Карелия', type: 'lake', manual: [62.2000, 35.4000],
    description: 'Второе по величине озеро Европы, открытая вода и Кижи.' },
  { name: 'Озеро Ильмень', region: 'Новгородская область', type: 'lake', manual: [58.2830, 31.2000],
    description: 'Мелководное озеро с песчаными банками; спокойная вода в безветренную погоду.' },
  { name: 'Озеро Селигер', region: 'Тверская область', type: 'lake', manual: [56.3500, 32.7900],
    description: 'Озёрный каскад с протоками — классика многодневных SUP-походов.' },
  { name: 'Чудское озеро', region: 'Псковская область', type: 'lake', manual: [58.3500, 27.6500],
    description: 'Тёплое и мелководное, длинные переходы вдоль берега.' },
  { name: 'Озеро Неро', region: 'Ярославская область', type: 'lake', manual: [57.1450, 39.4100],
    description: 'Плоская открытая вода у Ростова Великого.' },
  { name: 'Озеро Плещеево', region: 'Ярославская область', type: 'lake', manual: [56.7500, 38.8500],
    description: 'Озеро у Переславля-Залесского, популярно для SUP и виндсёрфинга.' },
  { name: 'Озеро Сенеж', region: 'Московская область', type: 'lake', manual: [56.2456, 36.9917],
    description: 'Подмосковное озеро с оборудованной береговой линией.' },
  { name: 'Озеро Тургояк', region: 'Челябинская область', type: 'lake', manual: [55.1900, 60.0100],
    description: '«Младший Байкал» — чистая вода и остров Веры.' },
  { name: 'Озеро Увильды', region: 'Челябинская область', type: 'lake', manual: [55.3300, 60.5300],
    description: 'Большое озёрное зеркало с множеством заливов.' },
  { name: 'Озеро Баскунчак', region: 'Астраханская область', type: 'lake', manual: [48.1400, 46.8200],
    description: 'Рапа и белая соль: эффект «невесомости», сезон — лето.' },
  { name: 'Озеро Эльтон', region: 'Волгоградская область', type: 'lake', manual: [48.9300, 46.5300],
    description: 'Крупнейшее солёное озеро Европы, розовая вода.' },
  { name: 'Телецкое озеро', region: 'Республика Алтай', type: 'lake', manual: [51.6300, 87.4400],
    description: 'Горное озеро, водопады Корбу и Каменные Грибы.' },
  { name: 'Озеро Чаны', region: 'Новосибирская область', type: 'lake', manual: [54.8500, 77.5000], preferManual: true,
    description: 'Система озёр Барабинской низменности, тростниковые протоки.' },
  { name: 'Озеро Ханка', region: 'Приморский край', type: 'lake', manual: [44.9000, 131.6000],
    description: 'Крупнейшее озеро Дальнего Востока, тёплая вода летом.' },
  { name: 'Курильское озеро', region: 'Камчатский край', type: 'lake', manual: [44.0300, 158.9300],
    description: 'Вулканическое озеро с горячими источниками и медвежьими берегами.' },

  // — водохранилища —
  { name: 'Истринское водохранилище', region: 'Московская область', type: 'reservoir', manual: [56.3400, 36.8600],
    description: 'Подмосковные «острова» и длинные безветренные протоки.' },
  { name: 'Клязьминское водохранилище', region: 'Москва / Московская область', type: 'reservoir', manual: [56.0300, 37.5300],
    description: 'Север Москвы: широкая акватория, прокат и базы отдыха.' },
  { name: 'Пироговское водохранилище', region: 'Московская область', type: 'reservoir', manual: [56.0000, 37.5000],
    description: 'Тёплая вода, удобно для новичков.' },
  { name: 'Можайское водохранилище', region: 'Московская область', type: 'reservoir', manual: [55.5000, 36.1300],
    description: 'Затопленная долина Москвы-реки, ветреные плёсы.' },
  { name: 'Рыбинское водохранилище', region: 'Ярославская / Вологодская область', type: 'reservoir', manual: [58.2500, 37.8000],
    description: '«Море» в центре России, открытая вода и волны.' },
  { name: 'Горьковское водохранилище', region: 'Нижегородская область', type: 'reservoir', manual: [56.6500, 46.5500],
    description: 'Широкая Волга ниже Нижнего Новгорода.' },
  { name: 'Цимлянское водохранилище', region: 'Ростовская область', type: 'reservoir', manual: [47.7500, 42.3500],
    description: 'Тёплое донское море с песчаными берегами.' },

  // — реки —
  { name: 'Москва-река', region: 'Москва / Московская область', type: 'river', manual: [55.7520, 37.6115],
    description: 'Городской SUP: от Строгино до Андреевского шлюза.' },
  { name: 'Река Волга', region: 'Тверская / Ярославская область', type: 'river', manual: [57.6261, 39.8845],
    description: 'Сплавные участки и плёсы ниже Твери и Ярославля.' },
  { name: 'Река Ока', region: 'Московская / Рязанская область', type: 'river', manual: [54.6296, 39.7400],
    description: 'Песчаные косы, мелководные протоки, длинные маршруты.' },
  { name: 'Река Нева', region: 'Санкт-Петербург / Ленинградская область', type: 'river', manual: [59.8944, 30.5060],
    description: 'Сильное течение — только для опытных; выше мостов спокойнее.' },
  { name: 'Река Свирь', region: 'Ленинградская область', type: 'river', manual: [60.5800, 32.7900],
    description: 'Тёплая вода, связывает Оять и Онежское озеро.' },
  { name: 'Река Ангара', region: 'Иркутская область', type: 'river', manual: [52.2900, 104.2800],
    description: 'Прозрачная холодная вода, пороги и шиверы.' },
  { name: 'Волго-Ахтубинская пойма', region: 'Волгоградская / Астраханская область', type: 'river', manual: [48.3000, 46.0000],
    description: 'Сотни проток и ериков, тёплая вода, камышовые лабиринты.' },

  // — моря и заливы —
  { name: 'Финский залив', region: 'Санкт-Петербург и Ленобласть', type: 'sea', manual: [59.9400, 29.7500],
    description: 'Мелководная солёная вода, ветер появляется внезапно.' },
  { name: 'Чёрное море', region: 'Краснодарский край, Сочи', type: 'sea', manual: [43.5855, 39.7231],
    description: 'Морской SUP, сезон май–октябрь, волны и течения.' },
  { name: 'Азовское море', region: 'Краснодарский край / Ростовская область', type: 'sea', manual: [46.5000, 37.8000],
    description: 'Самое мелкое море: тёплая вода и длинный пологий вход.' },
  { name: 'Японское море', region: 'Приморский край, Владивосток', type: 'sea', manual: [43.0600, 131.9300],
    description: 'Бухты Приморья, прозрачная вода, холодное течение.' },
];

/** Типы объектов OSM, которые вообще могут быть водоёмом. */
const WATER_ADDRESS_TYPES = new Set([
  'water', 'lake', 'reservoir', 'river', 'stream', 'sea', 'bay', 'strait',
  'lagoon', 'sound', 'canal', 'wetland', 'marsh',
]);

/**
 * Сопоставление с Nominatim ненадёжно: по «Чёрное море» он отдаёт отель,
 * по «Озеро Ладожское» — одноимённую станцию. Берём хит только если это
 * реально водный объект И его название совпадает с нашим ключевым словом.
 */
function acceptHit(hit, name) {
  if (!hit) return false;
  const kind = (hit.addresstype || hit.type || hit.class || '').toLowerCase();
  if (!WATER_ADDRESS_TYPES.has(kind)) return false;
  const key = keyToken(name);
  const hay = `${hit.name ?? ''} ${hit.display_name ?? ''}`.toLowerCase();
  return hay.includes(key);
}

/** Главное слово названия без родовых полей («озеро», «река», «море»…). */
function keyToken(name) {
  const generic = new Set(['озеро', 'озера', 'река', 'реке', 'море', 'залив', 'водохранилище', 'канал', 'остров']);
  const words = name
    .toLowerCase()
    .replace(/[«»"]/g, '')
    .split(/[\s-]+/)
    .filter((w) => w.length > 2 && !generic.has(w));
  return words.sort((a, b) => b.length - a.length)[0] ?? name.toLowerCase();
}

async function geocode(query, type) {
  const featureType =
    type === 'river' ? 'river' : type === 'sea' ? 'bay' : type === 'reservoir' ? 'reservoir' : 'lake';
  const url =
    `${NOMINATIM}?format=jsonv2&limit=5&q=${encodeURIComponent(query)}` +
    `&featuretype=${featureType}&countrycodes=ru`;
  const res = await fetch(url, { headers: { 'User-Agent': USER_AGENT, 'Accept-Language': 'ru' } });
  if (!res.ok) throw new Error(`Nominatim HTTP ${res.status}`);
  const rows = await res.json();
  return rows.find((r) => acceptHit(r, query)) ?? null;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function main() {
  const pool = new Pool({
    host: process.env.DB_HOST ?? 'localhost',
    port: Number(process.env.DB_PORT ?? 5432),
    user: process.env.DB_USER ?? 'postgres',
    password: process.env.DB_PASSWORD ?? 'postgres',
    database: process.env.DB_NAME ?? 'sup_fun',
  });

  const resolved = [];
  for (const wb of WATER_BODIES) {
    let lat = wb.manual[0];
    let lng = wb.manual[1];
    let source = 'manual';
    try {
      // 1 запрос в секунду — требование использования Nominatim
      await sleep(1100);
      const hit = wb.preferManual ? null : await geocode(`${wb.name} ${wb.region.split('/')[0]}`, wb.type);
      if (hit) {
        lat = Number(hit.lat);
        lng = Number(hit.lon);
        source = `osm:${hit.type ?? hit.class ?? 'nominatim'}`;
      }
    } catch (err) {
      console.warn(`  ! ${wb.name}: геокодинг недоступен (${err.message}) — беру ручные координаты`);
    }
    resolved.push({ ...wb, lat, lng, source });
    console.log(`  ${wb.name.padEnd(28)} ${lat.toFixed(4)}, ${lng.toFixed(4)}  [${source}]`);
  }

  if (!APPLY) {
    console.log(`\nПоказано ${resolved.length} водоёмов. Перезапустите с --apply, чтобы записать.`);
    await pool.end();
    return;
  }

  let inserted = 0;
  let updated = 0;
  for (const wb of resolved) {
    const existing = await pool.query('SELECT id FROM waterbodies WHERE name = $1', [wb.name]);
    // location — geometry(Point, 4326), см. waterbodies.location в БД
    if (existing.rowCount > 0) {
      await pool.query(
        `UPDATE waterbodies
            SET description = $2, region = $3, active = TRUE,
                location = ST_SetSRID(ST_MakePoint($4, $5), 4326),
                updated_at = now()
          WHERE id = $1`,
        [existing.rows[0].id, wb.description, wb.region, wb.lng, wb.lat],
      );
      updated += 1;
    } else {
      await pool.query(
        `INSERT INTO waterbodies (id, name, description, region, active, location, created_at, updated_at)
         VALUES (gen_random_uuid(), $1, $2, $3, TRUE, ST_SetSRID(ST_MakePoint($4, $5), 4326), now(), now())`,
        [wb.name, wb.description, wb.region, wb.lng, wb.lat],
      );
      inserted += 1;
    }
  }
  console.log(`\nВодоёмы: обновлено ${updated}, добавлено ${inserted}`);

  if (CLEAN) {
    // Мусор чистим на JS: регулярки с mojibake-символами в SQL ненадёжны.
    // Двойная UTF-8 перекодировка кириллицы даёт символы U+0080–U+00BF.
    const all = await pool.query(
      `SELECT w.id, w.name, w.region,
              (SELECT count(*) FROM events e WHERE e.waterbody_id = w.id)::int AS events,
              (SELECT count(*) FROM tracks t WHERE t.waterbody_id = w.id)::int AS tracks,
              (SELECT count(*) FROM routes r WHERE r.waterbody_id = w.id)::int AS routes,
              (SELECT count(*) FROM users u WHERE u.home_waterbody_id = w.id)::int AS homes
         FROM waterbodies w`,
    );
    const isMojibake = (s) => /[\u0080-\u00BF]/.test(s ?? '');
    // Объектов с такими названиями не существует — это испорченные записи из старых данных.
    const OBSOLETE_NAMES = new Set(['озеро курило-камчатский']);
    const knownBad = (row) =>
      isMojibake(row.name) || isMojibake(row.region) ||
      (row.region ?? '').trim() === '1' ||
      /япония/i.test(row.region ?? '') ||
      OBSOLETE_NAMES.has((row.name ?? '').toLowerCase());

    let removed = 0;
    for (const row of all.rows) {
      if (!knownBad(row)) continue;
      const used = row.events + row.tracks + row.routes + row.homes;
      if (used > 0) {
        console.log(`  пропуск (ссылаются данные, ${used}): ${row.name}`);
        continue;
      }
      await pool.query('DELETE FROM waterbodies WHERE id = $1', [row.id]);
      console.log(`  удалён мусорный водоём: ${row.name}`);
      removed += 1;
    }
    console.log(`Удалено строк: ${removed}`);
  }

  await pool.end();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
