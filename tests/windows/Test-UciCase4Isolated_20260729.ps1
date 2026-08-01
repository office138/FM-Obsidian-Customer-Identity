<#
Test-UciCase4Isolated_20260729.ps1

目的:
Case4(既に正式名 "Faithウエダ㈱_[2250BA49]" のケース)を、他のいかなるケースとも
一切共有しない、完全新規・単独のTestRootで再診断する。

対象は本番実機ファイル(FM-Obsidian-Bridge-Payload.ps1)そのもの。本体は一切変更しない。
このVaultには以下の1フォルダ・1ノートだけを置く。

フォルダ: Faithウエダ㈱_[2250BA49]
ノート  : 🟨契約_Faithウエダ_[2250BA49].md
UUID    : 2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1
payloadの会社名: Faithウエダ㈱

実行前に、VaultRoot配下の全顧客フォルダ・UUID一致ノートの全パス・件数・
currentFolderFull・currentFolderName・newFolderName・folderNeedsRename・
targetFolderFull・Test-Path -LiteralPath targetFolderFull・
currentFolderFullとtargetFolderFullのOrdinalIgnoreCase比較を表示する。

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
  $TestRoot = Join-Path $env:TEMP ("uci_case4_isolated_" + [Guid]::NewGuid().ToString("N").Substring(0,8))
} else {
  $TestRoot = [System.IO.Path]::GetFullPath($TestRoot)
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Output "[FAIL] 対象スクリプトが見つかりません: $TargetScript"
  exit 1
}

Write-Output ("対象本体: " + $TargetScript)
Write-Output ("対象本体のSHA256: " + (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash)
Write-Output ""

$scriptText = Get-Content -LiteralPath $TargetScript -Raw -Encoding UTF8

function Extract-Function([string]$text, [string]$funcName) {
  $pattern = "(?ms)^function\s+$funcName\s*\([^\)]*\)\s*\{.*?\n\}"
  $m = [regex]::Match($text, $pattern)
  if (-not $m.Success) { throw "関数 $funcName を抽出できませんでした。" }
  return $m.Value
}

$funcNames = @(
  "Sanitize-LeafName", "Normalize-ForMatch", "Get-IconPrefix",
  "Get-YamlHeaderLines", "Get-YamlBodyLines", "Get-YamlScalarValue", "Get-YamlTagValues",
  "Update-Yaml-Robust", "Get-UuidNoteTypeMatches",
  "Get-UciKnownPrefixMap", "Get-NoteNameNormForUci", "Get-UciUuidSuffix",
  "Resolve-UciDirectChildFolder", "Get-UciRelativePath",
  "New-UCIResponse", "New-UCIExtendedNgResponse", "Test-UciUuidFormat",
  "Invoke-UpdateCustomerIdentity"
)
foreach ($fn in $funcNames) {
  $code = Extract-Function $scriptText $fn
  Invoke-Expression $code
}
Write-Output "[OK] 本体から実関数・Invoke-UpdateCustomerIdentity本体を抽出・ロードしました。"
Write-Output ""

# ---- Case4専用・完全新規・単独のTestRoot(他ケースと一切共有しない) ----
$vaultRoot = Join-Path $testRoot "Vault"
$custRoot = Join-Path $vaultRoot "01_顧客"
New-Item -ItemType Directory -Path $custRoot -Force | Out-Null
Write-Output ("Case4専用・完全独立TestRoot: " + $testRoot)
Write-Output ("VaultRoot: " + $vaultRoot)

$UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
$SUFFIX_A = "_[2250BA49]"

# 指示どおり、このVaultにはこの1フォルダ・1ノートだけを置く
$folderName = "Faithウエダ㈱" + $SUFFIX_A
$folderPath = Join-Path $custRoot $folderName
New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
$noteFileName = "🟨契約_Faithウエダ" + $SUFFIX_A + ".md"
$notePath = Join-Path $folderPath $noteFileName
$content = "---`ntags:`n  - `"Faithウエダ㈱`"`n  - `"代表太郎`"`nUUID: $UUID_A`nランク: A`n---`n本文サンプル`n"
[System.IO.File]::WriteAllText($notePath, $content, [System.Text.UTF8Encoding]::new($false))

Write-Output ""
Write-Output "=== 実行前状態(このVaultにはこの1フォルダ・1ノートのみ存在) ==="
Write-Output ("作成したフォルダ: " + $folderPath)
Write-Output ("作成したノート  : " + $notePath)
Write-Output ""
Write-Output "VaultRoot配下の全顧客フォルダ:"
Get-ChildItem -LiteralPath $custRoot -Directory | ForEach-Object { Write-Output ("  - " + $_.FullName) }
Write-Output ""

# UUID一致ノートの全パス・件数を、本体Step1と全く同じロジック(再帰・YAML UUID一致)で確認
$allMd = Get-ChildItem -LiteralPath $custRoot -Filter "*.md" -File -Recurse -ErrorAction SilentlyContinue
$matchedPaths = New-Object System.Collections.ArrayList
foreach ($f in $allMd) {
  $hdr = Get-YamlHeaderLines $f.FullName
  if ($null -eq $hdr) { continue }
  $u = Get-YamlScalarValue $hdr "UUID:"
  if (-not [string]::IsNullOrWhiteSpace($u) -and $u.ToUpperInvariant() -eq $UUID_A.ToUpperInvariant()) {
    [void]$matchedPaths.Add($f.FullName)
  }
}
Write-Output ("UUID一致ノートの全パス:")
$matchedPaths | ForEach-Object { Write-Output ("  - " + $_) }
Write-Output ("UUID一致ノート数: " + $matchedPaths.Count)
Write-Output ""

$currentFolderFull = $folderPath
$currentFolderName = $folderName
$companyNameRaw = "Faithウエダ㈱"
$uuidSuffixCalc = Get-UciUuidSuffix $UUID_A
$newFolderName = (Sanitize-LeafName $companyNameRaw "NO_NAME") + $uuidSuffixCalc
$folderNeedsRename = ($newFolderName -ne $currentFolderName)
$targetFolderFull = Join-Path $custRoot $newFolderName

Write-Output "=== 本体Step2/Step4相当の計算結果(事前確認) ==="
Write-Output ("currentFolderFull: " + $currentFolderFull)
Write-Output ("currentFolderName: " + $currentFolderName)
Write-Output ("newFolderName    : " + $newFolderName)
Write-Output ("folderNeedsRename: " + $folderNeedsRename)
Write-Output ("targetFolderFull : " + $targetFolderFull)
Write-Output ("Test-Path -LiteralPath targetFolderFull(作成前、Falseが正常): " + (Test-Path -LiteralPath $targetFolderFull))
Write-Output ("currentFolderFull と targetFolderFull の OrdinalIgnoreCase比較: " + ([string]::Equals($currentFolderFull, $targetFolderFull, [System.StringComparison]::OrdinalIgnoreCase)))
Write-Output ("currentFolderName と newFolderName の -eq 比較: " + ($currentFolderName -eq $newFolderName))
Write-Output ("currentFolderName と newFolderName の [string]::Equals(Ordinal)比較: " + ([string]::Equals($currentFolderName, $newFolderName, [System.StringComparison]::Ordinal)))
Write-Output ("currentFolderName 文字数: " + $currentFolderName.Length + " / newFolderName 文字数: " + $newFolderName.Length)
$b1 = [System.Text.Encoding]::Unicode.GetBytes($currentFolderName)
$b2 = [System.Text.Encoding]::Unicode.GetBytes($newFolderName)
Write-Output ("currentFolderName UTF-16 hex: " + (($b1 | ForEach-Object { $_.ToString('X2') }) -join ''))
Write-Output ("newFolderName     UTF-16 hex: " + (($b2 | ForEach-Object { $_.ToString('X2') }) -join ''))
Write-Output ("バイト列完全一致: " + ([System.BitConverter]::ToString($b1) -eq [System.BitConverter]::ToString($b2)))
Write-Output ""

# ---- 本体を実行 ----
$payload4 = @{
  protocolVersion = 1
  requestId       = "DIAG-CASE4-ISOLATED"
  VaultRoot       = $vaultRoot
  pk_CLIENT       = $UUID_A
  companyNameRaw  = "Faithウエダ㈱"
  CEO             = "代表太郎"
  RUBY            = ""
  RANK            = "A"
}
$rawOut4 = Invoke-UpdateCustomerIdentity $payload4 | Out-String
Write-Output "=== Invoke-UpdateCustomerIdentity 完全な生JSON応答(完全独立Vault) ==="
Write-Output $rawOut4.Trim()
Write-Output ""
try {
  $obj4 = $rawOut4.Trim() | ConvertFrom-Json
  Write-Output "=== JSON解析結果(全フィールド) ==="
  $obj4.PSObject.Properties | ForEach-Object { Write-Output ("  " + $_.Name + " = " + $_.Value) }
  Write-Output ""
  if ($obj4.status -eq "OK" -and $obj4.code -eq "NO_CHANGE") {
    Write-Output "[OK] 期待どおりNO_CHANGEでした(自己衝突判定へ入らなかったことを意味します)。"
  } elseif ($obj4.code -eq "TARGET_FOLDER_ALREADY_EXISTS") {
    Write-Output "[NG] 完全独立Vaultでも自己衝突(TARGET_FOLDER_ALREADY_EXISTS)が再現しました。本体側の判定ロジックに欠陥がある可能性が高いです。"
  } else {
    Write-Output ("[情報] 想定外のコードでした: " + $obj4.code)
  }
} catch {
  Write-Output ("[FAIL] JSON解析に失敗しました: " + $rawOut4)
}
Write-Output ""
Write-Output ("一時ディレクトリ(調査用に残します): " + $testRoot)
