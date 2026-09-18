<#
.SYNOPSIS
  FM-Obsidian-Bridge-Payload.ps1 のOPEN/CHECK経路で呼ばれる検索関数を
  本体から抽出(AST)して、合成Vault上で現行実装と最適化案の実行時間を比較する。
  本体ファイルは一切変更しない(read-only)。
#>
param(
  [string]$VaultRoot = "/tmp/synthvault",
  [string]$Payload = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "FM-Obsidian-Bridge-Payload.ps1"),
  [int]$Iterations = 3
)
$ErrorActionPreference = "Stop"
$custRoot = Join-Path $VaultRoot "01_顧客"
$uuids = [System.IO.File]::ReadAllLines((Join-Path $VaultRoot "uuids.txt"))
$targetUuid = $uuids[[int]($uuids.Count * 0.7)]   # 中盤~後半の顧客を対象

# ---- 本体から関数定義だけを抽出してロード(トップレベルの実行文は走らせない) ----
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Payload, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) { throw "Parse error: $($errors[0].Message)" }
$wanted = @("Get-YamlHeaderLines","Get-YamlScalarValue","Test-UciUuidFormat","Resolve-UciDirectChildFolder",
            "Get-UciUuidMatchedCustomerFolders","Get-UciFolderEvidence","Get-UuidNoteTypeMatches",
            "Get-UuidNoteTypeMatchesInTree","Get-UciOutOfScopeManagedNotes","Get-UciFuzzyNameCandidates",
            "Sanitize-LeafName","Normalize-ForMatch","Get-IconPrefix","Get-UciUuidSuffix","Get-CanonicalCustomerFolderName",
            "Read-YamlUuidFast","Get-MdFilesOrdered")
$funcs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $n.Name }, $false)
foreach ($f in $funcs) { . ([scriptblock]::Create($f.Extent.Text)) }
Write-Host ("Loaded {0} functions from payload (read-only)" -f $funcs.Count)

function Measure-Block([string]$label, [scriptblock]$sb) {
  $best = [double]::MaxValue; $res = $null
  for ($i = 0; $i -lt $Iterations; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = & $sb
    $sw.Stop()
    if ($sw.Elapsed.TotalMilliseconds -lt $best) { $best = $sw.Elapsed.TotalMilliseconds }
  }
  Write-Host ("{0,-62} {1,9:N1} ms" -f $label, $best)
  return $res
}

$prefixStr = Get-IconPrefix "契約一覧"
$md = @(Get-ChildItem -LiteralPath $custRoot -Filter *.md -File -Recurse)
Write-Host ("Vault: {0} md files / {1} customer folders`n" -f $md.Count, (Get-ChildItem -LiteralPath $custRoot -Directory).Count)

Write-Host "=== [A] 対象payloadの実装: Invoke-OpenObsidianNotes が1回の呼び出しで実行する検索 (v9.1.1では A1 が3回呼ばれる) ==="
$t = Measure-Block "A1 Get-UciUuidMatchedCustomerFolders (全再帰) x1" { Get-UciUuidMatchedCustomerFolders $custRoot $targetUuid }
$folder = @($t.folders)[0]
Measure-Block "A2 同関数 3回目まで (本体は同じ結果を3回計算)" { 1..3 | ForEach-Object { Get-UciUuidMatchedCustomerFolders $custRoot $targetUuid } } | Out-Null
Measure-Block "A3 Get-UciFolderEvidence (顧客フォルダ再帰)" { Get-UciFolderEvidence $folder.FullName $targetUuid } | Out-Null
Measure-Block "A4 Get-UuidNoteTypeMatches x2 + OutOfScope x2" {
  Get-UuidNoteTypeMatches $folder.FullName $prefixStr $targetUuid; Get-UciOutOfScopeManagedNotes $folder.FullName $prefixStr $targetUuid
  Get-UuidNoteTypeMatches $folder.FullName $prefixStr $targetUuid; Get-UciOutOfScopeManagedNotes $folder.FullName $prefixStr $targetUuid } | Out-Null
Measure-Block "A5 identity未確定時: Get-UuidNoteTypeMatchesInTree (全再帰)" { Get-UuidNoteTypeMatchesInTree $custRoot $prefixStr $targetUuid } | Out-Null
Measure-Block "A6 legacy候補: Normalize-ForMatch x 全フォルダ" {
  $folders = Get-ChildItem -LiteralPath $custRoot -Directory
  $m = Normalize-ForMatch "テスト顧客01050"
  @($folders | Where-Object { (Normalize-ForMatch $_.Name) -eq $m }) } | Out-Null

Write-Host "`n=== [B] 単体要素のコスト分解 ==="
Measure-Block "B1 Get-ChildItem -Recurse -Filter *.md (列挙のみ)" { @(Get-ChildItem -LiteralPath $custRoot -Filter *.md -File -Recurse) } | Out-Null
Measure-Block "B2 [IO.Directory]::EnumerateFiles (列挙のみ)" { @([System.IO.Directory]::EnumerateFiles($custRoot, "*.md", [System.IO.SearchOption]::AllDirectories)) } | Out-Null
Measure-Block "B3 全ファイル Get-YamlHeaderLines (ReadAllLines+Test-Path+Get-Item)" { foreach ($f in $md) { Get-YamlHeaderLines $f.FullName | Out-Null } } | Out-Null

# ---- 最適化案: frontmatterだけをストリームで読む ----
function Get-YamlUuidFast([string]$path) {
  # 先頭 "---" ~ 次の "---" の間だけ読み、"UUID:" を返す。閉じていなければ $null(=InvalidYaml)、frontmatterなし/UUIDなしは ""。
  $sr = [System.IO.StreamReader]::new($path, [System.Text.UTF8Encoding]::new($false), $true, 4096)
  try {
    $first = $sr.ReadLine()
    if ($null -eq $first -or $first.Trim() -ne "---") { return "" }
    $uuid = ""
    $guard = 0
    while ($null -ne ($line = $sr.ReadLine())) {
      $t = $line.Trim()
      if ($t -eq "---") { return $uuid }
      if ($t.StartsWith("UUID:")) {
        $v = $t.Substring(5).Trim()
        if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) { $v = $v.Substring(1, $v.Length-2) }
        if ($uuid -eq "") { $uuid = $v }
      }
      if (++$guard -gt 200) { break }   # 異常に長いfrontmatterは以降を通常読みへフォールバックさせる想定
    }
    return $null
  } finally { $sr.Dispose() }
}
Measure-Block "B4 全ファイル Get-YamlUuidFast (StreamReaderで先頭のみ)" { foreach ($f in $md) { Get-YamlUuidFast $f.FullName | Out-Null } } | Out-Null

Write-Host "`n=== [C] 最適化案の複合効果 ==="
$C1 = Measure-Block "C1 EnumerateFiles + YamlUuidFast で全Vault UUID走査 1回" {
  $hits = [System.Collections.Generic.List[string]]::new()
  foreach ($p in [System.IO.Directory]::EnumerateFiles($custRoot, "*.md", [System.IO.SearchOption]::AllDirectories)) {
    $u = Get-YamlUuidFast $p
    if ($u -and $u.Equals($targetUuid, [System.StringComparison]::OrdinalIgnoreCase)) { $hits.Add($p) }
  }
  $hits }
Write-Host ("    -> hits: {0}" -f $C1.Count)

# ---- 最適化案: UUIDインデックス(pk_CLIENT -> 顧客フォルダ) を使った O(1) 解決 + 検証 ----
$idxPath = Join-Path $VaultRoot "scripts/uuid_folder_index.json"
Measure-Block "C2 インデックス構築(全走査1回, 初回/バックグラウンド更新のみ)" {
  $map = @{}
  foreach ($p in [System.IO.Directory]::EnumerateFiles($custRoot, "*.md", [System.IO.SearchOption]::AllDirectories)) {
    $u = Get-YamlUuidFast $p
    if (-not $u) { continue }
    $rel = $p.Substring($custRoot.Length).TrimStart('/','\')
    $top = $rel.Split([char[]]@('/','\'))[0]
    $k = $u.ToUpperInvariant()
    if (-not $map.ContainsKey($k)) { $map[$k] = [System.Collections.Generic.HashSet[string]]::new() }
    [void]$map[$k].Add($top)
  }
  $out = @{}
  foreach ($k in $map.Keys) { $out[$k] = @($map[$k]) }
  [System.IO.File]::WriteAllText($idxPath, ($out | ConvertTo-Json -Compress), [System.Text.UTF8Encoding]::new($false))
} | Out-Null

Measure-Block "C3 インデックス参照 + 該当フォルダのみ再検証 (提案する通常経路)" {
  $idx = ConvertFrom-Json ([System.IO.File]::ReadAllText($idxPath)) -AsHashtable
  $cands = @($idx[$targetUuid.ToUpperInvariant()])
  $verified = @()
  foreach ($c in $cands) {
    $dir = Join-Path $custRoot $c
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $ok = $false
    foreach ($p in [System.IO.Directory]::EnumerateFiles($dir, "*.md", [System.IO.SearchOption]::AllDirectories)) {
      $u = Get-YamlUuidFast $p
      if ($u -and $u.Equals($targetUuid, [System.StringComparison]::OrdinalIgnoreCase)) { $ok = $true; break }
    }
    if ($ok) { $verified += $c }
  }
  $verified } | Out-Null
