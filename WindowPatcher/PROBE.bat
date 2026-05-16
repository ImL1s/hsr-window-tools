@echo off
title HSR Registry Probe
echo ==========================================
echo   HSR Registry Probe - 找新版 FPS key
echo ==========================================
echo.
echo 步驟:
echo   1) 現在按 Enter 建立基線
echo   2) 進 HSR -^> 設定 -^> 畫面 -^> 切換 FPS 30/60 -^> 套用
echo   3) ESC 關設定面板 (不必關遊戲)
echo   4) 再次雙擊本檔案看 diff
echo.
pause
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0RegProbe.ps1"
echo.
pause
