# DEVELOPMENT ENTRY PROTOCOL

# NO IMPLEMENTATION WITHOUT CURRENT-SPEC RECONCILIATION

This document is the canonical development governance authority for **FM-Obsidian-Bridge**.

No implementation, bug fix, feature addition, or behavior-affecting change of any kind may occur without completing the mandatory 13-step development entry protocol below.

---

## 1. Mandatory 13-Step Development Entry Protocol

Every future behavior-affecting task MUST complete all 13 steps in strict sequence:

1. **Read `SPECIFICATION.md`**:
   Examine [`docs/current/SPECIFICATION.md`](SPECIFICATION.md) to understand current canonical externally observable behavior and safety contracts.
2. **Read `ARCHITECTURE_DESIGN.md`**:
   Examine [`docs/current/ARCHITECTURE_DESIGN.md`](ARCHITECTURE_DESIGN.md) to understand internal architecture, Win32/PInvoke mechanisms, staging ownership, durable journal, and error boundaries.
3. **Read `CURRENT_BASELINE.md`**:
   Examine [`docs/current/CURRENT_BASELINE.md`](CURRENT_BASELINE.md) and [`docs/current/current-baseline.json`](current-baseline.json) to verify current closed production baseline identity.
4. **Execute Baseline Guard**:
   Run the read-only, fail-closed baseline guard:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-CurrentBaseline.ps1
   ```
5. **If Guard Fails → STOP IMMEDIATELY**:
   If any `STOP_BASELINE_GUARD_*` status is emitted, halt all activity. Do not attempt to fix or bypass the baseline guard.
6. **Reconcile Request vs Current Specification**:
   Analyze the requested modification against the canonical specification to identify contracts affected.
7. **Classify Contract Impacts**:
   Classify all affected behavioral contracts into four explicit categories:
   - `KEEP`: Contracts that must remain unchanged.
   - `CHANGE`: Contracts whose behavior will be modified.
   - `REMOVE`: Contracts being deprecated or deleted.
   - `ADD`: New contracts being introduced.
8. **Identify Impacted Production Functions & Files**:
   Enumerate exact functions, lines, and files in production scope.
9. **Identify Impacted Tests**:
   Identify required focused test harnesses, regression tests, and fixture requirements.
10. **Identify FileMaker / Obsidian Integration Impact**:
    Evaluate impacts on FileMaker scripts (299, 307, 313), payload serialization, Base Elements transport, and Obsidian Vault topology.
11. **Produce Bounded Change Proposal**:
    Draft a bounded proposal defining scope, contract delta, test strategy, risk analysis, and verification plan.
12. **Obtain Explicit Human Authorization**:
    Present the proposal to the Human and receive explicit, unambiguous authorization.
13. **Only Then Begin Implementation**:
    Execute implementation strictly within the authorized boundaries.

---

## 2. Release Closure Protocol

When an authorized implementation is completed, follow the release closure sequence:

1. **Implementation Complete**: Code changes bounded to authorized paths only.
2. **Focused & Full Regression Verification**: Pass all focused test suites and full regression suites.
3. **Internal & Independent Review**:
   - Internal pre-review: DeepSeek (`ofox-deepseek`).
   - Formal independent review: Claude Cowork.
4. **Git Consolidation**: Stage and commit cleanly.
5. **Deployment (if authorized)**: Copy verified payload to production target with backup and verification.
6. **Current Spec Update**: Update `docs/current/SPECIFICATION.md` if observable behavior changed.
7. **Current Design Update**: Update `docs/current/ARCHITECTURE_DESIGN.md` if internal architecture changed.
8. **Current Baseline Update**: Update `docs/current/CURRENT_BASELINE.md` and `docs/current/current-baseline.json` with new SHA256, commit, and version.
9. **Baseline Guard Verification**: Confirm `tools/Test-CurrentBaseline.ps1` returns `PASS_BASELINE_GUARD_GREEN`.
10. **Freeze New Baseline**: Formally lock the new production baseline.

---

## 3. Explicit Authority Boundaries

To prevent unauthorized scope expansion and accidental drift:

- **Investigation / design authority DOES NOT imply implementation authority.**
- **Implementation authority DOES NOT imply deployment authority.**
- **Deployment authority DOES NOT imply Git remote authority.**

Each level of authority requires separate, explicit Human authorization.

---

## 4. Project Identity Rules

Always maintain strict distinction between product, feature, and internal routine:

- **Product ID:** `FM-Obsidian-Bridge`
- **Product Title:** `FM-Obsidian Bridge`
- **Feature ID:** `customer-folder-merge`
- **Feature Title:** `Customer Folder Merge`
- **Feature Version:** `1`
- **Implementation Version:** `9.1.0`
- **Internal / Legacy Routine:** `UPDATE_CUSTOMER_IDENTITY` (an internal routine / older action; never use as top-level product name).
