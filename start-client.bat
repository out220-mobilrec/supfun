@echo off
chcp 65001 >nul
title SUP FUN - web client

set "ROOT=%~dp0"
set "WEB=%ROOT%web"

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js not found
  pause
  exit /b 1
)

if not exist "%WEB%\node_modules" (
  echo Installing client dependencies...
  pushd "%WEB%"
  call npm install
  popd
)

cd /d "%WEB%"
echo.
echo ============================================
echo  SUP FUN - Web (Vite)
echo  UI: http://localhost:5173
echo  API proxies to http://localhost:3000
echo ============================================
echo.

call npm run dev

pause
