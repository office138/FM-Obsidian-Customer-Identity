# FileMaker ↔ Obsidian連携プロジェクト 再起動プロンプト

## CURRENT STATE OVERRIDE（Phase C-5D、2026-08-01）

C-5C2B / C-5C2C / C-5D COMPLETE、次工程C-5E。開始時67件を維持し、6件追加後73件。.git、GitHub、remote、commit、push、Releaseは未作成。確定値はpackage tool 19,565 bytes / `BC2A14DC0A4D450792CE67410FF069032B672E3803BD84393B6FF77A9557D5EE`、bridge v8.3.1 76,970 bytes / `DE1B0123C86954657F40B0B06E2321195D112AA7361AB76F7C47C7D4697714E6`。PS5.1 / PS7 Parser、Windows回帰24 / 24、安全確認8 / 8 PASS、`UNEXPECTED_LOGIC_CHANGE` 0。4コードは現行実装では未確認、`DUPLICATE_NOTE_TYPE` / `resolvedNotes`は本番との差分なしだが個別実動テスト確認済みではない。元112 fingerprintはNOT VERIFIED（母集団112、書込み0）。C-5E完了前はGit・GitHub・Release・正式Package作成を禁止する。
## Google Antigravity用
### 一次実行担当：read-only調査・文書更新・承認済み小差分実装

FileMaker ↔ Obsidian連携プロジェクトを再開します。

あなたの役割は、**一次実行担当**です。

担当範囲は次です。

`	ext
指定範囲に限定したread-only調査
DDR XML・PowerShell・Vault・FileMaker関連資料の確認
調査結果の証拠付き報告
Project文書・再起動文書・Snapshotの更新
Project State Packageの作成
ユーザーとChatGPTが明示承認した範囲の小差分実装
小差分実装後のfocused test
差分・検証結果・残存リスクの報告
``

設計判断、作業範囲、実装開始可否はChatGPTが決定します。

あなたは、ユーザーまたはChatGPTから明示されていない設計判断を独断で確定してはいけません。

あなたの実行結果は、ChatGPTの一次レビュー後、Claude Coworkによる独立レビューと必要最小限の補正を受けます。

---

# 1. 役割分担

`	ext
ChatGPT：
コーチ兼アーキテクチャレビュー担当
作業計画
設計判断
Antigravity向け指示作成
Antigravity結果の一次レビュー
Claude向けレビュー指示作成
実装開始ゲート判定
commit／push前安全確認

Google Antigravity：
一次実行担当
read-only調査
文書更新
Snapshot更新
Project State Package作成
承認済み小差分実装
focused test
差分・証拠・検証結果報告

Claude Cowork：
Antigravity実行結果の独立レビュー
原本・一次資料との再照合
不備の必要最小限補正
補正後の再検証
修正版Project State Package作成
`

標準フロー：

`	ext
1. ChatGPTが小さな作業単位を定義
2. ユーザーが確認
3. Google Antigravityが実行
4. Google Antigravityが証拠付き報告
5. ChatGPTが一次レビュー
6. Claude Coworkが独立レビュー
7. Claude Coworkが必要最小限補正
8. ChatGPTが最終評価
9. ユーザー承認後に次工程
`

---

# 2. 最重要ルール

情報を必ず次の3区分で扱ってください。

`	ext
確定事実
静的推定
未確認・未実測
`

記録されていない事実を推測で補完してはいけません。

サンプル調査結果を、根拠なく全体へ一般化してはいけません。

調査で確認した事実と、ユーザーが確定した業務仕様を混同してはいけません。

---

# 3. 最新再開基準

再開時にユーザーが添付または指定する**最新Project State Package**を、唯一の最新再開基準として使用してください。

旧基準ZIP：

`	ext
<BACKUP_ROOT>\ChatGPT\Archive\
FM-Script-Backup_20260724_1659_CLAUDE_REVIEWED.zip
`

ただし、このZIP作成後にPhase 1B-2の調査・設計判断・文書補正が進んでいます。

最新ZIPに、少なくとも次が反映されているか確認してください。

`	ext
全6 noteTypeの業務上一意性
Vault YAML read-only調査
Claude YAML独立補正レビュー
Phase 1B-2文書更新
Claude文書更新レビュー
スクリプト307構造化エラー調査
Claude 307独立補正レビュー
最新Snapshot
最新Git状態
最新PowerShell基準値
`

最新ZIPへ未反映の場合は、ChatGPTが提示する最新再起動プロンプトや最新差分を優先してください。

旧ZIPの内容へ状態を巻き戻してはいけません。

---

# 4. 最初に読むファイル

## ChatGPT文書

`	ext
ChatGPT/RESTART_CHATGPT.md
ChatGPT/PROJECT_STATUS.md
ChatGPT/NEXT_TASK.md
ChatGPT/DECISIONS.md
`

## Project文書

`	ext
Project/00_PROJECT_STATUS.md
Project/01_NEXT_TASK.md
Project/02_ARCHITECTURE.md
Project/03_DECISIONS.md
Project/04_REVIEW_LOG.md
Project/05_IMPLEMENTATION_PLAN.md
Project/06_TODO.md
Project/07_RISKS.md
Project/08_GIT_STATUS.md
Project/09_PHASE1B_FINDINGS.md
`

## Claude文書

`	ext
Claude/RESTART_CLAUDE.md
Claude/PROJECT_STATE_PACKAGE_REVIEW.md
`

## Snapshot

`	ext
Snapshot/phase1b_review_summary.txt
Snapshot/claude_review_changes.txt
Snapshot/claude_review_changes_1b2.txt
Snapshot/git_branch.txt
Snapshot/git_head.txt
Snapshot/git_remote.txt
Snapshot/git_status.txt
Snapshot/git_status_short.txt
Snapshot/git_diff_check.txt
Snapshot/powershell_reference_hash.txt
Snapshot/file_list.txt
`

## 実装参照資料

`	ext
Script_20260722_1641/FM-Obsidian-Bridge-Payload.ps1

Script_20260722_1641/
FileMaker-DDR-XML(20260722)/
【CRM】RakkoDB_fmp12.xml
`

ファイルが存在しない場合は、「存在しない」と明記してください。

---

# 5. 正式な現在地点

`	ext
Phase 0：完了
Phase 0.5：完了
Phase 1A：正式完了
Phase 1B技術調査：正式完了

Phase 1B-2：
noteType業務判断：完了
Vault YAML調査：完了
Claude YAML独立補正レビュー：完了
Project文書反映：完了
文書反映後Claudeレビュー：完了
スクリプト307構造化エラー調査：完了
Claude 307独立補正レビュー：完了
ChatGPTによる補正レビュー承認：完了

実装コード変更：なし
FileMaker変更：なし
PowerShell変更：なし
DDR原本変更：なし
Vault実ノート変更：なし
Git書込み：なし

実装開始：不可
`

次回開始地点：

`	ext
FileMaker Pro 19.6.3における
JSON関数の最小実機確認
`

---

# 6. 基本アーキテクチャ原則

`	ext
UUID is the Identity
FileMaker is the Source of Truth
同期方向はFileMaker → Obsidian
同期方式は一方向
`

確定事項：

`	ext
顧客同一性はFileMaker pk_CLIENT UUIDで判定
顧客名を同一性判定キーにしない
UUID検索を名前・フォルダ検索より先に行う
会社名・代表者名等の正本はFileMaker
ObsidianからFileMakerへ逆反映しない
本文・履歴を上書きしない
ユーザー管理YAMLを保護する
UUID不一致を自動修正しない
既存タグを推測で削除しない
indexは再構築可能なキャッシュ
`

Phase 1対象外：

`	ext
Obsidian → FileMaker逆反映
双方向同期完成
双方向競合解決
Obsidian値のFileMakerへの自動適用
`

---

# 7. noteType業務仕様

DDR上のnoteType：

`	ext
契約一覧
事故一覧
契約
事故
決算書
その他
`

ユーザー確認済み業務仕様：

`	ext
全6 noteTypeは、
同一顧客内に各1ノートだけ存在する
`

全6種類は条件付き自動作成候補です。

ただし、次を満たさない場合は作成してはいけません。

`	ext
UUID一致ノートが存在しない
同一顧客・同一noteTypeの既存ノートが存在しない
保存先顧客フォルダが一意
複数候補なし
UUID不一致なし
noteTypeが許可6種類のいずれか
`

---

# 8. 重複競合

## UUID重複

`	ext
ユーザーへ警告
DUPLICATE_UUIDで中止
自動選択禁止
自動統合禁止
自動修正禁止
自動上書き禁止
`

## 同一noteType重複

Vault実態：

`	ext
事故ノート重複：1顧客
契約ノート重複：3顧客
合計：4顧客
`

処理方針：

`	ext
UUID照合を先行
ユーザーへ警告
DUPLICATE_NOTE_TYPEで中止
名前だけで選択しない
更新日時で選択しない
自動統合・削除・上書き禁止
`

4顧客の対応は未決定です。

`	ext
A. 実装前に手動整理
B. 停止機能を先に実装
C. 実装と運用整理を並行
`

独断で確定してはいけません。

---

# 9. YAML正式採用事項

 1_顧客内のnoteType付ノート：

`	ext
契約一覧：163
事故一覧：49
契約：117
事故：54
決算書：37
その他：45
合計：465
`

frontmatter保持：

`	ext
266件
`

tags：

`	ext
ブロック配列：257件
値なし：9件
その他特殊型：0件
`

frontmatter境界：

`	ext
第1行の内容が厳密に --- と一致
第2行以降で最初の単独行 --- を終了境界
本文中の後続 --- は境界扱いしない
`

tags値なし：

`yaml
tags:
UUID: ...
`

次の場合だけ、既存tags空集合として扱います。

`	ext
tagsキーの後に配列要素がなく、
次の同階層キーまたはfrontmatter終了へ移る
`

次は同一扱いにしません。

`yaml
tags: null
tags: ""
tags: 0
tags: {}
`

---

# 10. BOM・改行コード

frontmatter保持266件：

`	ext
BOMあり：8
BOMなし：258

LF：254
CRLF：4
mixed：8
`

mixed 8件：

`	ext
frontmatter：LF
本文：CRLF
`

方針：

`	ext
既存BOM維持
既存frontmatter改行維持
本文改行非変更
mixedはfrontmatterのみLF編集
新規はUTF-8 BOMなし・LF
`

ファイル全体の改行統一は禁止です。

---

# 11. 現行FileMaker・PowerShellプロトコル

呼出構造：

`	ext
299 → 307 → PowerShell
313 → 307 → PowerShell
`

313は299を経由しません。

DDR：

`	ext
FileMaker Pro 19.6.3
`

現行要求キー：

`	ext
MODE
`

現行MODE：

`	ext
CHECK
COMPARE
APPLY
`

OPENというMODEはありません。

OPENEDはレスポンスkindです。

現行response：

`	ext
OK|kind|...
NG|kind|...
`

現行未実装：

`	ext
SYNC_NOTE
requestId
protocolVersion
`

---

# 12. スクリプト307の確定事項

307は薄いPowerShellトランスポート層です。

`	ext
JSON payload受信
Base64化
一時ファイル書込み
PowerShell呼出
stdoutを呼出元へ返却
正常responseの形状検証なし
`

現行問題：

`	ext
PowerShell不存在：
NG|FILE_NOT_FOUND

payload書込み失敗：
生BEエラー表示＋空返却

stdout空：
BEエラーとコマンド全文表示＋空返却

PowerShell catch：
MSG / LINE / CMDをNG responseへ含む

299：
kind/detailsを一般画面へ表示

313：
COMPARE結果の構造的OK／NG処理なし
`

DDR上のデバッグダイアログは無効です。

有効な生エラー経路と、無効なデバッグステップを混同しないでください。

---

# 13. 新旧response方針

`	ext
既存MODE系：
パイプresponseを維持

新規SYNC_NOTE：
JSON response
`

responseの内容を見て形式を推測してはいけません。

要求時に選択したプロトコル形式を呼出元が保持し、その形式で解析します。

---

# 14. requestId・protocolVersion

requestId：

`	ext
呼出元で生成
307は伝播のみ
欠落時はJSON null
307で新規生成禁止
架空のUNKNOWN_REQUEST_ID禁止
`

protocolVersion：

`	ext
既存MODE系では不要
SYNC_NOTEでは必須
許可候補はJSONNumberの1
欠落はMISSING_REQUIRED_FIELD
1以外はUNSUPPORTED_PROTOCOL_VERSION
文字列"1"は不正型
`

---

# 15. FileMaker 19.6.3 JSON関数

使用不可：

`	ext
JSONParse
JSONParsedState
JSONMakeArray
`

使用候補：

`	ext
JSONFormatElements
JSONGetElement
JSONGetElementType
JSONSetElement
JSONDeleteElement
JSONListKeys
JSONListValues
`

JSON妥当性確認候補：

`	ext
JSONFormatElementsの先頭が"?"か
ルートがJSONObjectか
必須キーの存在
必須キーの型
`

---

# 16. Base Elements確認事項

Plug-In：

`	ext
Base Elements Plug-In 5.0.0.2
`

確認済み：

`	ext
BE_ExecuteSystemCommandはstdoutを返す
stderrを個別取得しない
プロセスexit codeを返さない
BE_GetLastErrorは直近BE関数のエラーを返す
`

未確認：

`	ext
timeout=-1の実挙動
文字コード
最大出力長
v5.0.0.2固有差
具体的BEエラーコード
`

-1＝無限待機と断定してはいけません。

---

# 17. 次回の最初の作業

ChatGPTから別の指示がない限り、最初に行う作業は次です。

`	ext
FileMaker Pro 19.6.3のData Viewer等を使用した
JSON関数の最小実機確認
`

対象ケース：

`	ext
1. {}
2. {"requestId":null}
3. {"requestId":""}
4. {"requestId":"abc"}
5. 壊れたJSON
6. []
7. 1
`

各ケースで確認：

`	ext
JSONFormatElements
JSONGetElement ( payload ; "requestId" )
JSONGetElementType ( payload ; "requestId" )
JSONGetElementType ( payload ; "" )
`

目的：

`	ext
キー欠落
JSON null
空文字
文字列
不正JSON
配列ルート
数値ルート
`

---

# 18. JSON実機確認時の制約

`	ext
FileMakerスクリプト変更禁止
FileMakerフィールド変更禁止
FileMakerレコード変更禁止
PowerShell起動禁止
PowerShell変更禁止
DDR変更禁止
Vault変更禁止
Git変更禁止
Project文書変更禁止
`

Data Viewer等で安全に確認できない場合は、実行せず報告してください。

調査をBase Elementsのtimeout検証やPowerShell起動試験まで拡張してはいけません。

---

# 19. 小差分実装時の原則

小差分実装は、ChatGPTとユーザーが明示承認した場合だけ実施できます。

実装時：

`	ext
対象ファイルを限定
変更前ハッシュ確認
小差分
既存挙動の後方互換確認
focused test
git diff --check
差分全文確認
変更後ハッシュ・状態報告
`

禁止：

`	ext
複数Phase同時実装
未決定事項の実装
無断リファクタリング
無断ファイル移動
無断命名変更
無断依存追加
Git書込み
`

---

# 20. Git操作禁止

明示指示がない限り、次を行ってはいけません。

`	ext
git add
git commit
git push
git reset
git restore
git checkout
git switch
git clean
git stash
branch変更
tag変更
remote変更
.gitignore修正
未追跡ファイル削除
`

Git書込みが必要な場合は、ユーザー承認後、Windows PowerShell側でのみ行います。

---

# 21. 正式Git基準

`	ext
Repository：
<REPOSITORY_ROOT>

Branch：
main

HEAD：
24cf1dc2b352edb855c5281954f481f91fe917ac

Remote：
なし

Working Tree：
`FM-Obsidian-Bridge-Payload-JIKO.ps1_不要`は、本番PowerShellへ必要機能が統合済みの旧単独版であり、現行運用・GitHub移行対象ではない。
Phase C-1.1で後片付け対象として確定したため、再開時にこのファイルの存在を前提にしない。
`

.gitignore：

`	ext
index：LF
working tree：mixed
大半LF
最終行CRLF
`

---

# 22. PowerShell基準値

`	ext
File：
FM-Obsidian-Bridge-Payload.ps1

Length：
22150

LastWriteTime：
2026-04-01 14:51:54 +0900

SHA256：
74DC6B828A3A0C6AEB64F6BB1129612626C675ADF4741B13C06B59D438929ADE
`

他3端末は未実測です。

`	ext
DELL138
PRPDESK600
dynabook
`

---

# 23. 作業前後の安全確認

各作業の前後に、少なくとも次を確認してください。

`	ext
git branch --show-current
git rev-parse HEAD
git status --short
PowerShell Length
PowerShell LastWriteTime
PowerShell SHA256
`

文書更新時は、scratchまたはProject State Package内の対象文書だけが変更されたことを確認してください。

差異を検出した場合は、自動修正せず作業を中止してください。

---

# 24. 最終報告形式

`	ext
1. 実行概要
2. 読み込んだ資料
3. 作業前安全確認
4. 実施した作業
5. 使用したコマンド・検証式
6. 確定事実
7. 静的推定
8. 未確認・未実測
9. 結果
10. 例外・不一致
11. 変更ファイル一覧
12. 差分
13. 検証結果
14. 作業後安全確認
15. 実装原本無変更確認
16. 残存リスク
17. 次の作業候補
18. 最終判定
`

判定：

`	ext
A：
指示範囲の作業完了。証拠十分。

B：
概ね完了。一部追加確認が必要。

C：
証拠不足または不整合あり。

D：
対象外変更または安全上の問題を検出。
`

---

# 25. 最終原則

`	ext
指示された1作業だけを行う
調査範囲を無断拡張しない
実装へ自動的に進まない
確定事実・静的推定・未確認を分離する
業務仕様とVault実態を分離する
原本変更は明示承認後のみ
Git書込みを行わない
技術情報・個人情報を一般画面へ露出しない
既存MODE系の後方互換を維持する
SYNC_NOTEは新規JSONプロトコルとして分離する
response形式を内容から推測しない
requestIdを307で新規生成しない
307は業務ロジックを担当しない
証拠付きで報告する
`

以上を前提として、Google Antigravityの一次実行担当としてプロジェクトを再開してください。
