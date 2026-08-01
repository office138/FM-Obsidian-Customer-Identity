# SCRIPT 307 構造化エラー調査 独立レビュー（Claude Cowork）

- レビュー日: 2026-07-24
- 担当: Claude Cowork（二次レビュー）
- 一次資料: DDR XML `【CRM】RakkoDB_fmp12.xml`（UTF-16LE, FMPReport version=**19.6.3**）、PowerShell原本 `FM-Obsidian-Bridge-Payload.ps1`（501行, SHA256 74DC…29ADE）、Claris公式JSON関数ドキュメント、Base Elements Plugin公式ドキュメント（GoyaPtyLtd）。
- 変更: なし（FileMaker/PowerShell/DDR/Vault/Git/Project すべて無変更、git書込みコマンド未使用）。
- 注: Antigravityの「307構造化エラー調査報告書」本体は当環境に存在しなかったため、報告書の主張は原本（DDR/PS/一次資料）と直接照合した。

---

## 1. DDR再確認結果（確定事実）
XMLパーサでScriptCatalog定義を抽出（参照ノードと定義ノードを区別）。

**307 `EXT-obs_内部CallPS-PAYLOAD`（57ステップ）— PowerShell薄呼び出し層**
- 引数 `$payloadJson = Get(スクリプト引数)`。`$vaultRoot = JSONGetElement($payloadJson;"VaultRoot")`。
- `If BE_FileExists($psScript)=0` → 生ダイアログ「PowerShellスクリプトが見つかりません…」→ **現在のスクリプト終了 [結果: "NG|FILE_NOT_FOUND"]**（パイプ形式で返す）。
- payloadB64を一時ファイルへ `BE_FileWriteText`。直後に `$errWrite = BE_GetLastError`。`If $errWrite≠0` → 生ダイアログ「BE_GetLastError = …」→ **現在のスクリプト終了 [ ]（空文字返却・codeなし）**。
- `$stdout = BE_ExecuteSystemCommand($cmd; -1)`。直後 `$lastErr = BE_GetLastError`。
- `If IsEmpty($stdout)` → 生ダイアログ「出力が空です。¶BE_LastError:… ¶実行コマンド:… & $cmd」（**この分岐に 現在のスクリプト終了 は無く、素通りする**）。
- 末尾 **現在のスクリプト終了 [結果: $stdout]**（生の$stdoutをそのまま返す。レスポンス形状の検証なし）。
- **307自身は正常レスポンスを解析しない**（パイプ分解はしない）。デバッグダイアログ（status/action, 生データ）は全て `enable="False"`（無効）。

**299 `EXT-obs_OBSノート-開く`（163ステップ）— 呼出元/オーケストレータ**
- `$noteType = Get(スクリプト引数)`。VaultRoot確定→payload構築（キー: VaultRoot, noteType, pk_CLIENT, companyNameRaw, CEO, RUBY, RANK(=RANK1LYear), obs_RELPATH, obs_URL, fm_LASTMODIFIED, **MODE="CHECK"** 相当の初回実行）。
- `スクリプト実行[307]` → `$stdout=Get(スクリプトの結果)` → **パイプ解析** `$resList=Substitute($stdout;"|";"¶")`, `$status=GetValue(1)`, `$action=GetValue(2)`。
- `If $status≠"OK"` → ダイアログ「Obsidian連携エラー」= `GetValue(2) & " : " & GetValue(3)`（＝action名と details を生表示）→ 終了。
- `$action="NEED_FOLDER_CONFIRM"` 時はフォルダ確定UI→payloadに `folderNameConfirmed` を足して307再実行。
- 同期反映: 3=URL,4=RELPATH,5=lastWriteISO,6=diffB64。`$diffJson=Base64Decode(6)`、`hasDiff`／`recommend.winner`＝"FM"→APPLY(再307, MODE=APPLY)／"OB"→OB→FM（社名・RANK保護）。

**313 `EXT-obs_損保最新証券-突合`（135ステップ）— 突合、299を経由しない**
- 引数チェック（"契約一覧"/"事故一覧"のみ）。CSVエクスポート→payload構築 **MODE="COMPARE"**（キー: MODE, csvPath, VaultRoot, pk_CLIENT, companyNameRaw, CEO, RUBY, RANK 等）。
- `スクリプト実行[307]`（Step 127相当）→ `$result=Get(スクリプトの結果)`。**戻り値の構造的ハンドリングは無し**（結果表示ダイアログは無効化コメント、実処理なし）。

**確定事項の要点**
- action と MODE は別物。**現行の要求キーは `MODE`（CHECK/COMPARE/APPLY）**。`action` は「レスポンスの第2フィールド」（OPENED/NEED_FOLDER_CONFIRM/CREATED/ERROR）としてのみ存在。
- MODE実在値は **CHECK / COMPARE / APPLY の3種**。**`OPEN` という MODE は存在しない**（"OPENED" はレスポンスのkind/action）。
- **`SYNC_NOTE` は現行に一切存在しない**（DDR/PS 0件）。
- **`requestId` / `protocolVersion` は現行payloadに存在しない（DDR 0件）**。したがって現状の307で `JSONGetElement($payloadJson;"requestId")` は空を返す。
- 呼出経路: 299→307→PS、313→307→PS（313は299非経由）。307はPSのexit code非可視（後述）。

## 2. JSON関数実測（一次資料: Claris公式 / 実バージョン19.6.3）
FileMakerは有効JSONに対しキー欠落は空文字、パース失敗時は先頭 `"?"` ＋エラーメッセージを返す。型判定は `JSONGetElementType`（`JSONObject/JSONArray/JSONString/JSONNumber/JSONBoolean/JSONNull` 定数）。

| 入力 | JSONGetElement | JSONGetElementType | 確定度 |
|---|---|---|---|
| 有効JSON・キーあり | 値 | 対応する型 | 公式 |
| 有効JSON・キーなし | 空文字（"?"は付かない） | "?"（要素なし=エラー扱い） | 公式準拠・19.6.3実機で最終確認推奨 |
| キー値 null | "null" ではなく空扱い/型は JSONNull | JSONNull | 実機確認推奨 |
| キー値 空文字 "" | "" | JSONString | 公式準拠 |
| JSON構文不正 | `"? …"` | `"?"` | 公式 |
| 空文字入力 | `"? …"`（空は無効JSON） | `"?"` | 公式 |
| ルート=オブジェクト | — | JSONObject | 公式 |
| ルート=配列 | — | JSONArray | 公式 |
| ルート=数値 | 数値 | JSONNumber（裸の数値は有効JSON） | 公式 |

**重要（バージョン差）**: `JSONParse` / `JSONParsedState` は **FileMaker 2023（v20.1）以降**の関数。**DDRは v19.6.3 のため両関数は使用不可**（`JSONMakeArray` も v20+）。19.6.3で使えるのは JSONGetElement / JSONGetElementType / JSONSetElement / JSONDeleteElement / JSONListKeys / JSONListValues / JSONFormatElements。妥当性判定は「`JSONFormatElements` の先頭が `"?"` か」または `JSONGetElementType(...;"")≠JSONObject` で行う（公式手法）。
→ 設計含意: 不正JSON検知は `"?"` 判定で行い、`JSONParsedState` に依存しない設計とすること。

## 3. Base Elements 一次資料・実測（Goya公式）
`BE_ExecuteSystemCommand ( command ; { timeout ; executeUsingShell } )`
- **timeout**: ミリ秒。**空=無限待機、0=即時リターン、正値=ms**。**「-1」は公式に定義がない**。現行307は `BE_ExecuteSystemCommand($cmd; -1)` を使用 → **-1の挙動は一次資料で未定義（未確認）**。関連Issue（#166/#180）で不正timeoutは `"?"` 返却の報告あり。
- **戻り値**: **stdoutのみ**を返す。「それ以外はコマンド側で捕捉が必要」。
- **stderr**: **BE_ExecuteSystemCommandは別取得しない**（stdoutのみ）。stderrはコマンド内でリダイレクトが必要（PSのCOMPAREはPython stderrを `_py_err.log` へリダイレクト＝整合）。
- **終了コード**: BE_ExecuteSystemCommandは**プロセスexit codeを返さない**。→ 307/FileMakerはPSのexit codeを見られず、**stdout本文のみ**が唯一の判定材料。
- **文字コード / 最大長**: 一次資料に明記なし → **未確認**。
- **executeUsingShell**: 既定True。Windowsで `|` パイプはコマンド側で「動作しない」既知caveat（本件のパイプはPSレスポンス文字列内なので直接は非該当だが留意）。
- **BE_GetLastError**: 直近のBE関数呼び出しのエラーコードを返す仕様 → **対象BE関数の直後に読む必要があり、以降の任意のBE関数呼び出しで上書きされる**（307はBE_FileWriteText直後・BE_ExecuteSystemCommand直後に読んでおり順序は妥当）。v5.0.0.2固有の細部は一次資料に版番号記載がなく **未確認**。
- **起動失敗時**: プラグインは空または `"?"` を返し BE_GetLastError が非0（Issue群より）。→ 空stdout分岐で捕捉されるが、`"?"` 単体は現行307で未検査。

## 4. action／MODE整理（設計候補）
- 現行 = **MODE方式**（要求: CHECK/COMPARE/APPLY）。レスポンス = パイプ `OK|kind|…` / `NG|kind|details|||`。
- SYNC_NOTE（action方式・JSONレスポンス）は**新規**で、既存MODEと**共存**させる設計が必要。
- **判定は内容推測でなく明示キーで**行う（§8遵守）: レスポンス先頭が `OK|`/`NG|`（既存）か、JSON（新）かを、要求時に決めた形式で判定する。307は現状「結果内容から形式推測」すらせず素通しのため、**形式検証（OK|/NG|始まり・フィールド数、またはJSON妥当性）を追加**すべき。

## 5. requestId方針（推奨）
- 現行payloadに `requestId` 無し。**欠落時は `null` を返し、307で新規UUIDを生成しない**案を支持。requestIdは呼出元が発行・保持する相関IDであり、307が採番すると相関が壊れ、偽の来歴を与える。
- 実装時は 307構造化エラーJSONに `requestId`（無ければ JSON null）を含める。**架空文字列 `UNKNOWN_REQUEST_ID` は不可**（型が文字列になり null と区別不能になる）。

## 6. protocolVersion方針（推奨）
- 現行payloadに無し。**既存action（MODE系）は protocolVersion を要求しない（後方互換）**。**SYNC_NOTE では必須とし、欠落・取得不能時はエラー**（`MISSING_REQUIRED_FIELD` / `UNSUPPORTED_PROTOCOL_VERSION`）。
- 欠落時に暗黙で1補完するのは、将来のバージョン差異検知を弱めるため、**SYNC_NOTEでは非採用**（既存actionでのみ「無ければ1相当」を許容可）。
- **`"1"`（文字列）と `1`（数値）を区別**: `JSONGetElementType(payload;"protocolVersion")` が `JSONNumber` であることを要件化（文字列 "1" は不正型候補）。

## 7. stdout／stderr／BEエラー マトリクス（§6 ケースD再評価）
| ケース | stdout | BE_GetLastError | 現行307の挙動 | 評価 |
|---|---|---|---|---|
| 正常 | `OK\|kind\|…`（完全1行） | 0 | $stdout返却 | 妥当 |
| PS内業務エラー | `NG\|ERROR\|details\|\|\|`（exit 0） | 0 | $stdout返却（299が NG 表示） | detailsに技術情報混入（§10要改善） |
| スクリプト不在 | （307が生成）`NG\|FILE_NOT_FOUND` | — | 早期終了 | 妥当だが details空 |
| payload書込失敗 | （PS未起動） | ≠0 | 生ダイアログ＋**空返却（codeなし）** | **要改善**: 構造化 `PAYLOAD_FILE_WRITE_FAILED` を返すべき |
| 起動失敗/stdout空 | 空 or `"?"` | ≠0 | 生ダイアログ→**空$stdout返却** | **要改善**: `POWERSHELL_LAUNCH_FAILED`/`EMPTY_POWERSHELL_RESPONSE` |
| **ケースD: stdout非空 かつ BE≠0** | 非空 | ≠0 | **BE_GetLastErrorを無視し$stdoutを無条件返却** | **要再設計** |

**ケースD評価**: stdoutを**無条件優先してはならない**。BE_ExecuteSystemCommandはexit code非可視・stderr非取得のため、非0のBE_GetLastErrorは「プロセス途中終了/部分出力」の兆候になり得る。PSは常にexit 0で単一パイプ行を出す設計だが、307は**レスポンス形状を検証していない**ため、部分出力（先頭が `OK|`/`NG|` でない、フィールド数不足）を299/313が誤解析する危険がある。よって:
- レスポンス**妥当性検査**（`OK|`/`NG|`始まり＋最小フィールド数、または将来のJSON妥当性）を必須化。
- 検査不合格時は専用 **transport error**（`INVALID_POWERSHELL_RESPONSE`）で安全停止。
- BE≠0 かつ stdout非空でも、形状不正なら成功扱いにしない。

## 8. PowerShell出力経路（§7 全件）
出力ヘルパ（すべて**パイプ形式・`exit 0`**）:
- `Out-OK(kind,url,rel,lwIso,diffB64)` → `OK|{kind}|{url}|{rel}|{lwIso}|{diffB64}` ; exit 0
- `Out-OKNeedFolder(...)` → `OK|NEED_FOLDER_CONFIRM|{cands}|{suggest}|{nameNorm}|{expectedFile}` ; exit 0
- `Out-NG(kind,details)` → `NG|{kind}|{details}|||` ; exit 0
- 最上位 `try{…}catch{ Out-NG "ERROR" ("MSG="+例外+" / LINE="+行番号+" / CMD="+コマンド) }`（**技術情報を露出**）。

| MODE/経路 | 成功時 stdout | 失敗時 stdout |
|---|---|---|
| 共通前段 | — | payload不明→`NG\|ERROR\|Payload not found.\|\|\|` / VaultRoot不明→`NG\|ERROR\|VaultRoot not found.\|\|\|` |
| COMPARE (313) | `OK\|OPENED\|url\|rel\|lw\|COMPARE_DONE` | フォルダ無→`NG\|ERROR\|比較対象…\|\|\|` ; py/csv/結果不在・py異常→throw→catch→`NG\|ERROR\|MSG=…/LINE=…/CMD=…` |
| 既存ノート開く (CHECK/APPLY/無MODE) | `OK\|OPENED\|url\|rel\|lw\|e30=`（e30==空{}） | 例外→catch→`NG\|ERROR\|MSG=…` |
| フォルダ未確定 | `OK\|NEED_FOLDER_CONFIRM\|cands\|suggest\|nameNorm\|expectedFile` | — |
| 新規作成 | `OK\|CREATED\|url\|rel\|now\|e30=` | 例外→catch→`NG\|ERROR\|MSG=…` |

**注**: PSは `MODE=COMPARE` のみ分岐。**CHECK と APPLY はPS側で区別されず**同じ通常オープン経路に落ち、diffB64は常に `e30=`（空）。したがって299側の APPLY/`recommend.winner`/双方向差分ロジックは現行PSでは実質休眠（常に hasDiff 空）。`throw` は最上位catchで `Out-NG` 化され、`Write-Host` はstdoutに混じらない（コンソール装飾用、FileMakerはstdoutのパイプ行のみ取得）。

## 9. 299・313責務
- **299**: レスポンスのパイプ解析・UI・フォルダ確定再実行・差分同期の主責務。エラー表示は `action:details` を生表示（技術情報露出）。
- **313**: COMPARE要求のみ。**戻り値の構造的ハンドリングを実質行わない**（結果取得のみ、表示は無効化）。→ 将来のNG受信時のユーザー通知責務が未定義。
- 307は両者の共通トランスポート。現状は形状検証なしの素通し＋実行層エラー時のみ生ダイアログ。

## 10. Antigravity報告の正しい点（原本と一致）
- 307のスクリプト不在時 `NG|FILE_NOT_FOUND`、payload書込失敗時の生ダイアログ＋空結果、stdout空時の生ダイアログ＋空stdout返却、という3系統の実行層問題の指摘は**原本と一致**。
- 307は正常レスポンス非解析（解析は299/313）、313は299非経由（Step127で307直接呼出）、SYNC_NOTE未実装、暫定安全側 `NOTE_NOT_FOUND` の方向性、いずれも妥当。
- 技術情報（コマンド/BEエラー/パス）が一般画面に露出する問題の指摘は妥当（catchの MSG/LINE/CMD、299の action:details 表示で裏付け）。

## 11. 誤り・未裏付け箇所（要補正・要確認）
- **timeout=-1**: 一次資料に定義なし。「-1＝無限待機」等と断定していれば誤り。正しくは「空=無限、0=即時」で-1は未定義（未確認）。
- **JSONParse/JSONParsedState前提**: 19.6.3では使用不可。これらに依存する設計は不可。
- **requestId/protocolVersionが現行payloadに在る**かのような記述は誤り（現行0件）。両者は新規追加が前提。
- **stdout無条件優先**（ケースD）: 形状検証なしは危険。要再設計。
- BE_ExecuteSystemCommandの**文字コード・最大長・exit code取得可否**を確定的に記述していれば未裏付け（exit codeは非取得が正、文字コード/最大長は未確認）。
- 「OPEN」をMODEとして扱っていれば誤り（"OPENED"はレスポンスkind）。

## 12. 補正後の設計候補
1. **レスポンス形式は要求時に確定**（MODE系=パイプ、SYNC_NOTE=JSON）。307/299/313は**明示形式で判定**、内容推測しない。
2. **307にレスポンス妥当性検査**を追加（`OK|`/`NG|`始まり＋最小フィールド数、またはJSON妥当性）。不合格は `INVALID_POWERSHELL_RESPONSE`。
3. **307実行層エラーを構造化**: `PAYLOAD_FILE_WRITE_FAILED` / `POWERSHELL_SCRIPT_NOT_FOUND`（現 NG|FILE_NOT_FOUND を改称統一）/ `POWERSHELL_LAUNCH_FAILED` / `EMPTY_POWERSHELL_RESPONSE`。生ダイアログは廃し、requestId（無ければ null）を含める。
4. **requestId**: 欠落→null、307採番しない。**protocolVersion**: 既存要求せず、SYNC_NOTE必須・型は数値。
5. **一般画面 vs 内部ログ分離**（§10）: 画面は `userMessage` のみ。内部ログ候補 = `requestId, stage, beErrorCode, pluginFunction, hasStdout, responseLength`。catchの MSG/LINE/CMD は内部ログ専用へ。
6. エラーコード集合（§9）: `INVALID_PAYLOAD / MISSING_REQUIRED_FIELD / UNSUPPORTED_ACTION / UNSUPPORTED_PROTOCOL_VERSION / PAYLOAD_FILE_WRITE_FAILED / POWERSHELL_SCRIPT_NOT_FOUND / POWERSHELL_LAUNCH_FAILED / EMPTY_POWERSHELL_RESPONSE / INVALID_POWERSHELL_RESPONSE` を採用候補。307は自身の実行層エラー（後半5つ）を担当、業務系（前半）はPS/上位が担当と責務分離。

## 13. 未確認事項
- BE_ExecuteSystemCommand の timeout=-1 実挙動、文字コード、最大出力長（一次資料に記載なし → 実機検証が必要）。
- BE v5.0.0.2 固有の版差（公式docは版番号を4.2.0までしか明示せず）。
- FileMaker 19.6.3 実機での JSONGetElement のキー欠落/null値の厳密な戻り（公式は現行版基準）。
- BE_GetLastError の起動失敗時コード値の具体。
- Antigravity報告書本体・使用スクリプトの所在（未提供）。

## 14. 安全確認
- Git: branch=main / HEAD=24cf1dc2b352edb855c5281954f481f91fe917ac / status= ` M .gitignore`, `?? …JIKO.ps1_不要`（作業前後不変、書込コマンド未使用）。
- PowerShell原本: Length=22150 / SHA256=74DC6B828A3A0C6AEB64F6BB1129612626C675ADF4741B13C06B59D438929ADE（不変）。
- DDR/FileMaker/Vault/Project/QuickAdd 無変更。read-onlyのみ。

## 15. 最終判定
**B：補正後に採用可能。** DDR/PSに関するAntigravityの中核指摘（3系統の実行層問題・非解析・313非経由）は原本と一致し妥当。ただし (a) timeout=-1の未定義、(b) JSONParse/JSONParsedStateが19.6.3で不可、(c) requestId/protocolVersionが現行未実装、(d) ケースDのstdout無条件優先、(e) exit code非取得/stderr非取得/文字コード未確認、の各点で補正・明示が必要。実装開始は不可（設計確定＋ChatGPTゲート＋ユーザー明示指示が未充足）。
