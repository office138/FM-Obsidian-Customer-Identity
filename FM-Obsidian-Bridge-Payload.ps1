<# =====================================================
FM-Obsidian-Bridge-Payload.ps1
Ver: 9.0.3 (2026-08-13) - Folder Confirmation Contract Fix

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
                    $check = $potentialVal -replace "[*]", "" -replace ",", "" -replace "[\s　]", ""
                    if ($check -match "^\d+$") { return ($potentialVal -replace "[*]", "") }
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
  # 単一要素・空配列のPowerShell自動アンロールを避けるため、既存Get-YamlHeaderLinesと同様に
  # 単項カンマ演算子(,)で配列を1段階分ラップしてから返す。
  $matched = [System.Collections.ArrayList]::new()
  if ([string]::IsNullOrWhiteSpace($uuid)) { return ,$matched.ToArray() }
  $candidates = Get-ChildItem -LiteralPath $folderPath -Filter "${iconPrefix}_*.md" -File -ErrorAction SilentlyContinue
  foreach ($f in $candidates) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if (-not [string]::IsNullOrWhiteSpace($u) -and $u.ToUpperInvariant() -eq $uuid.ToUpperInvariant()) {
      [void]$matched.Add($f.FullName)
    }
  }
  return ,$matched.ToArray()
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
  if ([string]::IsNullOrWhiteSpace($uuid)) { return ,$matched.ToArray() }
  $candidates = Get-ChildItem -LiteralPath $rootPath -Filter "${iconPrefix}_*.md" -File -Recurse -ErrorAction SilentlyContinue
  foreach ($f in $candidates) {
    $hdr = Get-YamlHeaderLines $f.FullName
    if ($null -eq $hdr) { continue }
    $u = Get-YamlScalarValue $hdr "UUID:"
    if (-not [string]::IsNullOrWhiteSpace($u) -and $u.ToUpperInvariant() -eq $uuid.ToUpperInvariant()) {
      [void]$matched.Add($f.FullName)
    }
  }
  return ,$matched.ToArray()
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
  if ([string]::IsNullOrWhiteSpace($uuid)) { return ,$outOfScope.ToArray() }
  $all = @(Get-UuidNoteTypeMatchesInTree $folderPath $iconPrefix $uuid)
  foreach ($p in $all) {
    $parent = Split-Path -Parent $p
    if (-not [string]::Equals($parent, $folderPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      [void]$outOfScope.Add($p)
    }
  }
  return ,$outOfScope.ToArray()
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
    return ,$names.ToArray()
  }
  $files = Get-ChildItem -LiteralPath $folderPath -Filter "${iconPrefix}_*.md" -File -ErrorAction SilentlyContinue
  foreach ($f in $files) { [void]$names.Add($f.Name) }
  return ,$names.ToArray()
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

  $newFolderNameCheck = Sanitize-LeafName $companyNameRaw "NO_NAME"
  if ($newFolderNameCheck -eq "NO_NAME") {
    Write-Output (New-UCIResponse $requestIdRaw "NG" "INVALID_CUSTOMER_NAME" "companyNameRawから安全なフォルダ名を生成できません。")
    return
  }

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
}

try {
  if ([string]::IsNullOrWhiteSpace($PayloadB64)) {
    if (-not (Test-Path -LiteralPath $PayloadFile)) { Out-NG "ERROR" "Payload not found." }
    $PayloadB64 = (Get-Content -LiteralPath $PayloadFile -Raw -Encoding UTF8).Trim()
    try { Remove-Item -LiteralPath $PayloadFile -Force -ErrorAction SilentlyContinue } catch {}
  }

  $payload = ConvertTo-Hashtable (ConvertFrom-Json (From-Base64Any $PayloadB64))

  # UPDATE_CUSTOMER_IDENTITY: 既存Assert-ObsidianReady・MODE判定より前で分岐。
  # JSON応答をstdoutへ出力した後、既存処理へは流れず終了する(既存Out-OK/Out-NGは使用しない)。
  # 回帰修正(2026-07-29): 従来payload(EXT-obs_OBSノート-開く由来)にはactionキーが存在しないため、
  # StrictMode下で$payload.actionを直接参照すると「プロパティ'action'が見つかりません」で例外になる。
  # $payloadはConvertTo-Hashtableにより必ず[hashtable]化されるため、ContainsKey('action')で
  # 存在確認してから読み取る(PSObject.PropertiesはHashtableの動的キーを列挙しないため使用しない)。
  $uciActionValue = $null
  if (($null -ne $payload) -and ($payload -is [hashtable]) -and $payload.ContainsKey('action')) {
    $uciActionValue = [string]$payload.action
  }
  if ($uciActionValue -eq "UPDATE_CUSTOMER_IDENTITY") {
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

  $VaultRoot = ([string]$payload.VaultRoot).Trim()
  if (-not (Test-Path -LiteralPath $VaultRoot)) { Out-NG "ERROR" "VaultRoot not found." }
  Assert-ObsidianReady

  $custRoot  = Join-Path $VaultRoot "01_顧客"
  $indexPath = Join-Path $VaultRoot "scripts\obsidian_index.json"
  if (-not (Test-Path -LiteralPath $custRoot)) { New-Item -ItemType Directory -Path $custRoot -Force | Out-Null }

  $index = Load-IndexSafe $indexPath

  $nameRaw  = [string]$payload.companyNameRaw
  $rank     = [string]$payload.RANK
  $ceo      = [string]$payload.CEO
  $ruby     = [string]$payload.RUBY
  $uuid     = [string]$payload.pk_CLIENT

  # ---- 不正UUIDフォールバックの廃止 (2026-07-30) ----
  if (-not (Test-UciUuidFormat $uuid)) {
      Out-NG "INVALID_UUID_FORMAT" "pk_CLIENTがUUID形式ではありません。"
  }
  $noteType = [string]$payload.noteType

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
      $outOfScopeNotes = @(Get-UciOutOfScopeManagedNotes $currentFolderFull $prefixStr $uuid)
      $uciMatches = @(Get-UuidNoteTypeMatches $currentFolderFull $prefixStr $uuid)

      if ($uciMatches.Count -ge 2) {
          Out-NG "DUPLICATE_NOTE_TYPE" "同一UUID・同一noteTypeの既存ノートが顧客フォルダ直下に複数見つかりました。安全のため処理を中止します。(Folder: $foundFolder / noteType: $noteType / 件数: $($uciMatches.Count))"
      }
      if ($outOfScopeNotes.Count -ge 1) {
          Out-NG "MANAGED_NOTE_OUT_OF_SCOPE" "管理対象ノートと同一UUID・同一noteTypeのノートが顧客フォルダのサブフォルダ内に存在します。自動採用・自動作成は行わず処理を中止します。(Folder: $foundFolder / noteType: $noteType / Path: $($outOfScopeNotes[0]))"
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
  if ($payload.MODE -eq "COMPARE") {
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

} catch {
  $ex = $_.Exception
  $msg = "MSG=" + $ex.Message + " / LINE=" + $_.InvocationInfo.ScriptLineNumber + " / CMD=" + $_.InvocationInfo.MyCommand
  Out-NG "ERROR" $msg
}
