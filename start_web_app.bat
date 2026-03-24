@echo off
setlocal

REM Jump to this BAT's directory (repo root).
cd /d "%~dp0"

if not exist "web_app" (
  echo [ERROR] web_app folder not found.
  pause
  exit /b 1
)

cd /d "web_app"

if not exist "node_modules" (
  echo Installing dependencies...
  call npm.cmd install
  if errorlevel 1 (
    echo [ERROR] npm install failed.
    pause
    exit /b 1
  )
)

echo Starting web app...
call npm.cmd run dev

endlocal
