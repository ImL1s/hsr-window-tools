# Uninstall-StartMenu.ps1 — 移除 Install-StartMenu 建立的 3 個捷徑 + icon
# 不影響:Install-Autostart.bat 建的 schtasks (那個用 Uninstall-Autostart.bat 移除)

$ErrorActionPreference = 'Continue'

$startMenuLnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\WindowPatcher.lnk'
$desktopLnk   = Join-Path $env:USERPROFILE 'Desktop\WindowPatcher.lnk'
$iconPath     = "$env:LOCALAPPDATA\WindowPatcher\WindowPatcher.ico"

# Best-effort unpin taskbar 在刪 lnk 之前 (lnk 刪了 verb 就找不到)
try {
  $folder = Split-Path $startMenuLnk -Parent
  $shell = New-Object -ComObject Shell.Application
  $ns = $shell.Namespace($folder)
  $item = $ns.ParseName('WindowPatcher.lnk')
  if ($item) {
    foreach ($v in $item.Verbs()) {
      $name = $v.Name
      if ($name -match 'taskbar|工作列' -and ($name -match 'Unpin|取消|解除|移除')) {
        $item.InvokeVerb($name)
        Write-Host "[-] Taskbar unpin: '$name'" -ForegroundColor Yellow
        break
      }
    }
  }
} catch {}

foreach ($p in @($startMenuLnk, $desktopLnk)) {
  if (Test-Path $p) {
    try {
      Remove-Item $p -Force -ErrorAction Stop
      Write-Host "[-] Removed: $p" -ForegroundColor Yellow
    } catch {
      Write-Host "[!] 無法移除 $p — $_" -ForegroundColor Red
    }
  }
}

if (Test-Path $iconPath) {
  try {
    Remove-Item $iconPath -Force -ErrorAction Stop
    Write-Host "[-] Removed icon: $iconPath" -ForegroundColor Yellow
  } catch {
    Write-Host "[!] 無法移除 icon $iconPath — $_" -ForegroundColor Red
  }
}

Write-Host ""
Write-Host "[OK] Start Menu / Desktop 捷徑已移除" -ForegroundColor Green
Write-Host "    (開機自啟動是另一個 — 想移除請跑 Uninstall-Autostart.bat)" -ForegroundColor Gray
Write-Host "    (若 tray 還在執行,從 tray 右鍵「結束」)" -ForegroundColor Gray
