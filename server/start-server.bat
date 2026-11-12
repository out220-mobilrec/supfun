@echo off
REM ===================================================================
REM  SUP FUN backend server launcher (D:\sup3\server)
REM
REM  - проверяет, что PostgreSQL доступен
REM  - убивает старые node.exe, если порт 3000 занят (EADDRINUSE)
REM  - если dist/ нет — собирает проект (npm run build)
REM  - запускает node dist/main.js
REM  - ждёт готовности /api/health (5 секунд)
REM  - при ошибке печатает причину
REM ===================================================================

setlocal EnableExtensions EnableDelayedExpansion

set PROJECT=%~dp0
cd /d "%PROJECT%"

echo =====================================================
echo  SUP FUN backend launcher
echo  %PROJECT%
echo =====================================================
echo.

REM --- 1. Sanity checks -----------------------------------------------
where node >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Node.js not found in PATH. Install from https://nodejs.org/
    pause
    exit /b 1
)
where npm >nul 2>&1
if errorlevel 1 (
    echo [ERROR] npm not found in PATH.
    pause
    exit /b 1
)

REM --- 2. PostgreSQL availability ------------------------------------
echo [1/5] Checking PostgreSQL on localhost:5432 ...
powershell -NoProfile -Command "try { (New-Object System.Net.Sockets.TcpClient).Connect('127.0.0.1', 5432) } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Cannot connect to PostgreSQL on 127.0.0.1:5432
    echo          Server will start but DB-dependent endpoints may fail.
    echo          Start PostgreSQL service: net start postgresql-x64-18
) else (
    echo [OK] PostgreSQL reachable
)
echo.

REM --- 3. Build if dist is missing -----------------------------------
if not exist "dist\main.js" (
    echo [2/5] dist\main.js not found, building ...
    call npm install --legacy-peer-deps
    if errorlevel 1 (
        echo [ERROR] npm install failed
        pause
        exit /b 1
    )
    call npm run build
    if errorlevel 1 (
        echo [ERROR] npm run build failed
        pause
        exit /b 1
    )
    echo [OK] Build complete
) else (
    echo [2/5] dist\main.js already exists, skipping build
)
echo.

REM --- 4. Free port 3000 if EADDRINUSE --------------------------------
echo [3/5] Checking port 3000 ...
set PORT_BUSY=0
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-NetTCPConnection -State Listen -LocalPort 3000 -ErrorAction SilentlyContinue).OwningProcess | Select-Object -First 1" 2^>nul') do set PORT_PID=%%i
if defined PORT_PID (
    set PORT_BUSY=1
    echo [WARNING] Port 3000 is in use by PID !PORT_PID!
    echo          Killing old node.exe processes ...
    taskkill /im node.exe /f >nul 2>&1
    ping -n 3 127.0.0.1 >nul 2>&1
    echo [OK] Old processes terminated
) else (
    echo [OK] Port 3000 is free
)
echo.

REM --- 5. Start server in background and verify health ---------------
echo [4/5] Starting server ...
start "SUP FUN Server" /min cmd /c "node dist\main.js"

REM --- 6. Wait for /api/health (max 20s) ------------------------------
echo [5/5] Waiting for /api/health ...
set HEALTH_OK=0
for /l %%i in (1,1,20) do (
    ping -n 2 127.0.0.1 >nul 2>&1
    powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://localhost:3000/api/health' -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200; exit 0 } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 (
        set HEALTH_OK=1
        goto :health_ok
    )
)

:health_ok
if %HEALTH_OK%==1 (
    echo.
    echo =====================================================
    echo  Server is up at http://localhost:3000
    echo  Swagger UI:  http://localhost:3000/api/docs
    echo =====================================================
    echo  Minimised console "SUP FUN Server" is running.
    echo  Use stop-server.bat to stop it.
    echo.
    echo  This launcher will now exit. Server stays in background.
    ping -n 4 127.0.0.1 >nul 2>&1
) else (
    echo.
    echo [ERROR] Server did not become healthy within 20s.
    echo          Check the minimised console window
    echo          "SUP FUN Server" for the actual error.
    pause
    exit /b 1
)

endlocal
