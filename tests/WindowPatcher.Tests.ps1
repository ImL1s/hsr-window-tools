# Pester unit tests for WindowPatcher
# 跑法: Invoke-Pester -Path tests/

BeforeAll {
  $script:Root = (Resolve-Path "$PSScriptRoot/..").Path
  $script:Main = Join-Path $script:Root 'WindowPatcher/WindowPatcher-WPF.ps1'

  Add-Type @"
public static class DJB2 {
  public static uint Hash(string s) {
    uint h = 5381;
    foreach (char c in s) { h = unchecked((h * 33) ^ (uint)c); }
    return h;
  }
}
"@
}

Describe "DJB2 hash algorithm" {
  It "matches known HSR registry keys (5/5)" {
    [DJB2]::Hash('GraphicsSettings_Model')           | Should -Be ([uint32]2986158309)
    [DJB2]::Hash('GraphicsSettings_PCResolution')    | Should -Be ([uint32]431323223)
    [DJB2]::Hash('GraphicsSettings_GraphicsQuality') | Should -Be ([uint32]523255858)
    [DJB2]::Hash('GraphicsSettings_Version')         | Should -Be ([uint32]3593268432)
    [DJB2]::Hash('GraphicsSettings_IsUserSave')      | Should -Be ([uint32]3014707328)
  }
}

Describe "PowerShell parse check" {
  It "WindowPatcher-WPF.ps1 parses without errors" {
    $errors = $null; $tokens = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script:Main, [ref]$tokens, [ref]$errors) | Out-Null
    $errors.Count | Should -Be 0
  }

  It "All .ps1 files parse OK" {
    $files = Get-ChildItem $script:Root -Recurse -Filter *.ps1
    foreach ($f in $files) {
      $errors = $null; $tokens = $null
      [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors) | Out-Null
      $errors.Count | Should -Be 0 -Because "$($f.Name) should parse"
    }
  }
}

Describe "CLI smoke tests" {
  It "--help returns exit 0 and contains 'WindowPatcher CLI'" {
    $out = pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Main --help 2>&1
    $LASTEXITCODE | Should -Be 0
    ($out -join "`n") | Should -Match 'WindowPatcher CLI'
  }

  It "--diagnose runs without crash" {
    $out = pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Main --diagnose 2>&1
    $LASTEXITCODE | Should -Be 0
  }
}

Describe "Has-UnsavedChanges JSON 比對邏輯" {
  It "相同 config 返回 false" {
    $a = @{ targets = @(@{ name='X'; processName='X.exe'; enabled=$true }) } | ConvertTo-Json -Depth 5
    $b = $a
    ($a.Trim() -ne $b.Trim()) | Should -Be $false
  }
  It "不同 fpsTarget 應返回 true" {
    $a = @{ targets = @(@{ name='X'; fpsTarget=0 }) } | ConvertTo-Json -Depth 5
    $b = @{ targets = @(@{ name='X'; fpsTarget=120 }) } | ConvertTo-Json -Depth 5
    ($a.Trim() -ne $b.Trim()) | Should -Be $true
  }
  It "新增 target 應返回 true" {
    $a = @{ targets = @(@{ name='X' }) } | ConvertTo-Json -Depth 5
    $b = @{ targets = @(@{ name='X' }, @{ name='Y' }) } | ConvertTo-Json -Depth 5
    ($a.Trim() -ne $b.Trim()) | Should -Be $true
  }
}

Describe "Test-WizardDiffHasFps polling 邏輯" {
  BeforeAll {
    # NOTE: 雙份 source 已知 trade-off — 主檔不能 dot-source (有 mutex + auto-elevate + GUI 啟動).
    # 改善: 下方 'main + test 函式 source 同步' contract test 偵測漂移
    # 跟主檔同步:strict pattern (JSON field 帶引號)
    $fpsPattern = '"FPS"|"fps"|"TargetFrameRate"|"MaxFPS"|"FrameRate"'
    function Test-WizardDiffHasFps {
      param([hashtable]$Baseline, [hashtable]$Current)
      foreach ($k in $Current.Keys) {
        $info = $Current[$k]
        if ($info.type -ne 'binary') { continue }
        if (-not $Baseline.ContainsKey($k)) {
          if ($info.text -match $fpsPattern) { return $true }
        } elseif ($Baseline[$k].type -eq 'binary' -and $info.bytes_hex -ne $Baseline[$k].bytes_hex) {
          if ($info.text -match $fpsPattern) { return $true }
        }
      }
      return $false
    }
  }

  It "[Contract] 主檔 \$script:FPS_PATTERN 跟 test inline pattern 同步 (偵測 drift)" {
    $mainContent = Get-Content $script:Main -Raw
    # 主檔必須有 strict $script:FPS_PATTERN 宣告 (抽常數後的單一 source of truth)
    $mainContent | Should -Match '\$script:FPS_PATTERN\s*=\s*''"FPS"\|"fps"\|"TargetFrameRate"\|"MaxFPS"\|"FrameRate"'''
    # Test-WizardDiffHasFps 函式必須引用 $script:FPS_PATTERN (不能 hard-code 重複)
    if ($mainContent -match '(?ms)function Test-WizardDiffHasFps \{(.*?)^\}') {
      $mainBody = $matches[1]
      $mainBody | Should -Match '\$script:FPS_PATTERN'
      $mainBody | Should -Match 'type -ne ''binary'''
    } else {
      throw "主檔找不到 Test-WizardDiffHasFps 函式 (可能被刪/改名)"
    }
  }

  It "baseline 為空, current 含 FPS binary → 返回 true (新增 case)" {
    $baseline = @{}
    $current = @{
      'GraphicsSettings_Model_h99999' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='AABBCC' }
    }
    Test-WizardDiffHasFps -Baseline $baseline -Current $current | Should -Be $true
  }

  It "baseline 含 FPS:60 binary, current 改成 FPS:120 → 返回 true (變更 case)" {
    $baseline = @{
      'GraphicsSettings_Model_h99999' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='AABBCC' }
    }
    $current = @{
      'GraphicsSettings_Model_h99999' = @{ type='binary'; text='{"FPS":120}'; bytes_hex='DDEEFF' }
    }
    Test-WizardDiffHasFps -Baseline $baseline -Current $current | Should -Be $true
  }

  It "新增 binary 但不含 FPS 字串 → 返回 false (FPS pattern 過濾)" {
    $baseline = @{}
    $current = @{
      'SomeOtherKey_h12345' = @{ type='binary'; text='{"name":"value"}'; bytes_hex='AABBCC' }
    }
    Test-WizardDiffHasFps -Baseline $baseline -Current $current | Should -Be $false
  }

  It "baseline 跟 current 相同 → 返回 false (無變化)" {
    $shared = @{
      'GraphicsSettings_Model_h99999' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='AABBCC' }
    }
    Test-WizardDiffHasFps -Baseline $shared -Current $shared | Should -Be $false
  }

  It "DWORD (非 binary) 新增不該觸發 (避免 GraphicsQuality 等誤判)" {
    $baseline = @{}
    $current = @{
      'GraphicsSettings_GraphicsQuality_h523255858' = @{ type='Int32'; value='4' }
    }
    Test-WizardDiffHasFps -Baseline $baseline -Current $current | Should -Be $false
  }

  It "新增多個 key 其中一個含 FPS → 返回 true" {
    $baseline = @{}
    $current = @{
      'NoiseKey_h1' = @{ type='binary'; text='{"x":1}'; bytes_hex='AA' }
      'GraphicsSettings_Model_h99999' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='BB' }
      'NoiseKey_h2' = @{ type='binary'; text='{"y":2}'; bytes_hex='CC' }
    }
    Test-WizardDiffHasFps -Baseline $baseline -Current $current | Should -Be $true
  }
}

Describe "Get-WizardDiff (純函式 — 拆 Run-FpsWizardDiff 後可測)" {
  BeforeAll {
    # Inline copy 跟主檔同步 — contract test 偵測 drift
    $script:FPS_PATTERN = '"FPS"|"fps"|"TargetFrameRate"|"MaxFPS"|"FrameRate"'
    $script:COMMON_FPS_VALUES = @(30, 60, 120, 144)
    function Get-WizardDiff {
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
  }

  It "[Contract] 主檔有 Get-WizardDiff 且引用 \$script:FPS_PATTERN + \$script:COMMON_FPS_VALUES" {
    $main = Get-Content $script:Main -Raw
    $main | Should -Match '(?ms)function Get-WizardDiff \{'
    if ($main -match '(?ms)function Get-WizardDiff \{(.*?)^\}') {
      $matches[1] | Should -Match '\$script:FPS_PATTERN'
      $matches[1] | Should -Match '\$script:COMMON_FPS_VALUES'
    }
  }

  It "新增 binary 含 FPS → candidates 1 個 isBinary=true" {
    $b = @{}
    $c = @{ 'K1' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='AA' } }
    $d = Get-WizardDiff -Baseline $b -Current $c
    $d.added.Count | Should -Be 1
    $d.candidates.Count | Should -Be 1
    $d.candidates[0].isBinary | Should -Be $true
  }

  It "變更 binary FPS:60→120 → changed 1 個 candidates 1 個" {
    $b = @{ 'K1' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='AA' } }
    $c = @{ 'K1' = @{ type='binary'; text='{"FPS":120}'; bytes_hex='BB' } }
    $d = Get-WizardDiff -Baseline $b -Current $c
    $d.changed.Count | Should -Be 1
    $d.candidates.Count | Should -Be 1
  }

  It "Int32 in COMMON_FPS_VALUES 新增 → candidates isBinary=false" {
    $b = @{}
    $c = @{ 'K1' = @{ type='Int32'; value='60' } }
    $d = Get-WizardDiff -Baseline $b -Current $c
    $d.candidates.Count | Should -Be 1
    $d.candidates[0].isBinary | Should -Be $false
  }

  It "Int32=999 (不在 COMMON_FPS_VALUES) → added 1 但不算候選" {
    $b = @{}
    $c = @{ 'K1' = @{ type='Int32'; value='999' } }
    $d = Get-WizardDiff -Baseline $b -Current $c
    $d.added.Count | Should -Be 1
    $d.candidates.Count | Should -Be 0
  }

  It "baseline=current → 全 0" {
    $s = @{ 'K1' = @{ type='binary'; text='{"FPS":60}'; bytes_hex='AA' } }
    $d = Get-WizardDiff -Baseline $s -Current $s
    $d.added.Count | Should -Be 0
    $d.changed.Count | Should -Be 0
    $d.candidates.Count | Should -Be 0
  }
}

Describe "Build-WizardSummary (純函式)" {
  BeforeAll {
    function Build-WizardSummary {
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
  }

  It "[Contract] 主檔有 Build-WizardSummary 函式" {
    $main = Get-Content $script:Main -Raw
    $main | Should -Match '(?ms)function Build-WizardSummary \{'
  }

  It "candidates>0 → '★ 找到 N 個 FPS 候選' + TargetFPS" {
    $diff = @{ added=@('K1','K2'); changed=@(); candidates=@(@{ key='K1' }) }
    $s = Build-WizardSummary -Diff $diff -TargetFPS 120
    $s | Should -Match '★ 找到 1 個 FPS 候選'
    $s | Should -Match '寫入 120 FPS'
  }

  It "candidates=0 → '沒找到明顯 FPS 候選'" {
    $diff = @{ added=@(); changed=@(); candidates=@() }
    $s = Build-WizardSummary -Diff $diff -TargetFPS 120
    $s | Should -Match '沒找到明顯 FPS 候選'
  }
}

Describe "Wizard end-to-end (dummy registry)" {
  BeforeAll { $script:TestPath = 'HKCU:\Software\WindowPatcherCITest' }
  AfterAll { Remove-Item $script:TestPath -Recurse -Force -EA SilentlyContinue }

  It "wizard-baseline + diff + auto-patch handles FPS 60 -> 120 (binary grows 1 byte)" {
    if (Test-Path $script:TestPath) { Remove-Item $script:TestPath -Recurse -Force }
    New-Item -Path $script:TestPath -Force | Out-Null

    # 1. 寫 dummy binary 含 FPS:60
    $json60 = '{"FPS":60,"width":1920,"height":1080,"padding":"____________________"}'
    $bytes60 = [System.Text.Encoding]::UTF8.GetBytes($json60)
    Set-ItemProperty $script:TestPath -Name 'GraphicsSettings_Model_h99999' -Value $bytes60 -Type Binary

    # 2. baseline
    $b = pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Main --wizard-baseline $script:TestPath 2>&1
    $LASTEXITCODE | Should -Be 0

    # 3. 改 FPS:60 → FPS:30 模擬使用者動設定
    $json30 = '{"FPS":30,"width":1920,"height":1080,"padding":"____________________"}'
    $bytes30 = [System.Text.Encoding]::UTF8.GetBytes($json30)
    while ($bytes30.Length -lt $bytes60.Length) { $bytes30 += [byte]0 }
    Set-ItemProperty $script:TestPath -Name 'GraphicsSettings_Model_h99999' -Value $bytes30 -Type Binary

    # 4. wizard-diff 應識別 FPS 候選 + patch 30 → 120
    $d = pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Main --wizard-diff $script:TestPath 120 2>&1
    $LASTEXITCODE | Should -Be 0
    ($d -join ' ') | Should -Match '找到 1 個 FPS 候選'
    ($d -join ' ') | Should -Match 'patched 1 / 1'

    # 5. 讀回確認 FPS=120
    $after = (Get-ItemProperty $script:TestPath -Name 'GraphicsSettings_Model_h99999').'GraphicsSettings_Model_h99999'
    $afterText = [System.Text.Encoding]::UTF8.GetString($after).TrimEnd([char]0)
    $afterText | Should -Match '"FPS"\s*:\s*120'
  }
}
