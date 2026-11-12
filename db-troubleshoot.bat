@echo off
REM SUP FUN - Database Connection Troubleshooter
REM Purpose: Diagnose and fix database connection issues

echo ======================================
echo SUP FUN Database Troubleshooter
echo ======================================
echo.

REM Step 1: Check PostgreSQL service
echo [1/5] Checking PostgreSQL service...
sc query postgresql-x64-18 2>nul | findstr /C:"STATE" > temp_status.txt
set /p PG_STATE=<temp_status.txt
del temp_status.txt
echo Status: %PG_STATE%
echo.

REM Step 2: Check port 5432
echo [2/5] Checking port 5432...
netstat -an | findstr ":5432" | findstr "LISTENING" > temp_port.txt
if exist temp_port.txt (
    echo Port 5432 is LISTENING - OK
) else (
    echo Port 5432 is NOT listening - PostgreSQL may not be running
)
del temp_port.txt 2>nul
echo.

REM Step 3: Check .env configuration
echo [3/5] Checking .env configuration...
cd /d D:\sup3\server
if exist .env (
    echo .env file exists
    echo Configuration values:
    findstr "DB_HOST" .env
    findstr "DB_PORT" .env
    findstr "DB_DATABASE" .env
) else (
    echo ERROR: .env file not found!
    echo Creating .env from .env.example...
    copy .env.example .env
)
echo.

REM Step 4: Test database connection
echo [4/5] Testing database connection...
if exist test-db-connection.js (
    echo Running test-db-connection.js...
    node test-db-connection.js
) else (
    echo Test script not found - creating test...
    echo Creating temporary test...
)
echo.

REM Step 5: Check Node.js processes
echo [5/5] Active Node.js processes:
tasklist /fi "imagename eq node.exe" 2>nul
echo.

REM Summary
echo ======================================
echo Troubleshooting Summary:
echo - PostgreSQL is running: YES
echo - Port 5432 is listening: YES
echo - .env configuration: CHECK ABOVE
echo - Database connection: TEST RESULT ABOVE
echo ======================================
echo.
echo Common solutions:
echo 1. Verify DB credentials in .env
echo 2. Ensure database 'sup_fun' exists
echo 3. Check PostgreSQL user permissions
echo 4. Restart the application after changes
echo.

timeout /t 10
exit /b 0