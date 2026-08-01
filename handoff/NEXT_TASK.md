# NEXT_TASK

## Phase C-5E：repository全体の最終検証

C-5Dで追加した6件を含む73ファイルを対象に、GitHub公開前の最終read-only検証を行う。

## 必須検証

- 全ファイル数と全相対パス
- 秘密情報、実ユーザー名、実メール、固定ローカルパス、実顧客情報
- 各ファイルのSize、SHA256、文字コード、BOM、改行、末尾改行
- Windows PowerShell 5.1 ParserとPowerShell 7 Parser
- Windows回帰テスト24 / 24と安全確認8 / 8
- `tests/fixtures/`のbyte不変
- `filemaker/`書き出しのbyte不変
- `README.md`、`.gitignore`、`.gitattributes`と実構成の整合
- Package validation-only（ZIP生成0、source変更0、一時残留0）
- `.git`不存在、ZIP混入0、一時物混入0
- 正式Project State Package、既存ローカルGit、本番PowerShellの不変
- 元112 fingerprintはNOT VERIFIED、母集団112件、元資産書込み0を維持

## 完了前の禁止操作

- `git init`、`git add`、commit、branch作成
- remote追加、push、GitHub repository作成、Release作成
- 旧staging削除、正式Package新規作成
- 本番Vault、顧客実データ、元112資産、既存ローカルGit、本番PowerShellへの書込み

不一致を検出した場合は追加修正を繰り返さず、実測値を報告して停止する。
