@echo off
REM SUP FUN - Build Monitor Script
REM Purpose: Monitor application build process

echo ======================================
echo SUP FUN Build Monitor
echo ======================================
echo.

REM Step 1: Check TypeScript compilation
echo [1/4] Monitoring TypeScript compilation...
cd /d D:\sup3\server

if exist dist (
    echo [INFO] dist directory exists - checking for updates
    for %%f in (dist\*.js) do echo   - %%~nxf
) else (
    echo [WARNING] dist directory not found - build needed
)

echo.

REM Step 2: Check source changes
echo [2/4] Checking source files...
dir /s /b src\*.ts 2>nul | find /c "\.ts$" > temp_count.txt
set /p TS_COUNT=<temp_count.txt
del temp_count.txt
echo [INFO] TypeScript source files: %TS_COUNT%

echo.

REM Step 3: Watch process status
echo [3/4] Active processes:
tasklist /fi "imagename eq node.exe" 2>nul
echo.

REM Step 4: Display build output
echo [4/4] Recent build output:
if exist run3002.out (
    echo --- Last run3002 output ---
    powershell -Command "Get-Content run3002.out -Tail 15"
)
if exist server-output.log (
    echo --- Server output log ---
    powershell -Command "Get-Content server-output.log -Tail 15"
)

echo.
echo ======================================
echo Build monitor complete
echo ======================================
timeout /t 5
exit /b 0