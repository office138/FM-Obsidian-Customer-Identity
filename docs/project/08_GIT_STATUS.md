# 08_GIT_STATUS

## GitHub移行トラック（Phase C-5D、2026-08-01）

C-5C2B / C-5C2C / C-5D COMPLETE、次工程C-5E。開始時67件を維持し、6件追加後73件。stagingには`.git`がなく、git init、git add、initial commit、branch、remote、push、GitHub repository、Releaseは未作成。確定値はpackage tool 19,565 bytes / `BC2A14DC0A4D450792CE67410FF069032B672E3803BD84393B6FF77A9557D5EE`、bridge v8.3.1 76,970 bytes / `DE1B0123C86954657F40B0B06E2321195D112AA7361AB76F7C47C7D4697714E6`。PS5.1 / PS7 Parser、Windows回帰24 / 24、安全確認8 / 8 PASS。元112 fingerprintはNOT VERIFIED（母集団112、書込み0）。C-5E完了前にGit書込みを行わない。

Phase 1B read-only調査正式完了・Package更新時点（再確認日：2026-07-26、読取専用コマンドのみで確認、git add/commit等は一切実行していない）。

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
