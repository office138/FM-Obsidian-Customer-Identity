<#
Test-UciCase1InternalException_20260729.ps1

目的:
FOLDER_RENAME_FAILEDの内部で握りつぶされている実例外を可視化するための診断専用ハーネス。

本番実機ファイル(FM-Obsidian-Bridge-Payload.ps1)は一切変更しない。
代わりに、-DiagCopy で指定した「診断専用の一時コピー」(Step7のcatch内にのみ
診断情報出力コードを追加したもの)を対象に、Case1相当を完全独立Vaultで1件だけ実行する。

診断専用コピーはGitHub cloneに含まれない。外部LOCAL_EVIDENCEのパスを
-DiagCopyPathで明示した場合だけ実行する。
追加された診断コードは、応答の内容・返却コード自体は変更しておらず
(従来どおりFOLDER_RENAME_FAILEDを返す)、"###UCI_DIAG###"というマーカー付きの
診断JSONを1行追加出力するのみ。

対象診断専用コピー: -DiagCopyPathで明示する。
#>

[CmdletBinding()]
param(
  [string]$DiagCopyPath = "",
  [string]$TestRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DiagCopyPath)) {
  Write-Output "SKIP: DiagCopyPath was not supplied."
  exit 0
}
$DiagCopyPath = [System.IO.Path]::GetFullPath($DiagCopyPath)
if (-not (Test-Path -LiteralPath $DiagCopyPath -PathType Leaf)) {
  Write-Output "SKIP: DiagCopyPath does not exist."
  exit 0
}
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
  $TestRoot = Join-Path $env:TEMP ("uci_case1_internal_" + [Guid]::NewGuid().ToString("N").Substring(0,8))
} else {
  $TestRoot = [System.IO.Path]::GetFullPath($TestRoot)
}

Write-Output ("PSVersion: " + $PSVersionTable.PSVersion.ToString())
Write-Output ("対象診断専用コピー: " + $DiagCopyPath)
Write-Output ("対象コピーのSHA256: " + (Get-FileHash -LiteralPath $DiagCopyPath -Algorithm SHA256).Hash)
Write-Output ""

$scriptText = Get-Content -LiteralPath $DiagCopyPath -Raw -Encoding UTF8

if ($scriptText -notmatch [regex]::Escape("DIAGCOPY-ONLY 2026-07-29")) {
  Write-Output "[FAIL] 診断専用コピーに計測コードのマーカーが見つかりません。正しいコピーを指定してください。"
  exit 1
}
Write-Output "[OK] 診断専用コピーの計測コードマーカーを確認しました。"

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
  "New-UCIResponse", "New-UCIExtendedNgResponse", "Test-UciUuidFormat",
  "Invoke-UpdateCustomerIdentity"
)
foreach ($fn in $funcNames) {
  $code = Extract-Function $scriptText $fn
  Invoke-Expression $code
  Write-Output "[OK] $fn を診断専用コピーから抽出・ロードしました。"
}
Write-Output ""

# ---- Case1専用の完全独立Vault(このテストだけで使用) ----
$vaultRoot = Join-Path $testRoot "Vault"
$custRoot = Join-Path $vaultRoot "01_顧客"
New-Item -ItemType Directory -Path $custRoot -Force | Out-Null
Write-Output ("Case1専用の完全独立一時Vault: " + $vaultRoot)

$UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
$SUFFIX_A = "_[2250BA49]"

$f1 = Join-Path $custRoot "Faithウエダ㈱"
New-Item -ItemType Directory -Path $f1 -Force | Out-Null
$note1 = Join-Path $f1 "🟨契約_Faithウエダ.md"
$content1 = "---`ntags:`n  - `"Faithウエダ㈱`"`n  - `"代表太郎`"`nUUID: $UUID_A`nランク: A`n---`n本文サンプル`n"
[System.IO.File]::WriteAllText($note1, $content1, [System.Text.UTF8Encoding]::new($false))

Write-Output ("元フォルダ: " + $f1)
Write-Output ("元フォルダ存在: " + (Test-Path -LiteralPath $f1))
Write-Output ("元ノート: " + $note1)
Write-Output ("元ノート存在: " + (Test-Path -LiteralPath $note1))
Write-Output ("VaultRoot配下の顧客フォルダ一覧:")
Get-ChildItem -LiteralPath $custRoot -Directory | ForEach-Object { Write-Output ("  - " + $_.Name) }
Write-Output ""

$payload1 = @{
  protocolVersion = 1
  requestId       = "DIAG-CASE1"
  VaultRoot       = $vaultRoot
  pk_CLIENT       = $UUID_A
  companyNameRaw  = "Faithウエダ㈱"
  CEO             = "代表太郎"
  RUBY            = ""
  RANK            = "A"
}
Write-Output "渡すpayload:"
$payload1.Keys | ForEach-Object { Write-Output ("  $_ = " + $payload1[$_]) }
Write-Output ""

$rawOut = Invoke-UpdateCustomerIdentity $payload1 | Out-String
Write-Output "=== 生出力(診断JSON行 + 最終応答JSON行、両方含む可能性あり) ==="
Write-Output $rawOut
Write-Output "=== ここまで ==="
Write-Output ""

$lines = $rawOut -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
$diagLine = $lines | Where-Object { $_ -like "###UCI_DIAG###*" } | Select-Object -First 1
$respLine = $lines | Where-Object { $_ -notlike "###UCI_DIAG###*" } | Select-Object -Last 1

if ($diagLine) {
  Write-Output "=== 内部診断情報(Step7 catch内、FOLDER_RENAME_FAILEDの実例外) ==="
  $diagJson = $diagLine.Substring("###UCI_DIAG###".Length)
  $diagObj = $diagJson | ConvertFrom-Json
  $diagObj.PSObject.Properties | ForEach-Object { Write-Output ("  " + $_.Name + " = " + $_.Value) }
} else {
  Write-Output "[情報] 診断JSON行は出力されませんでした(=Step7のRename-Itemまたはその直後の処理で例外が発生しなかった可能性。つまりFOLDER_RENAME_FAILEDにならず正常応答またはStep7以降の別コードで停止したことを意味します)。"
}
Write-Output ""

if ($respLine) {
  Write-Output "=== 最終応答JSON ==="
  try {
    $respObj = $respLine | ConvertFrom-Json
    $respObj.PSObject.Properties | ForEach-Object { Write-Output ("  " + $_.Name + " = " + $_.Value) }
  } catch {
    Write-Output ("[FAIL] 最終応答のJSON解析に失敗しました: " + $respLine)
  }
}
Write-Output ""

Write-Output "=== 実行後の実際のディレクトリ状態 ==="
Write-Output ("元フォルダなお存在するか: " + (Test-Path -LiteralPath $f1))
$newF1 = Join-Path $custRoot ("Faithウエダ㈱" + $SUFFIX_A)
Write-Output ("正式名フォルダが存在するか: " + (Test-Path -LiteralPath $newF1))
Write-Output ("$custRoot 直下の実際のフォルダ一覧:")
Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ("  - " + $_.Name) }

Write-Output ""
Write-Output ("一時ディレクトリ(調査用に残します): " + $testRoot)
