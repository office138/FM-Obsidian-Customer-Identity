# CURRENT BASELINE

## 1. Governance Notices

> **This baseline describes the current repository-canonical, formally-closed source and current-documentation state.**
> 
> **This baseline does NOT assert that the canonical source has been deployed to the live Obsidian Vault.**
> 
> **Repository canonical baseline promotion and live Vault deployment are separate governance events. No Vault deployment is authorized by this baseline promotion.**
> 
> **Changes to source do not automatically update this baseline.**
>
> **Production Vault deployment status (as of 2026-09-09): DEPLOYED.** Production Vault payload deployment has been completed under explicit Human authorization, following Gate 5 closure. The production payload SHA256 matches the canonical SHA256 recorded below. See §5 for details.

---

## 2. Product Identity

- **Product ID:** `FM-Obsidian-Bridge`
- **Product Title:** `FM-Obsidian Bridge`
- **Feature ID:** `customer-folder-merge`
- **Feature Title:** `Customer Folder Merge`
- **Feature Version:** `1`
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
| implementationVersion | 9.1.0 |
| versionHeader | Ver: 9.1.0 (2026-08-29) - Customer Folder Merge v1 Implementation |
| canonicalSourcePath | FM-Obsidian-Bridge-Payload.ps1 |
| canonicalSha256 | 39F497ACEA8471CFE1CCBB4E840DC301ECCA1D1499DBB0F01C93EC1C0C0A8014 |
| canonicalSizeBytes | 265277 |
| canonicalEncoding | UTF-8 BOM |
| canonicalEol | CRLF |
| bindingCommitSha | 0a14303fc7ac1db3d4be8b092c9846bfc3bb0ec6 |
| commitParentSha | ea34609f66e7aa099f81803af20f318068d4d2e1 |
| closureAuthority | J2_STEP11_REPOSITORY_BASELINE_HUMAN_GATE_20260907 |
| closureDisposition | PASS_J2_STEP11_REPOSITORY_CANONICAL_BASELINE_PROMOTED_VAULT_DEPLOYMENT_NOT_AUTHORIZED |
| productionVaultTargetPath | C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1 |
| effectiveDate | 2026-09-07 |
| currentStatus | repository canonical / J-2 Step 11 MERGE_TARGET_FILE_EXISTS formally closed / Gate 5 formally closed by Human Authority / Production Vault payload deployment completed under explicit Human authorization (2026-09-09) |

---

## 4. Formal Closure Authority

This repository baseline is formally closed under authority **J2_STEP11_REPOSITORY_BASELINE_HUMAN_GATE_20260907** with closure disposition:
`PASS_J2_STEP11_REPOSITORY_CANONICAL_BASELINE_PROMOTED_VAULT_DEPLOYMENT_NOT_AUTHORIZED`

This closure is repository-baseline closure only. It is NOT Vault deployment authority.

The `productionVaultTargetPath` below designates the intended production deployment target path. It does NOT assert that the newly promoted repository baseline has been deployed to that location. Live Vault deployment is a separate governance event not authorized by this baseline gate.

- **Production Target Path (designated):** `C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1`
- **Binding Commit:** `0a14303fc7ac1db3d4be8b092c9846bfc3bb0ec6`
- **Canonical SHA256:** `39F497ACEA8471CFE1CCBB4E840DC301ECCA1D1499DBB0F01C93EC1C0C0A8014`
- **Implementation Version:** `9.1.0`

---

## 5. Production Deployment & Gate 5 Status

| Attribute | Value |
|---|---|
| gate5Status | FORMALLY_CLOSED_BY_HUMAN_AUTHORITY |
| productionDeploymentStatus | DEPLOYED |
| productionDeploymentDate | 2026-09-09 |
| productionPayloadSha256 | 39F497ACEA8471CFE1CCBB4E840DC301ECCA1D1499DBB0F01C93EC1C0C0A8014 |
| productionDeploymentAuthority | Human Authority (approved and completed following Gate 5 closure) |

Production payload SHA256 at `C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1` was independently re-verified this session and matches the canonical SHA256 above exactly.

**Closure basis and disclosure.** `Evidence_Gate5_FinalClosure_R2_20260908/GATE5_FINAL_R2_CORRECTIVE_ADDENDUM.md` §7 recorded Gate status as `GATE5_CLOSURE_NOT_YET_AUTHORIZED` as of 2026-09-08 23:54 JST, and named a fresh Claude Cowork / Genspark re-review as the next required step. Per Human Authority, that re-review was subsequently completed, its findings were formally adjudicated, and Gate 5 closure was explicitly approved by Human Authority; production Vault deployment was then approved and completed by Human Authority. No corresponding evidence artifact for this later sequence was independently located in this repository during this reconciliation task; this entry records the closure and deployment status as confirmed by Human Authority.
