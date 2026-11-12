@echo off
REM ===================================================================
REM  Stops the SUP FUN web frontend (Vite dev server on port 5173)
REM ===================================================================

setlocal EnableExtensions

echo =====================================================
echo  SUP FUN frontend stop
echo =====================================================
echo.

REM --- Find process holding port 5173 --------------------------------
set FOUND=0
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "Get-NetTCPConnection -State Listen -LocalPort 5173 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique" 2^>nul') do (
    set FOUND=1
    echo [INFO] Port 5173 held by PID %%i
    taskkill /pid %%i /f >nul 2>&1
    if not errorlevel 1 (
        echo [OK] Killed PID %%i
    )
)

REM --- Fallback: kill all node.exe -----------------------------------
tasklist /fi "imagename eq node.exe" 2>nul | findstr /i "node.exe" >nul
if not errorlevel 1 (
    echo [INFO] Killing remaining node.exe processes
    taskkill /im node.exe /f >nul 2>&1
    if not errorlevel 1 (
        echo [OK] Done
    ) else (
        echo [WARNING] taskkill returned an error
    )
)

if %FOUND%==0 (
    echo [OK] No process was holding port 5173
)

REM --- Verify --------------------------------------------------------
ping -n 3 127.0.0.1 >nul 2>&1
powershell -NoProfile -Command "$x = Get-NetTCPConnection -State Listen -LocalPort 5173 -ErrorAction SilentlyContinue; if ($x) { Write-Output '[ERROR] Port 5173 still busy' ; exit 1 } else { Write-Output '[OK] Port 5173 is free'; exit 0 }" 2>nul
if errorlevel 1 (
    echo.
    echo Stop signal sent, but port may need a moment to release.
)

echo.
pause
endlocal
