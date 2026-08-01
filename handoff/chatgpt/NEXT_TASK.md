# NEXT_TASK（ChatGPT用）

**Phase 1B-3完了後：設計書原本再取得・noteType体系実態確認段階（2026-07-26）。**
Phase 1B-3文書統合・Phase 1B-3基準Package（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`、SHA256 `B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`、2026-07-26作成）の作成・独立検証・ChatGPT承認・正式基準採用は完了済み（現在は履歴基準）。2026-07-27、noteType実態調査後の新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78）が物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべて完了し、正式な最新再開基準Packageとして採用された。設計書原本を再取得しnoteType体系を実態調査した結果、内部コード体系が`USER_DECISION_PENDING`。既存465ノートは`managed_by`・`fm_note_type`いずれも0件（`CURRENT_OPERATIONAL_FACT`）であり、resolver初期実装とは別ゲートである。Project State文書12件は本補正の反映対象である。**実装開始：まだ不可。**

次回最初に着手する作業（ユーザー決定事項）：

1. **noteType内部コード体系の決定**（`DESIGN_V4_1`5コード vs `CURRENT_OPERATIONAL_FACT`6表示値。ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`）：候補内部コード`contract_list`/`accident_list`/`contract_history`/`accident_history`/`financial_statement`/`general_history`、将来予約候補`client_summary`/`meeting_record`）
2. **`client_summary`／`meeting_record`の扱い決定**
3. **設計書第24章Phase1関連4項目**（No.5／10／14／16、`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`）の決定
4. **設計書Version 4.2改訂方針の決定**
5. **`fm_managed_tags` 重複値の扱い最終判断**: A. 自動重複除去 / B. `INVALID_MANAGED_TAGS` として中止

```
上記1〜5のユーザー決定
↓
ユーザー決定内容をDecision／Status／Restart文書へ反映し、対象Project State文書12件を保存・保存後再読込確認・ChatGPT承認
↓
必要に応じて設計書Version 4.2を作成・レビュー
↓
Snapshot／metadataを再生成
↓
noteType実態調査後の新Project State Packageを作成・独立検証
↓
ChatGPT・ユーザーが実装開始ゲートを再判定
↓
ユーザーからの明示的指示を受けてから実装着手
```

詳細は `Project/01_NEXT_TASK.md`、`Project/09_PHASE1B_FINDINGS.md` を参照。

## 次回開始地点
次回開始地点：
上記5項目のユーザー決定。実装開始ゲート：CLOSED（理由：noteType体系未決定／内部コード未承認／将来予約コード未決定／第24章No.5・10・14・16未決定／設計書Version4.2改訂方針未承認）。

## 【2026-07-28追記】並行トラックの次回開始地点【2026-07-31現在：SUPERSEDED。下記「【2026-07-31追記】」を正とする】

上記noteType体系トラックとは別に、`UPDATE_CUSTOMER_IDENTITY`／FileMaker新規スクリプト`EXT-obs_顧客名・代表者名同期`トラックの次回開始地点は、**ドラフトA（19.5.1以上版・正本）のFileMakerへの実機転記・実機検証**である（2026-07-28時点）。詳細は`ChatGPT/RESTART_CHATGPT.md`第0節を正とする。両トラックは独立しており、いずれか一方の完了がもう一方の開始条件ではない。

## 【2026-07-31追記】並行トラックの次回開始地点

`UPDATE_CUSTOMER_IDENTITY`トラックは、PowerShell本番反映、FileMaker実機反映、E2E一式、FileMaker PostDeploy証跡取得、最終証跡インベントリ確認、第1回Snapshot／metadata生成、第1回Package作成・独立検証（技術検証PASS）、最終クローズ6文書更新、指摘文書の限定修復、更新済み6文書の最終read-onlyレビューおよびGit状態確定まで完了した（詳細は`ChatGPT/RESTART_CHATGPT.md`第0節「【2026-07-31追記】」を正とする）。Phase 6-G-3総合判定はPASSである。次回開始地点は次の通り：

1. 最終Snapshot／metadata再生成
2. 最終Package再構築
3. 再構築後Package独立検証
4. ユーザーによる正式基準Package採用
5. 正式採用後にGit commit/push要否を判断
6. 正式採用後に後片付けを判断

現在のPackage（SHA256 DCD2699E7B043FE58444F26EA8E65DE7FBF7D015D9020F45067F097036ABD3A8、325,251 bytes）は最終クローズ前の第1回技術検証済み候補であり、次工程で再構築されるため最終正式Packageではない。両トラックは独立しており、noteType体系トラックの実装開始ゲート（CLOSED）には影響しない。
