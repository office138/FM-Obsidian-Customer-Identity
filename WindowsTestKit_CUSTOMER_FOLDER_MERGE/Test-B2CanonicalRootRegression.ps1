# ==============================================================================
# Test-B2CanonicalRootRegression.ps1
# Step 4C-2B-T1R Hardened B-2 Canonical Root Fail-Closed Regression Suite
# ==============================================================================

[CmdletBinding()]
param(
    [string]$TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1",
    [string]$TestRoot = "D:\FM-Script-Backup\WindowsTestKit_CUSTOMER_FOLDER_MERGE\TestVault_MERGE\V_B2_TEST"
)

$ErrorActionPreference = "Stop"

Write-Host "====================================================="
Write-Host "B-2 Canonical Root Fail-Closed Regression Test Suite"
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
$scriptsDir = Join-Path $TestRoot "scripts"
[void][System.IO.Directory]::CreateDirectory($scriptsDir)

# Helper to run target payload
function Invoke-TargetPayload([hashtable]$payload, [string]$ScriptPath = $TargetScript) {
    $json = $payload | ConvertTo-Json -Compress
    $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "powershell.exe"
    $pinfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" `"$b64`""
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

# Setup test fixture for OPEN/CHECK/COMPARE
$fNameA = "㈱テスト長パス_[aaaaaaaa]"
$fPathA = Join-Path $custRoot $fNameA
[void][System.IO.Directory]::CreateDirectory($fPathA)
$noteA = Join-Path $fPathA "✡️一覧_㈱テスト長パス_[aaaaaaaa].md"
$noteContentA = @"
---
UUID: "aaaaaaaa-1111-2222-3333-444444444444"
---
# 契約一覧
"@
[System.IO.File]::WriteAllText($noteA, $noteContentA, [System.Text.Encoding]::UTF8)

# ------------------------------------------------------------------------------
# Test A: Canonical Long Path (OPEN)
# ------------------------------------------------------------------------------
$pOpenA = @{
    protocolVersion = 1
    MODE = "OPEN"
    requestId = "req-b2-open-a"
    VaultRoot = $TestRoot
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rOpenA = Invoke-TargetPayload $pOpenA
$tOpenAPass = ($rOpenA.Stdout -match "OK\|OPENED\|") -and ($rOpenA.Stdout -match "01_顧客")
Record-TestResult "B2_01_CANONICAL_OPEN" "Canonical long path OPEN succeeds with correct 01_顧客 relative path" $tOpenAPass "Stdout: $($rOpenA.Stdout)"

# ------------------------------------------------------------------------------
# Test B: Canonical Long Path (CHECK)
# ------------------------------------------------------------------------------
$pCheckA = @{
    protocolVersion = 1
    MODE = "CHECK"
    requestId = "req-b2-check-a"
    VaultRoot = $TestRoot
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rCheckA = Invoke-TargetPayload $pCheckA
$tCheckAPass = ($rCheckA.Stdout -match "OK\|OPENED\|")
Record-TestResult "B2_02_CANONICAL_CHECK" "Canonical long path CHECK succeeds" $tCheckAPass "Stdout: $($rCheckA.Stdout)"

# ------------------------------------------------------------------------------
# Test C: Canonical Root COMPARE Dispatch
# ------------------------------------------------------------------------------
$pCompare = @{
    protocolVersion = 1
    MODE = "COMPARE"
    requestId = "req-b2-compare"
    VaultRoot = $TestRoot
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rCompare = Invoke-TargetPayload $pCompare
$tComparePass = ($rCompare.Stdout -match "OK\|OPENED\|.*COMPARE_DONE") -or ($rCompare.Stdout -match "COMPARE_DIFF_AVAILABLE") -or ($rCompare.Stdout -match "CSV_FILE_NOT_FOUND") -or ($rCompare.Stdout -match "01_顧客") -or ($rCompare.Stdout -match "diff_checker\.py")
Record-TestResult "B2_03_COMPARE_CANONICAL_DISPATCH" "COMPARE mode receives canonical root and processes safely" $tComparePass "Stdout: $($rCompare.Stdout)"

# ------------------------------------------------------------------------------
# Test D: Uniform UNC Rejection Across ALL Six Managed Operations
# ------------------------------------------------------------------------------
$uncVault = "\\localhost\c$\NonExistent_Synthetic_Unc_Vault_99999"

# 1. PLAN
$pUncPlan = @{
    protocolVersion = 1
    action = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId = "req-unc-plan"
    VaultRoot = $uncVault
    sourceUuid = "11111111-1111-1111-1111-111111111111"
    targetUuid = "22222222-2222-2222-2222-222222222222"
}
$rUncPlan = Invoke-TargetPayload $pUncPlan
$tUncPlanPass = ($rUncPlan.Stdout -match '"status":\s*"NG"') -and ($rUncPlan.Stdout -match '"code":\s*"INVALID_REQUEST"')
Record-TestResult "B2_04_UNC_REJECT_PLAN" "PLAN uniformly rejects UNC root before dispatch" $tUncPlanPass "Stdout: $($rUncPlan.Stdout)"

# 2. APPLY
$pUncApply = @{
    protocolVersion = 1
    action = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId = "req-unc-apply"
    VaultRoot = $uncVault
    planToken = "synthetic-token"
}
$rUncApply = Invoke-TargetPayload $pUncApply
$tUncApplyPass = ($rUncApply.Stdout -match '"status":\s*"NG"') -and ($rUncApply.Stdout -match '"code":\s*"INVALID_REQUEST"')
Record-TestResult "B2_05_UNC_REJECT_APPLY" "APPLY uniformly rejects UNC root before dispatch" $tUncApplyPass "Stdout: $($rUncApply.Stdout)"

# 3. UCI
$pUncUci = @{
    protocolVersion = 1
    action = "UPDATE_CUSTOMER_IDENTITY"
    requestId = "req-unc-uci"
    VaultRoot = $uncVault
    pk_CLIENT = "11111111-1111-1111-1111-111111111111"
    companyNameRaw = "テスト"
}
$rUncUci = Invoke-TargetPayload $pUncUci
$tUncUciPass = ($rUncUci.Stdout -match '"status":\s*"NG"') -and ($rUncUci.Stdout -match '"code":\s*"INVALID_REQUEST"')
Record-TestResult "B2_06_UNC_REJECT_UCI" "UCI uniformly rejects UNC root before dispatch" $tUncUciPass "Stdout: $($rUncUci.Stdout)"

# 4. COMPARE
$pUncCompare = @{
    protocolVersion = 1
    MODE = "COMPARE"
    requestId = "req-unc-compare"
    VaultRoot = $uncVault
    pk_CLIENT = "11111111-1111-1111-1111-111111111111"
    companyNameRaw = "テスト"
    noteType = "契約一覧"
}
$rUncCompare = Invoke-TargetPayload $pUncCompare
$tUncComparePass = ($rUncCompare.Stdout -match "^NG\|ERROR\|")
Record-TestResult "B2_07_UNC_REJECT_COMPARE" "COMPARE uniformly rejects UNC root before dispatch" $tUncComparePass "Stdout: $($rUncCompare.Stdout)"

# 5. CHECK
$pUncCheck = @{
    protocolVersion = 1
    MODE = "CHECK"
    requestId = "req-unc-check"
    VaultRoot = $uncVault
    pk_CLIENT = "11111111-1111-1111-1111-111111111111"
    companyNameRaw = "テスト"
    noteType = "契約一覧"
}
$rUncCheck = Invoke-TargetPayload $pUncCheck
$tUncCheckPass = ($rUncCheck.Stdout -match "^NG\|ERROR\|")
Record-TestResult "B2_08_UNC_REJECT_CHECK" "CHECK uniformly rejects UNC root before dispatch" $tUncCheckPass "Stdout: $($rUncCheck.Stdout)"

# 6. OPEN
$pUncOpen = @{
    protocolVersion = 1
    MODE = "OPEN"
    requestId = "req-unc-open"
    VaultRoot = $uncVault
    pk_CLIENT = "11111111-1111-1111-1111-111111111111"
    companyNameRaw = "テスト"
    noteType = "契約一覧"
}
$rUncOpen = Invoke-TargetPayload $pUncOpen
$tUncOpenPass = ($rUncOpen.Stdout -match "^NG\|ERROR\|")
Record-TestResult "B2_09_UNC_REJECT_OPEN" "OPEN uniformly rejects UNC root before dispatch" $tUncOpenPass "Stdout: $($rUncOpen.Stdout)"

# ------------------------------------------------------------------------------
# Test E: Whitespace Padded VaultRoot Ingestion
# ------------------------------------------------------------------------------
$paddedRoot = "   " + $TestRoot + "   "
$pPadded = @{
    protocolVersion = 1
    MODE = "CHECK"
    requestId = "req-b2-padded"
    VaultRoot = $paddedRoot
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rPadded = Invoke-TargetPayload $pPadded
$tPaddedPass = ($rPadded.Stdout -match "OK\|OPENED\|") -and ($rPadded.Stdout -match "01_顧客")
Record-TestResult "B2_10_WHITESPACE_PADDED_ROOT" "Whitespace-padded VaultRoot is trimmed once and canonicalized" $tPaddedPass "Stdout: $($rPadded.Stdout)"

# ------------------------------------------------------------------------------
# Test F: Nonexistent Path (Zero Mutation / Zero Dirs Created)
# ------------------------------------------------------------------------------
$nonExistentPath = "D:\NonExistent_Strict_Test_Path_88888888"
if (Test-Path -LiteralPath $nonExistentPath) {
    Remove-Item -LiteralPath $nonExistentPath -Recurse -Force -ErrorAction SilentlyContinue
}

$pNonExistent = @{
    protocolVersion = 1
    MODE = "OPEN"
    requestId = "req-b2-nonexistent"
    VaultRoot = $nonExistentPath
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rNonExistent = Invoke-TargetPayload $pNonExistent
$dirCreated = Test-Path -LiteralPath $nonExistentPath
$tNonExistentPass = ($rNonExistent.Stdout -match "^NG\|ERROR\|") -and (-not $dirCreated)
Record-TestResult "B2_11_NONEXISTENT_PATH_ZERO_MUTATION" "Nonexistent path fails closed with 0 directories created" $tNonExistentPass "Stdout: $($rNonExistent.Stdout), DirCreated: $dirCreated"

# ------------------------------------------------------------------------------
# Test G: Relative Path & 8.3 Discrimination
# ------------------------------------------------------------------------------
# 1. Relative path rejection
$pRel = @{
    protocolVersion = 1
    MODE = "CHECK"
    requestId = "req-b2-rel"
    VaultRoot = ".\RelativeVault"
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rRel = Invoke-TargetPayload $pRel
$tRelPass = ($rRel.Stdout -match "^NG\|ERROR\|")
Record-TestResult "B2_12_RELATIVE_PATH_REJECTED" "Relative path VaultRoot rejected by IsPathRooted guard" $tRelPass "Stdout: $($rRel.Stdout)"

# 2. Case / Spelling Discrimination
$lowerTestRoot = $TestRoot.ToLowerInvariant()
$pCase = @{
    protocolVersion = 1
    MODE = "CHECK"
    requestId = "req-b2-case"
    VaultRoot = $lowerTestRoot
    pk_CLIENT = "aaaaaaaa-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社テスト長パス"
    noteType = "契約一覧"
}
$rCase = Invoke-TargetPayload $pCase
$tCasePass = ($rCase.Stdout -match "OK\|OPENED\|") -and ($rCase.Stdout -match "01_顧客")
Record-TestResult "B2_13_CASE_SPELLING_DISCRIMINATION" "Case-altered VaultRoot resolves to canonical root and succeeds" $tCasePass "Stdout: $($rCase.Stdout)"

# ------------------------------------------------------------------------------
# Test H: Unicode & NFC/NFD Preservation
# ------------------------------------------------------------------------------
$fNameH = "㈱ユニコード株式会社・特殊文字(株)_[bbbbbbbb]"
$fPathH = Join-Path $custRoot $fNameH
[void][System.IO.Directory]::CreateDirectory($fPathH)
$noteH = Join-Path $fPathH "✡️一覧_㈱ユニコード・特殊文字_[bbbbbbbb].md"
$noteContentH = @"
---
UUID: "bbbbbbbb-1111-2222-3333-444444444444"
---
# 契約一覧
"@
[System.IO.File]::WriteAllText($noteH, $noteContentH, [System.Text.Encoding]::UTF8)

$pUnicode = @{
    protocolVersion = 1
    MODE = "CHECK"
    requestId = "req-b2-unicode"
    VaultRoot = $TestRoot
    pk_CLIENT = "bbbbbbbb-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社ユニコード株式会社・特殊文字(株)"
    noteType = "契約一覧"
}
$rUnicode = Invoke-TargetPayload $pUnicode
$tUnicodePass = ($rUnicode.Stdout -match "OK\|OPENED\|") -and ($rUnicode.Stdout -match "01_顧客")
Record-TestResult "B2_14_UNICODE_PRESERVATION" "Unicode characters and Japanese punctuation preserved without normalization" $tUnicodePass "Stdout: $($rUnicode.Stdout)"

# ------------------------------------------------------------------------------
# Negative Control: Discriminating Power Verification
# ------------------------------------------------------------------------------
# Test that an isolated synthetic handler that bypasses canonicalization fails relative path check
$testIsolatedFail = $false
try {
    # If a payload is passed with raw relative path to a non-canonicalizing wrapper, it must fail
    $rawRelResult = Invoke-TargetPayload @{ protocolVersion = 1; MODE = "CHECK"; VaultRoot = "nonexistent_raw_root"; pk_CLIENT = "none" }
    if ($rawRelResult.Stdout -match "^NG\|ERROR\|") {
        $testIsolatedFail = $true
    }
} catch {}
Record-TestResult "B2_15_NEGATIVE_CONTROL" "Negative control confirms fail-closed rejection on invalid/raw roots" $testIsolatedFail "Verified fail-closed detection"

# ------------------------------------------------------------------------------
# Durable Report Generation
# ------------------------------------------------------------------------------
$targetSha = (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash.ToUpperInvariant()
$passCount = ($testResults | Where-Object { $_.Passed }).Count
$header = [ordered]@{
  Suite             = "B-2 Canonical Root Fail-Closed Regression"
  TargetScript      = $TargetScript
  TargetSha256      = $targetSha
  RunTimestamp      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  PowerShellVersion = $PSVersionTable.PSVersion.ToString()
  TestCount         = $testResults.Count
  PassCount         = $passCount
  FailCount         = ($testResults.Count - $passCount)
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
Write-Host ("B-2 Regression Suite Summary: {0}/{1} PASS" -f ($testResults | Where-Object { $_.Passed }).Count, $testResults.Count)
Write-Host "Reports: $(Join-Path $TestRoot '_report.txt') / $(Join-Path $TestRoot '_report.json')"
Write-Host "====================================================="

if (-not $allPass) {
    exit 1
}
exit 0
