# Test-Tier3Regression.ps1
# Dedicated Regression Suite for Step 4C-3 / Tier 3 (Exact Implementation Gate)
# Authority: Claude Cowork Tier-3 Frozen Corrective Design Spec
[CmdletBinding()]
param(
  [string]$TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1",
  [string]$TestRoot = "D:\FM-Script-Backup\WindowsTestKit_CUSTOMER_FOLDER_MERGE\TestVault_MERGE\V_T3_TEST"
)

$ErrorActionPreference = "Stop"
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Tier 3 Focused & Concurrency Regression Suite" -ForegroundColor Cyan
Write-Host "Target: $TargetScript"
Write-Host "TestRoot: $TestRoot"
Write-Host "====================================================="

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Host "[FAIL] Target script not found: $TargetScript" -ForegroundColor Red
  exit 1
}

# 1. Load Win32 native types
if (-not ([System.Management.Automation.PSTypeName]'Win32NativeMergeHelper').Type) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Win32NativeMergeHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "GetLongPathNameW")]
    public static extern uint GetLongPathName(string lpszShortPath, StringBuilder lpszLongPath, uint cchBuffer);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateDirectoryW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CreateDirectory(string lpPathName, IntPtr lpSecurityAttributes);
}
"@
}

if (-not ([System.Management.Automation.PSTypeName]'Win32DurableJournalHelper').Type) {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Win32DurableJournalHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "MoveFileExW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, uint dwFlags);

    public const uint MOVEFILE_REPLACE_EXISTING = 0x1;
    public const uint MOVEFILE_WRITE_THROUGH    = 0x8;
}
"@
}

# 2. Parse TargetScript AST and load all function definitions
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

$funcAsts = $scriptAst.FindAll({
  param($n)
  $n -is [System.Management.Automation.Language.FunctionDefinitionAst]
}, $true)

foreach ($fAst in $funcAsts) {
  Invoke-Expression $fAst.Extent.Text
}

# Parent self-protection guard
function Assert-ParentHookDisarmed {
  if ($null -ne (Get-Variable -Name __TEST_CRASH_HOOK -Scope Global -ValueOnly -ErrorAction SilentlyContinue)) {
    Write-Host "[ABORT] Parent session has an armed crash hook." -ForegroundColor Red
    exit 1
  }
}
Assert-ParentHookDisarmed

# Child process execution helper
function Invoke-ChildPowerShellScript([string]$scriptText, [int]$TimeoutMs = 60000) {
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

# Asynchronous child process launcher for multi-process race tests
function Start-ChildPowerShellScriptAsync([string]$scriptText) {
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

  return @{
    Process   = $p
    ChildPid  = $childPid
    StartTime = $startTime
    SoTask    = $soTask
    SeTask    = $seTask
  }
}

function Wait-ChildPowerShellProcess($handle, [int]$TimeoutMs = 60000) {
  $p = $handle.Process
  $exited = $p.WaitForExit($TimeoutMs)
  $timedOut = -not $exited
  if ($timedOut) { try { $p.Kill() } catch {} ; [void]$p.WaitForExit(15000) }

  $stdout = try { $handle.SoTask.Result } catch { "" }
  $stderr = try { $handle.SeTask.Result } catch { "" }
  $exitCode = try { $p.ExitCode } catch { $null }

  return @{
    Executable   = (Join-Path $PSHOME 'powershell.exe')
    ChildPid     = $handle.ChildPid
    StartTime    = $handle.StartTime
    EndTime      = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    ExitCode     = $exitCode
    TimedOut     = $timedOut
    StdOut       = $stdout
    StdErr       = $stderr
  }
}

# Child payload execution helper (end-to-end payload dispatch via Base64)
function Invoke-ChildPayloadJson([string]$payloadJson, [int]$TimeoutMs = 60000) {
  $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($payloadJson))
  $script = @"
& '$TargetScript' -PayloadB64 '$b64'
"@
  return Invoke-ChildPowerShellScript -scriptText $script -TimeoutMs $TimeoutMs
}

# Ensure clean isolated test directory
if (Test-Path -LiteralPath $TestRoot) {
  Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
}
[void][System.IO.Directory]::CreateDirectory($TestRoot)

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
    ChildPid          = if ($meta -and $meta.ChildPid) { $meta.ChildPid } else { $null }
    ChildExitCode     = if ($meta -and ($null -ne $meta.ChildExitCode)) { $meta.ChildExitCode } else { $null }
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

# ==============================================================================
# SECTION A: Tier-3 Concurrency & Lock Tests (T3-L1 through T3-L7)
# ==============================================================================

# --- T3-L1: Two Concurrent Real Child Processes on APPLY_CUSTOMER_FOLDER_MERGE ---
try {
  $vL1 = Join-Path $TestRoot "V_T3_L1"
  [void][System.IO.Directory]::CreateDirectory($vL1)
  $custL1 = Join-Path $vL1 "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($custL1)

  $fA = Join-Path $custL1 "株式会社テスト_A"
  $fB = Join-Path $custL1 "株式会社テスト_B"
  [void][System.IO.Directory]::CreateDirectory($fA)
  [void][System.IO.Directory]::CreateDirectory($fB)

  $uuidL1 = "11111111-2222-3333-4444-555555555555"
  $pfxKeiyaku = Get-IconPrefix "契約"
  $pfxJiko = Get-IconPrefix "事故"
  $noteA = Join-Path $fA ($pfxKeiyaku + "_テスト.md")
  $noteB = Join-Path $fB ($pfxJiko + "_テスト.md")

  [System.IO.File]::WriteAllLines($noteA, @("---", "UUID: $uuidL1", "---", "# 契約"), [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllLines($noteB, @("---", "UUID: $uuidL1", "---", "# 事故"), [System.Text.Encoding]::UTF8)

  $expShaA = Get-FileSha256Raw $noteA
  $expShaB = Get-FileSha256Raw $noteB

  # Run PLAN to generate valid planToken
  $planOutL1 = Invoke-PlanCustomerFolderMerge @{
    protocolVersion = 1
    action = 'PLAN_CUSTOMER_FOLDER_MERGE'
    requestId = 'req-t3-l1-plan'
    VaultRoot = $vL1
    pk_CLIENT = $uuidL1
    companyNameRaw = '株式会社テスト'
  } | ConvertFrom-Json

  $tokenL1 = $planOutL1.planToken
  $pJsonL1_Apply = @{
    protocolVersion = 1
    action = 'APPLY_CUSTOMER_FOLDER_MERGE'
    requestId = 'req-t3-l1-apply'
    VaultRoot = $vL1
    pk_CLIENT = $uuidL1
    companyNameRaw = '株式会社テスト'
    planToken = $tokenL1
  } | ConvertTo-Json -Compress
  $b64ApplyL1 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pJsonL1_Apply))

  $barrierL1 = Join-Path $vL1 "START.barrier"
  if (Test-Path -LiteralPath $barrierL1) { Remove-Item -LiteralPath $barrierL1 -Force }

  $childScriptL1 = @"
`$barrier = '$barrierL1'
while (-not (Test-Path -LiteralPath `$barrier)) { Start-Sleep -Milliseconds 10 }
& '$TargetScript' -PayloadB64 '$b64ApplyL1'
"@

  $h1 = Start-ChildPowerShellScriptAsync $childScriptL1
  $h2 = Start-ChildPowerShellScriptAsync $childScriptL1
  Start-Sleep -Milliseconds 100
  [System.IO.File]::WriteAllText($barrierL1, "GO", [System.Text.Encoding]::UTF8)

  $res1 = Wait-ChildPowerShellProcess $h1 60000
  $res2 = Wait-ChildPowerShellProcess $h2 60000

  $j1 = $null; try { $j1 = ConvertFrom-Json $res1.StdOut.Trim() } catch {}
  $j2 = $null; try { $j2 = ConvertFrom-Json $res2.StdOut.Trim() } catch {}

  $codes = @($j1.code, $j2.code)
  $hasSuccess = $codes -contains "MERGE_COMPLETED"
  $hasContention = ($codes -contains "MERGE_OPERATION_IN_PROGRESS") -or ($codes -contains "PLAN_TOKEN_MISMATCH") -or ($codes -contains "CUSTOMER_NOT_FOUND")

  # Independent filesystem verification:
  $canonDir = Join-Path $custL1 "株式会社テスト_[11111111]"
  $canonExists = Test-Path -LiteralPath $canonDir
  $mergedNoteA = Join-Path $canonDir ($pfxKeiyaku + "_テスト.md")
  $mergedNoteB = Join-Path $canonDir ($pfxJiko + "_テスト.md")
  $notesExistOnce = (Test-Path -LiteralPath $mergedNoteA) -and (Test-Path -LiteralPath $mergedNoteB)
  $srcCleaned = (-not (Test-Path -LiteralPath $noteA)) -and (-not (Test-Path -LiteralPath $noteB))
  $shaAOk = if (Test-Path -LiteralPath $mergedNoteA) { (Get-FileSha256Raw $mergedNoteA) -eq $expShaA } else { $false }
  $shaBOk = if (Test-Path -LiteralPath $mergedNoteB) { (Get-FileSha256Raw $mergedNoteB) -eq $expShaB } else { $false }

  $passL1 = $hasSuccess -and $hasContention -and $canonExists -and $notesExistOnce -and $srcCleaned -and $shaAOk -and $shaBOk
  Report-Test "T3_L1_TWO_CONCURRENT_APPLY_MUTATION_EXACTLY_ONCE" $passL1 "Codes: $($codes -join ', '), CanonExists: $canonExists, NotesExistOnce: $notesExistOnce, ShaValid: $($shaAOk -and $shaBOk)" @{ EvidenceClass="REAL_CONCURRENCY"; ChildPid="$($h1.ChildPid),$($h2.ChildPid)" }
} catch {
  Report-Test "T3_L1_TWO_CONCURRENT_APPLY_MUTATION_EXACTLY_ONCE" $false $_.Exception.Message
}

# --- T3-L2: PLAN versus APPLY Real Child Process Contention ---
try {
  $vL2 = Join-Path $TestRoot "V_T3_L2"
  [void][System.IO.Directory]::CreateDirectory($vL2)
  $custL2 = Join-Path $vL2 "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($custL2)

  $fA2 = Join-Path $custL2 "株式会社L2_A"
  $fB2 = Join-Path $custL2 "株式会社L2_B"
  [void][System.IO.Directory]::CreateDirectory($fA2)
  [void][System.IO.Directory]::CreateDirectory($fB2)

  $uuidL2 = "22222222-3333-4444-5555-666666666666"
  $pfxKeiyaku = Get-IconPrefix "契約"
  $noteA2 = Join-Path $fA2 ($pfxKeiyaku + "_テスト.md")
  [System.IO.File]::WriteAllLines($noteA2, @("---", "UUID: $uuidL2", "---", "# 契約"), [System.Text.Encoding]::UTF8)

  # Generate planToken
  $planOutL2 = Invoke-PlanCustomerFolderMerge @{
    protocolVersion = 1
    action = 'PLAN_CUSTOMER_FOLDER_MERGE'
    requestId = 'req-t3-l2-plan0'
    VaultRoot = $vL2
    pk_CLIENT = $uuidL2
    companyNameRaw = '株式会社L2'
  } | ConvertFrom-Json

  $tokenL2 = $planOutL2.planToken

  $pJsonApplyL2 = @{
    protocolVersion = 1
    action = 'APPLY_CUSTOMER_FOLDER_MERGE'
    requestId = 'req-t3-l2-apply'
    VaultRoot = $vL2
    pk_CLIENT = $uuidL2
    companyNameRaw = '株式会社L2'
    planToken = $tokenL2
  } | ConvertTo-Json -Compress
  $b64ApplyL2 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pJsonApplyL2))

  $pJsonPlanL2 = @{
    protocolVersion = 1
    action = 'PLAN_CUSTOMER_FOLDER_MERGE'
    requestId = 'req-t3-l2-plan'
    VaultRoot = $vL2
    pk_CLIENT = $uuidL2
    companyNameRaw = '株式会社L2'
  } | ConvertTo-Json -Compress
  $b64PlanL2 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pJsonPlanL2))

  $barrierL2 = Join-Path $vL2 "START.barrier"
  if (Test-Path -LiteralPath $barrierL2) { Remove-Item -LiteralPath $barrierL2 -Force }

  $scriptApply = @"
`$barrier = '$barrierL2'
while (-not (Test-Path -LiteralPath `$barrier)) { Start-Sleep -Milliseconds 10 }
& '$TargetScript' -PayloadB64 '$b64ApplyL2'
"@

  $scriptPlan = @"
`$barrier = '$barrierL2'
while (-not (Test-Path -LiteralPath `$barrier)) { Start-Sleep -Milliseconds 10 }
& '$TargetScript' -PayloadB64 '$b64PlanL2'
"@

  $hApply = Start-ChildPowerShellScriptAsync $scriptApply
  $hPlan = Start-ChildPowerShellScriptAsync $scriptPlan
  Start-Sleep -Milliseconds 100
  [System.IO.File]::WriteAllText($barrierL2, "GO", [System.Text.Encoding]::UTF8)

  $resApply = Wait-ChildPowerShellProcess $hApply 60000
  $resPlan = Wait-ChildPowerShellProcess $hPlan 60000

  $jApply = $null; try { $jApply = ConvertFrom-Json $resApply.StdOut.Trim() } catch {}
  $jPlan = $null; try { $jPlan = ConvertFrom-Json $resPlan.StdOut.Trim() } catch {}

  # Verify lock semantics and zero unintended PLAN mutation
  $canonDirL2 = Join-Path $custL2 "株式会社L2_[22222222]"
  $canonExistsL2 = Test-Path -LiteralPath $canonDirL2
  $bothValidJson = ($null -ne $jApply) -and ($null -ne $jPlan)

  $contentionObserved = ($jApply.code -eq "MERGE_OPERATION_IN_PROGRESS") -or ($jPlan.code -eq "MERGE_OPERATION_IN_PROGRESS")
  $noUnintendedPlanMutation = if ($jPlan.code -eq "MERGE_PLAN_READY" -and -not $canonExistsL2) {
    (Test-Path -LiteralPath $noteA2) -and (-not $canonExistsL2)
  } elseif ($jApply.code -eq "MERGE_COMPLETED") {
    $canonExistsL2
  } else {
    $true
  }

  $passL2 = $bothValidJson -and $contentionObserved -and $noUnintendedPlanMutation
  Report-Test "T3_L2_PLAN_VERSUS_APPLY_CROSS_OPERATION_CONTENTION" $passL2 "ApplyCode: $($jApply.code), PlanCode: $($jPlan.code), CanonExists: $canonExistsL2, NoUnintendedPlanMutation: $noUnintendedPlanMutation" @{ EvidenceClass="REAL_CONCURRENCY"; ChildPid="$($hApply.ChildPid),$($hPlan.ChildPid)" }
} catch {
  Report-Test "T3_L2_PLAN_VERSUS_APPLY_CROSS_OPERATION_CONTENTION" $false $_.Exception.Message
}

# --- T3-L3: Lock Enclosure & Restored Public Error Schema Across UCI and Legacy Ops ---
try {
  $vL3 = Join-Path $TestRoot "V_T3_L3"
  [void][System.IO.Directory]::CreateDirectory($vL3)
  $txL3 = Join-Path $vL3 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txL3)
  $lockFileL3 = Join-Path $txL3 "ACTIVE.lock"

  # Hold lock to test all operations concurrently under contention
  $heldLock3 = [System.IO.FileStream]::new($lockFileL3, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)

  # 1. UCI: must return EXECUTION_FAILED (NOT OPERATION_IN_PROGRESS)
  $pJsonL3_Uci = @{
    protocolVersion = 1
    action = 'UPDATE_CUSTOMER_IDENTITY'
    requestId = 'req-t3-l3-uci'
    VaultRoot = $vL3
    pk_CLIENT = '11111111-2222-3333-4444-555555555555'
    companyNameRaw = 'テスト株式会社'
    CEO = ''
    RUBY = ''
    RANK = ''
  } | ConvertTo-Json -Compress
  $resL3_Uci = Invoke-ChildPayloadJson $pJsonL3_Uci

  # 2. OPEN: must return NG|ERROR|... (NOT LOCK_ACQUISITION_FAILED)
  $pJsonL3_Open = @{ protocolVersion = 1; MODE = 'OPEN'; requestId = 'req-t3-l3-o'; VaultRoot = $vL3; pk_CLIENT = '11111111-2222-3333-4444-555555555555'; companyNameRaw = 'テスト' } | ConvertTo-Json -Compress
  $resL3_Open = Invoke-ChildPayloadJson $pJsonL3_Open

  # 3. CHECK: must return NG|ERROR|... (NOT LOCK_ACQUISITION_FAILED)
  $pJsonL3_Check = @{ protocolVersion = 1; MODE = 'CHECK'; requestId = 'req-t3-l3-c'; VaultRoot = $vL3; pk_CLIENT = '11111111-2222-3333-4444-555555555555'; companyNameRaw = 'テスト' } | ConvertTo-Json -Compress
  $resL3_Check = Invoke-ChildPayloadJson $pJsonL3_Check

  # 4. COMPARE: must return NG|ERROR|... (NOT LOCK_ACQUISITION_FAILED)
  $pJsonL3_Comp = @{ protocolVersion = 1; MODE = 'COMPARE'; requestId = 'req-t3-l3-m'; VaultRoot = $vL3; pk_CLIENT = '11111111-2222-3333-4444-555555555555'; companyNameRaw = 'テスト'; csvPath = 'dummy.csv' } | ConvertTo-Json -Compress
  $resL3_Comp = Invoke-ChildPayloadJson $pJsonL3_Comp

  $heldLock3.Close()
  $heldLock3.Dispose()

  $jsonUci = $null; try { $jsonUci = ConvertFrom-Json $resL3_Uci.StdOut.Trim() } catch {}
  $passUci = ($null -ne $jsonUci) -and ($jsonUci.status -eq "NG") -and ($jsonUci.code -eq "EXECUTION_FAILED")
  $passOpen = $resL3_Open.StdOut -match "^NG\|ERROR\|"
  $passCheck = $resL3_Check.StdOut -match "^NG\|ERROR\|"
  $passComp = $resL3_Comp.StdOut -match "^NG\|ERROR\|"

  $passL3 = $passUci -and $passOpen -and $passCheck -and $passComp
  Report-Test "T3_L3_LOCK_ENCLOSURE_AND_PUBLIC_RESPONSE_RESTORED" $passL3 "UCI: $passUci (Code=$($jsonUci.code)), Open: $passOpen, Check: $passCheck, Comp: $passComp" @{ EvidenceClass="REAL_CONCURRENCY"; ChildPid=$resL3_Uci.ChildPid }
} catch {
  if ($null -ne $heldLock3) { $heldLock3.Close(); $heldLock3.Dispose() }
  Report-Test "T3_L3_LOCK_ENCLOSURE_AND_PUBLIC_RESPONSE_RESTORED" $false $_.Exception.Message
}

# --- T3-L4: Real Child Process Lock Contention on OPEN, CHECK, COMPARE ---
try {
  $vL4 = Join-Path $TestRoot "V_T3_L4"
  [void][System.IO.Directory]::CreateDirectory($vL4)
  $txL4 = Join-Path $vL4 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txL4)
  $lockFileL4 = Join-Path $txL4 "ACTIVE.lock"

  $heldLock4 = [System.IO.FileStream]::new($lockFileL4, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)

  $pJsonL4_Open = @{ protocolVersion = 1; MODE = 'OPEN'; requestId = 'req-t3-l4-o'; VaultRoot = $vL4; pk_CLIENT = '11111111-2222-3333-4444-555555555555'; companyNameRaw = 'テスト' } | ConvertTo-Json -Compress
  $resL4_Open = Invoke-ChildPayloadJson $pJsonL4_Open

  $pJsonL4_Check = @{ protocolVersion = 1; MODE = 'CHECK'; requestId = 'req-t3-l4-c'; VaultRoot = $vL4; pk_CLIENT = '11111111-2222-3333-4444-555555555555'; companyNameRaw = 'テスト' } | ConvertTo-Json -Compress
  $resL4_Check = Invoke-ChildPayloadJson $pJsonL4_Check

  $pJsonL4_Comp = @{ protocolVersion = 1; MODE = 'COMPARE'; requestId = 'req-t3-l4-m'; VaultRoot = $vL4; pk_CLIENT = '11111111-2222-3333-4444-555555555555'; companyNameRaw = 'テスト'; csvPath = 'dummy.csv' } | ConvertTo-Json -Compress
  $resL4_Comp = Invoke-ChildPayloadJson $pJsonL4_Comp

  $heldLock4.Close()
  $heldLock4.Dispose()

  $passOpen = $resL4_Open.StdOut -match "^NG\|ERROR\|"
  $passCheck = $resL4_Check.StdOut -match "^NG\|ERROR\|"
  $passComp = $resL4_Comp.StdOut -match "^NG\|ERROR\|"

  Report-Test "T3_L4_LEGACY_OPS_LOCK_CONTENTION_REAL_PROCESS" ($passOpen -and $passCheck -and $passComp) "Open: $passOpen, Check: $passCheck, Comp: $passComp" @{ EvidenceClass="REAL_CONCURRENCY" }
} catch {
  if ($null -ne $heldLock4) { $heldLock4.Close(); $heldLock4.Dispose() }
  Report-Test "T3_L4_LEGACY_OPS_LOCK_CONTENTION_REAL_PROCESS" $false $_.Exception.Message
}

# --- T3-L5: Lock Classification & Machine-Semantic Error Discrimination ---
try {
  # 1. Genuine file lock contention: open FileStream exclusively and attempt second open
  $tmpFileL5 = Join-Path $TestRoot "locked_test_file.tmp"
  $fs1 = [System.IO.File]::Open($tmpFileL5, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
  $clsContention = $null
  try {
    $fs2 = [System.IO.File]::Open($tmpFileL5, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs2.Close()
  } catch {
    $clsContention = Get-LockAcquisitionErrorClass $_.Exception
  } finally {
    $fs1.Close()
    $fs1.Dispose()
    Remove-Item -LiteralPath $tmpFileL5 -Force -ErrorAction SilentlyContinue
  }

  # 2. Genuine UnauthorizedAccessException
  $exAccess = [System.UnauthorizedAccessException]::new("Access Denied")
  $clsAccess = Get-LockAcquisitionErrorClass $exAccess

  # 3. Genuine DirectoryNotFoundException
  $exPath = [System.IO.DirectoryNotFoundException]::new("Path not found")
  $clsPath = Get-LockAcquisitionErrorClass $exPath

  # 4. Generic/Unexpected exception
  $exGeneric = [System.InvalidOperationException]::new("Unexpected error")
  $clsGeneric = Get-LockAcquisitionErrorClass $exGeneric

  # 5. Negative control: synthetic IOException with message "sharing violation" but 0 HResult must NOT classify as CONTENTION
  $exSynthetic = [System.IO.IOException]::new("sharing violation")
  $clsSynthetic = Get-LockAcquisitionErrorClass $exSynthetic

  $classCorrect = ($clsContention -eq "CONTENTION") -and
                  ($clsAccess -eq "ACCESS_DENIED") -and
                  ($clsPath -eq "INVALID_PATH") -and
                  ($clsGeneric -eq "UNEXPECTED_IO") -and
                  ($clsSynthetic -eq "UNEXPECTED_IO")

  Report-Test "T3_L5_LOCK_ACQUISITION_ERROR_CLASSIFICATION" $classCorrect "Contention: $clsContention, Access: $clsAccess, Path: $clsPath, Generic: $clsGeneric, SyntheticRejected: $($clsSynthetic -eq 'UNEXPECTED_IO')"
} catch {
  Report-Test "T3_L5_LOCK_ACQUISITION_ERROR_CLASSIFICATION" $false $_.Exception.Message
}

# --- T3-L6: Dispatcher Control-Root Creation Removal (NM-1) ---
try {
  $vL6 = Join-Path $TestRoot "V_T3_L6"
  [void][System.IO.Directory]::CreateDirectory($vL6)
  $txL6 = Join-Path $vL6 ".fm-obsidian-bridge-transactions"

  # Invoke target payload with an invalid request that dispatcher rejects early
  $pJson = @{ protocolVersion = "invalid_string"; action = "PLAN_CUSTOMER_FOLDER_MERGE"; VaultRoot = $vL6; pk_CLIENT = "none" } | ConvertTo-Json -Compress
  $resL6 = Invoke-ChildPayloadJson $pJson

  $txCreated = Test-Path -LiteralPath $txL6
  Report-Test "T3_L6_DISPATCHER_NO_CONTROL_ROOT_CREATION" (-not $txCreated) "ControlRootCreated: $txCreated"
} catch {
  Report-Test "T3_L6_DISPATCHER_NO_CONTROL_ROOT_CREATION" $false $_.Exception.Message
}

# --- T3-L7: Real Two-Child Process Control-Root Bootstrap Race ---
try {
  $vL7 = Join-Path $TestRoot "V_T3_L7"
  [void][System.IO.Directory]::CreateDirectory($vL7)
  $custL7 = Join-Path $vL7 "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($custL7)

  $fA7 = Join-Path $custL7 "株式会社L7_A"
  $fB7 = Join-Path $custL7 "株式会社L7_B"
  [void][System.IO.Directory]::CreateDirectory($fA7)
  [void][System.IO.Directory]::CreateDirectory($fB7)

  $uuidL7 = "77777777-1111-2222-3333-444444444444"
  $pfxKeiyaku = Get-IconPrefix "契約"
  $noteA7 = Join-Path $fA7 ($pfxKeiyaku + "_テストA.md")
  $noteB7 = Join-Path $fB7 ($pfxKeiyaku + "_テストB.md")
  [System.IO.File]::WriteAllLines($noteA7, @("---", "UUID: $uuidL7", "---", "# L7 A"), [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllLines($noteB7, @("---", "UUID: $uuidL7", "---", "# L7 B"), [System.Text.Encoding]::UTF8)

  $txL7 = Join-Path $vL7 ".fm-obsidian-bridge-transactions"
  $txAbsentBefore = -not (Test-Path -LiteralPath $txL7)

  $pJsonL7_A = @{
    protocolVersion = 1
    action = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId = "req-t3-l7-a"
    VaultRoot = $vL7
    pk_CLIENT = $uuidL7
    companyNameRaw = "株式会社L7"
  } | ConvertTo-Json -Compress
  $b64PlanA = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pJsonL7_A))

  $pJsonL7_B = @{
    protocolVersion = 1
    action = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId = "req-t3-l7-b"
    VaultRoot = $vL7
    pk_CLIENT = $uuidL7
    companyNameRaw = "株式会社L7"
  } | ConvertTo-Json -Compress
  $b64PlanB = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pJsonL7_B))

  $barrierL7 = Join-Path $vL7 "START.barrier"
  if (Test-Path -LiteralPath $barrierL7) { Remove-Item -LiteralPath $barrierL7 -Force }

  $scriptA = @"
`$barrier = '$barrierL7'
while (-not (Test-Path -LiteralPath `$barrier)) { Start-Sleep -Milliseconds 10 }
& '$TargetScript' -PayloadB64 '$b64PlanA'
"@

  $scriptB = @"
`$barrier = '$barrierL7'
while (-not (Test-Path -LiteralPath `$barrier)) { Start-Sleep -Milliseconds 10 }
& '$TargetScript' -PayloadB64 '$b64PlanB'
"@

  # Launch two genuinely separate child processes racing for first control-root creation
  $hA = Start-ChildPowerShellScriptAsync $scriptA
  $hB = Start-ChildPowerShellScriptAsync $scriptB
  Start-Sleep -Milliseconds 100
  [System.IO.File]::WriteAllText($barrierL7, "GO", [System.Text.Encoding]::UTF8)

  $resA = Wait-ChildPowerShellProcess $hA 60000
  $resB = Wait-ChildPowerShellProcess $hB 60000

  $jA = $null; try { $jA = ConvertFrom-Json $resA.StdOut.Trim() } catch {}
  $jB = $null; try { $jB = ConvertFrom-Json $resB.StdOut.Trim() } catch {}

  # Post-hoc independent filesystem verification
  $txExistsAfter = Test-Path -LiteralPath $txL7 -PathType Container
  $lockExistsAfter = Test-Path -LiteralPath (Join-Path $txL7 "ACTIVE.lock")
  $bothValidJson = ($null -ne $jA) -and ($null -ne $jB)
  $outcomesValid = ($jA.status -in @("OK", "NG")) -and ($jB.status -in @("OK", "NG"))

  $passL7 = $txAbsentBefore -and $txExistsAfter -and $lockExistsAfter -and $bothValidJson -and $outcomesValid
  Report-Test "T3_L7_TWO_PROCESS_CONTROL_ROOT_BOOTSTRAP_RACE" $passL7 "TxAbsentBefore: $txAbsentBefore, TxExistsAfter: $txExistsAfter, LockExists: $lockExistsAfter, Statuses: $($jA.status),$($jB.status)" @{ EvidenceClass="REAL_CONCURRENCY"; ChildPid="$($hA.ChildPid),$($hB.ChildPid)" }
} catch {
  Report-Test "T3_L7_TWO_PROCESS_CONTROL_ROOT_BOOTSTRAP_RACE" $false $_.Exception.Message
}

# ==============================================================================
# SECTION B: Tier-3 Rollback Lifecycle & Retain-and-Classify Tests (T3-R1 through T3-R6)
# ==============================================================================

# --- T3-R1: Successful Rollback Reaches ROLLBACK_COMPLETE & Cleans Residue ---
try {
  $vR1 = Join-Path $TestRoot "V_T3_R1"
  [void][System.IO.Directory]::CreateDirectory($vR1)
  $txR1 = Join-Path $vR1 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txR1)

  $txIdR1 = [Guid]::NewGuid().ToString("D")
  $srcFileR1 = Join-Path $vR1 "src_R1.md"
  $dstFileR1 = Join-Path $vR1 "dst_R1.md"
  [System.IO.File]::WriteAllLines($srcFileR1, @("Content R1"), [System.Text.Encoding]::UTF8)
  $expShaR1 = Get-FileSha256Raw $srcFileR1
  $expSzR1 = (Get-Item -LiteralPath $srcFileR1).Length

  [System.IO.File]::Move($srcFileR1, $dstFileR1)

  # Create inprogress file & staging folder to test residue cleanup
  $ipPathR1 = Join-Path $txR1 "$txIdR1.inprogress.json"
  [System.IO.File]::WriteAllText($ipPathR1, "{}", [System.Text.Encoding]::UTF8)

  $stagingDirR1 = Join-Path $txR1 "staging_$txIdR1"
  [void][System.IO.Directory]::CreateDirectory($stagingDirR1)
  $ownerMarkerR1 = Join-Path $stagingDirR1 ".fm-obsidian-merge-owner"
  [System.IO.File]::WriteAllText($ownerMarkerR1, "tok_owner", [System.Text.Encoding]::UTF8)

  $jDataR1 = [ordered]@{
    txId = $txIdR1
    uuid = "11111111-2222-3334-4444-555555555555"
    vaultRoot = $vR1
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_R1"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $srcFileR1
        DestPath = $dstFileR1
        ExpectedSha256 = $expShaR1
        ExpectedSizeBytes = $expSzR1
        OwnerToken = $null
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txR1 $txIdR1 $jDataR1 | Out-Null

  $rbResultR1 = Invoke-OptionBRollback $jDataR1 $txIdR1 $txR1
  if ($rbResultR1.Success) {
    Complete-RollbackEvidenceCleanup $txIdR1 $txR1 $jDataR1
  }

  $journalOnDisk = Get-Content -LiteralPath (Join-Path $txR1 "$txIdR1.journal.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $statusComplete = ($journalOnDisk.rollbackStatus -eq "ROLLBACK_COMPLETE")
  $ipCleaned = -not (Test-Path -LiteralPath $ipPathR1)
  $stagingCleaned = -not (Test-Path -LiteralPath $stagingDirR1)
  $srcRestored = (Test-Path -LiteralPath $srcFileR1) -and (-not (Test-Path -LiteralPath $dstFileR1))

  $passR1 = $rbResultR1.Success -and $rbResultR1.TerminalStatePersisted -and $statusComplete -and $ipCleaned -and $stagingCleaned -and $srcRestored
  Report-Test "T3_R1_ROLLBACK_COMPLETE_TERMINAL_AND_CLEANUP" $passR1 "Success: $($rbResultR1.Success), StatusComplete: $statusComplete, IpCleaned: $ipCleaned, StagingCleaned: $stagingCleaned, SrcRestored: $srcRestored"
} catch {
  Report-Test "T3_R1_ROLLBACK_COMPLETE_TERMINAL_AND_CLEANUP" $false $_.Exception.Message
}

# --- T3-R2: Subsequent PLAN Accepts Valid ROLLBACK_COMPLETE Journal (Read-Only Scan) ---
try {
  $vR2 = Join-Path $TestRoot "V_T3_R2"
  [void][System.IO.Directory]::CreateDirectory($vR2)
  $custR2 = Join-Path $vR2 "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($custR2)
  $fR2 = Join-Path $custR2 "株式会社R2_[22222222]"
  [void][System.IO.Directory]::CreateDirectory($fR2)
  $pfxKeiyaku = Get-IconPrefix "契約"
  $nR2 = Join-Path $fR2 ($pfxKeiyaku + "_テスト.md")
  [System.IO.File]::WriteAllLines($nR2, @("---", "UUID: 22222222-1111-2222-3333-444444444444", "---", "# R2"), [System.Text.Encoding]::UTF8)

  $txR2 = Join-Path $vR2 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txR2)

  # Leave a valid ROLLBACK_COMPLETE journal on disk from a prior transaction
  $txIdR2 = [Guid]::NewGuid().ToString("D")
  $jDataR2 = [ordered]@{
    txId = $txIdR2
    uuid = "22222222-1111-2222-3333-444444444444"
    vaultRoot = $vR2
    canonicalFolderName = "株式会社R2_[22222222]"
    ownerToken = "tok_R2"
    rollbackStatus = "ROLLBACK_COMPLETE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $nR2
        DestPath = (Join-Path $vR2 "nonexistent_dst.md")
        ExpectedSha256 = (Get-FileSha256Raw $nR2)
        ExpectedSizeBytes = (Get-Item -LiteralPath $nR2).Length
        OwnerToken = $null
        State = "ROLLED_BACK"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txR2 $txIdR2 $jDataR2 | Out-Null

  # Leave a surviving inprogress marker to test that read-only Retain-and-Classify validator resolves it without deletion
  $ipPathR2 = Join-Path $txR2 "$txIdR2.inprogress.json"
  [System.IO.File]::WriteAllText($ipPathR2, "{}", [System.Text.Encoding]::UTF8)

  $planOutR2 = Invoke-PlanCustomerFolderMerge @{
    protocolVersion = 1
    action = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId = "req-t3-r2"
    VaultRoot = $vR2
    pk_CLIENT = "22222222-1111-2222-3333-444444444444"
    companyNameRaw = "株式会社R2"
  } | ConvertFrom-Json

  $planSucceeded = ($planOutR2.status -eq "OK") -and ($planOutR2.code -ne "MERGE_RECOVERY_REQUIRED")
  # Read-only scan must retain residue without deleting it
  $ipRetainedR2 = Test-Path -LiteralPath $ipPathR2
  $journalStillExistsR2 = Test-Path -LiteralPath (Join-Path $txR2 "$txIdR2.journal.json")

  $passR2 = $planSucceeded -and $ipRetainedR2 -and $journalStillExistsR2
  Report-Test "T3_R2_PLAN_ACCEPTS_VALID_ROLLBACK_COMPLETE_JOURNAL" $passR2 "PlanStatus: $($planOutR2.status), Code: $($planOutR2.code), IpRetainedReadOnly: $ipRetainedR2, JournalRetained: $journalStillExistsR2"
} catch {
  Report-Test "T3_R2_PLAN_ACCEPTS_VALID_ROLLBACK_COMPLETE_JOURNAL" $false $_.Exception.Message
}

# --- T3-R3: Real Hard-Crash Window H (Rollback Persisted in APPLY, Crash Before Cleanup) ---
try {
  $vR3 = Join-Path $TestRoot "V_T3_R3"
  [void][System.IO.Directory]::CreateDirectory($vR3)
  $custR3 = Join-Path $vR3 "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($custR3)
  $fR3 = Join-Path $custR3 "株式会社R3_[33333333]"
  [void][System.IO.Directory]::CreateDirectory($fR3)
  $pfxKeiyaku = Get-IconPrefix "契約"
  $srcFileR3 = Join-Path $fR3 ($pfxKeiyaku + "_テスト.md")
  $dstFileR3 = Join-Path $vR3 "dst_R3.md"
  [System.IO.File]::WriteAllLines($srcFileR3, @("---", "UUID: 33333333-1111-2222-3333-444444444444", "---", "# Content R3 for Crash H"), [System.Text.Encoding]::UTF8)
  $shaR3 = Get-FileSha256Raw $srcFileR3
  $szR3 = (Get-Item -LiteralPath $srcFileR3).Length

  [System.IO.File]::Move($srcFileR3, $dstFileR3)

  $txR3 = Join-Path $vR3 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txR3)

  $txIdR3 = [Guid]::NewGuid().ToString("D")
  $ipPathR3 = Join-Path $txR3 "$txIdR3.inprogress.json"
  [System.IO.File]::WriteAllText($ipPathR3, "{}", [System.Text.Encoding]::UTF8)

  $jDataR3 = [ordered]@{
    txId = $txIdR3
    uuid = "33333333-1111-2222-3333-444444444444"
    vaultRoot = $vR3
    canonicalFolderName = "株式会社R3_[33333333]"
    ownerToken = "tok_R3"
    rollbackStatus = "NONE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = $srcFileR3
        DestPath = $dstFileR3
        ExpectedSha256 = $shaR3
        ExpectedSizeBytes = $szR3
        OwnerToken = $null
        State = "COMPLETED"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txR3 $txIdR3 $jDataR3 | Out-Null

  # Execute child process armed with crash hook H
  $childR3Script = @"
`$global:__TEST_CRASH_HOOK = 'H'

if (-not ([System.Management.Automation.PSTypeName]'Win32DurableJournalHelper').Type) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Win32DurableJournalHelper {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "MoveFileExW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, uint dwFlags);
    public const uint MOVEFILE_REPLACE_EXISTING = 0x1;
    public const uint MOVEFILE_WRITE_THROUGH    = 0x8;
}
'@
}

`$astErrors = `$null; `$astTokens = `$null
`$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile('$TargetScript', [ref]`$astTokens, [ref]`$astErrors)
`$funcAsts = `$scriptAst.FindAll({ param(`$n) `$n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, `$true)
foreach (`$f in `$funcAsts) { Invoke-Expression `$f.Extent.Text }

# Simulate APPLY's catch block execution after failure
`$rbRes = Invoke-OptionBRollback `$null '$txIdR3' '$txR3'
if (`$rbRes.Success) {
  Invoke-TestCrashHook "H"
  Complete-RollbackEvidenceCleanup '$txIdR3' '$txR3' `$null
}
"@
  $resR3 = Invoke-ChildPowerShellScript $childR3Script
  Assert-ParentHookDisarmed

  $hardKillR3 = ($resR3.ExitCode -eq -1) -or ($resR3.ExitCode -eq 4294967295)

  # Check on-disk state after crash H
  $jDiskR3 = Get-Content -LiteralPath (Join-Path $txR3 "$txIdR3.journal.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  $statusCompleteR3 = ($jDiskR3.rollbackStatus -eq "ROLLBACK_COMPLETE")
  $ipStillExistsR3 = Test-Path -LiteralPath $ipPathR3   # Residue survived because crash occurred at Window H
  $srcRestoredR3 = Test-Path -LiteralPath $srcFileR3

  # Fresh PLAN starts and encounters surviving inprogress + ROLLBACK_COMPLETE journal
  $pJsonR3_Plan = @{
    protocolVersion = 1
    action = 'PLAN_CUSTOMER_FOLDER_MERGE'
    requestId = 'req-t3-r3-fresh'
    VaultRoot = $vR3
    pk_CLIENT = '33333333-1111-2222-3333-444444444444'
    companyNameRaw = '株式会社R3'
  } | ConvertTo-Json -Compress

  $resR3_Plan = Invoke-ChildPayloadJson $pJsonR3_Plan
  Assert-ParentHookDisarmed

  $planOutR3 = $null
  try { $planOutR3 = ConvertFrom-Json $resR3_Plan.StdOut.Trim() } catch {}

  $freshPlanOk = ($null -ne $planOutR3) -and ($planOutR3.status -eq "OK")
  # With strictly read-only recovery scan, inprogress residue is retained
  $ipRetainedAfterFreshPlan = Test-Path -LiteralPath $ipPathR3

  $passR3 = $hardKillR3 -and $statusCompleteR3 -and $ipStillExistsR3 -and $srcRestoredR3 -and $freshPlanOk -and $ipRetainedAfterFreshPlan
  Report-Test "T3_R3_HARD_CRASH_WINDOW_H_AND_FRESH_PLAN_RECOVERY" $passR3 "HardKill: $hardKillR3 (ExitCode: $($resR3.ExitCode)), StatusComplete: $statusCompleteR3, IpSurvivedCrash: $ipStillExistsR3, FreshPlanOk: $freshPlanOk, IpRetainedReadOnly: $ipRetainedAfterFreshPlan" @{ EvidenceClass="REAL_CRASH"; ChildPid=$resR3.ChildPid; ChildExitCode=$resR3.ExitCode }
} catch {
  Report-Test "T3_R3_HARD_CRASH_WINDOW_H_AND_FRESH_PLAN_RECOVERY" $false $_.Exception.Message
}
Assert-ParentHookDisarmed

# --- T3-R4: Incomplete / Tampered Rollback Journal Fails Closed in PLAN/APPLY ---
try {
  $vR4 = Join-Path $TestRoot "V_T3_R4"
  [void][System.IO.Directory]::CreateDirectory($vR4)
  $txR4 = Join-Path $vR4 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txR4)

  # Case 1: Journal claims ROLLBACK_COMPLETE, but expected source file does not exist
  $txIdR4_1 = [Guid]::NewGuid().ToString("D")
  $jDataR4_1 = [ordered]@{
    txId = $txIdR4_1
    uuid = "44444444-1111-2222-3334-444444444444"
    vaultRoot = $vR4
    canonicalFolderName = "01_顧客"
    ownerToken = "tok_R4"
    rollbackStatus = "ROLLBACK_COMPLETE"
    entries = @(
      [ordered]@{
        Seq = 1
        OpType = "MOVE_FILE"
        SourcePath = (Join-Path $vR4 "missing_source.md")
        DestPath = (Join-Path $vR4 "dst.md")
        ExpectedSha256 = "abc"
        ExpectedSizeBytes = 10
        OwnerToken = $null
        State = "ROLLED_BACK"
        Timestamp = "2026-08-30T10:00:00Z"
      }
    )
  }
  Write-JournalEvidenceSafe $txR4 $txIdR4_1 $jDataR4_1 | Out-Null
  [System.IO.File]::WriteAllText((Join-Path $txR4 "$txIdR4_1.inprogress.json"), "{}", [System.Text.Encoding]::UTF8)

  $planOutR4_1 = Invoke-PlanCustomerFolderMerge @{
    protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-t3-r4-1"; VaultRoot = $vR4; pk_CLIENT = "44444444-1111-2222-3334-444444444444"; companyNameRaw = "テストR4"
  } | ConvertFrom-Json

  $case1Blocked = ($planOutR4_1.status -eq "NG") -and ($planOutR4_1.code -eq "MERGE_RECOVERY_REQUIRED")

  # Case 2: Committed evidence exists alongside rollback journal -> fail closed
  $txIdR4_2 = [Guid]::NewGuid().ToString("D")
  [System.IO.File]::WriteAllText((Join-Path $txR4 "$txIdR4_2.committed.json"), "{}", [System.Text.Encoding]::UTF8)
  [System.IO.File]::WriteAllText((Join-Path $txR4 "$txIdR4_2.inprogress.json"), "{}", [System.Text.Encoding]::UTF8)
  $jDataR4_2 = [ordered]@{
    txId = $txIdR4_2; uuid = "44444444-1111-2222-3334-444444444444"; vaultRoot = $vR4; canonicalFolderName = "01_顧客"; ownerToken = "t"; rollbackStatus = "ROLLBACK_COMPLETE"; entries = @()
  }
  Write-JournalEvidenceSafe $txR4 $txIdR4_2 $jDataR4_2 | Out-Null

  $semValidWithCommitted = Test-RollbackCompleteSemanticValid $jDataR4_2 $txIdR4_2 $txR4
  $case2Blocked = (-not $semValidWithCommitted)

  Report-Test "T3_R4_TAMPERED_OR_AMBIGUOUS_ROLLBACK_FAILS_CLOSED" ($case1Blocked -and $case2Blocked) "MissingSourceBlocked: $case1Blocked, CommittedCollisionBlocked: $case2Blocked"
} catch {
  Report-Test "T3_R4_TAMPERED_OR_AMBIGUOUS_ROLLBACK_FAILS_CLOSED" $false $_.Exception.Message
}

# --- T3-R5: Test-RollbackCompleteSemanticValid Unit Matrix ---
try {
  $vR5 = Join-Path $TestRoot "V_T3_R5"
  [void][System.IO.Directory]::CreateDirectory($vR5)
  $txR5 = Join-Path $vR5 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txR5)

  $sFile = Join-Path $vR5 "s.md"
  $dFile = Join-Path $vR5 "d.md"
  [System.IO.File]::WriteAllLines($sFile, @("test s"), [System.Text.Encoding]::UTF8)
  $sSha = Get-FileSha256Raw $sFile

  # 1. Valid file move rollback complete
  $jGood = [ordered]@{
    txId = "TX_GOOD"; uuid = "u"; vaultRoot = $vR5; canonicalFolderName = "01_顧客"; ownerToken = "t"; rollbackStatus = "ROLLBACK_COMPLETE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = $sFile; DestPath = $dFile; ExpectedSha256 = $sSha; ExpectedSizeBytes = 6; OwnerToken = $null; State = "ROLLED_BACK"; Timestamp = "2026-08-30T10:00:00Z" })
  }
  $goodRes = Test-RollbackCompleteSemanticValid $jGood "TX_GOOD" $txR5

  # 2. Invalid state (PENDING instead of ROLLED_BACK)
  $jPending = [ordered]@{
    txId = "TX_PENDING"; uuid = "u"; vaultRoot = $vR5; canonicalFolderName = "01_顧客"; ownerToken = "t"; rollbackStatus = "ROLLBACK_COMPLETE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = $sFile; DestPath = $dFile; ExpectedSha256 = $sSha; ExpectedSizeBytes = 6; OwnerToken = $null; State = "PENDING"; Timestamp = "2026-08-30T10:00:00Z" })
  }
  $pendingRes = Test-RollbackCompleteSemanticValid $jPending "TX_PENDING" $txR5

  # 3. Destination file still exists on disk
  [System.IO.File]::WriteAllLines($dFile, @("dest exists"), [System.Text.Encoding]::UTF8)
  $destExistsRes = Test-RollbackCompleteSemanticValid $jGood "TX_GOOD" $txR5
  Remove-Item -LiteralPath $dFile -Force

  # 4. Hash mismatch on restored source file
  $jHashMismatch = [ordered]@{
    txId = "TX_HASH"; uuid = "u"; vaultRoot = $vR5; canonicalFolderName = "01_顧客"; ownerToken = "t"; rollbackStatus = "ROLLBACK_COMPLETE"
    entries = @([ordered]@{ Seq = 1; OpType = "MOVE_FILE"; SourcePath = $sFile; DestPath = $dFile; ExpectedSha256 = "WRONG_HASH"; ExpectedSizeBytes = 6; OwnerToken = $null; State = "ROLLED_BACK"; Timestamp = "2026-08-30T10:00:00Z" })
  }
  $hashMismatchRes = Test-RollbackCompleteSemanticValid $jHashMismatch "TX_HASH" $txR5

  $matrixPass = $goodRes -and (-not $pendingRes) -and (-not $destExistsRes) -and (-not $hashMismatchRes)
  Report-Test "T3_R5_SEMANTIC_VALIDATOR_UNIT_MATRIX" $matrixPass "Good: $goodRes, PendingRejected: $(-not $pendingRes), DestExistsRejected: $(-not $destExistsRes), HashMismatchRejected: $(-not $hashMismatchRes)"
} catch {
  Report-Test "T3_R5_SEMANTIC_VALIDATOR_UNIT_MATRIX" $false $_.Exception.Message
}

# --- T3-R6: Complete-RollbackEvidenceCleanup Safety Invariants ---
try {
  $vR6 = Join-Path $TestRoot "V_T3_R6"
  [void][System.IO.Directory]::CreateDirectory($vR6)
  $txR6 = Join-Path $vR6 ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txR6)

  $txIdR6 = [Guid]::NewGuid().ToString("D")
  $jPathR6 = Join-Path $txR6 "$txIdR6.journal.json"
  [System.IO.File]::WriteAllText($jPathR6, "{ txId: '$txIdR6' }", [System.Text.Encoding]::UTF8)

  $ipPathR6 = Join-Path $txR6 "$txIdR6.inprogress.json"
  [System.IO.File]::WriteAllText($ipPathR6, "{}", [System.Text.Encoding]::UTF8)

  $stagingDirR6 = Join-Path $txR6 "staging_$txIdR6"
  [void][System.IO.Directory]::CreateDirectory($stagingDirR6)
  $ownerMarkerR6 = Join-Path $stagingDirR6 ".fm-obsidian-merge-owner"
  [System.IO.File]::WriteAllText($ownerMarkerR6, "tok", [System.Text.Encoding]::UTF8)

  $custNoteR6 = Join-Path $vR6 "customer_note.md"
  [System.IO.File]::WriteAllLines($custNoteR6, @("Customer Note Intact"), [System.Text.Encoding]::UTF8)
  $shaBeforeR6 = Get-FileSha256Raw $custNoteR6

  # Execute cleanup
  Complete-RollbackEvidenceCleanup $txIdR6 $txR6 $null

  $journalPreserved = Test-Path -LiteralPath $jPathR6
  $ipDeleted = -not (Test-Path -LiteralPath $ipPathR6)
  $stagingDeleted = -not (Test-Path -LiteralPath $stagingDirR6)
  $committedNotCreated = -not (Test-Path -LiteralPath (Join-Path $txR6 "$txIdR6.committed.json"))
  $custNoteIntact = (Test-Path -LiteralPath $custNoteR6) -and ((Get-FileSha256Raw $custNoteR6) -eq $shaBeforeR6)

  $passR6 = $journalPreserved -and $ipDeleted -and $stagingDeleted -and $committedNotCreated -and $custNoteIntact
  Report-Test "T3_R6_CLEANUP_SAFETY_INVARIANTS" $passR6 "JournalPreserved: $journalPreserved, IpDeleted: $ipDeleted, StagingDeleted: $stagingDeleted, CommittedNotCreated: $committedNotCreated, CustNoteIntact: $custNoteIntact"
} catch {
  Report-Test "T3_R6_CLEANUP_SAFETY_INVARIANTS" $false $_.Exception.Message
}

# ==============================================================================
# SECTION C: Durable Report Generation
# ==============================================================================
$targetSha = (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash.ToUpperInvariant()
$passCount = ($script:testResults | Where-Object { $_.Passed }).Count
$reportHeader = [ordered]@{
  Suite                    = "Tier 3 Focused & Concurrency Regression Suite"
  TargetScript             = $TargetScript
  TargetSha256             = $targetSha
  RunTimestamp             = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  PowerShellVersion        = $PSVersionTable.PSVersion.ToString()
  PSEdition                = $PSVersionTable.PSEdition
  OSVersion                = [Environment]::OSVersion.VersionString
  TestCount                = $script:totalTests
  PassCount                = $passCount
  FailCount                = ($script:totalTests - $passCount)
  RealConcurrencyCovered   = "T3-L1, T3-L2, T3-L3, T3-L4, T3-L7"
  RealCrashWindowsCovered  = "T3-R3 (Window H)"
}

$reportTxtPath = Join-Path $TestRoot "_report.txt"
$reportJsonPath = Join-Path $TestRoot "_report.json"

$lines = @(
  "=====================================================",
  "Tier 3 Focused & Concurrency Report",
  "TargetScript: $($reportHeader.TargetScript)",
  "TargetSha256: $($reportHeader.TargetSha256)",
  "RunTimestamp: $($reportHeader.RunTimestamp)",
  "PowerShellVersion: $($reportHeader.PowerShellVersion) ($($reportHeader.PSEdition))",
  "OSVersion: $($reportHeader.OSVersion)",
  "Summary: $($reportHeader.PassCount) / $($reportHeader.TestCount) PASS",
  "RealConcurrencyCovered: $($reportHeader.RealConcurrencyCovered)",
  "RealCrashWindowsCovered: $($reportHeader.RealCrashWindowsCovered)",
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
Write-Host "Tier 3 Suite Summary: $passCount/$($script:totalTests) PASS"
Write-Host "Durable Reports Written:"
Write-Host "  $reportTxtPath"
Write-Host "  $reportJsonPath"
Write-Host "====================================================="

if ($passCount -ne $script:totalTests) {
  exit 1
}
