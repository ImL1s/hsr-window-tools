# RegProbe.ps1 - thin wrapper 呼叫 WindowPatcher-WPF.ps1 CLI 命令
#
# 三條路徑互通:
#   GUI:     托盤右鍵 → 「FPS 探查精靈...」
#   CLI:     WindowPatcher-WPF.ps1 --wizard-baseline / --wizard-diff
#   Script:  RegProbe.ps1 (本檔) — 把使用者引導套上 CLI 命令
#
# 用法:
#   .\RegProbe.ps1                 # 預設 HSR
#   .\RegProbe.ps1 -Path 'HKCU:\Software\miHoYo\絕區零'
#   .\RegProbe.ps1 -Reset          # 重建基線

param(
  [string]$Path = 'HKCU:\Software\Cognosphere\Star Rail',
  [switch]$Reset
)

$main = Join-Path $PSScriptRoot 'WindowPatcher-WPF.ps1'
if (-not (Test-Path $main)) { Write-Host "找不到 WindowPatcher-WPF.ps1"; exit 1 }
$bf = "$env:LOCALAPPDATA\WindowPatcher\wizard-baseline.json"

if ($Reset -and (Test-Path $bf)) { Remove-Item $bf -Force; Write-Host "已清基線" }

if (-not (Test-Path $bf)) {
  Write-Host "===  Step 1: 建基線  ===" -ForegroundColor Cyan
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $main --wizard-baseline $Path
  Write-Host ""
  Write-Host "下一步:" -ForegroundColor Yellow
  Write-Host "  1. 進 HSR → ESC → 設定 → 畫面 → 切換 FPS 30/60 套用"
  Write-Host "  2. 完整退出 HSR"
  Write-Host "  3. 再次跑 RegProbe.ps1 看 diff"
  exit 0
}

Write-Host "===  Step 2: 比對 + 自動 patch  ===" -ForegroundColor Cyan
& pwsh -NoProfile -ExecutionPolicy Bypass -File $main --wizard-diff $Path 120
