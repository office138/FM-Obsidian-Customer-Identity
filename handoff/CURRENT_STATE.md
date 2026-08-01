# CURRENT_STATE

## 現在地点

- Phase C-8: COMPLETE
- Phase C-8S1: COMPLETE
- Phase C-8S2: 初回atomic replacement失敗、本番未変更
- Phase C-8S2R: 明示backup pathで内容置換成功、ACL不一致検出により停止
- Phase C-8S2A: COMPLETE（同期前ACLへ復元、同期後検証PASS）
- Phase C-8S3: COMPLETE（本番側既存GitへBridge単独commit）
- Phase C-8S4: COMPLETE（GitHub文書commit・push）
- Phase C-9: Package生成・構造検証PASS、source HEAD自己参照要件により候補昇格停止
- Phase C-9A: COMPLETE（Package source-state metadata方式へ移行）
- Phase C-9B: COMPLETE（source-state付きPackage生成・独立検証・正式採用）
- 現在: Phase C-9C（正式採用Package情報の文書反映）

本番同期と本番Git commitは完了している。Phase C-9初回候補は自己参照要件により昇格を停止したが、Phase C-9Aで現行HEADをtracked文書へ固定せず`PACKAGE_METADATA/package_source_state.json`へ動的記録する方式に変更し、Phase C-9Bで新PackageのBuild・独立検証・正式採用まで完了した。Package自身の最終Size／SHA256はPackage外部で管理する。次工程はPhase C-10 GitHub tag／Release準備。Releaseとtagは未作成。

## GitHub repository

- Owner／repository: `office138/FM-Obsidian-Customer-Identity`
- Visibility: Private
- Default branch: `main`
- remote: `origin`
- Phase C-8S4開始HEAD／origin/main: `61dbc5cd9be5fc7fcb2a44d6d74467438d5ae376`
- 開始時commit count: 2
- 開始時ahead／behind: 0 / 0
- 開始時working tree: clean
- Phase C-8S4文書commitは第3commit。自己参照を避けるため、そのcommit IDは本文へ固定しない。
- Package source HEAD: `0cde9fe982f028259a142a914e2fd9cd85d91166`（Package生成時のorigin/mainと同値、commit count 4、clean、tracked files 74）
- Current repository HEAD: Gitで確認すること。C-9C文書commit IDは自己参照回避のため固定しない。

## 本番Bridge

- Path: `<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`
- Version: 8.3.1
- Size: 76,954 bytes
- SHA256: `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`
- GitHub版とのbyte一致: YES
- UTF-8 BOM: あり
- CRLF: 1,453
- LF単独／CR単独: 0 / 0
- 末尾改行: なし
- ACL owner: 同期前値へ復元済み
- ACL／SDDL: 同期前状態と一致
- Attributes: Archive
- ADS: 意図しない追加0

## 本番同期履歴

1. 外部バックアップ作成成功。
2. null backup pathによる`File.Replace`は失敗し、本番内容は未変更。
3. 明示backup pathによる`File.Replace`で内容置換成功。
4. sandbox owner／ACL継承によるmetadata不一致を検出して停止。
5. File.Replace backupが同期前ACLを保持していることを検証。
6. `Set-Acl`で同期前ACLを完全復元。
7. ACL復元前後で内容SHA256不変を確認。
8. Parser、Windows回帰、安全確認、COMPARE、FileMaker実機確認がPASS。

失敗履歴は保持するが、現在の本番Bridgeは内容・ACLとも正常に同期完了している。

## バックアップ／TEMP

- 外部バックアップ: `<BACKUP_ROOT>\ChatGPT\Archive\FM-Obsidian-Bridge-Payload_PRE_GITHUB_SYNC_20260801_125252.ps1`
- File.Replace backup: `<TEMP_ROOT>\FMOBS_PROD_SYNC_<ID>\FM-Obsidian-Bridge-Payload_FILE_REPLACE_BACKUP_<ID>.ps1`
- 両バックアップ: 75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`
- 状態: 両方保持
- 同期専用TEMP、回帰TestRoot、report: 保持
- 削除件数: 0

## 検証結果

- PS5.1 Parser／PS7 Parser: PASS、errors 0 / 0
- Windows回帰: 24 / 24 PASS、FAIL 0、SKIP 0
- 安全確認: 8 / 8 PASS
- fixture: 27 / 27不変
- FileMaker scripts: 3 / 3不変
- COMPARE focused: PASS
- 本番Vaultの意図しない変更: 0

### UPDATE_CUSTOMER_IDENTITY

- dispatch、NO_CHANGE、CUSTOMER_IDENTITY_UPDATED、MISSING_REQUIRED_FIELD、CUSTOMER_NOT_FOUND、folderRenamed、rollback: 実動テストPASS
- INVALID_UUID_FORMAT: 個別テストなし
- DUPLICATE_NOTE_TYPE: 個別テストなし、本番／GitHub差分なし
- resolvedNotes: 応答フィールド出力確認
- newline: LF／CRLF／MIXED本文保持PASS。更新後CRLF化は既知動作

### COMPARE

- Python resolver: PASS
- `FM_OBSIDIAN_PYTHON`: 未設定
- 選択: PATH上の`python.exe`、Python 3.13.9
- Application、絶対パス、`.exe`、実在Leaf: 確認済み
- 引数境界、WorkingDirectory、location復元、exit code、stdout／stderr: PASS
- COMPARE外resolver呼出し: 0
- 本番Vault書込み: 0

## FileMaker実機

- テスト対象: 削除予定E2Eテスト顧客
- 結果: `変更はありません。`
- FileMaker → 本番PowerShell transport: PASS
- NO_CHANGE: PASS
- resolvedNotes参照パス更新: PASS
- エラー: なし
- FileMaker変更: 不要
- 実顧客データ: 未使用

## 本番側既存Git

- repository: `<VAULT_ROOT>\scripts`
- branch: `main`
- HEAD: `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`（short `35c8bcb`）
- parent: `435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8`
- subject: `fix: resolve Python safely for compare mode`
- Author／Committer: `office138`、email非公開
- commit count: 3
- changed files: `FM-Obsidian-Bridge-Payload.ps1` 1件
- working tree: clean
- remote count: 0
- push: 未実施
- GitHub repositoryとは別履歴を維持し、GitHub remoteは追加しない。

## Package・次工程

- 正式Package: 326,389 bytes、SHA256 `94D78049B6F17EF2A10CCB046F4F8081D7A962FF8BF0BC075B0880100EA95C06`
- 最新正式Package: `FM-Obsidian-Customer-Identity_20260801_1638_PRODUCTION_SYNC_VERIFIED_RESTART.zip`、376,266 bytes、SHA256 `7F1A25F892A716FFD688B8C2A945EA5A803C46F24332F781E9F2CA0D7CB0888C`、entries 78（payload 74／generated metadata 4）、FORMALLY_ADOPTED: YES。Build・独立検証・manifest／checksums／payload byte・Parser・ZIP validationはPASS、既知のPackage問題なし。
- 保存先表記: `<BACKUP_ROOT>\ChatGPT\Archive\FM-Obsidian-Customer-Identity_20260801_1638_PRODUCTION_SYNC_VERIFIED_RESTART.zip`
- Package source-state: HEAD／origin/main `0cde9fe982f028259a142a914e2fd9cd85d91166`、commit count 4、tracked files 74、working tree clean、Package tool SHA256 `B6FBE3D32D8E2F53827F719C513FFA2E637A1B57732FAD6A4BAB73BDB9420ADF`。
- 上記326,389 bytesの直前正式Packageは過去正式証跡として保持する。
- Phase C-9非正式FAIL候補: `FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`、368,652 bytes、SHA256 `7D6A003BD87A132470922FF7F666DAEE4B338C7C023E214108321DC71521C8EB`。保持し、編集・再利用・正式採用しない。
- source repository state: 新Package生成時に`PACKAGE_METADATA/package_source_state.json`へ動的記録し、既存3 metadataと同じ自己参照除外集合として扱う。tracked文書へ生成時HEADを固定しない。
- Package自身のSHA256: Package外部の検証報告またはRelease情報で管理する。
- 元112 fingerprint: NOT VERIFIED、元資産書込み0
- Release／tag: 未作成

次工程はPhase C-10 GitHub tag／Release準備。tag名・Release名・notes・tag対象commit・Package assetを確認し、Release後に保持中TEMP／backup／TestRootとE2Eテスト顧客、旧staging／不要資産の整理を判断する。推奨候補はtag `v8.3.1-production-sync-verified`、Release title `v8.3.1 — Production Sync Verified`だが未確定。Package source HEADとC-9C後HEADのどちらをtag対象にするかは次工程で明示判断し、未実施項目をCOMPLETEにしない。
