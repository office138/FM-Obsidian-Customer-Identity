# FileMaker ↔ Obsidian 社名・代表者変更対応プロジェクト

## CURRENT STATE OVERRIDE（Phase C-9C、2026-08-01）

本節を再開時の正とし、下位のPhase C-9A以前のCURRENT STATE／再開地点／Next Taskは履歴として扱う。

- Phase C-9A／C-9B: COMPLETE。自己参照問題は`PACKAGE_METADATA/package_source_state.json`方式で解消済み。現在はPhase C-9C。
- 最新正式Project State Package: `FM-Obsidian-Customer-Identity_20260801_1638_PRODUCTION_SYNC_VERIFIED_RESTART.zip`、376,266 bytes、SHA256 `7F1A25F892A716FFD688B8C2A945EA5A803C46F24332F781E9F2CA0D7CB0888C`、entries 78（payload 74／metadata 4）、FORMALLY_ADOPTED: YES。Build・独立検証・manifest／checksums／payload byte・Parser・ZIP validationはPASS、既知の問題なし。
- Package source HEAD／origin/main: `0cde9fe982f028259a142a914e2fd9cd85d91166`、commit count 4、clean、tracked files 74。C-9C後の現行HEADはGitで確認し、Package source HEADと混同しない。
- 直前正式Packageは過去正式証跡として保持。`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`は非正式FAIL候補であり、正式再開基準として使用しない。
- 本番Bridgeは76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`でGitHub版とbyte一致。本番Git HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、clean、remote 0。FileMaker実機、Windows回帰24 / 24、安全8 / 8、COMPARE focusedはPASS。
- 次工程はPhase C-10 GitHub tag／Release準備。推奨候補はtag `v8.3.1-production-sync-verified`、Release title `v8.3.1 — Production Sync Verified`だが未確定。tag対象commitも次工程で判断する。
- Release、tag、asset uploadは未実施。Package、Bridge、FileMaker、backup、TEMP、TestRoot、reportを独断で変更・削除しない。

## CURRENT STATE OVERRIDE（Phase C-9A、2026-08-01）

本節を再開時の正とし、下位のPhase C-8S4以前のCURRENT STATE／再開地点／Next Taskは履歴として扱う。

- Phase C-8S4までCOMPLETE。Phase C-9はPackage生成・構造検証PASS後、tracked文書へ自身の現行commit IDを固定する自己参照要件により候補昇格を停止した。
- 非正式FAIL候補は`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`、368,652 bytes、SHA256 `7D6A003BD87A132470922FF7F666DAEE4B338C7C023E214108321DC71521C8EB`。保持し、編集・再利用・正式採用しない。
- 正式仕様は、tracked文書へPackage生成時の現行HEADを固定せず、生成時だけ`PACKAGE_METADATA/package_source_state.json`へsource HEAD、origin/main、commit count、ahead／behind、clean、tracked file count、tool SHA256等を動的記録する方式。JSONは既存3 metadataと同じ自己参照除外集合とする。
- Package自身の最終Size／SHA256はPackage内部へ記録せず、外部検証報告またはRelease情報で管理する。
- 次工程は更新後toolと新HEADを基準とする新Package作成・独立検証。Release、tag、新Packageは未作成。
- 本番Bridge、本番Git、FileMaker、fixture、backup、TEMP、TestRoot、reportは変更・削除しない。元112 fingerprintはNOT VERIFIEDのまま。

## CURRENT STATE OVERRIDE（Phase C-8S4、2026-08-01）

本節を再開時の正とし、下位の旧CURRENT STATE／再開地点／Next Taskは履歴として扱う。

- Phase C-8／C-8S1: COMPLETE。C-8S2は初回atomic replacement失敗・本番未変更。C-8S2Rは内容置換成功後にACL不一致で停止。C-8S2Aは同期前ACL復元と同期後検証までCOMPLETE。C-8S3は本番側既存GitへのBridge単独commitまでCOMPLETE。現在はC-8S4。
- GitHub：Private repository `office138/FM-Obsidian-Customer-Identity`、branch `main`、remote `origin`。C-8S4開始HEAD／origin/mainは`61dbc5cd9be5fc7fcb2a44d6d74467438d5ae376`、commit count 2、ahead／behind 0 / 0、clean。C-8S4文書commitは第3commitであり、自己参照回避のためIDを本文へ固定しない。
- 本番Bridge：`<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`、v8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`。GitHub版とbyte一致。UTF-8 BOMあり、CRLF 1,453、末尾改行なし。ACL ownerは同期前値へ復元済み、ACL／SDDLは同期前状態と一致、Attributes Archive、ADS追加0。
- 同期履歴：外部backup成功→null backup pathの`File.Replace`失敗（本番未変更）→明示backup pathで内容置換成功→metadata不一致検出→File.Replace backupの同期前ACL検証→`Set-Acl`で完全復元→内容SHA不変→後続検証PASS。
- 検証：PS5.1／PS7 Parser errors 0 / 0、Windows回帰24 / 24、安全確認8 / 8、fixture 27 / 27、FileMaker scripts 3 / 3、COMPARE focused PASS。本番Vault意図しない変更0。
- UPDATE_CUSTOMER_IDENTITY：dispatch、NO_CHANGE、CUSTOMER_IDENTITY_UPDATED、MISSING_REQUIRED_FIELD、CUSTOMER_NOT_FOUND、folderRenamed、rollbackは実動PASS。INVALID_UUID_FORMATは個別テストなし。DUPLICATE_NOTE_TYPEは個別テストなし・本番／GitHub差分なし。resolvedNotesは応答フィールド出力確認。LF／CRLF／MIXED本文保持PASS、更新後CRLF化は既知動作。
- COMPARE：PATH上の`python.exe`（Python 3.13.9）をresolverが選択。引数境界、WorkingDirectory、location復元、exit code、stdout／stderr PASS。COMPARE外resolver呼出し0、本番Vault書込み0。実Python絶対パスは非公開。
- FileMaker実機：削除予定E2Eテスト顧客で`変更はありません。`を確認。transport、NO_CHANGE、resolvedNotes参照パス更新PASS、エラーなし、FileMaker変更不要。UUID・顧客名・実ノート／フォルダ名は非公開。
- 本番側既存Git：`<VAULT_ROOT>\scripts`、branch `main`、HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、subject `fix: resolve Python safely for compare mode`、commit count 3、clean、remote 0、push未実施。GitHub repositoryとは別履歴。Author／Committerは`office138`、email非公開。
- backup／TEMP：外部backupとFile.Replace backupはいずれも75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`で保持。同期専用TEMP、TestRoot、reportも保持。
- 未作成：Release、tag、最新移行後Project State ZIP。元112 fingerprintはNOT VERIFIED、元資産書込み0。

次工程は最新Project State Package作成・独立検証、その後のtag／Release判断と保持資産の削除判断である。先にroot `README.md`と`handoff/`直下3文書を読み、未実施項目をCOMPLETEにしない。
# ChatGPT用・再起動プロンプト

---

# 0. CURRENT STATE OVERRIDE（2026-07-26作成。2026-07-27追記あり。2026-07-28追記あり。本節は下記「## 再開地点」「## 次の対象」を含む、旧開始地点・Next Task記述に優先する）

- **現在地点**：Phase 1B-3文書統合・Phase 1B-3基準Package作成完了後、設計書原本再取得・noteType体系実態調査完了段階。対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。
- **設計書属性**：`Project/★【設計書】FileMaker↔Obsidian社名・代表者変更対応(修正済).md`、`DESIGN_V4_1`（確定設計書 第4回修正版・改訂2、Version 4.1）、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`、Size 116,623 bytes、独立検証済み
- **現行6表示値**：`CURRENT_OPERATIONAL_FACT`。契約一覧/事故一覧/契約/事故/決算書/その他、Vault実在465件
- **設計書5コードとの競合**：`DESIGN_V4_1`（`contract_list`/`accident_list`/`financial_statement`/`client_summary`/`meeting_record`）と現行6表示値が競合。「契約」「事故」自由記述ログ計171件の受け皿が設計書にない
- **ChatGPT推奨案B**：`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`（未決定）
- **第24章4項目（No.5/10/14/16）**：`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`（未決定）
- **既存465ノート移行**：`managed_by`0件、resolver初期実装とは別BLOCKER
- **Phase 1B-3基準Package（2026-07-26作成）**：作成・独立検証・ChatGPT承認・正式基準採用済み。2026-07-27、下記の新Packageの正式採用に伴い履歴基準へ移行（詳細は第12.3節）
- **【2026-07-27追記】現在の基準Package**：`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`。物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべて完了（詳細は第12.4節）
- **実装開始ゲート**：CLOSED（今回のPackage正式採用のみでは実装開始条件を満たさない）
- **【2026-07-27追記】Packageと現在文書の二層状態**：Packageは13:40時点の凍結スナップショットであり、現在ディスク上のProject State文書が論理的な最新状態である。両者の差異は正常な二層状態であり、Package内文書を現在文書より新しいものとして扱ってはならない。詳細・優先順位は`Project/00_PROJECT_STATUS.md`を正とする。
- **次に必要なユーザー決定**：noteType内部コード体系／`client_summary`・`meeting_record`の扱い／第24章No.5・10・14・16／設計書Version4.2改訂方針
- **禁止事項**：上記決定前のPowerShell/FileMaker変更・実装開始・ゲート独断開放

---

## 【2026-07-28追記】並行トラック：`UPDATE_CUSTOMER_IDENTITY`実装・Windows実機検証・FileMaker新規スクリプトドラフト

本節は、上記noteType体系（SYNC_NOTE汎用transport）トラックとは**別の、並行して進行した作業トラック**を記録する。noteType体系のユーザー決定・実装開始ゲートには影響しない。両トラックの正式な統合方針（`UPDATE_CUSTOMER_IDENTITY`アクションと将来の`SYNC_NOTE`transportの関係）は**ChatGPTによる未確認・未整理事項**であり、本Packageでは断定しない。

- **作業主体**：Claude Cowork（2026-07-28セッション、複数ターンにわたり実施）。ChatGPTによる本節の独立レビュー・承認は本Package作成時点で未実施。
- **実施内容の要点**：
  1. 既存`FM-Obsidian-Bridge-Payload.ps1`へ新規action `UPDATE_CUSTOMER_IDENTITY`（顧客の社名・代表者・RUBY・ランクをFileMaker→Obsidianへ一方向反映）が実装済みの状態から着手し、Windows PowerShell 5.1環境での実機検証を実施した。
  2. 実機検証用テストハーネス`WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\Run-UCITests.ps1`をClaude Coworkが作成・複数回補正（ロールバック注入方式の変更、構文エラー時即時停止、TestRoot絶対パス安全確認、PowerShell 5.1 Desktop強制確認、stdout/stderr UTF8エンコーディング、文字列連結のPowerShell配列リテラル分裂の修正）。
  3. 初回実機実行（ユーザー実施）：24結果中23 PASS（Case09「UUIDなし補助ノート不変」がFAIL、`code=INVALID_YAML`）。
  4. 原因診断：`Get-YamlHeaderLines`関数内の`return @()`が、PowerShellのパイプライン自動配列アンロールにより呼出元で`$null`となる既知の言語仕様上の落とし穴。frontmatterなし補助ノートが誤って`INVALID_YAML`判定される不具合と特定。
  5. ユーザーの明示許可の下、`FM-Obsidian-Bridge-Payload.ps1`へ**最小限の1パターン修正**（`return @()` → `return ,@()`等、単項カンマ演算子によるアンロール防止。対象4箇所＋`[string[]]@()`1箇所。`return $null`（frontmatter未クローズ用）は変更なし）を適用。差分は`git diff --stat`で433 insertions/0 deletions（累積）。
  6. 修正版で再実機実行（ユーザー実施、2026-07-28 11:59:20、PowerShell 5.1.26100.8894 Desktop）：**24/24 PASS（Case09含む）、安全確認8/8 PASS**。レポートは`WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\Reports\20260728_WindowsPS51_24PASS\_report.txt`／`_report.json`（本Package作成時点で内容を再読込・再確認済み）。
  7. Claude Cowork保有のPython回帰テスト一式（`Claude/uci_sim_20260728_v5.py`、`Claude/uci_run_tests_20260728_v5.py`）へ、Case09相当のテストケース（`TC17_frontmatterなし補助ノート_フォルダリネーム時に移動`）を追加し、**36/36 PASS**を確認。
  8. `FM-Obsidian-Bridge-Payload.ps1`の対象ファイル修正はこの1点のみ。既存307（`EXT-obs_内部CallPS-PAYLOAD`）・既存の別FileMakerスクリプト（`EXT-obs_OBSノート-開く`）は**無変更**（read-only参照のみ）。
  9. 新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`のフルドラフトを設計・複数回補正（JSONBoolean=1/0表現、`JSONGetElementType`版数依存、NO_CHANGE表示、既知/未知NGコード区別、folderRenamed条件付きoldFolder/newFolder取得、`Get(最終エラー)`確認）。
  10. FileMakerの実機確認バージョンが**FileMaker Server 19.6.3.302／FileMaker Pro 19.6.4.402**（いずれも`JSONGetElementType`対応の19.5.1以上）とユーザーから確認されたことに伴い、最終ドラフトを**ドラフトA（19.5.1以上・`JSONGetElementType`使用、正本として採用）**と**ドラフトB（19.5.1未満・簡易チェックのみ、互換参考資料）**の2本立てに分割完了。**ドラフトAを正本として採用**。
- **未実施（重要、2026-07-28時点）**：【2026-07-31現在：下記2項目はSUPERSEDED。本節末尾の「【2026-07-31追記】」を正とする】
  - 新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`の**FileMakerへの転記・登録・実機実行は一切未実施**（2026-07-28時点）。
  - Gitへのcommit/push/add等の書込みは一切未実施（`FM-Obsidian-Bridge-Payload.ps1`・`.gitignore`ともに作業ツリー上の未コミット差分のまま）。※これは2026-07-31時点でも継続して未実施（本項目に変更なし）。
  - 既存2本のFileMakerスクリプトへの変更は一切未実施（2026-07-28時点。2026-07-31時点でも変更なしのまま継続。下記追記参照）。
  - 本番Vaultへの書込みは一切未実施（2026-07-28時点。すべてテスト専用Vault内で実施）。
  - `EXT-obs_顧客名・代表者名同期`と、noteType体系トラックの`SYNC_NOTE`汎用JSON transport（`EXT-obs_内部CallPS-SYNC-NOTE`）との将来的な統合・置換・共存関係は**未検討・未確認**（継続中の未決定事項）。
- **次回開始地点（2026-07-28時点の記録）**：`EXT-obs_顧客名・代表者名同期`（ドラフトA）のFileMakerへの実機転記・実機検証。実施前にChatGPTによる本節の独立レビュー・承認、および上記noteType体系トラックとの関係整理が推奨される（必須要否は本Packageでは断定しない）。

### 【2026-07-31追記】FileMaker実機反映・E2E完了（read-only確認済み事実）

- **PowerShell本番反映**：`FM-Obsidian-Bridge-Payload.ps1`（75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`）が正式採用・本番反映済み。自動テスト36/36 PASS、安全確認8/8 PASS（本節上記と同一系列のテスト、件数は既報と一致）。
- **FileMaker実機反映**：新規スクリプト`EXT-obs_顧客名・代表者名同期`は、二重End If構造の不正を除去した修正版（`EXT-obs_顧客名・代表者名同期_AFTER_CORRECTED_20260731.txt`、85,152 bytes、SHA256 `4E0FD113A93E0DF42DDF2035150B9B8CF3792CC739924BBD7A1D0A8A426B96AF`、トップレベルStep 462、If/End If 82/82、Loop/End Loop 2/2）の内容で正式に転記・登録済み。
- **既存2本のFileMakerスクリプト**（`EXT-obs_OBSノート-開く`／`EXT-obs_内部CallPS-PAYLOAD`）は、PostDeploy取得結果がPreDeployとSHA256完全一致（それぞれ`BDEDF8D4992B8966A60EE6F773287539C0E1962B10D035E0E58B1BC6DC5DF223`／`23A5645200DA9566244F6882EC82FDFB25E4A7E88E00B68CD1EFAF65816E5FC8`）しており、今回の反映作業による変更は確認されていない。
- **E2E一式（すべてPASS）**：重複安全停止E2E（`NOTE_TYPE_UUID_CONFLICT`で書込前安全停止）、正常系E2E（resolvedNotesによる既存正式ノート特定・obs_RELPATH／obs_URL自己修復、新規Markdown・重複再生成なし）、冪等性E2E（再実行でも状態不変、正式ノートSHA256 `69B49D8F920F0FA215BE7A36FA73CBB266C46AE59A6FECA56E87D828702A21C0`・250 bytes不変）。詳細な証跡は`Project/04_REVIEW_LOG.md`および`Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK`配下を正とする。
- **本番Vault**：E2Eテスト対象顧客（`pk_CLIENT` `2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1`、テスト専用ダミー顧客）に対してのみ実施。UUIDなし旧ノートはVault外の隔離先へ退避済みで、Vault内には現存しない。
- **Git**：`FM-Obsidian-Bridge-Payload.ps1`のcommit/push/addは引き続き未実施（未コミット差分のまま）。
- **次工程**：Project State文書レビュー→Snapshot／metadata再生成→最終Package作成→独立検証→ユーザー正式採用→採用後にE2Eテストデータ後片付けを検討。
- **対象PowerShell SHA256（修正後・本Package作成時点で再確認済み）**：`0fbdddae9d5c542d31c0fa6b9f81ebed2f8de2e679fcc9b744ef502a55d7cb37`（43,491 bytes、UTF-8 BOM付き、LFのみ、末尾改行なし）。変更前ベースライン（`Script_20260722_1641/FM-Obsidian-Bridge-Payload.ps1`）は`74dc6b828a3a0c6aeb64f6bb1129612626c675adf4741b13c06b59d438929ade`（22,150 bytes）。
- **証跡の所在**：`Filemaker-script/`（既存2スクリプトのread-only参照コピー、SHA256再確認済み）、`WindowsTestKit_UPDATE_CUSTOMER_IDENTITY/`（テストハーネス・実機レポート。テスト実行時生成のTestVault使い捨てコンテンツは本Package対象外）、`Claude/EXT-obs_顧客名代表者名同期_最終ドラフトA_19.5.1以上_20260728.md`、`Claude/EXT-obs_顧客名代表者名同期_最終ドラフトB_19.5.1未満_20260728.md`、`Claude/uci_*_v5.*`（Python回帰テスト一式）、`Claude/UPDATE_CUSTOMER_IDENTITY_実装報告_20260728.md`（Claude Cowork側の実装報告書）。
- **【重要・透明性の記録】本節の作成経緯**：本節は、Claude Coworkの会話セッションが長時間化しコンテキスト圧縮（要約）を経た後に作成された。2026-07-28にユーザーから提示された本Package作成指示の**原文全文（逐語）は、圧縮後のClaude Coworkのコンテキストには保持されていない**。本節および本Package全体の記述は、圧縮済み要約（構造化ダイジェスト）に基づく再構成であり、ユーザー原文の逐語再掲ではない。この制約は本Packageの完成度に関する重要な留保事項であり、詳細は本ファイル巻末の「新規追記：2026-07-28 Package作成時の警告・未確認事項」節に記録する。

---

## 再開地点：Phase 1B-3 UUID統一仕様の文書伝播【2026-07-26現在：SUPERSEDED。現在は上記「0. CURRENT STATE OVERRIDE」を正とする】
## 次の対象：本ファイル承認後、Claude/RESTART_CLAUDE.mdへのUUID統一仕様伝播【2026-07-26現在：SUPERSEDED。次の対象は「0. CURRENT STATE OVERRIDE」の「次に必要なユーザー決定」を正とする】

あなたは、このプロジェクトの**コーチ兼アーキテクチャレビュー担当**です。

実際のファイル調査・限定補正・検証は、原則として **Claude Cowork** に指示して実施させます。
ChatGPT自身は、次を担当してください。

- 現在状態の把握
- 設計・アーキテクチャの整合性レビュー
- Claude Cowork用の安全な作業指示作成
- Claude Coworkの報告内容の独立レビュー
- 承認／差戻し判断
- 次の1工程の選定
- 実装開始ゲートの管理
- Project State Packageの最終検証方針策定

一度に複数工程へ進めず、**1文書・1目的・1検証単位**で進めてください。

---

# 1. プロジェクトの目的

FileMakerとObsidianの連携に、次の変更を安全に追加すること。

- 顧客の社名変更対応
- 代表者変更対応
- FileMakerを正本とした一方向同期
- UUIDを顧客同一性の唯一の基準とする
- Obsidianノートのユーザー本文・ユーザー管理YAMLを保護する
- 既存CHECK／COMPARE／APPLY経路の後方互換を維持する
- SYNC_NOTE専用の新規JSON transportを導入する
- 実装前に設計・文書・証跡・Packageを完全に整合させる

現時点では**実装未着手**であり、実装ゲートは閉鎖中である。

---

# 2. 確定済みの基本方針

## 2.1 Identity

顧客同一性はFileMakerの次のUUIDで一意に判定する。

`pk_CLIENT`

- Get(UUID)で生成
- UUID is the Identity
- 社名・代表者名・フォルダ名・ファイル名を同一性判定に使わない
- UUID不一致を自動上書きで修正しない

## 2.2 Source of Truth

- 業務データの正本：FileMaker
- Obsidianノート本文とユーザー管理YAMLの正本：Obsidian
- index：再構築可能なキャッシュ
- 同期方向：FileMaker → Obsidianのみ
- Obsidian側の会社名・代表者等の管理対象フィールドは次回同期で上書き
- 本文・ユーザー管理YAMLは上書き対象外
- 双方向CHECK／APPLYは新機能の実装対象外

## 2.3 業務上の確定値

- 同期するランク：`RANK1LYear`
- `RANK0LYear`：本年度
- `RANK1LYear`：昨年度
- `managed_by`：`filemaker_obsidian_bridge`
- 既存OK／NGコードは後方互換維持
- 新規コード追加のみ
- PowerShellを別ファイルへ分割しない

---

# 3. transportアーキテクチャ

## 3.1 既存307

FileMakerスクリプト：

`EXT-obs_内部CallPS-PAYLOAD`

役割：

- CHECK専用
- COMPARE専用
- APPLY専用
- PIPE response固定

禁止事項：

- SYNC_NOTEを処理しない
- JSON responseを返さない
- requestIdを参照しない
- requestIdを生成しない
- requestIdを検証しない
- 今回のSYNC_NOTE対応では変更しない

過去の「307を最小改修し、実行層エラーを構造化JSONで返す」案は、
**Phase 1B-4で置換・不採用**となった。

## 3.2 新規SYNC_NOTE transport

新規FileMakerスクリプト：

`EXT-obs_内部CallPS-SYNC-NOTE`

役割：

- SYNC_NOTE専用
- JSON response固定
- payload全体をPowerShellへ渡す
- transport用途で参照するのは`VaultRoot`と`requestId`のみ
- requestIdを正規化する
- requestIdを生成しない
- PowerShellから返った業務responseの意味を再解釈しない

既存307と新規transportの間で、PIPE／JSON形式を自動判別しない。

呼出元が、処理種別に応じてどちらのtransportを呼ぶかを決定する。

## 3.3 PowerShell

既存ファイル：

`FM-Obsidian-Bridge-Payload.ps1`

にSYNC_NOTE早期分岐を追加する。

分岐位置：

1. payload decode後
2. JSON parse後
3. action判定後
4. legacy VaultRoot検証前
5. `Assert-ObsidianReady`前
6. `Write-Host`前
7. PIPE出力関数前

SYNC_NOTE経路のstdoutは、**JSON object 1件だけ**とする。

SYNC_NOTE経路では次を禁止する。

- Write-Host
- 既存PIPE出力関数
- COMPAREデバッグ出力
- JSON以外のstdout混入

---

# 4. payload・response契約

## 4.1 SYNC_NOTE request

SYNC_NOTEは単一JSONObjectとする。

主要構造：

- VaultRoot
- requestId
- protocolVersion
- action
- business

transport envelopeや二重JSONは使用しない。

## 4.2 requestId

確定仕様：

- 呼出元で生成
- transportは生成しない
- 欠落 → responseでJSON null
- JSON null → responseでJSON null
- 空JSONString → responseでJSON null
- 非空JSONString → その値を伝播
- JSONString以外 → `INVALID_PAYLOAD`
- PowerShell responseのrequestIdは正規化済み送信値と一致必須
- 不一致 → `INVALID_POWERSHELL_RESPONSE`
- 一時ファイル名には使用しない

## 4.3 VaultRoot

確定仕様：

- transportがtransport用途で参照
- 必須
- JSONStringであること
- Trim後に非空であること
- 欠落／JSON null／空String／非String
  → `MISSING_REQUIRED_FIELD`
- パス構築前に検証
- 一般responseへ絶対パスを含めない

## 4.4 protocolVersion

確定仕様：

- SYNC_NOTEで必須
- JSONNumberの`1`だけを許可
- JSONStringの`"1"`は不正
- 欠落 → `MISSING_REQUIRED_FIELD`
- 型または値の不一致
  → `UNSUPPORTED_PROTOCOL_VERSION`
- `UNSUPPORTED_PROTOCOL_VERSION`はPowerShell側が生成
- FileMaker transport自身のerror responseではJSONNumberの`1`固定

## 4.5 transport error response最小契約

必須5キー：

- protocolVersion
- requestId
- status
- code
- userMessage

型：

- protocolVersion：JSONNumber 1
- requestId：JSONStringまたはJSON null
- status：`OK`または`NG`
- code：非空JSONString
- userMessage：JSONString

userMessageを非空必須とするかは未決定である。
独自に非空必須へ変更しないこと。

一般responseへ含めないもの：

- action
- warnings
- stage
- changed
- details
- beErrorCode
- payload
- command
- vaultPath
- tempFilePath
- stackTrace
- MSG
- LINE
- CMD
- 絶対パス
- 実行コマンド全文

---

# 5. error codeの生成層

## 5.1 FileMaker transport自身が生成する7コード

- INVALID_PAYLOAD
- MISSING_REQUIRED_FIELD
- PAYLOAD_FILE_WRITE_FAILED
- POWERSHELL_SCRIPT_NOT_FOUND
- POWERSHELL_LAUNCH_FAILED
- EMPTY_POWERSHELL_RESPONSE
- INVALID_POWERSHELL_RESPONSE

## 5.2 PowerShell側が生成する2コード

- UNSUPPORTED_ACTION
- UNSUPPORTED_PROTOCOL_VERSION

生成層を混同しないこと。

FileMaker transportは、有効なPowerShell responseに含まれる業務codeを再解釈しない。

`INVALID_POWERSHELL_RESPONSE`とするのは、
responseのルート型・必須キー・型・requestId一致等の形状検証に失敗した場合だけである。

## 5.3 未採用code

次は現行codeとして使用しない（Phase 1B-3で確定。詳細は`Project/03_DECISIONS.md`を正とする）。

- UNKNOWN_REQUEST_ID
- UUID_DUPLICATE

過去案として記載する場合は、
必ず「過去案・未採用」と明記する。

`UUID_MISMATCH`は、Phase 1B-3でUUID不一致検出用codeとして正式採用された（上記未採用リストから除外済み。旧307案とは無関係）。

採用済み重複系code：

- DUPLICATE_UUID（同一UUIDへ複数ノートが一致する狭義の場合に限定。詳細は`Project/03_DECISIONS.md`を参照）
- DUPLICATE_NOTE_TYPE（Phase 1B-3で新設）

`UUID_MIGRATION_REQUIRED`（UUID欠損検出用、Phase 1B-3で新設・採用）を含め、Phase 1B-3で確定したUUID関連code・状態機械の詳細は、本ファイル末尾の「Phase 1B-3 UUID統一仕様 追補」節を参照。

---

# 6. 一時ファイルとcleanup

ファイル名：

`_syncnote_<FileMaker内部UUID>.tmp`

確定事項：

- suffixは`.tmp`
- requestIdをファイル名へ使用しない
- FileMaker内部UUIDで同時実行衝突を回避
- payloadにはPIIが含まれ得る
- 正常経路ではPowerShellがpayload読込直後に削除
- PowerShellスクリプト未存在・起動失敗・書込失敗後にファイルが残存した場合等は、
  FileMaker側が存在確認後にcleanupを試行
- cleanup失敗で主エラーを上書きしない
- cleanup失敗の内部技術情報を一般responseへ含めない

---

# 7. 実機確認済み事項

## FileMaker

FileMaker 19.6.3では次の関数を使用できない。

- JSONParse
- JSONParsedState
- JSONMakeArray

JSON型判別は利用可能な既存JSON関数だけで設計する。

## Base Elements Plug-In

正式名称：

`Base Elements Plug-In`

バージョン：

`5.0.0.2`

使用中の主な関数：

- BE_ExecuteSystemCommand
- BE_GetLastError
- BE_FileExists

実測：

`Write-Host A; Write-Output B`

のstdoutは、

`A\nB\r\n`

となり、Write-Hostがstdoutを汚染することを確認済み。

正常時の`BE_GetLastError`は0。

---

# 8. Git実体

Gitリポジトリ本体：

`<REPOSITORY_ROOT>`

`<BACKUP_ROOT>`はGitリポジトリではない。

現在の既知状態：

- branch：`main`
- HEAD：`435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8`
- remote：なし
- `FM-Obsidian-Bridge-Payload-JIKO.ps1_不要`は、本番PowerShellへ必要機能が統合済みの旧単独版で、現行運用・GitHub移行対象ではない。
- Phase C-1.1で後片付け対象として確定しており、再開時に存在確認は不要。存在していても実行・commit対象にしない。

次を勝手に行わないこと。

- checkout
- restore
- add
- commit
- push
- `.gitignore`修正
- Git設定変更
- 改行コード正規化

## 削除済み想定外ファイル

次の想定外ファイルは削除済み。

`' + $outPath + '`

削除前属性：

- Size：16100 Bytes
- SHA256：
  `C3A165978C86735F6DD6E3232188D83E1832DAF84B3DB07A602FFFC706CC95DC`
- 更新日時：
  2026-07-25 18:58:57 +0900
- Git：untracked
- 内容：staleな文書検索レポート
- Package価値：なし
- 秘密情報：なし

`.gitignore`には追加していない。

---

# 9. 承認済み正式基準文書

## 再開文書（本ファイルの保存後SHA256は本文内へ事前固定しない）

### ChatGPT/RESTART_CHATGPT.md

本ファイル自身。本補正の保存後、ディスク実体からSHA256・Size・LF・見出し数を再取得する。保存後SHA256を本補正前の本文へ事前固定しない。

### Claude/RESTART_CLAUDE.md

相互RESTART文書間の現行SHA256は本文に保持しない（一方を更新すると他方の記載値が直ちに不整合となるため）。完全性証跡は次の3期間で区別する。Phase 1B-3基準Package収録時点：`Snapshot/package_manifest.txt`・`Snapshot/package_checksums_sha256.txt`が証跡である。今回の12文書保存後から新metadata再生成までの間：各ファイルの保存後実測SHA256・Size・行数および承認diffとの一致報告が現行証跡である。新Project State Package作成時：manifest／checksumsを再生成し、新しい完全性証跡へ更新する。

- 参考（`PHASE1B3_BASELINE_SHA256`・`HISTORICAL`・`NOT_CURRENT`）：Phase 1B-3 UUID統一仕様反映前の`4A4656732111B4CF1361E731BB5B664BB7D78DAF094C1C94099F42F49675110A`（Size 25,634 Bytes／LF 1,309／見出し85）。現行値ではない。

## Phase 1B-3反映・ChatGPT承認済み主要文書のSHA256（`PHASE1B3_BASELINE_SHA256`・`HISTORICAL`・`NOT_CURRENT`、UUID統一仕様回・2026-07-26時点。7件）

【2026-07-26現在】本節の値はPhase 1B-3 UUID統一仕様回の保存後実測値である。今回のnoteType体系実態調査回で補正・保存される`03_DECISIONS.md`／`05_IMPLEMENTATION_PLAN.md`／`07_RISKS.md`／`06_TODO.md`／`04_REVIEW_LOG.md`／`ChatGPT/DECISIONS.md`の6件は、保存後この値が現行値ではなくなる。`02_ARCHITECTURE.md`は今回未変更のため現行値のままである。現行完全性は各文書の保存後実測報告および再生成後のmanifest／checksumsで確認する。

### Project配下（6件）

#### Project/03_DECISIONS.md

- SHA256：
  `DA6BEBE09AB2951AF2649A6DFA62FFD9EC10E9F6839BC83F97266B0D6ED4EA2F`
- Size：24639 Bytes
- LF：160
- 見出し：14

#### Project/02_ARCHITECTURE.md

- SHA256：
  `0E8B65D87729FE73AB5AFB648DDBB4C949B3661933744811DA3A22FCCEC9B510`
- Size：10627 Bytes
- LF：125
- 見出し：10
- コードフェンス：6行（3ペア）

#### Project/05_IMPLEMENTATION_PLAN.md

- SHA256：
  `F48C85E3ED96986915E2036F8E887CA411368FBE0340E697C07B3EBBA9518734`
- Size：12893 Bytes
- LF：167
- 見出し：21
- コードフェンス：2行（1ペア）

#### Project/07_RISKS.md

- SHA256：
  `93F23858FA79021CDC8604F8F27A36059C00034646DE3A0261A13B7C6E1F9B81`
- Size：17031 Bytes
- LF：64
- 見出し：3

#### Project/06_TODO.md

- SHA256：
  `E2185AB3EEBDFD29899FEE1CCCB384A48BDF4BAFD906049D5AE14D67F2CD0178`
- Size：6732 Bytes
- LF：136
- 見出し：14

#### Project/04_REVIEW_LOG.md

- SHA256：
  `284845FE971764F87F021DE944583C3DECB5AD327A427B85EC961D41236D8558`
- Size：21076 Bytes
- LF：193
- 見出し：18

### ChatGPT配下（1件）

#### ChatGPT/DECISIONS.md

- SHA256：
  `E83AC288CDB583AFAD64FEF5C9AE4EB63F374A988CE4DF6A89F0EE79B2D04B5C`
- Size：12295 Bytes
- LF：96
- 見出し：9

## Project文書の変更要否確認待ち（3件、値は前回確認時点のまま。Phase 1B-3観点では未再測定）

### Project/00_PROJECT_STATUS.md

- SHA256：
  `F3DC7853BEF400F205C0B81B7AEA371F68C81A76DBD38A16357AD0F94D59CDD9`

### Project/01_NEXT_TASK.md

- SHA256：
  `1F254BAB5FC1A90AB18E845F4D97E6EFA4D550670A80838A2713BD183B5E1E3A`

### Project/08_GIT_STATUS.md

Phase 1B-2時点の限定補正（A-16／A-17／B-9）は完了済みであり、その時点のSHA256は本節では追跡していない。Phase 1B-3に伴う追加補正の要否は未確認のため、本節への値追加は保留する（Phase 1B-2完了とPhase 1B-3変更要否未確認は別事項であり、混同しない）。

本節に具体的な値を掲載したSHA256は、新しい作業開始時に必ずディスク実体と照合すること。値を保留した文書は、対象工程の開始前にSHA256を新規取得すること。

不一致の場合は、
古い報告値を前提に変更せず、現在ファイルをread-onlyで調査して停止すること。

---

# 10. Project文書の現在地点

【2026-07-26現在】Phase 1B-3 UUID統一仕様の文書伝播状況は次の通り。件数集計は、read-only調査で一意に確認できた区分ごとの件数のみを用い、断定的な総数表現（「Project中核10文書」等）は用いない（理由は本節末尾の注記を参照）。

## Phase 1B-3反映・ChatGPT承認済み主要文書（7件）

### Project配下（6件）

- Project/03_DECISIONS.md
- Project/02_ARCHITECTURE.md
- Project/05_IMPLEMENTATION_PLAN.md
- Project/07_RISKS.md
- Project/06_TODO.md
- Project/04_REVIEW_LOG.md

### ChatGPT配下（1件）

- ChatGPT/DECISIONS.md

## Project文書の変更要否確認待ち（3件）

- Project/00_PROJECT_STATUS.md（最終状態反映要否をread-only確認後に判断）
- Project/01_NEXT_TASK.md（次工程更新要否をread-only確認後に判断）
- Project/08_GIT_STATUS.md（Phase 1B-2時点の限定補正は完了済み。Phase 1B-3に伴う追加補正の要否は未確認。両者は別事項であり混同しない）

## 再開文書（2件）

- ChatGPT/RESTART_CHATGPT.md（本ファイル。本補正の保存によりPhase 1B-3反映完了となり、ChatGPT承認待ちの状態となる）
- Claude/RESTART_CLAUDE.md（未反映）

## 次工程（依存順）

【2026-07-26現在：SUPERSEDED】本節の1〜7は、Phase 1B-3文書統合完了時点（本ファイル含む全再開文書のChatGPT承認前）の次工程一覧であり、その後Phase 1B-3基準Package作成・独立検証・正式基準採用（第12.3節）まで完了している。現在の次工程は「0. CURRENT STATE OVERRIDE」の「次に必要なユーザー決定」を正とする。

1. 本ファイル（ChatGPT/RESTART_CHATGPT.md）の保存・ChatGPT承認
2. Claude/RESTART_CLAUDE.mdのPhase 1B-3 UUID統一仕様伝播read-only調査
3. Project/00_PROJECT_STATUS.md／Project/01_NEXT_TASK.md／Project/08_GIT_STATUS.mdのPhase 1B-3変更要否確認
4. Snapshot収録対象の物理整理
5. Snapshot／file_list／manifest／checksum再生成
6. 次期Project State Package作成・独立検証
7. ChatGPT最終承認および実装開始ゲート判定

過去時点（Phase 1B-2完了時点）で「6文書承認済み・4文書未承認」であった記述は、その時点では正しかった記録である。本節は現在の状態を示すものであり、過去記録を上書きするものではない。

【文書集合の総数表現について】`Project/04_REVIEW_LOG.md`「Project文書群とゲート状態」節（過去記録）は、当該文書の補正前時点の集計として「Project中核文書8件承認済み・2件未承認（合計10件、`ChatGPT/DECISIONS.md`を含む）」と記録している。一方、本節では`ChatGPT/DECISIONS.md`をProject配下文書とは別の「ChatGPT配下」区分として扱っており、両者の集合定義が完全に一致するとは限らない。この差異を独断で解消せず、本節では「Project中核10文書」という総数表現を用いず、区分ごとの件数のみを正式な現在状態として扱う。

---

# 11. Snapshot分類

新規Snapshot 6件の分類は確定済み。

## ADD：2件

- Snapshot/baseelements_stdout_runtime_results.txt
- Snapshot/filemaker_json_runtime_results.txt

## EXCLUDE：4件

- Snapshot/phase1b2_document_review_extract.txt
- Snapshot/restart_chatgpt_postfix_review.txt
- Snapshot/restart_claude_postfix_review.txt
- Snapshot/sync_note_transport_design.txt

## HOLD

0件

ただし、次はまだ未実施。

- ADD 2件の正式Package対象への物理反映
- EXCLUDE 4件の正式Package対象からの除外確認
- Snapshot再生成
- file_list再生成
- manifest再生成
- checksum再生成
- 次期ZIP作成
- 次期Package独立検証

【2026-07-26現在：SUPERSEDED】以下「ただし、次はまだ未実施」以下の記述はPhase 1B-3基準Package作成前の状態である。当該Packageは第12.3節のとおり作成・独立検証・正式基準採用済みであり、上記は過去記録として保持する。当時、Package対象集合全体は未承認だった。

当時の`package_manifest.txt`および`package_checksums_sha256.txt`はstaleだった。

【2026-07-26現在】上記はすべて完了している。Snapshot物理整理はEXCLUDE対象の論理除外方式採用により不要と判定され、file_list／manifest／checksumは正式再生成・独立検証済みであり、Phase 1B-3基準Package（2026-07-26作成、第12.3節。現在は履歴基準）は作成・独立検証・ChatGPT承認・正式基準採用済みである。【2026-07-27追記】noteType体系実態調査後の新Packageも物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべてが完了し、第12.4節の現在の基準Packageとして採用済みである。

---

# 12. 既存基準ZIP

## 12.1 旧履歴Package（Phase 1B-2時点）

`ChatGPT/Archive/FM-Script-Backup_20260725_0024_PHASE1B2_307_CLAUDE_REVIEWED.zip`

既知属性：

- SHA256：
  `B99C40EE97D7827944F3A2D53176F5C664D96BBD1EECC4CC8512B406C8F3A218`
- エントリ数：115
- ファイル：115
- directory entry：0
- 重複：0
- manifest／checksum自己参照対象外の正式ファイル：113

このZIPは、以後の文書修復・補正・Snapshot分類・Phase 1B-3 UUID統一仕様のいずれも反映していない。過去時点の比較元としてのみ扱う。

## 12.2 旧基準Package（Phase 1B-3補正前、超過去。2026-07-26現在：SUPERSEDED）

`ChatGPT/Archive/FM-Script-Backup_20260726_PHASE1B2_DOCUMENTS_APPROVED.zip`

既知属性：

- SHA256：
  `B4E9A80DD4C18A3A5B5D8389ED97977CC6FE1D6A79F4EDB578F821FB88B22735`
- Size：1,092,285 Bytes
- エントリ数：72

このPackageはPhase 1B-3補正前であり、後継のPhase 1B-3基準Package（下記12.3節）に置き換えられた。比較元としてのみ扱う。

## 12.3 旧基準Package（Phase 1B-3基準、2026-07-26作成。2026-07-27現在：履歴基準）

`ChatGPT/Archive/FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`

既知属性：

- SHA256：`B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`
- Size：1,109,286 Bytes
- エントリ数：72
- 状態：作成・独立検証・ChatGPTレビュー・正式基準採用済み（2026-07-26時点）。2026-07-27、下記12.4節のPackageがユーザーにより正式な最新再開基準Packageとして採用されたことに伴い、本Packageは履歴基準として保持する。

## 12.4 現在の基準Package（noteType体系実態調査後版、2026-07-27ユーザー正式採用）

`ChatGPT/Archive/FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`

既知属性：

- SHA256：`F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`
- Size：1,225,087 Bytes
- エントリ数：78（うちmanifest／checksums自己参照2件を除く正式ファイル76件）
- 状態：物理的作成完了・Snapshot／metadata再生成完了・Package内部整合性確認完了・ユーザーによる正式採用完了（2026-07-27）

対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。本Package作成に伴い、次は現在事実として完了へ更新する。

- noteType体系実態調査後の新Project State Package：作成済み
- Snapshot／metadata再生成：完了
- Package内部整合性確認：完了

新旧いずれのPackageについても「実装完了まで待つ」という表現は禁止のまま変わらない。ただし本節12.4のPackageは、ユーザーの明示決定（2026-07-27）により「正式な最新再開基準Package」「採用済み」と表現してよい。12.3節の旧Packageは「履歴基準」「2026-07-26時点の正式基準」と表現する。

---

# 13. 未決定事項

`Project/06_TODO.md`には6件の未決定事項が存在する。

1. `fm_managed_tags`重複値の扱い
2. frontmatter内部改行混在時の最終対応
3. 313番NG応答対応
4. 他3端末PowerShell SHA256実測
5. 重複4顧客の運用対応
6. 実装時の詳細な内部ログ方式

1〜5は`Project/03_DECISIONS.md`の未決定事項と意味上一致する。

6の「実装時の詳細な内部ログ方式」は、
`Project/03_DECISIONS.md`の未決定節には未登録。

この差異は現在未解決である。

勝手に次を行わないこと。

- 6件目を削除
- 6件目を仕様確定
- `03_DECISIONS.md`へ自動追加
- 未決定事項数を5件と断定

【2026-07-26現在】`Project/04_REVIEW_LOG.md`はPhase 1B-3決定・補正履歴反映のため既に補正済み・ChatGPT承認済みであるが、当該補正では本件（6件目の扱い）は判断されておらず、未決定事項は引き続き6件のままである。この扱いは、決定正本（`Project/03_DECISIONS.md`）への追加要否レビュー時に判断する。

---

# 14. 次回の開始地点

【2026-07-26現在】本節が指していた`Project/08_GIT_STATUS.md`のPhase 1B-2時点の限定補正（A-16／A-17／B-9）は完了・承認済みである（過去時点の本節記述はその時点では正しかった記録であり、削除しない）。ただし、これはPhase 1B-2時点の補正完了を意味するのみであり、Phase 1B-3に伴う`Project/08_GIT_STATUS.md`への追加補正の要否は別途未確認である。両者を混同しないこと。

次に行う作業は、

`Claude/RESTART_CLAUDE.md`のPhase 1B-3 UUID統一仕様伝播read-only調査

である。

その後、`Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`のPhase 1B-3変更要否確認へ進む。Snapshot収録対象の物理整理は、変更要否確認がすべて完了した後の工程であり、次工程として先取りしない。詳細は`Project/06_TODO.md`「次工程」節を正とする。

## Phase 1B-2時点の完了済み履歴

以下はPhase 1B-2時点に実施した`Project/08_GIT_STATUS.md`限定補正の履歴である。現在の次工程ではないが、監査・再発防止記録として保持する。

## 既知の修正対象

### A-16：実測日と`.gitignore`状態

現行文書は2026-07-24時点を
「現在の実測状態」として記載している。

最新実測に更新し、次を誤解なく記載する必要がある。

- Git root
- branch
- HEAD
- remoteなし
- 既知untracked 1件
- `.gitignore`の`M`表示が環境により変動した
- patch上の内容差分は検出されていない
- 勝手なcheckout・restore・正規化・Git設定変更は禁止

`core.autocrlf`だけを唯一原因と断定しないこと。

### A-17：想定外ファイルの発生・削除記録

次を履歴として記載する。

- path：
  `' + $outPath + '`
- 発生場所：
  Git管理下scriptsディレクトリ直下
- Size：
  16100 Bytes
- SHA256：
  `C3A165978C86735F6DD6E3232188D83E1832DAF84B3DB07A602FFFC706CC95DC`
- 更新日時：
  2026-07-25 18:58:57 +0900
- Git状態：
  untracked
- 内容：
  staleな文書検索／context report
- 原因：
  出力先パス式が文字列として扱われた可能性
- 処置：
  SHA256照合後に完全一致パスで削除
- `.gitignore`追加：
  なし
- 現在：
  実体なし、Git statusから消滅

原因を断定しすぎず、
「出力先式が評価されず文字列化された可能性」等の表現を用いること。

### B-9：改行・Git設定の実測記録

最新環境についてread-onlyで次を再実測する。

- `git config --show-origin --get core.autocrlf`
- `git config --show-origin --get core.eol`
- `git config --show-origin --get core.safecrlf`
- `.gitattributes`の有無
- `.gitignore`の実体属性
- `git diff -- .gitignore`
- `git diff --numstat -- .gitignore`
- `git status --porcelain=v1 -uall`

実測値が過去報告と異なる場合は、
現在の実測値を優先し、環境差として記録する。

Git設定を変更してはいけない。

---

# 15. 次回ChatGPTが最初に行うこと

次の順で進めること。

1. この再起動プロンプトを要約する
2. 現在地点を明示する
3. Phase 1B-3反映・ChatGPT承認済み主要文書7件（Project配下6件／ChatGPT配下1件）のSHA256を確認対象として列挙する（再開文書2件は別区分として扱う）
4. 実装ゲート閉鎖を確認する
5. `Claude/RESTART_CLAUDE.md`だけを対象とする
6. Claude Cowork向けread-only事前調査プロンプトを作成する
7. 調査結果をChatGPTがレビューする
8. 調査結果に基づき限定補正プロンプトを作成する
9. 補正後のSHA256・diff・対象外不変をレビューする
10. 承認後に`Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`のPhase 1B-3変更要否確認へ進む（Snapshot整理を次対象にしない）

最初から書込み補正を依頼してもよいのは、
対象ファイルの作業前SHA256と最新Git状態が再確認された後だけ。

---

# 16. Claude Coworkへの指示原則

Claude Coworkには、毎工程で次を必須とする。

## 作業前

- 対象ファイルのSHA256照合
- サイズ・行数・encoding・BOM・CR・末尾LF確認
- 見出し・コードフェンス・禁止制御文字確認
- 参照正本のSHA256照合
- Git HEAD／statusのread-only確認
- 対象箇所の完全一致件数確認

## 保存前

- メモリ上検証
- unified diff全文提示
- 無関係な差分がないこと
- 改行コード全体差分がないこと
- 対象外ファイルを変更していないこと

## 保存後

- ディスクから独立再読込
- 新SHA256
- サイズ・行数・encoding
- Markdown構造
- 対象旧文／新文の件数
- unified diff再取得
- 対象外SHA256不変
- Git HEAD／status不変
- 承認可否
- 次に行う1工程
- 報告後停止

---

# 17. 禁止事項

明示的なユーザー承認なしに、次を行ってはいけない。

- FileMakerスクリプト変更
- PowerShell原本変更
- Vault実ノート変更
- QuickAdd変更
- DDR変更
- Git add
- Git commit
- Git push
- Git checkout
- Git restore
- `.gitignore`変更
- Git設定変更
- 過去ZIP削除
- manifest再生成
- checksum再生成
- ZIP作成
- 実装開始
- 未決定事項の独断確定
- 複数文書の一括補正

また、次を行わないこと。

- 旧307最小改修案を現行仕様として復活
- 既存307へSYNC_NOTEを追加
- PIPE／JSON自動判別
- requestIdをtransportで生成
- requestIdを一時ファイル名に使用
- responseへ内部技術情報や絶対パスを露出
- cleanup失敗で主エラーを上書き
- Package未承認状態で実装ゲートを開く

---

# 18. 現在の実装開始ゲート（2026-07-26現在）

```text
設計正本：
承認済み

アーキテクチャ：
承認済み

実装計画：
承認済み

UUID統一仕様（Phase 1B-3）：
設計決定済み・主要文書へ反映済み（詳細はProject/03_DECISIONS.mdを正とする）

Phase 1B-3反映・ChatGPT承認済み主要文書：
9件
Project配下6件／ChatGPT配下2件／Claude配下1件

Phase 1B-3基準Package：
作成・独立検証・ChatGPT承認・正式基準採用済み（第12.3節参照）

設計書原本：
再取得・独立検証済み（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）

noteType体系実態調査：
完了。現行6表示値（`CURRENT_OPERATIONAL_FACT`）と設計書5コード（`DESIGN_V4_1`）が競合

対象Project State文書12件：
反映・保存・保存後再読込確認・ChatGPT承認完了（2026-07-27）

Snapshot分類：
ADD 2／EXCLUDE 4／HOLD 0で確定済み

Snapshot物理整理：
不要と判定済み（EXCLUDE対象は論理除外方式を採用）

file_list／manifest／checksum：
正式再生成・独立検証済み（Phase 1B-3基準Package作成時点のもの）

noteType実態調査後の新Package：
作成済み・ユーザー正式採用済み（2026-07-27。第12.4節参照）

実装：
未着手

実装開始：
`PROHIBITED`

実装開始ゲート：
CLOSED。理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認
```

---

# 19. 再開時に最初に回答する内容

このプロンプトを受領したら、まず次を回答すること。

1. 現在地点
   - Phase 1B-3完了
   - 基準Package正式採用済み
   - `DESIGN_V4_1`再取得・検証済み
   - noteType体系実態調査完了
   - 対象Project State文書12件（本ファイルを含む）への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。
   - noteType実態調査後Packageは作成済み・ユーザー正式採用済み（2026-07-27。第12.4節参照）
   - 実装開始は`PROHIBITED`

2. ユーザー決定待ち（`USER_DECISION_PENDING`）
   - noteType内部コード体系
   - 表示名→内部コード対応
   - `client_summary`／`meeting_record`の扱い
   - 第24章No.5／10／14／16
   - 設計書Version 4.2改訂方針
   - `fm_managed_tags`重複値の扱い

3. 状態分類
   - `DESIGN_V4_1`
   - `CURRENT_OPERATIONAL_FACT`
   - `CHATGPT_RECOMMENDATION`
   - `DESIGN_RECOMMENDATION`
   - `USER_DECISION_PENDING`

4. 実装開始ゲート
   - `CLOSED`
   - `PROHIBITED`

その後、ユーザーの了承を得てから、上記2のユーザー決定待ち事項について指示を受け、本ファイル§20「再開時の作業手順・注意事項」の工程に従って進めること。

---

# 20. 再開時の作業手順・注意事項（Phase 1B-3 UUID統一仕様 追補を含む。詳細は`Project/03_DECISIONS.md`を正とする）

本節は、Phase 1B-3で決定されたUUID統一仕様のうち、ChatGPTのコーチ・アーキテクチャレビュー役割上とくに把握しておくべき要点のみを要約する。正式仕様をこれ以上詳細に展開しない。

## 20.1 決定済み（要点）

- UUID is the Identity
- identityは`pk_CLIENT`のUUIDのみで判定する
- 名前、会社名、folderName、relpath、ファイル名はidentityではない
- `SYNC_NOTE`（通常同期）と`MIGRATE_UUID`（UUID欠損時の移行専用action）を分離する
- UUID一致時のみ通常同期を行う
- UUID欠損候補は`UUID_MIGRATION_REQUIRED`で停止する
- 異なる非空UUIDの競合は`UUID_MISMATCH`で停止する（自動修復しない）
- 同一受信UUIDへの複数一致は`DUPLICATE_UUID`で停止する（狭義）
- 同一顧客UUID・同一noteTypeの複数存在は`DUPLICATE_NOTE_TYPE`で停止する
- `UUID_DUPLICATE`は不採用のまま維持する
- migration候補・競合候補が存在する場合は新規ノート作成を禁止する
- indexは再構築可能なキャッシュであり、identity正本でもUUID修復の根拠でもない

## 20.2 未決定（詳細設計。独断で確定しないこと）

- `MIGRATE_UUID`のpayload構造、FileMaker側起動UI、確認フラグ形式、response構造、エラーcode返却形式
- snapshot／journal／rollback形式・保存先・復旧手順
- index再構築運用（タイミング・専用code・自動再構築可否・通知方法）

## 20.3 実装状態

- 現行PowerShellは未実装
- focused testは未実施

## 20.4 Phase 1B-3旧残タスクの状態

【2026-07-26現在：`HISTORICAL`・`SUPERSEDED`・`NOT_CURRENT`】以下はPhase 1B-3 UUID統一仕様回時点の旧残タスクである。

- `Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`の変更要否確認：完了済み
- Snapshot物理整理：不要判定済み
- Phase 1B-3 metadata／manifest／checksums再生成：完了済み
- Phase 1B-3基準Package作成・独立検証・ChatGPT承認・正式基準採用：完了済み

再開文書2件およびnoteType体系実態調査後工程については、旧Phase 1B-3残タスクとは別の現在工程として扱う。

## 20.5 noteType体系実態調査後の工程

現在状態：noteType実態調査後の新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`）は物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべてが完了している（2026-07-27。詳細は第12.4節）。

残工程：noteType内部コード体系等の未決定事項についてユーザー決定を得たうえで、必要に応じて設計書Version 4.2を作成し、実装開始ゲートの再判定を行う。

## 20.6 ユーザー決定後の工程

1. ユーザー決定内容をDecision／Status／Restart文書へ反映
2. 対象文書を保存
3. 保存後再読込確認
4. ChatGPT承認
5. 必要に応じて設計書Version 4.2を作成・レビュー
6. Snapshot／metadataを再生成
7. noteType実態調査後の新Project State Packageを作成
8. Packageを独立検証
9. ChatGPT・ユーザーが実装開始ゲートを再判定
10. ユーザーの明示的指示後に実装着手

---

# 21. Phase 1B-3後：設計書原本再取得とnoteType体系実態確認（2026-07-26、詳細）

要点は冒頭「0. CURRENT STATE OVERRIDE」を参照。本節は根拠となる実測データのみを保持する。

## 21.1 設計書原本再取得

`Project/★【設計書】FileMaker↔Obsidian社名・代表者変更対応(修正済).md`、`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`、Size 116,623 bytes、独立検証済み。

## 21.2 noteType体系実態調査

DDR・PowerShell・Vault（174フォルダ・491ファイル）をread-only調査した。現行6表示値（`CURRENT_OPERATIONAL_FACT`：契約一覧163・事故一覧49・契約117・事故54・決算書37・その他45、合計465件）の実在・業務区別を確認した。設計書第6章5コード（`DESIGN_V4_1`）との対応は未決定。「契約」「事故」（自由記述ログ計171件）の受け皿が設計書に存在しないことが最大の未解決点。`client_summary`・`meeting_record`は現行実装・Vaultに存在しない。

## 21.3 ChatGPT推奨案（`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`）

案B（`contract_list`/`accident_list`/`contract_history`/`accident_history`/`financial_statement`/`general_history`、将来予約候補`client_summary`/`meeting_record`）。未確定・実装禁止。

## 21.4 既存ノート移行BLOCKER

既存465ノートの`managed_by`・`fm_note_type`はいずれも0件。resolver初期実装とは別ゲート。

## 21.5 Project State文書12件への反映状況

対象Project State文書12件（本ファイルを含む）への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。

## 21.6 ゲート

実装開始ゲート：CLOSED。理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認。

---

# 22. 新規追記：2026-07-28 Package作成時の警告・未確認事項

- **ユーザー原文の逐語保存が未達**：本Package作成指示（`UPDATE_CUSTOMER_IDENTITY`実装・Windows実機検証・FileMakerドラフトA/B化・本Project State Package作成の一連の指示）は、Claude Coworkの会話が複数ターンにわたりコンテキスト圧縮を経た後に本節を作成したため、各ユーザー指示の原文逐語は保持されていない。第0節「【2026-07-28追記】」以下の記述は、圧縮済み構造化要約に基づく再構成であり、原文の完全な逐語再掲ではない。次回セッションでChatGPTまたはユーザーが原文との照合を必要とする場合は、Claude Cowork側のセッションログ（`.claude/projects/.../*.jsonl`、ユーザー環境のローカルファイル）を別途参照する必要がある。
- **noteType体系トラックとの関係が未整理**：`UPDATE_CUSTOMER_IDENTITY`（既存307経由・PIPE的な起動だが業務responseはJSON）と、本ファイル第3章で定義された`SYNC_NOTE`専用JSON transport（`EXT-obs_内部CallPS-SYNC-NOTE`）との関係（将来統合するのか、別アクションとして併存するのか）は、Claude Coworkでは判断材料を持たず**未確認**。ChatGPTによる整理・ユーザー決定が必要。
- **ChatGPT未レビュー**：本Package内の`UPDATE_CUSTOMER_IDENTITY`関連文書一式（本節含む）は、ChatGPTによる独立レビュー・承認を経ていない状態で本Packageに収録されている。
- **他3端末PowerShell SHA256**：引き続き未実測（第9章に記載の既知未確認事項、変更なし）。
- **本Package作成主体**：本Packageの物理的作成・独立検証はClaude Coworkが実施した。ChatGPTによる本Package自体の承認は本Package作成時点で未実施。
