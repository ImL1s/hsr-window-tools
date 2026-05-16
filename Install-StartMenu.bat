@echo off
chcp 65001 >nul
title Install WindowPatcher Start Menu / Desktop
echo ==========================================
echo   WindowPatcher Start Menu / Desktop 安裝
echo ==========================================
echo.
echo 將建立:
echo   - Start Menu 捷徑 (按 Win 鍵搜尋找得到)
echo   - 桌面捷徑
echo   - 嘗試釘選工作列 (Win11 22H2+ 多半被擋,給手動指引)
echo.
echo 捷徑自帶 admin 提權 flag,跟 tray 行為一致
echo 不寫 registry / Program Files,完全在使用者 profile
echo 移除:雙擊 Uninstall-StartMenu.bat
echo.
pause
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-StartMenu.ps1"
if errorlevel 1 (
  echo.
  echo [X] 安裝失敗,看上方錯誤訊息
  pause
  exit /b 1
)
echo.
pause
