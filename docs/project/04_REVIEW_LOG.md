# 04_REVIEW_LOG

過去の調査・レビューで判明した事実の記録（時系列）。

## Phase 0〜0.5要約
- Phase 0: 設計書と現行実装の差分調査、DDR詳細調査、バックアップ作成、初回ベースラインcommit (`24cf1dc`)。
- Phase 0.5: 実機確認4項目（z_sysClientPC、RANK1LYear正本、Base Elements 5.0.0.2、313番$result未処理）および最重要業務方針（FileMaker→Obsidian一方向同期）の決定。

## ChatGPTアーキテクチャレビュー（2026-07-22、条件付き承認）
Phase 1A〜1Hの順序見直し（プロトコル定義最優先）、UUID/rename/YAML詳細設計の明確化、CHECK/APPLYの縮退方針決定、実装開始前のゲート条件設定を決定・反映。

## Phase 1A仕様確定・最終ゲート決定（2026-07-23）
5つの上位設計判断、残存仕様5項目、最終ゲート決定3項目（`fm_managed_tags`破損時＝`INVALID_MANAGED_TAGS`/`INVALID_YAML`、307実行層エラー最小改修、noteType作成可否＝Phase 1B調査対象）をユーザー・ChatGPTが確定し、Phase 1Aは正式完了。

## Phase 1B read-only調査・補正報告・最終承認（2026-07-24、Google Antigravity / ChatGPT）

### 実施経緯
1. **Phase 1B調査実施 (2026-07-24)**: Google AntigravityがDDR XML（`【CRM】RakkoDB_fmp12.xml`）および PowerShell（`FM-Obsidian-Bridge-Payload.ps1`）の read-only 調査を実施し初版報告書を提出。
2. **ChatGPTレビュー (2026-07-24)**: 調査結果の有用性を評価しつつ、Git状態誤記、障害経路の静的トレース分類、UUID不一致表現、暫定code表記、313呼出ステップ番号の補強、`fm_managed_tags`異常形・コメント保持の検証追加を指摘。
3. **補正報告書提出 (2026-07-24)**: Antigravityが指摘事項を全て承諾し、DDR 313番ステップ（Step 127 `313 → 307` 直接呼出し）、`fm_managed_tags` 異常系の解釈と検出位置、YAMLコメント/キー順序破壊の実態、実機Git状態（当時の実測でWorking Tree未追跡1件のみ、`.gitignore`差分は未検出と報告）を補強した補正報告書を提出。※ 2026-07-24 Claude Cowork再実測では ` M .gitignore`（CRLF/LF差、内容変更なし）が存在。改行コードの揺れによる時点差と判断。
4. **Claude Cowork独立レビュー (2026-07-24)**: 補正報告内容について独立第三者レビューを実施し、補正が妥当であり Phase 1B を正式完了として差し支えないとの評価を得た。
5. **ChatGPT最終承認 (2026-07-24)**: **Phase 1B read-only調査を「正式完了」として承認。** 成果物は承認。実装開始はまだ不可とし、次の工程を「実装前設計判断3項目の確定」に決定。

### 確定した主要事実と設計方針
- **実在noteType (6種)**: `契約一覧`, `事故一覧`, `契約`, `事故`, `決算書`, `その他` の6種。現行コードは全6種で自動作成するが、新プロトコルでの業務上の作成許可/禁止はユーザー業務判断待ち（暫定 `NOTE_NOT_FOUND`）。
- **313番の構造**: 313 は 299 を経由せず直接 307 を呼出す（DDR Step 127）。
- **307のエラー問題**: 一時ファイル書込み失敗時および PS 起動失敗時に生ダイアログ・コマンド全文を表示し空文字を返す。実行層エラーに限り構造化 JSON を返送する最小改修の方針が正当化された。
- **YAML編集方式**: Phase 1 では外部パーサーを導入せず、PowerShell単体完結の行保持型編集を採用。未対応構文（`INVALID_YAML` / `INVALID_MANAGED_TAGS`）は更新前に検知して即時中止する。
- **Git状態（2026-07-24 Claude Cowork再実測・訂正）**: ` M .gitignore`（最終行の改行コードのみCRLF/LF差、内容変更なし）と未追跡 `FM-Obsidian-Bridge-Payload-JIKO.ps1_不要` の2件。差分は末尾改行の揺れで時点により検出有無が変わる（実害なし）。Antigravity初版報告で `.gitignore` が欠落していた件はレビューにて実測値へ訂正された。

## Phase 1B-2 調査・Claude補正レビュー・設計判断確定（2026-07-24）

### 実施経緯と数値補正
1. **Vault YAML read-onlyサンプリング調査 (2026-07-24)**: Google AntigravityがVault内全956件のMarkdownノートを走査し、初版報告を提出。
2. **Claude Cowork 独立補正レビュー (2026-07-24)**: 初版報告値を精査し、`01_顧客` 内の実働ノート実測値へ補正した。区分は次のとおり。【確定事実】初版6分類の単純和は1013で、申告総数956件ともVault総Markdown数957件とも不一致。【静的推定】`その他:525` は履歴（`999_履歴保管`）・テンプレート・非noteTypeファイルを誤包含した可能性が高い。【未確認】初回走査スクリプト不在のため誤集計の正確な内訳・メカニズムは未確定。
   * **Antigravity初版報告値**: 契約一覧:212, 事故一覧:57, 契約:124, 事故:57, 決算書:38, その他:525
   * **Claude独立再集計値 (`01_顧客`内)**: 契約一覧:163, 事故一覧:49, 契約:117, 事故:54, 決算書:37, その他:45（合計465件）
   * **正式採用値**: frontmatter保持 266件。うち `tags` ブロック配列 257件、`tags` 値なし 9件（`INVALID_YAML` にせず空タグとして扱う）。YAMLアンカー・エイリアス構文 0件（文字列内 `&` / `*` と混同しない）。
   * **BOM・改行コード**: frontmatter保持 266件中 UTF-8 BOMあり 8件 / BOMなし 258件。LF 254件 / CRLF 4件 / mixed 8件。mixed 8件は全件「frontmatterがLF、本文がCRLF」の構造であり、本文非改変原則に従い frontmatter のみ LF で編集し本文 CRLF には一切触れない方針を決定。

### 業務仕様と重複保護の確定
- **全6 noteTypeの業務上一意性**: ユーザー確認により、全6種（契約一覧/事故一覧/契約/事故/決算書/その他）は「同一顧客内に各1ノート」を業務仕様として確定。安全条件を満たす場合に限り条件付き自動作成候補とする。
- **顧客名変更判定原則**: `pk_CLIENT` UUIDで同一性を判定。名前変更時は既存顧客として処理し、UUID検索を名前/フォルダ検索より優先する。
- **UUID重複時の保護**: 複数ノートでUUIDが重複する場合、警告を表示し `DUPLICATE_UUID` で処理中止する（自動選択・統合・修復・上書き禁止）。
- **同一noteType重複時の保護**: Vault実態調査により **4顧客で同一noteType重複が存在**（事故1顧客、契約3顧客）することを確認。業務仕様（1ノート）とVault実態の乖離に対応するため、候補が複数ある場合は警告を表示し `DUPLICATE_NOTE_TYPE` で処理中止する。
- **最終評価**: 最終判定 `B`（軽微不備修正・補正完了、Claude修正版ZIP `..._CLAUDE_REVIEWED.zip` を最新再開基準として採用）。**実装開始：不可。**



## Phase 1B-2 文書更新および検証 (2026-07-25)

**【確定事実】**
- FileMaker JSON関数 基本7ケース（{}, {"requestId":null}, {"requestId":""}, {"requestId":"abc"}, 壊れたJSON, [], トップレベル数値 1）実測
- 追加2ケース（{"protocolVersion":1}, {"protocolVersion":"1"}）実測（※JSONNumber=2は追加ケースで確定したことを明記）
- Base Elements `Write-Host`が戻り値へ混入する事実
- Base Elements正常時 `BE_GetLastError=0` の実測
- 初回文書更新の不備（BOM欠落、改行CRLF化、Snapshot不足、旧記述残存）とChatGPT一次レビュー不合格
- 完全検証により未更新5件・旧記述・Snapshot不足を確認し、今回の再補正を実施

**【設計判断】**
- 方式A採用：FileMaker transportスクリプトを分割（既存307はMODE専用、新規SYNC_NOTE専用作成）
- PowerShellは既存ps1へ早期分岐追加方針（専用ps1へ分割しない）
- transport envelope案を検討したが不採用。
- 方式Aとして、既存307と新規SYNC_NOTE transportスクリプトを分離した。
- 新規transportは生のSYNC_NOTE payloadを受け取り、二重JSON envelopeは使用しない。

**【未決定】**
- `fm_managed_tags`重複値の扱い
- frontmatter内部改行混在時の最終対応
- 313番NG応答対応
- 他3端末PowerShell SHA256確認
- 重複4顧客の運用対応
- 実装時の詳細な内部ログ方式

## Phase 1B-2 Project文書統合補正（2026-07-26）

**【Project文書補正・承認記録】**
- `Project/08_GIT_STATUS.md`を、A-16（最新Git実測への更新）、A-17（想定外ファイルの発生・調査・削除履歴）、B-9（改行設定・`.gitattributes`実測）の範囲で限定補正し、ChatGPTが承認した。
  - SHA256: `6DD97C0ABBCEFB436DE51A40FB2BDC19CBEFF8015565E450604BA4FD8BC57E4F`
- `Project/07_RISKS.md`を、`.gitignore`リスク記述の更新、UUID処理に関する正本文書間不整合の記録、frontmatter内部改行混在の未決定注記、既存重複4顧客の運用未決定注記、新規リスク8件の追加の範囲で限定補正し、ChatGPTが承認した。
  - SHA256: `08274D0011A1D99A3369BD3F8BAA7EB72FFD4D4E6ACDD685DEFC8C91DC3B8E5D`

**【既存307最小改修案の不採用化】**
- Phase 1A（2026-07-23）およびPhase 1B（2026-07-24）時点で検討・正当化されていた「既存307の実行層エラーを構造化JSONで返す最小改修」案は、その後のPhase 1B-2設計統合により不採用となった。
- 現行仕様では、既存307 `EXT-obs_内部CallPS-PAYLOAD`はCHECK／COMPARE／APPLY専用かつPIPE response固定のまま変更しない。
- SYNC_NOTEは、新規FileMakerスクリプト`EXT-obs_内部CallPS-SYNC-NOTE`で処理し、JSON response固定とする。
- 既存307と新規transportの間でPIPE／JSON形式の自動判別は行わない。

**【Base Elements stdout実測】**
- Base Elements Plug-In v5.0.0.2で`Write-Host A; Write-Output B`を実行した結果、stdoutは`A\nB\r\n`となった。
- `Write-Host`がstdoutへ混入することを実機確認したため、SYNC_NOTE経路では`Write-Host`、既存PIPE出力関数、COMPAREデバッグ出力およびJSON以外のstdoutを禁止する。

**【FileMaker JSON関数実測】**
- FileMaker 19.6.3では、`JSONParse`、`JSONParsedState`、`JSONMakeArray`を利用できないことを実機確認した。
- SYNC_NOTE transportの設計・実装では、実機で利用可能な既存JSON関数だけを使用する。

**【Snapshot分類とProject State Package状態】**
- Snapshot新規6件の分類は、ADD 2件、EXCLUDE 4件、HOLD 0件で確定した。
- ADD対象：
  - `Snapshot/baseelements_stdout_runtime_results.txt`
  - `Snapshot/filemaker_json_runtime_results.txt`
- EXCLUDE対象：
  - `Snapshot/phase1b2_document_review_extract.txt`
  - `Snapshot/restart_chatgpt_postfix_review.txt`
  - `Snapshot/restart_claude_postfix_review.txt`
  - `Snapshot/sync_note_transport_design.txt`
- Snapshotの物理整理、file_list／manifest／checksumの正式再生成は未実施である。
- 現行manifest／checksumはstaleであり、次期Project State Packageは未作成・未承認である。
- 旧基準ZIPは比較元および過去時点の再開基準であり、現行の承認済みProject State Packageではない。

**【想定外ファイルの発生・調査・削除】**
- 2026-07-25、Git管理下scriptsディレクトリ直下に、pathが`' + $outPath + '`である想定外ファイルが発生した。
- Sizeは16100 Bytes、SHA256は`C3A165978C86735F6DD6E3232188D83E1832DAF84B3DB07A602FFFC706CC95DC`、Git状態はuntracked、内容はstaleな文書検索／context reportだった。
- 削除前にサイズ、SHA256、内容およびGit状態を確認し、SHA256照合後に完全一致するパスを指定して削除した。
- `.gitignore`には追加していない。現在は実体が存在せず、Git statusからも消滅している。
- 原因は未確定であり、出力先パス式が評価されず式文字列がファイル名として扱われた可能性としてのみ記録する。

**【UUID処理に関する正本文書間不整合】**
- 承認済み文書間に、「UUIDをFileMaker値で上書きする」「UUIDを照合なしで上書きする」「UUID不一致時は自動上書きせずエラー停止する」という記述が併存していることを確認した。
- この不整合の存在は確認済みであり、`Project/07_RISKS.md`へ正式なリスクとして記録した。
- UUID一致後の同一値再記録、UUID欠損時の移行、UUID不一致時の停止を明確に区別し、正本文書間で統一する必要がある。
- 統一後の最終仕様は未確定であり、正本文書間の不整合も未解消である。
- 不整合が解消されるまでUUID更新処理を実装しない。本レビュー記録だけで仕様を確定しない。
- 【2026-07-26現在】Phase 1B-3にて正本文書間のUUID記述不整合は設計上解消された。詳細は本文書「Phase 1B-3 UUID統一仕様の決定・文書反映履歴」節および`Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節を正とする。

**【未決定事項6件目の正本未登録】**
- `Project/06_TODO.md`の未決定事項6件目「実装時の詳細な内部ログ方式」は、`Project/03_DECISIONS.md`の未決定節に未登録である。
- この差異を検出したことのみを記録し、現時点では削除・仕様確定・`Project/03_DECISIONS.md`への追加を行わない。
- 決定正本への追加要否は後工程で判断し、未決定事項は引き続き6件として扱う。

**【`.gitignore`最新実測】**
- 2026-07-26実測では`.gitignore`が`M`と表示された。
- Git diffは1行追加・1行削除として認識され、対応する可視文字列は同一である。
- 最終行付近のEOL差に由来するとみられるが原因は未確定であり、`core.autocrlf`単独を原因と断定しない。
- `core.autocrlf`、`core.eol`、`core.safecrlf`はいずれも未設定であり、`.gitattributes`は存在しない。
- checkout、restore、Git設定変更および改行正規化は、ユーザーの明示承認なしに行わない。

**【Project文書群とゲート状態】**
- 本文書の補正前時点では、Project中核文書は8件承認済み、2件未承認である。
- 承認済み8件：
  - `Project/03_DECISIONS.md`
  - `Project/02_ARCHITECTURE.md`
  - `Project/05_IMPLEMENTATION_PLAN.md`
  - `Project/00_PROJECT_STATUS.md`
  - `Project/01_NEXT_TASK.md`
  - `Project/06_TODO.md`
  - `Project/08_GIT_STATUS.md`
  - `Project/07_RISKS.md`
- 未承認2件：
  - `Project/04_REVIEW_LOG.md`
  - `ChatGPT/DECISIONS.md`
- 本文書は限定補正後にChatGPTの承認を受ける必要がある。
- 本文書の承認後、次の対象は`ChatGPT/DECISIONS.md`である。
- Snapshot物理整理は未実施、manifest／checksumはstale、次期Project State Packageは未作成・未承認である。
- FileMaker実装およびPowerShell実装は未着手であり、実装開始ゲートは閉鎖中である。

## Phase 1B-3 UUID統一仕様の決定・文書反映履歴（2026-07-26、詳細は`Project/03_DECISIONS.md`を正とする）

既存の「Phase 1B-2 Project文書統合補正」節に記載された承認件数、未承認文書および次対象は当時点の履歴であり、本節に記録するPhase 1B-3現在状態で上書き解釈しない。

### 開始・問題確定
- Phase 1B-2文書統合レビュー後、承認済み文書間に「UUIDをFileMaker値で上書き」「UUIDを照合なしで上書き」「UUID不一致時は自動上書きせずエラー停止」という記述が併存している状態を、Phase 1B-3の設計ブロッカーとして確定した。
- FileMaker／PowerShell実装開始を停止したまま、決定正本を`Project/03_DECISIONS.md`と確認し、UUID統一仕様の確定と関連文書への伝播を開始した。

### 設計決定
- `Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節にてUUID統一仕様を確定した。正式仕様全文は同節を正本とし、本項では複製しない。
- `SYNC_NOTE`と`MIGRATE_UUID`を分離し、UUID初回記録を通常同期から切り離した。
- code体系：`UUID_MIGRATION_REQUIRED`（新規正式採用）、`UUID_MISMATCH`（不採用から正式採用へ変更）、`DUPLICATE_UUID`（同一受信UUIDに複数ノートが一致する場合専用に狭義化）、`DUPLICATE_NOTE_TYPE`（同一顧客UUID・同一noteType複数）、`UUID_DUPLICATE`（不採用のまま維持）を確定した。
- identity・新規作成禁止・index原則：`pk_CLIENT` UUIDのみをidentityとし、名前・会社名・folderName・relpath・ファイル名は使用しないこと、migration候補または別UUID競合候補が存在する場合は新規ノートを作成しないこと、index（`obsidian_index.json`）をidentityの正本・UUID自動修復の根拠としないこと、不一致時は実ファイルを再探索し一意性を確定できない場合は安全停止することを確定した。
- `MIGRATE_UUID`のpayload構造、FileMaker側起動UI、ユーザー確認済みフラグ形式、response構造、migration用エラーcode返却形式、snapshot／journal／rollback詳細、index再構築運用の詳細設計は未決定のまま維持した。

### 文書補正履歴
【2026-07-26現在：`PHASE1B3_BASELINE_SHA256`・`HISTORICAL`・`NOT_CURRENT`】以下のSHA256は、Phase 1B-3 UUID統一仕様回における保存時点の値である。`03_DECISIONS.md`／`05_IMPLEMENTATION_PLAN.md`／`07_RISKS.md`／`06_TODO.md`／`ChatGPT/DECISIONS.md`は今回のnoteType体系実態調査回でも補正されるため、これらの値は補正保存後は現行値ではなくなる。`02_ARCHITECTURE.md`は今回未変更のため現行値のままである。現行完全性は各文書の保存後実測報告および再生成後のmanifest／checksumsで確認する。
- `Project/03_DECISIONS.md`：read-only調査→限定補正→保存後検証→ChatGPT承認。SHA256 `DA6BEBE09AB2951AF2649A6DFA62FFD9EC10E9F6839BC83F97266B0D6ED4EA2F`
- `Project/02_ARCHITECTURE.md`：read-only調査→限定補正→保存後検証→ChatGPT承認。SHA256 `0E8B65D87729FE73AB5AFB648DDBB4C949B3661933744811DA3A22FCCEC9B510`
- `Project/05_IMPLEMENTATION_PLAN.md`：read-only調査→限定補正→行数・diff完全性のread-only再検証→ChatGPT承認。SHA256 `F48C85E3ED96986915E2036F8E887CA411368FBE0340E697C07B3EBBA9518734`
- `Project/07_RISKS.md`：read-only調査→想定diff全文不足により書込み保留→diff全文のread-only確定→ChatGPTによる文言2箇所の修正指示→限定補正→保存後検証→ChatGPT承認。SHA256 `93F23858FA79021CDC8604F8F27A36059C00034646DE3A0261A13B7C6E1F9B81`
- `Project/06_TODO.md`：read-only調査→初回案の文書伝播状況誤認をChatGPTが指摘→初回案撤回→修正版diff再設計→保存後状態表現の追加修正→限定補正→保存後検証→ChatGPT承認。SHA256 `E2185AB3EEBDFD29899FEE1CCCB384A48BDF4BAFD906049D5AE14D67F2CD0178`
- `ChatGPT/DECISIONS.md`：read-only調査→code体系・旧状態履歴・自己状態・ゲート文言の修正指示→限定補正→保存後検証→ChatGPT承認。SHA256 `E83AC288CDB583AFAD64FEF5C9AE4EB63F374A988CE4DF6A89F0EE79B2D04B5C`
- 本`Project/04_REVIEW_LOG.md`は、本補正の保存によりPhase 1B-3決定・補正履歴の反映が完了し、ChatGPT承認待ちの状態となる。

### 品質記録
- `Project/05_IMPLEMENTATION_PLAN.md`の限定補正turnの最終報告において、純増行数の算術記載ミスが発生した。初回報告は「純増38行、135行から173行」としたが、保存後実測は167行だった。
- 後続のread-only再検証により、正しい統計を追加40行・削除8行・純増32行・135行から167行と確定した。適用diffの内容自体は当初から正確かつ完全であり、ファイル内容の不備、想定外変更、ツール定義差には該当しない。
- Git状態はPhase 1B-3の一連の補正turnを通じて不変である（branch `main`、HEAD `24cf1dc2b352edb855c5281954f481f91fe917ac`、` M .gitignore`および未追跡1件）。
- 基準Package（`FM-Script-Backup_20260726_PHASE1B2_DOCUMENTS_APPROVED.zip`、SHA256 `B4E9A80DD4C18A3A5B5D8389ED97977CC6FE1D6A79F4EDB578F821FB88B22735`）は変更・再作成していない。
- metadata再生成、新Project State Package作成、FileMaker実装、PowerShell実装はいずれも未実施である。

### 次工程
- 再開文書、`Project/00_PROJECT_STATUS.md`／`Project/01_NEXT_TASK.md`／`Project/08_GIT_STATUS.md`のUUID仕様伝播・変更要否をread-only確認する。
- 上記確認と必要な限定補正が完了した後、Snapshot収録対象の物理整理を行う。
- metadata（file_list／manifest／checksum）を正式再生成する。
- 新Project State Packageを作成し独立検証する。
- 実装開始ゲートは、実装開始前に必要と判断された詳細設計、文書伝播、データ運用方針および証跡更新がすべて完了し、ChatGPT・ユーザーが明示承認するまで閉鎖する。

## Phase 1B-3後：設計書原本再取得とnoteType体系実態確認（2026-07-26、read-only）

### 設計書原本の再取得
設計書原本（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`、Size 116,623 bytes）を再取得・独立検証した。

### noteType体系実態調査
DDR・PowerShell・Vault（174フォルダ・491ファイル）をread-only調査した。現行6表示値（`CURRENT_OPERATIONAL_FACT`：契約一覧163・事故一覧49・契約117・事故54・決算書37・その他45、合計465件）の実在・業務区別を確認した。設計書第6章5コード（`DESIGN_V4_1`）との対応は未決定であり、「契約」「事故」（自由記述ログ計171件）の受け皿が設計書に存在しないことが最大の未解決点。`client_summary`・`meeting_record`は現行実装・Vaultに存在しない。

### ChatGPT推奨案（`CHATGPT_RECOMMENDATION`・`USER_DECISION_PENDING`）
案B（`contract_list`/`accident_list`/`contract_history`/`accident_history`/`financial_statement`/`general_history`、将来予約候補`client_summary`/`meeting_record`）。未確定・実装禁止。

### 既存ノート移行BLOCKER
既存465ノートの`managed_by`・`fm_note_type`はいずれも0件。resolver初期実装とは別ゲート。

### Project State文書12件への反映状況（2026-07-26現在）
対象Project State文書12件（本ファイルを含む）への反映・保存・保存後再読込確認・ChatGPT承認は、2026-07-27にすべて完了した。

### ゲート
**実装開始ゲート：CLOSED。** 理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16は`DESIGN_RECOMMENDATION`かつ`USER_DECISION_PENDING`／設計書Version 4.2改訂方針が未承認。

---

## 最終レビュー記録（2026-07-27）

```text
レビュー対象：
Project State文書12件

結果：
全12件の保存・保存後再読込確認・ChatGPT承認完了

最終承認日：
2026-07-27

最終文書：
Claude/RESTART_CLAUDE.md

当該作業完了時点SHA256（2026-07-27、対象Project State文書12件の最終承認完了時点の記録値。正確な記録時刻は未確認）：
対象ファイル：Claude/RESTART_CLAUDE.md
値：D578679E5BD1F6162CABDD7EA44A77348F0F615D21FEAA8EF5100782F1FD67CF

注記：Claude/RESTART_CLAUDE.mdは、この記録以降も複数回の補正（Package正式採用反映、M-1／M-3／M-7補正等）を経ており、その都度SHA256が変化している。本記録は上記時点の値の履歴保持のみを目的とし、可変の「現在値」をここに併記しない。現在の実体SHA256が必要な場合は、その都度ファイル実体から再計算すること。

新Project State Package：
未作成（本記録時点。2026-07-27追記を参照）

実装開始ゲート：
CLOSED
```

## Package採用記録（2026-07-27追記）

```text
対象：
noteType実態調査後の新Project State Package

ファイル名：
FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip

SHA256：
F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D

Size：
1,225,087 Bytes

エントリ数：
78（うちmanifest／checksums自己参照2件を除く正式ファイル76件）

物理的作成：
完了

Snapshot／metadata再生成：
完了

Package内部整合性確認：
完了

ユーザーによる正式採用：
完了

旧基準Package（FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip）：
履歴基準へ移行

実装開始ゲート：
CLOSED（Package正式採用のみでは実装開始条件を満たさない）
```

## `UPDATE_CUSTOMER_IDENTITY`トラック：PowerShell本番反映・FileMaker実機反映・E2E完了記録（2026-07-31追記）

本節は、noteType体系トラック（上記、CLOSED）とは独立した並行トラック`UPDATE_CUSTOMER_IDENTITY`（顧客社名・代表者・RUBY・ランクのFileMaker→Obsidian一方向同期）に関する、2026-07-31時点の完了事実の記録である。noteType体系の実装開始ゲート判定には影響しない。

```text
PowerShell本番反映：
パス：<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1
サイズ：75,488 bytes
SHA256：3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030
状態：正式採用・本番反映済み
自動テスト：36/36 PASS
安全確認：8/8 PASS

FileMaker反映対象：
EXT-obs_顧客名・代表者名同期
反映元：Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\FileMaker\EXT-obs_顧客名・代表者名同期_AFTER_CORRECTED_20260731.txt
サイズ：85,152 bytes
SHA256：4E0FD113A93E0DF42DDF2035150B9B8CF3792CC739924BBD7A1D0A8A426B96AF
構造：XML解析PASS／トップレベルStep 462／If・End If 82/82／Loop・End Loop 2/2／Step内Step入れ子0
備考：不正な二重End If構造を除去した正式修正版

FileMaker PostDeploy証跡（Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\FileMaker\PostDeploy）：
1. EXT-obs_顧客名・代表者名同期_AFTER_REAL.txt　サイズ85,307 bytes　SHA256 1758B536A811C6DFDF5EAD19EF11F3DBC20FE5E7F0993B0B7A4E4A1DB5D7EFC9　反映元とのバイト差は改行・FileMaker再書き出し表現差のみ、意味的同一性PASS
2. EXT-obs_OBSノート-開く_AFTER_REAL.txt　サイズ37,091 bytes　SHA256 BDEDF8D4992B8966A60EE6F773287539C0E1962B10D035E0E58B1BC6DC5DF223　PreDeployとSHA256完全一致PASS、今回の反映作業による変更なし
3. EXT-obs_内部CallPS-PAYLOAD_AFTER_REAL.txt　サイズ9,610 bytes　SHA256 23A5645200DA9566244F6882EC82FDFB25E4A7E88E00B68CD1EFAF65816E5FC8　PreDeployとSHA256完全一致PASS、今回の反映作業による変更なし

FileMaker PreDeploy証跡（Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\FileMaker\PreDeploy）：
EXT-obs_顧客名・代表者名同期_BEFORE_REAL.txt　SHA256 1245EAD79F3BAC3DF31F89B891E9188DAAB01FE3F41ED838F5A5404FBD32223B
EXT-obs_OBSノート-開く_BEFORE_REAL.txt　SHA256 BDEDF8D4992B8966A60EE6F773287539C0E1962B10D035E0E58B1BC6DC5DF223
EXT-obs_内部CallPS-PAYLOAD_BEFORE_REAL.txt　SHA256 23A5645200DA9566244F6882EC82FDFB25E4A7E88E00B68CD1EFAF65816E5FC8

E2Eテスト顧客：
pk_CLIENT：2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1
NAME：【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後
CEO：検証次郎　RUBY：ｹﾝｼｮｳｼﾞﾛｳ　RANK1LYear：AA

重複安全停止E2E：
事前状態：同一UUID・同一noteType「契約」のMarkdownが2件（UUID付き正式ノート／UUIDなし旧ノート）
結果：エラーコードNOTE_TYPE_UUID_CONFLICT、FileMakerで既知エラー表示、書込前に安全停止、Vault内ファイル数・ファイル名・サイズ・SHA256は不変、新規Markdownなし、obs_RELPATH／obs_URLは旧値のまま
判定：PASS

正常系E2E準備：
UUIDなし旧ノートを削除せずVault外へ隔離
隔離先：Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\E2EQuarantine\2250BA49_PRE_NORMAL_E2E　SHA256 F7E82164E56A0EC33257D8D6A538863ACCF235360C4C2781E1C1D447D088F656
事前バックアップ：Diagnostics\RESOLVED_NOTES_FIX_20260730_WORK\E2EBackup\2250BA49_PRE_NORMAL_E2E
UUID付きノート事前SHA256：FF271EDF2CFC1B4CCAEA6B692B802D158D9D5AB41292BA85C8C27A8DA1F5269C
旧ノート事前SHA256：F7E82164E56A0EC33257D8D6A538863ACCF235360C4C2781E1C1D447D088F656

正常系E2E：
FileMakerのobs_RELPATH／obs_URLがUUIDなし旧ノートを指す状態で「契約」ノートを開く操作を実施
結果：エラーダイアログなし、UUID付き正式ノートが開いた、新規Markdownなし、対象UUID一致Markdownは1件、obs_RELPATHがUUID付き正式パスへ自己修復、obs_URLが正式パス対応URLへ自己修復、resolvedNotesによる既存正式ノート特定成功、重複ノート再生成なし
正式obs_RELPATH：01_顧客/【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後_[2250BA49]/🟨契約_【E2Eテスト_削除予定】FMOBS検証_20260729_変更後_[2250BA49].md
判定：PASS

正式ノートの改行正規化：
E2E前：238 bytes　LF　SHA256 FF271EDF2CFC1B4CCAEA6B692B802D158D9D5AB41292BA85C8C27A8DA1F5269C
E2E後：250 bytes　CRLF　SHA256 69B49D8F920F0FA215BE7A36FA73CBB266C46AE59A6FECA56E87D828702A21C0
差分：12改行のLF→CRLFによる+12 bytes。YAML値・tags・UUID・本文文字内容は不変
判定：Windows PowerShell 5.1での既知・許容される改行正規化

冪等性E2E：
正規化済み状態で同じ契約ノートを再実行
結果：エラーダイアログなし、同じUUID付き正式ノートが開いた、obs_RELPATH不変、obs_URL不変、Markdown件数1件、対象UUID一致1件、旧ファイル名再作成なし、関連新規Markdownなし、正式ノートサイズ250 bytesで不変、SHA256 69B49D8F920F0FA215BE7A36FA73CBB266C46AE59A6FECA56E87D828702A21C0で不変
判定：PASS

最終証跡インベントリ確認：
PreDeploy／PostDeploy／E2EBackup／E2EQuarantine配下の各ファイルのサイズ・SHA256を2026-07-31にread-onlyで再実測し、上記記載値と一致することを確認済み。

Git状態（read-only確認、2026-07-31）：
リポジトリ：<REPOSITORY_ROOT>
branch：main　HEAD：24cf1dc2b352edb855c5281954f481f91fe917ac　remote：なし
Working Tree：M FM-Obsidian-Bridge-Payload.ps1（今回反映分、未コミット）、M .gitignore（既知の改行差、実害なし）、untracked：FM-Obsidian-Bridge-Payload-JIKO.ps1_不要／FM-Obsidian-Bridge-Payload_PRE_20260730_BOM_FIX.ps1／FM-Obsidian-Bridge-Payload_REJECTED_20260730_ANTIGRAVITY.ps1（いずれも本トラックの作業過程で生成されたバックアップ／却下版で、無関係な変更ではない）
Git commit/push/add：未実施（要否は未決定、`06_TODO.md`参照）

次工程：
1. Project State文書更新内容レビュー
2. 必要に応じた文書補正
3. Snapshot／metadata再生成
4. 最終Project State Package作成
5. Package独立検証
6. ユーザー正式採用
7. 採用後にのみE2Eテストデータ後片付けを検討（テスト顧客・隔離ノート・バックアップ・PreDeploy/PostDeploy証跡は最終Package正式採用前には削除しない）

【2026-07-31 最終クローズ前更新】
第1回Package技術検証はPASSした。途中でmetadata欠落によるV1のFAILと退避が発生したが、V2修正版PackageでPASSを確認した（SHA256 DCD2699E7B043FE58444F26EA8E65DE7FBF7D015D9020F45067F097036ABD3A8）。しかし、Package作成前を示す陳腐化した記述が各文書に残存していたため、最終クローズ更新が必要となった。現在のPackageは最終クローズ前の候補である。
次工程：
1. 最終クローズ更新後の6文書レビュー
2. 更新後Snapshot／metadata／Package再構築
3. 更新後Packageの独立検証
4. ユーザーによる正式基準Package採用
5. 正式採用後にGit commit/push要否を判断
6. 正式採用後に後片付け（E2Eデータ、隔離物、バックアップ、V1/V2ステージング、不合格ZIP、旧build_package.ps1等）を判断

実装開始ゲート（noteType体系トラック）：
CLOSED（本トラックの完了は当該ゲート判定に影響しない）

## 【2026-07-31 最終文書レビューPASS・Package再構築前状態固定】
- 最終クローズ6文書更新後、第1回レビューで4文書の修正事項を検出
- 限定再修正過程で追加破損を検出
- 2文書の状態ドリフトをread-onlyで特定
- 2文書4箇所を限定修復
- 06_TODO重複見出しを限定除去
- 更新済み6文書の最終read-onlyレビューPASS
- 6文書SHA256完全一致
- 00_PROJECT_STATUSは24,544 bytes
- 04_REVIEW_LOGは更新前33,181 bytes
- Git未追跡3ファイルは通常の未追跡として確定
- .gitignoreはGit正規化後の差分なし
- Phase 6-G-3総合PASS

次工程：
1. 最終Snapshot／metadata再生成
2. 最終Package再構築
3. 再構築後Package独立検証
4. ユーザー正式採用
5. 採用後Git判断
6. 採用後後片付け判断
```
