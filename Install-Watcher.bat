@echo off
chcp 65001 >nul
title Install HSR Window Watcher
echo 即將安裝背景監聽器,自動在 HSR 啟動時修補視窗 style
echo 安裝後完全無感,啟動遊戲就自動有 thickframe
echo.
pause
schtasks /create /tn HsrWindowWatcher /tr "pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0HsrWatcher.ps1\"" /sc onlogon /rl HIGHEST /f
if errorlevel 1 (
  echo.
  echo [X] 建立排程任務失敗 - 試試手動以管理員執行本檔
  pause
  exit /b 1
)
echo.
echo [OK] 已建立排程任務 HsrWindowWatcher,下次登入自動啟動
echo 立即啟動 watcher...
schtasks /run /tn HsrWindowWatcher
echo.
echo Log: %%LOCALAPPDATA%%\HsrWatcher.log
echo 解除安裝:雙擊 Uninstall-Watcher.bat
pause
