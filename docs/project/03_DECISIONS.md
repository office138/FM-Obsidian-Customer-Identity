# 03_DECISIONS

採用済みの設計判断・運用判断のみを記載する（検討中のものは含めない）。

## 採用済み（Phase 0時点）

| 決定事項 | 内容 | 理由 |
|---|---|---|
| UUID優先 | 顧客の唯一の識別キーはFileMakerの`pk_CLIENT`（`Get(UUID)`、RFC 4122形式）とする | ファイル名・フォルダ名・会社名に依存しない安定識別のため |
| Gitはscriptsフォルダのみ管理対象 | `C:\...\scripts` 配下のみをGitリポジトリ化。Vault全体・顧客データは除外 | 顧客の機微情報をGit履歴に残さないため |
| .gitignoreの除外方針 | バックアップ拡張子、Python生成物、破損/競合index、実行時生成JSON、一時ファイル、quickadd/旧スクリプト/ を除外 | ソースコードと実行時データ/バックアップを分離するため |
| managed_by固定値 | `"filemaker_obsidian_bridge"` に統一 | 既存ノートとの後方互換性維持のため |
| 状態コード後方互換 | 既存のaction/statusコードは削除・改名せず、新規コードのみ追加する方針 | FileMaker側の分岐ロジックを破壊しないため |

## 採用済み（Phase 0.5で新規確定、決定日：2026-07-22、決定者：ユーザー）

| 決定事項 | 内容 | 決定根拠 |
|---|---|---|
| 会社名・代表者名の正本 | FileMakerを正本とする | データの入力・管理の主業務がFileMaker側で行われているため |
| 同期方向 | FileMaker → Obsidianの一方向のみ | Obsidian側は閲覧・自由記述用途であり、FileMakerへの書き戻しは不要 |
| Obsidian側変更の扱い | 会社名・カナ・代表者名・カナ・RANK・managed_byはFileMaker値を正本として同期する。本文・履歴欄は保持する。UUIDは、通常`SYNC_NOTE`ではUUID一致時の同一値再記録だけを許可し、UUID欠損ノートへの初回記録は専用`MIGRATE_UUID`の条件を満たす場合だけ許可する。UUID不一致の自動上書き・自動修復は禁止する（詳細は「Phase 1B-3 UUID統一仕様確定」節を正とする） | 一方向同期方針およびUUID is the Identity原則に基づく |
| CHECK/APPLY双方向同期は実装対象外 | `recommend.winner`・`diffs[]`を用いた双方向更新判断・競合解決の実装は行わない | 一方向同期のみで業務要件を満たすため |
| RANK1LYearの同期仕様 | Obsidianへ同期する正本として`RANK1LYear`（昨年度基準）を継続使用する | 実機確認（Phase 0.5）。業務上RANK1LYearが同期対象と確定 |
| z_sysClientPCのhostname自動判別運用 | 現行運用を有効と認める（4端末：<WINDOWS_HOST>／DELL138／PRPDESK600／dynabook） | 実機確認（Phase 0.5） |
| Base Elements Plug-Inのバージョン | 正式名称「Base Elements Plug-In」、バージョン5.0.0.2を全端末で使用する前提 | 実機確認（Phase 0.5） |
| 他3端末のPowerShell同一性 | 「未確認の運用前提」として明記した上で、同一内容前提で進行する | ユーザー判断（1端末のみSHA256実測済み） |

## 採用済み（ChatGPTアーキテクチャレビュー反映、決定日：2026-07-22）

| 決定事項 | 内容 | 決定根拠 |
|---|---|---|
| Phase 1着手順序 | プロトコル定義（1A）最優先、1B UUID検索 → 1C 移行・互換 → 1D YAML更新 → 1E rename → 1F 代表者変更 → 1G バックアップ → 1H FM統合 | プロトコル仕様を最優先で確定するため |
| UUIDとrenameの責務分離 | ①UUID一致検索→②一意特定→③現在名称比較→④rename計画→⑤競合確認→⑥バックアップ→⑦rename→⑧YAML更新→⑨結果検証の順 | 名前起点の処理順による誤更新防止 |
| UUID状態別の扱い【Phase 1B-3で仕様置換】 | UUID欠損＝移行候補、UUID一致＝更新可能、UUID不一致／重複／名前一致だがUUID不一致＝エラー停止 | 乗っ取り防止のため。現行codeと処理条件はPhase 1B-3統一仕様へ置換し、UUID欠損は`UUID_MIGRATION_REQUIRED`、UUID不一致は`UUID_MISMATCH`、UUID重複は`DUPLICATE_UUID`として分離する |
| renameの疑似トランザクション | manifest→競合確認→バックアップ→一時名称→rename→YAML更新→リンク更新→検証→ロールバック | 部分更新の成功扱いを防止 |

## 採用済み（5つの設計判断確定、決定日：2026-07-23、ユーザー・ChatGPT）

| # | 決定事項 | 内容 | 決定根拠 |
|---|---|---|---|
| ① | 一方向同期方式 | 新action `SYNC_NOTE` を追加して実装。既存CHECK/APPLY経路は初期移行段階では維持。**307の実行層エラー最小改修は【Phase 1B-4で置換・不採用】**（本文書末尾「旧307最小改修案の降格記録」参照。現行は307を変更せず、新規 `EXT-obs_内部CallPS-SYNC-NOTE` が担当する） | 307の中継構造維持とロールバック容易性確保のため |
| ② | YAML構造 | Phase 1では現行の日本語キー構造（`tags:`/`UUID:`/`ランク:`/`総合計保険料:`）を維持し全面移行は行わない | 段階移行とリスク軽減を優先するため |
| ③ | tags更新方式 | `tags:` 丸ごと置換を禁止。FileMaker管理タグのみ差分更新しユーザー独自タグを保持（`更新後tags = 既存tags - 既存fm_managed_tags + 今回管理タグ`） | ユーザー独自タグ消失防止のため |
| ④ | protocolVersion・requestId | 両方を導入（初期値 `protocolVersion=1`、`requestId` 呼出元生成） | 冪等性・トレーサビリティ確保のため |
| ⑤ | エラーコード・表示マトリクス | 成功/入力不正/UUID整合性/競合/書込み補償/実行障害系へ整理・採用 | 障害詳細と一般ユーザーメッセージの分離のため |

## 採用済み（Phase 1A残存仕様5項目確定、決定日：2026-07-23、ユーザー・ChatGPT）

| # | 決定事項 | 内容 |
|---|---|---|
| 残存① | 追加YAMLキー名 | `managed_by: filemaker_obsidian_bridge` と `fm_managed_tags` の2つに限定。`protocol_version` はYAML非保存 |
| 残存② | 既存タグ初回移行方式 | `fm_managed_tags` 欠損時は既存タグを削除せず追加分のみ記録し warning `LEGACY_TAG_OWNERSHIP_UNKNOWN` を返却 |
| 残存③ | response互換方針 | `SYNC_NOTE` ＝ JSON形式のみ、既存action ＝ パイプ区切り維持。**呼出元299が、処理種別に応じて既存307または新規SYNC_NOTE transportのどちらを呼ぶかを決定する。transport側でPIPE／JSONを自動判別しない。**（299の実装変更内容は本項では確定しない） |
| 残存④ | `FILE_NOT_FOUND` の意味分離 | `SYNC_NOTE` では使用せず、`CREATED` / `NOTE_NOT_FOUND` / `FOLDER_CONFIRM_REQUIRED` / `FOLDER_NOT_FOUND` へ分離 |
| 残存⑤ | warning体系 | Phase 1 で正式採用する warning は `LEGACY_TAG_OWNERSHIP_UNKNOWN` のみ |

## 採用済み（Phase 1A最終ゲート決定、決定日：2026-07-23、ユーザー・ChatGPT）

| # | 決定事項 | 内容 |
|---|---|---|
| ゲート① | `fm_managed_tags` 破損時 | `status=NG` / `code=INVALID_MANAGED_TAGS`（YAML解析不能時は `INVALID_YAML`）。自動修復せず実更新前に中止 |
| ゲート② | 307の実行層エラー対応**【Phase 1B-4で置換・不採用】** | （旧案）307 は実行層エラー4種（一時ファイル書込み失敗・PS起動失敗・標準出力なし・`BE_GetLastError`検出）に限り構造化結果（`POWERSHELL_LAUNCH_FAILED`等）を返す最小改修対象とする。**現行：307はCHECK／COMPARE／APPLY用PIPE transportとして変更せず維持し、新規 `EXT-obs_内部CallPS-SYNC-NOTE` がSYNC_NOTE用JSON transportを担当する（1B-4／1B2-8参照）** |
| ゲート③ | noteTypeごとの作成可否 | Phase 1B 調査対象とし、調査完了までは自動作成せず `NOTE_NOT_FOUND` を安全側デフォルトとする |

## 採用済み（Phase 1B確定事項、決定日：2026-07-24、ユーザー・ChatGPT承認）

| # | 決定事項 | 内容 | 決定根拠 |
|---|---|---|---|
| 1B-1 | noteType実在確認と呼出構造 | DDR上実在するnoteTypeは `契約一覧`, `事故一覧`, `契約`, `事故`, `決算書`, `その他` の6種。呼出構造は 299 → 307 → PS（通常）、313 → 307 → PS（突合）。313 は 299 を経由しない | Phase 1B read-only調査で確認 |
| 1B-2 | YAML編集方式 | Phase 1 では外部 YAML パーサーを導入せず、PowerShell 単体で完結する行保持型 frontmatter 編集（方式A拡張）を採用する | 4端末環境への展開容易性・外部依存なしを最優先とするため |
| 1B-3 | 未対応YAML構文の扱い | 閉じていない frontmatter、非先頭 frontmatter、重複キー、複雑な入れ子、`fm_managed_tags` 型不正等は更新前（`Update-Yaml-Robust` 冒頭）に検知し `INVALID_YAML` または `INVALID_MANAGED_TAGS` で即時中止する | ファイル破損・誤生成防止のため |
| 1B-4 | 307の責務分離と新規SYNC_NOTE transport | 307はCHECK／COMPARE／APPLY専用のPIPE response固定。新規 `EXT-obs_内部CallPS-SYNC-NOTE` がpayloadからrequestIdを参照・正規化し、transport自身の入力・書込・起動・不正responseエラー等のみ構造化 JSON（`POWERSHELL_LAUNCH_FAILED` 等）返却。業務エラーの意味は解析しない | エラー・Vaultパスの一重化・露出防止のため |

## 採用済み（Phase 1B-2確定事項、決定日：2026-07-24、ユーザー・ChatGPT・Claude）

| # | 決定事項 | 内容 | 決定根拠 |
|---|---|---|---|
| 1B2-1 | 全6 noteTypeの業務上一意性 | 契約一覧/事故一覧/契約/事故/決算書/その他の全6種は「同一顧客内に各1ノート」を業務仕様とする。安全条件を満たす場合に限り条件付き自動作成候補とする | ユーザー確認（業務仕様確定） |
| 1B2-2 | 顧客名変更の判定原則 | 顧客の同一性は `pk_CLIENT` UUIDで判定する。顧客名変更時は既存顧客として処理し、新規ノートは追加作成しない。UUID検索を名前・フォルダ検索より優先する | 確定原則に基づく |
| 1B2-3 | UUID重複時の保護 | UUID一致ノートが複数存在する場合、警告メッセージを表示し `DUPLICATE_UUID` で処理中止する。自動選択・自動統合・自動修正・自動上書きは行わない。技術情報は表示しない | 誤更新・データ破壊防止のため |
| 1B2-4 | 同一noteType重複時の保護 | 同一顧客・同一noteTypeの候補が複数存在する場合、警告メッセージを表示し `DUPLICATE_NOTE_TYPE` で処理中止する。自動選択・自動統合・自動上書きは行わない。**`DUPLICATE_NOTE_TYPE` の判定はUUID照合を先行させ、名前検索のみで判定しない** | Vault実態（4顧客で重複存在）への安全対策 |
| 1B2-5 | BOM・改行コード維持方針 | 既存ファイルはBOM有無を検出して維持し、frontmatter内の改行コードを維持する。本文の改行コードは変更しない（mixed 8件はfrontmatterのみLF編集）。新規ファイルは UTF-8 BOMなし・LF | 本文非改変原則およびVault実態調査に基づく |
| 1B2-6 | frontmatter境界規則 | ファイル第1行の内容が厳密に `---` と一致する場合のみ開始境界とし、第2行以降で最初に現れる単独行 `---` を終了境界とする（本文中の後続 `---` は境界として扱わない） | Vault実態調査（257件で本文中 `---` 存在）に基づく |
| 1B2-7 | `tags` 値なしの扱い | `tags:` 直後に値がなく次の同階層キーまたはfrontmatter終了へ移る形式に限り、既存タグ集合が空である状態として扱う（`INVALID_YAML` にはしない）。`tags: null` / `tags: ""` / `tags: 0` / `tags: {}` はこれと同一扱いにせず、未対応または不正型候補とする | Vault実態調査（値なし9件確認）に基づく |


## 採用済み（Phase 1B-2 transport設計確定、決定日：2026-07-25、ユーザー）

| # | 決定事項 | 内容 | 決定根拠 |
|---|---|---|---|
| 1B2-8 | 既存307と新規SYNC_NOTE分割 | 既存307(`EXT-obs_内部CallPS-PAYLOAD`)はMODE専用として維持し、SYNC_NOTE専用の `EXT-obs_内部CallPS-SYNC-NOTE` を新規作成する | response形式自動判別やenvelope判別の複雑化を避けるため |
| 1B2-9 | transport参照キーとVaultRoot仕様 | transportがtransport用途で参照するのは `VaultRoot` と `requestId` のみ。その他はPowerShellへpayload全体として素通しする。`VaultRoot` は必須・`JSONString`・Trim後に非空であること。欠落／JSON null／空String／非JSONStringは `MISSING_REQUIRED_FIELD`。検証はPowerShellスクリプトパスおよび一時ファイルパスの構築前に行う。一般responseへ絶対パスを含めない。**これはFileMaker transportの入力検証であり、PowerShell側の業務処理用VaultRoot検証（`Test-Path` による実在確認）とは別層である** | transport層の責務を最小化し、誤誘導的なcode返却を防ぐため |
| 1B2-10| JSON型判別とpayloadルート検証 | JSONString=1, JSONNumber=2, JSONObject=3, JSONArray=4, JSONNull=6。型判定は `JSONGetElementType` 必須。payloadはルートがJSONObject(=3)であることを検証する | 19.6.3実機確認結果。数値1と文字列"1"を区別するため |
| 1B2-11| requestId仕様 | 呼出元で生成し、transportは生成しない。欠落／JSON null／空JSONStringはresponseで JSON null とする。非空JSONStringはその値を伝播する。JSONString以外の型は `INVALID_PAYLOAD`。PowerShell responseの `requestId` は正規化済み送信値と一致必須で、不一致は `INVALID_POWERSHELL_RESPONSE`。requestIdを一時ファイル名へ使用しない | 冪等性・追跡性の確保、およびパストラバーサル防止のため |
| 1B2-12| transportエラーresponse | JSON固定。BEエラーコード等の技術情報やスタックトレースを含めない | 一般利用者への技術情報露出を防ぐため |
| 1B2-13| PowerShell構成方針 | 既存 `FM-Obsidian-Bridge-Payload.ps1` にSYNC_NOTE早期分岐を追加（専用ps1に分割しない） | 正規化処理等の重複を避けるため |
| 1B2-14| BE_ExecuteSystemCommand仕様 | Write-Host出力は戻り値へ混入する。正常実行時BE_GetLastErrorは0 | Base Elements実機確認結果 |
| 1B2-15| 一時ファイルとcleanup責務 | ファイル名は `_syncnote_<FileMaker内部UUID>.tmp`（suffixは `.tmp`）。requestIdをファイル名へ使用せず、FileMaker内部UUIDにより同時実行衝突を回避する。payloadにはPIIが含まれ得る。**正常経路ではPowerShellがpayload読込直後に削除する。PowerShellスクリプト未存在・書込失敗後の残存・起動失敗等では、FileMaker側がファイルが存在する場合に限り削除を試行する。** cleanupの失敗で主エラーを上書きしない。cleanup失敗の内部技術情報を一般responseへ含めない | 孤児化・PII滞留の防止および主エラー隠蔽の防止のため。`.gitignore` の `*.tmp` により管理外となるため新規規則は不要 |

## 採用済み（Phase 1B-3 UUID統一仕様確定、決定日：2026-07-26、ユーザー・ChatGPT）

| # | 決定事項 | 内容 | 決定根拠 |
|---|---|---|---|
| 1B3-1 | action分離 | 通常同期`SYNC_NOTE`とUUID移行`MIGRATE_UUID`を独立したactionとして分離する。`MIGRATE_UUID`は通常同期から独立した明示操作とし、FileMaker側からの明示的起動、対象ノート相対パスの明示、ユーザー確認済みフラグを最低条件とする | 通常同期経路からリスクの高い移行処理を隔離するため |
| 1B3-2 | SYNC_NOTEの識別原則 | `SYNC_NOTE`はUUID一致ノートだけを通常更新可能とする。UUID欠損ノートへの自動UUID付与、UUID不一致の自動修復は行わない。名前・社名・folderName・relpath・ファイル名はidentityとして使用せず、migration候補検出またはユーザー選択対象の指定にのみ使用できる | UUID is the Identity原則を実装レベルで担保するため |
| 1B3-3 | UUID一致時の処理 | 受信UUIDと一致する管理対象ノートが1件の場合、通常同期可能とする。UUIDは同じ値の再記録を許可する | UUID変更と同一値再記録を区別するため |
| 1B3-4 | UUID欠損時の処理 | UUID欠損の既存管理対象ノート候補が存在する場合、`SYNC_NOTE`は停止し`UUID_MIGRATION_REQUIRED`を返す。通常同期内でUUIDを自動付与しない | 誤紐付け防止のため |
| 1B3-5 | UUID不一致時の処理 | 候補ノートに受信値と異なる非空UUIDが存在する場合、処理を停止し`UUID_MISMATCH`を返す。UUIDをFileMaker値で自動上書きしない | 顧客identityの乗っ取り防止のため |
| 1B3-6 | UUID重複時の処理 | 受信UUIDと一致する管理対象ノートが複数存在する場合、処理を停止し`DUPLICATE_UUID`を返す。`DUPLICATE_UUID`は複数ノートが同一UUIDに一致するケース専用とし、UUID不一致へ流用しない | code意味衝突と誤更新を防止するため |
| 1B3-7 | noteType重複時の処理 | 同一顧客UUIDかつ同一noteTypeの管理対象ノートが複数存在する場合、処理を停止し`DUPLICATE_NOTE_TYPE`を返す | Vault実態への安全対策 |
| 1B3-8 | 新規ノート作成条件 | UUID一致ノートなし、UUID欠損のmigration候補なし、別UUIDの競合候補なし、duplicate UUIDなし、duplicate noteTypeなしの全条件を満たす場合だけ新規ノートを作成できる | migration候補を無視した重複ノート作成を防止するため |
| 1B3-9 | MIGRATE_UUIDの最低条件 | 対象ノート相対パスを明示し、対象ノートのUUIDが欠損していること、既存UUIDがある場合は停止すること、同一受信UUIDを持つ別ノートが存在しないこと、対象noteTypeが一意であること、`managed_by: filemaker_obsidian_bridge`であること、ユーザー確認済みフラグがあること、migration前にsnapshotまたはjournalを作成することを必須とする。migrationではUUIDの初回記録だけを行い、業務項目同期は別の`SYNC_NOTE`で実行する | 移行処理の安全性、明示性および追跡性を確保するため |
| 1B3-10 | code正式採用 | 過去案・未採用だった`UUID_MISMATCH`を正式採用へ変更する。`UUID_MIGRATION_REQUIRED`を新規正式採用する。`UUID_DUPLICATE`は引き続き不採用とする | UUID状態ごとの結果を一意に識別するため |

本節は、Phase 0.5の「Obsidian側変更の扱い」およびChatGPTアーキテクチャレビュー反映の「UUID状態別の扱い」に関する従来記述を置換する。既存記述は意思決定履歴として保持し、現行仕様は本節を正とする。

## 未決定・要確認（決定事項ではない）


- **`fm_managed_tags` 重複値の扱い**: A. 自動重複除去 / B. `INVALID_MANAGED_TAGS` として中止（現時点の安全側候補はB）
- **frontmatter内部改行混在の扱い**: `INVALID_YAML` とするか専用codeを設計するか
- **313番のNG応答対応方針**: 313 での 307 エラー受信時のダイアログ表示要否
- **他3端末のPowerShell SHA256実測**: 未実測の運用前提を確証事実へ格上げするための実測
- **4顧客の同一noteType重複の運用整理（未決定・独断確定しない）**: Vault実態として存在する4顧客の重複ノートへの対応方針。次の3案を未決定として残す。A. 実装開始前に手動整理 / B. `DUPLICATE_NOTE_TYPE` 停止機能を先に実装 / C. 実装と運用整理を並行。「事前整理必須」とは確定していない
- **`MIGRATE_UUID`詳細仕様**:
  - payload構造
  - FileMaker側の起動UI
  - ユーザー確認済みフラグの形式
  - migration前snapshot／journalの形式・保存先・復旧手順
  - response構造およびエラーcodeの返却形式

- **noteType内部コード体系**（2026-07-26追加、`USER_DECISION_PENDING`）: 現行6表示値（契約一覧/事故一覧/契約/事故/決算書/その他、Vault実在465件）の実在と業務区別は`CURRENT_OPERATIONAL_FACT`として確認済み（本項目はこの確認済み事実を変更しない）。設計書第6章5コード（`DESIGN_V4_1`：`contract_list`/`accident_list`/`financial_statement`/`client_summary`/`meeting_record`）との対応・正式な内部コード体系は未決定であり、両者は明確に別レイヤーである。
- **ChatGPT推奨案B**（`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`）: 候補内部コード`contract_list`/`accident_list`/`contract_history`/`accident_history`/`financial_statement`/`general_history`。将来予約候補`client_summary`/`meeting_record`。採用済みではない。
- **設計書第24章 Phase1関連4項目**（`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`）: No.5（index自動検証間隔、推奨A）・No.10（tags/aliases大小文字方針、推奨B）・No.14（protocolVersion更新方針、推奨B）・No.16（pk_CLIENT UUID形式、推奨B）。
- **設計書Version 4.2作成方針**（`USER_DECISION_PENDING`）: noteType内部コード決定後、設計書自体を改訂（Version 4.2）するか、Project文書側のみで対応するかは未決定。
- **既存Vaultノートの`managed_by`未反映**（`CURRENT_OPERATIONAL_FACT`）: 現行465ノートは`managed_by`・`fm_note_type`いずれも0件。設計書Version 4.1のYAML_MIGRATE自動条件を大半または全件が満たしていない。resolver初期実装とは別ゲート。


## transport構造化エラー方針（307はPIPE専用、新規SYNC_NOTE transportがJSON担当）
- **現行呼出**: 299 → 307 → PowerShell, 313 → 307 → PowerShell (313は299を経由せず)
- **要求キー**: MODE (CHECK, COMPARE, APPLY)。SYNC_NOTE, requestId, protocolVersion は未実装。
- **307の責務**: CHECK／COMPARE／APPLY専用のPIPE response固定。JSON responseを返さない。requestIdを参照・生成・検証しない。
- **requestId**: 呼出元で生成。欠落／JSON null／空JSONStringはresponseでJSON null。非空JSONStringは伝播し、JSONString以外は `INVALID_PAYLOAD`。新規transportはrequestIdを生成しない。responseのrequestIdは正規化済み送信値と一致必須で、不一致は `INVALID_POWERSHELL_RESPONSE`。
- **transport自身が生成するcode**: `INVALID_PAYLOAD` / `MISSING_REQUIRED_FIELD` / `PAYLOAD_FILE_WRITE_FAILED` / `POWERSHELL_SCRIPT_NOT_FOUND` / `POWERSHELL_LAUNCH_FAILED` / `EMPTY_POWERSHELL_RESPONSE` / `INVALID_POWERSHELL_RESPONSE`
- **責務境界**: 新規transportは業務responseの意味を解析せず、requestId一致およびresponse最小形状だけを検証する。
- **protocolVersion**: SYNC_NOTEで必須。`JSONNumber` の `1` だけを許可し、`JSONString` の `"1"` は不正型とする。欠落は `MISSING_REQUIRED_FIELD`。型または値の不一致は `UNSUPPORTED_PROTOCOL_VERSION`（PowerShell側が生成）。FileMaker transport自身のerror responseでは `protocolVersion` を `JSONNumber` の `1` に固定する。
- **エラーcodeの生成層（混同禁止）**:
  - **FileMaker transport自身が生成する7コード**: `INVALID_PAYLOAD` / `MISSING_REQUIRED_FIELD` / `PAYLOAD_FILE_WRITE_FAILED` / `POWERSHELL_SCRIPT_NOT_FOUND` / `POWERSHELL_LAUNCH_FAILED` / `EMPTY_POWERSHELL_RESPONSE` / `INVALID_POWERSHELL_RESPONSE`
  - **PowerShell側が生成する2コード**: `UNSUPPORTED_ACTION` / `UNSUPPORTED_PROTOCOL_VERSION`
  - **業務・YAML・ノート判定系code（Phase 1B-3時点で正式採用）**: `INVALID_YAML` / `INVALID_MANAGED_TAGS` / `NOTE_NOT_FOUND` / `DUPLICATE_UUID` / `DUPLICATE_NOTE_TYPE` / `UUID_MISMATCH`（過去案・未採用から正式採用へ変更） / `UUID_MIGRATION_REQUIRED`（新規正式採用）。適用条件は「Phase 1B-3 UUID統一仕様確定」節を正とする
  - **引き続き不採用**: `UNKNOWN_REQUEST_ID` / `UUID_DUPLICATE`
  - FileMaker transportの7コードとPowerShellの2コードを混同しない。
  - PowerShellから返った有効responseに含まれる業務codeを、FileMaker transportは再解釈しない。
  - FileMaker transportが `INVALID_POWERSHELL_RESPONSE` とするのは、response形状検証に失敗した場合だけとする。
- **transport error response 最小契約**: 必須キーは `protocolVersion` / `requestId` / `status` / `code` / `userMessage` の5件のみ。`status` は `OK` または `NG`。`code` は非空の `JSONString`。`userMessage` は `JSONString`（非空必須とするかは未決定であり本項では確定しない）。`requestId` は `JSONString` または JSON null。
- **一般responseへ含めないもの**: `action` / `warnings` / `stage` / `changed` / `details` / `beErrorCode` / `payload` / `command` / `vaultPath` / `tempFilePath` / `stackTrace` / `MSG` / `LINE` / `CMD` / 絶対パス / 実行コマンド全文。

## 旧307最小改修案の降格記録（Phase 1B-4で置換・不採用）

【Phase 1B-4で置換・不採用】
旧案：307が実行層エラーを構造化JSONで返す最小改修。
現行：307はCHECK／COMPARE／APPLY用PIPE transportとして変更せず維持し、
新規 EXT-obs_内部CallPS-SYNC-NOTE がSYNC_NOTE用JSON transportを担当する。

該当箇所：本文書「① 一方向同期方式」および「ゲート② 307の実行層エラー対応」。削除せず履歴として保持し、現行仕様は 1B-4 / 1B2-8 および「transport構造化エラー方針」節を正とする。
