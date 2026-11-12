const { Client } = require('pg');

const client = new Client({
  host: 'localhost',
  port: 5432,
  user: 'postgres',
  password: process.env.DB_PASSWORD || 'change_me',
  database: 'sup_fun'
});

client.connect(async (err) => {
  if (err) {
    console.log('Connection Error:', err.message, 'Code:', err.code);
  } else {
    console.log('Connected to sup_fun database!');
    const res = await client.query(
      'SELECT datname FROM pg_database WHERE datname = $1', ['sup_fun']
    );
    console.log('Database status:', res.rows[0].datname ? '✓ AVAILABLE' : '✗ NOT FOUND');
  }
  client.end();
});

console.log('Testing connection to sup_fun database on localhost:5432...');
