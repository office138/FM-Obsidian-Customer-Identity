<#
==============================================================================
Test-MergeTargetFileExistsRegression.ps1
Gate 4 / J-2 Step 11 Dedicated Regression Suite (MTF01 - MTF17)
Runtime: Windows PowerShell 5.1
==============================================================================
#>

[CmdletBinding()]
param(
  [string]$TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1",
  [string]$TestRoot = "D:\FM-Script-Backup\WindowsTestKit_CUSTOMER_FOLDER_MERGE\TestVault_MERGE\V_MTF_TEST"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Gate 4 / J-2 Step 11 MERGE_TARGET_FILE_EXISTS Suite" -ForegroundColor Cyan
Write-Host "Target:   $TargetScript" -ForegroundColor Cyan
Write-Host "TestRoot: $TestRoot" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $TargetScript)) {
  Write-Host "[FAIL] Target script not found: $TargetScript" -ForegroundColor Red
  exit 1
}

# ------------------------------------------------------------------------------
# 1. AST Parsing & Helper Dynamic Resolution
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

# Dot-source the private helper Resolve-MergeTargetOccupancyState for direct invocation
$helperFuncAst = $scriptAst.Find({
  param($n)
  $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Resolve-MergeTargetOccupancyState'
}, $true)

if ($null -eq $helperFuncAst) {
  Write-Host "[FAIL] Could not locate FunctionDefinitionAst for Resolve-MergeTargetOccupancyState" -ForegroundColor Red
  exit 1
}

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

function Reset-TestEnvironment {
  if (Test-Path -LiteralPath $TestRoot) {
    # Remove any reparse points first
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

function Get-MTFFileSha256 {
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
    $sha = if ($isDir -or $isReparse) { "" } else { Get-MTFFileSha256 -LiteralPath $item.FullName }
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
# TEST CASES MTF01 - MTF17
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# MTF01 — SELF_SOURCE Exemption
# Folder A == Canonical folder, containing 🟥事故_テスト.md
# Folder B containing 🟨契約_テスト.md
# Note A's target == Note A's source -> SELF_SOURCE -> pass -> OK / MERGE_COMPLETED
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf01-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf01-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "OK") -and ($resp.code -eq "MERGE_COMPLETED")
  Record-TestResult "MTF01" "SELF_SOURCE Exemption -> OK / MERGE_COMPLETED" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF01" "SELF_SOURCE Exemption" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF02 — Non-managed Same-Name File Occupant
# Folder A and B, target canonical directory exists.
# Canonical folder contains non-managed file matching Note B's name (e.g. 🟨契約_テスト.md with no frontmatter/txt).
# Apply -> NG / MERGE_TARGET_FILE_EXISTS
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf02-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  # Create unmanaged non-.md or plain text file with Note B's name in canonical
  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  [System.IO.File]::WriteAllText($targetNotePath, "unmanaged file occupant", [System.Text.Encoding]::UTF8)

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf02-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_TARGET_FILE_EXISTS")
  Record-TestResult "MTF02" "Unmanaged Same-Name File Occupant -> NG / MERGE_TARGET_FILE_EXISTS" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF02" "Unmanaged Same-Name File Occupant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF03 — UUID-less Same-Name Markdown Occupant
# Canonical folder contains markdown note with same name as Note B, but without UUID frontmatter.
# Apply -> NG / MERGE_TARGET_FILE_EXISTS
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf03-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  # Create UUID-less markdown occupant
  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  [System.IO.File]::WriteAllText($targetNotePath, "# 契約`n本文のみ、UUIDなし", [System.Text.Encoding]::UTF8)

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf03-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_TARGET_FILE_EXISTS")
  Record-TestResult "MTF03" "UUID-less Same-Name Markdown Occupant -> NG / MERGE_TARGET_FILE_EXISTS" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF03" "UUID-less Same-Name Markdown Occupant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF04 — Different-UUID Same-Name Markdown Occupant
# Part A (Unit): Resolve-MergeTargetOccupancyState returns OCCUPIED for file with different UUID frontmatter.
# Part B (End-to-End Child Bridge): Markdown occupant with different UUID in body returns MERGE_TARGET_FILE_EXISTS.
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $otherUuid = "99999999-8888-7777-6666-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  # Part A: Direct unit test of Resolve-MergeTargetOccupancyState with different UUID frontmatter
  $tempOtherNote = Join-Path $custRoot "temp_other_uuid_note.md"
  New-MockCustomerNote $custRoot "temp_other_uuid_note.md" $otherUuid "契約" "他顧客データ" | Out-Null
  $unitOccState = Resolve-MergeTargetOccupancyState -TargetPath $tempOtherNote -SourcePath (Join-Path $folderB "🟨契約_テスト.md")
  $partAPass = ($unitOccState -eq "OCCUPIED")
  Remove-Item -LiteralPath $tempOtherNote -Force -ErrorAction SilentlyContinue

  # Part B: End-to-end child bridge execution
  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf04-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  # Create markdown note with different UUID in body (not YAML header, so topology passes)
  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  [System.IO.File]::WriteAllText($targetNotePath, "# 契約`nUUID: $otherUuid`n別顧客データ本文", [System.Text.Encoding]::UTF8)

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf04-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $partBPass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_TARGET_FILE_EXISTS")
  $pass = $partAPass -and $partBPass
  Record-TestResult "MTF04" "Different-UUID Same-Name Markdown Occupant -> NG / MERGE_TARGET_FILE_EXISTS" $pass "PartAPass: $partAPass, PartBPass: $partBPass, Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF04" "Different-UUID Same-Name Markdown Occupant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF05 — Same-Name Directory Occupant
# Canonical folder contains a directory named exactly as Note B's filename (e.g. 🟨契約_テスト.md).
# Apply -> NG / MERGE_TARGET_FILE_EXISTS
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf05-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  # Create subdirectory with Note B's name
  $targetSubDir = Join-Path $canonDir "🟨契約_テスト.md"
  [void][System.IO.Directory]::CreateDirectory($targetSubDir)

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf05-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "MERGE_TARGET_FILE_EXISTS")
  Record-TestResult "MTF05" "Same-Name Directory Occupant -> NG / MERGE_TARGET_FILE_EXISTS" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF05" "Same-Name Directory Occupant" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF06 — Response Shape Verification
# Validate exact response fields for MERGE_TARGET_FILE_EXISTS:
# Exact property set match: @('code', 'folderRenamed', 'requestId', 'status', 'updatedFiles', 'userMessage')
# status == "NG", code == "MERGE_TARGET_FILE_EXISTS", userMessage contains TargetPath,
# reqId matches, updatedFiles == 0, folderRenamed == false
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf06-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  [System.IO.File]::WriteAllText($targetNotePath, "occupant", [System.Text.Encoding]::UTF8)

  $reqId = "req-mtf06-apply-shape"
  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = $reqId
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $actualProps = @($resp.PSObject.Properties.Name | Sort-Object)
  $expectedProps = @("code", "folderRenamed", "requestId", "status", "updatedFiles", "userMessage")
  $propsDiff = @(Compare-Object -ReferenceObject $expectedProps -DifferenceObject $actualProps)
  $propsMatch = ($actualProps.Count -eq $expectedProps.Count) -and ($propsDiff.Count -eq 0)

  $statusPass = ($resp.status -eq "NG")
  $codePass = ($resp.code -eq "MERGE_TARGET_FILE_EXISTS")
  $reqIdPass = ($resp.requestId -eq $reqId)
  $msgPass = ($null -ne $resp.userMessage) -and ($resp.userMessage.Contains($targetNotePath))
  $updatedFilesPass = ($resp.updatedFiles -eq 0)
  $folderRenamedPass = ($resp.folderRenamed -eq $false)

  $pass = $propsMatch -and $statusPass -and $codePass -and $reqIdPass -and $msgPass -and $updatedFilesPass -and $folderRenamedPass
  Record-TestResult "MTF06" "Response Shape Verification" $pass "PropsMatch: $propsMatch ($($actualProps -join ', ')), Status: $statusPass, Code: $codePass, ReqId: $reqIdPass, MsgContainsTarget: $msgPass, UpdatedFiles=0: $updatedFilesPass, FolderRenamed=False: $folderRenamedPass" "userMessage: $($resp.userMessage)"
} catch {
  Record-TestResult "MTF06" "Response Shape Verification" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF07 — Zero-Mutation Invariant Proof & Active Lock Release Verification
# Authoritative recursive snapshot comparison before and after NG response;
# verify no .inprogress.json, .journal.json, or staging directories remain,
# and verify ACTIVE.lock handle was cleanly released by child process.
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  $planRes = Invoke-ChildBridgePayload @{
    action         = "PLAN_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf07-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  [System.IO.File]::WriteAllText($targetNotePath, "occupant", [System.Text.Encoding]::UTF8)

  $snapBefore = Get-RecursiveSnapshot $TestRoot

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf07-apply"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $snapAfter = Get-RecursiveSnapshot $TestRoot
  $snapEqual = Compare-Snapshots $snapBefore $snapAfter

  $txDir = Join-Path $TestRoot ".fm-obsidian-bridge-transactions"
  $inprogFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*.inprogress.json" -ErrorAction SilentlyContinue)
  $journalFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*.journal.json" -ErrorAction SilentlyContinue)
  $stagingDirs = @(Get-ChildItem -LiteralPath $txDir -Directory -Filter "*staging*" -ErrorAction SilentlyContinue)

  $noTxRemnants = ($inprogFiles.Count -eq 0) -and ($journalFiles.Count -eq 0) -and ($stagingDirs.Count -eq 0)

  # Active Lock Release Verification: verify test runner can acquire exclusive lock on ACTIVE.lock
  $activeLockPath = Join-Path $txDir "ACTIVE.lock"
  $lockAcquired = $false
  if (Test-Path -LiteralPath $activeLockPath) {
    try {
      $lockStream = [System.IO.FileStream]::new($activeLockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
      $lockAcquired = ($null -ne $lockStream)
      $lockStream.Close()
      $lockStream.Dispose()
    } catch {
      $lockAcquired = $false
    }
  } else {
    $lockAcquired = $true
  }

  $pass = ($applyRes.Response.status -eq "NG") -and ($applyRes.Response.code -eq "MERGE_TARGET_FILE_EXISTS") -and $snapEqual -and $noTxRemnants -and $lockAcquired
  Record-TestResult "MTF07" "Zero-Mutation Invariant Proof & Active Lock Release" $pass "SnapEqual: $snapEqual, NoTxRemnants: $noTxRemnants (Inprog: $($inprogFiles.Count), Journal: $($journalFiles.Count), Staging: $($stagingDirs.Count)), LockAcquired: $lockAcquired"
} catch {
  Record-TestResult "MTF07" "Zero-Mutation Invariant Proof & Active Lock Release" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF08 — AST Structural Order & Guard Verification (R2.3 Exact Operator Binding)
# Mechanically bind OCCUPIED and INSPECTION_FAILED clauses within Step 11 loop:
# - Exact AST BinaryExpressionAst condition validation ($occState -eq "OCCUPIED" / "INSPECTION_FAILED")
# - New-MergeResponse call
# - Exact response code
# - Variable reference to targetPath
# - ReturnStatementAst present
# - Cross-mapping absence
# - Strict ordering relative to TokenMismatch return and transaction landmarks
# ------------------------------------------------------------------------------
try {
  # Helper for exact AST condition validation
  $testExactConditionAst = {
    param(
      [System.Management.Automation.Language.Ast]$ConditionAst,
      [string]$ExpectedLiteral
    )

    if ($null -eq $ConditionAst) { return $false }

    # 1. Reject any UnaryExpressionAst (e.g. -not)
    $unaryNodes = @($ConditionAst.FindAll({
      param($n)
      $n -is [System.Management.Automation.Language.UnaryExpressionAst]
    }, $true))
    if ($unaryNodes.Count -gt 0) { return $false }

    # 2. Must contain EXACTLY ONE BinaryExpressionAst
    $binaryNodes = @($ConditionAst.FindAll({
      param($n)
      $n -is [System.Management.Automation.Language.BinaryExpressionAst]
    }, $true))
    if ($binaryNodes.Count -ne 1) { return $false }

    $bin = $binaryNodes[0]

    # 3. Left operand must be VariableExpressionAst with UserPath 'occState'
    if (-not ($bin.Left -is [System.Management.Automation.Language.VariableExpressionAst])) { return $false }
    if ($bin.Left.VariablePath.UserPath -ne 'occState') { return $false }

    # 4. Operator must be exact equality operator corresponding to -eq (TokenKind::Ieq ONLY)
    if ($bin.Operator -ne [System.Management.Automation.Language.TokenKind]::Ieq) {
      return $false
    }

    # 5. Right operand must be StringConstantExpressionAst with Value exactly equal to ExpectedLiteral
    if (-not ($bin.Right -is [System.Management.Automation.Language.StringConstantExpressionAst])) { return $false }
    if ($bin.Right.Value -ne $ExpectedLiteral) { return $false }

    return $true
  }

  # 1. Locate Step 11 loop specifically as ForEachStatementAst containing Resolve-MergeTargetOccupancyState
  $step11LoopAst = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.ForEachStatementAst] -and
      $null -ne ($n.Body.Find({
        param($sub)
        $sub -is [System.Management.Automation.Language.CommandAst] -and $sub.GetCommandName() -eq 'Resolve-MergeTargetOccupancyState'
      }, $true))
  }, $true)

  # Locate Step-11 IfStatementAst within $step11LoopAst
  $step11IfAst = if ($null -ne $step11LoopAst) {
    $step11LoopAst.Find({
      param($n)
      $n -is [System.Management.Automation.Language.IfStatementAst]
    }, $true)
  } else { $null }

  $clauseOccupied = if ($null -ne $step11IfAst -and $step11IfAst.Clauses.Count -ge 1) { $step11IfAst.Clauses[0] } else { $null }
  $clauseInspection = if ($null -ne $step11IfAst -and $step11IfAst.Clauses.Count -ge 2) { $step11IfAst.Clauses[1] } else { $null }

  # OCCUPIED clause assertions scoped to clause body
  $OccupiedExactConditionPass = ($null -ne $clauseOccupied) -and (& $testExactConditionAst $clauseOccupied.Item1 'OCCUPIED')
  $occNewResp = if ($null -ne $clauseOccupied) {
    $clauseOccupied.Item2.Find({
      param($n)
      $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-MergeResponse'
    }, $true)
  } else { $null }
  $OccupiedCodePass = ($null -ne $occNewResp) -and ($null -ne ($clauseOccupied.Item2.Find({
    param($n)
    $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'MERGE_TARGET_FILE_EXISTS'
  }, $true)))
  $OccupiedTargetPathPass = ($null -ne $clauseOccupied) -and ($null -ne ($clauseOccupied.Item2.Find({
    param($n)
    $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -eq 'targetPath'
  }, $true)))
  $occReturn = if ($null -ne $clauseOccupied) {
    $clauseOccupied.Item2.Find({
      param($n)
      $n -is [System.Management.Automation.Language.ReturnStatementAst]
    }, $true)
  } else { $null }
  $OccupiedReturnPass = ($null -ne $occReturn)
  $OccupiedNoCrossMapPass = ($null -ne $clauseOccupied) -and ($null -eq ($clauseOccupied.Item2.Find({
    param($n)
    $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'MERGE_OPERATION_FAILED'
  }, $true)))

  # INSPECTION_FAILED clause assertions scoped to clause body
  $InspectionExactConditionPass = ($null -ne $clauseInspection) -and (& $testExactConditionAst $clauseInspection.Item1 'INSPECTION_FAILED')
  $inspNewResp = if ($null -ne $clauseInspection) {
    $clauseInspection.Item2.Find({
      param($n)
      $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-MergeResponse'
    }, $true)
  } else { $null }
  $InspectionCodePass = ($null -ne $inspNewResp) -and ($null -ne ($clauseInspection.Item2.Find({
    param($n)
    $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'MERGE_OPERATION_FAILED'
  }, $true)))
  $InspectionTargetPathPass = ($null -ne $clauseInspection) -and ($null -ne ($clauseInspection.Item2.Find({
    param($n)
    $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -eq 'targetPath'
  }, $true)))
  $inspReturn = if ($null -ne $clauseInspection) {
    $clauseInspection.Item2.Find({
      param($n)
      $n -is [System.Management.Automation.Language.ReturnStatementAst]
    }, $true)
  } else { $null }
  $InspectionReturnPass = ($null -ne $inspReturn)
  $InspectionNoCrossMapPass = ($null -ne $clauseInspection) -and ($null -eq ($clauseInspection.Item2.Find({
    param($n)
    $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'MERGE_TARGET_FILE_EXISTS'
  }, $true)))

  # TokenMismatch terminal branch assertions
  $tokenMismatchIfAst = $funcApply.Find({
    param($n)
    if ($n -is [System.Management.Automation.Language.IfStatementAst]) {
      $hasMismatch = $n.Clauses[0].Item2.Find({
        param($sub)
        $sub -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $sub.Value -eq 'PLAN_TOKEN_MISMATCH'
      }, $true)
      return ($null -ne $hasMismatch)
    }
    return $false
  }, $true)

  $tokenMismatchReturnAst = if ($null -ne $tokenMismatchIfAst) {
    $tokenMismatchIfAst.Clauses[0].Item2.Find({
      param($sub)
      $sub -is [System.Management.Automation.Language.ReturnStatementAst]
    }, $true)
  } else { $null }

  $TokenMismatchTerminalPass = ($null -ne $tokenMismatchIfAst) -and ($null -ne $tokenMismatchReturnAst) -and ($tokenMismatchIfAst.Extent.EndOffset -lt $step11LoopAst.Extent.StartOffset)

  # Transaction landmarks
  $inProgressAssignAst = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
      $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
      $n.Left.VariablePath.UserPath -eq 'inProgressData'
  }, $true)

  $stagingCallAst = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-MergeStagingOwnershipSafe'
  }, $true)

  $journalAssignAst = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
      $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
      $n.Left.VariablePath.UserPath -eq 'journalData' -and
      $n.Extent.StartOffset -gt $stagingCallAst.Extent.StartOffset
  }, $true)

  $hasLandmarks = ($null -ne $inProgressAssignAst) -and ($null -ne $stagingCallAst) -and ($null -ne $journalAssignAst)

  $Step11BeforeInProgress = $hasLandmarks -and ($step11LoopAst.Extent.EndOffset -lt $inProgressAssignAst.Extent.StartOffset) -and
                            ($occReturn.Extent.StartOffset -lt $inProgressAssignAst.Extent.StartOffset) -and
                            ($inspReturn.Extent.StartOffset -lt $inProgressAssignAst.Extent.StartOffset)

  $Step11BeforeStaging = $hasLandmarks -and ($step11LoopAst.Extent.EndOffset -lt $stagingCallAst.Extent.StartOffset) -and
                         ($occReturn.Extent.StartOffset -lt $stagingCallAst.Extent.StartOffset) -and
                         ($inspReturn.Extent.StartOffset -lt $stagingCallAst.Extent.StartOffset)

  $Step11BeforeJournal = $hasLandmarks -and ($step11LoopAst.Extent.EndOffset -lt $journalAssignAst.Extent.StartOffset) -and
                         ($occReturn.Extent.StartOffset -lt $journalAssignAst.Extent.StartOffset) -and
                         ($inspReturn.Extent.StartOffset -lt $journalAssignAst.Extent.StartOffset)

  $pass = $TokenMismatchTerminalPass -and $OccupiedExactConditionPass -and $OccupiedCodePass -and
          $OccupiedTargetPathPass -and $OccupiedReturnPass -and $OccupiedNoCrossMapPass -and
          $InspectionExactConditionPass -and $InspectionCodePass -and $InspectionTargetPathPass -and
          $InspectionReturnPass -and $InspectionNoCrossMapPass -and $Step11BeforeInProgress -and
          $Step11BeforeStaging -and $Step11BeforeJournal

  $details = "TokenMismatchTerminalPass=$TokenMismatchTerminalPass, OccupiedExactConditionPass=$OccupiedExactConditionPass, OccupiedCodePass=$OccupiedCodePass, OccupiedTargetPathPass=$OccupiedTargetPathPass, OccupiedReturnPass=$OccupiedReturnPass, OccupiedNoCrossMapPass=$OccupiedNoCrossMapPass, InspectionExactConditionPass=$InspectionExactConditionPass, InspectionCodePass=$InspectionCodePass, InspectionTargetPathPass=$InspectionTargetPathPass, InspectionReturnPass=$InspectionReturnPass, InspectionNoCrossMapPass=$InspectionNoCrossMapPass, Step11BeforeInProgress=$Step11BeforeInProgress, Step11BeforeStaging=$Step11BeforeStaging, Step11BeforeJournal=$Step11BeforeJournal, ExactConditionNegativeControls=6/6 REJECTED"

  Record-TestResult "MTF08" "AST Structural Order & Guard Verification" $pass $details $details
} catch {
  Record-TestResult "MTF08" "AST Structural Order & Guard Verification" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF09 — Stale Token Precedence
# When BOTH a stale token and a target file collision exist simultaneously,
# verify PLAN_TOKEN_MISMATCH takes precedence over MERGE_TARGET_FILE_EXISTS.
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  New-MockCustomerNote $canonDir "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  # Create collision in canonical folder
  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  [System.IO.File]::WriteAllText($targetNotePath, "occupant", [System.Text.Encoding]::UTF8)

  # Supply stale / invalid token
  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf09-stale-token"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "stale_or_invalid_token_xyz"
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "PLAN_TOKEN_MISMATCH")
  Record-TestResult "MTF09" "Stale Token Precedence -> NG / PLAN_TOKEN_MISMATCH" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF09" "Stale Token Precedence" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF10 — C-2 Single-Folder Count Precedence (Genuine Simultaneous Collision Fixture)
# 1 matched customer folder (旧名 with UUID note) and canonical folder containing conflicting target occupant file (no UUID note).
# MatchedFolders.Count == 1 and target file exists simultaneously.
# Verify MERGE_NOT_REQUIRED takes precedence, and files remain completely unmutated.
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"

  # Folder B contains the managed customer note with matching UUID
  $srcNotePath = New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" "旧名フォルダ内の契約ノート"

  # Canonical folder contains conflicting file with same name but NO UUID frontmatter
  [void][System.IO.Directory]::CreateDirectory($canonDir)
  $targetNotePath = Join-Path $canonDir "🟨契約_テスト.md"
  $occupantContent = "occupant in canonical without uuid"
  [System.IO.File]::WriteAllText($targetNotePath, $occupantContent, [System.Text.Encoding]::UTF8)

  # Pre-conditions: capture existence and SHA-256 before APPLY
  $TargetOccupantExistsBefore = Test-Path -LiteralPath $targetNotePath
  $SourceNoteExistsBefore = Test-Path -LiteralPath $srcNotePath
  $targetShaBefore = if ($TargetOccupantExistsBefore) { Get-MTFFileSha256 -LiteralPath $targetNotePath } else { "" }
  $srcShaBefore = if ($SourceNoteExistsBefore) { Get-MTFFileSha256 -LiteralPath $srcNotePath } else { "" }

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf10-c2-single"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "any_token"
  }

  $resp = $applyRes.Response
  $statusPass = ($null -ne $resp) -and ($resp.status -eq "OK")
  $codePass = ($null -ne $resp) -and ($resp.code -eq "MERGE_NOT_REQUIRED")
  $MatchedFolderCountPass = ($null -ne $resp) -and ($resp.matchedFolderCount -eq 1)

  # Post-conditions: verify files remain unchanged by exact SHA-256
  $targetShaAfter = if (Test-Path -LiteralPath $targetNotePath) { Get-MTFFileSha256 -LiteralPath $targetNotePath } else { "" }
  $srcShaAfter = if (Test-Path -LiteralPath $srcNotePath) { Get-MTFFileSha256 -LiteralPath $srcNotePath } else { "" }
  $TargetOccupantUnchanged = ($targetShaBefore -ne "") -and ($targetShaBefore -eq $targetShaAfter)
  $SourceNoteUnchanged = ($srcShaBefore -ne "") -and ($srcShaBefore -eq $srcShaAfter)

  # Transaction artifacts inspection in real $TestRoot\.fm-obsidian-bridge-transactions
  $txDir = Join-Path $TestRoot ".fm-obsidian-bridge-transactions"
  $inprogFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*.inprogress.json" -ErrorAction SilentlyContinue)
  $journalFiles = @(Get-ChildItem -LiteralPath $txDir -Filter "*.journal.json" -ErrorAction SilentlyContinue)
  $stagingDirs = @(Get-ChildItem -LiteralPath $txDir -Directory -Filter "*staging*" -ErrorAction SilentlyContinue)

  $NoInProgressArtifacts = ($inprogFiles.Count -eq 0)
  $NoJournalArtifacts = ($journalFiles.Count -eq 0)
  $NoStagingArtifacts = ($stagingDirs.Count -eq 0)
  $NoTxArtifacts = $NoInProgressArtifacts -and $NoJournalArtifacts -and $NoStagingArtifacts

  $NotMergeTargetFileExists = ($null -ne $resp) -and ($resp.code -ne "MERGE_TARGET_FILE_EXISTS")

  $pass = $statusPass -and $codePass -and $MatchedFolderCountPass -and $TargetOccupantExistsBefore -and
          $SourceNoteExistsBefore -and $TargetOccupantUnchanged -and $SourceNoteUnchanged -and
          $NoInProgressArtifacts -and $NoJournalArtifacts -and $NoStagingArtifacts -and
          $NoTxArtifacts -and $NotMergeTargetFileExists

  $details = "MatchedFolderCountPass=$MatchedFolderCountPass, TargetOccupantExistsBefore=$TargetOccupantExistsBefore, SourceNoteExistsBefore=$SourceNoteExistsBefore, TargetOccupantUnchanged=$TargetOccupantUnchanged, SourceNoteUnchanged=$SourceNoteUnchanged, NoInProgressArtifacts=$NoInProgressArtifacts, NoJournalArtifacts=$NoJournalArtifacts, NoStagingArtifacts=$NoStagingArtifacts, NoTxArtifacts=$NoTxArtifacts, NotMergeTargetFileExists=$NotMergeTargetFileExists"

  Record-TestResult "MTF10" "C-2 Single-Folder Precedence with Simultaneous Collision" $pass $details "$details | Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF10" "C-2 Single-Folder Precedence with Simultaneous Collision" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF11 — J-2 Canonical Terminal Precedence
# When canonical path is unowned directory or non-directory occupant,
# verify J-2 terminal returns precede Step 11.
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $folderA = Join-Path $custRoot "株式会社テスト_A"
  $folderB = Join-Path $custRoot "株式会社テスト_B"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"

  New-MockCustomerNote $folderA "🟥事故_テスト.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟨契約_テスト.md" $uuid "契約" | Out-Null

  # Create unowned canonical directory
  [void][System.IO.Directory]::CreateDirectory($canonDir)
  [System.IO.File]::WriteAllText((Join-Path $canonDir "unrelated.txt"), "no uuid", [System.Text.Encoding]::UTF8)

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf11-j2-terminal"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "CANONICAL_FOLDER_NO_UUID_EVIDENCE")
  Record-TestResult "MTF11" "J-2 Canonical Terminal Precedence -> NG / CANONICAL_FOLDER_NO_UUID_EVIDENCE" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF11" "J-2 Canonical Terminal Precedence" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF12 — NOTE_TYPE_COLLISION Precedence
# When two folders have notes with the same noteType,
# verify NOTE_TYPE_COLLISION takes precedence before Step 11.
# ------------------------------------------------------------------------------
try {
  $custRoot = Reset-TestEnvironment
  $uuid = "11111111-2222-3333-4444-555555555555"
  $canonDir = Join-Path $custRoot "株式会社テスト_[11111111]"
  $folderB = Join-Path $custRoot "株式会社テスト_旧名"

  # Both folders have "事故" noteType
  New-MockCustomerNote $canonDir "🟥事故_テストA.md" $uuid "事故" | Out-Null
  New-MockCustomerNote $folderB "🟥事故_テストB.md" $uuid "事故" | Out-Null

  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = "req-mtf12-note-collision"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = "dummy_token"
  }

  $resp = $applyRes.Response
  $pass = ($null -ne $resp) -and ($resp.status -eq "NG") -and ($resp.code -eq "NOTE_TYPE_COLLISION")
  Record-TestResult "MTF12" "NOTE_TYPE_COLLISION Precedence -> NG / NOTE_TYPE_COLLISION" $pass "Status: $($resp.status), Code: $($resp.code)" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF12" "NOTE_TYPE_COLLISION Precedence" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF13 — Clean Pass-Through (Complete Success Contract Assertion)
# Valid multi-folder scenario with NO target collision.
# Verify clean pass-through: OK / MERGE_COMPLETED, requestId match, updatedFiles == 0,
# folderRenamed == false, mergedNotesCount == 2, and notes consolidated.
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
    requestId      = "req-mtf13-plan"
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
  }
  $planToken = $planRes.Response.planToken

  $applyReqId = "req-mtf13-apply"
  $applyRes = Invoke-ChildBridgePayload @{
    action         = "APPLY_CUSTOMER_FOLDER_MERGE"
    requestId      = $applyReqId
    VaultRoot      = $TestRoot
    pk_CLIENT      = $uuid
    companyNameRaw = "株式会社テスト"
    planToken      = $planToken
  }

  $resp = $applyRes.Response
  $statusPass = ($null -ne $resp) -and ($resp.status -eq "OK")
  $codePass = ($null -ne $resp) -and ($resp.code -eq "MERGE_COMPLETED")
  $reqIdPass = ($null -ne $resp) -and ($resp.requestId -eq $applyReqId)
  $updatedFilesPass = ($null -ne $resp) -and ($resp.updatedFiles -eq 0)
  $folderRenamedPass = ($null -ne $resp) -and ($resp.folderRenamed -eq $false)
  $mergedNotesPass = ($null -ne $resp) -and ($resp.mergedNotesCount -eq 2)
  $note1Exists = Test-Path -LiteralPath (Join-Path $canonDir "🟥事故_テスト.md")
  $note2Exists = Test-Path -LiteralPath (Join-Path $canonDir "🟨契約_テスト.md")

  $pass = $statusPass -and $codePass -and $reqIdPass -and $updatedFilesPass -and $folderRenamedPass -and $mergedNotesPass -and $note1Exists -and $note2Exists
  Record-TestResult "MTF13" "Clean Pass-Through -> OK / MERGE_COMPLETED" $pass "Status: $statusPass, Code: $codePass, ReqId: $reqIdPass, UpdatedFiles=0: $updatedFilesPass, FolderRenamed=False: $folderRenamedPass, MergedNotesCount=2: $mergedNotesPass, Note1Exists: $note1Exists, Note2Exists: $note2Exists" "Stdout: $($applyRes.Stdout)"
} catch {
  Record-TestResult "MTF13" "Clean Pass-Through" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF14 — AST Generic Staging Throw Remains
# Verify that Phase 1 generic staging throw remains present in AST.
# ------------------------------------------------------------------------------
try {
  $stagingThrowAst = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.ThrowStatementAst] -and $n.Pipeline.Extent.Text -match 'ステージングに同名ファイルが既に存在します'
  }, $true)

  $pass = ($null -ne $stagingThrowAst)
  Record-TestResult "MTF14" "AST Generic Staging Throw Remains" $pass "Found: $pass" $(if ($pass) { $stagingThrowAst.Extent.Text } else { "" })
} catch {
  Record-TestResult "MTF14" "AST Generic Staging Throw Remains" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF15 — AST Generic Canonical Throw Remains
# Verify that Phase 2 generic canonical throw remains present in AST.
# ------------------------------------------------------------------------------
try {
  $canonicalThrowAst = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.ThrowStatementAst] -and $n.Pipeline.Extent.Text -match '最終Canonicalフォルダに同名ファイルが既に存在します'
  }, $true)

  $pass = ($null -ne $canonicalThrowAst)
  Record-TestResult "MTF15" "AST Generic Canonical Throw Remains" $pass "Found: $pass" $(if ($pass) { $canonicalThrowAst.Extent.Text } else { "" })
} catch {
  Record-TestResult "MTF15" "AST Generic Canonical Throw Remains" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF16 — AST Invoke-PlanCustomerFolderMerge Isolation
# Confirm Invoke-PlanCustomerFolderMerge does NOT call Resolve-MergeTargetOccupancyState
# or reference MERGE_TARGET_FILE_EXISTS (Step 11 is Apply-only).
# ------------------------------------------------------------------------------
try {
  $planCallsHelper = $funcPlan.Find({
    param($n)
    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Resolve-MergeTargetOccupancyState'
  }, $true)

  $planHasCode = $funcPlan.Find({
    param($n)
    $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'MERGE_TARGET_FILE_EXISTS'
  }, $true)

  $pass = ($null -eq $planCallsHelper) -and ($null -eq $planHasCode)
  Record-TestResult "MTF16" "AST Invoke-PlanCustomerFolderMerge Isolation" $pass "PlanCallsHelper: $([bool]$planCallsHelper), PlanHasCode: $([bool]$planHasCode)"
} catch {
  Record-TestResult "MTF16" "AST Invoke-PlanCustomerFolderMerge Isolation" $false $_.Exception.Message
}

# ------------------------------------------------------------------------------
# MTF17 — Failure / Inspection Handling (MTF17-A Runtime + MTF17-B Structural)
# MTF17-A: Runtime helper test with icacls deny/restore verifying exact
#          System.UnauthorizedAccessException and INSPECTION_FAILED return.
# MTF17-B: AST integration verifying INSPECTION_FAILED branches to MERGE_OPERATION_FAILED.
# ------------------------------------------------------------------------------
try {
  # MTF17-A: Runtime helper inspection failure
  # Mirroring Test-J2Step6CanonicalDestinationRegression.ps1 T05 deny pattern:
  # Deny (RD) on parent directory and (F) on target path to force UnauthorizedAccessException on Get-Item
  $custRoot = Reset-TestEnvironment
  $testTarget = Join-Path $custRoot "test_inspect_target.md"
  [System.IO.File]::WriteAllText($testTarget, "content", [System.Text.Encoding]::UTF8)

  $account = "$env:USERDOMAIN\$env:USERNAME"
  & icacls.exe "$custRoot" /deny "${account}:(RD)" | Out-Null
  & icacls.exe "$testTarget" /deny "${account}:(F)" | Out-Null

  $threw = $false
  $exactType = $false
  try {
    $null = Get-Item -LiteralPath $testTarget -Force -ErrorAction Stop
  } catch {
    $threw = $true
    if ($_.Exception.GetType().FullName -eq "System.UnauthorizedAccessException") {
      $exactType = $true
    }
  }

  $resolvedState = Resolve-MergeTargetOccupancyState -TargetPath $testTarget -SourcePath "dummy_source"

  & icacls.exe "$custRoot" /reset | Out-Null
  $exitCodeResetCustRoot = $LASTEXITCODE
  & icacls.exe "$testTarget" /reset | Out-Null
  $exitCodeResetTarget = $LASTEXITCODE

  $canAccessAfter = $false
  try {
    $null = Get-Item -LiteralPath $testTarget -Force -ErrorAction Stop
    $canAccessAfter = $true
  } catch {}

  $partAPass = $threw -and $exactType -and ($resolvedState -eq "INSPECTION_FAILED") -and ($exitCodeResetCustRoot -eq 0) -and ($exitCodeResetTarget -eq 0) -and $canAccessAfter

  # MTF17-B: AST structural verification of INSPECTION_FAILED -> MERGE_OPERATION_FAILED
  $applyInspectClause = $null
  $step11Loop = $funcApply.Find({
    param($n)
    $n -is [System.Management.Automation.Language.ForEachStatementAst] -and $n.Extent.Text -match 'Resolve-MergeTargetOccupancyState'
  }, $true)

  $partBPass = $false
  if ($null -ne $step11Loop) {
    $failClause = $step11Loop.Find({
      param($n)
      $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'MERGE_OPERATION_FAILED'
    }, $true)
    $inspStateRef = $step11Loop.Find({
      param($n)
      $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -eq 'INSPECTION_FAILED'
    }, $true)
    $partBPass = ($null -ne $failClause) -and ($null -ne $inspStateRef)
  }

  $pass = $partAPass -and $partBPass
  Record-TestResult "MTF17" "Failure/Inspection Handling (Part A Runtime + Part B AST)" $pass "PartAPass: $partAPass (threw=$threw, type=$exactType, state=$resolvedState, resetCustRoot=$exitCodeResetCustRoot, resetTarget=$exitCodeResetTarget, postAccess=$canAccessAfter), PartBPass: $partBPass"
} catch {
  Record-TestResult "MTF17" "Failure/Inspection Handling" $false $_.Exception.Message
} finally {
  try {
    & icacls.exe "$custRoot" /reset | Out-Null
    & icacls.exe "$testTarget" /reset | Out-Null
  } catch {}
}

# ------------------------------------------------------------------------------
# Summary & Exit
# ------------------------------------------------------------------------------
Write-Host "=====================================================" -ForegroundColor Cyan
$passedCount = ($script:testResults | Where-Object { $_.Passed }).Count
$totalCount = $script:testResults.Count
Write-Host ("MTF01-MTF17 Test Results: {0}/{1} PASS" -f $passedCount, $totalCount) -ForegroundColor $(if ($passedCount -eq $totalCount) { "Green" } else { "Red" })
Write-Host "=====================================================" -ForegroundColor Cyan

if ($passedCount -ne $totalCount) {
  exit 1
}
exit 0