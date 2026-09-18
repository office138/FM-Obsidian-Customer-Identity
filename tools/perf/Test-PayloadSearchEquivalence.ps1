<#
.SYNOPSIS
  v9.1.1 (参照コピー) と 現行 payload の検索 helper 4 関数の結果が完全一致することを検証する。
  両方のファイルから AST で関数定義のみを抽出し、合成 Vault + エッジケース fixture に対して比較する。
  さらに実行時間を比較する。本番 Vault には触れない。

.PARAMETER ReferencePayload  比較元(旧版) .ps1 のパス (例: git show <sha>:FM-Obsidian-Bridge-Payload.ps1 > ref.ps1)
.PARAMETER Payload           比較先(新版) .ps1 のパス
.PARAMETER VaultRoot         New-SyntheticVault.ps1 で生成した合成 Vault
#>
param(
  [Parameter(Mandatory)][string]$ReferencePayload,
  [string]$Payload = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "FM-Obsidian-Bridge-Payload.ps1"),
  [string]$VaultRoot = "/tmp/synthvault"
)
$ErrorActionPreference = "Stop"
$custRoot = Join-Path $VaultRoot "01_顧客"
$enc = [System.Text.UTF8Encoding]::new($false)

$wanted = @("Get-YamlHeaderLines","Get-YamlScalarValue","Test-UciUuidFormat","Resolve-UciDirectChildFolder",
            "Get-UciUuidMatchedCustomerFolders","Get-UciFolderEvidence","Get-UuidNoteTypeMatchesInTree",
            "Get-UciOutOfScopeManagedNotes","Get-IconPrefix","Read-YamlUuidFast","Get-MdFilesOrdered")

function Get-RenamedFunctionSource([string]$file, [string]$suffix) {
  # 対象関数の定義を AST から取り出し、関数名と内部呼び出しに suffix を付けたソースを返す(呼び出し側で script scope に dot-source する)
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) { throw "Parse error in ${file}: $($errors[0].Message)" }
  $defs = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $n.Name }, $false)
  $sb = [System.Text.StringBuilder]::new()
  $names = @()
  foreach ($d in $defs) {
    $text = $d.Extent.Text
    foreach ($w in $wanted) { $text = [regex]::Replace($text, "(?<![\w-])" + [regex]::Escape($w) + "(?![\w-])", ($w + $suffix)) }
    [void]$sb.AppendLine($text)
    $names += ($d.Name + $suffix)
  }
  return @{ Source = $sb.ToString(); Names = $names }
}
$refSrc = Get-RenamedFunctionSource $ReferencePayload "_REF"
$newSrc = Get-RenamedFunctionSource $Payload "_NEW"
. ([scriptblock]::Create($refSrc.Source))
. ([scriptblock]::Create($newSrc.Source))
$refNames = $refSrc.Names; $newNames = $newSrc.Names
Write-Host ("REF functions: {0}" -f ($refNames -join ", "))
Write-Host ("NEW functions: {0}" -f ($newNames -join ", "))
if ($newNames -notcontains "Read-YamlUuidFast_NEW" -or $newNames -notcontains "Get-MdFilesOrdered_NEW") { throw "NEW payload does not contain Tier 1 helpers" }

# ---- エッジケース fixture ----
$edgeUuid = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
$pfx = Get-IconPrefix_NEW "契約一覧"
$edgeDir = Join-Path $custRoot "EDGE顧客_[AAAAAAAA]"
$unclosedDir = Join-Path $custRoot "UNCLOSED顧客"
$strayNote = Join-Path $custRoot "stray_[AAAAAAAA].md"
function Cleanup { Remove-Item -LiteralPath $edgeDir, $unclosedDir -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $strayNote -Force -ErrorAction SilentlyContinue }
Cleanup
[void][System.IO.Directory]::CreateDirectory((Join-Path $edgeDir "sub"))
[System.IO.File]::WriteAllText((Join-Path $edgeDir "${pfx}_EDGE_[AAAAAAAA].md"), "---`ntags:`n  - x`nUUID: `"$edgeUuid`"`n---`nbody`nUUID: 99999999-9999-9999-9999-999999999999", $enc)  # quoted; body UUID ignored
[System.IO.File]::WriteAllText((Join-Path $edgeDir "🟡契約_EDGE.md"), "---`nUUID: '$($edgeUuid.ToLower())'`n---`n", $enc)                                       # lowercase quoted
[System.IO.File]::WriteAllText((Join-Path $edgeDir "no_frontmatter.md"), "# no yaml`nUUID: $edgeUuid`n", $enc)                                                  # no frontmatter
[System.IO.File]::WriteAllText((Join-Path $edgeDir "empty.md"), "", $enc)                                                                                        # empty
[System.IO.File]::WriteAllText((Join-Path $edgeDir "only_dashes.md"), "---`n", $enc)                                                                             # unclosed (start only)
[System.IO.File]::WriteAllText((Join-Path $edgeDir "sub/${pfx}_SUB_[AAAAAAAA].md"), "---`nUUID: $edgeUuid`n---`n", $enc)                                        # out-of-scope
[System.IO.File]::WriteAllText((Join-Path $edgeDir "bom_crlf.md"), "---`r`nUUID: $edgeUuid`r`n---`r`n", [System.Text.UTF8Encoding]::new($true))                # BOM + CRLF
[System.IO.File]::WriteAllText((Join-Path $edgeDir "indented.md"), "  ---  `n  UUID:   $edgeUuid   `n ---`n", $enc)                                              # whitespace around
[System.IO.File]::WriteAllText((Join-Path $edgeDir "dup_key.md"), "---`nUUID: $edgeUuid`nUUID: 11111111-2222-3333-4444-555555555555`n---`n", $enc)              # first key wins
[System.IO.File]::WriteAllText((Join-Path $edgeDir "empty_fm.md"), "---`n---`n", $enc)                                                                           # empty frontmatter
# Hidden 項目 (Windows: 属性 / Linux+pwsh: 先頭 "." が Hidden 扱い) は Get-ChildItem(-Force なし) と同様に対象外であること
[System.IO.File]::WriteAllText((Join-Path $edgeDir ".hidden_note.md"), "---`nUUID: 11111111-2222-3333-4444-555555555555`n---`n", $enc)
[void][System.IO.Directory]::CreateDirectory((Join-Path $edgeDir ".hiddendir"))
[System.IO.File]::WriteAllText((Join-Path $edgeDir ".hiddendir/h.md"), "---`nUUID: 11111111-2222-3333-4444-555555555555`n---`n", $enc)
try { (Get-Item -LiteralPath (Join-Path $edgeDir ".hidden_note.md") -Force).Attributes = [System.IO.FileAttributes]::Hidden } catch {}
try { (Get-Item -LiteralPath (Join-Path $edgeDir ".hiddendir") -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::Directory } catch {}
[void][System.IO.Directory]::CreateDirectory($unclosedDir)
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "a.md"), "---`nUUID: 11111111-2222-3333-4444-555555555555`nno end", $enc)                               # unclosed
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "b.md"), "---`nUUID: not-a-uuid`n---`n", $enc)                                                           # invalid uuid
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "c.md"), "---`nUUID: 11111111-2222-3333-4444-555555555555`n---`n", $enc)
[System.IO.File]::WriteAllText((Join-Path $unclosedDir "d.md"), "---`nUUID: 99999999-2222-3333-4444-555555555555`n---`n", $enc)
[System.IO.File]::WriteAllText($strayNote, "---`nUUID: $edgeUuid`n---`n", $enc)                                                                                 # unresolved

$uuids = [System.IO.File]::ReadAllLines((Join-Path $VaultRoot "uuids.txt"))
$cases = @($uuids[3], $uuids[700], $uuids[1499], $edgeUuid, "11111111-2222-3333-4444-555555555555", "99999999-2222-3333-4444-555555555555", "00000000-0000-0000-0000-000000000000", "")

function Canon($o) { ($o | ConvertTo-Json -Depth 6 -Compress) }
$pass = 0; $fail = 0
function Check([string]$label, $a, $b) {
  if ((Canon $a) -eq (Canon $b)) { $script:pass++ }
  else { $script:fail++; Write-Host ("  FAIL  {0}`n    REF={1}`n    NEW={2}" -f $label, (Canon $a), (Canon $b)) -ForegroundColor Red }
}
function Norm-Folders($o) { @{ folders = @(@($o.folders) | ForEach-Object { $_.FullName } | Sort-Object); unresolved = $o.unresolved } }

Write-Host "`n=== Get-UciUuidMatchedCustomerFolders ==="
$tRef = 0.0; $tNew = 0.0
foreach ($u in $cases) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew(); $a = Get-UciUuidMatchedCustomerFolders_REF $custRoot $u; $sw.Stop(); $tRef += $sw.Elapsed.TotalMilliseconds
  $sw = [System.Diagnostics.Stopwatch]::StartNew(); $b = Get-UciUuidMatchedCustomerFolders_NEW $custRoot $u; $sw.Stop(); $tNew += $sw.Elapsed.TotalMilliseconds
  Check "MatchedFolders [$u]" (Norm-Folders $a) (Norm-Folders $b)
}
Write-Host ("  {0} cases; time REF={1:N0}ms  NEW={2:N0}ms  ({3:N1}x)" -f $cases.Count, $tRef, $tNew, ($tRef / [math]::Max($tNew,1)))

Write-Host "`n=== Get-UciFolderEvidence ==="
$folders = @(Get-ChildItem -LiteralPath $custRoot -Directory | Select-Object -First 60) + @(Get-Item $edgeDir) + @(Get-Item $unclosedDir)
$n = 0
foreach ($d in $folders) {
  foreach ($u in @($edgeUuid, "11111111-2222-3333-4444-555555555555", $uuids[0], $uuids[3])) {
    Check "Evidence [$($d.Name)] [$u]" (Get-UciFolderEvidence_REF $d.FullName $u) (Get-UciFolderEvidence_NEW $d.FullName $u); $n++
  }
}
Write-Host ("  {0} folder x uuid combinations" -f $n)

Write-Host "`n=== Get-UuidNoteTypeMatchesInTree / Get-UciOutOfScopeManagedNotes ==="
foreach ($u in $cases) {
  foreach ($p in @($pfx, (Get-IconPrefix_NEW "契約"), (Get-IconPrefix_NEW "その他"))) {
    Check "InTree [$p] [$u]" @(Get-UuidNoteTypeMatchesInTree_REF $custRoot $p $u | Sort-Object) @(Get-UuidNoteTypeMatchesInTree_NEW $custRoot $p $u | Sort-Object)
    Check "OutOfScope [$p] [$u]" @(Get-UciOutOfScopeManagedNotes_REF $edgeDir $p $u | Sort-Object) @(Get-UciOutOfScopeManagedNotes_NEW $edgeDir $p $u | Sort-Object)
  }
}

Write-Host "`n=== Read-YamlUuidFast vs Get-YamlHeaderLines+Get-YamlScalarValue (per-file semantics) ==="
foreach ($f in Get-ChildItem -LiteralPath $edgeDir, $unclosedDir -Filter *.md -File -Recurse) {
  $hdr = Get-YamlHeaderLines_REF $f.FullName
  $refState = if ($null -eq $hdr) { "Unclosed" } else { "Ok" }   # REF: ,@() (no frontmatter) も UUID "" の Ok 相当
  $refUuid = if ($null -eq $hdr) { "" } else { Get-YamlScalarValue_REF $hdr "UUID:" }
  $r = Read-YamlUuidFast_NEW $f.FullName
  $newState = if ($r.State -eq "Unclosed") { "Unclosed" } else { "Ok" }
  Check "Yaml [$($f.Name)]" @{ s = $refState; u = $refUuid } @{ s = $newState; u = [string]$r.Uuid }
}

Write-Host "`n=== Exception safety: unreadable dir / nonexistent root / reparse point ==="
$noaccess = Join-Path $edgeDir "noaccess"
[void][System.IO.Directory]::CreateDirectory($noaccess)
[System.IO.File]::WriteAllText((Join-Path $noaccess "x.md"), "---`nUUID: $edgeUuid`n---`n", $enc)
$permChanged = $false
try { & chmod 000 $noaccess 2>$null; $permChanged = $true } catch {}
try {
  $r1 = Get-UciFolderEvidence_NEW $edgeDir $edgeUuid
  Write-Host ("  no-access subdir: state={0} (no exception)" -f $r1.state); $pass++
} catch { $fail++; Write-Host "  FAIL exception on no-access dir: $($_.Exception.Message)" -ForegroundColor Red }
if ($permChanged) { & chmod 755 $noaccess 2>$null }
$missing = Join-Path $VaultRoot "does_not_exist"
# Get-UciUuidMatchedCustomerFolders は REF/NEW とも先頭の Get-Item で throw する(既存挙動・呼び出し側が事前に 01_顧客 を作成)。REF と NEW の挙動一致のみ確認する。
$refThrew = $false; $newThrew = $false
try { [void](Get-UciUuidMatchedCustomerFolders_REF $missing $edgeUuid) } catch { $refThrew = $true }
try { [void](Get-UciUuidMatchedCustomerFolders_NEW $missing $edgeUuid) } catch { $newThrew = $true }
Check "MatchedFolders nonexistent root (REF/NEW both throw=$refThrew)" $refThrew $newThrew
# Get-UciFolderEvidence / Get-UuidNoteTypeMatchesInTree / Get-MdFilesOrdered は missing root で例外を出さず空結果を返す
try {
  $e1 = Get-UciFolderEvidence_NEW $missing $edgeUuid
  Check "Evidence nonexistent folder" (Get-UciFolderEvidence_REF $missing $edgeUuid) $e1
  $e2 = @(Get-UuidNoteTypeMatchesInTree_NEW $missing $pfx $edgeUuid)
  Check "InTree nonexistent root" @(Get-UuidNoteTypeMatchesInTree_REF $missing $pfx $edgeUuid) $e2
  $e3 = Get-MdFilesOrdered_NEW $missing "*.md"
  if ($e3.Count -eq 0) { $pass++ } else { $fail++ }
  Write-Host ("  nonexistent root: evidence={0} inTree={1} files={2} (no exception)" -f $e1.state, $e2.Count, $e3.Count)
} catch { $fail++; Write-Host "  FAIL exception on nonexistent root: $($_.Exception.Message)" -ForegroundColor Red }
# ファイルパスをルートとして渡した場合も例外なし
try { $e4 = Get-MdFilesOrdered_NEW (Join-Path $edgeDir "empty.md") "*.md"; if ($e4.Count -eq 0) { $pass++ } else { $fail++ } } catch { $fail++; Write-Host "  FAIL file-as-root: $($_.Exception.Message)" -ForegroundColor Red }
$link = Join-Path $edgeDir "loop_link"
try {
  [void][System.IO.Directory]::CreateSymbolicLink($link, $edgeDir)
  $r3 = Get-MdFilesOrdered_NEW $edgeDir "*.md"
  Write-Host ("  symlink loop: enumerated {0} files, no infinite recursion" -f $r3.Count); $pass++
} catch { Write-Host "  (symlink test skipped: $($_.Exception.Message))" }
Remove-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue

Cleanup
Write-Host ("`nRESULT: pass={0} fail={1}" -f $pass, $fail)
if ($fail -gt 0) { exit 1 }
