# CURRENT CANONICAL ARCHITECTURE / DESIGN

## 1. System Architecture Overview

The FM-Obsidian Bridge connects FileMaker CRM with Obsidian Knowledge Vaults using a secure, local, one-shot PowerShell bridge process:

```text
+-------------------------------------------------------------------------------+
|                             FileMaker CRM (RakkoDB)                           |
|   - Confirmed Active Transport Script: Script 307                             |
|   - Historical / Unverified Scripts: Script 299, Script 313                   |
|     (unverified against current repository evidence)                          |
+-------------------------------------------------------------------------------+
                                      |
                       Base Elements Plug-In
                       BE_ExecuteSystemCommand
                       (Specific plugin / FM versions: historical / unverified)
                                      |
                                      v
+-------------------------------------------------------------------------------+
|                    PowerShell Bridge (Ver 9.1.0)                              |
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

### 1.1 FileMaker Evidence Boundaries
Canonical architectural claims regarding FileMaker integration are strictly bounded by direct repository evidence:
- **Directly Evidenced**:
  - Script 307 (Payload dispatch & merge transport)
  - Base Elements plug-in command execution transport (`BE_ExecuteSystemCommand`)
  - Base64-encoded JSON payload transport (`-PayloadB64` / `-PayloadFile`)
- **Historical / Unverified against Current Repository Evidence**:
  - Script 299 (historical open/create routine)
  - Script 313 (historical compare routine)
  - Specific FileMaker Pro major/minor version numbers
  - Specific Base Elements plug-in version numbers (e.g. 5.0.0.2)

No architectural invariants or security decisions depend on the unverified historical claims.

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
     - 2+ matched folders: continues through canonical destination determination, managed-note evaluation, `DUPLICATE_NOTE_TYPE` protection, plan construction, Token V3 generation, and returns structured plan JSON (`MERGE_PLAN_READY`).
   - Releases the per-vault lock on branch exit.
2. `APPLY_CUSTOMER_FOLDER_MERGE` -> `Invoke-ApplyCustomerFolderMerge`:
   - Acquires exclusive per-vault transaction lock (`ACTIVE.lock`).
   - Validates requested plan token against live recomputed plan token.
   - Creates staging directory via `New-MergeStagingOwnershipSafe`.
   - Writes durable transaction journal via `Write-JournalEvidenceSafe`.
   - Moves files from source folders to staging, then staging to canonical target.
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

## 3. Win32 Native Interoperability (P/Invoke) Layer

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

---

## 6. Authority Hierarchy & Conflict Resolution Rule

1. **Current Production Implementation** (`FM-Obsidian-Bridge-Payload.ps1` Ver 9.1.0) and **Final Closure Authorities** (`Step4C-23`, `Step4C-24`, `Step4C-25`, `Step4C-26`) are the supreme technical authority.
2. **Current Governance Documentation** (`docs/current/*`) reflects and governs this baseline.
3. **Historical Documents** (`docs/project/*`, `docs/claude/*`, `handoff/*`, `Claude/*`, `Antigravity/*`, `ChatGPT/*`) are historical reference materials and must not override current production or current specifications.

