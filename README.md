# FM-Obsidian Bridge

FileMakerを正本（Source of Truth）とし、顧客情報をFileMakerからObsidianへ片方向同期するWindows向け連携資産です。UUIDを不変識別子として完全一致検索に使用し、顧客名・代表者名・RUBY・RANKの更新、顧客フォルダ名と管理対象ノート名の常時正規化、および顧客フォルダ統合（Customer Folder Merge）を行います。

---

## Current Development Authority

The following canonical documents govern current development, feature evolutions, and engineering reasoning for **FM-Obsidian Bridge**:

- [`AGENTS.md`](AGENTS.md) — Universal agent governance entry point and rules of engagement.
- [`docs/current/README.md`](docs/current/README.md) — Current documentation navigation index.
- [`docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md`](docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md) — Mandatory 13-step development entry protocol before any code modification.
- [`docs/current/CURRENT_BASELINE.md`](docs/current/CURRENT_BASELINE.md) — Human-readable production baseline record.
- [`docs/current/current-baseline.json`](docs/current/current-baseline.json) — Machine-readable closed baseline specification.
- [`docs/current/SPECIFICATION.md`](docs/current/SPECIFICATION.md) — Canonical functional specification for Customer Folder Merge v1 (Ver 9.1.0).
- [`docs/current/ARCHITECTURE_DESIGN.md`](docs/current/ARCHITECTURE_DESIGN.md) — Canonical internal architecture and design.

**Product Identity:** `FM-Obsidian-Bridge`  
**Current Closed Feature:** `customer-folder-merge` (Customer Folder Merge v1, Ver 9.1.0)  
**Baseline Guard Command:**
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/Test-CurrentBaseline.ps1
```

> **Note on Historical Documents:**  
> Older documentation under `docs/project/`, `docs/claude/`, and `handoff/` are historical records. Current canonical behavior and safety rules are governed solely by `docs/current/`.

---

## 主要機能

- `PLAN_CUSTOMER_FOLDER_MERGE` / `APPLY_CUSTOMER_FOLDER_MERGE` (Customer Folder Merge v1)
- `UPDATE_CUSTOMER_IDENTITY` action
- UUID完全一致による対象顧客・対象ノートの識別
- YAMLの`NAME`、`CEO`、`RUBY`、`RANK`更新
- 顧客フォルダrenameと管理対象ノートrename
- 処理後の実体を`resolvedNotes`として返却
- Windows PowerShell 5.1対応

## Repository構成

```text
FM-Obsidian-Bridge-Payload.ps1   PowerShell本体（Ver: 9.1.0 - Customer Folder Merge v1）
docs/current/                    最新仕様・アーキテクチャ・Baseline・開発プロトコル
tools/                           Test-CurrentBaseline.ps1 等の検証ツール
filemaker/                       FileMakerスクリプト書き出し
tests/windows/                   Windows回帰テストと補助テスト
tests/fixtures/                  byte-sensitiveなテストfixture
docs/project/                    （過去履歴）旧設計・状態・判断・レビュー記録
docs/claude/                     （過去履歴）旧実装・調査資料
handoff/                         （過去履歴）旧再開用資料
tools/package/                   安全なPackage検証・生成ツール
```

## 前提環境

- Windows PowerShell 5.1（実行・回帰テスト確認済み）
- PowerShell 7 Parser互換（構文解析確認済み）
- FileMaker Pro 19.6.3+
- Base Elements Plug-In 5.0.0.2
- Obsidian

## 安全上の注意

- 本番Vaultをテスト対象にしない。
- 顧客実データをrepositoryへ入れない。
- `.env`、API key、token、password、secretを保存しない。
- `tests/fixtures/`のbyte状態を変更しない。
- `filemaker/`配下のBOM・改行を変更しない。
- 正式変更は development entry protocol、focused test、full regression、diff確認、独立レビューの順で検証する。

## Package検証・生成

`tools/package/build_package_final.ps1`は、引数なしではusageを表示するだけで書き込みません。`-Validate`はread-only、`-Build`を明示した場合だけ新しいZIPを作成します。既存ZIPは上書きせず、`.git`、過去ZIP、一時物、生成レポート、`PACKAGE_METADATA`のsource側実体をPackage対象から除外します。`LOCAL_EVIDENCE`は`-EvidenceRoot`を明示し、安全検査を通過した場合だけ収録されます。

Repositoryを検証する例:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File "<REPOSITORY_ROOT>\tools\package\build_package_final.ps1" `
  -Validate -RepositoryRoot "<REPOSITORY_ROOT>"
```
