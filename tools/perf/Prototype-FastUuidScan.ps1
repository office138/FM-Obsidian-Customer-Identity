<#
=====================================================================
Prototype-FastUuidScan.ps1  (提案用プロトタイプ / 本体未組込み)

FM-Obsidian-Bridge-Payload.ps1 の検索ホットスポット
  - Get-UciUuidMatchedCustomerFolders  (01_顧客 全再帰: UUID→顧客フォルダ)
  - Get-UciFolderEvidence              (顧客フォルダ再帰: evidence判定)
  - Get-UuidNoteTypeMatchesInTree      (全再帰: noteType接頭辞+UUID)
を「判定規則・戻り値契約を変えずに」高速化した参照実装。

高速化の要点:
  (1) Get-ChildItem -Recurse → DirectoryInfo.GetFiles/GetDirectories による
      同一訪問順の直接列挙(PSObjectラップ無し)                   (列挙 ~5-8x)
  (2) Get-YamlHeaderLines(Test-Path+Get-Item+ReadAllLines 全文) →
      StreamReader で frontmatter 終端 "---" までしか読まない        (~3.5x)
  (3) 任意: (path, size, mtime) をキーにした増分UUIDキャッシュ。
      毎回ファイル列挙は行う(=Vault全体の衝突検出は維持)が、
      変更のないファイルは再読込しない。                             (~20x+)

安全性についての注記:
  - frontmatter の境界規則は Get-YamlHeaderLines と同一
    (1行目 "---" / 次の Trim()=="---" 行で終端 / 終端なし→InvalidYaml=$null)。
  - UUID: キーの取り出しは Get-YamlScalarValue "UUID:" と同一
    (最初に一致した行、前後の "…" / '…' を1組だけ剥がす)。
  - 本文中のUUIDは一切見ない(現行と同じ)。
=====================================================================
#>
Set-StrictMode -Version Latest

# ---------------------------------------------------------------
# frontmatter だけを読んで UUID: を返す。
# 戻り値: @{ State = "NoFrontmatter" | "Unclosed" | "Ok"; Uuid = [string] }
#   NoFrontmatter ... 1行目が "---" でない / 空ファイル       (現行: ,@() → UUID "")
#   Unclosed      ... 開始 "---" はあるが終端 "---" が無い      (現行: $null → InvalidYaml)
#   Ok            ... frontmatter 正常。Uuid は "" の場合もある
# ---------------------------------------------------------------
function Read-YamlUuidFast([string]$path) {
  $sr = $null
  try {
    $sr = [System.IO.StreamReader]::new($path, [System.Text.UTF8Encoding]::new($false), $true, 4096)
    $first = $sr.ReadLine()
    if ($null -eq $first) { return @{ State = "NoFrontmatter"; Uuid = "" } }
    if ($first.Trim() -ne "---") { return @{ State = "NoFrontmatter"; Uuid = "" } }
    $uuid = ""
    $found = $false
    while ($null -ne ($line = $sr.ReadLine())) {
      $t = $line.Trim()
      if ($t -eq "---") { return @{ State = "Ok"; Uuid = $uuid } }
      if (-not $found -and $t.StartsWith("UUID:")) {
        $v = $t.Substring(5).Trim()
        if ($v.Length -ge 2 -and (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'")))) {
          $v = $v.Substring(1, $v.Length - 2)
        }
        $uuid = $v; $found = $true
      }
    }
    return @{ State = "Unclosed"; Uuid = "" }
  } finally {
    if ($null -ne $sr) { $sr.Dispose() }
  }
}


# ---------------------------------------------------------------
# Get-ChildItem -Recurse -File と同じ訪問順(各ディレクトリ: ファイル名順 → サブディレクトリ名順で再帰)
# で FileInfo を列挙する。"最初に見つかった不正ファイル" を detailPath として返す
# Get-UciFolderEvidence 等の診断出力を現行と一致させるために順序を固定する。
# 再解析ポイント(ジャンクション/シンボリックリンク)のディレクトリへは降下しない
# (Get-ChildItem -Recurse は既定で降下するが、安全側に振る。必要なら $FollowReparse で切替)。
# ---------------------------------------------------------------
function Get-MdFilesOrdered {
  param([Parameter(Mandatory)][string]$RootPath, [string]$Pattern = "*.md", [switch]$FollowReparse)
  # 訪問順: 各ディレクトリで ファイル(名前順) → サブディレクトリ(名前順)へ再帰 = Get-ChildItem -Recurse と同じ。
  # 名前順の比較器:
  #   Windows(NTFS) ... FindFirstFile が返す順 = 大文字化ordinal。Get-ChildItemはその順をそのまま返す。
  #   非Windows     ... PowerShell 7 の FileSystemProvider が CurrentCulture で並べ替えるのでそれに合わせる。
  # ※ ソートは .NET の Array.Sort(keys, items, comparer) を使う(scriptblock比較器はPowerShellでは桁違いに遅い)。
  $cmp = if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)) {
           [System.StringComparer]::OrdinalIgnoreCase } else { [System.StringComparer]::CurrentCulture }
  $out = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
  $stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
  $stack.Push([System.IO.DirectoryInfo]::new($RootPath))
  while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    $files = $null; $subs = $null
    try {
      $files = $dir.GetFiles($Pattern, [System.IO.SearchOption]::TopDirectoryOnly)
      $subs  = $dir.GetDirectories()
    } catch { continue }   # -ErrorAction SilentlyContinue 相当
    if ($files.Length -gt 1) {
      $keys = [string[]]::new($files.Length); for ($i = 0; $i -lt $files.Length; $i++) { $keys[$i] = $files[$i].Name }
      [Array]::Sort($keys, $files, $cmp)
    }
    foreach ($f in $files) { $out.Add($f) }
    if ($subs.Length -gt 1) {
      $dkeys = [string[]]::new($subs.Length); for ($i = 0; $i -lt $subs.Length; $i++) { $dkeys[$i] = $subs[$i].Name }
      [Array]::Sort($dkeys, $subs, $cmp)
    }
    for ($i = $subs.Length - 1; $i -ge 0; $i--) {
      $d = $subs[$i]
      if (-not $FollowReparse -and (($d.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) { continue }
      $stack.Push($d)
    }
  }
  return $out
}

# ---------------------------------------------------------------
# 増分UUIDキャッシュ (任意 / Tier2)
#   cache: path(大文字化) -> @{ Size; Ticks; State; Uuid }
#   毎回 全ファイルを列挙し、Size/LastWriteTicks が一致するものだけ再利用。
#   消えたファイルはキャッシュから落とす(列挙結果に無いキーは書き戻さない)。
# ---------------------------------------------------------------
function Get-VaultUuidTable {
  param(
    [Parameter(Mandatory)][string]$RootPath,
    [string]$CachePath = $null
  )
  $old = @{}
  if ($CachePath -and (Test-Path -LiteralPath $CachePath)) {
    try {
      $raw = [System.IO.File]::ReadAllText($CachePath)
      $json = ConvertFrom-Json $raw
      foreach ($p in $json.PSObject.Properties) {
        $old[$p.Name] = @{ Size = [long]$p.Value.s; Ticks = [long]$p.Value.t; State = [string]$p.Value.st; Uuid = [string]$p.Value.u }
      }
    } catch { $old = @{} }
  }
  $new = @{}
  $rows = [System.Collections.Generic.List[object]]::new()
  $rootInfo = [System.IO.DirectoryInfo]::new($RootPath)
  $hit = 0; $miss = 0
  foreach ($fi in (Get-MdFilesOrdered -RootPath $rootInfo.FullName)) {
    $key = $fi.FullName.ToUpperInvariant()
    $size = $fi.Length; $ticks = $fi.LastWriteTimeUtc.Ticks
    $entry = $null
    if ($old.ContainsKey($key)) {
      $o = $old[$key]
      if ($o.Size -eq $size -and $o.Ticks -eq $ticks) { $entry = $o; $hit++ }
    }
    if ($null -eq $entry) {
      $r = Read-YamlUuidFast $fi.FullName
      $entry = @{ Size = $size; Ticks = $ticks; State = $r.State; Uuid = $r.Uuid }
      $miss++
    }
    $new[$key] = $entry
    $rows.Add([PSCustomObject]@{ Path = $fi.FullName; Dir = $fi.DirectoryName; State = $entry.State; Uuid = $entry.Uuid })
  }
  if ($CachePath) {
    $out = @{}
    foreach ($k in $new.Keys) { $e = $new[$k]; $out[$k] = @{ s = $e.Size; t = $e.Ticks; st = $e.State; u = $e.Uuid } }
    $tmp = $CachePath + ".tmp"
    [System.IO.File]::WriteAllText($tmp, ($out | ConvertTo-Json -Compress -Depth 3), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Copy($tmp, $CachePath, $true)
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
  return @{ Rows = $rows; CacheHit = $hit; CacheMiss = $miss }
}

# ---------------------------------------------------------------
# Get-UciUuidMatchedCustomerFolders の高速版 (戻り値契約は同一)
#   folders    : DirectoryInfo[] (01_顧客直下の顧客フォルダ、重複なし)
#   unresolved : 01_顧客直下として解決できないノートの最初のパス / $null
# 判定: UUID形式正 かつ 完全一致 のみ(現行と同じ)。
# ---------------------------------------------------------------
function Get-UciUuidMatchedCustomerFoldersFast {
  param(
    [Parameter(Mandatory)][string]$CustRootPath,
    [Parameter(Mandatory)][string]$PkClient,
    [string]$CachePath = $null,
    $Rows = $null   # 既に取得済みの Get-VaultUuidTable().Rows を渡すと再走査しない
  )
  $out = @{ folders = @(); unresolved = $null }
  if ([string]::IsNullOrWhiteSpace($PkClient)) { return $out }
  $custRootInfo = Get-Item -LiteralPath $CustRootPath
  $rootFull = $custRootInfo.FullName
  if ($null -eq $Rows) { $Rows = (Get-VaultUuidTable -RootPath $rootFull -CachePath $CachePath).Rows }
  $target = $PkClient.ToUpperInvariant()
  $map = [ordered]@{}
  foreach ($r in $Rows) {
    if ($r.State -ne "Ok") { continue }
    $u = $r.Uuid
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    if ($u -notmatch '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$') { continue }
    if ($u.ToUpperInvariant() -ne $target) { continue }
    # 01_顧客 直下の子フォルダへ帰属解決 (Resolve-UciDirectChildFolder と同じ .Parent 走査)
    $dir = [System.IO.DirectoryInfo]::new($r.Dir)
    $child = $null
    while ($null -ne $dir) {
      $parent = $dir.Parent
      if ($null -ne $parent -and [string]::Equals($parent.FullName, $rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { $child = $dir; break }
      $dir = $parent
    }
    if ($null -eq $child) { if ($null -eq $out.unresolved) { $out.unresolved = $r.Path }; continue }
    $key = $child.FullName.ToUpperInvariant()
    if (-not $map.Contains($key)) { $map[$key] = $child }
  }
  $out.folders = @($map.Values)
  return $out
}

# ---------------------------------------------------------------
# Get-UciFolderEvidence の高速版 (戻り値契約・優先順位は同一)
#   InvalidYaml > Conflict > InvalidUuid > Matched > NoEvidence
# ---------------------------------------------------------------
function Get-UciFolderEvidenceFast {
  param(
    [Parameter(Mandatory)][string]$FolderPath,
    [Parameter(Mandatory)][string]$PkClient,
    $Rows = $null
  )
  $result = @{ state = "NoEvidence"; matchedCount = 0; detailPath = $null; detailValue = $null }
  $folderFull = (Get-Item -LiteralPath $FolderPath).FullName
  if ($null -eq $Rows) { $Rows = (Get-VaultUuidTable -RootPath $folderFull).Rows }
  else {
    $prefix = $folderFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $Rows = @($Rows | Where-Object { $_.Path.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })
  }
  $target = $PkClient.ToUpperInvariant()
  $matched = 0; $invalidYaml = $null; $conflictP = $null; $conflictV = $null; $invUuidP = $null; $invUuidV = $null
  foreach ($r in $Rows) {
    if ($r.State -eq "Unclosed") { if ($null -eq $invalidYaml) { $invalidYaml = $r.Path }; continue }
    $u = $r.Uuid
    if ([string]::IsNullOrWhiteSpace($u)) { continue }
    if ($u -notmatch '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$') {
      if ($null -eq $invUuidP) { $invUuidP = $r.Path; $invUuidV = $u }; continue
    }
    if ($u.ToUpperInvariant() -eq $target) { $matched++ } else { if ($null -eq $conflictP) { $conflictP = $r.Path; $conflictV = $u } }
  }
  $result.matchedCount = $matched
  if ($invalidYaml) { $result.state = "InvalidYaml"; $result.detailPath = $invalidYaml; return $result }
  if ($conflictP)   { $result.state = "Conflict"; $result.detailPath = $conflictP; $result.detailValue = $conflictV; return $result }
  if ($invUuidP)    { $result.state = "InvalidUuid"; $result.detailPath = $invUuidP; $result.detailValue = $invUuidV; return $result }
  if ($matched -ge 1) { $result.state = "Matched" }
  return $result
}

# ---------------------------------------------------------------
# Get-UuidNoteTypeMatchesInTree の高速版 (ファイル名パターン + UUID完全一致)
# ---------------------------------------------------------------
function Get-UuidNoteTypeMatchesInTreeFast {
  param([string]$RootPath, [string]$IconPrefix, [string]$Uuid, $Rows = $null)
  $matched = [System.Collections.ArrayList]::new()
  if ([string]::IsNullOrWhiteSpace($Uuid)) { return $matched.ToArray() }
  $target = $Uuid.ToUpperInvariant()
  if ($null -eq $Rows) {
    $Rows = [System.Collections.Generic.List[object]]::new()
    foreach ($fi in (Get-MdFilesOrdered -RootPath $RootPath -Pattern "${IconPrefix}_*.md")) {
      $r = Read-YamlUuidFast $fi.FullName
      $Rows.Add([PSCustomObject]@{ Path = $fi.FullName; State = $r.State; Uuid = $r.Uuid })
    }
  } else {
    $Rows = @($Rows | Where-Object { [System.IO.Path]::GetFileName($_.Path).StartsWith("${IconPrefix}_") -and $_.Path.EndsWith(".md", [System.StringComparison]::OrdinalIgnoreCase) })
  }
  foreach ($r in $Rows) {
    if ($r.State -eq "Unclosed") { continue }
    if (-not [string]::IsNullOrWhiteSpace($r.Uuid) -and $r.Uuid.ToUpperInvariant() -eq $target) { [void]$matched.Add($r.Path) }
  }
  return $matched.ToArray()
}
