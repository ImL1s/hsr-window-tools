# Install-StartMenu.ps1 — Start Menu + Desktop + best-effort Taskbar 捷徑
# .lnk 自帶 admin 提權 flag (byte 0x15 |= 0x20),啟動只彈一次 UAC
# Icon: 跟主檔 tray icon 同色 (#2563EB 藍框 + #F97316 橘塊),存到 LOCALAPPDATA

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$mainPs1 = Join-Path $scriptDir 'WindowPatcher\WindowPatcher-WPF.ps1'
if (-not (Test-Path $mainPs1)) {
  Write-Host "[X] 找不到 $mainPs1" -ForegroundColor Red
  Write-Host "    請確認本檔放在 hsr-window-tools 專案根目錄"
  exit 1
}

# === 1. Icon (跟主檔 New-PatcherIcon 同設計, 存到 LOCALAPPDATA) ===
$iconDir = "$env:LOCALAPPDATA\WindowPatcher"
if (-not (Test-Path $iconDir)) { New-Item -ItemType Directory -Path $iconDir -Force | Out-Null }
$iconPath = Join-Path $iconDir 'WindowPatcher.ico'

Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(37,99,235)), 2
$g.DrawRectangle($pen, 3, 5, 26, 22)
$br1 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(37,99,235))
$g.FillRectangle($br1, 4, 6, 25, 4)
$br2 = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(249,115,22))
$g.FillRectangle($br2, 8, 14, 16, 8)
$g.Dispose()
$hicon = $bmp.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hicon)
$fs = [System.IO.File]::Create($iconPath)
$icon.Save($fs)
$fs.Close()
$icon.Dispose()
$bmp.Dispose()
Write-Host "[+] Icon: $iconPath" -ForegroundColor Green

# === 2. 找 pwsh.exe (優先 PowerShell 7) ===
$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshExe) { $pwshExe = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
if (-not $pwshExe) {
  Write-Host "[X] 找不到 pwsh.exe 或 powershell.exe" -ForegroundColor Red
  exit 1
}
Write-Host "[+] PowerShell: $pwshExe" -ForegroundColor Green

# === 3. .lnk builder ===
function New-WindowPatcherLnk {
  param([string]$LnkPath)
  $parent = Split-Path $LnkPath -Parent
  if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

  $sh = New-Object -ComObject WScript.Shell
  $lnk = $sh.CreateShortcut($LnkPath)
  $lnk.TargetPath = $pwshExe
  $lnk.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$mainPs1`""
  $lnk.WorkingDirectory = (Split-Path $mainPs1 -Parent)
  $lnk.IconLocation = "$iconPath,0"
  $lnk.Description = "視窗修補器 — HSR FancyZones + 120 FPS unlock"
  $lnk.WindowStyle = 7  # Minimized (tray app, 沒主視窗)
  $lnk.Save()

  # 設 admin 提權 flag: ShellLinkHeader.LinkFlags byte 0x15 |= 0x20 (RunAsAdministrator)
  $bytes = [System.IO.File]::ReadAllBytes($LnkPath)
  $bytes[0x15] = $bytes[0x15] -bor 0x20
  [System.IO.File]::WriteAllBytes($LnkPath, $bytes)
}

$startMenuLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WindowPatcher.lnk'
$desktopLnk = Join-Path $env:USERPROFILE 'Desktop\WindowPatcher.lnk'

New-WindowPatcherLnk -LnkPath $startMenuLnk
Write-Host "[+] Start Menu: $startMenuLnk" -ForegroundColor Green

New-WindowPatcherLnk -LnkPath $desktopLnk
Write-Host "[+] Desktop:    $desktopLnk" -ForegroundColor Green

# === 4. Best-effort Win11 taskbar pin (22H2+ 多半被 OS 擋,失敗 graceful) ===
$pinned = $false
try {
  $folder = Split-Path $startMenuLnk -Parent
  $shell = New-Object -ComObject Shell.Application
  $ns = $shell.Namespace($folder)
  $item = $ns.ParseName('WindowPatcher.lnk')
  if ($item) {
    foreach ($v in $item.Verbs()) {
      $name = $v.Name
      if ($name -match 'taskbar|工作列' -and $name -notmatch 'Unpin|取消|解除') {
        $item.InvokeVerb($name)
        Write-Host "[+] Taskbar pin: tried verb '$name'" -ForegroundColor Green
        $pinned = $true
        break
      }
    }
  }
} catch {
  # silent
}

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  安裝完成" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "已建立:" -ForegroundColor White
Write-Host "  ✓ Start Menu (按 Win 鍵搜 'WindowPatcher' 找到)" -ForegroundColor Gray
Write-Host "  ✓ 桌面 WindowPatcher.lnk" -ForegroundColor Gray
if ($pinned) {
  Write-Host "  ✓ 工作列 (嘗試自動釘選,若 Win11 已擋會看不到效果)" -ForegroundColor Gray
} else {
  Write-Host "  ! 工作列:Win11 限制 API,沒自動釘選" -ForegroundColor Yellow
  Write-Host "    手動:Win 搜 'WindowPatcher' → 右鍵 → 釘選到工作列" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "啟動:雙擊任一捷徑,UAC 同意一次,tray 出現於右下角" -ForegroundColor White
Write-Host "釘到「開始」首頁:Win 搜 'WindowPatcher' → 右鍵 → 釘選到「開始」畫面" -ForegroundColor White
Write-Host "移除:雙擊 Uninstall-StartMenu.bat" -ForegroundColor White
