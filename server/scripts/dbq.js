// Ad-hoc DB inspector (dev only). Usage: node scripts/dbq.js "SELECT ..."
const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

const env = fs.readFileSync(path.join(__dirname, '..', '.env'), 'utf8');
const cfg = {};
for (const line of env.split(/\r?\n/)) {
  const m = line.match(/^([A-Z_]+)=(.*)$/);
  if (m) cfg[m[1]] = m[2];
}

(async () => {
  const c = new Client({
    host: cfg.DB_HOST,
    port: Number(cfg.DB_PORT || 5432),
    user: cfg.DB_USERNAME,
    password: cfg.DB_PASSWORD,
    database: cfg.DB_DATABASE,
  });
  await c.connect();
  const sql = process.argv[2];
  if (!sql) {
    const t = await c.query(
      `SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name`,
    );
    console.log(t.rows.map((r) => r.table_name).join('\n'));
  } else {
    const r = await c.query(sql);
    console.log(JSON.stringify(r.rows, null, 1));
  }
  await c.end();
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
