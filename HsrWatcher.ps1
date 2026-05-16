# HsrWatcher.ps1 - 背景監聽 StarRail.exe 啟動,自動修補視窗 style
# 由 schtasks 在登入時以 admin 啟動
# 機制:polling 每 2 秒掃描一次,比 WMI Event 在隱藏 session 下更可靠

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class HP {
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr h2, int x, int y, int w, int ht, uint f);
}
"@

$log = "$env:LOCALAPPDATA\HsrWatcher.log"
$patchedPids = @{}  # 已確認完成的 PID；每輪仍重新驗證 style，避免同 PID 被遊戲重設後漏補
$desiredMask = 0x40000 -bor 0x10000

function Write-Log($msg) {
  Add-Content -Path $log -Value ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg)
}

function Patch-Hsr {
  param([int]$ProcessId)
  $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if (-not $p) { return }
  # 等視窗 handle 出現,最多 30 秒
  for ($i = 0; $i -lt 30; $i++) {
    $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { break }
    Start-Sleep -Seconds 1
  }
  if ($p.MainWindowHandle -eq [IntPtr]::Zero) {
    Write-Log "PID=$ProcessId 30 秒內無 window handle,跳過"
    return
  }
  $hwnd = $p.MainWindowHandle
  $pre = [HP]::GetWindowLong($hwnd, -16)
  if (($pre -band $desiredMask) -eq $desiredMask) {
    if (-not $patchedPids.ContainsKey($ProcessId)) {
      Write-Log ("PID={0} 已有 THICKFRAME+MAXIMIZEBOX (style 0x{1:X8}),不需修補" -f $ProcessId, $pre)
    }
    $patchedPids[$ProcessId] = $true
    return
  }
  if ($patchedPids.ContainsKey($ProcessId)) {
    Write-Log ("PID={0} style 被重設或不完整,重新修補 (style 0x{1:X8})" -f $ProcessId, $pre)
  }
  [HP]::SetWindowLong($hwnd, -16, ($pre -bor $desiredMask)) | Out-Null
  [HP]::SetWindowPos($hwnd, [IntPtr]::Zero, 0,0,0,0, 0x27) | Out-Null
  Start-Sleep -Milliseconds 200
  $post = [HP]::GetWindowLong($hwnd, -16)
  $ok = (($post -band $desiredMask) -eq $desiredMask)
  Write-Log ("PID={0}  0x{1:X8} -> 0x{2:X8}  THICKFRAME+MAXIMIZEBOX={3}" -f $ProcessId, $pre, $post, $ok)
  if ($ok) { $patchedPids[$ProcessId] = $true }
}

Write-Log "Watcher started (polling mode,interval=2s)"

# 主迴圈:每 2 秒掃描一次 StarRail.exe
while ($true) {
  try {
    $procs = Get-Process StarRail -ErrorAction SilentlyContinue
    foreach ($p in $procs) { Patch-Hsr -ProcessId $p.Id }
    # 清理已結束的 PID
    $live = @{}
    foreach ($p in $procs) { $live[$p.Id] = $true }
    $deadPids = @($patchedPids.Keys | Where-Object { -not $live.ContainsKey($_) })
    foreach ($dp in $deadPids) { $patchedPids.Remove($dp) }
  } catch {
    Write-Log "Loop error: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 2
}
