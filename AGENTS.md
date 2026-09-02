# AGENTS.md — Universal Agent Governance

## 1. Product Identity

- **Product:** `FM-Obsidian-Bridge`
- **Current Feature:** `customer-folder-merge` (Customer Folder Merge v1, Ver 9.1.0)
- **Internal / Legacy Routine:** `UPDATE_CUSTOMER_IDENTITY` (an internal routine / older action; never use as a top-level product identifier)

---

## 2. Mandatory Rules of Engagement

Any AI agent (Google Antigravity, Claude, Gemini, ChatGPT, or any other automation tooling) operating within this repository MUST strictly comply with the following governance rules before performing any task:

1. **Read Canonical Governance First**:
   - [`docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md`](docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md)
   - [`docs/current/CURRENT_BASELINE.md`](docs/current/CURRENT_BASELINE.md)
   - [`docs/current/SPECIFICATION.md`](docs/current/SPECIFICATION.md)
   - [`docs/current/ARCHITECTURE_DESIGN.md`](docs/current/ARCHITECTURE_DESIGN.md)
2. **Execute Baseline Guard**:
   - Run the fail-closed baseline guard before any behavior-affecting task:
     ```powershell
     powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-CurrentBaseline.ps1
     ```
   - If the baseline guard reports any `STOP_BASELINE_GUARD_*` status code, **STOP IMMEDIATELY**.
   - Do not attempt to bypass, weaken, or auto-repair the baseline guard.
3. **Strict Authority Boundaries**:
   - **Investigation / design authority DOES NOT imply implementation authority.**
   - **Implementation authority DOES NOT imply deployment authority.**
   - **Deployment authority DOES NOT imply Git remote authority.**
4. **No Automatic Baseline Mutation**:
   - Never modify `docs/current/CURRENT_BASELINE.md` or `docs/current/current-baseline.json` automatically without explicit Human authorization.
5. **Historical Documentation Status**:
   - All materials under `docs/project/`, `docs/claude/`, and `handoff/` are historical records. Current canonical behavior is governed solely by `docs/current/`.
