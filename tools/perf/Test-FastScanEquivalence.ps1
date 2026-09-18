<#
.SYNOPSIS
  現行実装(本体からAST抽出)と Prototype-FastUuidScan.ps1 の結果が
  完全に一致することを確認し、実行時間を比較する。本体は変更しない。
#>
param(
  [string]$VaultRoot = "/tmp/synthvault",
  [string]$Payload = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "FM-Obsidian-Bridge-Payload.ps1")
)
$ErrorActionPreference = "Stop"
$custRoot = Join-Path $VaultRoot "01_顧客"
$enc = [System.Text.UTF8Encoding]::new($false)

# --- 本体関数の抽出 ---
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Payload, [ref]$tokens, [ref]$errors)
$wanted = @("Get-YamlHeaderLines","Get-YamlScalarValue","Test-UciUuidFormat","Resolve-UciDirectChildFolder",
            "Get-UciUuidMatchedCustomerFolders","Get-UciFolderEvidence","Get-UuidNoteTypeMatchesInTree","Get-IconPrefix")
foreach ($f in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $n.Name }, $false)) {
  . ([scriptblock]::Create($f.Extent.Text))
}
. (Join-Path $PSScriptRoot "Prototype-FastUuidScan.ps1")

# --- エッジケース用の顧客フォルダを追加 ---
$edgeUuid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
$edgeDir = Join-Path $custRoot "EDGE顧客_[AAAAAAAA]"
Remove-Item -LiteralPath $edgeDir -Recurse -Force -ErrorAction SilentlyContinue
[void][System.IO.Directory]::CreateDirectory((Join-Path $edgeDir "sub"))
$pfx = Get-IconPrefix "契約一覧"
[System.IO.File]::WriteAllText((Join-Path $edgeDir "${pfx}_EDGE_[AAAAAAAA].md"), "---`ntags:`n  - x`nUUID: `"$edgeUuid`"`n---`nbody", $enc)   # quoted UUID
[System.IO.File]::WriteAllText((Join-Path $edgeDir "🟡契約_EDGE.md"), "---`nUUID: '$($edgeUuid.ToLower())'`n---`n", $enc)              # lowercase quoted
[System.IO.File]::WriteAllText((Join-Path $edgeDir "no_frontmatter.md"), "# no yaml`nUUID: $edgeUuid`n", $enc)                          # body UUID must be ignored
[System.IO.File]::WriteAllText((Join-Path $edgeDir "empty.md"), "", $enc)
[System.IO.File]::WriteAllText((Join-Path $edgeDir "sub/${pfx}_SUB_[AAAAAAAA].md"), "---`nUUID: $edgeUuid`n---`n", $enc)                # out-of-scope
[System.IO.File]::WriteAllText((Join-Path $edgeDir "bom.md"), "---`r`nUUID: $edgeUuid`r`n---`r`n", [System.Text.UTF8Encoding]::new($true)) # BOM + CRLF
$unclosedDir = Join-Path $custRoot "UNCLOSED顧客"
Remove-Item -LiteralPath $unclosedDir -Recurse -Force -ErrorAction SilentlyContinue
[void][System.IO.Directory]::CreateDirectory($unclosedDir)
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "a.md"), "---`nUUID: 11111111-2222-3333-4444-555555555555`nno end", $enc)
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "b.md"), "---`nUUID: not-a-uuid`n---`n", $enc)
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "c.md"), "---`nUUID: 11111111-2222-3333-4444-555555555555`n---`n", $enc)
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "d.md"), "---`nUUID: 99999999-2222-3333-4444-555555555555`n---`n", $enc)
# 01_顧客 直下に直接置かれたノート(unresolved ケース)
[System.IO.File]::WriteAllText((Join-Path $custRoot "stray_[AAAAAAAA].md"), "---`nUUID: $edgeUuid`n---`n", $enc)

$uuids = [System.IO.File]::ReadAllLines((Join-Path $VaultRoot "uuids.txt"))
$cases = @($uuids[3], $uuids[700], $uuids[1499], $edgeUuid, "11111111-2222-3333-4444-555555555555", "00000000-0000-0000-0000-000000000000")

function Canon($o) { ($o | ConvertTo-Json -Depth 6 -Compress) }
$pass = 0; $fail = 0
function Check([string]$label, $a, $b) {
  if ((Canon $a) -eq (Canon $b)) { $script:pass++; Write-Host ("  PASS  {0}" -f $label) }
  else { $script:fail++; Write-Host ("  FAIL  {0}`n    orig={1}`n    fast={2}" -f $label, (Canon $a), (Canon $b)) -ForegroundColor Red }
}

$cachePath = Join-Path $VaultRoot "scripts/uuid_cache.json"
Remove-Item -LiteralPath $cachePath -Force -ErrorAction SilentlyContinue

Write-Host "=== Equivalence: Get-UciUuidMatchedCustomerFolders ==="
$tOrig = 0.0; $tFast = 0.0; $tCache = 0.0
foreach ($u in $cases) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew(); $o = Get-UciUuidMatchedCustomerFolders $custRoot $u; $sw.Stop(); $tOrig += $sw.Elapsed.TotalMilliseconds
  $sw = [System.Diagnostics.Stopwatch]::StartNew(); $f = Get-UciUuidMatchedCustomerFoldersFast -CustRootPath $custRoot -PkClient $u; $sw.Stop(); $tFast += $sw.Elapsed.TotalMilliseconds
  $sw = [System.Diagnostics.Stopwatch]::StartNew(); $c = Get-UciUuidMatchedCustomerFoldersFast -CustRootPath $custRoot -PkClient $u -CachePath $cachePath; $sw.Stop(); $tCache += $sw.Elapsed.TotalMilliseconds
  $oN = @{ folders = @(@($o.folders) | ForEach-Object { $_.FullName } | Sort-Object); unresolved = $o.unresolved }
  $fN = @{ folders = @(@($f.folders) | ForEach-Object { $_.FullName } | Sort-Object); unresolved = $f.unresolved }
  $cN = @{ folders = @(@($c.folders) | ForEach-Object { $_.FullName } | Sort-Object); unresolved = $c.unresolved }
  Check "$u  (fast)"  $oN $fN
  Check "$u  (cache)" $oN $cN
}
Write-Host ("  time: orig={0:N0}ms  fast={1:N0}ms  cached={2:N0}ms  (6 lookups; cache cold on 1st)" -f $tOrig, $tFast, $tCache)

Write-Host "`n=== Equivalence: Get-UciFolderEvidence ==="
$folders = @(Get-ChildItem -LiteralPath $custRoot -Directory | Select-Object -First 40) + @(Get-Item $edgeDir) + @(Get-Item $unclosedDir)
foreach ($d in $folders) {
  foreach ($u in @($cases[3], $cases[4], $cases[0])) {
    $o = Get-UciFolderEvidence $d.FullName $u
    $f = Get-UciFolderEvidenceFast -FolderPath $d.FullName -PkClient $u
    if ((Canon $o) -eq (Canon $f)) { $pass++ } else { $fail++; Write-Host ("  FAIL evidence {0} / {1}`n    orig={2}`n    fast={3}" -f $d.Name, $u, (Canon $o), (Canon $f)) -ForegroundColor Red }
  }
}
Write-Host ("  {0} folder x uuid combinations compared" -f ($folders.Count * 3))

Write-Host "`n=== Equivalence: Get-UuidNoteTypeMatchesInTree ==="
foreach ($u in $cases) {
  $o = @(Get-UuidNoteTypeMatchesInTree $custRoot $pfx $u | Sort-Object)
  $f = @(Get-UuidNoteTypeMatchesInTreeFast -RootPath $custRoot -IconPrefix $pfx -Uuid $u | Sort-Object)
  Check "$u" $o $f
}

Write-Host "`n=== Cache warm run (2nd call, nothing changed) ==="
$sw = [System.Diagnostics.Stopwatch]::StartNew(); $tbl = Get-VaultUuidTable -RootPath $custRoot -CachePath $cachePath; $sw.Stop()
Write-Host ("  Get-VaultUuidTable warm: {0:N0}ms  hit={1} miss={2}" -f $sw.Elapsed.TotalMilliseconds, $tbl.CacheHit, $tbl.CacheMiss)
# ファイルを1つ変更 → そのファイルだけ再読込されること
$touch = Join-Path $edgeDir "🟡契約_EDGE.md"
[System.IO.File]::WriteAllText($touch, "---`nUUID: $edgeUuid`nランク: B`n---`n", $enc)
$tbl2 = Get-VaultUuidTable -RootPath $custRoot -CachePath $cachePath
Write-Host ("  after 1 file modified: hit={0} miss={1}" -f $tbl2.CacheHit, $tbl2.CacheMiss)
if ($tbl2.CacheMiss -eq 1) { $pass++ } else { $fail++; Write-Host "  FAIL cache invalidation" -ForegroundColor Red }

# cleanup edge fixtures
Remove-Item -LiteralPath $edgeDir, $unclosedDir -Recurse -Force
Remove-Item -LiteralPath (Join-Path $custRoot "stray_[AAAAAAAA].md") -Force

Write-Host ("`nRESULT: pass={0} fail={1}" -f $pass, $fail)
if ($fail -gt 0) { exit 1 }
