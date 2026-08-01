# 00_PROJECT_STATUS

## GitHub移行トラック最新状態（Phase C-9C、2026-08-01）

本節が現状の正であり、以下のPhase C-9A以前の状態記述は履歴として扱う。Phase C-9A／C-9BはCOMPLETE。自己参照問題は`PACKAGE_METADATA/package_source_state.json`方式で解消し、現在はPhase C-9C。

最新正式Project State Packageは`FM-Obsidian-Customer-Identity_20260801_1638_PRODUCTION_SYNC_VERIFIED_RESTART.zip`、376,266 bytes、SHA256 `7F1A25F892A716FFD688B8C2A945EA5A803C46F24332F781E9F2CA0D7CB0888C`、entries 78（payload 74／generated metadata 4）、FORMALLY_ADOPTED: YES。Package source HEAD／origin/mainは`0cde9fe982f028259a142a914e2fd9cd85d91166`、commit count 4、clean、tracked files 74。Build・独立検証・manifest 74 / 74・checksums 74 / 74・payload 74 / 74 byte・Parser・ZIP validationはPASSし、既知のPackage問題はない。C-9C後の現行HEADはGitで確認し、Package source HEADと混同しない。

直前正式Packageは過去正式証跡として保持。`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`は非正式FAIL候補であり、正式再開基準として使用しない。本番Bridge、本番Git、FileMaker、回帰状態は不変。Releaseとtagは未作成。

次工程はPhase C-10 GitHub tag／Release準備。推奨候補はtag `v8.3.1-production-sync-verified`、Release title `v8.3.1 — Production Sync Verified`だが未確定。Package source HEADとC-9C後HEADのどちらをtag対象にするかは次工程で明示判断する。

## GitHub移行トラック最新状態（Phase C-9A、2026-08-01）

本節が現状の正であり、以下の旧Project／Current Phase／Git節は履歴として扱う。Phase C-8S4までCOMPLETE。Phase C-9はPackage生成・構造検証PASS後、tracked文書へ自身の現行commit IDを固定する自己参照要件により候補昇格を停止した。現在はPhase C-9A。

GitHubはPrivate repository `office138/FM-Obsidian-Customer-Identity`、branch `main`。tracked文書へPackage生成時の現行HEADを固定しない。source repository stateは生成時だけ`PACKAGE_METADATA/package_source_state.json`へ動的記録し、既存3 metadataと同じ自己参照除外集合として扱う。Package自身の最終Size／SHA256はPackage外部で管理する。

本番Bridgeは`<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`へ同期完了。v8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`、GitHub版とbyte一致。UTF-8 BOMあり、CRLF 1,453、末尾改行なし。同期前ACLへ復元済み、Attributes Archive、ADS追加0。

PS5.1／PS7 Parser errors 0 / 0、Windows回帰24 / 24、安全確認8 / 8、COMPARE focused PASS、fixture 27 / 27、FileMaker scripts 3 / 3不変。FileMaker実機transport、NO_CHANGE、resolvedNotes参照パス更新PASS、エラーなし、FileMaker変更不要。

本番側既存Gitは`<VAULT_ROOT>\scripts`、HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、subject `fix: resolve Python safely for compare mode`、commit count 3、clean、remote 0、push未実施。外部backup、File.Replace backup、同期専用TEMP、TestRoot、reportは保持。

Phase C-9非正式FAIL候補`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`（368,652 bytes、SHA256 `7D6A003BD87A132470922FF7F666DAEE4B338C7C023E214108321DC71521C8EB`）は保持し、編集・再利用・正式採用しない。次工程は更新後toolと新HEADを基準とする新Package作成・source-state独立検証、その後のtag／Release判断と保持資産の削除判断。Release、tag、新Packageは未作成。元112 fingerprintはNOT VERIFIED。

## Project
FileMaker ↔ Obsidian 連携システム改修プロジェクト（社名・代表者変更対応、確定設計書 第4回修正版・改訂2 準拠）

## Current Phase
**Phase 1B-3完了後：設計書原本再取得・noteType体系実態確認（2026-07-26）。**
UUID統一仕様（顧客identityの唯一の正本を`pk_CLIENT`とする設計。正本は`Project/03_DECISIONS.md`）は設計決定済みであり、Phase 1B-3主要文書（Project 6件・ChatGPT 2件）および`Claude/RESTART_CLAUDE.md`への伝播は完了している。Project/00・01・08のPhase 1B-3変更要否read-only統合調査は完了しており、`Project/00_PROJECT_STATUS.md`はPhase 1B-3限定補正反映済み、`Project/01_NEXT_TASK.md`はPhase 1B-3限定補正反映済み、`Project/08_GIT_STATUS.md`はread-only統合調査により変更不要と判定済みである。Phase 1B-3基準Package（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`、SHA256 `B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`）は作成・独立検証・ChatGPT承認・正式基準採用済みである。その後、設計書原本（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）を再取得しnoteType体系を実態調査した結果、内部コード体系・第24章Phase1関連4項目が`USER_DECISION_PENDING`であることが判明した。
**実装開始：不可（`PROHIBITED`）。** 実装コード変更なし、Git書き込みなし。【過去状態】Phase 1B-2（SYNC_NOTE transport設計・JSON実機確認・PowerShell構成確定、2026-07-25完了）の詳細は本ファイル「## 現在のフェーズと状態」を参照。

## Current Goal
noteType内部コード体系、設計書第24章Phase1関連4項目（No.5／10／14／16）、ChatGPT推奨案Bおよび将来予約候補（`client_summary`／`meeting_record`）の扱い、設計書Version 4.2改訂方針についてユーザー・ChatGPTの決定を得ること。決定後、対象Project State文書12件へ反映・保存・独立検証・ChatGPT承認を行い、metadata更新・新Project State Package作成・独立検証を経て実装開始前ゲート判定へ進むこと。


## Git
```
リポジトリ： <REPOSITORY_ROOT>
Branch:      main
HEAD:        435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8
Remote:      なし
本番PowerShellのローカルcommit: 完了
Commit:      435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8
Commit message: feat: add customer identity update and resolved note sync
Working Tree: 未追跡の旧PowerShell 3件（現行運用対象外）
  FM-Obsidian-Bridge-Payload-JIKO.ps1_不要
  FM-Obsidian-Bridge-Payload_PRE_20260730_BOM_FIX.ps1
  FM-Obsidian-Bridge-Payload_REJECTED_20260730_ANTIGRAVITY.ps1
後片付け: Phase C-1.1で処分方針確定、削除実行前。再開基準として3件の存在を要求しない。
```

## Historical Project Status

以下は過去フェーズの監査履歴であり、冒頭のPhase C-8状態を上書きしない。

### Phase 0（完了）
Step 0-1〜0-4：静的調査・DDR調査・バックアップ作成・初回ベースラインcommit。詳細は`04_REVIEW_LOG.md`。

### Phase 0.5（完了）
実機確認4項目（端末特定運用、RANK1LYear正本、Base Elements 5.0.0.2、313番$result取得後処理）およびユーザーによる最重要業務方針（FileMaker→Obsidian一方向同期）の確定完了。

### Phase 1A（完了、2026-07-23）
上位設計判断5項目、残存仕様5項目、最終ゲート決定3項目のすべてが確定し文書反映完了。新action `SYNC_NOTE` 追加、現行YAML構造維持、tags差分更新、protocolVersion/requestId導入、エラーコード体系が決定。なお307実行層エラー対応の旧最小改修案は、**Phase 1B-4で置換・不採用**となり、「既存307はCHECK／COMPARE／APPLY専用PIPE transportとして変更せず維持し、新規 `EXT-obs_内部CallPS-SYNC-NOTE` がSYNC_NOTE専用JSON transportを担当する」方針へ置換された。

### Phase 1B read-only調査（完了・承認、2026-07-24）
Google Antigravityが調査3項目および補正報告を実施し、ChatGPTがレビュー・正式承認した。
1. **noteType別挙動**: DDR上の実在noteTypeは6種類（契約一覧/事故一覧/契約/事故/決算書/その他）。現行コード上は全6種で自動作成経路があるが、業務上の自動作成可否は未決定。暫定安全側codeとして `NOTE_NOT_FOUND` を採用。
2. **呼出構造**: 299 → 307 → PS（通常）、313 → 307 → PS（突合）。313は299を経由しない。現行307では、PowerShell起動失敗等の実行層エラー時に生ダイアログ・実行コマンド全文が露出し、空resultとなる問題が実証された。この問題の解決手段は307の改修ではなく、新規 `EXT-obs_内部CallPS-SYNC-NOTE` transport による最小5キーJSON error responseである。既存307は今回変更しない。
3. **YAML処理**: 現行 `Update-Yaml-Robust` は文字列ベースであり、`tags:` 丸ごと置換、キー順序再生成、インラインコメント消去等の制限がある。Phase 1 では外部パーサーを導入せず、PowerShell単体完結の行保持型編集を採用し、未対応構文（`INVALID_YAML` / `INVALID_MANAGED_TAGS`）は更新前に安全に中止する方針が確定した。

### Phase 1B-2 実装前設計判断（主要方針確定、2026-07-24）
Google AntigravityによるVault YAML走査（956件走査）およびユーザー確認・Claude独立補正レビューを経て以下を確定：
1. **全6 noteTypeの業務上一意性**: 契約一覧/事故一覧/契約/事故/決算書/その他の全6種は「同一顧客内に各1ノート」を業務仕様として確定。安全条件を満たす場合に限り条件付き自動作成候補とする。
2. **顧客名変更の判定原則**: `pk_CLIENT` UUIDで判定。名前変更時も既存顧客として処理し、新規ノートは追加作成しない。UUID検索を優先。
3. **重複保護決定**: UUID重複時は `DUPLICATE_UUID`、同一noteType重複時（Vault実態4顧客で存在確認）は `DUPLICATE_NOTE_TYPE` で警告表示・処理中止（自動選択/統合/修正/上書き禁止）。
4. **BOM・改行コード維持方針**: 既存BOM/改行を維持し、mixed 8件（frontmatter:LF, 本文:CRLF）は frontmatter のみ LF で編集し本文 CRLF は不変更。新規は UTF-8 BOMなし・LF。
5. **YAML境界規則**: 第1行 `---` から直後の単独行 `---` を一意なfrontmatter終了境界とする。本文中の `---` はfrontmatter境界として扱わない（本文中 `---` 存在 257件）。`tags:` 直後値なし形式（9件）は空タグとして扱う。
6. **JSON関数の実機確認と型判別**: FileMaker Pro 19.6.3 にて JSONString=1, JSONNumber=2 等を実測確定。型判定には必ず `JSONGetElementType` を使用する。
7. **Base Elements挙動**: `Write-Host` は戻り値に混入する。正常時 `BE_GetLastError = 0`。
8. **SYNC_NOTE transport設計**: 既存307はMODE系専用に維持し、SYNC_NOTE専用の `EXT-obs_内部CallPS-SYNC-NOTE` を新規作成する（新規transportがJSON固定応答を担当する）。
9. **PowerShell構成**: 既存 `FM-Obsidian-Bridge-Payload.ps1` に SYNC_NOTE 早期分岐を追加する。専用PowerShellファイルへ分割しない。

### Phase 1B-3 UUID統一仕様への文書統合（2026-07-26）
顧客identityの唯一の正本をFileMakerの`pk_CLIENT`（`Get(UUID)`によるRFC 4122形式UUID）へ一本化する設計が確定した。正式仕様は`Project/03_DECISIONS.md`を正本とし、本書では要点のみ記載する。
1. **identity**: 唯一の正本は`pk_CLIENT`。顧客名・会社名・代表者名・folderName・relpath・フォルダパス・Markdownファイル名・Obsidianノート名・index上の名称情報はidentityとして扱わない。
2. **action分離**: 通常同期`SYNC_NOTE`とUUID移行専用action`MIGRATE_UUID`は分離する。`MIGRATE_UUID`のpayload構造・FileMaker側起動UI・ユーザー確認フラグ形式・response構造・snapshot／journal／rollback形式・保存先・復旧手順・index再構築タイミング等の詳細は未決定であり、実装開始前に確定が必要（独断確定しない）。
3. **response code**: 正式採用は`UUID_MIGRATION_REQUIRED`（UUID欠損managed candidate検出時）、`UUID_MISMATCH`（異なる非空UUID candidate検出時）、`DUPLICATE_UUID`（同一受信UUIDへ複数ノートが一致する場合の狭義code）、`DUPLICATE_NOTE_TYPE`（同一顧客UUID・同一noteType重複時）。不採用は`UNKNOWN_REQUEST_ID`・`UUID_DUPLICATE`。既存OK／NG系codeの後方互換は維持する。
4. **文書伝播**: Phase 1B-3主要文書（Project 6件：`03_DECISIONS.md`／`02_ARCHITECTURE.md`／`05_IMPLEMENTATION_PLAN.md`／`07_RISKS.md`／`06_TODO.md`／`04_REVIEW_LOG.md`、ChatGPT 2件：`DECISIONS.md`／`RESTART_CHATGPT.md`）は反映・承認済み。`Claude/RESTART_CLAUDE.md`は再開文書として個別承認済み。
5. **00・01・08の確認**: Project/00・01・08のPhase 1B-3変更要否read-only統合調査は完了。`Project/00_PROJECT_STATUS.md`：Phase 1B-3限定補正反映済み。`Project/01_NEXT_TASK.md`：当時はPhase 1B-3限定補正未実施【2026-07-26現在：SUPERSEDED。後続工程で反映済み】。`Project/08_GIT_STATUS.md`：read-only統合調査により変更不要と判定済み。

## Next Task
`01_NEXT_TASK.md`を参照。Phase 1B-3として、`01_NEXT_TASK.md`のPhase 1B-3限定補正案を作成すること（ChatGPT・ユーザーの承認および明示的な保存許可を得た後、1ファイルずつ保存）。【過去状態】307構造化エラー仕様の確定（2026-07-25完了・確定済み）およびProject文書（03/02/05/07/06/04）反映結果の承認（2026-07-26完了・確定済み）。

## Blockers & Pending Gates
1. **`fm_managed_tags` 重複値の扱い**: A. 自動重複除去 / B. `INVALID_MANAGED_TAGS` として中止（現時点の安全側候補はB）。
2. **4顧客の同一noteType重複ノートの運用事前整理**: Vault実態として存在する4顧客の重複ノートの事前手動整理・運用対応の決定。
3. **Project State文書12件のnoteType体系関連状態反映**: 対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。次はSnapshot／metadataへの再反映、新Project State Package作成・独立検証へ進む。
4. **他3端末のPowerShell同一性**: 未実測の運用前提（<WINDOWS_HOST>端末のSHA256と同一前提）として進行中。
5. **`MIGRATE_UUID`詳細設計**: payload構造・起動UI・ユーザー確認フラグ形式・response構造・snapshot／journal／rollback形式・保存先・復旧手順・index再構築タイミング等は未決定（`Project/03_DECISIONS.md`参照）。
6. **noteType内部コード体系**（`USER_DECISION_PENDING`）: 設計書第6章5コード（`DESIGN_V4_1`）と現行6表示値（`CURRENT_OPERATIONAL_FACT`、Vault実在465件）が競合。ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）は未採用。
7. **設計書第24章 Phase1関連4項目**（`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`）: No.5（推奨A）／No.10（推奨B）／No.14（推奨B）／No.16（推奨B）。
8. **既存Vaultノートの`managed_by`未反映**: 現行465ノートは`managed_by`・`fm_note_type`いずれも0件。resolver初期実装とは別ゲート。

## Last Updated
2026-07-27（Project/00・01・08のPhase 1B-3限定補正完了、Phase 1B-3基準Package作成・独立検証・正式基準採用完了、設計書原本再取得・noteType体系実態調査完了。対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。詳細は「## 現在のフェーズと状態」を参照）


## 現在のフェーズと状態

### Phase 1B-2（完了・過去履歴、2026-07-24〜2026-07-25）
noteType業務判断：完了
Vault YAML調査：完了
Claude YAML独立補正レビュー：完了
Project文書反映：完了
文書反映後Claudeレビュー：完了
スクリプト307構造化エラー調査：完了
Claude 307独立補正レビュー：完了
ChatGPTによる307補正後承認：完了
SYNC_NOTE transport設計・JSON実機確認：完了
PowerShell構成方針確定：完了
ChatGPT一次レビュー：完了
Claude Cowork独立レビュー：完了
RESTART_CHATGPT.md 構造修復（閉じフェンス）：完了
RESTART_CHATGPT.md 文字欠損2件修正：完了
RESTART_CLAUDE.md 修復：完了
想定外ファイル削除：完了
Snapshot新規6件の分類：完了
Project/03_DECISIONS.md 承認：完了
Project/02_ARCHITECTURE.md 承認：完了
Project/05_IMPLEMENTATION_PLAN.md 承認：完了

実装コード変更：なし
FileMaker変更：なし
PowerShell変更：なし
DDR原本変更：なし
Vault実ノート変更：なし
Git書込み：なし

Snapshot新規6件の分類：確定済み
  ADD：Snapshot/baseelements_stdout_runtime_results.txt
  ADD：Snapshot/filemaker_json_runtime_results.txt
  EXCLUDE：Snapshot/phase1b2_document_review_extract.txt
  EXCLUDE：Snapshot/restart_chatgpt_postfix_review.txt
  EXCLUDE：Snapshot/restart_claude_postfix_review.txt
  EXCLUDE：Snapshot/sync_note_transport_design.txt
  HOLD：0件

### Phase 1B-3（現在、2026-07-26）
Project/00・01・08のPhase 1B-3変更要否read-only統合調査：完了
Project/00_PROJECT_STATUS.md：Phase 1B-3限定補正反映済み
Project/01_NEXT_TASK.md：Phase 1B-3限定補正反映済み
Project/08_GIT_STATUS.md：read-only統合調査により変更不要と判定済み
UUID統一仕様（`Project/03_DECISIONS.md`正本）：設計決定済み
Phase 1B-3主要文書（Project 6件・ChatGPT 2件）への伝播：完了
Claude/RESTART_CLAUDE.md：反映・承認済み
Snapshot分類（ADD 2／EXCLUDE 4／HOLD 0）：確定済み（内容は上記Phase 1B-2参照）
Snapshot物理整理：不要と判定済み（EXCLUDE対象は論理除外方式を採用、物理移動なし）
file_list／manifest／checksum：Phase 1B-3基準Package作成時点で正式再生成・独立検証済み
Phase 1B-3基準Package：作成・独立検証・ChatGPT承認・正式基準採用済み（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`、SHA256 `B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`、2026-07-26作成。2026-07-27、下記の新Package正式採用に伴い履歴基準へ移行）
noteType実態調査後の新Package：作成済み・ユーザー正式採用済み（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78、2026-07-27）
FileMaker実装：未着手
PowerShell実装：未着手
現行PowerShellへのPhase 1B-3反映：未実装
focused test：未実施
手動E2E：未実施
実装開始ゲート：閉鎖中
実装開始ゲート正式文言：「実装開始前に必要と判断された詳細設計、文書伝播、データ運用方針および証跡更新がすべて完了し、ChatGPT・ユーザーが明示承認するまで閉鎖する。」

### Phase 1B-3後：設計書原本再取得とnoteType体系実態確認（2026-07-26、read-only）
設計書原本を再取得した（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`、Size 116,623 bytes、独立検証済み）。
noteType体系のread-only実態調査（`CURRENT_OPERATIONAL_FACT`）により、設計書第6章5コード（`DESIGN_V4_1`：`contract_list`/`accident_list`/`financial_statement`/`client_summary`/`meeting_record`）と現行6表示値（契約一覧/事故一覧/契約/事故/決算書/その他、Vault実在465件）が競合することを確認した。`client_summary`・`meeting_record`に相当するノートは現行実装・Vaultに存在しない。ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）は`USER_DECISION_PENDING`であり採用済みではない。設計書第24章Phase1関連4項目（No.5・No.10・No.14・No.16）も同様に`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`。既存465ノートの`managed_by`・`fm_note_type`未反映（いずれも0件）はresolver初期実装とは別ゲート。
対象Project State文書12件（本ファイルを含む）への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。同日、Snapshot／metadata再生成および新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`）の作成・Package内部整合性確認・ユーザー正式採用も完了した。

**Packageと現在文書の二層状態（2026-07-27追記）**：正式Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`）は2026-07-27 13:40時点の再開用スナップショットである。Package正式採用後にProject State文書12件のうち9件が更新されたため、現在ディスク上のProject State文書が論理的な最新状態である。Package内文書と現在ディスク上の文書に差異があること自体は既知かつ正常な二層状態であり、Package内文書を現在ディスク文書より新しいものとして扱ってはならない。再開時の参照優先順位は次のとおりである（これは、複数のProject State文書間でどれを正本として扱うかという既存の文書間優先順位とは別軸であり、両者は併存する。文書間優先順位はどの現在ディスク文書を正本として扱うかを定め、本項はPackageスナップショットと現在ディスク文書のどちらを新しいものとして扱うかを定める）。

1. 現在ディスク上のProject State文書
2. 正式Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`）
3. Package作成時点以前の履歴資料（旧Package等）

**実装開始：PROHIBITED。実装開始ゲート：CLOSED。** 理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認。

実装開始：不可

### 【2026-07-28追記】並行トラック：`UPDATE_CUSTOMER_IDENTITY`（本ゲートとは独立）

上記noteType体系の実装開始ゲート（CLOSED）とは別に、Claude Coworkが`UPDATE_CUSTOMER_IDENTITY`アクション（顧客社名・代表者・RUBY・ランクのFileMaker→Obsidian一方向同期）についてWindows PowerShell 5.1実機検証（24/24 PASS、安全確認8/8 PASS）を完了し、`FM-Obsidian-Bridge-Payload.ps1`へユーザー許可済みの最小限1パターン修正（`Get-YamlHeaderLines`の配列アンロール対策）を適用済みである。新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`のドラフトA（19.5.1以上・正本）／ドラフトB（互換参考）も作成済みだが、この時点では**FileMakerへの転記・登録・実機実行は未実施**であった。【2026-07-31時点：本トラックはPowerShell本番反映・FileMaker実機反映・E2E一式が完了している。現在状態は下記「### 【2026-07-31追記】」を正とする。】詳細は`ChatGPT/RESTART_CHATGPT.md`第0節、`Claude/RESTART_CLAUDE.md`第0節を正とする。本項はnoteType体系の実装開始ゲート判定に影響しない。

### 【2026-07-31追記】`UPDATE_CUSTOMER_IDENTITY`トラック：PowerShell本番反映・FileMaker実機反映・E2E完了

本トラックはnoteType体系の実装開始ゲート（CLOSED）とは独立のまま、以下がすべて完了した（read-onlyでの実測・確認に基づく確定事実）。

- **PowerShell本番反映**：`<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1`、75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`。正式採用・本番反映済み。自動テスト36/36 PASS、安全確認8/8 PASS。
- **FileMaker実機反映**：`EXT-obs_顧客名・代表者名同期`スクリプトの内容を、修正版（不正な二重End If構造を除去した正式版）`Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\FileMaker\EXT-obs_顧客名・代表者名同期_AFTER_CORRECTED_20260731.txt`（85,152 bytes、SHA256 `4E0FD113A93E0DF42DDF2035150B9B8CF3792CC739924BBD7A1D0A8A426B96AF`）へ反映済み。構造：XML解析PASS、トップレベルStep 462、If/End If 82/82、Loop/End Loop 2/2、Step内Step入れ子0。
- **FileMaker PostDeploy証跡**（`Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\FileMaker\PostDeploy`）：
  - `EXT-obs_顧客名・代表者名同期_AFTER_REAL.txt`（85,307 bytes、SHA256 `1758B536A811C6DFDF5EAD19EF11F3DBC20FE5E7F0993B0B7A4E4A1DB5D7EFC9`）。反映元とのバイト差は改行・FileMaker再書き出し表現差のみで、意味的同一性PASS。
  - `EXT-obs_OBSノート-開く_AFTER_REAL.txt`（37,091 bytes、SHA256 `BDEDF8D4992B8966A60EE6F773287539C0E1962B10D035E0E58B1BC6DC5DF223`）。PreDeployとSHA256完全一致。今回の反映作業による変更なし。
  - `EXT-obs_内部CallPS-PAYLOAD_AFTER_REAL.txt`（9,610 bytes、SHA256 `23A5645200DA9566244F6882EC82FDFB25E4A7E88E00B68CD1EFAF65816E5FC8`）。PreDeployとSHA256完全一致。今回の反映作業による変更なし。
- **重複安全停止E2E（PASS）**：同一UUID・同一noteType「契約」のMarkdownが2件（UUID付き正式ノート／UUIDなし旧ノート）存在する事前状態で実行し、`NOTE_TYPE_UUID_CONFLICT`としてFileMakerで既知エラー表示・書き込み前に安全停止。Vault内ファイル数・ファイル名・サイズ・SHA256は不変、新規Markdownなし、obs_RELPATH／obs_URLは旧値のまま。
- **正常系E2E（PASS）**：UUIDなし旧ノートをVault外（`Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\E2EQuarantine\2250BA49_PRE_NORMAL_E2E`、SHA256 `F7E82164E56A0EC33257D8D6A538863ACCF235360C4C2781E1C1D447D088F656`）へ隔離した状態で「契約」ノートを開く操作を実施。エラーダイアログなし、UUID付き正式ノートが開き、新規Markdownなし、対象UUID一致Markdownは1件。`obs_RELPATH`／`obs_URL`はUUID付き正式パス（`01_顧客/【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後_[2250BA49]/🟨契約_【E2Eテスト_削除予定】FMOBS検証_20260729_変更後_[2250BA49].md`）へ自己修復し、resolvedNotesによる既存正式ノート特定・重複ノード再生成なしを確認した。
- **正式ノートの改行正規化**：E2E前238 bytes（LF、SHA256 `FF271EDF2CFC1B4CCAEA6B692B802D158D9D5AB41292BA85C8C27A8DA1F5269C`）→E2E後250 bytes（CRLF、SHA256 `69B49D8F920F0FA215BE7A36FA73CBB266C46AE59A6FECA56E87D828702A21C0`）。差分は12個のLF→CRLFによる+12 bytesのみで、YAML値・tags・UUID・本文文字内容は不変。Windows PowerShell 5.1での既知・許容される改行正規化と判定。
- **冪等性E2E（PASS）**：正規化済み状態で同一操作を再実行。エラーダイアログなし、同じUUID付き正式ノートが開き、obs_RELPATH／obs_URL不変、Markdown件数1件、旧ファイル名再作成なし、正式ノートサイズ250 bytes・SHA256 `69B49D8F920F0FA215BE7A36FA73CBB266C46AE59A6FECA56E87D828702A21C0`不変。
- **最終証跡インベントリ確認**：PreDeploy／PostDeploy／E2EBackup／E2EQuarantine配下の各ファイルのサイズ・SHA256が上記記載値と一致することを確認済み。

**次工程**：最終Snapshot／metadata再生成→最終Package再構築→再構築後Package独立検証→ユーザーによる正式基準Package採用→正式採用後にGit commit/push要否と後片付けを判断。更新済み6文書の最終read-onlyレビューPASS、文書実測値とGit状態の再確認PASS、Phase 6-G-3総合PASSを確認済み。現在のPackage（SHA256 DCD2699E7B043FE58444F26EA8E65DE7FBF7D015D9020F45067F097036ABD3A8）は最終クローズ前の第1回技術検証済み候補であり、次工程で再構築される。本トラックは引き続きnoteType体系の実装開始ゲート（CLOSED）とは別軸であり、当該ゲート判定に影響しない。
