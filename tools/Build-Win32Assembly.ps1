<#
.SYNOPSIS
    Compiles the Win32 native helper C# source into a pre-compiled DLL.

.DESCRIPTION
    This script compiles lib/Win32NativeHelpers.cs into lib/Win32NativeHelpers.dll
    using the .NET Framework C# compiler (csc.exe) available with Windows PowerShell 5.1.

    The resulting DLL replaces the runtime Add-Type -TypeDefinition compilation
    in FM-Obsidian-Bridge-Payload.ps1, eliminating ~350ms of startup overhead.

.NOTES
    Run this script once after any modification to lib/Win32NativeHelpers.cs.
    The compiled DLL should be committed to the repository.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/Build-Win32Assembly.ps1
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$csFile   = Join-Path $repoRoot "lib\Win32NativeHelpers.cs"
$dllFile  = Join-Path $repoRoot "lib\Win32NativeHelpers.dll"

if (-not (Test-Path -LiteralPath $csFile)) {
    Write-Error "C# source not found: $csFile"
    exit 1
}

# Locate the .NET Framework C# compiler
$cscPath = $null

# Strategy 1: Use the .NET Framework directory (most reliable on Windows PowerShell 5.1)
$fwDir = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
$cscCandidate = Join-Path $fwDir "csc.exe"
if (Test-Path -LiteralPath $cscCandidate) {
    $cscPath = $cscCandidate
}

# Strategy 2: Search known .NET Framework paths
if (-not $cscPath) {
    $fwRoot = Join-Path $env:SystemRoot "Microsoft.NET\Framework64\v4.0.30319"
    $cscCandidate = Join-Path $fwRoot "csc.exe"
    if (Test-Path -LiteralPath $cscCandidate) {
        $cscPath = $cscCandidate
    }
}

if (-not $cscPath) {
    $fwRoot = Join-Path $env:SystemRoot "Microsoft.NET\Framework\v4.0.30319"
    $cscCandidate = Join-Path $fwRoot "csc.exe"
    if (Test-Path -LiteralPath $cscCandidate) {
        $cscPath = $cscCandidate
    }
}

if (-not $cscPath) {
    Write-Error "csc.exe not found. Ensure .NET Framework 4.x is installed."
    exit 1
}

Write-Host "=== FM-Obsidian-Bridge Win32 Assembly Builder ==="
Write-Host "C# source:  $csFile"
Write-Host "Output DLL:  $dllFile"
Write-Host "Compiler:    $cscPath"
Write-Host ""

# Remove existing DLL to ensure clean build
if (Test-Path -LiteralPath $dllFile) {
    Remove-Item -LiteralPath $dllFile -Force
    Write-Host "Removed existing DLL."
}

# Compile
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$cscArgs = @(
    "/target:library"
    "/optimize+"
    "/nologo"
    "/out:$dllFile"
    $csFile
)

$process = Start-Process -FilePath $cscPath -ArgumentList $cscArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput (Join-Path $env:TEMP "csc_stdout.txt") -RedirectStandardError (Join-Path $env:TEMP "csc_stderr.txt")

$compileMs = $sw.ElapsedMilliseconds

$stdout = Get-Content (Join-Path $env:TEMP "csc_stdout.txt") -Raw -ErrorAction SilentlyContinue
$stderr = Get-Content (Join-Path $env:TEMP "csc_stderr.txt") -Raw -ErrorAction SilentlyContinue

if ($stdout) { Write-Host $stdout }
if ($stderr) { Write-Host $stderr }

if ($process.ExitCode -ne 0) {
    Write-Error "Compilation failed with exit code $($process.ExitCode)"
    exit 1
}

if (-not (Test-Path -LiteralPath $dllFile)) {
    Write-Error "DLL was not created: $dllFile"
    exit 1
}

$dllSize = (Get-Item -LiteralPath $dllFile).Length
Write-Host ""
Write-Host "=== Build Successful ==="
Write-Host "DLL size:    $dllSize bytes"
Write-Host "Build time:  ${compileMs}ms"
Write-Host ""

# Verification: Load and verify types
Write-Host "=== Verification ==="
try {
    Add-Type -Path $dllFile
    $t1 = [Win32NativeMergeHelper]
    $t2 = [Win32DurableJournalHelper]
    Write-Host "Win32NativeMergeHelper:    OK (type loaded)"
    Write-Host "Win32DurableJournalHelper: OK (type loaded)"

    # Verify key members exist
    $members = @(
        "GetLongPathName", "CreateDirectory", "GetFileInformationByHandle",
        "FindFirstStream", "FindNextStream", "FindClose",
        "CreateFile", "GetFileInformationByHandleEx", "CloseHandle",
        "SetFileInformationByHandle", "RenameDirectory"
    )
    foreach ($m in $members) {
        $found = $t1.GetMethod($m)
        if ($found) {
            Write-Host "  $m : OK"
        } else {
            Write-Warning "  $m : NOT FOUND"
        }
    }

    $moveFileEx = $t2.GetMethod("MoveFileEx")
    if ($moveFileEx) {
        Write-Host "  MoveFileEx: OK"
    } else {
        Write-Warning "  MoveFileEx: NOT FOUND"
    }

    Write-Host ""
    Write-Host "All verifications passed."
} catch {
    Write-Error "Verification failed: $_"
    exit 1
}
