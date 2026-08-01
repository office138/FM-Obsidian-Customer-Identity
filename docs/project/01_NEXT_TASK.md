# 01_NEXT_TASK

**Phase 1B-3：UUID統一仕様（顧客identityの唯一の正本を`pk_CLIENT`とする設計。正本は`Project/03_DECISIONS.md`）への文書統合工程。**
Phase 1B-3主要文書（Project 6件・ChatGPT 2件）および`Claude/RESTART_CLAUDE.md`への伝播は完了している。`Project/00_PROJECT_STATUS.md`はPhase 1B-3限定補正反映・保存後再読込確認合格・ChatGPT承認済み、`Project/01_NEXT_TASK.md`はPhase 1B-3限定補正反映済み、`Project/08_GIT_STATUS.md`はread-only統合調査により変更不要と判定済みである。**実装開始：不可。**

## 前提方針（確定済み）
- 会社名・代表者名の正本はFileMaker
- 同期はFileMaker→Obsidianの一方向のみ
- Obsidian側の変更（対象フィールドに限る）はFileMakerへ戻さない
- CHECK/APPLY双方向差分同期・`recommend.winner`・競合解決は実装対象外
- 新action `SYNC_NOTE` の追加による一方向同期プロトコルを採用
- Phase 1 では現行の日本語YAML構造を維持し、外部YAMLパーサーは導入しない（PowerShell単体完結の行保持型編集）
- 307はMODE系PIPE専用として維持し、新規 `EXT-obs_内部CallPS-SYNC-NOTE` transport が文書化済みのtransport error 7コードを構造化エラー設計として担当する
- 全6 noteTypeは「同一顧客内に各1ノート」の業務仕様。条件付き自動作成候補。
- UUID重複（`DUPLICATE_UUID`）および同一noteType重複（`DUPLICATE_NOTE_TYPE`）時は警告を表示し処理を安全に中止する
- 既存BOM/改行コードを維持し、mixed 8件は frontmatter のみ LF で編集し本文 CRLF は一切変更しない

## Phase 1B-3 UUID統一仕様（要点）
- 顧客identityの唯一の正本：FileMaker `pk_CLIENT`。詳細・全文は`Project/03_DECISIONS.md`を参照（ここに複製しない）。
- 通常同期`SYNC_NOTE`とUUID移行専用action`MIGRATE_UUID`は分離する。
- 正式採用code：`UUID_MIGRATION_REQUIRED` / `UUID_MISMATCH` / `DUPLICATE_UUID` / `DUPLICATE_NOTE_TYPE`。
- 不採用code：`UNKNOWN_REQUEST_ID` / `UUID_DUPLICATE`。
- `MIGRATE_UUID`のpayload・UI・response・snapshot・journal・rollback・復旧・index再構築等の詳細は未決定であり、独断確定しない。

## 実装状態
- FileMaker実装：未着手
- PowerShell実装：未着手
- 現行PowerShellへのPhase 1B-3反映：未実装
- focused test：未実施
- 手動E2E：未実施

## 完了済み工程（Phase 1B-2）

- ChatGPT一次レビュー：完了
- Claude Cowork独立レビュー：完了
- `ChatGPT/RESTART_CHATGPT.md` 修復・承認：完了
- `Claude/RESTART_CLAUDE.md` 修復・承認：完了
- `Project/03_DECISIONS.md` 補正・承認：完了
- `Project/02_ARCHITECTURE.md` 補正・承認：完了
- `Project/05_IMPLEMENTATION_PLAN.md` 補正・承認：完了
- `Project/00_PROJECT_STATUS.md` 補正・承認：完了
- 想定外ファイル削除：完了
- Snapshot新規6件の分類確定：完了

## Snapshot／Package状態

- Snapshot新規6件の分類は**確定済み**（ADD 2件／EXCLUDE 4件／HOLD 0件。個別pathは `00_PROJECT_STATUS.md` を参照）
- Phase 1B-3基準Package：**作成・独立検証・ChatGPT承認・正式基準採用済み**（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`、SHA256 `B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`、2026-07-26作成。現在は履歴基準）
- noteType実態調査後の新Package：**作成済み・ユーザー正式採用済み**（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78、2026-07-27。Package内部整合性確認完了。noteType内部コード体系等の未決定事項自体は引き続き未決定）
- `package_manifest.txt` ／ `package_checksums_sha256.txt`：**正式再生成・独立検証済み**（2026-07-27作成の新Package作成時点のもの）
- 実装ゲート：**閉鎖中**（理由は本ファイル末尾「Phase 1B-3後」節を参照）
- 実装開始ゲート正式文言：「実装開始前に必要と判断された詳細設計、文書伝播、データ運用方針および証跡更新がすべて完了し、ChatGPT・ユーザーが明示承認するまで閉鎖する。」

## 完了済み工程（Phase 1B-3文書統合）

- `Project/06_TODO.md` の反映・承認：完了
- `Project/07_RISKS.md` の反映・承認：完了
- Project/04_REVIEW_LOG.md の反映・承認：完了
- `ChatGPT/DECISIONS.md` の反映・承認：完了
- `Project/08_GIT_STATUS.md`：read-only統合調査により変更不要と判定済み
- `Project/00_PROJECT_STATUS.md`：Phase 1B-3限定補正反映・保存後再読込確認合格・ChatGPT承認済み

## 次に行うべき1工程

noteType体系のユーザー決定（下記5項目）。決定後、Decision／Status／Restart文書への反映、保存後再読込確認、設計書Version 4.2差分作成・承認・保存の要否判断、Snapshot／metadata更新、新Project State Package作成・独立検証、限定実装ゲート再判定の順に進む。

## 現在の次回開始地点（2026-07-26改訂）

1. noteType体系のユーザー決定
2. 表示名→内部コード対応の決定
3. `client_summary`／`meeting_record`の扱い決定
4. 設計書Version 4.2改訂方針の決定（改訂しない場合は、Project文書側のみで対応する運用に切り替える）
5. 第24章No.5／10／14／16のユーザー決定

上記決定後、次の順で進める。
1. ユーザー決定
2. `Project/03_DECISIONS.md`／`ChatGPT/DECISIONS.md`／`ChatGPT/PROJECT_STATUS.md`／`ChatGPT/RESTART_CHATGPT.md`／`Claude/RESTART_CLAUDE.md`等への反映
3. 保存後再読込確認
4. 設計書Version 4.2差分作成・承認・保存（作成しない決定の場合は本工程を省略し、Project文書側のみで対応する）
5. Snapshot／metadata更新
6. 新Project State Package作成・独立検証
7. 限定実装ゲート再判定

## 実装開始のゲート条件
以下がすべて満たされるまで Phase 1 の実装コードは書かない。
- 上記設計判断および文書更新が文書上で確定・承認されていること
- ChatGPTによる実装前ゲート判定（Phase 1C/1D実装許可）で承認を得ていること
- ユーザーからの明示的な実装着手の指示があること


## 今回着手しないこと
- PowerShellスクリプトの実装変更
- FileMakerスクリプトの変更
- git add / commit / push
- 未決定事項の独断によるコード化

## 次回開始地点

1. noteType体系のユーザー決定
2. 表示名→内部コード対応の決定
3. `client_summary`／`meeting_record`の扱い決定
4. 設計書Version 4.2改訂方針の決定
5. 第24章No.5／10／14／16のユーザー決定

## Phase 1B-3後：設計書原本再取得とnoteType体系実態確認（2026-07-26、read-only）

設計書原本を再取得した（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）。noteType体系（`DESIGN_V4_1`5コード vs `CURRENT_OPERATIONAL_FACT`6表示値、Vault実在465件）は`USER_DECISION_PENDING`。ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）・第24章Phase1関連4項目（`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`）も同様。既存465ノートの`managed_by`未反映（0件）はresolver初期実装とは別ゲート。Project State文書12件は本補正の反映対象である。

**実装開始ゲート：CLOSED。** 理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認。

## 【2026-07-28追記】並行トラックの次回開始地点（本ゲートとは独立）【2026-07-31現在：SUPERSEDED、下記追記を正とする】

`UPDATE_CUSTOMER_IDENTITY`／FileMaker新規スクリプト`EXT-obs_顧客名・代表者名同期`トラックの次回開始地点は、ドラフトA（19.5.1以上版・正本）のFileMakerへの実機転記・実機検証である（2026-07-28時点）。詳細は`ChatGPT/RESTART_CHATGPT.md`第0節を正とする。

## 【2026-07-31追記】並行トラックの次回開始地点（本ゲートとは独立）

`UPDATE_CUSTOMER_IDENTITY`トラックは、PowerShell本番反映・FileMaker実機反映・重複安全停止E2E・正常系E2E・resolvedNotes自己修復確認・冪等性E2E・FileMaker PostDeploy証跡取得・最終証跡インベントリ確認・第1回Package技術検証PASS・指摘文書の限定修復・更新済み6文書の最終read-onlyレビューPASS・Git状態確定PASS・Phase 6-G-3総合PASSをすべて完了した。次回開始地点：最終Snapshot／metadata再生成→最終Package再構築→再構築後Package独立検証→ユーザー正式採用→採用後Git判断・後片付け判断。詳細は`Project/04_REVIEW_LOG.md`および`ChatGPT/RESTART_CHATGPT.md`第0節「【2026-07-31追記】」を正とする。noteType体系トラックの実装開始ゲート（CLOSED）には影響しない。
