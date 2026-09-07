<#
==============================================================================
Test-J2Step6CanonicalDestinationRegression.ps1
Gate 4 / J-2 Step 6 Stage A Dedicated Regression Suite (T01 - T17)
Runtime: Windows PowerShell 5.1
==============================================================================
#>

[CmdletBinding()]
param(
  [string]$TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1",
  [string]$TestRoot = "D:\FM-Script-Backup\WindowsTestKit_CUSTOMER_FOLDER_MERGE\TestVault_MERGE\V_J2_TEST"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Gate 4 / J-2 Step 6 Canonical Destination Regression" -ForegroundColor Cyan
Write-Host "Target:   $TargetScript" -ForegroundColor Cyan
Write-Host "TestRoot: $TestRoot" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Host "[FAIL] Target script not found: $TargetScript" -ForegroundColor Red
  exit 1
}

# ------------------------------------------------------------------------------
# 1. AST Parsing & Dynamic Symbol Resolution (Section 11 Compliance)
# ------------------------------------------------------------------------------
$astTokens = $null
$astErrors = $null
$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
  $TargetScript,
  [ref]$astTokens,
  [ref]$astErrors
)

if ($null -ne $astErrors -and $astErrors.Count -gt 0) {
  Write-Host "[FAIL] Failed to parse target script AST ($($astErrors.Count) errors)" -ForegroundColor Red
  $astErrors | ForEach-Object { Write-Host "       $($_.Message)" -ForegroundColor Red }
  exit 1
}

# Resolve Invoke-PlanCustomerFolderMerge and Invoke-ApplyCustomerFolderMerge
$funcPlan = $scriptAst.Find({
  param($n)
  $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-PlanCustomerFolderMerge'
}, $true)

$funcApply = $scriptAst.Find({
  param($n)
  $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-ApplyCustomerFolderMerge'
}, $true)

if ($null -eq $funcPlan -or $null -eq $funcApply) {
  Write-Host "[FAIL] Could not locate Invoke-PlanCustomerFolderMerge or Invoke-ApplyCustomerFolderMerge in AST" -ForegroundColor Red
  exit 1
}

# Helper to locate the main StatementBlockAst inside try
function Get-MainStatementBlock($funcAst) {
  $callTopo = $funcAst.Find({
    param($n)
    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Get-CustomerMergeTopology'
  }, $true)
  if ($null -eq $callTopo) { return $null }

  $cur = $callTopo
  while ($null -ne $cur -and -not ($cur.Parent -is [System.Management.Automation.Language.TryStatementAst] -and $cur.Parent.Body -eq $cur)) {
    $cur = $cur.Parent
  }
  return $cur
}

$planMainBlock = Get-MainStatementBlock $funcPlan
$applyMainBlock = Get-MainStatementBlock $funcApply

if ($null -eq $planMainBlock -or $null -eq $applyMainBlock) {
  Write-Host "[FAIL] Could not locate main StatementBlockAst for Plan or Apply" -ForegroundColor Red
  exit 1
}

# Dynamically identify the private shared helper function and resolver-result variable
function Get-ResolverSymbolInfo($mainBlock) {
  for ($i = 0; $i -lt $mainBlock.Statements.Count; $i++) {
    $stmt = $mainBlock.Statements[$i]
    if ($stmt -is [System.Management.Automation.Language.AssignmentStatementAst]) {
      $right = $stmt.Right
      if ($right -is [System.Management.Automation.Language.PipelineAst] -and $right.PipelineElements[0] -is [System.Management.Automation.Language.CommandAst]) {
        $cmd = $right.PipelineElements[0]
        if ($cmd.CommandElements.Count -ge 2 -and $cmd.CommandElements[1].Extent.Text -match '\$topo') {
          return @{
            AssignIdx   = $i
            VarName     = $stmt.Left.VariablePath.UserPath
            HelperName  = $cmd.GetCommandName()
            CommandAst  = $cmd
          }
        }
      }
    }
  }
  return $null
}

$planResolverInfo = Get-ResolverSymbolInfo $planMainBlock
$applyResolverInfo = Get-ResolverSymbolInfo $applyMainBlock

if ($null -eq $planResolverInfo -or $null -eq $applyResolverInfo) {
  Write-Host "[FAIL] Could not dynamically resolve helper call in Plan or Apply AST" -ForegroundColor Red
  exit 1
}

if ($planResolverInfo.HelperName -ne $applyResolverInfo.HelperName) {
  Write-Host "[FAIL] Plan helper ($($planResolverInfo.HelperName)) and Apply helper ($($applyResolverInfo.HelperName)) do not match!" -ForegroundColor Red
  exit 1
}

$sharedHelperName = $applyResolverInfo.HelperName
$sharedResolverVar = $applyResolverInfo.VarName
Write-Host "[AST] Dynamically resolved shared helper symbol: $sharedHelperName" -ForegroundColor Green
Write-Host "[AST] Dynamically resolved resolver variable:    `$$sharedResolverVar" -ForegroundColor Green

# Extract the shared helper function definition AST and dot-source it for direct unit invocation (T05, T06)
$helperFuncAst = $scriptAst.Find({
  param($n)
  $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $sharedHelperName
}, $true)

if ($null -eq $helperFuncAst) {
  Write-Host "[FAIL] Could not locate FunctionDefinitionAst for $sharedHelperName" -ForegroundColor Red
  exit 1
}

# Invoke definition into current test scope
Invoke-Expression $helperFuncAst.Extent.Text

# ------------------------------------------------------------------------------
# 2. Test Execution Harness & Verification Helpers
# ------------------------------------------------------------------------------
$script:testResults = [System.Collections.Generic.List[object]]::new()

function Record-TestResult([string]$TestId, [string]$Name, [bool]$Passed, [string]$Details, [string]$Observed = "") {
  $mark = if ($Passed) { "PASS" } else { "FAIL" }
  $color = if ($Passed) { "Green" } else { "Red" }
  Write-Host ("[{0}] {1}: {2}" -f $mark, $TestId, $Name) -ForegroundColor $color
  if (-not $Passed -and $Details) {
    Write-Host "       Details:  $Details" -ForegroundColor Yellow
  }
  if ($Observed) {
    Write-Host "       Observed: $Observed" -ForegroundColor DarkGray
  }
  $script:testResults.Add([pscustomobject]@{
    TestId   = $TestId
    Name     = $Name
    Passed   = $Passed
    Details  = $Details
    Observed = $Observed
  })
}

# Clean and recreate test root safely
function Reset-TestEnvironment {
  if (Test-Path -LiteralPath $TestRoot) {
    # Remove junctions first if any exist
    Get-ChildItem -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {
      ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    } | ForEach-Object {
      cmd.exe /c "rmdir `"$($_.FullName)`"" 2>$null
    }
    Remove-Item -LiteralPath $TestRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
  [void][System.IO.Directory]::CreateDirectory($TestRoot)
  $custRoot = Join-Path $TestRoot "01_顧客"
  [void][System.IO.Directory]::CreateDirectory($custRoot)
  $txDir = Join-Path $TestRoot ".fm-obsidian-bridge-transactions"
  [void][System.IO.Directory]::CreateDirectory($txDir)
  return $custRoot
}

function New-MockCustomerNote([string]$FolderPath, [string]$FileName, [string]$Uuid, [string]$NoteType, [string]$Body = "本文") {
  if (-not (Test-Path -LiteralPath $FolderPath)) {
    [void][System.IO.Directory]::CreateDirectory($FolderPath)
  }
  $filePath = Join-Path $FolderPath $FileName
  $content = "---`nUUID: $Uuid`n---`n# $NoteType`n$Body"
  [System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($false))
  return $filePath
}

function Invoke-ChildBridgePayload([hashtable]$Payload) {
  $json = $Payload | ConvertTo-Json -Depth 10 -Compress
  $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))

  $tmpFile = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tmpFile, $b64, [System.Text.UTF8Encoding]::new($false))

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = Join-Path $PSHOME "powershell.exe"
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetScript`" -PayloadFile `"$tmpFile`""
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

  $proc = [System.Diagnostics.Process]::Start($psi)
  $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
  $stderrTask = $proc.StandardError.ReadToEndAsync()
  $proc.WaitForExit()

  $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
  $stderr = $stderrTask.GetAwaiter().GetResult().Trim()
  $exitCode = $proc.ExitCode

  try { Remove-Item -LiteralPath $tmpFile -Force -ErrorAction SilentlyContinue } catch {}

  $respObj = $null
  if ($stdout) {
    try {
      $respObj = $stdout | ConvertFrom-Json
    } catch {
      # Try finding last JSON line
      $lines = @($stdout -split "`r?`n")
      for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i].Trim().StartsWith('{')) {
          try {
            $respObj = $lines[$i..($lines.Count - 1)] -join "`n" | ConvertFrom-Json
            break
          } catch {}
        }
      }
    }
  }

  return @{
    ExitCode = $exitCode
    Stdout   = $stdout
    Stderr   = $stderr
    Response = $respObj
  }
}

function Get-J2FileSha256 {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$LiteralPath
  )
  $fs = [System.IO.FileStream]::new($LiteralPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha256.ComputeHash($fs)
    $sb = [System.Text.StringBuilder]::new($hashBytes.Length * 2)
    foreach ($b in $hashBytes) {
      [void]$sb.Append($b.ToString("X2"))
    }
    return $sb.ToString()
  } finally {
    $sha256.Dispose()
    $fs.Close()
    $fs.Dispose()
  }
}

function Get-RecursiveSnapshot([string]$RootPath) {
  $map = [ordered]@{}
  if (-not (Test-Path -LiteralPath $RootPath)) { return $map }

  $items = Get-ChildItem -LiteralPath $RootPath -Recurse -Force
  foreach ($item in $items) {
    $rel = $item.FullName.Substring($RootPath.Length).TrimStart('\', '/')
    $isDir = [bool]($item.Attributes -band [System.IO.FileAttributes]::Directory)
    $isReparse = [bool]($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
    $size = if ($isDir) { 0 } else { $item.Length }
    $sha = if ($isDir -or $isReparse) { "" } else { Get-J2FileSha256 -LiteralPath $item.FullName }
    $map[$rel] = @{
      RelPath   = $rel
      IsDir     = $isDir
      IsReparse = $isReparse
      Size      = $size
      Sha256    = $sha
    }
  }
  return $map
}

function Compare-Snapshots($snap1, $snap2) {
  if ($snap1.Count -ne $snap2.Count) { return $false }
  foreach ($k in $snap1.Keys) {
    if (-not $snap2.Contains($k)) { return $false }
    $e1 = $snap1[$k]
    $e2 = $snap2[$k]
    if ($e1.IsDir -ne $e2.IsDir -or $e1.IsReparse -ne $e2.IsReparse -or $e1.Size -ne $e2.Size -or $e1.Sha256 -ne $e2.Sha256) {
      return $false
    }
  }
  return $true
}

# ------------------------------------------------------------------------------
# TEST CASES T01 - T17
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# T01 — MATCHED_EXISTING APPLY
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonName = "株式会社テスト_[11111111]"
  $canonDir = Join-Path $custRoot $canonName
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t01-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t01-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "OK") -and ($resp.code -eq "MERGE_COMPLETED")
  Record-TestResult "T01" "MATCHED_EXISTING APPLY -> OK / MERGE_COMPLETED" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T01" "MATCHED_EXISTING APPLY" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T02 — ABSENT APPLY
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonName = "株式会社テスト_[11111111]"
  $canonDir = Join-Path $custRoot $canonName

  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $canonAbsentBefore = -not (Test-Path -LiteralPath $canonDir)

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t02-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t02-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $canonExistsAfter = Test-Path -LiteralPath $canonDir -PathType Container
  $pass = ($canonAbsentBefore -and ($null -ne $resp) -and ($resp.status -eq "OK") -and ($resp.code -eq "MERGE_COMPLETED") -and $canonExistsAfter)
  Record-TestResult "T02" "ABSENT APPLY -> OK / MERGE_COMPLETED" $pass "CanonAbsentBefore: $canonAbsentBefore, Status: $($resp.status), Code: $($resp.code), CanonCreated: $canonExistsAfter" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T02" "ABSENT APPLY" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T03 — UNOWNED_DIRECTORY APPLY
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"

  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null
  # Create unowned directory at canonical path (contains no UUID evidence)
  [void][System.IO.Directory]::CreateDirectory($canonDir)
  [System.IO.File]::WriteAllText((Join-Path $canonDir "unrelated.txt"), "no uuid", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t03-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }

  $resp = $applyRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapMatch = Compare-Snapshots $snapBefore $snapAfter

  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "CANONICAL_FOLDER_NO_UUID_EVIDENCE") -and $snapMatch
  Record-TestResult "T03" "UNOWNED_DIRECTORY APPLY -> NG / CANONICAL_FOLDER_NO_UUID_EVIDENCE" $pass "Status: $($resp.status), Code: $($resp.code), SnapMatch: $snapMatch" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T03" "UNOWNED_DIRECTORY APPLY" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T04 — NON_DIRECTORY_OCCUPANT APPLY
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonPath = Join-Path $custRoot "株式会社テスト_[11111111]"

  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null
  # Create regular file at canonical path
  [System.IO.File]::WriteAllText($canonPath, "regular file occupant", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t04-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }

  $resp = $applyRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapMatch = Compare-Snapshots $snapBefore $snapAfter
  $occupantIntact = (Test-Path -LiteralPath $canonPath -PathType Leaf) -and ((Get-Content -LiteralPath $canonPath -Raw) -eq "regular file occupant")

  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_CANONICAL_PATH_OCCUPIED") -and $snapMatch -and $occupantIntact
  Record-TestResult "T04" "NON_DIRECTORY_OCCUPANT APPLY -> NG / MERGE_CANONICAL_PATH_OCCUPIED" $pass "Status: $($resp.status), Code: $($resp.code), SnapMatch: $snapMatch, OccupantIntact: $occupantIntact" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T04" "NON_DIRECTORY_OCCUPANT APPLY" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T05 — resolver-only INSPECTION_FAILED runtime test
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  # 1. Establish valid topology first
  $matchedFolders = @(
    @{ FullPath = $canonDir; FolderName = "株式会社テスト_[11111111]" },
    @{ FullPath = $folderB;  FolderName = "株式会社テスト_旧名" }
  )
  $realTopo = @{
    CustRoot                = $custRoot
    CanonicalFolderName     = "株式会社テスト_[11111111]"
    CanonicalFolderFullPath = $canonDir
    MatchedFolders          = $matchedFolders
  }

  # 2. Apply ACL Deny to parent and canonical path
  $account = "$env:USERDOMAIN\$env:USERNAME"
  & icacls.exe "$custRoot" /deny "${account}:(RD)" | Out-Null
  & icacls.exe "$canonDir" /deny "${account}:(F)" | Out-Null

  $primitiveThrew = $false
  $primitiveExceptionType = $null
  $primitiveUnauthorizedExact = $false
  try {
    # 3. Verify fail-closed that Get-Item raises UnauthorizedAccessException
    $null = Get-Item -LiteralPath $canonDir -Force -ErrorAction Stop
  } catch {
    $primitiveThrew = $true
    $primitiveExceptionType = $_.Exception.GetType().FullName
    if ($primitiveExceptionType -eq "System.UnauthorizedAccessException") {
      $primitiveUnauthorizedExact = $true
    }
  }

  # 4. Invoke the REAL implemented shared resolver directly
  $actualState = & $sharedHelperName $realTopo

  # 5. Restore ACL and verify restoration
  $exitCodeCustRoot = -1
  $exitCodeCanonDir = -1
  $aclRestorationVerified = $false

  & icacls.exe "$custRoot" /reset | Out-Null
  $exitCodeCustRoot = $LASTEXITCODE
  & icacls.exe "$canonDir" /reset | Out-Null
  $exitCodeCanonDir = $LASTEXITCODE

  $postRestoreSuccess = $false
  try {
    $null = Get-Item -LiteralPath $canonDir -Force -ErrorAction Stop
    $postRestoreSuccess = $true
  } catch {}

  if ($exitCodeCustRoot -eq 0 -and $exitCodeCanonDir -eq 0 -and $postRestoreSuccess) {
    $aclRestorationVerified = $true
  }

  $detailStr = "PrimitiveExceptionThrown=$primitiveThrew, PrimitiveExceptionType=$primitiveExceptionType, PrimitiveUnauthorizedAccessExact=$primitiveUnauthorizedExact, ResolverResult=$actualState, ACLResetExitCodeCustRoot=$exitCodeCustRoot, ACLResetExitCodeCanonDir=$exitCodeCanonDir, ACLRestorationVerified=$aclRestorationVerified"

  $pass = $primitiveThrew -and $primitiveUnauthorizedExact -and ($actualState -eq "INSPECTION_FAILED") -and $aclRestorationVerified
  Record-TestResult "T05" "resolver-only INSPECTION_FAILED runtime test" $pass `
    $detailStr `
    "PrimitiveExceptionThrown=$primitiveThrew`nPrimitiveExceptionType=$primitiveExceptionType`nPrimitiveUnauthorizedAccessExact=$primitiveUnauthorizedExact`nResolverResult=$actualState`nACLResetExitCodeCustRoot=$exitCodeCustRoot`nACLResetExitCodeCanonDir=$exitCodeCanonDir`nACLRestorationVerified=$aclRestorationVerified"
} catch {
  Record-TestResult "T05" "resolver-only INSPECTION_FAILED runtime test" $false $_.Exception.Message
} finally {
  # 6. Restore ACL fully in finally to guarantee cleanup
  try {
    & icacls.exe "$custRoot" /reset | Out-Null
    & icacls.exe "$canonDir" /reset | Out-Null
  } catch {}
}

# ------------------------------------------------------------------------------
# T06 — OrdinalIgnoreCase membership
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  [void][System.IO.Directory]::CreateDirectory($canonDir)

  # Casing variation in MatchedFolders vs CanonicalFolderFullPath
  $casedPath = $canonDir.ToUpperInvariant()
  $topoCase = @{
    CustRoot                = $custRoot
    CanonicalFolderName     = "株式会社テスト_[11111111]"
    CanonicalFolderFullPath = $canonDir
    MatchedFolders          = @(
      @{ FullPath = $casedPath; FolderName = "株式会社テスト_[11111111]".ToUpperInvariant() }
    )
  }

  $actualState = & $sharedHelperName $topoCase
  $pass = ($actualState -eq "MATCHED_EXISTING")
  Record-TestResult "T06" "OrdinalIgnoreCase membership test" $pass "ActualState: $actualState" "Resolved: $actualState"
} catch {
  Record-TestResult "T06" "OrdinalIgnoreCase membership test" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T07 — reparse handling
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $targetDir = Join-Path $TestRoot "JunctionTargetDir"
  [void][System.IO.Directory]::CreateDirectory($targetDir)
  [System.IO.File]::WriteAllText((Join-Path $targetDir "target_file.txt"), "target content", [System.Text.Encoding]::UTF8)

  $juncPath = Join-Path $custRoot "株式会社テスト_ジャンクション"
  cmd.exe /c "mklink /J `"$juncPath`" `"$targetDir`"" | Out-Null
  $isJunc = [bool]((Get-Item -LiteralPath $juncPath -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint)

  if (-not $isJunc) {
    throw "Precondition failure: Junction could not be established at $juncPath"
  }

  $snapBefore = Get-RecursiveSnapshot $targetDir

  $res = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t07-reparse"
    VaultRoot      = $TestRoot
    pk_CLIENT      = "11111111-2222-3333-4444-555555555555"
    companyNameRaw = "株式会社テスト"
  }

  $resp = $res.Response
  $snapAfter = Get-RecursiveSnapshot $targetDir
  $targetIntact = Compare-Snapshots $snapBefore $snapAfter

  # Safely delete junction without deleting target
  cmd.exe /c "rmdir `"$juncPath`"" 2>$null

  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_REPARSE_POINT_UNSUPPORTED") -and $targetIntact
  Record-TestResult "T07" "reparse handling -> NG / MERGE_REPARSE_POINT_UNSUPPORTED" $pass "Status: $($resp.status), Code: $($resp.code), TargetIntact: $targetIntact" "Stdout: $($res.Stdout)"
} catch {
  Record-TestResult "T07" "reparse handling" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T08 — exact matched-set membership drift / stale plan token
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"
  $folderBNew = Join-Path $custRoot "株式会社テスト_変更後"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  # Run PLAN first
  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t08-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planResp = $planRes.Response
  $planToken = $planResp.planToken
  $planOk = ($null -ne $planResp) -and ($planResp.status -eq "OK") -and ($planResp.code -eq "MERGE_PLAN_READY")

  # Rename B to 株式会社テスト_変更後
  Rename-Item -LiteralPath $folderB -NewName "株式会社テスト_変更後"

  # Authoritative recursive snapshot immediately after rename and before APPLY
  $preApplySnap = Get-RecursiveSnapshot $custRoot

  # Fresh APPLY
  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t08-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $applyResp = $applyRes.Response
  $postApplySnap = Get-RecursiveSnapshot $custRoot
  $snapEqual = Compare-Snapshots $preApplySnap $postApplySnap

  # Check transaction preparation absent
  $txDir = Join-Path $TestRoot ".fm-obsidian-bridge-transactions"
  $txFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*req-t08-apply*" -ErrorAction SilentlyContinue)
  $noTxPrep = ($txFiles.Count -eq 0)

  $pass = $planOk -and ($null -ne $applyResp) -and ($applyResp.status -eq "NG") -and ($applyResp.code -eq "PLAN_TOKEN_MISMATCH") -and $noTxPrep -and $snapEqual
  Record-TestResult "T08" "exact matched-set membership drift / stale plan token -> NG / PLAN_TOKEN_MISMATCH" $pass "PlanOk: $planOk, ApplyStatus: $($applyResp.status), ApplyCode: $($applyResp.code), NoTxPrep: $noTxPrep, SnapEqual: $snapEqual" "Apply Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T08" "exact matched-set membership drift / stale plan token" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T09 — canonical directory created between PLAN/APPLY
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"

  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t09-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  # Create unowned directory at canonical path
  [void][System.IO.Directory]::CreateDirectory($canonDir)
  [System.IO.File]::WriteAllText((Join-Path $canonDir "unrelated.txt"), "no uuid", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t09-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapMatch = Compare-Snapshots $snapBefore $snapAfter

  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "CANONICAL_FOLDER_NO_UUID_EVIDENCE") -and $snapMatch
  Record-TestResult "T09" "canonical directory created between PLAN/APPLY -> NG / CANONICAL_FOLDER_NO_UUID_EVIDENCE" $pass "Status: $($resp.status), Code: $($resp.code), SnapMatch: $snapMatch" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T09" "canonical directory created between PLAN/APPLY" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T10 — canonical path replaced by regular file between PLAN/APPLY
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonPath = Join-Path $custRoot "株式会社テスト_[11111111]"

  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t10-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  # Replace canonical path with regular file
  [System.IO.File]::WriteAllText($canonPath, "regular occupant", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t10-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapMatch = Compare-Snapshots $snapBefore $snapAfter
  $fileIntact = (Test-Path -LiteralPath $canonPath -PathType Leaf) -and ((Get-Content -LiteralPath $canonPath -Raw) -eq "regular occupant")

  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_CANONICAL_PATH_OCCUPIED") -and $snapMatch -and $fileIntact
  Record-TestResult "T10" "canonical path replaced by regular file -> NG / MERGE_CANONICAL_PATH_OCCUPIED" $pass "Status: $($resp.status), Code: $($resp.code), SnapMatch: $snapMatch, FileIntact: $fileIntact" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "T10" "canonical path replaced by regular file" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T11 — APPLY INSPECTION_FAILED structural integration (AST test)
# ------------------------------------------------------------------------------
try {
  $assignIdx = $applyResolverInfo.AssignIdx
  $varName = $applyResolverInfo.VarName
  $branchStmt = $null
  $branchIdx = -1

  for ($i = $assignIdx + 1; $i -lt $applyMainBlock.Statements.Count; $i++) {
    $stmt = $applyMainBlock.Statements[$i]
    if ($stmt -is [System.Management.Automation.Language.IfStatementAst]) {
      $c0 = $stmt.Clauses[0].Item1.Extent.Text
      if ($c0 -match [regex]::Escape("`$$varName")) {
        $branchStmt = $stmt
        $branchIdx = $i
        break
      }
    }
  }

  $isDirectMember = ($null -ne $branchStmt) -and ([object]::ReferenceEquals($branchStmt.Parent, $applyMainBlock))

  # Find clause with INSPECTION_FAILED
  $inspClause = $null
  if ($null -ne $branchStmt) {
    foreach ($cl in $branchStmt.Clauses) {
      if ($cl.Item1.Extent.Text -match 'INSPECTION_FAILED') {
        $inspClause = $cl
        break
      }
    }
  }

  $clauseValid = $false
  if ($null -ne $inspClause) {
    $body = $inspClause.Item2
    if ($body.Statements.Count -eq 2) {
      $s0 = $body.Statements[0]
      $s1 = $body.Statements[1]
      $isWriteOutput = ($s0 -is [System.Management.Automation.Language.PipelineAst]) -and ($s0.PipelineElements[0].GetCommandName() -eq 'Write-Output')
      $isBareReturn = ($s1 -is [System.Management.Automation.Language.ReturnStatementAst]) -and ($null -eq $s1.Pipeline)
      $hasCode = $s0.Extent.Text -match 'MERGE_TOPOLOGY_ENUMERATION_FAILED'
      $clauseValid = $isWriteOutput -and $isBareReturn -and $hasCode
    }
  }

  # Derive ordering
  $topoErrIdx = -1
  $managedNotesIdx = -1
  $tokenV3Idx = -1
  $txPrepIdx = -1
  for ($i = 0; $i -lt $applyMainBlock.Statements.Count; $i++) {
    $t = $applyMainBlock.Statements[$i].Extent.Text
    if ($t -match '\$null\s*-ne\s*\$topo\.Error') { $topoErrIdx = $i }
    if ($t -match '\$allManagedNotes\s*=\s*@\(\)') { $managedNotesIdx = $i }
    if ($t -match 'New-MergePlanTokenV3') { $tokenV3Idx = $i }
    if ($t -match '\$inProgressData\s*=') { $txPrepIdx = $i }
  }

  $orderingValid = ($topoErrIdx -lt $assignIdx -and
                    $assignIdx -lt $branchIdx -and
                    $branchIdx -lt $managedNotesIdx -and
                    $managedNotesIdx -lt $tokenV3Idx -and
                    $tokenV3Idx -lt $txPrepIdx)

  $pass = $isDirectMember -and ($null -ne $inspClause) -and $clauseValid -and $orderingValid
  Record-TestResult "T11" "APPLY INSPECTION_FAILED structural integration" $pass "DirectMember: $isDirectMember, ClauseValid: $clauseValid, OrderingValid: $orderingValid (topoErr=$topoErrIdx < assign=$assignIdx < branch=$branchIdx < notes=$managedNotesIdx < token=$tokenV3Idx < txPrep=$txPrepIdx)"
} catch {
  Record-TestResult "T11" "APPLY INSPECTION_FAILED structural integration" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T12 — no Token V3 invariant (combined runtime + structural proof)
# ------------------------------------------------------------------------------
try {
  # Runtime half: deterministic NON_DIRECTORY_OCCUPANT
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonPath = Join-Path $custRoot "株式会社テスト_[11111111]"
  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null
  [System.IO.File]::WriteAllText($canonPath, "file occupant", [System.Text.Encoding]::UTF8)

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t12-runtime"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }
  $runtimePass = ($null -ne $applyRes.Response) -and ($applyRes.Response.status -eq "NG") -and ($applyRes.Response.code -eq "MERGE_CANONICAL_PATH_OCCUPIED")

  # Structural half
  $tokenCalls = $funcApply.FindAll({
    param($n)
    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-MergePlanTokenV3'
  }, $true)
  $singleTokenCall = ($tokenCalls.Count -eq 1)

  $allClausesValid = $true
  $states = @('UNOWNED_DIRECTORY', 'NON_DIRECTORY_OCCUPANT', 'INSPECTION_FAILED')
  foreach ($st in $states) {
    $foundCl = $null
    foreach ($cl in $branchStmt.Clauses) {
      if ($cl.Item1.Extent.Text -match $st) {
        $foundCl = $cl; break
      }
    }
    if ($null -eq $foundCl) { $allClausesValid = $false; break }
    $b = $foundCl.Item2
    if ($b.Statements.Count -ne 2) { $allClausesValid = $false; break }
    if (-not ($b.Statements[0] -is [System.Management.Automation.Language.PipelineAst])) { $allClausesValid = $false; break }
    if (-not ($b.Statements[1] -is [System.Management.Automation.Language.ReturnStatementAst] -and $null -eq $b.Statements[1].Pipeline)) { $allClausesValid = $false; break }
  }

  $structPass = $singleTokenCall -and $allClausesValid -and ($branchIdx -lt $tokenV3Idx)

  $pass = $runtimePass -and $structPass
  Record-TestResult "T12" "no Token V3 invariant (runtime + structural)" $pass "RuntimePass: $runtimePass, SingleTokenCall: $singleTokenCall, AllClausesValid: $allClausesValid, BranchPrecedesToken: $($branchIdx -lt $tokenV3Idx)"
} catch {
  Record-TestResult "T12" "no Token V3 invariant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T13 — no transaction preparation invariant
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonPath = Join-Path $custRoot "株式会社テスト_[11111111]"
  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null
  [System.IO.File]::WriteAllText($canonPath, "file occupant", [System.Text.Encoding]::UTF8)

  $reqId = "req-t13-verify-tx"
  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = $reqId
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }

  $txDir = Join-Path $TestRoot ".fm-obsidian-bridge-transactions"
  $txFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*$reqId*" -ErrorAction SilentlyContinue)
  $allInprogress = @(Get-ChildItem -LiteralPath $txDir -Filter "*.inprogress.json" -ErrorAction SilentlyContinue)
  $allJournals = @(Get-ChildItem -LiteralPath $txDir -Filter "*.journal.json" -ErrorAction SilentlyContinue)
  $allStaging = @(Get-ChildItem -LiteralPath $txDir -Directory -Filter "*staging*" -ErrorAction SilentlyContinue)

  $noTxArtifacts = ($txFiles.Count -eq 0) -and ($allInprogress.Count -eq 0) -and ($allJournals.Count -eq 0) -and ($allStaging.Count -eq 0)
  $pass = ($applyRes.Response.status -eq "NG") -and $noTxArtifacts
  Record-TestResult "T13" "no transaction preparation invariant" $pass "NoTxArtifacts: $noTxArtifacts (Inprogress: $($allInprogress.Count), Journal: $($allJournals.Count), Staging: $($allStaging.Count))"
} catch {
  Record-TestResult "T13" "no transaction preparation invariant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T14 — zero customer mutation invariant
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null
  [void][System.IO.Directory]::CreateDirectory($canonDir)
  [System.IO.File]::WriteAllText((Join-Path $canonDir "unowned.txt"), "no evidence", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t14-mutation"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }

  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapEqual = Compare-Snapshots $snapBefore $snapAfter

  $pass = ($applyRes.Response.status -eq "NG") -and $snapEqual
  Record-TestResult "T14" "zero customer mutation invariant" $pass "Status: $($applyRes.Response.status), SnapEqual: $snapEqual"
} catch {
  Record-TestResult "T14" "zero customer mutation invariant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T15 — PLAN MATCHED_EXISTING regression
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"
  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t15-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }

  $resp = $planRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapEqual = Compare-Snapshots $snapBefore $snapAfter
  $hasToken = ($null -ne $resp) -and (-not [string]::IsNullOrWhiteSpace($resp.planToken))

  $pass = ($null -ne $resp) -and ($resp.status -eq "OK") -and ($resp.code -eq "MERGE_PLAN_READY") -and $hasToken -and $snapEqual
  Record-TestResult "T15" "PLAN MATCHED_EXISTING regression -> OK / MERGE_PLAN_READY" $pass "Status: $($resp.status), Code: $($resp.code), HasToken: $hasToken, ZeroMutation: $snapEqual" "Stdout: $($planRes.Stdout)"
} catch {
  Record-TestResult "T15" "PLAN MATCHED_EXISTING regression" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T16 — PLAN ABSENT regression
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t16-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }

  $resp = $planRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapEqual = Compare-Snapshots $snapBefore $snapAfter
  $hasToken = ($null -ne $resp) -and (-not [string]::IsNullOrWhiteSpace($resp.planToken))

  $pass = ($null -ne $resp) -and ($resp.status -eq "OK") -and ($resp.code -eq "MERGE_PLAN_READY") -and $hasToken -and $snapEqual
  Record-TestResult "T16" "PLAN ABSENT regression -> OK / MERGE_PLAN_READY" $pass "Status: $($resp.status), Code: $($resp.code), HasToken: $hasToken, ZeroMutation: $snapEqual" "Stdout: $($planRes.Stdout)"
} catch {
  Record-TestResult "T16" "PLAN ABSENT regression" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# T17 — PLAN new terminal states (Part A runtime + Part B structural)
# ------------------------------------------------------------------------------
try {
  # Part A — Runtime NON_DIRECTORY_OCCUPANT
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonPath = Join-Path $custRoot "株式会社テスト_[11111111]"
  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null
  [System.IO.File]::WriteAllText($canonPath, "regular occupant", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $custRoot

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-t17-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }

  $resp = $planRes.Response
  $snapAfter = Get-RecursiveSnapshot $custRoot
  $snapEqual = Compare-Snapshots $snapBefore $snapAfter
  $hasToken = ($null -ne $resp) -and ($resp.PSObject.Properties.Name -contains 'planToken') -and (-not [string]::IsNullOrWhiteSpace($resp.planToken))
  $noToken = -not $hasToken

  $partAPass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_CANONICAL_PATH_OCCUPIED") -and $noToken -and $snapEqual

  # Part B — Structural INSPECTION_FAILED integration
  $planAssignIdx = $planResolverInfo.AssignIdx
  $planVarName = $planResolverInfo.VarName
  $planBranchStmt = $null
  $planBranchIdx = -1

  for ($i = $planAssignIdx + 1; $i -lt $planMainBlock.Statements.Count; $i++) {
    $stmt = $planMainBlock.Statements[$i]
    if ($stmt -is [System.Management.Automation.Language.IfStatementAst]) {
      $c0 = $stmt.Clauses[0].Item1.Extent.Text
      if ($c0 -match [regex]::Escape("`$$planVarName")) {
        $planBranchStmt = $stmt
        $planBranchIdx = $i
        break
      }
    }
  }

  $isPlanDirectMember = ($null -ne $planBranchStmt) -and ([object]::ReferenceEquals($planBranchStmt.Parent, $planMainBlock))

  $planInspClause = $null
  if ($null -ne $planBranchStmt) {
    foreach ($cl in $planBranchStmt.Clauses) {
      if ($cl.Item1.Extent.Text -match 'INSPECTION_FAILED') {
        $planInspClause = $cl; break
      }
    }
  }

  $planClauseValid = $false
  if ($null -ne $planInspClause) {
    $body = $planInspClause.Item2
    if ($body.Statements.Count -eq 2) {
      $s0 = $body.Statements[0]
      $s1 = $body.Statements[1]
      $isWO = ($s0 -is [System.Management.Automation.Language.PipelineAst]) -and ($s0.PipelineElements[0].GetCommandName() -eq 'Write-Output')
      $isBR = ($s1 -is [System.Management.Automation.Language.ReturnStatementAst]) -and ($null -eq $s1.Pipeline)
      $hasCode = $s0.Extent.Text -match 'MERGE_TOPOLOGY_ENUMERATION_FAILED'
      $planClauseValid = $isWO -and $isBR -and $hasCode
    }
  }

  $planOneFolderIdx = -1
  $planNotesIdx = -1
  for ($i = 0; $i -lt $planMainBlock.Statements.Count; $i++) {
    $t = $planMainBlock.Statements[$i].Extent.Text
    if ($t -match '\$topo\.MatchedFolders\.Count\s*-eq\s*1') { $planOneFolderIdx = $i }
    if ($t -match '\$allManagedNotes\s*=\s*@\(\)') { $planNotesIdx = $i }
  }

  $planOrderingValid = ($planOneFolderIdx -lt $planAssignIdx -and
                        $planAssignIdx -lt $planBranchIdx -and
                        $planBranchIdx -lt $planNotesIdx)

  $partBPass = $isPlanDirectMember -and ($null -ne $planInspClause) -and $planClauseValid -and $planOrderingValid

  $pass = $partAPass -and $partBPass
  Record-TestResult "T17" "PLAN new terminal states (Part A runtime + Part B structural)" $pass "PartAPass: $partAPass, PartBPass: $partBPass (OneFolder=$planOneFolderIdx < assign=$planAssignIdx < branch=$planBranchIdx < notes=$planNotesIdx)" "Plan Stdout: $($planRes.Stdout)"
} catch {
  Record-TestResult "T17" "PLAN new terminal states" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# Summary & Exit
# ------------------------------------------------------------------------------
Write-Host "=====================================================" -ForegroundColor Cyan
$passedCount = ($script:testResults | Where-Object { $_.Passed }).Count
$totalCount = $script:testResults.Count
Write-Host ("J-2 Step 6 Test Results: {0}/{1} PASS" -f $passedCount, $totalCount) -ForegroundColor $(if ($passedCount -eq $totalCount) { "Green" } else { "Red" })
Write-Host "=====================================================" -ForegroundColor Cyan

if ($passedCount -ne $totalCount) {
  exit 1
}
exit 0
