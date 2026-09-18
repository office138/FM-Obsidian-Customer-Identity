<#
.SYNOPSIS
  検索速度ベンチマーク用の合成Vault(顧客実データなし)を生成する。
.PARAMETER Root       生成先(既存なら削除して再生成)
.PARAMETER Customers  顧客フォルダ数
.PARAMETER NotesPer   1顧客あたりのノート数
.PARAMETER BodyLines  1ノートあたりの本文行数(契約一覧テーブル相当)
#>
param(
  [string]$Root = "/tmp/synthvault",
  [int]$Customers = 1500,
  [int]$NotesPer = 4,
  [int]$BodyLines = 150
)
$ErrorActionPreference = "Stop"
if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
$cust = Join-Path $Root "01_顧客"
[void][System.IO.Directory]::CreateDirectory($cust)
[void][System.IO.Directory]::CreateDirectory((Join-Path $Root "scripts"))
$rng = [System.Random]::new(42)
$prefixes = @("✡️一覧","⛔一覧","🟡契約","🔴事故","◻️決算書","⬛その他")
$enc = [System.Text.UTF8Encoding]::new($false)
$uuids = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $Customers; $i++) {
  $u = [guid]::NewGuid().ToString().ToUpperInvariant()
  $uuids.Add($u)
  $name = "テスト顧客{0:D5}" -f $i
  $legacy = ($i % 5 -eq 0)   # 20%はUUIDなしlegacyフォルダ名
  $fname = if ($legacy) { $name } else { "${name}_[" + $u.Substring(0,8) + "]" }
  $dir = Join-Path $cust $fname
  [void][System.IO.Directory]::CreateDirectory($dir)
  for ($k = 0; $k -lt $NotesPer; $k++) {
    $pfx = $prefixes[$k % $prefixes.Count]
    $file = Join-Path $dir ("{0}_{1}_[{2}].md" -f $pfx, $name, $u.Substring(0,8))
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("tags:")
    [void]$sb.AppendLine("  - `"$name`"")
    [void]$sb.AppendLine("UUID: $u")
    [void]$sb.AppendLine("ランク: A")
    [void]$sb.AppendLine("---")
    for ($b = 0; $b -lt $BodyLines; $b++) {
      $row = "| 2026-01-{0:D2} | 保険会社{1} | 証券{2} | 自動車 | {3} |" -f (($b % 28)+1), $rng.Next(1,9), $rng.Next(100000,999999), $rng.Next(10000,999999)
      [void]$sb.AppendLine($row)
    }
    [System.IO.File]::WriteAllText($file, $sb.ToString(), $enc)
  }
  # 10%の顧客にサブフォルダ+添付md
  if ($i % 10 -eq 0) {
    $sub = Join-Path $dir "資料"
    [void][System.IO.Directory]::CreateDirectory($sub)
    [System.IO.File]::WriteAllText((Join-Path $sub "メモ.md"), "# メモ`n本文のみ", $enc)
  }
}
[System.IO.File]::WriteAllLines((Join-Path $Root "uuids.txt"), $uuids, $enc)
$count = (Get-ChildItem -LiteralPath $cust -Filter *.md -File -Recurse).Count
Write-Output ("Generated: {0} customers, {1} md files at {2}" -f $Customers, $count, $Root)
