# HSR Window Tools / WindowPatcher v6

[繁體中文](#繁體中文) | [English](#english)

---

## English

Windows PowerShell tooling that makes Honkai: Star Rail and similar Unity game windows resizable, maximizable, and compatible with Windows Snap / PowerToys FancyZones.

### What it does

- Detects target game processes and adds `WS_THICKFRAME + WS_MAXIMIZEBOX` to their windows.
- Makes the window draggable by border, maximizable, and Snap/FancyZones-friendly.
- Runs as a WPF tray app, with legacy one-shot patch scripts still available.
- Requires administrator privileges when patching elevated game windows; UAC behavior depends on local policy.

### Quick start

```powershell
# Start tray mode
.\WindowPatcher\WindowPatcher.bat

# CLI smoke checks
pwsh -NoProfile -ExecutionPolicy Bypass -File .\WindowPatcher\WindowPatcher-WPF.ps1 --help
pwsh -NoProfile -ExecutionPolicy Bypass -File .\WindowPatcher\WindowPatcher-WPF.ps1 --status
pwsh -NoProfile -ExecutionPolicy Bypass -File .\WindowPatcher\WindowPatcher-WPF.ps1 --scan-now

# Legacy one-shot patch for StarRail.exe
.\APPLY-PATCH.bat
```

### FPS note

The main supported feature is **window style patching**. HSR Version=10 no longer uses the old single `GraphicsSettings_Model_h*` JSON binary key for graphics settings. Public FPS unlock tools that still write the old key may only create a ghost key that the game does not read.

FPS tooling in this repo is therefore exploratory and disabled for HSR by default (`fpsProfile = "none"`, `fpsTarget = 0`). Use the tray menu **FPS Probe Wizard** or `WindowPatcher\RegProbe.ps1` only if you intentionally want to investigate the current registry schema.

### Key files

| Path | Purpose |
| --- | --- |
| `WindowPatcher/WindowPatcher-WPF.ps1` | Main WPF tray app and CLI entry point |
| `WindowPatcher/WindowPatcher.bat` | Tray launcher |
| `WindowPatcher/reload-admin.ps1` | Restart tray app elevated |
| `HSR-Patch.ps1` | Legacy one-shot StarRail window patcher |
| `APPLY-PATCH*.bat` | Legacy wrapper scripts, optionally resizing the window |
| `HsrWatcher.ps1` | Legacy polling watcher |
| `Install-Watcher.bat` / `Uninstall-Watcher.bat` | Legacy scheduled-task watcher management |
| `WindowPatcher/RegProbe.ps1` | Registry diff helper for FPS key discovery |
| `WindowPatcher/FPS-Wizard.ps1` | CLI FPS probe wizard wrapper |

### Verification snapshot

The project has been smoke-tested against a live StarRail window:

- `--help`, `--list`, `--status`, `--scan-now`, `--apply StarRail`, and `--diagnose` returned successfully.
- Live StarRail window style contained both `THICKFRAME=True` and `MAXIMIZEBOX=True`.
- Temporary resize/restore checks confirmed the patched window can be resized and restored.
- `APPLY-PATCH*.bat` wrappers were tested with automatic restore.
- All tracked PowerShell scripts passed parser checks.

### Risks and limitations

- This tool manipulates another process's window style via Win32 APIs and may require elevation.
- The launchers use `ExecutionPolicy Bypass` for local unsigned scripts; inspect the source and only run copies from this repository.
- Restarting the game window restores the original window style; the patch is not permanent.
- FPS registry changes are a separate risk surface from window style patching and are not enabled by default for HSR.
- The legacy scheduled-task watcher runs from the local script path with highest privileges; install it only from a trusted, non-shared folder.
- Use at your own risk; game publisher policies may change.

### Uninstall

```powershell
# Stop tray process
Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" |
  Where-Object { $_.CommandLine -like '*WindowPatcher-WPF.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# Remove user config/logs
Remove-Item "$env:LOCALAPPDATA\WindowPatcher" -Recurse -Force
```

---

## 繁體中文

這是一組 Windows PowerShell 工具，用來讓《崩壞：星穹鐵道》和類似 Unity 遊戲視窗可以拖曳邊框、最大化，並能被 Windows Snap / PowerToys FancyZones 正常抓取。

### 核心功能

- 偵測目標遊戲 process，為視窗補上 `WS_THICKFRAME + WS_MAXIMIZEBOX`。
- 讓原本鎖死大小的視窗可以拖曳邊框、最大化、Snap、FancyZones。
- 主要介面是 WPF 托盤程式；舊版一次性 patch 腳本仍保留。
- 修補高權限遊戲視窗時需要管理員權限；是否能完全 zero-touch 取決於本機 UAC 政策。

### 快速開始

```powershell
# 啟動托盤模式
.\WindowPatcher\WindowPatcher.bat

# CLI 基本檢查
pwsh -NoProfile -ExecutionPolicy Bypass -File .\WindowPatcher\WindowPatcher-WPF.ps1 --help
pwsh -NoProfile -ExecutionPolicy Bypass -File .\WindowPatcher\WindowPatcher-WPF.ps1 --status
pwsh -NoProfile -ExecutionPolicy Bypass -File .\WindowPatcher\WindowPatcher-WPF.ps1 --scan-now

# 舊版 StarRail.exe 一次性 patch
.\APPLY-PATCH.bat
```

### FPS 說明

本工具的主要可靠功能是 **視窗 style 修補**。HSR Version=10 不再使用舊版單一 `GraphicsSettings_Model_h*` JSON binary key 來保存圖形設定；仍寫舊 key 的公開 FPS unlock 工具可能只是建立遊戲不讀的 ghost key。

因此，本 repo 的 FPS 功能目前定位為探查輔助，且 HSR 預設不啟用 (`fpsProfile = "none"`, `fpsTarget = 0`)。只有當你明確想研究目前 registry schema 時，才建議使用托盤選單的 **FPS 探查精靈** 或 `WindowPatcher\RegProbe.ps1`。

### 主要檔案

| 路徑 | 用途 |
| --- | --- |
| `WindowPatcher/WindowPatcher-WPF.ps1` | 主程式，WPF 托盤 app 與 CLI 入口 |
| `WindowPatcher/WindowPatcher.bat` | 托盤啟動器 |
| `WindowPatcher/reload-admin.ps1` | 重新啟動托盤並提權 |
| `HSR-Patch.ps1` | 舊版 StarRail 一次性視窗修補 |
| `APPLY-PATCH*.bat` | 舊版 wrapper，可選擇 resize |
| `HsrWatcher.ps1` | 舊版 polling watcher |
| `Install-Watcher.bat` / `Uninstall-Watcher.bat` | 舊版排程 watcher 安裝/移除 |
| `WindowPatcher/RegProbe.ps1` | FPS key 探查用 registry diff helper |
| `WindowPatcher/FPS-Wizard.ps1` | CLI 版 FPS 探查精靈 wrapper |

### 實測摘要

已對 live StarRail 視窗做過安全 smoke test：

- `--help`、`--list`、`--status`、`--scan-now`、`--apply StarRail`、`--diagnose` 都能正常返回。
- live StarRail 視窗 style 已包含 `THICKFRAME=True` 與 `MAXIMIZEBOX=True`。
- 實際 resize / restore 測試確認視窗可被調整大小並還原。
- `APPLY-PATCH*.bat` wrapper 已測試，並在測試後自動還原視窗大小。
- 所有已追蹤的 PowerShell 腳本通過 parser check。

### 風險與限制

- 本工具透過 Win32 API 操作其他 process 的視窗 style，可能需要管理員權限。
- 啟動器會使用 `ExecutionPolicy Bypass` 執行本機未簽章腳本；請先檢查來源，只執行本 repo 的可信副本。
- 視窗 style 修補不是永久修改；重啟遊戲視窗後會回到原狀。
- FPS registry 改寫和視窗 style 修補是不同風險面，且 HSR 預設不啟用 FPS patch。
- 舊版排程 watcher 會從本機腳本路徑以最高權限執行；只建議從可信、非共用資料夾安裝。
- 遊戲廠商政策可能改變，請自行承擔使用風險。

### 卸載

```powershell
# 停止托盤 process
Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" |
  Where-Object { $_.CommandLine -like '*WindowPatcher-WPF.ps1*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

# 移除使用者設定與 log
Remove-Item "$env:LOCALAPPDATA\WindowPatcher" -Recurse -Force
```
