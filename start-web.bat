@echo off
chcp 65001 >NUL
title ZenHome Web Admin Dashboard (Port 3000)
echo ========================================================
echo    DANG KHOI CHAY ZENHOME WEB ADMIN DASHBOARD
echo ========================================================
cd /d "%~dp0zenhome-web"
npm run dev
pause
