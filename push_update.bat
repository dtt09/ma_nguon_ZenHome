@echo off
setlocal enabledelayedexpansion

echo =================================================================
echo        [ZENHOME SMART HOME] - PHAT HANH BAN CAP NHAT APP (OTA)
echo =================================================================
echo.

set "ROOT_DIR=%~dp0"
set "NODE_SCRIPT=%ROOT_DIR%scripts\push_update.cjs"

if not exist "%NODE_SCRIPT%" (
    echo [ERROR] Khong tim thay script %NODE_SCRIPT%!
    pause
    exit /b 1
)

:: Kiem tra Node.js
where node >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Node.js chua duoc cai dat hoac chua co trong bien moi truong PATH!
    pause
    exit /b 1
)

node "%NODE_SCRIPT%" %*

pause
