@echo off
chcp 65001 >nul
title Install WindowPatcher Autostart
echo ==========================================
echo   WindowPatcher 開機自動啟動安裝
echo ==========================================
echo.
echo 安裝後:
echo   - Windows 登入時自動啟動 WindowPatcher tray
echo   - 啟動遊戲後自動修補視窗 + (可選) FPS patch
echo   - 完全 zero-touch (除了第一次需要 UAC 同意)
echo.
echo 移除: 雙擊 Uninstall-Autostart.bat
echo.
pause
schtasks /create /tn "WindowPatcherTray" /tr "pwsh -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%~dp0WindowPatcher\WindowPatcher-WPF.ps1\"" /sc onlogon /rl HIGHEST /f
if errorlevel 1 (
  echo.
  echo [X] 建立排程任務失敗 (可能需要管理員權限)
  echo 請右鍵本檔 -^> 以系統管理員身分執行
  pause
  exit /b 1
)
echo.
echo [OK] 已安裝開機啟動 (排程任務名稱: WindowPatcherTray)
echo.
echo 立即啟動一次?
choice /c YN /n /m "Y/N: "
if errorlevel 2 goto end
schtasks /run /tn "WindowPatcherTray"
echo [OK] 已啟動 tray
:end
echo.
pause
