# FPS-Wizard.ps1 - 引導式 wrapper 呼叫 WindowPatcher-WPF.ps1 CLI 命令
#
# 三條路徑互通:
#   GUI:     托盤右鍵 → 「FPS 探查精靈...」 (推薦)
#   CLI:     WindowPatcher-WPF.ps1 --wizard-baseline / --wizard-diff
#   Script:  FPS-Wizard.ps1 (本檔) — 自動 watch HSR 退出 + 自動 diff
#
# 流程: 建基線 → 自動 watch StarRail.exe 啟動+退出 → 自動 diff + patch

param(
  [string]$Path = 'HKCU:\Software\Cognosphere\Star Rail',
  [int]$TargetFPS = 120
)

$main = Join-Path $PSScriptRoot 'WindowPatcher-WPF.ps1'
if (-not (Test-Path $main)) { Write-Host "找不到 WindowPatcher-WPF.ps1"; exit 1 }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  HSR FPS Setup Wizard (CLI)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# Step 1: 建基線 (透過 CLI 命令)
Write-Host ""
Write-Host "[1/3] 建立基線..." -ForegroundColor Green
& pwsh -NoProfile -ExecutionPolicy Bypass -File $main --wizard-baseline $Path
if ($LASTEXITCODE -ne 0) { Write-Host "基線建立失敗"; exit 1 }

# Step 2: Watch HSR
Write-Host ""
Write-Host "[2/3] 等你動 HSR FPS 設定..." -ForegroundColor Green
Write-Host "  1. 進 HSR → ESC → 設定 → 畫面"
Write-Host "  2. 切換 FPS (60 → 30 套用 → 60 套用)"
Write-Host "  3. 完整退出 HSR (CLI 版需要 process exit; GUI tray menu 不必關遊戲)"
Write-Host ""
Write-Host "  我會自動偵測 HSR 退出..." -ForegroundColor Cyan

$seen = $false; $start = Get-Date
while ($true) {
  $proc = Get-Process StarRail -ErrorAction SilentlyContinue
  if ($proc) {
    if (-not $seen) { $seen = $true; Write-Host "  ✓ 偵測到 HSR (PID $($proc.Id))" -ForegroundColor Green }
  } else {
    if ($seen) { Write-Host "  ✓ HSR 已退出"; break }
    if (((Get-Date) - $start).TotalMinutes -gt 15) { Write-Host "Timeout 15min,放棄"; exit 1 }
  }
  Start-Sleep -Seconds 2
}

Start-Sleep -Seconds 3  # 等 HSR flush

# Step 3: Diff + patch (透過 CLI 命令)
Write-Host ""
Write-Host "[3/3] 比對 + 自動 patch..." -ForegroundColor Green
& pwsh -NoProfile -ExecutionPolicy Bypass -File $main --wizard-diff $Path $TargetFPS
