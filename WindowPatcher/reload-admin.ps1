# reload-admin.ps1 - 重啟 WindowPatcher 托盤(自動提權)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  $sb = Join-Path $env:TEMP "wp-reload-result.txt"
  if (Test-Path $sb) { Remove-Item $sb -Force }
  Start-Process pwsh -ArgumentList '-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$PSCommandPath -Verb RunAs -Wait
  if (Test-Path $sb) { Get-Content $sb }
  exit
}

$killed = 0
Get-Process pwsh -ErrorAction SilentlyContinue | ForEach-Object {
  try {
    $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
    if ($cmd -like '*WindowPatcher-WPF*') {
      Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
      $killed++
    }
  } catch {}
}
Start-Sleep -Milliseconds 500

# 啟動新托盤
$main = Join-Path $PSScriptRoot 'WindowPatcher-WPF.ps1'
Start-Process pwsh -ArgumentList '-NoProfile','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$main

# 寫結果
"Killed $killed 個舊托盤,已啟動新托盤" | Out-File "$env:TEMP\wp-reload-result.txt" -Encoding UTF8
