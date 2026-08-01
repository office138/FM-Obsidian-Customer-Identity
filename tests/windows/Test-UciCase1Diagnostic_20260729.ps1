<#
Test-UciCase1Diagnostic_20260729.ps1

目的:
Test-UciUuidNormalization_20260729.ps1 実機実行での大量FOLDER_RENAME_FAILED、
および Case4 の自己衝突(TARGET_FOLDER_ALREADY_EXISTS)について、
本体(FM-Obsidian-Bridge-Payload.ps1)を一切変更せず、read-onlyで原因を特定するための
診断専用ハーネス。

本体は一切変更しない。本体から実関数をそのまま抽出して呼び出し、かつ本体のtry/catchが
実例外を握りつぶしている箇所(Step7フォルダリネーム)については、全く同一の引数で
「本体の外側」でも同じ操作を単独実行し、実際の例外の型・メッセージ・スタックトレースを
そのまま可視化する。あわせて、"[" "]" を含む名前に対してPowerShellの各種パス関連コマンドが
ワイルドカードとして誤解釈していないかを直接検証する独立実験を行う。

一時ディレクトリのみを使用する。本番Vault・FileMaker・Obsidianは一切使用しない。

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
  $TestRoot = Join-Path $env:TEMP ("uci_diag_" + [Guid]::NewGuid().ToString("N").Substring(0,8))
} else {
  $TestRoot = [System.IO.Path]::GetFullPath($TestRoot)
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Output "[FAIL] 対象スクリプトが見つかりません: $TargetScript"
  exit 1
}

Write-Output "=== 実行環境確認 ==="
Write-Output ("PSVersion: " + $PSVersionTable.PSVersion.ToString())
Write-Output ("PSEdition: " + $PSVersionTable.PSEdition)
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
Write-Output "[OK] 対象ファイルから実関数・Invoke-UpdateCustomerIdentity本体を抽出・ロードしました。"
Write-Output ""

$vaultRoot = Join-Path $testRoot "Vault"
$custRoot = Join-Path $vaultRoot "01_顧客"
New-Item -ItemType Directory -Path $custRoot -Force | Out-Null
Write-Output ("テスト用一時Vault: " + $vaultRoot)
Write-Output ""

$UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
$SUFFIX_A = "_[2250BA49]"

function New-TestNote([string]$folder, [string]$fileName, [string]$uuid, [string[]]$tags, [string]$rank = "A", [string]$body = "本文サンプル") {
  if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
  $path = Join-Path $folder $fileName
  $tagLines = ""
  foreach ($t in $tags) { $tagLines += "  - `"$t`"`n" }
  $content = "---`ntags:`n$tagLines" + "UUID: $uuid`n" + "ランク: $rank`n---`n$body`n"
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
  return $path
}

function New-UciPayload([string]$vaultRoot, [string]$pkClient, [string]$companyNameRaw, [string]$ceo = "", [string]$ruby = "", [string]$rank = "A", [string]$reqId = "DIAG-REQ") {
  return @{
    protocolVersion = 1
    requestId       = $reqId
    VaultRoot       = $vaultRoot
    pk_CLIENT       = $pkClient
    companyNameRaw  = $companyNameRaw
    CEO             = $ceo
    RUBY            = $ruby
    RANK            = $rank
  }
}

# =====================================================================
# 実験0: "[" "]" を含む名前に対するPowerShellパス関連コマンドの挙動を単独検証
# (本体・ハーネスのどちらの問題かを切り分けるための独立実験。本体コードは一切使わない)
# =====================================================================
Write-Output "=== 実験0: 角カッコを含む名前に対するワイルドカード誤解釈の直接検証 ==="
$expDir = Join-Path $testRoot "wildcard_experiment"
New-Item -ItemType Directory -Path $expDir -Force | Out-Null
$bracketName = "Test顧客" + $SUFFIX_A
$bracketPath = Join-Path $expDir $bracketName
New-Item -ItemType Directory -Path $bracketPath -Force | Out-Null
Write-Output ("作成したフォルダ: " + $bracketPath)

Write-Output ("Test-Path -LiteralPath (対象を直接指定): " + (Test-Path -LiteralPath $bracketPath))
Write-Output ("Test-Path (非LiteralPath、通常の -Path 経由): " + (Test-Path -Path $bracketPath))
Write-Output ("Get-ChildItem -LiteralPath $expDir | Where Name -eq 一致件数: " + (@(Get-ChildItem -LiteralPath $expDir -Directory | Where-Object { $_.Name -eq $bracketName }).Count))

# Rename-Item -NewName に角カッコを含む名前を渡した場合の実際の例外を単独取得
$renameSrc = Join-Path $expDir "リネーム元フォルダ"
New-Item -ItemType Directory -Path $renameSrc -Force | Out-Null
$renameNewName = "リネーム先" + $SUFFIX_A
Write-Output ""
Write-Output ("Rename-Item単独実験: -LiteralPath '$renameSrc' -NewName '$renameNewName'")
try {
  Rename-Item -LiteralPath $renameSrc -NewName $renameNewName -Force -ErrorAction Stop
  $renamedPath = Join-Path $expDir $renameNewName
  Write-Output ("  → 成功。Test-Path -LiteralPath 変更後パス: " + (Test-Path -LiteralPath $renamedPath))
} catch {
  Write-Output "  → 失敗(実例外情報):"
  Write-Output ("    例外型: " + $_.Exception.GetType().FullName)
  Write-Output ("    例外メッセージ: " + $_.Exception.Message)
  Write-Output ("    FullyQualifiedErrorId: " + $_.FullyQualifiedErrorId)
  Write-Output ("    CategoryInfo: " + $_.CategoryInfo)
  Write-Output ("    InvocationInfo.Line: " + $_.InvocationInfo.Line)
}

# [System.IO.Directory]::Move との比較(PowerShellプロバイダ層を経由しない.NET直接呼び出し)
$renameSrc2 = Join-Path $expDir "リネーム元フォルダ2"
New-Item -ItemType Directory -Path $renameSrc2 -Force | Out-Null
$renameDest2 = Join-Path $expDir ("リネーム先2" + $SUFFIX_A)
Write-Output ""
Write-Output ("[System.IO.Directory]::Move単独実験: '$renameSrc2' → '$renameDest2'")
try {
  [System.IO.Directory]::Move($renameSrc2, $renameDest2)
  Write-Output ("  → 成功。Directory.Exists: " + [System.IO.Directory]::Exists($renameDest2))
} catch {
  Write-Output "  → 失敗(実例外情報):"
  Write-Output ("    例外型: " + $_.Exception.GetType().FullName)
  Write-Output ("    例外メッセージ: " + $_.Exception.Message)
}
Write-Output ""

# =====================================================================
# Case1相当のセットアップ
# =====================================================================
Write-Output "=== Case1最小診断(社名変更なし・識別子なし) ==="
$f1 = Join-Path $custRoot "Faithウエダ㈱"
$note1 = New-TestNote $f1 "🟨契約_Faithウエダ.md" $UUID_A @("Faithウエダ㈱","代表太郎") "A"
Write-Output ("元フォルダ絶対パス: " + $f1)
Write-Output ("元フォルダ Test-Path -LiteralPath: " + (Test-Path -LiteralPath $f1))
Write-Output ("元ノート絶対パス: " + $note1)

# 本体と全く同じ計算式で新フォルダ名を事前に算出して表示(本体コードは変更せず、
# 抽出済みの同一関数をそのまま使って計算するだけ)
$uuidSuffixCalc = Get-UciUuidSuffix $UUID_A
$newFolderNameCalc = (Sanitize-LeafName "Faithウエダ㈱" "NO_NAME") + $uuidSuffixCalc
$newFolderPathCalc = Join-Path $custRoot $newFolderNameCalc
Write-Output ("算出されたUUID接尾辞: " + $uuidSuffixCalc)
Write-Output ("算出された新フォルダ名: " + $newFolderNameCalc)
Write-Output ("算出された新フォルダ絶対パス: " + $newFolderPathCalc)
Write-Output ("新フォルダ Test-Path -LiteralPath(作成前、Falseが正常): " + (Test-Path -LiteralPath $newFolderPathCalc))
Write-Output ("親ディレクトリ($custRoot) Test-Path -LiteralPath: " + (Test-Path -LiteralPath $custRoot))
Write-Output ""

$payload1 = New-UciPayload $vaultRoot $UUID_A "Faithウエダ㈱" "代表太郎"
Write-Output "渡すpayload:"
$payload1.Keys | ForEach-Object { Write-Output ("  $_ = " + $payload1[$_]) }
Write-Output ""

$rawOut1 = Invoke-UpdateCustomerIdentity $payload1 | Out-String
Write-Output "=== Invoke-UpdateCustomerIdentity 完全な生JSON応答 ==="
Write-Output $rawOut1.Trim()
Write-Output ""
try {
  $obj1 = $rawOut1.Trim() | ConvertFrom-Json
  Write-Output "=== JSON解析結果(全フィールド) ==="
  $obj1.PSObject.Properties | ForEach-Object { Write-Output ("  " + $_.Name + " = " + $_.Value) }
} catch {
  Write-Output ("[FAIL] JSON解析に失敗しました: " + $_.Exception.Message)
}
Write-Output ""

Write-Output "=== Case1実行後の実際のディレクトリ状態 ==="
Write-Output ("元フォルダなお存在するか: " + (Test-Path -LiteralPath $f1))
Write-Output ("算出した新フォルダが存在するか: " + (Test-Path -LiteralPath $newFolderPathCalc))
Write-Output ("$custRoot 直下の実際のフォルダ一覧:")
Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ("  - " + $_.Name) }
Write-Output ""

# 本体のStep7と全く同一のRename-Item呼び出しを、本体のtry/catchの外側で単独再現する
# (本体は例外メッセージを握りつぶして"FOLDER_RENAME_FAILED"にまとめてしまうため、
#  実際の例外を見るには全く同じ引数で外側から再実行するしかない)
Write-Output "=== 本体Step7と同一のRename-Item呼び出しを外側で単独再現 ==="
if (Test-Path -LiteralPath $f1) {
  Write-Output ("Rename-Item -LiteralPath '$f1' -NewName '$newFolderNameCalc' -Force を単独実行:")
  try {
    Rename-Item -LiteralPath $f1 -NewName $newFolderNameCalc -Force -ErrorAction Stop
    Write-Output "  → 成功(本体内では失敗するはずの操作が、外側では成功した場合、ハーネス抽出・スコープ側の問題を疑う)"
    Write-Output ("  → 変更後 Test-Path -LiteralPath: " + (Test-Path -LiteralPath $newFolderPathCalc))
  } catch {
    Write-Output "  → 失敗(実例外情報。本体内で握りつぶされている実際の原因はこれと同一のはず):"
    Write-Output ("    例外型: " + $_.Exception.GetType().FullName)
    Write-Output ("    例外メッセージ: " + $_.Exception.Message)
    Write-Output ("    FullyQualifiedErrorId: " + $_.FullyQualifiedErrorId)
    Write-Output ("    CategoryInfo: " + $_.CategoryInfo)
  }
} else {
  Write-Output "  (元フォルダが既に存在しないため、本体側の実行で既にリネームまたは削除が発生している可能性があります)"
}
Write-Output ""

# =====================================================================
# Case4相当: 既に正式名のケースでの自己衝突を診断
# =====================================================================
Write-Output "=== Case4診断(既に正式名の自己衝突) ==="
$f4 = Join-Path $custRoot ("Faithウエダ㈱" + $SUFFIX_A)
$note4 = New-TestNote $f4 ("🟨契約_Faithウエダ" + $SUFFIX_A + ".md") $UUID_A @("Faithウエダ㈱","代表太郎") "A"
Write-Output ("Case4用フォルダ: " + $f4)

$uuidSuffixCalc4 = Get-UciUuidSuffix $UUID_A
$newFolderNameCalc4 = (Sanitize-LeafName "Faithウエダ㈱" "NO_NAME") + $uuidSuffixCalc4
$currentFolderNameCalc4 = "Faithウエダ㈱" + $SUFFIX_A

Write-Output ("期待される現フォルダ名(ハーネスが作成した名前): " + $currentFolderNameCalc4)
Write-Output ("算出された新フォルダ名(本体が計算するはずの値): " + $newFolderNameCalc4)
Write-Output ("文字列として -eq で一致するか: " + ($newFolderNameCalc4 -eq $currentFolderNameCalc4))
Write-Output ("文字列長: 現=" + $currentFolderNameCalc4.Length + " / 新=" + $newFolderNameCalc4.Length)

# バイト単位(UTF-16コードユニット単位)で完全一致するか、目に見えない差異がないかを確認
$bytesCur = [System.Text.Encoding]::Unicode.GetBytes($currentFolderNameCalc4)
$bytesNew = [System.Text.Encoding]::Unicode.GetBytes($newFolderNameCalc4)
Write-Output ("現フォルダ名のUTF-16バイト列(hex): " + (($bytesCur | ForEach-Object { $_.ToString("X2") }) -join ""))
Write-Output ("新フォルダ名のUTF-16バイト列(hex): " + (($bytesNew | ForEach-Object { $_.ToString("X2") }) -join ""))
Write-Output ("バイト列が完全一致するか: " + ([System.BitConverter]::ToString($bytesCur) -eq [System.BitConverter]::ToString($bytesNew)))
Write-Output ""

# 実際にGet-ChildItemで取得した現フォルダ名(ディスク上の実名)も比較対象に加える
$actualDirObj = Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.FullName -eq $f4 }
if ($actualDirObj) {
  $actualName = $actualDirObj.Name
  Write-Output ("ディスク上の実際のフォルダ名(Get-ChildItem由来): " + $actualName)
  Write-Output ("実際の名前 -eq 算出した新フォルダ名: " + ($actualName -eq $newFolderNameCalc4))
  $bytesActual = [System.Text.Encoding]::Unicode.GetBytes($actualName)
  Write-Output ("実際の名前のUTF-16バイト列(hex): " + (($bytesActual | ForEach-Object { $_.ToString("X2") }) -join ""))
}
Write-Output ""

$payload4 = New-UciPayload $vaultRoot $UUID_A "Faithウエダ㈱" "代表太郎"
$rawOut4 = Invoke-UpdateCustomerIdentity $payload4 | Out-String
Write-Output "=== Case4: Invoke-UpdateCustomerIdentity 完全な生JSON応答 ==="
Write-Output $rawOut4.Trim()
Write-Output ""

Write-Output "=== 診断終了。一時ディレクトリは削除せず残します(追加調査用) ==="
Write-Output ("一時ディレクトリ: " + $testRoot)
Write-Output "(調査完了後、手動で削除してください。本番Vaultではないため放置しても影響はありません)"
