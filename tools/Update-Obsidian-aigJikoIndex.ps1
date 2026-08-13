#requires -Version 5.1
<#
Script : Update-Obsidian-aigJikoIndex.ps1 (v1.1)
Description: 事故一覧生成（全量データ・共通モジュール使用・改善版）
#>

# ====== 設定 ======
$VaultRoot      = Join-Path $env:USERPROFILE "Documents\07Obsidian\【Vault】INS"
$CustomerRoot   = Join-Path $VaultRoot "01_顧客"
$ScriptsDir     = $PSScriptRoot
$MapJsonPath    = Join-Path $ScriptsDir "customer_folder_map.json"
$DesktopPath    = Join-Path $env:USERPROFILE "Desktop"

# 共通モジュール読み込み
$CommonScript = Join-Path $ScriptsDir "AIG-Common.ps1"
if (-not (Test-Path $CommonScript)) { Write-Error "共通モジュールが見つかりません: $CommonScript"; Pause; exit }
. $CommonScript

$DisplayColumns = @(
    "事故日", "状態", "事故内容", "保険種類", "証券番号", 
    "契約者名", "支払金額(合算)", "ClaimNo", "お問合せ番号", 
    "担当センター", "担当者", "担当者電話番号"
)

function Select-JikoCsv {
    $csvFiles = Get-ChildItem -Path $DesktopPath -Filter "JIKO_SHINCHOKU_*.csv" | Sort-Object Name -Descending
    if ($csvFiles.Count -eq 0) { throw "デスクトップに 'JIKO_SHINCHOKU_*.csv' が見つかりません。" }
    if ($csvFiles.Count -eq 1) { return $csvFiles[0].FullName }

    Write-Host "=== 事故進捗CSV 選択 ===" -ForegroundColor Cyan
    for ($i=0; $i -lt $csvFiles.Count; $i++) {
        Write-Host " [$($i+1)] $($csvFiles[$i].Name)"
    }
    $def = $csvFiles[0].Name
    Write-Host "`n[Enter]キーで最新 '$def' を使用します。" -ForegroundColor Green
    
    $inputVal = Read-Host "番号を選択 (Enterで決定)"
    if ([string]::IsNullOrWhiteSpace($inputVal)) { return $csvFiles[0].FullName }
    if ($inputVal -match '^\d+$' -and [int]$inputVal -le $csvFiles.Count) { 
        return $csvFiles[[int]$inputVal - 1].FullName 
    }
    return $csvFiles[0].FullName
}

# ====== メイン処理 ======
try {
    Write-Host "処理を開始（事故一覧）..."
    
    # CSV選択 & 読み込み
    $TargetCsvPath = Select-JikoCsv
    Write-Host "対象ファイル: $TargetCsvPath" -ForegroundColor Gray
    $allCsvData = Import-CsvSafe $TargetCsvPath
    
    # (A) 空データチェック
    if ($allCsvData.Count -eq 0) { throw "CSVデータが空です。" }
    
    # 必須列チェック
    $required = @("証券番号", "契約者名", "事故日", "状態", "ClaimNo")
    foreach ($col in $required) {
        if (-not ($allCsvData[0].PSObject.Properties.Name -contains $col)) {
            throw "必須列不足: CSVに '$col' がありません。"
        }
    }

    $folderMap = Load-Json-Compatible $MapJsonPath
    $existFolders = Get-ChildItem $CustomerRoot -Directory | Select-Object -ExpandProperty Name
    $today = (Get-Date).Date

    $folderGroups = @{} 
    $processedCount = 0
    $updateCount = 0

    # 1. データ解析 & フォルダ振り分け
    foreach ($row in $allCsvData) {
        $rawName = [string]$row."契約者名"
        $lookupKey = Get-LookupKey $rawName
        
        $folderName = ""
        if ($folderMap.ContainsKey($lookupKey)) {
            $folderName = $folderMap[$lookupKey]
        } else {
            $folderName = Ask-UserForFolder $lookupKey $existFolders
            $folderMap[$lookupKey] = $folderName
            Save-Json $folderMap $MapJsonPath
            if ($existFolders -notcontains $folderName) { $existFolders += $folderName }
        }

        # 存在チェック (Mapにあっても実フォルダがない場合の対策)
        $targetDir = Join-Path $CustomerRoot $folderName
        if (-not (Test-Path $targetDir)) {
             Write-Host "警告: フォルダ '$folderName' が見つかりません。再指定してください。" -ForegroundColor Yellow
             $folderName = Ask-UserForFolder $lookupKey $existFolders
             $folderMap[$lookupKey] = $folderName
             Save-Json $folderMap $MapJsonPath
             # (B) 修正後もフォルダリストに追加
             if ($existFolders -notcontains $folderName) { $existFolders += $folderName }
        }

        if (-not $folderGroups.ContainsKey($folderName)) { $folderGroups[$folderName] = @() }
        $folderGroups[$folderName] += $row
    }

    # 2. Markdown生成
    Write-Host "Markdownファイルを更新中..."
    foreach ($fName in $folderGroups.Keys) {
        $rows = $folderGroups[$fName]
        $targetDir = Join-Path $CustomerRoot $fName
        Ensure-Directory $targetDir
        $mdPath = Join-Path $targetDir "⛔一覧_$fName.md"
        $isUpdate = Test-Path $mdPath

        $listActive = @()
        $listDoneRecent = @()

        foreach ($r in $rows) {
            $st = [string]$r."状態"
            $dtStr = [string]$r."事故日"
            $dt = Parse-DateSafe $dtStr

            if ($st -ne "完了") {
                $listActive += $r
            } elseif ($dt -and $dt -ge $today.AddDays(-365)) {
                $listDoneRecent += $r
            }
        }

        if ($listActive.Count -eq 0 -and $listDoneRecent.Count -eq 0) { continue }

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
        
        $WriteSection = {
            param($title, $dataList)
            if ($dataList.Count -gt 0) {
                [void]$sb.AppendLine("## $title")
                [void]$sb.AppendLine("| " + ($DisplayColumns -join " | ") + " |")
                [void]$sb.AppendLine("| " + (($DisplayColumns | %{"---"}) -join " | ") + " |")
                
                $sorted = $dataList | Sort-Object @{Expression={
                    $d = Parse-DateSafe $_."事故日"; if($d){$d}else{[DateTime]::MaxValue} 
                }}

                foreach ($r in $sorted) {
                    $line = @()
                    foreach ($col in $DisplayColumns) {
                        $val = ""
                        if ($col -eq "支払金額(合算)") {
                            $num = 0
                            # (C) カンマ除去後にパース
                            $cleanVal = [string]$r.$col -replace ",", ""
                            if ([decimal]::TryParse($cleanVal, [ref]$num)) { $val = "{0:N0}" -f $num } 
                            else { $val = $r.$col }
                        } else {
                            $val = [string]$r.$col
                            if ($col -eq "事故日" -and [string]::IsNullOrWhiteSpace($val)) { $val = "不明" }
                        }
                        $line += $val -replace "\|", "\|"
                    }
                    [void]$sb.AppendLine("| " + ($line -join " | ") + " |")
                }
                [void]$sb.AppendLine("")
            }
        }

        & $WriteSection "🚨 対応中" $listActive
        & $WriteSection "✅ 完了（1年以内）" $listDoneRecent

        try {
            Set-Content -Path $mdPath -Value $sb.ToString() -Encoding UTF8 -ErrorAction Stop
            $updateCount++
        } catch {
            Write-Host "書き込み失敗(スキップ): $mdPath" -ForegroundColor Red
        }
    }

    Write-Host "`n完了! 更新ファイル数: $updateCount" -ForegroundColor Cyan
    Write-Host "Enterキーを押して終了してください..."
    Pause
}
catch {
    Write-Host "`n============ エラーが発生しました ============" -ForegroundColor Red
    Write-Host "エラー内容: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "発生場所: $($_.InvocationInfo.ScriptLineNumber) 行目" -ForegroundColor Yellow
    Pause
}