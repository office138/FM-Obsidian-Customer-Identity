# 07_RISKS

Phase 1B read-only調査完了・承認（2026-07-24）を受けてリスク表を更新。

| 重大度 | リスク内容 | 根拠 | 影響 | 推奨対応 / 解消方針 |
|---|---|---|---|---|
| 高（Phase 1B確認） | 現行307が生の技術情報（`BE_GetLastError`、実行コマンド全文、Vaultパス）を診断ダイアログで一般利用者へ表示する | DDR 307 Line 36, 50 | 障害発生時に一般画面へ技術情報・内部パスが露出する。 | SYNC_NOTE経路は新規 `EXT-obs_内部CallPS-SYNC-NOTE` へ分離し一般responseへ内部技術情報を含めない。既存307のlegacyダイアログ露出は後方互換上の残存リスクとして別途改修判断する。新規 `EXT-obs_内部CallPS-SYNC-NOTE` がtransport自身の7エラーを最小構造化JSONで返し、呼出元requestIdの参照・正規化・一致検証を行う |
| 高（Phase 1B確認） | 現行 `Update-Yaml-Robust` が `tags:` 配列を丸ごと置換するためユーザー独自タグが消える。またインラインコメントも消去される | ps1 Line 222-237 | 運用中のVaultで手動追加した独自タグや注記コメントが同期のたびに消失する | 決定③および残存②に基づき、`tags` 差分更新（`既存 - 既存fm_managed_tags + 今回管理タグ`）と `fm_managed_tags` 所有権管理を採用する |
| 高（Phase 1B確認） | 現行 `Update-Yaml-Robust` にYAML構文検証がなく、`---` 境界不正時にファイル全体が本文扱いとなりYAMLが二重挿入されるリスクがある | ps1 Line 209-215 | frontmatter崩れを起こしたノートのYAMLが破壊・増殖する | `Update-Yaml-Robust` 冒頭で境界・構文チェックを行い、不正時は `INVALID_YAML` / `INVALID_MANAGED_TAGS` で実更新前に安全に中止する |
| 高（新規） | 個別系noteType（契約/事故/決算書/その他）の自動作成を許可した場合、同名ファイルを区別できず重複ノートが増加するリスク | Phase 1B調査。ファイル名規則に固有IDが含まれない | 同一顧客内で複数契約・事故がある場合に誤ったファイルへの上書きや無駄な新規作成が発生する | noteTypeごとの業務上自動作成可否を個別に切り分け、一意性が保証されないnoteTypeは `NOTE_NOT_FOUND` とする |
| 中 | FileMaker側（299）に残るCHECK/APPLYコードの未整理残存 | Step 0-2 | 保守性低下・将来改修時の混乱リスク | Phase 1Hで整理方針を実行する。それまではドキュメント記述で誤認を防止する |
| 中 | 他3端末（DELL138、PRPDESK600、dynabook）のPowerShellファイルSHA256が未実測 | 1端末のみ実測 | 未実測の端末で異なるスクリプトが動作していた場合に改修が反映されないリスク | 実装着手前に4端末全てでSHA256を実測し一致を確認する。「未確認の運用前提」として全関係者に周知する |
| 中 | 313番（突合）がPowerShellのNG応答をハンドリングせずそのまま終了する | DDR 313 Step 130-135 | 突合エラー発生時に現場が気づかない可能性がある | 新規transportの導入に伴い、313番でのNG応答ハンドリング要否をPhase 1Hで個別に判断する |
| 高 | rename処理が途中で失敗した場合の部分更新 | Phase 1E設計対象 | ノートが行方不明になるリスク | 疑似トランザクション設計（manifest→バックアップ→rename→検証→ロールバック）を採用する |
| 高 | Obsidian側での手動編集が次回同期でFileMaker値により上書きされる | 一方向同期方針の帰結 | ユーザーの編集内容が消えるトラブル | 対象フィールドの運用上書き方針を周知する。【Phase 1B-3決定前の状態】UUIDについては、承認済み文書間に「FileMaker値で上書き」「照合なしで上書き」と「UUID不一致時は自動上書きせずエラー停止」が併存していたため、UUID一致後の同一値再記録、UUID欠損時の移行、UUID不一致時の停止を区別し、正本文書間の不整合が解消されるまで実装しない方針としていた。【2026-07-26現在】`03_DECISIONS.md`／`02_ARCHITECTURE.md`／`05_IMPLEMENTATION_PLAN.md`の3文書間ではUUID記述の不整合は設計上解消済み。その他の関連文書への伝播および現行PowerShellへの実装は未完了。詳細は「Phase 1B-3 UUID関連残存リスク」節を参照 |
| 高（Phase 1B-2確定） | 同一顧客・同一noteTypeの重複ノートが存在するリスク | Vault実態調査で4顧客（事故1顧客、契約3顧客）に業務仕様違反の重複ノートが存在 | 同一顧客内で誤ったファイルへの上書きや予期せぬ新規作成が発生する | 候補が複数存在する場合は `DUPLICATE_NOTE_TYPE` で警告を表示し処理中止する。自動選択・統合・削除・上書きは行わない。システムの安全停止仕様は確定済みだが、既存の重複4顧客を業務上どのように整理するかは未決定。【2026-07-26現在】`DUPLICATE_NOTE_TYPE`検出仕様は設計上確定済み。現行PowerShellへの実装は未完了。既存4顧客の運用整理方針は未決定。詳細は「Phase 1B-3 UUID関連残存リスク」節を参照 |
| 高（Phase 1B-2確定） | 同一UUIDを持つノートが複数存在するリスク | 過去手動操作等でのUUID重複発生 | 誤った顧客ノートを更新・汚染するリスク | 候補が複数存在する場合は `DUPLICATE_UUID` で警告を表示し処理中止する。【2026-07-26現在】`DUPLICATE_UUID`検出仕様は設計上確定済み。現行PowerShellへの実装は未完了。詳細は「Phase 1B-3 UUID関連残存リスク」節を参照 |
| 高（Phase 1B-2確定） | 顧客名変更時に別ノートが新規作成されるリスク | 名前起点の検索に依存した場合 | 社名変更時に既存ノートが放置され、新規ノートが重複作成される | 顧客同一性を `pk_CLIENT` UUIDで判定し、UUID検索を優先して既存フォルダ・ノートを特定してrename処理する。【2026-07-26現在】UUID優先検索およびmigration候補・競合候補が存在する場合の新規作成禁止は設計上確定済み。現行PowerShellは名前検索のみで、UUID検索・UUID状態判定・新規作成禁止条件はいずれも未実装。詳細は「Phase 1B-3 UUID関連残存リスク」節を参照 |
| 高（Phase 1B-2確定） | ファイル全文再書き込みによる本文改行コード誤変換リスク | Vault実態調査で 8件が mixed 改行（frontmatter:LF / 本文:CRLF） | ノート本文・履歴欄の改行コードが不必要に変更される | 既存BOM・frontmatter内改行コードのみを検知して維持し、本文の改行コードには一切変更を加えない。ただしfrontmatter内部で複数種類の改行が混在する異常ケースの最終対応は未決定であり、本項の維持方針だけでは確定していない |
| 高（Phase 1B-2確定） | 本文中の `---` 水平線による frontmatter 境界誤認リスク | Vault実態調査で 257件のノート本文中に `---` 行が存在 | frontmatter 範囲を誤認して本文の一部を YAML として解析・改変するリスク | 第1行の内容が厳密に `---` と一致する場合のみ開始境界とし、第2行以降で最初に現れる単独行 `---` を終了境界とする厳格規則により境界を一意決定する（本文中の後続 `---` は境界扱いしない） |
| 中（Phase 1B-2確定） | `tags:` 直後に値がない形式（9件）の処理エラー | Vault実態調査で `tags:\nUUID:...` 形式が 9件確認された | `INVALID_YAML` として誤検出され正常ノートが更新拒否されるリスク | `tags:` 直後に値がない場合は既存タグ集合が空である状態として扱う仕様を採用し、`INVALID_YAML` にはしない |
| 低 | `.gitignore` の未ステージ差分が環境・実行条件により検出されたりされなかったりするリスク | 2026-07-26 Claude Cowork再実測および承認済み `Project/08_GIT_STATUS.md` | Git状態の誤認や、不用意なrestore・改行正規化につながる可能性 | 今回の差分は1行追加・1行削除として認識され、対応する可視文字列は同一。最終行付近の改行状態に由来するとみられるが原因は未確定であり、`core.autocrlf`単独を原因と断定しない。checkout／restore／Git設定変更／改行正規化はユーザー明示承認なしに行わない。現行Snapshotおよびmanifest／checksumはstaleであり、次期Package作成時に最新実測値から再生成・独立検証する |



## Phase 1B-2 追加リスク (2026-07-25)
| リスク | 回避策・検証方法 | 残存リスク |
|---|---|---|
| `Write-Host`によるJSON stdout汚染 | PowerShell側でSYNC_NOTE経路内の`Write-Host`を禁止 | サードパーティモジュール等からの意図せぬ標準出力混入 |
| SYNC_NOTE経路が `Assert-ObsidianReady` を通過するリスク | SYNC_NOTE分岐を `Assert-ObsidianReady` より前に配置 | 分岐判定の記述ミスによる通過 |
| 既存PIPE出力関数を誤利用するリスク | SYNC_NOTE専用のJSON出力関数を導入し、PIPE関数利用を禁止 | レビュー漏れによる誤利用 |
| stdout非JSON時の誤受理 | FileMaker側で `JSONGetElementType = 3` を必須検証 | FileMakerのJSON解析仕様に依存するエラー文字混入 |
| FileMaker 19.6.3で利用できないJSON関数を設計・実装へ使用するリスク | `JSONParse`／`JSONParsedState`／`JSONMakeArray`を使用せず、実機で利用可能な既存JSON関数だけで設計する | 実装レビューで非対応関数を見落とす可能性 |
| response requestId不一致 | FileMaker側で送信値と受信値の一致検証を必須化 | なし |
| FileMaker transport生成codeとPowerShell生成codeの責務混同 | FileMaker transport自身の7code、PowerShell入口層の2code、業務処理codeを生成層ごとに分離し、有効なPowerShell業務responseをFileMaker transportで再解釈しない | 実装・レビュー時に生成層を取り違える可能性 |
| 一時ファイル孤児化 | 正常時はPS側で、起動失敗系はFM側で削除を徹底 | 強制終了時の残留（運用上の致命傷にはならない） |
| cleanup失敗が主エラーを上書きするリスク | cleanup失敗時も最初に発生した主エラーを維持し、cleanup失敗の内部技術情報を一般responseへ含めない | 強制終了等では一時ファイルが残留する可能性 |
| Base64平文に業務情報が残留するリスク | 一時ファイルは実行後即座に削除 | セキュリティ上の情報露出（一時的） |
| requestIdをファイル名へ利用するパストラバーサル／禁止文字リスク | requestIdを一時ファイル名に使用せず、FM内部UUIDを利用 | なし |
| 同一PowerShell改修による既存MODE系回帰 | SYNC_NOTE早期分岐とし、既存経路への影響を局所化。focused test実施 | 影響の完全な遮断は不可能 |
| UUID書込み・不一致時処理に関する承認済み文書間の不整合 | UUID一致後の同一値再記録、UUID欠損時の移行、UUID不一致時の停止を区別し、正本文書間の記述を実装前に統一する | 【2026-07-26現在】`03_DECISIONS.md`／`02_ARCHITECTURE.md`／`05_IMPLEMENTATION_PLAN.md`の3文書間では設計上解消済み。本ファイルへの伝播はPhase 1B-3残存リスク節の追加により完了する。その他の関連文書への伝播および現行PowerShellへの実装は未完了であり、実装開始ゲートは閉鎖中。詳細は「Phase 1B-3 UUID関連残存リスク」節を参照 |
| 未決定事項6件目「実装時の詳細な内部ログ方式」が決定正本へ未登録であるリスク | `Project/04_REVIEW_LOG.md`補正時または決定正本への追加要否レビュー時に判断し、現時点では削除・確定しない | 実装時にログ内容や保存先を独断決定する可能性 |
| 文書更新時のBOM・改行一括変換 | ツールによる更新時に改行コードLF・BOMなしUTF-8を明示指定 | 編集環境依存による再発 |
| 正規表現一括置換による過剰削除 | 置換対象を限定し、手動またはスクリプトによる更新後全文検証を実施 | 予期せぬマッチによる情報欠落 |
| `.gitignore` EOL差に対して不用意なrestore／改行正規化を行うリスク | checkout／restore／Git設定変更／改行正規化はユーザー明示承認なしに行わず、可視文字列・EOL・Git実測を分離して記録する | 環境差により`M`表示が再発する可能性 |
| staleなmanifest／checksumを正式証跡として誤使用するリスク | Snapshot物理整理後にfile_list／manifest／checksumを正式再生成し、次期Packageを独立検証するまでは未承認・stale扱いを維持する | 過去Packageを現行承認済みPackageと誤認する可能性 |
| SnapshotのADD対象欠落またはEXCLUDE対象混入リスク | 次期Package対象集合へADD 2件／EXCLUDE 4件を物理反映し、file_list／manifest／checksumで個別照合する | 物理整理または再生成手順の漏れ |

## Phase 1B-3 UUID関連残存リスク（2026-07-26）

正本文書間のUUID記述不整合は `03_DECISIONS.md` ／ `02_ARCHITECTURE.md` ／ `05_IMPLEMENTATION_PLAN.md` の3文書では設計上解消済みである（2026-07-26）。本節は、設計上解消済みの事項と、なお残存する文書伝播・実装・詳細設計・運用整理の各リスクを区別して記録する。上表の該当行は削除せず、本節への参照注記のみを追加する。

| # | 残存リスク | 主分類 | 副分類 | 現在状態 | 解消条件 |
|---|---|---|---|---|---|
| 1 | UUID仕様の他文書への伝播未完了 | DOCUMENT_PROPAGATION_PENDING | ー | `03_DECISIONS.md`／`02_ARCHITECTURE.md`／`05_IMPLEMENTATION_PLAN.md`に加え、本`07_RISKS.md`への反映は本節により完了する。その他の関連文書への伝播は未完了 | 残存する関連文書を個別turnで確認・反映する |
| 2 | 現行PowerShellの名前検索・UUID無条件上書き・UUID状態判定未実装 | IMPLEMENTATION_PENDING | ー | UUID検索が未実装で名前検索のみに依存し、`Update-Yaml-Robust`がUUIDを無条件上書きする。UUID一致・欠損・不一致・重複のいずれも判定しない | Phase 1C実装完了・focused test合格 |
| 3 | UUID関連4codeの実装未完了 | IMPLEMENTATION_PENDING | `DUPLICATE_UUID`／`DUPLICATE_NOTE_TYPE`／`UUID_MISMATCH`／`UUID_MIGRATION_REQUIRED` | 4code全て仕様確定済みだが現行PowerShellには未実装 | 4code全ての実装およびcode別focused test合格 |
| 4 | `MIGRATE_UUID`のpayload構造・FileMaker側起動UI・ユーザー確認済みフラグ形式・response構造が未決定 | DETAIL_DESIGN_PENDING | `MIGRATE_UUID` | `03_DECISIONS.md`未決定事項6件目として記録済みだが内容は未確定 | ChatGPT・ユーザーによる詳細仕様の確定 |
| 5 | `MIGRATE_UUID`実行前のsnapshot／journal／rollback詳細未決定 | DETAIL_DESIGN_PENDING | `MIGRATE_UUID` | 形式・保存先・復旧手順のいずれも未確定 | ChatGPT・ユーザーによる詳細仕様の確定 |
| 6 | index再構築タイミング・専用code・自動再構築可否・運用通知方法未決定 | DETAIL_DESIGN_PENDING | index | indexを判定・修復根拠にしない原則のみ確定済み。再構築運用の詳細は未確定 | 別途運用設計の確定 |
| 7 | 既存4顧客（事故1顧客、契約3顧客）のduplicate noteType運用整理方針未決定 | OPERATIONS_PENDING | ー | システム側の安全停止仕様は確定済みだが、既存データの業務整理方針（事前整理／停止機能先行／並行対応／別案）は未確定 | ユーザー・現場側での運用整理方針の確定 |
| 8 | migration候補または別UUID競合候補が存在する場合の新規作成禁止が未実装 | IMPLEMENTATION_PENDING | ー | 5条件充足時のみ新規作成を許可する設計は確定済みだが、現行PowerShellは条件判定なしで新規作成する | Phase 1C実装完了・focused test合格 |
| 9 | noteType内部コード体系が設計書第6章（`DESIGN_V4_1`、5コード）と現行6表示値（`CURRENT_OPERATIONAL_FACT`、Vault実在465件）で未確定（2026-07-26追加） | DETAIL_DESIGN_PENDING | noteType | 「契約」「事故」（自由記述ログ計171件）の受け皿が設計書に存在しない。ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）は`USER_DECISION_PENDING` | ユーザー・ChatGPTによるnoteType体系の正式決定 |

> 【2026-07-26 SUPERSEDED】旧記述「文書伝播、`MIGRATE_UUID`詳細設計、既存データ運用整理、現行PowerShell／FileMaker実装が未完了であるため、実装開始ゲートは閉鎖中」は、Phase 1B-3基準Packageの作成・独立検証・正式基準採用が完了した現在では理由として不正確であり、下記に置き換える。
> Phase 1B-3の基本UUID方針は設計判断済みである。実装開始ゲートは閉鎖中である。理由：noteType体系が未決定／内部コードが未承認／将来予約コードの扱いが未決定／第24章No.5／10／14／16が未決定／設計書Version 4.2改訂方針が未承認（2026-07-26追加）。
>
> **2026-07-26追加**：設計書原本（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）を再取得した結果、noteType内部コード体系（上表9番）・設計書第24章Phase1関連4項目（No.5/10/14/16）・既存465ノートの`managed_by`未反映（0件）という3つの追加ブロッカーが判明した。Phase 1B-3基準Package（2026-07-26作成）は作成・独立検証・正式基準採用済みであり、上表「staleなmanifest／checksumを正式証跡として誤使用するリスク」行の「過去Packageを現行承認済みPackageと誤認する可能性」は当該基準Packageに関しては解消済みである。noteType実態調査後の新Packageについては同リスクが引き続き適用される。Project State文書12件は本補正の反映対象である。

> **2026-07-27追加**：noteType実態調査後の新Project State Package（`FM-Script-Backup_20260727_1340_PHASE1B3_NOTETYPE_FINALIZED_RESTART.zip`、SHA256 `F0F23477705A541FA5D47B52F629151AE6EE8C7AE296301A84A431A93AED2B0D`、Size 1,225,087 Bytes、エントリ数78）が物理的作成・Snapshot／metadata再生成・Package内部整合性確認・ユーザー正式採用のすべて完了した。当該Packageに関する上記「過去Packageを現行承認済みPackageと誤認する可能性」リスクは解消済みである。旧Package（`FM-Script-Backup_20260726_2137_PHASE1B3_PRE_IMPLEMENTATION.zip`）は履歴基準へ移行した。ただし、当該Package正式採用のみでは実装開始条件は満たされず、実装開始ゲートはCLOSEDのまま変わらない。
