<#
Test-UciUuidNormalization_20260729.ps1 (補正版 2026-07-29b)

目的:
UUID識別子付き正式命名規則への常時正規化(2026-07-29追加)により
FM-Obsidian-Bridge-Payload.ps1 の Invoke-UpdateCustomerIdentity へ追加した、
・フォルダ名/ノートファイル名へのUUID先頭8文字識別子の常時付与
・4パターン(社名変更なし/あり × 識別子なし/ありの正規化)
・衝突事前チェック(NOTE_TYPE_UUID_CONFLICT / TARGET_NOTE_FILENAME_CONFLICT)
・YAML修復ポリシー(YAML_BODY_BOUNDARY_UNRESOLVED / 境界確定時の修復)
・ロールバック拡張(リネーム済みノート名の復元を含む)
を、実際のWindows PowerShell 5.1環境・実ファイルI/Oで検証する。

このテストは対象.ps1ファイルから実際の関数定義・Invoke-UpdateCustomerIdentity関数
本体をそのまま抽出して実行するため、手動で書き写した再現コードではなく、
実際に適用された修正コードそのものを検証する。
本番Vault・FileMaker・Obsidianの起動は一切不要。一時ディレクトリのみを使用する。

【補正(2026-07-29b)】
初版は全13ケースが単一の$custRoot(01_顧客)を共有し、かつ複数ケースが同一UUID(UUID_A)を
再利用していたため、後続ケースが先行ケースの残存フォルダ/ノートと衝突・混信し、
本来の検証対象とは無関係な失敗(FOLDER_RENAME_FAILED・TARGET_FOLDER_ALREADY_EXISTS等)を
誘発していた可能性がある。本補正版では、各ケースごとに完全に独立したVaultRoot
(そのケース専用の01_顧客)を新規作成し、ケース間の相互汚染を構造的に排除する。
対象.ps1本体(FM-Obsidian-Bridge-Payload.ps1)は本補正で一切変更していない。

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
  $TestRoot = Join-Path $env:TEMP ("uci_uuid_norm_" + [Guid]::NewGuid().ToString("N").Substring(0,8))
} else {
  $TestRoot = [System.IO.Path]::GetFullPath($TestRoot)
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Output "[FAIL] 対象スクリプトが見つかりません: $TargetScript"
  Write-Output "       -TargetScript パラメータで実際のパスを指定して再実行してください。"
  exit 1
}

$scriptText = Get-Content -LiteralPath $TargetScript -Raw -Encoding UTF8

# ---- 1. 修正マーカーの存在確認 ----
if ($scriptText -notmatch [regex]::Escape("UUID識別子付き正式命名規則への常時正規化(2026-07-29追加)")) {
  Write-Output "[FAIL] 対象スクリプトにUUID識別子付き正式命名規則への常時正規化の修正マーカーが見つかりません。"
  exit 1
}
Write-Output "[OK] 修正マーカーを確認しました。"

# ---- 2. 対象ファイルから実際の関数定義・Invoke-UpdateCustomerIdentity本体をそのまま抽出 ----
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
  Write-Output "[OK] $fn を対象ファイルから抽出・ロードしました。"
}

# ---- 3. テスト用一時ディレクトリ(ケースごとに完全に独立したVaultRootを配下に作る) ----
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Write-Output "テスト用一時ディレクトリ(親): $testRoot"

$UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
$UUID_B = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
$UUID_C = "9F13C842-0000-0000-0000-000000000000"
$SUFFIX_A = "_[2250BA49]"

# ケースごとに完全独立したVaultRoot(01_顧客)を新規作成する。他ケースの残存物と
# 一切共有しないため、フォルダ名・UUIDの再利用によるケース間相互汚染を構造的に排除する。
function New-CaseVault([string]$caseTag) {
  $vRoot = Join-Path $testRoot ("Vault_" + $caseTag)
  $cRoot = Join-Path $vRoot "01_顧客"
  New-Item -ItemType Directory -Path $cRoot -Force | Out-Null
  return @{ VaultRoot = $vRoot; CustRoot = $cRoot }
}

function New-TestNote([string]$folder, [string]$fileName, [string]$uuid, [string[]]$tags, [string]$rank = "A", [string]$body = "本文サンプル") {
  if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
  $path = Join-Path $folder $fileName
  $tagLines = ""
  foreach ($t in $tags) { $tagLines += "  - `"$t`"`n" }
  $content = "---`ntags:`n$tagLines" + "UUID: $uuid`n" + "ランク: $rank`n---`n$body`n"
  [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
  return $path
}

function New-UciPayload([string]$vaultRoot, [string]$pkClient, [string]$companyNameRaw, [string]$ceo = "", [string]$ruby = "", [string]$rank = "A", [string]$reqId = "TEST-REQ") {
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

function Invoke-UciAndParse($payload) {
  $out = Invoke-UpdateCustomerIdentity $payload | Out-String
  $out = $out.Trim()
  try { return ($out | ConvertFrom-Json) } catch { throw "JSON解析に失敗しました。出力: $out" }
}

$results = New-Object System.Collections.ArrayList
function Add-Result([string]$name, [bool]$pass, [string]$detail = "") {
  [void]$script:results.Add([pscustomobject]@{ Case = $name; Pass = $pass; Detail = $detail })
}

# ==== Case1: 社名変更なし・UUID識別子なし → フォルダ+ノートへ識別子付与 ====
$v1 = New-CaseVault "Case1"
$f1 = Join-Path $v1.CustRoot "Faithウエダ㈱"
New-TestNote $f1 "🟨契約_Faithウエダ.md" $UUID_A @("Faithウエダ㈱","代表太郎") "A" | Out-Null
$resp1 = Invoke-UciAndParse (New-UciPayload $v1.VaultRoot $UUID_A "Faithウエダ㈱" "代表太郎")
$newF1 = Join-Path $v1.CustRoot ("Faithウエダ㈱" + $SUFFIX_A)
Add-Result "Case1_status_code" ($resp1.status -eq "OK" -and $resp1.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp1.status)/$($resp1.code)/$($resp1.userMessage)"
Add-Result "Case1_フォルダ識別子付与" (Test-Path -LiteralPath $newF1)
Add-Result "Case1_旧フォルダ消滅" (-not (Test-Path -LiteralPath $f1))
$expNote1 = Join-Path $newF1 ("🟨契約_Faithウエダ" + $SUFFIX_A + ".md")
Add-Result "Case1_ノート識別子付与" (Test-Path -LiteralPath $expNote1)
if (Test-Path -LiteralPath $expNote1) {
  $body1 = Get-Content -LiteralPath $expNote1 -Raw -Encoding UTF8
  Add-Result "Case1_本文保持" ($body1 -match "本文サンプル")
}

# ==== Case2: 社名変更あり・UUID識別子なし → リネーム+識別子付与 ====
$v2 = New-CaseVault "Case2"
$f2 = Join-Path $v2.CustRoot "旧会社名"
New-TestNote $f2 "🟨契約_旧会社名.md" $UUID_A @("旧会社名","代表太郎") "A" | Out-Null
$resp2 = Invoke-UciAndParse (New-UciPayload $v2.VaultRoot $UUID_A "新会社名" "代表太郎")
$newF2 = Join-Path $v2.CustRoot ("新会社名" + $SUFFIX_A)
Add-Result "Case2_status_code" ($resp2.status -eq "OK" -and $resp2.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp2.status)/$($resp2.code)/$($resp2.userMessage)"
Add-Result "Case2_フォルダリネーム+付与" (Test-Path -LiteralPath $newF2)
Add-Result "Case2_ノートリネーム+付与" (Test-Path -LiteralPath (Join-Path $newF2 ("🟨契約_新会社名" + $SUFFIX_A + ".md")))

# ==== Case3: 社名変更あり・識別子は既に付いている → 名前部分のみ更新、識別子重複なし ====
$v3 = New-CaseVault "Case3"
$f3 = Join-Path $v3.CustRoot ("旧会社名" + $SUFFIX_A)
New-TestNote $f3 ("🟨契約_旧会社名" + $SUFFIX_A + ".md") $UUID_A @("旧会社名","代表太郎") "A" | Out-Null
$resp3 = Invoke-UciAndParse (New-UciPayload $v3.VaultRoot $UUID_A "新会社名" "代表太郎")
$newF3 = Join-Path $v3.CustRoot ("新会社名" + $SUFFIX_A)
$newNote3 = Join-Path $newF3 ("🟨契約_新会社名" + $SUFFIX_A + ".md")
Add-Result "Case3_status_code" ($resp3.status -eq "OK" -and $resp3.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp3.status)/$($resp3.code)/$($resp3.userMessage)"
Add-Result "Case3_フォルダ名部分更新" (Test-Path -LiteralPath $newF3)
Add-Result "Case3_ノート名部分更新" (Test-Path -LiteralPath $newNote3)
Add-Result "Case3_識別子重複なし(フォルダ)" ((Split-Path -Leaf $newF3) -notlike "*_[2250BA49]_[2250BA49]*")
Add-Result "Case3_識別子重複なし(ノート)" ((Split-Path -Leaf $newNote3) -notlike "*_[2250BA49]_[2250BA49]*")

# ==== Case4: 既に完全正式名 → NO_CHANGE、内容不変 ====
$v4 = New-CaseVault "Case4"
$f4 = Join-Path $v4.CustRoot ("Faithウエダ㈱" + $SUFFIX_A)
$note4 = New-TestNote $f4 ("🟨契約_Faithウエダ" + $SUFFIX_A + ".md") $UUID_A @("Faithウエダ㈱","代表太郎") "A"
$before4 = Get-FileHash -LiteralPath $note4 -Algorithm SHA256
$resp4 = Invoke-UciAndParse (New-UciPayload $v4.VaultRoot $UUID_A "Faithウエダ㈱" "代表太郎")
$after4 = Get-FileHash -LiteralPath $note4 -Algorithm SHA256
Add-Result "Case4_NO_CHANGE" ($resp4.status -eq "OK" -and $resp4.code -eq "NO_CHANGE") "$($resp4.status)/$($resp4.code)/$($resp4.userMessage)"
Add-Result "Case4_SHA256不変" ($before4.Hash -eq $after4.Hash)

# ==== Case5: 6noteType全てが同一UUID配下に共存 → 全て正式名+識別子へ ====
$v5 = New-CaseVault "Case5"
$f5 = Join-Path $v5.CustRoot "Faith5種顧客"
New-TestNote $f5 "🟨契約_Faith5種顧客.md" $UUID_A @("Faith5種顧客","代表太郎") "A" "本文_契約" | Out-Null
New-TestNote $f5 "🟥事故_Faith5種顧客.md" $UUID_A @("Faith5種顧客","代表太郎") "A" "本文_事故" | Out-Null
New-TestNote $f5 "◻️決算書_Faith5種顧客.md" $UUID_A @("Faith5種顧客","代表太郎") "A" "本文_決算書" | Out-Null
New-TestNote $f5 "⬛その他_Faith5種顧客.md" $UUID_A @("Faith5種顧客","代表太郎") "A" "本文_その他" | Out-Null
New-TestNote $f5 "✡️一覧_Faith5種顧客.md" $UUID_A @("Faith5種顧客","代表太郎") "A" "本文_契約一覧" | Out-Null
New-TestNote $f5 "⛔一覧_Faith5種顧客.md" $UUID_A @("Faith5種顧客","代表太郎") "A" "本文_事故一覧" | Out-Null
$resp5 = Invoke-UciAndParse (New-UciPayload $v5.VaultRoot $UUID_A "Faith5種顧客" "代表太郎")
$newF5 = Join-Path $v5.CustRoot ("Faith5種顧客" + $SUFFIX_A)
Add-Result "Case5_status_code" ($resp5.status -eq "OK" -and $resp5.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp5.status)/$($resp5.code)/$($resp5.userMessage)"
$expect5 = @{
  "契約"    = "🟨契約_Faith5種顧客" + $SUFFIX_A + ".md"
  "事故"    = "🟥事故_Faith5種顧客" + $SUFFIX_A + ".md"
  "決算書"  = "◻️決算書_Faith5種顧客" + $SUFFIX_A + ".md"
  "その他"  = "⬛その他_Faith5種顧客" + $SUFFIX_A + ".md"
  "契約一覧" = "✡️一覧_Faith5種顧客" + $SUFFIX_A + ".md"
  "事故一覧" = "⛔一覧_Faith5種顧客" + $SUFFIX_A + ".md"
}
foreach ($k in $expect5.Keys) {
  $p = Join-Path $newF5 $expect5[$k]
  Add-Result "Case5_${k}_正式名" (Test-Path -LiteralPath $p) $expect5[$k]
}

# ==== Case6: UUIDなし補助ノート → ファイル名・内容とも不変 ====
$v6 = New-CaseVault "Case6"
$f6 = Join-Path $v6.CustRoot "補助ノート顧客"
New-TestNote $f6 "🟨契約_補助ノート顧客.md" $UUID_A @("補助ノート顧客","代表太郎") "A" | Out-Null
$aux6 = Join-Path $f6 "補助メモ.md"
[System.IO.File]::WriteAllText($aux6, "UUIDなしの補助ノート本文", [System.Text.UTF8Encoding]::new($false))
$auxBefore6 = Get-FileHash -LiteralPath $aux6 -Algorithm SHA256
$resp6 = Invoke-UciAndParse (New-UciPayload $v6.VaultRoot $UUID_A "補助ノート顧客" "代表太郎")
$newF6 = Join-Path $v6.CustRoot ("補助ノート顧客" + $SUFFIX_A)
$movedAux6 = Join-Path $newF6 "補助メモ.md"
Add-Result "Case6_補助ノートはファイル名不変" (Test-Path -LiteralPath $movedAux6)
if (Test-Path -LiteralPath $movedAux6) {
  $auxAfter6 = Get-FileHash -LiteralPath $movedAux6 -Algorithm SHA256
  Add-Result "Case6_補助ノート内容不変" ($auxBefore6.Hash -eq $auxAfter6.Hash)
}

# ==== Case7: 別UUIDノートが混在 → FOLDER_UUID_MIXEDで停止 ====
$v7 = New-CaseVault "Case7"
$f7 = Join-Path $v7.CustRoot "混在顧客"
New-TestNote $f7 "🟨契約_混在顧客.md" $UUID_A @("混在顧客","代表太郎") "A" | Out-Null
New-TestNote $f7 "🟥事故_別顧客.md" $UUID_B @("別顧客","別代表") "B" | Out-Null
$resp7 = Invoke-UciAndParse (New-UciPayload $v7.VaultRoot $UUID_A "混在顧客" "代表太郎")
Add-Result "Case7_FOLDER_UUID_MIXED" ($resp7.status -eq "NG" -and $resp7.code -eq "FOLDER_UUID_MIXED") "$($resp7.status)/$($resp7.code)/$($resp7.userMessage)"
Add-Result "Case7_フォルダ名不変" (Test-Path -LiteralPath $f7)

# ==== Case8: 同一社名・異なるUUID識別子の2顧客が共存(同一VaultRoot内で意図的に共存させる) ====
$v8 = New-CaseVault "Case8"
$f8a = Join-Path $v8.CustRoot "Faith同名顧客_A"
$f8b = Join-Path $v8.CustRoot "Faith同名顧客_B"
New-TestNote $f8a "🟨契約_Faith同名顧客.md" $UUID_A @("Faith同名顧客","代表A") "A" | Out-Null
New-TestNote $f8b "🟨契約_Faith同名顧客.md" $UUID_C @("Faith同名顧客","代表B") "A" | Out-Null
$resp8a = Invoke-UciAndParse (New-UciPayload $v8.VaultRoot $UUID_A "Faith同名顧客" "代表A")
$resp8b = Invoke-UciAndParse (New-UciPayload $v8.VaultRoot $UUID_C "Faith同名顧客" "代表B")
$newF8a = Join-Path $v8.CustRoot ("Faith同名顧客" + $SUFFIX_A)
$newF8b = Join-Path $v8.CustRoot ("Faith同名顧客" + "_[9F13C842]")
Add-Result "Case8_顧客A正常処理" ($resp8a.status -eq "OK" -and $resp8a.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp8a.status)/$($resp8a.code)/$($resp8a.userMessage)"
Add-Result "Case8_顧客B正常処理" ($resp8b.status -eq "OK" -and $resp8b.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp8b.status)/$($resp8b.code)/$($resp8b.userMessage)"
Add-Result "Case8_両者共存(A)" (Test-Path -LiteralPath $newF8a)
Add-Result "Case8_両者共存(B)" (Test-Path -LiteralPath $newF8b)

# ==== Case9: 変更先パスに無関係な別ファイル(UUIDキーなし)が既に存在 → TARGET_NOTE_FILENAME_CONFLICT ====
$v9 = New-CaseVault "Case9"
$f9 = Join-Path $v9.CustRoot "衝突顧客"
New-TestNote $f9 "🟨契約_衝突顧客旧名.md" $UUID_A @("衝突顧客","代表太郎") "A" "正しい本文" | Out-Null
$conflictPath9 = Join-Path $f9 ("🟨契約_衝突顧客" + $SUFFIX_A + ".md")
[System.IO.File]::WriteAllText($conflictPath9, "無関係な既存ファイル(UUIDキーなし)", [System.Text.UTF8Encoding]::new($false))
$conflictBefore9 = Get-FileHash -LiteralPath $conflictPath9 -Algorithm SHA256
$resp9 = Invoke-UciAndParse (New-UciPayload $v9.VaultRoot $UUID_A "衝突顧客" "代表太郎")
Add-Result "Case9_TARGET_NOTE_FILENAME_CONFLICT" ($resp9.status -eq "NG" -and $resp9.code -eq "TARGET_NOTE_FILENAME_CONFLICT") "$($resp9.status)/$($resp9.code)/$($resp9.userMessage)"
$conflictAfter9 = Get-FileHash -LiteralPath $conflictPath9 -Algorithm SHA256
Add-Result "Case9_衝突先内容不変" ($conflictBefore9.Hash -eq $conflictAfter9.Hash)
Add-Result "Case9_元の旧名ノート残存" (Test-Path -LiteralPath (Join-Path $f9 "🟨契約_衝突顧客旧名.md"))

# ==== Case10: YAML管理キー破損だが本文境界は確定 → 修復+正式名化、本文保持 ====
$v10 = New-CaseVault "Case10"
$f10 = Join-Path $v10.CustRoot "修復顧客"
New-TestNote $f10 "🟨契約_修復顧客.md" $UUID_A @("修復顧客","代表太郎") "A" "正常ノート本文" | Out-Null
$p10 = Join-Path $f10 "🟥事故_修復顧客.md"
[System.IO.File]::WriteAllText($p10, "---`ntags:`n  broken: yes`nUUID: not-a-uuid`nrank_typo: A`n---`n本文は保持されるべき`n", [System.Text.UTF8Encoding]::new($false))
$resp10 = Invoke-UciAndParse (New-UciPayload $v10.VaultRoot $UUID_A "修復顧客" "代表太郎" "カブシキガイシャ")
$newF10 = Join-Path $v10.CustRoot ("修復顧客" + $SUFFIX_A)
$newNote10 = Join-Path $newF10 ("🟥事故_修復顧客" + $SUFFIX_A + ".md")
Add-Result "Case10_status_code" ($resp10.status -eq "OK" -and $resp10.code -eq "CUSTOMER_IDENTITY_UPDATED") "$($resp10.status)/$($resp10.code)/$($resp10.userMessage)"
Add-Result "Case10_修復後に正式名へ" (Test-Path -LiteralPath $newNote10)
if (Test-Path -LiteralPath $newNote10) {
  $body10 = Get-Content -LiteralPath $newNote10 -Raw -Encoding UTF8
  Add-Result "Case10_UUID修復" ($body10 -match [regex]::Escape($UUID_A))
  Add-Result "Case10_本文完全保持" ($body10 -match "本文は保持されるべき")
}

# ==== Case11: frontmatter開始行はあるが終了---が見つからない(境界判定不能) ====
$v11 = New-CaseVault "Case11"
$f11 = Join-Path $v11.CustRoot "境界不能顧客"
New-TestNote $f11 "🟨契約_境界不能顧客.md" $UUID_A @("境界不能顧客","代表太郎") "A" "正常ノート本文" | Out-Null
$p11 = Join-Path $f11 "🟥事故_境界不能顧客.md"
[System.IO.File]::WriteAllText($p11, "---`ntags:`n  - `"x`"`nUUID: $UUID_A`n本文相当(終了---なし)`n", [System.Text.UTF8Encoding]::new($false))
$before11 = Get-FileHash -LiteralPath $p11 -Algorithm SHA256
$resp11 = Invoke-UciAndParse (New-UciPayload $v11.VaultRoot $UUID_A "境界不能顧客" "代表太郎")
$after11 = Get-FileHash -LiteralPath $p11 -Algorithm SHA256
Add-Result "Case11_YAML_BODY_BOUNDARY_UNRESOLVED" ($resp11.status -eq "NG" -and $resp11.code -eq "YAML_BODY_BOUNDARY_UNRESOLVED") "$($resp11.status)/$($resp11.code)/$($resp11.userMessage)"
Add-Result "Case11_元ファイル完全不変" ($before11.Hash -eq $after11.Hash)

# ==== Case12: Update-Yaml-Robust呼び出し時に注入失敗 → 全リネーム・内容が完全ロールバック ====
$v12 = New-CaseVault "Case12"
$f12 = Join-Path $v12.CustRoot "ロールバック顧客"
New-TestNote $f12 "🟨契約_ロールバック顧客.md" $UUID_A @("ロールバック顧客","代表太郎") "A" "本文1" | Out-Null
New-TestNote $f12 "🟥事故_ロールバック顧客.md" $UUID_A @("ロールバック顧客","代表太郎") "A" "本文2" | Out-Null
$before12 = @{}
Get-ChildItem -LiteralPath $f12 -File | ForEach-Object { $before12[$_.Name] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }

$originalUpdateYamlRobust = ${function:Update-Yaml-Robust}
$script:uciFailCount = 0
function Update-Yaml-Robust($filePath, $rank, $cust, $ceo, $ruby, $uuid, [string]$totalPremium = $null) {
  $script:uciFailCount++
  if ($script:uciFailCount -ge 2) { throw "意図的な注入失敗(テスト用)" }
  & $script:originalUpdateYamlRobust $filePath $rank $cust $ceo $ruby $uuid $totalPremium
}
$resp12 = Invoke-UciAndParse (New-UciPayload $v12.VaultRoot $UUID_A "新ロールバック顧客" "代表太郎")
Set-Item "function:Update-Yaml-Robust" -Value $originalUpdateYamlRobust

Add-Result "Case12_NOTE_UPDATE_FAILEDでロールバック" ($resp12.status -eq "NG" -and $resp12.code -eq "NOTE_UPDATE_FAILED") "$($resp12.status)/$($resp12.code)/$($resp12.userMessage)"
Add-Result "Case12_フォルダ名復元" ((Test-Path -LiteralPath $f12) -and -not (Test-Path -LiteralPath (Join-Path $v12.CustRoot ("新ロールバック顧客" + $SUFFIX_A))))
$after12 = @{}
if (Test-Path -LiteralPath $f12) {
  Get-ChildItem -LiteralPath $f12 -File | ForEach-Object { $after12[$_.Name] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
}
$rollbackMatch = ($before12.Count -eq $after12.Count)
if ($rollbackMatch) {
  foreach ($k in $before12.Keys) {
    if (-not $after12.ContainsKey($k) -or $after12[$k] -ne $before12[$k]) { $rollbackMatch = $false; break }
  }
}
Add-Result "Case12_全ファイル名SHA256完全復元" $rollbackMatch "before=$($before12.Keys -join ',') after=$($after12.Keys -join ',')"

# ==== Case13: 正規化後、legacy CHECKのUUID+noteType優先解決(既存機能)が正常機能する ====
$v13 = New-CaseVault "Case13"
$f13 = Join-Path $v13.CustRoot "統合確認顧客"
New-TestNote $f13 "🟨契約_統合確認顧客.md" $UUID_A @("統合確認顧客","代表太郎") "A" | Out-Null
$resp13 = Invoke-UciAndParse (New-UciPayload $v13.VaultRoot $UUID_A "統合確認顧客" "代表太郎")
$newF13 = Join-Path $v13.CustRoot ("統合確認顧客" + $SUFFIX_A)
$canonicalNote13 = "🟨契約_統合確認顧客" + $SUFFIX_A + ".md"
$uciMatches13 = @()
if (Test-Path -LiteralPath $newF13) { $uciMatches13 = Get-UuidNoteTypeMatches $newF13 "🟨契約" $UUID_A }
Add-Result "Case13_正規化後もUUID優先解決で1件一致" (@($uciMatches13).Count -eq 1 -and (Split-Path -Leaf $uciMatches13[0]) -eq $canonicalNote13) "matches=$(@($uciMatches13).Count)"

# ---- 結果出力 ----
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
  Write-Output "[NG] 失敗ケースあり。上記詳細を確認してください。"
  exit 1
}
