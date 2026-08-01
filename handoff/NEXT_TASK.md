# NEXT_TASK

## 現在地点

Phase C-9A／C-9BまでCOMPLETE。自己参照問題は`PACKAGE_METADATA/package_source_state.json`方式で解消し、`FM-Obsidian-Customer-Identity_20260801_1638_PRODUCTION_SYNC_VERIFIED_RESTART.zip`（376,266 bytes、SHA256 `7F1A25F892A716FFD688B8C2A945EA5A803C46F24332F781E9F2CA0D7CB0888C`、entries 78、payload 74、metadata 4）はBuild・独立検証PASS後に最新正式Project State Packageとして採用済み。現在はPhase C-9C。

## 次工程

Phase C-10 GitHub tag／Release準備として、次の順で判断する。

1. tag名・Release名・Release notesを確定する。
2. Package source HEADとC-9C後HEADのどちらをtag対象とするか明示判断する。
3. 正式Package assetを再検証する。
4. GitHub Releaseを作成し、Package ZIPをassetとして添付する。
5. Release assetのSize／SHA256とGitHub Web状態を独立確認する。
6. Release後の最終文書更新、backup／TEMP／TestRoot、E2Eテスト顧客、旧staging／不要資産の整理を判断する。

推奨候補はtag `v8.3.1-production-sync-verified`、Release title `v8.3.1 — Production Sync Verified`だが未確定。Phase C-9非正式FAIL候補`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`は保持し、正式再開基準として使用しない。Releaseとtagは未作成であり、未実施工程をCOMPLETEとして扱わない。

## 確定baseline

- GitHub repository: `office138/FM-Obsidian-Customer-Identity`、Private、branch `main`
- Phase C-8S4開始HEAD: `61dbc5cd9be5fc7fcb2a44d6d74467438d5ae376`、origin/main同値、commit count 2、clean
- 本番Bridge: `<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`
- Version 8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`
- 本番側既存Git: `<VAULT_ROOT>\scripts`、HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、clean、remote 0
- Parser: PS5.1／PS7 PASS、errors 0 / 0
- Windows回帰: 24 / 24 PASS、安全確認8 / 8 PASS
- FileMaker実機transport／NO_CHANGE／resolvedNotes参照パス更新: PASS
- 外部バックアップ、File.Replace backup、TEMP、TestRoot、report: 保持
- 元112 fingerprint: NOT VERIFIED、元資産書込み0

## 変更禁止

- GitHub版Bridge、本番Bridge、本番側既存Git、FileMaker、fixtureの変更
- Release、tag、Project State ZIPの先行作成
- バックアップ／TEMP／TestRoot／reportの削除
- 実Windowsユーザー名、実メール、実絶対パス、UUID、顧客情報、credential、secretの文書追加
