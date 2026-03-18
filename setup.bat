@echo off
title Shakti General Store - Setup
cd /d "%~dp0"
color 0B

echo.
echo  ================================================
echo    Shakti General Store - First Time Setup
echo  ================================================
echo.

:: ── Check Python ──────────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo  [!] Python is not installed on this computer.
    echo.
    echo  Opening the Python download page in your browser...
    echo.
    echo  IMPORTANT during install:
    echo    - Check the box that says "Add Python to PATH"
    echo    - Then click Install Now
    echo.
    echo  After Python is installed, run this setup again.
    echo.
    start https://www.python.org/downloads/
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('python --version 2^>^&1') do set PY_VER=%%v
echo  [OK] Found %PY_VER%
echo.

:: ── Create virtual environment ────────────────────────
if not exist "venv\Scripts\python.exe" (
    echo  [..] Creating isolated environment...
    python -m venv venv
    if errorlevel 1 (
        echo  [!] Failed to create virtual environment.
        pause
        exit /b 1
    )
    echo  [OK] Environment created.
) else (
    echo  [OK] Environment already exists, skipping.
)
echo.

:: ── Install packages ──────────────────────────────────
echo  [..] Installing required packages...
echo       This may take 1-2 minutes on first run.
echo.
venv\Scripts\pip install -r requirements.txt --quiet --disable-pip-version-check
if errorlevel 1 (
    echo.
    echo  [!] Package installation failed.
    echo      Check your internet connection and try again.
    pause
    exit /b 1
)
echo  [OK] All packages installed.
echo.

:: ── Add shakti.local to hosts file (requires admin) ──
echo  [..] Registering shakti.local (needs admin rights)...
findstr /C:"shakti.local" "%SystemRoot%\System32\drivers\etc\hosts" >nul 2>&1
if errorlevel 1 (
    :: Not yet added — try to add it
    echo 127.0.0.1  shakti.local >> "%SystemRoot%\System32\drivers\etc\hosts" 2>nul
    if errorlevel 1 (
        echo  [!] Could not write to hosts file (run setup.bat as Administrator
        echo      for shakti.local to work in the local browser).
        echo      Mobile devices will still work via zeroconf on the same WiFi.
    ) else (
        echo  [OK] shakti.local registered.
    )
) else (
    echo  [OK] shakti.local already registered.
)
echo.

:: ── Done ──────────────────────────────────────────────
echo  ================================================
echo    Setup complete!
echo.
echo    Next step: Double-click  run.bat  to start.
echo    Then open: http://shakti.local:5000
echo  ================================================
echo.
pause
