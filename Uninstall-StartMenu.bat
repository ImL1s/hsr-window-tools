@echo off
chcp 65001 >nul
title Uninstall WindowPatcher Start Menu
echo 移除 Start Menu + Desktop + Icon ...
echo (tray 還在跑的話,從 tray 右鍵「結束」或工作管理員結束 pwsh)
echo.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-StartMenu.ps1"
echo.
pause
