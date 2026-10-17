@echo off
chcp 65001 >NUL
title ZenHome Full-Stack Unified Server (Port 5000)
echo ========================================================
echo    DANG KHOI CHAY HE THONG THONG NHAT ZENHOME (PORT 5000)
echo    - Web Admin:      http://localhost:5000
echo    - API Docs:       http://localhost:5000/api/docs
echo    - RESTful API:    http://localhost:5000/api/v1
echo ========================================================
cd /d "%~dp0zenhome-server"
npm run dev
pause
