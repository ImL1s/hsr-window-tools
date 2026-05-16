@echo off
chcp 65001 >nul
title Uninstall WindowPatcher Autostart
echo 移除 WindowPatcher 開機自動啟動...
schtasks /end /tn "WindowPatcherTray" 2>nul
schtasks /delete /tn "WindowPatcherTray" /f
if errorlevel 1 (
  echo [!] 排程任務不存在或已移除
) else (
  echo [OK] 已移除排程任務 WindowPatcherTray
)
echo.
echo 目前執行中的 tray 仍存活,可用工作管理員或 tray 右鍵「結束」關閉。
pause
