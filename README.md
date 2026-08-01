# FM-Obsidian Customer Identity Bridge

FileMakerを正本（Source of Truth）とし、顧客情報をFileMakerからObsidianへ片方向同期するWindows向け連携資産です。UUIDを不変識別子として完全一致検索に使用し、顧客名・代表者名・RUBY・RANKの更新、顧客フォルダ名と管理対象ノート名の常時正規化を行います。

## 主要機能

- `UPDATE_CUSTOMER_IDENTITY` action
- UUID完全一致による対象顧客・対象ノートの識別
- YAMLの`NAME`、`CEO`、`RUBY`、`RANK`更新
- 顧客フォルダrenameと管理対象ノートrename
- 処理後の実体を`resolvedNotes`として返却
- Windows PowerShell 5.1対応

## Repository構成

```text
FM-Obsidian-Bridge-Payload.ps1   PowerShell本体（Version 8.3.1）
filemaker/                       FileMakerスクリプト書き出し
tests/windows/                   Windows回帰テストと補助テスト
tests/fixtures/                  byte-sensitiveなテストfixture
docs/project/                    設計・状態・判断・レビュー記録
docs/claude/                     実装・調査資料
handoff/                         再開用資料と現在状態
tools/package/                   安全なPackage検証・生成ツール
```

## 前提環境

- Windows PowerShell 5.1（実行・回帰テスト確認済み）
- PowerShell 7 Parser互換（構文解析確認済み）
- FileMaker Pro
- Base Elements Plug-In
- Obsidian

## 現在の検証結果

- Windows PowerShell 5.1: 機能テスト23件 + 構文確認1件 = 24 / 24 PASS
- 安全確認: 8 / 8 PASS
- PowerShell 5.1 Parser: PASS
- PowerShell 7 Parser: PASS

fixtureに含まれる名称・UUIDはテスト専用です。本番Vaultや顧客実データを試験に使用しないでください。

## 安全上の注意

- 本番Vaultをテスト対象にしない。
- 顧客実データをrepositoryへ入れない。
- `.env`、API key、token、password、secretを保存しない。
- `tests/fixtures/`のbyte状態を変更しない。
- `filemaker/`配下のBOM・改行を変更しない。
- 正式変更はfocused test、full regression、diff確認、独立レビューの順で検証する。

## Package検証・生成

`tools/package/build_package_final.ps1`は、引数なしではusageを表示するだけで書き込みません。`-Validate`はread-only、`-Build`を明示した場合だけ新しいZIPを作成します。既存ZIPは上書きせず、`.git`、過去ZIP、一時物、生成レポート、`PACKAGE_METADATA`のsource側実体をPackage対象から除外します。`LOCAL_EVIDENCE`は`-EvidenceRoot`を明示し、安全検査を通過した場合だけ収録されます。

Repositoryを検証する例:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File "<REPOSITORY_ROOT>\tools\package\build_package_final.ps1" `
  -Validate -RepositoryRoot "<REPOSITORY_ROOT>"
```

既存ZIPを検証する例:

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File "<REPOSITORY_ROOT>\tools\package\build_package_final.ps1" `
  -Validate -ValidationTarget "<BACKUP_ROOT>\<PACKAGE_NAME>.zip"
```

新規ZIPを生成する場合だけ、既存の出力ディレクトリと未使用のPackage名を指定します。

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
  -File "<REPOSITORY_ROOT>\tools\package\build_package_final.ps1" `
  -Build -RepositoryRoot "<REPOSITORY_ROOT>" `
  -OutputDirectory "<BACKUP_ROOT>\Packages" -PackageName "<PACKAGE_NAME>"
```

## GitHub運用方針

新しいPrivate repositoryとして運用し、`main`を保護対象にします。通常変更はfeature branch上の小差分とし、focused test、full regression、diff確認、独立レビュー、ChatGPT最終レビューを経てcommit・pushします。節目だけReleaseを作成します。

現時点ではGit repositoryの初期化、initial commit、GitHub repository作成、remote設定、push、Release作成はいずれも未実施です。Repository URL、branch HEAD、Release tagは未確定です。

再開時は[`handoff/CURRENT_STATE.md`](handoff/CURRENT_STATE.md)と[`handoff/NEXT_TASK.md`](handoff/NEXT_TASK.md)を先に確認してください。
