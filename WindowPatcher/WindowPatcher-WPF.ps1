# WindowPatcher v6 - Win11 Fluent UI, 視窗 style 修補 + optional Unity FPS tweak
# PowerShell + WPF + WinForms NotifyIcon

$ErrorActionPreference = 'Stop'

# 共用常數 (CLI + GUI + Wizard 共用)
# FPS_FIELD_NAMES = single source of truth (read-side regex + write-side foreach 都從這個 derive)
# FPS_PATTERN = strict regex (JSON field 帶引號) — 避免誤匹配 substring,HSR registry binary 一定是 JSON
$script:FPS_FIELD_NAMES = @('FPS','fps','TargetFrameRate','MaxFPS','FrameRate')
$script:FPS_PATTERN = ($script:FPS_FIELD_NAMES | ForEach-Object { '"' + $_ + '"' }) -join '|'
$script:COMMON_FPS_VALUES = @(30, 60, 120, 144)

# === CLI 模式 (在自動提權之前處理, 不需 admin) ===
if ($args.Count -gt 0) {
  $cmd = $args[0]
  # 載入核心邏輯需要的 type
  Add-Type -Name Win32Cli -Namespace WCli -MemberDefinition @"
    [DllImport("user32.dll")] public static extern int GetWindowLong(System.IntPtr h, int i);
    [DllImport("user32.dll")] public static extern int SetWindowLong(System.IntPtr h, int i, int v);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(System.IntPtr h, System.IntPtr h2, int x, int y, int w, int ht, uint f);
    [DllImport("user32.dll")] public static extern bool IsWindow(System.IntPtr h);
    [DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(System.IntPtr h, out int pid);
"@ -ErrorAction SilentlyContinue

  switch ($cmd) {
    '--help' {
      Write-Host "WindowPatcher CLI 用法:"
      Write-Host "  WindowPatcher-WPF.ps1                       無參數: 啟動托盤模式"
      Write-Host "  WindowPatcher-WPF.ps1 --list                列出 config 中所有目標"
      Write-Host "  WindowPatcher-WPF.ps1 --apply <name>        對指定目標立即修補 (依 config)"
      Write-Host "  WindowPatcher-WPF.ps1 --scan-now            掃描全部啟用目標立即修補"
      Write-Host "  WindowPatcher-WPF.ps1 --patch-foreground    修補當前最前面視窗 (補 THICKFRAME+MAXIMIZEBOX)"
      Write-Host "  WindowPatcher-WPF.ps1 --status              顯示工具狀態"
      Write-Host "  WindowPatcher-WPF.ps1 --diagnose            印 HSR 視窗 + FPS 狀態診斷"
      Write-Host "  WindowPatcher-WPF.ps1 --wizard-baseline [registry-path]"
      Write-Host "                                              建 FPS 探查基線(輸出到 LOCALAPPDATA;預設 HSR registry)"
      Write-Host "  WindowPatcher-WPF.ps1 --wizard-diff [registry-path] [fps]"
      Write-Host "                                              比對基線 vs 當前,自動 patch FPS (預設 120)"
      Write-Host "  WindowPatcher-WPF.ps1 --help                顯示本說明"
      Write-Host ""
      Write-Host "範例 (放在 Steam launch options):"
      Write-Host '  pwsh -File "C:\path\WindowPatcher-WPF.ps1" --apply StarRail; %command%'
      exit 0
    }
    '--list' {
      $cp = "$env:LOCALAPPDATA\WindowPatcher\config.json"
      if (Test-Path $cp) {
        $r = Get-Content $cp -Raw | ConvertFrom-Json
        Write-Host "已設定目標:"
        $r.targets | ForEach-Object { Write-Host ("  - {0,-30} process={1,-18} {2}" -f $_.name, $_.processName, $(if($_.enabled){'enabled'}else{'disabled'})) }
      } else { Write-Host "尚未設定任何目標 (config.json 不存在)" }
      exit 0
    }
    '--status' {
      $cp = "$env:LOCALAPPDATA\WindowPatcher\config.json"
      $lp = "$env:LOCALAPPDATA\WindowPatcher\patcher.log"
      Write-Host "Config: $(if(Test-Path $cp){'存在'}else{'未建立'})"
      Write-Host "Log:    $(if(Test-Path $lp){"$((Get-Item $lp).Length) bytes"}else{'無'})"
      $cliArgPattern = '--(help|list|apply|scan-now|patch-foreground|status|diagnose|wizard-baseline|wizard-diff)\b'
      $mtx = @(Get-CimInstance Win32_Process -Filter "Name = 'pwsh.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and
        $_.CommandLine -like '*WindowPatcher-WPF.ps1*' -and
        $_.CommandLine -notmatch $cliArgPattern
      })
      Write-Host "托盤行程: $(if($mtx.Count -gt 0){"執行中 (PID $($mtx.ProcessId -join ','))"} else {'未執行'})"
      if ($mtx.Count -gt 0) {
        $mtx | ForEach-Object {
          Write-Host "  - $($_.CommandLine)"
        }
      }
      exit 0
    }
    '--patch-foreground' {
      $hwnd = [WCli.Win32Cli]::GetForegroundWindow()
      if ($hwnd -eq [IntPtr]::Zero) { Write-Host "找不到前景視窗"; exit 1 }
      $cur = [WCli.Win32Cli]::GetWindowLong($hwnd, -16)
      $new = $cur -bor 0x40000 -bor 0x10000
      if ($cur -eq $new) { Write-Host "視窗已有 THICKFRAME+MAXIMIZEBOX, 不需修補"; exit 0 }
      [WCli.Win32Cli]::SetWindowLong($hwnd, -16, $new) | Out-Null
      [WCli.Win32Cli]::SetWindowPos($hwnd, [IntPtr]::Zero, 0,0,0,0, 0x27) | Out-Null
      $after = [WCli.Win32Cli]::GetWindowLong($hwnd, -16)
      if (($after -band 0x40000) -ne 0) { Write-Host ("修補成功: 0x{0:X8} -> 0x{1:X8}" -f $cur, $after); exit 0 }
      else { Write-Host "修補失敗 (可能權限不足, 請以管理員執行)"; exit 1 }
    }
    { $_ -in @('--apply','--scan-now') } {
      $cp = "$env:LOCALAPPDATA\WindowPatcher\config.json"
      if (-not (Test-Path $cp)) { Write-Host "config.json 不存在,請先啟動托盤模式建立目標"; exit 1 }
      $cfg = Get-Content $cp -Raw | ConvertFrom-Json
      $filter = if ($cmd -eq '--apply') { $args[1] } else { $null }
      if ($cmd -eq '--apply' -and -not $filter) { Write-Host "用法: --apply <process-name 或 顯示名稱>"; exit 1 }
      $n = 0
      $failed = 0
      foreach ($t in $cfg.targets) {
        if (-not $t.enabled) { continue }
        if ($filter -and $t.processName -notlike "*$filter*" -and $t.name -notlike "*$filter*") { continue }
        foreach ($p in (Get-Process -Name $t.processName -ErrorAction SilentlyContinue)) {
          $h = $p.MainWindowHandle
          if ($h -eq [IntPtr]::Zero) { continue }
          $cur = [WCli.Win32Cli]::GetWindowLong($h, -16)
          $addMask = 0; foreach($s in $t.addStyles){ switch($s){ 'WS_THICKFRAME'{$addMask=$addMask -bor 0x40000} 'WS_MAXIMIZEBOX'{$addMask=$addMask -bor 0x10000} 'WS_MINIMIZEBOX'{$addMask=$addMask -bor 0x20000} 'WS_CAPTION'{$addMask=$addMask -bor 0xC00000} 'WS_SYSMENU'{$addMask=$addMask -bor 0x80000} 'WS_BORDER'{$addMask=$addMask -bor 0x800000} } }
          $removeMask = 0; foreach($s in $t.removeStyles){ switch($s){ 'WS_THICKFRAME'{$removeMask=$removeMask -bor 0x40000} 'WS_MAXIMIZEBOX'{$removeMask=$removeMask -bor 0x10000} 'WS_MINIMIZEBOX'{$removeMask=$removeMask -bor 0x20000} 'WS_CAPTION'{$removeMask=$removeMask -bor 0xC00000} 'WS_SYSMENU'{$removeMask=$removeMask -bor 0x80000} 'WS_BORDER'{$removeMask=$removeMask -bor 0x800000} 'WS_POPUP'{$removeMask=$removeMask -bor -2147483648} } }
          $new = ($cur -bor $addMask) -band (-bnot $removeMask)
          if ($cur -ne $new) {
            [WCli.Win32Cli]::SetWindowLong($h, -16, $new) | Out-Null
            [WCli.Win32Cli]::SetWindowPos($h, [IntPtr]::Zero, 0,0,0,0, 0x27) | Out-Null
            $after = [WCli.Win32Cli]::GetWindowLong($h, -16)
            $hasAdds = (($after -band $addMask) -eq $addMask)
            $removed = (($after -band $removeMask) -eq 0)
            if ($hasAdds -and $removed) {
              $n++
              Write-Host ("修補 $($t.name) PID=$($p.Id) 0x{0:X8} -> 0x{1:X8}" -f $cur, $after)
            } else {
              $failed++
              Write-Host ("修補失敗 $($t.name) PID=$($p.Id) 0x{0:X8} -> 0x{1:X8} (可能權限不足)" -f $cur, $after)
            }
          }
        }
      }
      Write-Host "完成: 修補了 $n 個視窗, 失敗 $failed 個"
      exit $(if($failed -gt 0){1}else{0})
    }
    '--diagnose' {
      Write-Host "=== WindowPatcher Diagnose ==="
      $h = Get-Process StarRail -ErrorAction SilentlyContinue
      if (-not $h) { Write-Host "StarRail: 未在執行"; exit 0 }
      foreach ($p in $h) {
        Write-Host "StarRail PID $($p.Id)"
        if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
          $s = [WCli.Win32Cli]::GetWindowLong($p.MainWindowHandle, -16)
          Write-Host ("  Style       : 0x{0:X8}" -f $s)
          Write-Host ("  THICKFRAME  : {0}" -f (($s -band 0x40000) -ne 0))
          Write-Host ("  MAXIMIZEBOX : {0}" -f (($s -band 0x10000) -ne 0))
        }
      }
      $base = 'HKCU:\Software\Cognosphere\Star Rail'
      if (Test-Path $base) {
        $props = (Get-Item $base).Property | Where-Object { $_ -like 'GraphicsSettings_*' -or $_ -like 'Screenmanager*' }
        Write-Host "HSR Graphics keys ($($props.Count)):"
        foreach ($p in $props) { Write-Host "  - $p" }
      }
      exit 0
    }
    '--wizard-baseline' {
      $regPath = if ($args[1]) { $args[1] } else { 'HKCU:\Software\Cognosphere\Star Rail' }
      if (-not (Test-Path $regPath)) { Write-Host "Path 不存在: $regPath"; exit 1 }
      $snap = @{}
      foreach ($name in (Get-Item $regPath).Property) {
        try {
          $v = (Get-ItemProperty $regPath -Name $name).$name
          if ($v -is [byte[]]) {
            $snap[$name] = @{ type='binary'; length=$v.Length; text=[System.Text.Encoding]::UTF8.GetString($v).TrimEnd([char]0); bytes_hex=($v | ForEach-Object {'{0:X2}' -f $_}) -join '' }
          } else { $snap[$name] = @{ type=$v.GetType().Name; value="$v" } }
        } catch {}
      }
      $bd = "$env:LOCALAPPDATA\WindowPatcher"
      [System.IO.Directory]::CreateDirectory($bd) | Out-Null
      $bf = Join-Path $bd 'wizard-baseline.json'
      $snap | ConvertTo-Json -Depth 6 | Set-Content $bf -Encoding UTF8
      Write-Host "✓ 基線已建立: $($snap.Count) keys"
      Write-Host "  路徑: $bf"
      Write-Host "  Registry: $regPath"
      Write-Host ""
      Write-Host "下一步: 進 HSR 動 FPS 設定 → ESC 關設定面板 → 跑 --wizard-diff (不必關遊戲)"
      exit 0
    }
    '--wizard-diff' {
      $regPath = if ($args[1]) { $args[1] } else { 'HKCU:\Software\Cognosphere\Star Rail' }
      $targetFps = if ($args[2]) { [int]$args[2] } else { 120 }
      $bf = "$env:LOCALAPPDATA\WindowPatcher\wizard-baseline.json"
      if (-not (Test-Path $bf)) { Write-Host "✗ 沒有基線檔,先跑 --wizard-baseline"; exit 1 }
      $baseline = Get-Content $bf -Raw | ConvertFrom-Json -AsHashtable
      $current = @{}
      foreach ($name in (Get-Item $regPath).Property) {
        try {
          $v = (Get-ItemProperty $regPath -Name $name).$name
          if ($v -is [byte[]]) {
            $current[$name] = @{ type='binary'; length=$v.Length; text=[System.Text.Encoding]::UTF8.GetString($v).TrimEnd([char]0); bytes_hex=($v | ForEach-Object {'{0:X2}' -f $_}) -join '' }
          } else { $current[$name] = @{ type=$v.GetType().Name; value="$v" } }
        } catch {}
      }
      $added = @(); $changed = @()
      foreach ($k in $current.Keys) {
        if (-not $baseline.ContainsKey($k)) { $added += $k }
        elseif ($current[$k].type -eq 'binary' -and $current[$k].bytes_hex -ne $baseline[$k].bytes_hex) {
          $changed += @{key=$k;before=$baseline[$k];after=$current[$k]}
        } elseif ($current[$k].type -ne 'binary' -and $current[$k].value -ne $baseline[$k].value) {
          $changed += @{key=$k;before=$baseline[$k];after=$current[$k]}
        }
      }
      Write-Host "新增 $($added.Count) key, 變更 $($changed.Count) key"
      Write-Host ""
      if ($added.Count -eq 0 -and $changed.Count -eq 0) { Write-Host "無差異 (等 2-3 秒讓 HSR flush registry 後再試)"; exit 0 }
      $cands = @()
      foreach ($k in $added) {
        $info = $current[$k]
        if ($info.type -eq 'binary' -and $info.text -match $script:FPS_PATTERN) {
          $cands += @{key=$k;isBinary=$true}
        } elseif (($info.type -in @('Int32','UInt32')) -and ([int]$info.value -in $script:COMMON_FPS_VALUES)) {
          $cands += @{key=$k;isBinary=$false}
        }
      }
      foreach ($c in $changed) {
        $info = $current[$c.key]
        if ($info.type -eq 'binary' -and $info.text -match $script:FPS_PATTERN) {
          $cands += @{key=$c.key;isBinary=$true}
        } elseif (($info.type -in @('Int32','UInt32')) -and ([int]$info.value -in $script:COMMON_FPS_VALUES) -and ([int]$c.before.value -in $script:COMMON_FPS_VALUES)) {
          $cands += @{key=$c.key;isBinary=$false}
        }
      }
      if ($cands.Count -eq 0) {
        Write-Host "沒找到 FPS 候選欄位。Diff 列出:"
        foreach ($k in $added) { Write-Host "  + $k"; if ($current[$k].type -eq 'binary') { Write-Host ("      $($current[$k].text)" -replace "`r|`n", ' ') } else { Write-Host "      $($current[$k].value)" } }
        foreach ($c in $changed) { Write-Host "  ~ $($c.key)" }
        exit 0
      }
      Write-Host "找到 $($cands.Count) 個 FPS 候選:"
      foreach ($c in $cands) { Write-Host "  $($c.key)" }
      Write-Host ""
      Write-Host "套用 $targetFps FPS..."
      $patched = 0
      foreach ($c in $cands) {
        try {
          if ($c.isBinary) {
            $bytes = (Get-ItemProperty $regPath -Name $c.key).$($c.key)
            $text = [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
            $newText = $text
            foreach ($f in $script:FPS_FIELD_NAMES) {
              $pat = '"' + $f + '"\s*:\s*\d+'
              $rep = '"' + $f + '":' + $targetFps
              $newText = [regex]::Replace($newText, $pat, $rep)
            }
            $newBytes = [System.Text.Encoding]::UTF8.GetBytes($newText)
            # Registry binary 支援可變長度 (HSR FPS 60→120 會多 1 byte,直接寫)
            if ($newBytes.Length -lt $bytes.Length) {
              while ($newBytes.Length -lt $bytes.Length) { $newBytes += [byte]0 }
            }
            $bk = "$env:LOCALAPPDATA\WindowPatcher\wizard-backup-$($c.key).bin"
            if (-not (Test-Path $bk)) { [System.IO.File]::WriteAllBytes($bk, $bytes) }
            Set-ItemProperty -Path $regPath -Name $c.key -Value $newBytes -Type Binary
            Write-Host ("  ✓ binary $($c.key) ($($bytes.Length) -> $($newBytes.Length) bytes)")
            $patched++
          } else {
            Set-ItemProperty -Path $regPath -Name $c.key -Value $targetFps -Type DWord
            Write-Host "  ✓ DWORD $($c.key)"
            $patched++
          }
        } catch { Write-Host "  ✗ $($c.key): $_" }
      }
      Write-Host ""
      Write-Host "完成 — patched $patched / $($cands.Count) 個 key"
      exit $(if($patched -eq 0){1}else{0})
    }
    default {
      Write-Host "未知參數: $cmd  (用 --help 看用法)"
      exit 1
    }
  }
}

[System.Threading.Thread]::CurrentThread.SetApartmentState([System.Threading.ApartmentState]::STA) 2>$null

# 先提權再拿 mutex，避免非管理員 parent 尚未退出時 elevated child 誤判已啟動
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  try {
    Start-Process pwsh -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$PSCommandPath -Verb RunAs -ErrorAction Stop
  } catch [System.ComponentModel.Win32Exception] {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("需要管理員權限才能修補遊戲視窗。`n`n你剛剛在 UAC 對話框按了「否」。`n`n請重新雙擊圖示，並在 UAC 詢問時點「是」。", "需要管理員權限", 'OK', 'Warning') | Out-Null
  } catch {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("啟動失敗:`n$($_.Exception.Message)", "錯誤", 'OK', 'Error') | Out-Null
  }
  exit
}

# Mutex 防止重複啟動
$script:Mutex = New-Object System.Threading.Mutex($false, 'Global\WindowPatcher')
if (-not $script:Mutex.WaitOne(0, $false)) {
  Add-Type -AssemblyName System.Windows.Forms
  [System.Windows.Forms.MessageBox]::Show("視窗修補器已經在執行中。`n`n請從右下角托盤圖示開啟設定。", "已啟動", 'OK', 'Information') | Out-Null
  exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -Name CW -Namespace H -MemberDefinition @"
  [DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
  [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int n);
  [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(System.IntPtr h, int a, ref int v, int s);
  [DllImport("user32.dll")] public static extern bool DestroyIcon(System.IntPtr h);
"@
$cw = [H.CW]::GetConsoleWindow()
if ($cw -ne [IntPtr]::Zero) { [H.CW]::ShowWindow($cw, 0) | Out-Null }

Add-Type -Name Win32 -Namespace WP -MemberDefinition @"
  [DllImport("user32.dll", SetLastError=true)] public static extern int GetWindowLong(System.IntPtr h, int i);
  [DllImport("user32.dll", SetLastError=true)] public static extern int SetWindowLong(System.IntPtr h, int i, int v);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool SetWindowPos(System.IntPtr h, System.IntPtr h2, int x, int y, int w, int ht, uint f);
  [DllImport("user32.dll")] public static extern bool IsWindow(System.IntPtr h);
"@

# === Style 定義 (含描述) ===
$script:STYLES = [ordered]@{
  WS_THICKFRAME  = @{ Bit = 0x40000;       Short = 'THICKFRAME';  Desc = '可拖曳邊框 — 讓視窗能用滑鼠調整大小' }
  WS_MAXIMIZEBOX = @{ Bit = 0x10000;       Short = 'MAXIMIZEBOX'; Desc = '最大化按鈕 — 標題列右上角的方框' }
  WS_MINIMIZEBOX = @{ Bit = 0x20000;       Short = 'MINIMIZEBOX'; Desc = '最小化按鈕 — 標題列右上角的 _' }
  WS_CAPTION     = @{ Bit = 0xC00000;      Short = 'CAPTION';     Desc = '標題列 — 顯示視窗標題的橫條' }
  WS_SYSMENU     = @{ Bit = 0x80000;       Short = 'SYSMENU';     Desc = '系統選單 — 標題列右上的 X 與 alt+space 選單' }
  WS_BORDER      = @{ Bit = 0x800000;      Short = 'BORDER';      Desc = '細邊框 — 細的、不可拖曳的邊框' }
  WS_POPUP       = @{ Bit = -2147483648;   Short = 'POPUP';       Desc = '彈出視窗 — 無標題列、無邊框的 popup 模式' }
}

# === FPS Profile (常見 Unity 遊戲 registry path 與 binary key pattern) ===
# 2026-05 真實 HSR 測試確認: HSR 仍用 GraphicsSettings_Model_h2986158309 (DJB2 hash 驗證 5/5 命中)
# 必要前提: 使用者進過遊戲設定 → 套用任意設定 → ESC 離開時 HSR 才寫 registry
# 寫入後 wizard auto-patch 到目標 FPS 已實測 work
$script:FPS_PROFILES = [ordered]@{
  'none' = @{ Name = '不調整 FPS'; Method = 'none' }
  'unity_cognosphere_starrail' = @{
    Name = '崩壞星穹鐵道 (Cognosphere)'
    Method = 'unity_registry_binary'
    RegPath = 'HKCU:\Software\Cognosphere\Star Rail'
    KeyPattern = 'GraphicsSettings_Model_h*'
  }
  'unity_cognosphere_genshin' = @{
    Name = '原神 (Cognosphere - 國際版)'
    Method = 'unity_registry_binary'
    RegPath = 'HKCU:\Software\Cognosphere\Genshin Impact'
    KeyPattern = 'GraphicsSettings_Model_h*'
  }
  'unity_miHoYo_genshin' = @{
    Name = '原神 (miHoYo - 國服)'
    Method = 'unity_registry_binary'
    RegPath = 'HKCU:\Software\miHoYo\原神'
    KeyPattern = 'GraphicsSettings_Model_h*'
  }
  'unity_miHoYo_zzz' = @{
    Name = '絕區零 (miHoYo)'
    Method = 'unity_registry_binary'
    RegPath = 'HKCU:\Software\miHoYo\絕區零'
    KeyPattern = 'GraphicsSettings_Model_h*'
  }
  'unity_kuro_wuwa' = @{
    Name = '鳴潮 (Kuro)'
    Method = 'unity_registry_binary'
    RegPath = 'HKCU:\Software\Kuro Game\Wuthering Waves'
    KeyPattern = '*Frame*'
  }
  'custom_unity_registry' = @{
    Name = '自訂 Unity 登錄檔'
    Method = 'unity_registry_binary'
    RegPath = ''
    KeyPattern = '*Model_h*'
  }
}

$script:ConfigDir = "$env:LOCALAPPDATA\WindowPatcher"
$script:ConfigPath = "$script:ConfigDir\config.json"
$script:LogPath = "$script:ConfigDir\patcher.log"
[System.IO.Directory]::CreateDirectory($script:ConfigDir) | Out-Null

function Log { param([string]$M, [string]$L='INFO'); Add-Content $script:LogPath ("$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  [$L]  $M") -EA SilentlyContinue }

function Clamp-ScanInterval {
  param($Value)
  try { $n = [int]$Value } catch { $n = 2 }
  if ($n -lt 1) { return 1 }
  if ($n -gt 60) { return 60 }
  return $n
}

function Get-DefaultConfig {
  # 2026-05 真實測試: HSR 仍用 GraphicsSettings_Model_h2986158309
  # 預設不啟用 FPS 解鎖 (避免 UI 噪音"鍵尚未生成"); 主功能是視窗 style 修補
  # 想啟用 FPS patch 進 edit target -> 設 fpsTarget=120 + 選 unity_cognosphere_starrail profile
  @{
    targets = @(
      @{
        name = '崩壞星穹鐵道'
        processName = 'StarRail'
        enabled = $true
        addStyles = @('WS_THICKFRAME','WS_MAXIMIZEBOX')
        removeStyles = @()
        fpsProfile = 'none'
        fpsTarget = 0
        fpsRegPath = ''
        fpsKeyPattern = ''
      }
    )
    scanIntervalSec = 2
    showNotifications = $true
  }
}

function Load-Config {
  if (Test-Path $script:ConfigPath) {
    try {
      $raw = Get-Content $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
      # 已知 processName -> profile 對應(Migration 用)
      # 註: HSR 從 mapping 移除是預設策略 (避免初次使用者看到「鍵尚未生成」噪音);
      #     2026-05 真實測試確認 HSR 仍用 GraphicsSettings_Model_h2986158309,
      #     使用者進設定動一次後 wizard 即可 patch FPS。
      #     原神/絕區零等其他遊戲類似機制,故保留 mapping
      $autoProfileMap = @{
        'GenshinImpact'         = 'unity_cognosphere_genshin'
        'YuanShen'              = 'unity_miHoYo_genshin'
        'ZenlessZoneZero'       = 'unity_miHoYo_zzz'
        'Client-Win64-Shipping' = 'unity_kuro_wuwa'  # 鳴潮
      }
      $cfg = @{
        targets = @()
        scanIntervalSec = Clamp-ScanInterval $(if($null -ne $raw.scanIntervalSec -and $raw.scanIntervalSec -ne 5){$raw.scanIntervalSec}else{2})
        showNotifications = $(if($null -ne $raw.showNotifications){[bool]$raw.showNotifications}else{$true})
      }
      $migrated = $false
      foreach ($t in $raw.targets) {
        $fps = [int]($t.fpsTarget)
        $prof = $(if($t.fpsProfile){[string]$t.fpsProfile}else{'none'})
        # Zero-touch migration A: 已知 processName + profile=none → 套上正確 profile
        if ($prof -eq 'none' -and $autoProfileMap.ContainsKey([string]$t.processName)) {
          $prof = $autoProfileMap[[string]$t.processName]
          $migrated = $true
        }
        # Zero-touch migration B: 已是 Unity profile 但 fpsTarget=0 → 填 120
        if ($fps -eq 0 -and $prof -ne 'none' -and $script:FPS_PROFILES.Contains($prof) -and $script:FPS_PROFILES[$prof].Method -eq 'unity_registry_binary') {
          $fps = 120
          $migrated = $true
        }
        $cfg.targets += @{
          name = [string]$t.name
          processName = [string]$t.processName
          enabled = [bool]$t.enabled
          addStyles = @($t.addStyles)
          removeStyles = @($t.removeStyles)
          fpsProfile = $prof
          fpsTarget = $fps
          fpsRegPath = [string]$t.fpsRegPath
          fpsKeyPattern = [string]$t.fpsKeyPattern
        }
      }
      if ($migrated) { Log "Auto-migrated config: 套上正確 fpsProfile + fpsTarget=120 給已知遊戲" }
      return $cfg
    } catch {
      Log "Load failed: $_" 'ERROR'
      try {
        $backup = "$script:ConfigPath.broken-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $script:ConfigPath -Destination $backup -Force -ErrorAction Stop
        Log "Backed up broken config to $backup" 'WARN'
      } catch { Log "Broken config backup failed: $_" 'WARN' }
    }
  }
  $d = Get-DefaultConfig; Save-Config $d; return $d
}
function Save-Config {
  # Atomic write: 先寫 .tmp 再 rename (避免 reader 讀到截斷 JSON 觸發 Load-Config catch + backup-broken)
  param($c)
  $tmp = "$script:ConfigPath.tmp"
  try {
    $c | ConvertTo-Json -Depth 5 | Set-Content $tmp -Encoding UTF8
    Move-Item $tmp $script:ConfigPath -Force
    Log "Saved ($($c.targets.Count) targets)"
  } catch {
    Log "Save-Config failed: $_" 'ERROR'
    if (Test-Path $tmp) { Remove-Item $tmp -Force -EA SilentlyContinue }
    throw
  }
}
$script:Config = Load-Config
$script:PatchedHandles = @{}
$script:FpsPatchedKeys = @{}

# === Style patch ===
function Mask-Of {
  param($names)
  $m = 0
  foreach ($n in $names) { if ($script:STYLES.Contains($n)) { $m = $m -bor $script:STYLES[$n].Bit } }
  $m
}
function Patch-Process {
  param($Proc, $Target)
  try {
    $h = $Proc.MainWindowHandle
    if ($h -eq [IntPtr]::Zero -or -not [WP.Win32]::IsWindow($h)) { return $false }
    $cur = [WP.Win32]::GetWindowLong($h, -16)
    $new = ($cur -bor (Mask-Of $Target.addStyles)) -band (-bnot (Mask-Of $Target.removeStyles))
    if ($cur -eq $new) { return $false }
    [WP.Win32]::SetWindowLong($h, -16, $new) | Out-Null
    [WP.Win32]::SetWindowPos($h, [IntPtr]::Zero, 0,0,0,0, 0x27) | Out-Null
    $after = [WP.Win32]::GetWindowLong($h, -16)
    if ($after -eq $new) {
      $script:PatchedHandles[[int64]$h] = Get-Date
      Log "Patched '$($Target.name)' PID=$($Proc.Id) 0x$('{0:X8}' -f $cur)->0x$('{0:X8}' -f $after)"
      Add-Activity "視窗已修補 — $($Target.name) (現可拖曳邊框)"
      return $true
    }
  } catch { Log "Patch err: $_" 'ERROR' }
  return $false
}

# === FPS patch (Unity registry binary) ===
function Patch-FPS {
  param($Target)
  if ($Target.fpsTarget -le 0) { return $false }
  $profile = $script:FPS_PROFILES[$Target.fpsProfile]
  if (-not $profile -or $profile.Method -ne 'unity_registry_binary') { return $false }

  $regPath = if ($Target.fpsRegPath) { $Target.fpsRegPath } else { $profile.RegPath }
  $keyPattern = if ($Target.fpsKeyPattern) { $Target.fpsKeyPattern } else { $profile.KeyPattern }
  if (-not $regPath -or -not (Test-Path $regPath)) { return $false }

  $cacheKey = "$($Target.processName)|$regPath|$($Target.fpsTarget)"
  if ($script:FpsPatchedKeys.ContainsKey($cacheKey)) {
    $age = ((Get-Date) - $script:FpsPatchedKeys[$cacheKey]).TotalMinutes
    if ($age -lt 5) { return $false }
  }

  $item = Get-Item $regPath -ErrorAction SilentlyContinue
  if (-not $item) { return $false }
  $matched = $item.Property | Where-Object { $_ -like $keyPattern }
  if (-not $matched) {
    # 節流: 每個 target 每 5 分鐘最多 log+notify 一次「等鍵」(避免每 2s 洗版)
    if (-not $script:FpsPendingNotified) { $script:FpsPendingNotified = @{} }
    $pendKey = "$($Target.processName)|$regPath"
    $now = Get-Date
    $last = $script:FpsPendingNotified[$pendKey]
    if (-not $last -or ($now - $last).TotalMinutes -ge 5) {
      $script:FpsPendingNotified[$pendKey] = $now
      Log "FPS: no key match $keyPattern in $regPath (節流 5min)" 'WARN'
      Add-Activity "FPS 等待中 — $($Target.name): 進遊戲設定 → 圖形 → 任意動一個選項按儲存,鍵生成後自動解鎖"
    }
    return $false
  }

  $any = $false
  foreach ($key in $matched) {
    $bytes = (Get-ItemProperty $regPath -Name $key).$key
    if ($bytes -isnot [byte[]]) { continue }
    $text = [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
    if ($text -match '"FPS"\s*:\s*(\d+)') {
      $oldFps = [int]$matches[1]
      if ($oldFps -eq $Target.fpsTarget) {
        $script:FpsPatchedKeys[$cacheKey] = Get-Date
        return $false
      }
      # 保留原始空白 (使用 capture group)
      $newText = $text -replace '("FPS"\s*:\s*)\d+', "`${1}$($Target.fpsTarget)"
      $newBytes = [System.Text.Encoding]::UTF8.GetBytes($newText)
      # Registry binary 支援可變長度,直接寫即可 (FPS 60→120 會多 1 byte)
      # 備份原 binary 至 config dir (一次性)
      $backupFile = Join-Path $script:ConfigDir "backup-$($Target.processName)-$key.bin"
      if (-not (Test-Path $backupFile)) {
        [System.IO.File]::WriteAllBytes($backupFile, $bytes)
        Log "Backed up original $key to $backupFile"
      }
      # 補 trailing null bytes 維持原長度
      while ($newBytes.Length -lt $bytes.Length) { $newBytes += [byte]0 }
      Set-ItemProperty -Path $regPath -Name $key -Value $newBytes -Type Binary
      Log "FPS patched '$($Target.name)' ${key}: $oldFps -> $($Target.fpsTarget)"
      Add-Activity "FPS 已解鎖 — $($Target.name) $oldFps → $($Target.fpsTarget)"
      # 即時 toast 通知 (使用者立即知道生效)
      if ($script:Tray -and $script:Config.showNotifications) {
        try { $script:Tray.ShowBalloonTip(3000, "FPS 已解鎖", "$($Target.name): $oldFps → $($Target.fpsTarget) FPS", 'Info') } catch {}
      }
      $script:FpsPatchedKeys[$cacheKey] = Get-Date
      $any = $true
    }
  }
  return $any
}

# Window rect 讀取(診斷用)
Add-Type -Name Win32R -Namespace WP -MemberDefinition @"
  [DllImport("user32.dll")] public static extern bool GetWindowRect(System.IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
"@

# === FPS Wizard (GUI 內整合,不需獨立 .bat) ===
function Snapshot-Reg {
  param([string]$P)
  $snap = @{}
  if (-not (Test-Path $P)) { return $snap }
  foreach ($name in (Get-Item $P).Property) {
    try {
      $v = (Get-ItemProperty $P -Name $name).$name
      if ($v -is [byte[]]) {
        $snap[$name] = @{
          type = 'binary'; length = $v.Length
          text = [System.Text.Encoding]::UTF8.GetString($v).TrimEnd([char]0)
          bytes_hex = ($v | ForEach-Object { '{0:X2}' -f $_ }) -join ''
        }
      } else {
        $snap[$name] = @{ type = $v.GetType().Name; value = "$v" }
      }
    } catch {}
  }
  return $snap
}

function Apply-FpsCandidates {
  param($Candidates, [int]$TargetFPS, [string]$Path)
  $n = 0
  foreach ($c in $Candidates) {
    try {
      if ($c.isBinary) {
        $bytes = (Get-ItemProperty $Path -Name $c.key).$($c.key)
        $text = [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
        $newText = $text
        foreach ($f in $script:FPS_FIELD_NAMES) {
          $pat = '"' + $f + '"\s*:\s*\d+'
          $rep = '"' + $f + '":' + $TargetFPS
          $newText = [regex]::Replace($newText, $pat, $rep)
        }
        $newBytes = [System.Text.Encoding]::UTF8.GetBytes($newText)
        # Registry binary 支援可變長度
        if ($newBytes.Length -lt $bytes.Length) {
          while ($newBytes.Length -lt $bytes.Length) { $newBytes += [byte]0 }
        }
        # 備份原 binary (一次性)
        $bk = Join-Path $script:ConfigDir "wizard-backup-$($c.key).bin"
        if (-not (Test-Path $bk)) { [System.IO.File]::WriteAllBytes($bk, $bytes) }
        Set-ItemProperty -Path $Path -Name $c.key -Value $newBytes -Type Binary
        Log "FPS Wizard: patched binary $($c.key) → $TargetFPS"
        $n++
      } else {
        Set-ItemProperty -Path $Path -Name $c.key -Value $TargetFPS -Type DWord
        Log "FPS Wizard: patched DWORD $($c.key) → $TargetFPS"
        $n++
      }
    } catch { Log "Wizard patch err on $($c.key): $_" 'ERROR' }
  }
  return $n
}

function Test-WizardDiffHasFps {
  # 純函式: 比對 baseline 與 current snapshot,回傳是否有 binary key 含 FPS 字串的新增/變更
  # 抽出來方便 Pester unit test
  param([hashtable]$Baseline, [hashtable]$Current)
  foreach ($k in $Current.Keys) {
    $info = $Current[$k]
    if ($info.type -ne 'binary') { continue }
    if (-not $Baseline.ContainsKey($k)) {
      if ($info.text -match $script:FPS_PATTERN) { return $true }
    } elseif ($Baseline[$k].type -eq 'binary' -and $info.bytes_hex -ne $Baseline[$k].bytes_hex) {
      if ($info.text -match $script:FPS_PATTERN) { return $true }
    }
  }
  return $false
}

function Get-WizardDiff {
  # 純函式:比對 baseline vs current,挑出新增/變更/FPS 候選 (Pester 可測,GUI/Snapshot 解耦)
  param([hashtable]$Baseline, [hashtable]$Current)
  $added = @(); $changed = @()
  foreach ($k in $Current.Keys) {
    if (-not $Baseline.ContainsKey($k)) {
      $added += $k
    } elseif ($Current[$k].type -eq 'binary') {
      if ($Current[$k].bytes_hex -ne $Baseline[$k].bytes_hex) {
        $changed += @{ key=$k; before=$Baseline[$k]; after=$Current[$k] }
      }
    } elseif ($Current[$k].value -ne $Baseline[$k].value) {
      $changed += @{ key=$k; before=$Baseline[$k]; after=$Current[$k] }
    }
  }
  $candidates = @()
  foreach ($k in $added) {
    $info = $Current[$k]
    if ($info.type -eq 'binary' -and $info.text -match $script:FPS_PATTERN) {
      $candidates += @{ key=$k; isBinary=$true }
    } elseif (($info.type -in @('Int32','UInt32')) -and ([int]$info.value -in $script:COMMON_FPS_VALUES)) {
      $candidates += @{ key=$k; isBinary=$false }
    }
  }
  foreach ($c in $changed) {
    $info = $Current[$c.key]
    if ($info.type -eq 'binary' -and $info.text -match $script:FPS_PATTERN) {
      $candidates += @{ key=$c.key; isBinary=$true }
    } elseif (($info.type -in @('Int32','UInt32')) -and ([int]$info.value -in $script:COMMON_FPS_VALUES) -and ([int]$c.before.value -in $script:COMMON_FPS_VALUES)) {
      $candidates += @{ key=$c.key; isBinary=$false }
    }
  }
  return @{ added = $added; changed = $changed; candidates = $candidates }
}

function Build-WizardSummary {
  # 純函式:把 diff 結構轉成使用者看的 dialog 字串
  param([hashtable]$Diff, [int]$TargetFPS)
  $added = $Diff.added; $changed = $Diff.changed; $candidates = $Diff.candidates
  $summary = "本次掃描結果`n  新增 key: $($added.Count)`n  變更 key: $($changed.Count)`n`n"
  if ($candidates.Count -gt 0) {
    $summary += "★ 找到 $($candidates.Count) 個 FPS 候選:`n"
    foreach ($c in $candidates) { $summary += "    $($c.key)`n" }
    $summary += "`n是否現在寫入 $TargetFPS FPS patch?"
  } else {
    $summary += "沒找到明顯 FPS 候選。可能:`n  • 等 2-3 秒讓 HSR flush registry 後再試`n  • FPS 設定不在此 path`n`n變更 keys (前 5):`n"
    foreach ($c in ($changed | Select-Object -First 5)) { $summary += "  ~ $($c.key)`n" }
    foreach ($k in ($added | Select-Object -First 5)) { $summary += "  + $k`n" }
  }
  return $summary
}

function Prompt-EnableGuard {
  # Patch 成功後的二步 opt-in:是否啟動持續守護 (改 config + dialog)
  # TOCTOU 安全:snapshot $cfg 一次,避免 modal dialog pumping dispatcher 期間 Settings 視窗 Save 改 $script:Config
  param([int]$TargetFPS)
  $cfg = $script:Config
  $needsEnable = $false
  foreach ($t in $cfg.targets) {
    if ($t.processName -eq 'StarRail' -and ($t.fpsTarget -lt $TargetFPS -or $t.fpsProfile -eq 'none')) {
      $needsEnable = $true; break
    }
  }
  if (-not $needsEnable) { return }
  $guardMsg = "已 patch FPS=$TargetFPS。`n`n是否啟動「持續守護」?`n`n" +
              "是 = 之後 HSR 動其他設定若把 FPS 寫回 30/60,工具會 2 秒內 re-patch 回 $TargetFPS`n" +
              "否 = 只 patch 這一次,使用者後續手動調整 FPS 不被覆寫`n`n" +
              "之後可從 tray 右鍵選單「持續守護: 啟動/停止」隨時切換。"
  $g = [System.Windows.MessageBox]::Show($guardMsg, "啟動持續守護?", 'YesNo', 'Question')
  if ($g -eq 'Yes') {
    foreach ($t in $cfg.targets) {
      if ($t.processName -eq 'StarRail') {
        $t.fpsTarget = $TargetFPS
        $t.fpsProfile = 'unity_cognosphere_starrail'
      }
    }
    Save-Config $cfg
    Add-Activity "★ 已啟動持續守護 (fpsTarget=$TargetFPS) — 可從 tray menu 隨時停止"
    [System.Windows.MessageBox]::Show("持續守護已啟動。`n`n停止方法:右下角托盤右鍵 → 持續守護:停止", "守護已啟動", 'OK', 'Information') | Out-Null
  } else {
    Add-Activity "Wizard: 使用者選擇只 patch 一次,不啟動持續守護"
  }
}

function Run-FpsWizardDiff {
  # Orchestration:Get-WizardDiff → Build-WizardSummary → dialog → Apply → Prompt-EnableGuard
  param([int]$TargetFPS, [string]$Path)
  $current = Snapshot-Reg $Path
  $diff = Get-WizardDiff -Baseline $script:WizardBaseline -Current $current
  $summary = Build-WizardSummary -Diff $diff -TargetFPS $TargetFPS

  if ($diff.candidates.Count -gt 0) {
    $r = [System.Windows.MessageBox]::Show($summary, "FPS Wizard 結果", 'YesNo', 'Question')
    if ($r -eq 'Yes') {
      $patched = Apply-FpsCandidates -Candidates $diff.candidates -TargetFPS $TargetFPS -Path $Path
      Add-Activity "FPS Wizard: 已 patch $patched 個 key → $TargetFPS"
      if ($script:Tray) { $script:Tray.ShowBalloonTip(4000, "FPS 已寫入", "patched $patched 個 key → $TargetFPS FPS", 'Info') }
      if ($patched -gt 0) {
        Prompt-EnableGuard -TargetFPS $TargetFPS
      } else {
        Add-Activity "Wizard: Apply-FpsCandidates 回傳 0 patched, 不啟用守護"
        [System.Windows.MessageBox]::Show("沒成功 patch 任何 key (Apply-FpsCandidates 回傳 0)`n`n可能原因: registry binary 無法寫入,或 FPS pattern 未匹配", "Wizard 部分失敗", 'OK', 'Warning') | Out-Null
      }
    }
  } else {
    Add-Activity "FPS Wizard: 沒找到 FPS 候選 (新增 $($diff.added.Count), 變更 $($diff.changed.Count))"
    [System.Windows.MessageBox]::Show($summary, "FPS Wizard 無結果", 'OK', 'Warning') | Out-Null
  }
  $script:WizardBaseline = $null
}

function Start-FpsWizard {
  param([int]$TargetFPS = 120, [string]$Path = 'HKCU:\Software\Cognosphere\Star Rail')
  if ($script:WizardTimer -and $script:WizardTimer.IsEnabled) {
    [System.Windows.MessageBox]::Show("FPS Wizard 已在執行中,請先讓它完成或重啟工具", "進行中", 'OK', 'Warning') | Out-Null
    return
  }
  $msg = "FPS 探查精靈 (實驗性)`n`n" +
         "步驟:`n" +
         "  1. 我會為 $Path 建立 registry 基線`n" +
         "  2. 你進 HSR → ESC → 設定 → 畫面`n" +
         "  3. 切換 FPS (60 → 30 套用 → 60 套用)`n" +
         "  4. ESC 離開設定面板 (不必關遊戲) — 工具會 2 秒內自動偵測`n" +
         "  5. 我自動 diff + 找 FPS key + patch 到 $TargetFPS`n`n" +
         "是否開始?"
  $r = [System.Windows.MessageBox]::Show($msg, "FPS 探查精靈", 'OKCancel', 'Information')
  if ($r -ne 'OK') { return }

  if (-not (Test-Path $Path)) {
    [System.Windows.MessageBox]::Show("Registry 路徑不存在: $Path", "錯誤", 'OK', 'Error') | Out-Null
    return
  }

  $script:WizardBaseline = Snapshot-Reg $Path
  $script:WizardTargetFPS = $TargetFPS
  $script:WizardPath = $Path
  $script:WizardSeen = $false
  $script:WizardStartTime = Get-Date
  Add-Activity "FPS Wizard 啟動 (已記下 $($script:WizardBaseline.Count) keys 當基準)"
  Add-Activity "下一步: 進 HSR → ESC → 設定 → 畫面 → 切換 FPS → ESC 關設定面板 (不必關遊戲)"
  if ($script:Tray) { $script:Tray.ShowBalloonTip(4000, "FPS Wizard 已啟動", "在 HSR 動 FPS 設定 + ESC 關面板後 (不必關遊戲),我會自動 diff + patch 到 $TargetFPS", 'Info') }

  $script:WizardTimer = New-Object System.Windows.Threading.DispatcherTimer
  $script:WizardTimer.Interval = [TimeSpan]::FromSeconds(2)
  $script:WizardTimer.Add_Tick({
    # 1. Polling diff (主路徑): 不等 HSR 退出,registry 變化含 FPS 字串就立刻 patch
    #    HSR 在 ESC 關設定面板時就會 flush registry,使用者不必完整關閉遊戲
    try {
      $current = Snapshot-Reg $script:WizardPath
      if (Test-WizardDiffHasFps -Baseline $script:WizardBaseline -Current $current) {
        $script:WizardTimer.Stop()
        Add-Activity "偵測到 registry 內 FPS 欄位變化 — 立即 diff + patch (不需等 HSR 關閉)"
        Run-FpsWizardDiff -TargetFPS $script:WizardTargetFPS -Path $script:WizardPath
        return
      }
    } catch { Log "Wizard polling diff err: $_" 'WARN' }

    # 2. HSR exit 備援路徑 (兼容舊行為,若使用者完整退出 HSR)
    $proc = Get-Process StarRail -ErrorAction SilentlyContinue
    if ($proc) {
      if (-not $script:WizardSeen) {
        $script:WizardSeen = $true
        Add-Activity "偵測到 HSR (PID $($proc.Id)) — 在 HSR 改 FPS 設定 + ESC 關設定面板後我會立即偵測 (不必關遊戲)"
      }
    } else {
      if ($script:WizardSeen) {
        $script:WizardTimer.Stop()
        Add-Activity "HSR 已關閉 — 強制 diff 看是否有變化"
        Start-Sleep -Milliseconds 2500
        Run-FpsWizardDiff -TargetFPS $script:WizardTargetFPS -Path $script:WizardPath
      } elseif (((Get-Date) - $script:WizardStartTime).TotalMinutes -gt 15) {
        $script:WizardTimer.Stop()
        Add-Activity "FPS Wizard: 15 分鐘 timeout,取消"
        if ($script:Tray) { $script:Tray.ShowBalloonTip(3000, "FPS Wizard timeout", "15 分鐘沒偵測到變化", 'Warning') }
        $script:WizardBaseline = $null
      }
    }
  })
  $script:WizardTimer.Start()
}

# === Diagnostic Report (完整逐目標狀態) ===
function Get-DiagnosticReport {
  param($Targets, $PatchResult)
  $lines = @()
  $lines += "本次掃描: 修補 $($PatchResult.style) 個視窗 / $($PatchResult.fps) 個 FPS"
  $lines += ""

  foreach ($t in $Targets) {
    $procs = @(Get-Process -Name $t.processName -EA SilentlyContinue)
    # 若 name 已含 processName 就不重複顯示
    $label = if ($t.name -like "*$($t.processName)*") { $t.name } else { "$($t.name) ($($t.processName))" }
    if ($procs.Count -eq 0) {
      $lines += "$label  ○ 未在執行"
      if ($t.fpsTarget -gt 0) { $lines += "  FPS 目標    $($t.fpsTarget) (等遊戲啟動後自動套用)" }
      $lines += ""
      continue
    }
    foreach ($p in $procs) {
      $h = $p.MainWindowHandle
      if ($h -eq [IntPtr]::Zero) {
        $lines += "$($t.name) PID $($p.Id)  ✓ 執行中 (視窗載入中)"
        $lines += ""; continue
      }
      $style = [WP.Win32]::GetWindowLong($h, -16)
      $r = New-Object WP.Win32R+RECT
      [WP.Win32R]::GetWindowRect($h, [ref]$r) | Out-Null
      $lines += "$($t.name) PID $($p.Id)  ✓ 執行中"
      $marks = @()
      foreach ($n in $t.addStyles) {
        $bit = $script:STYLES[$n].Bit
        $mark = if (($style -band $bit) -ne 0) { "✓" } else { "✗" }
        $marks += "$mark $($script:STYLES[$n].Short)"
      }
      $lines += "  視窗 style  0x$('{0:X8}' -f $style)  $($marks -join '  ')"
      $lines += "  位置與大小  $($r.L),$($r.T)  $($r.R-$r.L) x $($r.B-$r.T)"
      $needMask = Mask-Of $t.addStyles
      $hasAll = ($style -band $needMask) -eq $needMask
      if ($hasAll) {
        $lines += "              → 已可拖曳邊框 / 被 FancyZones 抓取"
      } else {
        $lines += "              → 還缺一些 style (按 Apply 會補)"
      }
      # FPS 診斷
      if ($t.fpsTarget -gt 0) {
        $lines += "  FPS 目標    $($t.fpsTarget)"
        $prof = $script:FPS_PROFILES[$t.fpsProfile]
        $regPath = if ($t.fpsRegPath) { $t.fpsRegPath } else { $prof.RegPath }
        $pat = if ($t.fpsKeyPattern) { $t.fpsKeyPattern } else { $prof.KeyPattern }
        if (-not $regPath -or -not (Test-Path $regPath)) {
          $lines += "  FPS 狀態    ⚠ 登錄檔路徑不存在: $regPath"
        } else {
          $matched = (Get-Item $regPath).Property | Where-Object { $_ -like $pat }
          if (-not $matched) {
            $lines += "  FPS 狀態    ⚠ 鍵尚未生成 (pattern $pat)"
            $lines += "              → 進遊戲 設定 → 圖形 → 任意動一個選項 → 儲存"
            $lines += "              → 工具每 $($script:Config.scanIntervalSec)s 掃描,鍵一出現立即自動解鎖"
          } else {
            $found = $false
            foreach ($k in $matched) {
              $bytes = (Get-ItemProperty $regPath -Name $k).$k
              if ($bytes -isnot [byte[]]) { continue }
              $txt = [System.Text.Encoding]::UTF8.GetString($bytes).TrimEnd([char]0)
              if ($txt -match '"FPS"\s*:\s*(\d+)') {
                $cur = [int]$matches[1]
                if ($cur -eq $t.fpsTarget) {
                  $lines += "  FPS 狀態    ✓ 已套用 $cur"
                } else {
                  $lines += "  FPS 狀態    ⚠ 目前 $cur (背景將自動 patch 為 $($t.fpsTarget))"
                }
                $found = $true; break
              }
            }
            if (-not $found) { $lines += "  FPS 狀態    ⚠ 找到鍵但無 FPS 欄位 — 進遊戲圖形設定動一下" }
          }
        }
      }
      $lines += ""
    }
  }
  ($lines -join "`r`n").TrimEnd()
}

# === Theme (跟隨系統 dark mode) ===
function Test-SystemDarkMode {
  try {
    $v = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme
    return ($v -eq 0)
  } catch { return $false }
}
$script:IsDarkMode = Test-SystemDarkMode
# B7: 跟隨系統 dark mode 只在啟動時讀, 切換系統 theme 後需重啟工具才會套用新色
function Apply-Chrome {
  param($Win)
  $h = (New-Object System.Windows.Interop.WindowInteropHelper $Win).Handle
  if ($h -eq [IntPtr]::Zero) { return }
  $pref = 2  # DWMWCP_ROUND
  [H.CW]::DwmSetWindowAttribute($h, 33, [ref]$pref, 4) | Out-Null
  $dark = [int]$script:IsDarkMode
  [H.CW]::DwmSetWindowAttribute($h, 20, [ref]$dark, 4) | Out-Null  # USE_IMMERSIVE_DARK_MODE
}

# === Activity Feed (UI 內可見的最近活動) ===
# B5: ObservableCollection 自動觸發 ListView 刷新, 不需手動 Items.Refresh()
$script:Activities = New-Object System.Collections.ObjectModel.ObservableCollection[psobject]
function Add-Activity {
  param([string]$Text)
  $entry = [pscustomobject]@{
    Time = (Get-Date -Format 'HH:mm:ss')
    Text = $Text
  }
  $script:Activities.Insert(0, $entry)
  while ($script:Activities.Count -gt 20) { $script:Activities.RemoveAt($script:Activities.Count - 1) }
  # B2: 同步 ActivityCount 文字 (僅在設定視窗開啟時生效)
  if ($script:ActivityCountLabel) {
    try { $script:ActivityCountLabel.Text = "($($script:Activities.Count) 筆)" } catch {}
  }
}

function Scan-And-Patch {
  # B3: 清掉死的 hwnd (遊戲關閉後), 避免記憶體洩漏
  if ($script:PatchedHandles.Count -gt 0) {
    $deadKeys = @()
    foreach ($k in $script:PatchedHandles.Keys) {
      try { if (-not [WP.Win32]::IsWindow([IntPtr]$k)) { $deadKeys += $k } } catch { $deadKeys += $k }
    }
    foreach ($k in $deadKeys) { $script:PatchedHandles.Remove($k) | Out-Null }
  }
  $n = 0
  $f = 0
  foreach ($t in $script:Config.targets) {
    if (-not $t.enabled) { continue }
    foreach ($p in (Get-Process -Name $t.processName -EA SilentlyContinue)) {
      if (Patch-Process -Proc $p -Target $t) { $n++ }
    }
    if (Patch-FPS -Target $t) { $f++ }
  }
  @{ style = $n; fps = $f }
}

# === 自繪 Icon (16x16 視窗-in-視窗) ===
function New-PatcherIcon {
  param([int]$Size = 16, [byte]$AccentR = 37, [byte]$AccentG = 99, [byte]$AccentB = 235)
  $bmp = New-Object System.Drawing.Bitmap $Size, $Size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::Transparent)
  $scale = $Size / 16.0
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($AccentR,$AccentG,$AccentB)), (1.5 * $scale)
  $g.DrawRectangle($pen, (1*$scale), (2*$scale), (13*$scale), (11*$scale))
  $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($AccentR,$AccentG,$AccentB))
  $g.FillRectangle($brush, (2*$scale), (3*$scale), (12*$scale), (2*$scale))
  $brush2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(249,115,22))
  $g.FillRectangle($brush2, (4*$scale), (7*$scale), (8*$scale), (4*$scale))
  $g.Dispose()
  $pen.Dispose()
  $brush.Dispose()
  $brush2.Dispose()
  $hicon = $bmp.GetHicon()
  $icon = [System.Drawing.Icon]::FromHandle($hicon).Clone()
  [H.CW]::DestroyIcon($hicon) | Out-Null  # 釋放原 HICON, Clone 後 GC 會處理
  $bmp.Dispose()
  return $icon
}

# === Main XAML ===
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="視窗修補器" Width="920" Height="600"
        WindowStartupLocation="CenterScreen"
        Background="#FAFAFA"
        FontFamily="Segoe UI Variable Text, Segoe UI"
        FontSize="13"
        ResizeMode="CanResize"
        MinWidth="780" MinHeight="520">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent" Color="#2563EB"/>
    <SolidColorBrush x:Key="AccentHover" Color="#1D4ED8"/>
    <SolidColorBrush x:Key="Surface" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="Border" Color="#E5E7EB"/>
    <SolidColorBrush x:Key="BorderDim" Color="#F3F4F6"/>
    <SolidColorBrush x:Key="Text" Color="#111827"/>
    <SolidColorBrush x:Key="TextSub" Color="#6B7280"/>
    <SolidColorBrush x:Key="TextDim" Color="#9CA3AF"/>

    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="{StaticResource AccentHover}"/></Trigger></Style.Triggers>
    </Style>

    <Style x:Key="SecondaryButton" TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Surface}"/>
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#F9FAFB"/></Trigger></Style.Triggers>
    </Style>

    <Style TargetType="ListView">
      <Setter Property="Background" Value="{StaticResource Surface}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="0"/>
    </Style>
    <Style TargetType="GridViewColumnHeader">
      <Setter Property="Background" Value="#F9FAFB"/>
      <Setter Property="Foreground" Value="{StaticResource TextSub}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="12,8"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
    </Style>
    <Style TargetType="ListViewItem">
      <Setter Property="Padding" Value="12,10"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderDim}"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Grid.Row="0" Background="White" BorderBrush="{StaticResource BorderDim}" BorderThickness="0,0,0,1" Padding="32,24">
      <StackPanel>
        <TextBlock Text="目標管理" FontSize="22" FontWeight="SemiBold" Foreground="{StaticResource Text}"/>
        <TextBlock Text="新啟動的目標 process 會被自動修補視窗 style；FPS 只在目標值大於 0 時套用" FontSize="12" Foreground="{StaticResource TextSub}" Margin="0,4,0,0"/>
      </StackPanel>
    </Border>

    <Grid Grid.Row="1" Margin="32,24">
      <Grid.RowDefinitions>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <ListView x:Name="TargetList" Grid.Column="0" Grid.Row="0">
        <ListView.View>
          <GridView>
            <GridViewColumn Header="" Width="44">
              <GridViewColumn.CellTemplate>
                <DataTemplate><CheckBox IsChecked="{Binding enabled, Mode=TwoWay}" VerticalAlignment="Center"/></DataTemplate>
              </GridViewColumn.CellTemplate>
            </GridViewColumn>
            <GridViewColumn Header="名稱" Width="180">
              <GridViewColumn.CellTemplate>
                <DataTemplate><TextBlock Text="{Binding name}" VerticalAlignment="Center" FontWeight="SemiBold"/></DataTemplate>
              </GridViewColumn.CellTemplate>
            </GridViewColumn>
            <GridViewColumn Header="Process" Width="130">
              <GridViewColumn.CellTemplate>
                <DataTemplate><TextBlock Text="{Binding processName}" VerticalAlignment="Center" Foreground="{StaticResource TextSub}"/></DataTemplate>
              </GridViewColumn.CellTemplate>
            </GridViewColumn>
            <GridViewColumn Header="Style" Width="180">
              <GridViewColumn.CellTemplate>
                <DataTemplate><TextBlock Text="{Binding styleDisplay}" VerticalAlignment="Center" Foreground="{StaticResource TextSub}" TextTrimming="CharacterEllipsis"/></DataTemplate>
              </GridViewColumn.CellTemplate>
            </GridViewColumn>
            <GridViewColumn Header="FPS" Width="130">
              <GridViewColumn.CellTemplate>
                <DataTemplate><TextBlock Text="{Binding fpsDisplay}" VerticalAlignment="Center" Foreground="{StaticResource TextSub}"/></DataTemplate>
              </GridViewColumn.CellTemplate>
            </GridViewColumn>
          </GridView>
        </ListView.View>
      </ListView>

      <StackPanel Grid.Column="1" Grid.Row="0" Margin="16,0,0,0" Width="140">
        <Button x:Name="BtnAdd"  Content="新增" Style="{StaticResource PrimaryButton}" Margin="0,0,0,8"/>
        <Button x:Name="BtnEdit" Content="編輯" Style="{StaticResource SecondaryButton}" Margin="0,0,0,8"/>
        <Button x:Name="BtnDel"  Content="移除" Style="{StaticResource SecondaryButton}" Foreground="#DC2626" Margin="0,0,0,24"/>
        <Button x:Name="BtnNow"  Content="立即套用" Style="{StaticResource SecondaryButton}"/>
      </StackPanel>

      <!-- 最近活動 -->
      <Border Grid.Row="1" Grid.ColumnSpan="2" Margin="0,16,0,0" Background="#F9FAFB" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="6" Padding="0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>
          <StackPanel Grid.Row="0" Orientation="Horizontal" Margin="14,10,14,6">
            <TextBlock Text="最近活動" FontWeight="SemiBold" Foreground="{StaticResource Text}" FontSize="12" VerticalAlignment="Center"/>
            <TextBlock x:Name="ActivityCount" Text="(無)" FontSize="11" Foreground="{StaticResource TextDim}" Margin="6,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
          <ListView x:Name="ActivityList" Grid.Row="1" MaxHeight="120" BorderThickness="0" Background="Transparent" Padding="0,0,0,6">
            <ListView.View>
              <GridView>
                <GridViewColumn Header="時間" Width="80" DisplayMemberBinding="{Binding Time}"/>
                <GridViewColumn Header="" Width="600" DisplayMemberBinding="{Binding Text}"/>
              </GridView>
            </ListView.View>
          </ListView>
        </Grid>
      </Border>
    </Grid>

    <Border Grid.Row="2" Background="White" BorderBrush="{StaticResource BorderDim}" BorderThickness="0,1,0,0" Padding="32,16">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <TextBlock x:Name="LblStatus" Grid.Column="0" VerticalAlignment="Center" Foreground="{StaticResource TextSub}" Text="—"/>
        <StackPanel Grid.Column="1" Orientation="Horizontal">
          <Button x:Name="BtnSave"   Content="儲存" Style="{StaticResource PrimaryButton}"   Width="100" Margin="0,0,8,0"/>
          <Button x:Name="BtnCancel" Content="取消" Style="{StaticResource SecondaryButton}" Width="100"/>
        </StackPanel>
      </Grid>
    </Border>
  </Grid>
</Window>
"@

function Build-Row {
  param($t)
  $sd = ($t.addStyles | ForEach-Object { ($script:STYLES[$_].Short) }) -join ', '
  if ($t.removeStyles.Count -gt 0) { $sd += ' - ' + (($t.removeStyles | ForEach-Object { ($script:STYLES[$_].Short) }) -join ', ') }
  $fd = if ($t.fpsTarget -gt 0) { "$($t.fpsTarget) FPS" } else { '—' }
  [pscustomobject]@{
    name = $t.name
    processName = $t.processName + '.exe'
    enabled = [bool]$t.enabled
    styleDisplay = $sd
    fpsDisplay = $fd
    Tag = $t
  }
}

function Show-SettingsWPF {
  $reader = New-Object System.Xml.XmlNodeReader $xaml
  $win = [Windows.Markup.XamlReader]::Load($reader)
  $win.Icon = $script:WpfIcon
  $list = $win.FindName('TargetList')
  $draftConfig = $script:Config | ConvertTo-Json -Depth 8 | ConvertFrom-Json
  # B1: 對所有 FindName 結果做 null 防護, 避免 .Text on $null crash
  $activityList = $win.FindName('ActivityList')
  if ($activityList) {
    $script:ActivityListView = $activityList
    $script:ActivityListView.ItemsSource = $script:Activities
  }
  $activityCount = $win.FindName('ActivityCount')
  if ($activityCount) {
    $script:ActivityCountLabel = $activityCount
    $activityCount.Text = "($($script:Activities.Count) 筆)"
  }
  $lblStatus = $win.FindName('LblStatus')
  $coll = New-Object System.Collections.ObjectModel.ObservableCollection[psobject]
  function Refresh-Items {
    $coll.Clear()
    foreach ($t in @($draftConfig.targets)) { $coll.Add((Build-Row $t)) | Out-Null }
    if ($lblStatus) { $lblStatus.Text = "$(@($draftConfig.targets).Count) 個目標 · 已修補 $($script:PatchedHandles.Count) 個視窗" }
    if ($activityCount) { $activityCount.Text = "($($script:Activities.Count) 筆)" }
  }
  function Sync-RowsToDraft {
    foreach ($row in @($coll)) {
      if ($row.Tag) { $row.Tag.enabled = [bool]$row.enabled }
    }
  }
  function Commit-Draft {
    Sync-RowsToDraft
    $script:Config = $draftConfig
  }
  $list.ItemsSource = $coll
  Refresh-Items

  $win.FindName('BtnAdd').Add_Click({
    Sync-RowsToDraft
    $t = Show-EditWPF -Existing $null -Parent $win
    if ($t) { $draftConfig.targets = @($draftConfig.targets) + $t; Refresh-Items }
  })
  $win.FindName('BtnEdit').Add_Click({
    Sync-RowsToDraft
    $row = $list.SelectedItem; if (-not $row) { return }
    $e = Show-EditWPF -Existing $row.Tag -Parent $win
    if ($e) {
      foreach ($k in @('name','processName','addStyles','removeStyles','fpsProfile','fpsTarget','fpsRegPath','fpsKeyPattern')) { $row.Tag.$k = $e.$k }
      Refresh-Items
    }
  })
  $win.FindName('BtnDel').Add_Click({
    Sync-RowsToDraft
    $row = $list.SelectedItem; if (-not $row) { return }
    $draftConfig.targets = @($draftConfig.targets | Where-Object { $_ -ne $row.Tag })
    Refresh-Items
  })
  $win.FindName('BtnNow').Add_Click({
    Commit-Draft
    Save-Config $script:Config
    $r = Scan-And-Patch
    # 完整診斷: 對每個 target 顯示真實狀態而不是模糊的「無需修補」
    $enabledTargets = @($script:Config.targets | Where-Object { $_.enabled })
    if ($enabledTargets.Count -eq 0) {
      [System.Windows.MessageBox]::Show($win, "目前沒有啟用的目標。`n`n請至少啟用一個 (左側勾選方塊)。", "沒有啟用目標", 'OK', 'Warning') | Out-Null
      Refresh-Items; return
    }
    $diag = Get-DiagnosticReport -Targets $enabledTargets -PatchResult $r
    $title = if ($r.style -gt 0 -or $r.fps -gt 0) { "已修補 ($($r.style) 視窗 / $($r.fps) FPS)" } else { "當前狀態" }
    [System.Windows.MessageBox]::Show($win, $diag, $title, 'OK', 'Information') | Out-Null
    Refresh-Items
  })
  # 偵測未儲存變更: 比較 in-memory draftConfig vs 磁碟上的 config.json
  function Has-UnsavedChanges {
    Sync-RowsToDraft
    $diskJson = if (Test-Path $script:ConfigPath) { Get-Content $script:ConfigPath -Raw } else { '' }
    $draftJson = $draftConfig | ConvertTo-Json -Depth 5
    return ($draftJson.Trim() -ne $diskJson.Trim())
  }
  $win.FindName('BtnSave').Add_Click({ Commit-Draft; Save-Config $script:Config; $win.Close() })
  $win.FindName('BtnCancel').Add_Click({
    if (Has-UnsavedChanges) {
      $r = [System.Windows.MessageBox]::Show($win, "你有未儲存的變更,確定要放棄?`n`n是 = 放棄並關閉`n否 = 繼續編輯", "未儲存", 'YesNo', 'Warning')
      if ($r -ne 'Yes') { return }
    }
    $script:Config = Load-Config
    $win.Close()
  })
  # 攔截 X 關窗按鈕 — 同樣 prompt
  $win.Add_Closing({
    param($sender, $e)
    if (Has-UnsavedChanges) {
      $r = [System.Windows.MessageBox]::Show($win, "你有未儲存的變更,要儲存嗎?`n`n是 = 儲存並關閉`n否 = 不儲存關閉`n取消 = 繼續編輯", "未儲存", 'YesNoCancel', 'Warning')
      switch ($r) {
        'Yes'    { Commit-Draft; Save-Config $script:Config }
        'No'     { $script:Config = Load-Config }
        'Cancel' { $e.Cancel = $true }
      }
    }
  })
  $list.Add_MouseDoubleClick({
    Sync-RowsToDraft
    $row = $list.SelectedItem; if (-not $row) { return }
    $e = Show-EditWPF -Existing $row.Tag -Parent $win
    if ($e) {
      foreach ($k in @('name','processName','addStyles','removeStyles','fpsProfile','fpsTarget','fpsRegPath','fpsKeyPattern')) { $row.Tag.$k = $e.$k }
      Refresh-Items
    }
  })

  $win.Add_SourceInitialized({ Apply-Chrome $win })
  # B1: 視窗關閉時清掉 script-scope 快取, 避免 timer 拿到已 disposed 物件
  $win.Add_Closed({
    $script:ActivityListView = $null
    $script:ActivityCountLabel = $null
  })
  $win.ShowDialog() | Out-Null
}

# === Edit Form ===
[xml]$editXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="" Width="620" Height="780"
        WindowStartupLocation="CenterOwner"
        Background="White" FontFamily="Segoe UI Variable Text, Segoe UI"
        FontSize="13" ResizeMode="NoResize">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent" Color="#2563EB"/>
    <SolidColorBrush x:Key="AccentHover" Color="#1D4ED8"/>
    <SolidColorBrush x:Key="Surface" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="Border" Color="#E5E7EB"/>
    <SolidColorBrush x:Key="Text" Color="#111827"/>
    <SolidColorBrush x:Key="TextSub" Color="#6B7280"/>
    <SolidColorBrush x:Key="TextDim" Color="#9CA3AF"/>
    <Style x:Key="PrimaryButton" TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Setter.Value></Setter>
      <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="{StaticResource AccentHover}"/></Trigger></Style.Triggers>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Surface}"/>
      <Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Setter.Value></Setter>
      <Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#F9FAFB"/></Trigger></Style.Triggers>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="MinHeight" Value="36"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="MinHeight" Value="36"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/>
    </Style>
  </Window.Resources>
  <ScrollViewer VerticalScrollBarVisibility="Auto">
    <StackPanel Margin="28,24,28,24">

      <TextBlock x:Name="TitleText" Text="新增目標" FontSize="20" FontWeight="SemiBold" Foreground="{StaticResource Text}" Margin="0,0,0,20"/>

      <!-- 基本資訊 -->
      <TextBlock Text="基本" FontWeight="SemiBold" Foreground="{StaticResource Text}" FontSize="14" Margin="0,0,0,8"/>
      <Border Background="#FAFAFA" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="6" Padding="16,14">
        <StackPanel>
          <TextBlock Text="顯示名稱" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
          <TextBox x:Name="TxtName" Margin="0,0,0,12"/>
          <TextBlock Text="Process Name (不含 .exe)" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="TxtProc" Grid.Column="0" Margin="0,0,8,0"/>
            <Button x:Name="BtnPick" Grid.Column="1" Content="從執行中選擇" Style="{StaticResource SecondaryButton}" Width="130"/>
          </Grid>
        </StackPanel>
      </Border>

      <!-- 視窗 Style -->
      <TextBlock Text="視窗 Style 修補" FontWeight="SemiBold" Foreground="{StaticResource Text}" FontSize="14" Margin="0,20,0,8"/>
      <Border Background="#EFF6FF" BorderBrush="#BFDBFE" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="0,0,0,8">
        <TextBlock Foreground="#1E40AF" FontSize="11" TextWrapping="Wrap">
          <Run Text="勾選後,符合的遊戲視窗會"/><Run Text="自動補上對應的 Windows 視窗旗標" FontWeight="SemiBold"/><Run Text="。"/>
          <LineBreak/>
          <Run Text="預設勾的 THICKFRAME + MAXIMIZEBOX 適合大多數鎖死大小的遊戲,讓你能"/><Run Text="拖曳邊框 / 最大化 / FancyZones 抓取" FontWeight="SemiBold"/><Run Text="。不知道用哪個就保留預設。"/>
        </TextBlock>
      </Border>
      <Border Background="#FAFAFA" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="6" Padding="16,14">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="16"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0">
            <TextBlock Text="加上 (Add)" FontWeight="SemiBold" FontSize="12" Foreground="{StaticResource TextSub}" Margin="0,0,0,8"/>
            <StackPanel x:Name="AddPanel"/>
          </StackPanel>
          <StackPanel Grid.Column="2">
            <TextBlock Text="移除 (Remove)" FontWeight="SemiBold" FontSize="12" Foreground="{StaticResource TextSub}" Margin="0,0,0,8"/>
            <StackPanel x:Name="RemPanel"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- FPS 解鎖 -->
      <TextBlock Text="FPS 解鎖 (Unity 遊戲)" FontWeight="SemiBold" Foreground="{StaticResource Text}" FontSize="14" Margin="0,20,0,8"/>
      <Border Background="#FFFBEB" BorderBrush="#FBBF24" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="0,0,0,8">
        <StackPanel>
          <TextBlock Text="首次使用必讀" FontWeight="SemiBold" Foreground="#92400E" FontSize="12" Margin="0,0,0,4"/>
          <TextBlock Foreground="#92400E" FontSize="11" TextWrapping="Wrap">
            <Run Text="1. 先啟動遊戲一次,進入 [設定 → 圖形],隨便動一個選項按"/><Run Text="儲存" FontWeight="SemiBold"/><Run Text="後退出"/>
            <LineBreak/>
            <Run Text="2. 這會讓遊戲在登錄檔產生 GraphicsSettings 二進位鍵"/>
            <LineBreak/>
            <Run Text="3. 只有當目標 FPS 大於 0 時,本工具才會"/><Run Text="自動偵測並套用" FontWeight="SemiBold"/><Run Text="你設的值"/>
            <LineBreak/>
            <Run Text="4. 2026-05 真實測試確認: HSR 仍用 GraphicsSettings_Model_h2986158309 (DJB2 hash 已驗證), 使用者進設定動一次後 wizard 即可 patch FPS 到目標值"/>
          </TextBlock>
        </StackPanel>
      </Border>
      <Border Background="#FAFAFA" BorderBrush="{StaticResource Border}" BorderThickness="1" CornerRadius="6" Padding="16,14">
        <StackPanel>
          <TextBlock Text="Profile (預設遊戲)" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
          <ComboBox x:Name="CmbFps" Margin="0,0,0,12"/>

          <Grid>
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="16"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
              <TextBlock Text="目標 FPS (0 = 不調整)" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
              <TextBox x:Name="TxtFps" Text="0"/>
            </StackPanel>
            <StackPanel Grid.Column="2">
              <TextBlock Text="常見值" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
              <StackPanel Orientation="Horizontal">
                <Button x:Name="BtnFps60"  Content="60" Style="{StaticResource SecondaryButton}" Width="50" Margin="0,0,4,0"/>
                <Button x:Name="BtnFps120" Content="120" Style="{StaticResource SecondaryButton}" Width="50" Margin="0,0,4,0"/>
                <Button x:Name="BtnFps144" Content="144" Style="{StaticResource SecondaryButton}" Width="50"/>
              </StackPanel>
            </StackPanel>
          </Grid>

          <Expander Header="進階 (自訂 Profile)" Foreground="{StaticResource TextSub}" Margin="0,12,0,0">
            <StackPanel Margin="0,12,0,0">
              <TextBlock Text="Registry 路徑 (留空用 profile 預設)" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
              <TextBox x:Name="TxtRegPath" Margin="0,0,0,12"/>
              <TextBlock Text="Key 名稱萬用比對 (留空用 profile 預設)" Foreground="{StaticResource TextSub}" FontSize="12" Margin="0,0,0,6"/>
              <TextBox x:Name="TxtKeyPattern"/>
            </StackPanel>
          </Expander>
        </StackPanel>
      </Border>

      <!-- 按鈕 -->
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,24,0,0">
        <Button x:Name="BtnOk" Content="確定" Style="{StaticResource PrimaryButton}" Width="100" Margin="0,0,8,0"/>
        <Button x:Name="BtnCa" Content="取消" Style="{StaticResource SecondaryButton}" Width="100"/>
      </StackPanel>
    </StackPanel>
  </ScrollViewer>
</Window>
"@

function Build-StyleCheckBox {
  param([string]$key, $styleInfo)
  $cb = New-Object System.Windows.Controls.CheckBox
  $cb.Margin = '0,3,0,3'
  $cb.VerticalContentAlignment = 'Center'
  $cb.Cursor = 'Hand'
  $sp = New-Object System.Windows.Controls.StackPanel
  $sp.Margin = '4,0,0,0'
  $t1 = New-Object System.Windows.Controls.TextBlock
  $t1.Text = $styleInfo.Short
  $t1.FontWeight = 'SemiBold'
  $t1.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(17,24,39))
  $t2 = New-Object System.Windows.Controls.TextBlock
  $t2.Text = $styleInfo.Desc
  $t2.FontSize = 11
  $t2.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromRgb(107,114,128))
  $t2.TextWrapping = 'Wrap'
  $sp.Children.Add($t1) | Out-Null
  $sp.Children.Add($t2) | Out-Null
  $cb.Content = $sp
  $cb.ToolTip = "$($styleInfo.Short) (bit 0x$('{0:X}' -f $styleInfo.Bit))`n$($styleInfo.Desc)"
  return $cb
}

function Show-EditWPF {
  param($Existing, $Parent)
  $reader = New-Object System.Xml.XmlNodeReader $editXaml
  $win = [Windows.Markup.XamlReader]::Load($reader)
  $win.Owner = $Parent
  $win.Icon = $script:WpfIcon
  # B1+B4: null guard + 同步 Window.Title 讓 taskbar 顯示正確
  $titleText = $win.FindName('TitleText')
  $titleString = if ($Existing) { "編輯目標" } else { "新增目標" }
  if ($titleText) { $titleText.Text = $titleString }
  $win.Title = $titleString

  $txtName = $win.FindName('TxtName')
  $txtProc = $win.FindName('TxtProc')
  $cmbFps = $win.FindName('CmbFps')
  $txtFps = $win.FindName('TxtFps')
  $txtRegPath = $win.FindName('TxtRegPath')
  $txtKeyPattern = $win.FindName('TxtKeyPattern')
  $addPanel = $win.FindName('AddPanel')
  $remPanel = $win.FindName('RemPanel')

  # 建立 style checkboxes
  $addCbs = @{}
  $remCbs = @{}
  foreach ($k in $script:STYLES.Keys) {
    $cb1 = Build-StyleCheckBox -key $k -styleInfo $script:STYLES[$k]
    $addPanel.Children.Add($cb1) | Out-Null
    $addCbs[$k] = $cb1
    $cb2 = Build-StyleCheckBox -key $k -styleInfo $script:STYLES[$k]
    $remPanel.Children.Add($cb2) | Out-Null
    $remCbs[$k] = $cb2
  }

  # FPS profile combobox
  foreach ($pk in $script:FPS_PROFILES.Keys) {
    $cmbFps.Items.Add([pscustomobject]@{ Key = $pk; Display = $script:FPS_PROFILES[$pk].Name }) | Out-Null
  }
  $cmbFps.DisplayMemberPath = 'Display'
  $cmbFps.SelectedValuePath = 'Key'

  # FPS 常見值 buttons
  $win.FindName('BtnFps60').Add_Click({ $txtFps.Text = '60' })
  $win.FindName('BtnFps120').Add_Click({ $txtFps.Text = '120' })
  $win.FindName('BtnFps144').Add_Click({ $txtFps.Text = '144' })

  # 載入既有資料
  if ($Existing) {
    $txtName.Text = $Existing.name
    $txtProc.Text = $Existing.processName
    foreach ($s in $Existing.addStyles) { if ($addCbs.ContainsKey($s)) { $addCbs[$s].IsChecked = $true } }
    foreach ($s in $Existing.removeStyles) { if ($remCbs.ContainsKey($s)) { $remCbs[$s].IsChecked = $true } }
    $cmbFps.SelectedValue = $Existing.fpsProfile
    $txtFps.Text = "$($Existing.fpsTarget)"
    $txtRegPath.Text = $Existing.fpsRegPath
    $txtKeyPattern.Text = $Existing.fpsKeyPattern
  } else {
    $addCbs['WS_THICKFRAME'].IsChecked = $true
    $addCbs['WS_MAXIMIZEBOX'].IsChecked = $true
    $cmbFps.SelectedValue = 'none'
  }

  $win.FindName('BtnPick').Add_Click({
    $sel = Show-PickerWPF -Parent $win
    if ($sel) {
      $txtProc.Text = $sel.ProcessName
      if (-not $txtName.Text) { $txtName.Text = $(if($sel.MainWindowTitle){$sel.MainWindowTitle}else{$sel.ProcessName}) }
    }
  })

  $script:editResult = $null
  $win.FindName('BtnOk').Add_Click({
    if (-not $txtProc.Text.Trim()) { return }
    $fpsT = 0
    [int]::TryParse($txtFps.Text.Trim(), [ref]$fpsT) | Out-Null
    $script:editResult = @{
      name = $(if($txtName.Text.Trim()){$txtName.Text.Trim()}else{$txtProc.Text.Trim()})
      processName = $txtProc.Text.Trim() -replace '\.exe$',''
      enabled = $true
      addStyles = @($addCbs.Keys | Where-Object { $addCbs[$_].IsChecked })
      removeStyles = @($remCbs.Keys | Where-Object { $remCbs[$_].IsChecked })
      fpsProfile = $(if($cmbFps.SelectedValue){$cmbFps.SelectedValue}else{'none'})
      fpsTarget = $fpsT
      fpsRegPath = $txtRegPath.Text.Trim()
      fpsKeyPattern = $txtKeyPattern.Text.Trim()
    }
    $win.Close()
  })
  $win.FindName('BtnCa').Add_Click({ $win.Close() })
  $win.Add_SourceInitialized({ Apply-Chrome $win })
  $win.ShowDialog() | Out-Null
  return $script:editResult
}

# === Picker (執行中 process) ===
[xml]$pickerXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="選擇執行中的程式" Width="660" Height="560"
        WindowStartupLocation="CenterOwner"
        Background="White" FontFamily="Segoe UI Variable Text, Segoe UI"
        FontSize="13" ResizeMode="CanResize">
  <Window.Resources>
    <SolidColorBrush x:Key="Accent" Color="#2563EB"/>
    <SolidColorBrush x:Key="Border" Color="#E5E7EB"/>
    <SolidColorBrush x:Key="Text" Color="#111827"/>
    <Style x:Key="P" TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Accent}"/><Setter Property="Foreground" Value="White"/>
      <Setter Property="Padding" Value="16,8"/><Setter Property="BorderThickness" Value="0"/><Setter Property="MinHeight" Value="36"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="S" TargetType="Button">
      <Setter Property="Background" Value="White"/><Setter Property="Foreground" Value="{StaticResource Text}"/>
      <Setter Property="BorderBrush" Value="{StaticResource Border}"/><Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,8"/><Setter Property="MinHeight" Value="36"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate></Setter.Value></Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="20">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <TextBlock Grid.Row="0" Text="選擇執行中的程式" FontSize="18" FontWeight="SemiBold" Foreground="{StaticResource Text}" Margin="0,0,0,12"/>
    <TextBox x:Name="Search" Grid.Row="1" MinHeight="36" Padding="10,8" BorderBrush="{StaticResource Border}" BorderThickness="1" Margin="0,0,0,12"/>
    <ListView x:Name="List" Grid.Row="2" BorderBrush="{StaticResource Border}" BorderThickness="1">
      <ListView.View>
        <GridView>
          <GridViewColumn Header="Process" Width="160" DisplayMemberBinding="{Binding ProcessName}"/>
          <GridViewColumn Header="視窗標題" Width="350" DisplayMemberBinding="{Binding MainWindowTitle}"/>
          <GridViewColumn Header="PID" Width="80" DisplayMemberBinding="{Binding Id}"/>
        </GridView>
      </ListView.View>
    </ListView>
    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="BtnOk" Content="選擇" Style="{StaticResource P}" Width="100" Margin="0,0,8,0"/>
      <Button x:Name="BtnCa" Content="取消" Style="{StaticResource S}" Width="100"/>
    </StackPanel>
  </Grid>
</Window>
"@

function Show-PickerWPF {
  param($Parent)
  $reader = New-Object System.Xml.XmlNodeReader $pickerXaml
  $win = [Windows.Markup.XamlReader]::Load($reader)
  $win.Owner = $Parent
  $win.Icon = $script:WpfIcon
  $list = $win.FindName('List')
  $search = $win.FindName('Search')
  $all = @(Get-Process | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle } | Sort-Object ProcessName)
  $coll = New-Object System.Collections.ObjectModel.ObservableCollection[psobject]
  function Filter-Procs { param([string]$q); $coll.Clear(); foreach ($p in $all) { if ($q -and $p.ProcessName -notlike "*$q*" -and $p.MainWindowTitle -notlike "*$q*") { continue }; $coll.Add($p) | Out-Null } }
  Filter-Procs ''
  $list.ItemsSource = $coll
  $search.Add_TextChanged({ Filter-Procs $search.Text })
  $script:pickerResult = $null
  $win.FindName('BtnOk').Add_Click({ if ($list.SelectedItem) { $script:pickerResult = $list.SelectedItem; $win.Close() } })
  $win.FindName('BtnCa').Add_Click({ $win.Close() })
  $list.Add_MouseDoubleClick({ if ($list.SelectedItem) { $script:pickerResult = $list.SelectedItem; $win.Close() } })
  $win.Add_SourceInitialized({ Apply-Chrome $win })
  $win.ShowDialog() | Out-Null
  return $script:pickerResult
}

# === Icon: 自繪 16x16 ===
$winIcon = New-PatcherIcon
$script:Tray = New-Object System.Windows.Forms.NotifyIcon
$script:Tray.Icon = $winIcon
$script:Tray.Text = "視窗修補器"
$script:Tray.Visible = $true

# 給 WPF 視窗用 (32x32 大圖)
$bmp32 = New-Object System.Drawing.Bitmap 32, 32
$g32 = [System.Drawing.Graphics]::FromImage($bmp32)
$g32.SmoothingMode = 'AntiAlias'
$g32.Clear([System.Drawing.Color]::Transparent)
$pen32 = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(37,99,235)), 2
$g32.DrawRectangle($pen32, 3, 5, 26, 22)
$br32 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(37,99,235))
$g32.FillRectangle($br32, 4, 6, 25, 4)
$br33 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(249,115,22))
$g32.FillRectangle($br33, 8, 14, 16, 8)
$g32.Dispose()
$hi32 = $bmp32.GetHicon()
$tmpIco = [System.Drawing.Icon]::FromHandle($hi32)
$ms = New-Object System.IO.MemoryStream
$tmpIco.Save($ms)
$ms.Position = 0
$script:WpfIcon = [System.Windows.Media.Imaging.BitmapFrame]::Create($ms, [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)

# === Tray ContextMenu ===
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.RenderMode = 'System'
$menu.Font = New-Object System.Drawing.Font('Segoe UI Variable Text', 9)

$itemTitle = New-Object System.Windows.Forms.ToolStripLabel("視窗修補器")
$itemTitle.Font = New-Object System.Drawing.Font('Segoe UI Variable Display Semib', 10)
$itemTitle.ForeColor = [System.Drawing.Color]::FromArgb(17,24,39)
$menu.Items.Add($itemTitle) | Out-Null
$itemStatus = New-Object System.Windows.Forms.ToolStripLabel("狀態  啟動中")
$itemStatus.ForeColor = [System.Drawing.Color]::FromArgb(107,114,128)
$menu.Items.Add($itemStatus) | Out-Null
$menu.Items.Add('-') | Out-Null

$menu.Items.Add("立即掃描修補").add_Click({
  $r = Scan-And-Patch
  $script:Tray.ShowBalloonTip(2000, "視窗修補器", "已修補 $($r.style) 個視窗、$($r.fps) 個 FPS 設定", 'Info')
})
$menu.Items.Add("管理目標...").add_Click({ Show-SettingsWPF })
$menu.Items.Add("FPS 探查精靈 (HSR 解鎖到 120 FPS)...").add_Click({ Start-FpsWizard -TargetFPS 120 -Path 'HKCU:\Software\Cognosphere\Star Rail' })
# 持續守護 toggle: 動態看 config 顯示啟動 / 停止
$itemGuard = New-Object System.Windows.Forms.ToolStripMenuItem
function Refresh-GuardItem {
  $hsr = $script:Config.targets | Where-Object { $_.processName -eq 'StarRail' } | Select-Object -First 1
  $on = $hsr -and $hsr.fpsTarget -gt 0 -and $hsr.fpsProfile -like 'unity_*'
  $script:itemGuard.Text = if ($on) { "持續守護: 停止 (fpsTarget=$($hsr.fpsTarget))" } else { "持續守護: 啟動" }
}
$script:itemGuard = $itemGuard
Refresh-GuardItem
$itemGuard.add_Click({
  $hsr = $script:Config.targets | Where-Object { $_.processName -eq 'StarRail' } | Select-Object -First 1
  if (-not $hsr) { return }
  $on = $hsr.fpsTarget -gt 0 -and $hsr.fpsProfile -like 'unity_*'
  if ($on) {
    $hsr.fpsTarget = 0
    $hsr.fpsProfile = 'none'
    Save-Config $script:Config
    Add-Activity "★ 持續守護已停止 — 使用者手動調 HSR FPS 不再被覆寫"
    if ($script:Tray) { $script:Tray.ShowBalloonTip(2500, "持續守護已停止", "之後 HSR 動 FPS 設定工具不再覆寫", 'Info') }
  } else {
    $hsr.fpsTarget = 120
    $hsr.fpsProfile = 'unity_cognosphere_starrail'
    Save-Config $script:Config
    Add-Activity "★ 持續守護已啟動 — fpsTarget=120,registry 寫回會被 2 秒內 re-patch"
    if ($script:Tray) { $script:Tray.ShowBalloonTip(2500, "持續守護已啟動", "HSR 動其他設定後 FPS 會自動 re-patch 回 120", 'Info') }
  }
  Refresh-GuardItem
})
$menu.Items.Add($itemGuard) | Out-Null
$menu.Items.Add('-') | Out-Null
$menu.Items.Add("開啟 log").add_Click({ Start-Process notepad.exe $script:LogPath })
$menu.Items.Add("開啟設定資料夾").add_Click({ Start-Process explorer.exe $script:ConfigDir })
$menu.Items.Add('-') | Out-Null
$menu.Items.Add("結束").add_Click({
  $script:Tray.Visible = $false; $script:Tray.Dispose()
  [System.Windows.Application]::Current.Shutdown()
})

$script:Tray.ContextMenuStrip = $menu
$script:Tray.add_DoubleClick({ Show-SettingsWPF })

# Timer
# B6: scanIntervalSec 變更需重啟工具 (Interval 只在啟動時讀一次, 不會 hot-reload)
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromSeconds((Clamp-ScanInterval $script:Config.scanIntervalSec))
$script:Timer.Add_Tick({
  $null = Scan-And-Patch
  $w = $script:PatchedHandles.Count
  $f = $script:FpsPatchedKeys.Count
  # B1: try/catch 包裝避免 tray menu disposed 後 crash
  try {
    if ($w -eq 0 -and $f -eq 0) {
      $itemStatus.Text = "等待目標程式啟動..."
    } else {
      $parts = @()
      if ($w -gt 0) { $parts += "$w 個視窗已修補" }
      if ($f -gt 0) { $parts += "$f 個 FPS 已解鎖" }
      $itemStatus.Text = ($parts -join ' · ')
    }
  } catch {}
})
$script:Timer.Start()

$initial = Scan-And-Patch
Log "WindowPatcher v6 started. Initial style=$($initial.style) fps=$($initial.fps)"

# === 首次啟動歡迎 modal ===
$welcomeFlag = "$script:ConfigDir\.welcomed"
if (-not (Test-Path $welcomeFlag)) {
  [xml]$welcomeXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="歡迎使用視窗修補器" Width="560" Height="540"
        WindowStartupLocation="CenterScreen"
        Background="White" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13"
        ResizeMode="NoResize">
  <Grid Margin="28">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0">
      <TextBlock Text="歡迎使用視窗修補器" FontSize="22" FontWeight="SemiBold" Foreground="#111827"/>
      <TextBlock Text="一個 60 秒就懂的小工具" FontSize="12" Foreground="#6B7280" Margin="0,4,0,0"/>
    </StackPanel>
    <ScrollViewer Grid.Row="1" Margin="0,20,0,0" VerticalScrollBarVisibility="Auto">
      <StackPanel>
        <TextBlock Text="它做什麼" FontWeight="SemiBold" Foreground="#111827" FontSize="14" Margin="0,0,0,6"/>
        <TextBlock Foreground="#374151" TextWrapping="Wrap" Margin="0,0,0,16">
          <Run Text="主功能 - 自動修補鎖死大小的遊戲視窗,讓你能:"/><LineBreak/>
          <Run Text="• 用滑鼠拖曳邊框調整大小"/><LineBreak/>
          <Run Text="• 被 PowerToys FancyZones / Windows Snap 抓取"/><LineBreak/>
          <Run Text="次要 - Unity 遊戲 FPS tweak (只在目標 FPS 大於 0 時套用)"/><LineBreak/>
          <Run Text="• HSR FPS: 進遊戲設定動一次任意選項後,wizard 可自動 patch (新版亦 work)"/>
        </TextBlock>

        <TextBlock Text="從零到 120 FPS — 完整流程" FontWeight="SemiBold" Foreground="#111827" FontSize="14" Margin="0,0,0,6"/>
        <TextBlock Foreground="#374151" TextWrapping="Wrap" Margin="0,0,0,16">
          <Run Text="1. 啟動你的遊戲 (HSR / 原神 / 等)"/><LineBreak/>
          <Run Text="2. 本工具自動修補視窗 style (約 2 秒內) → 可拖曳邊框 / 最大化 / Snap"/><LineBreak/>
          <Run Text="3. (FPS) 進遊戲 設定 → 畫面 → 切換 FPS 值 → ESC 離開設定"/><LineBreak/>
          <Run Text="4. 右下角托盤圖示 → 右鍵 → FPS 探查精靈 → 確定建基線"/><LineBreak/>
          <Run Text="5. wizard 自動 diff + patch 到目標 FPS,重啟遊戲生效"/><LineBreak/>
          <Run Text=""/><LineBreak/>
          <Run Text="本工具關閉後縮到右下角系統托盤; 右鍵圖示開啟管理選單" FontStyle="Italic" Foreground="#6B7280"/>
        </TextBlock>

        <Border Background="#FFFBEB" BorderBrush="#FBBF24" BorderThickness="1" CornerRadius="6" Padding="14,12">
          <StackPanel>
            <TextBlock Text="風險提醒" FontWeight="SemiBold" Foreground="#92400E" FontSize="13" Margin="0,0,0,6"/>
            <TextBlock Foreground="#92400E" FontSize="12" TextWrapping="Wrap">
              <Run Text="• 本工具需要管理員權限 (修補其他遊戲視窗 style)"/><LineBreak/>
              <Run Text="• 視窗修補只呼叫 user32 API, 不注入遊戲、不改遊戲檔"/><LineBreak/>
              <Run Text="• FPS tweak 可能寫入 HKCU registry；HSR 預設不啟用"/><LineBreak/>
              <Run Text="• 遊戲服務條款與偵測政策可能改變, 不保證帳號風險為零"/><LineBreak/>
              <Run Text="• 自負風險；只在信任來源與可信資料夾中執行本工具"/>
            </TextBlock>
          </StackPanel>
        </Border>
      </StackPanel>
    </ScrollViewer>
    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
      <Button x:Name="BtnOk" Content="我知道了,開始用" Width="160" MinHeight="38" Background="#2563EB" Foreground="White" BorderThickness="0" Cursor="Hand">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="16,8"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
          </ControlTemplate>
        </Button.Template>
      </Button>
    </StackPanel>
  </Grid>
</Window>
"@
  try {
    $reader = New-Object System.Xml.XmlNodeReader $welcomeXaml
    $wel = [Windows.Markup.XamlReader]::Load($reader)
    $wel.Icon = $script:WpfIcon
    # MAJOR 7 fix: 只在使用者明確按 OK 才寫 .welcomed flag (避免 Alt+F4 也算)
    $wel.FindName('BtnOk').Add_Click({
      [System.IO.File]::WriteAllText($welcomeFlag, (Get-Date).ToString('o'))
      $wel.Close()
    })
    $wel.Add_SourceInitialized({ Apply-Chrome $wel })
    $wel.ShowDialog() | Out-Null
  } catch { Log "Welcome modal failed: $_" 'WARN' }
}

$script:Tray.ShowBalloonTip(2500, "視窗修補器", "已啟動 (托盤右下角)", 'Info')

$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
$app.Run() | Out-Null
