<#
=====================================================
Run-MergeTests.ps1
Customer Folder Merge v1 - Windows PowerShell 5.1 Test Harness
(M01-M82 Mandatory Semantic & Structural RED Test Matrix - Step 3P)

【目的】
FM-Obsidian-Bridge-Payload.ps1 に対し、M01〜M82 の全テストケースを
1. DIRECT_EXECUTION (実機フィクスチャ構築 + Unicodeコードポイント等の独立事前検証 PreconditionPass 必須)
2. STATIC_CAPABILITY (機械的観測に基づくコンポーネント検出 + 4状態遷移モデル + 複合要件 False-GREEN ガード)
3. NOT_EXECUTABLE_PRE_IMPLEMENTATION (実装前実行不可・理由 & 活性化条件明記 + 活性化到達時強制再評価ガード)
として厳格に実行・検査する。
部分実装状態を HARNESS_DEFECT ではなく正当な RED 状態として処理し、全要件充足時のみ PASS_EXISTING とする。
=====================================================
#>

[CmdletBinding()]
param(
  [string]$TargetScript = "",
  [string]$TestRoot = "",
  [string]$PowerShellExe = "powershell.exe",
  [string]$ProductionVaultRoot = "C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS",
  [string]$ExpectedTargetSha256 = "3C37D4818D89050BC3F22740A40F3FDC42F714182F4131894A2359AB733AB059"
)

if ([string]::IsNullOrWhiteSpace($TargetScript)) {
  $TargetScript = "D:\FM-Script-Backup\FM-Obsidian-Bridge-Payload.ps1"
}
if ([string]::IsNullOrWhiteSpace($TestRoot)) {
  $TestRoot = Join-Path $PSScriptRoot "TestVault_MERGE"
}

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:Results = New-Object System.Collections.Generic.List[object]
$script:SafetyChecks = New-Object System.Collections.Generic.List[object]

function Record-TestResult {
  param(
    [string]$Id,
    [string]$Name,
    [string]$TestType, # "DIRECT_EXECUTION", "STATIC_CAPABILITY", "NOT_EXECUTABLE_PRE_IMPLEMENTATION", "SYNTAX"
    [string]$Status,   # "PASS_EXISTING", "EXECUTED_EXPECTED_RED", "STATIC_CAPABILITY_RED", "NOT_EXECUTABLE_PRE_IMPLEMENTATION", "UNEXPECTED_RED", "HARNESS_DEFECT"
    [string]$EvidenceAuthority = "", # "DIRECT_PRECONDITION_PROOF", "NORMATIVE_FROZEN_LITERAL", "NORMATIVE_API_PRIMITIVE", "STRUCTURAL_CONTROL_FLOW_ABSENCE", "N/A"
    [string]$NormativeLiteral = "",
    [bool]$DispatchBranchFound = $false,
    [string]$ReachableFunctions = "",
    [string]$ReachableMutationPrimitives = "",
    [string]$ReachableJournalSymbols = "",
    [string]$ReachableStateSymbols = "",
    [string]$StructuralProofResult = "",
    [string[]]$RequiredComponents = @(),
    [string[]]$ObservedComponents = @(),
    [string[]]$MissingComponents = @(),
    [string]$GreenPredicate = "",
    [string]$SemanticAbsenceReason = "",
    [string]$PreconditionsRequired = "",
    [string]$PreconditionsObserved = "",
    [bool]$PreconditionPass = $true,
    [string]$ExecutionPerformed = "",
    [string]$AssertionPerformed = "",
    [string]$ActualEvidence = "",
    [string]$ActivationBoundary = "", # 機械可読な能力境界識別子
    [string]$ActivationCondition = "",
    [string]$EnvironmentRequirement = "NONE", # "NONE", "NTFS_8DOT3_NAME_AVAILABLE", "NTFS_CASE_SENSITIVE_DIRECTORY_CREATABLE", "DETERMINISTIC_LATENCY_SEAM_AVAILABLE", "ACTIVE_LOCK_ACCESS_DENIED_CREATABLE"
    [bool]$CodeCapabilityReachable = $false,
    [bool]$EnvironmentRequirementSatisfied = $true,
    [bool]$ExecutableNow = $false,
    [string]$Category = "Merge"
  )

  # Step 3P: 到達可能性および環境要件の機械的解決
  if (-not [string]::IsNullOrWhiteSpace($ActivationBoundary)) {
    $CodeCapabilityReachable = Test-ActivationBoundaryReached -BoundaryName $ActivationBoundary -ScriptAst $targetAst -ScriptText $targetScriptText
    $EnvironmentRequirementSatisfied = Test-EnvironmentRequirementSatisfied -RequirementName $EnvironmentRequirement -TestRootPath $TestRoot
    $ExecutableNow = ($CodeCapabilityReachable -and $EnvironmentRequirementSatisfied)
  }

  # セマンティック厳格化ガード: DIRECT_EXECUTION で PreconditionPass が false の場合はテストフィクスチャ構築欠陥 (HARNESS_DEFECT)
  if ($TestType -eq "DIRECT_EXECUTION" -and (-not $PreconditionPass)) {
    $Status = "HARNESS_DEFECT"
    $ActualEvidence = "HARNESS_PRECONDITION_DEFECT: $PreconditionsRequired vs Observed: $PreconditionsObserved"
  }

  # 部分実装セマンティクス是正: 複合 STATIC_CAPABILITY で MissingComponents が残っている場合、
  # PASS_EXISTING は禁止され、正当な部分実装 RED (STATIC_CAPABILITY_RED) として分類する (HARNESS_DEFECT にしない)
  if ($TestType -eq "STATIC_CAPABILITY" -and $MissingComponents.Count -gt 0 -and $Status -eq "PASS_EXISTING") {
    $Status = "STATIC_CAPABILITY_RED"
    $ActualEvidence = "PARTIAL_IMPLEMENTATION_RED: Missing components ($($MissingComponents -join ', ')) prevent PASS_EXISTING"
  }

  $script:Results.Add([ordered]@{
    Id = $Id
    Name = $Name
    TestType = $TestType
    Status = $Status
    EvidenceAuthority = $EvidenceAuthority
    NormativeLiteral = $NormativeLiteral
    DispatchBranchFound = $DispatchBranchFound
    ReachableFunctions = $ReachableFunctions
    ReachableMutationPrimitives = $ReachableMutationPrimitives
    ReachableJournalSymbols = $ReachableJournalSymbols
    ReachableStateSymbols = $ReachableStateSymbols
    StructuralProofResult = $StructuralProofResult
    RequiredComponents = $RequiredComponents
    ObservedComponents = $ObservedComponents
    MissingComponents = $MissingComponents
    GreenPredicate = $GreenPredicate
    SemanticAbsenceReason = $SemanticAbsenceReason
    PreconditionsRequired = $PreconditionsRequired
    PreconditionsObserved = $PreconditionsObserved
    PreconditionPass = $PreconditionPass
    ExecutionPerformed = $ExecutionPerformed
    AssertionPerformed = $AssertionPerformed
    ActualEvidence = $ActualEvidence
    ActivationBoundary = $ActivationBoundary
    ActivationCondition = $ActivationCondition
    EnvironmentRequirement = $EnvironmentRequirement
    CodeCapabilityReachable = $CodeCapabilityReachable
    EnvironmentRequirementSatisfied = $EnvironmentRequirementSatisfied
    ExecutableNow = $ExecutableNow
    Category = $Category
  })
  
  $color = switch ($Status) {
    "PASS_EXISTING" { "Green" }
    "EXECUTED_EXPECTED_RED" { "Yellow" }
    "STATIC_CAPABILITY_RED" { "DarkYellow" }
    "NOT_EXECUTABLE_PRE_IMPLEMENTATION" { "Cyan" }
    "UNEXPECTED_RED" { "Red" }
    "HARNESS_DEFECT" { "Magenta" }
    default { "White" }
  }
  Write-Host "[$Status] $Id - $Name ($TestType)" -ForegroundColor $color
  if ($TestType -eq "DIRECT_EXECUTION") {
    Write-Host "       Precondition: $(if($PreconditionPass){'PASS'}else{'FAIL'}) | $PreconditionsObserved" -ForegroundColor DarkGray
  } elseif ($TestType -eq "STATIC_CAPABILITY") {
    Write-Host "       Authority: $EvidenceAuthority | Literal: $NormativeLiteral" -ForegroundColor DarkGray
    if ($RequiredComponents.Count -gt 0) {
      Write-Host "       Components: $($ObservedComponents.Count)/$($RequiredComponents.Count) satisfied | Missing: $($MissingComponents.Count)" -ForegroundColor DarkGray
      Write-Host "       GreenPredicate: $GreenPredicate" -ForegroundColor DarkGray
    }
    Write-Host "       Structural: $StructuralProofResult" -ForegroundColor DarkGray
  }
  Write-Host "       Evidence: $ActualEvidence" -ForegroundColor DarkGray
  if (-not [string]::IsNullOrWhiteSpace($ActivationBoundary)) {
    Write-Host "       ActivationBoundary: $ActivationBoundary | EnvReq: $EnvironmentRequirement | ExecutableNow: $ExecutableNow" -ForegroundColor DarkCyan
  }
}

function Record-SafetyCheck {
  param([string]$Name, [bool]$Pass, [string]$Detail)
  $script:SafetyChecks.Add([ordered]@{ Name=$Name; Pass=$Pass; Detail=$Detail })
  $mark = if ($Pass) { "PASS" } else { "FAIL" }
  $color = if ($Pass) { "Green" } else { "Red" }
  Write-Host "[$mark][安全確認] $Name" -ForegroundColor $color
  if (-not $Pass) { Write-Host "       -> $Detail" -ForegroundColor Yellow }
}

function Assert-Environment {
  $edition = $PSVersionTable.PSEdition
  if ($null -eq $edition) { $edition = "Desktop" }
  $v = $PSVersionTable.PSVersion
  $isPs51Desktop = ($edition -eq "Desktop" -and $v.Major -eq 5 -and $v.Minor -eq 1)
  Record-SafetyCheck "実行環境: Windows PowerShell 5.1 Desktop" $isPs51Desktop "PSVersion: $v, PSEdition: $edition"
  if (-not $isPs51Desktop) { throw "Windows PowerShell 5.1 Desktop 環境でのみ実行可能です。" }

  $targetExists = Test-Path -LiteralPath $TargetScript -PathType Leaf
  Record-SafetyCheck "対象スクリプト存在確認" $targetExists "TargetScript: $TargetScript"
  if (-not $targetExists) { throw "対象スクリプトが存在しません: $TargetScript" }

  $curHash = (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash
  $hashMatch = ($curHash.ToUpperInvariant() -eq $ExpectedTargetSha256.ToUpperInvariant())
  Record-SafetyCheck "対象スクリプト開始時SHA256確認" $hashMatch "Expected: $ExpectedTargetSha256, Actual: $curHash"
  if (-not $hashMatch) { throw "対象スクリプトのSHA256が期待値と一致しません。" }

  $resolvedTestRoot = [System.IO.Path]::GetFullPath($TestRoot)
  $resolvedProdVault = [System.IO.Path]::GetFullPath($ProductionVaultRoot)
  $isSafeRoot = (-not $resolvedTestRoot.StartsWith($resolvedProdVault, [System.StringComparison]::OrdinalIgnoreCase))
  Record-SafetyCheck "TestRoot絶対パス安全確認 (本番Vault外)" $isSafeRoot "TestRoot: $resolvedTestRoot, ProdVault: $resolvedProdVault"
  if (-not $isSafeRoot) { throw "TestRootが本番Vault配下に指定されています。危険なため中止します。" }
}

function Reset-TestVault {
  param([string]$VaultPath)
  if (Test-Path -LiteralPath $VaultPath) {
    Remove-Item -LiteralPath $VaultPath -Recurse -Force -ErrorAction SilentlyContinue
  }
  New-Item -ItemType Directory -Path $VaultPath -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $VaultPath "01_顧客") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $VaultPath "scripts") -Force | Out-Null
}

function Write-MockFile {
  param([string]$FilePath, [string]$Content)
  $parent = Split-Path -Parent $FilePath
  if (-not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($FilePath, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Create-MockNote {
  param(
    [string]$FolderPath,
    [string]$FileName,
    [string]$Uuid,
    [string]$NoteType,
    [string]$Rank = "A",
    [string]$Body = "本文テキスト"
  )
  if (-not (Test-Path -LiteralPath $FolderPath)) {
    New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
  }
  $filePath = Join-Path $FolderPath $FileName
  $content = "---`ntags:`n  - `"テスト顧客`"`nUUID: $Uuid`nランク: $Rank`n---`n$Body"
  [System.IO.File]::WriteAllText($filePath, $content, [System.Text.UTF8Encoding]::new($false))
  $filePath | Out-Null
}

function Invoke-BridgePayload {
  param(
    [string]$TargetScriptPath,
    [hashtable]$PayloadHash,
    [string]$PowerShellExePath = "powershell.exe"
  )
  $json = $PayloadHash | ConvertTo-Json -Depth 10 -Compress
  $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
  
  $tmpPayloadFile = [System.IO.Path]::GetTempFileName()
  [System.IO.File]::WriteAllText($tmpPayloadFile, $b64, [System.Text.UTF8Encoding]::new($false))
  
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $PowerShellExePath
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$TargetScriptPath`" -PayloadFile `"$tmpPayloadFile`""
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

  $p = [System.Diagnostics.Process]::Start($psi)
  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  $exitCode = $p.ExitCode
  
  try { Remove-Item -LiteralPath $tmpPayloadFile -Force -ErrorAction SilentlyContinue } catch {}

  $jsonParsed = $null
  try {
    $trimmed = $stdout.Trim()
    if ($trimmed.StartsWith("{") -and $trimmed.EndsWith("}")) {
      $jsonParsed = ConvertFrom-Json $trimmed
    }
  } catch {}

  return [ordered]@{
    ExitCode = $exitCode
    Stdout = $stdout
    Stderr = $stderr
    Json = $jsonParsed
  }
}

Assert-Environment

$targetAstErrors = $null
$targetTokens = $null
$targetAst = [System.Management.Automation.Language.Parser]::ParseFile($TargetScript, [ref]$targetTokens, [ref]$targetAstErrors)
$syntaxPass = ($null -eq $targetAstErrors -or $targetAstErrors.Count -eq 0)
Record-TestResult -Id "SYNTAX" -Name "対象スクリプト構文確認 (PS5.1 AST)" -TestType "SYNTAX" `
  -Status $(if ($syntaxPass) { "PASS_EXISTING" } else { "UNEXPECTED_RED" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "TargetScript file exists and is readable" `
  -PreconditionsObserved "File exists, SHA256 verified" `
  -PreconditionPass $true `
  -ExecutionPerformed "Parser::ParseFile($TargetScript)" `
  -AssertionPerformed "AST error count == 0" `
  -ActualEvidence "AST error count: $($targetAstErrors.Count)"

$targetScriptText = [System.IO.File]::ReadAllText($TargetScript, [System.Text.Encoding]::UTF8)

# ===================== 構造解析エンジン (Structural Reachability Engine) =====================

# 1. 本番スクリプトの全アクションディスパッチを抽出
$script:DispatchedActions = @()
$ifStatements = $targetAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.IfStatementAst] }, $true)
foreach ($ifStmt in $ifStatements) {
  foreach ($clause in $ifStmt.Clauses) {
    $testText = $clause.Item1.Extent.Text
    if ($testText -match 'action|uciActionValue') {
      $strAsts = $clause.Item1.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)
      foreach ($s in $strAsts) {
        if ($s.Value -match '^[A-Z_]+$') {
          $script:DispatchedActions += $s.Value
        }
      }
    }
  }
}
$script:DispatchedActions = @($script:DispatchedActions | Select-Object -Unique)
Write-Host "Discovered Production Dispatched Actions: $($script:DispatchedActions -join ', ')" -ForegroundColor Gray

# 2. 指定アクションのディスパッチ分岐存在判定
function Test-ActionDispatchBranch {
  param([string]$ActionName)
  return ($script:DispatchedActions -contains $ActionName)
}

# 3. 指定アクションから到達可能なトランザクション／状態マシン構造解析
function Get-StructuralReachabilityProof {
  param(
    [string]$ActionName = "APPLY_CUSTOMER_FOLDER_MERGE",
    [string]$TargetCapabilityDescription = ""
  )
  $branchFound = Test-ActionDispatchBranch $ActionName
  if (-not $branchFound) {
    return [ordered]@{
      DispatchBranchFound = $false
      ReachableFunctions = "None (0 reachable functions from $ActionName dispatch)"
      ReachableMutationPrimitives = "None"
      ReachableJournalSymbols = "None"
      ReachableStateSymbols = "None"
      ProofResult = "AST Structural Proof: Action dispatch branch '$ActionName' is absent from production script. No reachable transaction engine, journal state machine, or mutation control flow exists."
      AbsenceProven = $true
    }
  } else {
    return [ordered]@{
      DispatchBranchFound = $true
      ReachableFunctions = "Branch found"
      ReachableMutationPrimitives = "Inspecting"
      ReachableJournalSymbols = "Inspecting"
      ReachableStateSymbols = "Inspecting"
      ProofResult = "Action dispatch branch '$ActionName' is present."
      AbsenceProven = $false
    }
  }
}

# 構造検査ヘルパー: 規範的識別子リテラル存在検査
function Assert-TargetSymbolAbsent {
  param([string]$Symbol)
  return (-not $targetScriptText.Contains($Symbol))
}

# 構造検査ヘルパー: メンバー/呼び出し式検査
function Assert-TargetMemberCallAbsent {
  param([string]$TypeOrVar, [string]$MemberName)
  $calls = $targetAst.FindAll({
    param($ast)
    if ($ast -is [System.Management.Automation.Language.MemberExpressionAst] -or $ast -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
      return ($ast.Member.Extent.Text -eq $MemberName)
    }
    return $false
  }, $true)
  return ($null -eq $calls -or $calls.Count -eq 0)
}

# ===================== AST 到達可能性グラフ解析エンジン (AST Reachability Graph Engine) =====================
function Get-ActionReachabilityContext {
  param(
    [string]$ActionName,
    [System.Management.Automation.Language.ScriptBlockAst]$ScriptAst = $targetAst,
    [string]$ScriptText = $targetScriptText
  )

  # 1. 全関数定義のマップ化
  $funcDefMap = @{}
  $funcDefs = $ScriptAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
  foreach ($fd in $funcDefs) {
    $funcDefMap[$fd.Name] = $fd
  }

  # 2. アクションディスパッチ分岐の探索
  $targetClauses = @()
  $ifStatements = $ScriptAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] }, $true)
  foreach ($ifStmt in $ifStatements) {
    foreach ($clause in $ifStmt.Clauses) {
      $condText = $clause.Item1.Extent.Text
      if ($condText -match [regex]::Escape($ActionName)) {
        $targetClauses += $clause.Item2 # StatementBlockAst
      }
    }
  }

  $switchStatements = $ScriptAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.SwitchStatementAst] }, $true)
  foreach ($swStmt in $switchStatements) {
    foreach ($clause in $swStmt.Clauses) {
      $clauseMatch = $clause.Item1.Extent.Text
      if ($clauseMatch -match [regex]::Escape($ActionName)) {
        $targetClauses += $clause.Item2
      }
    }
  }

  if ($targetClauses.Count -eq 0) {
    return [ordered]@{
      ActionName = $ActionName
      BranchFound = $false
      ReachableAstNodes = @()
      ReachableFunctions = @()
      ReachableText = ""
    }
  }

  # 3. 再帰的到達可能性グラフ探索 (BFS)
  $visitedFunctions = New-Object System.Collections.Generic.HashSet[string]
  $queue = New-Object System.Collections.Generic.Queue[System.Management.Automation.Language.Ast]
  foreach ($tc in $targetClauses) {
    $queue.Enqueue($tc)
  }

  $allReachableNodes = New-Object System.Collections.Generic.List[System.Management.Automation.Language.Ast]
  $reachableTextBuilder = New-Object System.Text.StringBuilder

  while ($queue.Count -gt 0) {
    $currAst = $queue.Dequeue()
    $allReachableNodes.Add($currAst)
    [void]$reachableTextBuilder.AppendLine($currAst.Extent.Text)

    # 呼び出される関数を探索
    $commands = $currAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($cmd in $commands) {
      $cmdName = $cmd.GetCommandName()
      if (-not [string]::IsNullOrWhiteSpace($cmdName)) {
        if ($funcDefMap.ContainsKey($cmdName) -and (-not $visitedFunctions.Contains($cmdName))) {
          [void]$visitedFunctions.Add($cmdName)
          $queue.Enqueue($funcDefMap[$cmdName].Body)
        }
      }
    }
  }

  return [ordered]@{
    ActionName = $ActionName
    BranchFound = $true
    ReachableAstNodes = $allReachableNodes
    ReachableFunctions = @($visitedFunctions)
    ReachableText = $reachableTextBuilder.ToString()
  }
}

# ===================== 環境要件適合判定 (Environment Requirement Checker) =====================
function Test-EnvironmentRequirementSatisfied {
  param(
    [string]$RequirementName,
    [string]$TestRootPath = $TestRoot
  )
  switch ($RequirementName) {
    "NONE" {
      return $true
    }
    "NTFS_8DOT3_NAME_AVAILABLE" {
      # ホスト NTFS ボリュームで 8.3 短縮名が生成可能か動的プローブ
      $probeDir = Join-Path $TestRootPath "Probe_8dot3"
      try {
        if (Test-Path -LiteralPath $probeDir) { Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
        $probeFile = Join-Path $probeDir "very_long_filename_for_8dot3_probe.txt"
        [System.IO.File]::WriteAllText($probeFile, "probe", [System.Text.Encoding]::UTF8)
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $f = $fso.GetFile($probeFile)
        $shortPath = $f.ShortPath
        $hasShort = (-not [string]::IsNullOrWhiteSpace($shortPath)) -and ($shortPath -ne $probeFile) -and ($shortPath.Contains("~"))
        Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue
        return $hasShort
      } catch {
        return $false
      }
    }
    "NTFS_CASE_SENSITIVE_DIRECTORY_CREATABLE" {
      # 非特権プロセスで per-directory case sensitivity が設定可能か動的プローブ
      $probeDir = Join-Path $TestRootPath "Probe_CaseSensitive"
      try {
        if (Test-Path -LiteralPath $probeDir) { Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue }
        New-Item -ItemType Directory -Path $probeDir -Force | Out-Null
        $null = (& fsutil file setCaseSensitiveInfo $probeDir enable 2>&1)
        $queryOut = (& fsutil file queryCaseSensitiveInfo $probeDir 2>&1) | Out-String
        $canSet = ($queryOut -match 'enabled|Enabled') -and ($queryOut -notmatch 'disabled|Disabled')
        Remove-Item -LiteralPath $probeDir -Recurse -Force -ErrorAction SilentlyContinue
        return $canSet
      } catch {
        return $false
      }
    }
    "DETERMINISTIC_LATENCY_SEAM_AVAILABLE" {
      return $false
    }
    "ACTIVE_LOCK_ACCESS_DENIED_CREATABLE" {
      return $true
    }
    default {
      return $true
    }
  }
}

# ===================== ロック取得 AST 構文検査 (Lock Acquisition AST Validator) =====================
function Test-LockAcquisitionValid {
  param(
    [System.Management.Automation.Language.ScriptBlockAst]$ScriptAst = $targetAst,
    [string]$ScriptText = $targetScriptText
  )
  # AST 上で ACTIVE.lock と FileShare.None が同一の FileStream 構築式に含まれているかを検証
  $newStreamCalls = $ScriptAst.FindAll({
    param($n)
    if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
      if ($n.Member.Extent.Text -eq "new" -and $n.Expression.Extent.Text -match '\[System\.IO\.FileStream\]') {
        $callText = $n.Extent.Text
        return ($callText -match 'ACTIVE\.lock' -and $callText -match 'FileShare\]::None')
      }
    }
    if ($n -is [System.Management.Automation.Language.CommandAst]) {
      if ($n.GetCommandName() -eq "New-Object") {
        $cmdText = $n.Extent.Text
        return ($cmdText -match 'System\.IO\.FileStream' -and $cmdText -match 'ACTIVE\.lock' -and $cmdText -match 'FileShare\]::None')
      }
    }
    return $false
  }, $true)

  return ($newStreamCalls.Count -gt 0)
}

# ヘルパー: ノードの直近レキシカルスコープ（FunctionDefinitionAst または StatementBlockAst）を取得
function Get-NearestScopeAst {
  param([System.Management.Automation.Language.Ast]$Node)
  $curr = $Node.Parent
  while ($null -ne $curr) {
    if ($curr -is [System.Management.Automation.Language.FunctionDefinitionAst] -or 
        $curr -is [System.Management.Automation.Language.NamedBlockAst] -or
        $curr -is [System.Management.Automation.Language.StatementBlockAst]) {
      return $curr
    }
    $curr = $curr.Parent
  }
  return $null
}

# ヘルパー: 実質的操作ステートメント（ファイル操作・ビジネスヘルパー呼出し等）か判定
function Test-IsSubstantiveStatement {
  param([System.Management.Automation.Language.Ast]$Stmt)
  $cmds = $Stmt.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
  foreach ($c in $cmds) {
    $cName = $c.GetCommandName()
    if ($cName -and $cName -notmatch '^(Write-Host|Write-Verbose|Write-Debug|Write-Output|Out-Null|New-UCIResponse|Out-OK|Out-NG|Join-Path|Split-Path)$') {
      return $true
    }
  }
  
  $invokes = $Stmt.FindAll({
    param($n)
    if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
      if ($n.Member.Extent.Text -match '^(Dispose|Close)$') { return $false }
      return $true
    }
    return $false
  }, $true)
  if ($invokes.Count -gt 0) { return $true }

  return $false
}

function Test-TryEnclosureValidInScope {
  param(
    [System.Management.Automation.Language.TryStatementAst]$TryStmt,
    [System.Management.Automation.Language.Ast]$ScopeAst
  )
  if ($null -eq $TryStmt.Finally) { return $false }

  # 1. Finally 内の Dispose/Close 呼び出しから変数名を抽出
  $finallyDisposes = $TryStmt.Finally.FindAll({
    param($n)
    if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
      if ($n.Member.Extent.Text -match '^(Dispose|Close)$') {
        if ($n.Expression -is [System.Management.Automation.Language.VariableExpressionAst]) {
          return $true
        }
      }
    }
    return $false
  }, $true)

  if ($finallyDisposes.Count -eq 0) { return $false }

  foreach ($dispCall in $finallyDisposes) {
    $lockVarName = $dispCall.Expression.VariablePath.UserPath

    # 2. 同一 ScopeAst 内での ACTIVE.lock + FileShare.None 代入文を探索
    $assigns = $ScopeAst.FindAll({
      param($n)
      if ($n -is [System.Management.Automation.Language.AssignmentStatementAst]) {
        if ($n.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
          if ($n.Left.VariablePath.UserPath -eq $lockVarName) {
            $rText = $n.Right.Extent.Text
            if ($rText -match 'ACTIVE\.lock' -and $rText -match 'FileShare\]::None') {
              $assignScope = Get-NearestScopeAst $n
              return ($assignScope -eq $ScopeAst)
            }
          }
        }
      }
      return $false
    }, $true)

    if ($assigns.Count -eq 0) { continue }
    $assignNode = $assigns[0]

    # 代入位置が Try より前にあること
    if ($assignNode.Extent.StartOffset -ge $TryStmt.Extent.StartOffset) { continue }

    # 3. Pre-Acquisition 検査: 代入文より前に実質的ステートメントがないこと
    $statementsInScope = $ScopeAst.Statements
    $hasPreAcqWork = $false
    if ($null -ne $statementsInScope) {
      for ($si = 0; $si -lt $statementsInScope.Count; $si++) {
        $st = $statementsInScope[$si]
        if ($st.Extent.StartOffset -lt $assignNode.Extent.StartOffset) {
          if (Test-IsSubstantiveStatement $st) {
            $hasPreAcqWork = $true
            break
          }
        }
      }
    }
    if ($hasPreAcqWork) { continue }

    # 4. Try ブロック本体内で早期 Dispose/Close がないこと
    $earlyDisposes = $TryStmt.Body.FindAll({
      param($n)
      if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
        if ($n.Member.Extent.Text -match '^(Dispose|Close)$') {
          if ($n.Expression -is [System.Management.Automation.Language.VariableExpressionAst]) {
            if ($n.Expression.VariablePath.UserPath -eq $lockVarName) {
              return $true
            }
          }
        }
      }
      return $false
    }, $true)
    if ($earlyDisposes.Count -gt 0) { continue }

    # 5. Try ブロック本体にステートメントが存在すること
    if ($TryStmt.Body.Statements.Count -eq 0) { continue }

    # 6. Post-Finally 検査: Try より後に実質的ステートメントがないこと
    $hasPostFinallyWork = $false
    if ($null -ne $statementsInScope) {
      $tryIdx = -1
      for ($si = 0; $si -lt $statementsInScope.Count; $si++) {
        if ($statementsInScope[$si].Extent.StartOffset -eq $TryStmt.Extent.StartOffset) {
          $tryIdx = $si
          break
        }
      }
      if ($tryIdx -ge 0 -and $tryIdx -lt ($statementsInScope.Count - 1)) {
        for ($postI = $tryIdx + 1; $postI -lt $statementsInScope.Count; $postI++) {
          $postStmt = $statementsInScope[$postI]
          if (Test-IsSubstantiveStatement $postStmt) {
            $hasPostFinallyWork = $true
            break
          }
        }
      }
    }
    if ($hasPostFinallyWork) { continue }

    return $true
  }

  return $false
}

function Test-FunctionIsFullyLockProtected {
  param(
    [System.Management.Automation.Language.FunctionDefinitionAst]$FuncDefAst
  )
  if ($null -eq $FuncDefAst) { return $false }
  $tries = $FuncDefAst.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.TryStatementAst] }, $true)
  foreach ($t in $tries) {
    $scope = Get-NearestScopeAst $t
    if ($null -ne $scope) {
      if (Test-TryEnclosureValidInScope -TryStmt $t -ScopeAst $scope) {
        return $true
      }
    }
  }
  return $false
}

function Test-FunctionIsNonMaterial {
  param(
    [System.Management.Automation.Language.FunctionDefinitionAst]$FuncDefAst
  )
  if ($null -eq $FuncDefAst) { return $false }
  $stmts = $FuncDefAst.Body.FindAll({
    param($n)
    if ($n -is [System.Management.Automation.Language.StatementAst] -and $n.Parent -is [System.Management.Automation.Language.NamedBlockAst]) {
      return $true
    }
    return $false
  }, $true)
  if ($null -eq $stmts -or $stmts.Count -eq 0) { return $true }
  foreach ($s in $stmts) {
    if (Test-IsSubstantiveStatement $s) {
      return $false
    }
  }
  return $true
}

# ===================== レキシカルスコープ & セマンティック委譲検査 (Semantic Helper Delegation Detector) =====================
function Test-LockFullLifetimeEnclosure {
  param(
    [string]$ActionName,
    [System.Management.Automation.Language.ScriptBlockAst]$ScriptAst = $targetAst,
    [string]$ScriptText = $targetScriptText
  )
  $ctx = Get-ActionReachabilityContext -ActionName $ActionName -ScriptAst $ScriptAst -ScriptText $ScriptText
  if (-not $ctx.BranchFound) { return $false }

  $funcDefMap = @{}
  $funcDefs = $ScriptAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
  foreach ($fd in $funcDefs) {
    $funcDefMap[$fd.Name] = $fd
  }

  $dispatchClause = $ctx.ReachableAstNodes[0]

  # パターン 1: ディスパッチ節自体が直接 TryEnclosure を持っているか
  $directTries = $dispatchClause.FindAll({
    param($n)
    if ($n -is [System.Management.Automation.Language.TryStatementAst]) {
      $scope = Get-NearestScopeAst $n
      return ($scope -eq $dispatchClause)
    }
    return $false
  }, $false)

  foreach ($dt in $directTries) {
    if (Test-TryEnclosureValidInScope -TryStmt $dt -ScopeAst $dispatchClause) {
      return $true
    }
  }

  # パターン 2: ディスパッチ節がヘルパー呼び出し列で構成されている場合
  # ディスパッチ節内の全ステートメントを順番にセマンティック分類 (名前ヒューリスティクス完全排除)
  $dispatchStmts = $dispatchClause.Statements
  if ($null -eq $dispatchStmts -or $dispatchStmts.Count -eq 0) { return $false }

  $protectedHelperCount = 0
  $hasInvalidStatement = $false

  foreach ($ds in $dispatchStmts) {
    $commands = $ds.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    if ($commands.Count -eq 0) {
      if (Test-IsSubstantiveStatement $ds) {
        $hasInvalidStatement = $true
        break
      }
      continue
    }

    foreach ($cmd in $commands) {
      $cmdName = $cmd.GetCommandName()
      if (-not $cmdName) { continue }

      # 既知の非実質的コマンド (NON_MATERIAL)
      if ($cmdName -match '^(Write-Host|Write-Verbose|Write-Debug|Write-Output|Out-Null|New-UCIResponse|Out-OK|Out-NG|Join-Path|Split-Path)$') {
        continue
      }

      # ユーザー定義関数呼び出しの検証
      if ($funcDefMap.ContainsKey($cmdName)) {
        $fd = $funcDefMap[$cmdName]
        if (Test-FunctionIsNonMaterial -FuncDefAst $fd) {
          # NON_MATERIAL
          continue
        }
        if (Test-FunctionIsFullyLockProtected -FuncDefAst $fd) {
          # DELEGATES_TO_VALID_PROTECTED_REGION
          $protectedHelperCount++
          continue
        }
        # UNPROTECTED_MATERIAL
        $hasInvalidStatement = $true
        break
      } else {
        # UNKNOWN -> Fail-Closed
        $hasInvalidStatement = $true
        break
      }
    }

    if ($hasInvalidStatement) { break }
  }

  if ((-not $hasInvalidStatement) -and ($protectedHelperCount -eq 1)) {
    return $true
  }

  return $false
}

# ===================== 到達可能性ベース能力境界検出エンジン (Reachability-Bound Activation Detector) =====================
function Test-ActivationBoundaryReached {
  param(
    [string]$BoundaryName,
    [System.Management.Automation.Language.ScriptBlockAst]$ScriptAst = $targetAst,
    [string]$ScriptText = $targetScriptText
  )

  # APPLY アクションの到達可能性コンテキスト
  $applyCtx = Get-ActionReachabilityContext -ActionName "APPLY_CUSTOMER_FOLDER_MERGE" -ScriptAst $ScriptAst -ScriptText $ScriptText

  switch ($BoundaryName) {
    "APPLY_DISPATCH" {
      return $applyCtx.BranchFound
    }
    "APPLY_REQUEST_VALIDATION" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("INVALID_REQUEST") -and $applyCtx.ReachableText.Contains("planToken"))
    }
    "PLAN_TOKEN_VALIDATION" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("MERGE_PLAN_STALE") -and ($applyCtx.ReachableText.Contains("planToken") -or $applyCtx.ReachableText.Contains("expectedPlanToken")))
    }
    "TOPOLOGY_RESCAN" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("MERGE_PLAN_STALE") -and ($applyCtx.ReachableText.Contains("Get-CustomerFolderSnapshot") -or $applyCtx.ReachableText.Contains("topologyHash")))
    }
    "FILE_MOVE_ENGINE" {
      if (-not $applyCtx.BranchFound) { return $false }
      $moveFound = $false
      foreach ($node in $applyCtx.ReachableAstNodes) {
        $memberCalls = $node.FindAll({
          param($n)
          if ($n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]) {
            return ($n.Member.Extent.Text -eq "Move" -and $n.Expression.Extent.Text -match '\[System\.IO\.File\]')
          }
          return $false
        }, $true)
        if ($memberCalls.Count -gt 0) { $moveFound = $true; break }
      }
      return $moveFound
    }
    "FILE_MOVE_ENGINE_PREMOVE_HOOK" {
      $hasMove = Test-ActivationBoundaryReached "FILE_MOVE_ENGINE" -ScriptAst $ScriptAst -ScriptText $ScriptText
      if (-not $hasMove) { return $false }
      return ($applyCtx.ReachableText.Contains("TARGET_NOTE_FILENAME_CONFLICT") -and $applyCtx.ReachableText.Contains("Exists"))
    }
    "STAGING_EXCLUSIVE_CREATE" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("CreateDirectoryW") -and ($applyCtx.ReachableText.Contains("ERROR_ALREADY_EXISTS") -or $applyCtx.ReachableText.Contains("183")))
    }
    "STAGING_LIFECYCLE" {
      $hasExclusive = Test-ActivationBoundaryReached "STAGING_EXCLUSIVE_CREATE" -ScriptAst $ScriptAst -ScriptText $ScriptText
      if (-not $hasExclusive) { return $false }
      return ($applyCtx.ReachableText.Contains(".fm-obsidian-merge-owner") -and $applyCtx.ReachableText.Contains("CreateNew"))
    }
    "JOURNAL_ENGINE" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("MOVE_FILE") -and $applyCtx.ReachableText.Contains("RENAME_FILE") -and $applyCtx.ReachableText.Contains("PENDING"))
    }
    "ROLLBACK_ENGINE" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("MERGE_ROLLBACK_FAILED") -or $applyCtx.ReachableText.Contains("MERGE_FAILED_ROLLED_BACK"))
    }
    "FINAL_VERIFICATION" {
      if (-not $applyCtx.BranchFound) { return $false }
      return ($applyCtx.ReachableText.Contains("MERGE_COMPLETED") -and $applyCtx.ReachableText.Contains("MERGE_FAILED_ROLLED_BACK"))
    }
    "LOCK_ACQUISITION" {
      return (Test-LockAcquisitionValid -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_FULL_LIFETIME_OPEN" {
      return (Test-LockFullLifetimeEnclosure -ActionName "OPEN" -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_FULL_LIFETIME_CHECK" {
      return (Test-LockFullLifetimeEnclosure -ActionName "CHECK" -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_FULL_LIFETIME_COMPARE" {
      return (Test-LockFullLifetimeEnclosure -ActionName "COMPARE" -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_FULL_LIFETIME_PLAN" {
      return (Test-LockFullLifetimeEnclosure -ActionName "PLAN_CUSTOMER_FOLDER_MERGE" -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_FULL_LIFETIME_APPLY" {
      return (Test-LockFullLifetimeEnclosure -ActionName "APPLY_CUSTOMER_FOLDER_MERGE" -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_FULL_LIFETIME_UPDATE" {
      return (Test-LockFullLifetimeEnclosure -ActionName "UPDATE_CUSTOMER_IDENTITY" -ScriptAst $ScriptAst -ScriptText $ScriptText)
    }
    "LOCK_ACQUISITION_ACCESS_DENIED" {
      $hasLock = Test-ActivationBoundaryReached "LOCK_ACQUISITION" -ScriptAst $ScriptAst -ScriptText $ScriptText
      return ($hasLock -and $ScriptText.Contains("MERGE_CONTROL_ACCESS_DENIED"))
    }
    "PATH_RESOLVER" {
      return ($ScriptText.Contains("GetLongPathNameW") -and $ScriptText.Contains("MERGE_PATH_IDENTITY_UNRESOLVED"))
    }
    "CUSTOMER_SCAN_EMPTY_FOLDER_TOLERANCE" {
      return ($ScriptText.Contains("TolerateEmptyFolder") -or ($ScriptText.Contains("01_顧客") -and $ScriptText.Contains("AllowEmpty")))
    }
    "SCAN_ENGINE_LATENCY_SEAM" {
      return ($ScriptText.Contains("TestHook_ScanLatency") -or $ScriptText.Contains("TestSeam_LatencyInjection"))
    }
    "PATH_RESOLVER_SHORT_NAME_SUPPORT" {
      return ($ScriptText.Contains("GetLongPathNameW") -and $ScriptText.Contains("ShortPathResolved"))
    }
    "NTFS_CASE_SENSITIVE_DIRECTORY_SUPPORT" {
      return ($ScriptText.Contains("MERGE_CASE_SENSITIVE_DIRECTORY_UNSUPPORTED"))
    }
    default {
      return $false
    }
  }
}

Write-Host "`n=== M01-M82 Mandatory Semantic & Structural RED Test Matrix ===" -ForegroundColor Cyan

$uuid1 = "11111111-2222-3333-4444-555555555555"
$uuid2 = "22222222-2222-3333-4444-555555555555"

# M01: Folder A + Folder B 正常統合 PLAN (DIRECT_EXECUTION)
$vM01 = Join-Path $TestRoot "V_M01"
Reset-TestVault $vM01
$f1_M01 = Join-Path $vM01 "01_顧客\株式会社テスト_旧名"
$f2_M01 = Join-Path $vM01 "01_顧客\株式会社テスト_[11111111]"
Create-MockNote $f1_M01 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M01 "🟥事故_テスト.md" $uuid1 "事故"
$pre_M01 = (Test-Path -LiteralPath (Join-Path $f1_M01 "🟨契約_テスト.md")) -and (Test-Path -LiteralPath (Join-Path $f2_M01 "🟥事故_テスト.md"))
$res_M01 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M01"; VaultRoot = $vM01; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M01 = ($null -eq $res_M01.Json -or $res_M01.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M01" -Name "Folder A(契約) + Folder B(事故) 正常統合 PLAN" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M01) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "2 customer folders exist with valid same-UUID notes" `
  -PreconditionsObserved "f1 and f2 exist with distinct notes (PreconditionPass: $pre_M01)" `
  -PreconditionPass $pre_M01 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_PLAN_READY" `
  -ActualEvidence "Observed stdout: $($res_M01.Stdout.Trim())"

# M02: 集合全体での同一 noteType 重複検知 (DIRECT_EXECUTION)
$vM02 = Join-Path $TestRoot "V_M02"
Reset-TestVault $vM02
$f1_M02 = Join-Path $vM02 "01_顧客\株式会社テスト_A"
$f2_M02 = Join-Path $vM02 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M02 "🟨契約_テスト1.md" $uuid1 "契約"
Create-MockNote $f2_M02 "🟨契約_テスト2.md" $uuid1 "契約"
$pre_M02 = (Test-Path -LiteralPath (Join-Path $f1_M02 "🟨契約_テスト1.md")) -and (Test-Path -LiteralPath (Join-Path $f2_M02 "🟨契約_テスト2.md"))
$res_M02 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M02"; VaultRoot = $vM02; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M02 = ($null -eq $res_M02.Json -or $res_M02.Json.code -ne "DUPLICATE_NOTE_TYPE")
Record-TestResult -Id "M02" -Name "集合全体での同一 noteType 重複検知" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M02) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "2 customer folders contain duplicate '契約' noteType" `
  -PreconditionsObserved "Both notes created with noteType '契約' (PreconditionPass: $pre_M02)" `
  -PreconditionPass $pre_M02 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == DUPLICATE_NOTE_TYPE" `
  -ActualEvidence "Observed stdout: $($res_M02.Stdout.Trim())"

# M03: フォルダ内に他 UUID 混在検知 (DIRECT_EXECUTION)
$vM03 = Join-Path $TestRoot "V_M03"
Reset-TestVault $vM03
$f1_M03 = Join-Path $vM03 "01_顧客\株式会社テスト_A"
$f2_M03 = Join-Path $vM03 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M03 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M03 "🟥事故_テスト.md" $uuid1 "事故"
Create-MockNote $f2_M03 "⬛その他_別顧客.md" $uuid2 "その他"
$pre_M03 = (Test-Path -LiteralPath (Join-Path $f2_M03 "⬛その他_別顧客.md"))
$res_M03 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M03"; VaultRoot = $vM03; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M03 = ($null -eq $res_M03.Json -or $res_M03.Json.code -ne "FOLDER_UUID_MIXED")
Record-TestResult -Id "M03" -Name "フォルダ内他UUID混在検知" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M03) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Folder B contains note with distinct UUID $uuid2" `
  -PreconditionsObserved "Mixed note exists with $uuid2 (PreconditionPass: $pre_M03)" `
  -PreconditionPass $pre_M03 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == FOLDER_UUID_MIXED" `
  -ActualEvidence "Observed stdout: $($res_M03.Stdout.Trim())"

# M04: サブフォルダ内管理ノート検知 (Scope外) (DIRECT_EXECUTION)
$vM04 = Join-Path $TestRoot "V_M04"
Reset-TestVault $vM04
$f1_M04 = Join-Path $vM04 "01_顧客\株式会社テスト_A"
$f2_M04 = Join-Path $vM04 "01_顧客\株式会社テスト_B"
$f2sub_M04 = Join-Path $f2_M04 "sub"
Create-MockNote $f1_M04 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2sub_M04 "🟨契約_旧.md" $uuid1 "契約"
$pre_M04 = (Test-Path -LiteralPath (Join-Path $f2sub_M04 "🟨契約_旧.md"))
$res_M04 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M04"; VaultRoot = $vM04; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M04 = ($null -eq $res_M04.Json -or $res_M04.Json.code -ne "MANAGED_NOTE_OUT_OF_SCOPE")
Record-TestResult -Id "M04" -Name "サブフォルダ内管理ノート検知 (Scope外)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M04) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Managed note placed in subfolder f2/sub/" `
  -PreconditionsObserved "Subfolder note exists (PreconditionPass: $pre_M04)" `
  -PreconditionPass $pre_M04 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MANAGED_NOTE_OUT_OF_SCOPE" `
  -ActualEvidence "Observed stdout: $($res_M04.Stdout.Trim())"

# M05: Case A (Folder B が既に Canonical 名) 統合 (DIRECT_EXECUTION)
$vM05 = Join-Path $TestRoot "V_M05"
Reset-TestVault $vM05
$f1_M05 = Join-Path $vM05 "01_顧客\株式会社テスト_旧名"
$f2_M05 = Join-Path $vM05 "01_顧客\株式会社テスト_[11111111]"
Create-MockNote $f1_M05 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M05 "🟥事故_テスト.md" $uuid1 "事故"
$pre_M05 = (Test-Path -LiteralPath $f2_M05) -and ($f2_M05.EndsWith("_[11111111]"))
$res_M05 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M05"; VaultRoot = $vM05; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M05 = ($null -eq $res_M05.Json -or $res_M05.Json.code -ne "MERGE_PLAN_READY" -or $res_M05.Json.canonicalFolderExisted -ne $true)
Record-TestResult -Id "M05" -Name "Case A (Folder B が既に Canonical 名) 統合" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M05) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Folder B already matches canonical name pattern _[11111111]" `
  -PreconditionsObserved "Canonical folder exists (PreconditionPass: $pre_M05)" `
  -PreconditionPass $pre_M05 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "canonicalFolderExisted == true" `
  -ActualEvidence "Observed: $($res_M05.Stdout.Trim())"

# M06: Case B (両方非 Canonical 名から新規 Canonical 統合) (DIRECT_EXECUTION)
$vM06 = Join-Path $TestRoot "V_M06"
Reset-TestVault $vM06
$f1_M06 = Join-Path $vM06 "01_顧客\株式会社テスト_A"
$f2_M06 = Join-Path $vM06 "01_顧客\株式会社テスト_B"
$fcanon_M06 = Join-Path $vM06 "01_顧客\株式会社テスト_[11111111]"
Create-MockNote $f1_M06 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M06 "🟥事故_テスト.md" $uuid1 "事故"
$pre_M06 = (Test-Path -LiteralPath $f1_M06) -and (Test-Path -LiteralPath $f2_M06) -and (-not (Test-Path -LiteralPath $fcanon_M06))
$res_M06 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M06"; VaultRoot = $vM06; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M06 = ($null -eq $res_M06.Json -or $res_M06.Json.code -ne "MERGE_PLAN_READY" -or $res_M06.Json.canonicalFolderExisted -ne $false)
Record-TestResult -Id "M06" -Name "Case B (両方非 Canonical 名から新規 Canonical 統合)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M06) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Both folders non-canonical and canonical folder absent" `
  -PreconditionsObserved "Canonical absent, sources exist (PreconditionPass: $pre_M06)" `
  -PreconditionPass $pre_M06 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "canonicalFolderExisted == false" `
  -ActualEvidence "Observed: $($res_M06.Stdout.Trim())"

# M07: 移動先ファイル名衝突検知 (DIRECT_EXECUTION)
$vM07 = Join-Path $TestRoot "V_M07"
Reset-TestVault $vM07
$f1_M07 = Join-Path $vM07 "01_顧客\株式会社テスト_旧名"
$f2_M07 = Join-Path $vM07 "01_顧客\株式会社テスト_[11111111]"
Create-MockNote $f1_M07 "🟨契約_テスト.md" $uuid1 "契約"
$f2note_M07 = Join-Path $f2_M07 "🟨契約_テスト.md"
Write-MockFile $f2note_M07 "非管理同名ファイル"
$pre_M07 = (Test-Path -LiteralPath (Join-Path $f1_M07 "🟨契約_テスト.md")) -and (Test-Path -LiteralPath $f2note_M07)
$res_M07 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M07"; VaultRoot = $vM07; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M07 = ($null -eq $res_M07.Json -or $res_M07.Json.code -ne "TARGET_NOTE_FILENAME_CONFLICT")
Record-TestResult -Id "M07" -Name "移動先ファイル名衝突検知" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M07) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Source file and target conflicting file exist simultaneously" `
  -PreconditionsObserved "Conflict note present in canonical destination (PreconditionPass: $pre_M07)" `
  -PreconditionPass $pre_M07 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == TARGET_NOTE_FILENAME_CONFLICT" `
  -ActualEvidence "Observed: $($res_M07.Stdout.Trim())"

# M08: 非管理ファイル (PDF) の温存 (DIRECT_EXECUTION)
$vM08 = Join-Path $TestRoot "V_M08"
Reset-TestVault $vM08
$f1_M08 = Join-Path $vM08 "01_顧客\株式会社テスト_旧名"
$f2_M08 = Join-Path $vM08 "01_顧客\株式会社テスト_[11111111]"
Create-MockNote $f1_M08 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M08 "🟥事故_テスト.md" $uuid1 "事故"
$pdf_M08 = Join-Path $f1_M08 "重要契約書.pdf"
Write-MockFile $pdf_M08 "PDFバイナリ"
$pre_M08 = (Test-Path -LiteralPath $pdf_M08) -and ((Get-Item -LiteralPath $pdf_M08).Length -gt 0)
$res_M08 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M08"; VaultRoot = $vM08; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M08 = ($null -eq $res_M08.Json -or $res_M08.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M08" -Name "非管理ファイル (PDF) の温存" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M08) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Unmanaged PDF exists in source folder" `
  -PreconditionsObserved "PDF exists with valid byte size (PreconditionPass: $pre_M08)" `
  -PreconditionPass $pre_M08 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_PLAN_READY with PDF retained" `
  -ActualEvidence "Observed: $($res_M08.Stdout.Trim())"

# M09: 3フォルダ衝突 (N=3) の統合 (DIRECT_EXECUTION)
$vM09 = Join-Path $TestRoot "V_M09"
Reset-TestVault $vM09
$f1_M09 = Join-Path $vM09 "01_顧客\株式会社テスト_A"
$f2_M09 = Join-Path $vM09 "01_顧客\株式会社テスト_B"
$f3_M09 = Join-Path $vM09 "01_顧客\株式会社テスト_C"
Create-MockNote $f1_M09 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M09 "🟥事故_テスト.md" $uuid1 "事故"
Create-MockNote $f3_M09 "🟩顧客_テスト.md" $uuid1 "顧客"
$pre_M09 = (Test-Path -LiteralPath $f1_M09) -and (Test-Path -LiteralPath $f2_M09) -and (Test-Path -LiteralPath $f3_M09)
$res_M09 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M09"; VaultRoot = $vM09; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M09 = ($null -eq $res_M09.Json -or $res_M09.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M09" -Name "3フォルダ衝突 (N=3) の統合" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M09) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "3 customer folders exist with same UUID" `
  -PreconditionsObserved "3 distinct folders created and verified (PreconditionPass: $pre_M09)" `
  -PreconditionPass $pre_M09 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_PLAN_READY" `
  -ActualEvidence "Observed: $($res_M09.Stdout.Trim())"

# M10: ロールバック機構 (STATIC_CAPABILITY)
$proof_M10 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Rollback Transaction Engine"
$req_M10 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "TransactionEngineReachable", "RollbackExecutionReachable")
$obs_M10 = @()
if ($proof_M10.DispatchBranchFound) { $obs_M10 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M10 = @($req_M10 | Where-Object { $obs_M10 -notcontains $_ })
$green_M10 = ($missing_M10.Count -eq 0)
Record-TestResult -Id "M10" -Name "APPLY 途中障害注入時の完全ロールバック" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M10) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "APPLY_CUSTOMER_FOLDER_MERGE Action Dispatch & Rollback Engine" `
  -DispatchBranchFound $proof_M10.DispatchBranchFound `
  -ReachableFunctions $proof_M10.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M10.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M10.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M10.ReachableStateSymbols `
  -StructuralProofResult $proof_M10.ProofResult `
  -RequiredComponents $req_M10 `
  -ObservedComponents $obs_M10 `
  -MissingComponents $missing_M10 `
  -GreenPredicate "ActionDispatchPresent -and TransactionEngineReachable -and RollbackExecutionReachable" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch branch; no reachable rollback engine control flow exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "APPLY dispatch branch exists and reaches rollback engine" `
  -ActualEvidence $proof_M10.ProofResult

# M11: PLAN 後管理ノート内容変更検知 (MERGE_PLAN_STALE) (DIRECT_EXECUTION)
$vM11 = Join-Path $TestRoot "V_M11"
Reset-TestVault $vM11
$f1_M11 = Join-Path $vM11 "01_顧客\株式会社テスト_A"
$f2_M11 = Join-Path $vM11 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M11 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M11 "🟥事故_テスト.md" $uuid1 "事故"
$pre_M11 = (Test-Path -LiteralPath (Join-Path $f1_M11 "🟨契約_テスト.md")) -and (Test-Path -LiteralPath (Join-Path $f2_M11 "🟥事故_テスト.md"))
$res_M11_plan = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M11-plan"; VaultRoot = $vM11; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$planToken_M11 = if ($null -ne $res_M11_plan.Json -and $null -ne $res_M11_plan.Json.planToken) { $res_M11_plan.Json.planToken } else { "dummyToken" }
$notePath_M11 = Join-Path $f1_M11 "🟨契約_テスト.md"
[System.IO.File]::AppendAllText($notePath_M11, "`n改ざん", [System.Text.Encoding]::UTF8)
$res_M11 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "APPLY_CUSTOMER_FOLDER_MERGE"; requestId = "req-M11-apply"; VaultRoot = $vM11; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"; planToken = $planToken_M11
}
$isPass_M11 = ($null -ne $res_M11.Json -and $res_M11.Json.code -eq "MERGE_PLAN_STALE")
Record-TestResult -Id "M11" -Name "PLAN 後管理ノート内容変更検知 (MERGE_PLAN_STALE)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isPass_M11) { "PASS_EXISTING" } else { "EXECUTED_EXPECTED_RED" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Content modified after plan generation" `
  -PreconditionsObserved "Content altered before APPLY (PreconditionPass: $pre_M11)" `
  -PreconditionPass $pre_M11 `
  -ExecutionPerformed "Invoke-BridgePayload APPLY_CUSTOMER_FOLDER_MERGE after note alteration" `
  -AssertionPerformed "code == MERGE_PLAN_STALE" `
  -ActualEvidence "Observed: $($res_M11.Stdout.Trim())"

# M12: PLAN 後非管理ファイル追加検知 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M12" -EnvironmentRequirement "NONE" -ActivationBoundary "TOPOLOGY_RESCAN" -Name "PLAN 後非管理ファイル追加検知 (MERGE_PLAN_STALE)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "Valid planToken and topology re-verification in APPLY" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "code == MERGE_PLAN_STALE upon topology change" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE dispatch and topology hash verification"

# M13: PLAN 後サブフォルダ追加検知 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M13" -EnvironmentRequirement "NONE" -ActivationBoundary "TOPOLOGY_RESCAN" -Name "PLAN 後サブフォルダ追加検知 (MERGE_PLAN_STALE)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "Valid planToken and directory structure verification in APPLY" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "code == MERGE_PLAN_STALE upon directory change" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE dispatch and directory snapshot verification"

# M14: Case C (衝突集合外に Canonical フォルダ既存) (DIRECT_EXECUTION)
$vM14 = Join-Path $TestRoot "V_M14"
Reset-TestVault $vM14
$f1_M14 = Join-Path $vM14 "01_顧客\株式会社テスト_A"
$f2_M14 = Join-Path $vM14 "01_顧客\株式会社テスト_B"
$fcanon_M14 = Join-Path $vM14 "01_顧客\株式会社テスト_[11111111]"
Create-MockNote $f1_M14 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M14 "🟥事故_テスト.md" $uuid1 "事故"
Create-MockNote $fcanon_M14 "🟩顧客_別顧客.md" $uuid2 "顧客"
$pre_M14 = (Test-Path -LiteralPath (Join-Path $fcanon_M14 "🟩顧客_別顧客.md"))
$res_M14 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M14"; VaultRoot = $vM14; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M14 = ($null -eq $res_M14.Json -or $res_M14.Json.code -ne "TARGET_FOLDER_ALREADY_EXISTS")
Record-TestResult -Id "M14" -Name "Case C (衝突集合外に Canonical フォルダ既存)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M14) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Canonical folder exists but belongs to distinct UUID $uuid2" `
  -PreconditionsObserved "Foreign canonical folder created and verified (PreconditionPass: $pre_M14)" `
  -PreconditionPass $pre_M14 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == TARGET_FOLDER_ALREADY_EXISTS" `
  -ActualEvidence "Observed: $($res_M14.Stdout.Trim())"

# M15: ロールバック実行中例外 (STATIC_CAPABILITY)
$absent_M15 = Assert-TargetSymbolAbsent "MERGE_ROLLBACK_FAILED"
$req_M15 = @("ErrorCode:MERGE_ROLLBACK_FAILED", "RollbackExceptionTrapReachable", "DiagnosticOutputMapping")
$obs_M15 = @()
if (-not $absent_M15) { $obs_M15 += "ErrorCode:MERGE_ROLLBACK_FAILED" }
$missing_M15 = @($req_M15 | Where-Object { $obs_M15 -notcontains $_ })
$green_M15 = ($missing_M15.Count -eq 0)
Record-TestResult -Id "M15" -Name "ロールバック実行中例外注入 (MERGE_ROLLBACK_FAILED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M15) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "MERGE_ROLLBACK_FAILED" `
  -StructuralInspection "Symbol search for frozen normative error code MERGE_ROLLBACK_FAILED" `
  -RequiredComponents $req_M15 `
  -ObservedComponents $obs_M15 `
  -MissingComponents $missing_M15 `
  -GreenPredicate "ErrorCodePresent -and RollbackExceptionTrapReachable -and DiagnosticMapped" `
  -SemanticAbsenceReason "Frozen contract requires MERGE_ROLLBACK_FAILED upon rollback failure; code and handler are absent" `
  -ExecutionPerformed "Symbol search in production script text" `
  -AssertionPerformed "MERGE_ROLLBACK_FAILED present" `
  -ActualEvidence "MERGE_ROLLBACK_FAILED absent: $absent_M15"

# M16: APPLY 定義外フィールド拒否 (INVALID_REQUEST) (DIRECT_EXECUTION)
$vM16 = Join-Path $TestRoot "V_M16"
Reset-TestVault $vM16
$res_M16 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "APPLY_CUSTOMER_FOLDER_MERGE"; requestId = "req-M16"; VaultRoot = $vM16; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"; planToken = "dummy"; extraUnexpectedField = "MALICIOUS"
}
$isPass_M16 = ($null -ne $res_M16.Json -and $res_M16.Json.code -eq "INVALID_REQUEST")
Record-TestResult -Id "M16" -Name "APPLY 定義外フィールド拒否 (INVALID_REQUEST)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isPass_M16) { "PASS_EXISTING" } else { "EXECUTED_EXPECTED_RED" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Payload contains unexpected extra field" `
  -PreconditionsObserved "extraUnexpectedField supplied in payload (PreconditionPass: $true)" `
  -PreconditionPass $true `
  -ExecutionPerformed "Invoke-BridgePayload APPLY_CUSTOMER_FOLDER_MERGE with extra field" `
  -AssertionPerformed "code == INVALID_REQUEST" `
  -ActualEvidence "Observed: $($res_M16.Stdout.Trim())"

# M17: 非管理ファイル残存 (v1 フォルダ削除禁止契約) (DIRECT_EXECUTION)
$vM17 = Join-Path $TestRoot "V_M17"
Reset-TestVault $vM17
$f1_M17 = Join-Path $vM17 "01_顧客\株式会社テスト_A"
$f2_M17 = Join-Path $vM17 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M17 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M17 "🟥事故_テスト.md" $uuid1 "事故"
$pdfFile_M17 = Join-Path $f2_M17 "契約書コピー.pdf"
Write-MockFile $pdfFile_M17 "PDF_BINARY_DUMMY"
$pre_M17 = (Test-Path -LiteralPath $pdfFile_M17)
$res_M17_plan = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M17-plan"; VaultRoot = $vM17; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$planToken_M17 = if ($null -ne $res_M17_plan.Json -and $null -ne $res_M17_plan.Json.planToken) { $res_M17_plan.Json.planToken } else { "dummyToken" }
$res_M17_apply = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "APPLY_CUSTOMER_FOLDER_MERGE"; requestId = "req-M17-apply"; VaultRoot = $vM17; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"; planToken = $planToken_M17
}
$pdfRetained = (Test-Path -LiteralPath $pdfFile_M17)
$f2Retained = (Test-Path -LiteralPath $f2_M17)
$isPass_M17 = ($null -ne $res_M17_apply.Json -and ($res_M17_apply.Json.code -eq "MERGE_COMPLETED" -or $res_M17_apply.Json.code -eq "MERGE_PLAN_READY") -and $pdfRetained -and $f2Retained)
Record-TestResult -Id "M17" -Name "PDF 温存・旧ソースフォルダ残存確認 (v1 仕様)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isPass_M17) { "PASS_EXISTING" } else { "EXECUTED_EXPECTED_RED" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Non-managed PDF exists in source folder" `
  -PreconditionsObserved "PDF note created (PreconditionPass: $pre_M17)" `
  -PreconditionPass $pre_M17 `
  -ExecutionPerformed "Invoke-BridgePayload APPLY_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "PDF file and source folder preserved after merge" `
  -ActualEvidence "Observed: $($res_M17_apply.Stdout.Trim())"

# M18: UUID なし unmanaged Markdown 温存確認 (DIRECT_EXECUTION)
$vM18 = Join-Path $TestRoot "V_M18"
Reset-TestVault $vM18
$f1_M18 = Join-Path $vM18 "01_顧客\株式会社テスト_A"
$f2_M18 = Join-Path $vM18 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M18 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M18 "🟥事故_テスト.md" $uuid1 "事故"
$unmanaged_M18 = Join-Path $f1_M18 "メモ.md"
Write-MockFile $unmanaged_M18 "UUIDのないメモ"
$pre_M18 = (Test-Path -LiteralPath $unmanaged_M18) -and (-not [System.IO.File]::ReadAllText($unmanaged_M18).Contains("UUID:"))
$res_M18 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M18"; VaultRoot = $vM18; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M18 = ($null -eq $res_M18.Json -or $res_M18.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M18" -Name "UUID なし unmanaged Markdown 温存確認" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M18) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Unmanaged markdown note without UUID exists in source" `
  -PreconditionsObserved "Unmanaged note exists and has no UUID (PreconditionPass: $pre_M18)" `
  -PreconditionPass $pre_M18 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_PLAN_READY" `
  -ActualEvidence "Observed: $($res_M18.Stdout.Trim())"

# M19: target UUID 保持 unmanaged Markdown 検知 (DIRECT_EXECUTION)
$vM19 = Join-Path $TestRoot "V_M19"
Reset-TestVault $vM19
$f1_M19 = Join-Path $vM19 "01_顧客\株式会社テスト_A"
$f2_M19 = Join-Path $vM19 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M19 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M19 "🟥事故_テスト.md" $uuid1 "事故"
$unmanaged_M19 = Join-Path $f1_M19 "未整理_旧メモ.md"
Write-MockFile $unmanaged_M19 "---`nUUID: $uuid1`n---`n本文"
$pre_M19 = (Test-Path -LiteralPath $unmanaged_M19) -and ([System.IO.File]::ReadAllText($unmanaged_M19).Contains($uuid1))
$res_M19 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M19"; VaultRoot = $vM19; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M19 = ($null -eq $res_M19.Json -or $res_M19.Json.code -ne "MERGE_UNMANAGED_UUID_EVIDENCE")
Record-TestResult -Id "M19" -Name "target UUID 保持 unmanaged Markdown 検知 (MERGE_UNMANAGED_UUID_EVIDENCE)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M19) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Unmanaged markdown note contains target UUID $uuid1" `
  -PreconditionsObserved "Unmanaged note exists and contains target UUID (PreconditionPass: $pre_M19)" `
  -PreconditionPass $pre_M19 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_UNMANAGED_UUID_EVIDENCE" `
  -ActualEvidence "Observed: $($res_M19.Stdout.Trim())"

# M20: Option B - PENDING MOVE 診断専用 Fail-Closed (STATIC_CAPABILITY)
$proof_M20 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Option B PENDING MOVE Handler"
$req_M20 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "JournalStateMachine:MOVE_FILE", "StateBranch:PENDING", "NonDestructiveProhibition:NoWrongObjectUndo", "DiagnosticFailClosed:MERGE_ROLLBACK_FAILED")
$obs_M20 = @()
if ($proof_M20.DispatchBranchFound) { $obs_M20 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M20 = @($req_M20 | Where-Object { $obs_M20 -notcontains $_ })
$green_M20 = ($missing_M20.Count -eq 0)
Record-TestResult -Id "M20" -Name "PENDING MOVE 診断専用 Fail-Closed (Option B)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M20) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Option B Non-destructive PENDING Recovery" `
  -DispatchBranchFound $proof_M20.DispatchBranchFound `
  -ReachableFunctions $proof_M20.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M20.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M20.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M20.ReachableStateSymbols `
  -StructuralProofResult $proof_M20.ProofResult `
  -RequiredComponents $req_M20 `
  -ObservedComponents $obs_M20 `
  -MissingComponents $missing_M20 `
  -GreenPredicate "ActionDispatchPresent -and JournalMovePresent -and StatePendingPresent -and NoWrongObjectUndo -and DiagnosticFailClosed" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable journal state machine or PENDING MOVE recovery branch exists, so Option B diagnostic-only handling is absent" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Option B non-destructive recovery path exists" `
  -ActualEvidence $proof_M20.ProofResult

# M21: 同一 snapshot 別 VaultRoot 適用拒否 (DIRECT_EXECUTION)
$vM21_a = Join-Path $TestRoot "V_M21_A"
$vM21_b = Join-Path $TestRoot "V_M21_B"
Reset-TestVault $vM21_a
Reset-TestVault $vM21_b
$f1_M21_a = Join-Path $vM21_a "01_顧客\株式会社テスト_A"
$f2_M21_a = Join-Path $vM21_a "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M21_a "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M21_a "🟥事故_テスト.md" $uuid1 "事故"
$f1_M21_b = Join-Path $vM21_b "01_顧客\株式会社テスト_A"
$f2_M21_b = Join-Path $vM21_b "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M21_b "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M21_b "🟥事故_テスト.md" $uuid1 "事故"
$res_M21_plan = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M21-plan"; VaultRoot = $vM21_a; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$planToken_M21 = if ($null -ne $res_M21_plan.Json -and $null -ne $res_M21_plan.Json.planToken) { $res_M21_plan.Json.planToken } else { "dummyToken" }
$res_M21_apply = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "APPLY_CUSTOMER_FOLDER_MERGE"; requestId = "req-M21-apply"; VaultRoot = $vM21_b; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"; planToken = $planToken_M21
}
$isPass_M21 = (
  $null -ne $res_M21_apply.Json -and
  $res_M21_apply.Json.status -eq "NG" -and
  $res_M21_apply.Json.code -eq "PLAN_TOKEN_MISMATCH"
)
$res_M21_pos_plan = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M21-pos-plan"; VaultRoot = $vM21_b; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$posToken_M21 = if ($null -ne $res_M21_pos_plan.Json -and $null -ne $res_M21_pos_plan.Json.planToken) { $res_M21_pos_plan.Json.planToken } else { "dummyToken" }
$res_M21_pos_apply = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "APPLY_CUSTOMER_FOLDER_MERGE"; requestId = "req-M21-pos-apply"; VaultRoot = $vM21_b; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"; planToken = $posToken_M21
}
Record-TestResult -Id "M21" -Name "同一 snapshot の別 VaultRoot 適用拒否 (CUSTOMER_ROOT 不一致)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isPass_M21) { "PASS_EXISTING" } else { "EXECUTED_EXPECTED_RED" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Token from Vault A applied to Vault B" `
  -PreconditionsObserved "Different VaultRoot used for APPLY (PreconditionPass: $true)" `
  -PreconditionPass $true `
  -ExecutionPerformed "Invoke-BridgePayload APPLY_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == PLAN_TOKEN_MISMATCH" `
  -ActualEvidence "Observed: $($res_M21_apply.Stdout.Trim()) | PosControl: $($res_M21_pos_apply.Stdout.Trim())"

# M22: 全 managed note 内容 SHA256 完全一致 (STATIC_CAPABILITY)
$proof_M22 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "File Content SHA256 Integrity"
$req_M22 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "Sha256VerificationReachable", "FileMoveReachable")
$obs_M22 = @()
if ($proof_M22.DispatchBranchFound) { $obs_M22 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
if ($targetScriptText.Contains("SHA256") -and $targetScriptText.Contains("ComputeHash")) { $obs_M22 += "Sha256VerificationReachable" }
if ($proof_M22.ReachableMutationPrimitives.Contains("Move")) { $obs_M22 += "FileMoveReachable" }
$missing_M22 = @($req_M22 | Where-Object { $obs_M22 -notcontains $_ })
$green_M22 = ($missing_M22.Count -eq 0)
Record-TestResult -Id "M22" -Name "全 managed note 内容 SHA256 完全一致 (FILE_CONTENT_BYTES_PRESERVED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M22) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "FILE_CONTENT_BYTES_PRESERVED" `
  -DispatchBranchFound $proof_M22.DispatchBranchFound `
  -ReachableFunctions $proof_M22.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M22.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M22.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M22.ReachableStateSymbols `
  -StructuralProofResult $proof_M22.ProofResult `
  -RequiredComponents $req_M22 `
  -ObservedComponents $obs_M22 `
  -MissingComponents $missing_M22 `
  -GreenPredicate "ActionDispatchPresent -and Sha256VerificationReachable -and FileMoveReachable" `
  -SemanticAbsenceReason "Production script requires full-file SHA256 integrity verification across customer folder merge" `
  -ExecutionPerformed "AST Action Dispatch & Reachability Analysis" `
  -AssertionPerformed "File move and SHA256 integrity verification are reachable in APPLY" `
  -ActualEvidence $proof_M22.ProofResult

# M23: MOVE 直前 destination 外部作成検知 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M23" -EnvironmentRequirement "NONE" -ActivationBoundary "FILE_MOVE_ENGINE_PREMOVE_HOOK" -Name "MOVE 直前 destination 外部作成検知 (TARGET_NOTE_FILENAME_CONFLICT)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "APPLY step-by-step execution hook with external destination creation" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "code == TARGET_NOTE_FILENAME_CONFLICT right before move" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE atomic pre-move verification"

# M24: MOVE 後 destination 改ざん検知 (STATIC_CAPABILITY)
$proof_M24 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Pre-Rollback Hash Verification"
$req_M24 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "RollbackEngineReachable", "DestinationSha256Verification", "DestinationSizeVerification", "TamperingSuppression")
$obs_M24 = @()
if ($proof_M24.DispatchBranchFound) { $obs_M24 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M24 = @($req_M24 | Where-Object { $obs_M24 -notcontains $_ })
$green_M24 = ($missing_M24.Count -eq 0)
Record-TestResult -Id "M24" -Name "MOVE 後 destination 改ざん検知 (盲目 move-back 禁止)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M24) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Pre-Rollback Hash Re-verification" `
  -DispatchBranchFound $proof_M24.DispatchBranchFound `
  -ReachableFunctions $proof_M24.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M24.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M24.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M24.ReachableStateSymbols `
  -StructuralProofResult $proof_M24.ProofResult `
  -RequiredComponents $req_M24 `
  -ObservedComponents $obs_M24 `
  -MissingComponents $missing_M24 `
  -GreenPredicate "ActionDispatchPresent -and RollbackEnginePresent -and DestSha256Verified -and DestSizeVerified -and TamperingSuppressed" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable pre-rollback destination hash re-verification control flow exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Pre-rollback hash re-verification exists" `
  -ActualEvidence $proof_M24.ProofResult

# M25: Case B CREATE 直前同名フォルダ外部作成検知 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M25" -EnvironmentRequirement "NONE" -ActivationBoundary "STAGING_EXCLUSIVE_CREATE" -Name "CREATE 直前同名フォルダ外部作成検知 (TARGET_FOLDER_ALREADY_EXISTS)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "APPLY Case B execution hook with external folder creation" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "code == TARGET_FOLDER_ALREADY_EXISTS upon external folder creation" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE Win32 exclusive create"

# M26: final verification 失敗時ロールバック完了 (STATIC_CAPABILITY)
$absent_M26 = Assert-TargetSymbolAbsent "MERGE_FAILED_ROLLED_BACK"
$req_M26 = @("ErrorCode:MERGE_FAILED_ROLLED_BACK", "FinalVerificationGatePresent", "RollbackCompletionMapped")
$obs_M26 = @()
if (-not $absent_M26) { $obs_M26 += "ErrorCode:MERGE_FAILED_ROLLED_BACK" }
$missing_M26 = @($req_M26 | Where-Object { $obs_M26 -notcontains $_ })
$green_M26 = ($missing_M26.Count -eq 0)
Record-TestResult -Id "M26" -Name "final verification 失敗時ロールバック完了 (MERGE_FAILED_ROLLED_BACK)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M26) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "MERGE_FAILED_ROLLED_BACK" `
  -StructuralInspection "Symbol search for frozen normative code MERGE_FAILED_ROLLED_BACK" `
  -RequiredComponents $req_M26 `
  -ObservedComponents $obs_M26 `
  -MissingComponents $missing_M26 `
  -GreenPredicate "ErrorCodePresent -and FinalVerificationGatePresent -and RollbackCompletionMapped" `
  -SemanticAbsenceReason "Frozen contract requires MERGE_FAILED_ROLLED_BACK when final verification fails and rollback succeeds" `
  -ExecutionPerformed "Symbol search in production script text" `
  -AssertionPerformed "MERGE_FAILED_ROLLED_BACK present" `
  -ActualEvidence "MERGE_FAILED_ROLLED_BACK absent: $absent_M26, Observed: $($obs_M26.Count)/$($req_M26.Count)"

# M27: final verification 故意失敗時のロールバック (STATIC_CAPABILITY)
$absent_M27 = Assert-TargetSymbolAbsent "MERGE_FAILED_ROLLED_BACK"
$req_M27 = @("ErrorCode:MERGE_FAILED_ROLLED_BACK", "FinalVerificationGate", "RollbackCompletionMapping")
$obs_M27 = @()
if (-not $absent_M27) { $obs_M27 += "ErrorCode:MERGE_FAILED_ROLLED_BACK" }
$missing_M27 = @($req_M27 | Where-Object { $obs_M27 -notcontains $_ })
$green_M27 = ($missing_M27.Count -eq 0)
Record-TestResult -Id "M27" -Name "final verification 故意失敗時のロールバック" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M27) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "MERGE_FAILED_ROLLED_BACK" `
  -StructuralInspection "Symbol search for frozen normative code MERGE_FAILED_ROLLED_BACK" `
  -RequiredComponents $req_M27 `
  -ObservedComponents $obs_M27 `
  -MissingComponents $missing_M27 `
  -GreenPredicate "ErrorCodePresent -and FinalVerificationGatePresent -and RollbackCompletionMapped" `
  -SemanticAbsenceReason "Frozen contract requires MERGE_FAILED_ROLLED_BACK when final verification fails and rollback succeeds" `
  -ExecutionPerformed "Symbol search in production script text" `
  -AssertionPerformed "MERGE_FAILED_ROLLED_BACK present" `
  -ActualEvidence "MERGE_FAILED_ROLLED_BACK absent: $absent_M27"

# M28: Case B 作成直前外部空フォルダ作成時の外部フォルダ非削除 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M28" -EnvironmentRequirement "NONE" -ActivationBoundary "STAGING_EXCLUSIVE_CREATE" -Name "Case B 作成直前外部空フォルダ作成時の外部フォルダ非削除" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "APPLY Case B execution with external empty folder collision" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "code == TARGET_FOLDER_ALREADY_EXISTS and external folder untouched" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE Win32 exclusive protection"

# M29: Staging 作成後・リネーム前外部フォルダ作成時の安全停止 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M29" -EnvironmentRequirement "NONE" -ActivationBoundary "STAGING_LIFECYCLE" -Name "Staging 作成後・リネーム前外部フォルダ作成時の安全停止" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "APPLY Case B execution paused while staging exists" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "code == TARGET_FOLDER_ALREADY_EXISTS and staging cleaned up" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE staging lifecycle"

# M30: Staging リネーム後障害時の所有権同定 (STATIC_CAPABILITY)
$proof_M30 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Staging Lifecycle & Canonical Rollback"
$req_M30 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "StagingLifecycle", "OwnershipMarkerValidation", "SelfCreatedCanonicalRollback")
$obs_M30 = @()
if ($proof_M30.DispatchBranchFound) { $obs_M30 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M30 = @($req_M30 | Where-Object { $obs_M30 -notcontains $_ })
$green_M30 = ($missing_M30.Count -eq 0)
Record-TestResult -Id "M30" -Name "Staging リネーム後障害時の所有権同定・自作 Canonical 復元" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M30) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Staging Lifecycle and Ownership Identification" `
  -DispatchBranchFound $proof_M30.DispatchBranchFound `
  -ReachableFunctions $proof_M30.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M30.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M30.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M30.ReachableStateSymbols `
  -StructuralProofResult $proof_M30.ProofResult `
  -RequiredComponents $req_M30 `
  -ObservedComponents $obs_M30 `
  -MissingComponents $missing_M30 `
  -GreenPredicate "ActionDispatchPresent -and StagingLifecyclePresent -and OwnershipMarkerValidated -and SelfCreatedCanonicalRollback" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable staging lifecycle or ownership-based canonical rollback logic exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Staging ownership identification logic exists" `
  -ActualEvidence $proof_M30.ProofResult

# M31: Staging パス衝突時の GUID 再生成リトライ (STATIC_CAPABILITY)
$proof_M31 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Staging Path Collision Retry Loop"
$req_M31 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "StagingPathGeneration", "GuidCollisionRetryLoop", "FailClosedOnExhaustion")
$obs_M31 = @()
if ($proof_M31.DispatchBranchFound) { $obs_M31 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M31 = @($req_M31 | Where-Object { $obs_M31 -notcontains $_ })
$green_M31 = ($missing_M31.Count -eq 0)
Record-TestResult -Id "M31" -Name "Staging パス衝突時の GUID 再生成リトライ・Fail-Closed" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M31) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Staging Path Collision Retry Loop" `
  -DispatchBranchFound $proof_M31.DispatchBranchFound `
  -ReachableFunctions $proof_M31.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M31.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M31.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M31.ReachableStateSymbols `
  -StructuralProofResult $proof_M31.ProofResult `
  -RequiredComponents $req_M31 `
  -ObservedComponents $obs_M31 `
  -MissingComponents $missing_M31 `
  -GreenPredicate "ActionDispatchPresent -and StagingPathGenerated -and GuidRetryLoopPresent -and FailClosedExhaustion" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable staging directory creation or collision retry loop exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Staging directory collision retry logic exists" `
  -ActualEvidence $proof_M31.ProofResult

# M32: Win32 ERROR_ALREADY_EXISTS 検知 (STATIC_CAPABILITY)
$absent_M32       = Assert-TargetSymbolAbsent "CreateDirectoryW"
$absent_M32_183   = Assert-TargetSymbolAbsent "STAGING_DIR_ALREADY_EXISTS"
$absent_M32_nat   = Assert-TargetSymbolAbsent "STAGING_DIR_CREATE_FAILED_NATIVE"
$req_M32 = @("PInvokeDeclaration:CreateDirectoryW", "ErrorCodeHandling:StagingDirAlreadyExists183", "ErrorCodeHandling:StagingDirCreateFailedNative")
$obs_M32 = @()
if (-not $absent_M32)     { $obs_M32 += "PInvokeDeclaration:CreateDirectoryW" }
if (-not $absent_M32_183) { $obs_M32 += "ErrorCodeHandling:StagingDirAlreadyExists183" }
if (-not $absent_M32_nat) { $obs_M32 += "ErrorCodeHandling:StagingDirCreateFailedNative" }
$missing_M32 = @($req_M32 | Where-Object { $obs_M32 -notcontains $_ })
$green_M32   = ($missing_M32.Count -eq 0)
Record-TestResult -Id "M32" -Name "Win32 ERROR_ALREADY_EXISTS 検知による外部保護停止" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M32) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_API_PRIMITIVE" `
  -NormativeLiteral "CreateDirectoryW P/Invoke" `
  -StructuralInspection "Search for Win32 CreateDirectoryW P/Invoke declaration and ERROR_ALREADY_EXISTS handling" `
  -RequiredComponents $req_M32 `
  -ObservedComponents $obs_M32 `
  -MissingComponents $missing_M32 `
  -GreenPredicate "PInvokeDeclared -and StagingDirAlreadyExists183Handled -and StagingDirCreateFailedNativeHandled" `
  -SemanticAbsenceReason "Frozen contract normatively requires Win32 CreateDirectoryW for atomic directory creation with ERROR_ALREADY_EXISTS and native failure classification; all components absent" `
  -ExecutionPerformed "P/Invoke declaration & API call search" `
  -AssertionPerformed "CreateDirectoryW P/Invoke declared and handles ERROR_ALREADY_EXISTS" `
  -ActualEvidence "CreateDirectoryW absent: $absent_M32, Missing: $($missing_M32 -join ', ')"

# M33: 所有権 marker 欠落/不一致時の Canonical 削除抑止 (STATIC_CAPABILITY)
$absent_M33 = Assert-TargetSymbolAbsent ".fm-obsidian-merge-owner"
$req_M33 = @("MarkerFileName:.fm-obsidian-merge-owner", "PreDeletionMarkerValidation", "ForeignFolderSuppression")
$obs_M33 = @()
if (-not $absent_M33) { $obs_M33 += "MarkerFileName:.fm-obsidian-merge-owner" }
$missing_M33 = @($req_M33 | Where-Object { $obs_M33 -notcontains $_ })
$green_M33 = ($missing_M33.Count -eq 0)
Record-TestResult -Id "M33" -Name "所有権 marker 欠落/不一致時の Canonical 削除抑止" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M33) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral ".fm-obsidian-merge-owner" `
  -StructuralInspection "Symbol search for frozen normative ownership marker file name .fm-obsidian-merge-owner" `
  -RequiredComponents $req_M33 `
  -ObservedComponents $obs_M33 `
  -MissingComponents $missing_M33 `
  -GreenPredicate "MarkerFileNamePresent -and MarkerValidated -and ForeignFolderSuppressed" `
  -SemanticAbsenceReason "Frozen contract requires .fm-obsidian-merge-owner marker validation before deleting canonical folder" `
  -ExecutionPerformed "Symbol search in production script text" `
  -AssertionPerformed ".fm-obsidian-merge-owner present" `
  -ActualEvidence ".fm-obsidian-merge-owner absent: $absent_M33"

# M34: MOVE ロールバック直前外部ファイル出現 (STATIC_CAPABILITY)
$absent_M34 = Assert-TargetSymbolAbsent "[System.IO.File]::Move"
$req_M34 = @("APICall:[System.IO.File]::Move", "ExactPathParameterBinding", "NonOverwritingPreMoveVerification")
$obs_M34 = @()
if (-not $absent_M34) { $obs_M34 += "APICall:[System.IO.File]::Move" }
$missing_M34 = @($req_M34 | Where-Object { $obs_M34 -notcontains $_ })
$green_M34 = ($missing_M34.Count -eq 0)
Record-TestResult -Id "M34" -Name "MOVE ロールバック直前外部ファイル出現 (非上書き File.Move 失敗)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M34) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_API_PRIMITIVE" `
  -NormativeLiteral "[System.IO.File]::Move" `
  -StructuralInspection "Search for [System.IO.File]::Move method call in production source" `
  -RequiredComponents $req_M34 `
  -ObservedComponents $obs_M34 `
  -MissingComponents $missing_M34 `
  -GreenPredicate "FileMoveCalled -and ExactPathsBound -and NonOverwritingVerified" `
  -SemanticAbsenceReason "Frozen contract normatively requires exact-path non-overwriting File.Move to prevent overwriting colliding destinations" `
  -ExecutionPerformed "API invocation search" `
  -AssertionPerformed "[System.IO.File]::Move present" `
  -ActualEvidence "[System.IO.File]::Move absent: $absent_M34"

# M35: RENAME ロールバック直前外部ファイル出現 (STATIC_CAPABILITY)
$absent_M35 = Assert-TargetSymbolAbsent "[System.IO.File]::Move"
$req_M35 = @("APICall:[System.IO.File]::Move", "RenameOperationBinding", "NonOverwritingPreMoveVerification")
$obs_M35 = @()
if (-not $absent_M35) { $obs_M35 += "APICall:[System.IO.File]::Move" }
$missing_M35 = @($req_M35 | Where-Object { $obs_M35 -notcontains $_ })
$green_M35 = ($missing_M35.Count -eq 0)
Record-TestResult -Id "M35" -Name "RENAME ロールバック直前外部ファイル出現 (非上書き File.Move 失敗)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M35) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_API_PRIMITIVE" `
  -NormativeLiteral "[System.IO.File]::Move" `
  -StructuralInspection "Search for [System.IO.File]::Move method call for file renaming" `
  -RequiredComponents $req_M35 `
  -ObservedComponents $obs_M35 `
  -MissingComponents $missing_M35 `
  -GreenPredicate "FileMoveCalled -and RenameBound -and NonOverwritingVerified" `
  -SemanticAbsenceReason "Frozen contract requires non-overwriting File.Move for RENAME operations to prevent overwriting external files" `
  -ExecutionPerformed "API invocation search" `
  -AssertionPerformed "[System.IO.File]::Move present" `
  -ActualEvidence "[System.IO.File]::Move absent: $absent_M35"

# M36: 同一 SHA256/サイズの別オブジェクト存在時 Fail-Closed (STATIC_CAPABILITY)
$proof_M36 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Pre-Move Content Identity Guard"
$req_M36 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "PreMoveDestinationCheck", "ContentIdentityAttributionGuard", "FailClosedOnCollidingObject")
$obs_M36 = @()
if ($proof_M36.DispatchBranchFound) { $obs_M36 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M36 = @($req_M36 | Where-Object { $obs_M36 -notcontains $_ })
$green_M36 = ($missing_M36.Count -eq 0)
Record-TestResult -Id "M36" -Name "同一 SHA256/サイズの別オブジェクト検知時の Fail-Closed" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M36) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Pre-Move Object Identity Guard" `
  -DispatchBranchFound $proof_M36.DispatchBranchFound `
  -ReachableFunctions $proof_M36.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M36.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M36.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M36.ReachableStateSymbols `
  -StructuralProofResult $proof_M36.ProofResult `
  -RequiredComponents $req_M36 `
  -ObservedComponents $obs_M36 `
  -MissingComponents $missing_M36 `
  -GreenPredicate "ActionDispatchPresent -and PreMoveCheckPresent -and ContentIdentityGuarded -and FailClosedOnCollision" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable pre-move destination check or content identity verification control flow exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Pre-move object identity guard exists" `
  -ActualEvidence $proof_M36.ProofResult

# M37: v1 空ソースフォルダ温存後の UUID_FOLDER_CONFLICT 再発なし (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M37" -EnvironmentRequirement "NONE" -ActivationBoundary "CUSTOMER_SCAN_EMPTY_FOLDER_TOLERANCE" -Name "v1 空ソースフォルダ温存後の UUID_FOLDER_CONFLICT 再発なし" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "Empty customer folders tolerated in customer scan without error" `
  -PreconditionsObserved "Current customer scan in v9.0.4 treats empty customer folders as invalid/conflicting" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until customer scan scanner modification" `
  -AssertionPerformed "CHECK action ignores empty retained customer folders" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of empty folder tolerance in customer scanner"

# M38: ソースフォルダ内 Hidden ファイル温存 (DIRECT_EXECUTION)
$vM38 = Join-Path $TestRoot "V_M38"
Reset-TestVault $vM38
$f1_M38 = Join-Path $vM38 "01_顧客\株式会社テスト_A"
$f2_M38 = Join-Path $vM38 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M38 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M38 "🟥事故_テスト.md" $uuid1 "事故"
$hiddenFile_M38 = Join-Path $f1_M38 ".hidden_data"
Write-MockFile $hiddenFile_M38 "隠しデータ"
(Get-Item -LiteralPath $hiddenFile_M38 -Force).Attributes = [System.IO.FileAttributes]::Hidden
$pre_M38 = (Test-Path -LiteralPath $hiddenFile_M38) -and (((Get-Item -LiteralPath $hiddenFile_M38 -Force).Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0)
$res_M38 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M38"; VaultRoot = $vM38; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M38 = ($null -eq $res_M38.Json -or $res_M38.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M38" -Name "ソースフォルダ内 Hidden ファイルの捕捉・温存" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M38) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "File with FileAttributes.Hidden exists in source folder" `
  -PreconditionsObserved "Hidden file created and verified with -Force (PreconditionPass: $pre_M38)" `
  -PreconditionPass $pre_M38 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_PLAN_READY with hidden file captured" `
  -ActualEvidence "Observed: $($res_M38.Stdout.Trim())"

# M39: Hidden / System ディレクトリのスナップショット捕捉 (DIRECT_EXECUTION)
$vM39 = Join-Path $TestRoot "V_M39"
Reset-TestVault $vM39
$f1_M39 = Join-Path $vM39 "01_顧客\株式会社テスト_A"
$f2_M39 = Join-Path $vM39 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M39 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M39 "🟥事故_テスト.md" $uuid1 "事故"
$hiddenDir_M39 = Join-Path $f1_M39 ".hidden_dir"
New-Item -ItemType Directory -Path $hiddenDir_M39 -Force | Out-Null
(Get-Item -LiteralPath $hiddenDir_M39 -Force).Attributes = [System.IO.FileAttributes]::Hidden
$pre_M39 = (Test-Path -LiteralPath $hiddenDir_M39) -and (((Get-Item -LiteralPath $hiddenDir_M39 -Force).Attributes -band [System.IO.FileAttributes]::Hidden) -ne 0)
$res_M39 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M39"; VaultRoot = $vM39; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M39 = ($null -eq $res_M39.Json -or $res_M39.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M39" -Name "Hidden / System ディレクトリのスナップショット捕捉" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M39) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Directory with FileAttributes.Hidden exists in source folder" `
  -PreconditionsObserved "Hidden directory created and verified with -Force (PreconditionPass: $pre_M39)" `
  -PreconditionPass $pre_M39 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_PLAN_READY with hidden dir captured" `
  -ActualEvidence "Observed: $($res_M39.Stdout.Trim())"

# M40: Reparse Point 検知時の MERGE_REPARSE_POINT_UNSUPPORTED (DIRECT_EXECUTION)
$vM40 = Join-Path $TestRoot "V_M40"
Reset-TestVault $vM40
$f1_M40 = Join-Path $vM40 "01_顧客\株式会社テスト_A"
$f2_M40 = Join-Path $vM40 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M40 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M40 "🟥事故_テスト.md" $uuid1 "事故"
$jTarget_M40 = Join-Path $vM40 "ExternalJunctionTarget"
$jLink_M40 = Join-Path $f1_M40 "JunctionFolder"
New-Item -ItemType Directory -Path $jTarget_M40 -Force | Out-Null
$pre_M40 = $false
try {
  $jItem = New-Item -ItemType Junction -Path $jLink_M40 -Target $jTarget_M40 -Force
  $pre_M40 = (Test-Path -LiteralPath $jLink_M40) -and ((($jItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0))
} catch {
  $pre_M40 = $false
}
$res_M40 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M40"; VaultRoot = $vM40; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M40 = ($null -eq $res_M40.Json -or $res_M40.Json.code -ne "MERGE_REPARSE_POINT_UNSUPPORTED")
Record-TestResult -Id "M40" -Name "Reparse Point 検知時の MERGE_REPARSE_POINT_UNSUPPORTED 停止" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M40) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "NTFS Junction (ReparsePoint) exists inside customer tree" `
  -PreconditionsObserved "Junction created, ReparsePoint attribute confirmed (PreconditionPass: $pre_M40)" `
  -PreconditionPass $pre_M40 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "code == MERGE_REPARSE_POINT_UNSUPPORTED" `
  -ActualEvidence "Observed: $($res_M40.Stdout.Trim())"

# M41: スキャン中 Access Denied 時の Fail-Closed (DIRECT_EXECUTION)
$vM41 = Join-Path $TestRoot "V_M41"
Reset-TestVault $vM41
$f1_M41 = Join-Path $vM41 "01_顧客\株式会社テスト_A"
$f2_M41 = Join-Path $vM41 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M41 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M41 "🟥事故_テスト.md" $uuid1 "事故"
$lockedFile_M41 = Join-Path $f1_M41 "アクセス拒否ファイル.md"
Write-MockFile $lockedFile_M41 "秘密メモ"
$pre_M41 = $false
$acl_M41 = Get-Acl -LiteralPath $lockedFile_M41
$rule_M41 = New-Object System.Security.AccessControl.FileSystemAccessRule([System.Security.Principal.WindowsIdentity]::GetCurrent().Name, "Read", "Deny")
$acl_M41.AddAccessRule($rule_M41)
try {
  Set-Acl -LiteralPath $lockedFile_M41 $acl_M41
  try {
    [System.IO.File]::ReadAllText($lockedFile_M41) | Out-Null
    $pre_M41 = $false
  } catch [System.UnauthorizedAccessException] {
    $pre_M41 = $true
  }
} catch {
  $pre_M41 = $false
}
$res_M41 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M41"; VaultRoot = $vM41; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
try {
  $acl_M41.RemoveAccessRule($rule_M41)
  Set-Acl -LiteralPath $lockedFile_M41 $acl_M41
} catch {}
$isRed_M41 = ($null -eq $res_M41.Json -or $res_M41.Json.status -ne "NG")
Record-TestResult -Id "M41" -Name "スキャン中 Access Denied 時の Fail-Closed" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M41) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Target file in customer tree has Read:Deny ACL causing UnauthorizedAccessException" `
  -PreconditionsObserved "Read:Deny set and verified throwing UnauthorizedAccessException (PreconditionPass: $pre_M41)" `
  -PreconditionPass $pre_M41 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "status == NG (Fail-Closed)" `
  -ActualEvidence "Observed: $($res_M41.Stdout.Trim())"

# M42: プロセス強制終了残存マーカー検知 (STATIC_CAPABILITY)
$absent_M42 = Assert-TargetSymbolAbsent "MERGE_RECOVERY_REQUIRED"
$req_M42 = @("ErrorCode:MERGE_RECOVERY_REQUIRED", "ResidueDetectionGate", "FailClosedRejection")
$obs_M42 = @()
if (-not $absent_M42) { $obs_M42 += "ErrorCode:MERGE_RECOVERY_REQUIRED" }
$missing_M42 = @($req_M42 | Where-Object { $obs_M42 -notcontains $_ })
$green_M42 = ($missing_M42.Count -eq 0)
Record-TestResult -Id "M42" -Name "プロセス強制終了残存マーカー検知 (MERGE_RECOVERY_REQUIRED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M42) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "MERGE_RECOVERY_REQUIRED" `
  -StructuralInspection "Symbol search for frozen normative code MERGE_RECOVERY_REQUIRED" `
  -RequiredComponents $req_M42 `
  -ObservedComponents $obs_M42 `
  -MissingComponents $missing_M42 `
  -GreenPredicate "ErrorCodePresent -and ResidueDetected -and FailClosedRejection" `
  -SemanticAbsenceReason "Frozen contract requires MERGE_RECOVERY_REQUIRED when uncompleted transaction markers are detected" `
  -ExecutionPerformed "Symbol search in production script text" `
  -AssertionPerformed "MERGE_RECOVERY_REQUIRED present" `
  -ActualEvidence "MERGE_RECOVERY_REQUIRED absent: $absent_M42"

# M43: ロールバック後 Live Re-Scan 不一致検知 (STATIC_CAPABILITY)
$proof_M43 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Post-Rollback Live Re-Scan Verification"
$req_M43 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "RollbackCompletionGate", "LiveReScanVerification", "MismatchFailClosed:MERGE_ROLLBACK_FAILED")
$obs_M43 = @()
if ($proof_M43.DispatchBranchFound) { $obs_M43 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M43 = @($req_M43 | Where-Object { $obs_M43 -notcontains $_ })
$green_M43 = ($missing_M43.Count -eq 0)
Record-TestResult -Id "M43" -Name "ロールバック後 Live Re-Scan 不一致検知 (MERGE_ROLLBACK_FAILED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M43) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Post-Rollback Live Re-Scan Verification" `
  -DispatchBranchFound $proof_M43.DispatchBranchFound `
  -ReachableFunctions $proof_M43.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M43.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M43.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M43.ReachableStateSymbols `
  -StructuralProofResult $proof_M43.ProofResult `
  -RequiredComponents $req_M43 `
  -ObservedComponents $obs_M43 `
  -MissingComponents $missing_M43 `
  -GreenPredicate "ActionDispatchPresent -and RollbackCompleted -and LiveReScanVerified -and MismatchFailClosed" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable rollback engine or post-rollback verification control flow exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Post-rollback live re-scan exists" `
  -ActualEvidence $proof_M43.ProofResult

# M44: 8.3 短縮名 vs ロングパス正規化 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M44" -EnvironmentRequirement "NTFS_8DOT3_NAME_AVAILABLE" -ActivationBoundary "PATH_RESOLVER_SHORT_NAME_SUPPORT" -Name "8.3 短縮名 vs ロングパス正規化による同一 Token 生成" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "Host NTFS volume generates 8.3 short name aliases" `
  -PreconditionsObserved "8.3 short name generation is disabled on host NTFS volume (D:)" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred: requires 8.3-enabled NTFS volume" `
  -AssertionPerformed "Short path and long path generate identical planToken" `
  -ActualEvidence "Host filesystem does not provide 8.3 short name representation" `
  -ActivationCondition "Requires 8.3-enabled NTFS volume (fsutil 8dot3name set 0) and Win32CanonicalPath implementation"

# M45: Unicode コードポイント保持による非 Collapse (DIRECT_EXECUTION)
$vM45 = Join-Path $TestRoot "V_M45"
Reset-TestVault $vM45
$f1_M45 = Join-Path $vM45 "01_顧客\株式会社テスト_A"
$f2_M45 = Join-Path $vM45 "01_顧客\株式会社テスト_B"
Create-MockNote $f1_M45 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M45 "🟥事故_テスト.md" $uuid1 "事故"
$nfcLeaf_M45 = "note_" + [char]0x304C + ".md"                                # U+304C (が)
$nfdLeaf_M45 = "note_" + [char]0x304B + [char]0x3099 + ".md"                # U+304B U+3099 (か + 結合濁点)
$nfcFile_M45 = Join-Path $f1_M45 $nfcLeaf_M45
$nfdFile_M45 = Join-Path $f1_M45 $nfdLeaf_M45
Write-MockFile $nfcFile_M45 "NFCノート"
Write-MockFile $nfdFile_M45 "NFDノート"

$nfcChars_M45 = ($nfcLeaf_M45.ToCharArray() | ForEach-Object { "U+{0:X4}" -f [int]$_ }) -join " "
$nfdChars_M45 = ($nfdLeaf_M45.ToCharArray() | ForEach-Object { "U+{0:X4}" -f [int]$_ }) -join " "

$pre_M45_exists = (Test-Path -LiteralPath $nfcFile_M45) -and (Test-Path -LiteralPath $nfdFile_M45)
$pre_M45_distinct = ([string]::CompareOrdinal($nfcLeaf_M45, $nfdLeaf_M45) -ne 0)
$pre_M45_nfcExact = $nfcLeaf_M45.Contains([string][char]0x304C) -and (-not $nfcLeaf_M45.Contains([string][char]0x3099))
$pre_M45_nfdExact = $nfdLeaf_M45.Contains([string][char]0x304B + [string][char]0x3099)
$pre_M45 = $pre_M45_exists -and $pre_M45_distinct -and $pre_M45_nfcExact -and $pre_M45_nfdExact

$res_M45 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M45"; VaultRoot = $vM45; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M45 = ($null -eq $res_M45.Json -or $res_M45.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M45" -Name "Unicode コードポイント保持による非 Collapse 検証" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M45) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "2 distinct files with NFC (U+304C) vs NFD (U+304B U+3099) exist in same folder without normalization" `
  -PreconditionsObserved "NFC: [$nfcChars_M45], NFD: [$nfdChars_M45], OrdinalDistinct: $pre_M45_distinct (PreconditionPass: $pre_M45)" `
  -PreconditionPass $pre_M45 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE (raw non-normalized paths)" `
  -AssertionPerformed "code == MERGE_PLAN_READY with distinct token identity" `
  -ActualEvidence "Observed: $($res_M45.Stdout.Trim())"

# M46: final verification エラー時の MERGE_COMPLETED 抑止 (STATIC_CAPABILITY)
$proof_M46 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Final Topology Verification Gate"
$req_M46 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "FinalVerificationReachable", "MergeCompletedSuppressedOnMismatch")
$obs_M46 = @()
if ($proof_M46.DispatchBranchFound) { $obs_M46 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
if ($targetScriptText.Contains("MERGE_COMPLETED") -and $targetScriptText.Contains("MERGE_FAILED_ROLLED_BACK")) { $obs_M46 += "FinalVerificationReachable" }
$missing_M46 = @($req_M46 | Where-Object { $obs_M46 -notcontains $_ })
$green_M46 = ($missing_M46.Count -eq 0)
Record-TestResult -Id "M46" -Name "final verification エラー時の MERGE_COMPLETED 抑止" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M46) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Final Topology Verification Gate" `
  -DispatchBranchFound $proof_M46.DispatchBranchFound `
  -ReachableFunctions $proof_M46.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M46.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M46.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M46.ReachableStateSymbols `
  -StructuralProofResult $proof_M46.ProofResult `
  -RequiredComponents $req_M46 `
  -ObservedComponents $obs_M46 `
  -MissingComponents $missing_M46 `
  -GreenPredicate "ActionDispatchPresent -and FinalVerificationReachable -and MergeCompletedSuppressed" `
  -SemanticAbsenceReason "Production script must suppress MERGE_COMPLETED when final verification fails" `
  -ExecutionPerformed "AST Action Dispatch & Reachability Analysis" `
  -AssertionPerformed "Final verification suppresses MERGE_COMPLETED on failure" `
  -ActualEvidence $proof_M46.ProofResult

# M47: 完全ファイル名指定 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M47" -EnvironmentRequirement "NONE" -ActivationBoundary "JOURNAL_ENGINE" -Name "完全ファイル名指定 (Exact Destination Semantics)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "APPLY file move execution with journal path recording" `
  -PreconditionsObserved "APPLY action not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until APPLY implementation" `
  -AssertionPerformed "Journal records exact destination file path rather than folder path" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of APPLY_CUSTOMER_FOLDER_MERGE exact destination semantics"

# M48: Case A における Persistent Residue Marker 作成 (STATIC_CAPABILITY)
$absent_M48 = Assert-TargetSymbolAbsent ".inprogress.json"
$req_M48 = @("Literal:.inprogress.json", "CreationMode:FileMode.CreateNew", "Durability:Flush(true)", "Verification:ReopenAndParse", "Ordering:BeforeCustomerMutation")
$obs_M48 = @()
if (-not $absent_M48) { $obs_M48 += "Literal:.inprogress.json" }
$missing_M48 = @($req_M48 | Where-Object { $obs_M48 -notcontains $_ })
$green_M48 = ($missing_M48.Count -eq 0)
Record-TestResult -Id "M48" -Name "Case A における Persistent Residue Marker 作成・検知" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M48) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral ".inprogress.json" `
  -StructuralInspection "Symbol search for .inprogress.json and CreateNew / Flush / Read-back verification" `
  -RequiredComponents $req_M48 `
  -ObservedComponents $obs_M48 `
  -MissingComponents $missing_M48 `
  -GreenPredicate "MarkerNamed -and ModeCreateNew -and FlushedTrue -and ReadBackVerified -and PreMutationOrdered" `
  -SemanticAbsenceReason "Frozen contract requires .inprogress.json marker generation with Flush(true) and read-back before customer mutation; components absent" `
  -ExecutionPerformed "Symbol and durable creation search" `
  -AssertionPerformed ".inprogress.json created with FileMode.CreateNew, Flush(true), and verified before mutation" `
  -ActualEvidence "Literal absent: $absent_M48, Observed: $($obs_M48.Count)/$($req_M48.Count)"

# M49: Staging リネーム後 marker 不一致検知 (STATIC_CAPABILITY)
$proof_M49 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Random Ownership Token Verification"
$req_M49 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "RandomTokenGeneration:256bit", "OwnershipMarkerFileCreation", "PostRenameTokenVerification", "MismatchFailClosed:MERGE_ROLLBACK_FAILED")
$obs_M49 = @()
if ($proof_M49.DispatchBranchFound) { $obs_M49 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M49 = @($req_M49 | Where-Object { $obs_M49 -notcontains $_ })
$green_M49 = ($missing_M49.Count -eq 0)
Record-TestResult -Id "M49" -Name "Staging リネーム後 marker 不一致検知 (MERGE_ROLLBACK_FAILED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M49) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "256-bit Random Ownership Token Verification" `
  -DispatchBranchFound $proof_M49.DispatchBranchFound `
  -ReachableFunctions $proof_M49.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M49.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M49.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M49.ReachableStateSymbols `
  -StructuralProofResult $proof_M49.ProofResult `
  -RequiredComponents $req_M49 `
  -ObservedComponents $obs_M49 `
  -MissingComponents $missing_M49 `
  -GreenPredicate "ActionDispatchPresent -and RandomTokenGenerated -and MarkerCreated -and TokenVerified -and MismatchFailClosed" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable cryptographic random token generation or ownership marker comparison control flow exists" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Random ownership token verification exists" `
  -ActualEvidence $proof_M49.ProofResult

# M50: マージ成功後 marker クリーンアップ契約 (STATIC_CAPABILITY)
$absent_M50 = Assert-TargetSymbolAbsent "TRANSACTION_MARKER_CLEANUP_PENDING"
$req_M50 = @("WarningCode:TRANSACTION_MARKER_CLEANUP_PENDING", "Lifecycle:PostCommittedCleanup", "SuccessPreservedWithWarning")
$obs_M50 = @()
if (-not $absent_M50) { $obs_M50 += "WarningCode:TRANSACTION_MARKER_CLEANUP_PENDING" }
$missing_M50 = @($req_M50 | Where-Object { $obs_M50 -notcontains $_ })
$green_M50 = ($missing_M50.Count -eq 0)
Record-TestResult -Id "M50" -Name "マージ成功後 marker クリーンアップ契約" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M50) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "TRANSACTION_MARKER_CLEANUP_PENDING" `
  -StructuralInspection "Search for TRANSACTION_MARKER_CLEANUP_PENDING warning and post-commit cleanup lifecycle" `
  -RequiredComponents $req_M50 `
  -ObservedComponents $obs_M50 `
  -MissingComponents $missing_M50 `
  -GreenPredicate "WarningCodePresent -and PostCommitLifecycle -and CommitMaintained" `
  -SemanticAbsenceReason "Frozen contract requires TRANSACTION_MARKER_CLEANUP_PENDING warning upon transaction marker deletion failure while maintaining commit success" `
  -ExecutionPerformed "Symbol and lifecycle search" `
  -AssertionPerformed "TRANSACTION_MARKER_CLEANUP_PENDING warning emitted on cleanup failure" `
  -ActualEvidence "Warning absent: $absent_M50, Observed: $($obs_M50.Count)/$($req_M50.Count)"

# M51: GetLongPathNameW による 8.3 短縮名展開実機検証 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M51" -EnvironmentRequirement "NTFS_8DOT3_NAME_AVAILABLE" -ActivationBoundary "PATH_RESOLVER_SHORT_NAME_SUPPORT" -Name "GetLongPathNameW による 8.3 短縮名展開実機検証" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "8.3 short names generated on host NTFS volume and Win32CanonicalPath available" `
  -PreconditionsObserved "8.3 short name generation is disabled on host NTFS volume (D:)" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred: requires 8.3-enabled NTFS volume" `
  -AssertionPerformed "GetLongPathNameW expands 8.3 short path to canonical long path" `
  -ActualEvidence "Host filesystem does not provide 8.3 short name representation" `
  -ActivationCondition "Requires 8.3-enabled NTFS volume and Win32CanonicalPath implementation"

# M52: 8.3 短縮表現 vs ロング表現での planToken V3 生成一致 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M52" -EnvironmentRequirement "NTFS_8DOT3_NAME_AVAILABLE" -ActivationBoundary "PATH_RESOLVER_SHORT_NAME_SUPPORT" -Name "8.3 短縮表現 vs ロング表現での planToken V3 生成一致" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "8.3 short names generated on host NTFS volume and Win32CanonicalPath available" `
  -PreconditionsObserved "8.3 short name generation is disabled on host NTFS volume (D:)" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred: requires 8.3-enabled NTFS volume" `
  -AssertionPerformed "Short path input and long path input produce identical planToken V3" `
  -ActualEvidence "Host filesystem does not provide 8.3 short name representation" `
  -ActivationCondition "Requires 8.3-enabled NTFS volume and Win32CanonicalPath implementation"

# M53: Unicode 等価異コードポイント名の非 Collapse (DIRECT_EXECUTION)
$vM53 = Join-Path $TestRoot "V_M53"
Reset-TestVault $vM53
$f1Leaf_M53 = "株式会社テスト_" + [char]0x304C                                 # U+304C (が)
$f2Leaf_M53 = "株式会社テスト_" + [char]0x304B + [char]0x3099                 # U+304B U+3099 (か + 結合濁点)
$f1_M53 = Join-Path $vM53 ("01_顧客\" + $f1Leaf_M53)
$f2_M53 = Join-Path $vM53 ("01_顧客\" + $f2Leaf_M53)
Create-MockNote $f1_M53 "🟨契約_テスト.md" $uuid1 "契約"
Create-MockNote $f2_M53 "🟥事故_テスト.md" $uuid1 "事故"

$f1Chars_M53 = ($f1Leaf_M53.ToCharArray() | ForEach-Object { "U+{0:X4}" -f [int]$_ }) -join " "
$f2Chars_M53 = ($f2Leaf_M53.ToCharArray() | ForEach-Object { "U+{0:X4}" -f [int]$_ }) -join " "

$pre_M53_exists = (Test-Path -LiteralPath $f1_M53) -and (Test-Path -LiteralPath $f2_M53)
$pre_M53_distinct = ([string]::CompareOrdinal($f1Leaf_M53, $f2Leaf_M53) -ne 0)
$pre_M53_f1Exact = $f1Leaf_M53.Contains([string][char]0x304C) -and (-not $f1Leaf_M53.Contains([string][char]0x3099))
$pre_M53_f2Exact = $f2Leaf_M53.Contains([string][char]0x304B + [string][char]0x3099)
$pre_M53 = $pre_M53_exists -and $pre_M53_distinct -and $pre_M53_f1Exact -and $pre_M53_f2Exact

$res_M53 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M53"; VaultRoot = $vM53; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M53 = ($null -eq $res_M53.Json -or $res_M53.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M53" -Name "Unicode 等価異コードポイント名の非 Collapse 検証" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M53) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "2 customer folders with NFC (U+304C) vs NFD (U+304B U+3099) leaf names exist simultaneously without labels" `
  -PreconditionsObserved "f1: [$f1Chars_M53], f2: [$f2Chars_M53], OrdinalDistinct: $pre_M53_distinct (PreconditionPass: $pre_M53)" `
  -PreconditionPass $pre_M53 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE (raw non-normalized folder paths)" `
  -AssertionPerformed "code == MERGE_PLAN_READY with distinct token identity" `
  -ActualEvidence "Observed: $($res_M53.Stdout.Trim())"

# M54: COMMITTED 成立後マーカー削除失敗 (STATIC_CAPABILITY)
$absent_M54 = Assert-TargetSymbolAbsent "TRANSACTION_MARKER_CLEANUP_PENDING"
$req_M54 = @("WarningCode:TRANSACTION_MARKER_CLEANUP_PENDING", "CommitDurableStateMaintained", "NonRollbackExecution")
$obs_M54 = @()
if (-not $absent_M54) { $obs_M54 += "WarningCode:TRANSACTION_MARKER_CLEANUP_PENDING" }
$missing_M54 = @($req_M54 | Where-Object { $obs_M54 -notcontains $_ })
$green_M54 = ($missing_M54.Count -eq 0)
Record-TestResult -Id "M54" -Name "COMMITTED 成立後マーカー削除失敗 (warning: TRANSACTION_MARKER_CLEANUP_PENDING)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M54) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "TRANSACTION_MARKER_CLEANUP_PENDING" `
  -StructuralInspection "Symbol search for frozen normative warning code TRANSACTION_MARKER_CLEANUP_PENDING and commit retention" `
  -RequiredComponents $req_M54 `
  -ObservedComponents $obs_M54 `
  -MissingComponents $missing_M54 `
  -GreenPredicate "WarningCodePresent -and CommitMaintained -and NoRollback" `
  -SemanticAbsenceReason "Frozen contract requires commit success with TRANSACTION_MARKER_CLEANUP_PENDING warning upon marker deletion failure; components absent" `
  -ExecutionPerformed "Symbol and commit retention search" `
  -AssertionPerformed "Warning code present and commit maintained" `
  -ActualEvidence "Warning absent: $absent_M54, Observed: $($obs_M54.Count)/$($req_M54.Count)"

# M55: COMMITTED 更新失敗時の Fail-Closed ロールバック (STATIC_CAPABILITY)
$absent_M55 = Assert-TargetSymbolAbsent ".committed.json"
$req_M55 = @("Literal:.committed.json", "ImmutableCommitCreation", "Durability:Flush(true)", "FailClosedRollbackOnCreationFailure")
$obs_M55 = @()
if (-not $absent_M55) { $obs_M55 += "Literal:.committed.json" }
$missing_M55 = @($req_M55 | Where-Object { $obs_M55 -notcontains $_ })
$green_M55 = ($missing_M55.Count -eq 0)
Record-TestResult -Id "M55" -Name "COMMITTED 更新失敗時の Fail-Closed ロールバック" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M55) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral ".committed.json" `
  -StructuralInspection "Symbol search for frozen normative immutable commit marker extension .committed.json and rollback on failure" `
  -RequiredComponents $req_M55 `
  -ObservedComponents $obs_M55 `
  -MissingComponents $missing_M55 `
  -GreenPredicate "CommittedNamed -and ImmutableCreated -and FlushedTrue -and RollbackOnFailure" `
  -SemanticAbsenceReason "Frozen contract requires .committed.json creation with Flush(true) and rollback upon its failure; components absent" `
  -ExecutionPerformed "Symbol and commit failure rollback search" `
  -AssertionPerformed ".committed.json created and rollback triggered on commit write failure" `
  -ActualEvidence "Literal absent: $absent_M55, Observed: $($obs_M55.Count)/$($req_M55.Count)"

# M56: 残存 COMMITTED マーカーの遅延クリーンアップ (STATIC_CAPABILITY)
$proof_M56 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Delayed COMMITTED Cleanup Handler"
$req_M56 = @("ManagedOperationEntryInspection", "CommittedResidueDetection", "DelayedCleanupGarbageCollection", "NormalOperationNonBlocking")
$obs_M56 = @()
# 過剰推論排除: 実体検出のみ
$missing_M56 = @($req_M56 | Where-Object { $obs_M56 -notcontains $_ })
$green_M56 = ($missing_M56.Count -eq 0)
Record-TestResult -Id "M56" -Name "残存 COMMITTED マーカーの遅延クリーンアップ・通常操作継続" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M56) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Delayed COMMITTED Cleanup Handler" `
  -DispatchBranchFound $proof_M56.DispatchBranchFound `
  -ReachableFunctions $proof_M56.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M56.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M56.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M56.ReachableStateSymbols `
  -StructuralProofResult $proof_M56.ProofResult `
  -RequiredComponents $req_M56 `
  -ObservedComponents $obs_M56 `
  -MissingComponents $missing_M56 `
  -GreenPredicate "EntryInspected -and ResidueDetected -and DelayedGCExecuted -and NormalOpUnblocked" `
  -SemanticAbsenceReason "Production script lacks control directory residue scanner and delayed COMMITTED marker cleanup control flow" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Delayed COMMITTED cleanup logic exists" `
  -ActualEvidence $proof_M56.ProofResult

# M57: Canonical 内所有権マーカー削除失敗時のコミット維持 (STATIC_CAPABILITY)
$absent_M57 = Assert-TargetSymbolAbsent "OWNERSHIP_MARKER_CLEANUP_PENDING"
$req_M57 = @("WarningCode:OWNERSHIP_MARKER_CLEANUP_PENDING", "CanonicalMarkerDeletionAttempt", "EvidenceRetentionOrdering")
$obs_M57 = @()
if (-not $absent_M57) { $obs_M57 += "WarningCode:OWNERSHIP_MARKER_CLEANUP_PENDING" }
$missing_M57 = @($req_M57 | Where-Object { $obs_M57 -notcontains $_ })
$green_M57 = ($missing_M57.Count -eq 0)
Record-TestResult -Id "M57" -Name "Canonical 内所有権マーカー削除失敗時のコミット維持" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M57) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "OWNERSHIP_MARKER_CLEANUP_PENDING" `
  -StructuralInspection "Symbol search for frozen normative warning code OWNERSHIP_MARKER_CLEANUP_PENDING and retention ordering" `
  -RequiredComponents $req_M57 `
  -ObservedComponents $obs_M57 `
  -MissingComponents $missing_M57 `
  -GreenPredicate "WarningCodePresent -and DeletionAttempted -and ControlEvidenceRetained" `
  -SemanticAbsenceReason "Frozen contract requires OWNERSHIP_MARKER_CLEANUP_PENDING warning upon ownership marker cleanup failure; components absent" `
  -ExecutionPerformed "Symbol and cleanup ordering search" `
  -AssertionPerformed "Warning code present and control evidence retained" `
  -ActualEvidence "Warning absent: $absent_M57, Observed: $($obs_M57.Count)/$($req_M57.Count)"

# M58: planToken V3 Binary Golden Vector (STATIC_CAPABILITY)
$absent_M58_magic = Assert-TargetSymbolAbsent "FMOBSMERGE"
$hasTokenSerializer = $targetScriptText.Contains("FMOBSMERGE") -or $targetScriptText.Contains("0x46, 0x4D, 0x4F, 0x42")
$req_M58 = @("MagicHeader:FMOBSMERGE", "SchemaVersion:UInt16_3", "LengthFraming:UInt32", "RawUtf8Encoding", "RawSha256Bytes", "OrdinalFieldOrdering", "SerializerCapability")
$obs_M58 = @()
if (-not $absent_M58_magic) { $obs_M58 += "MagicHeader:FMOBSMERGE" }
if ($hasTokenSerializer) { $obs_M58 += "SerializerCapability" }
$missing_M58 = @($req_M58 | Where-Object { $obs_M58 -notcontains $_ })
$green_M58 = ($missing_M58.Count -eq 0)
Record-TestResult -Id "M58" -Name "planToken V3 Binary Golden Vector 検証" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M58) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "FMOBSMERGE magic header & planToken V3 binary serializer" `
  -StructuralInspection "Search for frozen normative magic bytes FMOBSMERGE and full binary packing serializer components" `
  -RequiredComponents $req_M58 `
  -ObservedComponents $obs_M58 `
  -MissingComponents $missing_M58 `
  -GreenPredicate "MagicPresent -and Version3 -and LengthFramed -and RawUtf8 -and RawSha256 -and OrdinalSorted -and SerializerPresent" `
  -SemanticAbsenceReason "Frozen contract requires planToken V3 binary format with FMOBSMERGE magic and full serializer; all components absent" `
  -ExecutionPerformed "Normative literal & structural binary serializer reachability search" `
  -AssertionPerformed "FMOBSMERGE magic header and binary serializer fully satisfy Golden Vector contract" `
  -ActualEvidence "FMOBSMERGE absent: $absent_M58_magic, Observed: $($obs_M58.Count)/$($req_M58.Count)"

# M59: ACTIVE.lock 排他制御 (STATIC_CAPABILITY)
$hasValidAcq_M59 = Test-LockAcquisitionValid -ScriptAst $targetAst -ScriptText $targetScriptText
$enclosed_OPEN = Test-LockFullLifetimeEnclosure -ActionName "OPEN" -ScriptAst $targetAst -ScriptText $targetScriptText
$enclosed_CHECK = Test-LockFullLifetimeEnclosure -ActionName "CHECK" -ScriptAst $targetAst -ScriptText $targetScriptText
$enclosed_COMPARE = Test-LockFullLifetimeEnclosure -ActionName "COMPARE" -ScriptAst $targetAst -ScriptText $targetScriptText
$enclosed_PLAN = Test-LockFullLifetimeEnclosure -ActionName "PLAN_CUSTOMER_FOLDER_MERGE" -ScriptAst $targetAst -ScriptText $targetScriptText
$enclosed_APPLY = Test-LockFullLifetimeEnclosure -ActionName "APPLY_CUSTOMER_FOLDER_MERGE" -ScriptAst $targetAst -ScriptText $targetScriptText
$enclosed_UPDATE = Test-LockFullLifetimeEnclosure -ActionName "UPDATE_CUSTOMER_IDENTITY" -ScriptAst $targetAst -ScriptText $targetScriptText

$req_M59 = @(
  "LockAcquisition:ACTIVE.lock+FileShare.None",
  "Enclosure:OPEN",
  "Enclosure:CHECK",
  "Enclosure:COMPARE",
  "Enclosure:PLAN_CUSTOMER_FOLDER_MERGE",
  "Enclosure:APPLY_CUSTOMER_FOLDER_MERGE",
  "Enclosure:UPDATE_CUSTOMER_IDENTITY"
)
$obs_M59 = @()
if ($hasValidAcq_M59) { $obs_M59 += "LockAcquisition:ACTIVE.lock+FileShare.None" }
if ($enclosed_OPEN) { $obs_M59 += "Enclosure:OPEN" }
if ($enclosed_CHECK) { $obs_M59 += "Enclosure:CHECK" }
if ($enclosed_COMPARE) { $obs_M59 += "Enclosure:COMPARE" }
if ($enclosed_PLAN) { $obs_M59 += "Enclosure:PLAN_CUSTOMER_FOLDER_MERGE" }
if ($enclosed_APPLY) { $obs_M59 += "Enclosure:APPLY_CUSTOMER_FOLDER_MERGE" }
if ($enclosed_UPDATE) { $obs_M59 += "Enclosure:UPDATE_CUSTOMER_IDENTITY" }

$missing_M59 = @($req_M59 | Where-Object { $obs_M59 -notcontains $_ })
$green_M59 = ($missing_M59.Count -eq 0)
Record-TestResult -Id "M59" -Name "ACTIVE.lock 排他制御 (parallel APPLY 競合: MERGE_OPERATION_IN_PROGRESS)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M59) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "ACTIVE.lock & FileShare.None" `
  -StructuralInspection "Search for normative lock file name ACTIVE.lock and FileShare.None exclusive handle acquisition across all managed operations" `
  -RequiredComponents $req_M59 `
  -ObservedComponents $obs_M59 `
  -MissingComponents $missing_M59 `
  -GreenPredicate "LockAcquisitionValid -and AllManagedOperationsEnclosed" `
  -SemanticAbsenceReason "Frozen contract normatively requires same-handle ACTIVE.lock with FileShare.None across all managed operations; components absent" `
  -ExecutionPerformed "AST same-handle lifetime and enclosure search" `
  -AssertionPerformed "ACTIVE.lock with FileShare.None held across entire managed operation lifetime for all operations" `
  -ActualEvidence "Valid Lock Acquisition: $hasValidAcq_M59, Observed Enclosures: $($obs_M59.Count)/$($req_M59.Count)"

# M60: PENDING MOVE 誤移動防止 (Option B) (STATIC_CAPABILITY)
$proof_M60 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Option B Non-destructive PENDING Rollback Restriction"
$req_M60 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "JournalStateMachine:MOVE_FILE", "StateBranch:PENDING", "DestructiveMoveProhibition", "OptionBFailClosed")
$obs_M60 = @()
if ($proof_M60.DispatchBranchFound) { $obs_M60 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M60 = @($req_M60 | Where-Object { $obs_M60 -notcontains $_ })
$green_M60 = ($missing_M60.Count -eq 0)
Record-TestResult -Id "M60" -Name "PENDING MOVE 誤移動防止 (Option B: MERGE_ROLLBACK_FAILED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M60) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Option B Non-destructive PENDING Rollback Restriction" `
  -DispatchBranchFound $proof_M60.DispatchBranchFound `
  -ReachableFunctions $proof_M60.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M60.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M60.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M60.ReachableStateSymbols `
  -StructuralProofResult $proof_M60.ProofResult `
  -RequiredComponents $req_M60 `
  -ObservedComponents $obs_M60 `
  -MissingComponents $missing_M60 `
  -GreenPredicate "ActionDispatchPresent -and JournalMovePresent -and StatePendingPresent -and DestructiveMoveProhibited -and OptionBFailClosed" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable journal state machine or file move rollback branch exists, so Option B wrong-object undo prohibition is absent" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Option B non-destructive rollback logic exists" `
  -ActualEvidence $proof_M60.ProofResult

# M61: トランザクション A 実行中のトランザクション B 開始拒否 (STATIC_CAPABILITY)
$absent_M61 = Assert-TargetSymbolAbsent "MERGE_OPERATION_IN_PROGRESS"
$req_M61 = @("ErrorCode:MERGE_OPERATION_IN_PROGRESS", "LockContentionMapping:UnauthorizedOrSharingViolation", "RejectionResponseWithoutMutation")
$obs_M61 = @()
if (-not $absent_M61) { $obs_M61 += "ErrorCode:MERGE_OPERATION_IN_PROGRESS" }
$missing_M61 = @($req_M61 | Where-Object { $obs_M61 -notcontains $_ })
$green_M61 = ($missing_M61.Count -eq 0)
Record-TestResult -Id "M61" -Name "トランザクション A 実行中のトランザクション B 開始拒否" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M61) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "MERGE_OPERATION_IN_PROGRESS" `
  -StructuralInspection "Symbol search for frozen normative error code MERGE_OPERATION_IN_PROGRESS and lock contention mapping" `
  -RequiredComponents $req_M61 `
  -ObservedComponents $obs_M61 `
  -MissingComponents $missing_M61 `
  -GreenPredicate "ErrorCodePresent -and ContentionMapped -and MutationSuppressed" `
  -SemanticAbsenceReason "Frozen contract requires MERGE_OPERATION_IN_PROGRESS upon concurrent lock contention; components absent" `
  -ExecutionPerformed "Symbol and lock contention search" `
  -AssertionPerformed "MERGE_OPERATION_IN_PROGRESS mapped from lock contention" `
  -ActualEvidence "Error code absent: $absent_M61, Observed: $($obs_M61.Count)/$($req_M61.Count)"

# M62: IN_PROGRESS マーカー残存時の MERGE_RECOVERY_REQUIRED 停止 (STATIC_CAPABILITY)
$proof_M62 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Transaction Residue Guard for IN_PROGRESS"
$req_M62 = @("ManagedOperationEntryScan", "InProgressResidueDetection", "FailClosedRecoveryStop:MERGE_RECOVERY_REQUIRED")
$obs_M62 = @()
# 過剰推論排除: 実体検出のみ
$missing_M62 = @($req_M62 | Where-Object { $obs_M62 -notcontains $_ })
$green_M62 = ($missing_M62.Count -eq 0)
Record-TestResult -Id "M62" -Name "IN_PROGRESS マーカー残存時の MERGE_RECOVERY_REQUIRED 停止" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M62) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Transaction Residue Guard for IN_PROGRESS" `
  -DispatchBranchFound $proof_M62.DispatchBranchFound `
  -ReachableFunctions $proof_M62.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M62.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M62.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M62.ReachableStateSymbols `
  -StructuralProofResult $proof_M62.ProofResult `
  -RequiredComponents $req_M62 `
  -ObservedComponents $obs_M62 `
  -MissingComponents $missing_M62 `
  -GreenPredicate "EntryScanPresent -and InProgressDetected -and FailClosedRecoveryStopped" `
  -SemanticAbsenceReason "Production script lacks control directory scanner and residue guard control flow to detect uncompleted transactions" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "IN_PROGRESS residue guard exists" `
  -ActualEvidence $proof_M62.ProofResult

# M63: 破損 COMMITTED マーカー検知 (STATIC_CAPABILITY)
$proof_M63 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Corrupt / Malformed Marker Guard"
$req_M63 = @("MarkerFileDeserialization", "SchemaValidation", "MalformedMarkerTrap:MERGE_RECOVERY_REQUIRED")
$obs_M63 = @()
# 過剰推論排除: 実体検出のみ
$missing_M63 = @($req_M63 | Where-Object { $obs_M63 -notcontains $_ })
$green_M63 = ($missing_M63.Count -eq 0)
Record-TestResult -Id "M63" -Name "破損 COMMITTED マーカー検知時の MERGE_RECOVERY_REQUIRED 停止" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M63) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Corrupt / Malformed Marker Guard" `
  -DispatchBranchFound $proof_M63.DispatchBranchFound `
  -ReachableFunctions $proof_M63.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M63.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M63.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M63.ReachableStateSymbols `
  -StructuralProofResult $proof_M63.ProofResult `
  -RequiredComponents $req_M63 `
  -ObservedComponents $obs_M63 `
  -MissingComponents $missing_M63 `
  -GreenPredicate "Deserialized -and SchemaValidated -and MalformedTrapped" `
  -SemanticAbsenceReason "Production script lacks marker file deserialization and corruption handling control flow" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Malformed marker guard exists" `
  -ActualEvidence $proof_M63.ProofResult

# M64: Control Directory Bootstrap 境界クラッシュ (STATIC_CAPABILITY)
$absent_M64 = Assert-TargetSymbolAbsent ".fm-obsidian-bridge-transactions"
$req_M64 = @("DirectoryName:.fm-obsidian-bridge-transactions", "BootstrapPreMutation", "CrashRecoveryCleanliness")
$obs_M64 = @()
if (-not $absent_M64) { $obs_M64 += "DirectoryName:.fm-obsidian-bridge-transactions" }
$missing_M64 = @($req_M64 | Where-Object { $obs_M64 -notcontains $_ })
$green_M64 = ($missing_M64.Count -eq 0)
Record-TestResult -Id "M64" -Name "Control Directory Bootstrap 境界クラッシュ時の顧客変更 0 件確認" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M64) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral ".fm-obsidian-bridge-transactions" `
  -StructuralInspection "Symbol search for frozen normative control directory name .fm-obsidian-bridge-transactions and pre-mutation bootstrap" `
  -RequiredComponents $req_M64 `
  -ObservedComponents $obs_M64 `
  -MissingComponents $missing_M64 `
  -GreenPredicate "DirNamed -and PreMutationBootstrapped -and CrashClean" `
  -SemanticAbsenceReason "Frozen contract requires bootstrap and lifecycle management of .fm-obsidian-bridge-transactions; components absent" `
  -ExecutionPerformed "Symbol and directory lifecycle search" `
  -AssertionPerformed "Control directory bootstrapped before customer mutation" `
  -ActualEvidence "Dir name absent: $absent_M64, Observed: $($obs_M64.Count)/$($req_M64.Count)"

# M65: Control Root 不正時の Fail-Closed 停止 (STATIC_CAPABILITY)
$proof_M65 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Control Directory Boundary & ReparsePoint Validation"
$req_M65 = @("ControlRootResolution", "ReparsePointInspection", "DirectoryBoundaryEnforcement", "FailClosedOnAnomaly")
$obs_M65 = @()
# 過剰推論排除: 実体検出のみ
$missing_M65 = @($req_M65 | Where-Object { $obs_M65 -notcontains $_ })
$green_M65 = ($missing_M65.Count -eq 0)
Record-TestResult -Id "M65" -Name "Control Root 不正時の Fail-Closed 停止" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M65) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Control Directory Boundary & ReparsePoint Validation" `
  -DispatchBranchFound $proof_M65.DispatchBranchFound `
  -ReachableFunctions $proof_M65.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M65.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M65.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M65.ReachableStateSymbols `
  -StructuralProofResult $proof_M65.ProofResult `
  -RequiredComponents $req_M65 `
  -ObservedComponents $obs_M65 `
  -MissingComponents $missing_M65 `
  -GreenPredicate "RootResolved -and ReparseInspected -and BoundaryEnforced -and AnomalyFailClosed" `
  -SemanticAbsenceReason "Production script lacks control root boundary check and ReparsePoint validation control flow" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Control root boundary guard exists" `
  -ActualEvidence $proof_M65.ProofResult

# M66: Ownership マーカー削除失敗時の Control Evidence 温存 (STATIC_CAPABILITY)
$proof_M66 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Cleanup Ordering & Control Retention Logic"
$req_M66 = @("OrderedCleanupLifecycle", "OwnershipMarkerDeletionFirst", "ControlEvidenceDeletionSecond", "RetentionOnOwnershipFailure")
$obs_M66 = @()
# 過剰推論排除: 実体検出のみ
$missing_M66 = @($req_M66 | Where-Object { $obs_M66 -notcontains $_ })
$green_M66 = ($missing_M66.Count -eq 0)
Record-TestResult -Id "M66" -Name "Ownership マーカー削除失敗時の Control Evidence 温存" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M66) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Cleanup Ordering & Control Retention Logic" `
  -DispatchBranchFound $proof_M66.DispatchBranchFound `
  -ReachableFunctions $proof_M66.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M66.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M66.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M66.ReachableStateSymbols `
  -StructuralProofResult $proof_M66.ProofResult `
  -RequiredComponents $req_M66 `
  -ObservedComponents $obs_M66 `
  -MissingComponents $missing_M66 `
  -GreenPredicate "OrderedLifecycle -and OwnershipFirst -and ControlSecond -and RetainedOnFailure" `
  -SemanticAbsenceReason "Production script lacks ordered cleanup logic retaining control evidence upon ownership marker deletion failure" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Control retention logic exists" `
  -ActualEvidence $proof_M66.ProofResult

# M67: Case-Sensitive NTFS ディレクトリ検知時の安全停止 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M67" -EnvironmentRequirement "NTFS_CASE_SENSITIVE_DIRECTORY_CREATABLE" -ActivationBoundary "NTFS_CASE_SENSITIVE_DIRECTORY_SUPPORT" -Name "Case-Sensitive NTFS ディレクトリ検知時の安全停止" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "NTFS directory with per-directory case-sensitivity enabled" `
  -PreconditionsObserved "fsutil file setCaseSensitiveInfo requires Administrator privilege; current un-elevated account returned Access is denied" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred: requires elevated privilege for NTFS attribute configuration" `
  -AssertionPerformed "code == MERGE_CASE_SENSITIVE_DIRECTORY_UNSUPPORTED" `
  -ActualEvidence "Cannot configure case-sensitive directory attribute under un-elevated test execution" `
  -ActivationCondition "Requires elevated administrator privilege to enable NTFS case-sensitivity on test directory"

# M68: 破損/空/未知マーカー検知時の MERGE_RECOVERY_REQUIRED (STATIC_CAPABILITY)
$proof_M68 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Unknown / Corrupted Marker Fail-Safe"
$req_M68 = @("MarkerScanner", "EmptyFileCheck", "UnknownPrefixCheck", "FailSafeRecoveryTrap")
$obs_M68 = @()
# 過剰推論排除: 実体検出のみ
$missing_M68 = @($req_M68 | Where-Object { $obs_M68 -notcontains $_ })
$green_M68 = ($missing_M68.Count -eq 0)
Record-TestResult -Id "M68" -Name "破損/空/未知マーカー検知時の MERGE_RECOVERY_REQUIRED" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M68) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Unknown / Corrupted Marker Fail-Safe" `
  -DispatchBranchFound $proof_M68.DispatchBranchFound `
  -ReachableFunctions $proof_M68.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M68.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M68.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M68.ReachableStateSymbols `
  -StructuralProofResult $proof_M68.ProofResult `
  -RequiredComponents $req_M68 `
  -ObservedComponents $obs_M68 `
  -MissingComponents $missing_M68 `
  -GreenPredicate "ScannerPresent -and EmptyChecked -and UnknownPrefixChecked -and FailSafeTrapped" `
  -SemanticAbsenceReason "Production script lacks marker scanning and unknown file fail-safe control flow" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Marker fail-safe guard exists" `
  -ActualEvidence $proof_M68.ProofResult

# M69: FileStream.Flush(true) + read-back 検証 (STATIC_CAPABILITY)
$absent_M69_flush = Assert-TargetMemberCallAbsent "FileStream" "Flush"
$hasFlushTrue = $targetScriptText.Contains(".Flush(`$true)") -or $targetScriptText.Contains(".Flush(true)")
$hasReadBack = $targetScriptText.Contains(".inprogress.json") -and ($targetScriptText.Contains("ReadAllText") -or $targetScriptText.Contains("ConvertFrom-Json"))
$req_M69 = @("MethodCall:Flush", "BooleanArgument:true", "TransactionStreamContext", "ReopenReadBackVerification", "FieldIntegrityCheck")
$obs_M69 = @()
if (-not $absent_M69_flush) { $obs_M69 += "MethodCall:Flush" }
if ($hasFlushTrue) { $obs_M69 += "BooleanArgument:true" }
if ($hasReadBack) { $obs_M69 += "ReopenReadBackVerification" }
$missing_M69 = @($req_M69 | Where-Object { $obs_M69 -notcontains $_ })
$green_M69 = ($missing_M69.Count -eq 0)
Record-TestResult -Id "M69" -Name "FileStream.Flush(true) + read-back 検証" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M69) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_API_PRIMITIVE" `
  -NormativeLiteral "FileStream.Flush(true)" `
  -StructuralInspection "AST search for InvokeMemberExpressionAst invoking Flush on FileStream with $true and durable read-back" `
  -RequiredComponents $req_M69 `
  -ObservedComponents $obs_M69 `
  -MissingComponents $missing_M69 `
  -GreenPredicate "FlushCalled -and ArgTrue -and StreamBound -and ReadBackVerified -and FieldsValidated" `
  -SemanticAbsenceReason "Frozen contract normatively requires FileStream.Flush(true) for durable disk commit and reopen read-back verification; all components absent" `
  -ExecutionPerformed "AST member expression and read-back verification search" `
  -AssertionPerformed "FileStream.Flush($true) invoked and marker read-back verified before customer mutation" `
  -ActualEvidence "Flush call absent: $absent_M69_flush, Observed: $($obs_M69.Count)/$($req_M69.Count)"

# M70: valid COMMITTED + IN_PROGRESS 共存時の COMMITTED 優先 (STATIC_CAPABILITY)
$proof_M70 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Coexistence Phase Priority Resolution"
$req_M70 = @("DualMarkerDetection", "PhasePriorityOrdering", "CommittedPhasePrecedence", "NormalOperationRecoveryContinuation")
$obs_M70 = @()
# 過剰推論排除: 実体検出のみ
$missing_M70 = @($req_M70 | Where-Object { $obs_M70 -notcontains $_ })
$green_M70 = ($missing_M70.Count -eq 0)
Record-TestResult -Id "M70" -Name "valid COMMITTED + IN_PROGRESS 共存時の COMMITTED 優先判定" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M70) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Coexistence Phase Priority Resolution" `
  -DispatchBranchFound $proof_M70.DispatchBranchFound `
  -ReachableFunctions $proof_M70.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M70.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M70.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M70.ReachableStateSymbols `
  -StructuralProofResult $proof_M70.ProofResult `
  -RequiredComponents $req_M70 `
  -ObservedComponents $obs_M70 `
  -MissingComponents $missing_M70 `
  -GreenPredicate "DualDetected -and PriorityOrdered -and CommittedPrecedence -and RecoveryContinued" `
  -SemanticAbsenceReason "Production script lacks dual-marker coexistence resolution control flow prioritizing COMMITTED evidence" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Coexistence phase resolution exists" `
  -ActualEvidence $proof_M70.ProofResult

# M71: PENDING RENAME 破壊的自動 Undo 禁止 (Option B) (STATIC_CAPABILITY)
$proof_M71 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Option B Non-destructive RENAME Rollback Restriction"
$req_M71 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "JournalStateMachine:RENAME_FILE", "StateBranch:PENDING", "DestructiveRenameProhibition", "OptionBFailClosed")
$obs_M71 = @()
if ($proof_M71.DispatchBranchFound) { $obs_M71 += "ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE" }
$missing_M71 = @($req_M71 | Where-Object { $obs_M71 -notcontains $_ })
$green_M71 = ($missing_M71.Count -eq 0)
Record-TestResult -Id "M71" -Name "PENDING RENAME 破壊的自動 Undo 禁止 (Option B: MERGE_ROLLBACK_FAILED)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M71) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Option B Non-destructive RENAME Rollback Restriction" `
  -DispatchBranchFound $proof_M71.DispatchBranchFound `
  -ReachableFunctions $proof_M71.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M71.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M71.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M71.ReachableStateSymbols `
  -StructuralProofResult $proof_M71.ProofResult `
  -RequiredComponents $req_M71 `
  -ObservedComponents $obs_M71 `
  -MissingComponents $missing_M71 `
  -GreenPredicate "ActionDispatchPresent -and JournalRenamePresent -and StatePendingPresent -and DestructiveRenameProhibited -and OptionBFailClosed" `
  -SemanticAbsenceReason "Production script lacks APPLY action dispatch; no reachable journal state machine or file rename rollback branch exists, so Option B prohibition of rename undo is absent" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Option B non-destructive rename rollback logic exists" `
  -ActualEvidence $proof_M71.ProofResult

# M72: Hash 計算中ファイル並行変更検知 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M72" -EnvironmentRequirement "DETERMINISTIC_LATENCY_SEAM_AVAILABLE" -ActivationBoundary "SCAN_ENGINE_LATENCY_SEAM" -Name "Hash 計算中ファイル並行変更検知 (SCAN_UNSTABLE)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "Deterministic race window during hash calculation" `
  -PreconditionsObserved "Hashing and scan routines are instant; cannot inject deterministic concurrent modification without modifying production code" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred: requires test seam or latency injection" `
  -AssertionPerformed "code == MERGE_PLAN_STALE upon metadata change during hash scan" `
  -ActualEvidence "Cannot inject race condition into production without modifying source" `
  -ActivationCondition "Requires implementation of scan engine and test latency injection seam"

# M73: GetLongPathNameW 失敗時フォールバック禁止 (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M73" -EnvironmentRequirement "NONE" -ActivationBoundary "PATH_RESOLVER" -Name "GetLongPathNameW 失敗時フォールバック禁止 (MERGE_PATH_IDENTITY_UNRESOLVED)" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "Path identity resolver reaches Win32 GetLongPathNameW failure branch" `
  -PreconditionsObserved "Win32CanonicalPath resolver is not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until Win32CanonicalPath implementation" `
  -AssertionPerformed "code == MERGE_PATH_IDENTITY_UNRESOLVED and no fallback to unresolved path" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of Win32CanonicalPath with fail-closed GetLongPathNameW handler"

# M74: GetLongPathNameW 動的バッファリサイズ (>260 文字ロングパス) (DIRECT_EXECUTION)
$vM74 = Join-Path $TestRoot "V_M74"
Reset-TestVault $vM74
$deepDir_M74 = $vM74
for ($i_M74 = 0; $i_M74 -lt 7; $i_M74++) {
  $deepDir_M74 = Join-Path $deepDir_M74 ("nested_sub_directory_layer_" + $i_M74.ToString("D3"))
}
$f1_M74 = Join-Path $deepDir_M74 "01_顧客\株式会社テスト_A"
$f2_M74 = Join-Path $deepDir_M74 "01_顧客\株式会社テスト_B"
New-Item -ItemType Directory -Path ("\\?\" + $f1_M74) -Force | Out-Null
New-Item -ItemType Directory -Path ("\\?\" + $f2_M74) -Force | Out-Null
$note1_M74 = Join-Path $f1_M74 "🟨契約_テスト.md"
$note2_M74 = Join-Path $f2_M74 "🟥事故_テスト.md"
[System.IO.File]::WriteAllText(("\\?\" + $note1_M74), "--`n tags:`n  - `"テスト顧客`"`nUUID: $uuid1`nランク: A`n---`n本文", [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText(("\\?\" + $note2_M74), "--`n tags:`n  - `"テスト顧客`"`nUUID: $uuid1`nランク: A`n---`n本文", [System.Text.UTF8Encoding]::new($false))
$longPathLen_M74 = $note1_M74.Length
$pre_M74 = ($longPathLen_M74 -gt 260) -and ([System.IO.File]::Exists("\\?\" + $note1_M74)) -and ([System.IO.File]::Exists("\\?\" + $note2_M74))
$res_M74 = Invoke-BridgePayload $TargetScript @{
  protocolVersion = 1; action = "PLAN_CUSTOMER_FOLDER_MERGE"; requestId = "req-M74"; VaultRoot = $deepDir_M74; pk_CLIENT = $uuid1; companyNameRaw = "株式会社テスト"
}
$isRed_M74 = ($null -eq $res_M74.Json -or $res_M74.Json.code -ne "MERGE_PLAN_READY")
Record-TestResult -Id "M74" -Name "GetLongPathNameW 動的バッファリサイズ (>260 文字ロングパス)" -TestType "DIRECT_EXECUTION" `
  -Status $(if ($isRed_M74) { "EXECUTED_EXPECTED_RED" } else { "PASS_EXISTING" }) `
  -EvidenceAuthority "DIRECT_PRECONDITION_PROOF" `
  -PreconditionsRequired "Existing NTFS file path length > 260 characters on local NTFS drive" `
  -PreconditionsObserved "Existing path length: $longPathLen_M74 > 260 on NTFS (PreconditionPass: $pre_M74)" `
  -PreconditionPass $pre_M74 `
  -ExecutionPerformed "Invoke-BridgePayload PLAN_CUSTOMER_FOLDER_MERGE" `
  -AssertionPerformed "Dynamic buffer resize successfully handles >260 chars path" `
  -ActualEvidence "Observed: $($res_M74.Stdout.Trim())"

# M75: Transaction Control Evidence 削除失敗専用契約 (STATIC_CAPABILITY)
$absent_M75 = Assert-TargetSymbolAbsent "TRANSACTION_MARKER_CLEANUP_PENDING"
$req_M75 = @("WarningCode:TRANSACTION_MARKER_CLEANUP_PENDING", "SeparationFromOwnershipFailure", "ControlEvidenceSpecificWarning")
$obs_M75 = @()
if (-not $absent_M75) { $obs_M75 += "WarningCode:TRANSACTION_MARKER_CLEANUP_PENDING" }
$missing_M75 = @($req_M75 | Where-Object { $obs_M75 -notcontains $_ })
$green_M75 = ($missing_M75.Count -eq 0)
Record-TestResult -Id "M75" -Name "Transaction Control Evidence 削除失敗専用契約 (warning: TRANSACTION_MARKER_CLEANUP_PENDING)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M75) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "TRANSACTION_MARKER_CLEANUP_PENDING" `
  -StructuralInspection "Symbol search for frozen normative warning code TRANSACTION_MARKER_CLEANUP_PENDING and separation from ownership" `
  -RequiredComponents $req_M75 `
  -ObservedComponents $obs_M75 `
  -MissingComponents $missing_M75 `
  -GreenPredicate "WarningCodePresent -and IsolatedFromOwnership -and ControlSpecific" `
  -SemanticAbsenceReason "Frozen contract requires TRANSACTION_MARKER_CLEANUP_PENDING specifically for control evidence cleanup failure; components absent" `
  -ExecutionPerformed "Symbol search in production script text" `
  -AssertionPerformed "Warning code present and isolated to control evidence failure" `
  -ActualEvidence "Warning absent: $absent_M75, Observed: $($obs_M75.Count)/$($req_M75.Count)"

# M76: OPEN 実行中の並行 APPLY 排他 (STATIC_CAPABILITY)
$enclosed_M76 = Test-LockFullLifetimeEnclosure -ActionName "OPEN"
$hasValidAcq = Test-LockAcquisitionValid
$req_M76 = @("LockAcquisition:ACTIVE.lock+FileShare.None", "Enclosure:OPEN")
$obs_M76 = @()
if ($hasValidAcq) { $obs_M76 += "LockAcquisition:ACTIVE.lock+FileShare.None" }
if ($enclosed_M76) { $obs_M76 += "Enclosure:OPEN" }
$missing_M76 = @($req_M76 | Where-Object { $obs_M76 -notcontains $_ })
$green_M76 = ($missing_M76.Count -eq 0)
Record-TestResult -Id "M76" -Name "OPEN 実行中の並行 APPLY 排他 (MERGE_OPERATION_IN_PROGRESS)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M76) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "ACTIVE.lock Full-Operation Lifetime Protection (OPEN)" `
  -StructuralInspection "AST same-handle lifetime enclosure analysis for OPEN action" `
  -RequiredComponents $req_M76 `
  -ObservedComponents $obs_M76 `
  -MissingComponents $missing_M76 `
  -GreenPredicate "LockAcquisitionValid -and EnclosureOpen" `
  -SemanticAbsenceReason "Frozen contract requires OPEN operation to hold ACTIVE.lock throughout entire execution lifetime" `
  -ExecutionPerformed "AST same-handle lifetime and enclosure analysis" `
  -AssertionPerformed "ACTIVE.lock held across entire OPEN lifetime" `
  -ActualEvidence "LockValid: $hasValidAcq, Enclosed: $enclosed_M76"

# M77: COMPARE 実行中の並行 APPLY 排他 (STATIC_CAPABILITY)
$enclosed_M77 = Test-LockFullLifetimeEnclosure -ActionName "COMPARE"
$req_M77 = @("LockAcquisition:ACTIVE.lock+FileShare.None", "Enclosure:COMPARE")
$obs_M77 = @()
if ($hasValidAcq) { $obs_M77 += "LockAcquisition:ACTIVE.lock+FileShare.None" }
if ($enclosed_M77) { $obs_M77 += "Enclosure:COMPARE" }
$missing_M77 = @($req_M77 | Where-Object { $obs_M77 -notcontains $_ })
$green_M77 = ($missing_M77.Count -eq 0)
Record-TestResult -Id "M77" -Name "COMPARE 実行中の並行 APPLY 排他 (MERGE_OPERATION_IN_PROGRESS)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M77) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "ACTIVE.lock Full-Operation Lifetime Protection (COMPARE)" `
  -StructuralInspection "AST same-handle lifetime enclosure analysis for COMPARE action" `
  -RequiredComponents $req_M77 `
  -ObservedComponents $obs_M77 `
  -MissingComponents $missing_M77 `
  -GreenPredicate "LockAcquisitionValid -and EnclosureCompare" `
  -SemanticAbsenceReason "Frozen contract requires COMPARE operation to hold ACTIVE.lock throughout entire execution lifetime" `
  -ExecutionPerformed "AST same-handle lifetime and enclosure analysis" `
  -AssertionPerformed "ACTIVE.lock held across entire COMPARE lifetime" `
  -ActualEvidence "LockValid: $hasValidAcq, Enclosed: $enclosed_M77"

# M78: PLAN スキャン中の並行 APPLY 排他 (STATIC_CAPABILITY)
$enclosed_M78 = Test-LockFullLifetimeEnclosure -ActionName "PLAN_CUSTOMER_FOLDER_MERGE"
$req_M78 = @("LockAcquisition:ACTIVE.lock+FileShare.None", "Enclosure:PLAN_CUSTOMER_FOLDER_MERGE")
$obs_M78 = @()
if ($hasValidAcq) { $obs_M78 += "LockAcquisition:ACTIVE.lock+FileShare.None" }
if ($enclosed_M78) { $obs_M78 += "Enclosure:PLAN_CUSTOMER_FOLDER_MERGE" }
$missing_M78 = @($req_M78 | Where-Object { $obs_M78 -notcontains $_ })
$green_M78 = ($missing_M78.Count -eq 0)
Record-TestResult -Id "M78" -Name "PLAN スキャン中の並行 APPLY 排他 (MERGE_OPERATION_IN_PROGRESS)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M78) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "ACTIVE.lock Full-Operation Lifetime Protection (PLAN)" `
  -StructuralInspection "AST same-handle lifetime enclosure analysis for PLAN action" `
  -RequiredComponents $req_M78 `
  -ObservedComponents $obs_M78 `
  -MissingComponents $missing_M78 `
  -GreenPredicate "LockAcquisitionValid -and EnclosurePlan" `
  -SemanticAbsenceReason "Frozen contract requires PLAN operation to hold ACTIVE.lock throughout entire execution lifetime" `
  -ExecutionPerformed "AST same-handle lifetime and enclosure analysis" `
  -AssertionPerformed "ACTIVE.lock held across entire PLAN lifetime" `
  -ActualEvidence "LockValid: $hasValidAcq, Enclosed: $enclosed_M78"

# M79: UPDATE_CUSTOMER_IDENTITY 実行中の並行 APPLY 排他 (STATIC_CAPABILITY)
$enclosed_M79 = Test-LockFullLifetimeEnclosure -ActionName "UPDATE_CUSTOMER_IDENTITY"
$req_M79 = @("LockAcquisition:ACTIVE.lock+FileShare.None", "Enclosure:UPDATE_CUSTOMER_IDENTITY")
$obs_M79 = @()
if ($hasValidAcq) { $obs_M79 += "LockAcquisition:ACTIVE.lock+FileShare.None" }
if ($enclosed_M79) { $obs_M79 += "Enclosure:UPDATE_CUSTOMER_IDENTITY" }
$missing_M79 = @($req_M79 | Where-Object { $obs_M79 -notcontains $_ })
$green_M79 = ($missing_M79.Count -eq 0)
Record-TestResult -Id "M79" -Name "UPDATE_CUSTOMER_IDENTITY 実行中の並行 APPLY 排他" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M79) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "NORMATIVE_FROZEN_LITERAL" `
  -NormativeLiteral "ACTIVE.lock Full-Operation Lifetime Protection (UPDATE)" `
  -StructuralInspection "AST same-handle lifetime enclosure analysis for UPDATE action" `
  -RequiredComponents $req_M79 `
  -ObservedComponents $obs_M79 `
  -MissingComponents $missing_M79 `
  -GreenPredicate "LockAcquisitionValid -and EnclosureUpdate" `
  -SemanticAbsenceReason "Frozen contract requires UPDATE operation to hold ACTIVE.lock throughout entire execution lifetime" `
  -ExecutionPerformed "AST same-handle lifetime and enclosure analysis" `
  -AssertionPerformed "ACTIVE.lock held across entire UPDATE lifetime" `
  -ActualEvidence "LockValid: $hasValidAcq, Enclosed: $enclosed_M79"

# M80: Ownership マーカー削除失敗時の Control Evidence 温存 (STATIC_CAPABILITY)
$proof_M80 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Ownership Failure Control Retention Gate"
$req_M80 = @("ActionDispatch:APPLY_CUSTOMER_FOLDER_MERGE", "CleanupOrderingEnforcement", "OwnershipFailureDetection", "ControlEvidenceSuppression")
$obs_M80 = @()
# 過剰推論排除: 実体検出のみ
$missing_M80 = @($req_M80 | Where-Object { $obs_M80 -notcontains $_ })
$green_M80 = ($missing_M80.Count -eq 0)
Record-TestResult -Id "M80" -Name "Ownership マーカー削除失敗時の Control Evidence 削除禁止・温存 (M75 と分離)" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M80) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Ownership Failure Control Retention Gate" `
  -DispatchBranchFound $proof_M80.DispatchBranchFound `
  -ReachableFunctions $proof_M80.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M80.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M80.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M80.ReachableStateSymbols `
  -StructuralProofResult $proof_M80.ProofResult `
  -RequiredComponents $req_M80 `
  -ObservedComponents $obs_M80 `
  -MissingComponents $missing_M80 `
  -GreenPredicate "ActionDispatchPresent -and OrderingEnforced -and OwnershipFailureDetected -and ControlRetained" `
  -SemanticAbsenceReason "Production script lacks cleanup separation logic isolating ownership marker failure from control evidence deletion" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Ownership failure control retention logic exists" `
  -ActualEvidence $proof_M80.ProofResult

# M81: valid IN_PROGRESS + valid COMMITTED 共存時の遅延クリーンアップ (STATIC_CAPABILITY)
$proof_M81 = Get-StructuralReachabilityProof "APPLY_CUSTOMER_FOLDER_MERGE" "Coexistence Delayed Marker Garbage Collection"
$req_M81 = @("DualMarkerDetection", "PhaseResolutionExecution", "DelayedGarbageCollection", "ResidueRemovalCompleted")
$obs_M81 = @()
# 過剰推論排除: 実体検出のみ
$missing_M81 = @($req_M81 | Where-Object { $obs_M81 -notcontains $_ })
$green_M81 = ($missing_M81.Count -eq 0)
Record-TestResult -Id "M81" -Name "valid IN_PROGRESS + valid COMMITTED 共存時の遅延クリーンアップ" -TestType "STATIC_CAPABILITY" `
  -Status $(if ($green_M81) { "PASS_EXISTING" } else { "STATIC_CAPABILITY_RED" }) `
  -EvidenceAuthority "STRUCTURAL_CONTROL_FLOW_ABSENCE" `
  -NormativeLiteral "Coexistence Delayed Marker Garbage Collection" `
  -DispatchBranchFound $proof_M81.DispatchBranchFound `
  -ReachableFunctions $proof_M81.ReachableFunctions `
  -ReachableMutationPrimitives $proof_M81.ReachableMutationPrimitives `
  -ReachableJournalSymbols $proof_M81.ReachableJournalSymbols `
  -ReachableStateSymbols $proof_M81.ReachableStateSymbols `
  -StructuralProofResult $proof_M81.ProofResult `
  -RequiredComponents $req_M81 `
  -ObservedComponents $obs_M81 `
  -MissingComponents $missing_M81 `
  -GreenPredicate "DualDetected -and PhaseResolved -and DelayedGCExecuted -and ResidueRemoved" `
  -SemanticAbsenceReason "Production script lacks delayed cleanup mechanism for coexisting markers" `
  -ExecutionPerformed "AST Action Dispatch & Control Flow Reachability Analysis" `
  -AssertionPerformed "Delayed cleanup logic exists" `
  -ActualEvidence $proof_M81.ProofResult

# M82: ACTIVE.lock Access Denied 検知時の MERGE_CONTROL_ACCESS_DENIED (NOT_EXECUTABLE_PRE_IMPLEMENTATION)
Record-TestResult -Id "M82" -EnvironmentRequirement "ACTIVE_LOCK_ACCESS_DENIED_CREATABLE" -ActivationBoundary "LOCK_ACQUISITION_ACCESS_DENIED" -Name "ACTIVE.lock Access Denied 検知時の MERGE_CONTROL_ACCESS_DENIED 分離" -TestType "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -Status "NOT_EXECUTABLE_PRE_IMPLEMENTATION" `
  -EvidenceAuthority "N/A" `
  -PreconditionsRequired "ACTIVE.lock file has Access Denied ACL and production attempts to acquire it" `
  -PreconditionsObserved "ACTIVE.lock acquisition logic is not implemented in production v9.0.4" `
  -PreconditionPass $false `
  -ExecutionPerformed "Deferred until ACTIVE.lock acquisition implementation" `
  -AssertionPerformed "code == MERGE_CONTROL_ACCESS_DENIED upon lock file Access Denied" `
  -ActualEvidence "Pre-implementation boundary not reachable" `
  -ActivationCondition "Requires implementation of ACTIVE.lock acquisition and MERGE_CONTROL_ACCESS_DENIED handler"

# ===================== ハーネス自己検証 (Self-Validation: 厳格 Fail-Closed ガード) =====================
Write-Host "`n=== ハーネス自己検証 (Harness Self-Validation) ===" -ForegroundColor Cyan

$allIds = $script:Results | ForEach-Object { $_.Id }
$mIds = $allIds | Where-Object { $_ -match "^M\d{2}$" }
$uniqueMIds = @($mIds | Select-Object -Unique)
$mCountPass = ($mIds.Count -eq 82)
$uniqueMPass = ($uniqueMIds.Count -eq 82)
Record-SafetyCheck "M-IDs 総件数確認 (82件)" $mCountPass "Total M-IDs: $($mIds.Count) / 82"
Record-SafetyCheck "M-IDs 一意件数確認 (82件)" $uniqueMPass "Unique M-IDs: $($uniqueMIds.Count) / 82"

$dupIds = @($mIds | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
$noDups = ($dupIds.Count -eq 0)
Record-SafetyCheck "重複 ID 0 件確認" $noDups "Duplicate IDs: $($dupIds -join ', ')"

$syntaxRecords = @($script:Results | Where-Object { $_.Id -eq "SYNTAX" })
$syntaxPassSingle = ($syntaxRecords.Count -eq 1)
Record-SafetyCheck "SYNTAX 登録 1 件確認" $syntaxPassSingle "SYNTAX Count: $($syntaxRecords.Count)"

$totalRecords = $script:Results.Count
$totalPass83 = ($totalRecords -eq 83)
Record-SafetyCheck "総登録件数 83 件確認 (M01-M82 + SYNTAX)" $totalPass83 "Total Records: $totalRecords / 83"

$placeholderTests = @($script:Results | Where-Object { [string]::IsNullOrWhiteSpace($_.ExecutionPerformed) -or [string]::IsNullOrWhiteSpace($_.ActualEvidence) })
$noPlaceholders = ($placeholderTests.Count -eq 0)
Record-SafetyCheck "固定プレースホルダー 0 件確認" $noPlaceholders "Placeholders: $($placeholderTests.Count)"

# セマンティック事前検証確認: DIRECT_EXECUTION で PreconditionPass が false のテストが 0 件であること
$failedPreconditions = @($script:Results | Where-Object { $_.TestType -eq "DIRECT_EXECUTION" -and (-not $_.PreconditionPass) })
$noPreconditionFailures = ($failedPreconditions.Count -eq 0)
Record-SafetyCheck "DIRECT_EXECUTION 事前条件不一致 0 件確認" $noPreconditionFailures "Failed Preconditions: $($failedPreconditions.Count)"

# 構造的証拠妥当性確認: STRUCTURAL_CONTROL_FLOW_ABSENCE のテストで機械的証拠が空でないこと
$invalidStructuralEvidence = @($script:Results | Where-Object {
  $_.EvidenceAuthority -eq "STRUCTURAL_CONTROL_FLOW_ABSENCE" -and [string]::IsNullOrWhiteSpace($_.StructuralProofResult)
})
$noInvalidStructural = ($invalidStructuralEvidence.Count -eq 0)
Record-SafetyCheck "STRUCTURAL_CONTROL_FLOW_ABSENCE 機械的構造証拠完備確認 (0件不備)" $noInvalidStructural "Invalid Structural Count: $($invalidStructuralEvidence.Count)"

# False-GREEN ガード自己検証: 複合 STATIC_CAPABILITY で MissingComponents があるのに PASS_EXISTING になっているテストが 0 件であること
$falseGreenTests = @($script:Results | Where-Object {
  $_.TestType -eq "STATIC_CAPABILITY" -and $_.MissingComponents.Count -gt 0 -and $_.Status -eq "PASS_EXISTING"
})
$noFalseGreens = ($falseGreenTests.Count -eq 0)
Record-SafetyCheck "False-GREEN ガード検証 (不完全実装での誤PASS 0件)" $noFalseGreens "False Green Count: $($falseGreenTests.Count)"

# 厳格能力到達性・環境要件統合 NOT_EXECUTABLE 活性化ガード自己検証:
# 各 NOT_EXECUTABLE テストについて、CodeCapabilityReachable かつ EnvironmentRequirementSatisfied (即ち ExecutableNow == $true)
# なのに NOT_EXECUTABLE のまま残っている場合のみ HARNESS_DEFECT
$staleDeferredTests = @()
foreach ($r in ($script:Results | Where-Object { $_.TestType -eq "NOT_EXECUTABLE_PRE_IMPLEMENTATION" })) {
  if ($r.ExecutableNow) {
    $staleDeferredTests += $r.Id
  }
}
$noStaleDeferred = ($staleDeferredTests.Count -eq 0)
Record-SafetyCheck "到達性・環境要件統合 NOT_EXECUTABLE 活性化ガード検証 (開通後未移行 0件)" $noStaleDeferred "Stale Deferred IDs: $($staleDeferredTests -join ', ')"

# ===================== 合成検出エンジン自己検証テスト (Synthetic Detector Matrix A-AO) =====================
# 指示書 Section 8 に基づき、41 個の合成 AST/コードフィクスチャに対する検出エンジンの完全性を検査する

# A. APPLY dispatch only -> PLAN_TOKEN_VALIDATION false
$astErrA = $null; $tokA = $null
$codeA = 'if ($action -eq "APPLY_CUSTOMER_FOLDER_MERGE") { Write-Host "apply" }'
$astA = [System.Management.Automation.Language.Parser]::ParseInput($codeA, [ref]$tokA, [ref]$astErrA)
$synthA = (-not (Test-ActivationBoundaryReached "PLAN_TOKEN_VALIDATION" -ScriptAst $astA -ScriptText $codeA))

# B. APPLY + actual token validation path -> PLAN_TOKEN_VALIDATION true
$astErrB = $null; $tokB = $null
$codeB = 'if ($action -eq "APPLY_CUSTOMER_FOLDER_MERGE") { if ($planToken -ne $expected) { return "MERGE_PLAN_STALE" } }'
$astB = [System.Management.Automation.Language.Parser]::ParseInput($codeB, [ref]$tokB, [ref]$astErrB)
$synthB = (Test-ActivationBoundaryReached "PLAN_TOKEN_VALIDATION" -ScriptAst $astB -ScriptText $codeB)

# C. lock acquisition only (no operation enclosure) -> LOCK_FULL_LIFETIME_OPEN false
$astErrC = $null; $tokC = $null
$codeC = '[System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)'
$astC = [System.Management.Automation.Language.Parser]::ParseInput($codeC, [ref]$tokC, [ref]$astErrC)
$synthC = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astC -ScriptText $codeC))

# D. lock held around OPEN work in try/finally -> LOCK_FULL_LIFETIME_OPEN true
$astErrD = $null; $tokD = $null
$codeD = 'if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "OPEN_WORK" } finally { $lock.Dispose() } }'
$astD = [System.Management.Automation.Language.Parser]::ParseInput($codeD, [ref]$tokD, [ref]$astErrD)
$synthD = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astD -ScriptText $codeD)

# E. lock acquired then disposed before OPEN -> LOCK_FULL_LIFETIME_OPEN false
$astErrE = $null; $tokE = $null
$codeE = 'if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); $lock.Dispose(); Write-Host "OPEN_WORK" }'
$astE = [System.Management.Automation.Language.Parser]::ParseInput($codeE, [ref]$tokE, [ref]$astErrE)
$synthE = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astE -ScriptText $codeE))

# F. APPLY literal + unrelated File.Move in UPDATE helper -> FILE_MOVE_ENGINE false
$astErrF = $null; $tokF = $null
$codeF = 'function Update-Helper { [System.IO.File]::Move("a", "b") }; if ($action -eq "APPLY_CUSTOMER_FOLDER_MERGE") { Write-Host "apply" }; if ($action -eq "UPDATE") { Update-Helper }'
$astF = [System.Management.Automation.Language.Parser]::ParseInput($codeF, [ref]$tokF, [ref]$astErrF)
$synthF = (-not (Test-ActivationBoundaryReached "FILE_MOVE_ENGINE" -ScriptAst $astF -ScriptText $codeF))

# G. APPLY branch reaches helper containing File.Move -> FILE_MOVE_ENGINE true
$astErrG = $null; $tokG = $null
$codeG = 'function Move-Helper { [System.IO.File]::Move("a", "b") }; if ($action -eq "APPLY_CUSTOMER_FOLDER_MERGE") { Move-Helper }'
$astG = [System.Management.Automation.Language.Parser]::ParseInput($codeG, [ref]$tokG, [ref]$astErrG)
$synthG = (Test-ActivationBoundaryReached "FILE_MOVE_ENGINE" -ScriptAst $astG -ScriptText $codeG)

# H. GetLongPathNameW implementation present but Environment8dot3=false -> M44/M51/M52 ExecutableNow=false
$astErrH = $null; $tokH = $null
$codeH = 'function Win32CanonicalPath { param($p) GetLongPathNameW; return "ShortPathResolved" }'
$astH = [System.Management.Automation.Language.Parser]::ParseInput($codeH, [ref]$tokH, [ref]$astErrH)
$codeReachH = (Test-ActivationBoundaryReached "PATH_RESOLVER_SHORT_NAME_SUPPORT" -ScriptAst $astH -ScriptText $codeH)
$envH = (Test-EnvironmentRequirementSatisfied "NTFS_8DOT3_NAME_AVAILABLE" -TestRootPath $TestRoot)
$execNowH = ($codeReachH -and $envH)
$synthH = (-not $execNowH)

# I. case-sensitive error handling present but EnvironmentCanCreateCaseSensitiveDir=false -> M67 ExecutableNow=false
$astErrI = $null; $tokI = $null
$codeI = 'if ($isCaseSensitive) { return "MERGE_CASE_SENSITIVE_DIRECTORY_UNSUPPORTED" }'
$astI = [System.Management.Automation.Language.Parser]::ParseInput($codeI, [ref]$tokI, [ref]$astErrI)
$codeReachI = (Test-ActivationBoundaryReached "NTFS_CASE_SENSITIVE_DIRECTORY_SUPPORT" -ScriptAst $astI -ScriptText $codeI)
$envI = (Test-EnvironmentRequirementSatisfied "NTFS_CASE_SENSITIVE_DIRECTORY_CREATABLE" -TestRootPath $TestRoot)
$execNowI = ($codeReachI -and $envI)
$synthI = (-not $execNowI)

# J. SCAN_UNSTABLE literal present but no deterministic race seam -> M72 ExecutableNow=false
$astErrJ = $null; $tokJ = $null
$codeJ = 'if ($unstable) { return "SCAN_UNSTABLE" }'
$astJ = [System.Management.Automation.Language.Parser]::ParseInput($codeJ, [ref]$tokJ, [ref]$astErrJ)
$codeReachJ = (Test-ActivationBoundaryReached "SCAN_ENGINE_LATENCY_SEAM" -ScriptAst $astJ -ScriptText $codeJ)
$envJ = (Test-EnvironmentRequirementSatisfied "DETERMINISTIC_LATENCY_SEAM_AVAILABLE" -TestRootPath $TestRoot)
$execNowJ = ($codeReachJ -and $envJ)
$synthJ = (-not $execNowJ)

# K. same handle acquired before try, disposed in finally -> LOCK_FULL_LIFETIME_OPEN true
$astErrK = $null; $tokK = $null
$codeK = 'if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }'
$astK = [System.Management.Automation.Language.Parser]::ParseInput($codeK, [ref]$tokK, [ref]$astErrK)
$synthK = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astK -ScriptText $codeK)

# L. different object disposed in finally -> LOCK_FULL_LIFETIME_OPEN false
$astErrL = $null; $tokL = $null
$codeL = 'if ($action -eq "OPEN") { $lockA = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $differentObject.Dispose() } }'
$astL = [System.Management.Automation.Language.Parser]::ParseInput($codeL, [ref]$tokL, [ref]$astErrL)
$synthL = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astL -ScriptText $codeL))

# M. same handle disposed before protected work -> LOCK_FULL_LIFETIME_OPEN false
$astErrM = $null; $tokM = $null
$codeM = 'if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { $lock.Dispose(); Write-Host "WORK" } finally { $lock.Dispose() } }'
$astM = [System.Management.Automation.Language.Parser]::ParseInput($codeM, [ref]$tokM, [ref]$astErrM)
$synthM = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astM -ScriptText $codeM))

# N. ACTIVE.lock acquisition in unreachable helper -> LOCK_FULL_LIFETIME_OPEN false
$astErrN = $null; $tokN = $null
$codeN = 'function Unrelated { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }; if ($action -eq "OPEN") { try { Write-Host "OPEN_WORK" } finally { $lock.Dispose() } }'
$astN = [System.Management.Automation.Language.Parser]::ParseInput($codeN, [ref]$tokN, [ref]$astErrN)
$synthN = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astN -ScriptText $codeN))

# O. FileShare.None belongs to different FileStream than ACTIVE.lock -> LOCK_FULL_LIFETIME_OPEN false
$astErrO = $null; $tokO = $null
$codeO = 'if ($action -eq "OPEN") { $other = [System.IO.FileStream]::new("other.txt", [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None); $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite); try { Write-Host "WORK" } finally { $lock.Dispose() } }'
$astO = [System.Management.Automation.Language.Parser]::ParseInput($codeO, [ref]$tokO, [ref]$astErrO)
$synthO = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astO -ScriptText $codeO))

# P. correct same-handle enclosure through reachable helper -> LOCK_FULL_LIFETIME_OPEN true
$astErrP = $null; $tokP = $null
$codeP = 'function Invoke-OpenHelper { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "OPEN_WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-OpenHelper }'
$astP = [System.Management.Automation.Language.Parser]::ParseInput($codeP, [ref]$tokP, [ref]$astErrP)
$synthP = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astP -ScriptText $codeP)

# Q. same variable name in different reachable lexical scopes -> LOCK_FULL_LIFETIME_OPEN false
$astErrQ = $null; $tokQ = $null
$codeQ = 'function Helper-A { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }; function Helper-B { try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Helper-A; Helper-B }'
$astQ = [System.Management.Automation.Language.Parser]::ParseInput($codeQ, [ref]$tokQ, [ref]$astErrQ)
$synthQ = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astQ -ScriptText $codeQ))

# R. dummy try protected, actual operation after finally -> LOCK_FULL_LIFETIME_OPEN false
$astErrR = $null; $tokR = $null
$codeR = 'if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "dummy" } finally { $lock.Dispose() }; Invoke-ActualOpenWork }'
$astR = [System.Management.Automation.Language.Parser]::ParseInput($codeR, [ref]$tokR, [ref]$astErrR)
$synthR = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astR -ScriptText $codeR))

# S. actual operation helper invoked inside protected try -> LOCK_FULL_LIFETIME_OPEN true
$astErrS = $null; $tokS = $null
$codeS = 'function Invoke-ActualWork { Write-Host "real" }; if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Invoke-ActualWork } finally { $lock.Dispose() } }'
$astS = [System.Management.Automation.Language.Parser]::ParseInput($codeS, [ref]$tokS, [ref]$astErrS)
$synthS = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astS -ScriptText $codeS)

# T. one operation helper inside try, second material helper after finally -> LOCK_FULL_LIFETIME_OPEN false
$astErrT = $null; $tokT = $null
$codeT = 'function Helper-1 { Write-Host "1" }; function Helper-2 { Write-Host "2" }; if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Helper-1 } finally { $lock.Dispose() }; Helper-2 }'
$astT = [System.Management.Automation.Language.Parser]::ParseInput($codeT, [ref]$tokT, [ref]$astErrT)
$synthT = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astT -ScriptText $codeT))

# U. lock acquired and full operation executed inside same helper lexical scope -> LOCK_FULL_LIFETIME_OPEN true
$astErrU = $null; $tokU = $null
$codeU = 'function Invoke-OpenOp { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-OpenOp }'
$astU = [System.Management.Automation.Language.Parser]::ParseInput($codeU, [ref]$tokU, [ref]$astErrU)
$synthU = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astU -ScriptText $codeU)

# V. nested helper uses unrelated same-name $lock -> LOCK_FULL_LIFETIME_OPEN false
$astErrV = $null; $tokV = $null
$codeV = 'function Helper-Nested { try { Write-Host "nested" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); Helper-Nested }'
$astV = [System.Management.Automation.Language.Parser]::ParseInput($codeV, [ref]$tokV, [ref]$astErrV)
$synthV = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astV -ScriptText $codeV))

# W. substantive helper before lock acquisition -> LOCK_FULL_LIFETIME_OPEN false
$astErrW = $null; $tokW = $null
$codeW = 'function Prepare-Work { [System.IO.File]::ReadAllText("prep.txt") }; if ($action -eq "OPEN") { Prepare-Work; $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }'
$astW = [System.Management.Automation.Language.Parser]::ParseInput($codeW, [ref]$tokW, [ref]$astErrW)
$synthW = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astW -ScriptText $codeW))

# X. direct File/Directory operation before lock -> LOCK_FULL_LIFETIME_OPEN false
$astErrX = $null; $tokX = $null
$codeX = 'if ($action -eq "OPEN") { [System.IO.File]::ReadAllText("config.json"); $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }'
$astX = [System.Management.Automation.Language.Parser]::ParseInput($codeX, [ref]$tokX, [ref]$astErrX)
$synthX = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astX -ScriptText $codeX))

# Y. only harmless variable setup before lock, all material work in try -> LOCK_FULL_LIFETIME_OPEN true
$astErrY = $null; $tokY = $null
$codeY = 'if ($action -eq "OPEN") { $vaultRoot = "C:\Vault"; $activeLockPath = Join-Path $vaultRoot "ACTIVE.lock"; $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }'
$astY = [System.Management.Automation.Language.Parser]::ParseInput($codeY, [ref]$tokY, [ref]$astErrY)
$synthY = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astY -ScriptText $codeY)

# Z. unprotected helper then protected helper -> LOCK_FULL_LIFETIME_OPEN false
$astErrZ = $null; $tokZ = $null
$codeZ = 'function Invoke-Unprotected { [System.IO.File]::ReadAllText("state.json") }; function Invoke-Protected { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-Unprotected; Invoke-Protected }'
$astZ = [System.Management.Automation.Language.Parser]::ParseInput($codeZ, [ref]$tokZ, [ref]$astErrZ)
$synthZ = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astZ -ScriptText $codeZ))

# AA. action immediately delegates to self-contained protected helper -> LOCK_FULL_LIFETIME_OPEN true
$astErrAA = $null; $tokAA = $null
$codeAA = 'function Invoke-ProtectedOpen { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-ProtectedOpen }'
$astAA = [System.Management.Automation.Language.Parser]::ParseInput($codeAA, [ref]$tokAA, [ref]$astErrAA)
$synthAA = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAA -ScriptText $codeAA)

# AB. protected try completes, only response construction/logging follows -> LOCK_FULL_LIFETIME_OPEN true
$astErrAB = $null; $tokAB = $null
$codeAB = 'if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() }; Write-Host "Done"; return (New-UCIResponse -Status "OK") }'
$astAB = [System.Management.Automation.Language.Parser]::ParseInput($codeAB, [ref]$tokAB, [ref]$astErrAB)
$synthAB = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAB -ScriptText $codeAB)

# AC. arbitrary-name material helper before protected helper -> LOCK_FULL_LIFETIME_OPEN false
$astErrAC = $null; $tokAC = $null
$codeAC = 'function Invoke-Preparation { [System.IO.File]::ReadAllText("customer-state.json") }; function Invoke-Protected { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-Preparation; Invoke-Protected }'
$astAC = [System.Management.Automation.Language.Parser]::ParseInput($codeAC, [ref]$tokAC, [ref]$astErrAC)
$synthAC = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAC -ScriptText $codeAC))

# AD. arbitrary-name material helper after protected helper -> LOCK_FULL_LIFETIME_OPEN false
$astErrAD = $null; $tokAD = $null
$codeAD = 'function Invoke-Cleanup { [System.IO.File]::Delete("temp.json") }; function Invoke-Protected { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-Protected; Invoke-Cleanup }'
$astAD = [System.Management.Automation.Language.Parser]::ParseInput($codeAD, [ref]$tokAD, [ref]$astErrAD)
$synthAD = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAD -ScriptText $codeAD))

# AE. two protected self-contained helpers only (discontinuous lock gap) -> LOCK_FULL_LIFETIME_OPEN false
$astErrAE = $null; $tokAE = $null
$codeAE = 'function Invoke-Prot1 { $lock1 = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "1" } finally { $lock1.Dispose() } }; function Invoke-Prot2 { $lock2 = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "2" } finally { $lock2.Dispose() } }; if ($action -eq "OPEN") { Invoke-Prot1; Invoke-Prot2 }'
$astAE = [System.Management.Automation.Language.Parser]::ParseInput($codeAE, [ref]$tokAE, [ref]$astErrAE)
$synthAE = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAE -ScriptText $codeAE))

# AF. harmless setup + immediate protected helper -> LOCK_FULL_LIFETIME_OPEN true
$astErrAF = $null; $tokAF = $null
$codeAF = 'function Invoke-Prot { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { $vault = "C:\Vault"; Write-Host "Starting"; Invoke-Prot }'
$astAF = [System.Management.Automation.Language.Parser]::ParseInput($codeAF, [ref]$tokAF, [ref]$astErrAF)
$synthAF = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAF -ScriptText $codeAF)

# AG. unknown reachable helper before protected helper -> LOCK_FULL_LIFETIME_OPEN false
$astErrAG = $null; $tokAG = $null
$codeAG = 'function Invoke-Prot { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-UnknownHelper; Invoke-Prot }'
$astAG = [System.Management.Automation.Language.Parser]::ParseInput($codeAG, [ref]$tokAG, [ref]$astErrAG)
$synthAG = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAG -ScriptText $codeAG))

# AH. helper with only Join-Path / variable setup before protected helper -> LOCK_FULL_LIFETIME_OPEN true
$astErrAH = $null; $tokAH = $null
$codeAH = 'function Build-Config { $p = Join-Path "C:\Vault" "sub"; Write-Host "config: $p" }; function Invoke-Prot { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Build-Config; Invoke-Prot }'
$astAH = [System.Management.Automation.Language.Parser]::ParseInput($codeAH, [ref]$tokAH, [ref]$astErrAH)
$synthAH = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAH -ScriptText $codeAH)

# AI. material helper named SafePreparation -> LOCK_FULL_LIFETIME_OPEN false
$astErrAI = $null; $tokAI = $null
$codeAI = 'function SafePreparation { [System.IO.File]::ReadAllText("sensitive.txt") }; function Invoke-Protected { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "WORK" } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { SafePreparation; Invoke-Protected }'
$astAI = [System.Management.Automation.Language.Parser]::ParseInput($codeAI, [ref]$tokAI, [ref]$astErrAI)
$synthAI = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAI -ScriptText $codeAI))

# AJ. two independently locked protected helpers -> LOCK_FULL_LIFETIME_OPEN false
$astErrAJ = $null; $tokAJ = $null
$codeAJ = 'function P1 { $l1 = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { [System.IO.File]::ReadAllText("1.txt") } finally { $l1.Dispose() } }; function P2 { $l2 = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { [System.IO.File]::ReadAllText("2.txt") } finally { $l2.Dispose() } }; if ($action -eq "OPEN") { P1; P2 }'
$astAJ = [System.Management.Automation.Language.Parser]::ParseInput($codeAJ, [ref]$tokAJ, [ref]$astErrAJ)
$synthAJ = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAJ -ScriptText $codeAJ))

# AK. one outer lock / try/finally enclosing two material helpers -> LOCK_FULL_LIFETIME_OPEN true
$astErrAK = $null; $tokAK = $null
$codeAK = 'function H1 { [System.IO.File]::ReadAllText("1.txt") }; function H2 { [System.IO.File]::ReadAllText("2.txt") }; if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { H1; H2 } finally { $lock.Dispose() } }'
$astAK = [System.Management.Automation.Language.Parser]::ParseInput($codeAK, [ref]$tokAK, [ref]$astErrAK)
$synthAK = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAK -ScriptText $codeAK)

# AL. action delegates to one helper; helper owns one lock and calls two material helpers inside its try -> LOCK_FULL_LIFETIME_OPEN true
$astErrAL = $null; $tokAL = $null
$codeAL = 'function H1 { [System.IO.File]::ReadAllText("1.txt") }; function H2 { [System.IO.File]::ReadAllText("2.txt") }; function Invoke-EntireOpen { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { H1; H2 } finally { $lock.Dispose() } }; if ($action -eq "OPEN") { Invoke-EntireOpen }'
$astAL = [System.Management.Automation.Language.Parser]::ParseInput($codeAL, [ref]$tokAL, [ref]$astErrAL)
$synthAL = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAL -ScriptText $codeAL)

# AM. protected helper A, logging, protected helper B -> LOCK_FULL_LIFETIME_OPEN false
$astErrAM = $null; $tokAM = $null
$codeAM = 'function P1 { $l1 = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "1" } finally { $l1.Dispose() } }; function P2 { $l2 = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { Write-Host "2" } finally { $l2.Dispose() } }; if ($action -eq "OPEN") { P1; Write-Host "log"; P2 }'
$astAM = [System.Management.Automation.Language.Parser]::ParseInput($codeAM, [ref]$tokAM, [ref]$astErrAM)
$synthAM = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAM -ScriptText $codeAM))

# AN. one lock acquired at action entry; Helper1; Helper2; response construction; same handle released only at final operation exit -> LOCK_FULL_LIFETIME_OPEN true
$astErrAN = $null; $tokAN = $null
$codeAN = 'function H1 { [System.IO.File]::ReadAllText("1.txt") }; function H2 { [System.IO.File]::ReadAllText("2.txt") }; if ($action -eq "OPEN") { $lock = [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None); try { H1; H2 } finally { $lock.Dispose() }; return (New-UCIResponse -Status "OK") }'
$astAN = [System.Management.Automation.Language.Parser]::ParseInput($codeAN, [ref]$tokAN, [ref]$astErrAN)
$synthAN = (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAN -ScriptText $codeAN)

# AO. cross-scope lock transfer without deterministic ownership proof -> LOCK_FULL_LIFETIME_OPEN false
$astErrAO = $null; $tokAO = $null
$codeAO = 'function H1 { return [System.IO.FileStream]::new("ACTIVE.lock", [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }; function H2 { param($l) [System.IO.File]::ReadAllText("1.txt") }; if ($action -eq "OPEN") { $lock = H1; try { H2 $lock } finally { $lock.Dispose() } }'
$astAO = [System.Management.Automation.Language.Parser]::ParseInput($codeAO, [ref]$tokAO, [ref]$astErrAO)
$synthAO = (-not (Test-ActivationBoundaryReached "LOCK_FULL_LIFETIME_OPEN" -ScriptAst $astAO -ScriptText $codeAO))

$allSynthPass = $synthA -and $synthB -and $synthC -and $synthD -and $synthE -and $synthF -and $synthG -and $synthH -and $synthI -and $synthJ -and $synthK -and $synthL -and $synthM -and $synthN -and $synthO -and $synthP -and $synthQ -and $synthR -and $synthS -and $synthT -and $synthU -and $synthV -and $synthW -and $synthX -and $synthY -and $synthZ -and $synthAA -and $synthAB -and $synthAC -and $synthAD -and $synthAE -and $synthAF -and $synthAG -and $synthAH -and $synthAI -and $synthAJ -and $synthAK -and $synthAL -and $synthAM -and $synthAN -and $synthAO
Record-SafetyCheck "合成検出エンジン完全性自己検証 (Synthetic Matrix A-AO 全41件)" $allSynthPass "A:$synthA B:$synthB C:$synthC D:$synthD E:$synthE F:$synthF G:$synthG H:$synthH I:$synthI J:$synthJ K:$synthK L:$synthL M:$synthM N:$synthN O:$synthO P:$synthP Q:$synthQ R:$synthR S:$synthS T:$synthT U:$synthU V:$synthV W:$synthW X:$synthX Y:$synthY Z:$synthZ AA:$synthAA AB:$synthAB AC:$synthAC AD:$synthAD AE:$synthAE AF:$synthAF AG:$synthAG AH:$synthAH AI:$synthAI AJ:$synthAJ AK:$synthAK AL:$synthAL AM:$synthAM AN:$synthAN AO:$synthAO"

# ステータス設定妥当性確認: Status が空のテストが 0 件であること
$emptyStatusTests = @($script:Results | Where-Object { [string]::IsNullOrWhiteSpace($_.Status) })
$noEmptyStatus = ($emptyStatusTests.Count -eq 0)
Record-SafetyCheck "全テスト Status 確定確認 (空ステータス 0 件)" $noEmptyStatus "Empty Status Count: $($emptyStatusTests.Count)"

# 厳格 Fail-Closed 判定: 上記の安全確認に 1 件でも失敗があれば HARNESS_DEFECT 例外を送出
$anySafetyFailure = @($script:SafetyChecks | Where-Object { -not $_.Pass })
if ($anySafetyFailure.Count -gt 0) {
  Write-Host "`n[FATAL] ハーネス自己検証に失敗しました ($($anySafetyFailure.Count) 件の不備)。Fail-Closed 停止します。" -ForegroundColor Red
  foreach ($f in $anySafetyFailure) {
    Write-Host "  - $($f.Name): $($f.Detail)" -ForegroundColor Red
  }
  throw "HARNESS_DEFECT: Self-validation failed with $($anySafetyFailure.Count) defects."
}

# ===================== 終了時整合性確認 =====================
Write-Host "`n=== 終了時整合性確認 ===" -ForegroundColor Cyan
$endHash = (Get-FileHash -LiteralPath $TargetScript -Algorithm SHA256).Hash
$endHashMatch = ($endHash.ToUpperInvariant() -eq $ExpectedTargetSha256.ToUpperInvariant())
Record-SafetyCheck "対象PowerShell本体のSHA256不変確認(終了時)" $endHashMatch "Expected: $ExpectedTargetSha256, Actual: $endHash"

$testCount = $script:Results.Count
Record-SafetyCheck "テスト件数確認 (M01-M82 + 構文確認 = 総83件)" ($testCount -eq 83) "Actual: $testCount"

# サマリ集計 (新6区分)
$passExistingCount = @($script:Results | Where-Object { $_.Status -eq "PASS_EXISTING" }).Count
$execRedCount      = @($script:Results | Where-Object { $_.Status -eq "EXECUTED_EXPECTED_RED" }).Count
$staticRedCount    = @($script:Results | Where-Object { $_.Status -eq "STATIC_CAPABILITY_RED" }).Count
$notExecCount      = @($script:Results | Where-Object { $_.Status -eq "NOT_EXECUTABLE_PRE_IMPLEMENTATION" }).Count
$unexpRedCount     = @($script:Results | Where-Object { $_.Status -eq "UNEXPECTED_RED" }).Count
$defectCount       = @($script:Results | Where-Object { $_.Status -eq "HARNESS_DEFECT" }).Count

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "件数: M01-M82 (82件) + 構文確認 (1件) = 総 $testCount 結果"
Write-Host "PASS_EXISTING (構文等既存挙動): $passExistingCount" -ForegroundColor Green
Write-Host "EXECUTED_EXPECTED_RED (実機フィクスチャ＋事前検証付きRED): $execRedCount" -ForegroundColor Yellow
Write-Host "STATIC_CAPABILITY_RED (AST/構造検査によるRED): $staticRedCount" -ForegroundColor DarkYellow
Write-Host "NOT_EXECUTABLE_PRE_IMPLEMENTATION (実装前実行不可): $notExecCount" -ForegroundColor Cyan
Write-Host "UNEXPECTED_RED (予期しない失敗): $unexpRedCount" -ForegroundColor Red
Write-Host "HARNESS_DEFECT (ハーネス不具合): $defectCount" -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Cyan

# レポート出力
$reportFile = Join-Path $TestRoot "_report.txt"
$reportJsonFile = Join-Path $TestRoot "_report.json"
try {
  $reportText = "CUSTOMER FOLDER MERGE ACTIVATION AND TRANSITION REPORT`n" +
                "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" +
                "TargetScript: $TargetScript`n" +
                "TargetSha256: $endHash`n" +
                "Total: $testCount (PASS_EXISTING: $passExistingCount, EXECUTED_EXPECTED_RED: $execRedCount, STATIC_CAPABILITY_RED: $staticRedCount, NOT_EXEC: $notExecCount, UNEXPECTED_RED: $unexpRedCount, DEFECT: $defectCount)`n`n"
  foreach ($r in $script:Results) {
    $reportText += "[$($r.Status)] $($r.Id) - $($r.Name) ($($r.TestType))`n" +
                   $(if (-not [string]::IsNullOrWhiteSpace($r.EvidenceAuthority)) { "  EvidenceAuthority: $($r.EvidenceAuthority)`n" } else { "" }) +
                   $(if (-not [string]::IsNullOrWhiteSpace($r.NormativeLiteral)) { "  NormativeLiteral: $($r.NormativeLiteral)`n" } else { "" }) +
                   $(if ($r.RequiredComponents.Count -gt 0) { "  RequiredComponents: $($r.RequiredComponents -join ', ')`n" } else { "" }) +
                   $(if ($r.ObservedComponents.Count -gt 0) { "  ObservedComponents: $($r.ObservedComponents -join ', ')`n" } else { "" }) +
                   $(if ($r.MissingComponents.Count -gt 0) { "  MissingComponents: $($r.MissingComponents -join ', ')`n" } else { "" }) +
                   $(if (-not [string]::IsNullOrWhiteSpace($r.GreenPredicate)) { "  GreenPredicate: $($r.GreenPredicate)`n" } else { "" }) +
                   $(if (-not [string]::IsNullOrWhiteSpace($r.StructuralProofResult)) { "  StructuralProof: $($r.StructuralProofResult)`n" } else { "" }) +
                   $(if (-not [string]::IsNullOrWhiteSpace($r.SemanticAbsenceReason)) { "  SemanticAbsenceReason: $($r.SemanticAbsenceReason)`n" } else { "" }) +
                   "  PreconditionsRequired: $($r.PreconditionsRequired)`n" +
                   "  PreconditionsObserved: $($r.PreconditionsObserved) (Pass: $($r.PreconditionPass))`n" +
                   "  ExecutionPerformed: $($r.ExecutionPerformed)`n" +
                   "  AssertionPerformed: $($r.AssertionPerformed)`n" +
                   "  ActualEvidence: $($r.ActualEvidence)`n" +
                   $(if (-not [string]::IsNullOrWhiteSpace($r.ActivationCondition)) { "  ActivationCondition: $($r.ActivationCondition)`n" } else { "" }) +
                   "`n"
  }
  [System.IO.File]::WriteAllText($reportFile, $reportText, [System.Text.UTF8Encoding]::new($false))
  $jsonStr = $script:Results | ConvertTo-Json -Depth 5
  [System.IO.File]::WriteAllText($reportJsonFile, $jsonStr, [System.Text.UTF8Encoding]::new($false))
} catch {}
