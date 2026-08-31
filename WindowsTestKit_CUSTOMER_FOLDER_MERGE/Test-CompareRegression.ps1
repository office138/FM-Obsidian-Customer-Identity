# ==============================================================================
# Test-CompareRegression.ps1
# Dedicated Regression Test Suite for MODE=COMPARE (Tier 0 NB-1 Verification)
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1",
    [string]$TestRoot = "D:\FM-Script-Backup\WindowsTestKit_CUSTOMER_FOLDER_MERGE\TestVault_MERGE\V_COMPARE_TEST"
)

$ErrorActionPreference = "Stop"

Write-Host "====================================================="
Write-Host "MODE=COMPARE Dedicated Regression Test Suite"
Write-Host "Target: $TargetScript"
Write-Host "TestRoot: $TestRoot"
Write-Host "====================================================="

$testResults = @()

function Record-TestResult([string]$TestId, [string]$Description, [bool]$Passed, [string]$Details) {
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] {1}: {2}" -f $status, $TestId, $Description)
    if (-not $Passed) {
        Write-Host "       Details: $Details" -ForegroundColor Red
    }
    $script:testResults += [pscustomobject]@{
        TestId = $TestId
        Description = $Description
        Passed = $Passed
        Details = $Details
    }
}

# Cleanup and recreate TestRoot
if (Test-Path -LiteralPath $TestRoot) {
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
[void][System.IO.Directory]::CreateDirectory($TestRoot)
$custRoot = Join-Path $TestRoot "01_顧客"
[void][System.IO.Directory]::CreateDirectory($custRoot)

# Helper to run target payload
function Invoke-TargetPayload([hashtable]$payload) {
    $json = $payload | ConvertTo-Json -Compress
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetScript`" `"$b64`""
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()

    return @{
        ExitCode = $proc.ExitCode
        Stdout = $stdout.Trim()
        Stderr = $stderr.Trim()
    }
}

# ------------------------------------------------------------------------------
# Test 1: Mechanical No-Fallthrough Proof (AST Static Verification)
# ------------------------------------------------------------------------------
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($TargetScript, [ref]$tokens, [ref]$errors)

$compareFn = $ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq "Invoke-CompareObsidianNotes"
}, $true)

$t1Pass = $false
$t1Details = ""
if ($compareFn.Count -eq 1) {
    $fnAst = $compareFn[0]
    $commands = $fnAst.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true)
    
    $cmdNames = @($commands | ForEach-Object { $_.GetCommandName() } | Where-Object { $null -ne $_ })
    
    $hasUpdateYamlCall = $cmdNames -contains "Update-Yaml-Robust"
    $hasCreateNewCall = $fnAst.Extent.Text -match "\[System\.IO\.File\]::Open\([^\)]*CreateNew"
    $hasHardReturn = $fnAst.Extent.Text -match "Out-OK `"OPENED`"[^\r\n]*`"COMPARE_DONE`"[\s\S]*return"
    
    if (-not $hasUpdateYamlCall -and -not $hasCreateNewCall -and $hasHardReturn) {
        $t1Pass = $true
        $t1Details = "AST verified: 0 Update-Yaml-Robust calls, 0 CreateNew calls, hard return present."
    } else {
        $t1Details = "AST violations: hasUpdateYamlCall=$hasUpdateYamlCall, hasCreateNewCall=$hasCreateNewCall, hasHardReturn=$hasHardReturn"
    }
} else {
    $t1Details = "Invoke-CompareObsidianNotes definition count: $($compareFn.Count)"
}
Record-TestResult "COMPARE_01_AST_NO_FALLTHROUGH" "Mechanical AST proof of no OPEN/CREATE fallthrough" $t1Pass $t1Details

# ------------------------------------------------------------------------------
# Test 2: Missing Managed Note (Fail-Closed)
# ------------------------------------------------------------------------------
$f2Name = "株式会社テスト空_[11111111]"
$f2Path = Join-Path $custRoot $f2Name
[void][System.IO.Directory]::CreateDirectory($f2Path)
$otherNote = Join-Path $f2Path "🚨事故_㈱テスト空_[11111111].md"
$otherContent = @"
---
UUID: "11111111-2222-3333-4444-555555555555"
---
# 事故一覧
"@
[System.IO.File]::WriteAllText($otherNote, $otherContent, [System.Text.Encoding]::UTF8)

$f2Csv = Join-Path $TestRoot "test2.csv"
[System.IO.File]::WriteAllText($f2Csv, "証券番号,状態`n12345,有効`n", [System.Text.Encoding]::UTF8)

$p2 = @{
    protocolVersion = 1
    MODE = "COMPARE"
    requestId = "req-comp-02"
    VaultRoot = $TestRoot
    pk_CLIENT = "11111111-2222-3333-4444-555555555555"
    companyNameRaw = "株式会社テスト空"
    noteType = "契約一覧"
    csvPath = $f2Csv
}
$r2 = Invoke-TargetPayload $p2
$filesAfter2 = @(Get-ChildItem -LiteralPath $f2Path -File -ErrorAction SilentlyContinue)
$t2Pass = ($r2.Stdout -match "NG\|MANAGED_NOTE_NOT_FOUND\|") -and ($filesAfter2.Count -eq 1)
Record-TestResult "COMPARE_02_MISSING_NOTE_FAIL_CLOSED" "Missing managed note returns MANAGED_NOTE_NOT_FOUND without note creation" $t2Pass "Stdout: $($r2.Stdout), Files in folder: $($filesAfter2.Count)"

# ------------------------------------------------------------------------------
# Test 3: UUID Folder Conflict (Fail-Closed)
# ------------------------------------------------------------------------------
$f3A = Join-Path $custRoot "株式会社重複A_[22222222]"
$f3B = Join-Path $custRoot "株式会社重複B_[22222222]"
[void][System.IO.Directory]::CreateDirectory($f3A)
[void][System.IO.Directory]::CreateDirectory($f3B)

$noteContent3A = @"
---
UUID: "22222222-3333-4444-5555-666666666666"
---
# 契約一覧
"@
$noteContent3B = @"
---
UUID: "22222222-3333-4444-5555-666666666666"
---
# 契約一覧
"@
[System.IO.File]::WriteAllText((Join-Path $f3A "✡️一覧_㈱重複A_[22222222].md"), $noteContent3A, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText((Join-Path $f3B "✡️一覧_㈱重複B_[22222222].md"), $noteContent3B, [System.Text.Encoding]::UTF8)

$f3Csv = Join-Path $TestRoot "test3.csv"
[System.IO.File]::WriteAllText($f3Csv, "証券番号,状態`n99999,有効`n", [System.Text.Encoding]::UTF8)

$p3 = @{
    protocolVersion = 1
    MODE = "COMPARE"
    requestId = "req-comp-03"
    VaultRoot = $TestRoot
    pk_CLIENT = "22222222-3333-4444-5555-666666666666"
    companyNameRaw = "株式会社重複"
    noteType = "契約一覧"
    csvPath = $f3Csv
}
$r3 = Invoke-TargetPayload $p3
$t3Pass = ($r3.Stdout -match "NG\|UUID_FOLDER_CONFLICT\|")
Record-TestResult "COMPARE_03_UUID_CONFLICT_FAIL_CLOSED" "UUID folder conflict returns UUID_FOLDER_CONFLICT and stops" $t3Pass "Stdout: $($r3.Stdout)"

# ------------------------------------------------------------------------------
# Test 4: Missing CSV Path (Fail-Closed)
# ------------------------------------------------------------------------------
$f4Name = "株式会社正常_[33333333]"
$f4Path = Join-Path $custRoot $f4Name
[void][System.IO.Directory]::CreateDirectory($f4Path)
$note4Path = Join-Path $f4Path "✡️一覧_㈱正常_[33333333].md"
$noteContent4 = @"
---
UUID: "33333333-4444-5555-6666-777777777777"
---
# 契約一覧
"@
[System.IO.File]::WriteAllText($note4Path, $noteContent4, [System.Text.Encoding]::UTF8)
$shaBefore4 = (Get-FileHash -LiteralPath $note4Path -Algorithm SHA256).Hash

$p4 = @{
    protocolVersion = 1
    MODE = "COMPARE"
    requestId = "req-comp-04"
    VaultRoot = $TestRoot
    pk_CLIENT = "33333333-4444-5555-6666-777777777777"
    companyNameRaw = "株式会社正常"
    noteType = "契約一覧"
    csvPath = "D:\NonExistentPath\nonexistent.csv"
}
$r4 = Invoke-TargetPayload $p4
$shaAfter4 = (Get-FileHash -LiteralPath $note4Path -Algorithm SHA256).Hash
$t4Pass = ($r4.Stdout -match "NG\|ERROR\|.*(CSVファイルが見つかりません|Pythonスクリプトが見つかりません)") -and ($shaBefore4 -eq $shaAfter4)
Record-TestResult "COMPARE_04_MISSING_CSV_FAIL_CLOSED" "Missing CSV fails closed with 0 modifications to managed note" $t4Pass "Stdout: $($r4.Stdout), HashMatch: $($shaBefore4 -eq $shaAfter4)"

# ------------------------------------------------------------------------------
# Durable Report Generation
# ------------------------------------------------------------------------------
$targetSha = (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash.ToUpperInvariant()
$passCount = ($testResults | Where-Object { $_.Passed }).Count
$header = [ordered]@{
  Suite             = "MODE=COMPARE Dedicated Regression"
  TargetScript      = $TargetScript
  TargetSha256      = $targetSha
  RunTimestamp      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  PowerShellVersion = $PSVersionTable.PSVersion.ToString()
  TestCount         = $testResults.Count
  PassCount         = $passCount
  FailCount         = ($testResults.Count - $passCount)
  PositivePathGap   = "POSITIVE_COMPARE_DONE_PATH_REMAINS_A_DECLARED_GAP"
}
$lines = @($header.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" })
$lines += "-----"
$lines += ($testResults | ForEach-Object { "$(if ($_.Passed) {'[PASS]'} else {'[FAIL]'}) $($_.TestId) - $($_.Description) :: $($_.Details)" })
[System.IO.File]::WriteAllLines((Join-Path $TestRoot "_report.txt"), $lines, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $TestRoot "_report.json"),
  ([ordered]@{ Report = $header; Results = $testResults } | ConvertTo-Json -Depth 10),
  [System.Text.UTF8Encoding]::new($false))

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
$allPass = ($testResults | Where-Object { -not $_.Passed }).Count -eq 0
Write-Host "`n====================================================="
Write-Host ("COMPARE Regression Suite Summary: {0}/{1} PASS" -f ($testResults | Where-Object { $_.Passed }).Count, $testResults.Count)
Write-Host "Reports: $(Join-Path $TestRoot '_report.txt') / $(Join-Path $TestRoot '_report.json')"
Write-Host "====================================================="

if (-not $allPass) {
    exit 1
}
exit 0
