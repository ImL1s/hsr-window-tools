# HSR 全自動補丁:注入 WS_THICKFRAME + WS_MAXIMIZEBOX,可選 resize
# 用法:
#   .\HSR-Patch.ps1                          # 只注入 style
#   .\HSR-Patch.ps1 -W 1600 -H 900           # 注入 style + resize
#   .\HSR-Patch.ps1 -W 1920 -H 1080 -X 0 -Y 0
param([int]$W=0,[int]$H=0,[int]$X=-1,[int]$Y=-1)

$resultPath = Join-Path $env:TEMP 'hsr-patch-result.json'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Remove-Item $resultPath -ErrorAction SilentlyContinue
  $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath)
  if ($W -gt 0) { $argList += '-W',$W }
  if ($H -gt 0) { $argList += '-H',$H }
  if ($X -ge 0) { $argList += '-X',$X }
  if ($Y -ge 0) { $argList += '-Y',$Y }
  try {
    $child = Start-Process pwsh -ArgumentList $argList -Verb RunAs -WindowStyle Hidden -Wait -PassThru
  } catch {
    @{ ok=$false; err="UAC cancelled or elevation failed: $($_.Exception.Message)" } | ConvertTo-Json
    exit 1
  }
  if (-not (Test-Path $resultPath)) {
    @{ ok=$false; err="Elevated patch did not produce result"; exitCode=$child.ExitCode } | ConvertTo-Json
    exit 1
  }
  $json = Get-Content $resultPath -Raw -ErrorAction SilentlyContinue
  Write-Output $json
  try {
    $result = $json | ConvertFrom-Json
    exit $(if($result.ok){0}else{1})
  } catch {
    exit $(if($child.ExitCode -eq 0){0}else{$child.ExitCode})
  }
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class P {
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr h2, int x, int y, int w, int h, uint f);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
}
"@

$hsr = Get-Process StarRail -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
if (-not $hsr) {
  @{ ok=$false; err="HSR not running or no main window" } | ConvertTo-Json | Out-File $resultPath -Encoding UTF8
  exit 1
}
$hwnd = $hsr.MainWindowHandle
$pre = [P]::GetWindowLong($hwnd, -16)

# 注入 WS_THICKFRAME + WS_MAXIMIZEBOX
[P]::SetWindowLong($hwnd, -16, ($pre -bor 0x40000 -bor 0x10000)) | Out-Null
[P]::SetWindowPos($hwnd, [IntPtr]::Zero, 0,0,0,0, 0x27) | Out-Null
Start-Sleep -Milliseconds 200

# Optional resize
$resized = $false
if ($W -gt 0 -and $H -gt 0) {
  Add-Type -AssemblyName System.Windows.Forms
  $rx = if ($X -ge 0) { $X } else { [Math]::Max(0, [int](([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width - $W) / 2)) }
  $ry = if ($Y -ge 0) { $Y } else { [Math]::Max(0, [int](([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height - $H) / 2)) }
  [P]::MoveWindow($hwnd, $rx, $ry, $W, $H, $true) | Out-Null
  $resized = $true
}

$post = [P]::GetWindowLong($hwnd, -16)
$r = New-Object P+RECT
[P]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$ok = (($post -band 0x40000) -ne 0) -and (($post -band 0x10000) -ne 0)
@{
  ok = $ok
  pre = "0x$('{0:X8}' -f $pre)"
  post = "0x$('{0:X8}' -f $post)"
  thickframe = (($post -band 0x40000) -ne 0)
  maximizebox = (($post -band 0x10000) -ne 0)
  resized = $resized
  position = "$($r.L),$($r.T)"
  size = "$($r.R-$r.L)x$($r.B-$r.T)"
} | ConvertTo-Json | Out-File $resultPath -Encoding UTF8
exit $(if($ok){0}else{1})
