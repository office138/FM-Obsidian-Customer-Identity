[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$OutputDirectory,
    [string]$PackageName,
    [string]$EvidenceRoot,
    [string]$ValidationTarget,
    [switch]$Build,
    [switch]$Validate
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

$metadataDirectory = "PACKAGE_METADATA"
$fileListEntry = "$metadataDirectory/file_list.txt"
$manifestEntry = "$metadataDirectory/manifest.tsv"
$checksumsEntry = "$metadataDirectory/checksums_sha256.txt"
$sourceStateEntry = "$metadataDirectory/package_source_state.json"
$metadataEntries = @($fileListEntry, $manifestEntry, $checksumsEntry, $sourceStateEntry)
$repositoryName = "office138/FM-Obsidian-Customer-Identity"
$packageToolEntry = "tools/package/build_package_final.ps1"
$noteText = -join @([char]0x30CE, [char]0x30FC, [char]0x30C8)
$openText = -join @([char]0x958B, [char]0x304F)
$internalText = -join @([char]0x5185, [char]0x90E8)
$customerText = -join @([char]0x9867, [char]0x5BA2)
$customerIdentityText = -join @([char]0x9867, [char]0x5BA2, [char]0x540D, [char]0x30FB, [char]0x4EE3, [char]0x8868, [char]0x8005, [char]0x540D, [char]0x540C, [char]0x671F)
$requiredEntries = @(
    "FM-Obsidian-Bridge-Payload.ps1",
    "filemaker/EXT-obs_OBS$($noteText)-$($openText).txt",
    "filemaker/EXT-obs_$($internalText)CallPS-PAYLOAD.txt",
    "filemaker/EXT-obs_$($customerIdentityText).txt",
    "tests/windows/Run-UCITests.ps1",
    "tools/package/build_package_final.ps1"
)

function Show-Usage {
    @"
Safe Project State package tool (Windows PowerShell 5.1 compatible)

Default behavior is no-write. Choose one explicit mode:
  Validate repository: .\build_package_final.ps1 -Validate [-RepositoryRoot <path>]
  Validate ZIP:        .\build_package_final.ps1 -Validate -ValidationTarget <zip>
  Build new ZIP:       .\build_package_final.ps1 -Build -OutputDirectory <existing-dir> -PackageName <name> [-RepositoryRoot <path>] [-EvidenceRoot <path>]

Build never overwrites an existing ZIP. Evidence is omitted unless EvidenceRoot is explicit.
"@ | Write-Output
}

function Get-FullPath([string]$Path) {
    return [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
}

function Test-PathWithin([string]$Child, [string]$Parent) {
    $childFull = Get-FullPath $Child
    $parentFull = Get-FullPath $Parent
    if ($childFull.Equals($parentFull, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $childFull.StartsWith($parentFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
}

function Get-SHA256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-RelativePath([string]$Root, [string]$FullName) {
    $rootFull = Get-FullPath $Root
    $fileFull = Get-FullPath $FullName
    if (-not (Test-PathWithin $fileFull $rootFull) -or $fileFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is not a child of the declared root: $FullName"
    }
    return $fileFull.Substring($rootFull.Length + 1).Replace('\', '/')
}

function Test-ExcludedRelativePath([string]$RelativePath) {
    $normalized = $RelativePath.Replace('\', '/').TrimStart('/')
    $segments = @($normalized -split '/')
    $leaf = $segments[$segments.Count - 1]

    foreach ($segment in $segments) {
        if ($segment -ieq '.git' -or
            $segment -ieq 'LOCAL_EVIDENCE' -or
            $segment -ieq 'GitHub-Staging' -or
            $segment -ieq 'Archive' -or
            $segment -ieq $metadataDirectory) {
            return $true
        }
    }

    if ($leaf -ieq '_payloadB64.tmp' -or $leaf -ieq '_report.json' -or $leaf -ieq '_report.txt') { return $true }
    if ($leaf -match '(?i)\.zip$|\.tmp$|\.temp$|\.building$|\.swp$|~$') { return $true }
    if ($leaf -match '^~\$') { return $true }
    return $false
}

function Assert-SafeEntryName([string]$EntryName) {
    $name = $EntryName.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($name)) { throw "Empty ZIP entry name" }
    if ($name.StartsWith('/') -or $name.StartsWith('\') -or $name -match '^[A-Za-z]:') {
        throw "Absolute ZIP entry is forbidden: $EntryName"
    }
    foreach ($segment in @($name -split '/')) {
        if ($segment -eq '' -or $segment -eq '.' -or $segment -eq '..') {
            throw "Unsafe ZIP entry path: $EntryName"
        }
    }
}

function ConvertTo-NormalizedEntryName([string]$EntryName) {
    $name = $EntryName.Replace('\', '/')
    while ($name.StartsWith('./')) { $name = $name.Substring(2) }
    while ($name.Contains('//')) { $name = $name.Replace('//', '/') }
    Assert-SafeEntryName $name
    return $name
}

function Assert-RequiredEntries([string[]]$EntryNames) {
    foreach ($required in $requiredEntries) {
        if (-not ($EntryNames -contains $required)) { throw "Required file is missing: $required" }
    }
}

function Get-RepositoryFiles([string]$Root) {
    $items = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File)) {
        $relative = Get-RelativePath $Root $file.FullName
        if (Test-ExcludedRelativePath $relative) { continue }
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse-point files are forbidden: $relative"
        }
        Assert-SafeEntryName $relative
        $items += [PSCustomObject]@{ Source = $file.FullName; Entry = $relative }
    }
    return @($items | Sort-Object Entry)
}

function Assert-SafeEvidenceRoot([string]$Root, [string]$Repository, [string]$Output) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "EvidenceRoot is not an existing directory: $Root" }
    $full = Get-FullPath $Root
    if ((Test-PathWithin $full $Repository) -or (Test-PathWithin $Repository $full)) {
        throw "EvidenceRoot must be separate from RepositoryRoot"
    }
    if ((Test-PathWithin $full $Output) -or (Test-PathWithin $Output $full)) {
        throw "EvidenceRoot must be separate from OutputDirectory"
    }
    $customerDirectory = '01_' + $customerText
    if ((Test-Path -LiteralPath (Join-Path $full '.obsidian') -PathType Container) -or
        (Test-Path -LiteralPath (Join-Path $full $customerDirectory) -PathType Container)) {
        throw "An Obsidian Vault or customer-data root cannot be used as EvidenceRoot"
    }
    $reparse = @(Get-ChildItem -LiteralPath $full -Recurse -Force | Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 })
    if ($reparse.Count -gt 0) { throw "EvidenceRoot contains a reparse point: $($reparse[0].FullName)" }
}

function Get-EvidenceFiles([string]$Root) {
    $files = @()
    $totalBytes = [Int64]0
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File)) {
        $relative = Get-RelativePath $Root $file.FullName
        if (Test-ExcludedRelativePath $relative) { continue }
        if ($file.Name -match '(?i)^\.env($|\.)|credentials|secret|token|password|private[-_]?key|^id_rsa') {
            throw "Potential secret file is forbidden in EvidenceRoot: $relative"
        }
        $entry = "LOCAL_EVIDENCE/$relative"
        Assert-SafeEntryName $entry
        $totalBytes += $file.Length
        $files += [PSCustomObject]@{ Source = $file.FullName; Entry = $entry }
    }
    if ($files.Count -gt 500) { throw "EvidenceRoot exceeds the 500-file safety limit" }
    if ($totalBytes -gt 100MB) { throw "EvidenceRoot exceeds the 100 MiB safety limit" }
    return @($files | Sort-Object Entry)
}

function Get-TreeSnapshot([string]$Root) {
    $rows = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Sort-Object FullName)) {
        $relative = Get-RelativePath $Root $file.FullName
        $rows += "$relative`t$($file.Length)`t$(Get-SHA256 $file.FullName)"
    }
    return $rows -join "`n"
}

function Write-Utf8Lines([string]$Path, [string[]]$Lines) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Write-Utf8LfText([string]$Path, [string]$Text) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $normalized = ($Text -replace "`r`n", "`n").TrimEnd("`r", "`n") + "`n"
    [IO.File]::WriteAllText($Path, $normalized, $encoding)
}

function Invoke-RepositoryGit([string]$Root, [string[]]$Arguments, [switch]$AllowEmpty) {
    $safeRoot = (Get-FullPath $Root).Replace('\', '/')
    $output = @(& git.exe -c "safe.directory=$safeRoot" -c 'core.quotepath=false' -C (Get-FullPath $Root) @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($Arguments -join ' '): $($output -join ' ')"
    }
    $trimmed = @($output | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
    if (-not $AllowEmpty -and $trimmed.Count -eq 0) {
        throw "Git command returned an empty value: git $($Arguments -join ' ')"
    }
    return $trimmed
}

function Get-PackageSourceState([string]$Root) {
    $branch = @(Invoke-RepositoryGit $Root @('rev-parse', '--abbrev-ref', 'HEAD'))
    $head = @(Invoke-RepositoryGit $Root @('rev-parse', 'HEAD'))
    $originMain = @(Invoke-RepositoryGit $Root @('rev-parse', 'origin/main'))
    $commitCountText = @(Invoke-RepositoryGit $Root @('rev-list', '--count', 'HEAD'))
    $aheadBehindText = @(Invoke-RepositoryGit $Root @('rev-list', '--left-right', '--count', 'HEAD...origin/main'))
    $status = @(Invoke-RepositoryGit $Root @('status', '--porcelain=v1', '--untracked-files=all') -AllowEmpty)
    $trackedFiles = @(Invoke-RepositoryGit $Root @('ls-files'))
    $originUrl = @(Invoke-RepositoryGit $Root @('remote', 'get-url', 'origin'))

    if ($branch.Count -ne 1 -or $branch[0] -cne 'main') { throw "Package build requires branch main" }
    if ($head.Count -ne 1 -or $head[0] -cnotmatch '^[0-9a-f]{40}$') { throw "Invalid source HEAD" }
    if ($originMain.Count -ne 1 -or $originMain[0] -cnotmatch '^[0-9a-f]{40}$') { throw "Invalid origin/main commit ID" }
    if ($head[0] -cne $originMain[0]) { throw "Package build requires HEAD to equal origin/main" }
    if ($commitCountText.Count -ne 1 -or $commitCountText[0] -notmatch '^\d+$') { throw "Invalid source commit count" }
    if ($aheadBehindText.Count -ne 1 -or $aheadBehindText[0] -notmatch '^\s*(\d+)\s+(\d+)\s*$') { throw "Invalid ahead/behind result" }
    $ahead = [int]$Matches[1]
    $behind = [int]$Matches[2]
    if ($ahead -ne 0 -or $behind -ne 0) { throw "Package build requires ahead/behind 0/0" }
    if ($status.Count -ne 0) { throw "Package build requires a clean working tree, including untracked files" }
    if ($originUrl.Count -ne 1) { throw "Package build requires remote origin" }

    $normalizedTrackedFiles = @($trackedFiles | ForEach-Object { ConvertTo-NormalizedEntryName $_ } | Sort-Object)
    if ($normalizedTrackedFiles.Count -eq 0) { throw "Tracked file count must be greater than zero" }
    if (@($normalizedTrackedFiles | Group-Object | Where-Object { $_.Count -ne 1 }).Count -ne 0) { throw "Duplicate tracked file path returned by Git" }

    $toolPath = Join-Path (Get-FullPath $Root) $packageToolEntry.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) { throw "Package tool is missing: $packageToolEntry" }

    return [PSCustomObject]@{
        Json = [ordered]@{
            schemaVersion = 1
            packageType = 'REPOSITORY'
            repository = $repositoryName
            branch = $branch[0]
            sourceHead = $head[0]
            sourceOriginMain = $originMain[0]
            sourceCommitCount = [int]$commitCountText[0]
            ahead = $ahead
            behind = $behind
            workingTreeClean = $true
            trackedFileCount = $normalizedTrackedFiles.Count
            generatedAt = [DateTimeOffset]::Now.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
            packageToolPath = $packageToolEntry
            packageToolSha256 = Get-SHA256 $toolPath
        }
        TrackedFiles = $normalizedTrackedFiles
    }
}

function Copy-PackageFile($Item, [string]$PackageRoot) {
    $destination = Join-Path $PackageRoot $Item.Entry.Replace('/', '\')
    $parent = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent | Out-Null
    }
    Copy-Item -LiteralPath $Item.Source -Destination $destination
}

function Read-ZipEntryText($Entry) {
    $stream = $Entry.Open()
    try {
        $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false)), $true)
        try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Read-ZipEntryBytes($Entry) {
    $stream = $Entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        try {
            $stream.CopyTo($memory)
            return $memory.ToArray()
        } finally { $memory.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-ZipEntrySHA256($Entry) {
    $stream = $Entry.Open()
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $sha.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Convert-TextToLines([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) { return @() }
    return @(($Text -replace "`r`n", "`n").TrimEnd("`n") -split "`n")
}

function Test-PackageSourceStateJson([string]$Text, [byte[]]$Bytes) {
    $propertyNames = @(
        'schemaVersion', 'packageType', 'repository', 'branch', 'sourceHead', 'sourceOriginMain',
        'sourceCommitCount', 'ahead', 'behind', 'workingTreeClean', 'trackedFileCount', 'generatedAt',
        'packageToolPath', 'packageToolSha256'
    )
    if ($Bytes.Length -eq 0 -or ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF)) { throw "Package source-state JSON must be UTF-8 without BOM" }
    if ($Bytes[$Bytes.Length - 1] -ne 0x0A -or $Bytes -contains 0x0D) { throw "Package source-state JSON must use LF and end with a newline" }
    try { $state = $Text | ConvertFrom-Json -ErrorAction Stop } catch { throw "Invalid package source-state JSON: $($_.Exception.Message)" }
    $actualNames = @($state.PSObject.Properties | ForEach-Object { $_.Name })
    if (($actualNames -join "`n") -cne ($propertyNames -join "`n")) { throw "Package source-state JSON has unexpected properties or property order" }
    if ([int]$state.schemaVersion -ne 1) { throw "Invalid package source-state schemaVersion" }
    if ($state.packageType -cne 'REPOSITORY') { throw "Invalid package source-state packageType" }
    if ($state.repository -cne $repositoryName) { throw "Invalid package source-state repository" }
    if ($state.branch -cne 'main') { throw "Invalid package source-state branch" }
    if ($state.sourceHead -cnotmatch '^[0-9a-f]{40}$' -or $state.sourceOriginMain -cnotmatch '^[0-9a-f]{40}$') { throw "Invalid package source-state commit ID" }
    if ($state.sourceHead -cne $state.sourceOriginMain) { throw "Package source-state HEAD does not equal origin/main" }
    if ($state.sourceCommitCount -isnot [int] -or $state.sourceCommitCount -lt 1) { throw "Invalid package source-state commit count" }
    if ($state.ahead -isnot [int] -or $state.behind -isnot [int] -or $state.ahead -ne 0 -or $state.behind -ne 0) { throw "Invalid package source-state ahead/behind" }
    if ($state.workingTreeClean -isnot [bool] -or -not $state.workingTreeClean) { throw "Invalid package source-state workingTreeClean" }
    if ($state.trackedFileCount -isnot [int] -or $state.trackedFileCount -lt 1) { throw "Invalid package source-state tracked file count" }
    $parsedGeneratedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact($state.generatedAt, 'o', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedGeneratedAt)) { throw "Invalid package source-state generatedAt" }
    if ($state.packageToolPath -cne $packageToolEntry) { throw "Invalid package source-state tool path" }
    if ($state.packageToolSha256 -cnotmatch '^[A-F0-9]{64}$') { throw "Invalid package source-state tool SHA256" }
}

function Test-PackageZip([string]$ZipPath, [string[]]$AllowedEvidenceEntries = @()) {
    if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw "Validation ZIP does not exist: $ZipPath" }
    $allowedEvidenceLookup = @{}
    foreach ($allowedEntry in @($AllowedEvidenceEntries)) {
        $normalizedAllowed = ConvertTo-NormalizedEntryName $allowedEntry
        if (-not $normalizedAllowed.StartsWith('LOCAL_EVIDENCE/', [StringComparison]::OrdinalIgnoreCase)) {
            throw "Evidence allowlist entry is outside LOCAL_EVIDENCE: $allowedEntry"
        }
        $allowedEvidenceLookup[$normalizedAllowed.ToLowerInvariant()] = $true
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead((Get-FullPath $ZipPath))
    try {
        $byName = @{}
        foreach ($entry in $zip.Entries) {
            $name = ConvertTo-NormalizedEntryName $entry.FullName
            if ($byName.ContainsKey($name.ToLowerInvariant())) { throw "Duplicate ZIP entry: $name" }
            $isGeneratedMetadata = $metadataEntries -contains $name
            $isAllowedEvidence = $name.StartsWith('LOCAL_EVIDENCE/', [StringComparison]::OrdinalIgnoreCase) -and $allowedEvidenceLookup.ContainsKey($name.ToLowerInvariant())
            if (-not $isGeneratedMetadata -and -not $isAllowedEvidence -and (Test-ExcludedRelativePath $name)) { throw "Excluded content found in ZIP: $name" }
            $byName[$name.ToLowerInvariant()] = $entry
        }

        foreach ($metadata in $metadataEntries) {
            if (-not $byName.ContainsKey($metadata.ToLowerInvariant())) { throw "Package metadata is missing: $metadata" }
        }
        $sourceStateBytes = @(Read-ZipEntryBytes $byName[$sourceStateEntry.ToLowerInvariant()])
        $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
        try { $sourceStateText = $strictUtf8.GetString([byte[]]$sourceStateBytes) } catch { throw "Package source-state JSON is not valid UTF-8" }
        Test-PackageSourceStateJson $sourceStateText ([byte[]]$sourceStateBytes)

        $payloadNames = @($zip.Entries | ForEach-Object { $_.FullName.Replace('\', '/') } | Where-Object { $metadataEntries -notcontains $_ } | Sort-Object)
        Assert-RequiredEntries $payloadNames

        $listed = @(Convert-TextToLines (Read-ZipEntryText $byName[$fileListEntry.ToLowerInvariant()]))
        $listed = @($listed | Sort-Object)
        if (($listed -join "`n") -cne ($payloadNames -join "`n")) { throw "file_list.txt does not match ZIP payload entries" }

        $manifest = @{}
        foreach ($line in @(Convert-TextToLines (Read-ZipEntryText $byName[$manifestEntry.ToLowerInvariant()]))) {
            $parts = @($line -split "`t")
            if ($parts.Count -ne 3 -or $manifest.ContainsKey($parts[0])) { throw "Invalid or duplicate manifest row: $line" }
            $manifest[$parts[0]] = @($parts[1], $parts[2])
        }

        $checksums = @{}
        foreach ($line in @(Convert-TextToLines (Read-ZipEntryText $byName[$checksumsEntry.ToLowerInvariant()]))) {
            if ($line -notmatch '^([A-Fa-f0-9]{64})  (.+)$') { throw "Invalid checksums row: $line" }
            if ($checksums.ContainsKey($Matches[2])) { throw "Duplicate checksums row: $($Matches[2])" }
            $checksums[$Matches[2]] = $Matches[1].ToUpperInvariant()
        }

        if ($manifest.Count -ne $payloadNames.Count -or $checksums.Count -ne $payloadNames.Count) {
            throw "Manifest or checksums entry count does not match the payload"
        }
        foreach ($name in $payloadNames) {
            if (-not $manifest.ContainsKey($name) -or -not $checksums.ContainsKey($name)) { throw "Metadata row missing for: $name" }
            $entry = $byName[$name.ToLowerInvariant()]
            $hash = Get-ZipEntrySHA256 $entry
            if ([Int64]$manifest[$name][0] -ne $entry.Length) { throw "Manifest size mismatch: $name" }
            if ($manifest[$name][1].ToUpperInvariant() -ne $hash) { throw "Manifest hash mismatch: $name" }
            if ($checksums[$name] -ne $hash) { throw "Checksums hash mismatch: $name" }
        }

        return [PSCustomObject]@{
            Path = Get-FullPath $ZipPath
            Size = (Get-Item -LiteralPath $ZipPath).Length
            SHA256 = Get-SHA256 $ZipPath
            Entries = $zip.Entries.Count
            PayloadEntries = $payloadNames.Count
        }
    } finally {
        $zip.Dispose()
    }
}

function Test-RepositoryTree([string]$Root) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "RepositoryRoot is not an existing directory: $Root" }
    $files = @(Get-RepositoryFiles $Root)
    $names = @($files | ForEach-Object { $_.Entry })
    Assert-RequiredEntries $names
    return [PSCustomObject]@{ Path = Get-FullPath $Root; IncludedFiles = $files.Count; ExcludedFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File).Count - $files.Count }
}

function New-Package([string]$Root, [string]$Output, [string]$Name, [string]$Evidence) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw "RepositoryRoot is not an existing directory: $Root" }
    if (-not (Test-Path -LiteralPath $Output -PathType Container)) { throw "OutputDirectory must already exist: $Output" }
    if ((Test-PathWithin $Output $Root) -or (Test-PathWithin $Root $Output)) { throw "OutputDirectory must be separate from RepositoryRoot" }
    if ([string]::IsNullOrWhiteSpace($Name)) { throw "PackageName is required with -Build" }
    $trimmedName = $Name.Trim()
    if ($trimmedName -match '[\\/]' -or $trimmedName.Contains('..')) { throw "PackageName cannot contain a path separator or '..'" }
    foreach ($invalid in [IO.Path]::GetInvalidFileNameChars()) {
        if ($trimmedName.Contains([string]$invalid)) { throw "PackageName contains an invalid character" }
    }
    if (-not $trimmedName.EndsWith('.zip', [StringComparison]::OrdinalIgnoreCase)) { $trimmedName += '.zip' }

    $finalPath = Join-Path (Get-FullPath $Output) $trimmedName
    if (Test-Path -LiteralPath $finalPath) { throw "Output ZIP already exists; overwrite is forbidden: $finalPath" }

    $rootFull = Get-FullPath $Root
    $sourceState = Get-PackageSourceState $rootFull
    $sourceBefore = Get-TreeSnapshot $rootFull
    $items = @(Get-RepositoryFiles $rootFull)
    Assert-RequiredEntries @($items | ForEach-Object { $_.Entry })
    $repositoryEntries = @($items | ForEach-Object { $_.Entry } | Sort-Object)
    if (($repositoryEntries -join "`n") -cne (@($sourceState.TrackedFiles) -join "`n")) {
        throw "Package repository payload does not exactly match Git tracked files"
    }
    $allowedEvidenceEntries = @()

    if (-not [string]::IsNullOrWhiteSpace($Evidence)) {
        Assert-SafeEvidenceRoot $Evidence $rootFull (Get-FullPath $Output)
        $evidenceItems = @(Get-EvidenceFiles (Get-FullPath $Evidence))
        $allowedEvidenceEntries = @($evidenceItems | ForEach-Object { $_.Entry })
        $items += $evidenceItems
        $items = @($items | Sort-Object Entry)
    }

    $duplicates = @($items | Group-Object { $_.Entry.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })
    if ($duplicates.Count -gt 0) { throw "Duplicate package entry: $($duplicates[0].Name)" }

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("fm-obsidian-package-" + [Guid]::NewGuid().ToString('N'))
    $packageRoot = Join-Path $temporaryRoot 'content'
    $temporaryZip = Join-Path $temporaryRoot 'package.building'
    try {
        New-Item -ItemType Directory -Path $packageRoot | Out-Null
        foreach ($item in $items) { Copy-PackageFile $item $packageRoot }

        $metadataRoot = Join-Path $packageRoot $metadataDirectory
        New-Item -ItemType Directory -Path $metadataRoot | Out-Null
        $fileList = @()
        $manifest = @()
        $checksums = @()
        foreach ($item in $items) {
            $copied = Join-Path $packageRoot $item.Entry.Replace('/', '\')
            $hash = Get-SHA256 $copied
            $fileList += $item.Entry
            $manifest += "$($item.Entry)`t$((Get-Item -LiteralPath $copied).Length)`t$hash"
            $checksums += "$hash  $($item.Entry)"
        }
        Write-Utf8Lines (Join-Path $metadataRoot 'file_list.txt') $fileList
        Write-Utf8Lines (Join-Path $metadataRoot 'manifest.tsv') $manifest
        Write-Utf8Lines (Join-Path $metadataRoot 'checksums_sha256.txt') $checksums
        $sourceStateJson = $sourceState.Json | ConvertTo-Json -Depth 3
        Write-Utf8LfText (Join-Path $metadataRoot 'package_source_state.json') $sourceStateJson

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::Open($temporaryZip, [IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in @(Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -File | Sort-Object FullName)) {
                $entry = Get-RelativePath $packageRoot $file.FullName
                Assert-SafeEntryName $entry
                [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $entry, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
            }
        } finally {
            $archive.Dispose()
        }

        $verification = Test-PackageZip $temporaryZip $allowedEvidenceEntries
        $sourceAfter = Get-TreeSnapshot $rootFull
        if ($sourceBefore -cne $sourceAfter) { throw "Source repository changed during package creation" }
        Move-Item -LiteralPath $temporaryZip -Destination $finalPath
        return Test-PackageZip $finalPath $allowedEvidenceEntries
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) { Remove-Item -LiteralPath $temporaryRoot -Recurse -Force }
    }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Get-FullPath (Join-Path $PSScriptRoot '..\..')
} else {
    $RepositoryRoot = Get-FullPath $RepositoryRoot
}

if (-not $Build -and -not $Validate) {
    Show-Usage
    exit 0
}
if ($Build -and $Validate) { throw "Choose only one mode: -Build or -Validate" }

if ($Validate) {
    if ([string]::IsNullOrWhiteSpace($ValidationTarget)) {
        $result = Test-RepositoryTree $RepositoryRoot
        Write-Output "VALIDATION: PASS"
        Write-Output "TYPE: REPOSITORY"
        Write-Output "PATH: $($result.Path)"
        Write-Output "INCLUDED_FILES: $($result.IncludedFiles)"
        Write-Output "EXCLUDED_FILES: $($result.ExcludedFiles)"
    } else {
        $result = Test-PackageZip (Get-FullPath $ValidationTarget)
        Write-Output "VALIDATION: PASS"
        Write-Output "TYPE: ZIP"
        Write-Output "PATH: $($result.Path)"
        Write-Output "SIZE: $($result.Size)"
        Write-Output "SHA256: $($result.SHA256)"
        Write-Output "ENTRIES: $($result.Entries)"
    }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { throw "OutputDirectory is required with -Build" }
$result = New-Package $RepositoryRoot $OutputDirectory $PackageName $EvidenceRoot
Write-Output "BUILD: PASS"
Write-Output "PATH: $($result.Path)"
Write-Output "SIZE: $($result.Size)"
Write-Output "SHA256: $($result.SHA256)"
Write-Output "ENTRIES: $($result.Entries)"
