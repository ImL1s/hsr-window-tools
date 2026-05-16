@echo off
chcp 65001 >nul
title HSR 1920x1080
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0HSR-Patch.ps1" -W 1920 -H 1080
set "ec=%errorlevel%"
pwsh -NoProfile -Command "Start-Sleep -Seconds 2"
exit /b %ec%
