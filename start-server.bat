@echo off
chcp 65001 >nul
title SUP FUN - server

set "ROOT=%~dp0"
set "SERVER=%ROOT%server"

where node >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Node.js not found
  pause
  exit /b 1
)

if not exist "%SERVER%\node_modules" (
  echo Installing server dependencies...
  pushd "%SERVER%"
  call npm install
  popd
)

cd /d "%SERVER%"
echo.
echo ============================================
echo  SUP FUN - Backend (NestJS)
echo  API:  http://localhost:3000
echo  Docs: http://localhost:3000/api/docs
echo ============================================
echo.

if exist "%SERVER%\dist\main.js" (
  echo Starting: node dist/main.js
  node dist/main.js
) else (
  echo No build found, dev mode: npm run start:dev
  call npm run start:dev
)

pause
