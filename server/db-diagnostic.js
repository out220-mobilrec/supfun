// SUP FUN - Database Diagnostic Tool
// Purpose: Comprehensive database connection diagnostics

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

console.log('======================================');
console.log('SUP FUN Database Diagnostic Tool');
console.log('======================================\n');

// Load .env manually
const envPath = path.join(__dirname, '.env');
let dbConfig = {
    host: 'localhost',
    port: 5432,
    user: 'postgres',
    password: '',
    database: 'sup_fun'
};

if (fs.existsSync(envPath)) {
    console.log('[1/6] Loading .env file...');
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split('\n').forEach(line => {
        const [key, value] = line.split('=');
        if (key && value) {
            const trimmedKey = key.trim();
            const trimmedValue = value.trim().replace(/^["']|["']$/g, '');
            if (trimmedKey === 'DB_HOST') dbConfig.host = trimmedValue;
            if (trimmedKey === 'DB_PORT') dbConfig.port = parseInt(trimmedValue);
            if (trimmedKey === 'DB_USERNAME') dbConfig.user = trimmedValue;
            if (trimmedKey === 'DB_PASSWORD') dbConfig.password = trimmedValue;
            if (trimmedKey === 'DB_DATABASE') dbConfig.database = trimmedValue;
        }
    });
    console.log(`  Host: ${dbConfig.host}`);
    console.log(`  Port: ${dbConfig.port}`);
    console.log(`  User: ${dbConfig.user}`);
    console.log(`  Database: ${dbConfig.database}\n`);
}

// Diagnostic functions
async function testConnection(config, label) {
    console.log(`[${label}] Testing connection to ${config.host}:${config.port}/${config.database}...`);
    const client = new Client(config);
    try {
        await client.connect();
        console.log(`  ✓ SUCCESS: Connected to ${config.database}`);
        const res = await client.query('SELECT version()');
        console.log(`  ✓ Server version: ${res.rows[0].version}`);
        await client.end();
        return true;
    } catch (err) {
        console.log(`  ✗ FAILED: ${err.message}`);
        console.log(`  ✗ Code: ${err.code}`);
        return false;
    }
}

async function listDatabases(config) {
    console.log('[3/6] Listing available databases...');
    const client = new Client({...config, database: 'postgres'});
    try {
        await client.connect();
        const res = await client.query("SELECT datname FROM pg_database WHERE datistemplate = false");
        console.log('  Available databases:');
        res.rows.forEach(row => console.log(`    - ${row.datname}`));

        const targetExists = res.rows.some(row => row.datname === dbConfig.database);
        if (!targetExists) {
            console.log(`\n  ⚠ Target database '${dbConfig.database}' does NOT exist!`);
            console.log(`  Creating database '${dbConfig.database}'...`);

            try {
                await client.query(`CREATE DATABASE ${dbConfig.database}`);
                console.log(`  ✓ Database '${dbConfig.database}' created successfully!`);
            } catch (createErr) {
                console.log(`  ✗ Failed to create database: ${createErr.message}`);
            }
        }
        await client.end();
    } catch (err) {
        console.log(`  ✗ Cannot list databases: ${err.message}`);
    }
}

async function checkPort(port) {
    console.log(`[4/6] Checking if port ${port} is reachable...`);
    const net = require('net');
    return new Promise((resolve) => {
        const socket = new net.Socket();
        socket.setTimeout(3000);
        socket.on('connect', () => {
            console.log(`  ✓ Port ${port} is OPEN`);
            socket.destroy();
            resolve(true);
        });
        socket.on('timeout', () => {
            console.log(`  ✗ Port ${port} TIMEOUT`);
            socket.destroy();
            resolve(false);
        });
        socket.on('error', (err) => {
            console.log(`  ✗ Port ${port} ERROR: ${err.message}`);
            resolve(false);
        });
        socket.connect(port, dbConfig.host);
    });
}

// Run diagnostics
(async () => {
    try {
        // Check port
        await checkPort(dbConfig.port);
        console.log('');

        // Test default postgres database
        const postgresConfig = {...dbConfig, database: 'postgres'};
        const connected = await testConnection(postgresConfig, '2/6');
        console.log('');

        if (connected) {
            await listDatabases(postgresConfig);
            console.log('');

            // Test target database
            const targetConnected = await testConnection(dbConfig, '5/6');
            console.log('');

            if (!targetConnected) {
                console.log('[6/6] Attempting to create and connect to target database...');
                // Try without specifying database to see if we can create it
            }
        } else {
            console.log('[3/6] Cannot connect to default postgres database.');
            console.log('Possible issues:');
            console.log('  - PostgreSQL is not running');
            console.log('  - Wrong credentials in .env');
            console.log('  - pg_hba.conf authentication issues');
        }
    } catch (err) {
        console.log(`\n✗ Diagnostic failed: ${err.message}`);
    }

    console.log('\n======================================');
    console.log('Diagnostic Complete');
    console.log('======================================');
    process.exit(0);
})();