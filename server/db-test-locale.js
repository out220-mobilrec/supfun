// SUP FUN - Database Connection Test with Locale Fix
const { Client } = require('pg');

console.log('=== SUP FUN Database Connection Test ===\n');

(async () => {
    const client = new Client({
        host: 'localhost',
        port: 5432,
        user: 'postgres',
        password: process.env.DB_PASSWORD || 'change_me',
        database: 'sup_fun'
    });

    try {
        await client.connect();
        console.log('[OK] Connected to database!');

        const res = await client.query('SELECT version()');
        console.log('[OK] Server version:', res.rows[0].version);

        // Check if sup_fun database exists and accessible
        const dbCheck = await client.query(
            "SELECT datname FROM pg_database WHERE datname = 'sup_fun'"
        );
        console.log('[OK] Database "sup_fun" accessible:', dbCheck.rows.length > 0 ? 'YES' : 'NO');

        // List tables
        const tables = await client.query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' LIMIT 10"
        );
        console.log('[OK] Tables found:', tables.rows.length);
        if (tables.rows.length > 0) {
            console.log('  Tables:');
            tables.rows.forEach(r => console.log('    -', r.table_name));
        }

        await client.end();
        console.log('\n[SUCCESS] All tests passed!');
    } catch (err) {
        console.log('[ERROR] Connection failed:', err.message);
        console.log('[ERROR] Code:', err.code);
        console.log('[ERROR] Detail:', err.detail);

        // Try with different encoding
        if (err.message.includes('����') || err.message.includes('кодировк')) {
            console.log('\n[INFO] Encoding error detected');
            console.log('[INFO] Trying with explicit UTF-8 encoding...');

            const client2 = new Client({
                host: 'localhost',
                port: 5432,
                user: 'postgres',
                password: process.env.DB_PASSWORD || 'change_me',
                database: 'sup_fun',
                client_encoding: 'UTF8'
            });

            try {
                await client2.connect();
                console.log('[OK] Connected with UTF-8 encoding!');
                await client2.end();
            } catch (e2) {
                console.log('[ERROR] UTF-8 also failed:', e2.message);
            }
        }

        process.exit(1);
    }
})();