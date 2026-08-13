#requires -Version 5.1
<#
Script : AIG-Common.ps1
Description: AIG連携用共通関数ライブラリ（契約・事故共通）
#>

function Parse-DateSafe([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $s = $s.Trim()
    $formats = @("yyyy/M/d", "yyyy/MM/dd", "yyyy/M/dd", "yyyy/MM/d", "yyyy-M-d", "yyyy-MM-dd", "yyyyMMdd")
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $style   = [System.Globalization.DateTimeStyles]::AssumeLocal
    foreach ($fmt in $formats) {
        try { return [DateTime]::ParseExact($s, $fmt, $culture, $style) } catch {}
    }
    try { return [DateTime]::Parse($s) } catch { return $null }
}

function Get-LevenshteinDistance([string]$a, [string]$b) {
    if ($a -eq $null) { $a = "" }; if ($b -eq $null) { $b = "" }
    $a = $a.ToString(); $b = $b.ToString()
    $n = $a.Length; $m = $b.Length
    if ($n -eq 0) { return $m }; if ($m -eq 0) { return $n }
    $d = New-Object 'int[][]' ($n + 1)
    for ($k = 0; $k -le $n; $k++) { $d[$k] = New-Object int[] ($m + 1) }
    for ($i=0; $i -le $n; $i++) { $d[$i][0] = $i }; for ($j=0; $j -le $m; $j++) { $d[0][$j] = $j }
    for ($i=1; $i -le $n; $i++) {
        for ($j=1; $j -le $m; $j++) {
            $cost = 0; if ($a[$i-1] -ne $b[$j-1]) { $cost = 1 }
            $del = $d[$i-1][$j] + 1; $ins = $d[$i][$j-1] + 1; $sub = $d[$i-1][$j-1] + $cost
            $d[$i][$j] = [Math]::Min($del, [Math]::Min($ins, $sub))
        }
    }
    return $d[$n][$m]
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Load-Json-Compatible([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        try {
            $jsonStr = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($jsonStr)) { return @{} }
            $obj = $jsonStr | ConvertFrom-Json
            $hash = @{}
            if ($null -ne $obj) {
                foreach ($prop in $obj.PSObject.Properties) { $hash[$prop.Name] = $prop.Value }
            }
            return $hash
        } catch { return @{} }
    }
    return @{}
}

function Save-Json([object]$Data, [string]$Path) {
    Ensure-Directory (Split-Path -Parent $Path)
    $json = $Data | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $Path -Value $json -Encoding UTF8
}

function Normalize-String([string]$s) {
    if ($null -eq $s) { return "" }
    # 1. 全角・半角スペース、タブ除去
    $s = ($s -replace "[\u0020\u3000\t]+","").Trim()
    
    # 2. 会社名正規化
    $s = $s -replace "株式会社", "㈱"
    $s = $s -replace "\（株\）", "㈱"
    $s = $s -replace "\(株\)", "㈱"
    
    $s = $s -replace "有限会社", "㈲"
    $s = $s -replace "\（有\）", "㈲"
    $s = $s -replace "\(有\)", "㈲"

    # 3. 役職・敬称以降をカット
    $titles = @("代表取締役", "取締役", "社長", "会長", "理事長", "院長", "所長", "代表", "CEO", "COO", "CFO")
    foreach ($t in $titles) {
        $idx = $s.IndexOf($t)
        if ($idx -gt 0) { 
            $s = $s.Substring(0, $idx) 
            break 
        }
    }
    return $s
}

function Get-LookupKey([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return "名称不明" }
    return Normalize-String $name
}

function Ask-UserForFolder([string]$targetName, [array]$existFolders) {
    $exactMatch = $existFolders | Where-Object { $_ -eq $targetName } | Select-Object -First 1
    if ($exactMatch) { return $exactMatch }

    $candidates = @()
    foreach ($f in $existFolders) {
        $normF = Normalize-String $f
        $score = Get-LevenshteinDistance $targetName $normF
        if ($f.Contains($targetName) -or $targetName.Contains($f)) { $score = 0 }
        $candidates += [pscustomobject]@{ Name=$f; Score=$score }
    }
    $candidates = $candidates | Sort-Object Score | Select-Object -First 5
    
    Clear-Host
    Write-Host "=== 顧客フォルダの紐付け確認 ===" -ForegroundColor Cyan
    Write-Host "CSV上の名前 : $targetName"
    
    if ($candidates.Count -gt 0) {
        Write-Host "既存フォルダ候補:"
        for ($i=0; $i -lt $candidates.Count; $i++) {
            Write-Host " [$($i+1)] $($candidates[$i].Name) (差異:$($candidates[$i].Score))"
        }
        $best = $candidates[0].Name
        Write-Host "`n[Enter]キーで '$best' を採用します。" -ForegroundColor Green
    } else {
        Write-Host "`n既存フォルダが見つかりません。新規作成します。" -ForegroundColor Yellow
        $best = $targetName
    }

    $inputVal = Read-Host "番号を選択、または正しいフォルダ名を手入力 (Enterで決定)"
    if ([string]::IsNullOrWhiteSpace($inputVal)) { return $best }
    if ($inputVal -match '^\d+$' -and [int]$inputVal -le $candidates.Count) { 
        return $candidates[[int]$inputVal - 1].Name 
    }
    return $inputVal
}

function Import-CsvSafe([string]$path) {
    $lines = Get-Content -LiteralPath $path -Encoding UTF8
    if ($lines.Count -lt 2) { return @() }
    $headers = $lines[0] -split ',' | ForEach-Object { $_.Trim().TrimStart([char]0xFEFF).Trim('"') }
    
    $uniqueHeaders = @(); $seen = @{}
    foreach ($h in $headers) {
        if ($seen[$h]) { $seen[$h]++; $h = "$h`__$($seen[$h])" } else { $seen[$h]=1 }
        $uniqueHeaders += $h
    }
    
    return ($lines | Select-Object -Skip 1) | ConvertFrom-Csv -Header $uniqueHeaders
}
Write-Host "Common module loaded." -ForegroundColor DarkGray