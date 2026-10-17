@echo off
setlocal enabledelayedexpansion

echo =================================================================
echo        [ZENHOME SMART HOME] - XUAT BAN PHAT HANH APK
echo =================================================================
echo.

set "ROOT_DIR=%~dp0"
set "APP_DIR=%ROOT_DIR%zenhome_app"

if not exist "%APP_DIR%\pubspec.yaml" (
    echo [ERROR] Khong tim thay thu muc zenhome_app!
    pause
    exit /b 1
)

cd /d "%APP_DIR%"

:: Giai phong Gradle daemon cu de khong bi lock file trong build/
if exist "android\gradlew.bat" (
    echo [*] Dang giai phong Gradle Daemons cu...
    call android\gradlew.bat --stop > nul 2>&1
)

echo.
echo [1/4] Dang don dep bo nho dem (flutter clean)...
call flutter clean
if %ERRORLEVEL% neq 0 (
    echo [THONG BAO] Thu muc build co file dang khoa, van tiep tuc qua trinh bien dich...
)

echo.
echo [2/4] Dang tai lai thu vien (flutter pub get)...
call flutter pub get

echo.
echo [3/4] Dang bien dich ban dia hoa song ngu (flutter gen-l10n)...
call flutter gen-l10n

echo.
echo [4/4] Dang bien dich APK (Release mode)...
echo Vui long cho trong giay lat...
call flutter build apk --release %*

if %ERRORLEVEL% equ 0 (
    if not exist "%ROOT_DIR%build_output" mkdir "%ROOT_DIR%build_output"
    if not exist "%ROOT_DIR%zenhome-server\public\downloads" mkdir "%ROOT_DIR%zenhome-server\public\downloads"

    copy /y "build\app\outputs\flutter-apk\app-release.apk" "%ROOT_DIR%ZenHome_Release.apk" > nul
    copy /y "build\app\outputs\flutter-apk\app-release.apk" "%ROOT_DIR%build_output\ZenHome_Release.apk" > nul
    copy /y "build\app\outputs\flutter-apk\app-release.apk" "%ROOT_DIR%zenhome-server\public\downloads\zenhome-app-release.apk" > nul

    echo.
    echo =================================================================
    echo              XUAT BAN APK THANH CONG RUC RO!
    echo =================================================================
    echo 1. File goc:      %ROOT_DIR%ZenHome_Release.apk
    echo 2. Thu muc build: %ROOT_DIR%build_output\ZenHome_Release.apk
    echo 3. Server OTA:    %ROOT_DIR%zenhome-server\public\downloads\zenhome-app-release.apk
    echo Cai dat nhanh qua USB: adb install -r ZenHome_Release.apk
    echo =================================================================
    echo.
    set "DO_PUBLISH=N"
    set /p "DO_PUBLISH=[?] Ban co muon day phien ban moi nay len Cloud de bao update cho App khong? (Y/N) [N]: "
    if /i "!DO_PUBLISH!"=="Y" (
        echo.
        call node "%ROOT_DIR%scripts\push_update.cjs"
    )
) else (
    echo.
    echo [ERROR] Bien dich APK that bai! Vui long xem log loi o tren.
)

pause
