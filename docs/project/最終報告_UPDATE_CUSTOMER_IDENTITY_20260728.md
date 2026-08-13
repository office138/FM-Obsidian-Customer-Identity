# UPDATE_CUSTOMER_IDENTITY — Windows PowerShell 5.1 実行検証フェーズ 最終報告

実行日: 2026-07-28 / 実施者: Claude Cowork

## 1. 総合判定

**B: 主要テスト合格。一部手動確認または限定的補足試験が必要**

理由は「実装に問題が見つかった」からではなく、**Claude Cowork の実行環境に Windows PowerShell が存在せず、
本フェーズが本来求める「Windows PowerShell 5.1 による実コード実行」をClaude自身では実施できなかった**ため。
静的コードレビューでは重大な欠陥は見つからなかったが、実機実行による確証がまだ無い状態であり、A判定は出せない。

## 2. 実行環境

- Claude Cowork側: Linuxサンドボックス(Ubuntu 22.04.5 LTS)。PowerShellは未インストールで、
  導入も不可能だった(下記4節参照)。
- 作業ディレクトリ(Claude側): `D:\FM-Script-Backup`
- テスト用Vaultパス: 未作成(Windows実機での実行待ち。生成スクリプトのみ用意)
- 本番Vault非書込み確認: 済み。セッション中、`【Vault】INS\01_顧客` 配下に更新されたファイルは0件。

## 3. 開始時状態(実測)

| 項目 | 値 |
|---|---|
| 対象ファイル | `【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1` |
| SHA256 | `04c48003fb1b462214cd85edb457d84b0b0e9e893fe913432faae7234fb524b5` |
| サイズ | 42,594 bytes |
| BOM | UTF-8 BOMあり |
| 改行コード | LFのみ(CR検出0件) |
| branch | main |
| HEAD | `24cf1dc2b352edb855c5281954f481f91fe917ac` |
| remote | なし |
| git status --short | ` M .gitignore` / ` M FM-Obsidian-Bridge-Payload.ps1` / `?? FM-Obsidian-Bridge-Payload-JIKO.ps1_不要` |

前回報告値と完全一致。差異なし。

## 4. 実行環境に関する重大な制約(最初に報告すべき事実)

Windows PowerShell 5.1 はおろか、PowerShell Core (`pwsh`) すら Linuxサンドボックスに導入できなかった。

- `apt-cache search/show powershell` → パッケージなし
- GitHub Releases (`github.com`) → プロキシで403拒否
- Microsoft Packages (`packages.microsoft.com`) → プロキシで403拒否
- npm/pypi は疎通可能だが、これらはPowerShell本体の配布元ではない

このため、本フェーズの核心である「実PowerShellコードの直接実行」はClaude単独では完了できない。
ユーザーへ相談し、**(1) Linux上でのベストエフォート静的レビュー + (2) Windows実機用テストキットの作成**
の両方を行う方針で承認を得て、以下を実施した。

## 5. 実施内容

### 5-1. 静的コードレビュー(Linux上、実行なし)

対象ファイル全928行を通読し、仕様書 第6〜17節の各要件と実装を1行ずつ突き合わせた。

主な確認結果:

- 入力検証順序(protocolVersion → requestId → VaultRoot → pk_CLIENT → companyNameRaw)は
  コード上のコメントと実装が一致していた。
- protocolVersionの型検証(数値のみ許可、文字列"1"は拒否)、requestIdの型検証(文字列のみ許可)は
  仕様通りの分岐になっていた。
- UUID検索がYAML frontmatter内の`UUID:`キーのみを対象とし、本文中の文字列を拾わない実装に
  なっていることを確認した。
- フォルダ一意特定(0件→CUSTOMER_NOT_FOUND、複数→UUID_FOLDER_CONFLICT)、フォルダ内整合性
  (別UUID混在→FOLDER_UUID_MIXED、YAML破損/UUID形式不正→INVALID_YAML)の判定順序・優先順位は
  仕様書 第9〜10節と一致していた。
- フォルダ名生成に`Sanitize-LeafName`のみを使用し、`Normalize-ForMatch`を使っていないこと
  (第11節の確定仕様)を確認した。
- ロールバックは、書込みを試行する前に対象を`processedPairs`へ登録してから処理する実装になっており、
  「途中で失敗しても該当ノートが必ず復元される」設計であることをコードレベルで確認した
  (632〜649行目)。復元順序(ノート→フォルダ)も仕様通り。
- 更新後再読込確認は、UUID・ランク・tags・総合計保険料・noteType・本文の6項目すべてを検証しており、
  第13節の8項目のうち実質的に該当する全項目をカバーしていた。
- 改行コード(CRLF正規化)に関する第14節の合意事項は、コード内コメント(604〜615行目)に
  明記されており、本文比較を行区切り(改行コード非依存)で行う実装になっていた。

**発見事項(バグではないが要確認)**: 仕様書 第17節にある `INVALID_PAYLOAD` エラーコードは、
現在の実装のどこからも出力されない。Base64/JSONのデコード自体が失敗した場合は、
UPDATE_CUSTOMER_IDENTITY用の新JSON応答ではなく、既存の`Out-NG`(旧PIPE形式`NG|ERROR|...`)
に流れる(663行目の`ConvertFrom-Json`が例外を投げた場合、actionの判定に到達する前に
outerのcatch節に落ちるため)。FileMaker側は非JSON応答を`INVALID_RESPONSE`として扱う設計なので
実害は無いと考えられるが、`INVALID_PAYLOAD`という専用コードを仕様書が定義した意図と実装に
ズレがある。修正要否はユーザー/ChatGPTの判断事項として提起するに留め、Claudeからの改修は行っていない。

### 5-2. git差分による非干渉確認(Linux上、実行不要のため実施可能)

```
git diff --stat -- FM-Obsidian-Bridge-Payload.ps1
 FM-Obsidian-Bridge-Payload.ps1 | 426 +++++++++++++++++++++++++++++++++++++++++
 1 file changed, 426 insertions(+)
```

- 追加426行・削除0行を実測で確認(前回報告値と一致)。
- `git diff --check`はエラーなし(空白関連の問題なし)。
- 削除行が1件も無いことを`git diff`の生出力からも確認(`^-[^-]`にマッチする行が0件)。
- これにより、既存のCOMPARE処理・既存PIPE応答関数・通常ノートオープン処理のコードは
  **1バイトも変更されていない**ことが構造的に保証されている(新規関数・新規分岐の追加のみ)。
- `.gitignore`は今回未変更(このセッションでは触れていない)。既存未追跡ファイル
  (`FM-Obsidian-Bridge-Payload-JIKO.ps1_不要`)も未変更。

### 5-3. Windows実機用テストキットの作成

Windows PowerShell 5.1で実際に実行できる自己完結型テストハーネス`Run-UCITests.ps1`を作成し、
`D:\FM-Script-Backup\WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\`に保存した。

内容:

- 実行のたびに使い捨てのテスト用Vaultを自動生成し、本番Vaultには一切触れない設計。
- `[System.Management.Automation.Language.Parser]::ParseFile()`による対象スクリプトの
  **真の構文確認**(Windows実機で初めて意味を持つ検証)。
- 正常系10件、異常系9件、ロールバック重点試験1件、改行コード試験3件(LF/CRLF/混在)の
  計23自動テストケース。各テストでstdoutのJSON純度(旧PIPE形式混入がないこと、JSON単体で
  あること)も同時に検証する。
- 実行後、`_report.txt`(人間向け)と`_report.json`(機械可読)を自動生成する。
- `FOLDER_RENAME_FAILED`と`UPDATE_ROLLBACK_FAILED`は安全な自動再現方法が無かったため
  自動化対象から除外し、README内に手動確認の手順を記載した。

このキットはLinux上ではSHA256とバランスチェック(括弧・波括弧の対応)のみ確認済みで、
**実PowerShellパーサーによる構文確認はまだ行えていない**。Windows実機での初回実行時に
判明する可能性がある。

## 6. 未完了事項(本当に残っているものだけ)

- Windows PowerShell 5.1 による実コード実行が未実施(本フェーズの核心)。
- 上記に伴い、正常系・異常系・ロールバック・改行コード・stdout純度・非干渉の「実行による」確証は
  すべて未取得(静的レビューのみ)。
- `FOLDER_RENAME_FAILED` / `UPDATE_ROLLBACK_FAILED` の手動確認が未実施。
- `INVALID_PAYLOAD`エラーコード未使用の件について、ユーザー/ChatGPTの判断が未取得。

## 7. 次に行う操作(推奨順)

1. ユーザーが `D:\FM-Script-Backup\WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\README_実行手順.md` の
   手順に沿って、Windows PowerShell 5.1で `Run-UCITests.ps1` を実行する。
2. 生成された `_report.txt` をClaudeまたはChatGPTに共有する。
3. Claudeが結果を解析し、本報告書を更新する(必要なら追加修正提案)。
4. `FOLDER_RENAME_FAILED` / `UPDATE_ROLLBACK_FAILED` を手動確認する(任意、リスクを許容できる場合のみ)。
5. `INVALID_PAYLOAD`未使用について方針決定(現状維持 or 実装追加)。
6. ChatGPTによる最終レビューとFileMaker登録可否判定。
7. 影響の小さい顧客1件での限定E2E、その後の採用判断。

## 付録: 生成物一覧

- `D:\FM-Script-Backup\WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\Run-UCITests.ps1`
- `D:\FM-Script-Backup\WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\README_実行手順.md`
- 対象ファイルのバックアップ(Claude作業領域内。本番Gitや Vault には影響しない一時コピー)
