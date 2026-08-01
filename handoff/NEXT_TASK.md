# NEXT_TASK

## 本番Bridge同期準備

Phase C-8完了後の次工程は、GitHub版Bridgeと本番Bridgeの差分を確定し、安全な本番同期計画を作ることである。現時点で本番同期は未実施。

## 作業対象

- GitHub版 `FM-Obsidian-Bridge-Payload.ps1`
- `<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`
- 本番バックアップ
- 差分分類
- 本番反映可否判断

## 確定基準

- GitHub版: Version 8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`
- 本番版: 75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`
- GitHub repository: `office138/FM-Obsidian-Customer-Identity`、Private、branch `main`
- Initial commit: `0708ce25ff073a84c9f178a1549810c91b9f605f`
- Release / tag / 最新GitHub移行後Project State ZIP: 未作成

## 承認済み同期手順

1. GitHub版と本番版の差分確定
2. 本番バックアップ
3. 本番へ承認済みBridgeを反映
4. PS5.1 Parser
5. 24 / 24回帰
6. 安全確認8 / 8
7. FileMaker実機影響確認
8. 本番Size・SHA256更新
9. 既存ローカルGitへの反映方針決定
10. Project State文書更新

## 変更禁止

- 本番へ即時コピー
- 既存ローカルGitの履歴変更
- Release・tag作成
- 旧staging削除
- 差分確定・バックアップ・承認前の本番更新
