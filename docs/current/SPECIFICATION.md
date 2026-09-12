# CURRENT CANONICAL SPECIFICATION

## 1. Product & Feature Identity

- **Product:** FM-Obsidian Bridge (`productId`: `FM-Obsidian-Bridge`)
- **Product Title:** FM-Obsidian Bridge
- **Feature:** Customer Folder Merge (`featureId`: `customer-folder-merge`)
- **Feature Version:** `1`
- **Implementation Version:** `9.1.1`
- **Version Header:** `Ver: 9.1.1 (2026-09-12) - Customer Folder Merge v1 Corrective Closure`
- **Internal / Legacy Routine:** `UPDATE_CUSTOMER_IDENTITY` (an internal routine / older action; never use as a top-level product identifier)
- **Production Baseline Reference:** [`CURRENT_BASELINE.md`](CURRENT_BASELINE.md) and [`current-baseline.json`](current-baseline.json)

---

## 2. Purpose & Objectives

Customer Folder Merge v1 provides a fail-closed, transactionally safe consolidation mechanism for multiple folders in an Obsidian Vault (`01_顧客` tree) that represent the same logical customer entity (identified by FileMaker `pk_CLIENT` UUID).

Key objectives:
- **Identity-First Consolidation**: Customer identity is determined strictly by full `pk_CLIENT` UUID match against Markdown YAML frontmatter `UUID:` keys, never by fuzzy names, folder names, or prefix guesses.
- **Fail-Closed Safety**: Any unexpected filesystem structure, permission failure, unhandled attribute, or topology mutation immediately halts execution with an explicit error code.
- **Zero Data Loss**: No customer files are overwritten or silently discarded. All operations are verified against durable journals before commitment.

---

## 3. Two-Phase PLAN / APPLY Model

Customer Folder Merge operates strictly under a decoupled, two-phase request model:

```text
[ FileMaker CRM ]
       |
       +---> Action: PLAN_CUSTOMER_FOLDER_MERGE
       |        |
       |        v
       |     Acquire Lock -> Scan topology -> Validate safety ->
       |     Generate PlanToken -> Release Lock -> Return JSON Plan
       |
       +---> Action: APPLY_CUSTOMER_FOLDER_MERGE (with PlanToken)
                |
                v
             Acquire Lock -> Validate PlanToken (live recomputed match) ->
             Target Occupancy Preflight -> Transaction Preparation (inprogress.json) ->
             Exclusive Staging -> Durable Journal -> Atomic Migration ->
             Final Topology Verification -> Commit Marker (committed.json) ->
             Post-Commit Cleanup -> Release Lock -> Return Result
```

### 3.1 PLAN Phase (`PLAN_CUSTOMER_FOLDER_MERGE`)
- Acquires exclusive per-vault transaction lock (`ACTIVE.lock`).
- Scans the vault customer tree (`01_顧客`) for folders and notes matching the target `pk_CLIENT`.
- Verifies all topological safety constraints.
- Calculates an invariant topology hash covering all candidate files, hashes, sizes, and relative paths.
- Generates a bound `PlanToken` (`PLAN-V3-<SHA256>`).
- Returns a structured JSON summary describing candidate folders, managed notes, unmanaged files, and planned actions (`MERGE_PLAN_READY`).
- **PLAN Mutation Contract**:
  - PLAN is **customer-data non-mutating**: it does not modify customer folders, managed notes, or customer content.
  - PLAN is **not filesystem-write-free**: it creates and uses the per-vault transaction/concurrency infrastructure under VaultRoot, including `.fm-obsidian-bridge-transactions` directory and `ACTIVE.lock` as required.

### 3.1.1 PLAN Matched-Folder Count Contract (`Invoke-PlanCustomerFolderMerge`)

The PLAN phase returns different terminal results depending on the number of folders matched for the target `pk_CLIENT`:

| Matched Folders | Status | Code | Notes |
|---|---|---|---|
| **0** | `NG` | `CUSTOMER_NOT_FOUND` | Surfaced through topology error handling. No plan, no `planToken`, no mutation. |
| **1** | `OK` | `MERGE_NOT_REQUIRED` | Early terminal result. No merge necessary; no plan or `planToken` is returned. |
| **2 or more** | `OK` | `MERGE_PLAN_READY` | Continues through full plan construction: canonical destination state, managed-note evaluation, `DUPLICATE_NOTE_TYPE` protections, plan construction, and Token V3 generation. |

**Single-folder response fields** (`matchedFolders.Count == 1`):
- `status`: `OK`
- `code`: `MERGE_NOT_REQUIRED`
- `matchedFolderCount`: `1`
- `updatedFiles`: `0`
- `folderRenamed`: `false`
- Fields `plan`, `planToken`, and `mergedNotesCount` are **not present** in this response.

> [!IMPORTANT]
> The single-folder early-return (`MERGE_NOT_REQUIRED`) is implemented and closed in both the **PLAN phase** (`PLAN C-1`, committed at `df8b4791`) and the **APPLY phase** (`APPLY C-2`, current canonical source).
>
> **APPLY Matched-Folder Count Contract** (`Invoke-ApplyCustomerFolderMerge`):
> - **Count 0**: `NG` / `CUSTOMER_NOT_FOUND` (surfaced through fresh topology error handling). No live token comparison, no transaction preparation, and no customer data mutation.
> - **Count 1**: `OK` / `MERGE_NOT_REQUIRED` (terminal no-op early return). Required response properties: `status = "OK"`, `code = "MERGE_NOT_REQUIRED"`, `matchedFolderCount = 1`, `updatedFiles = 0`, `folderRenamed = false`, `requestId = incoming requestId`, and `userMessage = "マージ対象フォルダが1件のみのため、統合は不要です。"`. Does **not** emit `plan`, `planToken`, or `mergedNotesCount`. This branch is terminal before the J-2 canonical resolver, managed-note re-collection, Token V3 calculation, live token comparison, transaction preparation, and mutation.
> - **Count 2 or more**: Continues to J-2 Step 6 (`Resolve-CanonicalDestinationState`) and the remaining existing APPLY sequence.
>
> **Stale-Token Precedence**:
> If PLAN previously generated a multi-folder `planToken`, but fresh APPLY topology now contains exactly one matching folder, APPLY returns `OK` / `MERGE_NOT_REQUIRED` and does **not** return `PLAN_TOKEN_MISMATCH`. The fresh count-one no-op terminal condition has strict precedence over live token comparison. Prior folder count from PLAN is never trusted.

### 3.1.2 Canonical Destination Resolver & Terminal Contract

Prior to managed-note evaluation and token generation, both PLAN and APPLY evaluate the filesystem state of the target canonical destination path (`CanonicalFolderFullPath`) using the shared private helper `Resolve-CanonicalDestinationState`:

| Resolver State | PLAN Response (`status` / `code`) | APPLY Response (`status` / `code`) | Disposition / Continuation |
|---|---|---|---|
| `MATCHED_EXISTING` | Continues to managed-note processing | Continues to managed-note processing | Non-terminal. Fixes Phase-2 migration to **Case A** (merge into existing canonical directory). |
| `ABSENT` | Continues to managed-note processing | Continues to managed-note processing | Non-terminal. Fixes Phase-2 migration to **Case B** (atomic staging directory move). |
| `UNOWNED_DIRECTORY` | `NG` / `CANONICAL_FOLDER_NO_UUID_EVIDENCE` | `NG` / `CANONICAL_FOLDER_NO_UUID_EVIDENCE` | **Terminal Fail-Closed**. Canonical directory exists on disk but contains no matching customer UUID evidence. |
| `NON_DIRECTORY_OCCUPANT` | `NG` / `MERGE_CANONICAL_PATH_OCCUPIED` | `NG` / `MERGE_CANONICAL_PATH_OCCUPIED` | **Terminal Fail-Closed**. Canonical destination path is occupied by a non-directory filesystem object (e.g. standard file). |
| `INSPECTION_FAILED` | `NG` / `MERGE_TOPOLOGY_ENUMERATION_FAILED` | `NG` / `MERGE_TOPOLOGY_ENUMERATION_FAILED` | **Terminal Fail-Closed**. Filesystem inspection of canonical path failed (access/sharing violation or unexpected OS error). |

#### Fail-Closed Terminal Boundary & Symbolic Ordering
For terminal states (`UNOWNED_DIRECTORY`, `NON_DIRECTORY_OCCUPANT`, `INSPECTION_FAILED`), execution terminates immediately and never proceeds further:
- **PLAN Ordering Invariant**: `planOneFolderIdx < planResolverAssignIdx < planBranchIdx < planManagedNotesIdx`.  
  Terminal branches exit before managed-note processing, duplicate note type detection, and `New-MergePlanTokenV3` plan-token generation.
- **APPLY Ordering Invariant**: `topoErrIdx < c2Idx < applyResolverAssignIdx < branchIdx < managedNotesIdx < tokenV3Idx < tokenMismatchIdx < step11PreflightIdx < txPrepIdx`.  
  `c2Idx` represents the APPLY C-2 matched-folder count-one terminal handling (`MERGE_NOT_REQUIRED`). `managedNotesIdx` includes managed-note recollection and `NOTE_TYPE_COLLISION` detection. `step11PreflightIdx` represents the J-2 Step 11 target occupancy preflight loop, and `txPrepIdx` represents `$inProgressData` / `.inprogress.json` creation. Terminal branches exit before subsequent processing, and any terminal exit safely releases `ACTIVE.lock`.

#### Phase-2 Case A / Case B State Fixation
The Phase-2 mutation disposition is fixed exclusively by the Step 6 resolver state:
- `$canonicalState -eq "MATCHED_EXISTING"` $\rightarrow$ **Case A** (individual file moves to canonical folder, ownership marker move, empty staging deletion).
- `$canonicalState -eq "ABSENT"` $\rightarrow$ **Case B** (atomic directory move from staging to canonical path).

The former late `Test-Path -LiteralPath $targetCanonicalDir` Case A/B selector has been removed and replaced by `$canonicalState -eq "MATCHED_EXISTING"`. This guarantees that no subsequent fresh filesystem test can alter the Step 6 disposition.

### 3.2 APPLY Phase (`APPLY_CUSTOMER_FOLDER_MERGE`)
- Requires an explicit, non-empty `planToken` provided in the payload.
- Acquires exclusive per-vault transaction lock (`ACTIVE.lock`).
- Re-scans current filesystem topology via `Get-CustomerMergeTopology`.
- If topology error occurs, immediately terminates fail-closed (e.g. `CUSTOMER_NOT_FOUND` on 0 matched folders).
- If fresh `MatchedFolders.Count -eq 1`, immediately returns terminal `OK` / `MERGE_NOT_REQUIRED` (`matchedFolderCount = 1`, `updatedFiles = 0`, `folderRenamed = false`). Stale multi-folder tokens do not trigger `PLAN_TOKEN_MISMATCH` (stale-token precedence).
- If fresh `MatchedFolders.Count >= 2`, evaluates canonical destination path state via `Resolve-CanonicalDestinationState` (J-2 Step 6) and dispatches terminal errors (`CANONICAL_FOLDER_NO_UUID_EVIDENCE`, `MERGE_CANONICAL_PATH_OCCUPIED`, `MERGE_TOPOLOGY_ENUMERATION_FAILED`).
- Re-verifies managed note types across candidate folders. If collision occurs, rejects with `NOTE_TYPE_COLLISION`.
- Recomputes live `New-MergePlanTokenV3` and validates requested `planToken` against live token (`PLAN_TOKEN_MISMATCH`).
- Executes live target occupancy preflight inspection for all managed notes (J-2 Step 11, `APPLY_ONLY`). If any canonical target path is occupied by an existing non-self object, returns terminal `NG` / `MERGE_TARGET_FILE_EXISTS`. If target path inspection fails unexpectedly, returns terminal `NG` / `MERGE_OPERATION_FAILED`. Normal APPLY continues only when target paths are `ABSENT` or `SELF_SOURCE`.
- Prepares transaction record (`$inProgressData` / `.inprogress.json`).
- Executes atomic file migration through exclusive staging (`staging_<TxId>`) and durable journal tracking (`<TxId>.journal.json`).
- Executes **final topology verification** against the post-merge vault structure while still pre-commit. If verification fails, an exception is thrown and the operation enters the rollback engine.
- Only upon successful final verification is the commit marker written (`committed.json`, `$isCommitted = $true`).
- Completes best-effort post-commit cleanup (ownership marker and transaction evidence).
- Releases transaction lock and returns `MERGE_COMPLETED`.

### 3.2.1 Live Target Occupancy Preflight Contract (J-2 Step 11, `APPLY_ONLY`)

Prior to transaction preparation and customer mutation, the APPLY phase performs a structured preflight check verifying that no file or filesystem object collision exists at the canonical destination for any managed note:

#### Scope & Pipeline Isolation
- `MERGE_TARGET_FILE_EXISTS` is strictly an **`APPLY_ONLY`** response code.
- It **MUST NOT** be emitted as a PLAN response under any circumstance. The PLAN pipeline does not perform the Step-11 per-managed-note target occupancy preflight and does not emit `MERGE_TARGET_FILE_EXISTS`. This does not alter the existing J-2 Step-6 PLAN canonical-destination-state evaluation.

#### Relative APPLY Precedence
Within `Invoke-ApplyCustomerFolderMerge`, checks execute in the following strict bounded order:
1. Fresh topology enumeration (`Get-CustomerMergeTopology`)
2. Topology error handling (`CUSTOMER_NOT_FOUND`, etc.)
3. C-2 matched-folder-count handling (`MERGE_NOT_REQUIRED` on count = 1)
4. J-2 canonical destination state handling (`Resolve-CanonicalDestinationState` terminal states)
5. Managed-note recollection (`$allManagedNotes`)
6. `NOTE_TYPE_COLLISION` cross-folder detection
7. Live Token V3 recomputation (`New-MergePlanTokenV3`)
8. `PLAN_TOKEN_MISMATCH` live token validation
9. J-2 Step 11 target occupancy preflight (`Resolve-MergeTargetOccupancyState` $\rightarrow$ `MERGE_TARGET_FILE_EXISTS`)
10. Transaction preparation (`$inProgressData` / `.inprogress.json`)
11. Exclusive staging and customer data mutation

The J-2 Step 11 preflight executes strictly **after** `PLAN_TOKEN_MISMATCH` validation and strictly **before** transaction preparation.
Consequently:
- C-2 count-one `MERGE_NOT_REQUIRED` wins before Step 11.
- J-2 canonical terminal responses (`CANONICAL_FOLDER_NO_UUID_EVIDENCE`, `MERGE_CANONICAL_PATH_OCCUPIED`, `MERGE_TOPOLOGY_ENUMERATION_FAILED`) win before Step 11.
- `NOTE_TYPE_COLLISION` wins before Step 11.
- `PLAN_TOKEN_MISMATCH` wins before Step 11.

#### Live Target Derivation
Target paths are derived dynamically in APPLY from live state:
$$\text{targetPath} = \text{Join-Path } \$topo\text{.CanonicalFolderFullPath } \$n\text{.FileName}$$
A PLAN-supplied target path is never authoritative; live canonical folder path plus live managed note filename governs.

#### Self-Source Exemption
A target path is exempt from collision detection and not considered occupied when target full path and source full path are equal under:
```powershell
[string]::Equals($TargetPath, $SourcePath, [System.StringComparison]::OrdinalIgnoreCase)
```
- Evaluation uses full absolute paths, not filename-only comparison.
- String path equality is sufficient; filesystem object identity is not required.
- When `SELF_SOURCE` is detected, inspection does not halt; processing continues.

#### Occupancy Contract
For any non-self target, an existing filesystem occupant constitutes a collision. The collision contract encompasses at least:
- Unmanaged same-name file;
- UUID-less same-name Markdown file;
- Different-UUID same-name Markdown file;
- Another existing managed-note occupant where applicable;
- Same-name directory;
- Any other filesystem occupant resolved by the inspection primitive.

Collision handling is fail-closed and non-destructive:
- No overwrite.
- No delete.
- No auto-adopt.
- No UUID rewrite.
- No automatic normalization to bypass the collision.

#### Collision Response
When an occupant is detected (`OCCUPIED`):
- `status`: `NG`
- `code`: `MERGE_TARGET_FILE_EXISTS`
- `userMessage`: Non-empty and contains the actual inspected target path (`"マージ先に同名ファイルまたはオブジェクトが既に存在します: $targetPath"`).
- `requestId`: Exact incoming request identifier.
- `updatedFiles`: `0`
- `folderRenamed`: `false`
- No Step-11-specific extra diagnostic response fields are introduced.
- Execution halts immediately before transaction preparation, staging, journal creation, or customer data mutation.
- The transaction lock (`ACTIVE.lock`) is safely released before returning, consistent with all terminal responses.

#### Inspection Failure
If target path inspection fails for a reason other than absence (e.g. sharing violation, access denied, I/O error):
- `status`: `NG`
- `code`: `MERGE_OPERATION_FAILED`
- `userMessage`: Non-empty and contains the inspected target path (`"マージ先パスの検査に失敗しました: $targetPath"`).
- MUST NOT be documented or returned as `MERGE_TARGET_FILE_EXISTS`, `MERGE_TOPOLOGY_ENUMERATION_FAILED`, or `ABSENT`/pass-through.
- An occupant is never falsely reported when inspection itself failed.
- Execution terminates fail-closed prior to transaction preparation and customer mutation, releasing `ACTIVE.lock`.

#### Absence / Self-Source Continuation
When inspection yields `ABSENT` or `SELF_SOURCE`, the J-2 Step 11 preflight completes cleanly, and normal APPLY processing continues. If `$allManagedNotes` contains zero notes, the preflight loop executes zero iterations and processing continues to transaction preparation.

#### TOCTOU Defense-in-Depth Preservation
The J-2 Step 11 preflight is an early structured preflight only. It does **not** replace later generic collision/TOCTOU defenses during:
- Source $\rightarrow$ staging migration (`throw "ステージングに同名ファイルが既に存在します: $dstPath"`)
- Staging $\rightarrow$ canonical migration (`throw "最終Canonicalフォルダに同名ファイルが既に存在します: $finalFile"`)

Those generic same-name collision throws remain fully preserved in the payload AST as defense-in-depth against concurrent filesystem modification.

### 3.3 Strict Governance Rules
- **No Implicit Apply**: No merge mutation is ever executed without an explicit `APPLY_CUSTOMER_FOLDER_MERGE` action containing a verified `planToken`.
- **No Automatic Selection**: If duplicate note types or mixed UUIDs exist, the system stops and reports error rather than picking an arbitrary winner.

---

## 4. Plan-Token Binding & Error Contract

Plan tokens (`New-MergePlanTokenV3`) cryptographically bind:
1. **Target `pk_CLIENT` UUID**: Normalized uppercase UUID.
2. **Canonical Customer Name**: Normalized folder name prefix.
3. **Canonical VaultRoot**: Win32 canonical path (`Resolve-Win32CanonicalPath`).
4. **Source Folder Names**: Complete list of candidate folder names.
5. **Managed Notes Topology**: Relative paths, note types, sizes, and content SHA256 hashes.

### 4.1 Plan-Token Wire Error Contract
The production wire/API exposes **exactly one** top-level error code for all plan-token mismatch conditions:

$$\text{Wire Error Code: } \mathbf{PLAN\_TOKEN\_MISMATCH}$$

All mismatch scenarios collapse to `PLAN_TOKEN_MISMATCH` in the top-level response:
- **Topology Mutation**: Files added, modified, renamed, or deleted between PLAN and APPLY.
- **Foreign Customer Context**: Token generated for a different customer UUID or company name.
- **Cross-Vault Token**: Token generated for a different VaultRoot path.
- **Malformed / Arbitrary Token**: Token string that is malformed, invalid, or arbitrary.

> [!IMPORTANT]
> The following codes **DO NOT EXIST** on the production wire/API and MUST NOT be documented as observable error codes:
> - `STALE_PLAN_TOPOLOGY_MUTATED`
> - `FOREIGN_PLAN_TOKEN_REJECTED`
> - `CROSS_VAULT_PLAN_REJECTED`
> - `PLAN_TOKEN_INVALID`
>
> Any breakdown of token mismatch causes (e.g. topology changed, cross-vault, foreign context) represents **semantic causes only**, not separate externally observable error codes. The production implementation compares opaque token strings and does not perform field-level token decoding.

---

## 5. Duplicate Note Type Code Distinction

The bridge distinguishes duplicate note type detection by phase and scope:

| Phase / Detection Context | Observable Top-Level Code | Description |
|---|---|---|
| **PLAN / Topology Detection** | `DUPLICATE_NOTE_TYPE` | Detected within a single candidate folder during topology scan or across folders during PLAN generation. |
| **APPLY Cross-Folder Collision** | `NOTE_TYPE_COLLISION` | Detected during APPLY-time candidate folder iteration when identical `noteType` exists across multiple merging folders. |

These two codes are distinct in production and must not be conflated into a single universal code.

---

## 6. Complete Wire Code Catalog

### 6.1 Top-Level Response Codes (`New-MergeResponse`)

#### Success (`Status: "OK"`)
- `MERGE_PLAN_READY`: Merge plan generated successfully with bound `planToken` and proposed file moves (PLAN phase, 2+ matched folders).
- `MERGE_NOT_REQUIRED`: PLAN or APPLY phase determined exactly 1 folder matches the target `pk_CLIENT`; no merge is necessary. In both phases, returns `matchedFolderCount = 1`, `updatedFiles = 0`, `folderRenamed = false`. Fields `plan`, `planToken`, and `mergedNotesCount` are not present. In APPLY, this terminal no-op takes precedence over live token validation (stale-token precedence).
- `MERGE_COMPLETED`: Merge operation successfully verified, committed, and finalized.

#### Error (`Status: "NG"`)
- `INVALID_REQUEST`: Missing mandatory parameters (`VaultRoot`, `planToken`), invalid/unresolvable VaultRoot, or unexpected payload keys.
- `INVALID_UUID_FORMAT`: `pk_CLIENT` parameter is not a valid canonical UUID format.
- `MERGE_OPERATION_IN_PROGRESS`: Transaction lock contention (`ACTIVE.lock` held by another active bridge process).
- `MERGE_OPERATION_FAILED`: Lock acquisition failed due to non-contention OS/filesystem error, or target path inspection failed during J-2 Step 11 preflight (`userMessage` contains inspected target path).
- `MERGE_RECOVERY_REQUIRED`: Unresolved `.inprogress.json` transaction marker exists from a prior incomplete transaction.
- `CANONICAL_FOLDER_NO_UUID_EVIDENCE`: A folder matching canonical name exists on disk but contains no UUID evidence for target client.
- `MERGE_CANONICAL_PATH_OCCUPIED`: The canonical destination path is occupied by a non-directory filesystem object, so merge planning/application stops fail-closed.
- `PLAN_TOKEN_MISMATCH`: Requested `planToken` does not match live recomputed plan token.
- `MERGE_TARGET_FILE_EXISTS`: Target path in canonical destination is already occupied by a non-self filesystem object (file, markdown note, directory, etc.) during APPLY live target occupancy preflight (`APPLY_ONLY`). Returns `status = "NG"`, `code = "MERGE_TARGET_FILE_EXISTS"`, `updatedFiles = 0`, `folderRenamed = false`, and non-empty `userMessage` containing the inspected target path. Terminates fail-closed prior to transaction preparation and customer mutation.
- `DUPLICATE_NOTE_TYPE`: Multiple managed notes with the same `noteType` detected in candidate folder.
- `NOTE_TYPE_COLLISION`: Colliding managed notes of same `noteType` found across merging candidate folders during APPLY.
- `MERGE_FAILED_ROLLED_BACK`: Merge operation encountered an error prior to commit; durable rollback completed successfully.
- `MERGE_ROLLBACK_FAILED`: Merge operation encountered an error prior to commit and rollback also failed (requires manual operator recovery).

### 6.2 Topology Validation Error Codes (`Get-CustomerMergeTopology`)
When `Get-CustomerMergeTopology` encounters a safety violation, it returns an error object surfaced directly through `New-MergeResponse`:

| Error Code | Violation Description |
|---|---|
| `CUSTOMER_NOT_FOUND` | `01_顧客` root directory does not exist, or no folders with target UUID evidence exist. |
| `MERGE_REPARSE_POINT_UNSUPPORTED` | Reparse point (symlink, junction point, mount point) detected on customer root, folder, subfolder, or file. |
| `MERGE_HARDLINK_UNSUPPORTED` | File has hardlink count $> 1$ or hardlink query failed. |
| `MERGE_ALTERNATE_DATA_STREAM_UNSUPPORTED` | File contains named NTFS Alternate Data Streams (`:StreamName:$DATA`). |
| `MERGE_CASE_SENSITIVE_DIRECTORY_UNSUPPORTED` | Customer root directory has `FILE_CS_FLAG_CASE_SENSITIVE_DIR` enabled. |
| `MERGE_TOPOLOGY_ENUMERATION_FAILED` | Filesystem enumeration failed due to sharing violation, lock, or access permission error. |
| `FOLDER_UUID_INVALID` | YAML frontmatter `UUID:` in Markdown note is malformed or invalid UUID format. |
| `MERGE_UNMANAGED_UUID_EVIDENCE` | Target customer UUID detected in a non-managed Markdown file (outside known prefix map). |
| `MANAGED_NOTE_OUT_OF_SCOPE` | Managed note containing target customer UUID detected in a subfolder. |
| `FOLDER_UUID_MIXED` | Single customer folder contains notes with multiple conflicting customer UUIDs. |

### 6.3 Post-Commit Warning Codes
When a transaction commits successfully (`MERGE_COMPLETED`) but post-commit cleanup encounters non-fatal errors, warning codes are returned in the response:
- `OWNERSHIP_MARKER_CLEANUP_PENDING`: Deletion of `.fm-obsidian-merge-owner` in canonical folder failed.
- `TRANSACTION_MARKER_CLEANUP_PENDING`: Deletion of journal, inprogress, or committed files in transaction directory failed.
- `POST_COMMIT_CLEANUP_FAILED`: General post-commit cleanup exception.

### 6.4 Free-Text Exception Classifications
The following are internal exception classification strings (not top-level structured response codes) and must not be documented as wire-level response codes:
- `STAGING_DIR_ALREADY_EXISTS`
- `STAGING_DIR_CREATE_FAILED_NATIVE`

---

## 7. Staging, Durable Journal, Rollback, & Commit Ordering

```text
[ Staging Setup ]
       |
       v
Create Exclusive Staging Dir (staging_<TxId>) + Owner Marker (.fm-obsidian-merge-owner)
       |
       v
[ Write Durable Journal ] -> <TxId>.journal.json flushed to disk with UTF8 BOM / FileStream
       |
       v
[ File Movement ] -> Move source files to staging -> Move staging to canonical target
       |
       v
[ Final Topology Verification ] -> Execute Get-CustomerMergeTopology on post-merge vault
       |
       +--- On Failure (Pre-Commit) ---> Throw -> Rollback Engine (Invoke-OptionBRollback)
       |                                           |
       |                                           +--> Rollback OK: MERGE_FAILED_ROLLED_BACK
       |                                           +--> Rollback Fail: MERGE_ROLLBACK_FAILED
       v
[ Commit Point ] -> Write committed.json + Set $isCommitted = $true
       |
       v
[ Post-Commit Cleanup ] -> Remove ownership marker, delete transaction evidence files
       |
       +--- On Post-Commit Error ---> Post-Commit Interlock (Rollback permanently suppressed)
       |                              Return MERGE_COMPLETED with warning code
       v
[ Success Response ] -> Return OK / MERGE_COMPLETED
```

### 7.1 Exclusive Staging Ownership
- Staging directory is created via native Win32 `CreateDirectoryW` (`New-Win32ExclusiveDirectory`).
- A cryptographically random 32-byte ownership token is written to `.fm-obsidian-merge-owner`.
- The marker is verified via read-back. If the marker exists or cannot be verified, execution halts.

### 7.2 Durable Journal (`<TxId>.journal.json`)
- Maintained via `Write-JournalEvidenceSafe`.
- Contains ordered operation sequence (`entries`), operation types (`MOVE_FILE`, `MOVE_FILE_STAGING_TO_CANONICAL`, `MOVE_OWNERSHIP_MARKER`, `MOVE_DIRECTORY`), source paths, destination paths, expected SHA256 hashes, and operation state (`PENDING`, `COMPLETED`, `ROLLED_BACK`).

### 7.3 Final Topology Verification & Pre-Commit Ordering
- Final topology verification (`Get-CustomerMergeTopology`) executes **before** the commit marker is written.
- It verifies:
  1. All source files are present in their canonical destination folder.
  2. Total managed notes count matches expected pre-merge count.
  3. Matched folders reduce to exactly 1 folder matching the canonical folder name.
  4. All file hashes, hardlink counts, ADS checks, and attribute invariants remain clean.
- If final topology verification fails, an exception is thrown **while still pre-commit**.
- Pre-commit exception enters the rollback path:
  - Rollback success $\rightarrow$ `MERGE_FAILED_ROLLED_BACK`
  - Rollback failure $\rightarrow$ `MERGE_ROLLBACK_FAILED`
- > [!NOTE]
  > The nonexistent code `MERGE_FINAL_TOPOLOGY_VERIFY_FAILED` is removed. Final verification failure occurs pre-commit and always enters rollback.

### 7.4 Commit Point & Post-Commit Interlock
- Only after final topology verification succeeds is `committed.json` written to disk and `$isCommitted = $true`.
- Once committed, the transaction is immutable.
- Any error during post-commit cleanup (e.g. deleting marker files) enters the post-commit interlock, which **strictly suppresses rollback** to prevent destructive reversal of a validly committed topology.
- Post-commit cleanup failures return `OK` / `MERGE_COMPLETED` with an appropriate warning code (`OWNERSHIP_MARKER_CLEANUP_PENDING`, `TRANSACTION_MARKER_CLEANUP_PENDING`, or `POST_COMMIT_CLEANUP_FAILED`).

---

## 8. Non-Goals & Prohibited Behaviors

- **No Uncontrolled Auto-Merge**: The bridge never merges folders without explicit user confirmation in FileMaker.
- **No Cross-Vault Token Reuse**: Tokens issued for Vault A cannot be applied in Vault B.
- **No Safety Check Bypass**: Flags or parameters to disable hardlink, ADS, reparse point, or case-sensitivity checks are strictly forbidden.
- **No In-Place Overwriting**: Markdown notes are never overwritten without UUID identity verification and content checksum validation.

---

## 9. Corrective Closure

### 9.1.1 Corrective Closure

The Customer Folder Merge v1 corrective closure is fixed at implementation version 9.1.1 and does not introduce a new feature version. Customer Folder Merge remains Feature Version 1 / implementation 9.1.1.

#### Explicit Settled Behavioral Invariants:

1. **Fail-Closed Invalid UUID Finalization**:
   Invalid UUID evidence is strictly fail-closed: `status = NG`, `code = FOLDER_UUID_INVALID`. No automatic repair, normalization, or continue-through is permitted for invalid UUID evidence.
2. **Distinct Conflict Code Preservation**:
   `UUID_FOLDER_CONFLICT` remains the distinct multiple-folder identity-conflict path used by the UCI/FileMaker caller flow.
3. **Action Protocol Invariance**:
   `PLAN_CUSTOMER_FOLDER_MERGE` and `APPLY_CUSTOMER_FOLDER_MERGE` action names remain unchanged.
4. **Opaque Plan-Token Contract**:
   `planToken` remains completely opaque to FileMaker and is passed unchanged from PLAN to APPLY.
5. **External Terminal Response Invariance**:
   `MERGE_PLAN_READY`, `MERGE_NOT_REQUIRED`, and `MERGE_COMPLETED` external contracts remain current.
6. **APPLY RelativePath Projection Corrective (P-C9)**:
   Promoted managed-note results retain correct Vault-relative path identity (`RelativePath`). This specifies the observable/invariant integrity required by the specification. `RelativePath` is not a new FileMaker-facing response wire field.
7. **Feature Version Stability**:
   Corrective closure does not introduce a new feature version. Customer Folder Merge remains Feature Version 1 / implementation 9.1.1.

#### Summary of Settled Corrective Closures:

- **Legacy folder/name-match corrective closure**: Reconciled and validated across focused regression suites.
- **Fail-closed invalid UUID finalization**: Invalid UUID formats in Markdown frontmatter reject immediately with `FOLDER_UUID_INVALID`.
- **Byte/content preservation corrective**: Byte-exact payload and note content handling preserved without loss.
- **YAML/header materialization correctness**: Correct frontmatter ordering and key preservation maintained.
- **Lifecycle ordering and safety**: Strict sequential ordering enforced across all discovery, preflight, staging, verification, and commit phases.
- **APPLY RelativePath projection corrective**: Note relocation results reflect true Vault-relative paths.
- **Zero external PLAN/APPLY protocol change**: Complete backward-compatible stability with FileMaker integration layer.
