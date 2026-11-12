const ds = require('./dist/data-source.js').default;
(async () => {
  await ds.initialize();
  const cols = await ds.query("SELECT column_name FROM information_schema.columns WHERE table_name='users' ORDER BY ordinal_position");
  console.log('users cols:', JSON.stringify(cols.map(r => r.column_name)));
  const audit = await ds.query("SELECT action, email, ip, user_agent, status, created_at FROM auth_audit ORDER BY id DESC LIMIT 10");
  console.log('audit:');
  for (const r of audit) console.log(`  ${r.created_at} ${r.action} ${r.email} ${r.status} ip=${r.ip}`);
  await ds.destroy();
})().catch((e) => { console.error('ERR', e.message); process.exit(1; });
