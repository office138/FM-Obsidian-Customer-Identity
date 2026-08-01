# CURRENT_STATE

## 現在地点

- Phase C-8: COMPLETE
- Phase C-8S1: COMPLETE
- Phase C-8S2: 初回atomic replacement失敗、本番未変更
- Phase C-8S2R: 明示backup pathで内容置換成功、ACL不一致検出により停止
- Phase C-8S2A: COMPLETE（同期前ACLへ復元、同期後検証PASS）
- Phase C-8S3: COMPLETE（本番側既存GitへBridge単独commit）
- 現在: Phase C-8S4

本番同期と本番Git commitは完了している。Phase C-8S4はGitHub文書だけを更新・commit・pushする工程である。次工程は最新Project State Package作成と独立検証、その後のtag／Release判断。Release、tag、最新移行後Project State ZIPは未作成。

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
- 元112 fingerprint: NOT VERIFIED、元資産書込み0
- Release／tag／最新移行後Project State ZIP: 未作成

次工程候補は、最新Project State Package作成、独立検証、tag／Release判断、保持中TEMP／backup／TestRootとE2Eテスト顧客の削除判断、旧staging／不要資産の後片付けである。未実施項目をCOMPLETEにしない。
