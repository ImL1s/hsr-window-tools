# HSR Window Tools (WindowPatcher v6)

讓崩壞:星穹鐵道(及其他 Unity 遊戲)的視窗能拖曳邊框、最大化、被 PowerToys FancyZones 與 Windows Snap 識別的自動化工具。

## 核心功能(zero-touch)

- 偵測遊戲啟動 → 自動為視窗注入 `WS_THICKFRAME + WS_MAXIMIZEBOX`
- 視窗立即可:拖曳邊框、最大化、FancyZones snap、Win+方向鍵 Snap Layout
- 需要管理員權限時會自動觸發 UAC 提權；若系統政策允許可達到 zero-touch

## 主要用法

雙擊 **`WindowPatcher\WindowPatcher.bat`** 啟動托盤模式,從此每次啟動 HSR 自動修補。

也可雙擊 **`APPLY-PATCH.bat`** 做單次修補(legacy 模式)。

## FPS 解鎖的現實 (2026-05 誠實修訂)

> 我先前在文檔說「HSR PC 自 1.6 起內建 120 FPS UI」**是錯的**。實際 HSR 圖形設定的 FPS 下拉只有 30/60。

### 為什麼目前對 HSR 沒辦法 zero-touch 解 120 FPS

**HSR Version=10 新 schema 的限制**:
1. 舊 HSR (< Version=10) 把所有圖形設定塞進單一 binary key `GraphicsSettings_Model_h2986158309`(內含 `{"FPS":60,...}` JSON)
2. **新版 HSR (Version=10) 把每個設定拆成獨立 PlayerPrefs key** — `_Model_h*` 完全消失
3. 拆分後的 FPS key 真實名字 **沒有任何公開來源知道**
4. 所有公開工具(HsrGraphicsTool、hyv-fps-unlocker、HonkaiStarRailFPSUnlock 等)還在改舊的 `_Model_h*`,對 Version=10 機器**完全失效**(只是寫進 ghost key,遊戲不讀)

**Unity PlayerPrefs hash 演算法 (DJB2) 已驗證**:`h = (h * 33) ^ char`,對你機器 4/4 已知 key 完美吻合。但這只能算 hash,不能猜 key 名字。

### 真正能做的:用 GUI 內的「FPS 探查精靈」找新 FPS key

**主要方式 (GUI 整合)**:右下角托盤圖示 → 右鍵 → **「FPS 探查精靈 (HSR 找新 schema key)...」**

1. 點下後跳對話框,按「確定」開始建立基線
2. 進 HSR → ESC → 設定 → 畫面 → 切換 FPS (60→30→套用→60→套用)
3. **完整退出 HSR** (按結束遊戲或關閉視窗)
4. 工具自動偵測 HSR 退出 → 自動 diff → 自動找 FPS 候選 → 跳對話框問是否 patch
5. 點 Yes → 寫入 120 FPS,下次啟動 HSR 應該就生效

**進階 CLI 路徑** (給 headless 用):
- `WindowPatcher\RegProbe.ps1` + `WindowPatcher\PROBE.bat` — 手動 baseline + diff
- `WindowPatcher\FPS-Wizard.ps1` + `WindowPatcher\FPS-WIZARD.bat` — 命令列版 wizard

### 工具當前對 HSR 的實際功能
- ✅ **視窗 style 修補** (THICKFRAME + MAXIMIZEBOX):完全 work,核心需求已解
- ⚠️ **FPS 解鎖**:對 Version=10 schema 暫無解。先跑 RegProbe 找 key,或接受現狀
- 預設 `fpsTarget = 0` 不啟用 FPS patch (避免 UI 噪音)

## 自動化機制

工具透過 `Start-Process -Verb RunAs` 提升權限，再用 Win32 `GetWindowLong` / `SetWindowLong` / `SetWindowPos` 對目標視窗補上 style。是否完全 zero-touch 取決於本機 UAC 政策、使用者是否具備管理員權限，以及目標遊戲行程完整性等級。

## 檔案清單

| 檔案 | 用途 |
|------|------|
| `WindowPatcher/WindowPatcher-WPF.ps1` ⭐ | 主程式(WPF 托盤,1300+ 行) |
| `WindowPatcher/WindowPatcher.bat` | 啟動入口 |
| `WindowPatcher/reload-admin.ps1` | 重啟托盤(admin 提權) |
| `APPLY-PATCH.bat` | 單次手動修補 |
| `APPLY-PATCH-1920x1080.bat` | 單次修補 + resize 1920x1080 |
| `APPLY-PATCH-2560x1440.bat` | 單次修補 + resize 2560x1440 |
| `HSR-Patch.ps1` | APPLY-PATCH 的核心 |
| `HsrWatcher.ps1` | 舊版 polling watcher(legacy) |
| `Install-Watcher.bat` / `Uninstall-Watcher.bat` | 舊版排程(legacy) |

## READ-ONLY QA 快照 (2026-05-16)

- 已對 live StarRail 視窗執行安全 CLI smoke tests: `--help`、`--list`、`--status`、`--diagnose` 皆可正常返回。
- `--diagnose` 讀到 live StarRail 視窗 style 已包含 `THICKFRAME=True`、`MAXIMIZEBOX=True`；代表本工具的核心目的（讓 HSR 視窗可 resize / maximize / Snap）在不改遊戲設定的前提下已經成立。
- HSR target 預設仍是 `fpsProfile = "none"`、`fpsTarget = 0`，與上方 Version=10 新 schema 風險描述一致。
- `schtasks /query /tn HsrWindowWatcher` 在本機回傳「找不到指定檔案」；本次 QA **未執行** `Install-Watcher.bat` / `Uninstall-Watcher.bat`，只做靜態審閱。
- `HSR-Patch.ps1`、`HsrWatcher.ps1`、`WindowPatcher-WPF.ps1`、`reload-admin.ps1`、`RegProbe.ps1`、`FPS-Wizard.ps1` 均已用 PowerShell parser 做語法檢查，未發現 parse error。

### 這次 QA 額外觀察到的限制

- `WindowPatcher-WPF.ps1 --status` 目前只排除 `--help|--list|--apply|--scan-now|--patch-foreground|--status` 這些 CLI 參數；若同時有 `--diagnose` / wizard 類 CLI 正在執行，`--status` 可能短暫把它們也算成「托盤行程」。
- `WindowPatcher\WindowPatcher.bat` 與 `WindowPatcher\reload-admin.ps1` 使用相對路徑啟動主程式，repo 搬家後不需改硬編碼路徑。

## 風險與限制

- **視窗 style 修補**(主功能):mhyprot2 截至 2026-05 **未偵測**,10 秒 0 還原已驗證
- **FPS registry 改寫**(次要功能,僅 RegProbe / FPS-Wizard):mhyprot2 對 HKCU registry 寫入的偵測現況**未經獨立驗證**,理論上是不同攻擊面,風險與視窗 style 不可一概而論
- HoYoverse 政策不保證,自負風險,建議副帳號先試
- 移除影響:重啟遊戲視窗即還原,無持久副作用

## Migration 行為(舊 config 自動升級)

啟動托盤時 `Load-Config` 會自動:
- 已知遊戲 processName(原神/絕區零/鳴潮)若 `fpsProfile=none` → 套上正確 Unity profile
- 已是 Unity profile 但 `fpsTarget=0` → 自動填 120
- `scanIntervalSec=5`(舊預設) → 升級為 2(更快響應)

HSR 從 mapping 移除(因 Version=10 新 schema 的 FPS key 尚未確認),保留現有 config 不主動覆寫。

## 卸載

```powershell
# 結束托盤
Stop-Process -Name pwsh | Where-Object { (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like '*WindowPatcher*' }

# 清設定與 log
Remove-Item $env:LOCALAPPDATA\WindowPatcher -Recurse -Force

# 視窗 style 修補:重啟遊戲視窗自動還原,無持久變更
```
