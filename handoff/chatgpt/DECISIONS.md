# DECISIONS（ChatGPT用・採用済み設計判断のみ）

正本は`Project/03_DECISIONS.md`。本ファイルは要約のみ。

## Phase 0〜0.5時点
- **UUID優先**: `pk_CLIENT`（Get(UUID)）が唯一の識別キー。
- **Git範囲**: `C:\...\scripts` 配下のみ管理対象。
- **正本・同期方向**: FileMakerが正本、FileMaker→Obsidianの一方向同期のみ。双方向同期（CHECK/APPLY）は不要。

## Phase 1A確定事項（2026-07-23）
- **一方向同期方式**: 新action `SYNC_NOTE` を追加して実装。既存CHECK/APPLY経路は初期移行段階では維持。
- **YAML構造**: 現行の日本語キー構造（`tags:`/`UUID:`/`ランク:`/`総合計保険料:`）を維持。
- **tags更新方式**: 丸ごと置換禁止。`fm_managed_tags` で管理タグを記録する差分更新方式を採用。
- **protocolVersion/requestId**: 両方を導入（`protocolVersion=1`）。
- **307最小改修（過去決定・不採用）**: Phase 1A時点では、実行層エラー4種に限り構造化結果（`POWERSHELL_LAUNCH_FAILED`等）を返す最小改修案をゲート②として採用していたが、Phase 1B-4の責務分離により置換・不採用となった。現行仕様では既存307を変更しない。

## Phase 1B確定事項（2026-07-24、ユーザー・ChatGPT承認）
- **1B-1 noteType実在確認と呼出構造**: DDR上実在するnoteTypeは `契約一覧`, `事故一覧`, `契約`, `事故`, `決算書`, `その他` の6種。呼出構造は 299 → 307 → PS（通常）、313 → 307 → PS（突合）。313 は 299 を経由しない。
- **1B-2 YAML編集方式**: Phase 1 では外部 YAML パーサーを導入せず、PowerShell 単体で完結する行保持型 frontmatter 編集（方式A拡張）を採用する。
- **1B-3 未対応YAML構文の扱い**: 閉じていない frontmatter、非先頭 frontmatter、重複キー、複雑な入れ子、`fm_managed_tags` 型不正等は更新前（`Update-Yaml-Robust` 冒頭）に検知し `INVALID_YAML` または `INVALID_MANAGED_TAGS` で即時中止する。
- **1B-4 307責務分離と新規SYNC_NOTE transport**: 307はCHECK／COMPARE／APPLY専用のPIPE response固定とし、SYNC_NOTE・JSON response・requestId処理を追加しない。新規 `EXT-obs_内部CallPS-SYNC-NOTE` はpayloadからrequestIdを参照・正規化し、transport自身の入力・書込・起動・response形式エラーを構造化する。requestIdは生成せず、業務responseの意味は解析しない。

## Phase 1B-2確定事項（2026-07-24、ユーザー・ChatGPT・Claude）
- **noteType一意性と自動作成**: 全6 noteTypeは同一顧客内に各1ノートの業務仕様。条件付き自動作成候補。
- **顧客名変更・UUID優先**: 顧客同一性は `pk_CLIENT` UUIDで判定。名前変更時は既存顧客として処理（新規作成せず）。
- **重複保護**: UUID重複時は `DUPLICATE_UUID`、同一noteType重複時（Vault実態4顧客で確認）は `DUPLICATE_NOTE_TYPE` で警告表示・処理中止。
- **BOM・改行コード方針**: 既存BOM/改行を維持、本文改行は不変更（mixed 8件はfrontmatterのみLF編集）。新規は UTF-8 BOMなし・LF。
- **frontmatter境界規則**: 第1行 `---` から直後の単独行 `---` を一意な終了境界とする（本文中 `---` は無視）。
- **`tags` 値なし**: `tags:` 直後に値がない形式（9件）は空タグとして扱い `INVALID_YAML` にしない。

## Phase 1B-2 transport設計確定事項（2026-07-25）
- **既存307と新規SYNC_NOTE分割**: 既存307はMODE専用。新規に `EXT-obs_内部CallPS-SYNC-NOTE` を作成しJSON固定。
- **JSON型とpayload検証**: JSONString=1, JSONNumber=2等実測済。型判定に `JSONGetElementType` を使用。ルートがJSONObjectかを検証。
- **Base Elements**: `Write-Host` 出力は戻り値に混入する。正常時 `BE_GetLastError = 0`。
- **SYNC_NOTE stdout制約**: SYNC_NOTE経路では、`Write-Host`、既存PIPE出力関数、COMPAREデバッグ出力およびJSON以外のstdoutを禁止し、stdoutをJSON object 1件だけに限定する。
- **PowerShell構成**: 既存ps1にSYNC_NOTE早期分岐を追加。分割しない。

## Phase 1B-2 統合確定事項（2026-07-26）

- **既存307**: `EXT-obs_内部CallPS-PAYLOAD`はCHECK／COMPARE／APPLY専用、PIPE response固定とし、SYNC_NOTE対応では変更しない。requestIdを生成・参照・検証せず、JSON responseも返さない。
- **新規transport**: `EXT-obs_内部CallPS-SYNC-NOTE`をSYNC_NOTE専用transportとして追加し、JSON response固定とする。既存307との間でPIPE／JSON形式を自動判別しない。
- **PowerShell分岐**: 既存`FM-Obsidian-Bridge-Payload.ps1`へSYNC_NOTE早期分岐を追加し、別ファイルへ分割しない。分岐はlegacy VaultRoot検証、`Assert-ObsidianReady`、`Write-Host`および既存PIPE出力より前に完了させる。
- **requestId**: 呼出元が生成し、transportは生成しない。欠落、JSON null、空JSONStringはresponseでJSON nullへ正規化し、非空JSONStringは伝播する。JSONString以外は`INVALID_PAYLOAD`とし、PowerShell responseのrequestId不一致は`INVALID_POWERSHELL_RESPONSE`とする。一時ファイル名には使用しない。
- **一時ファイル**: `_syncnote_<FileMaker内部UUID>.tmp`を使用する。正常経路ではPowerShellがpayload読込直後に削除し、PowerShell未存在・起動失敗等ではFileMaker側がcleanupを試行する。cleanup失敗で主エラーを上書きせず、cleanupの内部技術情報を一般responseへ含めない。
- **code生成層**: FileMaker transport自身が生成する7code、PowerShell入口層が生成する2code、業務・YAML・ノート判定系codeを生成層ごとに分離する。FileMaker transportは、有効なPowerShell業務responseのcodeを再解釈しない。
  - FileMaker transport自身：`INVALID_PAYLOAD`、`MISSING_REQUIRED_FIELD`、`PAYLOAD_FILE_WRITE_FAILED`、`POWERSHELL_SCRIPT_NOT_FOUND`、`POWERSHELL_LAUNCH_FAILED`、`EMPTY_POWERSHELL_RESPONSE`、`INVALID_POWERSHELL_RESPONSE`
  - PowerShell入口層：`UNSUPPORTED_ACTION`、`UNSUPPORTED_PROTOCOL_VERSION`
  - 採用済み業務・YAML・ノート判定系：`INVALID_YAML`、`INVALID_MANAGED_TAGS`、`NOTE_NOT_FOUND`、`DUPLICATE_UUID`、`DUPLICATE_NOTE_TYPE`、`UUID_MIGRATION_REQUIRED`、`UUID_MISMATCH`【Phase 1B-3で`UUID_MISMATCH`を追加・正式採用（2026-07-26）。詳細は`Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節を正とする】
  - 未採用：`UNKNOWN_REQUEST_ID`、`UUID_DUPLICATE`【Phase 1B-3で`UUID_MISMATCH`は不採用から正式採用へ変更し、上記採用済みリストへ移動した（2026-07-26）】
- **FileMaker JSON関数**: FileMaker 19.6.3では`JSONParse`、`JSONParsedState`、`JSONMakeArray`を利用できないため、実機で利用可能な既存JSON関数だけを使用する。
- **Snapshot分類**: 新規Snapshot 6件をADD 2件、EXCLUDE 4件、HOLD 0件に分類する。
  - ADD：`Snapshot/baseelements_stdout_runtime_results.txt`、`Snapshot/filemaker_json_runtime_results.txt`
  - EXCLUDE：`Snapshot/phase1b2_document_review_extract.txt`、`Snapshot/restart_chatgpt_postfix_review.txt`、`Snapshot/restart_claude_postfix_review.txt`、`Snapshot/sync_note_transport_design.txt`
- **実装開始ゲート**: Snapshot物理整理、file_list／manifest／checksumの正式再生成、次期Project State Packageの独立検証およびChatGPT最終承認が完了するまで、FileMaker実装・PowerShell実装を開始しない。
- **UUID正本文書間不整合**: 【Phase 1B-3決定前の状態】承認済み文書間に「UUIDをFileMaker値で上書き」「UUIDを照合なしで上書き」「UUID不一致時は自動上書きせずエラー停止」という記述が併存していた。不整合の存在は確認済みだが、統一後の最終仕様は未確定であり、不整合も未解消であるため、不整合解消前はUUID更新処理を実装せず、本項だけで仕様を確定しない方針としていた。【2026-07-26現在】Phase 1B-3により正本文書間のUUID記述不整合は設計上解消済み。詳細は下記「Phase 1B-3 UUID統一仕様」節および`Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節を正とする。

## 未決定事項

現在の未決定事項は次の6件である。

1. `fm_managed_tags`重複値の扱い
2. frontmatter内部改行混在時の最終対応
3. 313番NG応答対応
4. 他3端末PowerShell SHA256実測
5. 重複4顧客の運用対応
6. 実装時の詳細な内部ログ方式

6件目「実装時の詳細な内部ログ方式」は、`Project/03_DECISIONS.md`の未決定節に未登録である。この差異を検出したことのみを記録し、現時点では削除・仕様確定・`Project/03_DECISIONS.md`への追加を行わない。決定正本への追加要否は後工程で判断し、未決定事項は引き続き6件として扱う。

## Phase 1B-3 UUID統一仕様（2026-07-26、詳細は`Project/03_DECISIONS.md`を正とする）

以下はChatGPT側の要約であり、詳細な条件・payload・エラーcode定義は`Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節を正とする。本節では正式仕様全文を複製しない。

**決定済み（設計判断）**
- UUID is the Identity：`pk_CLIENT` UUIDのみを顧客identityとし、名前・会社名・folderName・relpath・ファイル名はidentityとして使用しない
- `SYNC_NOTE`と`MIGRATE_UUID`を分離し、通常同期からUUID初回記録を切り離す
- UUID一致時のみ通常`SYNC_NOTE`で同期可能（同一値の再記録を許可）
- UUID欠損の既存候補がある場合、`SYNC_NOTE`を停止し`UUID_MIGRATION_REQUIRED`を返す
- UUID不一致の場合、`SYNC_NOTE`を停止し`UUID_MISMATCH`を返し、自動上書き・自動修復は行わない
- `DUPLICATE_UUID`は同一受信UUIDに複数ノートが一致する場合専用とし、`DUPLICATE_NOTE_TYPE`（同一顧客UUID・同一noteType複数）と混同しない
- `UUID_DUPLICATE`は不採用のまま維持する
- migration候補または別UUID競合候補が存在する場合、新規ノートを作成しない
- index（`obsidian_index.json`）はidentityの正本・UUID自動修復の根拠として使用せず、不一致時は実ファイルを再探索し、一意性を確定できない場合は安全停止する
- `MIGRATE_UUID`は`SYNC_NOTE`と独立したactionとする。対象相対パス明示、ユーザー確認済み、UUID欠損限定、既存UUIDがあれば停止、同一受信UUIDを持つ別ノートなし、noteType一意、managed_by一致、事前snapshot／journal作成を条件とし、UUID初回記録だけを行う。業務項目は後続の別`SYNC_NOTE`で同期する

**未決定（詳細設計待ち）**
- `MIGRATE_UUID`のpayload構造、FileMaker側起動UI、ユーザー確認済みフラグ形式、response構造、migration用エラーcode返却形式
- snapshot／journal／rollbackの詳細形式・保存先・復旧手順
- index再構築運用（タイミング・専用code・自動再構築可否・通知方法）

**残タスク**
- 現行PowerShellは未実装（UUID検索・状態判定・4code・新規作成禁止条件のいずれも未反映）
- focused testは未実施
- 文書伝播：`Project/04_REVIEW_LOG.md`、再開文書、`Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`の変更要否確認が残存。本`ChatGPT/DECISIONS.md`は本補正の保存により反映完了となり、ChatGPT承認待ちの状態となる
- Phase 1B-3関連文書の補正・承認完了後、実装着手前の状態を固定するためにSnapshot整理、metadata再生成、新Project State Package作成・独立検証を行う
- 実装開始ゲートは、実装開始前に必要と判断された詳細設計、文書伝播、データ運用方針および証跡更新がすべて完了し、ChatGPT・ユーザーが明示承認するまで閉鎖する

## 追加の未決定事項（2026-07-26、noteType体系関連、上記6件とは別枠）

設計書原本を再取得した（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）。Phase 1B-3基準Package（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`）は作成・独立検証・正式基準採用済みである。read-only実態調査の結果、次が追加の未決定事項として判明した。

- **noteType内部コード体系**（`USER_DECISION_PENDING`）：設計書第6章5コード（`DESIGN_V4_1`）と現行6表示値（`CURRENT_OPERATIONAL_FACT`、Vault実在465件）の対応が未確定
- **ChatGPT推奨案B**（`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`）：候補内部コード`contract_list`/`accident_list`/`contract_history`/`accident_history`/`financial_statement`/`general_history`。将来予約候補`client_summary`/`meeting_record`含む。採用済みではない
- **設計書第24章 Phase1関連4項目**（`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`）：No.5/10/14/16
- **既存Vaultノートの`managed_by`・`fm_note_type`未反映**（`CURRENT_OPERATIONAL_FACT`）：現行465ノートはいずれも0件。resolver初期実装とは別ゲート

Project State文書12件（本ファイルを含む）は、本補正の反映対象である。

**実装開始ゲート：CLOSED。** 理由：noteType体系未決定／内部コード未承認／将来予約コード未決定／第24章No.5・10・14・16未決定／設計書Version4.2改訂方針未承認。

## 【2026-07-28追記】並行トラックの決定事項（`UPDATE_CUSTOMER_IDENTITY`／FileMaker新規スクリプト）

- `FM-Obsidian-Bridge-Payload.ps1`の`Get-YamlHeaderLines`関数における空配列返却時のPowerShell自動アンロール対策（`return @()`→`return ,@()`等）をユーザー許可の下、適用済み（対象4箇所＋1箇所、`return $null`は変更なし）。
- 新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`の既知NGコード判定は`not IsEmpty(FilterValues($respCode; $knownNGCodes))`方式、既知NGコードは15件（既存13件＋`EXECUTION_FAILED`／`INVALID_PAYLOAD`）で確定。
- FileMaker実機バージョン（Server 19.6.3.302／Pro 19.6.4.402、いずれも19.5.1以上）確認に伴い、**ドラフトA（`JSONGetElementType`使用）を正本として採用**。ドラフトB（簡易チェックのみ）は19.5.1未満環境向けの互換参考資料として保持。
- 上記はいずれも、本ファイル本文のnoteType体系・SYNC_NOTE transportに関する決定事項とは独立しており、これらを変更・上書きするものではない。両トラックの統合方針は未確認・未決定。

## 【2026-07-31追記】並行トラックの決定事項（PowerShell本番反映・FileMaker実機反映）

- `FM-Obsidian-Bridge-Payload.ps1`（SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`）を正式版として本番反映することを決定・実施済み。
- 新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`は、不正な二重End If構造を除去した修正版（`EXT-obs_顧客名・代表者名同期_AFTER_CORRECTED_20260731.txt`、SHA256 `4E0FD113A93E0DF42DDF2035150B9B8CF3792CC739924BBD7A1D0A8A426B96AF`）を正式版として採用・実機反映することを決定・実施済み。
- 既存2本のFileMakerスクリプト（`EXT-obs_OBSノート-開く`／`EXT-obs_内部CallPS-PAYLOAD`）は今回の反映対象外とし、無変更のまま維持する方針を確認済み（PostDeployのSHA256完全一致により裏付け済み）。
- 本追記もいずれも、本ファイル本文のnoteType体系・SYNC_NOTE transportに関する決定事項とは独立しており、これらを変更・上書きするものではない。
