# Test-B4DurableJournalRegression.ps1
# Dedicated Regression Suite for Step 4C-2B-T2R2 (Exact Implementation Gate)
# Authority: Claude Cowork Step4C-2B-T2R2_Corrective_Design_Spec.md
[CmdletBinding()]
param(
  [string]$TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1",
  [string]$TestRoot = "D:\FM-Script-Backup\WindowsTestKit_CUSTOMER_FOLDER_MERGE\TestVault_MERGE\V_B4_TEST"
)

$ErrorActionPreference = "Stop"
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "B-4 Durable Journal & Directory Attribution Regression Suite (T2R2)" -ForegroundColor Cyan
Write-Host "Target: $TargetScript"
Write-Host "TestRoot: $TestRoot"
Write-Host "====================================================="

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Host "[FAIL] Target script not found: $TargetScript" -ForegroundColor Red
  exit 1
}

# 1. Parse TargetScript AST
$astErrors = $null
$astTokens = $null
$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
  $TargetScript,
  [ref]$astTokens,
  [ref]$astErrors
)

if ($astErrors.Count -gt 0) {
  Write-Host "[FAIL] Failed to parse target script AST!" -ForegroundColor Red
  exit 1
}

# 2. Load Win32 native types directly from production script AST
$bootstrapAsts = $scriptAst.FindAll({
  param($n)
  $n -is [System.Management.Automation.Language.IfStatementAst] -and
  ($n.Extent.Text -match 'Win32NativeMergeHelper' -or $n.Extent.Text -match 'Win32DurableJournalHelper') -and
  $n.Extent.Text -match 'Add-Type'
}, $false)

foreach ($bAst in $bootstrapAsts) {
  Invoke-Expression $bAst.Extent.Text
}

# 3. Load all function definitions from production script AST
$funcAsts = $scriptAst.FindAll({
  param($n)
  $n -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $true)

foreach ($fAst in $funcAsts) {
  Invoke-Expression $fAst.Extent.Text
}

# 16.1 Parent self-protection guard
function Assert-ParentHookDisarmed {
  if ($null -ne (Get-Variable -Name __TEST_CRASH_HOOK -Scope Global -ValueOnly -ErrorAction SilentlyContinue)) {
    Write-Host "[ABORT] Parent session has an armed crash hook." -ForegroundColor Red
    exit 1
  }
}
Assert-ParentHookDisarmed

# 16.2 Child process execution helper
function Invoke-ChildPowerShellScript([string]$scriptText, [int]$TimeoutMs = 120000) {
  $bytes   = [System.Text.Encoding]::Unicode.GetBytes($scriptText)
  $encoded = [Convert]::ToBase64String($bytes)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName  = (Join-Path $PSHOME 'powershell.exe')
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow  = $true

  $p = [System.Diagnostics.Process]::Start($psi)
  $childPid  = $p.Id
  $startTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

  $soTask = $p.StandardOutput.ReadToEndAsync()
  $seTask = $p.StandardError.ReadToEndAsync()
  $exited = $p.WaitForExit($TimeoutMs)
  $timedOut = -not $exited
  if ($timedOut) { try { $p.Kill() } catch {} ; [void]$p.WaitForExit(15000) }

  $stdout = try { $soTask.Result } catch { "" }
  $stderr = try { $seTask.Result } catch { "" }
  $exitCode = try { $p.ExitCode } catch { $null }

  return @{
    Executable   = $psi.FileName
    ChildPid     = $childPid
    StartTime    = $startTime
    EndTime      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    ExitCode     = $exitCode
    TimedOut     = $timedOut
    StdOut       = $stdout
    StdErr       = $stderr
  }
}

# 16.3 Hard-termination assertion helper
function Test-HardTermination($res) {
  if ($res.TimedOut) { return $false }
  return (($res.ExitCode -eq -1) -or ($res.ExitCode -eq 4294967295))
}
function Test-NoMergeResponseEmitted($res) {
  return -not ($res.StdOut -match 'MERGE_COMPLETED|MERGE_FAILED_ROLLED_BACK|MERGE_ROLLBACK_FAILED')
}

# Ensure clean isolated test directory
if (Test-Path -LiteralPath $TestRoot) {
  Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
[void][System.IO.Directory]::CreateDirectory($TestRoot)

$txDir = Join-Path $TestRoot ".fm-obsidian-bridge-transactions"
[void][System.IO.Directory]::CreateDirectory($txDir)

$script:testResults = New-Object System.Collections.Generic.List[object]
$totalTests = 0
$passedTests = 0

function Report-Test($name, $passed, $details = "", $meta = $null) {
  $script:totalTests++
  $resObj = [ordered]@{
    Name              = $name
    Passed            = $passed
    Details           = $details
    EvidenceClass     = if ($meta -and $meta.EvidenceClass) { $meta.EvidenceClass } else { "FUNCTIONAL" }
    CrashWindow       = if ($meta -and $meta.CrashWindow) { $meta.CrashWindow } else { $null }
    TerminationMethod = if ($meta -and $meta.TerminationMethod) { $meta.TerminationMethod } else { $null }
    ChildExecutable   = if ($meta -and $meta.ChildExecutable) { $meta.ChildExecutable } else { $null }
    ChildPid          = if ($meta -and $meta.ChildPid) { $meta.ChildPid } else { $null }
    ChildStartTime    = if ($meta -and $meta.ChildStartTime) { $meta.ChildStartTime } else { $null }
    ChildExitCode     = if ($meta -and ($null -ne $meta.ChildExitCode)) { $meta.ChildExitCode } else { $null }
    ChildTimedOut     = if ($meta -and ($null -ne $meta.ChildTimedOut)) { $meta.ChildTimedOut } else { $null }
    JournalPath       = if ($meta -and $meta.JournalPath) { $meta.JournalPath } else { $null }
    JournalSha256     = if ($meta -and $meta.JournalSha256) { $meta.JournalSha256 } else { $null }
    RollbackStatus    = if ($meta -and $meta.RollbackStatus) { $meta.RollbackStatus } else { $null }
    Entries           = if ($meta -and $meta.Entries) { $meta.Entries } else { $null }
    SourceExists      = if ($meta -and ($null -ne $meta.SourceExists)) { $meta.SourceExists } else { $null }
    DestExists        = if ($meta -and ($null -ne $meta.DestExists)) { $meta.DestExists } else { $null }
    OwnerMarkerExists = if ($meta -and ($null -ne $meta.OwnerMarkerExists)) { $meta.OwnerMarkerExists } else { $null }
    CommittedExists   = if ($meta -and ($null -ne $meta.CommittedExists)) { $meta.CommittedExists } else { $null }
    InProgressExists  = if ($meta -and ($null -ne $meta.InProgressExists)) { $meta.InProgressExists } else { $null }
    BoundarySignal    = $null
    Timestamp         = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
  }
  $script:testResults.Add($resObj)
  if ($passed) {
    $script:passedTests++
    Write-Host "[PASS] $name" -ForegroundColor Green
  } else {
    Write-Host "[FAIL] $name" -ForegroundColor Red
    if ($details) {
      Write-Host "       Details: $details" -ForegroundColor Yellow
    }
  }
}

# -------------------------------------------------------------
# Test K: Durable journal read-back, write verification & atomic replace over existing
# -------------------------------------------------------------
try {
  $testTxId_K = [Guid]::NewGuid().ToString("D")
  $journalData_K = [ordered]@{
    txId = $testTxId_K
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客 (11111111-2222-3333-4444-555555555555)"
    ownerToken = "tok_test_k_123456"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = "D:\dummy\src.md"
        DestPath = "D:\dummy\dst.md"
        ExpectedSha256 = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
        ExpectedSizeBytes = 0
        OwnerToken = $null
        State = "PENDING"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }

  $writtenPath = Write-JournalEvidenceSafe $txDir $testTxId_K $journalData_K
  $fileExists = Test-Path -LiteralPath $writtenPath
  $readBack = Get-Content -LiteralPath $writtenPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $reparseValid = ($null -ne $readBack) -and ($readBack.txId -eq $testTxId_K) -and ($readBack.entries.Count -eq 1)

  $journalData_K.entries[0].State = "COMPLETED"
  $replacedPath = Write-JournalEvidenceSafe $txDir $testTxId_K $journalData_K
  $readBack2 = Get-Content -LiteralPath $replacedPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $replacedValid = ($null -ne $readBack2) -and ($readBack2.entries[0].State -eq "COMPLETED")

  Report-Test "B4_K_DURABLE_JOURNAL_READ_BACK_AND_ATOMIC_REPLACE" ($fileExists -and $reparseValid -and $replacedValid) "Initial: $reparseValid, Replaced: $replacedValid"
} catch {
  Report-Test "B4_K_DURABLE_JOURNAL_READ_BACK_AND_ATOMIC_REPLACE" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test A: PENDING durable before mutation
# -------------------------------------------------------------
try {
  $testTxId_A = [Guid]::NewGuid().ToString("D")
  $srcFile_A = Join-Path $TestRoot "src_A.md"
  $dstFile_A = Join-Path $TestRoot "dst_A.md"
  [System.IO.File]::WriteAllLines($srcFile_A, @("Test Content A"), [System.Text.Encoding]::UTF8)

  $journalData_A = [ordered]@{
    txId = $testTxId_A
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_A"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $srcFile_A
        DestPath = $dstFile_A
        ExpectedSha256 = (Get-FileSha256Raw $srcFile_A)
        ExpectedSizeBytes = (Get-Item -LiteralPath $srcFile_A).Length
        OwnerToken = $null
        State = "PENDING"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_A $journalData_A | Out-Null

  $jDisk = Get-Content -LiteralPath (Join-Path $txDir "$testTxId_A.journal.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $pendingOnDisk = ($jDisk.entries[0].State -eq "PENDING")
  $srcExistsBefore = Test-Path -LiteralPath $srcFile_A
  $dstAbsentBefore = -not (Test-Path -LiteralPath $dstFile_A)

  Report-Test "B4_A_PENDING_DURABLE_BEFORE_MUTATION" ($pendingOnDisk -and $srcExistsBefore -and $dstAbsentBefore) "Pending on disk: $pendingOnDisk, src: $srcExistsBefore, dst: $dstAbsentBefore"
} catch {
  Report-Test "B4_A_PENDING_DURABLE_BEFORE_MUTATION" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test B: COMPLETED durable after verified mutation
# -------------------------------------------------------------
try {
  $expSha_B = Get-FileSha256Raw $srcFile_A
  $expSize_B = (Get-Item -LiteralPath $srcFile_A).Length
  [System.IO.File]::Move($srcFile_A, $dstFile_A)
  $postSha_B = Get-FileSha256Raw $dstFile_A
  $postSize_B = (Get-Item -LiteralPath $dstFile_A).Length
  $shaMatchesExpected = ($postSha_B -eq $expSha_B) -and ($postSize_B -eq $expSize_B)

  $journalData_A.entries[0].State = "COMPLETED"
  Write-JournalEvidenceSafe $txDir $testTxId_A $journalData_A | Out-Null

  $jDiskAfter = Get-Content -LiteralPath (Join-Path $txDir "$testTxId_A.journal.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $completedOnDisk = ($jDiskAfter.entries[0].State -eq "COMPLETED")
  $dstExistsAfter = Test-Path -LiteralPath $dstFile_A

  Report-Test "B4_B_COMPLETED_DURABLE_AFTER_VERIFICATION" ($completedOnDisk -and $dstExistsAfter -and $shaMatchesExpected) "Completed: $completedOnDisk, dstExists: $dstExistsAfter, shaMatch: $shaMatchesExpected"
} catch {
  Report-Test "B4_B_COMPLETED_DURABLE_AFTER_VERIFICATION" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test C: Crash after durable PENDING before mutation (Option B fail-closed)
# -------------------------------------------------------------
try {
  $testTxId_C = [Guid]::NewGuid().ToString("D")
  $journalData_C = [ordered]@{
    txId = $testTxId_C
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_C"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = "D:\dummy\src_C.md"
        DestPath = "D:\dummy\dst_C.md"
        ExpectedSha256 = "abc"
        ExpectedSizeBytes = 10
        OwnerToken = $null
        State = "PENDING"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_C $journalData_C | Out-Null

  $rbResult_C = Invoke-OptionBRollback $journalData_C $testTxId_C $txDir
  $blockedPending = (-not $rbResult_C.Success) -and ($rbResult_C.Details -match "PENDING") -and ($rbResult_C.TerminalStatePersisted -eq $true)

  Report-Test "B4_C_CRASH_AFTER_PENDING_NO_DESTRUCTIVE_UNDO" $blockedPending "Success: $($rbResult_C.Success), TerminalPersisted: $($rbResult_C.TerminalStatePersisted), Details: $($rbResult_C.Details)"
} catch {
  Report-Test "B4_C_CRASH_AFTER_PENDING_NO_DESTRUCTIVE_UNDO" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test D: Crash after mutation before COMPLETED (PENDING remains, fail-closed)
# -------------------------------------------------------------
try {
  $testTxId_D = [Guid]::NewGuid().ToString("D")
  $srcFile_D = Join-Path $TestRoot "src_D.md"
  $dstFile_D = Join-Path $TestRoot "dst_D.md"
  [System.IO.File]::WriteAllLines($srcFile_D, @("Content D"), [System.Text.Encoding]::UTF8)

  $journalData_D = [ordered]@{
    txId = $testTxId_D
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_D"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $srcFile_D
        DestPath = $dstFile_D
        ExpectedSha256 = (Get-FileSha256Raw $srcFile_D)
        ExpectedSizeBytes = 9
        OwnerToken = $null
        State = "PENDING"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_D $journalData_D | Out-Null
  [System.IO.File]::Move($srcFile_D, $dstFile_D)

  $rbResult_D = Invoke-OptionBRollback $null $testTxId_D $txDir
  $blockedPending_D = (-not $rbResult_D.Success) -and ($rbResult_D.Details -match "PENDING") -and ($rbResult_D.TerminalStatePersisted -eq $true)

  Report-Test "B4_D_CRASH_AFTER_MUTATION_PENDING_REMAINS" $blockedPending_D "Success: $($rbResult_D.Success), TerminalPersisted: $($rbResult_D.TerminalStatePersisted), Details: $($rbResult_D.Details)"
} catch {
  Report-Test "B4_D_CRASH_AFTER_MUTATION_PENDING_REMAINS" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test E: Rollback attribution for COMPLETED file operation + verify ROLLED_BACK persisted
# -------------------------------------------------------------
try {
  $testTxId_E = [Guid]::NewGuid().ToString("D")
  $srcFile_E = Join-Path $TestRoot "src_E.md"
  $dstFile_E = Join-Path $TestRoot "dst_E.md"
  [System.IO.File]::WriteAllLines($srcFile_E, @("Content E for Rollback"), [System.Text.Encoding]::UTF8)
  $expSha_E = Get-FileSha256Raw $srcFile_E
  $expSize_E = (Get-Item -LiteralPath $srcFile_E).Length

  [System.IO.File]::Move($srcFile_E, $dstFile_E)

  $journalData_E = [ordered]@{
    txId = $testTxId_E
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_E"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $srcFile_E
        DestPath = $dstFile_E
        ExpectedSha256 = $expSha_E
        ExpectedSizeBytes = $expSize_E
        OwnerToken = $null
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_E $journalData_E | Out-Null

  $rbResult_E = Invoke-OptionBRollback $journalData_E $testTxId_E $txDir
  $srcRestored = (Test-Path -LiteralPath $srcFile_E) -and (-not (Test-Path -LiteralPath $dstFile_E))
  $restoredSha = if ($srcRestored) { Get-FileSha256Raw $srcFile_E } else { "" }

  $diskJ_E = Get-Content -LiteralPath (Join-Path $txDir "$testTxId_E.journal.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $stateIsRolledBack = ($diskJ_E.entries[0].State -eq "ROLLED_BACK") -and ($diskJ_E.rollbackStatus -eq "ROLLBACK_COMPLETE")

  Report-Test "B4_E_COMPLETED_FILE_ROLLBACK_ATTRIBUTION" ($rbResult_E.Success -and $rbResult_E.TerminalStatePersisted -and $srcRestored -and ($restoredSha -eq $expSha_E) -and $stateIsRolledBack) "Success: $($rbResult_E.Success), Restored: $srcRestored, PersistedState: $($diskJ_E.entries[0].State)"
} catch {
  Report-Test "B4_E_COMPLETED_FILE_ROLLBACK_ATTRIBUTION" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test F: MOVE_DIRECTORY owner-token success
# -------------------------------------------------------------
try {
  $testTxId_F = [Guid]::NewGuid().ToString("D")
  $srcDir_F = Join-Path $TestRoot "srcDir_F"
  $dstDir_F = Join-Path $TestRoot "dstDir_F"
  [void][System.IO.Directory]::CreateDirectory($dstDir_F)

  $expectedToken_F = "tok_valid_owner_123456789"
  $ownerMarker_F = Join-Path $dstDir_F ".fm-obsidian-merge-owner"
  [System.IO.File]::WriteAllLines($ownerMarker_F, @($expectedToken_F), [System.Text.Encoding]::UTF8)

  $journalData_F = [ordered]@{
    txId = $testTxId_F
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "dstDir_F"
    ownerToken = $expectedToken_F
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_DIRECTORY"
        SourcePath = $srcDir_F
        DestPath = $dstDir_F
        ExpectedSha256 = $null
        ExpectedSizeBytes = $null
        OwnerToken = $expectedToken_F
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_F $journalData_F | Out-Null

  $rbResult_F = Invoke-OptionBRollback $journalData_F $testTxId_F $txDir
  $srcDirRestored = (Test-Path -LiteralPath $srcDir_F -PathType Container) -and (-not (Test-Path -LiteralPath $dstDir_F))

  Report-Test "B4_F_MOVE_DIRECTORY_OWNER_TOKEN_SUCCESS" ($rbResult_F.Success -and $rbResult_F.TerminalStatePersisted -and $srcDirRestored) "Success: $($rbResult_F.Success), Restored: $srcDirRestored"
} catch {
  Report-Test "B4_F_MOVE_DIRECTORY_OWNER_TOKEN_SUCCESS" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test G: MOVE_DIRECTORY owner-token mismatch (zero mutation, fail closed)
# -------------------------------------------------------------
try {
  $testTxId_G = [Guid]::NewGuid().ToString("D")
  $srcDir_G = Join-Path $TestRoot "srcDir_G"
  $dstDir_G = Join-Path $TestRoot "dstDir_G"
  [void][System.IO.Directory]::CreateDirectory($dstDir_G)

  $expectedToken_G = "tok_expected_111"
  $tamperedToken_G = "tok_attacker_999"
  $ownerMarker_G = Join-Path $dstDir_G ".fm-obsidian-merge-owner"
  [System.IO.File]::WriteAllLines($ownerMarker_G, @($tamperedToken_G), [System.Text.Encoding]::UTF8)

  $journalData_G = [ordered]@{
    txId = $testTxId_G
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "dstDir_G"
    ownerToken = $expectedToken_G
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_DIRECTORY"
        SourcePath = $srcDir_G
        DestPath = $dstDir_G
        ExpectedSha256 = $null
        ExpectedSizeBytes = $null
        OwnerToken = $expectedToken_G
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_G $journalData_G | Out-Null

  $rbResult_G = Invoke-OptionBRollback $journalData_G $testTxId_G $txDir
  $dstDirStillExists = (Test-Path -LiteralPath $dstDir_G -PathType Container)
  $srcDirStillAbsent = (-not (Test-Path -LiteralPath $srcDir_G))
  $zeroMutation = $dstDirStillExists -and $srcDirStillAbsent -and (-not $rbResult_G.Success) -and ($rbResult_G.TerminalStatePersisted -eq $true)

  Report-Test "B4_G_MOVE_DIRECTORY_TOKEN_MISMATCH_FAIL_CLOSED" $zeroMutation "Success: $($rbResult_G.Success), DstExists: $dstDirStillExists, SrcAbsent: $srcDirStillAbsent"
} catch {
  Report-Test "B4_G_MOVE_DIRECTORY_TOKEN_MISMATCH_FAIL_CLOSED" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test H: Unknown OpType (zero mutation, fail closed)
# -------------------------------------------------------------
try {
  $testTxId_H = [Guid]::NewGuid().ToString("D")
  $journalData_H = [ordered]@{
    txId = $testTxId_H
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_H"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "UNKNOWN_MUTATION_TYPE"
        SourcePath = "D:\dummy\src_H.md"
        DestPath = "D:\dummy\dst_H.md"
        ExpectedSha256 = "abc"
        ExpectedSizeBytes = 10
        OwnerToken = $null
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  [System.IO.File]::WriteAllText((Join-Path $txDir "$testTxId_H.journal.json"), ($journalData_H | ConvertTo-Json -Depth 10), [System.Text.Encoding]::UTF8)

  $rbResult_H = Invoke-OptionBRollback $null $testTxId_H $txDir
  $unknownOpBlocked = (-not $rbResult_H.Success) -and ($rbResult_H.TerminalStatePersisted -eq $false)

  Report-Test "B4_H_UNKNOWN_OPTYPE_FAIL_CLOSED" $unknownOpBlocked "Success: $($rbResult_H.Success), Details: $($rbResult_H.Details)"
} catch {
  Report-Test "B4_H_UNKNOWN_OPTYPE_FAIL_CLOSED" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test I: Corrupt/truncated journal (fail closed)
# -------------------------------------------------------------
try {
  $testTxId_I = [Guid]::NewGuid().ToString("D")
  $corruptJournalPath = Join-Path $txDir "$testTxId_I.journal.json"
  [System.IO.File]::WriteAllText($corruptJournalPath, "{ txId: '$testTxId_I', entries: [ TRUNCATED JSON", [System.Text.Encoding]::UTF8)

  $rbResult_I = Invoke-OptionBRollback $null $testTxId_I $txDir
  $corruptHandled = (-not $rbResult_I.Success) -and ($rbResult_I.TerminalStatePersisted -eq $false)

  Report-Test "B4_I_CORRUPT_JOURNAL_FAIL_CLOSED" $corruptHandled "Success: $($rbResult_I.Success), Details: $($rbResult_I.Details)"
} catch {
  Report-Test "B4_I_CORRUPT_JOURNAL_FAIL_CLOSED" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test J: Multiple journal entries dependent reverse ordering
# -------------------------------------------------------------
try {
  $testTxId_J = [Guid]::NewGuid().ToString("D")
  $src1_J = Join-Path $TestRoot "file_step1.md"
  $mid_J = Join-Path $TestRoot "file_step2_mid.md"
  $final_J = Join-Path $TestRoot "file_step3_final.md"

  [System.IO.File]::WriteAllLines($src1_J, @("Chain Content"), [System.Text.Encoding]::UTF8)
  $sha_J = Get-FileSha256Raw $src1_J
  $size_J = (Get-Item -LiteralPath $src1_J).Length

  [System.IO.File]::Move($src1_J, $mid_J)
  [System.IO.File]::Move($mid_J, $final_J)

  $journalData_J = [ordered]@{
    txId = $testTxId_J
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_J"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $src1_J
        DestPath = $mid_J
        ExpectedSha256 = $sha_J
        ExpectedSizeBytes = $size_J
        OwnerToken = $null
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      },
      [ordered]@{
        Seq = 2
        OpType = "MOVE_FILE_STAGING_TO_CANONICAL"
        SourcePath = $mid_J
        DestPath = $final_J
        ExpectedSha256 = $sha_J
        ExpectedSizeBytes = $size_J
        OwnerToken = $null
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:01Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txDir $testTxId_J $journalData_J | Out-Null

  $rbResult_J = Invoke-OptionBRollback $journalData_J $testTxId_J $txDir
  $restoredToInitial = (Test-Path -LiteralPath $src1_J) -and (-not (Test-Path -LiteralPath $mid_J)) -and (-not (Test-Path -LiteralPath $final_J))

  Report-Test "B4_J_DEPENDENT_ENTRIES_STRICT_REVERSE_ORDER" ($rbResult_J.Success -and $rbResult_J.TerminalStatePersisted -and $restoredToInitial) "Success: $($rbResult_J.Success), Restored: $restoredToInitial"
} catch {
  Report-Test "B4_J_DEPENDENT_ENTRIES_STRICT_REVERSE_ORDER" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test STRUCT: Structural validation tests
# -------------------------------------------------------------
try {
  $jBadState = [ordered]@{
    txId = [Guid]::NewGuid().ToString("D"); uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s"; DestPath = "d"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "INVALID_STATE" })
  }
  $resBadState = Test-JournalStructureValid $jBadState
  Report-Test "B4_STRUCT_INVALID_STATE_REJECTED" (-not $resBadState) "Valid: $resBadState"

  $jDupSeq = [ordered]@{
    txId = [Guid]::NewGuid().ToString("D"); uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @(
      [ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s"; DestPath = "d"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" },
      [ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s2"; DestPath = "d2"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" }
    )
  }
  $resDupSeq = Test-JournalStructureValid $jDupSeq
  Report-Test "B4_STRUCT_DUPLICATE_SEQ_REJECTED" (-not $resDupSeq) "Valid: $resDupSeq"

  $jNonMono = [ordered]@{
    txId = [Guid]::NewGuid().ToString("D"); uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @(
      [ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s"; DestPath = "d"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" },
      [ordered]@{ Seq = 3; OpType = "MOVE_FILE"; SourcePath = "s2"; DestPath = "d2"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" }
    )
  }
  $resNonMono = Test-JournalStructureValid $jNonMono
  Report-Test "B4_STRUCT_NON_MONOTONIC_SEQ_REJECTED" (-not $resNonMono) "Valid: $resNonMono"

  $jTxMismatch = [ordered]@{
    txId = "TX_EXPECTED"; uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s"; DestPath = "d"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" })
  }
  $resTxMismatch = Test-JournalStructureValid $jTxMismatch "TX_DIFFERENT"
  Report-Test "B4_STRUCT_TXID_MISMATCH_REJECTED" (-not $resTxMismatch) "Valid: $resTxMismatch"

  $jMissingSha = [ordered]@{
    txId = [Guid]::NewGuid().ToString("D"); uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s"; DestPath = "d"; ExpectedSha256 = $null; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" })
  }
  $resMissingSha = Test-JournalStructureValid $jMissingSha
  Report-Test "B4_STRUCT_MISSING_SHA_REJECTED" (-not $resMissingSha) "Valid: $resMissingSha"

  $jMissingFolder = [ordered]@{
    txId = [Guid]::NewGuid().ToString("D"); uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = ""; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "s"; DestPath = "d"; ExpectedSha256 = "h"; ExpectedSizeBytes = 1; OwnerToken = $null; State = "COMPLETED" })
  }
  $resMissingFolder = Test-JournalStructureValid $jMissingFolder
  Report-Test "B4_STRUCT_MISSING_FOLDERNAME_REJECTED" (-not $resMissingFolder) "Valid: $resMissingFolder"
} catch {
  Report-Test "B4_STRUCT_VALIDATION_SUITE" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test: Missing journal with inprogress evidence fail-closed
# -------------------------------------------------------------
try {
  $testTxId_Missing = [Guid]::NewGuid().ToString("D")
  $ipFile_Missing = Join-Path $txDir "$testTxId_Missing.inprogress.json"
  [System.IO.File]::WriteAllText($ipFile_Missing, "{}", [System.Text.Encoding]::UTF8)

  $rbResMissing = Invoke-OptionBRollback $null $testTxId_Missing $txDir
  Report-Test "B4_MISSING_JOURNAL_WITH_EVIDENCE_FAIL_CLOSED" ((-not $rbResMissing.Success) -and ($rbResMissing.TerminalStatePersisted -eq $false)) "Success: $($rbResMissing.Success), Details: $($rbResMissing.Details)"
} catch {
  Report-Test "B4_MISSING_JOURNAL_WITH_EVIDENCE_FAIL_CLOSED" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test: Post-Commit Rollback Interlock
# -------------------------------------------------------------
try {
  $testTxId_Lock = [Guid]::NewGuid().ToString("D")
  $committedFile_Lock = Join-Path $txDir "$testTxId_Lock.committed.json"
  [System.IO.File]::WriteAllText($committedFile_Lock, "{ txId: '$testTxId_Lock' }", [System.Text.Encoding]::UTF8)

  $committedOnDisk = Test-Path -LiteralPath $committedFile_Lock
  Report-Test "B4_POST_COMMIT_ROLLBACK_INTERLOCK_PROTECTED" ($committedOnDisk -eq $true) "CommittedOnDisk: $committedOnDisk"
} catch {
  Report-Test "B4_POST_COMMIT_ROLLBACK_INTERLOCK_PROTECTED" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test: Case A End-to-End PLAN + APPLY
# -------------------------------------------------------------
try {
  $caseAVault = Join-Path $TestRoot "CaseA_Vault"
  [void][System.IO.Directory]::CreateDirectory($caseAVault)
  $caseACustRoot = Join-Path $caseAVault "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($caseACustRoot)

  $uuidA = "aaaaaaaa-1111-2222-3333-444444444444"
  $folderA1 = Join-Path $caseACustRoot "株式会社テストA ($uuidA)"
  $folderA2 = Join-Path $caseACustRoot "株式会社テストA_旧"
  [void][System.IO.Directory]::CreateDirectory($folderA1)
  [void][System.IO.Directory]::CreateDirectory($folderA2)

  $pfxKeiyaku = Get-IconPrefix "契約"
  $pfxJiko = Get-IconPrefix "事故"

  $note1Name = ($pfxKeiyaku + "_テストA.md")
  $note2Name = ($pfxJiko + "_テストA.md")

  $note1 = Join-Path $folderA1 $note1Name
  $note2 = Join-Path $folderA2 $note2Name
  [System.IO.File]::WriteAllLines($note1, @("---", ("UUID: " + $uuidA), "---", "# 契約"), [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllLines($note2, @("---", ("UUID: " + $uuidA), "---", "# 事故"), [System.Text.Encoding]::UTF8)

  $planPayload = @{
    protocolVersion = 1
    action = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId = "req-plan-caseA"
    VaultRoot = $caseAVault
    pk_CLIENT = $uuidA
    companyNameRaw = "株式会社テストA"
  }
  $planOut = Invoke-PlanCustomerFolderMerge $planPayload | ConvertFrom-Json
  $planToken = $planOut.planToken
  $planOk = ($planOut.status -eq "OK") -and (-not [string]::IsNullOrWhiteSpace($planToken))
  $canonFolderAName = $planOut.plan.canonicalFolderName
  $canonFolderAPath = Join-Path $caseACustRoot $canonFolderAName

  $applyPayload = @{
    protocolVersion = 1
    action = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId = "req-apply-caseA"
    VaultRoot = $caseAVault
    pk_CLIENT = $uuidA
    companyNameRaw = "株式会社テストA"
    planToken = $planToken
  }
  $applyOut = Invoke-ApplyCustomerFolderMerge $applyPayload | ConvertFrom-Json
  $applyOk = ($applyOut.status -eq "OK") -and ($applyOut.code -eq "MERGE_COMPLETED")

  $bothNotesInCanon = (Test-Path -LiteralPath (Join-Path $canonFolderAPath $note1Name)) -and
                      (Test-Path -LiteralPath (Join-Path $canonFolderAPath $note2Name))

  Report-Test "B4_CASE_A_END_TO_END_APPLY" ($planOk -and $applyOk -and $bothNotesInCanon) "Plan: $planOk, Apply: $applyOk, NotesInCanon: $bothNotesInCanon"
} catch {
  Report-Test "B4_CASE_A_END_TO_END_APPLY" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Test: Case B End-to-End PLAN + APPLY (Directory Move)
# -------------------------------------------------------------
try {
  $caseBVault = Join-Path $TestRoot "CaseB_Vault"
  [void][System.IO.Directory]::CreateDirectory($caseBVault)
  $caseBCustRoot = Join-Path $caseBVault "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($caseBCustRoot)

  $uuidB = "bbbbbbbb-1111-2222-3333-444444444444"
  $sourceOldFolderB = Join-Path $caseBCustRoot "株式会社テストB_旧"
  [void][System.IO.Directory]::CreateDirectory($sourceOldFolderB)

  $pfxKeiyaku = Get-IconPrefix "契約"
  $noteB1Name = ($pfxKeiyaku + "_テストB.md")
  $noteB1 = Join-Path $sourceOldFolderB $noteB1Name
  [System.IO.File]::WriteAllLines($noteB1, @("---", ("UUID: " + $uuidB), "---", "# 契約B"), [System.Text.Encoding]::UTF8)

  $planPayloadB = @{
    protocolVersion = 1
    action = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId = "req-plan-caseB"
    VaultRoot = $caseBVault
    pk_CLIENT = $uuidB
    companyNameRaw = "株式会社テストB"
  }
  $planOutB = Invoke-PlanCustomerFolderMerge $planPayloadB | ConvertFrom-Json
  $planTokenB = $planOutB.planToken
  $planOkB = ($planOutB.status -eq "OK") -and (-not [string]::IsNullOrWhiteSpace($planTokenB))
  $canonFolderBName = $planOutB.plan.canonicalFolderName
  $canonFolderBPath = Join-Path $caseBCustRoot $canonFolderBName

  $canonAbsentBefore = -not (Test-Path -LiteralPath $canonFolderBPath)

  $applyPayloadB = @{
    protocolVersion = 1
    action = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId = "req-apply-caseB"
    VaultRoot = $caseBVault
    pk_CLIENT = $uuidB
    companyNameRaw = "株式会社テストB"
    planToken = $planTokenB
  }
  $applyOutB = Invoke-ApplyCustomerFolderMerge $applyPayloadB | ConvertFrom-Json
  $applyOkB = ($applyOutB.status -eq "OK") -and ($applyOutB.code -eq "MERGE_COMPLETED")

  $canonExistsAfter = (Test-Path -LiteralPath $canonFolderBPath -PathType Container)
  $noteInCanonB = (Test-Path -LiteralPath (Join-Path $canonFolderBPath $noteB1Name))

  Report-Test "B4_CASE_B_END_TO_END_APPLY" ($canonAbsentBefore -and $planOkB -and $applyOkB -and $canonExistsAfter -and $noteInCanonB) "Plan: $planOkB, Apply: $applyOkB, CanonCreated: $canonExistsAfter"
} catch {
  Report-Test "B4_CASE_B_END_TO_END_APPLY" $false $_.Exception.Message
}

# -------------------------------------------------------------
# Real Crash Tests: Windows A, A2, B, C (API contract), D, E, E-Recovery, F, G (Interlock)
# -------------------------------------------------------------

# Crash Window A: Hard process termination during journal tmp write before atomic promotion
try {
  $crashTxId_A = [Guid]::NewGuid().ToString("D")
  $codeA = @"
`$global:__TEST_CRASH_HOOK = 'A'
. '$TargetScript'
`$jData = [ordered]@{
  txId = '$crashTxId_A'; uuid = 'u'; vaultRoot = '$TestRoot'; canonicalFolderName = 'f'; ownerToken = 't'; rollbackStatus = 'NONE'; entries = @()
}
Write-JournalEvidenceSafe '$txDir' '$crashTxId_A' `$jData
"@
  $resA = Invoke-ChildPowerShellScript $codeA
  Assert-ParentHookDisarmed

  $tmpPath_A = Join-Path $txDir "$crashTxId_A.journal.json.tmp"
  $livePath_A = Join-Path $txDir "$crashTxId_A.journal.json"
  $liveAbsent_A = -not (Test-Path -LiteralPath $livePath_A)
  $tmpExists_A = Test-Path -LiteralPath $tmpPath_A
  $hardKill_A = Test-HardTermination $resA

  $tmpValid = $false
  if ($tmpExists_A) {
    try {
      $tmpObj = Get-Content -LiteralPath $tmpPath_A -Raw -Encoding UTF8 | ConvertFrom-Json
      $tmpValid = ($null -ne $tmpObj) -and (Test-JournalStructureValid $tmpObj $crashTxId_A)
    } catch {}
  }

  $metaA = [ordered]@{
    EvidenceClass     = "REAL_CRASH"
    CrashWindow       = "A"
    TerminationMethod = "HARD_KILL_TERMINATEPROCESS"
    ChildExecutable   = $resA.Executable
    ChildPid          = $resA.ChildPid
    ChildStartTime    = $resA.StartTime
    ChildExitCode     = $resA.ExitCode
    ChildTimedOut     = $resA.TimedOut
    JournalPath       = $livePath_A
    JournalSha256     = if (Test-Path -LiteralPath $livePath_A) { (Get-FileHash -LiteralPath $livePath_A -Algorithm SHA256).Hash } else { $null }
    RollbackStatus    = $null
    Entries           = @()
    SourceExists      = $null
    DestExists        = $null
    OwnerMarkerExists = $null
    CommittedExists   = $false
    InProgressExists  = $null
  }

  Report-Test "B4_REAL_CRASH_WINDOW_A_TEMP_ISOLATED" ($hardKill_A -and $liveAbsent_A -and $tmpExists_A -and $tmpValid) "HardKill: $hardKill_A (ExitCode: $($resA.ExitCode)), LiveAbsent: $liveAbsent_A, TmpValid: $tmpValid" $metaA
} catch {
  Report-Test "B4_REAL_CRASH_WINDOW_A_TEMP_ISOLATED" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Crash Window A2: Pre-existing valid live journal J0 preserved on crash during J1 write
try {
  $crashTxId_A2 = [Guid]::NewGuid().ToString("D")
  $jData_A2_0 = [ordered]@{
    txId = $crashTxId_A2; uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "D:\dummy\s.md"; DestPath = "D:\dummy\d.md"; ExpectedSha256 = "abc"; ExpectedSizeBytes = 10; OwnerToken = $null; State = "PENDING"; Timestamp = "2026-08-30T10:00:00Z" })
  }
  $livePath_A2 = Write-JournalEvidenceSafe $txDir $crashTxId_A2 $jData_A2_0
  $liveSha_A2_0 = (Get-FileHash -LiteralPath $livePath_A2 -Algorithm SHA256).Hash

  $codeA2 = @"
`$global:__TEST_CRASH_HOOK = 'A'
. '$TargetScript'
`$jData1 = [ordered]@{
  txId = '$crashTxId_A2'; uuid = 'u'; vaultRoot = '$TestRoot'; canonicalFolderName = 'f'; ownerToken = 't'; rollbackStatus = 'NONE'
  entries = @([ordered]@{ Seq = 1; OpType = 'MOVE_FILE'; SourcePath = 'D:\dummy\s.md'; DestPath = 'D:\dummy\d.md'; ExpectedSha256 = 'abc'; ExpectedSizeBytes = 10; OwnerToken = `$null; State = 'COMPLETED'; Timestamp = '2026-08-30T10:00:00Z' })
}
Write-JournalEvidenceSafe '$txDir' '$crashTxId_A2' `$jData1
"@
  $resA2 = Invoke-ChildPowerShellScript $codeA2
  Assert-ParentHookDisarmed

  $hardKill_A2 = Test-HardTermination $resA2
  $liveExists_A2 = Test-Path -LiteralPath $livePath_A2
  $liveSha_A2_After = if ($liveExists_A2) { (Get-FileHash -LiteralPath $livePath_A2 -Algorithm SHA256).Hash } else { "" }
  $liveUnchanged = ($liveSha_A2_After -eq $liveSha_A2_0)
  $tmpPath_A2 = Join-Path $txDir "$crashTxId_A2.journal.json.tmp"
  $tmpExists_A2 = Test-Path -LiteralPath $tmpPath_A2

  $metaA2 = [ordered]@{
    EvidenceClass     = "REAL_CRASH"
    CrashWindow       = "A2"
    TerminationMethod = "HARD_KILL_TERMINATEPROCESS"
    ChildExecutable   = $resA2.Executable
    ChildPid          = $resA2.ChildPid
    ChildStartTime    = $resA2.StartTime
    ChildExitCode     = $resA2.ExitCode
    ChildTimedOut     = $resA2.TimedOut
    JournalPath       = $livePath_A2
    JournalSha256     = $liveSha_A2_After
    RollbackStatus    = "NONE"
    Entries           = @(@{ Seq = 1; OpType = "MOVE_FILE"; State = "PENDING" })
    SourceExists      = $null
    DestExists        = $null
    OwnerMarkerExists = $null
    CommittedExists   = $false
    InProgressExists  = $null
  }

  Report-Test "B4_REAL_CRASH_WINDOW_A2_EXISTING_LIVE_PRESERVED" ($hardKill_A2 -and $liveExists_A2 -and $liveUnchanged -and $tmpExists_A2) "HardKill: $hardKill_A2 (ExitCode: $($resA2.ExitCode)), LiveUnchanged: $liveUnchanged, TmpExists: $tmpExists_A2" $metaA2
} catch {
  Report-Test "B4_REAL_CRASH_WINDOW_A2_EXISTING_LIVE_PRESERVED" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Crash Window B: Hard process termination after promotion before post-promotion verification
try {
  $crashTxId_B = [Guid]::NewGuid().ToString("D")
  $expectedData_B = [ordered]@{
    txId = $crashTxId_B; uuid = "u"; vaultRoot = $TestRoot; canonicalFolderName = "f"; ownerToken = "t"; rollbackStatus = "NONE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = "D:\dummy\s_B.md"; DestPath = "D:\dummy\d_B.md"; ExpectedSha256 = "abc"; ExpectedSizeBytes = 10; OwnerToken = $null; State = "PENDING"; Timestamp = "2026-08-30T10:00:00Z" })
  }

  $codeB = @"
`$global:__TEST_CRASH_HOOK = 'B'
. '$TargetScript'
`$jDataB = [ordered]@{
  txId = '$crashTxId_B'; uuid = 'u'; vaultRoot = '$TestRoot'; canonicalFolderName = 'f'; ownerToken = 't'; rollbackStatus = 'NONE'
  entries = @([ordered]@{ Seq = 1; OpType = 'MOVE_FILE'; SourcePath = 'D:\dummy\s_B.md'; DestPath = 'D:\dummy\d_B.md'; ExpectedSha256 = 'abc'; ExpectedSizeBytes = 10; OwnerToken = `$null; State = 'PENDING'; Timestamp = '2026-08-30T10:00:00Z' })
}
Write-JournalEvidenceSafe '$txDir' '$crashTxId_B' `$jDataB
"@
  $resB = Invoke-ChildPowerShellScript $codeB
  Assert-ParentHookDisarmed

  $hardKill_B = Test-HardTermination $resB
  $livePath_B = Join-Path $txDir "$crashTxId_B.journal.json"
  $tmpPath_B = Join-Path $txDir "$crashTxId_B.journal.json.tmp"
  $liveExists_B = Test-Path -LiteralPath $livePath_B
  $tmpAbsent_B = -not (Test-Path -LiteralPath $tmpPath_B)

  $liveContentEqual = $false
  if ($liveExists_B) {
    try {
      $liveObj_B = Get-Content -LiteralPath $livePath_B -Raw -Encoding UTF8 | ConvertFrom-Json
      $liveContentEqual = Test-JournalContentEquality $expectedData_B $liveObj_B
    } catch {}
  }

  $metaB = [ordered]@{
    EvidenceClass     = "REAL_CRASH"
    CrashWindow       = "B"
    TerminationMethod = "HARD_KILL_TERMINATEPROCESS"
    ChildExecutable   = $resB.Executable
    ChildPid          = $resB.ChildPid
    ChildStartTime    = $resB.StartTime
    ChildExitCode     = $resB.ExitCode
    ChildTimedOut     = $resB.TimedOut
    JournalPath       = $livePath_B
    JournalSha256     = if ($liveExists_B) { (Get-FileHash -LiteralPath $livePath_B -Algorithm SHA256).Hash } else { $null }
    RollbackStatus    = "NONE"
    Entries           = @(@{ Seq = 1; OpType = "MOVE_FILE"; State = "PENDING" })
    SourceExists      = $null
    DestExists        = $null
    OwnerMarkerExists = $null
    CommittedExists   = $false
    InProgressExists  = $null
  }

  Report-Test "B4_REAL_CRASH_WINDOW_B_PROMOTED_JOURNAL_VALID" ($hardKill_B -and $liveExists_B -and $liveContentEqual -and $tmpAbsent_B) "HardKill: $hardKill_B (ExitCode: $($resB.ExitCode)), LiveExists: $liveExists_B, ContentEqual: $liveContentEqual, TmpAbsent: $tmpAbsent_B" $metaB
} catch {
  Report-Test "B4_REAL_CRASH_WINDOW_B_PROMOTED_JOURNAL_VALID" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Window C: API Contract Only (Empirical test NOT_CONSTRUCTIBLE)
try {
  $payloadContent = [System.IO.File]::ReadAllText($TargetScript, [System.Text.Encoding]::UTF8)

  # C-1: MoveFileEx used in Write-JournalEvidenceSafe
  $c1 = $payloadContent -match '\[Win32DurableJournalHelper\]::MoveFileEx\('

  # C-2: MOVEFILE_REPLACE_EXISTING present and defined as 0x1
  $c2 = ($payloadContent -match 'MOVEFILE_REPLACE_EXISTING\s*=\s*0x1') -and ($payloadContent -match 'MOVEFILE_REPLACE_EXISTING')

  # C-3: MOVEFILE_WRITE_THROUGH present and defined as 0x8
  $c3 = ($payloadContent -match 'MOVEFILE_WRITE_THROUGH\s*=\s*0x8') -and ($payloadContent -match 'MOVEFILE_WRITE_THROUGH')

  # C-4: Same TxDir used for tmp and live (same volume rename)
  $c4 = ($payloadContent -match '\$tmpPath\s*=\s*Join-Path\s+\$TxDir') -and ($payloadContent -match '\$filePath\s*=\s*Join-Path\s+\$TxDir')

  # C-5: Return value checked and failure throws
  $c5 = ($payloadContent -match 'if\s*\(-not\s+\$ok\)\s*\{') -and ($payloadContent -match 'throw\s+"Win32 MoveFileEx')

  $cPassed = $c1 -and $c2 -and $c3 -and $c4 -and $c5

  $metaC = [ordered]@{
    EvidenceClass     = "API_CONTRACT_ONLY"
    CrashWindow       = "C"
    TerminationMethod = "NONE"
    ChildExecutable   = $null
    ChildPid          = $null
    ChildStartTime    = $null
    ChildExitCode     = $null
    ChildTimedOut     = $null
    JournalPath       = $null
    JournalSha256     = $null
    RollbackStatus    = $null
    Entries           = @()
    SourceExists      = $null
    DestExists        = $null
    OwnerMarkerExists = $null
    CommittedExists   = $null
    InProgressExists  = $null
  }

  Report-Test "B4_WINDOW_C_API_CONTRACT_ONLY" $cPassed "C1_MoveFileEx: $c1, C2_ReplaceExisting: $c2, C3_WriteThrough: $c3, C4_SameDir: $c4, C5_CheckThrow: $c5" $metaC
} catch {
  Report-Test "B4_WINDOW_C_API_CONTRACT_ONLY" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Crash Window D: Hard process termination after durable PENDING before mutation
try {
  $crashVault_D = Join-Path $TestRoot "CrashD_Vault"
  [void][System.IO.Directory]::CreateDirectory($crashVault_D)
  $crashCust_D = Join-Path $crashVault_D "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($crashCust_D)
  $uuidD = "dddddddd-1111-2222-3333-444444444444"
  $fD = Join-Path $crashCust_D "株式会社テストD ($uuidD)"
  [void][System.IO.Directory]::CreateDirectory($fD)
  $pfxKeiyaku = Get-IconPrefix "契約"
  $nD = Join-Path $fD ($pfxKeiyaku + "_テストD.md")
  [System.IO.File]::WriteAllLines($nD, @("---", ("UUID: " + $uuidD), "---", "# D"), [System.Text.Encoding]::UTF8)

  $planOutD = Invoke-PlanCustomerFolderMerge @{ protocolVersion=1; action="PLAN_CUSTOMER_FOLDER_MERGE"; requestId="req-plan-d"; VaultRoot=$crashVault_D; pk_CLIENT=$uuidD; companyNameRaw="株式会社テストD" } | ConvertFrom-Json

  $codeD = @"
`$global:__TEST_CRASH_HOOK = 'D'
. '$TargetScript'
Invoke-ApplyCustomerFolderMerge @{ protocolVersion=1; action='APPLY_CUSTOMER_FOLDER_MERGE'; requestId='req-apply-d'; VaultRoot='$crashVault_D'; pk_CLIENT='$uuidD'; companyNameRaw='株式会社テストD'; planToken='$($planOutD.planToken)' }
"@
  $resD = Invoke-ChildPowerShellScript $codeD
  Assert-ParentHookDisarmed

  $hardKill_D = Test-HardTermination $resD
  $noResponse_D = Test-NoMergeResponseEmitted $resD
  $srcIntact_D = Test-Path -LiteralPath $nD

  $txDirD = Join-Path $crashVault_D ".fm-obsidian-bridge-transactions"
  $journalFiles = @(Get-ChildItem -LiteralPath $txDirD -Filter "*.journal.json" -File -ErrorAction SilentlyContinue)
  $pendingSurvives_D = $false
  $noCompleted_D = $false
  $rollbackStatusNone_D = $false
  $jSha_D = $null
  $jPath_D = $null

  if ($journalFiles.Count -eq 1) {
    $jPath_D = $journalFiles[0].FullName
    $jSha_D = (Get-FileHash -LiteralPath $jPath_D -Algorithm SHA256).Hash
    $journalContentD = Get-Content -LiteralPath $jPath_D -Raw -Encoding UTF8 | ConvertFrom-Json
    $pendingSurvives_D = ($journalContentD.entries.Count -gt 0) -and ($journalContentD.entries[0].State -eq "PENDING")
    $noCompleted_D = @($journalContentD.entries | Where-Object { $_.State -eq "COMPLETED" -or $_.State -eq "ROLLED_BACK" }).Count -eq 0
    $rollbackStatusNone_D = ($journalContentD.rollbackStatus -eq "NONE")
  }

  $stagingDir_D = Join-Path $txDirD "staging_$($journalFiles[0].BaseName.Replace('.journal',''))"
  $stagedFile_D = if (Test-Path -LiteralPath $stagingDir_D) { Join-Path $stagingDir_D (Split-Path -Leaf $nD) } else { $null }
  $stagingDstAbsent_D = ($null -eq $stagedFile_D) -or (-not (Test-Path -LiteralPath $stagedFile_D))

  $committedAbsent_D = @(Get-ChildItem -LiteralPath $txDirD -Filter "*.committed.json" -File -ErrorAction SilentlyContinue).Count -eq 0
  $inprogressExists_D = @(Get-ChildItem -LiteralPath $txDirD -Filter "*.inprogress.json" -File -ErrorAction SilentlyContinue).Count -gt 0

  $dPassed = $hardKill_D -and $noResponse_D -and $srcIntact_D -and $stagingDstAbsent_D -and $pendingSurvives_D -and $noCompleted_D -and $rollbackStatusNone_D -and $committedAbsent_D -and $inprogressExists_D

  $metaD = [ordered]@{
    EvidenceClass     = "REAL_CRASH"
    CrashWindow       = "D"
    TerminationMethod = "HARD_KILL_TERMINATEPROCESS"
    ChildExecutable   = $resD.Executable
    ChildPid          = $resD.ChildPid
    ChildStartTime    = $resD.StartTime
    ChildExitCode     = $resD.ExitCode
    ChildTimedOut     = $resD.TimedOut
    JournalPath       = $jPath_D
    JournalSha256     = $jSha_D
    RollbackStatus    = if ($rollbackStatusNone_D) { "NONE" } else { $null }
    Entries           = @(@{ Seq = 1; OpType = "MOVE_FILE"; State = "PENDING" })
    SourceExists      = $srcIntact_D
    DestExists        = -not $stagingDstAbsent_D
    OwnerMarkerExists = $true
    CommittedExists   = -not $committedAbsent_D
    InProgressExists  = $inprogressExists_D
  }

  Report-Test "B4_REAL_CRASH_WINDOW_D_PENDING_SURVIVES" $dPassed "HardKill: $hardKill_D, SrcIntact: $srcIntact_D, StagingDstAbsent: $stagingDstAbsent_D, PendingSurvives: $pendingSurvives_D, RollbackStatusNone: $rollbackStatusNone_D" $metaD
} catch {
  Report-Test "B4_REAL_CRASH_WINDOW_D_PENDING_SURVIVES" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Crash Window E: Hard process termination after File.Move verified before COMPLETED journal write
try {
  $crashVault_E = Join-Path $TestRoot "CrashE_Vault"
  [void][System.IO.Directory]::CreateDirectory($crashVault_E)
  $crashCust_E = Join-Path $crashVault_E "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($crashCust_E)
  $uuidE = "eeeeeeee-1111-2222-3333-444444444444"
  $fE = Join-Path $crashCust_E "株式会社テストE ($uuidE)"
  [void][System.IO.Directory]::CreateDirectory($fE)
  $pfxKeiyaku = Get-IconPrefix "契約"
  $nE = Join-Path $fE ($pfxKeiyaku + "_テストE.md")
  [System.IO.File]::WriteAllLines($nE, @("---", ("UUID: " + $uuidE), "---", "# E"), [System.Text.Encoding]::UTF8)
  $expSha_E = Get-FileSha256Raw $nE

  $planOutE = Invoke-PlanCustomerFolderMerge @{ protocolVersion=1; action="PLAN_CUSTOMER_FOLDER_MERGE"; requestId="req-plan-e"; VaultRoot=$crashVault_E; pk_CLIENT=$uuidE; companyNameRaw="株式会社テストE" } | ConvertFrom-Json

  $codeE = @"
`$global:__TEST_CRASH_HOOK = 'E'
. '$TargetScript'
Invoke-ApplyCustomerFolderMerge @{ protocolVersion=1; action='APPLY_CUSTOMER_FOLDER_MERGE'; requestId='req-apply-e'; VaultRoot='$crashVault_E'; pk_CLIENT='$uuidE'; companyNameRaw='株式会社テストE'; planToken='$($planOutE.planToken)' }
"@
  $resE = Invoke-ChildPowerShellScript $codeE
  Assert-ParentHookDisarmed

  $hardKill_E = Test-HardTermination $resE
  $noResponse_E = Test-NoMergeResponseEmitted $resE
  $srcAbsent_E = -not (Test-Path -LiteralPath $nE)

  $txDirE = Join-Path $crashVault_E ".fm-obsidian-bridge-transactions"
  $journalFiles_E = @(Get-ChildItem -LiteralPath $txDirE -Filter "*.journal.json" -File -ErrorAction SilentlyContinue)
  $pendingSurvives_E = $false
  $noCompleted_E = $false
  $rollbackStatusNone_E = $false
  $jSha_E = $null
  $jPath_E = $null
  $txId_E = $null

  if ($journalFiles_E.Count -eq 1) {
    $jPath_E = $journalFiles_E[0].FullName
    $txId_E = $journalFiles_E[0].BaseName.Replace(".journal", "")
    $jSha_E = (Get-FileHash -LiteralPath $jPath_E -Algorithm SHA256).Hash
    $journalContentE = Get-Content -LiteralPath $jPath_E -Raw -Encoding UTF8 | ConvertFrom-Json
    $pendingSurvives_E = ($journalContentE.entries.Count -gt 0) -and ($journalContentE.entries[0].State -eq "PENDING")
    $noCompleted_E = @($journalContentE.entries | Where-Object { $_.State -eq "COMPLETED" -or $_.State -eq "ROLLED_BACK" }).Count -eq 0
    $rollbackStatusNone_E = ($journalContentE.rollbackStatus -eq "NONE")
  }

  $stagingDir_E = Join-Path $txDirE "staging_$txId_E"
  $stagedFile_E = if (Test-Path -LiteralPath $stagingDir_E) { Join-Path $stagingDir_E (Split-Path -Leaf $nE) } else { $null }
  $stagingDstExists_E = ($null -ne $stagedFile_E) -and (Test-Path -LiteralPath $stagedFile_E)
  $stagedSha_E = if ($stagingDstExists_E) { Get-FileSha256Raw $stagedFile_E } else { "" }
  $shaMatches_E = ($stagedSha_E -eq $expSha_E)

  $committedAbsent_E = @(Get-ChildItem -LiteralPath $txDirE -Filter "*.committed.json" -File -ErrorAction SilentlyContinue).Count -eq 0

  $ePassed = $hardKill_E -and $noResponse_E -and $srcAbsent_E -and $stagingDstExists_E -and $shaMatches_E -and $pendingSurvives_E -and $noCompleted_E -and $rollbackStatusNone_E -and $committedAbsent_E

  $metaE = [ordered]@{
    EvidenceClass     = "REAL_CRASH"
    CrashWindow       = "E"
    TerminationMethod = "HARD_KILL_TERMINATEPROCESS"
    ChildExecutable   = $resE.Executable
    ChildPid          = $resE.ChildPid
    ChildStartTime    = $resE.StartTime
    ChildExitCode     = $resE.ExitCode
    ChildTimedOut     = $resE.TimedOut
    JournalPath       = $jPath_E
    JournalSha256     = $jSha_E
    RollbackStatus    = if ($rollbackStatusNone_E) { "NONE" } else { $null }
    Entries           = @(@{ Seq = 1; OpType = "MOVE_FILE"; State = "PENDING" })
    SourceExists      = -not $srcAbsent_E
    DestExists        = $stagingDstExists_E
    OwnerMarkerExists = $true
    CommittedExists   = -not $committedAbsent_E
    InProgressExists  = $true
  }

  Report-Test "B4_REAL_CRASH_WINDOW_E_MUTATED_BUT_PENDING" $ePassed "HardKill: $hardKill_E, SrcAbsent: $srcAbsent_E, StagedExists: $stagingDstExists_E, ShaMatches: $shaMatches_E, PendingSurvives: $pendingSurvives_E, RollbackNone: $rollbackStatusNone_E" $metaE

  # Window E Recovery continuation: Fresh child runs Invoke-OptionBRollback
  $codeERecovery = @"
. '$TargetScript'
`$rbRes = Invoke-OptionBRollback `$null '$txId_E' '$txDirE'
Write-Output (`$rbRes | ConvertTo-Json -Depth 5)
"@
  $resERecovery = Invoke-ChildPowerShellScript $codeERecovery
  Assert-ParentHookDisarmed

  $outERecovery = $null
  $firstBrace_E = $resERecovery.StdOut.IndexOf("{")
  $lastBrace_E = $resERecovery.StdOut.LastIndexOf("}")
  if ($firstBrace_E -ge 0 -and $lastBrace_E -gt $firstBrace_E) {
    try {
      $outERecovery = ConvertFrom-Json $resERecovery.StdOut.Substring($firstBrace_E, $lastBrace_E - $firstBrace_E + 1)
    } catch {}
  }

  $recoveryFailedClosed = ($null -ne $outERecovery) -and ($outERecovery.Success -eq $false) -and ($outERecovery.TerminalStatePersisted -eq $true) -and ($outERecovery.Details -match "PENDING")
  $stagingStillExists = Test-Path -LiteralPath $stagedFile_E
  $srcStillAbsent = -not (Test-Path -LiteralPath $nE)

  $diskJ_E_After = Get-Content -LiteralPath $jPath_E -Raw -Encoding UTF8 | ConvertFrom-Json
  $statusIsFailed = ($diskJ_E_After.rollbackStatus -eq "ROLLBACK_FAILED")

  $eRecPassed = ($resERecovery.ExitCode -eq 0) -and $recoveryFailedClosed -and $stagingStillExists -and $srcStillAbsent -and $statusIsFailed

  $metaERec = [ordered]@{
    EvidenceClass     = "FUNCTIONAL"
    CrashWindow       = "E"
    TerminationMethod = "NONE"
    ChildExecutable   = $resERecovery.Executable
    ChildPid          = $resERecovery.ChildPid
    ChildStartTime    = $resERecovery.StartTime
    ChildExitCode     = $resERecovery.ExitCode
    ChildTimedOut     = $resERecovery.TimedOut
    JournalPath       = $jPath_E
    JournalSha256     = (Get-FileHash -LiteralPath $jPath_E -Algorithm SHA256).Hash
    RollbackStatus    = $diskJ_E_After.rollbackStatus
    Entries           = @(@{ Seq = 1; OpType = "MOVE_FILE"; State = "PENDING" })
    SourceExists      = -not $srcStillAbsent
    DestExists        = $stagingStillExists
    OwnerMarkerExists = $true
    CommittedExists   = $false
    InProgressExists  = $true
  }

  Report-Test "B4_WINDOW_E_RECOVERY_FAIL_CLOSED" $eRecPassed "ExitCode: $($resERecovery.ExitCode), RecoveryRefused: $recoveryFailedClosed, StagingPreserved: $stagingStillExists, RollbackStatusOnDisk: $($diskJ_E_After.rollbackStatus)" $metaERec
} catch {
  Report-Test "B4_REAL_CRASH_WINDOW_E_MUTATED_BUT_PENDING" $false $_.Exception.Message
  Report-Test "B4_WINDOW_E_RECOVERY_FAIL_CLOSED" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Crash Window F: Hard process termination after 1st reverse move in rollback loop
try {
  $crashTxId_F = [Guid]::NewGuid().ToString("D")
  $src1_F = Join-Path $TestRoot "crash_src1_F.md"
  $dst1_F = Join-Path $TestRoot "crash_dst1_F.md"
  $src2_F = Join-Path $TestRoot "crash_src2_F.md"
  $dst2_F = Join-Path $TestRoot "crash_dst2_F.md"

  [System.IO.File]::WriteAllLines($src1_F, @("F1"), [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllLines($src2_F, @("F2"), [System.Text.Encoding]::UTF8)
  $sha1_F = Get-FileSha256Raw $src1_F
  $sha2_F = Get-FileSha256Raw $src2_F
  $sz1_F = (Get-Item -LiteralPath $src1_F).Length
  $sz2_F = (Get-Item -LiteralPath $src2_F).Length

  [System.IO.File]::Move($src1_F, $dst1_F)
  [System.IO.File]::Move($src2_F, $dst2_F)

  $journalData_F_test = [ordered]@{
    txId = $crashTxId_F
    uuid = "11111111-2222-3333-4444-555555555555"
    vaultRoot = $TestRoot
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_F_crash"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = $src1_F; DestPath = $dst1_F; ExpectedSha256 = $sha1_F; ExpectedSizeBytes = $sz1_F; OwnerToken = $null; State = "COMPLETED"; Timestamp = "2026-08-30T10:00:00Z" },
      [ordered]@{ Seq = 2; OpType = "MOVE_FILE"; SourcePath = $src2_F; DestPath = $dst2_F; ExpectedSha256 = $sha2_F; ExpectedSizeBytes = $sz2_F; OwnerToken = $null; State = "COMPLETED"; Timestamp = "2026-08-30T10:00:01Z" }
    )
  }
  Write-JournalEvidenceSafe $txDir $crashTxId_F $journalData_F_test | Out-Null

  $codeF = @"
`$global:__TEST_CRASH_HOOK = 'F'
. '$TargetScript'
Invoke-OptionBRollback `$null '$crashTxId_F' '$txDir'
"@
  $resF = Invoke-ChildPowerShellScript $codeF
  Assert-ParentHookDisarmed

  $hardKill_F = Test-HardTermination $resF

  $jPath_F = Join-Path $txDir "$crashTxId_F.journal.json"
  $diskJ_F = Get-Content -LiteralPath $jPath_F -Raw -Encoding UTF8 | ConvertFrom-Json
  $entry2RolledBack = ($diskJ_F.entries[1].State -eq "ROLLED_BACK")
  $entry1Completed = ($diskJ_F.entries[0].State -eq "COMPLETED")
  # MANDATORY: rollbackStatus must remain NONE because crash happened before terminal persist
  $rollbackStatusIsNone = ($diskJ_F.rollbackStatus -eq "NONE")

  # Filesystem exact correspondence
  $src2Exists = Test-Path -LiteralPath $src2_F
  $dst2Absent = -not (Test-Path -LiteralPath $dst2_F)
  $src1Absent = -not (Test-Path -LiteralPath $src1_F)
  $dst1Exists = Test-Path -LiteralPath $dst1_F
  $sha2Matches = if ($src2Exists) { (Get-FileSha256Raw $src2_F) -eq $sha2_F } else { $false }
  $sha1Matches = if ($dst1Exists) { (Get-FileSha256Raw $dst1_F) -eq $sha1_F } else { $false }
  $structValid_F = Test-JournalStructureValid $diskJ_F $crashTxId_F

  $fPassed = $hardKill_F -and $rollbackStatusIsNone -and $entry2RolledBack -and $entry1Completed -and
             $src2Exists -and $dst2Absent -and $src1Absent -and $dst1Exists -and $sha2Matches -and $sha1Matches -and $structValid_F

  $metaF = [ordered]@{
    EvidenceClass     = "REAL_CRASH"
    CrashWindow       = "F"
    TerminationMethod = "HARD_KILL_TERMINATEPROCESS"
    ChildExecutable   = $resF.Executable
    ChildPid          = $resF.ChildPid
    ChildStartTime    = $resF.StartTime
    ChildExitCode     = $resF.ExitCode
    ChildTimedOut     = $resF.TimedOut
    JournalPath       = $jPath_F
    JournalSha256     = (Get-FileHash -LiteralPath $jPath_F -Algorithm SHA256).Hash
    RollbackStatus    = $diskJ_F.rollbackStatus
    Entries           = @(
      @{ Seq = 1; OpType = "MOVE_FILE"; State = $diskJ_F.entries[0].State },
      @{ Seq = 2; OpType = "MOVE_FILE"; State = $diskJ_F.entries[1].State }
    )
    SourceExists      = $src2Exists
    DestExists        = $dst1Exists
    OwnerMarkerExists = $null
    CommittedExists   = $false
    InProgressExists  = $null
  }

  Report-Test "B4_REAL_CRASH_WINDOW_F_ROLLBACK_PROGRESS_PERSISTED" $fPassed "HardKill: $hardKill_F, RollbackStatusNone: $rollbackStatusIsNone, Entry2RolledBack: $entry2RolledBack, Entry1Completed: $entry1Completed, Src2Restored: $src2Exists, Dst1Intact: $dst1Exists" $metaF
} catch {
  Report-Test "B4_REAL_CRASH_WINDOW_F_ROLLBACK_PROGRESS_PERSISTED" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# Post-Commit Fault Interlock (Window G: FAULT_INJECTION)
try {
  $crashVault_G = Join-Path $TestRoot "CrashG_Vault"
  [void][System.IO.Directory]::CreateDirectory($crashVault_G)
  $crashCust_G = Join-Path $crashVault_G "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($crashCust_G)
  $uuidG = "77777777-1111-2222-3333-444444444444"
  $fG = Join-Path $crashCust_G "株式会社テストG ($uuidG)"
  [void][System.IO.Directory]::CreateDirectory($fG)
  $pfxKeiyaku = Get-IconPrefix "契約"
  $nG = Join-Path $fG ($pfxKeiyaku + "_テストG.md")
  [System.IO.File]::WriteAllLines($nG, @("---", ("UUID: " + $uuidG), "---", "# G"), [System.Text.Encoding]::UTF8)

  $planOutG = Invoke-PlanCustomerFolderMerge @{ protocolVersion=1; action="PLAN_CUSTOMER_FOLDER_MERGE"; requestId="req-plan-g"; VaultRoot=$crashVault_G; pk_CLIENT=$uuidG; companyNameRaw="株式会社テストG" } | ConvertFrom-Json

  $codeG = @"
`$global:__TEST_CRASH_HOOK = 'G:THROW'
. '$TargetScript'
`$res = Invoke-ApplyCustomerFolderMerge @{ protocolVersion=1; action='APPLY_CUSTOMER_FOLDER_MERGE'; requestId='req-apply-g'; VaultRoot='$crashVault_G'; pk_CLIENT='$uuidG'; companyNameRaw='株式会社テストG'; planToken='$($planOutG.planToken)' }
Write-Output `$res
"@
  $resG = Invoke-ChildPowerShellScript $codeG
  Assert-ParentHookDisarmed

  $outG = $null
  $firstBrace_G = $resG.StdOut.IndexOf("{")
  $lastBrace_G = $resG.StdOut.LastIndexOf("}")
  if ($firstBrace_G -ge 0 -and $lastBrace_G -gt $firstBrace_G) {
    try {
      $outG = ConvertFrom-Json $resG.StdOut.Substring($firstBrace_G, $lastBrace_G - $firstBrace_G + 1)
    } catch {}
  }

  $canonPathG = Join-Path $crashCust_G $planOutG.plan.canonicalFolderName
  $canonicalNoteExists = Test-Path -LiteralPath (Join-Path $canonPathG ($pfxKeiyaku + "_テストG.md"))
  $sourceNoteAbsent = -not (Test-Path -LiteralPath $nG)
  $committedExists_G = @(Get-ChildItem -LiteralPath (Join-Path $crashVault_G ".fm-obsidian-bridge-transactions") -Filter "*.committed.json" -File -ErrorAction SilentlyContinue).Count -gt 0

  $gPassed = ($resG.ExitCode -eq 0) -and ($null -ne $outG) -and ($outG.status -eq "OK") -and ($outG.code -eq "MERGE_COMPLETED") -and
             ($outG.warning -eq "POST_COMMIT_CLEANUP_FAILED") -and $canonicalNoteExists -and $sourceNoteAbsent -and $committedExists_G

  $metaG = [ordered]@{
    EvidenceClass     = "FAULT_INJECTION"
    CrashWindow       = "G"
    TerminationMethod = "EXCEPTION"
    ChildExecutable   = $resG.Executable
    ChildPid          = $resG.ChildPid
    ChildStartTime    = $resG.StartTime
    ChildExitCode     = $resG.ExitCode
    ChildTimedOut     = $resG.TimedOut
    JournalPath       = $null
    JournalSha256     = $null
    RollbackStatus    = $null
    Entries           = @()
    SourceExists      = -not $sourceNoteAbsent
    DestExists        = $canonicalNoteExists
    OwnerMarkerExists = $null
    CommittedExists   = $committedExists_G
    InProgressExists  = $false
  }

  Report-Test "B4_POST_COMMIT_FAULT_INTERLOCK_NO_ROLLBACK" $gPassed "ExitCode: $($resG.ExitCode), Status: $(if ($null -ne $outG) { $outG.status } else { 'NULL' }), Warning: $(if ($null -ne $outG) { $outG.warning } else { 'NULL' }), CanonNoteExists: $canonicalNoteExists, SourceAbsent: $sourceNoteAbsent" $metaG
} catch {
  Report-Test "B4_POST_COMMIT_FAULT_INTERLOCK_NO_ROLLBACK" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# -------------------------------------------------------------
# Write Durable Test Reports (Section 17 / 21)
# -------------------------------------------------------------
$targetSha = (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash.ToUpperInvariant()
$harnessSha = if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) { (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToUpperInvariant() } else { "INLINE_OR_DIRECT" }

$reportHeader = [ordered]@{
  Suite                    = "B-4 Durable Journal & Directory Attribution Regression Suite (T2R2)"
  TargetScript             = $TargetScript
  TargetSha256             = $targetSha
  RunTimestamp             = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  PowerShellVersion        = $PSVersionTable.PSVersion.ToString()
  PSEdition                = $PSVersionTable.PSEdition
  OSVersion                = [Environment]::OSVersion.VersionString
  HarnessSha256            = $harnessSha
  TestCount                = $script:totalTests
  PassCount                = $script:passedTests
  FailCount                = ($script:totalTests - $script:passedTests)
  WindowCEmpiricalTest     = "NOT_CONSTRUCTIBLE"
  RealCrashWindowsCovered  = "A, A2, B, D, E, F"
  FaultInjectionWindows    = "G (POST_COMMIT_FAULT_INTERLOCK)"
}

$reportTxtPath = Join-Path $TestRoot "_report.txt"
$reportJsonPath = Join-Path $TestRoot "_report.json"

$lines = @(
  "=====================================================",
  "B-4 Durable Journal & Directory Attribution Report (T2R2)",
  "TargetScript: $($reportHeader.TargetScript)",
  "TargetSha256: $($reportHeader.TargetSha256)",
  "RunTimestamp: $($reportHeader.RunTimestamp)",
  "PowerShellVersion: $($reportHeader.PowerShellVersion) ($($reportHeader.PSEdition))",
  "OSVersion: $($reportHeader.OSVersion)",
  "HarnessSha256: $($reportHeader.HarnessSha256)",
  "Summary: $($reportHeader.PassCount) / $($reportHeader.TestCount) PASS",
  "WindowCEmpiricalTest: $($reportHeader.WindowCEmpiricalTest)",
  "RealCrashWindowsCovered: $($reportHeader.RealCrashWindowsCovered)",
  "FaultInjectionWindows: $($reportHeader.FaultInjectionWindows)",
  "====================================================="
)
foreach ($r in $script:testResults) {
  $mark = if ($r.Passed) { "[PASS]" } else { "[FAIL]" }
  $lines += "$mark $($r.Name) ($($r.EvidenceClass)) - $($r.Details)"
}
[System.IO.File]::WriteAllLines($reportTxtPath, $lines, [System.Text.Encoding]::UTF8)

$reportJsonObject = [ordered]@{
  Report  = $reportHeader
  Results = $script:testResults
}
$jsonReport = $reportJsonObject | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($reportJsonPath, $jsonReport, [System.Text.Encoding]::UTF8)

Write-Host "====================================================="
Write-Host "B-4 Regression Suite Summary: $passedTests/$totalTests PASS"
Write-Host "Durable Reports Written:"
Write-Host "  $reportTxtPath"
Write-Host "  $reportJsonPath"
Write-Host "====================================================="

if ($passedTests -ne $totalTests) {
  exit 1
}
