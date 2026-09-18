<#
.SYNOPSIS
  REF(旧版) と NEW(新版) の Invoke-OpenObsidianNotes / Invoke-CheckObsidianNotes を
  合成 Vault 上で実際に実行し、FileMaker へ返す応答文字列(OK|... / NG|...)が一致することを確認する。
  Windows/Obsidian 依存の副作用(Start-Process, Get-Process, exit)だけをスタブ化する。
  ※ 判定ロジック・ファイル I/O・YAML 更新はそのまま実行される(合成 Vault のみ書き換える)。
#>
param(
  [Parameter(Mandatory)][string]$ReferencePayload,
  [string]$Payload = (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "FM-Obsidian-Bridge-Payload.ps1"),
  [string]$VaultRoot = "/tmp/synthvault"
)
$ErrorActionPreference = "Stop"
$enc = [System.Text.UTF8Encoding]::new($false)
$custRoot = Join-Path $VaultRoot "01_顧客"

function Get-AllFunctionSource([string]$file, [string]$suffix) {
  $tokens = $null; $errors = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$errors)
  if ($errors.Count -gt 0) { throw "Parse error in ${file}: $($errors[0].Message)" }
  $defs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Parent.Parent -is [System.Management.Automation.Language.ScriptBlockAst] }, $false))
  $names = @($defs | ForEach-Object { $_.Name })
  $sb = [System.Text.StringBuilder]::new()
  foreach ($d in $defs) {
    $text = $d.Extent.Text
    foreach ($w in ($names | Sort-Object Length -Descending)) {
      $text = [regex]::Replace($text, "(?<![\w-])" + [regex]::Escape($w) + "(?![\w-])", ($w + $suffix))
    }
    [void]$sb.AppendLine($text)
  }
  # スタブ: 応答は exit せず例外で持ち帰る / Obsidian 起動・URI オープンは no-op
  [void]$sb.AppendLine(@"
function Out-OK$suffix([string]`$kind, [string]`$url, [string]`$rel, [string]`$lwIso, [string]`$diffB64) { throw [System.InvalidOperationException]::new("RESP::" + ("OK|{0}|{1}|{2}|{3}|{4}" -f `$kind, `$url, `$rel, "<TS>", `$diffB64)) }
function Out-OKNeedFolder$suffix([string[]]`$cands, [string]`$suggest, [string]`$nameNorm, [string]`$expectedFileName) { `$c = (`$cands | ForEach-Object { `$_ -replace "[\s　]+", "" } | Select-Object -First 20) -join ";"; throw [System.InvalidOperationException]::new("RESP::" + ("OK|NEED_FOLDER_CONFIRM|{0}|{1}|{2}|{3}" -f `$c, `$suggest, `$nameNorm, `$expectedFileName)) }
function Out-NG$suffix([string]`$kind, [string]`$details) { throw [System.InvalidOperationException]::new("RESP::" + ("NG|{0}|{1}|||" -f `$kind, `$details)) }
function Assert-ObsidianReady$suffix { }
function Open-ObsidianFile$suffix([string]`$vaultRoot, [string]`$relPath) { }
"@)
  return $sb.ToString()
}
. ([scriptblock]::Create((Get-AllFunctionSource $ReferencePayload "_REF")))
. ([scriptblock]::Create((Get-AllFunctionSource $Payload "_NEW")))

function Invoke-Mode([string]$suffix, [string]$mode, [hashtable]$payload) {
  $p = $payload.Clone(); $p["VaultRoot"] = $VaultRoot; $p["MODE"] = $mode
  try {
    if ($mode -eq "CHECK") { & "Invoke-CheckObsidianNotes$suffix" $p } else { & "Invoke-OpenObsidianNotes$suffix" $p }
    return "<NO RESPONSE>"
  } catch {
    $m = $_.Exception.Message
    if ($m.StartsWith("RESP::")) { return $m.Substring(6) }
    return "EXCEPTION::" + $m + " @ " + $_.InvocationInfo.ScriptLineNumber
  }
}

$uuids = [System.IO.File]::ReadAllLines((Join-Path $VaultRoot "uuids.txt"))
# --- fixture: 同一UUIDが2フォルダに存在する衝突ケース / legacy名一致 / canonical名のみ ---
$conflictUuid = "CCCCCCCC-1111-2222-3333-444444444444"
foreach ($d in @("衝突顧客A_[CCCCCCCC]", "衝突顧客B")) {
  $dir = Join-Path $custRoot $d; [void][System.IO.Directory]::CreateDirectory($dir)
  [System.IO.File]::WriteAllText((Join-Path $dir "⬛その他_x.md"), "---`nUUID: $conflictUuid`n---`n", $enc)
}
$legacyUuid = "DDDDDDDD-1111-2222-3333-444444444444"
$legacyDir = Join-Path $custRoot "株式会社レガシー商事"; [void][System.IO.Directory]::CreateDirectory($legacyDir)
[System.IO.File]::WriteAllText((Join-Path $legacyDir "メモ.md"), "# no uuid", $enc)
$canonNoEvUuid = "EEEEEEEE-1111-2222-3333-444444444444"
$canonDir = Join-Path $custRoot "カノニカル商事_[EEEEEEEE]"; [void][System.IO.Directory]::CreateDirectory($canonDir)
[System.IO.File]::WriteAllText((Join-Path $canonDir "メモ.md"), "# no uuid", $enc)
$mixedUuid = $uuids[10]
$mixedDir = (Get-ChildItem -LiteralPath $custRoot -Directory | Where-Object { $_.Name -like "テスト顧客00010*" })[0].FullName
[System.IO.File]::WriteAllText((Join-Path $mixedDir "混在.md"), "---`nUUID: 12345678-1111-2222-3333-444444444444`n---`n", $enc)

$scenarios = @(
  @{ name = "既存顧客 OPEN(契約一覧)";           p = @{ pk_CLIENT = $uuids[700];  companyNameRaw = "テスト顧客00700"; noteType = "契約一覧"; RANK = "A"; CEO = "代表"; RUBY = "テスト" } },
  @{ name = "既存顧客 OPEN(事故)";               p = @{ pk_CLIENT = $uuids[3];    companyNameRaw = "テスト顧客00003"; noteType = "事故";     RANK = "B" } },
  @{ name = "legacyフォルダ顧客 OPEN(決算書)";    p = @{ pk_CLIENT = $uuids[5];    companyNameRaw = "テスト顧客00005"; noteType = "決算書";   RANK = "C" } },
  @{ name = "同一UUID複数フォルダ";               p = @{ pk_CLIENT = $conflictUuid; companyNameRaw = "衝突顧客";       noteType = "契約一覧" } },
  @{ name = "未知UUID・候補なし";                 p = @{ pk_CLIENT = "FFFFFFFF-1111-2222-3333-444444444444"; companyNameRaw = "新規顧客XYZ"; noteType = "契約一覧" } },
  @{ name = "未知UUID・legacy名一致";             p = @{ pk_CLIENT = $legacyUuid;  companyNameRaw = "株式会社レガシー商事"; noteType = "契約一覧" } },
  @{ name = "canonical名あり・UUID証拠なし";      p = @{ pk_CLIENT = $canonNoEvUuid; companyNameRaw = "カノニカル商事"; noteType = "契約一覧" } },
  @{ name = "フォルダ内に別UUID混在";             p = @{ pk_CLIENT = $mixedUuid;   companyNameRaw = "テスト顧客00010"; noteType = "契約一覧" } },
  @{ name = "UUID形式不正";                       p = @{ pk_CLIENT = "not-a-uuid"; companyNameRaw = "X";              noteType = "契約一覧" } },
  @{ name = "obs_RELPATH hint 付き OPEN";         p = @{ pk_CLIENT = $uuids[700];  companyNameRaw = "テスト顧客00700"; noteType = "契約一覧"; obs_RELPATH = ("01_顧客/" + (Split-Path -Leaf (Get-ChildItem -LiteralPath $custRoot -Directory | Where-Object { $_.Name -like "テスト顧客00700*" })[0].FullName) + "/✡️一覧_テスト顧客00700_[" + $uuids[700].Substring(0,8) + "].md") } }
)
function Normalize-Response([string]$r) {
  # (1) UUID_FOLDER_CONFLICT の "Folders: a;b" は @(hashtable.Values) 由来で列挙順(=FS列挙順)依存。
  #     Linux の Get-ChildItem は readdir 順(未ソート)、Get-MdFilesOrdered は NTFS と同じ名前順のため
  #     Linux 上でのみ順序が入れ替わる。Windows では一致する。順序を正規化して比較する。
  $r = [regex]::Replace($r, "Folders: ([^)]+)\)", { param($m) "Folders: " + (($m.Groups[1].Value -split ";" | Sort-Object) -join ";") + ")" })
  # (2) Windows 専用 P/Invoke 型が無い環境での例外は行番号を除いて比較する。
  if ($r.StartsWith("EXCEPTION::")) { $r = [regex]::Replace($r, " @ \d+$", "") }
  return $r
}
$pass = 0; $fail = 0
foreach ($mode in @("OPEN","CHECK")) {
  Write-Host "=== MODE=$mode ==="
  foreach ($sc in $scenarios) {
    $a = Invoke-Mode "_REF" $mode $sc.p
    $b = Invoke-Mode "_NEW" $mode $sc.p
    if ((Normalize-Response $a) -eq (Normalize-Response $b)) {
      $pass++
      $tag = if ($a.StartsWith("EXCEPTION::")) { "PASS* (env-limited: REF/NEW ともに同一例外)" } else { "PASS " }
      Write-Host ("  {0} {1,-32} {2}" -f $tag, $sc.name, ($a.Substring(0, [math]::Min(90, $a.Length))))
    }
    else { $fail++; Write-Host ("  FAIL  {0}`n    REF={1}`n    NEW={2}" -f $sc.name, $a, $b) -ForegroundColor Red }
  }
}
# 時間比較 (OPEN 既存顧客)
$sw = [System.Diagnostics.Stopwatch]::StartNew(); [void](Invoke-Mode "_REF" "OPEN" $scenarios[0].p); $sw.Stop(); $tr = $sw.Elapsed.TotalMilliseconds
$sw = [System.Diagnostics.Stopwatch]::StartNew(); [void](Invoke-Mode "_NEW" "OPEN" $scenarios[0].p); $sw.Stop(); $tn = $sw.Elapsed.TotalMilliseconds
Write-Host ("`nOPEN 既存顧客 1回: REF={0:N0}ms  NEW={1:N0}ms  ({2:N1}x)" -f $tr, $tn, ($tr / [math]::Max($tn,1)))

# cleanup fixtures
Remove-Item -LiteralPath (Join-Path $custRoot "衝突顧客A_[CCCCCCCC]"), (Join-Path $custRoot "衝突顧客B"), $legacyDir, $canonDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $mixedDir "混在.md") -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $custRoot "新規顧客XYZ_[FFFFFFFF]") -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("`nRESULT: pass={0} fail={1}" -f $pass, $fail)
if ($fail -gt 0) { exit 1 }
