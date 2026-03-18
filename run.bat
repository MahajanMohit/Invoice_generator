@echo off
title Shakti General Store - Invoice Tool
cd /d "%~dp0"
color 0A

:: ── Check setup was done ──────────────────────────────
if not exist "venv\Scripts\python.exe" (
    echo.
    echo  [!] Setup not complete.
    echo      Please double-click setup.bat first.
    echo.
    pause
    exit /b 1
)

:: ── Check credentials ─────────────────────────────────
if not exist "credentials.json" (
    echo.
    echo  [!] WARNING: credentials.json not found.
    echo      Google Sheet sync will be disabled.
    echo      Place credentials.json in this folder to enable it.
    echo.
    timeout /t 3 /nobreak >nul
)

echo.
echo  ================================================
echo    Shakti General Store - Invoice Tool
echo    Starting server, please wait...
echo  ================================================
echo.

venv\Scripts\python app.py

echo.
echo  Server stopped. Close this window or press any key.
pause >nul
