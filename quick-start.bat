@echo off
REM SUP FUN - Quick Server Start with DB Connection Fix
REM Purpose: Start server with proper DB configuration

echo ======================================
echo SUP FUN - Quick Server Start
echo ======================================
echo.

cd /d D:\sup3\server

REM Step 1: Verify database connection
echo [1/4] Verifying database connection...
node -e "const{Client}=require('pg');const c=new Client({host:'localhost',port:5432,user:'postgres',password:process.env.DB_PASSWORD||'postgres',database:'sup_fun'});c.connect().then(()=>{console.log('DB OK');c.end()}).catch(e=>{console.log('DB Error:',e.message);process.exit(1)})"
if %errorlevel% neq 0 (
    echo [ERROR] Database connection failed
    echo Trying to fix by creating database...
    node -e "const{Client}=require('pg');const c=new Client({host:'localhost',port:5432,user:'postgres',password:process.env.DB_PASSWORD||'postgres',database:'postgres'});c.connect().then(async()=>{try{await c.query('CREATE DATABASE sup_fun');console.log('Database created')}catch(e){console.log('DB exists or error:',e.message)}c.end()})"
)
echo.

REM Step 2: Build the project
echo [2/4] Building TypeScript...
call npm run build
if %errorlevel% neq 0 (
    echo [ERROR] Build failed
    pause
    exit /b 1
)
echo.

REM Step 3: Start the server
echo [3/4] Starting server in background...
echo Server will run on port configured in .env
start "SUP FUN Server" cmd /k "node dist\main.js"

echo.
echo [4/4] Server started in new window!
echo.
echo To monitor the server:
echo - View logs in the new window
echo - Or run: tail -f D:\sup3\server\server-output.log
echo.

timeout /t 5
exit /b 0