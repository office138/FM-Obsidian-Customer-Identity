# =============================================================================
# Test-CurrentBaseline.ps1
# Read-Only Fail-Closed Baseline Guard for FM-Obsidian-Bridge
# =============================================================================

[CmdletBinding()]
param(
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-BaselineGuard {
    param(
        [Parameter(Mandatory = $true)][string]$Code,
        [Parameter(Mandatory = $true)][string]$Details
    )

    if (-not $Quiet) {
        Write-Output "FAIL_BASELINE_GUARD: $Code - $Details"
    }
    exit 1
}

function Invoke-GitCommand {
    param(
        [string]$RepoRoot,
        [string[]]$Arguments
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.WorkingDirectory = $RepoRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $argList = New-Object System.Collections.Generic.List[string]
    foreach ($arg in $Arguments) {
        if ($arg -match '[\s"]') {
            $argList.Add('"' + ($arg -replace '"', '"') + '"')
        } else {
            $argList.Add($arg)
        }
    }
    $psi.Arguments = ($argList -join ' ')

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    $exitCode = $proc.ExitCode
    $proc.Dispose()

    $list = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        $lines = $stdout -split "?
"
        foreach ($line in $lines) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                $list.Add($line.Trim())
            }
        }
    }

    return @{
        Output   = $list
        ExitCode = $exitCode
        StdErr   = $stderr
    }
}


# -----------------------------------------------------------------------------
# 1. Resolve Repository Root
# -----------------------------------------------------------------------------
$startDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$repoRoot = $null

try {
    $gitRoot = & git -C $startDir rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        $repoRoot = [System.IO.Path]::GetFullPath(($gitRoot.Trim()))
    }
} catch {}

if (-not $repoRoot) {
    $curr = [System.IO.Path]::GetFullPath($startDir)
    while ($true) {
        if (Test-Path -LiteralPath (Join-Path $curr '.git')) {
            $repoRoot = $curr
            break
        }
        $parent = [System.IO.Path]::GetDirectoryName($curr)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $curr) { break }
        $curr = $parent
    }
}

if (-not $repoRoot) {
    $repoRoot = [System.IO.Path]::GetFullPath($startDir)
}

# -----------------------------------------------------------------------------
# 2. Validate Baseline JSON Existence & Schema
# -----------------------------------------------------------------------------
$baselineJsonPath = Join-Path $repoRoot 'docs/current/current-baseline.json'
if (-not (Test-Path -LiteralPath $baselineJsonPath -PathType Leaf)) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_JSON_INVALID' "current-baseline.json not found at '$baselineJsonPath'"
}

$baselineRaw = Get-Content -LiteralPath $baselineJsonPath -Raw -Encoding UTF8
$baseline = $null

try {
    $baseline = $baselineRaw | ConvertFrom-Json
} catch {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_JSON_INVALID' "Failed to parse current-baseline.json: $($_.Exception.Message)"
}

if ($null -eq $baseline -or $baseline -isnot [PSCustomObject]) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_JSON_INVALID' "current-baseline.json must contain a JSON root object."
}

$requiredStringProps = @(
    'productId',
    'productTitle',
    'featureId',
    'featureTitle',
    'implementationVersion',
    'versionHeader',
    'canonicalSourcePath',
    'canonicalSha256',
    'canonicalEncoding',
    'canonicalEol',
    'bindingCommitSha',
    'closureAuthority',
    'closureDisposition'
)

$propNames = @($baseline.PSObject.Properties.Name)

foreach ($prop in $requiredStringProps) {
    if ($propNames -notcontains $prop) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_JSON_INVALID' "Missing required JSON property '$prop'"
    }
    $val = $baseline.$prop
    if ($null -eq $val -or $val -isnot [string] -or [string]::IsNullOrWhiteSpace($val)) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_JSON_INVALID' "Property '$prop' must be a non-empty string"
    }
}

if ($propNames -notcontains 'canonicalSizeBytes') {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_JSON_INVALID' "Missing required property 'canonicalSizeBytes'"
}

$canonicalSizeBytes = [long]$baseline.canonicalSizeBytes
$canonicalSha256 = [string]$baseline.canonicalSha256
$canonicalSourcePath = [string]$baseline.canonicalSourcePath
$bindingCommitSha = [string]$baseline.bindingCommitSha
$implementationVersion = [string]$baseline.implementationVersion
$closureDisposition = [string]$baseline.closureDisposition
$gitCanonicalPath = $canonicalSourcePath.Replace('\', '/')

# -----------------------------------------------------------------------------
# 3. Validate Required Documentation Files Exist
# -----------------------------------------------------------------------------
$requiredDocs = @(
    'docs/current/SPECIFICATION.md',
    'docs/current/ARCHITECTURE_DESIGN.md',
    'docs/current/CURRENT_BASELINE.md',
    'docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md'
)

foreach ($docRel in $requiredDocs) {
    $docFull = Join-Path $repoRoot $docRel
    if (-not (Test-Path -LiteralPath $docFull -PathType Leaf)) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_REQUIRED_DOC_MISSING' "Required doc missing: '$docRel'"
    }
}

# -----------------------------------------------------------------------------
# 4. Human-Readable Baseline Reconciliation (CURRENT_BASELINE.md)
# -----------------------------------------------------------------------------
$currentBaselineMdPath = Join-Path $repoRoot 'docs/current/CURRENT_BASELINE.md'
$cbContent = Get-Content -LiteralPath $currentBaselineMdPath -Raw -Encoding UTF8

$requiredSubstrings = @(
    $canonicalSha256,
    $bindingCommitSha,
    $implementationVersion,
    $closureDisposition
)

foreach ($sub in $requiredSubstrings) {
    if (-not $cbContent.Contains($sub)) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_DOC_BASELINE_MISMATCH' "CURRENT_BASELINE.md does not contain required substring: '$sub'"
    }
}

# -----------------------------------------------------------------------------
# 5. Validate Canonical Production Payload
# -----------------------------------------------------------------------------
$payloadFullPath = Join-Path $repoRoot $canonicalSourcePath
$payloadFullPath = [System.IO.Path]::GetFullPath($payloadFullPath)

if (-not (Test-Path -LiteralPath $payloadFullPath -PathType Leaf)) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_PAYLOAD_HASH_MISMATCH' "Canonical payload missing at '$payloadFullPath'"
}

$payloadBytes = [System.IO.File]::ReadAllBytes($payloadFullPath)

if ($payloadBytes.Length -ne $canonicalSizeBytes) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_PAYLOAD_SIZE_MISMATCH' "Canonical payload size mismatch: expected $canonicalSizeBytes, got $($payloadBytes.Length)"
}

$sha256 = [System.Security.Cryptography.SHA256]::Create()
try {
    $hashBytes = $sha256.ComputeHash($payloadBytes)
} finally {
    $sha256.Dispose()
}
$computedHash = ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToUpperInvariant()

if ($computedHash -ne $canonicalSha256.ToUpperInvariant()) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_PAYLOAD_HASH_MISMATCH' "SHA256 mismatch: expected $canonicalSha256, computed $computedHash"
}

# BOM check: first 3 bytes must be EF BB BF
if ($payloadBytes.Length -lt 3 -or $payloadBytes[0] -ne 0xEF -or $payloadBytes[1] -ne 0xBB -or $payloadBytes[2] -ne 0xBF) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_PAYLOAD_ENCODING_MISMATCH' "Payload missing UTF-8 BOM (0xEF 0xBB 0xBF)"
}

# CRLF line ending check: no lone LF
for ($i = 0; $i -lt $payloadBytes.Length; $i++) {
    if ($payloadBytes[$i] -eq 0x0A) {
        if ($i -eq 0 -or $payloadBytes[$i - 1] -ne 0x0D) {
            Stop-BaselineGuard 'STOP_BASELINE_GUARD_PAYLOAD_ENCODING_MISMATCH' "Payload contains lone LF at byte offset $i (CRLF required)"
        }
    }
}

# -----------------------------------------------------------------------------
# 6. Git Index & Working Tree Cleanliness
# -----------------------------------------------------------------------------
$indexDiff = Invoke-GitCommand -RepoRoot $repoRoot -Arguments @('diff', '--cached', '--name-only')
if ($indexDiff.ExitCode -ne 0) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_INDEX_DIRTY' "git diff --cached failed with exit code $($indexDiff.ExitCode)"
}
$indexList = [System.Collections.Generic.List[string]]$indexDiff.Output
if ($indexList.Count -gt 0) {
    $staged = ($indexList | ForEach-Object { $_ }) -join ', '
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_INDEX_DIRTY' "Tracked files staged in index: $staged"
}

$worktreeDiff = Invoke-GitCommand -RepoRoot $repoRoot -Arguments @('diff', '--name-only')
if ($worktreeDiff.ExitCode -ne 0) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_WORKTREE_DIRTY' "git diff failed with exit code $($worktreeDiff.ExitCode)"
}
$worktreeList = [System.Collections.Generic.List[string]]$worktreeDiff.Output
if ($worktreeList.Count -gt 0) {
    $modified = ($worktreeList | ForEach-Object { $_ }) -join ', '
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_WORKTREE_DIRTY' "Tracked files modified in worktree: $modified"
}

# -----------------------------------------------------------------------------
# 7. Git HEAD & Descendant Baseline Guard
# -----------------------------------------------------------------------------
$headResult = Invoke-GitCommand -RepoRoot $repoRoot -Arguments @('rev-parse', 'HEAD')
if ($headResult.ExitCode -ne 0) {
    Stop-BaselineGuard 'STOP_BASELINE_GUARD_HEAD_NOT_DESCENDANT' "Failed to resolve git HEAD"
}

$headList = [System.Collections.Generic.List[string]]$headResult.Output
$currentHead = ($headList | Select-Object -First 1).Trim()

if ($currentHead -eq $bindingCommitSha) {
    # Case A: HEAD is exact binding commit -> PASS
} else {
    # Case B: HEAD is a descendant of bindingCommitSha
    $ancestryCheck = Invoke-GitCommand -RepoRoot $repoRoot -Arguments @('merge-base', '--is-ancestor', $bindingCommitSha, $currentHead)
    if ($ancestryCheck.ExitCode -ne 0) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_HEAD_NOT_DESCENDANT' "HEAD ($currentHead) is not a descendant of binding commit ($bindingCommitSha)"
    }

    # Verify zero diff for production payload between binding commit and HEAD
    $payloadDiff = Invoke-GitCommand -RepoRoot $repoRoot -Arguments @('diff', '--name-only', "$bindingCommitSha..$currentHead", '--', $gitCanonicalPath)
    if ($payloadDiff.ExitCode -ne 0) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_PRODUCTION_DRIFT' "Failed to inspect diff for '$canonicalSourcePath'"
    }
    $pDiffList = [System.Collections.Generic.List[string]]$payloadDiff.Output
    if ($pDiffList.Count -gt 0) {
        Stop-BaselineGuard 'STOP_BASELINE_GUARD_PRODUCTION_DRIFT' "Production payload was modified between binding commit ($bindingCommitSha) and HEAD ($currentHead)"
    }
}

# -----------------------------------------------------------------------------
# 8. Guard PASSED
# -----------------------------------------------------------------------------
if (-not $Quiet) {
    Write-Output 'PASS_BASELINE_GUARD_GREEN'
}
exit 0
