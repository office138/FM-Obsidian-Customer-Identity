# CURRENT CANONICAL ARCHITECTURE / DESIGN

## 1. System Architecture Overview

The FM-Obsidian Bridge connects FileMaker CRM with Obsidian Knowledge Vaults using a secure, local, one-shot PowerShell bridge process:

```text
+-------------------------------------------------------------------------------+
|                             FileMaker CRM (RakkoDB)                           |
|   - Active Integration Scripts:                                               |
|     * Script 299: EXT-obs_OBSノート-開く                                     |
|     * Script 370: EXT-obs_顧客フォルダ統合                                   |
|     * Script 365: EXT-obs_顧客名・代表者名同期                               |
|     * Script 307: EXT-obs_内部CallPS-PAYLOAD                                  |
+-------------------------------------------------------------------------------+
                                      |
                       Base Elements Plug-In
                       BE_ExecuteSystemCommand
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                    PowerShell Bridge (Ver 9.1.1)                              |
|                    FM-Obsidian-Bridge-Payload.ps1                              |
|                                                                               |
|   1. Payload Parsing & Base64 Decoding                                        |
|   2. Action Router:                                                           |
|      - PLAN_CUSTOMER_FOLDER_MERGE                                             |
|      - APPLY_CUSTOMER_FOLDER_MERGE                                            |
|      - UPDATE_CUSTOMER_IDENTITY                                               |
|      - Legacy MODEs (COMPARE, CHECK, OPEN)                                    |
|   3. Win32 Native P/Invoke Kernel Layer (kernel32.dll)                        |
|   4. Discovery & Topology Validation Engine                                   |
|   5. Exclusive Staging & Durable Journal Engine                               |
|   6. Option B Rollback Engine & Crash Hooks                                   |
|   7. Pre-Commit Final Verification & Post-Commit Interlock Engine             |
+-------------------------------------------------------------------------------+
                                      |
                   Local Windows Filesystem / NTFS Operations
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                             Obsidian Vault                                    |
|   - Customer Root: <VaultRoot>/01_顧客/                                        |
|   - Customer Folders: <SanitizedName>_[<UUID-8-Upper>]                        |
|   - Managed Notes: [NoteTypePrefix]_<SanitizedName>.md                        |
|   - YAML Frontmatter: UUID, NAME, CEO, RUBY, RANK, tags                       |
+-------------------------------------------------------------------------------+
```

### 1.1 FileMaker Integration Architecture & Direct Evidence

The FileMaker integration architecture is established by direct repository and DDR evidence across four key scripts:

- **Script 299: `EXT-obs_OBSノート-開く`**
  - Handles normal UCI / customer identity flow.
  - On `status = "NG"` with `code = "UUID_FOLDER_CONFLICT"`, branches into merge resolution.
  - Calls Script 370 (`EXT-obs_顧客フォルダ統合`).
  - Accepts merge success only for `MERGE_COMPLETED` or `MERGE_NOT_REQUIRED`.
  - Reruns UCI at most once after successful merge.
  - Repeated conflict, invalid result, or merge failure terminates fail-closed.

- **Script 370: `EXT-obs_顧客フォルダ統合`**
  - Establishes FileMaker customer / Vault context.
  - Enforces full-table `pk_CLIENT` uniqueness guard.
  - Dispatches `PLAN_CUSTOMER_FOLDER_MERGE` through Script 307.
  - Validates plan response structure.
  - Obtains explicit Human approval before executing APPLY.
  - Passes opaque `planToken` unchanged.
  - Dispatches `APPLY_CUSTOMER_FOLDER_MERGE` through Script 307.
  - Validates terminal result and returns structured script result.

- **Script 365: `EXT-obs_顧客名・代表者名同期`**
  - UCI / customer identity synchronization path.

- **Script 307: `EXT-obs_内部CallPS-PAYLOAD`**
  - PowerShell payload transport and dispatch helper via Base Elements plug-in (`BE_ExecuteSystemCommand`) using `-PayloadB64` or `-PayloadFile`.

FileMaker itself does not directly mutate the filesystem for merge operations; all mutations are executed exclusively through the PowerShell bridge engine.

---

## 2. Request & Action Routing Model

Requests arrive as a Base64-encoded JSON payload either via `-PayloadB64` or `-PayloadFile`.

### Primary Action Handlers:
1. `PLAN_CUSTOMER_FOLDER_MERGE` -> `Invoke-PlanCustomerFolderMerge`:
   - Acquires exclusive per-vault transaction lock (`ACTIVE.lock`).
   - Scans customer root `01_顧客` via `Get-CustomerMergeTopology` and validates filesystem safety invariants (ReparsePoint, HardLink, ADS, CaseSensitivity).
   - Branches on `MatchedFolders.Count`:
     - 0 matched folders: returns terminal `NG` / `CUSTOMER_NOT_FOUND` via topology error handling.
     - 1 matched folder: returns terminal `OK` / `MERGE_NOT_REQUIRED`; no plan, no planToken, no Token V3.
     - 2+ matched folders: resolves canonical destination state via `Resolve-CanonicalDestinationState $topo`. On terminal states (`UNOWNED_DIRECTORY` -> `CANONICAL_FOLDER_NO_UUID_EVIDENCE`, `NON_DIRECTORY_OCCUPANT` -> `MERGE_CANONICAL_PATH_OCCUPIED`, `INSPECTION_FAILED` -> `MERGE_TOPOLOGY_ENUMERATION_FAILED`), returns immediately. On non-terminal states (`MATCHED_EXISTING`, `ABSENT`), continues through managed-note evaluation, `DUPLICATE_NOTE_TYPE` protection, plan construction, Token V3 generation, and returns structured plan JSON (`MERGE_PLAN_READY`).
   - Symbolic ordering invariant: `planOneFolderIdx < planResolverAssignIdx < planBranchIdx < planManagedNotesIdx`.
   - Releases the per-vault lock on branch exit.
2. `APPLY_CUSTOMER_FOLDER_MERGE` -> `Invoke-ApplyCustomerFolderMerge`:
   - Acquires exclusive per-vault transaction lock (`ACTIVE.lock`).
   - Scans customer root `01_顧客` via `Get-CustomerMergeTopology`.
   - Evaluates topology error handling: on 0 matched folders, returns terminal `NG` / `CUSTOMER_NOT_FOUND`.
   - Evaluates fresh `MatchedFolders.Count`: on exactly 1 matched folder, returns terminal `OK` / `MERGE_NOT_REQUIRED` (`matchedFolderCount = 1`, `updatedFiles = 0`, `folderRenamed = false`). When only one matching folder remains, there is no merge operation to perform, so the function returns the idempotent no-op before canonical merge-destination evaluation.
   - Stale-token precedence: if PLAN previously generated a multi-folder `planToken`, but fresh APPLY topology now contains exactly one matching folder, APPLY returns `OK` / `MERGE_NOT_REQUIRED` and does not return `PLAN_TOKEN_MISMATCH`. The fresh count-one no-op terminal condition has precedence over live token comparison.
   - On 2+ matched folders, resolves canonical destination state via `Resolve-CanonicalDestinationState $topo`. On terminal states (`UNOWNED_DIRECTORY` -> `CANONICAL_FOLDER_NO_UUID_EVIDENCE`, `NON_DIRECTORY_OCCUPANT` -> `MERGE_CANONICAL_PATH_OCCUPIED`, `INSPECTION_FAILED` -> `MERGE_TOPOLOGY_ENUMERATION_FAILED`), returns immediately.
   - Evaluates managed notes and detects cross-folder `NOTE_TYPE_COLLISION`.
   - Recomputes live `New-MergePlanTokenV3` and validates requested `planToken` against live token (`PLAN_TOKEN_MISMATCH`).
   - J-2 Step 11: Live target occupancy preflight inspection (`Resolve-MergeTargetOccupancyState`). Derives `$targetPath = Join-Path $topo.CanonicalFolderFullPath $n.FileName` for each managed note. On `OCCUPIED`, returns terminal `NG` / `MERGE_TARGET_FILE_EXISTS` (`updatedFiles = 0`, `folderRenamed = false`, non-empty `userMessage` containing target path). On `INSPECTION_FAILED`, returns terminal `NG` / `MERGE_OPERATION_FAILED` (`userMessage` containing target path). On `ABSENT` or `SELF_SOURCE`, continues. (APPLY_ONLY; PLAN pipeline never invokes Step 11).
   - Symbolic ordering invariant: `topoErrIdx < c2Idx < applyResolverAssignIdx < branchIdx < managedNotesIdx < tokenV3Idx < tokenMismatchIdx < step11PreflightIdx < txPrepIdx`. `c2Idx` represents the APPLY C-2 matched-folder count-one terminal handling (`MERGE_NOT_REQUIRED`). `managedNotesIdx` includes managed-note recollection and `NOTE_TYPE_COLLISION` detection. `step11PreflightIdx` represents the J-2 Step 11 target occupancy preflight loop, and `txPrepIdx` represents `$inProgressData` / `.inprogress.json` creation. Terminal states never reach transaction preparation, staging, or mutation, and any terminal exit safely releases `ACTIVE.lock`.
   - Writes transaction inprogress evidence (`.inprogress.json`).
   - Creates staging directory via `New-MergeStagingOwnershipSafe`.
   - Writes durable transaction journal via `Write-JournalEvidenceSafe`.
   - Moves files from source folders to staging (Phase 1).
   - Executes Phase 2 migration based on Step 6 `$canonicalState` fixation:
     - Case A (`$canonicalState -eq "MATCHED_EXISTING"`): Moves individual staged files to canonical destination, moves ownership marker, and deletes empty staging directory.
     - Case B (`$canonicalState -eq "ABSENT"`): Moves staging directory atomically to canonical destination path.
     - (The former late `Test-Path -LiteralPath $targetCanonicalDir` selector has been removed).
   - **Executes final topology verification** via `Get-CustomerMergeTopology` *prior* to commit.
   - Writes `committed.json` and updates `$isCommitted = $true`.
   - Executes post-commit cleanup (ownership marker and transaction evidence).
   - Releases lock and returns `MERGE_COMPLETED`.
3. `UPDATE_CUSTOMER_IDENTITY` -> `Invoke-UpdateCustomerIdentity`:
   - Updates YAML frontmatter (`NAME`, `CEO`, `RUBY`, `RANK`, `UUID`) in-place with CRLF line-ending preservation.
   - Renames customer folder and managed notes to canonical form.
   - Returns structured UCI response via `New-UCIResponse`.
4. Legacy Modes:
   - `COMPARE` -> `Invoke-CompareObsidianNotes`
   - `CHECK` -> `Invoke-CheckObsidianNotes`
   - `OPEN` -> `Invoke-OpenObsidianNotes`

---

## 3. Win32 Native Interoperability (P/Invoke) & Canonical Resolver Layer

### 3.1 Canonical Destination Resolver (`Resolve-CanonicalDestinationState`)

To eliminate internal disposition discrepancies and unify canonical path validation between PLAN and APPLY, the payload implements a shared private helper:

- **Function Name**: `Resolve-CanonicalDestinationState`
- **Signature**: `param([hashtable]$Topology)`
- **Invocation Contract**: Single positional topology argument (`Resolve-CanonicalDestinationState $topo`).
- **Inspection Path**: `$canonicalPath = $Topology.CanonicalFolderFullPath`
- **Exact Inspection Primitive**:
  ```powershell
  Get-Item -LiteralPath $canonicalPath -Force -ErrorAction Stop
  ```

#### State Transition & Return Semantics:

| State | Detection & Classification Condition |
|---|---|
| `ABSENT` | `[System.Management.Automation.ItemNotFoundException]` caught; or Windows PowerShell 5.1 literal bracket-path absent condition returning `$null`. |
| `INSPECTION_FAILED` | Any non-`ItemNotFoundException` exception caught during `Get-Item` (e.g. sharing violation, access denied, I/O failure). |
| `MATCHED_EXISTING` | `Get-Item` returns container (`$item.PSIsContainer -eq $true`) whose identity matches `$Topology.MatchedFolders` by `canonicalPath == matched.FullPath` or `CanonicalFolderName == matched.FolderName` using explicit `[System.StringComparison]::OrdinalIgnoreCase`. |
| `UNOWNED_DIRECTORY` | `Get-Item` returns container (`$item.PSIsContainer -eq $true`) that does not match any entry in `$Topology.MatchedFolders`. |
| `NON_DIRECTORY_OCCUPANT` | `Get-Item` returns a non-container filesystem object (`$item.PSIsContainer -eq $false`) occupying `$canonicalPath`. |

#### Terminal Response Contract:
PLAN and APPLY map resolver states as follows:
- `UNOWNED_DIRECTORY` $\rightarrow$ `NG` / `CANONICAL_FOLDER_NO_UUID_EVIDENCE`
- `NON_DIRECTORY_OCCUPANT` $\rightarrow$ `NG` / `MERGE_CANONICAL_PATH_OCCUPIED`
- `INSPECTION_FAILED` $\rightarrow$ `NG` / `MERGE_TOPOLOGY_ENUMERATION_FAILED`
- `MATCHED_EXISTING` / `ABSENT` $\rightarrow$ Non-terminal, proceeds to managed-note processing.

#### Phase-2 Case A / Case B State Fixation:
Phase-2 migration branching is fixed exclusively by Step 6 `$canonicalState`:
- `$canonicalState -eq "MATCHED_EXISTING"` $\rightarrow$ **Case A**
- `$canonicalState -eq "ABSENT"` $\rightarrow$ **Case B**

The former late `Test-Path -LiteralPath $targetCanonicalDir` selector has been removed.

### 3.2 Target Occupancy Preflight Resolver (`Resolve-MergeTargetOccupancyState`)

To detect existing filesystem occupants at the canonical merge destination before any staging or transaction mutations occur, the payload implements a dedicated private helper:

- **Function Name**: `Resolve-MergeTargetOccupancyState`
- **Signature**: `param([string]$TargetPath, [string]$SourcePath)`
- **Invocation Contract**: Evaluated per managed note during APPLY: `Resolve-MergeTargetOccupancyState -TargetPath $targetPath -SourcePath $n.FullPath`.
- **Exact Inspection Primitive**:
  ```powershell
  Get-Item -LiteralPath $TargetPath -Force -ErrorAction Stop
  ```
- **Helper Character**:
  - Read-only with respect to filesystem state.
  - Not a JSON response emitter (returns one of four classification strings to caller).
  - Not a mutation helper.

#### State Classification & Return Semantics:

| State | Detection & Classification Condition |
|---|---|
| `SELF_SOURCE` | `TargetPath` equals `SourcePath` evaluated with `[System.StringComparison]::OrdinalIgnoreCase`. Full-path comparison; filesystem object identity not required. |
| `ABSENT` | `[System.Management.Automation.ItemNotFoundException]` caught; or the current Windows PowerShell compatibility fallback where the Get-Item result is $null (`$null -eq $item`). |
| `OCCUPIED` | `Get-Item` returns non-null filesystem object occupying `$TargetPath` after `SELF_SOURCE` exclusion. |
| `INSPECTION_FAILED` | Any non-`ItemNotFoundException` exception caught during `Get-Item` (e.g. sharing violation, access denied, I/O failure). |

#### Integration & Terminal Response Mapping in `Invoke-ApplyCustomerFolderMerge`:
- **Execution Point**: Executed after `PLAN_TOKEN_MISMATCH` validation, and strictly before `$inProgressData` creation, staging directory creation (`staging_<TxId>`), durable journal creation (`<TxId>.journal.json`), or customer data mutation.
- **Mapping**:
  - `OCCUPIED` $\rightarrow$ `NG` / `MERGE_TARGET_FILE_EXISTS` (`updatedFiles = 0`, `folderRenamed = false`, `userMessage` contains `$targetPath`).
  - `INSPECTION_FAILED` $\rightarrow$ `NG` / `MERGE_OPERATION_FAILED` (`userMessage` contains `$targetPath`).
  - `ABSENT` / `SELF_SOURCE` $\rightarrow$ Preflight passes cleanly; normal APPLY sequence continues.
- **Pipeline Isolation**: The PLAN pipeline (`Invoke-PlanCustomerFolderMerge`) does not invoke `Resolve-MergeTargetOccupancyState`.
- **TOCTOU Defense Preservation**: Generic staging same-name throw (`throw "ステージングに同名ファイルが既に存在します: $dstPath"`) and canonical same-name throw (`throw "最終Canonicalフォルダに同名ファイルが既に存在します: $finalFile"`) are preserved in the payload AST as defense-in-depth against race conditions.

### 3.3 Win32 Kernel APIs (P/Invoke)

To guarantee safety beyond standard .NET abstractions, the payload includes a C# type definition (`Win32NativeMergeHelper`) compiling native Win32 kernel APIs:

| Win32 API Function | Usage in Payload | Safety Purpose |
|---|---|---|
| `CreateFileW` | `Get-FileHardLinkCountSafe`, `Test-DirectoryCaseSensitiveSafe` | Open raw file/directory handles without following unintended symlinks or mutating file times. |
| `GetFileInformationByHandle` | `Get-FileHardLinkCountSafe` | Query `nNumberOfLinks`. Detects NTFS hardlinks (`nNumberOfLinks > 1`) and prevents link breakage. |
| `GetFileInformationByHandleEx` | `Test-DirectoryCaseSensitiveSafe` | Query `FileCaseSensitiveInfo` (Flags: `FILE_CS_FLAG_CASE_SENSITIVE_DIR`). Rejects case-sensitive directories. |
| `FindFirstStreamW` / `FindNextStreamW` / `FindClose` | `Test-FileAlternateDataStreamsSafe` | Enumerate all named streams. Rejects files with non-standard NTFS Alternate Data Streams (`:StreamName:$DATA`). |
| `GetLongPathNameW` | `Resolve-Win32CanonicalPath` | Resolves 8.3 short-name components in a Win32 path to their long-name equivalents, normalizing short-path aliases while preserving the full absolute path. |
| `CreateDirectoryW` | `New-Win32ExclusiveDirectory` | Atomically creates directory with error code 183 (`ERROR_ALREADY_EXISTS`) check, eliminating TOCTOU race conditions. |

Win32 Helper R1 adds a PowerShell helper layer above the P/Invoke declarations: directory handle acquisition with specific desired-access/share/flag contracts (`FILE_LIST_DIRECTORY` or `DELETE` plus `FILE_FLAG_BACKUP_SEMANTICS`), filesystem object identity retrieval via `GetFileInformationByHandle` (volume serial number plus file index tuple), path-to-identity binding verification, and handle-based atomic rename via `SetFileInformationByHandle` / `FileRenameInfo`. Deterministic handle disposal is provided by `Close-DirectoryHandleOnce`. This helper capability is present in the current committed source; full APPLY Case A/B integration using this layer is not yet implemented in the current committed source.

---

## 4. Durable Journal, Rollback, & Commit Architecture

### 4.1 Journal Data Structure
The journal (`<TxId>.journal.json`) is maintained as a strictly structured JSON object:
- `txId`: Unique transaction ID.
- `uuid`: Target customer `pk_CLIENT` UUID.
- `vaultRoot`: Canonical vault root path.
- `canonicalFolderName`: Target folder name (`<Name>_[<UUID8>]`).
- `ownerToken`: 32-byte cryptographically random hex token.
- `rollbackStatus`: Transaction status (`NONE`, `IN_PROGRESS`, `ROLLED_BACK`, `FAILED`).
- `entries`: Array of atomic operations:
  - `Seq`: 1-based sequential operation index.
  - `OpType`: Operation category (`MOVE_FILE`, `MOVE_FILE_STAGING_TO_CANONICAL`, `MOVE_OWNERSHIP_MARKER`, `MOVE_DIRECTORY`).
  - `SourcePath`: Absolute source path.
  - `DestPath`: Absolute destination path.
  - `ExpectedSha256`: Pre-computed SHA256 of file before movement.
  - `ExpectedSizeBytes`: Pre-computed file size in bytes.
  - `OwnerToken`: Associated ownership token.
  - `State`: Execution state (`PENDING`, `COMPLETED`, `ROLLED_BACK`).

### 4.2 Merge Commit Ordering & Pre-Commit Verification
The merge operation strictly adheres to the following sequential order:

```text
[ Staging & File Migration ]
             |
             v
[ Final Topology Verification ]
             |
             +--- Pass ---> [ Commit Marker: committed.json + $isCommitted = $true ]
             |                     |
             |                     v
             |              [ Post-Commit Cleanup ]
             |                     |
             |                     v
             |              [ Return MERGE_COMPLETED ]
             |
             +--- Fail ---> [ Throw Exception Pre-Commit ]
                                   |
                                   v
                            [ Invoke-OptionBRollback ]
                                   |
                                   +-- Rollback OK --> Return MERGE_FAILED_ROLLED_BACK
                                   +-- Rollback Fail --> Return MERGE_ROLLBACK_FAILED
```

Key Architectural Invariants:
1. **Verification Precedes Commit**: Final topology verification executes while `$isCommitted` is still `$false`.
2. **Pre-Commit Failures Trigger Rollback**: Any failure during migration or final verification throws into the pre-commit catch block and triggers `Invoke-OptionBRollback`.
3. **No Standalone Verification Code**: There is no standalone `MERGE_FINAL_TOPOLOGY_VERIFY_FAILED` wire code. Pre-commit verification failures result in `MERGE_FAILED_ROLLED_BACK` or `MERGE_ROLLBACK_FAILED`.

### 4.3 Post-Commit Interlock & Cleanup
- Once `committed.json` is written and `$isCommitted = $true`, the transaction is formally committed.
- Any subsequent error during cleanup enters the post-commit catch block, which **strictly suppresses rollback** to prevent destructive reversal of a validly committed topology.
- Post-commit cleanup failures return `OK` / `MERGE_COMPLETED` with an appropriate warning code (`OWNERSHIP_MARKER_CLEANUP_PENDING`, `TRANSACTION_MARKER_CLEANUP_PENDING`, or `POST_COMMIT_CLEANUP_FAILED`).

### 4.4 Rollback Engine (`Invoke-OptionBRollback`)
- Operates in reverse sequence (`$entries | Sort-Object Seq -Descending`).
- Validates file existence and hash integrity prior to reverse move.
- Restores original directory and file structures.
- Fails closed on any unexpected state or journal corruption.
- Releases staging ownership marker only upon clean completion.

---

## 5. Test Architecture & Crash Hooks

The repository test harness (`WindowsTestKit_CUSTOMER_FOLDER_MERGE`) verifies resilience using deterministic crash injection:
- Hook Variable: `$global:__TEST_CRASH_HOOK`
- Injection Windows:
  - `Window_A`: Crash before journal creation.
  - `Window_B`: Crash immediately after initial journal creation.
  - `Window_C`: Crash before moving files to staging.
  - `Window_D`: Crash during file migration to staging.
  - `Window_E`: Crash after staging complete, before `committed.json`.
  - `Window_F`: Crash during Option B rollback.
  - `Window_G`: Crash immediately after `committed.json` write.
  - `Window_H`: Crash after rollback completion before evidence cleanup.
- Verification: Test harnesses execute `Run-MergeTests.ps1` and verify that the durable journal and rollback engine leave the vault in a clean, recoverable state across all crash windows.

### 5.1 Dedicated Step-11 Regression Suite (`Test-MergeTargetFileExistsRegression.ps1`)

Dedicated regression test script `WindowsTestKit_CUSTOMER_FOLDER_MERGE\Test-MergeTargetFileExistsRegression.ps1` validates the J-2 Step 11 target occupancy preflight contract under Windows PowerShell 5.1 (`17/17 PASS`, exit code 0).

Key contract verification coverage:

| Test ID | Test Scenario | Expected Outcome & Verified Contract |
|---|---|---|
| `MTF01` | Canonical destination matches source note path | `OK` / `MERGE_COMPLETED`; `SELF_SOURCE` exemption via `OrdinalIgnoreCase` |
| `MTF02` | Unmanaged same-name standard file in canonical folder | `NG` / `MERGE_TARGET_FILE_EXISTS`; unmanaged file occupant collision |
| `MTF03` | Same-name Markdown note with no UUID frontmatter | `NG` / `MERGE_TARGET_FILE_EXISTS`; UUID-less Markdown occupant collision |
| `MTF04` | Same-name Markdown note with different customer UUID | `NG` / `MERGE_TARGET_FILE_EXISTS`; different-UUID Markdown occupant collision |
| `MTF05` | Same-name subdirectory in canonical folder | `NG` / `MERGE_TARGET_FILE_EXISTS`; directory occupant collision |
| `MTF06` | Response shape and property integrity | `status = "NG"`, `code = "MERGE_TARGET_FILE_EXISTS"`, `userMessage` with target path, `updatedFiles = 0`, `folderRenamed = false` |
| `MTF07` | Zero-mutation and lock-release proof | No staging/journal/in-progress files created; customer files untouched; `ACTIVE.lock` cleanly released |
| `MTF08` | AST structural order & operator guard validation | Evaluated after token mismatch and before `$inProgressData`; `TokenKind::Ieq` operator check |
| `MTF09` | Stale multi-folder plan token with changed topology | `NG` / `PLAN_TOKEN_MISMATCH` takes precedence over Step 11 |
| `MTF10` | Single matching folder with colliding file in canonical folder | `OK` / `MERGE_NOT_REQUIRED` takes precedence over Step 11 |
| `MTF11` | Canonical folder exists without UUID evidence | `NG` / `CANONICAL_FOLDER_NO_UUID_EVIDENCE` takes precedence over Step 11 |
| `MTF12` | Same note type across multiple source folders | `NG` / `NOTE_TYPE_COLLISION` takes precedence over Step 11 |
| `MTF13` | No occupant at canonical destination path | `OK` / `MERGE_COMPLETED`; clean pass-through (`ABSENT`) |
| `MTF14` | AST check for generic staging same-name throw | Verifies `throw "ステージングに同名ファイルが既に存在します..."` remains in payload AST |
| `MTF15` | AST check for generic canonical same-name throw | Verifies `throw "最終Canonicalフォルダに同名ファイルが既に存在します..."` remains in payload AST |
| `MTF16` | AST check for PLAN phase isolation | Verifies `Invoke-PlanCustomerFolderMerge` AST contains no Step-11 call |
| `MTF17` | Unexpected inspection failure runtime & AST check | `NG` / `MERGE_OPERATION_FAILED` with target path in `userMessage` |

---

## 6. Corrective Internals Reconciliation (Ver 9.1.1)

The 9.1.1 corrective closure consolidates internal invariants across the bridge engine:

- **P-C1 Byte-Preservation Handling**: Strict binary and text stream preservation across all filesystem operations, maintaining UTF-8 BOM and CRLF integrity with zero content truncation or silent byte alteration.
- **P-C2 Fail-Closed `FOLDER_UUID_INVALID` Handling**: Strict validation of Markdown YAML frontmatter `UUID:` keys. Any malformed, non-canonical, or invalid UUID terminates fail-closed immediately with `FOLDER_UUID_INVALID` without automatic normalization or continue-through.
- **P-C5 YAML-Header Materialization**: Reliable, deterministic frontmatter parsing, formatting, and key-order preservation during note update and relocation phases.
- **P-C6 Lifecycle Ordering & Safety**: Strict sequential phase boundaries across discovery, target preflight inspection, exclusive staging creation, durable journal tracking, pre-commit final topology verification, atomic commit marker creation, and post-commit cleanup interlock.
- **P-C9 APPLY Promotion RelativePath Projection**: Promoted managed notes accurately calculate and maintain true Vault-relative path identities (`RelativePath`) during relocation resolution.

---

## 7. Authority Hierarchy & Conflict Resolution Rule

1. **Current Production Implementation** (`FM-Obsidian-Bridge-Payload.ps1` Ver 9.1.1) and **Final Closure Authorities** (`FINAL_GIT_CLOSURE_HUMAN_GATE_20260912`) are the supreme technical authority.
2. **Current Governance Documentation** (`docs/current/*`) reflects and governs this baseline.
3. **Historical Documents** (`docs/project/*`, `docs/claude/*`, `handoff/*`, `Claude/*`, `Antigravity/*`, `ChatGPT/*`) are historical reference materials and must not override current production or current specifications.

