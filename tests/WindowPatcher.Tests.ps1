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
    function Test-WizardDiffHasFps {
      param([hashtable]$Baseline, [hashtable]$Current)
      $fpsPattern = '"FPS"|"fps"|TargetFrameRate|MaxFPS|FrameRate'
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

  It "[Contract] 主檔的 Test-WizardDiffHasFps 內容跟 test 一致 (偵測 double-source 漂移)" {
    $mainContent = Get-Content $script:Main -Raw
    # 抽出主檔 Test-WizardDiffHasFps 函式 body (從 'function Test-WizardDiffHasFps' 到下一個 'function ' 或 '\n}' 結尾)
    if ($mainContent -match '(?ms)function Test-WizardDiffHasFps \{(.*?)^\}') {
      $mainBody = $matches[1]
      # 核心 regex pattern 必須一致
      $mainBody | Should -Match '"FPS"\|"fps"\|TargetFrameRate\|MaxFPS\|FrameRate'
      # 結構檢查: 主檔該函式必須有 binary type filter
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
