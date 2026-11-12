// One-off: mark a test user's email as verified.
// Reads DB_* from .env in-process; never prints secrets.
// Usage: node verify-user.mjs <email>
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const envPath = fileURLToPath(new URL('./.env', import.meta.url));
const env = {};
for (const line of readFileSync(envPath, 'utf8').split(/\r?\n/)) {
  if (!line.includes('=') || line.startsWith('#')) continue;
  const i = line.indexOf('=');
  env[line.slice(0, i).trim()] = line.slice(i + 1).trim();
}

const email = process.argv[2];
if (!email) {
  console.error('usage: node verify-user.mjs <email>');
  process.exit(2);
}

const client = new pg.Client({
  host: env.DB_HOST,
  port: Number(env.DB_PORT),
  user: env.DB_USERNAME,
  password: env.DB_PASSWORD,
  database: env.DB_DATABASE,
});
await client.connect();
try {
  const res = await client.query(
    'UPDATE users SET is_email_verified = true WHERE email = $1 RETURNING id',
    [email],
  );
  console.log(`rows_updated=${res.rowCount}`);
  if (res.rowCount) console.log(`user_id=${res.rows[0].id}`);
} finally {
  await client.end();
}
