@echo off
title HSR FPS Setup Wizard
echo ===========================================
echo   HSR FPS Setup Wizard
echo ===========================================
echo.
echo 這個工具會自動:
echo   1. 建立基線 registry 快照
echo   2. 等你進 HSR 動 FPS 設定後完整退出
echo   3. 自動 diff + 找 FPS key + 寫 120 FPS patch
echo.
echo 你需要做的:
echo   進 HSR -^> 設定 -^> 畫面 -^> 切換 FPS 30/60 -^> 套用 -^> 完整退出
echo.
pause
echo.
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0FPS-Wizard.ps1" -TargetFPS 120
echo.
pause
