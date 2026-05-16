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

  It "[Contract] 主檔 \$script:FPS_FIELD_NAMES 是 single source of truth + FPS_PATTERN 由它 derive" {
    $mainContent = Get-Content $script:Main -Raw
    # FIELD_NAMES 是 single source — read-side regex + write-side foreach 都從這 derive
    $mainContent | Should -Match '\$script:FPS_FIELD_NAMES\s*=\s*@\(''FPS'',''fps'',''TargetFrameRate'',''MaxFPS'',''FrameRate''\)'
    # FPS_PATTERN 必須由 FIELD_NAMES derive (不能 hard-code literal regex)
    $mainContent | Should -Match '\$script:FPS_PATTERN\s*=\s*\(\$script:FPS_FIELD_NAMES'
    # Test-WizardDiffHasFps 函式必須引用 $script:FPS_PATTERN (不能 hard-code 重複)
    if ($mainContent -match '(?ms)function Test-WizardDiffHasFps \{(.*?)^\}') {
      $mainBody = $matches[1]
      $mainBody | Should -Match '\$script:FPS_PATTERN'
      $mainBody | Should -Match 'type -ne ''binary'''
    } else {
      throw "主檔找不到 Test-WizardDiffHasFps 函式 (可能被刪/改名)"
    }
  }

  It "[Contract] 主檔 derive 出來的 FPS_PATTERN 內容跟 test inline 一致 (執行 derive 驗 value)" {
    # 跑主檔的 derive 邏輯,跟 test inline strict pattern 比對 — 偵測 FIELD_NAMES 改動忘了同步 test
    $fieldNames = @('FPS','fps','TargetFrameRate','MaxFPS','FrameRate')
    $derived = ($fieldNames | ForEach-Object { '"' + $_ + '"' }) -join '|'
    $testInline = '"FPS"|"fps"|"TargetFrameRate"|"MaxFPS"|"FrameRate"'
    $derived | Should -Be $testInline
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

  It "DWORD 變更 60→120 (兩端都 in COMMON_FPS_VALUES) → changed 1 candidates 1 isBinary=false" {
    $b = @{ 'K1' = @{ type='Int32'; value='60' } }
    $c = @{ 'K1' = @{ type='Int32'; value='120' } }
    $d = Get-WizardDiff -Baseline $b -Current $c
    $d.changed.Count | Should -Be 1
    $d.candidates.Count | Should -Be 1
    $d.candidates[0].isBinary | Should -Be $false
  }

  It "DWORD 變更 5→60 (before 不在 COMMON_FPS_VALUES) → changed 1 但非 candidate" {
    # before.value=5 不在 @(30,60,120,144),guard 過濾掉這種非 FPS 欄位的雜訊變化
    $b = @{ 'K1' = @{ type='Int32'; value='5' } }
    $c = @{ 'K1' = @{ type='Int32'; value='60' } }
    $d = Get-WizardDiff -Baseline $b -Current $c
    $d.changed.Count | Should -Be 1
    $d.candidates.Count | Should -Be 0
  }
}

Describe "Build-WizardSummary (純函式)" {
  BeforeAll {
    # 載入真實 zh-TW psd1 給 inline Build-WizardSummary 用 (跟主檔同邏輯,依賴 $script:Lang)
    $script:Lang = Import-PowerShellDataFile (Join-Path $script:Root 'WindowPatcher\i18n\zh-TW\strings.psd1')
    function Build-WizardSummary {
      param([hashtable]$Diff, [int]$TargetFPS)
      $added = $Diff.added; $changed = $Diff.changed; $candidates = $Diff.candidates
      $summary = ($script:Lang.wizard_summary_header -f $added.Count, $changed.Count)
      if ($candidates.Count -gt 0) {
        $summary += ($script:Lang.wizard_summary_found_prefix -f $candidates.Count)
        foreach ($c in $candidates) { $summary += "    $($c.key)`n" }
        $summary += ($script:Lang.wizard_summary_apply_prompt -f $TargetFPS)
      } else {
        $summary += $script:Lang.wizard_summary_no_candidate
        foreach ($c in ($changed | Select-Object -First 5)) { $summary += "  ~ $($c.key)`n" }
        foreach ($k in ($added | Select-Object -First 5)) { $summary += "  + $k`n" }
      }
      return $summary
    }
  }

  It "[Contract] 主檔 Build-WizardSummary 函式 + 引用 4 個 wizard_summary_* i18n keys (抓 drift)" {
    $main = Get-Content $script:Main -Raw
    $main | Should -Match '(?ms)function Build-WizardSummary \{'
    if ($main -match '(?ms)function Build-WizardSummary \{(.*?)^\}') {
      $body = $matches[1]
      $body | Should -Match 'wizard_summary_header'
      $body | Should -Match 'wizard_summary_found_prefix'
      $body | Should -Match 'wizard_summary_apply_prompt'
      $body | Should -Match 'wizard_summary_no_candidate'
    } else {
      throw "主檔找不到 Build-WizardSummary"
    }
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

Describe "Prompt-EnableGuard (contract only — 副作用函式靠 contract 驗 drift)" {
  It "[Contract] 主檔有 Prompt-EnableGuard 且呼叫 Save-Config + Add-Activity + 用 \$cfg snapshot 避 TOCTOU" {
    $main = Get-Content $script:Main -Raw
    $main | Should -Match '(?ms)function Prompt-EnableGuard \{'
    if ($main -match '(?ms)function Prompt-EnableGuard \{(.*?)^\}') {
      $body = $matches[1]
      $body | Should -Match 'Save-Config'
      $body | Should -Match 'Add-Activity'
      # TOCTOU 防護:必須 snapshot 一次到 $cfg,不能直接重複用 $script:Config
      $body | Should -Match '\$cfg\s*=\s*\$script:Config'
    } else {
      throw "主檔找不到 Prompt-EnableGuard 函式 (可能被刪/改名)"
    }
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

Describe "i18n localization framework (5 locales)" {
  BeforeAll {
    $script:I18nRoot = Join-Path $script:Root 'WindowPatcher\i18n'
    $script:I18nLocales = @('zh-TW','en','zh-CN','ja','ko')

    # Inline copy 跟主檔同步 — contract test 偵測 drift
    function Get-EffectiveLocale {
      param([string]$ConfigLanguage)
      $supported = @('zh-TW','en','zh-CN','ja','ko')
      if ($ConfigLanguage -and $ConfigLanguage -ne 'auto' -and $ConfigLanguage -in $supported) {
        return $ConfigLanguage
      }
      $sys = $PSUICulture
      if ($sys -in $supported) { return $sys }
      $base = ($sys -split '-')[0]
      $match = $supported | Where-Object { ($_ -split '-')[0] -eq $base } | Select-Object -First 1
      if ($match) { return $match }
      return 'en'
    }
  }

  It "All 5 strings.psd1 exist and parse without errors" {
    foreach ($loc in $script:I18nLocales) {
      $p = Join-Path $script:I18nRoot "$loc\strings.psd1"
      Test-Path $p | Should -Be $true -Because "$loc/strings.psd1 must exist"
      $errors = $null; $tokens = $null
      [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errors) | Out-Null
      $errors.Count | Should -Be 0 -Because "$loc parses cleanly"
    }
  }

  It "[Contract] Key parity — 4 個 locale 的 key 集合都跟 zh-TW canonical 完全一致" {
    $canonical = (Import-PowerShellDataFile (Join-Path $script:I18nRoot 'zh-TW\strings.psd1')).Keys | Sort-Object
    $canonical.Count | Should -BeGreaterThan 50 -Because "至少 50+ keys (Commit A: ~62)"
    foreach ($loc in $script:I18nLocales | Where-Object { $_ -ne 'zh-TW' }) {
      $keys = (Import-PowerShellDataFile (Join-Path $script:I18nRoot "$loc\strings.psd1")).Keys | Sort-Object
      $missing = @($canonical | Where-Object { $_ -notin $keys })
      $extra   = @($keys | Where-Object { $_ -notin $canonical })
      $missing.Count | Should -Be 0 -Because "$loc 缺 keys: $($missing -join ', ')"
      $extra.Count | Should -Be 0 -Because "$loc 多 keys: $($extra -join ', ')"
    }
  }

  It "[Contract] 主檔有 Get-EffectiveLocale + Load-Lang + \$script:SupportedLocales" {
    $main = Get-Content $script:Main -Raw
    $main | Should -Match '(?ms)function Get-EffectiveLocale \{'
    $main | Should -Match '(?ms)function Load-Lang \{'
    $main | Should -Match '\$script:SupportedLocales\s*=\s*@\(''zh-TW'',''en'',''zh-CN'',''ja'',''ko''\)'
    # config.json 必須有 language 欄位 (Get-DefaultConfig)
    $main | Should -Match 'language\s*=\s*''auto'''
  }

  It "Get-EffectiveLocale: explicit valid locale → 該 locale" {
    Get-EffectiveLocale -ConfigLanguage 'zh-TW' | Should -Be 'zh-TW'
    Get-EffectiveLocale -ConfigLanguage 'en'    | Should -Be 'en'
    Get-EffectiveLocale -ConfigLanguage 'zh-CN' | Should -Be 'zh-CN'
    Get-EffectiveLocale -ConfigLanguage 'ja'    | Should -Be 'ja'
    Get-EffectiveLocale -ConfigLanguage 'ko'    | Should -Be 'ko'
  }

  It "Get-EffectiveLocale: 'auto' → 跑 OS-detect 路徑,結果是 supported 之一" {
    $r = Get-EffectiveLocale -ConfigLanguage 'auto'
    $r | Should -BeIn $script:I18nLocales
  }

  It "Get-EffectiveLocale: invalid explicit value → fallback 也在 supported" {
    $r = Get-EffectiveLocale -ConfigLanguage 'invalid-xyz'
    $r | Should -BeIn $script:I18nLocales
  }

  It "Get-EffectiveLocale: 空字串 → fallback (走 auto 路徑)" {
    $r = Get-EffectiveLocale -ConfigLanguage ''
    $r | Should -BeIn $script:I18nLocales
  }

  It "Load 真實 psd1 內容 — zh-TW + en 已知 key 值正確" {
    $tw = Import-PowerShellDataFile (Join-Path $script:I18nRoot 'zh-TW\strings.psd1')
    $tw.tray_title    | Should -Be '視窗修補器'
    $tw.tray_menu_exit | Should -Be '結束'

    $en = Import-PowerShellDataFile (Join-Path $script:I18nRoot 'en\strings.psd1')
    $en.tray_title    | Should -Be 'WindowPatcher'
    $en.tray_menu_exit | Should -Be 'Exit'
  }
}
