[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '..\..')
)

$ErrorActionPreference = 'Stop'
$RepositoryRoot = [IO.Path]::GetFullPath($RepositoryRoot)
$results = New-Object System.Collections.Generic.List[object]

function Add-Check([string]$Name, [bool]$Passed) {
    $script:results.Add([PSCustomObject]@{ Name = $Name; Passed = $Passed })
    if (-not $Passed) { throw "Focused test failed: $Name" }
}

function Invoke-Git([string]$Root, [string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& git.exe -C $Root @Arguments 2>&1 | ForEach-Object { $_.ToString() }) } finally { $ErrorActionPreference = $previousPreference }
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($Arguments -join ' '): $($output -join ' ')" }
    return @($output | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Invoke-Tool([string]$ToolPath, [string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ToolPath @Arguments 2>&1 | ForEach-Object { $_.ToString() }) } finally { $ErrorActionPreference = $previousPreference }
    return [PSCustomObject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

function Read-ZipText($Entry) {
    $stream = $Entry.Open()
    try {
        $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false)), $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally { $stream.Dispose() }
}

function Read-ZipBytes($Entry) {
    $stream = $Entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); return $memory.ToArray() } finally { $memory.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-SourceSnapshot([string]$Root) {
    $rows = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($Root.Length).TrimStart('\').Replace('\', '/')
        $rows += "$relative`t$($file.Length)`t$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)"
    }
    return $rows -join "`n"
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('fm-obsidian-source-state-test-' + [Guid]::NewGuid().ToString('N'))
$workingRoot = Join-Path $testRoot 'repository'
$remoteRoot = Join-Path $testRoot 'origin.git'
$outputRoot = Join-Path $testRoot 'output'

try {
    New-Item -ItemType Directory -Path $workingRoot, $outputRoot | Out-Null
    foreach ($item in @(Get-ChildItem -LiteralPath $RepositoryRoot -Force | Where-Object { $_.Name -ne '.git' })) {
        Copy-Item -LiteralPath $item.FullName -Destination $workingRoot -Recurse -Force
    }

    & git.exe init --bare $remoteRoot | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize focused-test bare repository' }
    & git.exe init $workingRoot | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize focused-test repository' }
    Invoke-Git $workingRoot @('checkout', '-b', 'main') | Out-Null
    Invoke-Git $workingRoot @('add', '--all') | Out-Null
    Invoke-Git $workingRoot @('-c', 'user.name=Package Test', '-c', 'user.email=package-test@example.invalid', 'commit', '-m', 'test fixture') | Out-Null
    Invoke-Git $workingRoot @('remote', 'add', 'origin', $remoteRoot) | Out-Null
    Invoke-Git $workingRoot @('push', '-u', 'origin', 'main') | Out-Null

    $toolPath = Join-Path $workingRoot 'tools\package\build_package_final.ps1'
    $zipPath = Join-Path $outputRoot 'fixture.zip'
    $build = Invoke-Tool $toolPath @('-Build', '-RepositoryRoot', $workingRoot, '-OutputDirectory', $outputRoot, '-PackageName', 'fixture.zip')
    Add-Check 'clean repository build passes' ($build.ExitCode -eq 0 -and (Test-Path -LiteralPath $zipPath -PathType Leaf))

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $sourceEntries = @($zip.Entries | Where-Object { $_.FullName -ceq 'PACKAGE_METADATA/package_source_state.json' })
        Add-Check 'source-state metadata exists once' ($sourceEntries.Count -eq 1)
        Add-Check 'ZIP has no duplicate entry names' (@($zip.Entries | Group-Object { $_.FullName.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 }).Count -eq 0)
        $sourceEntry = $sourceEntries[0]
        $jsonBytes = [byte[]]@(Read-ZipBytes $sourceEntry)
        $jsonText = Read-ZipText $sourceEntry
        $state = $jsonText | ConvertFrom-Json
        $headOutput = @(Invoke-Git $workingRoot @('rev-parse', 'HEAD'))
        $originMainOutput = @(Invoke-Git $workingRoot @('rev-parse', 'origin/main'))
        $commitCountOutput = @(Invoke-Git $workingRoot @('rev-list', '--count', 'HEAD'))
        $head = $headOutput[0]
        $originMain = $originMainOutput[0]
        $commitCount = [int]$commitCountOutput[0]
        $trackedCount = @(Invoke-Git $workingRoot @('ls-files')).Count
        Add-Check 'sourceHead matches HEAD' ($state.sourceHead -ceq $head)
        Add-Check 'sourceOriginMain matches origin/main' ($state.sourceOriginMain -ceq $originMain)
        Add-Check 'branch is main' ($state.branch -ceq 'main')
        Add-Check 'ahead and behind are zero' ($state.ahead -eq 0 -and $state.behind -eq 0)
        Add-Check 'workingTreeClean is true' ($state.workingTreeClean -is [bool] -and $state.workingTreeClean)
        Add-Check 'trackedFileCount matches Git' ($state.trackedFileCount -eq $trackedCount)
        Add-Check 'sourceCommitCount matches Git' ($state.sourceCommitCount -eq $commitCount)
        Add-Check 'package tool SHA256 matches' ($state.packageToolSha256 -ceq (Get-FileHash -LiteralPath $toolPath -Algorithm SHA256).Hash)
        Add-Check 'JSON omits local absolute path' (-not $jsonText.Contains($workingRoot))
        Add-Check 'JSON omits email' (-not $jsonText.Contains('@'))
        Add-Check 'JSON omits hostname' (-not $jsonText.Contains([Environment]::MachineName))
        $hasBom = $jsonBytes.Length -ge 3 -and $jsonBytes[0] -eq 0xEF -and $jsonBytes[1] -eq 0xBB -and $jsonBytes[2] -eq 0xBF
        Add-Check 'JSON is UTF-8 without BOM, LF, and final newline' ($jsonBytes.Length -gt 0 -and -not $hasBom -and -not ($jsonBytes -contains 0x0D) -and $jsonBytes[$jsonBytes.Length - 1] -eq 0x0A)
        Add-Check 'generatedAt includes timezone' ($state.generatedAt -match '(Z|[+-]\d{2}:\d{2})$')
        $fileList = Read-ZipText ($zip.Entries | Where-Object { $_.FullName -ceq 'PACKAGE_METADATA/file_list.txt' } | Select-Object -First 1)
        $manifest = Read-ZipText ($zip.Entries | Where-Object { $_.FullName -ceq 'PACKAGE_METADATA/manifest.tsv' } | Select-Object -First 1)
        $checksums = Read-ZipText ($zip.Entries | Where-Object { $_.FullName -ceq 'PACKAGE_METADATA/checksums_sha256.txt' } | Select-Object -First 1)
        Add-Check 'source-state metadata is self-excluded' (-not $fileList.Contains('package_source_state.json') -and -not $manifest.Contains('package_source_state.json') -and -not $checksums.Contains('package_source_state.json'))
    } finally { $zip.Dispose() }

    Add-Check 'metadata does not remain in source tree' (-not (Test-Path -LiteralPath (Join-Path $workingRoot 'PACKAGE_METADATA\package_source_state.json')))

    Add-Content -LiteralPath (Join-Path $workingRoot 'README.md') -Value 'dirty focused test'
    $dirty = Invoke-Tool $toolPath @('-Build', '-RepositoryRoot', $workingRoot, '-OutputDirectory', $outputRoot, '-PackageName', 'dirty.zip')
    Add-Check 'dirty repository stops before ZIP generation' ($dirty.ExitCode -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $outputRoot 'dirty.zip')))
    Invoke-Git $workingRoot @('checkout', '--', 'README.md') | Out-Null

    Add-Content -LiteralPath (Join-Path $workingRoot 'README.md') -Value 'diverged focused test'
    Invoke-Git $workingRoot @('add', 'README.md') | Out-Null
    Invoke-Git $workingRoot @('-c', 'user.name=Package Test', '-c', 'user.email=package-test@example.invalid', 'commit', '-m', 'diverge fixture') | Out-Null
    $diverged = Invoke-Tool $toolPath @('-Build', '-RepositoryRoot', $workingRoot, '-OutputDirectory', $outputRoot, '-PackageName', 'diverged.zip')
    Add-Check 'diverged repository stops before ZIP generation' ($diverged.ExitCode -ne 0 -and -not (Test-Path -LiteralPath (Join-Path $outputRoot 'diverged.zip')))

    $beforeValidation = Get-SourceSnapshot $workingRoot
    $zipCountBefore = @(Get-ChildItem -LiteralPath $outputRoot -Filter '*.zip' -File).Count
    $validation = Invoke-Tool $toolPath @('-Validate', '-RepositoryRoot', $workingRoot)
    $zipCountAfter = @(Get-ChildItem -LiteralPath $outputRoot -Filter '*.zip' -File).Count
    Add-Check 'validation-only passes without ZIP generation' ($validation.ExitCode -eq 0 -and $validation.Output -contains 'VALIDATION: PASS' -and $zipCountBefore -eq $zipCountAfter)
    Add-Check 'validation-only leaves source unchanged' ($beforeValidation -ceq (Get-SourceSnapshot $workingRoot) -and -not (Test-Path -LiteralPath (Join-Path $workingRoot 'PACKAGE_METADATA')))

    $parser = Invoke-Tool $toolPath @()
    Add-Check 'Windows PowerShell 5.1 parser passes' ($parser.ExitCode -eq 0 -and $parser.Output -contains 'Safe Project State package tool (Windows PowerShell 5.1 compatible)')

    $passed = @($results | Where-Object { $_.Passed }).Count
    Write-Output "FOCUSED_TEST: PASS"
    Write-Output "TOTAL: $($results.Count)"
    Write-Output "PASS: $passed"
    Write-Output "FAIL: $($results.Count - $passed)"
    foreach ($result in $results) { Write-Output ("PASS: " + $result.Name) }
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
