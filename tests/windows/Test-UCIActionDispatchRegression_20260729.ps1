<#
Test-UCIActionDispatchRegression_20260729.ps1

目的:
既存 EXT-obs_OBSノート-開く の実機実行で検出された回帰
「このオブジェクトにプロパティ 'action' が見つかりません。(LINE=674)」
に対する FM-Obsidian-Bridge-Payload.ps1 の修正を検証する focused test。

背景:
$payload は ConvertTo-Hashtable により必ず [hashtable] 化される。
従来payload(EXT-obs_OBSノート-開く由来)には action キーが存在しないため、
Set-StrictMode -Version Latest 下で $payload.action を直接参照すると例外になる。
修正では ContainsKey('action') で存在確認してから読み取るよう変更した。

このテストは対象.ps1ファイルから修正後の判定ロジックをそのまま抽出して実行するため、
手動で書き写した再現コードではなく、実際に適用された修正コードそのものを検証する。
Obsidian・Vault・FileMakerの起動は一切不要。

対象ファイル:
<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1

実行環境:
Windows PowerShell 5.1 Desktop (実機)
#>

[CmdletBinding()]
param(
  [string]$RepositoryRoot = "",
  [string]$TargetScript = ""
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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Output "[FAIL] 対象スクリプトが見つかりません: $TargetScript"
  Write-Output "       -TargetScript パラメータで実際のパスを指定して再実行してください。"
  exit 1
}

$scriptText = Get-Content -LiteralPath $TargetScript -Raw -Encoding UTF8

# ---- 1. 回帰修正マーカーの存在確認 ----
$expectedMarker = "回帰修正(2026-07-29)"
if ($scriptText -notmatch [regex]::Escape($expectedMarker)) {
  Write-Output "[FAIL] 対象スクリプトに回帰修正マーカーが見つかりません。修正が適用されていない可能性があります。"
  exit 1
}
Write-Output "[OK] 回帰修正マーカーを確認しました。"

# ---- 2. 修正後の判定ロジックブロックを対象ファイルからそのまま抽出 ----
$pattern = '(?s)\$uciActionValue\s*=\s*\$null.*?\$uciActionValue\s*=\s*\[string\]\$payload\.action\s*\r?\n\s*\}'
$m = [regex]::Match($scriptText, $pattern)
if (-not $m.Success) {
  Write-Output "[FAIL] 判定ロジックブロックを抽出できませんでした(正規表現不一致)。対象ファイルの構造が変わっている可能性があります。"
  exit 1
}
$logicBlockText = $m.Value
Write-Output "[OK] 判定ロジックブロックを抽出しました。"
Write-Output "----- 抽出ブロック -----"
Write-Output $logicBlockText
Write-Output "------------------------"

function Invoke-ExtractedDispatchLogic {
  param($payload)
  # 対象ファイルから抽出した実コードそのものをこのスコープ内で実行する。
  Invoke-Expression $script:logicBlockText
  return $uciActionValue
}

$results = New-Object System.Collections.ArrayList

function Add-TestResult {
  param([string]$Name, [scriptblock]$Block, $Expected)
  try {
    $actual = & $Block
    $pass = ($actual -eq $Expected)
    [void]$script:results.Add([pscustomobject]@{
      Case = $Name; Expected = $Expected; Actual = $actual; Exception = $null; Pass = $pass
    })
  } catch {
    [void]$script:results.Add([pscustomobject]@{
      Case = $Name; Expected = $Expected; Actual = $null; Exception = $_.Exception.Message; Pass = $false
    })
  }
}

# TC1: payloadにactionキーなし(従来payload相当) → 例外なし・$uciActionValueはnull相当(空文字列)のまま
Add-TestResult "TC1_NoActionKey_LegacyPayload" {
  $p = @{ VaultRoot = "C:\dummy"; noteType = "契約一覧"; MODE = "CHECK" }
  $v = Invoke-ExtractedDispatchLogic $p
  [string]::IsNullOrEmpty($v)
} $true

# TC2: action=UPDATE_CUSTOMER_IDENTITY → 新actionへ分岐する値が得られる
Add-TestResult "TC2_ActionEqualsUpdateCustomerIdentity" {
  $p = @{ action = "UPDATE_CUSTOMER_IDENTITY"; pk_CLIENT = "dummy-uuid" }
  $v = Invoke-ExtractedDispatchLogic $p
  $v -eq "UPDATE_CUSTOMER_IDENTITY"
} $true

# TC3: actionが別文字列 → 例外なし・新actionへは分岐しない値が得られる
Add-TestResult "TC3_ActionOtherString" {
  $p = @{ action = "SOME_OTHER_ACTION"; VaultRoot = "C:\dummy" }
  $v = Invoke-ExtractedDispatchLogic $p
  ($v -eq "SOME_OTHER_ACTION") -and ($v -ne "UPDATE_CUSTOMER_IDENTITY")
} $true

# TC4: action=null(JSON nullが$nullとして渡るケースを再現) → 例外なし・新actionへは分岐しない
Add-TestResult "TC4_ActionIsNull" {
  $p = @{ action = $null; VaultRoot = "C:\dummy" }
  $v = Invoke-ExtractedDispatchLogic $p
  [string]::IsNullOrEmpty($v)
} $true

# ---- 参考: 修正前の旧ロジック($payload.action直接参照)がTC1相当の入力で
#            実際にStrictMode例外を再現することの確認(回帰の実在性を裏付ける) ----
function Invoke-OldBuggyDispatchLogic {
  param($payload)
  return ([string]$payload.action -eq "UPDATE_CUSTOMER_IDENTITY")
}
$oldLogicThrew = $false
$oldLogicErrorMessage = $null
try {
  $p = @{ VaultRoot = "C:\dummy"; noteType = "契約一覧"; MODE = "CHECK" }
  Invoke-OldBuggyDispatchLogic $p | Out-Null
} catch {
  $oldLogicThrew = $true
  $oldLogicErrorMessage = $_.Exception.Message
}

# ---- 結果出力 ----
$results | Format-Table -AutoSize

$passCount = ($results | Where-Object { $_.Pass }).Count
$totalCount = $results.Count

Write-Output ""
Write-Output "旧ロジック(修正前・`$payload.action直接参照)はTC1相当の入力でStrictMode例外を再現したか: $oldLogicThrew"
if ($oldLogicThrew) {
  Write-Output "  再現時の例外メッセージ: $oldLogicErrorMessage"
}
Write-Output ""
Write-Output "回帰テスト結果: $passCount / $totalCount PASS"

if ($passCount -eq $totalCount -and $oldLogicThrew) {
  Write-Output "[OK] 修正版は4ケースすべてPASS。旧ロジックでの例外再現も確認済み(回帰が実在し、修正で解消されたことを確認)。"
  exit 0
} else {
  Write-Output "[NG] 一部テストが失敗、または旧ロジックでの例外再現に失敗しました。詳細を確認してください。"
  exit 1
}
