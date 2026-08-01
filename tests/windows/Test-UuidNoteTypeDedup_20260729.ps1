<#
Test-UuidNoteTypeDedup_20260729.ps1

目的:
社名変更後の重複ノート作成防止のため FM-Obsidian-Bridge-Payload.ps1 へ追加した
Get-UuidNoteTypeMatches 関数、および legacy CHECK の $existing フォルダ解決ブロックへの
UUID+noteType優先解決ロジックを、実際のWindows PowerShell 5.1環境・実ファイルI/Oで検証する。

このテストは対象.ps1ファイルから実際の関数定義をそのまま抽出して実行するため、
手動で書き写した再現コードではなく、実際に適用された修正コードそのものを検証する。
本番Vault・FileMaker・Obsidianの起動は一切不要。一時ディレクトリのみを使用する。

対象ファイル:
<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1
#>

[CmdletBinding()]
param(
  [string]$RepositoryRoot = "",
  [string]$TargetScript = "",
  [string]$TestRoot = ""
)

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
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
  $TestRoot = Join-Path $env:TEMP ("uci_notetype_test_" + [Guid]::NewGuid().ToString("N").Substring(0,8))
} else {
  $TestRoot = [System.IO.Path]::GetFullPath($TestRoot)
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Output "[FAIL] 対象スクリプトが見つかりません: $TargetScript"
  exit 1
}

$scriptText = Get-Content -LiteralPath $TargetScript -Raw -Encoding UTF8

# ---- 1. 回帰修正マーカーの存在確認 ----
if ($scriptText -notmatch [regex]::Escape("重複ノート作成防止(2026-07-29回帰修正)")) {
  Write-Output "[FAIL] 対象スクリプトに重複ノート作成防止の修正マーカーが見つかりません。"
  exit 1
}
Write-Output "[OK] 修正マーカーを確認しました。"

# ---- 2. 対象ファイルから既存の共通関数と新規関数をそのまま抽出して読み込む ----
function Extract-Function([string]$text, [string]$funcName) {
  $pattern = "(?ms)^function\s+$funcName\s*\([^\)]*\)\s*\{.*?\n\}"
  $m = [regex]::Match($text, $pattern)
  if (-not $m.Success) { throw "関数 $funcName を抽出できませんでした。" }
  return $m.Value
}

$funcNames = @("Get-YamlHeaderLines","Get-YamlScalarValue","Get-UuidNoteTypeMatches","Sanitize-LeafName")
foreach ($fn in $funcNames) {
  $code = Extract-Function $scriptText $fn
  Invoke-Expression $code
  Write-Output "[OK] $fn を対象ファイルから抽出・ロードしました。"
}

# ---- 3. テスト用一時Vault ----
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Write-Output "テスト用一時ディレクトリ: $testRoot"

function New-TestNote([string]$folder, [string]$fileName, [string]$uuid) {
  if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
  $path = Join-Path $folder $fileName
  $content = "---`ntags:`n  - `"テスト`"`nUUID: $uuid`nランク: A`n---`n本文サンプル`n"
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
  return $path
}

$UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
$UUID_B = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

$results = New-Object System.Collections.ArrayList
function Add-Result([string]$name, [bool]$pass, [string]$detail = "") {
  [void]$script:results.Add([pscustomobject]@{ Case = $name; Pass = $pass; Detail = $detail })
}

# Case 1
$f1 = Join-Path $testRoot "新顧客名"
New-TestNote $f1 "🟨契約_旧顧客名.md" $UUID_A | Out-Null
$m1 = Get-UuidNoteTypeMatches $f1 "🟨契約" $UUID_A
Add-Result "Case1_1件一致_旧名採用" ($m1.Count -eq 1 -and $m1[0] -like "*🟨契約_旧顧客名.md") "matches=$($m1.Count)"
Add-Result "Case1_新規ファイル未作成" (-not (Test-Path (Join-Path $f1 "🟨契約_新顧客名.md")))

# Case 2
$f2 = Join-Path $testRoot "複数種別顧客"
New-TestNote $f2 "🟨契約_旧複数種別顧客.md" $UUID_A | Out-Null
New-TestNote $f2 "🟥事故_旧複数種別顧客.md" $UUID_A | Out-Null
New-TestNote $f2 "◻️決算書_旧複数種別顧客.md" $UUID_A | Out-Null
New-TestNote $f2 "⬛その他_旧複数種別顧客.md" $UUID_A | Out-Null
New-TestNote $f2 "✡️一覧_旧複数種別顧客.md" $UUID_A | Out-Null
New-TestNote $f2 "⛔一覧_旧複数種別顧客.md" $UUID_A | Out-Null
$c2 = @(
  @{ prefix = "🟨契約"; file = "🟨契約_旧複数種別顧客.md" },
  @{ prefix = "🟥事故"; file = "🟥事故_旧複数種別顧客.md" },
  @{ prefix = "◻️決算書"; file = "◻️決算書_旧複数種別顧客.md" },
  @{ prefix = "⬛その他"; file = "⬛その他_旧複数種別顧客.md" },
  @{ prefix = "✡️一覧"; file = "✡️一覧_旧複数種別顧客.md" },
  @{ prefix = "⛔一覧"; file = "⛔一覧_旧複数種別顧客.md" }
)
foreach ($c in $c2) {
  $m = Get-UuidNoteTypeMatches $f2 $c.prefix $UUID_A
  Add-Result ("Case2_" + $c.prefix + "_1件採用") ($m.Count -eq 1 -and $m[0] -like ("*" + $c.file)) "matches=$($m.Count)"
}

# Case 3: 0件
$f3 = Join-Path $testRoot "新規相当顧客"
New-Item -ItemType Directory -Path $f3 -Force | Out-Null
$m3 = Get-UuidNoteTypeMatches $f3 "🟨契約" $UUID_A
Add-Result "Case3_0件" ($m3.Count -eq 0) "matches=$($m3.Count)"

# Case 4: 2件競合
$f4 = Join-Path $testRoot "重複顧客"
New-TestNote $f4 "🟨契約_旧顧客名A.md" $UUID_A | Out-Null
New-TestNote $f4 "🟨契約_旧顧客名B.md" $UUID_A | Out-Null
$m4 = Get-UuidNoteTypeMatches $f4 "🟨契約" $UUID_A
Add-Result "Case4_2件競合" ($m4.Count -eq 2) "matches=$($m4.Count)"

# Case 5: UUID不一致
$f5 = Join-Path $testRoot "別顧客"
New-TestNote $f5 "🟨契約_別顧客.md" $UUID_B | Out-Null
$m5 = Get-UuidNoteTypeMatches $f5 "🟨契約" $UUID_A
Add-Result "Case5_UUID不一致0件" ($m5.Count -eq 0) "matches=$($m5.Count)"

# Case 6: noteType不一致(接頭辞違い)
$f6 = Join-Path $testRoot "種別不一致顧客"
New-TestNote $f6 "🟨契約_旧顧客名.md" $UUID_A | Out-Null
$m6 = Get-UuidNoteTypeMatches $f6 "🟥事故" $UUID_A
Add-Result "Case6_noteType不一致0件" ($m6.Count -eq 0) "matches=$($m6.Count)"
Add-Result "Case6_契約ノート変更なし" (Test-Path (Join-Path $f6 "🟨契約_旧顧客名.md"))

# 追加: 不正YAML(frontmatter未閉鎖)は候補除外
$f7 = Join-Path $testRoot "不正YAML顧客"
New-Item -ItemType Directory -Path $f7 -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $f7 "🟨契約_不正YAML顧客.md"), "---`ntags:`n  - `"x`"`nUUID: $UUID_A`n本文のみ(終了---なし)`n", [System.Text.UTF8Encoding]::new($false))
$m7 = Get-UuidNoteTypeMatches $f7 "🟨契約" $UUID_A
Add-Result "追加_不正YAML候補除外" ($m7.Count -eq 0) "matches=$($m7.Count)"

$results | Format-Table -AutoSize
$passCount = ($results | Where-Object { $_.Pass }).Count
$totalCount = $results.Count
Write-Output ""
Write-Output "テスト結果: $passCount / $totalCount PASS"

Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue

if ($passCount -eq $totalCount) {
  Write-Output "[OK] 全ケースPASS"
  exit 0
} else {
  Write-Output "[NG] 失敗ケースあり"
  exit 1
}
