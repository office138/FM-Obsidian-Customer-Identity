#requires -Version 5.1
<#
Script : Update-Obsidian-aigPolicyIndex.ps1 (Commonized v2.1)
Description: 契約一覧生成（共通モジュール完全移行版）
#>

# ====== 設定 ======
$VaultRoot      = Join-Path $env:USERPROFILE "Documents\07Obsidian\【Vault】INS"
$CustomerRoot   = Join-Path $VaultRoot "01_顧客"
$ScriptsDir     = $PSScriptRoot
$MapJsonPath    = Join-Path $ScriptsDir "customer_folder_map.json"
$MasterDbPath   = Join-Path $ScriptsDir "policy_master_db.json"
$CsvPath        = Join-Path $env:USERPROFILE "Desktop\Policy.csv"

# 共通モジュール読み込み
$CommonScript = Join-Path $ScriptsDir "AIG-Common.ps1"
if (-not (Test-Path $CommonScript)) { Write-Error "共通モジュールが見つかりません: $CommonScript"; Pause; exit }
. $CommonScript

$SourceColumns  = @("証券番号", "契約者 氏名漢字", "始期年月日", "満期年月日", "保険種目", "保険種類", "合計保険料")
$DisplayColumns = @("証券番号", "契約者 氏名漢字", "保険期間", "保険種目", "保険種類", "合計保険料")

# ====== メイン処理 ======
try {
    Write-Host "処理を開始（契約一覧）..."
    if (-not (Test-Path $CsvPath)) { throw "CSVなし: $CsvPath" }
    Ensure-Directory $CustomerRoot

    $allCsvData = Import-CsvSafe $CsvPath
    # 空チェック追加
    if ($allCsvData.Count -eq 0) { throw "CSVデータが空です。" }

    $folderMap  = Load-Json-Compatible $MapJsonPath
    $masterDb   = Load-Json-Compatible $MasterDbPath
    $existFolders = Get-ChildItem $CustomerRoot -Directory | Select-Object -ExpandProperty Name
    $today = (Get-Date).Date
    $newCount = 0; $updCount = 0

    # 1. DB更新
    foreach ($row in $allCsvData) {
        $br = [string]$row."証券番号枝番"
        if (-not [string]::IsNullOrWhiteSpace($br)) { continue } # 枝番除外

        $key = [string]$row."証券番号"
        if ([string]::IsNullOrWhiteSpace($key)) { continue }

        $rawName = [string]$row."契約者 氏名漢字"
        $lookupKey = Get-LookupKey $rawName
        
        $item = [ordered]@{}
        foreach ($col in $SourceColumns) { $item[$col] = $row.$col }
        $item["_SourceKey"] = $lookupKey
        $masterDb[$key] = [pscustomobject]$item
    }

    # 2. 振り分け
    $folderGroups = @{} 
    $validKeys = @()

    foreach ($key in $masterDb.Keys) {
        $item = $masterDb[$key]
        $start = Parse-DateSafe $item."始期年月日"
        $end   = Parse-DateSafe $item."満期年月日"

        if ($start -and $end -and ($start -le $today -and $today -le $end)) {
            $validKeys += $key
            
            $srcName = $null
            try { $srcName = [string]$item."_SourceKey" } catch { $srcName = "" }
            if ([string]::IsNullOrWhiteSpace($srcName)) {
                $rawName = [string]$item."契約者 氏名漢字"
                $srcName = Get-LookupKey $rawName
            }

            $folderName = ""
            if ($folderMap.ContainsKey($srcName)) {
                $folderName = $folderMap[$srcName]
            } else {
                $folderName = Ask-UserForFolder $srcName $existFolders
                $folderMap[$srcName] = $folderName
                Save-Json $folderMap $MapJsonPath
                if ($existFolders -notcontains $folderName) { $existFolders += $folderName }
            }

            if (-not $folderGroups.ContainsKey($folderName)) { $folderGroups[$folderName] = @() }
            $folderGroups[$folderName] += $item
        }
    }

    # 3. 保存 & 書き出し
    $newMasterDb = @{}
    foreach ($k in $validKeys) { $newMasterDb[$k] = $masterDb[$k] }
    Save-Json $newMasterDb $MasterDbPath

    Write-Host "Markdownファイルを更新中..."
    foreach ($fName in $folderGroups.Keys) {
        $rows = $folderGroups[$fName]
        $targetDir = Join-Path $CustomerRoot $fName
        Ensure-Directory $targetDir
        $mdPath = Join-Path $targetDir "✡️一覧_$fName.md"
        $isUpdate = Test-Path $mdPath
        
        $existingYaml = ""
        if ($isUpdate) {
            try {
                $rawContent = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
                if ($rawContent -match '^(?s)---\r?\n.*?\r?\n---\r?\n') { $existingYaml = $matches[0] }
            } catch {}
        }

        $sb = New-Object System.Text.StringBuilder
        if (-not [string]::IsNullOrEmpty($existingYaml)) { [void]$sb.Append($existingYaml) }
        [void]$sb.AppendLine("- 更新日: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
        [void]$sb.AppendLine("## 契約一覧")
        [void]$sb.AppendLine("| " + ($DisplayColumns -join " | ") + " |")
        [void]$sb.AppendLine("| " + (($DisplayColumns | %{"---"}) -join " | ") + " |")

        $rows = $rows | Sort-Object { $_."保険種目" }, { $_."保険種類" }

        foreach ($r in $rows) {
            $line = @()
            foreach ($col in $DisplayColumns) {
                $val = ""
                if ($col -eq "保険期間") {
                    $sDate = Parse-DateSafe $r."始期年月日"
                    $eDate = Parse-DateSafe $r."満期年月日"
                    if ($sDate -and $eDate) {
                        $diff = $eDate.Year - $sDate.Year
                        if ($diff -lt 0) { $diff = 0 }
                        $val = "{0}({1}年)" -f $sDate.ToString("yyyy/MM/dd"), $diff
                    } else { $val = "-" }
                }
                elseif ($col -eq "合計保険料") {
                    $num = 0
                    $cleanVal = [string]$r."合計保険料" -replace ",", "" # カンマ除去
                    if ([decimal]::TryParse($cleanVal, [ref]$num)) { $val = "{0:N0}" -f $num } else { $val = $r."合計保険料" }
                }
                else { $val = [string]$r.$col }
                $line += $val -replace "\|", "\|"
            }
            [void]$sb.AppendLine("| " + ($line -join " | ") + " |")
        }

        try {
            Set-Content -Path $mdPath -Value $sb.ToString() -Encoding UTF8 -ErrorAction Stop
            if ($isUpdate) { $updCount++ } else { $newCount++ }
        } catch {
            Write-Host "書き込み失敗(スキップ): $mdPath" -ForegroundColor Red
        }
    }

    Write-Host "`n完了! 新規:$newCount 更新:$updCount" -ForegroundColor Cyan
    Write-Host "Enterキーを押して終了してください..."
    Pause
}
catch {
    Write-Host "`n============ エラーが発生しました ============" -ForegroundColor Red
    Write-Host "エラー内容: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "発生場所: $($_.InvocationInfo.ScriptLineNumber) 行目" -ForegroundColor Yellow
    Pause
}