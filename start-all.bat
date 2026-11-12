@echo off
chcp 65001 >nul
title SUP FUN - launcher

set "ROOT=%~dp0"
set "SERVER=%ROOT%server"
set "WEB=%ROOT%web"

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js not found in PATH
  pause
  exit /b 1
)

if not exist "%SERVER%\node_modules" (
  echo Installing server dependencies...
  pushd "%SERVER%"
  call npm install
  popd
)
if not exist "%WEB%\node_modules" (
  echo Installing client dependencies...
  pushd "%WEB%"
  call npm install
  popd
)

echo.
echo ============================================
echo   SUP FUN - Backend + Web
echo ============================================
echo   API:  http://localhost:3000
echo   Docs: http://localhost:3000/api/docs
echo   UI:   http://localhost:5173
echo.
echo   Admin:      admin@supfun.app / password123
echo   Moderator:  mod6573@dev.sup / password123
echo.
echo   PostgreSQL (DB sup_fun) required.
echo ============================================
echo.

echo [1/2] Starting backend...
start "SUP FUN Server" /D "%SERVER%" cmd /c "cd /d %SERVER% && node dist/main.js"

echo Waiting for API (3000)...
set /a tries=0
:waitloop
set /a tries+=1
curl -s -o nul http://localhost:3000/api/health
if not errorlevel 1 goto ready
if %tries% geq 40 goto timeout
timeout /t 1 /nobreak >nul
goto waitloop

:ready
echo Backend ready.

:timeout
if %tries% geq 40 echo [WARNING] API timeout after 40s.

echo [2/2] Starting web client...
start "SUP FUN Web" /D "%WEB%" cmd /c "cd /d %WEB% && npm run dev"

timeout /t 4 /nobreak >nul
start "" http://localhost:5173

echo.
echo Complete. Close windows to stop services.
exit /b 0
