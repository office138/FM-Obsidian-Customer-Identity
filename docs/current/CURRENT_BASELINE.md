# CURRENT BASELINE

## 1. Governance Notices

> **This baseline describes the current repository-canonical, formally-closed source and current-documentation state.**
> 
> **Product Version:** `9.1.1`
> **Feature:** `customer-folder-merge` (Customer Folder Merge v1)
> **Effective Date:** `2026-09-12`
> **Production Vault Deployment Status:** `DEPLOYED`
> **Formal Project Closure Disposition:** `PASS_CUSTOMER_FOLDER_MERGE_V1_FORMAL_PROJECT_CLOSURE_COMPLETE`

---

## 2. Product Identity

- **Product ID:** `FM-Obsidian-Bridge`
- **Product Title:** `FM-Obsidian Bridge`
- **Feature ID:** `customer-folder-merge`
- **Feature Title:** `Customer Folder Merge`
- **Feature Version:** `1`
- **Implementation Version:** `9.1.1`
- **Internal / Legacy Routine:** `UPDATE_CUSTOMER_IDENTITY` (an internal routine / older action; never use as a top-level product identifier)

---

## 3. Baseline Attributes

| Attribute | Value |
|---|---|
| productId | FM-Obsidian-Bridge |
| productTitle | FM-Obsidian Bridge |
| featureId | customer-folder-merge |
| featureTitle | Customer Folder Merge |
| featureVersion | 1 |
| implementationVersion | 9.1.1 |
| versionHeader | Ver: 9.1.1 (2026-09-12) - Customer Folder Merge v1 Corrective Closure |
| canonicalSourcePath | FM-Obsidian-Bridge-Payload.ps1 |
| canonicalSha256 | 3AFDF25C643F8820545FF169DEC411A13B990EBF8C99086F5AB7DC33EC9CB50B |
| canonicalSizeBytes | 333267 |
| canonicalEncoding | UTF-8 BOM |
| canonicalEol | CRLF |
| bindingCommitSha | b95489cf931ff1806a0580725ab13c225dd8917a |
| commitParentSha | 223f6fae859cf9cf1d4cf21d8b2e1a3bc472d829 |
| closureAuthority | FINAL_GIT_CLOSURE_HUMAN_GATE_20260912 |
| closureDisposition | PASS_FINAL_GIT_CLOSURE_COMMIT_PUSH_COMPLETE |
| productionVaultTargetPath | C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1 |
| effectiveDate | 2026-09-12 |
| currentStatus | repository canonical / Customer Folder Merge v1 formally closed / implementation 9.1.1 / production deployed / full regression accepted / FileMaker integration compatible / no corrective required |

---

## 4. Formal Closure Authority

This repository baseline is formally closed under authority **FINAL_GIT_CLOSURE_HUMAN_GATE_20260912** with closure disposition:
`PASS_FINAL_GIT_CLOSURE_COMMIT_PUSH_COMPLETE`

Formal project closure disposition:
`PASS_CUSTOMER_FOLDER_MERGE_V1_FORMAL_PROJECT_CLOSURE_COMPLETE`

- **Production Target Path:** `C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1`
- **Binding Commit:** `b95489cf931ff1806a0580725ab13c225dd8917a`
- **Commit Parent:** `223f6fae859cf9cf1d4cf21d8b2e1a3bc472d829`
- **Canonical SHA256:** `3AFDF25C643F8820545FF169DEC411A13B990EBF8C99086F5AB7DC33EC9CB50B`
- **Canonical SizeBytes:** `333267`
- **Implementation Version:** `9.1.1`
- **Effective Date:** `2026-09-12`

---

## 5. Production Deployment & Verification Status

| Attribute | Value |
|---|---|
| gate5Status | FORMALLY_CLOSED_BY_HUMAN_AUTHORITY |
| productionDeploymentStatus | DEPLOYED |
| productionDeploymentDate | 2026-09-15 |
| productionPayloadSha256 | 3AFDF25C643F8820545FF169DEC411A13B990EBF8C99086F5AB7DC33EC9CB50B |
| productionDeploymentAuthority | Human Authority (approved performance optimization deployment) |

Production payload SHA256 at `C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1` matches the canonical SHA256 above exactly (`3AFDF25C643F8820545FF169DEC411A13B990EBF8C99086F5AB7DC33EC9CB50B`).

**Closure and deployment reconciliation:**
Following Gate 5, the performance optimization release (pre-compiled Win32 assembly loading) was deployed to the production Obsidian Vault on 2026-09-15 and verified under Human Authority. Full execution verification, FileMaker integration compatibility, and baseline guard green were achieved with zero regressions.
