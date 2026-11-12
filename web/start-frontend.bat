@echo off
REM ===================================================================
REM  SUP FUN web frontend launcher (D:\sup3\web)
REM
REM  - проверяет, что Node.js установлен
REM  - ставит зависимости, если node_modules нет
REM  - убивает старые процессы, если порт 5173 занят (EADDRINUSE)
REM  - если dist/ есть и свежее src/ — спрашивает, запустить preview или
REM    пересобрать
REM  - запускает `npm run dev` в минимизированной консоли
REM  - ждёт готовности http://localhost:5173 (до 30 сек)
REM
REM  Использование:
REM    start-frontend.bat         - dev-режим (Vite, с hot-reload)
REM    start-frontend.bat preview - build + Vite preview (production)
REM ===================================================================

setlocal EnableExtensions EnableDelayedExpansion

set PROJECT=%~dp0
cd /d "%PROJECT%"

set MODE=%1
if "%MODE%"==""" set MODE=dev

echo =====================================================
echo  SUP FUN web frontend launcher
echo  %PROJECT%
echo  mode: %MODE%
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

REM --- 2. Install deps if needed --------------------------------------
if not exist "node_modules" (
    echo [1/5] node_modules not found, installing ...
    call npm install
    if errorlevel 1 (
        echo [ERROR] npm install failed
        pause
        exit /b 1
    )
    echo [OK] Dependencies installed
) else (
    echo [1/5] node_modules present, skipping install
)
echo.

REM --- 3. Preview-mode needs build ------------------------------------
if /I "%MODE%"=="preview" (
    if not exist "dist\index.html" (
        echo [2/5] Building for production ...
        call npm run build
        if errorlevel 1 (
            echo [ERROR] npm run build failed
            pause
            exit /b 1
        )
        echo [OK] Build complete
    ) else (
        echo [2/5] dist\index.html already exists, skipping build
    )
    echo.
)

REM --- 4. Free port 5173 if EADDRINUSE --------------------------------
echo [3/5] Checking port 5173 ...
set PORT_PID=
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-NetTCPConnection -State Listen -LocalPort 5173 -ErrorAction SilentlyContinue).OwningProcess | Select-Object -First 1" 2^>nul') do set PORT_PID=%%i
if defined PORT_PID (
    echo [WARNING] Port 5173 is in use by PID !PORT_PID!
    echo          Killing old node.exe / vite processes ...
    taskkill /im node.exe /f >nul 2>&1
    ping -n 3 127.0.0.1 >nul 2>&1
    echo [OK] Old processes terminated
) else (
    echo [OK] Port 5173 is free
)
echo.

REM --- 5. Start frontend (minimised console) -------------------------
echo [4/5] Starting Vite ...
if /I "%MODE%"=="preview" (
    set CMDLINE=npm run preview -- --port 5173 --strictPort
    set TITLE=SUP FUN Frontend (preview)
) else (
    set CMDLINE=npm run dev -- --port 5173 --strictPort --host
    set TITLE=SUP FUN Frontend (dev)
)
start "%TITLE%" /min cmd /c "%CMDELINE%"

REM --- 6. Wait for / (max 30s) ----------------------------------------
echo [5/5] Waiting for http://localhost:5173 ...
set FRONTEND_OK=0
for /l %%i in (1,1,30) do (
    ping -n 2 127.0.0.1 >nul 2>&1
    powershell -NoProfile -Command "try { (Invoke-WebRequest -Uri 'http://localhost:5173' -UseBasicParsing -TimeoutSec 2).StatusCode -ge 200; exit 0 } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 (
        set FRONTEND_OK=1
        goto :up
    )
)

:up
if %FRONTEND_OK%==1 (
    echo.
    echo =====================================================
    if /I "%MODE%"=="preview" (
        echo  Production build served at http://localhost:5173
    ) else (
        echo  Dev server up at http://localhost:5173
        echo  Hot reload enabled
    )
    echo =====================================================
    echo  Minimised console: "%TITLE%"
    echo  Use stop-frontend.bat to stop it.
    echo.
    echo  This launcher exits. Frontend stays in background.
    ping -n 4 127.0.0.1 >nul 2>&1
) else (
    echo.
    echo [ERROR] Frontend did not respond within 30s.
    echo          Check the minimised console "%TITLE%"
    echo          for actual errors.
    pause
    exit /b 1
)

endlocal
