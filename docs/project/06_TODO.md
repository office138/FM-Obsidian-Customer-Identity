# 06_TODO

## GitHub移行トラック（Phase C-9A、2026-08-01）

- [x] C-5C1〜C-5D：GitHub向けsanitizationとrepositoryメタファイル整備。
- [x] C-5E：73件全体のsecurity／byte／Parser／回帰／Package validation。
- [x] C-6〜C-6D：Git初期化、73 filesのinitial commit `0708ce25ff073a84c9f178a1549810c91b9f605f`。
- [x] C-7〜C-7C：private repository `office138/FM-Obsidian-Customer-Identity`へinitial push、local／origin一致。
- [x] C-8：GitHub状態を文書10件へ反映し、第2commit `docs: record GitHub repository state and next steps`をpushする。
- [x] C-8S1〜C-8S2A：本番Bridge backup、内容同期、同期前ACL復元、Parser／回帰／COMPARE検証。
- [x] C-8S3：本番側既存GitへBridge 1件のみcommit。HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、clean、remote 0。
- [x] FileMaker実機：transport、NO_CHANGE、resolvedNotes参照パス更新PASS。
- [x] C-8S4：本番同期結果を許可文書だけへ反映し、第3commitとしてpushする。
- [x] C-9：Package生成・構造検証PASS後、現行HEAD自己参照要件により候補昇格停止。非正式FAIL候補は保持し、再利用しない。
- [x] C-9A：tracked文書への現行HEAD固定を廃止し、Package生成時の`PACKAGE_METADATA/package_source_state.json`動的生成方式へ移行。
- [ ] 更新後toolと新HEADを基準とする最新Project State Package作成。
- [ ] source HEAD照合を含むPackage独立検証。
- [ ] tag／Release作成判断。
- [ ] backup／TEMP／TestRoot／report、E2Eテスト顧客、旧staging／不要資産の削除判断。

本番Bridge確定値：`<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`、v8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`、GitHub版とbyte一致、同期前ACLへ復元済み。Phase C-9非正式FAIL候補は368,652 bytes、SHA256 `7D6A003BD87A132470922FF7F666DAEE4B338C7C023E214108321DC71521C8EB`で保持し再利用しない。Release、tag、新Packageは未作成。元112 fingerprintはNOT VERIFIED。

## 過去の完了・TODO履歴

以下は過去フェーズの監査履歴であり、冒頭のPhase C-8状態を上書きしない。
- JSON関数7ケース実測
- JSONNumber型コード実測
- 数値1／文字列"1"判別確認
- Write-Host混入確認
- 正常時BE_GetLastError=0確認
- FileMaker transport分割方針
- PowerShell構成方針
- requestId基本仕様
- VaultRoot基本仕様
- transport error response基本仕様
- ChatGPT一次レビュー完了
- Claude Cowork独立レビュー完了
- `ChatGPT/RESTART_CHATGPT.md` 構造修復完了
- `ChatGPT/RESTART_CHATGPT.md` 文字欠損2件修正・承認完了
- `Claude/RESTART_CLAUDE.md` 修復・承認完了
- 想定外ファイル `' + $outPath + '` の削除完了
- Snapshot新規6件の分類確定（ADD 2件／EXCLUDE 4件／HOLD 0件）
- `Project/03_DECISIONS.md` 補正・承認完了
- `Project/02_ARCHITECTURE.md` 補正・承認完了
- `Project/05_IMPLEMENTATION_PLAN.md` 補正・承認完了
- `Project/00_PROJECT_STATUS.md` 補正・承認完了
- `Project/01_NEXT_TASK.md` 補正・承認完了
- `Project/06_TODO.md` 補正完了

## 現在

- Phase 1B-3 UUID統一仕様の文書反映状況（2026-07-26時点）
  - Phase 1B-3反映・ChatGPT承認済み：
    - `Project/03_DECISIONS.md`
    - `Project/02_ARCHITECTURE.md`
    - `Project/05_IMPLEMENTATION_PLAN.md`
    - `Project/07_RISKS.md`
  - Phase 1B-3反映済み・ChatGPT承認待ち：
    - `Project/06_TODO.md`（本補正の保存により反映完了となる）
  - 伝播・最終確認待ち：
    - `ChatGPT/DECISIONS.md`
    - `Project/04_REVIEW_LOG.md`
    - 再開文書
    - `Project/00_PROJECT_STATUS.md`（最終状態反映要否をread-only確認後に判断）
    - `Project/01_NEXT_TASK.md`（次工程更新要否をread-only確認後に判断）
    - `Project/08_GIT_STATUS.md`（UUID仕様伝播要否をread-only確認後に判断。Git状態記録のみで変更不要の可能性もある）
- Snapshot物理整理：不要と判定済み（EXCLUDE対象は論理除外方式を採用）
- file_list／manifest／checksum：正式再生成・独立検証済み
- Phase 1B-3基準Package：作成・独立検証・ChatGPT承認・正式基準採用済み（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`、SHA256 `B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`、2026-07-26作成。現在は履歴基準）
- noteType実態調査後の新Package：作成済み・ユーザー正式採用済み（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78、2026-07-27）
- 実装開始ゲート：閉鎖中。詳細は「Phase 1B-3 UUID関連TODO」節および末尾「noteType内部コード化待ち」節を参照

## 次工程（依存順）

【2026-07-26現在：SUPERSEDED】本節1〜10は、Phase 1B-3文書統合完了時点（`Project/06_TODO.md`のChatGPT承認前）の次工程一覧である。Snapshot物理整理はEXCLUDE対象の論理除外方式採用により不要と判定され、file_list／manifest／checksum再生成・Phase 1B-3基準Package作成・独立検証・正式基準採用まで完了している。現在の次工程は末尾「noteType内部コード化待ち」節を参照。

1. `Project/06_TODO.md`補正結果のChatGPT承認
2. `ChatGPT/DECISIONS.md` UUID仕様伝播のread-only調査・必要なら補正
3. `Project/04_REVIEW_LOG.md` Phase 1B-3決定・補正履歴の反映
4. 再開文書の更新
5. `Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`の最終確認と必要な限定補正
6. Snapshot収録対象の物理整理
7. Snapshot／file_list／manifest／checksum再生成
8. 新Project State Package作成
9. 新Package独立検証
10. ChatGPT最終承認

本`Project/06_TODO.md`のChatGPT承認完了後に行う対象：`ChatGPT/DECISIONS.md`のUUID仕様伝播read-only調査

## Snapshot／Package状態

- Snapshot分類：ADD 2件／EXCLUDE 4件／HOLD 0件で確定済み（個別pathは `00_PROJECT_STATUS.md` 参照）
- Phase 1B-3基準Package：作成・独立検証・ChatGPT承認・正式基準採用済み（2026-07-26作成。現在は履歴基準）
- noteType実態調査後の新Package：作成済み・ユーザー正式採用済み（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78、2026-07-27。Package内部整合性確認完了）
- `package_manifest.txt` ／ `package_checksums_sha256.txt`：正式再生成・独立検証済み（2026-07-27作成の新Package作成時点のもの）
- 実装ゲート：閉鎖中

## 未決定
- `fm_managed_tags`重複値
- frontmatter内部改行混在時の最終対応
- 313番NG応答対応
- 他3端末PowerShell SHA256
- 重複4顧客の運用対応
- 実装時の詳細な内部ログ方式

- **noteType内部コード体系**（`USER_DECISION_PENDING`）: 設計書第6章5コードと現行6表示値の対応が未確定。ChatGPT推奨案Bは未採用
- **設計書第24章 Phase1関連4項目**（`USER_DECISION_PENDING`）: No.5/10/14/16は設計書推奨値のみ確認済み

## Phase 1B-3 UUID関連TODO（2026-07-26）

UUID統一仕様の基本方針は `03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節で決定済みであり、`02_ARCHITECTURE.md`／`05_IMPLEMENTATION_PLAN.md`／`07_RISKS.md`へ反映・ChatGPT承認済みである。本節は、UUID関連の残タスクを状態別に整理する。「## 未決定」節のUUID非関連項目とは区別し、重複記載しない。各項目が実装開始前必須か、後続Phase判断か、運用開始前必須かは、現時点で断定しない。

### 完了済み（設計判断）
- UUID is the Identity（UUIDを唯一のidentityとする方針）
- `SYNC_NOTE`／`MIGRATE_UUID`の分離
- UUID一致時のみ通常同期可能
- UUID欠損時の通常同期停止
- UUID不一致の自動修復禁止
- `UUID_MISMATCH`の正式採用
- `UUID_MIGRATION_REQUIRED`の正式採用
- `DUPLICATE_UUID`の狭義化
- `DUPLICATE_NOTE_TYPE`の新設
- `UUID_DUPLICATE`の不採用維持

### 文書伝播待ち
- `ChatGPT/DECISIONS.md`
- `Project/04_REVIEW_LOG.md`
- 再開文書
- `Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`は変更要否確認待ち（read-only確認後に判断し、必ず変更が必要とは断定しない）
- 本`Project/06_TODO.md`は本補正の保存により反映完了となり、ChatGPT承認待ちの状態となる

### 詳細設計待ち
- `MIGRATE_UUID` payload構造
- FileMaker側起動UI
- ユーザー確認済みフラグ形式
- response構造
- migration用エラーcode返却形式
- snapshot／journal／rollback形式・保存先・復旧手順
- index再構築運用（タイミング・専用code・自動再構築可否・通知方法）

### 実装待ち
- 現行PowerShellへのUUID検索・UUID状態判定ロジックの追加
- `DUPLICATE_UUID`／`DUPLICATE_NOTE_TYPE`／`UUID_MISMATCH`／`UUID_MIGRATION_REQUIRED`の4code実装
- migration候補・別UUID競合候補が存在する場合の新規作成禁止条件の実装
- `MIGRATE_UUID` actionの実装
- migration後の別`SYNC_NOTE`実装
- 上記実装に対するfocused test実施

### 運用・証跡待ち
- 既存4顧客のduplicate noteType整理（「## 未決定」節「重複4顧客の運用対応」と同一事項。本節では重複記載しない）
- 他3端末PowerShell SHA256実測（「## 未決定」節と同一事項）
- frontmatter内部改行混在（mixed EOL）時の最終対応（「## 未決定」節と同一事項）
- `fm_managed_tags`重複値方針（「## 未決定」節と同一事項）
- 313番NG応答対応判断（「## 未決定」節と同一事項）
- 実装時の詳細な内部ログ方式（「## 未決定」節と同一事項）

### Package待ち
【2026-07-26現在：SUPERSEDED】本節はPhase 1B-3文書統合完了時点の記録である。Snapshot物理整理は論理除外方式採用により不要と判定され、metadata再生成・Phase 1B-3基準Package作成・独立検証は完了している（詳細は`Project/00_PROJECT_STATUS.md`参照）。
- Phase 1B-3関連文書の補正・承認が完了した後、実装着手前の状態を固定するためにSnapshot収録対象の物理整理を行う
- metadata（file_list／manifest／checksum）再生成
- 新Project State Package作成
- 新Packageの独立検証
- 旧Packageは履歴として保持し、削除・上書きしない

### ゲート
- 実装開始ゲートは、実装開始前に必要と判断された詳細設計、文書伝播、データ運用方針および証跡更新がすべて完了し、ChatGPT・ユーザーが明示承認するまで閉鎖する

### `UPDATE_CUSTOMER_IDENTITY`トラック：E2E完了後の未決定事項（2026-07-31追加）

本節は、noteType体系トラック（上記各節）とは独立した並行トラック`UPDATE_CUSTOMER_IDENTITY`に関する未決定事項である。PowerShell本番反映・FileMaker実機反映・E2E一式（重複安全停止／正常系／冪等性）は完了済み（詳細は`Project/04_REVIEW_LOG.md`「`UPDATE_CUSTOMER_IDENTITY`トラック：PowerShell本番反映・FileMaker実機反映・E2E完了記録」節を参照）。

- 第1回Project State更新レビュー・Gemini独立確認：完了
- 第1回Snapshot／metadata生成：完了
- 第1回Package作成・独立検証（第1回Package技術検証PASS）：完了
- 最終クローズ6文書更新：完了
- 第1回レビュー指摘の限定修復：完了
- 追加破損の特定・修復：完了
- 06_TODO重複見出し除去：完了
- 更新済み6文書の最終read-onlyレビュー：完了
- 文書実測値・Git状態確定：完了
- Phase 6-G-3総合PASS：完了
- 正式Package採用：完了
- 本番PowerShellのローカルGit commit：完了（`435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8`、`feat: add customer identity update and resolved note sync`）
- 旧`build_package.ps1`・INVALID Package・V1 staging・未追跡旧PowerShell 3件・BOM比較生試験物の処分方針：Phase C-1.1で確定
- 旧`build_package.ps1`は旧V1用scratch版。後継は`build_package_v2.ps1`および`build_package_final.ps1`であり、現行運用・GitHub移行対象外
- Phase C-2文書更新後確認：未完了
- Phase C-3対象7件削除：未完了
- 削除後Git clean確認：未完了
- 残存資産の第二次監査：未完了
- GitHub共有体制の構築：未完了
- GitHub Releaseへの正式Package登録：未完了
- clone／再開試験：未完了

### noteType内部コード化待ち（2026-07-26追加）
- 設計書原本再取得済み（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）
- 現行6表示値（`CURRENT_OPERATIONAL_FACT`、Vault実在465件）と設計書第6章5コード（`DESIGN_V4_1`）の対応が未確定
- `client_summary`・`meeting_record`は現行実装・Vaultに存在しない
- ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）はUSER_DECISION_PENDING
- 既存465ノートの`managed_by`・`fm_note_type`未反映（いずれも0件）はresolver初期実装とは別ゲート
- Project State文書12件：本補正の反映対象
- 実装開始ゲート：CLOSED（理由：noteType体系未決定／内部コード未承認／将来予約コード未決定／第24章No.5・10・14・16未決定／設計書Version4.2改訂方針未承認）
