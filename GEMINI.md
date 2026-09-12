# GEMINI.md — Gemini / Antigravity Agent Entry Instructions

## 1. Product Identity

- **Product:** `FM-Obsidian-Bridge`
- **Current Feature:** `customer-folder-merge` (Customer Folder Merge v1, Ver 9.1.1)
- **Internal / Legacy Routine:** `UPDATE_CUSTOMER_IDENTITY` (an internal routine / older action; never use as a top-level product identifier)

---

## 2. Governance Pointers

Gemini / Google Antigravity operates under the repository governance defined in:

- [`AGENTS.md`](AGENTS.md)
- [`docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md`](docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md)
- [`docs/current/CURRENT_BASELINE.md`](docs/current/CURRENT_BASELINE.md)
- [`docs/current/SPECIFICATION.md`](docs/current/SPECIFICATION.md)
- [`docs/current/ARCHITECTURE_DESIGN.md`](docs/current/ARCHITECTURE_DESIGN.md)

---

## 3. Mandatory Verification & Constraints

1. **Pre-Task Baseline Guard**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-CurrentBaseline.ps1
   ```
   If any `STOP_BASELINE_GUARD_*` status code is reported, **STOP IMMEDIATELY**.
2. **No Code Modification Before Specification Reconciliation**:
   - Complete the mandatory 13-step protocol in `DEVELOPMENT_ENTRY_PROTOCOL.md`.
   - Obtain explicit Human authorization before any behavior-affecting implementation.
3. **No Automatic Baseline Modification**:
   - Never alter `docs/current/CURRENT_BASELINE.md` or `docs/current/current-baseline.json` automatically.
4. **Role Separation**:
   - Gemini operates as orchestrator, tool router, evidence collector, filesystem/test executor, and synthesizer.
   - Engineering reasoning backend is OFOX DeepSeek (`ofox-deepseek` MCP).
   - Formal independent reviewer is Claude Cowork.
