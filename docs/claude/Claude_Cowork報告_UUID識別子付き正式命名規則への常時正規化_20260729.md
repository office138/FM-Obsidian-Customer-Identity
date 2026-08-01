# Claude Cowork 実装報告 — UUID識別子付き正式命名規則への常時正規化(2026-07-29)

対象アクション: `UPDATE_CUSTOMER_IDENTITY`(`Invoke-UpdateCustomerIdentity`)
対象ファイル: `<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1`

---

## 1. 基準確認

- 作業開始前のSHA256: `41B006FB52F3AEF69D479AD836FD04D63E4724CF5D8F33B094FC6F3DB3CF97DE`(指示書記載値と完全一致、大小文字を除き同一)
- 作業開始前のサイズ: 47,038 bytes(指示書記載値と一致)
- エンコーディング: UTF-8 BOM付き(`EF BB BF`確認)
- 改行コード: LF-only(CR数0、指示書記載どおり)
- 判定: **基準ファイルは指示書の記載と完全に一致。実装開始前に相違なし。**

---

## 2. 調査結果(Step1)

- **フォルダ名生成用の顧客名正規化**: `Invoke-UpdateCustomerIdentity`内の既存Step4は`Sanitize-LeafName $companyNameRaw "NO_NAME"`を直接使用しており、会社種別語(株式会社/㈱等)の除去・略称化は一切行っていない(生の顧客名をそのままファイルシステム安全化するのみ)。
- **ノート名生成用の顧客名正規化**: legacy CHECK区分(本ファイル後方、`EXT-obs_OBSノート-開く`用処理)内に既存インラインコード(`$n`/`$nameNorm`生成ブロック)があり、noteTypeが「一覧」を含む場合は株式会社→㈱等へ**略称化**、含まない場合は株式会社/有限会社/合同会社等を**完全除去**する、という異なる規則を用いている。ご指摘の「フォルダ:Faithウエダ㈱ / ノート:Faithウエダ」という例は、まさにこの非一覧ノートの完全除去ルールと一致することを確認した。
  → 今回は、独自ルールを追加せず、**フォルダ名は既存のSanitize-LeafName(生名)を継続使用し、ノート名は既存legacy CHECKの`$n`/`$nameNorm`ブロックと全く同一のロジックを複製した新関数`Get-NoteNameNormForUci`で処理する**方針とした。legacy CHECK側の既存インラインコード自体は変更していない(diff最小化・既存動作の温存のため)。
- **UUID先頭8文字識別子の生成**: 既存`Test-UciUuidFormat`によりpk_CLIENTが標準UUID形式であることは既に検証済みのため、単純に`.Substring(0,8).ToUpperInvariant()`で取得可能と判断。新関数`Get-UciUuidSuffix`として実装。
- **管理対象ノートの列挙**: 既存Step1(UUID完全一致による`$matchedNotes`再帰検索)をそのまま利用。ファイル名からのnoteType判定は、既存`Get-IconPrefix`を6noteType分呼び出して作った「接頭辞→noteType」逆引き表(新関数`Get-UciKnownPrefixMap`)により行い、独自のnoteType判定ロジックは追加していない。
- **YAML修復の可能範囲**: 既存`Update-Yaml-Robust`を読み直した結果、同関数は「frontmatterの開始・終了`---`さえ確定できれば、既存UUID値の正誤を問わず、渡された認証済み値(UUID/顧客名/代表者/RUBY/ランク/総合計保険料)で必ず再生成する」設計であることを確認した。つまり**修復のための追加ロジックは一切不要**で、既存Step3の「UUID形式不正なら無条件停止」という判定を「修復候補として収集し処理を継続」に変更するだけで、修復要件を満たせると判断した。
- **本文境界の判定**: 既存`Get-YamlHeaderLines`が「開始`---`があり終了`---`が見つからない」場合に`$null`を返す既存規則をそのまま利用。この場合のみ本文喪失リスクがあるため、引き続き無条件停止とした(コードは`YAML_BODY_BOUNDARY_UNRESOLVED`へ変更)。
- **既存ロールバック機構**: 「更新失敗時、処理済みノートの内容をバックアップから復元→フォルダ名を旧名へ復元」という順序(ノート→フォルダ)を確認。今回の拡張(ノートのファイル名リネームも復元対象に追加)は、この既存順序をそのまま維持し、「ファイル名を戻す→バイト内容を復元」という手順をノート単位の処理に追加する形で対応可能と判断した。
- **FileMaker側変更の要否**: 既存タスク(f)で追加した`Get-UuidNoteTypeMatches`によるUUID+noteType優先解決は、ファイル名ではなくYAML内のUUID値で既存ノートを探すため、**今回のファイル名正規化後もlegacy CHECKは正しく既存ノートを再解決でき、重複ノート作成のおそれはない**ことを確認した(詳細は5節)。一方、`obs_RELPATH`/`obs_URL`等のFileMaker側フィールドについては、UPDATE_CUSTOMER_IDENTITYの応答から直接更新される経路が現状存在しないため、リネーム直後は一時的に古いパスを保持したままになり得る。次回のnote-open(legacy CHECK)時にUUID+noteType優先解決で自己修復されるが、それを経由しない他のFileMaker機能(例:キャッシュされたパスを直接使う「エクスプローラで開く」的なボタン等、存在する場合)は影響を受け得る。**この点はFileMaker側の設計次第であり、PowerShell側だけでは解消できないため、必要に応じてFileMaker側の対応要否をご確認いただきたい(今回はFileMakerスクリプトを変更していない)。**
- **衝突確認UIの実現可能性**: 4択の対話的確認フロー(中止/続行/別名指定/確認して再試行)をPowerShell単独でFileMaker側に表示させることはできないと判断した。今回は「衝突を検知したら安全に停止し、診断情報を構造化して返す」までを実装し、対話UI自体は実装していない(要:FileMaker側UI追加、実施は見送り)。
- **最小差分挿入点**: 既存`Invoke-UpdateCustomerIdentity`のStep3(整合性確認)/Step4(フォルダ名決定)/Step5(NO_CHANGE判定)/Step6-9(バックアップ・書込・検証・ロールバック)を、それぞれ最小限拡張する形で対応可能と判断し、その方針で実装した。致命的な不明点はなかったため、Step2以降へ進んだ。

---

## 3. 実装内容(Step2-3)

### 追加した関数(すべて`Get-UuidNoteTypeMatches`と`New-UCIResponse`の間に追加)

| 関数名 | 役割 |
|---|---|
| `Get-UciKnownPrefixMap` | 既存`Get-IconPrefix`を6noteType分呼び出し、「接頭辞→noteType名」逆引き表を作る |
| `Get-NoteNameNormForUci` | legacy CHECKの`$n`/`$nameNorm`ブロックと同一規則を複製したノート名正規化(独自ロジック追加なし) |
| `Get-UciUuidSuffix` | pk_CLIENT先頭8文字を大文字化し`_[XXXXXXXX]`形式で返す |
| `New-UCIExtendedNgResponse` | 衝突・境界未解決等、診断フィールドを伴うNG応答の汎用ビルダー |

### 既存関数の拡張(シグネチャ後方互換)

- `New-UCIResponse`: 末尾に`renamedNoteCount`/`uuidSuffixOut`/`renamedNotes`を追加(すべて省略可・既定値あり)。既存呼び出し箇所はすべて無改修で動作する。

### `Invoke-UpdateCustomerIdentity`内の変更点

1. **Step3(整合性確認)**: UUID形式不正のノートを即座に停止させず「修復候補」として収集するよう変更。本文境界が判定できないケースのみ`YAML_BODY_BOUNDARY_UNRESOLVED`(新コード)で停止。
2. **Step4(フォルダ名決定)**: `$newFolderName`の生成式に`Get-UciUuidSuffix`の結果を追加付与するよう変更(会社種別語の除去等は行わない、既存の生名ルールを継続)。
3. **Step4.5(新規)**: `matchedNotes`+修復候補の全ノートについて、現在のファイル名から既知の接頭辞を認識し、正式ファイル名(接頭辞_正規化済み名_UUID接尾辞.md)を算出。直下ノートのみを対象とし、サブフォルダ内ノートは対象外(現行スコープを維持)。
4. **Step5(NO_CHANGE判定)**: フォルダ・ノートのリネーム要否/修復要否をNO_CHANGE判定へ組み込み、識別子付与のみの変更でもNO_CHANGEとしないよう修正。
5. **Step4.6(新規)**: 書込み前の全件衝突事前チェック。同一UUID・同一noteTypeの重複は既存コード`NOTE_TYPE_UUID_CONFLICT`を再利用、無関係な既存ファイルとの衝突は新コード`TARGET_NOTE_FILENAME_CONFLICT`で診断情報付きで停止。
6. **Step6(バックアップ)**: `matchedNotes`と修復候補を統合したリネームプランからバックアップを取得するよう変更。
7. **Step7.5(新規)**: フォルダリネーム後、必要なノートのみ物理的にファイル名変更してからYAML更新へ進む。
8. **ロールバック**: リネーム済みノートはファイル名を先に戻してから内容を復元するよう拡張(既存の「ノート復元→フォルダ復元」の順序自体は変更していない)。
9. **成功応答**: 既存の成功コード`CUSTOMER_IDENTITY_UPDATED`を維持しつつ、`renamedNoteCount`/`uuidSuffix`/`renamedNotes`を追加。

### 新規/変更した応答コード

| コード | 内容 | 備考 |
|---|---|---|
| `YAML_BODY_BOUNDARY_UNRESOLVED` | 本文境界判定不能 | 新規。旧`INVALID_YAML`のうち本文境界不能ケースを分離 |
| `TARGET_NOTE_FILENAME_CONFLICT` | ノート単位の異常衝突 | 新規。既存コードに同等のものがなかったため追加 |
| `NOTE_TYPE_UUID_CONFLICT` | 同一UUID・同一noteType重複 | 既存(task f導入分)を再利用、新規追加なし |
| `TARGET_FOLDER_ALREADY_EXISTS` | フォルダ名衝突 | 既存コードを継続使用(数式のみ更新) |
| `INVALID_YAML` | (今回、本関数からは発生しなくなった) | UUID形式不正は修復対象へ、本文境界不能は上記へ分離したため。他コンテキストでの定義自体は維持 |

`CUSTOMER_PATHS_NORMALIZED`のような新規成功コードは導入していない(指示書の既定方針どおり、既存`CUSTOMER_IDENTITY_UPDATED`を継続使用)。

---

## 4. 変更ファイル

- `<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1`(直接編集)
- バックアップ(編集前コピー、許可領域のみ):
  - `<TESTKIT_ROOT>\FM-Obsidian-Bridge-Payload_PRE_20260729_UUID_NORMALIZATION.ps1`（ローカル履歴証跡。GitHub cloneには含まれない）

---

## 5. diff要約

- 今回タスク分のみの差分(編集前バックアップとの比較): **追加197行 / 削除11行**(プレーンdiffベース)。追加は新規関数4個・拡張応答フィールド・Step3/4/4.5/4.6/6/7.5/ロールバック/最終応答の各拡張。削除は旧フォルダ名数式・旧NO_CHANGE条件式・旧INVALID_YAML停止コードなど、置き換えられた行のみ。
- `git diff --check`: **エラーなし**(空白・改行の異常なし)。
- ファイル全体の意図しない書き換えがないことの確認:
  - 1〜126行目(先頭〜Sanitize-LeafName手前まで): **差分0行**
  - 127〜186行目(Sanitize-LeafName/Normalize-ForMatch/Get-IconPrefix等): **差分0行**
  - 187〜254行目(Update-Yaml-Robust): **差分0行**
  - 旧687行目以降(dispatch分岐〜legacy CHECK〜ファイル末尾、新873行目以降に相当): **差分0行**(task e・fで導入済みのContainsKey修正・UUID+noteType優先解決ロジックを含め、完全に無改修であることを確認)
  - `Get-UuidNoteTypeMatches`関数定義そのもの: **完全に同一(byte-identical)であることを個別確認**
- 変更は`Invoke-UpdateCustomerIdentity`関数本体および直前の新規ヘルパー関数群に限定されており、大規模な再設計・全面書き換えは発生していない。

---

## 6. テスト結果

### 6-1. Python再現テスト(参考: 実機確認の代替にはなりません)

`uci_uuid_normalization_test_20260729.py`にて、今回追加したロジックをPythonで忠実に再現し、実ファイルI/Oを用いて検証。

**結果: 44 / 44 PASS**(Case1〜13、各ケース複数アサーションを含む)

| Case | 内容 | 結果 |
|---|---|---|
| 1 | 社名変更なし・識別子なし→フォルダ+全ノートへ付与、本文保持 | PASS |
| 2 | 社名変更あり・識別子なし→リネーム+付与 | PASS |
| 3 | 社名変更あり・識別子あり→名前部分のみ更新、識別子重複なし | PASS |
| 4 | 既に完全正式名→NO_CHANGE、ファイル内容ハッシュ不変 | PASS |
| 5 | 6noteType全て共存→全て正式名+識別子、本文・接頭辞保持 | PASS |
| 6 | UUIDなし補助ノート→ファイル名・内容とも不変 | PASS |
| 7 | 別UUID混在→FOLDER_UUID_MIXEDで停止 | PASS |
| 8 | 同一社名・異なるUUID識別子の2顧客共存 | PASS |
| 9 | 異常衝突(UUIDキーなしの既存ファイル)→TARGET_NOTE_FILENAME_CONFLICT、上書きなし | PASS |
| 10 | YAML管理キー破損・境界確定→修復+正式名化、本文完全保持 | PASS |
| 11 | 本文境界判定不能→YAML_BODY_BOUNDARY_UNRESOLVED、元ファイル完全不変 | PASS |
| 12 | 途中注入失敗→ファイル名・内容とも完全ロールバック | PASS |
| 13 | 正規化後もUUID+noteType優先解決(task f)が正常機能、重複作成なし | PASS |

補足(重要な発見・テスト設計上の制約): Case10/11のように「YAML破損ノート単体」では、Step1/Step2の既存フォルダ解決ロジック(有効な形式でUUID完全一致するノートが最低1件必要)により顧客フォルダ自体を解決できないため、**修復・境界判定不能の検知は「同一フォルダ内に他の正常なノートが最低1件存在する場合」にのみ機能する**ことを確認した。これは既存Step1/Step2の仕様であり今回変更していないが、実運用上の適用範囲として認識しておく必要がある。

### 6-2. Windows PowerShell 5.1 実機確認(★要実施・現時点で未実施)

**このPython再現テストのみでは合格としません(ご指示のとおり)。** 以下のハーネスを実機で実行してください:

- `Test-UciUuidNormalization_20260729.ps1`(UTF-8 BOM付き、対象.ps1から実関数・`Invoke-UpdateCustomerIdentity`本体をそのまま抽出して実行。Case1〜13相当を実ファイルI/Oで検証)
- 既存 `Test-UCIActionDispatchRegression_20260729.ps1`(4/4、action未指定後方互換)
- 既存 `Test-UuidNoteTypeDedup_20260729.ps1`(重複ノート防止、task f分)
- 既存 `Run-UCITests.ps1`(24件) — **下記「既知の注意点」を必ずご確認ください**

実行例:
```
cd <TESTKIT_ROOT>
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-UciUuidNormalization_20260729.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-UCIActionDispatchRegression_20260729.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Test-UuidNoteTypeDedup_20260729.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-UCITests.ps1 -ExpectedTargetSha256 7c16fd4ea30f1558beca3fefd8f32314984223853d5308940bb709783f564e0e
```

**既知の注意点(Run-UCITests.ps1について、実装バグではなく仕様変更に伴うテスト期待値の陳腐化)**:

今回の命名規則変更は意図的な仕様変更であるため、既存24件スイート中、以下**3件は現状のままでは必ずFAILします**。これは実装の不具合ではなく、「命名規則・エラーコード語彙が正当に変わったためテスト側の期待値更新が必要」なケースです(ご指示に基づき、テストを緩めて通すのではなく、この区別を明示します)。

1. `01_顧客名変更+フォルダリネーム`: 期待フォルダ名が識別子なしの`株式会社新名称テストA`のまま。実際の結果は`株式会社新名称テストA_[XXXXXXXX]`となるため不一致。→ 期待値をUUID接尾辞付きへ更新する必要あり。
2. `14_INVALID_YAML(未クローズ)`: 期待コードが`INVALID_YAML`のまま。本文境界判定不能ケースは今回`YAML_BODY_BOUNDARY_UNRESOLVED`へ変更したため不一致。→ 期待コードの更新が必要。
3. `15_INVALID_YAML(UUID形式不正)`: 期待コードが`INVALID_YAML`のまま。UUID形式不正は今回「修復して継続」する仕様へ変更したため、成功コード(または該当ノートの配置次第でCUSTOMER_NOT_FOUND)になり不一致。→ 期待値の見直しが必要。

このテストスイート自体は既存の承認済み成果物であるため、**今回は期待値の書き換えを行っていません**。ChatGPT・ユーザー様のご確認のうえ、修正のご指示をいただければ対応します。上記3件を除く21件については、対象コードを変更していないため引き続きPASSする想定です(実機未確認)。

---

## 7. 修正後ファイル情報

- サイズ: 58,880 bytes
- SHA256: `7c16fd4ea30f1558beca3fefd8f32314984223853d5308940bb709783f564e0e`
- エンコーディング: UTF-8 BOM付き(維持)
- 改行コード: LF-only(CR数0、維持)
- 末尾改行: なし(維持、変更前と同一)
- 行数: 1,167行(変更前981行)

---

## 8. Git状態

- リポジトリルート: `【Vault】INS\scripts\.git`
- `git status --short`: `M FM-Obsidian-Bridge-Payload.ps1`(追跡中ファイルの変更のみ、新規未追跡ファイルなし)
- `git diff --check`: エラーなし
- 実行したgitコマンドはすべて読み取り専用(`status`/`diff --check`/`rev-parse`/`log`)。add/commit/push等の書き込み操作は一切行っていません。

---

## 9. 残存リスク

- **Windows PowerShell 5.1実機確認が未実施**: 本報告時点のテストはPython再現のみ。実機での`Test-UciUuidNormalization_20260729.ps1`等の実行結果待ちです。
- **Run-UCITests.ps1の3件は期待値更新が必要**(6-2節参照、実装バグではない)。
- **FileMaker側の`obs_RELPATH`/`obs_URL`の一時的な陳腐化**: リネーム直後、次回note-open(legacy CHECK)まで古いパスが残る可能性がある。実運用への影響有無はFileMaker側の実装次第で、今回はFileMakerスクリプトを変更していないため未解消。
- **衝突時の4択対話UI(中止/続行/別名指定/確認再試行)は未実装**: PowerShell単独では実現不可と判断したため、安全停止+診断情報のみを実装。UIが必要な場合はFileMaker側の追加実装が必要(今回は実施していません)。
- **修復機能の適用範囲の限定**: 同一フォルダ内に他の正常なUUID一致ノートが最低1件ないと、修復対象ノート単体では顧客フォルダを解決できず機能しない(既存Step1/Step2仕様、6-1節参照)。
- **サブフォルダ内ノートはファイル名変更の対象外**(現行の直下のみの仕様を維持し、スコープを独断で拡張していません)。YAML内容更新自体は既存どおり実施されます。
- **限定E2Eテスト環境(pk_CLIENT `2250BA49-...`)には一切触れていません**。ご指示のとおり、ChatGPTレビュー完了までE2E実行は行っていません。
- **本番Vaultへは一切書込みを行っていません**(すべて一時ディレクトリでの検証)。

---

## 10. 判定: **B**

理由: 静的検証(brace/paren/bracketバランス、`git diff --check`、BOM/改行/末尾改行の保持、無関係領域の完全不変性)およびPython再現テスト(44/44)はすべて合格しましたが、ご指示にある「Windows PowerShell 5.1実機での確認」は本レポート作成時点で未実施です。また、既存Run-UCITests.ps1の3件について期待値更新が必要であることが判明しており、その反映と実機再確認が完了するまでは判定Aとしません。

実機ハーネス(`Test-UciUuidNormalization_20260729.ps1`ほか)の実行結果、およびRun-UCITests.ps1の期待値更新方針についてご確認いただければ、続けて対応します。
