@echo off
REM Simple SUP FUN Startup
echo Starting SUP FUN System...
echo ==========================

REM Create directories
mkdir logs 2>nul
mkdir data 2>nul

REM Start system monitor (if Python available)
where python >nul 2>&1
if %errorlevel% equ 0 (
    echo Starting system monitor...
    python ".hermes\system-monitor.py"
) else (
    echo Python not found - skipping monitor
)

echo.
echo SUP FUN system initialized successfully
echo.
pause