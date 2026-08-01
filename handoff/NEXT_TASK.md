# NEXT_TASK

## 現在地点

Phase C-8S4までCOMPLETE。本番Bridge同期、ACL復元、機械検証、FileMaker実機transport確認、本番側既存Git commit、GitHub文書commit・pushは完了した。Phase C-9はPackage生成・構造検証PASS後、現行HEADのtracked文書固定が自己参照になるため候補昇格を停止した。Phase C-9AではPackage生成時だけ`PACKAGE_METADATA/package_source_state.json`へsource repository stateを動的記録する方式へ移行する。

## 次工程

Phase C-9A完了後は、次の順で判断する。

1. 更新後toolと新HEADを基準に新しいProject State Packageを作成する。
2. `package_source_state.json`のsource HEAD照合を含めてPackageを独立検証する。
3. GitHub tag／Releaseの作成可否を判断する。
4. 保持中の外部バックアップ、File.Replace backup、同期専用TEMP、回帰TestRoot、reportの削除可否を判断する。
5. E2Eテスト顧客の削除可否を判断する。
6. 旧staging／不要資産の後片付けを判断する。

Phase C-9非正式FAIL候補`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`（368,652 bytes、SHA256 `7D6A003BD87A132470922FF7F666DAEE4B338C7C023E214108321DC71521C8EB`）は保持し、編集・再利用・正式採用しない。未実施の工程をCOMPLETEとして扱わない。Release、tag、新Packageはまだ作成しない。

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
