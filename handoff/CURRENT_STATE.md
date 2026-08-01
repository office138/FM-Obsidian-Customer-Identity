# CURRENT_STATE

## 現在地点

- Phase C-5C1: COMPLETE
- Phase C-5C2A: COMPLETE
- Phase C-5C2B: COMPLETE
- Phase C-5C2C: COMPLETE
- Phase C-5D: COMPLETE
- Phase C-5E: COMPLETE
- Phase C-6: COMPLETE
- Phase C-7: COMPLETE
- Phase C-8: COMPLETE（GitHub状態反映・handoff更新）

次工程は本番Bridge同期準備。GitHub Release、tag、GitHub移行後の最新Project State ZIPは未作成。本番PowerShellはGitHub版未反映である。

## GitHub repository

- Owner: `office138`
- Repository: `FM-Obsidian-Customer-Identity`
- Visibility: Private
- Default branch: `main`
- URL: `https://github.com/office138/FM-Obsidian-Customer-Identity`
- remote: `origin`
- remote URL: `https://github.com/office138/FM-Obsidian-Customer-Identity.git`
- credential埋込み: なし
- committed files: 73
- 禁止ファイル、ZIP、`LOCAL_EVIDENCE`、report、`.env`、一時ファイル: 0

## Initial commit

- Full: `0708ce25ff073a84c9f178a1549810c91b9f605f`
- Short: `0708ce2`
- Subject: `feat: establish FileMaker Obsidian customer identity project`
- Parent: なし
- Author / Committer: `office138 <157262077+office138@users.noreply.github.com>`
- Co-authored-by: なし
- Phase C-7確認時: local `main` = `origin/main`、ahead 0、behind 0、upstream `origin/main`、working tree clean

Phase C-8の文書commitはこの状態記録を追加する2件目のcommitであり、自己参照となるためcommit IDを本文へ固定しない。

## 確定ファイル

### GitHub版Bridge

- Path: `FM-Obsidian-Bridge-Payload.ps1`
- Version: 8.3.1
- working tree: 76,954 bytes、SHA256 `7EFD3C5D94D9A4BAF98D422071C3C1843669E12B5DC30976D0957988E3F19D69`
- committed blob: `e45fc337fde2643f40026913d8ddf5a3a1342814`
- committed blob SHA256: `548AD01CBD975A53442DBEBB72E67D3B961F7F8F21BF053254F8904B0CF4D9D3`
- working tree: UTF-8 BOMあり、CRLF、末尾改行なし
- Git blob: UTF-8 BOMあり、LF、末尾改行なし
- 論理内容差: 改行正規化以外0

### Package tool

- Path: `tools/package/build_package_final.ps1`
- Size: 19,565 bytes
- SHA256: `BC2A14DC0A4D450792CE67410FF069032B672E3803BD84393B6FF77A9557D5EE`

## 検証結果

- Windows PowerShell 5.1: 機能23件 + 構文確認1件 = 24 / 24 PASS
- 安全確認: 8 / 8 PASS
- Parser: PS5.1 9 / 9 PASS、PS7 9 / 9 PASS
- fixture: 27 / 27 byte不変
- FileMaker: 3 / 3 byte不変
- Package validation: PASS、TYPE REPOSITORY、INCLUDED_FILES 73
- `.git`混入、ZIP生成、source変更、一時残留: 0

## Git属性

- Bridge: `text eol=crlf`
- Package tool: `text eol=lf`
- `tests/windows/*.ps1`: `text eol=lf`
- `filemaker/**`: `-text`
- `tests/fixtures/**`: `-text`

## 本番PowerShell

- Path表記: `<VAULT_ROOT>\scripts\FM-Obsidian-Bridge-Payload.ps1`
- Size: 75,488 bytes
- SHA256: `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`
- 状態: GitHub版未反映

## Package・fingerprint

- GitHub Release: 未作成
- tag: 未作成
- 最新GitHub移行後Project State ZIP: 未作成
- 過去の正式Package: 326,389 bytes、SHA256 `94D78049B6F17EF2A10CCB046F4F8081D7A962FF8BF0BC075B0880100EA95C06`（過去時点の証跡。上書きしない）
- 元112 fingerprint: 期待値 `090EA5DD79E6C9AF1F3FA7E9CBB4074F68826FEC3010CAAE0436A96B6A6AA57D`、結果 NOT VERIFIED、母集団112件、元資産書込み0
- NOT VERIFIEDの理由: 正規算出方式を現存資料から復元できないため。MATCHと記載しない。

## 次工程

本番Bridge同期準備として、GitHub版と本番版の差分確定、本番バックアップ、反映可否判断を行う。現時点では本番へのコピー、既存ローカルGitの履歴変更、Release作成、旧staging削除を行わない。
