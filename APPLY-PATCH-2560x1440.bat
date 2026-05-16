@echo off
chcp 65001 >nul
title HSR 2560x1440
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0HSR-Patch.ps1" -W 2560 -H 1440
set "ec=%errorlevel%"
pwsh -NoProfile -Command "Start-Sleep -Seconds 2"
exit /b %ec%
