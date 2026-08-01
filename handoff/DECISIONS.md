# DECISIONS

## GitHub移行

- GitHub repository `office138/FM-Obsidian-Customer-Identity`をPrivateで作成済み。default branchは`main`。
- remoteは`origin`、URLは`https://github.com/office138/FM-Obsidian-Customer-Identity.git`。credentialを埋め込まない。
- Initial commitは`0708ce25ff073a84c9f178a1549810c91b9f605f`（`feat: establish FileMaker Obsidian customer identity project`）、親なし、73 files。
- Author / Committerは`office138 <157262077+office138@users.noreply.github.com>`、Co-authored-byなし。
- command-scoped `safe.directory`だけを使用し、global／system／localの永続`safe.directory`設定を追加しない。
- GitHub Release、tag、最新GitHub移行後Project State ZIPは未作成。

## 本番同期

- GitHub版Bridgeと本番Bridgeの同期はGitHub側確認後の別工程とする。
- 本番PowerShellは現時点で未変更。GitHub版は未反映。
- 同期前に差分確定と本番バックアップを必須とする。
- 反映後はPS5.1 Parser、24 / 24回帰、安全確認8 / 8、FileMaker実機影響確認を行う。

## 連携・データ保護

- FileMakerを正本とし、FileMaker → Obsidianの片方向同期とする。
- 本番Vault、顧客実データ、credential、token、環境固有絶対パスをGitHubへ入れない。
- `filemaker/`と`tests/fixtures/`はbyte-sensitive資産としてGit変換を無効化する。
- Package Buildは`-Build`明示時だけ実行し、既存ZIPを上書きしない。

## 確定実装・検証

- Package tool: 19,565 bytes、SHA256 `BC2A14DC0A4D450792CE67410FF069032B672E3803BD84393B6FF77A9557D5EE`。
- GitHub版Bridge: Version 8.3.1、76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`。
- Parser: PS5.1 9 / 9、PS7 9 / 9 PASS。
- Windows回帰: 24 / 24 PASS、安全確認8 / 8 PASS。
- fixture 27 / 27、FileMaker 3 / 3 byte不変。

## 記録上の制約

- 元112 fingerprintは期待値`090EA5DD79E6C9AF1F3FA7E9CBB4074F68826FEC3010CAAE0436A96B6A6AA57D`に対しNOT VERIFIED。正規算出方式を現存資料から復元できず、母集団112件、元資産書込み0。MATCHと記載しない。
- 過去の36 / 36は過去試験記録であり、現在の回帰値として扱わない。
