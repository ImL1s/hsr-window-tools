@echo off
chcp 65001 >nul
title Uninstall HSR Window Watcher
echo 移除 HSR Window Watcher...
schtasks /end /tn HsrWindowWatcher 2>nul
schtasks /delete /tn HsrWindowWatcher /f
echo.
echo 已移除排程任務 watcher
echo 已執行的 HSR 視窗 style 不會還原 (重啟遊戲就回復)
pause
