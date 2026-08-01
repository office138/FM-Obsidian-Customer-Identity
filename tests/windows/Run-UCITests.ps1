<#
=====================================================
Run-UCITests.ps1
UPDATE_CUSTOMER_IDENTITY - Windows PowerShell 5.1 実行検証ハーネス
(補正版 2026-07-28: ロールバック注入方式変更 / TestRoot絶対パス安全確認 / 実行環境強制確認 /
 件数表記統一 / 終了時整合性確認 を反映。対象PowerShell本体は無改修)

【目的】
FM-Obsidian-Bridge-Payload.ps1 の UPDATE_CUSTOMER_IDENTITY action を、
本番Vaultとは完全に別のテスト用一時Vaultに対して実際に呼び出し、
正常系・異常系・ロールバック・改行コード・stdout純度を自動検証する。

【安全設計】
- 本番Vaultには一切アクセスしない。すべて $TestRoot 配下の使い捨てVaultで完結する。
- 対象PowerShell(FM-Obsidian-Bridge-Payload.ps1)は一切書き換えない。読み取り専用に呼び出すのみ。
  ロールバック試験でのみ、失敗注入のための「テスト専用の一時コピー」を作成するが、これは
  $TestRoot 配下にのみ作成し、テスト直後に確実に削除し、削除できたことを確認する。
- 各テストケースは独立した使い捨てVaultサブフォルダを持つ(相互汚染を避けるため)。
- 実行のたびに $TestRoot を作り直す(既存があれば削除して再作成)。
- $TestRoot は絶対パスへ正規化したうえで、本番Vault配下・ドライブルート・空パス・
  システム/プロファイル等の危険な上位フォルダでないことを無条件でチェックし、
  該当する場合は一切の処理を行わずに停止する。
- 実行環境が Windows PowerShell 5.1 (Desktop Edition) であることを開始時に強制確認する。
  pwsh.exe (PowerShell 7系/Core) 等での実行は起動直後に拒否する。
- テスト終了後、対象PowerShell本体のSHA256が既知の値から変化していないこと、
  テスト専用コピー(失敗注入版)が残存していないことを最終確認する。

【使い方】(Windows PowerShell 5.1 の powershell.exe で実行。pwsh.exe不可)
  cd "<REPOSITORY_ROOT>\tests\windows"
  powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-UCITests.ps1 `
      -TargetScript "C:\Users\<user>\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1"

  省略時は、このスクリプトと同じフォルダにある FM-Obsidian-Bridge-Payload.ps1 を探す。

【件数】
  機能テスト23件(正常系10 + 異常系9 + ロールバック1 + 改行コード3) + 構文確認1件 = 総24結果。
  これとは別に、実行環境確認・TestRoot安全確認・終了時整合性確認(SHA256/クリーンアップ)を
  「安全確認」として別集計で報告する(24件のカウントには含めない)。

【出力】
  $TestRoot\_report.txt      … 全ケースのPASS/FAIL一覧と詳細(安全確認セクションを含む)
  $TestRoot\_report.json     … 機械可読な結果一覧
  コンソールにも同内容のサマリを表示する。
=====================================================
#>

[CmdletBinding()]
param(
  [string]$RepositoryRoot = "",
  [string]$TargetScript = "",
  [string]$FixtureRoot = "",
  [string]$TestRoot = "",
  [string]$PowerShellExe = "powershell.exe",
  [string]$ProductionVaultRoot = "",
  [string]$ExpectedTargetSha256 = "17FF7E78DD129E6F90447F22C9E13FC53E6064A1D4D3C763E6586DA35E61C96A"
)

# 回帰修正(2026-07-29d): paramブロックの既定値でPSScriptRootを直接評価すると、
# 実行方法によって解決タイミングが不安定になり得るため、paramブロック直後で
# 明示的に解決する方式へ変更した。
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
  $RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))
} else {
  $RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
}
if ([string]::IsNullOrWhiteSpace($TargetScript)) {
  $TargetScript = Join-Path $RepositoryRoot "FM-Obsidian-Bridge-Payload.ps1"
} else {
  $TargetScript = [System.IO.Path]::GetFullPath($TargetScript)
}
if ([string]::IsNullOrWhiteSpace($FixtureRoot)) {
  $FixtureRoot = Join-Path $RepositoryRoot "tests\fixtures\TestVault_UPDATE_CUSTOMER_IDENTITY"
} else {
  $FixtureRoot = [System.IO.Path]::GetFullPath($FixtureRoot)
}
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
  $TestRoot = Join-Path $env:TEMP (Join-Path "FM-Obsidian-Customer-Identity" ([Guid]::NewGuid().ToString("N")))
} else {
  $TestRoot = [System.IO.Path]::GetFullPath($TestRoot)
}

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Utf8Bom   = New-Object System.Text.UTF8Encoding($true)

$script:Results = New-Object System.Collections.Generic.List[object]
$script:SafetyChecks = New-Object System.Collections.Generic.List[object]

function Record-Result {
  param([string]$Name, [bool]$Pass, [string]$Detail, [object]$Raw = $null, [string]$Category = "Functional")
  $script:Results.Add([ordered]@{ Name=$Name; Pass=$Pass; Detail=$Detail; Raw=$Raw; Category=$Category })
  $mark = if ($Pass) { "PASS" } else { "FAIL" }
  $color = if ($Pass) { "Green" } else { "Red" }
  Write-Host "[$mark] $Name" -ForegroundColor $color
  if (-not $Pass) { Write-Host "       -> $Detail" -ForegroundColor Yellow }
}

function Record-SafetyCheck {
  param([string]$Name, [bool]$Pass, [string]$Detail)
  $script:SafetyChecks.Add([ordered]@{ Name=$Name; Pass=$Pass; Detail=$Detail })
  $mark = if ($Pass) { "PASS" } else { "FAIL" }
  $color = if ($Pass) { "Green" } else { "Red" }
  Write-Host "[$mark][安全確認] $Name" -ForegroundColor $color
  if (-not $Pass) { Write-Host "       -> $Detail" -ForegroundColor Yellow }
}

# ===================== 0. 実行環境の強制確認(最優先・最初に行う) =====================
function Assert-WindowsPowerShell51Desktop {
  $edition = $PSVersionTable.PSEdition
  if ($null -eq $edition) { $edition = "Desktop" }  # PSEditionキーを持たない古い実装はDesktop扱い
  $v = $PSVersionTable.PSVersion
  $reasonParts = New-Object System.Collections.Generic.List[string]
  $ok = $true
  if ($edition -ne "Desktop") { $ok = $false; [void]$reasonParts.Add("PSEdition=$edition(Desktop以外)") }
  if ($v.Major -ne 5) { $ok = $false; [void]$reasonParts.Add("Major=$($v.Major)(5以外)") }
  elseif ($v.Minor -lt 1) { $ok = $false; [void]$reasonParts.Add("Minor=$($v.Minor)(1未満)") }

  if (-not $ok) {
    Write-Host "[STOP] このハーネスは Windows PowerShell 5.1 (Desktop Edition) 専用です。" -ForegroundColor Red
    Write-Host "       検出値: PSEdition=$edition / PSVersion=$($v.ToString()) ($($reasonParts -join ', '))" -ForegroundColor Red
    Write-Host "       pwsh.exe (PowerShell 7系/Core) ではなく、powershell.exe から実行してください。" -ForegroundColor Red
    exit 1
  }
  Record-SafetyCheck "実行環境: Windows PowerShell 5.1 Desktop" $true "PSEdition=$edition / PSVersion=$($v.ToString())"

  $exeLeaf = Split-Path $script:PowerShellExe -Leaf
  if ($exeLeaf.ToLowerInvariant() -ne "powershell.exe") {
    Write-Host "[STOP] -PowerShellExe が powershell.exe を指していません ($script:PowerShellExe)。対象スクリプトの子プロセス起動にはWindows PowerShell 5.1が必要です。" -ForegroundColor Red
    exit 1
  }
  Record-SafetyCheck "子プロセス起動exeの確認(powershell.exe)" $true "PowerShellExe=$script:PowerShellExe"
}
Assert-WindowsPowerShell51Desktop

# ===================== 1. 対象スクリプト存在確認 =====================
if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Host "[STOP] 対象スクリプトが見つかりません: $TargetScript" -ForegroundColor Red
  exit 1
}
$TargetScript = (Resolve-Path -LiteralPath $TargetScript).Path
Record-SafetyCheck "対象スクリプト存在確認" $true "$TargetScript"

if (-not (Test-Path -LiteralPath $FixtureRoot -PathType Container)) {
  Write-Host "[STOP] FixtureRootが見つかりません: $FixtureRoot" -ForegroundColor Red
  exit 1
}
$FixtureRoot = (Resolve-Path -LiteralPath $FixtureRoot).Path.TrimEnd('\')
$resolvedTestRoot = [System.IO.Path]::GetFullPath($TestRoot).TrimEnd('\')
$separator = [System.IO.Path]::DirectorySeparatorChar
$fixturePrefix = $FixtureRoot + $separator
$testPrefix = $resolvedTestRoot + $separator
if (
  $resolvedTestRoot.Equals($FixtureRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
  $testPrefix.StartsWith($fixturePrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
  $fixturePrefix.StartsWith($testPrefix, [System.StringComparison]::OrdinalIgnoreCase)
) {
  throw 'TestRoot and FixtureRoot must not be equal or contain one another.'
}

# ===================== 2. TestRootの絶対パス安全確認 =====================
function Assert-SafeTestRoot {
  param([string]$Path, [string]$ProdVaultRoot)

  if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Host "[STOP] TestRootが空です。" -ForegroundColor Red
    exit 1
  }

  $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')

  if ($full -match '^[A-Za-z]:$') {
    Write-Host "[STOP] TestRootがドライブルートです: $full" -ForegroundColor Red
    exit 1
  }

  $dangerous = New-Object System.Collections.Generic.List[string]
  foreach ($p in @($env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:USERPROFILE, $env:SystemDrive)) {
    if (-not [string]::IsNullOrWhiteSpace($p)) {
      [void]$dangerous.Add(([System.IO.Path]::GetFullPath($p)).TrimEnd('\'))
    }
  }
  if (-not [string]::IsNullOrWhiteSpace($ProdVaultRoot)) {
    [void]$dangerous.Add(([System.IO.Path]::GetFullPath($ProdVaultRoot)).TrimEnd('\'))
  }

  foreach ($d in $dangerous) {
    if ($full.Equals($d, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Host "[STOP] TestRootが保護対象フォルダそのものです: $full" -ForegroundColor Red
      exit 1
    }
    $dSep = $d + '\'
    $fullSep = $full + '\'
    if ($fullSep.StartsWith($dSep, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Host "[STOP] TestRootが保護対象フォルダの内側です: $full (保護対象: $d)" -ForegroundColor Red
      exit 1
    }
    if ($dSep.StartsWith($fullSep, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Host "[STOP] TestRootが保護対象フォルダを内包する上位フォルダです: $full (保護対象: $d)" -ForegroundColor Red
      exit 1
    }
  }

  $segments = $full.Split('\') | Where-Object { $_ -ne "" }
  if ($segments.Count -lt 3) {
    Write-Host "[STOP] TestRootの階層が浅すぎます(誤操作防止のため最低3階層を要求): $full" -ForegroundColor Red
    exit 1
  }

  return $full
}
$TestRoot = Assert-SafeTestRoot -Path $TestRoot -ProdVaultRoot $ProductionVaultRoot
Record-SafetyCheck "TestRoot絶対パス安全確認" $true "$TestRoot (本番Vault/ドライブルート/危険な上位フォルダのいずれでもないことを確認)"

Write-Host ""
Write-Host "対象スクリプト: $TargetScript"
Write-Host "テスト用Vaultルート: $TestRoot"
Write-Host "PowerShell実行バージョン: $($PSVersionTable.PSVersion.ToString()) ($($PSVersionTable.PSEdition))"
Write-Host ""

if (Test-Path -LiteralPath $TestRoot) {
  Remove-Item -LiteralPath $TestRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $TestRoot -Force | Out-Null

$fixtureFiles = @(Get-ChildItem -LiteralPath $FixtureRoot -File -Recurse)
foreach ($fixtureFile in $fixtureFiles) {
  $fixtureRelativePath = $fixtureFile.FullName.Substring($FixtureRoot.Length + 1)
  $fixtureDestination = Join-Path $TestRoot $fixtureRelativePath
  $fixtureDestinationDirectory = Split-Path -Parent $fixtureDestination
  if (-not (Test-Path -LiteralPath $fixtureDestinationDirectory)) {
    New-Item -ItemType Directory -Path $fixtureDestinationDirectory -Force | Out-Null
  }
  Copy-Item -LiteralPath $fixtureFile.FullName -Destination $fixtureDestination
}

# ===================== ヘルパー関数 =====================

function New-CaseVault([string]$caseName) {
  $caseRoot = Join-Path $TestRoot $caseName
  $custRoot = Join-Path $caseRoot "01_顧客"
  New-Item -ItemType Directory -Path $custRoot -Force | Out-Null
  return $caseRoot
}

function New-Note {
  param(
    [string]$Path,
    [string[]]$HeaderLines,   # frontmatter内側の行(--- は含めない)。$null ならfrontmatterなし。
    [string]$Body = "本文サンプルです。`n変更されないことを確認する対象の本文。",
    [string]$NewlineStyle = "LF"   # LF / CRLF / MIXED
  )
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

  $lines = New-Object System.Collections.Generic.List[string]
  if ($null -ne $HeaderLines) {
    [void]$lines.Add("---")
    foreach ($h in $HeaderLines) { [void]$lines.Add($h) }
    [void]$lines.Add("---")
  }
  foreach ($b in ($Body -split "`n")) { [void]$lines.Add($b) }

  $text = ($lines -join "`n")
  switch ($NewlineStyle) {
    "CRLF" { $text = $text -replace "`n", "`r`n" }
    "MIXED" {
      if ($null -ne $HeaderLines) {
        $hdrPart = ($lines[0..($HeaderLines.Count+1)] -join "`n") -replace "`n", "`r`n"
        $bodyPart = ($lines[($HeaderLines.Count+2)..($lines.Count-1)] -join "`n")
        $text = $hdrPart + "`r`n" + $bodyPart
      }
    }
    default { } # LF そのまま
  }
  [System.IO.File]::WriteAllText($Path, $text, $Utf8NoBom)
}

function Get-Uuid { return [guid]::NewGuid().ToString() }

# ===================== UUID常時正規化(2026-07-29)対応: 正式パス生成ヘルパー =====================
# 対象本体のUUID識別子付き正式命名規則への常時正規化により、社名変更の有無に関わらず
# フォルダ名の末尾にpk_CLIENT先頭8文字の識別子が必ず付与される。管理対象ノート
# (既知の6 noteType接頭辞を持つファイル)も同様に正式名へ変換される。
# 本ハーネスの多くのテストケースは接頭辞なしの単純なファイル名("契約.md"等)を使っており、
# その場合ノート自体はリネームされない(本体仕様どおり)ため、フォルダパスのみ
# 正式名を反映する必要がある。

function Get-TestUuidSuffix {
  param([string]$uuid)
  return "_[" + $uuid.Substring(0,8).ToUpperInvariant() + "]"
}

function Get-TestCanonicalFolderPath {
  # 本体のフォルダ名生成(Sanitize-LeafNameによる素通し、会社種別語の除去は行わない)相当。
  # 本ハーネスで使う会社名はファイルシステム上安全な文字のみのため、素通しで問題ない。
  param([string]$caseRoot, [string]$companyNameRaw, [string]$uuid)
  return Join-Path $caseRoot ("01_顧客\" + $companyNameRaw + (Get-TestUuidSuffix $uuid))
}

# 本体Get-IconPrefixの戻り値と同一の6noteType接頭辞(既知の管理対象ノート判定用)。
$script:TestKnownIconPrefixes = @(
  ([char]::ConvertFromUtf32(0x2721) + [char]::ConvertFromUtf32(0xFE0F) + "一覧"),   # ✡️一覧
  ([char]::ConvertFromUtf32(0x26D4) + "一覧"),                                      # ⛔一覧
  ([char]::ConvertFromUtf32(0x1F7E8) + "契約"),                                     # 🟨契約
  ([char]::ConvertFromUtf32(0x1F7E5) + "事故"),                                     # 🟥事故
  ([char]::ConvertFromUtf32(0x25FB) + [char]::ConvertFromUtf32(0xFE0F) + "決算書"), # ◻️決算書
  ([char]::ConvertFromUtf32(0x2B1B) + "その他")                                     # ⬛その他
)

function Get-TestCanonicalNotePath {
  # 既知の接頭辞で始まる管理対象ノートのみ正式名(接頭辞_正規化会社名_UUID8.md)へ変換する。
  # 接頭辞を認識できないファイル名は本体仕様上リネーム対象外のため、ファイル名は
  # 元のまま・所在フォルダのみ正式名(Get-TestCanonicalFolderPath)を使う。
  param([string]$canonicalFolderPath, [string]$originalFileName, [string]$companyNameRaw, [string]$uuid)
  foreach ($pfx in $script:TestKnownIconPrefixes) {
    if ($originalFileName.StartsWith($pfx + "_")) {
      return Join-Path $canonicalFolderPath ($pfx + "_" + $companyNameRaw + (Get-TestUuidSuffix $uuid) + ".md")
    }
  }
  return Join-Path $canonicalFolderPath $originalFileName
}

function Build-PayloadB64 {
  param([hashtable]$Fields)
  $obj = [ordered]@{}
  foreach ($k in $Fields.Keys) { $obj[$k] = $Fields[$k] }
  $json = ($obj | ConvertTo-Json -Depth 6)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  return @{ Json = $json; B64 = [Convert]::ToBase64String($bytes) }
}

function Invoke-TargetScript {
  param([string]$PayloadB64, [string]$ScriptPath = $TargetScript)
  $outFile = [System.IO.Path]::GetTempFileName()
  $errFile = [System.IO.Path]::GetTempFileName()
  try {
    $p = Start-Process -FilePath $PowerShellExe `
      -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"", "-PayloadB64", "`"$PayloadB64`"") `
      -RedirectStandardOutput $outFile `
      -RedirectStandardError  $errFile `
      -Wait -PassThru -NoNewWindow
    $stdout = Get-Content -LiteralPath $outFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $stderr = Get-Content -LiteralPath $errFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    return @{ ExitCode = $p.ExitCode; Stdout = $stdout; Stderr = $stderr }
  } finally {
    Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
  }
}

function Get-NoteInfo {
  # 独立の簡易YAML読み取り(対象スクリプトの実装から意図的に切り離した検証用リーダー)
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $lines = [System.IO.File]::ReadAllLines($Path, $Utf8NoBom)
  if ($lines.Count -eq 0 -or $lines[0].Trim() -ne "---") {
    return @{ HasFrontmatter = $false; Tags=@(); Uuid=""; Rank=""; Premium=""; NoteType=""; BodyJoined=($lines -join "`n") }
  }
  $endIdx = -1
  for ($i = 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq "---") { $endIdx = $i; break } }
  if ($endIdx -eq -1) { return @{ HasFrontmatter = $true; Broken = $true } }
  $hdr = @()
  if ($endIdx -gt 1) { $hdr = $lines[1..($endIdx-1)] }
  $body = @()
  if ($lines.Count -gt ($endIdx+1)) { $body = $lines[($endIdx+1)..($lines.Count-1)] }

  $tags = New-Object System.Collections.Generic.List[string]
  $inTags = $false
  $uuid=""; $rank=""; $premium=""; $noteType=""
  foreach ($l in $hdr) {
    $t = $l.Trim()
    if ($t -eq "tags:" -or $t.StartsWith("tags:")) { $inTags = $true; continue }
    if ($inTags) {
      if ($l -match "^\s*-\s*(.*)$") {
        $v = $Matches[1].Trim()
        if ($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1,$v.Length-2) }
        [void]$tags.Add($v)
        continue
      } else { $inTags = $false }
    }
    if ($t.StartsWith("UUID:")) { $uuid = $t.Substring(5).Trim() }
    elseif ($t.StartsWith("ランク:")) { $rank = $t.Substring(4).Trim() }
    elseif ($t.StartsWith("総合計保険料:")) { $premium = $t.Substring(7).Trim() }
    elseif ($t.StartsWith("noteType:")) { $noteType = $t.Substring(9).Trim() }
  }
  return @{ HasFrontmatter=$true; Broken=$false; Tags=$tags.ToArray(); Uuid=$uuid; Rank=$rank; Premium=$premium; NoteType=$noteType; BodyJoined=($body -join "`n") }
}

function Test-StdoutPurity {
  param([string]$Stdout)
  if ([string]::IsNullOrWhiteSpace($Stdout)) { return @{ Ok=$false; Reason="stdoutが空"; Obj=$null } }
  $trimmed = $Stdout.Trim()
  if ($trimmed -match "^OK\||^NG\|") { return @{ Ok=$false; Reason="旧PIPE形式が混入している"; Obj=$null } }
  try {
    $obj = $trimmed | ConvertFrom-Json
  } catch {
    return @{ Ok=$false; Reason="JSONとして解析できない: $($_.Exception.Message)"; Obj=$null }
  }
  if ($obj -is [System.Array]) { return @{ Ok=$false; Reason="JSONが配列(複数)になっている"; Obj=$null } }
  return @{ Ok=$true; Reason=""; Obj=$obj }
}

function New-InjectedRollbackCopy {
  # ロールバック試験専用: 対象スクリプトの「一時的な使い捨てコピー」を作り、
  # Update-Yaml-Robust による書込みが成功した直後・再読込確認より前に
  # 例外をthrowする1行だけを挿入する。対象スクリプト本体には一切触れない。
  param([string]$OriginalPath, [string]$DestPath)

  $bytes = [System.IO.File]::ReadAllBytes($OriginalPath)
  $text = [System.Text.Encoding]::UTF8.GetString($bytes)
  if ($text.Length -gt 0 -and [int]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }

  $marker = 'Update-Yaml-Robust $pair.newPath $rank $companyNameRaw $ceo $ruby $pkClient $premiumToPass'
  $idx1 = $text.IndexOf($marker, [System.StringComparison]::Ordinal)
  if ($idx1 -lt 0) {
    throw "注入アンカー行が見つかりません。対象スクリプトの該当行が変更された可能性があります: $marker"
  }
  $idx2 = $text.IndexOf($marker, $idx1 + 1, [System.StringComparison]::Ordinal)
  if ($idx2 -ge 0) {
    throw "注入アンカー行が複数一致しました(一意でない)。安全のため注入を中止します。"
  }

  $insertPos = $idx1 + $marker.Length
  # $updatedCount は「これまでに完全成功したノート数」。1件目の処理が完全成功した直後、
  # 2件目のノートに対して Update-Yaml-Robust の書込みが完了した「直後」・再読込確認より前に
  # throw する(=書込み成功後・検証前の失敗を模擬する)。
  $injection = "`n      if (`$updatedCount -eq 1) { throw `"UCI_TEST_INJECTED_FAILURE_AFTER_WRITE`" }  # [TEST-ONLY INJECTION by Run-UCITests.ps1]"
  $newText = $text.Substring(0, $insertPos) + $injection + $text.Substring($insertPos)

  $dir = Split-Path $DestPath -Parent
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  [System.IO.File]::WriteAllText($DestPath, $newText, $Utf8Bom)
}

# ===================== 個別テストケース(正常系) =====================

function Test-01-CustomerNameChange {
  $case = New-CaseVault "Case01_CustomerNameChange"
  $uuid = Get-Uuid
  $oldFolder = "株式会社旧名称テストA"
  $notePath = Join-Path $case "01_顧客\$oldFolder\契約一覧.md"
  New-Note -Path $notePath -HeaderLines @(
    'tags:', '  - "株式会社旧名称テストA"', '  - "代表太郎"', "UUID: $uuid", 'ランク: B'
  )
  $pay = Build-PayloadB64 @{
    action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid)
    VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw="株式会社新名称テストA"; CEO="代表太郎"; RUBY=""; RANK="B"
  }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "01_顧客名変更+フォルダリネーム" $false $purity.Reason $r; return }
  $o = $purity.Obj
  # 期待値更新(2026-07-29c、UUID識別子付き正式命名規則への常時正規化により、
  # フォルダ名は社名変更の有無に関わらずpk_CLIENT先頭8文字の識別子が末尾へ付与される。
  # これは実装バグではなく、命名規則自体の正当な仕様変更のため期待値側を更新する)。
  $uuidSuffix = "_[" + $uuid.Substring(0,8).ToUpperInvariant() + "]"
  $newFolder = Join-Path $case ("01_顧客\株式会社新名称テストA" + $uuidSuffix)
  $pass = ($o.status -eq "OK") -and ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($o.folderRenamed -eq $true) -and (Test-Path -LiteralPath $newFolder) -and (-not (Test-Path -LiteralPath (Join-Path $case "01_顧客\$oldFolder")))
  Record-Result "01_顧客名変更+フォルダリネーム" $pass "code=$($o.code) folderRenamed=$($o.folderRenamed) newFolderExists=$(Test-Path -LiteralPath $newFolder)" $r
}

function Test-02-CeoChange {
  $case = New-CaseVault "Case02_CeoChange"
  $uuid = Get-Uuid
  $folder = "株式会社CEO変更テスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", '  - "旧代表"', "UUID: $uuid", 'ランク: C')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO="新代表"; RUBY=""; RANK="C" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "02_代表者名変更" $false $purity.Reason $r; return }
  $o = $purity.Obj
  # UUID常時正規化対応: 社名変更なしでもフォルダ名にUUID接尾辞が付与されるため、
  # 正式フォルダパス配下でノートを参照する(ノート自体は接頭辞なしのためリネームされない)。
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $newNotePath = Get-TestCanonicalNotePath $newFolder "契約.md" $folder $uuid
  $info = Get-NoteInfo $newNotePath
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($info.Tags -contains "新代表") -and (-not ($info.Tags -contains "旧代表"))
  Record-Result "02_代表者名変更" $pass "code=$($o.code) tags=$($info.Tags -join ',')" $r
}

function Test-03-RubyChange {
  $case = New-CaseVault "Case03_RubyChange"
  $uuid = Get-Uuid
  $folder = "株式会社RUBYテスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY="ﾃｽﾄﾙﾋﾞ"; RANK="A" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "03_RUBY変更" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $newNotePath = Get-TestCanonicalNotePath $newFolder "契約.md" $folder $uuid
  $info = Get-NoteInfo $newNotePath
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($info.Tags -contains "ﾃｽﾄﾙﾋﾞ")
  Record-Result "03_RUBY変更" $pass "code=$($o.code) tags=$($info.Tags -join ',')" $r
}

function Test-04-RankChange {
  $case = New-CaseVault "Case04_RankChange"
  $uuid = Get-Uuid
  $folder = "株式会社RANKテスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: 旧C')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="新S" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "04_RANK変更" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $newNotePath = Get-TestCanonicalNotePath $newFolder "契約.md" $folder $uuid
  $info = Get-NoteInfo $newNotePath
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($info.Rank -eq "新S")
  Record-Result "04_RANK変更" $pass "code=$($o.code) rank=$($info.Rank)" $r
}

function Test-05-MultipleNotes {
  $case = New-CaseVault "Case05_MultipleNotes"
  $uuid = Get-Uuid
  $folder = "株式会社複数ノートテスト"
  $p1 = Join-Path $case "01_顧客\$folder\契約一覧.md"
  $p2 = Join-Path $case "01_顧客\$folder\契約.md"
  $p3 = Join-Path $case "01_顧客\$folder\事故一覧.md"
  foreach ($p in @($p1,$p2,$p3)) { New-Note -Path $p -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: X') }
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="Y" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "05_複数UUID一致ノート更新" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $allUpdated = @("契約一覧.md","契約.md","事故一覧.md") | ForEach-Object {
    (Get-NoteInfo (Get-TestCanonicalNotePath $newFolder $_ $folder $uuid)).Rank -eq "Y"
  }
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($o.updatedFiles -eq 3) -and (($allUpdated -notcontains $false))
  Record-Result "05_複数UUID一致ノート更新" $pass "code=$($o.code) updatedFiles=$($o.updatedFiles)" $r
}

function Test-06-PremiumPreserved {
  $case = New-CaseVault "Case06_PremiumPreserved"
  $uuid = Get-Uuid
  $folder = "株式会社保険料保持テスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約一覧.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A', '総合計保険料: 1234567')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "06_総合計保険料保持" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $newNotePath = Get-TestCanonicalNotePath $newFolder "契約一覧.md" $folder $uuid
  $info = Get-NoteInfo $newNotePath
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($info.Premium -eq "1234567")
  Record-Result "06_総合計保険料保持" $pass "code=$($o.code) premium=$($info.Premium)" $r
}

function Test-07-NoteTypePreserved {
  $case = New-CaseVault "Case07_NoteTypePreserved"
  $uuid = Get-Uuid
  $folder = "株式会社noteType保持テスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A', 'noteType: 顧客情報')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "07_noteTypeありの保持" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $newNotePath = Get-TestCanonicalNotePath $newFolder "契約.md" $folder $uuid
  $info = Get-NoteInfo $newNotePath
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($info.NoteType -eq "顧客情報")
  Record-Result "07_noteTypeありの保持" $pass "code=$($o.code) noteType=$($info.NoteType)" $r
}

function Test-08-NoteTypeNotAdded {
  $case = New-CaseVault "Case08_NoteTypeNotAdded"
  $uuid = Get-Uuid
  $folder = "株式会社noteType非追加テスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "08_noteTypeなしの非追加" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
  $newNotePath = Get-TestCanonicalNotePath $newFolder "契約.md" $folder $uuid
  $info = Get-NoteInfo $newNotePath
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ([string]::IsNullOrEmpty($info.NoteType))
  Record-Result "08_noteTypeなしの非追加" $pass "code=$($o.code) noteType='$($info.NoteType)'" $r
}

function Test-09-AuxNoteUnchanged {
  $case = New-CaseVault "Case09_AuxNoteUnchanged"
  $uuid = Get-Uuid
  $folder = "株式会社補助ノートテスト"
  $mainPath = Join-Path $case "01_顧客\$folder\契約.md"
  $auxPath  = Join-Path $case "01_顧客\$folder\補助メモ.md"
  New-Note -Path $mainPath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  New-Note -Path $auxPath -HeaderLines $null -Body "補助メモの本文。UUIDキーなし。更新されないはず。"
  $auxBefore = [System.IO.File]::ReadAllBytes($auxPath)
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw="株式会社補助ノート新名称"; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "09_UUIDなし補助ノート不変" $false $purity.Reason $r; return }
  $o = $purity.Obj
  $newFolder = Get-TestCanonicalFolderPath $case "株式会社補助ノート新名称" $uuid
  $newAuxPath = Join-Path $newFolder "補助メモ.md"
  $auxAfter = if (Test-Path -LiteralPath $newAuxPath) { [System.IO.File]::ReadAllBytes($newAuxPath) } else { $null }
  $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and ($null -ne $auxAfter) -and ([System.Convert]::ToBase64String($auxBefore) -eq [System.Convert]::ToBase64String($auxAfter))
  Record-Result "09_UUIDなし補助ノート不変" $pass "code=$($o.code) auxMovedWithFolder=$($null -ne $auxAfter) byteIdentical=$($pass)" $r
}

function Test-10-NoChangeRerun {
  $case = New-CaseVault "Case10_NoChangeRerun"
  $uuid = Get-Uuid
  $folder = "株式会社NOCHANGEテスト"
  $notePath = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  $fields = @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="A" }
  $pay1 = Build-PayloadB64 $fields
  $r1 = Invoke-TargetScript $pay1.B64
  $fields.requestId = (Get-Uuid)
  $pay2 = Build-PayloadB64 $fields
  $r2 = Invoke-TargetScript $pay2.B64
  $purity1 = Test-StdoutPurity $r1.Stdout
  $purity2 = Test-StdoutPurity $r2.Stdout
  if (-not $purity1.Ok -or -not $purity2.Ok) { Record-Result "10_NO_CHANGE再実行" $false "purity1=$($purity1.Reason) purity2=$($purity2.Reason)" @{r1=$r1;r2=$r2}; return }
  $pass = ($purity2.Obj.code -eq "NO_CHANGE") -and ($purity2.Obj.updatedFiles -eq 0) -and ($purity2.Obj.folderRenamed -eq $false)
  Record-Result "10_NO_CHANGE再実行" $pass "1回目code=$($purity1.Obj.code) 2回目code=$($purity2.Obj.code)" @{r1=$r1;r2=$r2}
}

# ===================== 個別テストケース(異常系) =====================

function Test-11-CustomerNotFound {
  $case = New-CaseVault "Case11_CustomerNotFound"
  New-Item -ItemType Directory -Path (Join-Path $case "01_顧客\ダミー") -Force | Out-Null
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=(Get-Uuid); companyNameRaw="存在しない会社"; CEO=""; RUBY=""; RANK="" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "11_CUSTOMER_NOT_FOUND" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "CUSTOMER_NOT_FOUND")
  Record-Result "11_CUSTOMER_NOT_FOUND" $pass "code=$($purity.Obj.code)" $r
}

function Test-12-UuidFolderConflict {
  $case = New-CaseVault "Case12_UuidFolderConflict"
  $uuid = Get-Uuid
  New-Note -Path (Join-Path $case "01_顧客\会社A\契約.md") -HeaderLines @('tags:', '  - "会社A"', "UUID: $uuid", 'ランク: A')
  New-Note -Path (Join-Path $case "01_顧客\会社B\契約.md") -HeaderLines @('tags:', '  - "会社B"', "UUID: $uuid", 'ランク: A')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw="会社統合後"; CEO=""; RUBY=""; RANK="A" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "12_UUID_FOLDER_CONFLICT" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "UUID_FOLDER_CONFLICT")
  Record-Result "12_UUID_FOLDER_CONFLICT" $pass "code=$($purity.Obj.code)" $r
}

function Test-13-FolderUuidMixed {
  $case = New-CaseVault "Case13_FolderUuidMixed"
  $uuid = Get-Uuid
  $other = Get-Uuid
  $folder = "株式会社混在テスト"
  New-Note -Path (Join-Path $case "01_顧客\$folder\契約.md") -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  New-Note -Path (Join-Path $case "01_顧客\$folder\別顧客.md") -HeaderLines @('tags:', '  - "別顧客"', "UUID: $other", 'ランク: A')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "13_FOLDER_UUID_MIXED" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "FOLDER_UUID_MIXED")
  Record-Result "13_FOLDER_UUID_MIXED" $pass "code=$($purity.Obj.code)" $r
}

function Test-14-InvalidYamlUnclosed {
  $case = New-CaseVault "Case14_InvalidYamlUnclosed"
  $uuid = Get-Uuid
  $folder = "株式会社YAML破損テスト"
  New-Note -Path (Join-Path $case "01_顧客\$folder\契約.md") -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  $brokenPath = Join-Path $case "01_顧客\$folder\破損ノート.md"
  [System.IO.File]::WriteAllText($brokenPath, "---`ntags:`n  - test`n本文がここに来てしまいfrontmatterが閉じていない", $Utf8NoBom)
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "14_YAML_BODY_BOUNDARY_UNRESOLVED(未クローズ)" $false $purity.Reason $r; return }
  # 期待値更新(2026-07-29、YAML修復ポリシー変更により、本文境界が判定できないケースの
  # コードはINVALID_YAMLからYAML_BODY_BOUNDARY_UNRESOLVEDへ変更された。実装バグではなく
  # 仕様変更のため期待値側を更新する)。
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "YAML_BODY_BOUNDARY_UNRESOLVED")
  Record-Result "14_YAML_BODY_BOUNDARY_UNRESOLVED(未クローズ)" $pass "code=$($purity.Obj.code)" $r
}

function Test-15-InvalidYamlBadUuid {
  $case = New-CaseVault "Case15_InvalidYamlBadUuid"
  $uuid = Get-Uuid
  $folder = "株式会社UUID形式不正テスト"
  New-Note -Path (Join-Path $case "01_顧客\$folder\契約.md") -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  New-Note -Path (Join-Path $case "01_顧客\$folder\不正UUIDノート.md") -HeaderLines @('tags:', '  - "test"', 'UUID: 12345-not-a-uuid', 'ランク: A')
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "15_UUID形式不正ノートの修復継続" $false $purity.Reason $r; return }
  # 期待値更新(2026-07-29、YAML修復ポリシー変更により、本文境界が確定できるYAML形式不正
  # ノートは無条件停止ではなくFileMaker権威値での修復対象となり、他に有効なUUID一致ノートが
  # 同一フォルダにあるため処理は継続・成功する。実装バグではなく仕様変更のため期待値を更新する)。
  $pass = ($purity.Obj.status -eq "OK") -and ($purity.Obj.code -eq "CUSTOMER_IDENTITY_UPDATED")
  Record-Result "15_UUID形式不正ノートの修復継続" $pass "code=$($purity.Obj.code)" $r
}

function Test-16-InvalidUuidPkClient {
  $case = New-CaseVault "Case16_InvalidUuidPkClient"
  New-Item -ItemType Directory -Path (Join-Path $case "01_顧客") -Force | Out-Null
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT="not-a-valid-uuid"; companyNameRaw="会社名"; CEO=""; RUBY=""; RANK="" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "16_INVALID_UUID(pk_CLIENT)" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "INVALID_UUID")
  Record-Result "16_INVALID_UUID(pk_CLIENT)" $pass "code=$($purity.Obj.code)" $r
}

function Test-17-TargetFolderAlreadyExists {
  $case = New-CaseVault "Case17_TargetFolderAlreadyExists"
  $uuid = Get-Uuid
  New-Note -Path (Join-Path $case "01_顧客\旧フォルダ\契約.md") -HeaderLines @('tags:', '  - "旧フォルダ"', "UUID: $uuid", 'ランク: A')
  # UUID常時正規化対応: 実際の変更先は"新フォルダ"+UUID接尾辞になるため、
  # 衝突させたい対象フォルダも同じ接尾辞付きの名前で事前作成する必要がある。
  $conflictFolder = Get-TestCanonicalFolderPath $case "新フォルダ" $uuid
  New-Item -ItemType Directory -Path $conflictFolder -Force | Out-Null
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw="新フォルダ"; CEO=""; RUBY=""; RANK="B" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "17_TARGET_FOLDER_ALREADY_EXISTS" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "TARGET_FOLDER_ALREADY_EXISTS")
  Record-Result "17_TARGET_FOLDER_ALREADY_EXISTS" $pass "code=$($purity.Obj.code)" $r
}

function Test-18-ProtocolVersionString {
  $case = New-CaseVault "Case18_ProtocolVersionString"
  New-Item -ItemType Directory -Path (Join-Path $case "01_顧客") -Force | Out-Null
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion="1"; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=(Get-Uuid); companyNameRaw="会社名"; CEO=""; RUBY=""; RANK="" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "18_protocolVersion文字列1拒否" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "UNSUPPORTED_PROTOCOL_VERSION")
  Record-Result "18_protocolVersion文字列1拒否" $pass "code=$($purity.Obj.code)" $r
}

function Test-19-RequestIdNumber {
  $case = New-CaseVault "Case19_RequestIdNumber"
  New-Item -ItemType Directory -Path (Join-Path $case "01_顧客") -Force | Out-Null
  $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=12345; VaultRoot=$case; pk_CLIENT=(Get-Uuid); companyNameRaw="会社名"; CEO=""; RUBY=""; RANK="" }
  $r = Invoke-TargetScript $pay.B64
  $purity = Test-StdoutPurity $r.Stdout
  if (-not $purity.Ok) { Record-Result "19_requestId数値拒否" $false $purity.Reason $r; return }
  $pass = ($purity.Obj.status -eq "NG") -and ($purity.Obj.code -eq "MISSING_REQUIRED_FIELD")
  Record-Result "19_requestId数値拒否" $pass "code=$($purity.Obj.code)" $r
}

# ===================== ロールバック重点試験 =====================

function Test-20-RollbackOnWriteFailure {
  $case = New-CaseVault "Case20_Rollback"
  $uuid = Get-Uuid
  $folder = "株式会社ロールバックテスト"
  $p1 = Join-Path $case "01_顧客\$folder\契約一覧.md"
  $p2 = Join-Path $case "01_顧客\$folder\契約.md"
  New-Note -Path $p1 -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  New-Note -Path $p2 -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A')
  $before1 = [System.IO.File]::ReadAllBytes($p1)
  $before2 = [System.IO.File]::ReadAllBytes($p2)

  # 「読み取り専用属性で書込み自体を失敗させる」方式ではなく、テスト専用の一時コピーに
  # 「書込み成功後・再読込確認より前」に例外をthrowする1行だけを注入する方式に変更。
  # 対象スクリプト本体(FM-Obsidian-Bridge-Payload.ps1)は一切書き換えない。
  $injectedDir = Join-Path $TestRoot "_InjectedCopy_Case20"
  $injectedScript = Join-Path $injectedDir "FM-Obsidian-Bridge-Payload.TESTCOPY.ps1"
  $cleanupOk = $true
  $r = $null
  $purity = $null
  $injectErr = $null
  try {
    New-Item -ItemType Directory -Path $injectedDir -Force | Out-Null
    New-InjectedRollbackCopy -OriginalPath $TargetScript -DestPath $injectedScript

    $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw="株式会社ロールバック後名称"; CEO=""; RUBY=""; RANK="Z" }
    $r = Invoke-TargetScript -PayloadB64 $pay.B64 -ScriptPath $injectedScript
    $purity = Test-StdoutPurity $r.Stdout
  } catch {
    $injectErr = $_.Exception.Message
  } finally {
    if (Test-Path -LiteralPath $injectedDir) {
      try { Remove-Item -LiteralPath $injectedDir -Recurse -Force -ErrorAction Stop }
      catch { $cleanupOk = $false }
    }
  }
  if (Test-Path -LiteralPath $injectedDir) { $cleanupOk = $false }
  Record-SafetyCheck "テスト専用コピー(失敗注入版)の削除確認(Case20直後)" $cleanupOk "$injectedDir が残存していないこと"

  if ($null -ne $injectErr) {
    Record-Result "20_ロールバック(書込み成功後・検証前のthrow注入)" $false "注入用コピー作成に失敗: $injectErr" $null
    return
  }
  if ($null -eq $purity -or -not $purity.Ok) {
    $reason = if ($null -ne $purity) { $purity.Reason } else { "テスト専用コピー実行結果が取得できなかった" }
    Record-Result "20_ロールバック(書込み成功後・検証前のthrow注入)" $false $reason $r
    return
  }
  $o = $purity.Obj
  $oldFolderPath = Join-Path $case "01_顧客\$folder"
  $folderRestored = Test-Path -LiteralPath $oldFolderPath
  $p1After = if (Test-Path -LiteralPath $p1) { [System.IO.File]::ReadAllBytes($p1) } else { $null }
  $p2After = if (Test-Path -LiteralPath $p2) { [System.IO.File]::ReadAllBytes($p2) } else { $null }
  $note1Restored = ($null -ne $p1After) -and ([Convert]::ToBase64String($p1After) -eq [Convert]::ToBase64String($before1))
  $note2Restored = ($null -ne $p2After) -and ([Convert]::ToBase64String($p2After) -eq [Convert]::ToBase64String($before2))
  $pass = ($o.status -eq "NG") -and ($o.code -eq "NOTE_UPDATE_FAILED") -and $folderRestored -and $note1Restored -and $note2Restored -and $cleanupOk
  Record-Result "20_ロールバック(書込み成功後・検証前のthrow注入)" $pass "code=$($o.code) folderRestored=$folderRestored note1Restored=$note1Restored note2Restored=$note2Restored テスト専用コピー削除=$cleanupOk" $r
}

# ===================== 改行コード試験 =====================

function Test-21-LineEndings {
  foreach ($style in @("LF","CRLF","MIXED")) {
    $case = New-CaseVault "Case21_LineEnding_$style"
    $uuid = Get-Uuid
    $folder = "株式会社改行$style"
    $notePath = Join-Path $case "01_顧客\$folder\契約.md"
    New-Note -Path $notePath -HeaderLines @('tags:', "  - `"$folder`"", "UUID: $uuid", 'ランク: A') -Body "1行目本文`n2行目本文`n3行目 日本語テキスト確認" -NewlineStyle $style
    $beforeInfo = Get-NoteInfo $notePath
    $pay = Build-PayloadB64 @{ action="UPDATE_CUSTOMER_IDENTITY"; protocolVersion=1; requestId=(Get-Uuid); VaultRoot=$case; pk_CLIENT=$uuid; companyNameRaw=$folder; CEO=""; RUBY=""; RANK="B" }
    $r = Invoke-TargetScript $pay.B64
    $purity = Test-StdoutPurity $r.Stdout
    if (-not $purity.Ok) { Record-Result "21_改行コード($style)" $false $purity.Reason $r; continue }
    $o = $purity.Obj
    $newFolder = Get-TestCanonicalFolderPath $case $folder $uuid
    $newNotePath = Get-TestCanonicalNotePath $newFolder "契約.md" $folder $uuid
    $afterInfo = Get-NoteInfo $newNotePath
    $bodyMatch = ($beforeInfo.BodyJoined -eq $afterInfo.BodyJoined)  # 行内容(改行種別を問わない)の一致
    $rawBytes = [System.IO.File]::ReadAllBytes($newNotePath)
    $hasCRLF = ($rawBytes -join ",") -match "13,10"
    $pass = ($o.code -eq "CUSTOMER_IDENTITY_UPDATED") -and $bodyMatch
    Record-Result "21_改行コード($style)" $pass "code=$($o.code) 本文文字内容一致=$bodyMatch 更新後CRLF検出=$hasCRLF(既知動作として許容)" $r
  }
}

# ===================== 構文確認 =====================
function Invoke-SyntaxCheck([string]$path, [string]$label) {
  $errors = $null
  $tokens = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
  $count = @($errors).Count
  $ok = ($count -eq 0)
  Record-Result "構文確認_$label" $ok "ParseError件数=$count $(if ($count -gt 0) { ($errors | ForEach-Object { $_.Message }) -join ' / ' })" $errors "Syntax"
  return $ok
}

# ===================== 終了時整合性確認 =====================
function Assert-FinalIntegrity {
  param([string]$TargetPath, [string]$ExpectedSha256, [string]$TestRootPath)

  $actualHash = (Get-FileHash -LiteralPath $TargetPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $expected = $ExpectedSha256.ToLowerInvariant()
  $hashOk = ($actualHash -eq $expected)
  Record-SafetyCheck "対象PowerShell本体のSHA256不変確認(終了時)" $hashOk "期待値=$expected / 実測値=$actualHash"

  $leftover = @(Get-ChildItem -LiteralPath $TestRootPath -Directory -Filter "_InjectedCopy*" -Recurse -ErrorAction SilentlyContinue)
  $cleanupOk = ($leftover.Count -eq 0)
  Record-SafetyCheck "テスト専用コピー(失敗注入版)の最終残存確認" $cleanupOk "残存フォルダ数=$($leftover.Count)"

  return ($hashOk -and $cleanupOk)
}

# ===================== 集計・レポート出力(関数化: 構文エラーによる早期停止時にも呼べるようにする) =====================
function Write-FinalReport {
  param([bool]$IntegrityOk = $true)

  $funcResults = @($script:Results | Where-Object { $_.Category -eq "Functional" })
  $syntaxResults = @($script:Results | Where-Object { $_.Category -eq "Syntax" })
  $funcTotal = $funcResults.Count
  $syntaxTotal = $syntaxResults.Count
  $total = $script:Results.Count
  $passCount = @($script:Results | Where-Object { $_.Pass }).Count
  $failCount = $total - $passCount

  # 件数確認自体を安全確認の1項目として記録する(警告表示のみで終わらせない)
  $countOk = ($total -eq 24 -and $funcTotal -eq 23 -and $syntaxTotal -eq 1)
  Record-SafetyCheck "テスト件数確認(機能23+構文1=総24)" $countOk "実測=機能${funcTotal}/構文${syntaxTotal}/総${total}"

  $safetyTotal = $script:SafetyChecks.Count
  $safetyPass = @($script:SafetyChecks | Where-Object { $_.Pass }).Count
  $safetyFail = $safetyTotal - $safetyPass

  Write-Host ""
  Write-Host "=====================================================" -ForegroundColor Cyan
  Write-Host "件数: 機能テスト${funcTotal}件 + 構文確認${syntaxTotal}件 = 総${total}結果" -ForegroundColor Cyan
  if (-not $countOk) {
    Write-Host "[警告] 想定件数(機能テスト23件+構文確認1件=総24結果)と一致しません。テスト構成を確認してください。" -ForegroundColor Yellow
  }
  Write-Host "総合結果: $passCount / $total PASS ($failCount FAIL)" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
  Write-Host "安全確認: $safetyPass / $safetyTotal PASS ($safetyFail FAIL) ※24件のカウントには含まない" -ForegroundColor $(if ($safetyFail -eq 0) { "Green" } else { "Red" })
  Write-Host "=====================================================" -ForegroundColor Cyan

  $reportPath = Join-Path $TestRoot "_report.txt"
  $jsonPath = Join-Path $TestRoot "_report.json"

  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add("UPDATE_CUSTOMER_IDENTITY Windows PowerShell 5.1 実行検証レポート")
  [void]$lines.Add("実行日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
  [void]$lines.Add("PowerShellバージョン: $($PSVersionTable.PSVersion.ToString()) ($($PSVersionTable.PSEdition))")
  [void]$lines.Add("対象スクリプト: $TargetScript")
  [void]$lines.Add("件数: 機能テスト${funcTotal}件 + 構文確認${syntaxTotal}件 = 総${total}結果")
  [void]$lines.Add("結果: $passCount / $total PASS ($failCount FAIL)")
  [void]$lines.Add("安全確認: $safetyPass / $safetyTotal PASS ($safetyFail FAIL) ※24件のカウントには含まない")
  if ($total -lt 24) {
    [void]$lines.Add("注記: 構文エラー等により機能テストを開始せず早期停止した可能性があります(総結果件数が24未満)。")
  }
  [void]$lines.Add("")
  [void]$lines.Add("--- 機能テスト・構文確認 ---")
  foreach ($res in $script:Results) {
    $mark = if ($res.Pass) { "PASS" } else { "FAIL" }
    [void]$lines.Add("[$mark][$($res.Category)] $($res.Name)")
    [void]$lines.Add("    詳細: $($res.Detail)")
  }
  [void]$lines.Add("")
  [void]$lines.Add("--- 安全確認(24件のカウント外) ---")
  foreach ($res in $script:SafetyChecks) {
    $mark = if ($res.Pass) { "PASS" } else { "FAIL" }
    [void]$lines.Add("[$mark] $($res.Name)")
    [void]$lines.Add("    詳細: $($res.Detail)")
  }
  [System.IO.File]::WriteAllText($reportPath, ($lines -join "`r`n"), $Utf8NoBom)

  $reportObj = [ordered]@{
    functionalAndSyntax = $script:Results
    safetyChecks = $script:SafetyChecks
    summary = [ordered]@{
      funcTotal = $funcTotal; syntaxTotal = $syntaxTotal; total = $total
      passCount = $passCount; failCount = $failCount
      safetyTotal = $safetyTotal; safetyPass = $safetyPass; safetyFail = $safetyFail
      countOk = $countOk; integrityOk = $IntegrityOk
    }
  }
  ($reportObj | ConvertTo-Json -Depth 6) | Out-File -LiteralPath $jsonPath -Encoding utf8

  Write-Host ""
  Write-Host "詳細レポート: $reportPath"
  Write-Host "JSON: $jsonPath"

  if ($failCount -gt 0 -or $safetyFail -gt 0 -or -not $IntegrityOk -or -not $countOk) { return 1 }
  return 0
}

# ===================== 実行 =====================
Write-Host "=== 構文確認 ===" -ForegroundColor Cyan
$syntaxOk = Invoke-SyntaxCheck $TargetScript "対象スクリプト(FM-Obsidian-Bridge-Payload.ps1)"

if (-not $syntaxOk) {
  # 停止条件(再起動プロンプト確定事項): Windows PowerShell 5.1パーサーで構文エラーが
  # 1件でもあれば、機能テストを開始せず停止する。ここで即座に停止し、後続23件の
  # 機能テストへは一切進まない(同じ構文エラー由来の連続FAILと機能試験結果が混在するのを防ぐ)。
  Write-Host ""
  Write-Host "[STOP] 対象PowerShellに構文エラーがあるため、機能テストを開始しません。" -ForegroundColor Red
  Write-Host ""
  Write-Host "=== 終了時整合性確認 ===" -ForegroundColor Cyan
  $integrityOk = Assert-FinalIntegrity -TargetPath $TargetScript -ExpectedSha256 $ExpectedTargetSha256 -TestRootPath $TestRoot
  [void](Write-FinalReport -IntegrityOk $integrityOk)
  exit 1
}

Write-Host ""
Write-Host "=== 正常系テスト ===" -ForegroundColor Cyan
Test-01-CustomerNameChange
Test-02-CeoChange
Test-03-RubyChange
Test-04-RankChange
Test-05-MultipleNotes
Test-06-PremiumPreserved
Test-07-NoteTypePreserved
Test-08-NoteTypeNotAdded
Test-09-AuxNoteUnchanged
Test-10-NoChangeRerun

Write-Host ""
Write-Host "=== 異常系テスト ===" -ForegroundColor Cyan
Test-11-CustomerNotFound
Test-12-UuidFolderConflict
Test-13-FolderUuidMixed
Test-14-InvalidYamlUnclosed
Test-15-InvalidYamlBadUuid
Test-16-InvalidUuidPkClient
Test-17-TargetFolderAlreadyExists
Test-18-ProtocolVersionString
Test-19-RequestIdNumber

Write-Host ""
Write-Host "=== ロールバック重点試験 ===" -ForegroundColor Cyan
Test-20-RollbackOnWriteFailure

Write-Host ""
Write-Host "=== 改行コード試験 ===" -ForegroundColor Cyan
Test-21-LineEndings

Write-Host ""
Write-Host "=== 終了時整合性確認 ===" -ForegroundColor Cyan
$integrityOk = Assert-FinalIntegrity -TargetPath $TargetScript -ExpectedSha256 $ExpectedTargetSha256 -TestRootPath $TestRoot

# ===================== 集計・レポート出力 =====================
$exitCode = Write-FinalReport -IntegrityOk $integrityOk
exit $exitCode
