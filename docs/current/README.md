# Current Baseline Documentation — Navigation

This directory (`docs/current/`) contains the canonical, authoritative specifications, architecture designs, baseline records, and governance protocols for **FM-Obsidian-Bridge**.

---

## Quick Navigation

| Question | Answer |
|---|---|
| **What is current?** | **Product:** `FM-Obsidian-Bridge`<br>**Feature:** `customer-folder-merge` (Customer Folder Merge v1)<br>**Version:** `9.1.1` (closed baseline: `2026-09-12`) |
| **Which file should I read first?** | [`DEVELOPMENT_ENTRY_PROTOCOL.md`](DEVELOPMENT_ENTRY_PROTOCOL.md) |
| **What must be done before code changes?** | Complete the mandatory 13-step development entry protocol and obtain explicit Human authorization. |
| **Where are historical documents?** | Legacy directories (`docs/project/`, `docs/claude/`, `handoff/`) are historical reference materials only. Current canonical state is governed solely by `docs/current/`. |
| **What is the baseline guard command?** | `powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-CurrentBaseline.ps1` |

---

## Recommended Reading Order

1. [`DEVELOPMENT_ENTRY_PROTOCOL.md`](DEVELOPMENT_ENTRY_PROTOCOL.md) — Mandatory governance protocol and rules of engagement.
2. [`SPECIFICATION.md`](SPECIFICATION.md) — Canonical functional specification for Customer Folder Merge v1 (Ver 9.1.1).
3. [`ARCHITECTURE_DESIGN.md`](ARCHITECTURE_DESIGN.md) — Canonical internal architecture and design.
4. [`CURRENT_BASELINE.md`](CURRENT_BASELINE.md) — Human-readable production baseline record.
5. [`current-baseline.json`](current-baseline.json) — Machine-readable production baseline record.
