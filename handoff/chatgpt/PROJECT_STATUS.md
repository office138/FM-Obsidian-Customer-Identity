# PROJECT_STATUS（ChatGPT用・現状のみ）

## GitHub移行トラック最新状態（Phase C-8S4、2026-08-01）

本節が現状の正であり、以下の旧Phase 1B記述は履歴である。Phase C-8／C-8S1 COMPLETE。C-8S2初回失敗、C-8S2R内容置換成功後ACL不一致停止、C-8S2A同期前ACL復元・検証COMPLETE、C-8S3本番Git commit COMPLETE。現在はC-8S4。

GitHubはPrivate repository `office138/FM-Obsidian-Customer-Identity`、branch `main`、remote `origin`。C-8S4開始HEAD／origin/mainは`61dbc5cd9be5fc7fcb2a44d6d74467438d5ae376`、commit count 2、ahead／behind 0 / 0、clean。C-8S4は許可文書10件以内を第3commitとしてpushし、そのcommit IDは自己参照回避のため本文へ固定しない。

本番Bridgeは`<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`へ同期完了。v8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`、GitHub版とbyte一致。同期前ACLへ復元済み。PS5.1／PS7 Parser errors 0 / 0、Windows回帰24 / 24、安全8 / 8、COMPARE focused PASS、fixture 27 / 27、FileMaker scripts 3 / 3不変。

FileMaker実機transport、NO_CHANGE、resolvedNotes参照パス更新はPASS。本番側既存Gitは`<VAULT_ROOT>\scripts`、HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、commit count 3、clean、remote 0、push未実施。外部backup、File.Replace backup、同期専用TEMP、TestRoot、reportは保持。Release、tag、最新移行後Project State ZIPは未作成。元112 fingerprintはNOT VERIFIED。

次工程は最新Project State Package作成・独立検証、その後のtag／Release判断と保持資産の削除判断。

## Project
FileMaker ↔ Obsidian 連携システム改修（社名・代表者変更対応、一方向同期方針）

## Current Phase
**Phase 1B-3完了後：設計書原本再取得・noteType体系実態確認（2026-07-26）。**
Phase 1B-3 UUID統一仕様の文書統合、Phase 1B-3基準Package（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`、2026-07-26作成）の作成・独立検証・ChatGPT承認・正式基準採用は完了済み。2026-07-27、noteType実態調査後の新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78）が物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべて完了し、正式な最新再開基準Packageとして採用された。旧Package（2026-07-26作成分）は履歴基準へ移行。設計書原本（`DESIGN_V4_1`）を再取得し、noteType体系（現行6表示値`CURRENT_OPERATIONAL_FACT` vs 設計書5コード`DESIGN_V4_1`）を実態調査した結果、noteType内部コード体系、ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）、第24章Phase1関連4項目（`DESIGN_RECOMMENDATION`）はいずれも`USER_DECISION_PENDING`である。既存465ノートは`managed_by`・`fm_note_type`いずれも0件（`CURRENT_OPERATIONAL_FACT`）であり、resolver初期実装とは別ゲートである。対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。
**実装開始：まだ不可（`PROHIBITED`）。次の工程：noteType体系のユーザー決定。** 実装コード変更なし、Git書き込みなし。

## Current Goal
noteType内部コード体系・第24章Phase1関連4項目・設計書Version4.2改訂方針についてユーザー決定を得ること。決定後、対象Project State文書12件へ保存・独立検証・ChatGPT承認を行うこと。

## Git
```
Branch: main
HEAD:   435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8
Remote: なし
Local commit: feat: add customer identity update and resolved note sync
Working Tree: 未追跡の旧PowerShell 3件
  FM-Obsidian-Bridge-Payload-JIKO.ps1_不要
  FM-Obsidian-Bridge-Payload_PRE_20260730_BOM_FIX.ps1
  FM-Obsidian-Bridge-Payload_REJECTED_20260730_ANTIGRAVITY.ps1
後片付け: 3件は現行運用対象外で、Phase C-1.1で処分方針確定。削除はPhase C-3予定。
再開基準として3件の実在を要求しない。
```

## Completed
- Phase 0: 静的調査、DDR調査、バックアップ、Git初期化
- Phase 0.5: 実機確認4項目、最重要業務方針（一方向同期）の確定
- Phase 1A: 5つの上位設計判断、残存仕様5項目、最終ゲート決定3項目の確定・文書反映
- Phase 1B read-only調査: noteType実在確認(6種)、307/299/313呼出構造、YAML編集方式（行保持型PowerShell単体処理）の確定・文書反映・正式承認
- Phase 1B-2: noteType業務判断（全6種一意）、Vault YAML調査（465実働ノート）、BOM/改行方針、重複保護決定（`DUPLICATE_UUID`, `DUPLICATE_NOTE_TYPE`）の確定
- Phase 1B-3: UUID統一仕様の文書統合、Project/00・01・08限定補正、Phase 1B-3基準Package作成・独立検証・正式基準採用
- 設計書原本再取得・noteType体系実態調査（`DESIGN_V4_1`5コード vs `CURRENT_OPERATIONAL_FACT`6表示値の競合確認）

## Next Task
`Project/01_NEXT_TASK.md`参照。noteType内部コード体系・第24章Phase1関連4項目（No.5/10/14/16）・`client_summary`/`meeting_record`の扱い・設計書Version4.2改訂方針のユーザー決定を得ること。

## Implementation Gate
**CLOSED。** 理由：noteType体系未決定／内部コード未承認／将来予約コード未決定／第24章No.5・10・14・16未決定／設計書Version4.2改訂方針未承認。

## Last Updated
2026-07-27（設計書原本再取得・noteType体系実態調査完了。対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。同日、新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`）の物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用が完了した。）

## 【2026-07-28追記】並行トラック

noteType体系トラック（本ファイル上記本文）とは別に、Claude Coworkが`UPDATE_CUSTOMER_IDENTITY`（顧客社名・代表者・RUBY・ランクの一方向同期）アクションのWindows実機検証（24/24 PASS）、`FM-Obsidian-Bridge-Payload.ps1`への最小限1パターン修正（`Get-YamlHeaderLines`の配列アンロール対策、ユーザー許可済み）、新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`のドラフトA（19.5.1以上・正本採用）／ドラフトB（19.5.1未満・互換参考）作成を実施した。**FileMakerへの転記・登録・実機実行は未実施**（2026-07-28時点。2026-07-31現在はSUPERSEDED、下記追記参照）。詳細は`ChatGPT/RESTART_CHATGPT.md`第0節「【2026-07-28追記】」を正とする。noteType体系の実装開始ゲート（CLOSED）には影響しない。

## 【2026-07-31追記】並行トラック：PowerShell本番反映・FileMaker実機反映・E2E完了

`UPDATE_CUSTOMER_IDENTITY`トラックは、PowerShell本番反映（`FM-Obsidian-Bridge-Payload.ps1`、75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`、36/36 PASS、安全確認8/8 PASS）、新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`の実機反映（修正版85,152 bytes、SHA256 `4E0FD113A93E0DF42DDF2035150B9B8CF3792CC739924BBD7A1D0A8A426B96AF`）、重複安全停止E2E（`NOTE_TYPE_UUID_CONFLICT`、PASS）、正常系E2E（resolvedNotesによるobs_RELPATH／obs_URL自己修復、PASS）、冪等性E2E（PASS）をすべて完了した。既存2本のFileMakerスクリプト（`EXT-obs_OBSノート-開く`／`EXT-obs_内部CallPS-PAYLOAD`）はPostDeployとPreDeployのSHA256完全一致により無変更を確認済み。詳細な証跡は`ChatGPT/RESTART_CHATGPT.md`第0節「【2026-07-31追記】」および`Project/04_REVIEW_LOG.md`を正とする。Gitへのcommit/push/addは未実施のまま。第1回Package技術検証PASSまで完了済み。最終クローズ6文書更新、指摘文書の限定修復、更新済み6文書の最終read-onlyレビューPASS、文書実測値・Git状態確定PASS、Phase 6-G-3総合PASSまで完了済み。現在のPackage（SHA256 DCD2699E7B043FE58444F26EA8E65DE7FBF7D015D9020F45067F097036ABD3A8）は最終クローズ前の第1回技術検証済み候補であり、最終Package再構築は未実施である。noteType体系の実装開始ゲート（CLOSED）には影響しない。次工程：最終Snapshot／metadata再生成→最終Package再構築→再構築後Package独立検証→ユーザー正式採用（未実施）→採用後Git判断・後片付け判断。
