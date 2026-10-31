@echo off
chcp 65001 >NUL
echo ========================================================
echo    DANG XUAT BAN PHAT HANH RELEASE APK v1.8.0+185
echo ========================================================

cd /d "%~dp0..\zenhome_app"

echo [1/3] Kiem tra va bien dich Flutter Release APK...
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Bien dich APK that bai!
    exit /b %ERRORLEVEL%
)

echo.
echo [2/3] Bien dich thanh cong! Tien hanh sao chep va dong bo...
cd /d "%~dp0.."
node "C:/Users/dinht/.gemini/antigravity/brain/386cedf8-a9a5-41c0-b477-877e83e67330/scratch/publish_v1_8_0.cjs"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Dong bo server that bai!
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================================
echo    HOAN TAT XUAT BAN & PHAT HANH ZENHOME v1.8.0!
echo ========================================================
