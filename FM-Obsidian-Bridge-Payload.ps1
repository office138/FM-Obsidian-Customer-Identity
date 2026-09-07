<# =====================================================
FM-Obsidian-Bridge-Payload.ps1
Ver: 9.1.0 (2026-08-29) - Customer Folder Merge v1 Implementation

【概要】
FileMaker（顧客管理システム）から送信されたJSONペイロードを受け取り、
ObsidianのVault内に該当顧客のMarkdownファイル（契約一覧、事故対応など）を
検索・作成・更新して自動的に開くための高度なブリッジスクリプトです。

【主な機能】
1. ペイロード解析: Base64エンコードされたJSONを解読し、顧客情報やアクションを取得。
2. 正規化と検索: 会社名のゆらぎ（株式会社、(株)、㈲など）を吸収し、既存フォルダを正確に特定。
3. YAMLフロントマターのインテリジェント更新: 既存のタグやUUIDを保持したまま、ランクや合計保険料などを安全に上書き。
4. Pythonスクリプト連携 (COMPAREモード): 事故や契約の差分突合処理を外部Pythonスクリプト(diff_checker.py等)に委譲。
5. 新規作成時の自動フォーマット: 事故一覧などの場合、対応中/完了などの必要なテーブルテンプレートを自動挿入。

【★ バージョン8.3.0 での最適化ポイント (Advanced URI → 標準URI) 】
旧バージョンで使用していた「Advanced URIプラグイン + JavaScriptによるUI操作（フォルダの折りたたみ等）」を廃止し、
Obsidian標準の obsidian://open?vault=<name>&file=<relpath> URIスキームで開く方式へ統一しました。
※ 公式CLIはAPIキー(OBSIDIAN_API_KEY)が全コマンドで必要なため、APIキー不要の標準URIスキームを採用。

これにより、以下のメリットをもたらします。
- プラグイン依存からの完全脱却（Obsidian本体の機能のみで完結）。
- CLIのAPIキー設定が不要（環境構築の手間を削減）。
- UI描画の待機時間（意図的な遅延処理の約0.45秒）を削減し、FileMakerからの呼び出しレスポンスを高速化。

【v8.2.0 → v8.3.0 修正内容】
- Open-ObsidianFile: CLI方式(& obsidian vault=... open path=...) → 標準URIスキーム(Start-Process obsidian://open)に変更。
- Assert-ObsidianReady: CLI存在チェックを削除 → Obsidianプロセス起動チェックのみに簡素化。

【v8.3.1 修正内容】
- FileMakerから渡されたobs_RELPATHが実在し、UUIDとnoteTypeが一致する場合、保存済みUUID付き正式ノートを最優先で採用。
- UUID付き正式ノートが存在する状態でlegacy CHECKがUUIDなしノートを重複作成する問題を修正。

【★ v9.0.0 修正内容 (UUIDなし顧客フォルダ重複作成バグの恒久修正) 】
- customer folder identityを「完全UUID(pk_CLIENT) == YAML frontmatterのUUID」でのみ確定する方式へ統一。
  顧客名/正規化名/フォルダ名/UUID先頭8文字/folderNameConfirmed/obs_RELPATHはidentity authorityにしない。
- canonical顧客フォルダ名を "<Sanitize-LeafNameされた顧客名>_[<pk_CLIENT先頭8文字大文字>]" に一元化し、
  新規フォルダ作成・NEED_FOLDER_CONFIRMのsuggest・作成直前の再確認をすべてcanonical名に固定。
- folderNameConfirmedは「新規作成継続のgo-ahead」としてのみ扱い、命名authorityを剥奪。
- legacy顧客フォルダ(UUIDなし)に完全UUID証拠がある場合は、別フォルダを作らずcanonical名へRename昇格。
  完全UUID証拠が無いlegacyはLEGACY_FOLDER_NEEDS_MIGRATIONで安全停止。
- canonical名フォルダが存在しても完全UUID証拠が無い場合はCANONICAL_FOLDER_NO_UUID_EVIDENCEで安全停止(UUID8衝突対策)。
- customer identity discoveryは再帰検索可。ただし正式managed noteのduplicate判定はcustomer folder直下のみ。
  サブフォルダ内の同一UUID+同一noteTypeはdirect-child件数へ混ぜず、MANAGED_NOTE_OUT_OF_SCOPEで安全停止。
- folder evidence状態(Matched/NoEvidence/Conflict/InvalidYaml/InvalidUuid)を明示的に区別し、
  InvalidYaml → YAML_BODY_BOUNDARY_UNRESOLVED / Conflict → FOLDER_UUID_MIXED / InvalidUuid → FOLDER_UUID_INVALID で停止。
- obs_RELPATHは「note locator hint」に格下げ。検証は弱体化させず、folder identity確定後に最終フォルダ上で再検証して採用。
- 新規ノート作成をNew-Item -Forceから FileMode::CreateNew へ変更し、既存ファイルの破壊を防止。

【★ v9.0.1 修正内容 (残存MAJOR 2件のピンポイント修正) 】
- MAJOR-1: 通常managed note解決から「filename fuzzy候補をUUID未検証で$targetAbsへ採用する経路」を廃止。
- MAJOR-2: Get-UciResolvedNotesのduplicate件数およびresolvedNotes配列をcustomer folder直下(direct-child)のみに限定。
  「direct-child 1件 + subfolder 1件」でDUPLICATE_NOTE_TYPEになる誤検出(T18)を解消。

【★ v9.0.2 修正内容 (残存2点のピンポイント修正) 】
- FIX-1: 「UUID未検証のcanonicalFileを$targetAbs経由で既存managed noteとして採用してしまう抜け道」を完全に封鎖した。
  v9.0.1では direct-child UUID一致0件のときに
      $targetAbs = Join-Path $currentFolderFull $canonicalFile
  としていたため、canonicalFileと同名の既存ファイルが存在し、かつそのYAML UUIDがpk_CLIENTと
  一致していない(あるいはUUIDキー自体が無い)場合でも、後続の
      if ($targetAbs -and (Test-Path -LiteralPath $targetAbs)) { Update-Yaml-Robust $targetAbs ... }
  へ流れ、未検証ファイルへ対象顧客のUUIDを書き込む可能性が残っていた。
  本版では、$targetAbsへ設定してよいのは
      customer folder直下 + noteType接頭辞一致 + YAML完全UUID == pk_CLIENT
  を満たしUUID検証済みのファイル(Get-UuidNoteTypeMatches / 再検証済みobs_RELPATH hint)だけとし、
  direct-child UUID一致0件の場合は $targetAbs = $null のままにする。
  新規CREATE候補pathは別変数 $newCandidateAbs へ完全分離し、$targetAbsとは絶対に混同しない。
  $newCandidateAbsが既に実在する場合は、そのファイルを既存managed noteとして採用せず、
  TARGET_NOTE_FILENAME_CONFLICT でFail-closedする(既存ファイルへUUIDを書き込む「正規化」は行わない)。
- FIX-2: v9.0.1でfuzzy候補検出時に追加したWrite-Host診断出力を削除した。
  FileMakerとの通常応答契約(OK|... / NG|...)へ新規の診断出力を混在させない。
  fuzzy候補は内部変数($fuzzyCandidates)へ保持するのみとし、必要な場合はNG detailsへ含める。

【★ v9.0.3 修正内容 (folderNameConfirmed契約不整合の最終修正 / 変更点は1箇所のみ) 】
- folderNameConfirmedを命名authorityには戻さず、canonicalFolderNameとの一致確認を必須化。
  不一致時はFOLDER_CONFIRMATION_MISMATCHでFail-closed。
- 背景: v9.0.2までは
      $hasGoAhead = ($payload.ContainsKey("folderNameConfirmed") -and 非空)
  として「非空なら何でもgo-ahead」と扱っていた。現行FileMaker側(EXT-obs_OBSノート-開く)は
  NEED_FOLDER_CONFIRM時に $$obsFolderNameInput を編集可能フィールドとして提示し、その入力値を
  folderNameConfirmedとして再送するUI契約を維持している。そのため、オペレータが候補一覧から
  canonical名以外(例: 部分一致で候補表示された "ABC商事")を選択・確定しても、PowerShellは
  その値を黙って捨ててcanonical名("ABC_[12345678]")でCREATEしてしまい、
  「オペレータが別の既存フォルダを選んだのに無言で無視して別フォルダを作る」状態になっていた。
- 対応: folderNameConfirmedは引き続きnaming authorityにしない(値からフォルダ名を組み立てない)。
  ただしgo-aheadとして受け入れる前に、既存Sanitize-LeafNameを通した値が
  canonicalFolderNameとOrdinalIgnoreCaseで一致することを必須条件とする。
  一致した場合のみ$hasGoAhead = $trueとし、不一致の場合は
      NG|FOLDER_CONFIRMATION_MISMATCH|...
  で即時停止する。不一致時は、確認された名前のフォルダを既存採用しない/そこへ移動しない/
  canonicalフォルダも作成しない/ノートも作成しない(完全Fail-closed)。
- 新規helper関数は追加していない(既存Sanitize-LeafName / Out-NGのみを使用)。
- 正常系(NEED_FOLDER_CONFIRMのsuggestであるcanonical名をそのまま確認して再送する流れ)は不変。

【★ v9.0.4 修正内容 (PowerShell配列返却契約修正 / MANAGED_NOTE_OUT_OF_SCOPE誤発火解消) 】
- array-return helper関数 (Get-UuidNoteTypeMatches, Get-UuidNoteTypeMatchesInTree,
  Get-UciOutOfScopeManagedNotes, Get-UciFuzzyNameCandidates) において、
  過剰な単項カンマ演算子(,)による空配列の1オブジェクト化を廃止し、通常の配列返却へ統一。
- 呼び出し側の @(...) 配列サブ式との組み合わせによる nested empty array (Count=1 / Item[0]=@())
  誤判定を解消し、検索結果0件時に確実に Count=0 となるよう配列返却契約を正常化。
- 本修正により、サブフォルダに同UUID・同noteTypeのノートが存在しない正常ケースにおいて
  MANAGED_NOTE_OUT_OF_SCOPE (空Path) が誤発火する回帰バグを解消。
- サブフォルダ側に同UUID+同noteTypeが実際に存在する genuine な out-of-scope ケースにおける
  MANAGED_NOTE_OUT_OF_SCOPE の Fail-closed 安全防御はそのまま維持。

【前提条件】
- 対象Vaultが Obsidian に既知のVaultとして登録済みであること。
- Obsidian の obsidian:// URIスキームがOSに登録されていること（通常はインストール時に自動登録）。
===================================================== #>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)][string]$PayloadB64,
  [Parameter(Mandatory = $false)][string]$PayloadFile
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---- ヘルパー関数 ----
function Out-OK([string]$kind, [string]$url, [string]$rel, [string]$lwIso, [string]$diffB64) {
  Write-Output ("OK|{0}|{1}|{2}|{3}|{4}" -f $kind, $url, $rel, $lwIso, $diffB64)
  exit 0
}
function Out-OKNeedFolder([string[]]$cands, [string]$suggest, [string]$nameNorm, [string]$expectedFileName) {
  $cleanCands = $cands | ForEach-Object { $_ -replace "[\s　]+", "" }
  $joined = ($cleanCands | Select-Object -First 20) -join ";"
  Write-Output ("OK|NEED_FOLDER_CONFIRM|{0}|{1}|{2}|{3}" -f $joined, $suggest, $nameNorm, $expectedFileName)
  exit 0
}
function Out-NG([string]$kind, [string]$details) {
  Write-Output ("NG|{0}|{1}|||" -f $kind, $details)
  exit 0
}

function Get-RelPath([string]$vaultRoot, [string]$absPath) {
  $rel = $absPath.Substring($vaultRoot.Length).TrimStart("\","/")
  return ($rel -replace "\\", "/")
}

function Test-PythonExecutablePath([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path) -or $path -match "[`r`n]") { return $false }
  if (-not [System.IO.Path]::IsPathRooted($path)) { return $false }
  if (-not [string]::Equals([System.IO.Path]::GetExtension($path), ".exe", [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
  return (Test-Path -LiteralPath $path -PathType Leaf)
}

function Resolve-PythonExecutable {
  $explicitPath = [string]$env:FM_OBSIDIAN_PYTHON
  if (-not [string]::IsNullOrWhiteSpace($explicitPath)) {
    if (-not (Test-PythonExecutablePath $explicitPath)) {
      throw "FM_OBSIDIAN_PYTHON must name an existing Python executable (.exe)."
    }
    return [PSCustomObject]@{ FilePath = $explicitPath; PrefixArguments = @() }
  }

  foreach ($candidate in @(
    [PSCustomObject]@{ Name = "py.exe"; PrefixArguments = @("-3") },
    [PSCustomObject]@{ Name = "python.exe"; PrefixArguments = @() },
    [PSCustomObject]@{ Name = "python3.exe"; PrefixArguments = @() }
  )) {
    $command = Get-Command -Name $candidate.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command -and (Test-PythonExecutablePath ([string]$command.Source))) {
      return [PSCustomObject]@{ FilePath = [string]$command.Source; PrefixArguments = @($candidate.PrefixArguments) }
    }
  }

  throw "Python executable not found. Set FM_OBSIDIAN_PYTHON or install py.exe/python.exe."
}

function Get-ObsidianOpenUrl([string]$vaultRoot, [string]$relPath) {
  $vaultName = Split-Path $vaultRoot -Leaf
  $relNorm = $relPath -replace "\\", "/"
  return ("obsidian://open?vault={0}&file={1}" -f `
    [Uri]::EscapeDataString($vaultName), `
    [Uri]::EscapeDataString($relNorm))
}

function Assert-ObsidianReady {
  # URIスキーム方式ではCLI PATHは不要。
  # Obsidian未起動でもURIスキーム経由でOSが自動起動するが、
  # 起動直後はVaultのインデックスが未完了のため少し待つ。
  $proc = Get-Process "Obsidian" -ErrorAction SilentlyContinue
  if ($null -eq $proc) {
    Write-Host "Obsidian未起動のためURIスキーム経由で起動します..." -ForegroundColor Yellow
    Start-Process "obsidian://open"
    Start-Sleep -Seconds 3
  }
}

function Open-ObsidianFile([string]$vaultRoot, [string]$relPath) {
  # 標準URIスキーム: obsidian://open?vault=<name>&file=<relpath>
  # - プラグイン不要（Obsidian本体の標準機能）
  # - APIキー不要（CLIと異なりURIスキームは認証なし）
  # - Obsidian未起動でもOSが自動起動
  $url = Get-ObsidianOpenUrl $vaultRoot $relPath
  Start-Process $url
}

function From-Base64Any([string]$b64) {
  $s = ($b64 -replace "-", "+").Replace("_", "/")
  $pad = (4 - ($s.Length % 4)) % 4
  if ($pad -gt 0 -and $pad -lt 4) { $s += ("=" * $pad) }
  return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s))
}

function ConvertTo-Hashtable($obj) {
  if ($null -eq $obj) { return $null }
  if ($obj -is [string] -or $obj.GetType().IsPrimitive) { return $obj }
  if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [System.Collections.IDictionary])) {
    $arr = [System.Collections.ArrayList]::new()
    foreach ($it in $obj) { [void]$arr.Add((ConvertTo-Hashtable $it)) }
    return $arr.ToArray()
  }
  if ($obj -is [System.Collections.IDictionary]) {
    $h = @{}
    foreach ($k in $obj.Keys) { if ($null -ne $k) { $h[$k] = ConvertTo-Hashtable $obj[$k] } }
    return $h
  }
  if ($obj -is [psobject]) {
    $h = @{}
    foreach ($p in $obj.PSObject.Properties) { if (-not [string]::IsNullOrEmpty($p.Name)) { $h[$p.Name] = ConvertTo-Hashtable $p.Value } }
    return $h
  }
  return $obj
}

function Sanitize-LeafName([string]$s, [string]$fallback = "NO_NAME") {
  if ([string]::IsNullOrWhiteSpace($s)) { return $fallback }
  $t = $s.Trim()
  $t = [regex]::Replace($t, "[\p{C}]", "")
  $t = [regex]::Replace($t, "\s+|　+", "")
  $t = [regex]::Replace($t, '[\\/:*?"<>|]', "－")
  $t = $t.Trim(@("・","_","-","－"," ","."))
  if ([string]::IsNullOrWhiteSpace($t)) { $t = $fallback }
  if ($t -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$') { $t = "${t}_File" }
  return $t
}

function Normalize-ForMatch([string]$s) {
    $t = $s -replace "株式会社","" -replace "\(株\)","" -replace "（株）","" -replace "㈱",""
    $t = $t -replace "有限会社","" -replace "\(有\)","" -replace "（有）","" -replace "㈲",""
    return (Sanitize-LeafName $t)
}

function Get-IconPrefix([string]$type) {
    switch -Wildcard ($type) {
        "*契約一覧*" { return [char]::ConvertFromUtf32(0x2721) + [char]::ConvertFromUtf32(0xFE0F) + "一覧" } # ✡️一覧
        "*事故一覧*" { return [char]::ConvertFromUtf32(0x26D4) + "一覧" }  # ⛔一覧
        "*契約*" { return [char]::ConvertFromUtf32(0x1F7E8) + "契約" } # 🟡契約
        "*事故*" { return [char]::ConvertFromUtf32(0x1F7E5) + "事故" } # 🔴事故
        "*決算*" { return [char]::ConvertFromUtf32(0x25FB) + [char]::ConvertFromUtf32(0xFE0F) + "決算書" }
        default  { return [char]::ConvertFromUtf32(0x2B1B)  + "その他" }
    }
}

function Load-IndexSafe([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return @{} }
  try {
    $raw = (Get-Content -LiteralPath $path -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
    $tmp = ConvertTo-Hashtable (ConvertFrom-Json $raw)
    if ($tmp -is [hashtable]) { return $tmp }
  } catch { return @{} }
  return @{}
}

function Extract-TableTotal([string]$filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return $null }
    try {
        $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.UTF8Encoding]::new($false))
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            $line = $lines[$i]
            if ($line.Contains("合計") -and $line.Contains("|")) {
                $cols = $line.Split("|")
                $vals = $cols | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                if ($vals.Count -ge 2) {
                    $potentialVal = $vals[-1]
                    $valDigits = $potentialVal -replace "[*]", "" -replace ",", "" -replace "[\s　]", ""
                    if ($valDigits -match "^\d+$") { return ($potentialVal -replace "[*]", "") }
                }
            }
        }
    } catch {}
    return $null
}

function Update-Yaml-Robust($filePath, $rank, $cust, $ceo, $ruby, $uuid, [string]$totalPremium = $null) {
    if (-not (Test-Path -LiteralPath $filePath)) { return }
    $fInfo = Get-Item -LiteralPath $filePath
    if ($fInfo.Length -eq 0) { $lines = @() } else {
        $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.UTF8Encoding]::new($false))
    }
    $cleanTags = @()
    foreach ($val in @($cust, $ceo, $ruby)) {
        if (-not [string]::IsNullOrWhiteSpace($val)) {
            $c = $val -replace "[\s　]+", ""
            if (-not [string]::IsNullOrEmpty($c)) { $cleanTags += $c }
        }
    }
    $startIdx = -1; $endIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($null -eq $lines[$i]) { continue }
        if ($lines[$i].Trim() -eq "---") {
            if ($startIdx -eq -1) { $startIdx = $i }
            else { $endIdx = $i; break }
        }
    }
    $oldHeaderLines = @(); $bodyLines = @()
    if ($startIdx -eq 0 -and $endIdx -gt 0) {
        if ($endIdx -gt 1) {
            $len = ($endIdx - 1) - 1 + 1
            if ($len -gt 0) { $oldHeaderLines = $lines[1..($endIdx-1)] }
        }
        if ($lines.Count -gt ($endIdx+1)) { $bodyLines = $lines[($endIdx+1)..($lines.Count-1)] }
    } else { $bodyLines = $lines }

    $keptLines = [System.Collections.ArrayList]::new()
    $skipMode = $false
    foreach ($line in $oldHeaderLines) {
        if ($null -eq $line) { continue }
        $trim = $line.Trim()
        if ($trim.StartsWith("tags:")) { $skipMode = $true; continue }
        if ($trim.StartsWith("UUID:")) { $skipMode = $false; continue }
        if ($trim.StartsWith("ランク:")) { $skipMode = $false; continue }
        if ($trim.StartsWith("総合計保険料:")) { $skipMode = $false; continue }
        if ($skipMode) {
            if ($line -match "^\s*-") { continue }
            $skipMode = $false
            if ($trim.StartsWith("UUID:")) { continue }
            if ($trim.StartsWith("ランク:")) { continue }
            if ($trim.StartsWith("総合計保険料:")) { continue }
        }
        [void]$keptLines.Add($line)
    }
    $newHeader = [System.Collections.ArrayList]::new()
    [void]$newHeader.Add("tags:")
    foreach ($tag in $cleanTags) { [void]$newHeader.Add("  - ""$tag""") }
    [void]$newHeader.Add("UUID: $uuid")
    [void]$newHeader.Add("ランク: $rank")
    if (-not [string]::IsNullOrWhiteSpace($totalPremium)) {
        [void]$newHeader.Add("総合計保険料: $totalPremium")
    }
    $newHeader.AddRange($keptLines)
    $finalContent = @("---") + $newHeader + @("---") + $bodyLines
    [System.IO.File]::WriteAllLines($filePath, $finalContent, [System.Text.UTF8Encoding]::new($false))
}

# ========================================================
# UPDATE_CUSTOMER_IDENTITY 最小差分実装 (2026-07-28)
# 既存のCHECK/COMPARE/APPLY/通常ノートオープン処理とは独立した新規action。
# 顧客名・代表者名・RUBY・RANKをFileMakerの最新値でObsidianへ反映し、
# 顧客フォルダ名を最新顧客名へ変更する。既存処理へは一切流れない。
# ========================================================

function Get-YamlHeaderLines([string]$filePath) {
  # 戻り値:
  #   @()      ... frontmatterなし(1行目が"---"でない)。UUIDキーなしの補助ノートとして扱う。
  #   $null    ... frontmatterが閉じていない(開始"---"はあるが終了"---"がない) = 不正YAML
  #   string[] ... frontmatter内側の行配列(開始/終了の"---"自身は含まない)
  # 注意(2026-07-28修正): PowerShellは配列を出力ストリームへ書き出す際に自動的に列挙(unroll)
  # するため、要素数0の配列を素の "return @()" で返すと、呼び出し側では意図した空配列ではなく
  # $null として受け取られてしまう(既知のPowerShellの挙動)。これにより、本来「frontmatterなし
  # ・UUIDキーなしの補助ノート」として許容すべきケースが、呼び出し側の "$null -eq $hdr" 判定に
  # 誤って合致し、INVALID_YAMLとして拒否される不具合があった(Windows PowerShell 5.1実行試験の
  # Case09で判明)。単項カンマ演算子(,)で配列を1段階分ラップしてから返すことで、呼び出し側が
  # 本当に空配列を受け取れるようにする(この関数の戻り値の意味・呼び出し側のロジックは不変)。
  if (-not (Test-Path -LiteralPath $filePath)) { return ,@() }
  $fInfo = Get-Item -LiteralPath $filePath
  if ($fInfo.Length -eq 0) { return ,@() }
  $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.UTF8Encoding]::new($false))
  if ($lines.Count -eq 0) { return ,@() }
  if ($lines[0].Trim() -ne "---") { return ,@() }
  $endIdx = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "---") { $endIdx = $i; break }
  }
  if ($endIdx -eq -1) { return $null }
  if ($endIdx -eq 1) { return ,[string[]]@() }
  return $lines[1..($endIdx - 1)]
}

function Get-YamlBodyLines([string]$filePath) {
  # Get-YamlHeaderLinesと同一の境界規則で、frontmatter終了"---"より後ろの本文行を返す。
  # frontmatterが無いファイルは全行を本文として返す。frontmatterが閉じていない場合は$null。
  # 更新後再読込確認で「本文が変更されていないこと」を検証するために使用する。
  if (-not (Test-Path -LiteralPath $filePath)) { return @() }
  $fInfo = Get-Item -LiteralPath $filePath
  if ($fInfo.Length -eq 0) { return @() }
  $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.UTF8Encoding]::new($false))
  if ($lines.Count -eq 0) { return @() }
  if ($lines[0].Trim() -ne "---") { return $lines }
  $endIdx = -1
  for ($i = 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "---") { $endIdx = $i; break }
  }
  if ($endIdx -eq -1) { return $null }
  if ($lines.Count -gt ($endIdx + 1)) { return $lines[($endIdx + 1)..($lines.Count - 1)] }
  return [string[]]@()
}

function Get-YamlScalarValue($headerLines, [string]$keyPrefix) {
  if ($null -eq $headerLines) { return "" }
  foreach ($line in $headerLines) {
    if ($null -eq $line) { continue }
    $t = $line.Trim()
    if ($t.StartsWith($keyPrefix)) {
      $v = $t.Substring($keyPrefix.Length).Trim()
      if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
        $v = $v.Substring(1, $v.Length - 2)
      }
      return $v
    }
  }
  return ""
}

function Get-YamlTagValues($headerLines) {
  $result = [System.Collections.ArrayList]::new()
  if ($null -eq $headerLines) { return $result.ToArray() }
  $inTags = $false
  foreach ($line in $headerLines) {
    if ($null -eq $line) { continue }
    $trim = $line.Trim()
    if ($trim -eq "tags:" -or $trim.StartsWith("tags:")) {
      $inTags = $true
      continue
    }
    if ($inTags) {
      if ($line -match "^\s*-\s*(.*)$") {
        $v = $Matches[1].Trim()
        if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
          $v = $v.Substring(1, $v.Length - 2)
        }
        [void]$result.Add($v)
      } else {
        $inTags = $false
      }
    }
  }
  return $result.ToArray()
}

function Get-UuidNoteTypeMatches([string]$folderPath, [string]$iconPrefix, [string]$uuid) {
  # 重複ノート作成防止(2026-07-29回帰修正)。
  # 指定フォルダ内で、指定アイコン接頭辞(Get-IconPrefixの戻り値)のファイル名パターンに一致し、
  # かつYAML frontmatter内の"UUID:"キーが指定UUIDと一致する既存ノートを列挙する。
  # ※この関数は非再帰(customer folder直下のみ)であり、正式managed noteのduplicate判定・
  #   採用判定における唯一のauthorityである(v9.0.1で位置付けを明確化、v9.0.2で徹底)。
  # UUID一致判定はGet-YamlHeaderLines/Get-YamlScalarValueという既存の共通関数をそのまま再利用し、
  # 本文中の文字列一致など、frontmatter外のUUID一致は判定対象にしない。
  # UUIDが空の場合は判定不能として空配列を返す(呼び出し側は0件と同様に扱われ、既存挙動を維持する)。
  # 戻り値: 一致したファイルの絶対パスの配列(0件・1件・複数件のいずれもあり得る)。
  # ★ v9.0.4: 単項カンマ(,)による過剰ラップを廃止し、呼び出し側 @(...) で正しく 0/1/複数件を受け取れるよう修正。
  $matched = [System.Collections.ArrayList]::new()
  if ([string]::IsNullOrWhiteSpace($uuid)) { return $matched.ToArray() }
  $candidates = Get-ChildItem -LiteralPath $folderPath -Filter "${iconPrefix}_*.md" -File -ErrorAction SilentlyContinue
  foreach ($f in $candidates) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if (-not [string]::IsNullOrWhiteSpace($u) -and $u.ToUpperInvariant() -eq $uuid.ToUpperInvariant()) {
      [void]$matched.Add($f.FullName)
    }
  }
  return $matched.ToArray()
}

# ---- UUID識別子付き正式命名規則への常時正規化(2026-07-29追加) ----
# 既存のGet-IconPrefix(noteType→アイコン接頭辞)を6noteType分呼び出して
# 「接頭辞→noteType名」の逆引き表を作る。アイコン絵文字コードポイントを
# ここで新規にハードコードすることはせず、既存関数を必ず経由する。
function Get-UciKnownPrefixMap() {
  $map = @{}
  foreach ($nt in @("契約一覧","事故一覧","契約","事故","決算書","その他")) {
    $map[(Get-IconPrefix $nt)] = $nt
  }
  return $map
}

# legacy CHECK区分内(本ファイル後方、$n/$nameNorm生成ブロック)と全く同一の
# 会社種別語の正規化規則を、Invoke-UpdateCustomerIdentity内のノートファイル名
# 生成のために複製したもの。独自の会社種別除去・略称化ロジックは追加しない。
# legacy CHECK側の既存インラインコードはdiff最小化のため変更せず温存する。
function Get-NoteNameNormForUci([string]$nameRaw, [string]$noteTypeLike) {
  $n = $nameRaw.Trim()
  if ($noteTypeLike -match "一覧") {
    $n = $n -replace "株式会社", "㈱" -replace "有限会社", "㈲"
    $n = $n -replace "（株）", "㈱" -replace "\(株\)", "㈱"
    $n = $n -replace "（有）", "㈲" -replace "\(有\)", "㈲"
  } else {
    $remove = @("株式会社","有限会社","合同会社","合名会社","合資会社","（株）","(株)","㈱","有限","（有）","(有)","㈲")
    foreach ($r in $remove) { $n = $n -replace [regex]::Escape($r), "" }
  }
  return (Sanitize-LeafName $n "NO_NAME")
}

# pk_CLIENT先頭8文字を大文字化し"_[XXXXXXXX]"の形式で返す。
# ハイフン除去やハッシュ化は行わない(先頭8文字の単純な部分文字列)。
function Get-UciUuidSuffix([string]$pkClient) {
  return "_[" + $pkClient.Substring(0,8).ToUpperInvariant() + "]"
}

# 回帰修正(2026-07-29c): payloadのVaultRootが8.3短縮パス(例: <VAULT_ROOT_SHORT>)で
# 渡される一方、Get-ChildItemが返すFullNameが長いパス形式になる場合があり、両者の
# 文字列長が食い違う。文字列長・trim位置に依存する切り出しは切り出し位置がずれる
# 危険があるため、DirectoryInfo/FileInfoの.Parent/.Directoryを辿る方式に統一し、
# 各階層の比較は必ずOrdinalIgnoreCaseで行う(8.3短縮パス・長いパス・末尾区切り・
# 文字列長の違いに一切依存しない)。
function Resolve-UciDirectChildFolder([System.IO.DirectoryInfo]$rootInfo, [string]$filePath) {
  # $filePathの祖先ディレクトリを辿り、$rootInfo直下(直接の子)にあたるDirectoryInfoを返す。
  # $rootInfo配下として解決できない場合は$nullを返す(呼び出し側で安全に停止する)。
  $dir = [System.IO.FileInfo]::new($filePath).Directory
  while ($null -ne $dir) {
    $parent = $dir.Parent
    if ($null -ne $parent -and [string]::Equals($parent.FullName, $rootInfo.FullName, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $dir
    }
    $dir = $parent
  }
  return $null
}

function Get-UciRelativePath([System.IO.DirectoryInfo]$folderInfo, [string]$filePath) {
  # $folderInfo配下にある$filePathの相対パス(サブフォルダを含む場合はそれも保持)を、
  # 文字列長に依存せずセグメント名の積み上げ+結合で算出する。
  # $folderInfo配下として解決できない場合は$nullを返す(呼び出し側で安全に停止する)。
  $fi = [System.IO.FileInfo]::new($filePath)
  $segments = [System.Collections.ArrayList]::new()
  [void]$segments.Add($fi.Name)
  $dir = $fi.Directory
  while ($null -ne $dir) {
    if ([string]::Equals($dir.FullName, $folderInfo.FullName, [System.StringComparison]::OrdinalIgnoreCase)) {
      $arr = $segments.ToArray()
      [array]::Reverse($arr)
      return ($arr -join [System.IO.Path]::DirectorySeparatorChar)
    }
    [void]$segments.Add($dir.Name)
    $dir = $dir.Parent
  }
  return $null
}

function New-UCIResponse([string]$requestIdRaw, [string]$status, [string]$code, [string]$userMessage, [int]$updatedFiles = 0, [bool]$folderRenamed = $false, [string]$oldFolder = $null, [string]$newFolder = $null, [int]$renamedNoteCount = 0, [string]$uuidSuffixOut = $null, $renamedNotes = $null, $resolvedNotesOut = $null) {
  $reqIdOut = $null
  if (-not [string]::IsNullOrEmpty($requestIdRaw)) { $reqIdOut = $requestIdRaw }
  $resp = [ordered]@{
    status        = $status
    code          = $code
    userMessage   = $userMessage
    requestId     = $reqIdOut
    updatedFiles  = $updatedFiles
    folderRenamed = $folderRenamed
  }
  if (-not [string]::IsNullOrEmpty($oldFolder)) { $resp["oldFolder"] = $oldFolder }
  if (-not [string]::IsNullOrEmpty($newFolder)) { $resp["newFolder"] = $newFolder }
  if ($renamedNoteCount -gt 0) { $resp["renamedNoteCount"] = $renamedNoteCount }
  if (-not [string]::IsNullOrEmpty($uuidSuffixOut)) { $resp["uuidSuffix"] = $uuidSuffixOut }
  if ($null -ne $renamedNotes -and @($renamedNotes).Count -gt 0) { $resp["renamedNotes"] = @($renamedNotes) }
  # resolvedNotes(2026-07-30追加): 成功応答では常時出力する(0件でも空配列)。
  if ($null -ne $resolvedNotesOut) { $resp["resolvedNotes"] = @($resolvedNotesOut) }
  return ($resp | ConvertTo-Json -Depth 5)
}

# 構造化NG応答(衝突・境界未解決等)用の汎用拡張応答ビルダー。
# New-UCIResponseと同じ基本形(status/code/userMessage/requestId/updatedFiles/folderRenamed)を
# 維持しつつ、診断用の追加フィールドをhashtableで自由に追加できるようにする。
function New-UCIExtendedNgResponse([string]$requestIdRaw, [string]$code, [string]$userMessage, [hashtable]$extra = $null) {
  $reqIdOut = $null
  if (-not [string]::IsNullOrEmpty($requestIdRaw)) { $reqIdOut = $requestIdRaw }
  $resp = [ordered]@{
    status        = "NG"
    code          = $code
    userMessage   = $userMessage
    requestId     = $reqIdOut
    updatedFiles  = 0
    folderRenamed = $false
  }
  if ($null -ne $extra) {
    foreach ($k in $extra.Keys) { $resp[$k] = $extra[$k] }
  }
  return ($resp | ConvertTo-Json -Depth 5)
}

# ---- resolvedNotes生成(2026-07-30追加 / 2026-08-13 v9.0.1 direct-child限定へ修正) ----
# UPDATE_CUSTOMER_IDENTITY成功応答用に、最終実体(実在ファイル)からノート一覧を生成する。
# 予定値(リネーム計画)からは組み立てず、最終顧客フォルダを再列挙して
# frontmatter "UUID:"のpk_CLIENT完全一致 + 既存noteType判定(Get-UciKnownPrefixMap経由)で
# 管理対象と識別できたノートだけを対象とする。本文中のUUIDは判定しない。
#
# ★ v9.0.1 (MAJOR-2): 正式managed noteのscopeは「customer folder直下(direct-child)」である。
#   従来は -Recurse でtree全体を列挙し、サブフォルダ内の同一noteTypeまで
#   duplicateNoteTypeのカウントへ混入させていたため、
#     customer/⬛その他_A.md (UUID=X)
#     customer/Sub/⬛その他_B.md (UUID=X)
#   のような構成で direct-child は1件しかないのに DUPLICATE_NOTE_TYPE と誤検出していた(T18)。
#   本版では列挙自体を非再帰(direct-childのみ)に限定し、resolvedNotes配列・duplicate件数の
#   双方をdirect-childの正式managed noteだけで構成する。
#   サブフォルダ内の同一UUID+同一noteTypeはここでは一切カウントせず、
#   必要な場合は呼び出し側/専用helper(Get-UciOutOfScopeManagedNotes)で
#   MANAGED_NOTE_OUT_OF_SCOPEとして扱う。
#   ※ v9.0.2 / v9.0.3ではこの関数を一切変更していない(direct-child化・T18対応をそのまま維持)。
#
# 同一noteTypeが2件以上ある場合はduplicateNoteTypeを返し、呼び出し側で
# DUPLICATE_NOTE_TYPE停止させる(曖昧なresolvedNotesは返さない)。
# 出力順序はnoteType→relativePathの安定ソート。
function Get-UciResolvedNotes([System.IO.DirectoryInfo]$folderInfo, [string]$pkClient, $prefixMap) {
  $entries = [System.Collections.ArrayList]::new()
  $byType = @{}
  # ★ v9.0.1: -Recurse を使用しない(direct-childのみが正式managed note scope)。
  $files = Get-ChildItem -LiteralPath $folderInfo.FullName -Filter "*.md" -File -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    # 二重防御: 列挙が非再帰であっても、親ディレクトリが顧客フォルダ直下であることを明示確認する。
    if (-not [string]::Equals(
          (Split-Path -Parent $f.FullName),
          $folderInfo.FullName,
          [System.StringComparison]::OrdinalIgnoreCase)) { continue }
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    if ($u.ToUpperInvariant() -ne $pkClient.ToUpperInvariant()) { continue }
    $ntype = $null
    foreach ($pfx in $prefixMap.Keys) {
      if ($f.Name.StartsWith($pfx + "_")) { $ntype = $prefixMap[$pfx]; break }
    }
    if ($null -eq $ntype) { continue }
    $relInFolder = Get-UciRelativePath $folderInfo $f.FullName
    if ($null -eq $relInFolder) { continue }
    $relPath = "01_顧客/" + $folderInfo.Name + "/" + ($relInFolder -replace "\\", "/")
    [void]$entries.Add([ordered]@{
      noteType     = $ntype
      relativePath = $relPath
      fileName     = $f.Name
    })
    if (-not $byType.ContainsKey($ntype)) { $byType[$ntype] = 0 }
    $byType[$ntype] = $byType[$ntype] + 1
  }
  foreach ($k in @($byType.Keys)) {
    if ($byType[$k] -ge 2) {
      return @{ entries = $null; duplicateNoteType = [string]$k; duplicateCount = [int]$byType[$k] }
    }
  }
  $sorted = @($entries.ToArray() | Sort-Object { [string]$_.noteType }, { [string]$_.relativePath })
  return @{ entries = $sorted; duplicateNoteType = $null; duplicateCount = 0 }
}

# ---- 再帰版UUID+noteType検索(2026-07-30追加 / 2026-08-13 用途限定) ----
# 既存Get-UuidNoteTypeMatches(単一フォルダ・非再帰)と同一の判定規則
# (アイコン接頭辞のファイル名パターン + frontmatter "UUID:"完全一致のみ)を、
# 指定ルート配下全体(-Recurse)へ広げた再帰版。独自のnoteType判定は追加しない。
# ※重要(v9.0.0/v9.0.1/v9.0.2/v9.0.3): この再帰版の結果を「1件見つかったので正式managed noteとして
#   自動採用」する用途へ使ってはならない。正式managed noteのduplicate判定・採用判定は
#   必ずcustomer folder直下(非再帰のGet-UuidNoteTypeMatches)を主判定とする。
#   本関数はscope外ノート(サブフォルダ)の検出・診断のためだけに使用する。
function Get-UuidNoteTypeMatchesInTree([string]$rootPath, [string]$iconPrefix, [string]$uuid) {
  $matched = [System.Collections.ArrayList]::new()
  if ([string]::IsNullOrWhiteSpace($uuid)) { return $matched.ToArray() }
  $candidates = Get-ChildItem -LiteralPath $rootPath -Filter "${iconPrefix}_*.md" -File -Recurse -ErrorAction SilentlyContinue
  foreach ($f in $candidates) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if (-not [string]::IsNullOrWhiteSpace($u) -and $u.ToUpperInvariant() -eq $uuid.ToUpperInvariant()) {
      [void]$matched.Add($f.FullName)
    }
  }
  return $matched.ToArray()
}

function Test-UciUuidFormat([string]$s) {
  return ($s -match '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$')
}

# ========================================================
# v9.0.0 追加: customer folder identity 解決基盤
#
# 顧客identityは「YAML frontmatterの完全UUID == FileMaker pk_CLIENTの完全UUID」でのみ確定する。
# 顧客名/正規化名/フォルダ名/UUID先頭8文字/folderNameConfirmed/obs_RELPATHはauthorityにしない。
#
# identity discoveryは 01_顧客 配下の再帰検索を許容する(サブフォルダ内ノートも
# 「その顧客フォルダに属する証拠」としては有効)。ただし正式managed noteの
# 採用・duplicate判定は customer folder 直下のみで行う(Get-UuidNoteTypeMatches)。
# ========================================================

# canonical顧客フォルダ名を生成する。既存Sanitize-LeafName / Get-UciUuidSuffixのみを使用する。
function Get-CanonicalCustomerFolderName([string]$nameRaw, [string]$pkClient) {
  return ((Sanitize-LeafName $nameRaw "NO_NAME") + (Get-UciUuidSuffix $pkClient))
}

# 指定フォルダのevidence状態を評価する。
# 戻り値(hashtable):
#   state          ... "Matched" / "NoEvidence" / "Conflict" / "InvalidYaml" / "InvalidUuid"
#   matchedCount   ... 対象完全UUIDと一致したノート件数(再帰、frontmatterのみ判定)
#   detailPath     ... 停止理由に関係するファイルパス(あれば)
#   detailValue    ... 停止理由に関係する値(別UUID・不正UUID文字列など)
# 優先順位: InvalidYaml > Conflict > InvalidUuid > Matched > NoEvidence
# ※ "Matched + InvalidUuid" は Matched成功にしない(InvalidUuidを優先して停止させる)。
function Get-UciFolderEvidence([string]$folderPath, [string]$pkClient) {
  $result = @{ state = "NoEvidence"; matchedCount = 0; detailPath = $null; detailValue = $null }
  $matchedCount = 0
  $invalidYamlPath = $null
  $conflictPath = $null; $conflictValue = $null
  $invalidUuidPath = $null; $invalidUuidValue = $null

  $files = Get-ChildItem -LiteralPath $folderPath -Filter "*.md" -File -Recurse -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) {
      if ($null -eq $invalidYamlPath) { $invalidYamlPath = $f.FullName }
      continue
    }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    if (-not (Test-UciUuidFormat $u)) {
      if ($null -eq $invalidUuidPath) { $invalidUuidPath = $f.FullName; $invalidUuidValue = $u }
      continue
    }
    if ($u.ToUpperInvariant() -eq $pkClient.ToUpperInvariant()) {
      $matchedCount = $matchedCount + 1
    } else {
      if ($null -eq $conflictPath) { $conflictPath = $f.FullName; $conflictValue = $u }
    }
  }

  $result.matchedCount = $matchedCount
  if ($null -ne $invalidYamlPath) {
    $result.state = "InvalidYaml"; $result.detailPath = $invalidYamlPath
    return $result
  }
  if ($null -ne $conflictPath) {
    $result.state = "Conflict"; $result.detailPath = $conflictPath; $result.detailValue = $conflictValue
    return $result
  }
  if ($null -ne $invalidUuidPath) {
    $result.state = "InvalidUuid"; $result.detailPath = $invalidUuidPath; $result.detailValue = $invalidUuidValue
    return $result
  }
  if ($matchedCount -ge 1) { $result.state = "Matched" }
  return $result
}

# 完全UUIDに一致するノートを 01_顧客 配下から再帰検索し、
# それらが属する「01_顧客直下のcustomer folder」を一意に特定する。
# 戻り値(hashtable):
#   folders      ... DirectoryInfoの配列(0件/1件/複数件)
#   unresolved   ... 01_顧客直下として帰属解決できなかったノートパス($nullなら無し)
function Get-UciUuidMatchedCustomerFolders([string]$custRootPath, [string]$pkClient) {
  $out = @{ folders = @(); unresolved = $null }
  if ([string]::IsNullOrWhiteSpace($pkClient)) { return $out }
  $custRootInfo = Get-Item -LiteralPath $custRootPath
  $map = @{}
  $files = Get-ChildItem -LiteralPath $custRootPath -Filter "*.md" -File -Recurse -ErrorAction SilentlyContinue
  foreach ($f in $files) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    if (-not (Test-UciUuidFormat $u)) { continue }
    if ($u.ToUpperInvariant() -ne $pkClient.ToUpperInvariant()) { continue }
    $child = Resolve-UciDirectChildFolder $custRootInfo $f.FullName
    if ($null -eq $child) {
      if ($null -eq $out.unresolved) { $out.unresolved = $f.FullName }
      continue
    }
    $key = $child.FullName.ToUpperInvariant()
    if (-not $map.ContainsKey($key)) { $map[$key] = $child }
  }
  $out.folders = @($map.Values)
  return $out
}

# 指定customer folder配下のうち、サブフォルダ側にのみ存在する
# 同一UUID+同一noteTypeノート(scope外)を列挙する。
# direct-child duplicate件数へは絶対に混ぜない。
function Get-UciOutOfScopeManagedNotes([string]$folderPath, [string]$iconPrefix, [string]$uuid) {
  $outOfScope = [System.Collections.ArrayList]::new()
  if ([string]::IsNullOrWhiteSpace($uuid) -or [string]::IsNullOrWhiteSpace($folderPath)) { return $outOfScope.ToArray() }
  $normFolder = if (Test-Path -LiteralPath $folderPath) { (Get-Item -LiteralPath $folderPath).FullName } else { [System.IO.Path]::GetFullPath($folderPath) }
  $all = @(Get-UuidNoteTypeMatchesInTree $folderPath $iconPrefix $uuid)
  foreach ($p in $all) {
    $parent = Split-Path -Parent $p
    if (-not [string]::Equals($parent, $normFolder, [System.StringComparison]::OrdinalIgnoreCase)) {
      [void]$outOfScope.Add($p)
    }
  }
  return $outOfScope.ToArray()
}

# ---- v9.0.1追加 / v9.0.2で出力方針を修正: filename fuzzy候補の列挙 ----
# 旧v9.0.0までは「対象noteTypeのUUID一致ノートが0件のとき、ファイル名接頭辞だけが一致する
# ノート(UUID未検証)を$targetAbsとして自動採用」していた。これは未確認ファイルへ
# Update-Yaml-Robustで対象顧客UUIDを書き込む危険があるため廃止した。
# 本関数の戻り値は内部変数へ保持するだけで、$targetAbsへ代入してはならない。
# また、v9.0.2ではこの候補情報についてWrite-Host等の追加診断出力を一切行わない
# (FileMakerとの応答契約 OK|... / NG|... へ新規出力を混在させないため)。
# 必要な場合はNG応答のdetails文字列へ含めることだけを許容する。
function Get-UciFuzzyNameCandidates([string]$folderPath, [string]$iconPrefix) {
  $names = [System.Collections.ArrayList]::new()
  if ([string]::IsNullOrWhiteSpace($folderPath) -or [string]::IsNullOrWhiteSpace($iconPrefix)) {
    return $names.ToArray()
  }
  $files = Get-ChildItem -LiteralPath $folderPath -Filter "${iconPrefix}_*.md" -File -ErrorAction SilentlyContinue
  foreach ($f in $files) { [void]$names.Add($f.Name) }
  return $names.ToArray()
}

function Invoke-UpdateCustomerIdentity($payload) {
  # requestIdは「文字列であること」を型レベルで検証する(数値・真偽値等の暗黙文字列化は許容しない)。
  $requestIdRaw = $null
  if ($payload.requestId -is [string] -and -not [string]::IsNullOrWhiteSpace($payload.requestId)) {
    $requestIdRaw = $payload.requestId
  }

  # ---- 入力検証(実装指示書 第6章の順序: protocolVersion → requestId → VaultRoot → pk_CLIENT → companyNameRaw) ----
  # protocolVersionは「数値1」であることを型レベルで検証する(文字列"1"等は不可)。
  $pvOk = $false
  $pv = $payload.protocolVersion
  if ($null -ne $pv -and $pv -isnot [string] -and $pv -isnot [bool] -and
      ($pv -is [int] -or $pv -is [int16] -or $pv -is [int32] -or $pv -is [int64] -or
       $pv -is [double] -or $pv -is [single] -or $pv -is [decimal])) {
    try { if ([double]$pv -eq 1) { $pvOk = $true } } catch {}
  }
  if (-not $pvOk) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "UNSUPPORTED_PROTOCOL_VERSION" "対応していないprotocolVersionです。")
    return
  }

  if ($null -eq $requestIdRaw) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "MISSING_REQUIRED_FIELD" "requestIdが正しい文字列で指定されていません。")
    return
  }

  $vaultRootUci = ([string]$payload.VaultRoot).Trim()
  if ([string]::IsNullOrWhiteSpace($vaultRootUci)) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "MISSING_REQUIRED_FIELD" "VaultRootが指定されていません。")
    return
  }
  if (-not (Test-Path -LiteralPath $vaultRootUci)) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "INVALID_VAULT_ROOT" "Vaultフォルダが見つかりません。")
    return
  }

  $pkClient = ([string]$payload.pk_CLIENT).Trim()
  if ([string]::IsNullOrWhiteSpace($pkClient)) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "MISSING_REQUIRED_FIELD" "pk_CLIENTが指定されていません。")
    return
  }
  if (-not (Test-UciUuidFormat $pkClient)) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "INVALID_UUID" "pk_CLIENTがUUID形式ではありません。")
    return
  }

  $companyNameRaw = [string]$payload.companyNameRaw
  if ([string]::IsNullOrWhiteSpace($companyNameRaw)) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "MISSING_REQUIRED_FIELD" "companyNameRawが指定されていません。")
    return
  }
  $ceo  = [string]$payload.CEO
  $ruby = [string]$payload.RUBY
  $rank = [string]$payload.RANK

  $newFolderNameSanity = Sanitize-LeafName $companyNameRaw "NO_NAME"
  if ($newFolderNameSanity -eq "NO_NAME") {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "INVALID_CUSTOMER_NAME" "companyNameRawから安全なフォルダ名を生成できません。")
    return
  }

  # Lock Acquisition Phase (NH-1, NM-1, NM-2)
  $txDir = Join-Path $vaultRootUci ".fm-obsidian-bridge-transactions"
  if (-not (Test-Path -LiteralPath $txDir)) { [void][System.IO.Directory]::CreateDirectory($txDir) }

  $lock = $null
  try {
    $lock = [System.IO.FileStream]::new(
      (Join-Path $txDir "ACTIVE.lock"),
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  } catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    Write-Output (New-UCIResponse $requestIdRaw "NG" "EXECUTION_FAILED" "ロックの取得に失敗しました ($errClass): $($_.Exception.Message)")
    return
  }

  try {

  $custRootUci = Join-Path $vaultRootUci "01_顧客"
  if (-not (Test-Path -LiteralPath $custRootUci)) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "CUSTOMER_NOT_FOUND" "01_顧客フォルダが見つかりません。")
    return
  }

  # ---- Step1: UUID一致ノートの再帰検索(01_顧客配下、YAML frontmatterのみ照合) ----
  $allMd = Get-ChildItem -LiteralPath $custRootUci -Filter "*.md" -File -Recurse -ErrorAction SilentlyContinue
  $matchedNotes = [System.Collections.ArrayList]::new()
  foreach ($f in $allMd) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if (-not [string]::IsNullOrWhiteSpace($u) -and $u.ToUpperInvariant() -eq $pkClient.ToUpperInvariant()) {
      [void]$matchedNotes.Add($f.FullName)
    }
  }

  if ($matchedNotes.Count -eq 0) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "CUSTOMER_NOT_FOUND" "指定されたUUIDに一致する顧客ノートが見つかりません。")
    return
  }

  # ---- Step2: 対象顧客フォルダの一意特定 ----
  # 回帰修正(2026-07-29c): 8.3短縮パス/長いパス混在によるSubstring誤動作を避けるため、
  # 文字列長に依存する切り出しを廃止し、DirectoryInfoの親を辿って01_顧客直下の
  # 顧客フォルダを特定する(Resolve-UciDirectChildFolder、OrdinalIgnoreCase比較)。
  $custRootInfo = Get-Item -LiteralPath $custRootUci
  $folderInfoMap = @{}
  foreach ($p in $matchedNotes) {
    $childFolder = Resolve-UciDirectChildFolder $custRootInfo $p
    if ($null -eq $childFolder) {
      Write-Output (New-UCIResponse $requestIdRaw "NG" "CUSTOMER_NOT_FOUND" "顧客ノートが01_顧客直下のフォルダ構造として解決できません。")
      return
    }
    $key = $childFolder.FullName.ToUpperInvariant()
    if (-not $folderInfoMap.ContainsKey($key)) { $folderInfoMap[$key] = $childFolder }
  }
  if ($folderInfoMap.Count -gt 1) {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "UUID_FOLDER_CONFLICT" "同一UUIDのノートが複数の顧客フォルダにまたがっています。")
    return
  }
  $currentFolderInfo = $folderInfoMap.Values | Select-Object -First 1
  $currentFolderName = $currentFolderInfo.Name
  $currentFolderPath = $currentFolderInfo.FullName

  # ---- Step3: フォルダ内整合性確認(別UUID混在／YAML破損／UUIDキー形式不正) ----
  # UUID識別子付き正式命名規則への常時正規化(2026-07-29追加)に伴うYAML修復ポリシー変更:
  # 従来は「UUID形式が不正」なら無条件でINVALID_YAML停止していたが、FileMakerを正本として
  # 修復できる場合はそれを優先する。本文境界(開始・終了の---)が判定できる場合に限り、
  # UUID形式不正なノードは修復候補として収集し処理を継続する(実際の修復書込みは既存の
  # Update-Yaml-Robustが担う。同関数は元のUUID値の正誤を問わず、渡された認証済み値で
  # 必ずtags/UUID/ランクを再生成するため、修復のための追加ロジックは不要)。
  # 本文境界そのものが判定できない場合(開始---はあるが終了---が見つからない等)は、
  # 本文喪失のリスクがあるため引き続き無条件停止する(コードはYAML_BODY_BOUNDARY_UNRESOLVEDへ変更)。
  $folderMd = Get-ChildItem -LiteralPath $currentFolderPath -Filter "*.md" -File -Recurse -ErrorAction SilentlyContinue
  $repairCandidates = [System.Collections.ArrayList]::new()
  foreach ($f in $folderMd) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) {
      Write-Output (New-UCIExtendedNgResponse $requestIdRaw "YAML_BODY_BOUNDARY_UNRESOLVED" "対象フォルダ内にYAML本文境界が判定できないノートがあります。本文喪失のおそれがあるため自動修復せず処理を中止しました。手動確認が必要です。" @{
        filePath = $f.FullName
        reason   = "frontmatterの開始行(---)はありますが、終了行(---)が見つかりません。"
        uuid     = $pkClient
        noteType = $null
      })
      return
    }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if (-not [string]::IsNullOrWhiteSpace($u)) {
      if (-not (Test-UciUuidFormat $u)) {
        [void]$repairCandidates.Add($f.FullName)
        continue
      }
      if ($u.ToUpperInvariant() -ne $pkClient.ToUpperInvariant()) {
        Write-Output (New-UCIResponse $requestIdRaw "NG" "FOLDER_UUID_MIXED" "対象フォルダ内に別UUIDのノートが混在しています。")
        return
      }
    }
  }

  # ---- Step4: 新フォルダ名決定・重複確認 ----
  # UUID識別子付き正式命名規則への常時正規化(2026-07-29追加): 社名変更の有無に関わらず、
  # pk_CLIENT先頭8文字(大文字)を"_[XXXXXXXX]"としてフォルダ名末尾へ必ず付与する。
  # 顧客名部分の正規化は既存のSanitize-LeafName(会社種別語の除去は行わない)をそのまま再利用する。
  $uuidSuffix = Get-UciUuidSuffix $pkClient
  $newFolderNameBase = Sanitize-LeafName $companyNameRaw "NO_NAME"
  $newFolderName = $newFolderNameBase + $uuidSuffix
  $folderNeedsRename = ($newFolderName -ne $currentFolderName)
  if ($folderNeedsRename) {
    $conflict = Get-ChildItem -LiteralPath $custRootUci -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq $newFolderName -and $_.Name -ne $currentFolderName }
    if ($conflict) {
      Write-Output (New-UCIResponse $requestIdRaw "NG" "TARGET_FOLDER_ALREADY_EXISTS" "変更先と同名の別フォルダが既に存在します。")
      return
    }
  }

  # ---- Step4.5: ノート正式ファイル名決定(UUID識別子付き常時正規化) ----
  # 既存Get-IconPrefixの戻り値から接頭辞→noteType逆引き表を作り、各ノートの現在の
  # ファイル名がどのnoteTypeに該当するかを判定する(既存のnoteType判定ロジックの再利用)。
  # ノート名正規化はlegacy CHECKの$n/$nameNormと同一規則(Get-NoteNameNormForUci)を用いる。
  # サブフォルダ内ノート(現行仕様が直下のみのため)はファイル名変更の対象外とし、
  # 再帰スコープを勝手に拡張しない。YAML内容の更新自体はStep8で従来どおり全件に行う。
  $uciPrefixMap = Get-UciKnownPrefixMap
  $allTargetNotePaths = [System.Collections.ArrayList]::new()
  foreach ($p in $matchedNotes) { [void]$allTargetNotePaths.Add($p) }
  foreach ($p in $repairCandidates) { [void]$allTargetNotePaths.Add($p) }

  $noteRenamePlan = [System.Collections.ArrayList]::new()
  foreach ($origPath in $allTargetNotePaths) {
    $curFileName = Split-Path -Leaf $origPath
    $isDirectChild = ((Split-Path -Parent $origPath) -eq $currentFolderPath)
    $recPrefix = $null
    foreach ($pfx in $uciPrefixMap.Keys) {
      if ($curFileName.StartsWith($pfx + "_")) { $recPrefix = $pfx; break }
    }
    $needsRename = $false
    $targetFileName = $curFileName
    if ($null -ne $recPrefix -and $isDirectChild) {
      $noteTypeLike = $uciPrefixMap[$recPrefix]
      $noteNameNorm = Get-NoteNameNormForUci $companyNameRaw $noteTypeLike
      $targetFileName = "${recPrefix}_${noteNameNorm}${uuidSuffix}.md"
      $needsRename = ($targetFileName -ne $curFileName)
    }
    [void]$noteRenamePlan.Add([ordered]@{
      orig = $origPath; curFileName = $curFileName; recognizedPrefix = $recPrefix
      targetFileName = $targetFileName; needsRename = $needsRename
    })
  }
  $anyNoteNeedsRename = (@($noteRenamePlan | Where-Object { $_.needsRename }).Count -gt 0)
  $anyRepairPending = ($repairCandidates.Count -gt 0)

  # ---- Step5: 変更要否判定(NO_CHANGE) ----
  $cleanTags = @()
  foreach ($val in @($companyNameRaw, $ceo, $ruby)) {
    if (-not [string]::IsNullOrWhiteSpace($val)) {
      $c = $val -replace "[\s　]+", ""
      if (-not [string]::IsNullOrEmpty($c)) { $cleanTags += $c }
    }
  }
  $anyNoteNeedsUpdate = $false
  foreach ($p in $matchedNotes) {
    $hdr = Get-YamlHeaderLines $p
    $curRank = Get-YamlScalarValue $hdr "ランク:"
    $curTags = @(Get-YamlTagValues $hdr)
    $tagsSame = ($curTags.Count -eq $cleanTags.Count)
    if ($tagsSame) {
      for ($i = 0; $i -lt $cleanTags.Count; $i++) {
        if ($curTags[$i] -ne $cleanTags[$i]) { $tagsSame = $false; break }
      }
    }
    if (($curRank.Trim() -ne $rank.Trim()) -or (-not $tagsSame)) {
      $anyNoteNeedsUpdate = $true
      break
    }
  }

  if (-not $folderNeedsRename -and -not $anyNoteNeedsUpdate -and -not $anyNoteNeedsRename -and -not $anyRepairPending) {
    # resolvedNotes(2026-07-30追加): NO_CHANGEでも現在の実在ファイルから生成して常時返す。
    # 同一noteType重複時は成功応答を返さずDUPLICATE_NOTE_TYPEで停止する(変更は未発生のため確定処理なし)。
    # ★ v9.0.1: duplicate判定はdirect-childのみ(Get-UciResolvedNotes側で担保)。
    $resolvedInfoNc = Get-UciResolvedNotes $currentFolderInfo $pkClient $uciPrefixMap
    if ($null -ne $resolvedInfoNc.duplicateNoteType) {
      Write-Output (New-UCIExtendedNgResponse $requestIdRaw "DUPLICATE_NOTE_TYPE" ("同一UUID・同一noteTypeのノートが顧客フォルダ直下に複数存在します。(pk_CLIENT: " + $pkClient + " / noteType: " + $resolvedInfoNc.duplicateNoteType + " / 件数: " + $resolvedInfoNc.duplicateCount + ")") @{ duplicateNoteType = $resolvedInfoNc.duplicateNoteType; duplicateCount = $resolvedInfoNc.duplicateCount; pk_CLIENT = $pkClient })
      return
    }
    Write-Output (New-UCIResponse $requestIdRaw "OK" "NO_CHANGE" "変更はありません。" 0 $false $currentFolderName $currentFolderName -resolvedNotesOut $resolvedInfoNc.entries)
    return
  }

  # ---- Step4.6: 全リネーム先の衝突事前チェック(実際の書込みは一切行わない) ----
  # UUID識別子付き正式命名規則への常時正規化(2026-07-29追加)。
  # (a) 同一プランの中で異なるノートが同じ変更先ファイル名になる場合(同一UUID・同一noteTypeの
  #     既存ノートが複数ある場合)は、既存のNOTE_TYPE_UUID_CONFLICTコードを再利用して安全に停止する。
  # (b) 変更先ファイル名がプラン外の別ファイルとして既に存在する場合(異常な衝突)は、
  #     上書き・削除・自動マージを一切行わず、新規コードTARGET_NOTE_FILENAME_CONFLICTで
  #     構造化された診断情報を返して停止する(PowerShell単独ではFileMakerの対話UIを
  #     直接制御できないため、ここでは安全停止のみを行う)。
  $targetNamesSeen = @{}
  foreach ($rp in $noteRenamePlan) {
    if ($null -eq $rp.recognizedPrefix) { continue }
    if ($targetNamesSeen.ContainsKey($rp.targetFileName)) {
      Write-Output (New-UCIResponse $requestIdRaw "NG" "NOTE_TYPE_UUID_CONFLICT" "同一UUID・同一noteTypeの既存ノートが複数見つかりました。安全のため処理を中止します。")
      return
    }
    $targetNamesSeen[$rp.targetFileName] = $true
  }
  $planCurNames = @{}
  foreach ($rp in $noteRenamePlan) { $planCurNames[$rp.curFileName] = $true }
  foreach ($rp in $noteRenamePlan) {
    if (-not $rp.needsRename) { continue }
    $prospective = Join-Path $currentFolderPath $rp.targetFileName
    if ((Test-Path -LiteralPath $prospective) -and (-not $planCurNames.ContainsKey($rp.targetFileName))) {
      $collHdr  = Get-YamlHeaderLines $prospective
      $collUuid = Get-YamlScalarValue $collHdr "UUID:"
      $collTags = @(Get-YamlTagValues $collHdr)
      $collCust = if ($collTags.Count -ge 1) { $collTags[0] } else { "" }
      $collRep  = if ($collTags.Count -ge 2) { $collTags[1] } else { "" }
      Write-Output (New-UCIExtendedNgResponse $requestIdRaw "TARGET_NOTE_FILENAME_CONFLICT" "変更先と同名の別ノートが既に存在します。上書き・削除は行わず処理を中止しました。手動確認が必要です。" @{
        conflictPath            = $prospective
        conflictUuid            = $collUuid
        conflictNoteType        = $rp.recognizedPrefix
        conflictRepresentative  = $collRep
        conflictCustomerName    = $collCust
        requestedUuid           = $pkClient
        requestedRepresentative = $ceo
        suggestedCanonicalName  = $rp.targetFileName
      })
      return
    }
  }

  # ---- Step6: 対応表作成・バックアップ取得(ロールバック用、リネーム前の内容) ----
  # 更新後再読込確認(本文不変検証)のため、frontmatter後の本文行も更新前の状態で保持しておく。
  # matchedNotes(UUID完全一致)とrepairCandidates(境界確定・UUID形式不正の修復対象)の両方を
  # 同一パイプラインで処理する(noteRenamePlanで既に両方を統合済み)。
  $notePairs = [System.Collections.ArrayList]::new()
  foreach ($rp in $noteRenamePlan) {
    $origPath = $rp.orig
    # 回帰修正(2026-07-29c): こちらも$currentFolderPathとの文字列長差(8.3短縮パス等)に
    # 依存しないよう、Get-UciRelativePath(DirectoryInfo/FileInfoベース)へ置き換える。
    $rel = Get-UciRelativePath $currentFolderInfo $origPath
    if ($null -eq $rel) {
      Write-Output (New-UCIResponse $requestIdRaw "NG" "CUSTOMER_NOT_FOUND" "ノートパスが顧客フォルダ配下として解決できません。")
      return
    }
    $origBodyLines = Get-YamlBodyLines $origPath
    $origBodyJoined = if ($null -ne $origBodyLines) { ($origBodyLines -join "`n") } else { $null }
    [void]$notePairs.Add([ordered]@{
      orig = $origPath; rel = $rel; newPath = $null; origBody = $origBodyJoined
      needsRename = $rp.needsRename; targetFileName = $rp.targetFileName; curFileName = $rp.curFileName
      renamed = $false
    })
  }
  $noteBackups = @{}
  foreach ($pair in $notePairs) {
    $noteBackups[$pair.rel] = [System.IO.File]::ReadAllBytes($pair.orig)
  }

  # ---- Step7: フォルダリネーム ----
  $activeFolderPath = $currentFolderPath
  if ($folderNeedsRename) {
    try {
      Rename-Item -LiteralPath $currentFolderPath -NewName $newFolderName -Force -ErrorAction Stop
      $activeFolderPath = Join-Path $custRootUci $newFolderName
    } catch {
      Write-Output (New-UCIResponse $requestIdRaw "NG" "FOLDER_RENAME_FAILED" "顧客フォルダの名称変更に失敗しました。")
      return
    }
  }
  foreach ($pair in $notePairs) { $pair.newPath = Join-Path $activeFolderPath $pair.rel }

  # ---- Step8: YAML更新(既存の総合計保険料は保持) + Step9: 更新後YAML再読込み確認 ----
  $updatedCount = 0
  $writeError = $null
  $processedPairs = [System.Collections.ArrayList]::new()
  foreach ($pair in $notePairs) {
    # 書込みを試行する前にロールバック対象へ登録する。Update-Yaml-Robust内での例外や
    # 更新後再読込み確認の不一致など、書込みが部分的にでも発生し得るあらゆる失敗経路で
    # 当該ノートが確実にバックアップから復元されるようにするため。
    [void]$processedPairs.Add($pair)
    try {
      # ---- Step7.5: ノート物理リネーム(UUID識別子付き正式命名規則への常時正規化) ----
      # フォルダリネーム後の$pair.newPath(この時点ではまだ旧ファイル名)を対象に、
      # 必要な場合のみファイル名そのものをリネームしてから、以下の既存YAML更新処理へ進む。
      if ($pair.needsRename) {
        try {
          Rename-Item -LiteralPath $pair.newPath -NewName $pair.targetFileName -Force -ErrorAction Stop
        } catch {
          throw "ノートのファイル名変更に失敗しました: $($_.Exception.Message)"
        }
        $pair.renamed = $true
        $pair.newPath = Join-Path $activeFolderPath $pair.targetFileName
      }
      $hdrBefore = Get-YamlHeaderLines $pair.newPath
      $existingPremium = Get-YamlScalarValue $hdrBefore "総合計保険料:"
      $premiumToPass = $null
      if (-not [string]::IsNullOrWhiteSpace($existingPremium)) { $premiumToPass = $existingPremium }
      # noteType保持検証用(ChatGPT再レビュー指摘#3により追加)。この簡易YAML構造には
      # 現行実データ上"noteType:"キーは存在しないが(01_顧客配下491ノートで0件を確認済み)、
      # 将来的な混入・想定外キーからも既存Update-Yaml-Robustのkept_lines機構により
      # 保持される設計になっていることを、この検証で明示的に裏付ける。
      $noteTypeBefore = Get-YamlScalarValue $hdrBefore "noteType:"

      Update-Yaml-Robust $pair.newPath $rank $companyNameRaw $ceo $ruby $pkClient $premiumToPass

      # 更新後YAML再読込み確認(ChatGPTレビュー指摘によりUUID・ランクに加え、
      # tags・総合計保険料の保持・noteType保持・本文不変も検証する)
      $hdrAfter = Get-YamlHeaderLines $pair.newPath
      if ($null -eq $hdrAfter) { throw "更新後のYAML再読込みに失敗しました。" }

      $uAfter = Get-YamlScalarValue $hdrAfter "UUID:"
      $rAfter = Get-YamlScalarValue $hdrAfter "ランク:"
      if ($uAfter.ToUpperInvariant() -ne $pkClient.ToUpperInvariant() -or $rAfter.Trim() -ne $rank.Trim()) {
        throw "更新後のYAML内容(UUID/ランク)が期待値と一致しません。"
      }

      $noteTypeAfter = Get-YamlScalarValue $hdrAfter "noteType:"
      if ($noteTypeAfter.Trim() -ne $noteTypeBefore.Trim()) {
        throw "更新後のYAML内容(noteType)が更新前と一致しません。"
      }

      # tags検証(顧客名・代表者名・RUBYが期待どおり反映されていること)
      $tagsAfter = @(Get-YamlTagValues $hdrAfter)
      $tagsExpectedOk = ($tagsAfter.Count -eq $cleanTags.Count)
      if ($tagsExpectedOk) {
        for ($ti = 0; $ti -lt $cleanTags.Count; $ti++) {
          if ($tagsAfter[$ti] -ne $cleanTags[$ti]) { $tagsExpectedOk = $false; break }
        }
      }
      if (-not $tagsExpectedOk) {
        throw "更新後のYAML内容(tags)が期待値と一致しません。"
      }

      # 総合計保険料の保持検証(既存値があれば同値、無ければ引き続き未設定であること)
      $premiumAfter = Get-YamlScalarValue $hdrAfter "総合計保険料:"
      if ($null -ne $premiumToPass) {
        if ($premiumAfter.Trim() -ne $premiumToPass.Trim()) {
          throw "更新後のYAML内容(総合計保険料)が保持されていません。"
        }
      } elseif (-not [string]::IsNullOrWhiteSpace($premiumAfter)) {
        throw "総合計保険料が存在しなかったにもかかわらず新規追加されました。"
      }

      # 本文不変検証(frontmatterより後ろの本文の「テキスト内容」が更新前後で一致すること)。
      # ※ここでの比較は行配列(ReadAllLines)ベースであり、意図的に改行コード種別
      # (CRLF/LF/CR)の差異を許容する。理由：既存Update-Yaml-Robust自体が内部で
      # [System.IO.File]::WriteAllLines を使用しており、.NETの仕様上これはWindows環境で
      # 常にEnvironment.NewLine(CRLF)を行区切りとして書き出す。これは今回新設したコードの
      # 挙動ではなく、既存のUpdate-Yaml-Robustが元から持つ挙動であり、UPDATE_CUSTOMER_IDENTITY
      # 以外の既存の通常更新処理でも同様に発生し得る。そのため、本文の改行コードそのものを
      # 「不変」の判定基準に含めると、LF/混在改行の既存ノート(Vault実態調査で確認済み)を
      # 対象とした場合に、内容が一切変わっていなくても常にロールバックされてしまい、
      # 本アクションが実運用で機能しなくなる。したがって本検証は「本文の文字内容が
      # 意図せず変更・欠落していないこと」を目的とし、改行コード正規化それ自体は
      # Update-Yaml-Robust由来の既知の特性として許容する。
      if ($null -ne $pair.origBody) {
        $bodyAfterLines = Get-YamlBodyLines $pair.newPath
        $bodyAfterJoined = if ($null -ne $bodyAfterLines) { ($bodyAfterLines -join "`n") } else { $null }
        if ($bodyAfterJoined -ne $pair.origBody) {
          throw "更新後の本文が更新前と一致しません。"
        }
      }

      $updatedCount++
    } catch {
      $writeError = $_.Exception.Message
      break
    }
  }

  # ---- Step9.5: resolvedNotes生成(2026-07-30追加) ----
  # 書込み成功後、最終顧客フォルダを再取得し、実在ファイルからresolvedNotesを生成する。
  # 同一noteType重複を検出した場合は成功応答を返さず、既存ロールバック機構を再利用して
  # 変更を確定せずDUPLICATE_NOTE_TYPEで停止する。
  # ★ v9.0.1: duplicate判定・resolvedNotesともdirect-childのみ(Get-UciResolvedNotes側で担保)。
  $uciResolvedEntries = $null
  $uciDuplicateNg = $null
  if ($null -eq $writeError) {
    try {
      $finalFolderInfoUci = Get-Item -LiteralPath $activeFolderPath
      $resolvedInfoOk = Get-UciResolvedNotes $finalFolderInfoUci $pkClient $uciPrefixMap
      if ($null -ne $resolvedInfoOk.duplicateNoteType) {
        $uciDuplicateNg = New-UCIExtendedNgResponse $requestIdRaw "DUPLICATE_NOTE_TYPE" ("同一UUID・同一noteTypeのノートが顧客フォルダ直下に複数存在するため、変更を確定せずロールバックしました。(pk_CLIENT: " + $pkClient + " / noteType: " + $resolvedInfoOk.duplicateNoteType + " / 件数: " + $resolvedInfoOk.duplicateCount + ")") @{ duplicateNoteType = $resolvedInfoOk.duplicateNoteType; duplicateCount = $resolvedInfoOk.duplicateCount; pk_CLIENT = $pkClient }
        $writeError = "DUPLICATE_NOTE_TYPE"
      } else {
        $uciResolvedEntries = $resolvedInfoOk.entries
      }
    } catch {
      $writeError = "resolvedNotesの生成に失敗しました: " + $_.Exception.Message
    }
  }

  if ($null -ne $writeError) {
    # ---- ロールバック: 更新済みノートのファイル名・内容を復元 → フォルダを旧名称へ復元 ----
    # UUID識別子付き正式命名規則への常時正規化(2026-07-29追加)に伴う拡張:
    # $pair.renamedがtrueの場合、$activeFolderPath(現在の、まだリネームされたままの
    # フォルダパス)を基準に、まずファイル名を元のcurFileNameへ戻してから内容を復元する。
    # $activeFolderPathがまだ旧フォルダ名へ戻される前にノート単位の復元を行う必要があるため、
    # 既存の「ノート復元→フォルダ復元」の順序をそのまま維持する(順序を変更しない)。
    $rollbackOk = $true
    foreach ($pair in $processedPairs) {
      try {
        $restorePath = $pair.newPath
        if ($pair.renamed) {
          if (Test-Path -LiteralPath $pair.newPath) {
            Rename-Item -LiteralPath $pair.newPath -NewName $pair.curFileName -Force -ErrorAction Stop
          }
          $restorePath = Join-Path $activeFolderPath $pair.curFileName
        }
        [System.IO.File]::WriteAllBytes($restorePath, $noteBackups[$pair.rel])
      } catch { $rollbackOk = $false }
    }
    if ($folderNeedsRename) {
      try {
        Rename-Item -LiteralPath $activeFolderPath -NewName $currentFolderName -Force -ErrorAction Stop
      } catch { $rollbackOk = $false }
    }
    if (-not $rollbackOk) {
      Write-Output (New-UCIResponse $requestIdRaw "NG" "UPDATE_ROLLBACK_FAILED" "更新に失敗し、ロールバックにも失敗しました。手動確認が必要です。")
      return
    }
    if ($null -ne $uciDuplicateNg) {
      # resolvedNotes重複検出(2026-07-30追加): ロールバック完了後、DUPLICATE_NOTE_TYPEで停止する。
      Write-Output $uciDuplicateNg
      return
    }
    Write-Output (New-UCIResponse $requestIdRaw "NG" "NOTE_UPDATE_FAILED" "ノートの更新に失敗したため、変更をロールバックしました。")
    return
  }

  $finalFolderName = if ($folderNeedsRename) { $newFolderName } else { $currentFolderName }
  $renamedNotesOut = @($notePairs | Where-Object { $_.renamed } | ForEach-Object { [ordered]@{ oldName = $_.curFileName; newName = $_.targetFileName } })
  Write-Output (New-UCIResponse $requestIdRaw "OK" "CUSTOMER_IDENTITY_UPDATED" "顧客情報を更新しました。" $updatedCount $folderNeedsRename $currentFolderName $finalFolderName $renamedNotesOut.Count $uuidSuffix $renamedNotesOut -resolvedNotesOut $uciResolvedEntries)
  } finally {
    if ($null -ne $lock) {
      $lock.Close()
      $lock.Dispose()
    }
  }
}


# ==============================================================================
# Customer Folder Merge v1 Implementation Functions
# ==============================================================================
# Customer Folder Merge v1 Implementation Functions
# ==============================================================================


function New-MergeResponse {
  param(
    [string]$RequestId = $null,
    [string]$Status = "OK",
    [string]$Code = "",
    [string]$UserMessage = "",
    [string]$Warning = $null,
    [hashtable]$Extra = @{}
  )
  $resp = [ordered]@{
    status        = $Status
    code          = $Code
    userMessage   = $UserMessage
    requestId     = $RequestId
    updatedFiles  = 0
    folderRenamed = $false
  }
  if (-not [string]::IsNullOrEmpty($Warning)) {
    $resp["warning"] = $Warning
  }
  if ($null -ne $Extra) {
    foreach ($k in $Extra.Keys) {
      $resp[$k] = $Extra[$k]
    }
  }
  return ($resp | ConvertTo-Json -Depth 10)
}

# ---- Win32 Native Helpers ----
if (-not ([System.Management.Automation.PSTypeName]'Win32NativeMergeHelper').Type) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32NativeMergeHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "GetLongPathNameW")]
    public static extern uint GetLongPathName(
        string lpszShortPath,
        StringBuilder lpszLongPath,
        uint cchBuffer
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateDirectoryW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(
        string lpPathName,
        IntPtr lpSecurityAttributes
    );

    [StructLayout(LayoutKind.Sequential)]
    public struct BY_HANDLE_FILE_INFORMATION {
        public uint dwFileAttributes;
        public uint ftCreationTimeLow;
        public uint ftCreationTimeHigh;
        public uint ftLastAccessTimeLow;
        public uint ftLastAccessTimeHigh;
        public uint ftLastWriteTimeLow;
        public uint ftLastWriteTimeHigh;
        public uint dwVolumeSerialNumber;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint nNumberOfLinks;
        public uint nFileIndexHigh;
        public uint nFileIndexLow;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetFileInformationByHandle(
        IntPtr hFile,
        out BY_HANDLE_FILE_INFORMATION lpFileInformation
    );

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct WIN32_FIND_STREAM_DATA {
        public long StreamSize;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 296)]
        public string cStreamName;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "FindFirstStreamW")]
    public static extern IntPtr FindFirstStream(
        string lpFileName,
        int InfoLevel,
        out WIN32_FIND_STREAM_DATA lpFindStreamData,
        uint dwFlags
    );

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "FindNextStreamW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FindNextStream(
        IntPtr hFindStream,
        out WIN32_FIND_STREAM_DATA lpFindStreamData
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FindClose(IntPtr hFindFile);
    [StructLayout(LayoutKind.Sequential)]
    public struct FILE_CASE_SENSITIVE_INFO {
        public uint Flags;
    }

    public const int FileCaseSensitiveInfo = 23;
    public const uint FILE_CS_FLAG_CASE_SENSITIVE_DIR = 0x00000001;

    public const uint FILE_READ_ATTRIBUTES = 0x0080;
    public const uint FILE_SHARE_READ   = 0x00000001;
    public const uint FILE_SHARE_WRITE  = 0x00000002;
    public const uint FILE_SHARE_DELETE = 0x00000004;
    public const uint OPEN_EXISTING = 3;
    public const uint FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateFileW")]
    public static extern IntPtr CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetFileInformationByHandleEx(
        IntPtr hFile,
        int FileInformationClass,
        out FILE_CASE_SENSITIVE_INFO lpFileInformation,
        uint dwBufferSize
    );

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct FILE_RENAME_INFO {
        [MarshalAs(UnmanagedType.U1)]
        public bool ReplaceIfExists;
        public IntPtr RootDirectory;
        public uint FileNameLength;
        public char FileName;
    }

    public const uint DELETE = 0x00010000;
    public const uint FILE_LIST_DIRECTORY = 0x00000001;
    public const int FileRenameInfo = 3;
    public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetFileInformationByHandle(
        IntPtr hFile,
        int FileInformationClass,
        IntPtr lpFileInformation,
        uint dwBufferSize
    );

    public static bool RenameDirectory(IntPtr hFile, string newPath, bool replaceIfExists, out int win32Error)
    {
        win32Error = 0;
        string pathWithNull = newPath + "\0";
        byte[] nameBytes = Encoding.Unicode.GetBytes(pathWithNull);
        uint nameLenWithoutNull = (uint)Encoding.Unicode.GetByteCount(newPath);

        int offsetFileName = (IntPtr.Size == 8) ? 20 : 12;
        int offsetLen = (IntPtr.Size == 8) ? 16 : 8;

        int totalSize = offsetFileName + nameBytes.Length + 16;
        IntPtr pBuf = Marshal.AllocHGlobal(totalSize);

        try
        {
            for (int i = 0; i < totalSize; i++) Marshal.WriteByte(pBuf, i, 0);

            Marshal.WriteByte(pBuf, 0, (byte)(replaceIfExists ? 1 : 0));
            Marshal.WriteInt32(pBuf, offsetLen, (int)nameLenWithoutNull);
            Marshal.Copy(nameBytes, 0, new IntPtr(pBuf.ToInt64() + offsetFileName), nameBytes.Length);

            bool ok = SetFileInformationByHandle(hFile, FileRenameInfo, pBuf, (uint)(offsetFileName + nameBytes.Length));
            if (!ok)
            {
                win32Error = Marshal.GetLastWin32Error();
            }
            return ok;
        }
        finally
        {
            Marshal.FreeHGlobal(pBuf);
        }
    }
}
"@
}

if (-not ([System.Management.Automation.PSTypeName]'Win32DurableJournalHelper').Type) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Win32DurableJournalHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "MoveFileExW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveFileEx(
        string lpExistingFileName,
        string lpNewFileName,
        uint dwFlags
    );

    public const uint MOVEFILE_REPLACE_EXISTING = 0x1;
    public const uint MOVEFILE_WRITE_THROUGH    = 0x8;
}
"@
}

if (-not (Test-Path variable:global:__TEST_CRASH_HOOK)) {
  $global:__TEST_CRASH_HOOK = $null
}

function Invoke-TestCrashHook([string]$Window) {
  $hookVal = (Get-Variable -Name __TEST_CRASH_HOOK -Scope Global -ValueOnly -ErrorAction SilentlyContinue)
  if ([string]::IsNullOrWhiteSpace($hookVal)) { return }

  if ($hookVal -ceq $Window) {
    # HARD child termination: TerminateProcess. No unwinding, no catch/finally/trap.
    $p = [System.Diagnostics.Process]::GetCurrentProcess()
    $p.Kill()
    $p.WaitForExit()   # never returns; guarantees nothing past this seam runs
    return
  }

  if ($hookVal -ceq ($Window + ":THROW")) {
    throw [System.ApplicationException]::new("SIMULATED_FAULT_AT_${Window}")
  }
}

function Resolve-Win32CanonicalPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }

  if (-not [System.IO.Path]::IsPathRooted($Path)) {
    return $null
  }

  if ($Path.StartsWith("\\") -or $Path.StartsWith("//")) {
    return $null
  }

  $full = [System.IO.Path]::GetFullPath($Path)
  if ($full.StartsWith("\\") -or $full.StartsWith("//")) {
    return $null
  }

  $root = [System.IO.Path]::GetPathRoot($full)
  if ([string]::IsNullOrWhiteSpace($root) -or -not ($root -match '^[A-Za-z]:[\\/]')) {
    return $null
  }

  if (Test-Path -LiteralPath $full) {
    $bufferSize = [uint32]1024
    $sb = [System.Text.StringBuilder]::new([int]$bufferSize)
    $res = [Win32NativeMergeHelper]::GetLongPathName($full, $sb, $bufferSize)
    if ($res -ge $bufferSize) {
      $bufferSize = $res
      $sb = [System.Text.StringBuilder]::new([int]$bufferSize)
      $res = [Win32NativeMergeHelper]::GetLongPathName($full, $sb, $bufferSize)
    }
    if ($res -eq 0) {
      return $null
    }
    return $sb.ToString()
  }

  return $null
}

function New-Win32ExclusiveDirectory {
  param([string]$Path)
  $success = [Win32NativeMergeHelper]::CreateDirectory($Path, [IntPtr]::Zero)
  if (-not $success) {
    $lastErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    return @{ Success = $false; ErrorCode = $lastErr }
  }
  return @{ Success = $true; ErrorCode = 0 }
}

function Get-FileHardLinkCountSafe {
  param([string]$FilePath)
  if ([string]::IsNullOrWhiteSpace($FilePath)) { return -1 }

  $stream = $null
  try {
    $stream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $handle = $stream.SafeFileHandle.DangerousGetHandle()

    $info = New-Object Win32NativeMergeHelper+BY_HANDLE_FILE_INFORMATION
    $ok = [Win32NativeMergeHelper]::GetFileInformationByHandle($handle, [ref]$info)
    if (-not $ok) { return -1 }
    return [int]$info.nNumberOfLinks
  }
  catch {
    return -1
  }
  finally {
    if ($null -ne $stream) {
      $stream.Dispose()
    }
  }
}

function Test-DirectoryCaseSensitiveSafe {
  param([string]$DirectoryPath)
  if ([string]::IsNullOrWhiteSpace($DirectoryPath)) {
    return @{ Status = "INCONCLUSIVE"; Details = "DirectoryPath is null or empty"; ErrorCode = -1 }
  }

  $desiredAccess = [uint32]0x0080 # FILE_READ_ATTRIBUTES
  $shareMode = [uint32]0x00000007 # FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE
  $creationDisp = [uint32]3        # OPEN_EXISTING
  $flagsAndAttrs = [uint32]0x02000000 # FILE_FLAG_BACKUP_SEMANTICS
  $nullPtr = [IntPtr]::Zero
  $invalidHandle = [IntPtr](-1)

  $handle = [Win32NativeMergeHelper]::CreateFile(
    $DirectoryPath,
    $desiredAccess,
    $shareMode,
    $nullPtr,
    $creationDisp,
    $flagsAndAttrs,
    $nullPtr
  )

  if ($handle -eq $invalidHandle -or $handle -eq [IntPtr]::Zero) {
    $lastErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    return @{
      Status    = "INCONCLUSIVE"
      Details   = "CreateFile failed to open directory handle with Win32 error $lastErr"
      ErrorCode = $lastErr
    }
  }

  try {
    $info = New-Object Win32NativeMergeHelper+FILE_CASE_SENSITIVE_INFO
    $structSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($info)
    $success = [Win32NativeMergeHelper]::GetFileInformationByHandleEx(
      $handle,
      [Win32NativeMergeHelper]::FileCaseSensitiveInfo,
      [ref]$info,
      $structSize
    )

    if (-not $success) {
      $lastErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
      return @{
        Status    = "INCONCLUSIVE"
        Details   = "GetFileInformationByHandleEx(FileCaseSensitiveInfo) failed with Win32 error $lastErr"
        ErrorCode = $lastErr
      }
    }

    if (($info.Flags -band [Win32NativeMergeHelper]::FILE_CS_FLAG_CASE_SENSITIVE_DIR) -ne 0) {
      return @{
        Status    = "CASE_SENSITIVE"
        Details   = "顧客ルートフォルダが大文字/小文字を区別するディレクトリとして設定されています: $DirectoryPath"
        ErrorCode = 0
      }
    }
    else {
      return @{
        Status    = "CASE_INSENSITIVE"
        Details   = "Directory is case-insensitive (Flags=0x$($info.Flags.ToString('X8')))"
        ErrorCode = 0
      }
    }
  }
  catch {
    return @{
      Status    = "INCONCLUSIVE"
      Details   = "Exception during directory case sensitivity query: $($_.Exception.Message)"
      ErrorCode = -1
    }
  }
  finally {
    if ($handle -ne $invalidHandle -and $handle -ne [IntPtr]::Zero) {
      [void][Win32NativeMergeHelper]::CloseHandle($handle)
    }
  }
}

function Test-FileAlternateDataStreamsSafe {
  param([string]$FilePath)
  if ([string]::IsNullOrWhiteSpace($FilePath)) {
    return @{ Status = "INCONCLUSIVE"; NamedStreams = @(); Details = "FilePath is null or empty"; ErrorCode = -1 }
  }

  $data = New-Object Win32NativeMergeHelper+WIN32_FIND_STREAM_DATA
  $invalidHandle = [IntPtr](-1)
  $handle = [Win32NativeMergeHelper]::FindFirstStream($FilePath, 0, [ref]$data, [uint32]0)
  
  if ($handle -eq $invalidHandle -or $handle -eq [IntPtr]::Zero) {
    $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    return @{
      Status       = "INCONCLUSIVE"
      NamedStreams = @()
      Details      = "FindFirstStream failed with Win32 error $err"
      ErrorCode    = $err
    }
  }

  $namedStreams = New-Object System.Collections.Generic.List[string]
  try {
    if ($data.cStreamName -and -not $data.cStreamName.Equals('::$DATA', [System.StringComparison]::OrdinalIgnoreCase)) {
      $namedStreams.Add($data.cStreamName)
    }

    while ([Win32NativeMergeHelper]::FindNextStream($handle, [ref]$data)) {
      if ($data.cStreamName -and -not $data.cStreamName.Equals('::$DATA', [System.StringComparison]::OrdinalIgnoreCase)) {
        $namedStreams.Add($data.cStreamName)
      }
    }

    $lastErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if ($lastErr -ne 38) {
      return @{
        Status       = "INCONCLUSIVE"
        NamedStreams = @($namedStreams)
        Details      = "FindNextStream ended with unexpected Win32 error $lastErr (expected ERROR_HANDLE_EOF 38)"
        ErrorCode    = $lastErr
      }
    }

    if ($namedStreams.Count -gt 0) {
      return @{
        Status       = "HAS_ADS"
        NamedStreams = @($namedStreams)
        Details      = "Named alternate data streams detected: $($namedStreams -join ', ')"
        ErrorCode    = 0
      }
    }

    return @{
      Status       = "CLEAN"
      NamedStreams = @()
      Details      = "No named alternate data streams detected"
      ErrorCode    = 0
    }
  }
  catch {
    return @{
      Status       = "INCONCLUSIVE"
      NamedStreams = @($namedStreams)
      Details      = "Exception during stream enumeration: $($_.Exception.Message)"
      ErrorCode    = -1
    }
  }
  finally {
    if ($handle -ne $invalidHandle -and $handle -ne [IntPtr]::Zero) {
      [void][Win32NativeMergeHelper]::FindClose($handle)
    }
  }
}

function Get-FileSha256Raw {
  param([string]$FilePath)
  if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $null }
  $bytes = [System.IO.File]::ReadAllBytes($FilePath)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hashBytes = $sha.ComputeHash($bytes)
  return [BitConverter]::ToString($hashBytes).Replace("-", "").ToUpperInvariant()
}

function Open-CanonicalDirectoryGuard {
  param(
    [string]$DirectoryPath,
    [string]$OpaqueTestHandleId = 'CASEA-GUARD-DEFAULT'
  )
  if ([string]::IsNullOrWhiteSpace($DirectoryPath)) {
    return [PSCustomObject]@{
      OpaqueTestHandleId = $OpaqueTestHandleId
      IsValid            = $false
      Win32Error         = 87 # ERROR_INVALID_PARAMETER
      DesiredAccess      = 'FILE_LIST_DIRECTORY'
      ShareMode          = 'FILE_SHARE_READ | FILE_SHARE_WRITE'
      CloseCount         = 0
      NativeHandle       = [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE
    }
  }

  $desiredAccess = [Win32NativeMergeHelper]::FILE_LIST_DIRECTORY
  $shareMode = [Win32NativeMergeHelper]::FILE_SHARE_READ -bor [Win32NativeMergeHelper]::FILE_SHARE_WRITE
  $creationDisp = [Win32NativeMergeHelper]::OPEN_EXISTING
  $flagsAndAttrs = [Win32NativeMergeHelper]::FILE_FLAG_BACKUP_SEMANTICS
  $nullPtr = [IntPtr]::Zero

  $handle = [Win32NativeMergeHelper]::CreateFile(
    $DirectoryPath,
    $desiredAccess,
    $shareMode,
    $nullPtr,
    $creationDisp,
    $flagsAndAttrs,
    $nullPtr
  )

  $isValid = ($handle -ne [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE -and $handle -ne [IntPtr]::Zero)
  $win32Error = if ($isValid) { 0 } else { [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() }

  return [PSCustomObject]@{
    OpaqueTestHandleId = $OpaqueTestHandleId
    IsValid            = $isValid
    Win32Error         = $win32Error
    DesiredAccess      = 'FILE_LIST_DIRECTORY'
    ShareMode          = 'FILE_SHARE_READ | FILE_SHARE_WRITE'
    CloseCount         = 0
    NativeHandle       = $handle
  }
}

function Open-StagingDirectoryContinuityHandle {
  param(
    [string]$DirectoryPath,
    [string]$OpaqueTestHandleId = 'CASEB-CONTINUITY-DEFAULT'
  )
  if ([string]::IsNullOrWhiteSpace($DirectoryPath)) {
    return [PSCustomObject]@{
      OpaqueTestHandleId = $OpaqueTestHandleId
      IsValid            = $false
      Win32Error         = 87 # ERROR_INVALID_PARAMETER
      DesiredAccess      = 'DELETE'
      ShareMode          = 'FILE_SHARE_READ | FILE_SHARE_WRITE'
      CloseCount         = 0
      NativeHandle       = [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE
    }
  }

  $desiredAccess = [Win32NativeMergeHelper]::DELETE
  $shareMode = [Win32NativeMergeHelper]::FILE_SHARE_READ -bor [Win32NativeMergeHelper]::FILE_SHARE_WRITE
  $creationDisp = [Win32NativeMergeHelper]::OPEN_EXISTING
  $flagsAndAttrs = [Win32NativeMergeHelper]::FILE_FLAG_BACKUP_SEMANTICS
  $nullPtr = [IntPtr]::Zero

  $handle = [Win32NativeMergeHelper]::CreateFile(
    $DirectoryPath,
    $desiredAccess,
    $shareMode,
    $nullPtr,
    $creationDisp,
    $flagsAndAttrs,
    $nullPtr
  )

  $isValid = ($handle -ne [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE -and $handle -ne [IntPtr]::Zero)
  $win32Error = if ($isValid) { 0 } else { [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() }

  return [PSCustomObject]@{
    OpaqueTestHandleId = $OpaqueTestHandleId
    IsValid            = $isValid
    Win32Error         = $win32Error
    DesiredAccess      = 'DELETE'
    ShareMode          = 'FILE_SHARE_READ | FILE_SHARE_WRITE'
    CloseCount         = 0
    NativeHandle       = $handle
  }
}

function Open-RecoveryStagingDirectoryGuard {
  param(
    [string]$DirectoryPath,
    [string]$OpaqueTestHandleId = 'RECOVERY-GUARD-DEFAULT'
  )
  if ([string]::IsNullOrWhiteSpace($DirectoryPath)) {
    return [PSCustomObject]@{
      OpaqueTestHandleId = $OpaqueTestHandleId
      IsValid            = $false
      Win32Error         = 87 # ERROR_INVALID_PARAMETER
      DesiredAccess      = 'DELETE | FILE_READ_ATTRIBUTES'
      ShareMode          = 'FILE_SHARE_READ | FILE_SHARE_WRITE'
      CloseCount         = 0
      NativeHandle       = [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE
    }
  }

  $desiredAccess = [Win32NativeMergeHelper]::DELETE -bor [Win32NativeMergeHelper]::FILE_READ_ATTRIBUTES
  $shareMode = [Win32NativeMergeHelper]::FILE_SHARE_READ -bor [Win32NativeMergeHelper]::FILE_SHARE_WRITE
  $creationDisp = [Win32NativeMergeHelper]::OPEN_EXISTING
  $flagsAndAttrs = [Win32NativeMergeHelper]::FILE_FLAG_BACKUP_SEMANTICS
  $nullPtr = [IntPtr]::Zero

  $handle = [Win32NativeMergeHelper]::CreateFile(
    $DirectoryPath,
    $desiredAccess,
    $shareMode,
    $nullPtr,
    $creationDisp,
    $flagsAndAttrs,
    $nullPtr
  )

  $isValid = ($handle -ne [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE -and $handle -ne [IntPtr]::Zero)
  $win32Error = if ($isValid) { 0 } else { [System.Runtime.InteropServices.Marshal]::GetLastWin32Error() }

  return [PSCustomObject]@{
    OpaqueTestHandleId = $OpaqueTestHandleId
    IsValid            = $isValid
    Win32Error         = $win32Error
    DesiredAccess      = 'DELETE | FILE_READ_ATTRIBUTES'
    ShareMode          = 'FILE_SHARE_READ | FILE_SHARE_WRITE'
    CloseCount         = 0
    NativeHandle       = $handle
  }
}

function Get-DirectoryObjectIdentity {
  param($HandleWrapper)
  if ($null -eq $HandleWrapper) { return $null }
  if ($HandleWrapper -is [System.Management.Automation.PSReference]) {
    $HandleWrapper = $HandleWrapper.Value
  }
  if ($null -eq $HandleWrapper) { return $null }

  $rawHandle = if ($HandleWrapper -is [System.IntPtr]) {
    $HandleWrapper
  } elseif ($null -ne $HandleWrapper.PSObject.Properties['NativeHandle']) {
    $HandleWrapper.NativeHandle
  } else {
    [IntPtr]::Zero
  }

  if ($null -eq $rawHandle -or $rawHandle -eq [IntPtr]::Zero -or $rawHandle -eq [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE) {
    return $null
  }

  $info = New-Object Win32NativeMergeHelper+BY_HANDLE_FILE_INFORMATION
  $ok = [Win32NativeMergeHelper]::GetFileInformationByHandle($rawHandle, [ref]$info)
  if (-not $ok) {
    return $null
  }

  return [PSCustomObject]@{
    VolumeSerialNumber = [uint32]$info.dwVolumeSerialNumber
    FileIndexHigh      = [uint32]$info.nFileIndexHigh
    FileIndexLow       = [uint32]$info.nFileIndexLow
    VolumeSerialHex    = $info.dwVolumeSerialNumber.ToString('X8')
    FileIndexHighHex   = $info.nFileIndexHigh.ToString('X8')
    FileIndexLowHex    = $info.nFileIndexLow.ToString('X8')
    FileIdString       = "$($info.dwVolumeSerialNumber.ToString('X8'))-$($info.nFileIndexHigh.ToString('X8'))-$($info.nFileIndexLow.ToString('X8'))"
  }
}

function Test-DirectoryPathBinding {
  param(
    [string]$DirectoryPath,
    $ExpectedIdentity
  )
  if ([string]::IsNullOrWhiteSpace($DirectoryPath) -or $null -eq $ExpectedIdentity) {
    return $false
  }
  if ($null -eq $ExpectedIdentity.VolumeSerialNumber -or
      $null -eq $ExpectedIdentity.FileIndexHigh -or
      $null -eq $ExpectedIdentity.FileIndexLow) {
    return $false
  }

  $desiredAccess = [Win32NativeMergeHelper]::FILE_READ_ATTRIBUTES
  $shareMode = [Win32NativeMergeHelper]::FILE_SHARE_READ -bor [Win32NativeMergeHelper]::FILE_SHARE_WRITE -bor [Win32NativeMergeHelper]::FILE_SHARE_DELETE
  $creationDisp = [Win32NativeMergeHelper]::OPEN_EXISTING
  $flagsAndAttrs = [Win32NativeMergeHelper]::FILE_FLAG_BACKUP_SEMANTICS
  $nullPtr = [IntPtr]::Zero

  $handle = [Win32NativeMergeHelper]::CreateFile(
    $DirectoryPath,
    $desiredAccess,
    $shareMode,
    $nullPtr,
    $creationDisp,
    $flagsAndAttrs,
    $nullPtr
  )

  if ($handle -eq [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE -or $handle -eq [IntPtr]::Zero) {
    return $false
  }

  try {
    $actualIdentity = Get-DirectoryObjectIdentity -HandleWrapper $handle
    if ($null -eq $actualIdentity) {
      return $false
    }
    $match = ($actualIdentity.VolumeSerialNumber -eq [uint32]$ExpectedIdentity.VolumeSerialNumber) -and
             ($actualIdentity.FileIndexHigh -eq [uint32]$ExpectedIdentity.FileIndexHigh) -and
             ($actualIdentity.FileIndexLow -eq [uint32]$ExpectedIdentity.FileIndexLow)
    return $match
  }
  finally {
    [void][Win32NativeMergeHelper]::CloseHandle($handle)
  }
}

function Invoke-DirectoryRenameByHandle {
  param(
    $HandleWrapper,
    [string]$NewPath,
    [bool]$ReplaceIfExists = $false
  )
  if ($HandleWrapper -is [System.Management.Automation.PSReference]) {
    $HandleWrapper = $HandleWrapper.Value
  }
  $rawHandle = if ($HandleWrapper -is [System.IntPtr]) {
    $HandleWrapper
  } elseif ($null -ne $HandleWrapper -and $null -ne $HandleWrapper.PSObject.Properties['NativeHandle']) {
    $HandleWrapper.NativeHandle
  } else {
    [IntPtr]::Zero
  }

  if ($rawHandle -eq [IntPtr]::Zero -or $rawHandle -eq [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE) {
    return [PSCustomObject]@{
      Success    = $false
      Win32Error = 6 # ERROR_INVALID_HANDLE
    }
  }

  $err = 0
  # Strictly force ReplaceIfExists = $false (fail-closed, no overwrite, no fallback)
  $success = [Win32NativeMergeHelper]::RenameDirectory($rawHandle, $NewPath, $false, [ref]$err)
  return [PSCustomObject]@{
    Success    = [bool]$success
    Win32Error = [int]$err
  }
}

function Close-DirectoryHandleOnce {
  param($HandleWrapper)
  if ($null -eq $HandleWrapper) { return }
  if ($HandleWrapper -is [System.Management.Automation.PSReference]) {
    $HandleWrapper = $HandleWrapper.Value
  }
  if ($null -eq $HandleWrapper) { return }

  if ($HandleWrapper -is [System.IntPtr]) {
    return
  }

  if ($HandleWrapper.PSObject.Properties['NativeHandle']) {
    $rawHandle = $HandleWrapper.NativeHandle
    if ($rawHandle -ne [IntPtr]::Zero -and $rawHandle -ne [Win32NativeMergeHelper]::INVALID_HANDLE_VALUE) {
      $HandleWrapper.NativeHandle = [IntPtr]::Zero
      $HandleWrapper.IsValid = $false
      $HandleWrapper.CloseCount = [int]$HandleWrapper.CloseCount + 1
      [void][Win32NativeMergeHelper]::CloseHandle($rawHandle)
    }
  }
}

function New-MergePlanTokenV3 {
  param(
    [string]$VaultRoot,
    [string]$Uuid,
    [string]$CanonicalFolderName,
    [array]$SourceFolders,
    [array]$ManagedFiles
  )
  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms, [System.Text.Encoding]::UTF8)

  $bw.Write([System.Text.Encoding]::UTF8.GetBytes("FMOBSMERGE"))
  $bw.Write([byte]3)
  $bw.Write($VaultRoot)
  $bw.Write($Uuid.ToUpperInvariant())
  $bw.Write($CanonicalFolderName)

  $sortedFolders = [string[]]@($SourceFolders)
  [System.Array]::Sort($sortedFolders, [System.StringComparer]::Ordinal)
  $bw.Write([int32]$sortedFolders.Count)
  foreach ($sf in $sortedFolders) {
    $bw.Write($sf)
  }

  $fileKeys    = [string[]]@($ManagedFiles | ForEach-Object { $_.RelativePath })
  $sortedFiles = [object[]]@($ManagedFiles)
  [System.Array]::Sort([Array]$fileKeys, [Array]$sortedFiles, [System.StringComparer]::Ordinal)
  $bw.Write([int32]$sortedFiles.Count)
  foreach ($mf in $sortedFiles) {
    $bw.Write($mf.RelativePath)
    $bw.Write($mf.NoteType)
    $bw.Write([int64]$mf.SizeBytes)
    $bw.Write($mf.Sha256)
  }

  $bw.Flush()
  $payloadBytes = $ms.ToArray()
  $bw.Close()
  $ms.Close()

  $sha = [System.Security.Cryptography.SHA256]::Create()
  $hash = $sha.ComputeHash($payloadBytes)
  $tokenHex = [BitConverter]::ToString($hash).Replace("-", "").ToUpperInvariant()

  return "PLAN-V3-$tokenHex"
}

function Get-CustomerMergeTopology {
  param(
    [string]$VaultRoot,
    [string]$Uuid,
    [string]$CompanyNameRaw
  )
  $custRoot = Join-Path $VaultRoot "01_顧客"
  if (-not (Test-Path -LiteralPath $custRoot)) {
    return @{ Error = "CUSTOMER_NOT_FOUND"; Details = "顧客ルートフォルダ '01_顧客' が存在しません。" }
  }

  $custRootInfo = Get-Item -LiteralPath $custRoot
  if (($custRootInfo.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
    return @{
      Error   = "MERGE_REPARSE_POINT_UNSUPPORTED"
      Details = "顧客ルートフォルダ自体が再解析ポイント(ジャンクション/シンボリックリンク)です: $custRoot"
    }
  }
  $csCheck = Test-DirectoryCaseSensitiveSafe $custRoot
  if ($csCheck.Status -eq "CASE_SENSITIVE") {
    return @{
      Error   = "MERGE_CASE_SENSITIVE_DIRECTORY_UNSUPPORTED"
      Details = "顧客ルートフォルダが大文字/小文字を区別するディレクトリとして設定されています: $custRoot"
    }
  }
  if ($csCheck.Status -ne "CASE_INSENSITIVE") {
    return @{
      Error   = "MERGE_CASE_SENSITIVE_DIRECTORY_UNSUPPORTED"
      Details = "顧客ルートフォルダのケースセンシティブ状態を安全に確認できませんでした(フェイルクローズ): $($csCheck.Details)"
    }
  }

  try {
    $dirInfos = Get-ChildItem -LiteralPath $custRoot -Directory -Force -ErrorAction Stop
  }
  catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    return @{
      Error   = "MERGE_TOPOLOGY_ENUMERATION_FAILED"
      Details = "顧客ルートフォルダの列挙に失敗しました ($errClass): $($_.Exception.Message) (対象パス: $custRoot)"
    }
  }
  $matchedFolders = @()
  $prefixMap = Get-UciKnownPrefixMap

  foreach ($dir in $dirInfos) {
    if (($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
      return @{ Error = "MERGE_REPARSE_POINT_UNSUPPORTED"; Details = "顧客フォルダ内に再解析ポイント(ジャンクション/シンボリックリンク)が検出されました: $($dir.FullName)" }
    }

    try {
      $files = Get-ChildItem -LiteralPath $dir.FullName -File -Force -ErrorAction Stop
    }
    catch {
      $errClass = Get-LockAcquisitionErrorClass $_.Exception
      return @{
        Error   = "MERGE_TOPOLOGY_ENUMERATION_FAILED"
        Details = "顧客フォルダ内ファイルの列挙に失敗しました ($errClass): $($_.Exception.Message) (対象パス: $($dir.FullName))"
      }
    }
    $hasTargetUuid = $false
    $folderUuids = New-Object System.Collections.Generic.HashSet[string]
    $folderNoteTypes = New-Object System.Collections.Generic.HashSet[string]
    $folderManagedNotes = @()
    $folderUnmanagedFiles = @()

    foreach ($file in $files) {
      if (($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        return @{ Error = "MERGE_REPARSE_POINT_UNSUPPORTED"; Details = "ファイル '$($file.FullName)' に再解析ポイントが検出されました。" }
      }

      $linkCount = Get-FileHardLinkCountSafe $file.FullName
      if ($linkCount -lt 0) {
        return @{
          Error   = "MERGE_HARDLINK_UNSUPPORTED"
          Details = "ファイル '$($file.FullName)' のハードリンク状態を安全に確認できませんでした(フェイルクローズ)。"
        }
      }
      if ($linkCount -gt 1) {
        return @{
          Error   = "MERGE_HARDLINK_UNSUPPORTED"
          Details = "ファイル '$($file.FullName)' はハードリンクです(リンク数: $linkCount)。"
        }
      }

      $adsCheck = Test-FileAlternateDataStreamsSafe $file.FullName
      if ($adsCheck.Status -eq "HAS_ADS") {
        $streamSummary = ($adsCheck.NamedStreams -join ', ')
        return @{
          Error   = "MERGE_ALTERNATE_DATA_STREAM_UNSUPPORTED"
          Details = "ファイル '$($file.FullName)' に未対応の代替データストリーム(ADS)が検出されました ($streamSummary)。"
        }
      }
      if ($adsCheck.Status -ne "CLEAN") {
        return @{
          Error   = "MERGE_ALTERNATE_DATA_STREAM_UNSUPPORTED"
          Details = "ファイル '$($file.FullName)' の代替データストリーム(ADS)状態を安全に確認できませんでした(フェイルクローズ): $($adsCheck.Details)"
        }
      }

      if ($file.Name.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
        $headerLines = Get-YamlHeaderLines $file.FullName
        if ($null -ne $headerLines) {
          $fileUuid = Get-YamlScalarValue $headerLines "UUID:"
          if (-not [string]::IsNullOrWhiteSpace($fileUuid)) {
            if (-not (Test-UciUuidFormat $fileUuid)) {
              return @{ Error = "FOLDER_UUID_INVALID"; Details = "ファイル '$($file.FullName)' のYAML UUID形式が不正です: $fileUuid" }
            }
            [void]$folderUuids.Add($fileUuid.Trim().ToUpperInvariant())

            if ($fileUuid.Trim().ToUpperInvariant() -eq $Uuid.Trim().ToUpperInvariant()) {
              $hasTargetUuid = $true

              $matchedPrefix = $null
              foreach ($k in $prefixMap.Keys) {
                if ($file.Name.StartsWith("${k}_", [System.StringComparison]::Ordinal)) {
                  $matchedPrefix = $k
                  break
                }
              }

              if ($null -ne $matchedPrefix) {
                $nType = $prefixMap[$matchedPrefix]
                if ($folderNoteTypes.Contains($nType)) {
                  return @{ Error = "DUPLICATE_NOTE_TYPE"; Details = "フォルダ '$($dir.Name)' 内に同一noteType('$nType')のノートが複数存在します: $($file.Name)" }
                }
                [void]$folderNoteTypes.Add($nType)
                $sha = Get-FileSha256Raw $file.FullName
                $folderManagedNotes += @{
                  FileName = $file.Name
                  FullPath = $file.FullName
                  RelativePath = Get-RelPath $VaultRoot $file.FullName
                  NoteType = $nType
                  SizeBytes = $file.Length
                  Sha256 = $sha
                }
              } else {
                return @{ Error = "MERGE_UNMANAGED_UUID_EVIDENCE"; Details = "管理プレフィックス外のMarkdownファイル '$($file.Name)' に対象UUIDが記載されています。" }
              }
            }
          }
        }
      } else {
        $folderUnmanagedFiles += @{
          FileName = $file.Name
          FullPath = $file.FullName
          RelativePath = Get-RelPath $VaultRoot $file.FullName
          SizeBytes = $file.Length
        }
      }
    }

    try {
      $subDirs = Get-ChildItem -LiteralPath $dir.FullName -Directory -Recurse -Force -ErrorAction Stop
    }
    catch {
      $errClass = Get-LockAcquisitionErrorClass $_.Exception
      return @{
        Error   = "MERGE_TOPOLOGY_ENUMERATION_FAILED"
        Details = "顧客フォルダ配下のサブフォルダ列挙に失敗しました ($errClass): $($_.Exception.Message) (対象パス: $($dir.FullName))"
      }
    }
    foreach ($sd in $subDirs) {
      if (($sd.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        return @{ Error = "MERGE_REPARSE_POINT_UNSUPPORTED"; Details = "サブフォルダ '$($sd.FullName)' に再解析ポイントが検出されました。" }
      }
      try {
        $subFiles = Get-ChildItem -LiteralPath $sd.FullName -File -Force -ErrorAction Stop
      }
      catch {
        $errClass = Get-LockAcquisitionErrorClass $_.Exception
        return @{
          Error   = "MERGE_TOPOLOGY_ENUMERATION_FAILED"
          Details = "サブフォルダ内ファイルの列挙に失敗しました ($errClass): $($_.Exception.Message) (対象パス: $($sd.FullName))"
        }
      }
      foreach ($sf in $subFiles) {
        if ($sf.Name.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase)) {
          $subHeader = Get-YamlHeaderLines $sf.FullName
          if ($null -ne $subHeader) {
            $subUuid = Get-YamlScalarValue $subHeader "UUID:"
            if ($subUuid -and $subUuid.Trim().ToUpperInvariant() -eq $Uuid.Trim().ToUpperInvariant()) {
              return @{ Error = "MANAGED_NOTE_OUT_OF_SCOPE"; Details = "管理対象ノートと同一UUIDのノートがサブフォルダ内に存在します: $($sf.FullName)" }
            }
          }
        }
      }
    }

    if ($folderUuids.Count -gt 1) {
      return @{ Error = "FOLDER_UUID_MIXED"; Details = "フォルダ '$($dir.Name)' 内に複数の異なるUUIDが混在しています: $(($folderUuids | ForEach-Object { $_ }) -join ', ')" }
    }

    if ($hasTargetUuid) {
      $matchedFolders += @{
        DirectoryInfo = $dir
        FolderName = $dir.Name
        FullPath = $dir.FullName
        ManagedNotes = $folderManagedNotes
        UnmanagedFiles = $folderUnmanagedFiles
      }
    }
  }

  if ($matchedFolders.Count -eq 0) {
    return @{ Error = "CUSTOMER_NOT_FOUND"; Details = "指定されたUUID ($Uuid) の証拠を持つ顧客フォルダが見つかりません。" }
  }

  $canonicalFolderName = Get-CanonicalCustomerFolderName $CompanyNameRaw $Uuid
  $canonicalFolderFullPath = Join-Path $custRoot $canonicalFolderName

  return @{
    Error = $null
    CustRoot = $custRoot
    MatchedFolders = $matchedFolders
    CanonicalFolderName = $canonicalFolderName
    CanonicalFolderFullPath = $canonicalFolderFullPath
    IsConflict = ($matchedFolders.Count -ge 2)
  }
}

function Resolve-CanonicalDestinationState {
  param([hashtable]$Topology)

  $canonicalPath = $Topology.CanonicalFolderFullPath
  try {
    $item = Get-Item -LiteralPath $canonicalPath -Force -ErrorAction Stop
  }
  catch [System.Management.Automation.ItemNotFoundException] {
    return "ABSENT"
  }
  catch {
    return "INSPECTION_FAILED"
  }

  if ($null -eq $item) {
    return "ABSENT"
  }

  if ($item.PSIsContainer) {
    if ($null -ne $Topology.MatchedFolders) {
      foreach ($mf in $Topology.MatchedFolders) {
        if ([string]::Equals($canonicalPath, $mf.FullPath, [System.StringComparison]::OrdinalIgnoreCase) -or
            [string]::Equals($Topology.CanonicalFolderName, $mf.FolderName, [System.StringComparison]::OrdinalIgnoreCase)) {
          return "MATCHED_EXISTING"
        }
      }
    }
    return "UNOWNED_DIRECTORY"
  }

  return "NON_DIRECTORY_OCCUPANT"
}

function Resolve-MergeTargetOccupancyState {
  param(
    [string]$TargetPath,
    [string]$SourcePath
  )

  if ([string]::Equals($TargetPath, $SourcePath, [System.StringComparison]::OrdinalIgnoreCase)) {
    return "SELF_SOURCE"
  }

  try {
    $item = Get-Item -LiteralPath $TargetPath -Force -ErrorAction Stop
  }
  catch [System.Management.Automation.ItemNotFoundException] {
    return "ABSENT"
  }
  catch {
    return "INSPECTION_FAILED"
  }

  if ($null -eq $item) {
    return "ABSENT"
  }

  return "OCCUPIED"
}

function Write-TransactionEvidenceSafe {
  param(
    [string]$TxDir,
    [string]$TxId,
    [string]$Type,
    [hashtable]$Data
  )
  $filePath = Join-Path $TxDir "$TxId.$Type.json"
  $jsonText = $Data | ConvertTo-Json -Depth 10
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonText)
  
  $fs = [System.IO.FileStream]::new(
    $filePath,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
  )
  try {
    $fs.Write($bytes, 0, $bytes.Length)
    $fs.Flush($true)
  } finally {
    $fs.Close()
    $fs.Dispose()
  }

  $readText = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
  $readData = ConvertFrom-Json $readText
  if ($null -eq $readData -or [string]$readData.txId -ne $TxId) {
    throw "証拠ファイルの読み戻し検証に失敗しました: $filePath"
  }
  return $filePath
}

function New-MergeStagingOwnershipSafe {
  param(
    [string]$TxDir,
    [string]$TxId
  )
  $stagingDir = Join-Path $TxDir "staging_$TxId"
  $createRes = New-Win32ExclusiveDirectory $stagingDir
  if (-not $createRes.Success) {
    if ($createRes.ErrorCode -eq 183) {
      throw "排他的ステージングディレクトリの作成に失敗しました (Win32Error: $($createRes.ErrorCode), Class: STAGING_DIR_ALREADY_EXISTS): $stagingDir"
    } else {
      throw "排他的ステージングディレクトリの作成に失敗しました (Win32Error: $($createRes.ErrorCode), Class: STAGING_DIR_CREATE_FAILED_NATIVE): $stagingDir"
    }
  }

  $ownerMarkerPath = Join-Path $stagingDir ".fm-obsidian-merge-owner"
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  $tokenBytes = New-Object byte[] 32
  $rng.GetBytes($tokenBytes)
  $tokenHex = [BitConverter]::ToString($tokenBytes).Replace("-", "").ToLowerInvariant()

  $fs = [System.IO.FileStream]::new(
    $ownerMarkerPath,
    [System.IO.FileMode]::CreateNew,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
  )
  try {
    $b = [System.Text.Encoding]::UTF8.GetBytes($tokenHex)
    $fs.Write($b, 0, $b.Length)
    $fs.Flush($true)
  } finally {
    $fs.Close()
    $fs.Dispose()
  }

  $readToken = [System.IO.File]::ReadAllText($ownerMarkerPath, [System.Text.Encoding]::UTF8).Trim()
  if ($readToken -ne $tokenHex) {
    throw "所有権マーカーの読み戻し検証に失敗しました: $ownerMarkerPath"
  }

  return @{
    StagingDir = $stagingDir
    OwnerToken = $tokenHex
    OwnerMarkerPath = $ownerMarkerPath
  }
}

function Get-JournalPropSafe($obj, [string]$propName) {
  if ($null -eq $obj) { return $null }
  if ($obj -is [System.Collections.IDictionary]) {
    if ($obj.Contains($propName)) { return $obj[$propName] }
    return $null
  }
  if ($null -ne $obj.PSObject -and $null -ne $obj.PSObject.Properties[$propName]) {
    return $obj.PSObject.Properties[$propName].Value
  }
  return $null
}

function Set-JournalPropSafe($obj, [string]$propName, $val) {
  if ($null -eq $obj) { return }
  if ($obj -is [System.Collections.IDictionary]) {
    $obj[$propName] = $val
  } elseif ($null -ne $obj.PSObject -and $null -ne $obj.PSObject.Properties[$propName]) {
    $obj.PSObject.Properties[$propName].Value = $val
  }
}

function Get-JournalEntriesArray($obj) {
  $raw = Get-JournalPropSafe $obj "entries"
  $list = New-Object System.Collections.Generic.List[object]
  if ($null -eq $raw) { return ,$list }
  if ($raw -is [System.Collections.IDictionary]) {
    $list.Add($raw)
    return ,$list
  }
  if ($raw -is [System.Management.Automation.PSCustomObject] -and $null -ne (Get-JournalPropSafe $raw "Seq")) {
    $list.Add($raw)
    return ,$list
  }
  if ($raw -is [System.Collections.IEnumerable]) {
    foreach ($item in $raw) {
      $list.Add($item)
    }
    return ,$list
  }
  $list.Add($raw)
  return ,$list
}

function Test-JournalContentEquality($expectedObj, $actualObj) {
  if ($null -eq $expectedObj -or $null -eq $actualObj) { return $false }
  try {
    # Top-level checks
    $expTxId = [string](Get-JournalPropSafe $expectedObj "txId")
    $actTxId = [string](Get-JournalPropSafe $actualObj "txId")
    if ($expTxId -ne $actTxId) { return $false }

    $expUuid = [string](Get-JournalPropSafe $expectedObj "uuid")
    $actUuid = [string](Get-JournalPropSafe $actualObj "uuid")
    if ($expUuid -ne $actUuid) { return $false }

    $expVault = [string](Get-JournalPropSafe $expectedObj "vaultRoot")
    $actVault = [string](Get-JournalPropSafe $actualObj "vaultRoot")
    if ($expVault -ne $actVault) { return $false }

    $expFolder = [string](Get-JournalPropSafe $expectedObj "canonicalFolderName")
    $actFolder = [string](Get-JournalPropSafe $actualObj "canonicalFolderName")
    if ($expFolder -ne $actFolder) { return $false }

    $expOwner = [string](Get-JournalPropSafe $expectedObj "ownerToken")
    $actOwner = [string](Get-JournalPropSafe $actualObj "ownerToken")
    if ($expOwner -ne $actOwner) { return $false }

    $expRbStatus = [string](Get-JournalPropSafe $expectedObj "rollbackStatus")
    $actRbStatus = [string](Get-JournalPropSafe $actualObj "rollbackStatus")
    if ($expRbStatus -ne $actRbStatus) { return $false }

    # Entries comparison
    $expEntries = Get-JournalEntriesArray $expectedObj
    $actEntries = Get-JournalEntriesArray $actualObj

    if ($expEntries.Count -ne $actEntries.Count) { return $false }

    for ($i = 0; $i -lt $expEntries.Count; $i++) {
      $e1 = $expEntries[$i]
      $e2 = $actEntries[$i]
      
      $seq1 = Get-JournalPropSafe $e1 "Seq"
      $seq2 = Get-JournalPropSafe $e2 "Seq"
      if ([int]$seq1 -ne [int]$seq2) { return $false }

      $op1 = [string](Get-JournalPropSafe $e1 "OpType")
      $op2 = [string](Get-JournalPropSafe $e2 "OpType")
      if ($op1 -ne $op2) { return $false }

      $src1 = [string](Get-JournalPropSafe $e1 "SourcePath")
      $src2 = [string](Get-JournalPropSafe $e2 "SourcePath")
      if ($src1 -ne $src2) { return $false }

      $dst1 = [string](Get-JournalPropSafe $e1 "DestPath")
      $dst2 = [string](Get-JournalPropSafe $e2 "DestPath")
      if ($dst1 -ne $dst2) { return $false }

      $sha1 = [string](Get-JournalPropSafe $e1 "ExpectedSha256")
      $sha2 = [string](Get-JournalPropSafe $e2 "ExpectedSha256")
      if ($sha1 -ne $sha2) { return $false }

      $size1 = Get-JournalPropSafe $e1 "ExpectedSizeBytes"
      $size2 = Get-JournalPropSafe $e2 "ExpectedSizeBytes"
      if (($null -eq $size1) -ne ($null -eq $size2)) { return $false }
      if ($null -ne $size1 -and [long]$size1 -ne [long]$size2) { return $false }

      $tok1 = [string](Get-JournalPropSafe $e1 "OwnerToken")
      $tok2 = [string](Get-JournalPropSafe $e2 "OwnerToken")
      if ($tok1 -ne $tok2) { return $false }

      $st1 = [string](Get-JournalPropSafe $e1 "State")
      $st2 = [string](Get-JournalPropSafe $e2 "State")
      if ($st1 -ne $st2) { return $false }
    }
    return $true
  } catch {
    return $false
  }
}

function Test-JournalStructureValid {
  param(
    $JournalData,
    [string]$ExpectedTxId = "",
    [string]$ExpectedOwnerToken = ""
  )
  if ($null -eq $JournalData) { return $false }
  try {
    $jTxId = [string](Get-JournalPropSafe $JournalData "txId")
    if ([string]::IsNullOrWhiteSpace($jTxId)) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedTxId) -and $jTxId -ne $ExpectedTxId) { return $false }

    $jUuid = [string](Get-JournalPropSafe $JournalData "uuid")
    if ([string]::IsNullOrWhiteSpace($jUuid)) { return $false }

    $jVault = [string](Get-JournalPropSafe $JournalData "vaultRoot")
    if ([string]::IsNullOrWhiteSpace($jVault)) { return $false }

    $jFolder = [string](Get-JournalPropSafe $JournalData "canonicalFolderName")
    if ([string]::IsNullOrWhiteSpace($jFolder)) { return $false }

    $jOwner = [string](Get-JournalPropSafe $JournalData "ownerToken")
    if ([string]::IsNullOrWhiteSpace($jOwner)) { return $false }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedOwnerToken) -and $jOwner -ne $ExpectedOwnerToken) { return $false }

    $entryList = Get-JournalEntriesArray $JournalData

    $allowedOpTypes = @("MOVE_FILE", "MOVE_FILE_STAGING_TO_CANONICAL", "MOVE_OWNERSHIP_MARKER", "MOVE_DIRECTORY")
    $allowedStates = @("PENDING", "COMPLETED", "ROLLED_BACK")

    $expectedSeq = 1
    $seenSeq = New-Object System.Collections.Generic.HashSet[int]

    foreach ($e in $entryList) {
      if ($null -eq $e) { return $false }
      $seq = Get-JournalPropSafe $e "Seq"
      if ($null -eq $seq) { return $false }
      $seqInt = [int]$seq
      if ($seqInt -ne $expectedSeq -or $seenSeq.Contains($seqInt)) { return $false }
      [void]$seenSeq.Add($seqInt)
      $expectedSeq++

      $op = [string](Get-JournalPropSafe $e "OpType")
      if ($allowedOpTypes -notcontains $op) { return $false }

      $st = [string](Get-JournalPropSafe $e "State")
      if ($allowedStates -notcontains $st) { return $false }

      $src = [string](Get-JournalPropSafe $e "SourcePath")
      $dst = [string](Get-JournalPropSafe $e "DestPath")
      if ([string]::IsNullOrWhiteSpace($src) -or [string]::IsNullOrWhiteSpace($dst)) { return $false }

      if ($op -in @("MOVE_FILE", "MOVE_FILE_STAGING_TO_CANONICAL")) {
        $sha = [string](Get-JournalPropSafe $e "ExpectedSha256")
        $size = Get-JournalPropSafe $e "ExpectedSizeBytes"
        if ([string]::IsNullOrWhiteSpace($sha) -or $null -eq $size -or [long]$size -lt 0) { return $false }
      } elseif ($op -eq "MOVE_OWNERSHIP_MARKER") {
        $sha = [string](Get-JournalPropSafe $e "ExpectedSha256")
        $size = Get-JournalPropSafe $e "ExpectedSizeBytes"
        $tok = [string](Get-JournalPropSafe $e "OwnerToken")
        if ([string]::IsNullOrWhiteSpace($sha) -or $null -eq $size -or [string]::IsNullOrWhiteSpace($tok)) { return $false }
      } elseif ($op -eq "MOVE_DIRECTORY") {
        $tok = [string](Get-JournalPropSafe $e "OwnerToken")
        if ([string]::IsNullOrWhiteSpace($tok)) { return $false }
      }
    }
    return $true
  } catch {
    return $false
  }
}

function Write-JournalEvidenceSafe {
  param(
    [string]$TxDir,
    [string]$TxId,
    $Data
  )
  $filePath = Join-Path $TxDir "$TxId.journal.json"
  $tmpPath = Join-Path $TxDir "$TxId.journal.json.tmp"
  $jsonText = $Data | ConvertTo-Json -Depth 10
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonText)

  # 1. Write to temporary file with Flush(true)
  $fs = [System.IO.FileStream]::new(
    $tmpPath,
    [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::Write,
    [System.IO.FileShare]::None
  )
  try {
    $fs.Write($bytes, 0, $bytes.Length)
    $fs.Flush($true)
  } finally {
    $fs.Close()
    $fs.Dispose()
  }

  # Crash Window A: tmp written and flushed, before atomic promotion
  Invoke-TestCrashHook "A"

  # 2. Read-back verify temporary file
  $readTmpText = [System.IO.File]::ReadAllText($tmpPath, [System.Text.Encoding]::UTF8)
  $readTmpData = ConvertFrom-Json $readTmpText
  if (-not (Test-JournalStructureValid $readTmpData $TxId) -or -not (Test-JournalContentEquality $Data $readTmpData)) {
    if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue }
    throw "一時ジャーナルファイルの読み戻し完全検証に失敗しました: $tmpPath"
  }

  # 3. Atomic replace into live journal path
  $ok = [Win32DurableJournalHelper]::MoveFileEx(
    $tmpPath,
    $filePath,
    [Win32DurableJournalHelper]::MOVEFILE_REPLACE_EXISTING -bor [Win32DurableJournalHelper]::MOVEFILE_WRITE_THROUGH
  )
  if (-not $ok) {
    $winErr = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
    if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force -ErrorAction SilentlyContinue }
    throw "Win32 MoveFileEx によるジャーナルのアトミック置換に失敗しました (ErrorCode: $winErr): $filePath"
  }

  # Crash Window B: after atomic promotion, before post-promotion verify
  Invoke-TestCrashHook "B"

  # 4. Post-promotion verification of live journal
  $readLiveText = [System.IO.File]::ReadAllText($filePath, [System.Text.Encoding]::UTF8)
  $readLiveData = ConvertFrom-Json $readLiveText
  if (-not (Test-JournalStructureValid $readLiveData $TxId) -or -not (Test-JournalContentEquality $Data $readLiveData)) {
    throw "本番ジャーナルファイルのアトミック昇格後検証に失敗しました: $filePath"
  }

  return $filePath
}

function Get-LockAcquisitionErrorClass($Exception) {
  if ($null -eq $Exception) { return "UNEXPECTED_IO" }
  $curEx = $Exception
  if ($curEx -is [System.Management.Automation.ErrorRecord]) {
    $curEx = $curEx.Exception
  }

  while ($null -ne $curEx) {
    if ($curEx -is [System.UnauthorizedAccessException] -or $curEx -is [System.Security.SecurityException]) {
      return "ACCESS_DENIED"
    }
    if ($curEx -is [System.IO.DirectoryNotFoundException] -or
        $curEx -is [System.IO.PathTooLongException] -or
        $curEx -is [System.ArgumentException] -or
        $curEx -is [System.NotSupportedException]) {
      return "INVALID_PATH"
    }
    if ($curEx -is [System.IO.IOException]) {
      $hr = [int]$curEx.HResult
      # Win32 ERROR_SHARING_VIOLATION (0x80070020), ERROR_LOCK_VIOLATION (0x80070021)
      if ($hr -eq [int]0x80070020 -or $hr -eq [int]0x80070021 -or ($hr -band 0xFFFF) -eq 0x20 -or ($hr -band 0xFFFF) -eq 0x21) {
        return "CONTENTION"
      }
      # Win32 ERROR_ACCESS_DENIED (0x80070005)
      if ($hr -eq [int]0x80070005 -or ($hr -band 0xFFFF) -eq 0x05) {
        return "ACCESS_DENIED"
      }
      # Win32 ERROR_PATH_NOT_FOUND (0x80070003), ERROR_FILE_NOT_FOUND (0x80070002), ERROR_BAD_PATHNAME (0x800700A1)
      if ($hr -eq [int]0x80070003 -or $hr -eq [int]0x80070002 -or $hr -eq [int]0x800700A1 -or
          ($hr -band 0xFFFF) -eq 0x03 -or ($hr -band 0xFFFF) -eq 0x02 -or ($hr -band 0xFFFF) -eq 0xA1) {
        return "INVALID_PATH"
      }
      return "UNEXPECTED_IO"
    }
    $curEx = $curEx.InnerException
  }
  return "UNEXPECTED_IO"
}

function Test-RollbackCompleteSemanticValid($JournalObj, [string]$TxId, [string]$TxDir) {
  if ($null -eq $JournalObj -or [string]::IsNullOrWhiteSpace($TxId) -or [string]::IsNullOrWhiteSpace($TxDir)) {
    return $false
  }
  try {
    # 1. Structural validity
    if (-not (Test-JournalStructureValid $JournalObj $TxId)) { return $false }
    if ((Get-JournalPropSafe $JournalObj "txId") -ne $TxId) { return $false }
    if ((Get-JournalPropSafe $JournalObj "rollbackStatus") -ne "ROLLBACK_COMPLETE") { return $false }

    # 2. No committed evidence exists
    $committedPath = Join-Path $TxDir "$TxId.committed.json"
    if (Test-Path -LiteralPath $committedPath) { return $false }

    # 3. Check every entry is ROLLED_BACK with filesystem correspondence
    $entries = Get-JournalEntriesArray $JournalObj
    if ($entries.Count -eq 0) {
      return $true # empty transaction rollback complete
    }

    foreach ($e in $entries) {
      if ($null -eq $e) { return $false }
      $eState = Get-JournalPropSafe $e "State"
      if ($eState -ne "ROLLED_BACK") { return $false }

      $op = Get-JournalPropSafe $e "OpType"
      $src = Get-JournalPropSafe $e "SourcePath"
      $dst = Get-JournalPropSafe $e "DestPath"

      if ([string]::IsNullOrWhiteSpace($src) -or [string]::IsNullOrWhiteSpace($dst)) { return $false }

      # DestPath must be absent after rollback
      if (Test-Path -LiteralPath $dst) { return $false }

      # SourcePath must exist with correct type and hash
      if ($op -in @("MOVE_FILE", "MOVE_FILE_STAGING_TO_CANONICAL")) {
        if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { return $false }
        $expSha = Get-JournalPropSafe $e "ExpectedSha256"
        if (-not [string]::IsNullOrWhiteSpace($expSha)) {
          $actSha = Get-FileSha256Raw $src
          if ($actSha -ne $expSha) { return $false }
        }
      } elseif ($op -eq "MOVE_DIRECTORY") {
        if (-not (Test-Path -LiteralPath $src -PathType Container)) { return $false }
      } else {
        return $false # unknown op type
      }
    }

    return $true
  } catch {
    return $false
  }
}

function Complete-RollbackEvidenceCleanup([string]$TxId, [string]$TxDir, $JournalObj) {
  if ([string]::IsNullOrWhiteSpace($TxId) -or [string]::IsNullOrWhiteSpace($TxDir)) { return }
  try {
    # 1. Clean staging directory if present and empty
    $stagingDir = Join-Path $TxDir "staging_$TxId"
    if (Test-Path -LiteralPath $stagingDir -PathType Container) {
      $marker = Join-Path $stagingDir ".fm-obsidian-merge-owner"
      if (Test-Path -LiteralPath $marker) {
        Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
      }
      $remaining = @(Get-ChildItem -LiteralPath $stagingDir -Force -ErrorAction SilentlyContinue)
      if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $stagingDir -Force -ErrorAction SilentlyContinue
      }
    }

    # 2. Remove inprogress marker
    $ipPath = Join-Path $TxDir "$TxId.inprogress.json"
    if (Test-Path -LiteralPath $ipPath) {
      Remove-Item -LiteralPath $ipPath -Force -ErrorAction SilentlyContinue
    }
  } catch {}
}

function Complete-RollbackTerminalState {
  param($JournalObj, [string]$TxId, [string]$TxDir, [string]$Status)
  # $Status is "ROLLBACK_COMPLETE" or "ROLLBACK_FAILED"
  if ($null -eq $JournalObj) { return @{ Persisted = $false; Error = "no journal object" } }
  if ([string]::IsNullOrWhiteSpace($TxDir) -or [string]::IsNullOrWhiteSpace($TxId)) {
    return @{ Persisted = $false; Error = "txDir/txId 未指定" }
  }
  try {
    Set-JournalPropSafe $JournalObj "rollbackStatus" $Status
    [void](Write-JournalEvidenceSafe $TxDir $TxId $JournalObj)
    return @{ Persisted = $true; Error = $null }
  } catch {
    return @{ Persisted = $false; Error = $_.Exception.Message }
  }
}

function Invoke-OptionBRollback {
  param(
    $Journal,
    [string]$TxId,
    [string]$TxDir
  )
  $rollbackFailed = $false
  $rollbackDetails = @()

  $journalObj = $null
  $liveJournalPath = if (-not [string]::IsNullOrWhiteSpace($TxDir) -and -not [string]::IsNullOrWhiteSpace($TxId)) {
    Join-Path $TxDir "$TxId.journal.json"
  } else { $null }

  if ($null -ne $Journal -and ($Journal -is [System.Collections.IDictionary] -or $null -ne (Get-JournalPropSafe $Journal "txId") -or $null -ne (Get-JournalPropSafe $Journal "entries"))) {
    $journalObj = $Journal
  } elseif ($null -ne $liveJournalPath -and (Test-Path -LiteralPath $liveJournalPath)) {
    try {
      $rawText = [System.IO.File]::ReadAllText($liveJournalPath, [System.Text.Encoding]::UTF8)
      $journalObj = ConvertFrom-Json $rawText
    } catch {
      return @{
        Success = $false
        TerminalStatePersisted = $false
        Details = "ジャーナルファイルの読み込みまたはJSON解析に失敗しました: $liveJournalPath / ジャーナル読取不能のため終端状態を書き換えません (indeterminate)"
      }
    }
  }

  # B4-N7: Missing journal check
  if ($null -eq $journalObj) {
    $hasEvidence = $false
    if (-not [string]::IsNullOrWhiteSpace($TxDir) -and -not [string]::IsNullOrWhiteSpace($TxId)) {
      $ipPath = Join-Path $TxDir "$TxId.inprogress.json"
      $stgPath = Join-Path $TxDir "staging_$TxId"
      if ((Test-Path -LiteralPath $ipPath) -or (Test-Path -LiteralPath $stgPath)) {
        $hasEvidence = $true
      }
    }
    if ($hasEvidence) {
      return @{
        Success = $false
        TerminalStatePersisted = $false
        Details = "トランザクション証跡(inprogress/staging)が存在しますがジャーナルが存在しないためロールバック不能 (Fail-Closed) / ジャーナル不存在のため rollbackStatus の永続性は主張しません"
      }
    }
    return @{
      Success = $true
      TerminalStatePersisted = $false
      Details = "ジャーナルエントリなし (変更なし)"
    }
  }

  # Structural validation
  if (-not (Test-JournalStructureValid $journalObj $TxId)) {
    return @{
      Success = $false
      TerminalStatePersisted = $false
      Details = "ジャーナルの構造検証に失敗したためロールバックを拒否します (不正または改変されたジャーナル) / ジャーナル不正のため終端状態を書き換えません (indeterminate)"
    }
  }

  $entryList = Get-JournalEntriesArray $journalObj
  if ($entryList.Count -eq 0) {
    $term = Complete-RollbackTerminalState $journalObj $TxId $TxDir "ROLLBACK_COMPLETE"
    if (-not $term.Persisted) {
      return @{
        Success = $false
        TerminalStatePersisted = $false
        Details = "ジャーナルエントリなし (変更なし) / 終端 rollbackStatus (ROLLBACK_COMPLETE) の永続化に失敗したため、ロールバック完了を主張できません: $($term.Error)"
      }
    }
    return @{
      Success = $true
      TerminalStatePersisted = $true
      Details = "ジャーナルエントリなし (変更なし)"
    }
  }

  # Phase 1: Preflight / Option B rules (Check PENDING state)
  $allowedOpTypes = @("MOVE_FILE", "MOVE_FILE_STAGING_TO_CANONICAL", "MOVE_OWNERSHIP_MARKER", "MOVE_DIRECTORY")
  foreach ($entry in $entryList) {
    $eState = [string](Get-JournalPropSafe $entry "State")
    $eOp = [string](Get-JournalPropSafe $entry "OpType")
    $eSrc = [string](Get-JournalPropSafe $entry "SourcePath")
    $eDst = [string](Get-JournalPropSafe $entry "DestPath")

    if ($eState -eq "PENDING") {
      $term = Complete-RollbackTerminalState $journalObj $TxId $TxDir "ROLLBACK_FAILED"
      return @{
        Success = $false
        TerminalStatePersisted = [bool]$term.Persisted
        Details = "PENDING状態のジャーナルエントリ ('$eOp') は破壊的Undo禁止のためFail-Closed (Src: $eSrc / Dst: $eDst)"
      }
    }
    if ($allowedOpTypes -notcontains $eOp) {
      return @{
        Success = $false
        TerminalStatePersisted = $false
        Details = "未知のOpType ('$eOp') が存在するため、ロールバックを中断します / ジャーナル不正のため終端状態を書き換えません (indeterminate)"
      }
    }
  }

  # Phase 2: Reverse-order rollback of COMPLETED entries (Seq descending)
  for ($i = $entryList.Count - 1; $i -ge 0; $i--) {
    $entry = $entryList[$i]
    $eState = [string](Get-JournalPropSafe $entry "State")
    if ($eState -eq "COMPLETED") {
      $op = [string](Get-JournalPropSafe $entry "OpType")
      $dst = [string](Get-JournalPropSafe $entry "DestPath")
      $src = [string](Get-JournalPropSafe $entry "SourcePath")
      $expSha = [string](Get-JournalPropSafe $entry "ExpectedSha256")
      $expSize = Get-JournalPropSafe $entry "ExpectedSizeBytes"
      $ownerToken = [string](Get-JournalPropSafe $entry "OwnerToken")

      try {
        if ($op -in @("MOVE_FILE", "MOVE_FILE_STAGING_TO_CANONICAL")) {
          if ((Test-Path -LiteralPath $dst) -and (-not (Test-Path -LiteralPath $src))) {
            $curSha = Get-FileSha256Raw $dst
            $curSize = (Get-Item -LiteralPath $dst).Length
            if ($curSha -eq $expSha -and $curSize -eq $expSize) {
              $srcParent = [System.IO.Path]::GetDirectoryName($src)
              if (-not [string]::IsNullOrWhiteSpace($srcParent) -and -not (Test-Path -LiteralPath $srcParent)) {
                [void][System.IO.Directory]::CreateDirectory($srcParent)
              }
              [System.IO.File]::Move($dst, $src)

              # Verify reverse move
              $restoredSha = Get-FileSha256Raw $src
              $restoredSize = (Get-Item -LiteralPath $src).Length
              if ($restoredSha -ne $expSha -or $restoredSize -ne $expSize -or (Test-Path -LiteralPath $dst)) {
                throw "ファイル復元後のディスク検証に失敗しました: $src"
              }

              Set-JournalPropSafe $entry "State" "ROLLED_BACK"
              if (-not [string]::IsNullOrWhiteSpace($TxDir) -and -not [string]::IsNullOrWhiteSpace($TxId)) {
                [void](Write-JournalEvidenceSafe $TxDir $TxId $journalObj)
              }
              Invoke-TestCrashHook "F"
            } else {
              $rollbackFailed = $true
              $rollbackDetails += "COMPLETEDファイルのSHA256/サイズ不一致または改変検知 (Dst: $dst)"
              break
            }
          } else {
            $rollbackFailed = $true
            $rollbackDetails += "移動元が存在しないか移動先が存在 (Dst: $dst / Src: $src)"
            break
          }
        }
        elseif ($op -eq "MOVE_OWNERSHIP_MARKER") {
          if ((Test-Path -LiteralPath $dst) -and (-not (Test-Path -LiteralPath $src))) {
            $curToken = (Get-Content -LiteralPath $dst -Raw -Encoding UTF8).Trim()
            $curSha = Get-FileSha256Raw $dst
            $curSize = (Get-Item -LiteralPath $dst).Length
            if ($curToken -eq $ownerToken -and $curSha -eq $expSha -and $curSize -eq $expSize) {
              $srcParent = [System.IO.Path]::GetDirectoryName($src)
              if (-not [string]::IsNullOrWhiteSpace($srcParent) -and -not (Test-Path -LiteralPath $srcParent)) {
                [void][System.IO.Directory]::CreateDirectory($srcParent)
              }
              [System.IO.File]::Move($dst, $src)

              $restoredToken = (Get-Content -LiteralPath $src -Raw -Encoding UTF8).Trim()
              $restoredSha = Get-FileSha256Raw $src
              $restoredSize = (Get-Item -LiteralPath $src).Length
              if ($restoredToken -ne $ownerToken -or $restoredSha -ne $expSha -or $restoredSize -ne $expSize -or (Test-Path -LiteralPath $dst)) {
                throw "マーカー復元後のディスク検証に失敗しました: $src"
              }

              Set-JournalPropSafe $entry "State" "ROLLED_BACK"
              if (-not [string]::IsNullOrWhiteSpace($TxDir) -and -not [string]::IsNullOrWhiteSpace($TxId)) {
                [void](Write-JournalEvidenceSafe $TxDir $TxId $journalObj)
              }
              Invoke-TestCrashHook "F"
            } else {
              $rollbackFailed = $true
              $rollbackDetails += "所有権マーカーのトークンまたはSHA不一致 (Dst: $dst)"
              break
            }
          } else {
            $rollbackFailed = $true
            $rollbackDetails += "マーカー移動元が存在しないか移動先が存在 (Dst: $dst / Src: $src)"
            break
          }
        }
        elseif ($op -eq "MOVE_DIRECTORY") {
          if ((Test-Path -LiteralPath $dst -PathType Container) -and (-not (Test-Path -LiteralPath $src))) {
            $markerPath = Join-Path $dst ".fm-obsidian-merge-owner"
            if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
              $tokenOnDisk = (Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8).Trim()
              if (-not [string]::IsNullOrWhiteSpace($ownerToken) -and $tokenOnDisk -eq $ownerToken) {
                [System.IO.Directory]::Move($dst, $src)

                $restoredMarker = Join-Path $src ".fm-obsidian-merge-owner"
                $restoredToken = if (Test-Path -LiteralPath $restoredMarker) { (Get-Content -LiteralPath $restoredMarker -Raw -Encoding UTF8).Trim() } else { "" }
                if ($restoredToken -ne $ownerToken -or (Test-Path -LiteralPath $dst)) {
                  throw "ディレクトリ復元後のディスク検証に失敗しました: $src"
                }

                Set-JournalPropSafe $entry "State" "ROLLED_BACK"
                if (-not [string]::IsNullOrWhiteSpace($TxDir) -and -not [string]::IsNullOrWhiteSpace($TxId)) {
                  [void](Write-JournalEvidenceSafe $TxDir $TxId $journalObj)
                }
                Invoke-TestCrashHook "F"
              } else {
                $rollbackFailed = $true
                $rollbackDetails += "ディレクトリ所有権マーカーのトークン不一致または不正のためディレクトリのロールバックを禁止します (Dst: $dst)"
                break
              }
            } else {
              $rollbackFailed = $true
              $rollbackDetails += "ディレクトリ所有権マーカーが存在しないためディレクトリのロールバックを禁止します (Dst: $dst)"
              break
            }
          } else {
            $rollbackFailed = $true
            $rollbackDetails += "ロールバック元ディレクトリが存在しないか移動先が存在 (Dst: $dst / Src: $src)"
            break
          }
        }
      } catch {
        $rollbackFailed = $true
        $rollbackDetails += "ロールバック処理中に例外が発生しました: $dst -> $src ($($_.Exception.Message))"
        break
      }
    }
  }

  # Persist terminal rollback state
  $status = if ($rollbackFailed) { "ROLLBACK_FAILED" } else { "ROLLBACK_COMPLETE" }
  $term = Complete-RollbackTerminalState $journalObj $TxId $TxDir $status

  if (-not $term.Persisted) {
    return @{
      Success = $false
      TerminalStatePersisted = $false
      Details = (($rollbackDetails + @("終端 rollbackStatus ($status) の永続化に失敗したため、ロールバック完了を主張できません: $($term.Error)")) -join " / ")
    }
  }

  return @{
    Success = (-not $rollbackFailed)
    TerminalStatePersisted = $true
    Details = if ($rollbackFailed) { ($rollbackDetails -join " / ") } else { "ロールバック完了" }
  }
}

function Invoke-PlanCustomerFolderMerge {
  param([hashtable]$Payload)

  $reqId = if ($Payload.ContainsKey("requestId")) { [string]$Payload.requestId } else { $null }
  $rawVaultRoot = if ($Payload.ContainsKey("VaultRoot")) { [string]$Payload.VaultRoot } else { "" }
  $uuid = if ($Payload.ContainsKey("pk_CLIENT")) { [string]$Payload.pk_CLIENT } else { "" }
  $nameRaw = if ($Payload.ContainsKey("companyNameRaw")) { [string]$Payload.companyNameRaw } else { "" }

  if ([string]::IsNullOrWhiteSpace($rawVaultRoot)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_REQUEST" "VaultRootが指定されていません。")
    return
  }

  $vaultRoot = Resolve-Win32CanonicalPath $rawVaultRoot
  if ([string]::IsNullOrWhiteSpace($vaultRoot) -or -not (Test-Path -LiteralPath $vaultRoot)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_REQUEST" "VaultRootが存在しないか、正規化に失敗しました: $rawVaultRoot")
    return
  }
  if (-not (Test-UciUuidFormat $uuid)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_UUID_FORMAT" "pk_CLIENTが有効なUUID形式ではありません。")
    return
  }

  # Lock Acquisition Phase (NH-1, NM-1, NM-2)
  $txDir = Join-Path $vaultRoot ".fm-obsidian-bridge-transactions"
  if (-not (Test-Path -LiteralPath $txDir)) { [void][System.IO.Directory]::CreateDirectory($txDir) }

  $lock = $null
  try {
    $lock = [System.IO.FileStream]::new(
      (Join-Path $txDir "ACTIVE.lock"),
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  } catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    if ($errClass -eq "CONTENTION") {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_OPERATION_IN_PROGRESS" "他の操作が実行中です。しばらく待ってから再試行してください。")
    } else {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_OPERATION_FAILED" "ロックの取得に失敗しました ($errClass): $($_.Exception.Message)")
    }
    return
  }

  try {
    # B-5 & NH-2: Per-transaction recovery pairing with Retain-and-Classify validator
    $inProgressFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*.inprogress.json" -File -ErrorAction SilentlyContinue)
    $unresolvedTxFound = $false
    $unresolvedTxDiag = $null
    foreach ($ipFile in $inProgressFiles) {
      $txIdMatch = [regex]::Match($ipFile.Name, "^(.+)\.inprogress\.json$")
      if ($txIdMatch.Success) {
        $curTxId = $txIdMatch.Groups[1].Value
        $matchingCommitted = Join-Path $txDir "$curTxId.committed.json"
        if (-not (Test-Path -LiteralPath $matchingCommitted)) {
          # Check if this transaction is a valid ROLLBACK_COMPLETE terminal state (NH-2 Retain-and-Classify)
          $matchingJournal = Join-Path $txDir "$curTxId.journal.json"
          $isRollbackComplete = $false
          if (Test-Path -LiteralPath $matchingJournal) {
            try {
              $jRaw = [System.IO.File]::ReadAllText($matchingJournal, [System.Text.Encoding]::UTF8)
              $jObj = ConvertFrom-Json $jRaw
              if (Test-RollbackCompleteSemanticValid $jObj $curTxId $txDir) {
                $isRollbackComplete = $true
              }
            } catch {}
          }

          if (-not $isRollbackComplete) {
            $unresolvedTxFound = $true
            if (Test-Path -LiteralPath $matchingJournal) {
              try {
                $jRaw = [System.IO.File]::ReadAllText($matchingJournal, [System.Text.Encoding]::UTF8)
                $jObj = ConvertFrom-Json $jRaw
                if (Test-JournalStructureValid $jObj $curTxId) {
                  $jEntries = Get-JournalEntriesArray $jObj
                  $compCount = @($jEntries | Where-Object { (Get-JournalPropSafe $_ 'State') -eq 'COMPLETED' }).Count
                  $pendCount = @($jEntries | Where-Object { (Get-JournalPropSafe $_ 'State') -eq 'PENDING' }).Count
                  $rbCount = @($jEntries | Where-Object { (Get-JournalPropSafe $_ 'State') -eq 'ROLLED_BACK' }).Count
                  $unresolvedTxDiag = "txId: $curTxId, entries: $($jEntries.Count), completed: $compCount, pending: $pendCount, rolledBack: $rbCount, rollbackStatus: $(Get-JournalPropSafe $jObj 'rollbackStatus')"
                }
              } catch {}
            }
            break
          }
        }
      }
    }
    if ($unresolvedTxFound) {
      $msg = if ($null -ne $unresolvedTxDiag) { "未解決のトランザクションインプログレスマーカーが存在します ($unresolvedTxDiag)。" } else { "未解決のトランザクションインプログレスマーカーが存在します。" }
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_RECOVERY_REQUIRED" $msg)
      return
    }

    $topo = Get-CustomerMergeTopology $vaultRoot $uuid $nameRaw
    if ($null -ne $topo.Error) {
      Write-Output (New-MergeResponse $reqId "NG" $topo.Error $topo.Details)
      return
    }

    if ($topo.MatchedFolders.Count -eq 1) {
      Write-Output (New-MergeResponse $reqId "OK" "MERGE_NOT_REQUIRED" "マージ対象フォルダが1件のみのため、統合は不要です。" -Extra @{ matchedFolderCount = 1 })
      return
    }

    $canonicalFolderName = $topo.CanonicalFolderName
    $canonicalState = Resolve-CanonicalDestinationState $topo
    if ($canonicalState -eq "UNOWNED_DIRECTORY") {
      Write-Output (New-MergeResponse $reqId "NG" "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "canonicalフォルダ '$canonicalFolderName' が存在しますが、対象UUIDの証拠を持たないため統合計画を生成できません。")
      return
    }
    elseif ($canonicalState -eq "NON_DIRECTORY_OCCUPANT") {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_CANONICAL_PATH_OCCUPIED" "canonicalパスに通常ファイルが存在するため、統合計画を生成できません。")
      return
    }
    elseif ($canonicalState -eq "INSPECTION_FAILED") {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_TOPOLOGY_ENUMERATION_FAILED" "canonicalパスの検査に失敗しました。")
      return
    }

    $allManagedNotes = @()
    $globalNoteTypes = New-Object System.Collections.Generic.HashSet[string]
    $allSourceFolderNames = @()

    foreach ($f in $topo.MatchedFolders) {
      $allSourceFolderNames += $f.FolderName
      foreach ($n in $f.ManagedNotes) {
        if ($globalNoteTypes.Contains($n.NoteType)) {
          Write-Output (New-MergeResponse $reqId "NG" "DUPLICATE_NOTE_TYPE" "マージ対象フォルダ間で同一noteType('$($n.NoteType)')のノートが重複しています: $($n.FileName)")
          return
        }
        [void]$globalNoteTypes.Add($n.NoteType)
        $allManagedNotes += $n
      }
    }

    $token = New-MergePlanTokenV3 $vaultRoot $uuid $canonicalFolderName $allSourceFolderNames $allManagedNotes

    $moves = @()
    foreach ($n in $allManagedNotes) {
      $targetPath = Join-Path $topo.CanonicalFolderFullPath $n.FileName
      $moves += [ordered]@{
        sourcePath = $n.FullPath
        targetPath = $targetPath
        noteType = $n.NoteType
        sizeBytes = $n.SizeBytes
        sha256 = $n.Sha256
      }
    }

    $planData = [ordered]@{
      canonicalFolderName = $canonicalFolderName
      sourceFolders = $allSourceFolderNames
      managedFilesCount = $allManagedNotes.Count
      moves = $moves
    }

    Write-Output (New-MergeResponse $reqId "OK" "MERGE_PLAN_READY" "マージ計画を正常に生成しました。" -extra @{ planToken = $token; plan = $planData })
  } finally {
    if ($null -ne $lock) {
      $lock.Close()
      $lock.Dispose()
    }
  }
}

function Invoke-ApplyCustomerFolderMerge {
  param([hashtable]$Payload)

  $reqId = if ($Payload.ContainsKey("requestId")) { [string]$Payload.requestId } else { $null }
  $rawVaultRoot = if ($Payload.ContainsKey("VaultRoot")) { [string]$Payload.VaultRoot } else { "" }
  $uuid = if ($Payload.ContainsKey("pk_CLIENT")) { [string]$Payload.pk_CLIENT } else { "" }
  $nameRaw = if ($Payload.ContainsKey("companyNameRaw")) { [string]$Payload.companyNameRaw } else { "" }
  $reqToken = if ($Payload.ContainsKey("planToken")) { [string]$Payload.planToken } else { "" }

  if ([string]::IsNullOrWhiteSpace($rawVaultRoot)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_REQUEST" "VaultRootが指定されていません。")
    return
  }

  $vaultRoot = Resolve-Win32CanonicalPath $rawVaultRoot
  if ([string]::IsNullOrWhiteSpace($vaultRoot) -or -not (Test-Path -LiteralPath $vaultRoot)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_REQUEST" "VaultRootが存在しないか、正規化に失敗しました: $rawVaultRoot")
    return
  }
  if (-not (Test-UciUuidFormat $uuid)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_UUID_FORMAT" "pk_CLIENTが有効なUUID形式ではありません。")
    return
  }
  if ([string]::IsNullOrWhiteSpace($reqToken)) {
    Write-Output (New-MergeResponse $reqId "NG" "INVALID_REQUEST" "planTokenが指定されていません。")
    return
  }

  # APPLY request schema validation: unexpected fields check
  $allowedApplyKeys = @("protocolVersion", "action", "requestId", "VaultRoot", "pk_CLIENT", "companyNameRaw", "planToken")
  foreach ($k in $Payload.Keys) {
    if ($allowedApplyKeys -notcontains $k) {
      Write-Output (New-MergeResponse $reqId "NG" "INVALID_REQUEST" "定義外のフィールドが含まれています: $k")
      return
    }
  }

  # Lock Acquisition Phase (NH-1, NM-1, NM-2)
  $txDir = Join-Path $vaultRoot ".fm-obsidian-bridge-transactions"
  if (-not (Test-Path -LiteralPath $txDir)) { [void][System.IO.Directory]::CreateDirectory($txDir) }

  $txId = $null
  $journalData = $null
  $isCommitted = $false
  $warning = $null
  $topo = $null
  $allManagedNotes = @()

  $lock = $null
  try {
    $lock = [System.IO.FileStream]::new(
      (Join-Path $txDir "ACTIVE.lock"),
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  } catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    if ($errClass -eq "CONTENTION") {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_OPERATION_IN_PROGRESS" "他の操作が実行中です。しばらく待ってから再試行してください。")
    } else {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_OPERATION_FAILED" "ロックの取得に失敗しました ($errClass): $($_.Exception.Message)")
    }
    return
  }

  try {
    $txId = [Guid]::NewGuid().ToString("D")

    # B-5 & NH-2: Per-transaction recovery pairing with Retain-and-Classify validator
    $inProgressFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*.inprogress.json" -File -ErrorAction SilentlyContinue)
    $unresolvedTxFound = $false
    $unresolvedTxDiag = $null
    foreach ($ipFile in $inProgressFiles) {
      $txIdMatch = [regex]::Match($ipFile.Name, "^(.+)\.inprogress\.json$")
      if ($txIdMatch.Success) {
        $curTxId = $txIdMatch.Groups[1].Value
        $matchingCommitted = Join-Path $txDir "$curTxId.committed.json"
        if (-not (Test-Path -LiteralPath $matchingCommitted)) {
          # Check if this transaction is a valid ROLLBACK_COMPLETE terminal state (NH-2 Retain-and-Classify)
          $matchingJournal = Join-Path $txDir "$curTxId.journal.json"
          $isRollbackComplete = $false
          if (Test-Path -LiteralPath $matchingJournal) {
            try {
              $jRaw = [System.IO.File]::ReadAllText($matchingJournal, [System.Text.Encoding]::UTF8)
              $jObj = ConvertFrom-Json $jRaw
              if (Test-RollbackCompleteSemanticValid $jObj $curTxId $txDir) {
                $isRollbackComplete = $true
              }
            } catch {}
          }

          if (-not $isRollbackComplete) {
            $unresolvedTxFound = $true
            if (Test-Path -LiteralPath $matchingJournal) {
              try {
                $jRaw = [System.IO.File]::ReadAllText($matchingJournal, [System.Text.Encoding]::UTF8)
                $jObj = ConvertFrom-Json $jRaw
                if (Test-JournalStructureValid $jObj $curTxId) {
                  $jEntries = Get-JournalEntriesArray $jObj
                  $compCount = @($jEntries | Where-Object { (Get-JournalPropSafe $_ 'State') -eq 'COMPLETED' }).Count
                  $pendCount = @($jEntries | Where-Object { (Get-JournalPropSafe $_ 'State') -eq 'PENDING' }).Count
                  $rbCount = @($jEntries | Where-Object { (Get-JournalPropSafe $_ 'State') -eq 'ROLLED_BACK' }).Count
                  $unresolvedTxDiag = "txId: $curTxId, entries: $($jEntries.Count), completed: $compCount, pending: $pendCount, rolledBack: $rbCount, rollbackStatus: $(Get-JournalPropSafe $jObj 'rollbackStatus')"
                }
              } catch {}
            }
            break
          }
        }
      }
    }
    if ($unresolvedTxFound) {
      $msg = if ($null -ne $unresolvedTxDiag) { "未解決のトランザクションインプログレスマーカーが存在します ($unresolvedTxDiag)。" } else { "未解決のトランザクションインプログレスマーカーが存在します。" }
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_RECOVERY_REQUIRED" $msg)
      return
    }

    $topo = Get-CustomerMergeTopology $vaultRoot $uuid $nameRaw
    if ($null -ne $topo.Error) {
      Write-Output (New-MergeResponse $reqId "NG" $topo.Error $topo.Details)
      return
    }

    if ($topo.MatchedFolders.Count -eq 1) {
      Write-Output (New-MergeResponse $reqId "OK" "MERGE_NOT_REQUIRED" "マージ対象フォルダが1件のみのため、統合は不要です。" -Extra @{ matchedFolderCount = 1 })
      return
    }

    $canonicalState = Resolve-CanonicalDestinationState $topo
    if ($canonicalState -eq "UNOWNED_DIRECTORY") {
      Write-Output (New-MergeResponse $reqId "NG" "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "canonicalフォルダ '$($topo.CanonicalFolderName)' が存在しますが、対象UUIDの証拠を持たないため統合を実行できません。")
      return
    }
    elseif ($canonicalState -eq "NON_DIRECTORY_OCCUPANT") {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_CANONICAL_PATH_OCCUPIED" "canonicalパスに通常ファイルが存在するため、統合を実行できません。")
      return
    }
    elseif ($canonicalState -eq "INSPECTION_FAILED") {
      Write-Output (New-MergeResponse $reqId "NG" "MERGE_TOPOLOGY_ENUMERATION_FAILED" "canonicalパスの検査に失敗しました。")
      return
    }

    $allManagedNotes = @()
    $globalNoteTypes = New-Object System.Collections.Generic.HashSet[string]
    $allSourceFolderNames = @()

    foreach ($f in $topo.MatchedFolders) {
      $allSourceFolderNames += $f.FolderName
      foreach ($n in $f.ManagedNotes) {
        if ($globalNoteTypes.Contains($n.NoteType)) {
          Write-Output (New-MergeResponse $reqId "NG" "NOTE_TYPE_COLLISION" "複数フォルダ間で同一noteType '$($n.NoteType)' が衝突しています。")
          return
        }
        [void]$globalNoteTypes.Add($n.NoteType)
        $allManagedNotes += $n
      }
    }

    $liveToken = New-MergePlanTokenV3 $vaultRoot $uuid $topo.CanonicalFolderName $allSourceFolderNames $allManagedNotes
    if ($reqToken -ne $liveToken) {
      Write-Output (New-MergeResponse $reqId "NG" "PLAN_TOKEN_MISMATCH" "フォルダ構成またはノート構成がプラン作成時から変更されています。")
      return
    }

    # J-2 Step 11: Live target occupancy preflight inspection
    foreach ($n in $allManagedNotes) {
      $targetPath = Join-Path $topo.CanonicalFolderFullPath $n.FileName
      $occState = Resolve-MergeTargetOccupancyState -TargetPath $targetPath -SourcePath $n.FullPath
      if ($occState -eq "OCCUPIED") {
        Write-Output (New-MergeResponse $reqId "NG" "MERGE_TARGET_FILE_EXISTS" "マージ先に同名ファイルまたはオブジェクトが既に存在します: $targetPath")
        return
      }
      elseif ($occState -eq "INSPECTION_FAILED") {
        Write-Output (New-MergeResponse $reqId "NG" "MERGE_OPERATION_FAILED" "マージ先パスの検査に失敗しました: $targetPath")
        return
      }
    }

    $inProgressData = @{
      txId = $txId
      planToken = $liveToken
      uuid = $uuid
      canonicalFolderName = $topo.CanonicalFolderName
      sourceFolders = $allSourceFolderNames
      managedFiles = $allManagedNotes
      timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    $inProgressFile = Write-TransactionEvidenceSafe $txDir $txId "inprogress" $inProgressData

    $stagingInfo = New-MergeStagingOwnershipSafe $txDir $txId
    $stagingDir = $stagingInfo.StagingDir
    $ownerToken = $stagingInfo.OwnerToken

    $journalData = [ordered]@{
      txId = $txId
      uuid = $uuid
      vaultRoot = $vaultRoot
      canonicalFolderName = $topo.CanonicalFolderName
      ownerToken = $ownerToken
      rollbackStatus = "NONE"
      entries = @()
    }
    $journalFile = Write-JournalEvidenceSafe $txDir $txId $journalData
    $seq = 1

    # B-4 & B-3 Mutation Phase 1: source -> staging
    foreach ($n in $allManagedNotes) {
      $srcPath = $n.FullPath
      $dstPath = Join-Path $stagingDir $n.FileName

      # B-3: Staging conflict must enter failure/rollback path
      if (Test-Path -LiteralPath $dstPath) {
        throw "ステージングに同名ファイルが既に存在します: $dstPath"
      }

      $journalEntry = [ordered]@{
        Seq = $seq++
        OpType = "MOVE_FILE"
        SourcePath = $srcPath
        DestPath = $dstPath
        ExpectedSha256 = $n.Sha256
        ExpectedSizeBytes = $n.SizeBytes
        OwnerToken = $null
        State = "PENDING"
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
      }
      $journalData.entries = @($journalData.entries) + $journalEntry
      [void](Write-JournalEvidenceSafe $txDir $txId $journalData)

      Invoke-TestCrashHook "D"

      [System.IO.File]::Move($srcPath, $dstPath)

      $postSha = Get-FileSha256Raw $dstPath
      $postSize = (Get-Item -LiteralPath $dstPath).Length
      if ($postSha -ne $n.Sha256 -or $postSize -ne $n.SizeBytes) {
        throw "ファイル移動後のバイト検証に失敗しました: $dstPath"
      }

      Invoke-TestCrashHook "E"

      $journalEntry.State = "COMPLETED"
      [void](Write-JournalEvidenceSafe $txDir $txId $journalData)
    }

    # B-4 Mutation Phase 2
    $targetCanonicalDir = $topo.CanonicalFolderFullPath
    if ($canonicalState -eq "MATCHED_EXISTING") {
      # Case A: Move individual files to canonical
      foreach ($n in $allManagedNotes) {
        $stagedFile = Join-Path $stagingDir $n.FileName
        $finalFile = Join-Path $targetCanonicalDir $n.FileName
        if (Test-Path -LiteralPath $finalFile) {
          throw "最終Canonicalフォルダに同名ファイルが既に存在します: $finalFile"
        }
        $journalEntry = [ordered]@{
          Seq = $seq++
          OpType = "MOVE_FILE_STAGING_TO_CANONICAL"
          SourcePath = $stagedFile
          DestPath = $finalFile
          ExpectedSha256 = $n.Sha256
          ExpectedSizeBytes = $n.SizeBytes
          OwnerToken = $null
          State = "PENDING"
          Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        $journalData.entries = @($journalData.entries) + $journalEntry
        [void](Write-JournalEvidenceSafe $txDir $txId $journalData)

        Invoke-TestCrashHook "D"

        [System.IO.File]::Move($stagedFile, $finalFile)

        $postSha = Get-FileSha256Raw $finalFile
        $postSize = (Get-Item -LiteralPath $finalFile).Length
        if ($postSha -ne $n.Sha256 -or $postSize -ne $n.SizeBytes) {
          throw "最終Canonical移動後のバイト検証に失敗しました: $finalFile"
        }

        Invoke-TestCrashHook "E"

        $journalEntry.State = "COMPLETED"
        [void](Write-JournalEvidenceSafe $txDir $txId $journalData)
      }

      $finalOwnerMarker = Join-Path $targetCanonicalDir ".fm-obsidian-merge-owner"
      $markerSha = Get-FileSha256Raw $stagingInfo.OwnerMarkerPath
      $markerSize = (Get-Item -LiteralPath $stagingInfo.OwnerMarkerPath).Length
      $journalEntryMarker = [ordered]@{
        Seq = $seq++
        OpType = "MOVE_OWNERSHIP_MARKER"
        SourcePath = $stagingInfo.OwnerMarkerPath
        DestPath = $finalOwnerMarker
        ExpectedSha256 = $markerSha
        ExpectedSizeBytes = $markerSize
        OwnerToken = $ownerToken
        State = "PENDING"
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
      }
      $journalData.entries = @($journalData.entries) + $journalEntryMarker
      [void](Write-JournalEvidenceSafe $txDir $txId $journalData)

      Invoke-TestCrashHook "D"

      [System.IO.File]::Move($stagingInfo.OwnerMarkerPath, $finalOwnerMarker)

      if (-not (Test-Path -LiteralPath $finalOwnerMarker -PathType Leaf) -or (Test-Path -LiteralPath $stagingInfo.OwnerMarkerPath)) {
        throw "所有権マーカーの移動後検証に失敗しました: $finalOwnerMarker"
      }
      $postMarkerSha = Get-FileSha256Raw $finalOwnerMarker
      $postMarkerSize = (Get-Item -LiteralPath $finalOwnerMarker).Length
      $postMarkerToken = (Get-Content -LiteralPath $finalOwnerMarker -Raw -Encoding UTF8).Trim()
      if ($postMarkerSha -ne $markerSha -or $postMarkerSize -ne $markerSize -or $postMarkerToken -ne $ownerToken) {
        throw "最終所有権マーカーのバイト/トークン検証に失敗しました: $finalOwnerMarker"
      }

      Invoke-TestCrashHook "E"

      $journalEntryMarker.State = "COMPLETED"
      [void](Write-JournalEvidenceSafe $txDir $txId $journalData)

      # Verify staging directory is empty and transaction-owned before removal
      $remainingStaged = @(Get-ChildItem -LiteralPath $stagingDir -Force -ErrorAction Stop)
      if ($remainingStaged.Count -gt 0) {
        throw "ステージングディレクトリに未処理のファイルが存在するため削除できません: $stagingDir"
      }
      [System.IO.Directory]::Delete($stagingDir, $false)
    } else {
      # Case B: Directory move
      $finalOwnerMarker = Join-Path $targetCanonicalDir ".fm-obsidian-merge-owner"
      $journalEntryDir = [ordered]@{
        Seq = $seq++
        OpType = "MOVE_DIRECTORY"
        SourcePath = $stagingDir
        DestPath = $targetCanonicalDir
        ExpectedSha256 = $null
        ExpectedSizeBytes = $null
        OwnerToken = $ownerToken
        State = "PENDING"
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
      }
      $journalData.entries = @($journalData.entries) + $journalEntryDir
      [void](Write-JournalEvidenceSafe $txDir $txId $journalData)

      Invoke-TestCrashHook "D"

      [System.IO.Directory]::Move($stagingDir, $targetCanonicalDir)

      if (-not (Test-Path -LiteralPath $targetCanonicalDir -PathType Container) -or (Test-Path -LiteralPath $stagingDir)) {
        throw "ディレクトリ移動後の存在検証に失敗しました: $targetCanonicalDir"
      }
      if (-not (Test-Path -LiteralPath $finalOwnerMarker -PathType Leaf)) {
        throw "最終Canonicalフォルダに所有権マーカーが見つかりません: $finalOwnerMarker"
      }
      $readFinalToken = (Get-Content -LiteralPath $finalOwnerMarker -Raw -Encoding UTF8).Trim()
      if ($readFinalToken -ne $ownerToken) {
        throw "最終Canonicalフォルダの所有権トークンが不一致です。"
      }

      Invoke-TestCrashHook "E"

      $journalEntryDir.State = "COMPLETED"
      [void](Write-JournalEvidenceSafe $txDir $txId $journalData)
    }

    if (-not (Test-Path -LiteralPath $finalOwnerMarker)) {
      throw "最終Canonicalフォルダに所有権マーカーが見つかりません: $finalOwnerMarker"
    }
    $readFinalToken = [System.IO.File]::ReadAllText($finalOwnerMarker, [System.Text.Encoding]::UTF8).Trim()
    if ($readFinalToken -ne $stagingInfo.OwnerToken) {
      throw "最終Canonicalフォルダの所有権トークンが不一致です。"
    }

    $finalTopo = Get-CustomerMergeTopology $vaultRoot $uuid $nameRaw
    if ($null -ne $finalTopo.Error) {
      throw "マージ後のトポロジ検証でエラーが発生しました ($($finalTopo.Error)): $($finalTopo.Details)"
    }
    if ($finalTopo.MatchedFolders.Count -ne 1 -or $finalTopo.MatchedFolders[0].FolderName -ne $topo.CanonicalFolderName) {
      throw "マージ後のトポロジ検証に失敗しました: フォルダが単一Canonicalに集約されていません。"
    }
    if ($finalTopo.MatchedFolders[0].ManagedNotes.Count -ne $allManagedNotes.Count) {
      throw "マージ後の管理ノート総数が一致しません。"
    }

    $committedData = @{
      txId = $txId
      planToken = $liveToken
      uuid = $uuid
      canonicalFolderName = $topo.CanonicalFolderName
      mergedNotesCount = $allManagedNotes.Count
      committedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    $committedFile = Write-TransactionEvidenceSafe $txDir $txId "committed" $committedData
    $isCommitted = $true

    Invoke-TestCrashHook "G"

    $warning = $null

    try {
      if (Test-Path -LiteralPath $finalOwnerMarker) {
        Remove-Item -LiteralPath $finalOwnerMarker -Force -ErrorAction Stop
      }
    } catch {
      $warning = "OWNERSHIP_MARKER_CLEANUP_PENDING"
    }

    if ($null -eq $warning) {
      try {
        # Safe cleanup order: journal -> inprogress -> committed
        if (Test-Path -LiteralPath $journalFile) { Remove-Item -LiteralPath $journalFile -Force -ErrorAction Stop }
        if (Test-Path -LiteralPath $inProgressFile) { Remove-Item -LiteralPath $inProgressFile -Force -ErrorAction Stop }
        if (Test-Path -LiteralPath $committedFile) { Remove-Item -LiteralPath $committedFile -Force -ErrorAction Stop }
      } catch {
        $warning = "TRANSACTION_MARKER_CLEANUP_PENDING"
      }
    }

    $resp = New-MergeResponse $reqId "OK" "MERGE_COMPLETED" "顧客フォルダのマージに完了しました。" -extra @{
      canonicalFolderName = $topo.CanonicalFolderName
      mergedNotesCount = $allManagedNotes.Count
      sourceFoldersPreserved = $allSourceFolderNames
    }
    if ($null -ne $warning) {
      $resp = New-MergeResponse $reqId "OK" "MERGE_COMPLETED" "顧客フォルダのマージは完了しましたが、クリーンアップが一部遅延しました。" -warning $warning -extra @{
        canonicalFolderName = $topo.CanonicalFolderName
        mergedNotesCount = $allManagedNotes.Count
      }
    }
    Write-Output $resp
  } catch {
    $committedOnDisk = -not [string]::IsNullOrWhiteSpace($txDir) -and -not [string]::IsNullOrWhiteSpace($txId) -and (Test-Path -LiteralPath (Join-Path $txDir "$txId.committed.json"))
    if ($isCommitted -or $committedOnDisk) {
      # POST-COMMIT INTERLOCK: Destructive rollback is permanently forbidden after commit!
      $warnCode = if ($null -ne $warning) { $warning } else { "POST_COMMIT_CLEANUP_FAILED" }
      $resp = New-MergeResponse $reqId "OK" "MERGE_COMPLETED" "顧客フォルダのマージは完了しましたが、事後処理中に例外が発生しました ($($_.Exception.Message))。" -warning $warnCode -extra @{
        canonicalFolderName = if ($null -ne $topo) { $topo.CanonicalFolderName } else { $null }
        mergedNotesCount = if ($null -ne $allManagedNotes) { $allManagedNotes.Count } else { 0 }
      }
      Write-Output $resp
    } else {
      $rbRes = Invoke-OptionBRollback $journalData $txId $txDir
      if ($rbRes.Success) {
        # Crash Window H: ROLLBACK_COMPLETE persisted to journal, before best-effort cleanup
        Invoke-TestCrashHook "H"
        Complete-RollbackEvidenceCleanup $txId $txDir $journalData
        Write-Output (New-MergeResponse $reqId "NG" "MERGE_FAILED_ROLLED_BACK" "マージ中にエラーが発生したためロールバックしました: $($_.Exception.Message)")
      } else {
        Write-Output (New-MergeResponse $reqId "NG" "MERGE_ROLLBACK_FAILED" "マージ中にエラーが発生し、ロールバックも失敗しました(手動確認が必要です): $($_.Exception.Message) / $($rbRes.Details)")
      }
    }
  } finally {
    if ($null -ne $lock) {
      $lock.Close()
      $lock.Dispose()
    }
  }
}


function Invoke-OpenObsidianNotes($payload) {
  $rawVault = if ($payload.ContainsKey("VaultRoot")) { [string]$payload["VaultRoot"] } else { "" }
  $VaultRoot = $rawVault.Trim()
  if (-not (Test-Path -LiteralPath $VaultRoot)) { Out-NG "ERROR" "VaultRoot not found." }

  # Lock Acquisition Phase (NH-1, NM-1, NM-2)
  $txDir = Join-Path $VaultRoot ".fm-obsidian-bridge-transactions"
  if (-not (Test-Path -LiteralPath $txDir)) { [void][System.IO.Directory]::CreateDirectory($txDir) }

  $lock = $null
  try {
    $lock = [System.IO.FileStream]::new(
      (Join-Path $txDir "ACTIVE.lock"),
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  } catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    Out-NG "ERROR" "他の操作が実行中か、ロック取得に失敗しました ($errClass)。"
  }

  try {
  Assert-ObsidianReady

  $custRoot  = Join-Path $VaultRoot "01_顧客"
  $indexPath = Join-Path $VaultRoot "scripts\obsidian_index.json"
  if (-not (Test-Path -LiteralPath $custRoot)) { New-Item -ItemType Directory -Path $custRoot -Force | Out-Null }

  $index = Load-IndexSafe $indexPath

  $nameRaw  = if ($payload.ContainsKey("companyNameRaw")) { [string]$payload["companyNameRaw"] } else { "" }
  $rank     = if ($payload.ContainsKey("RANK")) { [string]$payload["RANK"] } else { "" }
  $ceo      = if ($payload.ContainsKey("CEO")) { [string]$payload["CEO"] } else { "" }
  $ruby     = if ($payload.ContainsKey("RUBY")) { [string]$payload["RUBY"] } else { "" }
  $uuid     = if ($payload.ContainsKey("pk_CLIENT")) { [string]$payload["pk_CLIENT"] } else { "" }

  # ---- 不正UUIDフォールバックの廃止 (2026-07-30) ----
  if (-not (Test-UciUuidFormat $uuid)) {
      Out-NG "INVALID_UUID_FORMAT" "pk_CLIENTがUUID形式ではありません。"
  }
  $noteType = if ($payload.ContainsKey("noteType")) { [string]$payload["noteType"] } else { "" }

  # ---- 名前正規化 ----
  $n = $nameRaw.Trim()
  if ($noteType -match "一覧") {
      $n = $n -replace "株式会社", "㈱" -replace "有限会社", "㈲"
      $n = $n -replace "（株）", "㈱" -replace "\(株\)", "㈱"
      $n = $n -replace "（有）", "㈲" -replace "\(有\)", "㈲"
  } else {
      $remove = @("株式会社","有限会社","合同会社","合名会社","合資会社","（株）","(株)","㈱","有限","（有）","(有)","㈲")
      foreach ($r in $remove) { $n = $n -replace [regex]::Escape($r), "" }
  }
  $nameNorm = Sanitize-LeafName $n "NO_NAME"

  # アイコンとファイル名決定
  $prefixStr = Get-IconPrefix $noteType

  # ---- v9.0.0: canonical命名の一元化 ----
  # 顧客フォルダ名・新規ノート名はここで確定したcanonical値以外を使用しない。
  $canonicalFolderName = Get-CanonicalCustomerFolderName $nameRaw $uuid

  # ---- Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護 ----
  $matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
  if ($matchedFoldersList.Count -ge 2) {
    Out-NG "UUID_FOLDER_CONFLICT" "同一のpk_CLIENT UUID ($uuid) を持つ顧客フォルダが複数存在します。マージ処理が必要です。(Count: $($matchedFoldersList.Count))"
  }

  # ---- Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護 ----
  $matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
  if ($matchedFoldersList.Count -ge 2) {
    Out-NG "UUID_FOLDER_CONFLICT" "同一のpk_CLIENT UUID ($uuid) を持つ顧客フォルダが複数存在します。マージ処理が必要です。(Count: $($matchedFoldersList.Count))"
  }
  $canonicalFile = "${prefixStr}_${nameNorm}$(Get-UciUuidSuffix $uuid).md"

  # ★ v9.0.2 (FIX-1): $targetAbs と 新規CREATE候補path を完全に分離する。
  #   $targetAbs        ... UUID検証済みの既存managed noteだけを設定してよい変数。
  #                         これが非nullのときのみUpdate-Yaml-Robustによる既存note更新を行う。
  #   $newCandidateAbs  ... 新規CREATE候補path(まだ採用が確定していない予定パス)。
  #                         実在していても既存managed noteとしては絶対に採用しない。
  #   $fuzzyCandidates  ... UUID未検証のファイル名類似候補(診断保持のみ。出力は行わない)。
  $targetAbs = $null
  $newCandidateAbs = $null
  $fuzzyCandidates = @()
  $foundFolder = $null

  # ========================================================
  # v9.0.0 Step A: obs_RELPATH を「note locator hint」として検証・保持する。
  # ここでは採用を確定しない(customer folder identity解決を必ず別途実行するため)。
  # 検証内容は従来通り弱体化させない:
  #   相対パス / ".."を含まない / 01_顧客配下 / Vault外へ出ない / 3セグメント /
  #   実在ファイル / YAML完全UUID一致 / noteType接頭辞一致 / customer folderとして解決可能
  # ========================================================
  $hintNoteAbs = $null
  $hintFolderInfo = $null
  $hintFileName = $null

  if (
      $payload.ContainsKey("obs_RELPATH") -and
      -not [string]::IsNullOrWhiteSpace([string]$payload.obs_RELPATH)
  ) {
      $storedRel = ([string]$payload.obs_RELPATH).Trim()
      $storedRelNormalized = $storedRel.Replace("/", [string][char]92)

      # 絶対パス、親ディレクトリ参照、01_顧客以外を拒否する。
      $storedSegments = @($storedRelNormalized -split '\\')
      $storedPathShapeValid = (
          -not [System.IO.Path]::IsPathRooted($storedRelNormalized) -and
          $storedRelNormalized -notmatch '(^|\\)\.\.(\\|$)' -and
          $storedSegments.Count -eq 3 -and
          $storedSegments[0] -eq "01_顧客" -and
          -not [string]::IsNullOrWhiteSpace($storedSegments[1]) -and
          -not [string]::IsNullOrWhiteSpace($storedSegments[2])
      )

      if ($storedPathShapeValid) {
          $storedAbs = [System.IO.Path]::GetFullPath((Join-Path $VaultRoot $storedRelNormalized))
          $custRootFull = [System.IO.Path]::GetFullPath($custRoot).TrimEnd([char]92) + [char]92

          # GetFullPath後も01_顧客配下に留まることを確認する。
          if ($storedAbs.StartsWith($custRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
              if (Test-Path -LiteralPath $storedAbs -PathType Leaf) {
                  $storedFile = Get-Item -LiteralPath $storedAbs
                  $storedFolderInfo = Resolve-UciDirectChildFolder `
                      ([System.IO.DirectoryInfo]::new($custRoot)) `
                      $storedFile.FullName

                  if ($null -ne $storedFolderInfo) {
                      # customer folder直下のノートであること(managed note scope)を確認する。
                      $storedIsDirectChild = [string]::Equals(
                          (Split-Path -Parent $storedFile.FullName),
                          $storedFolderInfo.FullName,
                          [System.StringComparison]::OrdinalIgnoreCase
                      )
                      $storedHeader = Get-YamlHeaderLines $storedFile.FullName
                      if ($null -ne $storedHeader -and $storedIsDirectChild) {
                          $storedUuid = Get-YamlScalarValue $storedHeader "UUID:"
                          $storedPrefixMatches = $storedFile.Name.StartsWith(
                              "${prefixStr}_",
                              [System.StringComparison]::Ordinal
                          )

                          if (
                              -not [string]::IsNullOrWhiteSpace($storedUuid) -and
                              (Test-UciUuidFormat $storedUuid) -and
                              $storedUuid.Trim().ToUpperInvariant() -eq $uuid.Trim().ToUpperInvariant() -and
                              $storedPrefixMatches
                          ) {
                              # note候補としてのみ保持する(folder identity authorityにはしない)。
                              $hintNoteAbs = $storedFile.FullName
                              $hintFolderInfo = $storedFolderInfo
                              $hintFileName = $storedFile.Name
                          }
                      }
                  }
              }
          }
      }
  }

  # ========================================================
  # v9.0.0 Step B: 完全UUIDによる customer folder identity discovery
  # 01_顧客配下を再帰検索し、YAML frontmatterの完全UUID一致ノートが属する
  # 01_顧客直下のcustomer folderを特定する。
  # ========================================================
  $identityInfo = Get-UciUuidMatchedCustomerFolders $custRoot $uuid
  if ($null -ne $identityInfo.unresolved) {
      Out-NG "ERROR" "UUID一致ノートが01_顧客直下のフォルダ構造として解決できません。(Path: $($identityInfo.unresolved))"
  }
  $identityFolders = @($identityInfo.folders)

  if ($identityFolders.Count -ge 2) {
      $names = ($identityFolders | ForEach-Object { $_.Name }) -join ";"
      Out-NG "UUID_FOLDER_CONFLICT" "同一UUIDのノートが複数の顧客フォルダにまたがっています。安全のため処理を中止します。(pk_CLIENT: $uuid / Folders: $names)"
  }

  $resolvedFolderInfo = $null
  if ($identityFolders.Count -eq 1) {
      $resolvedFolderInfo = $identityFolders[0]
  }

  # ========================================================
  # v9.0.0 Step C: identityで確定したフォルダのevidence評価 → canonical昇格
  # ========================================================
  if ($null -ne $resolvedFolderInfo) {
      $evidence = Get-UciFolderEvidence $resolvedFolderInfo.FullName $uuid
      switch ($evidence.state) {
          "InvalidYaml" {
              Out-NG "YAML_BODY_BOUNDARY_UNRESOLVED" "対象フォルダ内にYAML本文境界が判定できないノートがあります。本文喪失のおそれがあるため処理を中止しました。(Path: $($evidence.detailPath))"
          }
          "Conflict" {
              Out-NG "FOLDER_UUID_MIXED" "対象フォルダ内に別UUIDのノートが混在しています。安全のため処理を中止します。(Path: $($evidence.detailPath) / UUID: $($evidence.detailValue))"
          }
          "InvalidUuid" {
              Out-NG "FOLDER_UUID_INVALID" "対象フォルダ内にUUID形式が不正なノートが残存しています。安全のため処理を中止します。(Path: $($evidence.detailPath) / Value: $($evidence.detailValue))"
          }
          "NoEvidence" {
              Out-NG "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "対象フォルダの完全UUID証拠を再確認できませんでした。安全のため処理を中止します。(Folder: $($resolvedFolderInfo.Name) / pk_CLIENT: $uuid)"
          }
      }

      # legacy(UUIDなし等) → canonicalへ昇格。別canonicalフォルダの新規作成は行わない。
      if ($resolvedFolderInfo.Name -ne $canonicalFolderName) {
          $canonicalDest = Join-Path $custRoot $canonicalFolderName
          if (Test-Path -LiteralPath $canonicalDest) {
              Out-NG "TARGET_FOLDER_ALREADY_EXISTS" "canonical顧客フォルダ名と同名の別フォルダが既に存在するため、昇格できません。(Current: $($resolvedFolderInfo.Name) / Canonical: $canonicalFolderName)"
          }
          try {
              Rename-Item -LiteralPath $resolvedFolderInfo.FullName -NewName $canonicalFolderName -Force -ErrorAction Stop
          } catch {
              Out-NG "FOLDER_RENAME_FAILED" "顧客フォルダをcanonical名へ変更できませんでした: $($_.Exception.Message)"
          }
          $resolvedFolderInfo = Get-Item -LiteralPath (Join-Path $custRoot $canonicalFolderName)
      }

      $foundFolder = $resolvedFolderInfo.Name
      $currentFolderFull = $resolvedFolderInfo.FullName

      # ================================================================
      # ★ v9.0.1 (MAJOR-1) / v9.0.2 (FIX-1): 正式managed noteの解決
      #
      # 正式既存noteとして$targetAbsに設定できるのは、次の3条件をすべて満たすファイルだけである。
      #   (1) customer folder直下(direct-child)にあること
      #   (2) 対象noteTypeのアイコン接頭辞と一致するファイル名であること
      #   (3) YAML frontmatterの完全UUIDがpk_CLIENTと一致すること
      # これらは Get-UuidNoteTypeMatches が一括で判定する(唯一のauthority)。
      #
      # v9.0.1では direct-child UUID一致0件のときに
      #     $targetAbs = Join-Path $currentFolderFull $canonicalFile
      # としていたため、canonicalFileと同名の既存ファイルが存在し、そのYAML UUIDが
      # pk_CLIENTと一致しない(あるいはUUIDキー自体が無い)場合でも、後続の
      #     if ($targetAbs -and (Test-Path -LiteralPath $targetAbs))
      # へ流れて既存managed noteとして採用され、Update-Yaml-RobustでUUIDを
      # 書き込んでしまう抜け道が残っていた。
      #
      # v9.0.2では direct-child UUID一致が0件の場合、$targetAbsは$nullのままとし、
      # 新規CREATE候補pathは別変数$newCandidateAbsへ格納する。
      # $newCandidateAbsが実在する場合でも既存managed noteとしては採用せず、
      # 後段のCREATE直前チェックでTARGET_NOTE_FILENAME_CONFLICTとしてFail-closedする。
      #
      # サブフォルダ側に同一UUID+同一noteTypeのnoteがある場合は
      # MANAGED_NOTE_OUT_OF_SCOPE で安全停止する。
      # ================================================================
      $unscopedNotes = @(Get-UciOutOfScopeManagedNotes $currentFolderFull $prefixStr $uuid)
      $uciMatches = @(Get-UuidNoteTypeMatches $currentFolderFull $prefixStr $uuid)

      if ($uciMatches.Count -ge 2) {
          Out-NG "DUPLICATE_NOTE_TYPE" "同一UUID・同一noteTypeの既存ノートが顧客フォルダ直下に複数見つかりました。安全のため処理を中止します。(Folder: $foundFolder / noteType: $noteType / 件数: $($uciMatches.Count))"
      }
      if ($unscopedNotes.Count -ge 1) {
          Out-NG "MANAGED_NOTE_OUT_OF_SCOPE" "管理対象ノートと同一UUID・同一noteTypeのノートが顧客フォルダのサブフォルダ内に存在します。自動採用・自動作成は行わず処理を中止します。(Folder: $foundFolder / noteType: $noteType / Path: $($unscopedNotes[0]))"
      }

      if ($uciMatches.Count -eq 1) {
          # 正式managed note(direct-child + noteType一致 + 完全UUID一致)のみ採用する。
          $targetAbs = $uciMatches[0]
          $canonicalFile = Split-Path -Leaf $targetAbs
      } else {
          # ---- direct-child UUID一致 0件 ----
          # ★ v9.0.2 (FIX-1): $targetAbsは$nullのまま維持する(既存note採用は行わない)。
          # 新規CREATE候補pathのみを別変数へ保持する。
          # ★ v9.0.2 (FIX-2): fuzzy候補は内部変数へ保持するだけで、Write-Host等の
          #   追加診断出力は一切行わない(FileMaker応答契約へ新規出力を混在させない)。
          $fuzzyCandidates = @(Get-UciFuzzyNameCandidates $currentFolderFull $prefixStr)
          $newCandidateAbs = Join-Path $currentFolderFull $canonicalFile
      }

      # ---- v9.0.0: obs_RELPATH候補を最終フォルダ上で再検証して採用 ----
      # hintのフォルダとidentity確定フォルダが矛盾する場合はFail-closed。
      if ($null -ne $hintNoteAbs) {
          $hintFinalAbs = Join-Path $currentFolderFull $hintFileName
          $hintFolderConsistent = $false
          if ($null -ne $hintFolderInfo) {
              # 昇格Rename後は元パスが存在しないため、Rename前のフォルダ名/昇格後の名前いずれかと一致すればよい。
              if ([string]::Equals($hintFolderInfo.FullName, $currentFolderFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                  $hintFolderConsistent = $true
              } elseif (-not (Test-Path -LiteralPath $hintFolderInfo.FullName)) {
                  # 元フォルダが消えている = canonicalへRenameされた可能性。最終フォルダ上での実在で確認する。
                  if (Test-Path -LiteralPath $hintFinalAbs -PathType Leaf) { $hintFolderConsistent = $true }
              }
          }
          if (-not $hintFolderConsistent) {
              Out-NG "RELPATH_FOLDER_MISMATCH" "obs_RELPATHが示す顧客フォルダと、完全UUIDで確定した顧客フォルダが一致しません。安全のため処理を中止します。(Hint: $($hintFolderInfo.Name) / Resolved: $foundFolder)"
          }
          if (Test-Path -LiteralPath $hintFinalAbs -PathType Leaf) {
              $hintHdrFinal = Get-YamlHeaderLines $hintFinalAbs
              if ($null -ne $hintHdrFinal) {
                  $hintUuidFinal = Get-YamlScalarValue $hintHdrFinal "UUID:"
                  if (
                      -not [string]::IsNullOrWhiteSpace($hintUuidFinal) -and
                      (Test-UciUuidFormat $hintUuidFinal) -and
                      $hintUuidFinal.Trim().ToUpperInvariant() -eq $uuid.Trim().ToUpperInvariant() -and
                      $hintFileName.StartsWith("${prefixStr}_", [System.StringComparison]::Ordinal)
                  ) {
                      # hintも「direct-child + noteType一致 + 完全UUID一致」を満たす場合のみ採用する。
                      # (UUID検証済みであるため$targetAbsへの設定は正式ルールに適合する)
                      $targetAbs = $hintFinalAbs
                      $canonicalFile = $hintFileName
                      $newCandidateAbs = $null
                  }
              }
          }
      }

      # folderNameConfirmedはgo-aheadに過ぎない。canonical folderを別名へ降格しない。
      # 既にcanonical名へ昇格済みのため、ここでのRenameは行わない。
  } else {
      # identity未確定(完全UUID証拠なし)。
      # obs_RELPATHでnoteが見つかっていた場合でも、identityが確定しないままの採用は行わない。
      if ($null -ne $hintNoteAbs) {
          Out-NG "RELPATH_FOLDER_MISMATCH" "obs_RELPATHのノートは見つかりましたが、完全UUIDによる顧客フォルダ確定ができませんでした。安全のため処理を中止します。(Hint: $hintNoteAbs / pk_CLIENT: $uuid)"
      }

      # legacy顧客名一致フォルダの状態を確認する(自動作成の前に必ず判定する)。
      $folders = Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue
      $matchName = Normalize-ForMatch $nameRaw
      $legacyCandidates = @($folders | Where-Object {
          $_.Name -ne $canonicalFolderName -and (Normalize-ForMatch $_.Name) -eq $matchName
      })
      if ($legacyCandidates.Count -ge 1) {
          # 完全UUID証拠が無いlegacyフォルダ。別canonicalフォルダを勝手に作らずFail-closed。
          $legacyNames = ($legacyCandidates | ForEach-Object { $_.Name }) -join ";"
          Out-NG "LEGACY_FOLDER_NEEDS_MIGRATION" "顧客名が一致するフォルダが存在しますが、pk_CLIENTの完全UUID証拠がないため同一顧客と確定できません。手動確認が必要です。(Folders: $legacyNames / pk_CLIENT: $uuid)"
      }

      # canonical名フォルダが既に存在するのに完全UUID証拠が無い場合(UUID8衝突等)も自動採用しない。
      $canonicalExisting = @($folders | Where-Object { $_.Name -eq $canonicalFolderName })
      if ($canonicalExisting.Count -ge 1) {
          Out-NG "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "canonical名の顧客フォルダは存在しますが、pk_CLIENTの完全UUID証拠がありません。UUID先頭8文字の衝突の可能性があるため処理を中止します。(Folder: $canonicalFolderName / pk_CLIENT: $uuid)"
      }
  }

  # ▼▼▼ COMPARE モード (突合結果を開く) ▼▼▼
  # ▲▲▲ COMPARE モード 終了 ▲▲▲

  # ▼▼▼ 通常モード（引数に応じて一覧ファイルを開く／なければ作成） ▼▼▼

  # 1. 既存ノートあり（開いて終わる）
  # ★ v9.0.2 (FIX-1): ここへ到達する$targetAbsは、必ず
  #   「direct-child + noteType接頭辞一致 + 完全UUID一致」でUUID検証済みのファイルのみである。
  #   UUID未検証のcanonicalFile同名ファイルやfuzzy候補は$targetAbsへ入らないため、
  #   それらへUpdate-Yaml-Robustが実行されることはない。
  if ($targetAbs -and (Test-Path -LiteralPath $targetAbs)) {
    $totalVal = $null
    if ($noteType -eq "契約一覧") {
        $totalVal = Extract-TableTotal $targetAbs
        if ([string]::IsNullOrWhiteSpace($totalVal)) { $totalVal = "" }
    }

    Update-Yaml-Robust $targetAbs $rank $nameRaw $ceo $ruby $uuid $totalVal

    $rel = Get-RelPath $VaultRoot $targetAbs
    $lw  = (Get-Item -LiteralPath $targetAbs).LastWriteTime

    $index[$payload.pk_CLIENT] = @{ relpath=$rel; lastWrite=$lw.ToString("yyyy-MM-ddTHH:mm:ss"); noteType=[string]$payload.noteType; nameNorm=$nameNorm; folderName=$foundFolder }
    [System.IO.File]::WriteAllText($indexPath, ($index | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

    # 標準URIスキームでファイルを開く
    Open-ObsidianFile $VaultRoot $rel

    # FileMaker返却用URI
    $url = Get-ObsidianOpenUrl $VaultRoot $rel

    Out-OK "OPENED" $url $rel ($lw.ToString("yyyy-MM-ddTHH:mm:ss")) "e30="
  }

  # ---- v9.0.0/v9.0.1/v9.0.2: 新規作成へ入る前の最終防衛線 ----
  # customer folderが確定している場合は、その直下のみを主判定にして再確認する
  # (再帰検索の結果で正式ノートを自動採用してはならない)。
  # customer folderが未確定の場合は、01_顧客配下全体でscope外/他フォルダのノートを検出し、
  # 誤った新規作成を防ぐ。
  if ($null -ne $resolvedFolderInfo) {
    $finalDirect = @(Get-UuidNoteTypeMatches $resolvedFolderInfo.FullName $prefixStr $uuid)
    if ($finalDirect.Count -ge 2) {
      Out-NG "DUPLICATE_NOTE_TYPE" "同一UUID・同一noteTypeの既存ノートが顧客フォルダ直下に複数見つかりました。安全のため新規作成を中止します。(pk_CLIENT: $uuid / noteType: $noteType / 件数: $($finalDirect.Count))"
    }
    $finalOutOfScope = @(Get-UciOutOfScopeManagedNotes $resolvedFolderInfo.FullName $prefixStr $uuid)
    if ($finalOutOfScope.Count -ge 1) {
      Out-NG "MANAGED_NOTE_OUT_OF_SCOPE" "管理対象ノートと同一UUID・同一noteTypeのノートがサブフォルダ内に存在します。新規作成を中止します。(pk_CLIENT: $uuid / noteType: $noteType / Path: $($finalOutOfScope[0]))"
    }
    if ($finalDirect.Count -eq 1) {
      # 既存採用専用分岐: 内容・YAML・ファイル名・LastWriteTimeを一切変更しない。
      # (ここへ到達するのはUUID検証済みのdirect-child noteのみ)
      $adoptedAbs = [string]$finalDirect[0]
      $rel = Get-RelPath $VaultRoot $adoptedAbs
      $lw  = (Get-Item -LiteralPath $adoptedAbs).LastWriteTime
      $index[$payload.pk_CLIENT] = @{ relpath=$rel; lastWrite=$lw.ToString("yyyy-MM-ddTHH:mm:ss"); noteType=[string]$payload.noteType; nameNorm=$nameNorm; folderName=$resolvedFolderInfo.Name }
      [System.IO.File]::WriteAllText($indexPath, ($index | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
      Open-ObsidianFile $VaultRoot $rel
      $url = Get-ObsidianOpenUrl $VaultRoot $rel
      Out-OK "OPENED" $url $rel ($lw.ToString("yyyy-MM-ddTHH:mm:ss")) "e30="
    }
  } else {
    $treeMatches = @(Get-UuidNoteTypeMatchesInTree $custRoot $prefixStr $uuid)
    if ($treeMatches.Count -ge 1) {
      Out-NG "UUID_FOLDER_CONFLICT" "顧客フォルダを確定できないまま、同一UUID・同一noteTypeの既存ノートが検出されました。安全のため新規作成を中止します。(pk_CLIENT: $uuid / noteType: $noteType / Path: $($treeMatches[0]))"
    }
  }

  # 新規作成時のファイル名は必ずUUID識別子付きcanonical名にする。
  $canonicalFile = "${prefixStr}_${nameNorm}$(Get-UciUuidSuffix $uuid).md"

  # 2. フォルダ未確定時の確認
  # ※ suggestは必ずcanonicalFolderName。folderNameConfirmedは「新規作成継続のgo-ahead」としてのみ扱う。
  #
  # ★ v9.0.3 (folderNameConfirmed契約不整合の修正):
  #   従来は「folderNameConfirmedが非空ならgo-ahead」としており、FileMaker側の
  #   $$obsFolderNameInput(編集可能フィールド)でオペレータがcanonical名以外
  #   (例: 部分一致で候補表示されたlegacyフォルダ名)を確定しても、その値を黙って捨てて
  #   canonical名で新規作成していた。これは「オペレータの選択を無言で無視する」挙動であり安全でない。
  #   本版では、folderNameConfirmedを引き続きnaming authorityにはしない(値からフォルダ名を作らない)が、
  #   go-aheadとして受け入れる前に、既存Sanitize-LeafNameを通した値がcanonicalFolderNameと
  #   OrdinalIgnoreCaseで一致することを必須化する。
  #   不一致の場合はFOLDER_CONFIRMATION_MISMATCHでFail-closedし、
  #   確認された名前のフォルダを既存採用しない・そこへ移動しない・canonicalフォルダも作らない・
  #   ノートも作らない(何も作成・変更せずに停止する)。
  $folderNameConfirmedRaw = ""
  $hasGoAhead = $false
  if (
      $payload.ContainsKey("folderNameConfirmed") -and
      -not [string]::IsNullOrWhiteSpace([string]$payload.folderNameConfirmed)
  ) {
    $folderNameConfirmedRaw = [string]$payload.folderNameConfirmed
    # 既存のSanitize-LeafNameのみを使用する(新しいSanitize関数は追加しない)。
    # 前後空白・全角空白・制御文字・禁止文字等は既存規則で正規化されるため、
    # T27のような入力揺れはcanonicalと一致すれば正常継続できる。
    $confirmedSafeName = Sanitize-LeafName $folderNameConfirmedRaw "NO_NAME"
    if (-not [string]::Equals(
            $confirmedSafeName,
            $canonicalFolderName,
            [System.StringComparison]::OrdinalIgnoreCase)) {
      Out-NG "FOLDER_CONFIRMATION_MISMATCH" "FileMakerで確認されたフォルダ名がcanonicalFolderNameと一致しないため、新規作成を中止しました。(Confirmed: $confirmedSafeName / Canonical: $canonicalFolderName)"
    }
    $hasGoAhead = $true
  }

  if ((-not $foundFolder) -and (-not $hasGoAhead)) {
    $folders = Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue
    $suggest = $canonicalFolderName
    $cands = $folders | Where-Object { (Normalize-ForMatch $_.Name) -like "*$nameNorm*" } | Select-Object -ExpandProperty Name
    Out-OKNeedFolder $cands $suggest $nameNorm $canonicalFile
  }

  # 3. 新規作成（フォルダ作成含む）
  # 作成先フォルダ名はcanonicalFolderName以外を認めない。
  if ($foundFolder) {
    $newDir = Join-Path $custRoot $foundFolder
    $actualCreateFolderName = $foundFolder
  } else {
    $actualCreateFolderName = $canonicalFolderName
    $newDir = Join-Path $custRoot $canonicalFolderName
  }

  # fail-closed再確認: 作成先フォルダ名がcanonical名(または既にUUID証拠で確定したcanonical昇格済み名)であること。
  if ($actualCreateFolderName -ne $canonicalFolderName) {
    Out-NG "CANONICAL_FOLDER_NAME_MISMATCH" "作成先フォルダ名がcanonical名と一致しません。安全のため処理を中止します。(Actual: $actualCreateFolderName / Canonical: $canonicalFolderName)"
  }

  if (-not (Test-Path -LiteralPath $newDir)) {
    [void][System.IO.Directory]::CreateDirectory($newDir)
  }
  $newDirInfo = Get-Item -LiteralPath $newDir
  $newDir = $newDirInfo.FullName
  $safeConfName = $newDirInfo.Name

  # ★ v9.0.2 (FIX-1): 新規CREATE候補pathを最終確定する。
  # 既に$newCandidateAbs(identity確定フォルダ上での候補path)がある場合はそれを優先し、
  # 無い場合(identity未確定→新規フォルダ作成経路)はここで組み立てる。
  # いずれの場合も、このpathに実在ファイルがあるときは既存managed noteとして採用せず、
  # TARGET_NOTE_FILENAME_CONFLICTでFail-closedする(既存ファイルへのUUID書込みによる
  # 「正規化」は絶対に行わない)。
  $newAbs = Join-Path $newDir $canonicalFile
  if ($null -ne $newCandidateAbs) {
    if (-not [string]::Equals($newCandidateAbs, $newAbs, [System.StringComparison]::OrdinalIgnoreCase)) {
      # identity確定フォルダとCREATE先フォルダが食い違う異常系。安全のため停止する。
      Out-NG "CANONICAL_FOLDER_NAME_MISMATCH" "新規作成候補パスが顧客フォルダ確定結果と一致しません。安全のため処理を中止します。(Candidate: $newCandidateAbs / Create: $newAbs)"
    }
  }
  if (Test-Path -LiteralPath $newAbs) {
    $fuzzyDetail = ""
    if ($fuzzyCandidates.Count -ge 1) { $fuzzyDetail = " / UUID未検証の同種ファイル名候補: " + (($fuzzyCandidates | Select-Object -First 5) -join ";") }
    Out-NG "TARGET_NOTE_FILENAME_CONFLICT" "作成予定のノートと同名のファイルが既に存在しますが、YAMLの完全UUIDがpk_CLIENTと一致しないため既存ノートとして採用できません。上書き・自動正規化は行わず処理を中止します。(Path: $newAbs / pk_CLIENT: $uuid / noteType: $noteType$fuzzyDetail)"
  }
  try {
    $fsNew = [System.IO.File]::Open(
        $newAbs,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    $fsNew.Close()
    $fsNew.Dispose()
  } catch {
    Out-NG "NOTE_CREATE_FAILED" "ノートの新規作成に失敗しました(既存ファイルとの競合の可能性): $($_.Exception.Message)"
  }

  $totalVal = $null
  if ($noteType -eq "契約一覧") { $totalVal = "" }

  Update-Yaml-Robust $newAbs $rank $nameRaw $ceo $ruby $uuid $totalVal

  # 新規作成時のテンプレート挿入処理
  if ($noteType -match "事故一覧") {
      $jikoTemplate = @"

---
## 🚨対応中

| 事故日 | 状態 | 証券番号 | ClaimNo | お問合せNo | 事故内容 |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## ✅完了

| 事故日 | 状態 | 証券番号 | ClaimNo | お問合せNo | 事故内容 |
| --- | --- | --- | --- | --- | --- |
| | | | | | |
"@
      [System.IO.File]::AppendAllText($newAbs, $jikoTemplate, [System.Text.UTF8Encoding]::new($false))
  } else {
      [System.IO.File]::AppendAllText($newAbs, "`n---`n## 履歴`nここから入力", [System.Text.UTF8Encoding]::new($false))
  }

  $rel = Get-RelPath $VaultRoot $newAbs

  $index[$payload.pk_CLIENT] = @{ relpath=$rel; lastWrite=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"); noteType=[string]$payload.noteType; nameNorm=$nameNorm; folderName=$safeConfName }
  [System.IO.File]::WriteAllText($indexPath, ($index | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

  # 標準URIスキームでファイルを開く
  Open-ObsidianFile $VaultRoot $rel

  # FileMaker返却用URI
  $url = Get-ObsidianOpenUrl $VaultRoot $rel

  Out-OK "CREATED" $url $rel ((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")) "e30="
  } finally {
    if ($null -ne $lock) {
      $lock.Close()
      $lock.Dispose()
    }
  }
}

function Invoke-CheckObsidianNotes($payload) {
  $rawVault = if ($payload.ContainsKey("VaultRoot")) { [string]$payload["VaultRoot"] } else { "" }
  $VaultRoot = $rawVault.Trim()
  if (-not (Test-Path -LiteralPath $VaultRoot)) { Out-NG "ERROR" "VaultRoot not found." }

  # Lock Acquisition Phase (NH-1, NM-1, NM-2)
  $txDir = Join-Path $VaultRoot ".fm-obsidian-bridge-transactions"
  if (-not (Test-Path -LiteralPath $txDir)) { [void][System.IO.Directory]::CreateDirectory($txDir) }

  $lock = $null
  try {
    $lock = [System.IO.FileStream]::new(
      (Join-Path $txDir "ACTIVE.lock"),
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  } catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    Out-NG "ERROR" "他の操作が実行中か、ロック取得に失敗しました ($errClass)。"
  }

  try {
  Assert-ObsidianReady

  $custRoot  = Join-Path $VaultRoot "01_顧客"
  $indexPath = Join-Path $VaultRoot "scripts\obsidian_index.json"
  if (-not (Test-Path -LiteralPath $custRoot)) { New-Item -ItemType Directory -Path $custRoot -Force | Out-Null }

  $index = Load-IndexSafe $indexPath

  $nameRaw  = if ($payload.ContainsKey("companyNameRaw")) { [string]$payload["companyNameRaw"] } else { "" }
  $rank     = if ($payload.ContainsKey("RANK")) { [string]$payload["RANK"] } else { "" }
  $ceo      = if ($payload.ContainsKey("CEO")) { [string]$payload["CEO"] } else { "" }
  $ruby     = if ($payload.ContainsKey("RUBY")) { [string]$payload["RUBY"] } else { "" }
  $uuid     = if ($payload.ContainsKey("pk_CLIENT")) { [string]$payload["pk_CLIENT"] } else { "" }

  # ---- 不正UUIDフォールバックの廃止 (2026-07-30) ----
  if (-not (Test-UciUuidFormat $uuid)) {
      Out-NG "INVALID_UUID_FORMAT" "pk_CLIENTがUUID形式ではありません。"
  }
  $noteType = if ($payload.ContainsKey("noteType")) { [string]$payload["noteType"] } else { "" }

  # ---- 名前正規化 ----
  $n = $nameRaw.Trim()
  if ($noteType -match "一覧") {
      $n = $n -replace "株式会社", "㈱" -replace "有限会社", "㈲"
      $n = $n -replace "（株）", "㈱" -replace "\(株\)", "㈱"
      $n = $n -replace "（有）", "㈲" -replace "\(有\)", "㈲"
  } else {
      $remove = @("株式会社","有限会社","合同会社","合名会社","合資会社","（株）","(株)","㈱","有限","（有）","(有)","㈲")
      foreach ($r in $remove) { $n = $n -replace [regex]::Escape($r), "" }
  }
  $nameNorm = Sanitize-LeafName $n "NO_NAME"

  # アイコンとファイル名決定
  $prefixStr = Get-IconPrefix $noteType

  # ---- v9.0.0: canonical命名の一元化 ----
  # 顧客フォルダ名・新規ノート名はここで確定したcanonical値以外を使用しない。
  $canonicalFolderName = Get-CanonicalCustomerFolderName $nameRaw $uuid

  # ---- Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護 ----
  $matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
  if ($matchedFoldersList.Count -ge 2) {
    Out-NG "UUID_FOLDER_CONFLICT" "同一のpk_CLIENT UUID ($uuid) を持つ顧客フォルダが複数存在します。マージ処理が必要です。(Count: $($matchedFoldersList.Count))"
  }

  # ---- Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護 ----
  $matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
  if ($matchedFoldersList.Count -ge 2) {
    Out-NG "UUID_FOLDER_CONFLICT" "同一のpk_CLIENT UUID ($uuid) を持つ顧客フォルダが複数存在します。マージ処理が必要です。(Count: $($matchedFoldersList.Count))"
  }
  $canonicalFile = "${prefixStr}_${nameNorm}$(Get-UciUuidSuffix $uuid).md"

  # ★ v9.0.2 (FIX-1): $targetAbs と 新規CREATE候補path を完全に分離する。
  #   $targetAbs        ... UUID検証済みの既存managed noteだけを設定してよい変数。
  #                         これが非nullのときのみUpdate-Yaml-Robustによる既存note更新を行う。
  #   $newCandidateAbs  ... 新規CREATE候補path(まだ採用が確定していない予定パス)。
  #                         実在していても既存managed noteとしては絶対に採用しない。
  #   $fuzzyCandidates  ... UUID未検証のファイル名類似候補(診断保持のみ。出力は行わない)。
  $targetAbs = $null
  $newCandidateAbs = $null
  $fuzzyCandidates = @()
  $foundFolder = $null

  # ========================================================
  # v9.0.0 Step A: obs_RELPATH を「note locator hint」として検証・保持する。
  # ここでは採用を確定しない(customer folder identity解決を必ず別途実行するため)。
  # 検証内容は従来通り弱体化させない:
  #   相対パス / ".."を含まない / 01_顧客配下 / Vault外へ出ない / 3セグメント /
  #   実在ファイル / YAML完全UUID一致 / noteType接頭辞一致 / customer folderとして解決可能
  # ========================================================
  $hintNoteAbs = $null
  $hintFolderInfo = $null
  $hintFileName = $null

  if (
      $payload.ContainsKey("obs_RELPATH") -and
      -not [string]::IsNullOrWhiteSpace([string]$payload.obs_RELPATH)
  ) {
      $storedRel = ([string]$payload.obs_RELPATH).Trim()
      $storedRelNormalized = $storedRel.Replace("/", [string][char]92)

      # 絶対パス、親ディレクトリ参照、01_顧客以外を拒否する。
      $storedSegments = @($storedRelNormalized -split '\\')
      $storedPathShapeValid = (
          -not [System.IO.Path]::IsPathRooted($storedRelNormalized) -and
          $storedRelNormalized -notmatch '(^|\\)\.\.(\\|$)' -and
          $storedSegments.Count -eq 3 -and
          $storedSegments[0] -eq "01_顧客" -and
          -not [string]::IsNullOrWhiteSpace($storedSegments[1]) -and
          -not [string]::IsNullOrWhiteSpace($storedSegments[2])
      )

      if ($storedPathShapeValid) {
          $storedAbs = [System.IO.Path]::GetFullPath((Join-Path $VaultRoot $storedRelNormalized))
          $custRootFull = [System.IO.Path]::GetFullPath($custRoot).TrimEnd([char]92) + [char]92

          # GetFullPath後も01_顧客配下に留まることを確認する。
          if ($storedAbs.StartsWith($custRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
              if (Test-Path -LiteralPath $storedAbs -PathType Leaf) {
                  $storedFile = Get-Item -LiteralPath $storedAbs
                  $storedFolderInfo = Resolve-UciDirectChildFolder `
                      ([System.IO.DirectoryInfo]::new($custRoot)) `
                      $storedFile.FullName

                  if ($null -ne $storedFolderInfo) {
                      # customer folder直下のノートであること(managed note scope)を確認する。
                      $storedIsDirectChild = [string]::Equals(
                          (Split-Path -Parent $storedFile.FullName),
                          $storedFolderInfo.FullName,
                          [System.StringComparison]::OrdinalIgnoreCase
                      )
                      $storedHeader = Get-YamlHeaderLines $storedFile.FullName
                      if ($null -ne $storedHeader -and $storedIsDirectChild) {
                          $storedUuid = Get-YamlScalarValue $storedHeader "UUID:"
                          $storedPrefixMatches = $storedFile.Name.StartsWith(
                              "${prefixStr}_",
                              [System.StringComparison]::Ordinal
                          )

                          if (
                              -not [string]::IsNullOrWhiteSpace($storedUuid) -and
                              (Test-UciUuidFormat $storedUuid) -and
                              $storedUuid.Trim().ToUpperInvariant() -eq $uuid.Trim().ToUpperInvariant() -and
                              $storedPrefixMatches
                          ) {
                              # note候補としてのみ保持する(folder identity authorityにはしない)。
                              $hintNoteAbs = $storedFile.FullName
                              $hintFolderInfo = $storedFolderInfo
                              $hintFileName = $storedFile.Name
                          }
                      }
                  }
              }
          }
      }
  }

  # ========================================================
  # v9.0.0 Step B: 完全UUIDによる customer folder identity discovery
  # 01_顧客配下を再帰検索し、YAML frontmatterの完全UUID一致ノートが属する
  # 01_顧客直下のcustomer folderを特定する。
  # ========================================================
  $identityInfo = Get-UciUuidMatchedCustomerFolders $custRoot $uuid
  if ($null -ne $identityInfo.unresolved) {
      Out-NG "ERROR" "UUID一致ノートが01_顧客直下のフォルダ構造として解決できません。(Path: $($identityInfo.unresolved))"
  }
  $identityFolders = @($identityInfo.folders)

  if ($identityFolders.Count -ge 2) {
      $names = ($identityFolders | ForEach-Object { $_.Name }) -join ";"
      Out-NG "UUID_FOLDER_CONFLICT" "同一UUIDのノートが複数の顧客フォルダにまたがっています。安全のため処理を中止します。(pk_CLIENT: $uuid / Folders: $names)"
  }

  $resolvedFolderInfo = $null
  if ($identityFolders.Count -eq 1) {
      $resolvedFolderInfo = $identityFolders[0]
  }

  # ========================================================
  # v9.0.0 Step C: identityで確定したフォルダのevidence評価 → canonical昇格
  # ========================================================
  if ($null -ne $resolvedFolderInfo) {
      $evidence = Get-UciFolderEvidence $resolvedFolderInfo.FullName $uuid
      switch ($evidence.state) {
          "InvalidYaml" {
              Out-NG "YAML_BODY_BOUNDARY_UNRESOLVED" "対象フォルダ内にYAML本文境界が判定できないノートがあります。本文喪失のおそれがあるため処理を中止しました。(Path: $($evidence.detailPath))"
          }
          "Conflict" {
              Out-NG "FOLDER_UUID_MIXED" "対象フォルダ内に別UUIDのノートが混在しています。安全のため処理を中止します。(Path: $($evidence.detailPath) / UUID: $($evidence.detailValue))"
          }
          "InvalidUuid" {
              Out-NG "FOLDER_UUID_INVALID" "対象フォルダ内にUUID形式が不正なノートが残存しています。安全のため処理を中止します。(Path: $($evidence.detailPath) / Value: $($evidence.detailValue))"
          }
          "NoEvidence" {
              Out-NG "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "対象フォルダの完全UUID証拠を再確認できませんでした。安全のため処理を中止します。(Folder: $($resolvedFolderInfo.Name) / pk_CLIENT: $uuid)"
          }
      }

      # legacy(UUIDなし等) → canonicalへ昇格。別canonicalフォルダの新規作成は行わない。
      if ($resolvedFolderInfo.Name -ne $canonicalFolderName) {
          $canonicalDest = Join-Path $custRoot $canonicalFolderName
          if (Test-Path -LiteralPath $canonicalDest) {
              Out-NG "TARGET_FOLDER_ALREADY_EXISTS" "canonical顧客フォルダ名と同名の別フォルダが既に存在するため、昇格できません。(Current: $($resolvedFolderInfo.Name) / Canonical: $canonicalFolderName)"
          }
          try {
              Rename-Item -LiteralPath $resolvedFolderInfo.FullName -NewName $canonicalFolderName -Force -ErrorAction Stop
          } catch {
              Out-NG "FOLDER_RENAME_FAILED" "顧客フォルダをcanonical名へ変更できませんでした: $($_.Exception.Message)"
          }
          $resolvedFolderInfo = Get-Item -LiteralPath (Join-Path $custRoot $canonicalFolderName)
      }

      $foundFolder = $resolvedFolderInfo.Name
      $currentFolderFull = $resolvedFolderInfo.FullName

      # ================================================================
      # ★ v9.0.1 (MAJOR-1) / v9.0.2 (FIX-1): 正式managed noteの解決
      #
      # 正式既存noteとして$targetAbsに設定できるのは、次の3条件をすべて満たすファイルだけである。
      #   (1) customer folder直下(direct-child)にあること
      #   (2) 対象noteTypeのアイコン接頭辞と一致するファイル名であること
      #   (3) YAML frontmatterの完全UUIDがpk_CLIENTと一致すること
      # これらは Get-UuidNoteTypeMatches が一括で判定する(唯一のauthority)。
      #
      # v9.0.1では direct-child UUID一致0件のときに
      #     $targetAbs = Join-Path $currentFolderFull $canonicalFile
      # としていたため、canonicalFileと同名の既存ファイルが存在し、そのYAML UUIDが
      # pk_CLIENTと一致しない(あるいはUUIDキー自体が無い)場合でも、後続の
      #     if ($targetAbs -and (Test-Path -LiteralPath $targetAbs))
      # へ流れて既存managed noteとして採用され、Update-Yaml-RobustでUUIDを
      # 書き込んでしまう抜け道が残っていた。
      #
      # v9.0.2では direct-child UUID一致が0件の場合、$targetAbsは$nullのままとし、
      # 新規CREATE候補pathは別変数$newCandidateAbsへ格納する。
      # $newCandidateAbsが実在する場合でも既存managed noteとしては採用せず、
      # 後段のCREATE直前チェックでTARGET_NOTE_FILENAME_CONFLICTとしてFail-closedする。
      #
      # サブフォルダ側に同一UUID+同一noteTypeのnoteがある場合は
      # MANAGED_NOTE_OUT_OF_SCOPE で安全停止する。
      # ================================================================
      $unscopedNotes = @(Get-UciOutOfScopeManagedNotes $currentFolderFull $prefixStr $uuid)
      $uciMatches = @(Get-UuidNoteTypeMatches $currentFolderFull $prefixStr $uuid)

      if ($uciMatches.Count -ge 2) {
          Out-NG "DUPLICATE_NOTE_TYPE" "同一UUID・同一noteTypeの既存ノートが顧客フォルダ直下に複数見つかりました。安全のため処理を中止します。(Folder: $foundFolder / noteType: $noteType / 件数: $($uciMatches.Count))"
      }
      if ($unscopedNotes.Count -ge 1) {
          Out-NG "MANAGED_NOTE_OUT_OF_SCOPE" "管理対象ノートと同一UUID・同一noteTypeのノートが顧客フォルダのサブフォルダ内に存在します。自動採用・自動作成は行わず処理を中止します。(Folder: $foundFolder / noteType: $noteType / Path: $($unscopedNotes[0]))"
      }

      if ($uciMatches.Count -eq 1) {
          # 正式managed note(direct-child + noteType一致 + 完全UUID一致)のみ採用する。
          $targetAbs = $uciMatches[0]
          $canonicalFile = Split-Path -Leaf $targetAbs
      } else {
          # ---- direct-child UUID一致 0件 ----
          # ★ v9.0.2 (FIX-1): $targetAbsは$nullのまま維持する(既存note採用は行わない)。
          # 新規CREATE候補pathのみを別変数へ保持する。
          # ★ v9.0.2 (FIX-2): fuzzy候補は内部変数へ保持するだけで、Write-Host等の
          #   追加診断出力は一切行わない(FileMaker応答契約へ新規出力を混在させない)。
          $fuzzyCandidates = @(Get-UciFuzzyNameCandidates $currentFolderFull $prefixStr)
          $newCandidateAbs = Join-Path $currentFolderFull $canonicalFile
      }

      # ---- v9.0.0: obs_RELPATH候補を最終フォルダ上で再検証して採用 ----
      # hintのフォルダとidentity確定フォルダが矛盾する場合はFail-closed。
      if ($null -ne $hintNoteAbs) {
          $hintFinalAbs = Join-Path $currentFolderFull $hintFileName
          $hintFolderConsistent = $false
          if ($null -ne $hintFolderInfo) {
              # 昇格Rename後は元パスが存在しないため、Rename前のフォルダ名/昇格後の名前いずれかと一致すればよい。
              if ([string]::Equals($hintFolderInfo.FullName, $currentFolderFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                  $hintFolderConsistent = $true
              } elseif (-not (Test-Path -LiteralPath $hintFolderInfo.FullName)) {
                  # 元フォルダが消えている = canonicalへRenameされた可能性。最終フォルダ上での実在で確認する。
                  if (Test-Path -LiteralPath $hintFinalAbs -PathType Leaf) { $hintFolderConsistent = $true }
              }
          }
          if (-not $hintFolderConsistent) {
              Out-NG "RELPATH_FOLDER_MISMATCH" "obs_RELPATHが示す顧客フォルダと、完全UUIDで確定した顧客フォルダが一致しません。安全のため処理を中止します。(Hint: $($hintFolderInfo.Name) / Resolved: $foundFolder)"
          }
          if (Test-Path -LiteralPath $hintFinalAbs -PathType Leaf) {
              $hintHdrFinal = Get-YamlHeaderLines $hintFinalAbs
              if ($null -ne $hintHdrFinal) {
                  $hintUuidFinal = Get-YamlScalarValue $hintHdrFinal "UUID:"
                  if (
                      -not [string]::IsNullOrWhiteSpace($hintUuidFinal) -and
                      (Test-UciUuidFormat $hintUuidFinal) -and
                      $hintUuidFinal.Trim().ToUpperInvariant() -eq $uuid.Trim().ToUpperInvariant() -and
                      $hintFileName.StartsWith("${prefixStr}_", [System.StringComparison]::Ordinal)
                  ) {
                      # hintも「direct-child + noteType一致 + 完全UUID一致」を満たす場合のみ採用する。
                      # (UUID検証済みであるため$targetAbsへの設定は正式ルールに適合する)
                      $targetAbs = $hintFinalAbs
                      $canonicalFile = $hintFileName
                      $newCandidateAbs = $null
                  }
              }
          }
      }

      # folderNameConfirmedはgo-aheadに過ぎない。canonical folderを別名へ降格しない。
      # 既にcanonical名へ昇格済みのため、ここでのRenameは行わない。
  } else {
      # identity未確定(完全UUID証拠なし)。
      # obs_RELPATHでnoteが見つかっていた場合でも、identityが確定しないままの採用は行わない。
      if ($null -ne $hintNoteAbs) {
          Out-NG "RELPATH_FOLDER_MISMATCH" "obs_RELPATHのノートは見つかりましたが、完全UUIDによる顧客フォルダ確定ができませんでした。安全のため処理を中止します。(Hint: $hintNoteAbs / pk_CLIENT: $uuid)"
      }

      # legacy顧客名一致フォルダの状態を確認する(自動作成の前に必ず判定する)。
      $folders = Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue
      $matchName = Normalize-ForMatch $nameRaw
      $legacyCandidates = @($folders | Where-Object {
          $_.Name -ne $canonicalFolderName -and (Normalize-ForMatch $_.Name) -eq $matchName
      })
      if ($legacyCandidates.Count -ge 1) {
          # 完全UUID証拠が無いlegacyフォルダ。別canonicalフォルダを勝手に作らずFail-closed。
          $legacyNames = ($legacyCandidates | ForEach-Object { $_.Name }) -join ";"
          Out-NG "LEGACY_FOLDER_NEEDS_MIGRATION" "顧客名が一致するフォルダが存在しますが、pk_CLIENTの完全UUID証拠がないため同一顧客と確定できません。手動確認が必要です。(Folders: $legacyNames / pk_CLIENT: $uuid)"
      }

      # canonical名フォルダが既に存在するのに完全UUID証拠が無い場合(UUID8衝突等)も自動採用しない。
      $canonicalExisting = @($folders | Where-Object { $_.Name -eq $canonicalFolderName })
      if ($canonicalExisting.Count -ge 1) {
          Out-NG "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "canonical名の顧客フォルダは存在しますが、pk_CLIENTの完全UUID証拠がありません。UUID先頭8文字の衝突の可能性があるため処理を中止します。(Folder: $canonicalFolderName / pk_CLIENT: $uuid)"
      }
  }

  # ▼▼▼ COMPARE モード (突合結果を開く) ▼▼▼
  # ▲▲▲ COMPARE モード 終了 ▲▲▲

  # ▼▼▼ 通常モード（引数に応じて一覧ファイルを開く／なければ作成） ▼▼▼

  # 1. 既存ノートあり（開いて終わる）
  # ★ v9.0.2 (FIX-1): ここへ到達する$targetAbsは、必ず
  #   「direct-child + noteType接頭辞一致 + 完全UUID一致」でUUID検証済みのファイルのみである。
  #   UUID未検証のcanonicalFile同名ファイルやfuzzy候補は$targetAbsへ入らないため、
  #   それらへUpdate-Yaml-Robustが実行されることはない。
  if ($targetAbs -and (Test-Path -LiteralPath $targetAbs)) {
    $totalVal = $null
    if ($noteType -eq "契約一覧") {
        $totalVal = Extract-TableTotal $targetAbs
        if ([string]::IsNullOrWhiteSpace($totalVal)) { $totalVal = "" }
    }

    Update-Yaml-Robust $targetAbs $rank $nameRaw $ceo $ruby $uuid $totalVal

    $rel = Get-RelPath $VaultRoot $targetAbs
    $lw  = (Get-Item -LiteralPath $targetAbs).LastWriteTime

    $index[$payload.pk_CLIENT] = @{ relpath=$rel; lastWrite=$lw.ToString("yyyy-MM-ddTHH:mm:ss"); noteType=[string]$payload.noteType; nameNorm=$nameNorm; folderName=$foundFolder }
    [System.IO.File]::WriteAllText($indexPath, ($index | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

    # 標準URIスキームでファイルを開く
    Open-ObsidianFile $VaultRoot $rel

    # FileMaker返却用URI
    $url = Get-ObsidianOpenUrl $VaultRoot $rel

    Out-OK "OPENED" $url $rel ($lw.ToString("yyyy-MM-ddTHH:mm:ss")) "e30="
  }

  # ---- v9.0.0/v9.0.1/v9.0.2: 新規作成へ入る前の最終防衛線 ----
  # customer folderが確定している場合は、その直下のみを主判定にして再確認する
  # (再帰検索の結果で正式ノートを自動採用してはならない)。
  # customer folderが未確定の場合は、01_顧客配下全体でscope外/他フォルダのノートを検出し、
  # 誤った新規作成を防ぐ。
  if ($null -ne $resolvedFolderInfo) {
    $finalDirect = @(Get-UuidNoteTypeMatches $resolvedFolderInfo.FullName $prefixStr $uuid)
    if ($finalDirect.Count -ge 2) {
      Out-NG "DUPLICATE_NOTE_TYPE" "同一UUID・同一noteTypeの既存ノートが顧客フォルダ直下に複数見つかりました。安全のため新規作成を中止します。(pk_CLIENT: $uuid / noteType: $noteType / 件数: $($finalDirect.Count))"
    }
    $finalOutOfScope = @(Get-UciOutOfScopeManagedNotes $resolvedFolderInfo.FullName $prefixStr $uuid)
    if ($finalOutOfScope.Count -ge 1) {
      Out-NG "MANAGED_NOTE_OUT_OF_SCOPE" "管理対象ノートと同一UUID・同一noteTypeのノートがサブフォルダ内に存在します。新規作成を中止します。(pk_CLIENT: $uuid / noteType: $noteType / Path: $($finalOutOfScope[0]))"
    }
    if ($finalDirect.Count -eq 1) {
      # 既存採用専用分岐: 内容・YAML・ファイル名・LastWriteTimeを一切変更しない。
      # (ここへ到達するのはUUID検証済みのdirect-child noteのみ)
      $adoptedAbs = [string]$finalDirect[0]
      $rel = Get-RelPath $VaultRoot $adoptedAbs
      $lw  = (Get-Item -LiteralPath $adoptedAbs).LastWriteTime
      $index[$payload.pk_CLIENT] = @{ relpath=$rel; lastWrite=$lw.ToString("yyyy-MM-ddTHH:mm:ss"); noteType=[string]$payload.noteType; nameNorm=$nameNorm; folderName=$resolvedFolderInfo.Name }
      [System.IO.File]::WriteAllText($indexPath, ($index | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
      Open-ObsidianFile $VaultRoot $rel
      $url = Get-ObsidianOpenUrl $VaultRoot $rel
      Out-OK "OPENED" $url $rel ($lw.ToString("yyyy-MM-ddTHH:mm:ss")) "e30="
    }
  } else {
    $treeMatches = @(Get-UuidNoteTypeMatchesInTree $custRoot $prefixStr $uuid)
    if ($treeMatches.Count -ge 1) {
      Out-NG "UUID_FOLDER_CONFLICT" "顧客フォルダを確定できないまま、同一UUID・同一noteTypeの既存ノートが検出されました。安全のため新規作成を中止します。(pk_CLIENT: $uuid / noteType: $noteType / Path: $($treeMatches[0]))"
    }
  }

  # 新規作成時のファイル名は必ずUUID識別子付きcanonical名にする。
  $canonicalFile = "${prefixStr}_${nameNorm}$(Get-UciUuidSuffix $uuid).md"

  # 2. フォルダ未確定時の確認
  # ※ suggestは必ずcanonicalFolderName。folderNameConfirmedは「新規作成継続のgo-ahead」としてのみ扱う。
  #
  # ★ v9.0.3 (folderNameConfirmed契約不整合の修正):
  #   従来は「folderNameConfirmedが非空ならgo-ahead」としており、FileMaker側の
  #   $$obsFolderNameInput(編集可能フィールド)でオペレータがcanonical名以外
  #   (例: 部分一致で候補表示されたlegacyフォルダ名)を確定しても、その値を黙って捨てて
  #   canonical名で新規作成していた。これは「オペレータの選択を無言で無視する」挙動であり安全でない。
  #   本版では、folderNameConfirmedを引き続きnaming authorityにはしない(値からフォルダ名を作らない)が、
  #   go-aheadとして受け入れる前に、既存Sanitize-LeafNameを通した値がcanonicalFolderNameと
  #   OrdinalIgnoreCaseで一致することを必須化する。
  #   不一致の場合はFOLDER_CONFIRMATION_MISMATCHでFail-closedし、
  #   確認された名前のフォルダを既存採用しない・そこへ移動しない・canonicalフォルダも作らない・
  #   ノートも作らない(何も作成・変更せずに停止する)。
  $folderNameConfirmedRaw = ""
  $hasGoAhead = $false
  if (
      $payload.ContainsKey("folderNameConfirmed") -and
      -not [string]::IsNullOrWhiteSpace([string]$payload.folderNameConfirmed)
  ) {
    $folderNameConfirmedRaw = [string]$payload.folderNameConfirmed
    # 既存のSanitize-LeafNameのみを使用する(新しいSanitize関数は追加しない)。
    # 前後空白・全角空白・制御文字・禁止文字等は既存規則で正規化されるため、
    # T27のような入力揺れはcanonicalと一致すれば正常継続できる。
    $confirmedSafeName = Sanitize-LeafName $folderNameConfirmedRaw "NO_NAME"
    if (-not [string]::Equals(
            $confirmedSafeName,
            $canonicalFolderName,
            [System.StringComparison]::OrdinalIgnoreCase)) {
      Out-NG "FOLDER_CONFIRMATION_MISMATCH" "FileMakerで確認されたフォルダ名がcanonicalFolderNameと一致しないため、新規作成を中止しました。(Confirmed: $confirmedSafeName / Canonical: $canonicalFolderName)"
    }
    $hasGoAhead = $true
  }

  if ((-not $foundFolder) -and (-not $hasGoAhead)) {
    $folders = Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue
    $suggest = $canonicalFolderName
    $cands = $folders | Where-Object { (Normalize-ForMatch $_.Name) -like "*$nameNorm*" } | Select-Object -ExpandProperty Name
    Out-OKNeedFolder $cands $suggest $nameNorm $canonicalFile
  }

  # 3. 新規作成（フォルダ作成含む）
  # 作成先フォルダ名はcanonicalFolderName以外を認めない。
  if ($foundFolder) {
    $newDir = Join-Path $custRoot $foundFolder
    $actualCreateFolderName = $foundFolder
  } else {
    $actualCreateFolderName = $canonicalFolderName
    $newDir = Join-Path $custRoot $canonicalFolderName
  }

  # fail-closed再確認: 作成先フォルダ名がcanonical名(または既にUUID証拠で確定したcanonical昇格済み名)であること。
  if ($actualCreateFolderName -ne $canonicalFolderName) {
    Out-NG "CANONICAL_FOLDER_NAME_MISMATCH" "作成先フォルダ名がcanonical名と一致しません。安全のため処理を中止します。(Actual: $actualCreateFolderName / Canonical: $canonicalFolderName)"
  }

  if (-not (Test-Path -LiteralPath $newDir)) {
    [void][System.IO.Directory]::CreateDirectory($newDir)
  }
  $newDirInfo = Get-Item -LiteralPath $newDir
  $newDir = $newDirInfo.FullName
  $safeConfName = $newDirInfo.Name

  # ★ v9.0.2 (FIX-1): 新規CREATE候補pathを最終確定する。
  # 既に$newCandidateAbs(identity確定フォルダ上での候補path)がある場合はそれを優先し、
  # 無い場合(identity未確定→新規フォルダ作成経路)はここで組み立てる。
  # いずれの場合も、このpathに実在ファイルがあるときは既存managed noteとして採用せず、
  # TARGET_NOTE_FILENAME_CONFLICTでFail-closedする(既存ファイルへのUUID書込みによる
  # 「正規化」は絶対に行わない)。
  $newAbs = Join-Path $newDir $canonicalFile
  if ($null -ne $newCandidateAbs) {
    if (-not [string]::Equals($newCandidateAbs, $newAbs, [System.StringComparison]::OrdinalIgnoreCase)) {
      # identity確定フォルダとCREATE先フォルダが食い違う異常系。安全のため停止する。
      Out-NG "CANONICAL_FOLDER_NAME_MISMATCH" "新規作成候補パスが顧客フォルダ確定結果と一致しません。安全のため処理を中止します。(Candidate: $newCandidateAbs / Create: $newAbs)"
    }
  }
  if (Test-Path -LiteralPath $newAbs) {
    $fuzzyDetail = ""
    if ($fuzzyCandidates.Count -ge 1) { $fuzzyDetail = " / UUID未検証の同種ファイル名候補: " + (($fuzzyCandidates | Select-Object -First 5) -join ";") }
    Out-NG "TARGET_NOTE_FILENAME_CONFLICT" "作成予定のノートと同名のファイルが既に存在しますが、YAMLの完全UUIDがpk_CLIENTと一致しないため既存ノートとして採用できません。上書き・自動正規化は行わず処理を中止します。(Path: $newAbs / pk_CLIENT: $uuid / noteType: $noteType$fuzzyDetail)"
  }
  try {
    $fsNew = [System.IO.File]::Open(
        $newAbs,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None
    )
    $fsNew.Close()
    $fsNew.Dispose()
  } catch {
    Out-NG "NOTE_CREATE_FAILED" "ノートの新規作成に失敗しました(既存ファイルとの競合の可能性): $($_.Exception.Message)"
  }

  $totalVal = $null
  if ($noteType -eq "契約一覧") { $totalVal = "" }

  Update-Yaml-Robust $newAbs $rank $nameRaw $ceo $ruby $uuid $totalVal

  # 新規作成時のテンプレート挿入処理
  if ($noteType -match "事故一覧") {
      $jikoTemplate = @"

---
## 🚨対応中

| 事故日 | 状態 | 証券番号 | ClaimNo | お問合せNo | 事故内容 |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## ✅完了

| 事故日 | 状態 | 証券番号 | ClaimNo | お問合せNo | 事故内容 |
| --- | --- | --- | --- | --- | --- |
| | | | | | |
"@
      [System.IO.File]::AppendAllText($newAbs, $jikoTemplate, [System.Text.UTF8Encoding]::new($false))
  } else {
      [System.IO.File]::AppendAllText($newAbs, "`n---`n## 履歴`nここから入力", [System.Text.UTF8Encoding]::new($false))
  }

  $rel = Get-RelPath $VaultRoot $newAbs

  $index[$payload.pk_CLIENT] = @{ relpath=$rel; lastWrite=(Get-Date).ToString("yyyy-MM-ddTHH:mm:ss"); noteType=[string]$payload.noteType; nameNorm=$nameNorm; folderName=$safeConfName }
  [System.IO.File]::WriteAllText($indexPath, ($index | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

  # 標準URIスキームでファイルを開く
  Open-ObsidianFile $VaultRoot $rel

  # FileMaker返却用URI
  $url = Get-ObsidianOpenUrl $VaultRoot $rel

  Out-OK "CREATED" $url $rel ((Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")) "e30="
  } finally {
    if ($null -ne $lock) {
      $lock.Close()
      $lock.Dispose()
    }
  }
}

function Invoke-CompareObsidianNotes($payload) {
  $rawVault = if ($payload.ContainsKey("VaultRoot")) { [string]$payload["VaultRoot"] } else { "" }
  $VaultRoot = $rawVault.Trim()
  if (-not (Test-Path -LiteralPath $VaultRoot)) { Out-NG "ERROR" "VaultRoot not found." }

  # Lock Acquisition Phase (NH-1, NM-1, NM-2)
  $txDir = Join-Path $VaultRoot ".fm-obsidian-bridge-transactions"
  if (-not (Test-Path -LiteralPath $txDir)) { [void][System.IO.Directory]::CreateDirectory($txDir) }

  $lock = $null
  try {
    $lock = [System.IO.FileStream]::new(
      (Join-Path $txDir "ACTIVE.lock"),
      [System.IO.FileMode]::OpenOrCreate,
      [System.IO.FileAccess]::ReadWrite,
      [System.IO.FileShare]::None
    )
  } catch {
    $errClass = Get-LockAcquisitionErrorClass $_.Exception
    Out-NG "ERROR" "他の操作が実行中か、ロック取得に失敗しました ($errClass)。"
  }

  try {
  Assert-ObsidianReady

  $custRoot  = Join-Path $VaultRoot "01_顧客"
  $indexPath = Join-Path $VaultRoot "scripts\obsidian_index.json"
  if (-not (Test-Path -LiteralPath $custRoot)) { New-Item -ItemType Directory -Path $custRoot -Force | Out-Null }

  $index = Load-IndexSafe $indexPath

  $nameRaw  = if ($payload.ContainsKey("companyNameRaw")) { [string]$payload["companyNameRaw"] } else { "" }
  $rank     = if ($payload.ContainsKey("RANK")) { [string]$payload["RANK"] } else { "" }
  $ceo      = if ($payload.ContainsKey("CEO")) { [string]$payload["CEO"] } else { "" }
  $ruby     = if ($payload.ContainsKey("RUBY")) { [string]$payload["RUBY"] } else { "" }
  $uuid     = if ($payload.ContainsKey("pk_CLIENT")) { [string]$payload["pk_CLIENT"] } else { "" }

  # ---- 不正UUIDフォールバックの廃止 (2026-07-30) ----
  if (-not (Test-UciUuidFormat $uuid)) {
      Out-NG "INVALID_UUID_FORMAT" "pk_CLIENTがUUID形式ではありません。"
  }
  $noteType = if ($payload.ContainsKey("noteType")) { [string]$payload["noteType"] } else { "" }

  # ---- 名前正規化 ----
  $n = $nameRaw.Trim()
  if ($noteType -match "一覧") {
      $n = $n -replace "株式会社", "㈱" -replace "有限会社", "㈲"
      $n = $n -replace "（株）", "㈱" -replace "\(株\)", "㈱"
      $n = $n -replace "（有）", "㈲" -replace "\(有\)", "㈲"
  } else {
      $remove = @("株式会社","有限会社","合同会社","合名会社","合資会社","（株）","(株)","㈱","有限","（有）","(有)","㈲")
      foreach ($r in $remove) { $n = $n -replace [regex]::Escape($r), "" }
  }
  $nameNorm = Sanitize-LeafName $n "NO_NAME"

  # アイコンとファイル名決定
  $prefixStr = Get-IconPrefix $noteType

  # ---- v9.0.0: canonical命名の一元化 ----
  # 顧客フォルダ名・新規ノート名はここで確定したcanonical値以外を使用しない。
  $canonicalFolderName = Get-CanonicalCustomerFolderName $nameRaw $uuid

  # ---- Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護 ----
  $matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
  if ($matchedFoldersList.Count -ge 2) {
    Out-NG "UUID_FOLDER_CONFLICT" "同一のpk_CLIENT UUID ($uuid) を持つ顧客フォルダが複数存在します。マージ処理が必要です。(Count: $($matchedFoldersList.Count))"
  }

  # ---- Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護 ----
  $matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
  if ($matchedFoldersList.Count -ge 2) {
    Out-NG "UUID_FOLDER_CONFLICT" "同一のpk_CLIENT UUID ($uuid) を持つ顧客フォルダが複数存在します。マージ処理が必要です。(Count: $($matchedFoldersList.Count))"
  }
  $canonicalFile = "${prefixStr}_${nameNorm}$(Get-UciUuidSuffix $uuid).md"

  # ★ v9.0.2 (FIX-1): $targetAbs と 新規CREATE候補path を完全に分離する。
  #   $targetAbs        ... UUID検証済みの既存managed noteだけを設定してよい変数。
  #                         これが非nullのときのみUpdate-Yaml-Robustによる既存note更新を行う。
  #   $newCandidateAbs  ... 新規CREATE候補path(まだ採用が確定していない予定パス)。
  #                         実在していても既存managed noteとしては絶対に採用しない。
  #   $fuzzyCandidates  ... UUID未検証のファイル名類似候補(診断保持のみ。出力は行わない)。
  $targetAbs = $null
  $newCandidateAbs = $null
  $fuzzyCandidates = @()
  $foundFolder = $null

  # ========================================================
  # v9.0.0 Step A: obs_RELPATH を「note locator hint」として検証・保持する。
  # ここでは採用を確定しない(customer folder identity解決を必ず別途実行するため)。
  # 検証内容は従来通り弱体化させない:
  #   相対パス / ".."を含まない / 01_顧客配下 / Vault外へ出ない / 3セグメント /
  #   実在ファイル / YAML完全UUID一致 / noteType接頭辞一致 / customer folderとして解決可能
  # ========================================================
  $hintNoteAbs = $null
  $hintFolderInfo = $null
  $hintFileName = $null

  if (
      $payload.ContainsKey("obs_RELPATH") -and
      -not [string]::IsNullOrWhiteSpace([string]$payload.obs_RELPATH)
  ) {
      $storedRel = ([string]$payload.obs_RELPATH).Trim()
      $storedRelNormalized = $storedRel.Replace("/", [string][char]92)

      # 絶対パス、親ディレクトリ参照、01_顧客以外を拒否する。
      $storedSegments = @($storedRelNormalized -split '\\')
      $storedPathShapeValid = (
          -not [System.IO.Path]::IsPathRooted($storedRelNormalized) -and
          $storedRelNormalized -notmatch '(^|\\)\.\.(\\|$)' -and
          $storedSegments.Count -eq 3 -and
          $storedSegments[0] -eq "01_顧客" -and
          -not [string]::IsNullOrWhiteSpace($storedSegments[1]) -and
          -not [string]::IsNullOrWhiteSpace($storedSegments[2])
      )

      if ($storedPathShapeValid) {
          $storedAbs = [System.IO.Path]::GetFullPath((Join-Path $VaultRoot $storedRelNormalized))
          $custRootFull = [System.IO.Path]::GetFullPath($custRoot).TrimEnd([char]92) + [char]92

          # GetFullPath後も01_顧客配下に留まることを確認する。
          if ($storedAbs.StartsWith($custRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
              if (Test-Path -LiteralPath $storedAbs -PathType Leaf) {
                  $storedFile = Get-Item -LiteralPath $storedAbs
                  $storedFolderInfo = Resolve-UciDirectChildFolder `
                      ([System.IO.DirectoryInfo]::new($custRoot)) `
                      $storedFile.FullName

                  if ($null -ne $storedFolderInfo) {
                      # customer folder直下のノートであること(managed note scope)を確認する。
                      $storedIsDirectChild = [string]::Equals(
                          (Split-Path -Parent $storedFile.FullName),
                          $storedFolderInfo.FullName,
                          [System.StringComparison]::OrdinalIgnoreCase
                      )
                      $storedHeader = Get-YamlHeaderLines $storedFile.FullName
                      if ($null -ne $storedHeader -and $storedIsDirectChild) {
                          $storedUuid = Get-YamlScalarValue $storedHeader "UUID:"
                          $storedPrefixMatches = $storedFile.Name.StartsWith(
                              "${prefixStr}_",
                              [System.StringComparison]::Ordinal
                          )

                          if (
                              -not [string]::IsNullOrWhiteSpace($storedUuid) -and
                              (Test-UciUuidFormat $storedUuid) -and
                              $storedUuid.Trim().ToUpperInvariant() -eq $uuid.Trim().ToUpperInvariant() -and
                              $storedPrefixMatches
                          ) {
                              # note候補としてのみ保持する(folder identity authorityにはしない)。
                              $hintNoteAbs = $storedFile.FullName
                              $hintFolderInfo = $storedFolderInfo
                              $hintFileName = $storedFile.Name
                          }
                      }
                  }
              }
          }
      }
  }

  # ========================================================
  # v9.0.0 Step B: 完全UUIDによる customer folder identity discovery
  # 01_顧客配下を再帰検索し、YAML frontmatterの完全UUID一致ノートが属する
  # 01_顧客直下のcustomer folderを特定する。
  # ========================================================
  $identityInfo = Get-UciUuidMatchedCustomerFolders $custRoot $uuid
  if ($null -ne $identityInfo.unresolved) {
      Out-NG "ERROR" "UUID一致ノートが01_顧客直下のフォルダ構造として解決できません。(Path: $($identityInfo.unresolved))"
  }
  $identityFolders = @($identityInfo.folders)

  if ($identityFolders.Count -ge 2) {
      $names = ($identityFolders | ForEach-Object { $_.Name }) -join ";"
      Out-NG "UUID_FOLDER_CONFLICT" "同一UUIDのノートが複数の顧客フォルダにまたがっています。安全のため処理を中止します。(pk_CLIENT: $uuid / Folders: $names)"
  }

  $resolvedFolderInfo = $null
  if ($identityFolders.Count -eq 1) {
      $resolvedFolderInfo = $identityFolders[0]
  }

  # ========================================================
  # v9.0.0 Step C: identityで確定したフォルダのevidence評価 → canonical昇格
  # ========================================================
  if ($null -ne $resolvedFolderInfo) {
      $evidence = Get-UciFolderEvidence $resolvedFolderInfo.FullName $uuid
      switch ($evidence.state) {
          "InvalidYaml" {
              Out-NG "YAML_BODY_BOUNDARY_UNRESOLVED" "対象フォルダ内にYAML本文境界が判定できないノートがあります。本文喪失のおそれがあるため処理を中止しました。(Path: $($evidence.detailPath))"
          }
          "Conflict" {
              Out-NG "FOLDER_UUID_MIXED" "対象フォルダ内に別UUIDのノートが混在しています。安全のため処理を中止します。(Path: $($evidence.detailPath) / UUID: $($evidence.detailValue))"
          }
          "InvalidUuid" {
              Out-NG "FOLDER_UUID_INVALID" "対象フォルダ内にUUID形式が不正なノートが残存しています。安全のため処理を中止します。(Path: $($evidence.detailPath) / Value: $($evidence.detailValue))"
          }
          "NoEvidence" {
              Out-NG "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "対象フォルダの完全UUID証拠を再確認できませんでした。安全のため処理を中止します。(Folder: $($resolvedFolderInfo.Name) / pk_CLIENT: $uuid)"
          }
      }

      # legacy(UUIDなし等) → canonicalへ昇格。別canonicalフォルダの新規作成は行わない。
      if ($resolvedFolderInfo.Name -ne $canonicalFolderName) {
          $canonicalDest = Join-Path $custRoot $canonicalFolderName
          if (Test-Path -LiteralPath $canonicalDest) {
              Out-NG "TARGET_FOLDER_ALREADY_EXISTS" "canonical顧客フォルダ名と同名の別フォルダが既に存在するため、昇格できません。(Current: $($resolvedFolderInfo.Name) / Canonical: $canonicalFolderName)"
          }
          try {
              Rename-Item -LiteralPath $resolvedFolderInfo.FullName -NewName $canonicalFolderName -Force -ErrorAction Stop
          } catch {
              Out-NG "FOLDER_RENAME_FAILED" "顧客フォルダをcanonical名へ変更できませんでした: $($_.Exception.Message)"
          }
          $resolvedFolderInfo = Get-Item -LiteralPath (Join-Path $custRoot $canonicalFolderName)
      }

      $foundFolder = $resolvedFolderInfo.Name
      $currentFolderFull = $resolvedFolderInfo.FullName

      # ================================================================
      # ★ v9.0.1 (MAJOR-1) / v9.0.2 (FIX-1): 正式managed noteの解決
      #
      # 正式既存noteとして$targetAbsに設定できるのは、次の3条件をすべて満たすファイルだけである。
      #   (1) customer folder直下(direct-child)にあること
      #   (2) 対象noteTypeのアイコン接頭辞と一致するファイル名であること
      #   (3) YAML frontmatterの完全UUIDがpk_CLIENTと一致すること
      # これらは Get-UuidNoteTypeMatches が一括で判定する(唯一のauthority)。
      #
      # v9.0.1では direct-child UUID一致0件のときに
      #     $targetAbs = Join-Path $currentFolderFull $canonicalFile
      # としていたため、canonicalFileと同名の既存ファイルが存在し、そのYAML UUIDが
      # pk_CLIENTと一致しない(あるいはUUIDキー自体が無い)場合でも、後続の
      #     if ($targetAbs -and (Test-Path -LiteralPath $targetAbs))
      # へ流れて既存managed noteとして採用され、Update-Yaml-RobustでUUIDを
      # 書き込んでしまう抜け道が残っていた。
      #
      # v9.0.2では direct-child UUID一致が0件の場合、$targetAbsは$nullのままとし、
      # 新規CREATE候補pathは別変数$newCandidateAbsへ格納する。
      # $newCandidateAbsが実在する場合でも既存managed noteとしては採用せず、
      # 後段のCREATE直前チェックでTARGET_NOTE_FILENAME_CONFLICTとしてFail-closedする。
      #
      # サブフォルダ側に同一UUID+同一noteTypeのnoteがある場合は
      # MANAGED_NOTE_OUT_OF_SCOPE で安全停止する。
      # ================================================================
      $unscopedNotes = @(Get-UciOutOfScopeManagedNotes $currentFolderFull $prefixStr $uuid)
      $uciMatches = @(Get-UuidNoteTypeMatches $currentFolderFull $prefixStr $uuid)

      if ($uciMatches.Count -ge 2) {
          Out-NG "DUPLICATE_NOTE_TYPE" "同一UUID・同一noteTypeの既存ノートが顧客フォルダ直下に複数見つかりました。安全のため処理を中止します。(Folder: $foundFolder / noteType: $noteType / 件数: $($uciMatches.Count))"
      }
      if ($unscopedNotes.Count -ge 1) {
          Out-NG "MANAGED_NOTE_OUT_OF_SCOPE" "管理対象ノートと同一UUID・同一noteTypeのノートが顧客フォルダのサブフォルダ内に存在します。自動採用・自動作成は行わず処理を中止します。(Folder: $foundFolder / noteType: $noteType / Path: $($unscopedNotes[0]))"
      }

      if ($uciMatches.Count -eq 1) {
          # 正式managed note(direct-child + noteType一致 + 完全UUID一致)のみ採用する。
          $targetAbs = $uciMatches[0]
          $canonicalFile = Split-Path -Leaf $targetAbs
      } else {
          # ---- direct-child UUID一致 0件 ----
          # ★ v9.0.2 (FIX-1): $targetAbsは$nullのまま維持する(既存note採用は行わない)。
          # 新規CREATE候補pathのみを別変数へ保持する。
          # ★ v9.0.2 (FIX-2): fuzzy候補は内部変数へ保持するだけで、Write-Host等の
          #   追加診断出力は一切行わない(FileMaker応答契約へ新規出力を混在させない)。
          $fuzzyCandidates = @(Get-UciFuzzyNameCandidates $currentFolderFull $prefixStr)
          $newCandidateAbs = Join-Path $currentFolderFull $canonicalFile
      }

      # ---- v9.0.0: obs_RELPATH候補を最終フォルダ上で再検証して採用 ----
      # hintのフォルダとidentity確定フォルダが矛盾する場合はFail-closed。
      if ($null -ne $hintNoteAbs) {
          $hintFinalAbs = Join-Path $currentFolderFull $hintFileName
          $hintFolderConsistent = $false
          if ($null -ne $hintFolderInfo) {
              # 昇格Rename後は元パスが存在しないため、Rename前のフォルダ名/昇格後の名前いずれかと一致すればよい。
              if ([string]::Equals($hintFolderInfo.FullName, $currentFolderFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                  $hintFolderConsistent = $true
              } elseif (-not (Test-Path -LiteralPath $hintFolderInfo.FullName)) {
                  # 元フォルダが消えている = canonicalへRenameされた可能性。最終フォルダ上での実在で確認する。
                  if (Test-Path -LiteralPath $hintFinalAbs -PathType Leaf) { $hintFolderConsistent = $true }
              }
          }
          if (-not $hintFolderConsistent) {
              Out-NG "RELPATH_FOLDER_MISMATCH" "obs_RELPATHが示す顧客フォルダと、完全UUIDで確定した顧客フォルダが一致しません。安全のため処理を中止します。(Hint: $($hintFolderInfo.Name) / Resolved: $foundFolder)"
          }
          if (Test-Path -LiteralPath $hintFinalAbs -PathType Leaf) {
              $hintHdrFinal = Get-YamlHeaderLines $hintFinalAbs
              if ($null -ne $hintHdrFinal) {
                  $hintUuidFinal = Get-YamlScalarValue $hintHdrFinal "UUID:"
                  if (
                      -not [string]::IsNullOrWhiteSpace($hintUuidFinal) -and
                      (Test-UciUuidFormat $hintUuidFinal) -and
                      $hintUuidFinal.Trim().ToUpperInvariant() -eq $uuid.Trim().ToUpperInvariant() -and
                      $hintFileName.StartsWith("${prefixStr}_", [System.StringComparison]::Ordinal)
                  ) {
                      # hintも「direct-child + noteType一致 + 完全UUID一致」を満たす場合のみ採用する。
                      # (UUID検証済みであるため$targetAbsへの設定は正式ルールに適合する)
                      $targetAbs = $hintFinalAbs
                      $canonicalFile = $hintFileName
                      $newCandidateAbs = $null
                  }
              }
          }
      }

      # folderNameConfirmedはgo-aheadに過ぎない。canonical folderを別名へ降格しない。
      # 既にcanonical名へ昇格済みのため、ここでのRenameは行わない。
  } else {
      # identity未確定(完全UUID証拠なし)。
      # obs_RELPATHでnoteが見つかっていた場合でも、identityが確定しないままの採用は行わない。
      if ($null -ne $hintNoteAbs) {
          Out-NG "RELPATH_FOLDER_MISMATCH" "obs_RELPATHのノートは見つかりましたが、完全UUIDによる顧客フォルダ確定ができませんでした。安全のため処理を中止します。(Hint: $hintNoteAbs / pk_CLIENT: $uuid)"
      }

      # legacy顧客名一致フォルダの状態を確認する(自動作成の前に必ず判定する)。
      $folders = Get-ChildItem -LiteralPath $custRoot -Directory -ErrorAction SilentlyContinue
      $matchName = Normalize-ForMatch $nameRaw
      $legacyCandidates = @($folders | Where-Object {
          $_.Name -ne $canonicalFolderName -and (Normalize-ForMatch $_.Name) -eq $matchName
      })
      if ($legacyCandidates.Count -ge 1) {
          # 完全UUID証拠が無いlegacyフォルダ。別canonicalフォルダを勝手に作らずFail-closed。
          $legacyNames = ($legacyCandidates | ForEach-Object { $_.Name }) -join ";"
          Out-NG "LEGACY_FOLDER_NEEDS_MIGRATION" "顧客名が一致するフォルダが存在しますが、pk_CLIENTの完全UUID証拠がないため同一顧客と確定できません。手動確認が必要です。(Folders: $legacyNames / pk_CLIENT: $uuid)"
      }

      # canonical名フォルダが既に存在するのに完全UUID証拠が無い場合(UUID8衝突等)も自動採用しない。
      $canonicalExisting = @($folders | Where-Object { $_.Name -eq $canonicalFolderName })
      if ($canonicalExisting.Count -ge 1) {
          Out-NG "CANONICAL_FOLDER_NO_UUID_EVIDENCE" "canonical名の顧客フォルダは存在しますが、pk_CLIENTの完全UUID証拠がありません。UUID先頭8文字の衝突の可能性があるため処理を中止します。(Folder: $canonicalFolderName / pk_CLIENT: $uuid)"
      }
  }

  # ▼▼▼ COMPARE モード (突合結果を開く) ▼▼▼
  if ($true) {
    if (-not $foundFolder) {
       Out-NG "ERROR" "比較対象の顧客フォルダが見つかりません。(Search: $nameNorm / pk_CLIENT: $uuid)"
    }
    # ★ v9.0.1/v9.0.2: COMPAREの突合対象も正式managed note(UUID検証済み)でなければならない。
    # fuzzy候補・UUID未検証の同名ファイルは採用しないため、
    # UUID検証済みの$targetAbsが無い場合はPythonへ渡さず安全停止する。
    if ([string]::IsNullOrWhiteSpace($targetAbs) -or -not (Test-Path -LiteralPath $targetAbs -PathType Leaf)) {
       Out-NG "MANAGED_NOTE_NOT_FOUND" "突合対象の正式ノート(UUID一致・顧客フォルダ直下)が見つかりません。(Folder: $foundFolder / noteType: $noteType / Expected: $canonicalFile)"
    }

    $compareDir = Join-Path $custRoot $foundFolder

    $scriptName = "diff_checker.py"
    if ($noteType -match "事故一覧") { $scriptName = "diff_checker_jiko.py" }

    $pyScript = Join-Path $PSScriptRoot $scriptName
    if (-not (Test-Path -LiteralPath $pyScript)) { throw "Pythonスクリプトが見つかりません: $pyScript" }

    $csvPath = $payload.csvPath
    if (-not (Test-Path -LiteralPath $csvPath)) { throw "CSVファイルが見つかりません: $csvPath" }

    $logOut = Join-Path $env:TEMP "_py_out.log"
    $logErr = Join-Path $env:TEMP "_py_err.log"
    $python = Resolve-PythonExecutable
    $pythonArgs = @($python.PrefixArguments) + @($pyScript, $csvPath, $targetAbs)

    Write-Host "--- [COMPARE START] ---" -ForegroundColor Cyan
    Write-Host "Script : $scriptName"
    Write-Host "Target : $targetAbs"

    Push-Location -LiteralPath $compareDir
    try {
      & $python.FilePath @pythonArgs 1> $logOut 2> $logErr
      $pythonExitCode = $LASTEXITCODE
    } finally {
      Pop-Location
    }

    if ($pythonExitCode -ne 0) {
      Write-Host "Log (Err): $(Get-Content $logErr -Raw -ErrorAction SilentlyContinue)" -ForegroundColor Red
      throw "Pythonスクリプトエラー (ExitCode: $pythonExitCode)"
    }

    $resultFileName = "突合結果(契約).md"
    if ($noteType -match "事故一覧") { $resultFileName = "突合結果(事故).md" }

    $resultFilePath = Join-Path $compareDir $resultFileName

    if (-not (Test-Path -LiteralPath $resultFilePath)) {
         throw "結果ファイルが生成されませんでした: $resultFilePath"
    }

    $rel = Get-RelPath $VaultRoot $resultFilePath
    $lw  = (Get-Item -LiteralPath $resultFilePath).LastWriteTime

    # 標準URIスキームでファイルを開く
    Open-ObsidianFile $VaultRoot $rel

    # FileMaker返却用URI
    $url = Get-ObsidianOpenUrl $VaultRoot $rel

    Out-OK "OPENED" $url $rel ($lw.ToString("yyyy-MM-ddTHH:mm:ss")) "COMPARE_DONE"
  }
  # ▲▲▲ COMPARE モード 終了 ▲▲▲
    return
  } finally {
    if ($null -ne $lock) {
      $lock.Close()
      $lock.Dispose()
    }
  }
}

try {
  if ([string]::IsNullOrWhiteSpace($PayloadB64)) {
    if (-not (Test-Path -LiteralPath $PayloadFile)) { Out-NG "ERROR" "Payload not found." }
    $PayloadB64 = (Get-Content -LiteralPath $PayloadFile -Raw -Encoding UTF8).Trim()
    try { Remove-Item -LiteralPath $PayloadFile -Force -ErrorAction SilentlyContinue } catch {}
  }

  $payload = ConvertTo-Hashtable (ConvertFrom-Json (From-Base64Any $PayloadB64))
  if ($null -eq $payload -or -not ($payload -is [hashtable])) {
    Out-NG "ERROR" "Invalid payload format."
    exit 0
  }

  $rawVaultRootGlobal = if ($payload.ContainsKey('VaultRoot')) { ([string]$payload["VaultRoot"]).Trim() } else { "" }
  $actionName = if (($null -ne $payload) -and ($payload -is [hashtable]) -and $payload.ContainsKey('action')) { [string]$payload.action } else { "" }
  $modeName = if (($null -ne $payload) -and ($payload -is [hashtable]) -and $payload.ContainsKey('MODE')) { [string]$payload.MODE } else { "" }
  $reqIdGlobal = if (($null -ne $payload) -and ($payload -is [hashtable]) -and $payload.ContainsKey('requestId')) { [string]$payload.requestId } else { "" }

  $vaultRootGlobal = if (-not [string]::IsNullOrWhiteSpace($rawVaultRootGlobal)) { Resolve-Win32CanonicalPath $rawVaultRootGlobal } else { $null }
  $isValidVault = (-not [string]::IsNullOrWhiteSpace($vaultRootGlobal)) -and (Test-Path -LiteralPath $vaultRootGlobal -PathType Container)

  if (-not $isValidVault) {
    if ($actionName -in @("PLAN_CUSTOMER_FOLDER_MERGE", "APPLY_CUSTOMER_FOLDER_MERGE")) {
      Write-Output (New-MergeResponse $reqIdGlobal "NG" "INVALID_REQUEST" "VaultRootが存在しないか、正規化に失敗しました: $rawVaultRootGlobal")
      exit 0
    }
    if ($actionName -eq "UPDATE_CUSTOMER_IDENTITY") {
      $code = if ([string]::IsNullOrWhiteSpace($rawVaultRootGlobal)) { "MISSING_REQUIRED_FIELD" } else { "INVALID_REQUEST" }
      Write-Output (New-UCIResponse $reqIdGlobal "NG" $code "VaultRootが存在しないか、正規化に失敗しました: $rawVaultRootGlobal")
      exit 0
    }
    Out-NG "ERROR" "VaultRoot not found: $rawVaultRootGlobal"
  }

  $payload["VaultRoot"] = $vaultRootGlobal

  if ($actionName -eq "PLAN_CUSTOMER_FOLDER_MERGE") {
    Invoke-PlanCustomerFolderMerge $payload
    exit 0
  }

  if ($actionName -eq "APPLY_CUSTOMER_FOLDER_MERGE") {
    Invoke-ApplyCustomerFolderMerge $payload
    exit 0
  }

  if ($actionName -eq "UPDATE_CUSTOMER_IDENTITY") {
    try {
      Invoke-UpdateCustomerIdentity $payload
    } catch {
      $reqIdSafe = $null
      try {
        if ($payload.requestId -is [string] -and -not [string]::IsNullOrWhiteSpace($payload.requestId)) {
          $reqIdSafe = $payload.requestId
        }
      } catch {}
      Write-Output (New-UCIResponse $reqIdSafe "NG" "EXECUTION_FAILED" "処理中に予期しないエラーが発生しました。")
    }
    exit 0
  }

  $modeName = if ($payload.ContainsKey("MODE")) { [string]$payload.MODE } else { "" }
  if ($modeName -eq "COMPARE") {
    Invoke-CompareObsidianNotes $payload
    exit 0
  }

  if ($modeName -eq "CHECK") {
    Invoke-CheckObsidianNotes $payload
    exit 0
  }

  if ($modeName -eq "OPEN" -or [string]::IsNullOrWhiteSpace($modeName)) {
    Invoke-OpenObsidianNotes $payload
    exit 0
  }

} catch {
  $ex = $_.Exception
  $msg = "MSG=" + $ex.Message + " / LINE=" + $_.InvocationInfo.ScriptLineNumber + " / CMD=" + $_.InvocationInfo.MyCommand
  Out-NG "ERROR" $msg
}