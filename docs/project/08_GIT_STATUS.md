# 08_GIT_STATUS

## GitHub移行トラック（Phase C-9A、2026-08-01）

GitHub repositoryは`office138/FM-Obsidian-Customer-Identity`、Private、branch `main`、remote `origin`。C-8S4の第3commit・pushまで完了した。Phase C-9AではPackage生成時のsource repository stateを`PACKAGE_METADATA/package_source_state.json`へ動的記録する。tracked文書へ、その文書自身を含む現行HEADを固定しない。

本番側既存GitはGitHubとは別履歴。repository表記`<VAULT_ROOT>\scripts`、branch `main`、HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`（short `35c8bcb`）、parent `435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8`、subject `fix: resolve Python safely for compare mode`、commit count 3、working tree clean、remote 0、push未実施。changed fileは`FM-Obsidian-Bridge-Payload.ps1` 1件。Author／Committerは`office138`、email非公開。

本番Bridgeは76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`でGitHub版とbyte一致し、同期前ACLへ復元済み。PS5.1／PS7 Parser errors 0 / 0、回帰24 / 24、安全8 / 8、COMPARE focused、FileMaker実機transport／NO_CHANGE／resolvedNotes参照パス更新PASS。

Git操作ではcommand-scoped `-c safe.directory=<REPOSITORY_ROOT>`だけを使用し、永続safe.directory設定を追加しない。Phase C-9非正式FAIL候補は保持し、編集・再利用・正式採用しない。Release、tag、新Packageは未作成。backup、TEMP、TestRoot、reportは保持。元112 fingerprintはNOT VERIFIED。

## Historical Git Status

以下はPhase 1B時点の監査履歴であり、冒頭のPhase C-8状態を上書きしない。

## リポジトリ
```
<REPOSITORY_ROOT>
```

## HEAD
```
24cf1dc2b352edb855c5281954f481f91fe917ac
```

## Branch
```
main
```

## 直近commit
```
commit 24cf1dc2b352edb855c5281954f481f91fe917ac
Author: office138 <<GIT_AUTHOR_EMAIL>>
Date:   Wed Jul 22 17:14:05 2026 +0900

    chore: establish FileMaker Obsidian scripts baseline

 30 files changed, 3501 insertions(+)
```

## Working Tree（2026-07-26 Claude Cowork再実測）
```
On branch main
Changes not staged for commit:
	modified:   .gitignore

Untracked files:
	FM-Obsidian-Bridge-Payload-JIKO.ps1_不要

no changes added to commit (use "git add" and/or "git commit -a")
```

- Git root: `<REPOSITORY_ROOT>`
- branch: `main`
- HEAD: `24cf1dc2b352edb855c5281954f481f91fe917ac`
- remote: なし
- 既知untracked: `FM-Obsidian-Bridge-Payload-JIKO.ps1_不要`
- 2026-07-26の実測では`.gitignore`が`M`と表示された。
- `.gitignore`の`M`表示は環境・実行条件によって変動した履歴がある。
- 今回のGit diffは1行削除・1行追加として認識された。
- 対応する可視文字列は同一である。
- 差分は最終行付近の改行状態に由来するとみられる。
- 原因は確定していない。`core.autocrlf`単独を原因とは断定しない（詳細は「Git改行設定の実測記録」節を参照）。
- Phase 1B/本レビューによる変更：なし（読取専用コマンドのみ実行）。

## Git改行設定の実測記録（2026-07-26）
- `core.autocrlf`：未設定
- `core.eol`：未設定
- `core.safecrlf`：未設定
- `.gitattributes`：存在しない
- `.gitignore`：Git上では変更ありとして表示される。numstatは1行追加・1行削除。可視文字列の変更は確認されない。差分は最終行付近のEOL差とみられるが、原因は未確定。
- 推奨：`.gitattributes` での改行コード方針固定を将来検討（`06_TODO.md`）。

## 未追跡（許容・保留中）
```
FM-Obsidian-Bridge-Payload-JIKO.ps1_不要
```

## リモート
```
なし
```

## 今回の Package 作成作業で実行した git コマンド（すべて読取専用）
```
git status
git status --short
git status --ignored
git branch --show-current
git rev-parse HEAD
git log --oneline -12
git diff --stat
git diff --check
git remote -v
```
git add / commit / push / reset / restore / checkout / switch / clean / stash はいずれも実行していない。

## 想定外ファイルの発生・調査・削除記録（2026-07-25）
- path: `' + $outPath + '`
- 発生場所: Git管理下scriptsディレクトリ直下
- Size: 16100 Bytes
- SHA256: `C3A165978C86735F6DD6E3232188D83E1832DAF84B3DB07A602FFFC706CC95DC`
- 更新日時: 2026-07-25 18:58:57 +0900
- Git状態: untracked
- 内容: staleな文書検索／context report
- Package価値: なし
- 秘密情報: なし
- 調査: 削除前にサイズ・SHA256・内容・Git状態を確認した。
- 処置: SHA256照合後、完全一致するパスを指定して削除した。
- `.gitignore`追加: なし
- 現在: 実体なし、Git statusから消滅を確認済み
- 原因（仮説、未確定）: 出力先パス式が評価されず、式文字列がファイル名として扱われた可能性がある。原因は未確定。
