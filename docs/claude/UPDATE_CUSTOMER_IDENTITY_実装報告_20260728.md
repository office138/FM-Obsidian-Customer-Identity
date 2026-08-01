# UPDATE_CUSTOMER_IDENTITY 実装報告（2026-07-28）

対象：FileMaker ↔ Obsidian 顧客名・代表者名変更対応（最小差分実装）
担当：Claude Cowork

---

## 0. 改訂履歴

- 2026-07-28 初版：`UPDATE_CUSTOMER_IDENTITY` 実装・テスト28件PASSを報告
- 2026-07-28 改訂1：ChatGPTレビュー（判定B）を受け、指摘4点（ロールバック登録順序バグ／requestId型検証／protocolVersion型検証／FileMaker応答の必須項目検証・boolean判定）を修正。回帰テストを追加し31件PASSへ更新。
- 2026-07-28 改訂2：ChatGPT再レビュー（判定B、追加補正2点）を受け、(1) FileMaker側キー欠落判定を`JSONNull`比較から`JSONGetElementType`のエラー文字列（`"?"`始まり）＋期待JSON型の一致確認へ修正、(2) PowerShell側の更新後再読込確認へtags・総合計保険料保持・本文不変の検証を追加。証明テスト2件を含め33件PASSへ更新。
- 2026-07-28 改訂3：ChatGPT第3回レビュー（判定B、最終補正2点）を受け、(1) 更新後再読込確認へ`noteType`保持検証を追加、(2) FileMaker手順へ`oldFolder`/`newFolder`の型検証を追加。あわせて、本文不変検証を「バイト完全一致」にすべきという指摘について、既存`Update-Yaml-Robust`自体の技術的制約（後述）を理由に採用しなかった判断根拠を明記した。noteType追加テスト2件を含め35件PASSへ更新。本報告は改訂3時点の内容である。

---

## 1. 総合判定

**B: 実装完了、一部手動確認が必要**（据え置き）

理由は2点。

第一に、このサンドボックス環境には PowerShell（pwsh）が存在せず、root権限が無いためインストールもできず、外部ネットワーク（github.com のバイナリ配布 objects.githubusercontent.com 等）へのアクセスもプロキシにより遮断されている（`403 from proxy`）。そのため、実際の `.ps1` を Windows PowerShell 5.1 で実行するテストはこのサンドボックス内では実施不可能だった。代替として、追加ロジックをアルゴリズムレベルで忠実に Python へ移植し、実ファイルシステム上でテスト用一時Vaultを作成して正常系16件・異常系19件（うち回帰テスト1件・検証ロジック証明テスト2件を含む）、計35件のシナリオを実行し、全件PASSを確認した（詳細は6章）。構文面はブレース/括弧対応の自動チェックと `git diff --check`、目視レビューで確認済みだが、これは実際のPowerShellパーサーによる構文検証ではない。

第二に、ChatGPTの3回のレビューで指摘された計8点（うち1点は重大：ロールバック登録順序バグ）のうち7点をそのまま修正し、残る1点（本文の「バイト完全一致」検証化）については、技術的根拠に基づき意図的に採用しなかった（3.5章末尾「本文検証方式についての判断」を参照。これは指摘を軽視したのではなく、既存`Update-Yaml-Robust`自体の挙動を実測相当の根拠で確認した結果である）。修正の妥当性はPython移植コードで検証済み（旧ロジックに戻すと同一条件で不具合が再現し、修正後は再現しないことを実際に確認した。6章参照）が、**これらについても実PowerShell環境・実FileMaker環境での再確認が済んでいない**。特にFileMaker側の`JSONGetElementType`の実返却値（キー欠落時に`"?"`始まりのエラー文字列を返すか）と`GetAsBoolean`の実挙動は、このサンドボックスにFileMakerが無いため実機でのみ確認可能である。

以上2点から、**ユーザー側のWindows環境・FileMaker環境での最終的な実行確認を推奨する**（10章・11章参照）。

---

## 2. 実行概要

- 実施した調査：`FM-Obsidian-Bridge-Payload.ps1` 実コード全文確認、`Update-Yaml-Robust` / `Sanitize-LeafName` の実装内容確認、実Vault（`01_顧客`配下491ノート、UUID保有267ノート）のYAML実データ構造確認（noteType/fm_note_typeキーの実在確認を含む。3.5章参照）、Project State文書（既存のSYNC_NOTE/MIGRATE_UUID設計は`実装開始：PROHIBITED`のゲート中であることを確認。ただし本件は添付差分実装指示書に基づく別建ての最小差分実装であり、当該ゲートの対象ではないと判断）
- 実施した変更：`FM-Obsidian-Bridge-Payload.ps1` へ `UPDATE_CUSTOMER_IDENTITY` action を追加（純追加、既存行の削除・変更なし）。ChatGPTレビュー3回を経て、同ファイル内で計5箇所の小差分補正（ロールバック登録順序／requestId型検証／protocolVersion型検証／更新後再読込確認の強化(tags・総合計保険料・noteType・本文)）を追加実施（いずれも純追加または同一関数内の最小修正、既存の他行は無変更）
- 実施したテスト：Python移植コードによる正常系16件・異常系19件（計35件、うち回帰テスト1件・検証ロジック証明テスト2件を含む）、実ファイルシステム上での一時テストVaultによる検証。全件PASS
- 本番Vault非書込み確認：テストはすべて `/tmp/uci_test_vault*`（このサンドボックス内の一時領域）で実施。実Vault（`01_顧客`、491ノート）は一切書き換えていないことを実行前後のファイル数・サンプルMD5で確認済み（6章末尾）
- Git書込み非実施確認：`git add` / `commit` / `push` は一切実行していない（9章）

---

## 3. 変更ファイル

| 項目 | 値 |
|---|---|
| パス | `<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1` |
| 変更前SHA256（初回セッション開始時点） | `74dc6b828a3a0c6aeb64f6bb1129612626c675adf4741b13c06b59d438929ade` |
| 変更後SHA256（ChatGPT第3回レビュー対応後・最終） | `04c48003fb1b462214cd85edb457d84b0b0e9e893fe913432faae7234fb524b5` |
| 変更前サイズ | 22,150 bytes |
| 変更後サイズ | 42,594 bytes |
| 改行コード | LF のみ（変更前・変更後とも。CRLF混入なし） |
| BOM | UTF-8 BOMあり（変更前・変更後とも維持） |
| 末尾改行 | なし（変更前・変更後とも `}` で終端、変化なし） |
| 保存後再読込確認 | 実施済み（初回実装時・ChatGPTレビュー対応1〜3回目の計4回とも）。追加した関数7個（既存15個＋新規7個＝合計22個をgrepで確認）・分岐位置・意図した差分が保存後ファイルに一致することを確認 |

git diffは426行の追加のみ（0削除）。`git diff --check` はwarningなしで終了（exit 0）。

---

## 3.5 ChatGPTレビュー対応（累計8点、うち7点を修正・1点は判断根拠を明記のうえ不採用）

### 1回目レビュー対応（4点）

| # | 指摘内容 | 重大度 | 対応 |
|---|---|---|---|
| 1 | 失敗した当該ノートがロールバック対象に入らない（`Update-Yaml-Robust`が実際にファイルを書き換えた後で例外・検証不一致になった場合、当該ファイルが変更済みのまま残る） | 重大 | `$processedPairs.Add($pair)` を書込み試行の**前**（tryブロック先頭）へ移動。書込みが実際に発生したかどうかに関わらず、その回で処理対象になったノートは必ずロールバック対象に含まれるよう修正。Python移植版でも同一修正を行い、修正前ロジックに戻すと復元漏れが再現すること（`ランク`が新値のまま残る）、修正後は再現しないことを実際に確認した |
| 2 | requestIdの型検証が仕様どおりでない（`[string]$payload.requestId`により数値・真偽値等も暗黙的に文字列化され受理されてしまう） | 中 | `$payload.requestId -is [string]` による型チェックを追加。非文字列は`MISSING_REQUIRED_FIELD`として拒否するよう統一（`Invoke-UpdateCustomerIdentity`内、および分岐呼び出し側の`EXECUTION_FAILED`用requestId取得ロジックの両方に適用） |
| 3 | protocolVersionが「数値1」ではなく `[int]` キャストで緩く判定されており、文字列 `"1"` 等も受理し得る | 中 | 値が数値型（`int`/`int16`/`int32`/`int64`/`double`/`single`/`decimal`）かつ文字列・真偽値でないことを型レベルで確認したうえで `1` と比較するよう修正 |
| 4 | FileMaker手順で応答の必須項目欠落検証が無く、`status=NG`時に`code`/`userMessage`欠落でもそのまま表示へ進んでしまう。`folderRenamed`のboolean判定が`"true"`固定文字列比較のみで、環境により`1/0`で返る場合に誤判定し得る | 中 | FileMaker手順に必須応答項目欠落チェック（→`INVALID_RESPONSE`）を追加し、`GetAsBoolean()`によるboolean正規化を追加 |

### 2回目レビュー対応（追加2点）

| # | 指摘内容 | 重大度 | 対応 |
|---|---|---|---|
| 5 | FileMaker側のキー欠落判定（`JSONGetElementType(...) = JSONNull`）が機能しない可能性が高い。Claris公式仕様では、指定キーが存在しない場合`JSONGetElementType`は`JSONNull`ではなく`"? Incorrect key, index, or path"`形式のエラー文字列を返すため | 高 | `Left(...;1)="?"` によるエラー文字列判定と、`status`/`code`/`userMessage`/`requestId`は`JSONString`、`updatedFiles`は`JSONNumber`、`folderRenamed`は`JSONBoolean`という期待型との一致確認を組み合わせる方式へ修正（5章参照） |
| 6 | PowerShellの更新後再読込確認が`UUID`・`ランク`の2項目しか検証しておらず、`tags`（顧客名・代表者名・RUBY）更新失敗や総合計保険料消失を検出できない | 高 | 更新後再読込確認へ、①`tags`が期待値（顧客名・代表者名・RUBYから生成した`cleanTags`）と一致すること、②既存の総合計保険料があれば同値で保持、無ければ新規追加されていないこと、③frontmatter以降の本文が更新前と完全に一致すること、の3項目を追加。検証ロジックが実際に異常を検出できることを示すため、tags改ざん・本文改変をそれぞれ意図的に注入して`NOTE_UPDATE_FAILED`になることを確認する証明テスト2件を追加した |

### 3回目レビュー対応（追加2点。うち1点は不採用と判断）

| # | 指摘内容 | 重大度 | 対応 |
|---|---|---|---|
| 7 | `noteType`の不変検証が無い。「変更するコードが無いこと」と「更新関数実行後も保持されること」は別であり、`Update-Yaml-Robust`はfrontmatter全体を再構築する関数であるため検証すべき | 高 | 更新前後で`noteType:`キーの値を比較する検証を追加した（PowerShell側・Python移植版側の両方）。ただし実データ確認の結果を下記に付記する |
| 8 | 本文不変検証が`ReadAllLines`ベースの行配列比較であり、改行コード（CRLF/LF/CR、混在、末尾改行有無）の変更を検出できない。バイト列比較にすべき | 高 | **不採用**（技術的根拠を下記に明記）。本文検証は行配列（テキスト内容）比較のまま維持した |

**指摘#7についての事実確認**：ChatGPTは「`01_顧客`配下にnoteType付きノートが多数存在することが既に確認されている」と述べたが、これを実Vaultで直接検証したところ、`01_顧客`配下491ファイル中、`noteType:`および`fm_note_type`という文字列を含むファイルは**0件**だった（`grep -rl "noteType" 01_顧客/`および`grep -rl "fm_note_type" 01_顧客/`をこのセッションで実行し確認）。この点、ChatGPTの記述はおそらく、Project State文書に記録されている別の未実装設計（`fm_note_type`をYAML必須フィールドとする、はるかに大規模なSYNC_NOTE/Phase1再設計。実装開始ゲートは`PROHIBITED`のまま凍結中で、本件とは別建て）の記述との混同と考えられる。現行の実運用YAML構造（`Update-Yaml-Robust`が実際に書き込むフィールド）には`noteType`キーは存在しない。とはいえ、検証の追加自体は無害かつ低コストであり、`Update-Yaml-Robust`が既存の未知キーをすべて保持する`kept_lines`機構を持つこと自体を明示的に裏付ける効果もあるため、指摘どおり追加した。

**指摘#8についての判断根拠（本文検証を「バイト完全一致」にしなかった理由）**：`Update-Yaml-Robust`は無改修の既存関数であり、内部で次のように書込みを行っている。

```powershell
[System.IO.File]::WriteAllLines($filePath, $finalContent, [System.Text.UTF8Encoding]::new($false))
```

`System.IO.File.WriteAllLines(String, IEnumerable<String>)` は、.NETの標準仕様として、配列内の各要素を書き出す際の行区切りに常に `Environment.NewLine` を使用する（この引数無しオーバーロードには改行コードを指定するパラメータが存在しない）。Windows上で実行される限り `Environment.NewLine` は常に `"\r\n"`（CRLF）であり、これはPowerShellのバージョン（5.1／7系）やこのスクリプトの改修内容に関係なく決まる、.NET共通の仕様である。

つまり `Update-Yaml-Robust` は、**今回の新規追加コードとは無関係に、既存の実装として、呼び出すたびにfrontmatterと本文の両方を含むファイル全体をCRLFへ正規化して書き出す**。この関数は`UPDATE_CUSTOMER_IDENTITY`専用ではなく、既存の通常ノート更新フロー（299→307→PowerShellの経路）でも同一の`Update-Yaml-Robust`が使われているため、この特性は本アクションに限らず既存の運用にも既に存在する。

Project State文書のDecision（1B2-5「本文の改行コードは変更しない」）はこの制約と矛盾するが、これは将来の再設計（外部YAMLパーサー導入等を伴う、より丁寧なfrontmatter編集方式）を前提とした決定であり、現在実際に使われている軽量版`Update-Yaml-Robust`（v8.3.0スクリプトに実装されているもの）がこの制約を満たすかどうかは、今回のセッションで初めて技術的に検討された可能性が高い。

この状況で本文検証を「バイト完全一致」にすると、Vault実態調査で存在が確認されている「LF本文ノート」「混在改行ノート」（Decision 1B2-5に記載の8件等）を対象に`UPDATE_CUSTOMER_IDENTITY`を実行した場合、本文の文字内容が一切変わっていなくても、改行コードがCRLFへ正規化されたという理由だけで常に`NOTE_UPDATE_FAILED`となりロールバックされてしまう。これは今回の実装指示書が明示的に禁止する「①既存処理への影響を及ぼすリファクタリング」ではなく「②既存関数が元から持つ副作用の検出」であり、対処法は次の二択となる：

- (a) 本文検証を「テキスト内容」比較にとどめ、改行コード正規化は許容する（今回採用）
- (b) `Update-Yaml-Robust`を「今回安全に再利用できない」阻害要因として扱い、実装を停止する（実装指示書 第17章の停止条件「`Update-Yaml-Robust`が安全に再利用できない決定的事実がある」に該当し得る）

(b)を選ばなかった理由は、この改行コード正規化という特性が**今回新設したコードによって生まれたものではなく、既に本番運用されている既存機能（通常のノート作成・更新フロー）にも等しく存在する、独立した既知の特性**であるため。今回のスコープでこれを「阻害要因」として実装全体を停止するのは適切でないと判断した。ただし、これは重要な事実発見であるため、本項として明示的に報告する。本文検証は、この既知の副作用を許容しつつ「本文の文字内容が意図せず変更・欠落していないこと」を検出する目的に限定した（改行コードの変更自体を異常として検出する設計にはしなかった）。

**この判断についてはユーザー・ChatGPTの明示的な承認を推奨する**。もし「改行コード正規化も含めて本文の完全不変を保証すべき」という判断であれば、`Update-Yaml-Robust`自体の改修（既存関数の無改修再利用という前提を外れる）が必要になり、これは実装指示書の変更禁止範囲（「不要なリファクタリング」「目的外機能追加」）に抵触する可能性があるため、その場合はユーザーの追加承認を得たうえで別途対応する。

指摘のうち、#1（重大）は実際に書込みが行われた後に失敗するケース（`Update-Yaml-Robust`内での例外、または再読込確認の不一致）でのみ発現し、これまでのテストケース（22・23・24）はいずれも書込み**前**に失敗を注入していたため検出できていなかった。今回、書込みを実際に成功させたうえで直後の検証だけを失敗させる新規テストケース（TE25）を追加し、修正前コードでは復元漏れが再現すること・修正後コードでは再現しないことの両方を確認した（6章参照）。

---

## 4. PowerShell実装内容

### 追加した関数（すべて新規、既存関数は無改修）

- `Get-YamlHeaderLines` : frontmatter行配列を返す。閉じていないfrontmatterは `$null`（不正YAML）、frontmatterなしは `@()`（補助ノート扱い）
- `Get-YamlBodyLines` : frontmatter終了`---`より後ろの本文行を返す（更新後の本文不変検証専用。ChatGPT再レビュー対応で追加）
- `Get-YamlScalarValue` : `UUID:` / `ランク:` / `総合計保険料:` 等のスカラー値を取得
- `Get-YamlTagValues` : `tags:` 配下のタグ値一覧を取得（変更要否判定・更新後tags検証の両方で使用）
- `New-UCIResponse` : `status/code/userMessage/requestId/updatedFiles/folderRenamed/oldFolder/newFolder` の固定スキーマでJSON文字列を生成
- `Test-UciUuidFormat` : `8-4-4-4-12` 16進形式のUUID形式チェック
- `Invoke-UpdateCustomerIdentity` : 本体処理

### 追加した分岐・分岐位置

`$payload = ConvertTo-Hashtable (...)` の直後、`$VaultRoot = ...`（既存Assert-ObsidianReady呼び出しおよび既存MODE判定 `$payload.MODE -eq "COMPARE"` を含む）より前に配置：

```powershell
if ($null -ne $payload -and ([string]$payload.action -eq "UPDATE_CUSTOMER_IDENTITY")) {
  try {
    Invoke-UpdateCustomerIdentity $payload
  } catch {
    # 予期しない例外でも既存Pipe形式(Out-NG)へ落ちずJSONのみを返す
    Write-Output (New-UCIResponse ... "NG" "EXECUTION_FAILED" ...)
  }
  exit 0
}
```

`try/catch` で囲み、Invoke-UpdateCustomerIdentity内部で捕捉されない予期しない例外が発生した場合でも、既存の末尾 `catch { Out-NG "ERROR" $msg }`（パイプ形式）に流れず、`EXECUTION_FAILED` のJSON応答のみを返して `exit 0` する。既存の `Out-OK` / `Out-NG` は新actionでは一切使用しない。

### 入力検証（実装指示書 第6章の順序に準拠）

`action`（呼び出し元で判定）→ `protocolVersion`（数値1のみ許容、それ以外・欠落は `UNSUPPORTED_PROTOCOL_VERSION`）→ `requestId`（必須・空欄不可、`MISSING_REQUIRED_FIELD`）→ `VaultRoot`（必須・実在確認、`MISSING_REQUIRED_FIELD` / `INVALID_VAULT_ROOT`）→ `pk_CLIENT`（必須・UUID形式チェック、`MISSING_REQUIRED_FIELD` / `INVALID_UUID`）→ `companyNameRaw`（必須・空欄不可・`Sanitize-LeafName`適用後が`NO_NAME`にならないこと、`MISSING_REQUIRED_FIELD` / `INVALID_CUSTOMER_NAME`）。`CEO` / `RUBY` / `RANK` は空欄可、検証なし。入力不正時は検索・書込み・リネームを一切行わない。

### UUID検索方法

`<VaultRoot>\01_顧客` 配下の `.md` を `Get-ChildItem -Recurse` で再帰検索し、各ファイルの YAML frontmatter（1行目が厳密に `---`、次に現れる単独行 `---` を終端とする既存の境界規則を踏襲）内の `UUID:` 値のみを対象に、`pk_CLIENT` と大文字小文字を無視して比較。本文中のUUID文字列は対象にしない。frontmatterが閉じていない（不正YAML）ファイルは検索対象からスキップする（対象フォルダ確定後の整合性チェックでは別途 `INVALID_YAML` として検知）。

### フォルダ特定方法

一致ノートの親フォルダ（`01_顧客`直下の第1階層フォルダ名）を集約。0件は `CUSTOMER_NOT_FOUND`、2フォルダ以上にまたがる場合は `UUID_FOLDER_CONFLICT`、1件のみの場合に対象フォルダとして採用。採用後、対象フォルダ配下（再帰）の全`.md`を確認し、UUIDキーが存在してかつ形式不正なら `INVALID_YAML`、形式は正しいが別UUIDなら `FOLDER_UUID_MIXED` として停止。UUIDキーのない補助ノートは許容し、フォルダリネーム時は自然にフォルダごと移動する（内容は変更しない）。

### 新フォルダ名・重複確認

`Sanitize-LeafName $payload.companyNameRaw "NO_NAME"` を再利用（`Normalize-ForMatch`は不使用）。現在フォルダ名と同一ならリネーム不要。異なる場合、`01_顧客`直下に同名の別フォルダが存在すれば `TARGET_FOLDER_ALREADY_EXISTS` とし自動統合しない。

### YAML更新方法

各UUID一致ノートについて、更新前に該当ノートの既存 `総合計保険料:` 値を読み取り、`Update-Yaml-Robust` へそのまま渡すことで値を保持する（空欄なら渡さず、新規追加もしない）。呼び出しは指示書どおり：

```powershell
Update-Yaml-Robust $filePath $rank $companyNameRaw $ceo $ruby $pkClient $existingTotalPremium
```

`Update-Yaml-Robust` 自体は無改修で再利用。呼び出し後、当該ファイルを再読込みし次の6点を確認する（実装指示書 第12章 手順10「更新後YAMLを再読込み確認」に対応。ChatGPT2回目レビュー指摘により`tags`・総合計保険料・本文の3項目を、3回目レビュー指摘により`noteType`を追加）：

1. `UUID` が `pk_CLIENT` と一致すること
2. `ランク` が `RANK` と一致すること
3. `tags` が顧客名・代表者名・RUBYから生成した期待タグ列と一致すること
4. 総合計保険料が、既存値があれば同値のまま保持され、無ければ新規追加されていないこと
5. `noteType` が存在していれば更新前後で同一の値を保持していること（存在しなければ何もしない）
6. frontmatterより後ろの本文（更新前にバックアップ済み）がテキスト内容として更新前後で一致すること（改行コードの正規化は許容。理由は3.5章「本文検証方式についての判断」を参照）

いずれか1つでも不一致の場合は書込み失敗として扱いロールバックへ進む。ファイル名は本アクションでは一切変更しないため、この点については変化しようがない。実Vaultの`01_顧客`配下491ファイルを調査した結果、現時点で`noteType`キーを持つノートは0件だった（3.5章参照）ため、指摘#7の検証は現状は常に「両方ともキーなし＝不変」として通過するが、将来的にnoteTypeキーが導入された場合に備えた安全網として機能する。

### 実行順序

payload検証 → UUID一致ノート全件検索 → 親フォルダ一意性確認 → フォルダ内UUID整合性確認 → 新フォルダ名生成・重複確認 → 変更要否判定（`NO_CHANGE`） → 対象ファイルの元内容をメモリへ保持（バイト単位バックアップ） → 必要ならフォルダリネーム → 新パス上でYAML更新＋再読込み確認 → JSON応答、の順（実装指示書 第12章と一致）。

### ロールバック方法

対象ノートは、実際に書込みを試行する**前**（`Update-Yaml-Robust`呼び出しより前）にロールバック対象一覧へ登録する（ChatGPTレビュー指摘によりこの順序へ修正。初回実装では更新・再読込確認の両方が成功した後でのみ登録していたため、書込みが実際に発生した後で例外または検証不一致が起きた場合に、当該ファイルが変更済みのまま残る余地があった）。ノート更新が1件でも失敗した場合、その回に処理対象だった全ノート（書込みが実際に発生したかどうかによらない）をメモリ上のバックアップ（更新前バイト列）で復元し、フォルダをリネーム済みなら旧名称へ復元する。復元順序は「更新済みノート内容 → フォルダ名」。両方成功すれば元の失敗コード（`NOTE_UPDATE_FAILED`）を返す。復元自体が失敗した場合は `UPDATE_ROLLBACK_FAILED` を返す。部分成功を正常終了として扱わない。

### JSON応答方法

新actionの応答は次の固定スキーマで統一し、`stdout`にはこのJSON文字列のみを出力する（`Write-Host`・診断表示・既存パイプ応答は混入させない。新規追加コード内に `Write-Host` / `Write-Warning` が無いことをコードレビューで確認済み）：

```json
{
  "status": "OK|NG",
  "code": "<コード>",
  "userMessage": "<利用者向けメッセージ>",
  "requestId": "<受信requestIdまたはnull>",
  "updatedFiles": 0,
  "folderRenamed": true,
  "oldFolder": "...",
  "newFolder": "..."
}
```

（`oldFolder`/`newFolder`はエラー時は省略、成功系・`NO_CHANGE`時のみ付与）

採用コード一覧（実装指示書 第13章の全16コードを実装）：`CUSTOMER_IDENTITY_UPDATED` / `NO_CHANGE` / `INVALID_PAYLOAD`（未使用・将来予約として残置はせず今回未発生経路。action不一致は呼び出し元で分岐するため本関数内では発生しない）/ `UNSUPPORTED_PROTOCOL_VERSION` / `MISSING_REQUIRED_FIELD` / `INVALID_VAULT_ROOT` / `INVALID_UUID` / `INVALID_CUSTOMER_NAME` / `CUSTOMER_NOT_FOUND` / `UUID_FOLDER_CONFLICT` / `FOLDER_UUID_MIXED` / `INVALID_YAML` / `TARGET_FOLDER_ALREADY_EXISTS` / `NOTE_UPDATE_FAILED` / `FOLDER_RENAME_FAILED` / `UPDATE_ROLLBACK_FAILED` / `EXECUTION_FAILED`。

**注記**：`INVALID_PAYLOAD` は指示書の必須コード一覧に含まれるが、本実装ではより具体的な `MISSING_REQUIRED_FIELD` 等へ分解したため、`Invoke-UpdateCustomerIdentity` 内部では使用箇所がない（action自体が一致しない場合は本関数が呼ばれず、既存処理へ流れるため該当なし）。将来的にpayload全体がJSONとして解析不能な場合の受け皿として使う余地はあるが、今回はその経路（`From-Base64Any`/`ConvertFrom-Json`失敗）は本関数の外側で発生し、既存の末尾catchが`Out-NG`（パイプ形式）で処理する。これは実装指示書が「新action処理では既存のOut-OK/Out-NGを使用しない」と定める範囲の外（payload解析そのものの失敗）であり、次点の手動確認事項として10章に記載する。

---

## 5. FileMaker成果物

- 新規スクリプト名：`EXT-obs_顧客名・代表者名同期`
- 作成形式：**FileMakerへ貼り付け可能な完全なスクリプト手順（テキスト）**。`fmxmlsnippet`（XML）は、このサンドボックスにFileMaker自体が無く生成したXMLが実際にインポート可能か検証できないため、今回は作成を見送った（誤ったXMLを成果物として渡すより、確実に手動再現できるスクリプト手順を渡す方が安全と判断）。
- **FileMaker本体へは未登録**（登録はユーザー側の操作が必要）
- VaultRoot取得ロジックについて：実装指示書 第4章の記述（第一候補 `z_sysClientPC::OB_VAULTPATH + z_sysClientPC::OB_VAULTNAME`、代替 `Get(ドキュメントパス)`）に基づいて構成したが、実際の `EXT-obs_OBSノート-開く` スクリプトの内部ステップはFileMaker本体（`.fmp12`）内にありこのサンドボックスから読み取れないため、**バイト単位の完全一致は保証できない**。貼り付け時に、実際の `EXT-obs_OBSノート-開く` のVaultRoot取得ステップと突き合わせて必要なら修正することを推奨する。

### スクリプト手順（貼り付け用）

```
# ============================================
# EXT-obs_顧客名・代表者名同期
# 新規スクリプト。既存スクリプトは一切変更しない。
# ============================================

Set Error Capture [ On ]

# 1. VaultRoot取得（EXT-obs_OBSノート-開くと同一ロジックを使用。
#    第一候補で取得できない場合は既存スクリプトと同じGet(ドキュメントパス)代替生成を使用する。
#    ※ 実際のEXT-obs_OBSノート-開くの該当ステップと突き合わせて確認・調整すること）
Set Variable [ $vaultRoot ; Value: z_sysClientPC::OB_VAULTPATH & z_sysClientPC::OB_VAULTNAME ]
If [ IsEmpty ( z_sysClientPC::OB_VAULTPATH ) or IsEmpty ( z_sysClientPC::OB_VAULTNAME ) ]
    # 代替生成（EXT-obs_OBSノート-開くの既存ロジックと同一のものに置き換えること）
    Set Variable [ $vaultRoot ; Value: Get ( ドキュメントパス ) ]
End If

# 2. requestId生成
Set Variable [ $requestId ; Value: Get ( UUID ) ]

# 3. 顧客フィールド取得
Set Variable [ $pkClient ; Value: 顧客::pk_CLIENT ]
Set Variable [ $companyNameRaw ; Value: 顧客::NAME ]
Set Variable [ $ceo ; Value: 顧客::CEO ]
Set Variable [ $ruby ; Value: 顧客::RUBY ]
Set Variable [ $rank ; Value: 顧客::RANK1LYear ]

# 4. 必須値検証（PowerShell側の検証に加え、FileMaker側でも早期チェック）
If [ IsEmpty ( $vaultRoot ) or IsEmpty ( $pkClient ) or IsEmpty ( $companyNameRaw ) ]
    Show Custom Dialog [ "エラー" ; "必須項目（Vault／顧客UUID／顧客名）が取得できませんでした。" ]
    Exit Script [ Text Result: ]
End If

# 5. JSON payload生成
Set Variable [ $payload ; Value:
    JSONSetElement ( "{}" ;
        [ "action" ; "UPDATE_CUSTOMER_IDENTITY" ; JSONString ] ;
        [ "protocolVersion" ; 1 ; JSONNumber ] ;
        [ "requestId" ; $requestId ; JSONString ] ;
        [ "VaultRoot" ; $vaultRoot ; JSONString ] ;
        [ "pk_CLIENT" ; $pkClient ; JSONString ] ;
        [ "companyNameRaw" ; $companyNameRaw ; JSONString ] ;
        [ "CEO" ; $ceo ; JSONString ] ;
        [ "RUBY" ; $ruby ; JSONString ] ;
        [ "RANK" ; $rank ; JSONString ]
    )
]

# 6. 既存の内部transportを呼び出す（EXT-obs_内部CallPS-PAYLOADは無改修で再利用）
Perform Script [ "EXT-obs_内部CallPS-PAYLOAD" ; Parameter: $payload ]

# 7. 結果取得
Set Variable [ $result ; Value: Get ( ScriptResult ) ]

# 8. stdout空チェック
If [ IsEmpty ( $result ) ]
    Show Custom Dialog [ "エラー" ; "処理結果が取得できませんでした。" ]
    Exit Script [ Text Result: ]
End If

# 9. JSON解析可否チェック
If [ JSONGetElementType ( $result ; "" ) ≠ JSONObject ]
    Show Custom Dialog [ "エラー" ; "応答を解析できませんでした。(INVALID_RESPONSE)" ]
    Exit Script [ Text Result: ]
End If

# 10. 各フィールドの型を先に取得する(ChatGPT再レビュー指摘により追加。
#    JSONGetElementTypeは、キーが存在しない場合 JSONNull ではなく
#    "? Incorrect key, index, or path" 形式のエラー文字列を返すため、
#    IsEmpty/"?"比較ではなくJSONGetElementTypeの型そのものを見て判定する)
Set Variable [ $typeStatus        ; Value: JSONGetElementType ( $result ; "status" ) ]
Set Variable [ $typeCode          ; Value: JSONGetElementType ( $result ; "code" ) ]
Set Variable [ $typeUserMessage   ; Value: JSONGetElementType ( $result ; "userMessage" ) ]
Set Variable [ $typeRequestId     ; Value: JSONGetElementType ( $result ; "requestId" ) ]
Set Variable [ $typeUpdatedFiles  ; Value: JSONGetElementType ( $result ; "updatedFiles" ) ]
Set Variable [ $typeFolderRenamed ; Value: JSONGetElementType ( $result ; "folderRenamed" ) ]

# 11. 必須応答項目の欠落・型不正チェック(ChatGPTレビュー指摘#4 → 再レビュー指摘#1で強化)
#    status/code/userMessage/requestIdはJSONString、updatedFilesはJSONNumber、
#    folderRenamedはJSONBooleanであることを型で確認する。
#    JSONGetElementTypeの戻り値が"?"で始まる場合はキー欠落／パス不正を意味する。
If [
    Left ( $typeStatus ; 1 ) = "?" or $typeStatus ≠ JSONString or
    Left ( $typeCode ; 1 ) = "?" or $typeCode ≠ JSONString or
    Left ( $typeUserMessage ; 1 ) = "?" or $typeUserMessage ≠ JSONString or
    Left ( $typeRequestId ; 1 ) = "?" or $typeRequestId ≠ JSONString or
    Left ( $typeUpdatedFiles ; 1 ) = "?" or $typeUpdatedFiles ≠ JSONNumber or
    Left ( $typeFolderRenamed ; 1 ) = "?" or $typeFolderRenamed ≠ JSONBoolean
]
    Show Custom Dialog [ "エラー" ; "応答に必須項目が欠落しているか、型が不正です。(INVALID_RESPONSE)" ]
    Exit Script [ Text Result: ]
End If

# 12. 各フィールド抽出(型検証を通過した後に取得)
Set Variable [ $respStatus        ; Value: JSONGetElement ( $result ; "status" ) ]
Set Variable [ $respCode          ; Value: JSONGetElement ( $result ; "code" ) ]
Set Variable [ $respUserMessage   ; Value: JSONGetElement ( $result ; "userMessage" ) ]
Set Variable [ $respRequestId     ; Value: JSONGetElement ( $result ; "requestId" ) ]
Set Variable [ $respUpdatedFiles  ; Value: JSONGetElement ( $result ; "updatedFiles" ) ]
Set Variable [ $respFolderRenamed ; Value: JSONGetElement ( $result ; "folderRenamed" ) ]
Set Variable [ $respOldFolder     ; Value: JSONGetElement ( $result ; "oldFolder" ) ]
Set Variable [ $respNewFolder     ; Value: JSONGetElement ( $result ; "newFolder" ) ]

# 13. requestId一致確認
If [ $respRequestId ≠ $requestId ]
    Show Custom Dialog [ "エラー" ; "応答のrequestIdが一致しません。(INVALID_RESPONSE)" ]
    Exit Script [ Text Result: ]
End If

# 14. folderRenamedをboolean型として正規化(GetAsBooleanで吸収する。
#    JSONGetElement はJSON booleanをFileMaker数値1/0として返す仕様であり、
#    GetAsBooleanはこれを正しく真偽値化できる)
Set Variable [ $folderRenamedBool ; Value: GetAsBoolean ( $respFolderRenamed ) ]

# 15. status/code判定
If [ $respStatus = "NG" ]
    Show Custom Dialog [ "エラー: " & $respCode ; $respUserMessage ]
    Exit Script [ Text Result: ]
End If

If [ $respStatus = "OK" and $respCode = "NO_CHANGE" ]
    # 何も表示せず正常終了
    Exit Script [ Text Result: ]
End If

If [ $respStatus = "OK" and $respCode = "CUSTOMER_IDENTITY_UPDATED" ]
    If [ $folderRenamedBool ]
        // folderRenamed=trueの場合、oldFolder/newFolderも必須項目として型確認する
        // (ChatGPT第3回レビュー指摘により追加)
        If [
            Left ( JSONGetElementType ( $result ; "oldFolder" ) ; 1 ) = "?" or
            JSONGetElementType ( $result ; "oldFolder" ) ≠ JSONString or
            Left ( JSONGetElementType ( $result ; "newFolder" ) ; 1 ) = "?" or
            JSONGetElementType ( $result ; "newFolder" ) ≠ JSONString
        ]
            Show Custom Dialog [ "エラー" ; "応答にフォルダ名情報が欠落しているか、型が不正です。(INVALID_RESPONSE)" ]
            Exit Script [ Text Result: ]
        End If
        Show Custom Dialog [ "顧客情報を更新しました。" ;
            "更新ノート数：" & $respUpdatedFiles & ¶ &
            "フォルダ名変更：あり" & ¶ &
            "旧フォルダ：" & $respOldFolder & ¶ &
            "新フォルダ：" & $respNewFolder ]
    Else
        Show Custom Dialog [ "顧客情報を更新しました。" ;
            "更新ノート数：" & $respUpdatedFiles ]
    End If
    Exit Script [ Text Result: ]
End If

# 16. それ以外は未知のstatus/codeとして扱う
Show Custom Dialog [ "エラー" ; "予期しない応答です。(INVALID_RESPONSE)" ]
Exit Script [ Text Result: ]
```

- payload生成：上記手順5のとおり（`JSONSetElement`）
- 内部CallPS呼出し：手順6（既存 `EXT-obs_内部CallPS-PAYLOAD` を無改修で再利用。既存フィールド `obs_URL` / `obs_RELPATH` / `obs_LASTKNOWNWRITE` / `obs_LASTSYNCAT` は本スクリプトでは一切更新しない）
- 応答解析：手順9〜13（JSON型チェック・各フィールドの型取得・**キー欠落／型不正の検証**（`JSONGetElementType`の戻り値が`"?"`始まりでないこと、かつ期待JSON型と一致すること）・各フィールド抽出・requestId一致確認）
- boolean正規化：手順14（`GetAsBoolean`。Claris公式仕様上、`JSONGetElement`はJSON booleanをFileMaker数値`1/0`として返すため、`GetAsBoolean`による正規化は仕様に適合する）
- 表示条件：手順15〜16（`NG`→エラー表示、`OK`+`NO_CHANGE`→無表示、`OK`+`CUSTOMER_IDENTITY_UPDATED`→成功ダイアログ、それ以外→`INVALID_RESPONSE`扱い）。エラー時に既存の候補フォルダ選択処理へは流さない（本スクリプトはそれを呼び出していない）

**ChatGPT再レビュー指摘への対応注記（2回目）**：初版の必須項目チェックは`JSONGetElementType(...) = JSONNull`で判定していたが、Claris公式ドキュメントによれば、指定キーが存在しない場合`JSONGetElementType`は`JSONNull`ではなく`"? Incorrect key, index, or path"`形式のエラー文字列を返す。そのため`JSONNull`比較では欠落を検出できない可能性があった。本改訂では`Left(...;1)="?"`によるエラー文字列判定と、期待する各JSON型（`JSONString`/`JSONNumber`/`JSONBoolean`）との一致確認を組み合わせる方式へ修正した。ただし、この修正自体もこのサンドボックスでは実機検証できていないため、貼り付け後に意図的に不完全なJSON（例：`updatedFiles`キーを欠いたテスト応答、または型の異なる値）を`$result`に代入し、分岐が正しく`INVALID_RESPONSE`になることを実機で確認してほしい。

---

## 6. テスト結果

**実行環境の制約**：このサンドボックスにPowerShellが存在しないため、`Invoke-UpdateCustomerIdentity` および補助関数（`Get-YamlHeaderLines` / `Get-YamlScalarValue` / `Get-YamlTagValues` / `Sanitize-LeafName` / `Update-Yaml-Robust`の書込み仕様）をPythonへ忠実に移植し、実ファイルシステム上のテスト用一時Vault（`/tmp/uci_test_vault`、本番Vaultとは完全に別領域）で実行した。PowerShell構文そのものの実行検証ではない点に留意（10章参照）。

全35件PASS（初回実装時28件 + ChatGPTレビュー1回目対応後の追加3件 + 2回目対応後の追加2件 + 3回目対応後の追加2件）。

| # | テスト名 | 入力（要点） | 期待結果 | 実結果 | 判定 |
|---|---|---|---|---|---|
| 1 | 顧客名だけ変更 | フォルダ「株式会社旧テスト」→ companyNameRaw="株式会社新テスト" | CUSTOMER_IDENTITY_UPDATED、フォルダrename | 同左 | PASS |
| 2 | 代表者名だけ変更 | CEO変更、フォルダ名一致 | CUSTOMER_IDENTITY_UPDATED、folderRenamed=false | 同左 | PASS |
| 3 | RUBYだけ変更 | RUBY変更のみ | CUSTOMER_IDENTITY_UPDATED | 同左 | PASS |
| 4 | RANKだけ変更 | RANK: C→S | CUSTOMER_IDENTITY_UPDATED | 同左 | PASS |
| 5 | 全項目同時変更 | 社名/CEO/RUBY/RANK全変更 | CUSTOMER_IDENTITY_UPDATED | 同左 | PASS |
| 6 | フォルダ名だけ変更 | tags等は事前一致、フォルダ名だけ相違 | CUSTOMER_IDENTITY_UPDATED、folderRenamed=true | 同左 | PASS |
| 7 | 複数UUID一致ノート一括更新 | 同一UUIDの2ノート | updatedFiles=2 | updatedFiles=2 | PASS |
| 8 | CEO空欄 | CEO="" | CUSTOMER_IDENTITY_UPDATED（tagsからCEO除外） | 同左 | PASS |
| 9 | RUBY空欄 | RUBY="" | CUSTOMER_IDENTITY_UPDATED | 同左 | PASS |
| 10 | RANK空欄 | RANK="" | CUSTOMER_IDENTITY_UPDATED（ランク行は空値で更新） | 同左 | PASS |
| 11 | 変更なし | 全項目・フォルダ名とも一致 | NO_CHANGE、updatedFiles=0 | 同左 | PASS |
| 12 | 総合計保険料あり | 既存値"1,234,567" | 更新後も同値を維持 | 維持確認 | PASS |
| 13 | 総合計保険料なし | フィールド自体なし | 更新後も追加されない | 追加なし確認 | PASS |
| 14 | UUIDなし補助ノートあり | frontmatterなしの「メモ.md」同居 | 補助ノートは内容不変のままフォルダごと移動 | 内容不変確認 | PASS |
| 15 | UUID一致なし | 別UUIDのノートのみ | CUSTOMER_NOT_FOUND | 同左 | PASS |
| 16 | 同一UUIDが複数フォルダに存在 | 会社A/会社Bに同一UUID | UUID_FOLDER_CONFLICT | 同左 | PASS |
| 17 | 対象フォルダ内に別UUID混在 | 同一フォルダに別UUIDノート | FOLDER_UUID_MIXED | 同左 | PASS |
| 18 | YAML破損 | frontmatter閉じタグなし | INVALID_YAML | 同左 | PASS |
| 19 | UUID形式不正 | pk_CLIENT="not-a-uuid" | INVALID_UUID | 同左 | PASS |
| 20 | 顧客名空欄 | companyNameRaw="   " | MISSING_REQUIRED_FIELD | 同左 | PASS |
| 21 | 同名移動先フォルダ存在 | 別UUIDの既存フォルダと新フォルダ名が衝突 | TARGET_FOLDER_ALREADY_EXISTS | 同左 | PASS |
| 22 | ノート書込み失敗→ロールバック | 2ノート中2件目で書込み失敗を強制（書込み前に失敗） | NOTE_UPDATE_FAILED、1件目も元内容(rank=C)へ復元 | 同左 | PASS |
| 23 | フォルダリネーム失敗 | リネームを強制失敗 | FOLDER_RENAME_FAILED、ファイル未変更 | 同左 | PASS |
| 24 | ロールバック確認（3件中2件目失敗） | 3ノート中2件目で失敗を強制（書込み前に失敗） | NOTE_UPDATE_FAILED、フォルダ旧名復元、1件目も復元 | folder_reverted=True, n1_reverted=True | PASS |
| 25 | **【ChatGPT指摘の回帰テスト】書込み後の検証失敗でも書込み済みノートがロールバックされる** | 2ノート中1件目(index0)は実際に書込み成功、2件目(index1)の再読込み確認だけを強制失敗 | NOTE_UPDATE_FAILED、1件目も元内容(rank=C)へ復元、フォルダも旧名復元 | 同左（n1_reverted=True, folder_ok=True） | PASS |
| 26 | protocolVersion不正 | protocolVersion=2 | UNSUPPORTED_PROTOCOL_VERSION | 同左 | PASS |
| 27 | **【追加】protocolVersionが文字列"1"（型不正）** | protocolVersion="1"（数値でなく文字列） | UNSUPPORTED_PROTOCOL_VERSION | 同左 | PASS |
| 28 | requestId欠落 | requestId="" | MISSING_REQUIRED_FIELD | 同左 | PASS |
| 29 | **【追加】requestIdが非文字列（型不正）** | requestId=12345（数値） | MISSING_REQUIRED_FIELD | 同左 | PASS |
| 30 | VaultRoot不在 | 存在しないパス | INVALID_VAULT_ROOT | 同左 | PASS |
| 31 | **【追加・証明テスト】更新後検証がtags改ざんを検出できることの証明** | 書込み成功後、tags内容を意図的に改ざんして再読込み確認へ | NOTE_UPDATE_FAILED | 同左 | PASS |
| 32 | **【追加・証明テスト】更新後検証が本文改変を検出できることの証明** | 書込み成功後、本文へ意図的に1行追記して再読込み確認へ | NOTE_UPDATE_FAILED | 同左 | PASS |
| 33 | 01_顧客フォルダなし | VaultRoot直下に01_顧客が無い | CUSTOMER_NOT_FOUND | 同左 | PASS |
| 34 | **【追加】noteType保持（キー有り）** | 対象ノートに`noteType: 顧客`が既存 | CUSTOMER_IDENTITY_UPDATED、noteType値が更新後も維持 | 同左 | PASS |
| 35 | **【追加】noteType保持（キー無し）** | 対象ノートにnoteTypeキー自体が無い | CUSTOMER_IDENTITY_UPDATED、更新後もキー無しのまま | 同左 | PASS |

**テスト#34・#35についての補足**：ChatGPT第3回レビュー指摘#7を受けて追加。実Vault調査では`noteType`キーを持つノートは0件だったが（3.5章参照）、キーが存在するケース・しないケースの両方で検証ロジックが正しく機能することを確認した。

**テスト#31・#32についての補足**：`Update-Yaml-Robust`自体は無改修の既存関数であり、実際にtagsや本文を誤って壊すことは通常想定されない。しかし「更新後再読込確認」という安全網そのものが機能することを示すため、書込み成功直後に意図的な改ざんを注入し、検証ロジックが確実に`NOTE_UPDATE_FAILED`を検出することを確認した。

**テスト#25についての補足**：この回帰テストは、ChatGPTが指摘した「ロールバック登録順序バグ」を実際に検出できることを確認するために追加した。修正前のロジック（更新・検証の両方が成功した後にのみロールバック対象へ登録する版）へ一時的に戻して同一条件で実行したところ、1件目のノートは実際にファイルへ書込みが行われていたにもかかわらずロールバック対象に含まれず、`ランク`が新値"A"のまま残ることを確認した（バグの再現）。登録順序を修正版（書込み試行前に登録）へ戻すと、同一条件で`ランク`が正しく"C"へ復元されることを確認した（修正の有効性確認）。

修正履歴：テスト#22の検証コード側に、ロールバック後の確認パスを新フォルダ名で参照してしまう誤りがあり、1回FAILした。ロールバックはフォルダを**旧名称へ戻す**動作が正しい仕様であることを確認し、検証コード（テストスクリプト側）を旧フォルダ名参照に修正して再実行し、PASSを確認した（実装側の修正ではない）。

**本番Vault非書込み確認**：実Vault（`01_顧客`、491 `.md`）のファイル数・サンプルファイルのMD5をテスト前後で比較し、変化がないことを確認した。テストはすべて `/tmp/uci_test_vault*` に対して実行した。

---

## 7. 非干渉確認

| 項目 | 結果 |
|---|---|
| CHECK | 本 `.ps1` に明示的な `CHECK` モード分岐は存在しない（既存コードの事実として確認）。新actionはこれに一切影響しない |
| COMPARE | `$payload.MODE -eq "COMPARE"` 分岐は新actionの分岐（`$payload.action -eq "UPDATE_CUSTOMER_IDENTITY"`）より後段に位置し、`exit 0`により新action実行時はCOMPARE分岐へ到達しない。COMPARE分岐自体は無改修（diffで確認） |
| APPLY | 本 `.ps1` に明示的な `APPLY` モード分岐は存在しない（既存コードの事実として確認） |
| 既存PIPE応答 | 既存の `Out-OK` / `Out-OKNeedFolder` / `Out-NG` 関数は無改修。新actionはこれらを一切呼び出さない |
| `EXT-obs_OBSノート-開く` | FileMaker側スクリプトであり本セッションからは変更不可能（`.fmp12`はバイナリでこのサンドボックスに存在しない）。今回一切触れていない |
| `EXT-obs_内部CallPS-PAYLOAD` | 同上。今回一切触れていない。新規FileMakerスクリプトから無改修のまま呼び出す設計とした |
| `.gitignore` | `git diff --stat -- .gitignore` は1行変更（改行コード差のみ、既知の既存差分）。今回のセッションでは一切編集していない |
| 既存未追跡ファイル（`FM-Obsidian-Bridge-Payload-JIKO.ps1_不要`） | `git status --short` で `??` のまま、内容・状態とも変化なし |
| stdout純度 | 新規追加コードブロック（`Invoke-UpdateCustomerIdentity`関数および分岐呼び出し部）に `Write-Host` / `Write-Warning` が存在しないことをgrepで確認（2回目レビュー対応後も維持）。新action実行時のexit経路すべてで `Write-Output` は1回のみ呼ばれる設計（各return直前に1回ずつ、計17箇所） |

---

## 8. diff

差分は `git diff -- FM-Obsidian-Bridge-Payload.ps1` の出力そのもの（最終時点で426行追加、0行削除）。全文は同フォルダに保存した `uci_diff_20260728_v4.patch` を参照（初版は`uci_diff_20260728.patch`、1回目レビュー対応後は`_v2.patch`、2回目対応後は`_v3.patch`として別途保存済み）。要点は4章・3.5章のとおり。挿入・修正位置は次の4箇所のみ：

1. `Update-Yaml-Robust` 関数の直後・`try {` の直前（新規関数群。`Get-YamlBodyLines`を追加し、requestId/protocolVersionの型検証ロジックを強化）
2. `$payload = ConvertTo-Hashtable (...)` の直後・`$VaultRoot = ...` の直前（分岐呼び出し。`EXECUTION_FAILED`用requestId取得ロジックを強化）
3. `Invoke-UpdateCustomerIdentity` 内、ノート更新ループ（`$processedPairs.Add($pair)`を書込み試行前へ移動。更新後再読込確認へtags・総合計保険料・noteType・本文不変の検証を追加）
4. `Invoke-UpdateCustomerIdentity` 内、バックアップ取得部（本文・noteType不変検証のため更新前の本文行・noteType値を保持するよう追加）

---

## 9. Git状態

```
branch: main
HEAD:   24cf1dc2b352edb855c5281954f481f91fe917ac  （変更なし。今回コミットしていないため既知の値のまま）
remote: なし

git status --short:
 M .gitignore                                  （既存差分。今回触れていない）
 M FM-Obsidian-Bridge-Payload.ps1               （今回の変更）
?? FM-Obsidian-Bridge-Payload-JIKO.ps1_不要      （既存未追跡。今回触れていない）

git diff --check -- FM-Obsidian-Bridge-Payload.ps1:  （出力なし＝warningなし、exit 0）
```

Git add／commit／push は実施していない。

---

## 10. 未完了事項

1. **実PowerShell実行によるテスト未実施**：このサンドボックスにPowerShell実行系が存在しないため、実行系テストはPythonへのロジック移植による代替検証にとどまる。ユーザー側のWindows環境（実際にFileMakerが呼び出すPowerShell 5.1想定）で、少なくとも正常系数件・異常系数件（特にテスト#25＝書込み成功後に検証だけ失敗するケース、テスト#31・#32＝検証ロジック自体の動作証明、テスト#34・#35＝noteType保持）を再実行し、本報告のテスト結果と一致することを確認してほしい。
2. **ChatGPTレビュー対応8点の実PowerShell環境・実FileMaker環境での再確認未実施**：3.5章の8点はPython移植コードでの検証にとどまる。特に指摘#5（FileMaker側の`JSONGetElementType`のキー欠落時の実返却値が`"?"`始まりのエラー文字列であるか）と指摘#4の`GetAsBoolean`の実挙動は、このサンドボックスにFileMakerが無いため実機でのみ確認可能。
3. **指摘#8（本文バイト完全一致検証）の採否についてユーザー・ChatGPTの最終承認が必要**：3.5章末尾の技術的判断（`Update-Yaml-Robust`が`WriteAllLines`＋`Environment.NewLine`によりWindows上で常にCRLF正規化を行うため、バイト完全一致検証は既存機能の副作用によりLF/混在改行ノートで常に失敗する）に基づき、今回は本文検証をテキスト内容比較のまま維持し、バイト完全一致化は不採用とした。これは実装指示書の停止条件（`Update-Yaml-Robust`を安全に再利用できない決定的事実）に該当し得る判断であるため、この報告を読んだ上でユーザー側の最終承認・または追加対応方針の指示を求める。
4. **FileMaker新規スクリプトのVaultRoot取得ロジックの厳密照合未実施**：`EXT-obs_OBSノート-開く` の実ステップ内容を読み取れないため、5章のスクリプト手順内のVaultRoot取得部分は指示書記載のロジック説明に基づく再現であり、実際の既存ステップとバイト単位で一致する保証はない。貼り付け時に既存スクリプトと突き合わせて確認・必要なら修正してほしい。
5. **FileMaker本体への新規スクリプト未登録**：5章の手順をFileMaker Script Workspaceへ手動で貼り付け・登録する必要がある。
6. **実機E2Eテスト未実施**：テスト用顧客1件を用いた実際のFileMaker→PowerShell→Obsidianの通しテストは未実施（本番Vault書込みを伴うため今回のスコープ外）。

「将来改善候補」に類する事項（fmxmlsnippet化、noteType体系整理、`Update-Yaml-Robust`の改行コード保持対応等）は本章に含めていない。

---

## 11. 次にユーザーが行う操作

1. 本報告・`uci_diff_20260728_v4.patch`・3.5章の対応内容（特に指摘#8の不採用判断）をChatGPTで再レビュー
2. 5章のスクリプト手順を、実際の `EXT-obs_OBSノート-開く` のVaultRoot取得ステップと突き合わせながらFileMaker Script Workspaceへ `EXT-obs_顧客名・代表者名同期` として新規登録
3. バックアップ取得（Vault・FileMakerファイルとも）
4. 対象顧客1件（テスト用データが望ましい）で実機テスト：顧客名変更→成功ダイアログ確認→Obsidian側フォルダ名・YAML確認
5. 同一条件で再実行し `NO_CHANGE`（無表示）になることを確認
6. 可能であれば、意図的にノート書込み後の失敗を再現できる条件（例：対象ノートを読み取り専用にする等）でロールバックが正しく機能することを実機で確認
7. 意図的に不完全なJSON応答（例：`updatedFiles`キー欠落、型不一致）を`$result`に代入し、FileMaker側の手順11が正しく`INVALID_RESPONSE`になることを確認
8. 既存の `EXT-obs_OBSノート-開く` によるノートオープン処理が従来どおり動作することを確認（非干渉の実機確認）
9. 採用可否判断
10. 必要に応じて `git add` / `commit` / `push`（このセッションでは未実施）

---

## 付録：本セッションで作成した検証用ファイル（このMac/Windows環境の作業フォルダに保存、Vault非干渉）

- `uci_sim_20260728_v4.py` : PowerShell新規ロジックのPython移植版・ChatGPT3回目レビュー対応後の最終版（検証専用、納品物ではない）
- `uci_run_tests_20260728_v4.py` : 35件のテストケース定義・実行スクリプト
- `uci_diff_20260728.patch` : 初版時点の差分（342行追加）
- `uci_diff_20260728_v2.patch` : ChatGPT1回目レビュー対応後の差分（350行追加）
- `uci_diff_20260728_v3.patch` : ChatGPT2回目レビュー対応後の差分（405行追加）
- `uci_diff_20260728_v4.patch` : ChatGPT3回目レビュー対応後・最終の差分（426行追加）
- `uci_git_status_20260728.txt` / `_v2.txt` / `_v3.txt` / `_v4.txt` : git状態記録（初版・1回目・2回目・最終）
