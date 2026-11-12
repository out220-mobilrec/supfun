@echo off
REM Launch SUP FUN Mobile App on available platforms
REM Usage: launch-app.bat [platform]

set PROJECT_PATH=D:\sup3\SUP_FUN_Flutter_v0.1_VISUAL_FULL
set PLATFORM=%1

echo ====================================
echo SUP FUN Mobile App Launcher
echo ====================================
echo.

cd /d %PROJECT_PATH%

REM Check Flutter installation
where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter not found in PATH
    echo Please install Flutter from https://flutter.dev
    pause
    exit /b 1
)

echo [OK] Flutter found
flutter --version | findstr "Flutter"
echo.

if "%PLATFORM%"=="android" goto :android
if "%PLATFORM%"=="chrome" goto :chrome
if "%PLATFORM%"=="web" goto :chrome
if "%PLATFORM%"=="windows" goto :windows

REM No platform specified - show menu
:menu
echo Select target platform:
echo 1. Chrome (web) - fastest
echo 2. Windows (desktop)
echo 3. Android (requires Android SDK)
echo 4. Edge (web)
echo.
set /p CHOICE="Enter choice (1-4): "

if "%CHOICE%"=="1" goto :chrome
if "%CHOICE%"=="2" goto :windows
if "%CHOICE%"=="3" goto :android
if "%CHOICE%"=="4" goto :edge
goto :menu

:chrome
echo [INFO] Starting on Chrome...
call flutter run -d chrome --web-port=8080
goto :end

:edge
echo [INFO] Starting on Edge...
call flutter run -d edge --web-port=8080
goto :end

:windows
echo [INFO] Building for Windows...
echo This requires Visual Studio Build Tools.
call flutter build windows
if %errorlevel%==0 (
    echo.
    echo [OK] Build complete
    echo Run: %PROJECT_PATH%\build\windows\x64\runner\Debug\sup_fun.exe
)
goto :end

:android
echo [INFO] Checking Android setup...
where adb >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Android SDK not detected
    echo.
    echo To run on Android:
    echo 1. Install Android Studio: https://developer.android.com/studio
    echo 2. Run: flutter doctor
    echo 3. Connect device via USB or start emulator
    echo 4. Run this script again with: launch-app.bat android
    echo.
    pause
    exit /b 1
)

echo [OK] Android tools detected
flutter devices
echo.
echo Starting on first available Android device...
call flutter run -d android
goto :end

:end
echo.
echo Application stopped.
pause
