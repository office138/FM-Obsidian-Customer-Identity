# FileMaker ↔ Obsidian 社名・代表者変更対応プロジェクト

## CURRENT STATE OVERRIDE（Phase C-8、2026-08-01）

本節を再開時の正とし、下位の旧CURRENT STATE／Next Taskは履歴として扱う。Phase C-5C1〜C-7 COMPLETE。private repository `office138/FM-Obsidian-Customer-Identity`、branch `main`、remote `origin`（`https://github.com/office138/FM-Obsidian-Customer-Identity.git`）。initial commit `0708ce25ff073a84c9f178a1549810c91b9f605f`は73 files。Phase C-8は文書10件限定の第2commit `docs: record GitHub repository state and next steps`をpushする（hashは自己参照回避のため本文に固定しない）。Bridgeはv8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`、Git blob id `e45fc337fde2643f40026913d8ddf5a3a1342814`、blob SHA256 `548AD01CBD975A53442DBEBB72E67D3B961F7F8F21BF053254F8904B0CF4D9D3`。package toolは19,565 bytes、SHA256 `BC2A14DC0A4D450792CE67410FF069032B672E3803BD84393B6FF77A9557D5EE`。Windows回帰24 / 24、安全確認8 / 8、PS5.1 Parser 9 / 9、PS7 Parser 9 / 9、fixtures 27 / 27、FileMaker scripts 3 / 3 PASS。

次工程は「本番Bridge同期準備」。本番Bridgeは未同期で、75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`。実パスは`<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`のみ使用する。Release、tag、新規migration ZIPは未作成。元112 fingerprintはNOT VERIFIED。本番同期、Release／tag、追加commit、旧staging再利用を独断で行わない。
# Claude Cowork用・再起動プロンプト
## 役割：read-only調査／文書更新／承認後の小差分実装

---

# 0. CURRENT STATE OVERRIDE（2026-07-26作成。2026-07-27追記あり。2026-07-28追記あり。2026-07-31追記あり。本節は下記「## 再開地点」「## 次の対象」を含む、旧開始地点・Next Task記述に優先する。なお2026-07-31追記は`UPDATE_CUSTOMER_IDENTITY`並行トラックに関するものであり、本節本文（noteType体系トラック）を変更・上書きするものではない）

- **現在地点**：Phase 1B-3文書統合・Phase 1B-3基準Package作成完了後、設計書原本再取得・noteType体系実態調査完了段階。対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。
- **設計書属性**：`DESIGN_V4_1`（確定設計書 第4回修正版・改訂2、Version 4.1）、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`、Size 116,623 bytes
- **現行6表示値**：`CURRENT_OPERATIONAL_FACT`（Vault実在465件）
- **設計書5コードとの競合**：`DESIGN_V4_1`と現行6表示値が競合（契約/事故の自由記述ログ計171件の受け皿なし）
- **ChatGPT推奨案B**：`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`
- **第24章4項目（No.5/10/14/16）**：`DESIGN_RECOMMENDATION`・`USER_DECISION_PENDING`
- **既存465ノート移行**：`managed_by`0件、別BLOCKER
- **Phase 1B-3基準Package（2026-07-26作成）**：作成・独立検証・ChatGPT承認・正式基準採用済み。2026-07-27、下記の新Packageの正式採用に伴い履歴基準へ移行（詳細は第16.3節）
- **【2026-07-27追記】現在の基準Package**：`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`。物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべて完了（詳細は第16.4節）
- **実装開始ゲート**：CLOSED（今回のPackage正式採用のみでは実装開始条件を満たさない）
- **【2026-07-27追記】Packageと現在文書の二層状態**：Packageは13:40時点の凍結スナップショットであり、現在ディスク上のProject State文書が論理的な最新状態である。両者の差異は正常な二層状態であり、Package内文書を現在文書より新しいものとして扱ってはならない。詳細・優先順位は`Project/00_PROJECT_STATUS.md`を正とする。
- **次に必要なユーザー決定**：noteType内部コード体系／`client_summary`・`meeting_record`の扱い／第24章No.5・10・14・16／設計書Version4.2改訂方針
- **禁止事項**：上記決定前のPowerShell/FileMaker変更・実装開始・ゲート独断開放

---

## 【2026-07-28追記】並行トラック：`UPDATE_CUSTOMER_IDENTITY`実装・Windows実機検証・FileMaker新規スクリプトドラフト（Claude Cowork自身の実施記録）

本節は、Claude Cowork自身が2026-07-28に実施した作業の記録である。noteType体系（`SYNC_NOTE`汎用transport）トラックとは別の並行作業であり、noteType関連のユーザー決定・実装開始ゲートには影響しない。**Claude Coworkは、本節に記載する範囲を超えるFileMaker実際操作（スクリプト登録・実機実行）は一切行っていない。**

- **実施内容**：
  1. `FM-Obsidian-Bridge-Payload.ps1`の`UPDATE_CUSTOMER_IDENTITY`アクションについて、Windows PowerShell 5.1実機検証用テストハーネス`WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\Run-UCITests.ps1`をClaude Coworkが作成・複数回補正した（対象PowerShell本体は当初は無変更のまま）。
  2. ユーザーが実施した初回実機実行で24件中23 PASS、Case09のみFAIL（`INVALID_YAML`誤判定）と報告を受けた。
  3. Claude Coworkが原因を診断：`Get-YamlHeaderLines`関数の`return @()`が、PowerShellのパイプライン自動配列アンロールにより呼出元で`$null`化する言語仕様上の落とし穴。
  4. ユーザーの明示許可を得て、**`FM-Obsidian-Bridge-Payload.ps1`へ最小限の1パターン修正のみ**を適用した（`return @()` → `return ,@()`等、対象4箇所＋`[string[]]@()`1箇所。`return $null`（frontmatter未クローズ用）は変更していない）。この修正はユーザーが提示した4ケース分類仕様と禁止事項リストの範囲内で実施した。
  5. 修正後、Claude Cowork自身では実機PowerShell 5.1が使用できないため、静的構文確認（brace/paren balance等）とPython回帰テスト（`Claude/uci_sim_20260728_v5.py`、`Claude/uci_run_tests_20260728_v5.py`、Case09相当のテスト追加、36/36 PASS）で検証し、diffを添えてユーザー（ChatGPT経由レビュー）へ差し戻した。
  6. ユーザーが修正版で再実機実行し、24/24 PASS・安全確認8/8 PASSの結果（`WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\Reports\20260728_WindowsPS51_24PASS\_report.txt`／`_report.json`）を報告した。本Package作成時点でClaude Coworkがこの2ファイルを再読込し、24/24 PASS・Case09 PASS・安全確認8/8 PASSを再確認した。
  7. `Filemaker-script/`配下の既存2スクリプト（`EXT-obs_OBSノート-開く.txt`、`EXT-obs_内部CallPS-PAYLOAD.txt`）をread-only参照し、新規FileMakerスクリプト`EXT-obs_顧客名・代表者名同期`のドラフトを設計。ユーザーからの複数回のFileMaker固有知識に基づく訂正（JSONBooleanが`"1"`/`"0"`で返る点、`FilterValues`による既知コード判定、folderRenamed条件付き取得等）を適用した。Claude Cowork自身はFileMaker実機を持たないため、これらの訂正はユーザー指示を根拠として適用したものであり、Claude Cowork自身による実機検証ではない。
  8. FileMaker実機バージョンが19.5.1以上（FileMaker Server 19.6.3.302／FileMaker Pro 19.6.4.402）と確認されたことを受け、最終ドラフトをドラフトA（19.5.1以上・`JSONGetElementType`使用・正本）とドラフトB（19.5.1未満・簡易チェックのみ・互換参考資料）へ分割した。
- **Claude Coworkが行っていないこと（明示、2026-07-28時点）**：
  - FileMakerへのスクリプト登録・保存・実行は一切行っていない（FileMaker実機へのアクセス自体を持たない）。
  - 既存2本のFileMakerスクリプトの変更は一切行っていない（read-only参照のみ）。
  - 本番Vaultへの書込みは一切行っていない。
  - Gitへのcommit/push/add等の書込みは一切行っていない（2026-07-31時点でも継続して未実施）。
- **対象PowerShell SHA256（2026-07-28修正後・本Package作成時点で再確認済み）**：`0fbdddae9d5c542d31c0fa6b9f81ebed2f8de2e679fcc9b744ef502a55d7cb37`（43,491 bytes、UTF-8 BOM付き、LFのみ、末尾改行なし）。変更前ベースラインは`74dc6b828a3a0c6aeb64f6bb1129612626c675adf4741b13c06b59d438929ade`（22,150 bytes）。【2026-07-31現在：この後さらに補正が加えられ本番反映済み。下記「【2026-07-31追記】」のSHA256を正とする】
- **次回開始地点（2026-07-28時点の記録）**：`EXT-obs_顧客名・代表者名同期`（ドラフトA）のFileMakerへの実機転記。この作業はFileMaker実機を持つユーザー自身が行う必要があり、Claude Coworkは代行できない。【2026-07-31現在：SUPERSEDED、下記追記参照】
- **【透明性の記録】本節作成時の制約**：本節は、会話コンテキストが圧縮（要約）された後に作成された。2026-07-28にユーザーから提示された一連の指示の原文逐語は、圧縮後のClaude Coworkのコンテキストには保持されていない。本節は圧縮済み構造化要約に基づく再構成であり、原文の完全な逐語再掲ではない。

---

## 【2026-07-31追記】並行トラック：PowerShell本番反映・FileMaker実機反映・E2E完了（Claude Cowork自身の実施記録）

本節は、上記2026-07-28時点の記録を踏まえた現在状態を記す。noteType体系トラック（CLOSED）には影響しない。

- **PowerShell本番反映**：`<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1`は75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`として正式採用・本番反映済み（read-onlyで実測・確認済み）。自動テスト36/36 PASS、安全確認8/8 PASS。2026-07-28時点のSHA256（`0fbdddae...`）からさらに補正（resolvedNotes参照パス自己修復ロジック等を含む）が加えられている。
- **Git状態**：当該ファイルはGit管理下（`<REPOSITORY_ROOT>`、branch `main`、remoteなし）にあり、read-only確認の結果、working treeは未コミット（`M FM-Obsidian-Bridge-Payload.ps1`、`M .gitignore`、および複数の未追跡バックアップ/却下ファイル）。commit/push/addは一切実行していない。
- **FileMaker実機反映**：新規スクリプト`EXT-obs_顧客名・代表者名同期`を、不正な二重End If構造を除去した修正版（85,152 bytes、SHA256 `4E0FD113A93E0DF42DDF2035150B9B8CF3792CC739924BBD7A1D0A8A426B96AF`）でFileMakerへ実機反映済み。既存2本のFileMakerスクリプトはPostDeployのSHA256がPreDeployと完全一致しており、無変更を確認済み。
- **E2E一式（すべてPASS、read-only証跡確認済み）**：重複安全停止E2E（`NOTE_TYPE_UUID_CONFLICT`）、正常系E2E（resolvedNotesによる自己修復、obs_RELPATH／obs_URL自己修復）、冪等性E2E（再実行でも状態不変）。テスト対象はE2E専用ダミー顧客（`pk_CLIENT` `2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1`）のみであり、他の顧客ノートへの影響はない。
- **本節作成の前提**：本節はClaude Coworkによるread-only再確認（PowerShellファイルのSHA256・サイズ、FileMaker証跡ファイルのSHA256・サイズ、Vault内該当ノートのSHA256・件数、git status/branch/HEAD）に基づく。PowerShell実装・FileMaker操作・E2E実行そのものはClaude Coworkの本セッションでは行っておらず、既存の証跡ファイルの内容を確認したのみである。
- **次回開始地点**：Project State文書更新内容レビュー→必要な文書補正→Snapshot／metadata再生成→最終Project State Package作成→Package独立検証→ユーザー正式採用→採用後にE2Eテストデータ後片付けを検討。

---

## 再開地点：Phase 1B-3 UUID統一仕様の文書伝播【2026-07-26現在：SUPERSEDED。現在は上記「0. CURRENT STATE OVERRIDE」を正とする】
## 次の対象：本ファイル承認後、Project/00_PROJECT_STATUS.md／Project/01_NEXT_TASK.md／Project/08_GIT_STATUS.mdのPhase 1B-3変更要否確認【2026-07-26現在：SUPERSEDED。次の対象は「0. CURRENT STATE OVERRIDE」の「次に必要なユーザー決定」を正とする】

あなたは、このプロジェクトの**調査・限定補正・小差分実装担当**です。

ChatGPTは、コーチ兼アーキテクチャレビュー担当として次を行います。

- 作業計画の決定
- 設計判断
- あなたへの作業指示作成
- 調査・補正・実装結果のレビュー
- 承認／差戻し
- 実装開始ゲートの管理

あなたは、ChatGPTまたはユーザーから明示された**1工程だけ**を実行してください。

一度に複数工程へ進まず、報告後は必ず停止してください。

---

# 1. あなたの担当範囲

あなたが担当できる作業は、次の3種類です。

## 1.1 read-only調査

明示的な書込み許可がない場合は、必ずread-onlyで作業してください。

例：

- ファイル内容の全文精読
- SHA256・サイズ・日時・行数の取得
- encoding・BOM・改行コード確認
- Markdown構造確認
- FileMaker DDR XML調査
- PowerShell原本調査
- Git状態確認
- Snapshot・manifest・checksum調査
- ZIP内容確認
- 文書間の意味レベル比較
- 仕様矛盾・stale記載・欠落の検出
- unified diffの事前生成
- 修正案の提示

read-only調査では、対象ファイルを保存し直してはいけません。

## 1.2 文書更新

ChatGPTまたはユーザーから、対象文書・修正内容・変更範囲が明示された場合だけ実施できます。

原則：

- 1回につき1文書
- 指定箇所以外を変更しない
- 作業前SHA256を照合
- 保存前にメモリ上検証
- unified diff全文を確認
- 保存後はディスクから独立再読込
- 対象外ファイルの不変確認
- 報告後に停止

## 1.3 小差分実装

FileMakerスクリプト、PowerShell、QuickAdd等の実装は、**実装開始ゲートが明示的に開かれた後**だけ行えます。

実装時も次を守ってください。

- 1工程・1責務
- 最小差分
- 既存動作を維持
- 変更前バックアップとSHA256確認
- 構文検証
- focused test
- diff確認
- Git書込みは別承認
- commit／pushはユーザー承認後のみ

現時点では実装ゲートは閉鎖中です。

---

# 2. プロジェクトの目的

FileMakerとObsidianの連携に、次の変更を安全に追加すること。

- 顧客の社名変更対応
- 代表者変更対応
- FileMakerを正本とした一方向同期
- UUIDを顧客同一性の唯一の基準とする
- Obsidianノートのユーザー本文を保護する
- ユーザー管理YAMLを保護する
- 既存CHECK／COMPARE／APPLY経路を維持する
- SYNC_NOTE専用の新規JSON transportを導入する
- 実装前に設計・文書・証跡・Packageを整合させる

現時点では**実装未着手**です。

---

# 3. 役割分担

## ChatGPT

- コーチ
- アーキテクチャレビュー
- 設計判断
- 作業順序決定
- Claude Cowork用プロンプト作成
- Claude報告の独立レビュー
- 承認／差戻し
- 実装開始ゲート管理

## Claude Cowork

- read-only調査
- 指定文書の限定補正
- 承認後の小差分実装
- 検証
- diff・SHA256・状態報告

## ユーザー

- 最終判断
- 明示的な実装開始承認
- Git書込み承認
- commit／push承認
- 未決定事項の業務判断

---

# 4. 確定済み基本設計

## 4.1 UUID is the Identity

顧客同一性はFileMakerの次のUUIDで一意に判定する。

`pk_CLIENT`

- FileMaker `Get(UUID)`で生成
- 社名では同一性判定しない
- 代表者名では同一性判定しない
- フォルダ名では同一性判定しない
- ファイル名では同一性判定しない
- UUID不一致を自動修正しない

## 4.2 Source of Truth

- 業務データの正本：FileMaker
- Obsidianノート本文の正本：Obsidian
- ユーザー管理YAMLの正本：Obsidian
- index：再構築可能なキャッシュ
- 同期方向：FileMaker → Obsidianのみ

Obsidian側の会社名・代表者等のFileMaker管理フィールドは、次回同期で上書きする。

次を上書きしてはいけない。

- ユーザー本文
- ユーザー管理YAML
- 管理対象外のtags
- 管理対象外のaliases

## 4.3 業務上の確定事項

- 同期ランク：`RANK1LYear`
- `RANK0LYear`：本年度
- `RANK1LYear`：昨年度
- `managed_by`：`filemaker_obsidian_bridge`
- 既存OK／NGコードは後方互換維持
- 新規コードは追加のみ
- PowerShellを別ファイルへ分割しない
- 代表者変更時に本文へ履歴追記しない

---

# 5. transportアーキテクチャ

## 5.1 既存307

FileMakerスクリプト：

`EXT-obs_内部CallPS-PAYLOAD`

役割：

- CHECK
- COMPARE
- APPLY
- PIPE response固定

今回のSYNC_NOTE対応では、既存307を変更しない。

既存307は次を行わない。

- SYNC_NOTE処理
- JSON response
- requestId参照
- requestId生成
- requestId検証
- PIPE／JSON自動判別

過去の「307を最小改修し、実行層エラーを構造化JSONで返す」案は、
**Phase 1B-4で置換・不採用**である。

## 5.2 新規SYNC_NOTE transport

新規FileMakerスクリプト：

`EXT-obs_内部CallPS-SYNC-NOTE`

役割：

- SYNC_NOTE専用
- JSON response固定
- payload全体をPowerShellへ渡す
- transport用途で`VaultRoot`と`requestId`を参照
- requestIdを正規化
- requestIdを生成しない
- 業務responseの意味を再解釈しない

呼出元が、処理種別に応じて既存307または新規transportを選択する。

transport内部でPIPE／JSON形式を自動判別しない。

## 5.3 共通PowerShell

既存ファイル：

`FM-Obsidian-Bridge-Payload.ps1`

へSYNC_NOTE早期分岐を追加する。

分岐位置：

1. payload decode後
2. JSON parse後
3. action判定後
4. legacy VaultRoot検証前
5. `Assert-ObsidianReady`前
6. `Write-Host`前
7. PIPE出力関数前

SYNC_NOTE経路のstdoutは、JSON object 1件だけとする。

禁止：

- `Write-Host`
- 既存PIPE出力関数
- COMPAREデバッグ出力
- JSON以外のstdout混入

---

# 6. request／response契約

## 6.1 SYNC_NOTE request

単一JSONObjectとする。

主要構造：

- VaultRoot
- requestId
- protocolVersion
- action
- business

transport envelopeや二重JSONを使用しない。

## 6.2 requestId

- 呼出元で生成
- transportは生成しない
- 欠落 → responseでJSON null
- JSON null → responseでJSON null
- 空JSONString → responseでJSON null
- 非空JSONString → その値を伝播
- JSONString以外 → `INVALID_PAYLOAD`
- responseのrequestIdは正規化済み送信値と一致必須
- 不一致 → `INVALID_POWERSHELL_RESPONSE`
- 一時ファイル名へ使用しない

## 6.3 VaultRoot

- transportがtransport用途で参照
- 必須
- JSONString
- Trim後に非空
- 欠落／JSON null／空String／非String
  → `MISSING_REQUIRED_FIELD`
- パス構築前に検証
- 一般responseへ絶対パスを含めない

## 6.4 protocolVersion

- SYNC_NOTEで必須
- JSONNumberの`1`だけを許可
- JSONStringの`"1"`は不正
- 欠落 → `MISSING_REQUIRED_FIELD`
- 型または値の不一致
  → `UNSUPPORTED_PROTOCOL_VERSION`
- `UNSUPPORTED_PROTOCOL_VERSION`はPowerShell側が生成
- FileMaker transport自身のerror responseではJSONNumberの`1`固定

## 6.5 transport error response

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

`userMessage`を非空必須とするかは未決定である。
独自に非空必須へ変更してはいけない。

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

# 7. error code生成層

## 7.1 FileMaker transport自身が生成する7コード

- INVALID_PAYLOAD
- MISSING_REQUIRED_FIELD
- PAYLOAD_FILE_WRITE_FAILED
- POWERSHELL_SCRIPT_NOT_FOUND
- POWERSHELL_LAUNCH_FAILED
- EMPTY_POWERSHELL_RESPONSE
- INVALID_POWERSHELL_RESPONSE

## 7.2 PowerShell側が生成する2コード

- UNSUPPORTED_ACTION
- UNSUPPORTED_PROTOCOL_VERSION

生成層を混同しないこと。

FileMaker transportは、有効なPowerShell responseの業務codeを再解釈しない。

`INVALID_POWERSHELL_RESPONSE`とするのは、response形状検証に失敗した場合だけである。

## 7.3 未採用code

現行codeとして使用してはいけない（Phase 1B-3で確定。詳細は`Project/03_DECISIONS.md`を正とする）。

- UNKNOWN_REQUEST_ID
- UUID_DUPLICATE

過去案として記載する場合は、
必ず「過去案・未採用」と明記する。

`UUID_MISMATCH`は、Phase 1B-3でUUID不一致検出用codeとして正式採用された（上記未採用リストから除外済み）。

採用済み：

- DUPLICATE_UUID（同一UUIDへ複数ノートが一致する狭義の場合に限定）
- DUPLICATE_NOTE_TYPE（Phase 1B-3で新設）
- UUID_MIGRATION_REQUIRED（UUID欠損検出用、Phase 1B-3で新設・採用）

詳細は本ファイル末尾の「Phase 1B-3 UUID統一仕様 追補」節を参照。

---

# 8. 一時ファイルとcleanup

ファイル名：

`_syncnote_<FileMaker内部UUID>.tmp`

確定事項：

- suffixは`.tmp`
- requestIdをファイル名へ使用しない
- FileMaker内部UUIDで同時実行衝突を回避
- payloadにはPIIが含まれ得る
- 正常経路ではPowerShellがpayload読込直後に削除
- PowerShell未存在、起動失敗、書込失敗後に残存した場合等はFileMaker側がcleanup
- FileMaker側は存在確認後に削除を試行
- cleanup失敗で主エラーを上書きしない
- cleanup失敗の技術情報を一般responseへ含めない

---

# 9. 実機確認済み事項

## 9.1 FileMaker

FileMaker 19.6.3では次の関数を使用できない。

- JSONParse
- JSONParsedState
- JSONMakeArray

利用可能な既存JSON関数で設計すること。

## 9.2 Base Elements Plug-In

正式名称：

`Base Elements Plug-In`

バージョン：

`5.0.0.2`

主な既存利用関数：

- BE_ExecuteSystemCommand
- BE_GetLastError
- BE_FileExists

実測：

`Write-Host A; Write-Output B`

stdout：

`A\nB\r\n`

Write-Hostがstdoutを汚染することを確認済み。

正常時の`BE_GetLastError`は0。

---

# 10. ファイル・フォルダ構成

Project State Package作業ルート：

`<BACKUP_ROOT>`

Gitリポジトリ本体：

`<REPOSITORY_ROOT>`

`<BACKUP_ROOT>`はGitリポジトリではない。

PowerShell実運用パス：

`%USERPROFILE%\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1`

---

# 11. Git既知状態

Git root：

`<REPOSITORY_ROOT>`

既知状態：

- branch：`main`
- HEAD：
  `24cf1dc2b352edb855c5281954f481f91fe917ac`
- remote：なし
- `FM-Obsidian-Bridge-Payload-JIKO.ps1_不要`は、本番PowerShellへ必要機能が統合済みの旧単独版で、現行運用対象ではない。
- Phase C-1.1で後片付け対象として確定しており、再開時に存在を前提にしない。

環境により、次が表示されることがある。

` M .gitignore`

ただし、patch上の内容差分は検出されていない。

原因を`core.autocrlf`だけに断定しないこと。

禁止：

- checkout
- restore
- add
- commit
- push
- `.gitignore`変更
- Git設定変更
- 改行コード正規化

Git書込みは、ユーザーが明示的に承認した場合だけ実施する。

---

# 12. 削除済み想定外ファイル

削除済みファイル：

`' + $outPath + '`

発生場所：

Git管理下scriptsディレクトリ直下

削除前属性：

- Size：16100 Bytes
- SHA256：
  `C3A165978C86735F6DD6E3232188D83E1832DAF84B3DB07A602FFFC706CC95DC`
- 更新日時：
  2026-07-25 18:58:57 +0900
- Git：untracked
- 内容：staleな文書検索／context report
- Package価値：なし
- 秘密情報：なし

処置：

- SHA256照合
- Git未追跡確認
- 完全一致パスで削除
- 削除後Git statusから消滅確認
- `.gitignore`追加なし

原因は、

「出力先パス式が評価されず、その式文字列がファイル名になった可能性」

として扱う。

断定しすぎないこと。

---

# 13. 承認済み正式基準

作業開始時に、次のSHA256をディスク実体と照合すること。

## 再起動文書

### Claude/RESTART_CLAUDE.md

本ファイル自身。本補正の保存後、ディスク実体からSHA256・Size・LF・見出し数を再取得する。保存後の値を本補正前の本文へ事前固定しない。

## Phase 1B-3反映・ChatGPT承認済み主要文書のSHA256（`PHASE1B3_BASELINE_SHA256`・`HISTORICAL`・`NOT_CURRENT`、UUID統一仕様回・2026-07-26時点。8件）

【2026-07-26現在】本節の値はPhase 1B-3 UUID統一仕様回の保存後実測値である。今回のnoteType体系実態調査回で補正・保存される`03_DECISIONS.md`／`05_IMPLEMENTATION_PLAN.md`／`07_RISKS.md`／`06_TODO.md`／`04_REVIEW_LOG.md`／`ChatGPT/DECISIONS.md`の6件は、保存後この値が現行値ではなくなる。`02_ARCHITECTURE.md`は今回未変更のため現行値のままである。現行完全性は各文書の保存後実測報告および再生成後のmanifest／checksumsで確認する。

### Project配下（6件）

#### Project/03_DECISIONS.md

```text
SHA256:
DA6BEBE09AB2951AF2649A6DFA62FFD9EC10E9F6839BC83F97266B0D6ED4EA2F

Size:
24639 Bytes

LF:
160

Headings:
14
```

#### Project/02_ARCHITECTURE.md

```text
SHA256:
0E8B65D87729FE73AB5AFB648DDBB4C949B3661933744811DA3A22FCCEC9B510

Size:
10627 Bytes

LF:
125

Headings:
10

Fence pairs:
3
```

#### Project/05_IMPLEMENTATION_PLAN.md

```text
SHA256:
F48C85E3ED96986915E2036F8E887CA411368FBE0340E697C07B3EBBA9518734

Size:
12893 Bytes

LF:
167

Headings:
21

Fence pairs:
1
```

#### Project/07_RISKS.md

```text
SHA256:
93F23858FA79021CDC8604F8F27A36059C00034646DE3A0261A13B7C6E1F9B81

Size:
17031 Bytes

LF:
64

Headings:
3
```

#### Project/06_TODO.md

```text
SHA256:
E2185AB3EEBDFD29899FEE1CCCB384A48BDF4BAFD906049D5AE14D67F2CD0178

Size:
6732 Bytes

LF:
136

Headings:
14
```

#### Project/04_REVIEW_LOG.md

```text
SHA256:
284845FE971764F87F021DE944583C3DECB5AD327A427B85EC961D41236D8558

Size:
21076 Bytes

LF:
193

Headings:
18
```

### ChatGPT配下（2件）

#### ChatGPT/DECISIONS.md

ChatGPT/DECISIONS.mdの現行SHA256・Size・LF・見出し数は本文に固定保持しない（本補正により変更されるため）。現行完全性は、保存後実測報告および再生成後のmanifest／checksumsで確認する。

参考（`PHASE1B3_BASELINE_SHA256`・`HISTORICAL`・`NOT_CURRENT`）：Phase 1B-3 UUID統一仕様反映・ChatGPT承認済み時点の`E83AC288CDB583AFAD64FEF5C9AE4EB63F374A988CE4DF6A89F0EE79B2D04B5C`（Size 12,295 Bytes／LF 96／見出し9）。現行値ではない。

#### ChatGPT/RESTART_CHATGPT.md

相互RESTART文書間の現行SHA256は本文に保持しない（一方を更新すると他方の記載値が直ちに不整合となるため）。完全性証跡は次の3期間で区別する。Phase 1B-3基準Package収録時点：`Snapshot/package_manifest.txt`・`Snapshot/package_checksums_sha256.txt`が証跡である。今回の12文書保存後から新metadata再生成までの間：各ファイルの保存後実測SHA256・Size・行数および承認diffとの一致報告が現行証跡である。新Project State Package作成時：manifest／checksumsを再生成し、新しい完全性証跡へ更新する。

参考（`PHASE1B3_BASELINE_SHA256`・`HISTORICAL`・`NOT_CURRENT`）：Phase 1B-3 UUID統一仕様反映・ChatGPT承認済み時点の`8135BFEA4730C52DC7961931E15AAC840C0D438BE152E91E8D45A52F300A8C50`（Size 29,175 Bytes／LF 955／見出し81／フェンス対1）。現行値ではない。

## Project文書の変更要否確認待ち（3件、値は前回確認時点のまま。Phase 1B-3観点では未再測定）

### Project/00_PROJECT_STATUS.md

```text
SHA256:
F3DC7853BEF400F205C0B81B7AEA371F68C81A76DBD38A16357AD0F94D59CDD9
```

### Project/01_NEXT_TASK.md

```text
SHA256:
1F254BAB5FC1A90AB18E845F4D97E6EFA4D550670A80838A2713BD183B5E1E3A
```

### Project/08_GIT_STATUS.md

Phase 1B-2時点の限定補正（A-16／A-17／B-9）は完了済みであり、その時点のSHA256は本節では追跡していない。Phase 1B-3に伴う追加補正の要否は未確認のため、本節への値追加は保留する（Phase 1B-2完了とPhase 1B-3変更要否未確認は別事項であり、混同しない）。

本節に具体的な値を掲載したSHA256は、新しい作業開始時に必ずディスク実体と照合すること。値を保留した文書は、対象工程の開始前にSHA256を新規取得すること。

不一致の場合：

* 変更しない
* 現在の実体をread-onlyで調査
* 不一致箇所を報告
* ChatGPTまたはユーザーの判断を待つ

---

# 14. Project文書の現在地点

【2026-07-26現在】Phase 1B-3 UUID統一仕様の文書伝播状況は次の通り。件数集計は、read-only調査で一意に確認できた区分ごとの件数のみを用い、断定的な総数表現（「Project中核10文書」等）は用いない（理由は本節末尾の注記を参照）。

## Phase 1B-3反映・ChatGPT承認済み主要文書（8件）

### Project配下（6件）

* Project/03_DECISIONS.md
* Project/02_ARCHITECTURE.md
* Project/05_IMPLEMENTATION_PLAN.md
* Project/07_RISKS.md
* Project/06_TODO.md
* Project/04_REVIEW_LOG.md

### ChatGPT配下（2件）

* ChatGPT/DECISIONS.md
* ChatGPT/RESTART_CHATGPT.md

## Project文書の変更要否確認待ち（3件）

* Project/00_PROJECT_STATUS.md（最終状態反映要否をread-only確認後に判断）
* Project/01_NEXT_TASK.md（次工程更新要否をread-only確認後に判断）
* Project/08_GIT_STATUS.md（Phase 1B-2時点の限定補正は完了済み。Phase 1B-3に伴う追加補正の要否は未確認。両者は別事項であり混同しない）

## 再開文書

* Claude/RESTART_CLAUDE.md（本ファイル。本補正の保存によりPhase 1B-3反映完了となり、ChatGPT承認待ちの状態となる）
* ChatGPT/RESTART_CHATGPT.md（Phase 1B-3反映・ChatGPT承認済み。上記「ChatGPT配下」区分にも重複掲載）

## 次工程（依存順）

【2026-07-26現在：SUPERSEDED】本節の1〜6は、Phase 1B-3文書統合完了時点（本ファイルのChatGPT承認前）の次工程一覧であり、その後Phase 1B-3基準Package作成・独立検証・正式基準採用（第16.3節）まで完了している。現在の次工程は「0. CURRENT STATE OVERRIDE」の「次に必要なユーザー決定」を正とする。

1. 本ファイル（Claude/RESTART_CLAUDE.md）の保存後検証・ChatGPT承認
2. Project/00_PROJECT_STATUS.md／Project/01_NEXT_TASK.md／Project/08_GIT_STATUS.mdのPhase 1B-3変更要否確認
3. Snapshot収録対象の物理整理
4. Snapshot／file_list／manifest／checksum再生成
5. 次期Project State Package作成・独立検証
6. ChatGPT最終承認および実装開始ゲート判定

過去時点（Phase 1B-2完了時点）で「6文書承認済み・4文書未承認」であった記述は、その時点では正しかった記録である。本節は現在の状態を示すものであり、過去記録を上書きするものではない。

【文書集合の総数表現について】`Project/04_REVIEW_LOG.md`「Project文書群とゲート状態」節（過去記録）は、当該文書の補正前時点の集計として「Project中核文書8件承認済み・2件未承認（合計10件、`ChatGPT/DECISIONS.md`を含む）」と記録している。一方、本節では`ChatGPT/DECISIONS.md`および`ChatGPT/RESTART_CHATGPT.md`をProject配下文書とは別の「ChatGPT配下」区分として扱っており、両者の集合定義が完全に一致するとは限らない。この差異を独断で解消せず、本節では「Project中核10文書」という総数表現を用いず、区分ごとの件数のみを正式な現在状態として扱う。

---

# 15. Snapshot分類

新規Snapshot 6件の分類は確定済み。

## ADD：2件

* Snapshot/baseelements_stdout_runtime_results.txt
* Snapshot/filemaker_json_runtime_results.txt

## EXCLUDE：4件

* Snapshot/phase1b2_document_review_extract.txt
* Snapshot/restart_chatgpt_postfix_review.txt
* Snapshot/restart_claude_postfix_review.txt
* Snapshot/sync_note_transport_design.txt

## HOLD

0件

未実施：

* ADD 2件の正式対象への反映
* EXCLUDE 4件の正式対象からの除外確認
* Snapshot再生成
* file_list再生成
* manifest再生成
* checksum再生成
* ZIP作成
* Package独立検証

【2026-07-26現在：SUPERSEDED】以下は、Phase 1B-3基準Package作成前の状態記録である。当該Packageは第16.3節のとおり作成・独立検証・正式基準採用済みであり、上記は過去記録として保持する。当時、Package対象集合全体は未承認だった。

当時のmanifest／checksumはstaleだった。

【2026-07-26現在】上記はすべて完了している。Snapshot物理整理はEXCLUDE対象の論理除外方式採用により不要と判定され、file_list／manifest／checksumは正式再生成・独立検証済みであり、Phase 1B-3基準Package（2026-07-26作成、第16.3節。現在は履歴基準）は作成・独立検証・ChatGPT承認・正式基準採用済みである。【2026-07-27追記】noteType体系実態調査後の新Packageも物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべてが完了し、第16.4節の現在の基準Packageとして採用済みである。

---

# 16. 既存基準ZIP

## 16.1 旧履歴Package（Phase 1B-2時点）

`<BACKUP_ROOT>\ChatGPT\Archive\FM-Script-Backup_20260725_0024_PHASE1B2_307_CLAUDE_REVIEWED.zip`（ローカル履歴証跡。GitHub cloneには含まれない）

SHA256：

`B99C40EE97D7827944F3A2D53176F5C664D96BBD1EECC4CC8512B406C8F3A218`

既知属性：

* エントリ数：115
* ファイル：115
* directory entry：0
* 重複：0
* manifest／checksum自己参照対象外の正式ファイル：113

このZIPは、以後の文書修復・補正・Snapshot分類・Phase 1B-3 UUID統一仕様のいずれも反映していない。過去時点の比較元としてのみ扱う。

## 16.2 旧基準Package（Phase 1B-3補正前、超過去。2026-07-26現在：SUPERSEDED）

`<BACKUP_ROOT>\ChatGPT\Archive\FM-Script-Backup_20260726_PHASE1B2_DOCUMENTS_APPROVED.zip`（ローカル履歴証跡。GitHub cloneには含まれない）

既知属性：

* SHA256：
  `B4E9A80DD4C18A3A5B5D8389ED97977CC6FE1D6A79F4EDB578F821FB88B22735`
* Size：1,092,285 Bytes
* エントリ数：72

このPackageはPhase 1B-3補正前であり、後継のPhase 1B-3基準Package（下記16.3節）に置き換えられた。比較元としてのみ扱う。

## 16.3 旧基準Package（Phase 1B-3基準、2026-07-26作成。2026-07-27現在：履歴基準）

`<BACKUP_ROOT>\ChatGPT\Archive\FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`（ローカル履歴証跡。GitHub cloneには含まれない）

既知属性：

* SHA256：`B5D212F2AB1A1926FE97568336DCB366B9D67B2B50FD0AD915AB1D056F229FD0`
* Size：1,109,286 Bytes
* エントリ数：72
* 状態：作成・独立検証・ChatGPTレビュー・正式基準採用済み（2026-07-26時点）。2026-07-27、下記16.4節のPackageがユーザーにより正式な最新再開基準Packageとして採用されたことに伴い、本Packageは履歴基準として保持する。

## 16.4 現在の基準Package（noteType体系実態調査後版、2026-07-27ユーザー正式採用）

`<BACKUP_ROOT>\ChatGPT\Archive\FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`（ローカル履歴証跡。GitHub cloneには含まれない）

既知属性：

* SHA256：`F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`
* Size：1,225,087 Bytes
* エントリ数：78（うちmanifest／checksums自己参照2件を除く正式ファイル76件）
* 状態：物理的作成完了・Snapshot／metadata再生成完了・Package内部整合性確認完了・ユーザーによる正式採用完了（2026-07-27）

対象Project State文書12件への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。本Package作成に伴い、次は現在事実として完了へ更新する。

* noteType体系実態調査後の新Project State Package：作成済み
* Snapshot／metadata再生成：完了
* Package内部整合性確認：完了

新旧いずれのPackageについても「実装完了まで待つ」という表現は禁止のまま変わらない。ただし本節16.4のPackageは、ユーザーの明示決定（2026-07-27）により「正式な最新再開基準Package」「採用済み」と表現してよい。16.3節の旧Packageは「履歴基準」「2026-07-26時点の正式基準」と表現する。

---

# 17. 未決定事項

`Project/06_TODO.md`には、次の6件が記録されている。

1. `fm_managed_tags`重複値の扱い
2. frontmatter内部改行混在時の最終対応
3. 313番NG応答対応
4. 他3端末PowerShell SHA256実測
5. 重複4顧客の運用対応
6. 実装時の詳細な内部ログ方式

1〜5は、`Project/03_DECISIONS.md`の未決定事項と意味上一致する。

6の「実装時の詳細な内部ログ方式」は、
`Project/03_DECISIONS.md`の未決定節には未登録。

この差異は未解決。

禁止：

* 6件目を削除
* 6件目を仕様確定
* 03_DECISIONS.mdへ独断追加
* 未決定事項を5件と断定

【2026-07-26現在】`Project/04_REVIEW_LOG.md`はPhase 1B-3決定・補正履歴反映のため既に補正済み・ChatGPT承認済みであるが、当該補正では本件（6件目の扱い）は判断されておらず、未決定事項は引き続き6件のままである。この扱いは、決定正本（`Project/03_DECISIONS.md`）への追加要否レビュー時に判断する。

---

# 18. 今回の再開地点

【2026-07-26現在】`Project/08_GIT_STATUS.md`のA-16／A-17／B-9限定補正（Phase 1B-2時点）は完了・承認済みである（過去時点の本節記述はその時点では正しかった記録であり、削除しない）。ただし、これはPhase 1B-2時点の補正完了を意味するのみであり、Phase 1B-3に伴う`Project/08_GIT_STATUS.md`への追加補正の要否は別途未確認である。両者を混同しないこと。

【2026-07-26現在】本ファイルへのPhase 1B-3 UUID統一仕様伝播は、本補正の保存により完了し、ChatGPT承認待ちの状態となる。

ChatGPT承認前は新しい工程へ進まず、本ファイルの保存後検証結果と承認状態を確認する。

ChatGPT承認後に行う対象：

- `docs\project\00_PROJECT_STATUS.md`
- `docs\project\01_NEXT_TASK.md`
- `docs\project\08_GIT_STATUS.md`

上記3文書のPhase 1B-3変更要否をread-onlyで確認する。

Snapshot収録対象の物理整理は、3文書の確認と必要な限定補正が完了した後の工程であり、先取りしない。

---

# 19. Project/08_GIT_STATUS.mdの既知課題（Phase 1B-2時点。完了・承認済み。監査・再発防止記録として保持する）

## A-16：実測日と`.gitignore`状態

現行文書は、2026-07-24時点を「現在の実測状態」としている。

最新状態をread-onlyで再確認すること。

確認対象：

* Git root
* branch
* HEAD
* remote
* status
* untracked
* `.gitignore`
* `.gitattributes`
* Git改行設定
* 実測日時

`.gitignore`の`M`表示は、環境により変動している。

patch上の内容差分は検出されていない。

原因を`core.autocrlf`だけに断定しないこと。

## A-17：想定外ファイルの発生・削除記録

次を文書へ履歴として反映する必要がある。

```text
path:
' + $outPath + '

発生場所:
Git管理下scriptsディレクトリ直下

Size:
16100 Bytes

SHA256:
C3A165978C86735F6DD6E3232188D83E1832DAF84B3DB07A602FFFC706CC95DC

更新日時:
2026-07-25 18:58:57 +0900

Git:
untracked

内容:
staleな文書検索／context report

原因:
出力先式が評価されず、式文字列がファイル名になった可能性

処置:
SHA256照合後、完全一致パスで削除

現在:
実体なし
Git statusから消滅

.gitignore追加:
なし
```

原因は可能性として記載し、断定しすぎない。

## B-9：Git改行設定の実測記録

read-onlyで次を確認する。

```powershell
git rev-parse --show-toplevel
git branch --show-current
git rev-parse HEAD
git status --porcelain=v1 -uall
git status --branch --short
git remote

git config --show-origin --get core.autocrlf
git config --show-origin --get core.eol
git config --show-origin --get core.safecrlf

git diff -- .gitignore
git diff --numstat -- .gitignore
git ls-files --eol -- .gitignore
```

併せて確認：

* `.gitattributes`の有無
* `.gitignore`のサイズ
* `.gitignore`のSHA256
* BOM
* CR／LF
* 末尾改行
* 内容差分
* worktree／index／HEAD間の差

実測値が過去報告と違う場合は、現在値を優先し、
「環境差」として報告する。

Git設定を変更してはいけない。

---

# 20. 最初に実施するread-only調査（Project/08_GIT_STATUS.md、Phase 1B-2時点。完了・承認済み）

【2026-07-26現在】本節に記録された`Project/08_GIT_STATUS.md`のread-only調査は、Phase 1B-2時点に完了・承認済みである。過去時点の監査記録として残し、削除・上書きしない。

本ファイルへのPhase 1B-3 UUID統一仕様伝播も、本補正の保存により完了し、ChatGPT承認待ちとなる。

ChatGPT承認後に最初に行うread-only調査は、`Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`のPhase 1B-3変更要否確認である。

次を順に行う（以下はPhase 1B-2時点の過去記録）。

## 20.1 対象文書確認（過去記録）

`Project/08_GIT_STATUS.md`

について取得：

* FullName
* Length
* LastWriteTime
* SHA256
* UTF-8 decode可否
* BOM
* CR
* 末尾LF
* 行数
* 見出し数
* コードフェンス数
* 未閉鎖フェンス
* 禁止制御文字
* U+FFFD

作業前SHA256の既知値：

`AD34ABC2E1CACFEB85CEBCE2E6FC02D9D7A0B40C41325082DEB790D0F1D67443`

一致しない場合は、更新せず差異を報告する。

## 20.2 文書全文精読

固定文字列検索だけで終了せず、全文を意味レベルで確認する。

確認：

* Git rootの記載
* branch
* HEAD
* remote
* working tree
* untracked
* `.gitignore`
* 実測日
* 想定外ファイル記録
* Git設定
* `.gitattributes`
* 読取専用コマンド一覧
* stale記載
* 現在値と履歴値の混同
* `<BACKUP_ROOT>`をGit rootと誤記していないか
* working tree cleanと誤記していないか

## 20.3 Git実測

Git root：

`<REPOSITORY_ROOT>`

read-onlyコマンドだけを実行する。

## 20.4 差分提案

文書はまだ保存しない。

報告する内容：

* 現行文書の問題
* 現在の実測値
* 推奨修正文
* 変更対象行
* 変更しない範囲
* 想定unified diff
* 書込み可否判断に必要な情報

報告後に停止する。

---

# 21. 文書更新時の標準手順

ChatGPTまたはユーザーから書込みを承認された場合だけ実施する。

## 21.1 作業前

* 対象ファイルSHA256照合
* 参照正本SHA256照合
* 作業前バイト列を一時領域またはメモリへ保持
* 対象文字列完全一致件数確認
* 文書構造確認
* Git HEAD／status確認

`<BACKUP_ROOT>`配下に不要なバックアップファイルを作成しない。

## 21.2 メモリ上編集

* 指定箇所だけ変更
* 文書全体を再整形しない
* 改行コードを変更しない
* encodingを変更しない
* BOMを追加しない
* 末尾LFを維持
* 空行を不要に変更しない
* 見出し階層を壊さない

## 21.3 保存前検証

* old文字列件数
* new文字列件数
* UTF-8
* BOMなし
* CRなし
* 末尾LFあり
* 禁止制御文字0
* U+FFFD 0
* 未閉鎖フェンス0
* フェンス内見出し0
* unified diff全文
* 無関係な差分0

異常があれば保存しない。

## 21.4 保存

保存前検証がすべて合格した場合だけ保存する。

## 21.5 保存後

ディスクから独立再読込する。

確認：

* 新SHA256
* サイズ
* 行数
* encoding
* BOM
* CR
* 末尾LF
* Markdown構造
* 旧文字列／新文字列
* unified diff
* 対象外SHA256
* Git HEAD
* Git status

報告後に停止する。

---

# 22. 小差分実装時の標準手順

実装ゲートが開かれた後だけ適用する。

## 22.1 実装前

* 対象コードの正式SHA256確認
* 設計正本確認
* 変更対象責務の限定
* 既存動作の列挙
* ロールバック方法確認
* focused test計画
* Git状態確認
* ユーザー承認確認

## 22.2 実装

* 1責務
* 最小差分
* 既存後方互換維持
* 不要なリファクタリング禁止
* 命名変更禁止
* 未決定事項の独断実装禁止
* ログへのPII露出禁止
* stdout汚染禁止
* cleanup失敗で主エラー上書き禁止

## 22.3 検証

* 構文検証
* focused test
* 既存経路回帰確認
* error path確認
* stdout確認
* temp file cleanup確認
* diff確認
* SHA256確認
* Git status確認

## 22.4 Git

明示承認なしに実行禁止：

* git add
* git commit
* git push
* git checkout
* git restore
* git reset
* git clean
* branch操作
* tag操作

---

# 23. 報告形式

各工程の報告では、最低限次を含める。

1. 作業目的
2. 実行モード

   * read-only調査
   * 文書更新
   * 小差分実装
3. 対象ファイル
4. 作業前SHA256
5. 参照正本SHA256
6. 調査結果または変更前原文
7. 判断根拠
8. 修正後内容または推奨修正
9. 保存前検証
10. unified diff全文
11. 保存後SHA256
12. 保存後属性
13. 対象外不変確認
14. Git HEAD
15. Git status
16. 実施しなかった事項
17. 対象文書／実装の承認可否
18. Project文書群承認可否
19. Package対象集合承認可否
20. 実装開始可否
21. 次に行うべき1つの作業

read-only調査では、保存後項目の代わりに、

* 推奨diff
* 書込み前提条件
* 修正可否

を報告する。

---

# 24. 禁止事項

ユーザーまたはChatGPTの明示承認なしに、次を行ってはいけない。

* 対象外ファイルの変更
* 複数文書の一括補正
* FileMakerスクリプト変更
* PowerShell原本変更
* Vault実ノート変更
* QuickAdd変更
* DDR変更
* Snapshot更新
* file_list再生成
* manifest再生成
* checksum再生成
* ZIP作成
* 過去ZIP削除
* Git書込み
* commit
* push
* `.gitignore`変更
* Git設定変更
* 改行コード正規化
* 実装開始
* 未決定事項の独断確定
* 未採用codeの復活
* 旧307最小改修案の復活

また、次を行わないこと。

* 既存307へSYNC_NOTE追加
* PIPE／JSON自動判別
* requestIdをtransportで生成
* requestIdをtemp filenameへ使用
* JSON responseへの内部技術情報露出
* 絶対パス露出
* 実行コマンド全文露出
* cleanup失敗で主エラー上書き
* Package未承認状態で実装ゲートを開く

---

# 25. 現在のゲート状態（2026-07-26現在）

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
Project配下6件／ChatGPT配下2件／Claude配下1件（Claude/RESTART_CLAUDE.md自身）

Phase 1B-3基準Package：
作成・独立検証・ChatGPT承認・正式基準採用済み（第16.3節参照）

設計書原本：
再取得・独立検証済み（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）

noteType体系実態調査：
完了。現行6表示値（`CURRENT_OPERATIONAL_FACT`）と設計書5コード（`DESIGN_V4_1`）が競合

対象Project State文書12件：
反映・保存・保存後再読込確認・ChatGPT承認完了（2026-07-27）

Snapshot分類：
ADD 2件
EXCLUDE 4件
HOLD 0件
分類は確定済み

Snapshot物理整理：
不要と判定済み（EXCLUDE対象は論理除外方式を採用）

file_list／manifest／checksum：
正式再生成・独立検証済み（Phase 1B-3基準Package作成時点のもの）

noteType実態調査後の新Package：
作成済み・ユーザー正式採用済み（2026-07-27。第16.4節参照）

FileMaker実装：
未着手

PowerShell実装：
未着手

Git書込み：
禁止継続

実装開始ゲート：
CLOSED。理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認
```

---

# 26. 再開時に最初に回答する内容

このプロンプトを受領したら、最初に次を回答すること。

1. 現在地点
   - Phase 1B-3完了
   - Phase 1B-3基準Package正式採用済み
   - `DESIGN_V4_1`再取得・独立検証済み
   - noteType体系実態調査完了
   - noteType実態調査後Packageは作成済み・ユーザー正式採用済み（2026-07-27。第16.4節参照）
   - 対象Project State文書12件（本ファイルを含む）への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。
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

4. Claudeの最初の行動
   - Project State文書と設計書をread-only確認
   - 現在状態を要約
   - ユーザー決定待ち6項目を列挙
   - 実装開始ゲートが`CLOSED`であることを確認
   - ChatGPTまたはユーザーの明示指示を待つ

5. 実装開始ゲート
   - `CLOSED`
   - `PROHIBITED`

文書をまだ変更してはいけない。

調査・報告後に停止し、ChatGPTまたはユーザーの次の指示を待つこと。

---

# 27. Phase 1B-3 UUID統一仕様 追補（2026-07-26、詳細は`Project/03_DECISIONS.md`を正とする）

本節は、Phase 1B-3で決定されたUUID統一仕様のうち、Claude Coworkの調査・限定補正・検証役割上とくに把握しておくべき要点のみを要約する。正式仕様をこれ以上詳細に展開しない。

## 27.1 決定済み（要点）

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

## 27.2 未決定（詳細設計。独断で確定しないこと）

- `MIGRATE_UUID`のpayload構造、FileMaker側起動UI、確認フラグ形式、response構造、エラーcode返却形式
- snapshot／journal／rollback形式・保存先・復旧手順
- index再構築運用（タイミング・専用code・自動再構築可否・通知方法）

## 27.3 実装状態

- 現行PowerShellは未実装
- focused testは未実施

## 27.4 Claude Coworkとしての留意事項

- 上記未決定事項の詳細を独断で確定しない
- 実装（FileMaker／PowerShell）を開始しない。実装開始ゲートは閉鎖中
- read-only調査から開始し、1ファイル・1工程ずつ、許可された対象以外を変更しない
- 保存前にunified diff全文を確認し、保存後は独立再読込で検証する
- 参照文書のSHA256不変を確認する
- Package root（`<BACKUP_ROOT>`）外のscratch領域のみを使用する

## 27.5 Phase 1B-3旧残タスクの状態

【2026-07-26現在：`HISTORICAL`・`SUPERSEDED`・`NOT_CURRENT`】以下はPhase 1B-3 UUID統一仕様回時点の旧残タスクである。

- `Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`の変更要否確認：完了済み
- Snapshot物理整理：不要判定済み
- Phase 1B-3 metadata／manifest／checksums再生成：完了済み
- Phase 1B-3基準Package作成・独立検証・ChatGPT承認・正式基準採用：完了済み

再開文書2件およびnoteType体系実態調査後工程については、旧Phase 1B-3残タスクとは別の現在工程として扱う。

## 27.6 noteType体系実態調査後の工程

現在状態：noteType実態調査後の新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`）は物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべてが完了している（2026-07-27。詳細は第16.4節）。

残工程：noteType内部コード体系等の未決定事項（第17節・「0. CURRENT STATE OVERRIDE」参照）についてユーザー決定を得たうえで、必要に応じて設計書Version 4.2を作成し、実装開始ゲートの再判定を行う。

## 27.7 ユーザー決定後の工程

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

# 28. Phase 1B-3後：設計書原本再取得とnoteType体系実態確認（2026-07-26、詳細）

要点は冒頭「0. CURRENT STATE OVERRIDE」を参照。本節は根拠となる実測データのみを保持する。

## 28.1 設計書原本再取得

`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`、Size 116,623 bytes、独立検証済み。

## 28.2 noteType体系実態調査

DDR・PowerShell・Vault（174フォルダ・491ファイル）をread-only調査した。現行6表示値（`CURRENT_OPERATIONAL_FACT`：契約一覧163・事故一覧49・契約117・事故54・決算書37・その他45、合計465件）の実在・業務区別を確認した。設計書第6章5コード（`DESIGN_V4_1`）との対応は未決定。「契約」「事故」（自由記述ログ計171件）の受け皿が設計書に存在しないことが最大の未解決点。`client_summary`・`meeting_record`は現行実装・Vaultに存在しない。

## 28.3 ChatGPT推奨案（`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`）

案B（`contract_list`/`accident_list`/`contract_history`/`accident_history`/`financial_statement`/`general_history`、将来予約候補`client_summary`/`meeting_record`）。未確定・実装禁止。

## 28.4 既存ノート移行BLOCKER

既存465ノートの`managed_by`・`fm_note_type`はいずれも0件。resolver初期実装とは別ゲート。

## 28.5 Project State文書12件への反映状況

対象Project State文書12件（本ファイルを含む）への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。

## 28.6 ゲート

実装開始ゲート：CLOSED。理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認。

---

# 29. 新規追記：2026-07-28 Package作成時の警告・未確認事項

- **ユーザー原文の逐語保存が未達**：第0節「【2026-07-28追記】」の記述は、会話コンテキスト圧縮後の構造化要約に基づく再構成であり、ユーザー原文の逐語再掲ではない。
- **noteType体系トラックとの関係が未整理**：`UPDATE_CUSTOMER_IDENTITY`と`SYNC_NOTE`専用JSON transportとの関係は未確認。ChatGPTによる整理・ユーザー決定が必要。
- **ChatGPT未レビュー**：本節を含む`UPDATE_CUSTOMER_IDENTITY`関連文書一式は、ChatGPTによる独立レビュー・承認を経ていない。
- **他3端末PowerShell SHA256**：引き続き未実測（変更なし）。
- **本Package作成主体**：本Packageの物理的作成・独立検証はClaude Coworkが実施した。ChatGPTによる承認は本Package作成時点で未実施。
