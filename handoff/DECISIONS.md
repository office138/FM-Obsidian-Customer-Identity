# DECISIONS

## GitHub移行

- 新GitHub repositoryは、C-5D開始時点の67件にrepositoryメタファイルを加えた限定資産で新規作成する。
- 既存ローカルGitの履歴は継承せず、commit `435cc9fd0b4ff7ec2d6dd839bdabae4053d6fba8`は移植しない。
- GitHub repositoryはPrivate、初期collaboratorは0とする。
- `main`を保護し、通常変更はfeature branch、小差分、focused test、full regression、diff確認、独立レビュー、ChatGPT最終レビューを経る。
- 現在はGitHub repository、remote、commit、push、Releaseのいずれも未作成。

## 連携・データ保護

- FileMakerを正本とし、FileMaker → Obsidianの片方向同期とする。
- UUID完全一致検索を使用し、UUID識別子付きの顧客フォルダ名・管理対象ノート名へ常時正規化する。
- 本番Vaultと顧客実データをGitHubへ入れない。
- `filemaker/`書き出しと`tests/fixtures/`はbyte-sensitive資産としてGit変換を無効化する。
- Package Buildは`-Build`明示時だけ実行し、既存ZIPを上書きしない。

## 確定実装

Phase C-5C2Bで`tools/package/build_package_final.ps1`を確定した。Sizeは19,565 bytes、SHA256は`BC2A14DC0A4D450792CE67410FF069032B672E3803BD84393B6FF77A9557D5EE`。PowerShell 5.1 / 7 Parser、EvidenceなしBuild、EvidenceありBuild、危険EvidenceRoot拒否、source不変はいずれもPASS。

Phase C-5C2Cで`FM-Obsidian-Bridge-Payload.ps1` Version 8.3.1を確定した。Sizeは76,970 bytes、SHA256は`DE1B0123C86954657F40B0B06E2321195D112AA7361AB76F7C47C7D4697714E6`。PowerShell 5.1 / 7 Parser、Windows回帰24 / 24、安全確認8 / 8はいずれもPASS。`UNEXPECTED_LOGIC_CHANGE`は0。

## 記録上の制約

- 元112 fingerprintの期待値は`090EA5DD79E6C9AF1F3FA7E9CBB4074F68826FEC3010CAAE0436A96B6A6AA57D`だが、正規算出方式を復元できないため結果はNOT VERIFIEDを維持する。母集団112件、元資産書込み0。
- `INVALID_PAYLOAD`、`DUPLICATE_UUID`、`WRITE_FAILED`、`POST_WRITE_VERIFICATION_FAILED`は現行実装では未確認。過去設計資料だけを根拠に実装へ追加しない。
- `DUPLICATE_NOTE_TYPE`と`resolvedNotes`は本番との差分なしであり、今回個別の実動テスト確認済みとは表現しない。
