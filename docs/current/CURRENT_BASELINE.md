# CURRENT BASELINE

## 1. Governance Notices

> **This baseline describes the current repository-canonical, formally-closed source and current-documentation state.**
> 
> **Product Version:** `9.2.0`
> **Feature:** `search-performance` (Search Performance Optimization Tier 0/1)
> **Effective Date:** `2026-09-19`
> **Production Vault Deployment Status:** `DEPLOYED`
> **Formal Project Closure Disposition:** `PASS_SEARCH_PERFORMANCE_TIER01_FORMAL_PROJECT_CLOSURE_COMPLETE`

---

## 2. Product Identity

- **Product ID:** `FM-Obsidian-Bridge`
- **Product Title:** `FM-Obsidian Bridge`
- **Feature ID:** `search-performance`
- **Feature Title:** `Search Performance Optimization Tier 0/1`
- **Feature Version:** `1`
- **Implementation Version:** `9.2.0`
- **Internal / Legacy Routine:** `UPDATE_CUSTOMER_IDENTITY` (an internal routine / older action; never use as a top-level product identifier)

---

## 3. Baseline Attributes

| Attribute | Value |
|---|---|
| productId | FM-Obsidian-Bridge |
| productTitle | FM-Obsidian Bridge |
| featureId | search-performance |
| featureTitle | Search Performance Optimization Tier 0/1 |
| featureVersion | 1 |
| implementationVersion | 9.2.0 |
| versionHeader | Ver: 9.2.0 (2026-09-18) - Search Performance Tier 0/1 |
| canonicalSourcePath | FM-Obsidian-Bridge-Payload.ps1 |
| canonicalSha256 | 44E69132113F8766C62B30DC7711C8CE854FC62B483985FFBAFA8221FD1B5D8E |
| canonicalSizeBytes | 340230 |
| canonicalEncoding | UTF-8 BOM |
| canonicalEol | CRLF |
| bindingCommitSha | c7c6dc3fcc8f83cee9345d2e0a40da3801c00793 |
| commitParentSha | e56682d0a439b820a4a0be202f0303496a41252f |
| closureAuthority | FINAL_GIT_CLOSURE_HUMAN_GATE_20260919 |
| closureDisposition | PASS_FINAL_GIT_CLOSURE_COMMIT_PUSH_COMPLETE |
| productionVaultTargetPath | C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1 |
| effectiveDate | 2026-09-19 |
| currentStatus | repository canonical / Search Performance Tier 0/1 formally closed / implementation 9.2.0 / production deployed / full regression accepted / FileMaker integration compatible / no corrective required |

---

## 4. Formal Closure Authority

This repository baseline is formally closed under authority **FINAL_GIT_CLOSURE_HUMAN_GATE_20260919** with closure disposition:
`PASS_FINAL_GIT_CLOSURE_COMMIT_PUSH_COMPLETE`

Formal project closure disposition:
`PASS_SEARCH_PERFORMANCE_TIER01_FORMAL_PROJECT_CLOSURE_COMPLETE`

---

## 5. Production Deployment & Verification Status

| Attribute | Value |
|---|---|
| gate5Status | FORMALLY_CLOSED_BY_HUMAN_AUTHORITY |
| productionDeploymentStatus | DEPLOYED |
| productionDeploymentDate | 2026-09-19 |
| productionPayloadSha256 | 44E69132113F8766C62B30DC7711C8CE854FC62B483985FFBAFA8221FD1B5D8E |
| productionDeploymentAuthority | Human Authority (approved search performance optimization deployment) |

Production payload SHA256 at `C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1` matches the canonical SHA256 above exactly (`44E69132113F8766C62B30DC7711C8CE854FC62B483985FFBAFA8221FD1B5D8E`).

**Closure and deployment reconciliation:**
Following Tier 0 / Tier 1 search performance optimization, the release was deployed to the production Obsidian Vault on 2026-09-19 and verified under Human Authority. Full execution verification, FileMaker integration compatibility, and baseline guard green were achieved with zero regressions (10.1x speedup on production host).
