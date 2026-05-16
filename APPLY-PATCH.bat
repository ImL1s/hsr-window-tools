@echo off
chcp 65001 >nul
REM Double-click: auto-elevate via HSR-Patch.ps1, then add WS_THICKFRAME + WS_MAXIMIZEBOX
title HSR Window Patch
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0HSR-Patch.ps1"
set "ec=%errorlevel%"
pwsh -NoProfile -Command "Start-Sleep -Seconds 2"
exit /b %ec%
