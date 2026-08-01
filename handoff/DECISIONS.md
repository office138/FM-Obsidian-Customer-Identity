# DECISIONS

## GitHub移行

- GitHub repository `office138/FM-Obsidian-Customer-Identity`はPrivate、default branchは`main`、remoteは`origin`。
- command-scoped `safe.directory`だけを使用し、永続設定を追加しない。
- Phase C-8S4開始baselineはHEAD＝origin/main＝`61dbc5cd9be5fc7fcb2a44d6d74467438d5ae376`、commit count 2、clean。
- Phase C-8S4では許可文書だけを第3commitとしてpushし、Bridge、PowerShell、FileMaker、fixtureを変更しない。
- 第3commit IDは自己参照を避けるため本文へ固定しない。
- tracked文書へ、その文書自身を含むPackage生成時の現行HEADを固定しない。
- Package source repository stateは生成時だけ`PACKAGE_METADATA/package_source_state.json`へ動的記録する。このJSONはrepository payloadではないため、file_list／manifest／checksumsの自己参照除外集合へ加える。
- Package自身の最終Size／SHA256はPackage内部へ記録せず、外部検証報告またはRelease情報で管理する。
- `FM-Obsidian-Customer-Identity_20260801_1638_PRODUCTION_SYNC_VERIFIED_RESTART.zip`を最新正式Project State Packageとして採用する（376,266 bytes、SHA256 `7F1A25F892A716FFD688B8C2A945EA5A803C46F24332F781E9F2CA0D7CB0888C`、entries 78、payload 74、metadata 4）。
- Package source HEADは`0cde9fe982f028259a142a914e2fd9cd85d91166`。C-9C後の現行HEADとは区別し、現行HEADはGitで確認する。

## 本番同期

- 本番Bridgeは`<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`へ同期完了。
- `File.Replace`の初回失敗とACL不一致停止を履歴として保持する。明示backup pathによる内容置換後、検証済みFile.Replace backupから同期前ACLを完全復元した。
- 現在の本番Bridgeはv8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`でGitHub版とbyte一致。
- ACL ownerは同期前値へ復元済み、ACL／SDDLは同期前状態と一致。実アカウント名と完全SDDLは公開文書へ記載しない。
- 外部バックアップとFile.Replace backupは保持し、TEMP／TestRoot／reportもProject State Package完了前には削除しない。

## 検証・FileMaker

- PS5.1／PS7 Parser errors 0 / 0、Windows回帰24 / 24、安全確認8 / 8、COMPARE focused PASS。
- fixture 27 / 27、FileMaker scripts 3 / 3不変。本番Vaultの意図しない変更0。
- FileMaker実機transport、NO_CHANGE、resolvedNotes参照パス更新はPASS。FileMaker変更は不要。
- INVALID_UUID_FORMATとDUPLICATE_NOTE_TYPEを、個別テストPASSとして扱わない。
- LF／CRLF／MIXEDは本文保持PASSであり、更新後CRLF化は既知動作として記録する。

## 本番側既存Git

- GitHub repositoryとは別履歴を維持する。
- `<VAULT_ROOT>\scripts`の`main`へBridge 1件のみcommit済み。
- HEAD `35c8bcb43fb2a2fc5a29ce69e43629b684a8bf2d`、subject `fix: resolve Python safely for compare mode`、working tree clean、remote 0、push未実施。
- 本番GitへGitHub remoteを追加しない。Author／Committer名は`office138`、emailは非公開とする。

## 次工程と保護

- 次工程はPhase C-10 GitHub tag／Release準備。推奨候補はtag `v8.3.1-production-sync-verified`、Release title `v8.3.1 — Production Sync Verified`だが未確定であり、tag対象commitも次工程で判断する。
- Releaseとtagは未作成。
- 直前正式Packageは過去正式証跡として保持する。
- Phase C-9非正式FAIL候補`FM-Obsidian-Customer-Identity_20260801_1602_PRODUCTION_SYNC_VERIFIED_RESTART.zip`（368,652 bytes、SHA256 `7D6A003BD87A132470922FF7F666DAEE4B338C7C023E214108321DC71521C8EB`）は保持し、編集・再利用・正式採用しない。
- 正式Package、両バックアップ、TEMP、TestRoot、report、元112資産は保持する。
- 実Windowsユーザー名、実メール、実絶対パス、ACL実名／SDDL、顧客名、UUID、credential、token、secretをrepository文書へ追加しない。
- 元112 fingerprintはNOT VERIFIEDのままとし、MATCHと断定しない。
