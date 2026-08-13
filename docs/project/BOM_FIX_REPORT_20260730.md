# 本番PowerShell BOM付加作業 証跡レポート

## 作業日時
2026-07-30

## 1. 事前検証（Pre-check）結果
本番PowerShellファイル (`C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload.ps1`) の修正前状態を確認しました。
- **Length**: 66,924 bytes
- **SHA256**: `38B46E0338AEB7645BCC0FBE6116717C31CC58704B7A6EDB76E2FF67D48F8F10`
- **先頭16バイト**: `3C-23-20-3D-3D-3D-3D-3D-3D-3D-3D-3D-3D-3D-3D-3D`
- **判定**: プロンプトで指定された期待値と完全一致。

## 2. バックアップ作成
変更を加える前に、完全なバイトコピーによるバックアップを作成しました。
- **保存先**: `C:\Users\Fujitsu1320\Documents\07Obsidian\【Vault】INS\scripts\FM-Obsidian-Bridge-Payload_PRE_20260730_BOM_FIX.ps1`
- **バックアップ後SHA256**: `38B46E0338AEB7645BCC0FBE6116717C31CC58704B7A6EDB76E2FF67D48F8F10`
- **判定**: 本番修正前ファイルとバイナリ完全一致を確認。

## 3. BOM付加処理
テキストエディタの保存や再エンコード処理を避け、純粋なバイト操作により先頭3バイト（`0xEF, 0xBB, 0xBF`）を付加し、本番パスへ書き戻しました。

## 4. 事後検証（Post-check）結果
修正後の本番PowerShellファイル状態を確認しました。
- **Length**: 66,927 bytes (期待通り3バイト増加)
- **SHA256**: `4F714DC2A4EC451B16B038287063F0009622916ACAA7A72EF62C8296B092A911`
- **先頭16バイト**: `EF-BB-BF-3C-23-20-3D-3D-3D-3D-3D-3D-3D-3D-3D-3D`
- **判定**: 期待値通りのBOM付きファイル（先の検証における「BOM付き版」と全く同一のSHA256）として正常に生成されました。

## 5. 作業完了報告
本番PowerShellファイルへのBOM付与は、本文や改行コードに一切の変更を加えることなく、安全かつ完全に完了しました。FileMaker、Vault、およびGitへの操作は一切行っていません。

## Windows PowerShell 5.1 BOM比較試験の確定結果

- **比較目的**: `BE_ExecuteSystemCommand`の10100およびstdout `?`障害について、UTF-8 BOM欠落が原因かを切り分けるため。
- **実行環境**: Windows PowerShell 5.1
- **比較対象**: BOM有無以外が同一のPowerShellスクリプト。
- **BOMなし版**: Size 66,924 bytes、SHA256 `38B46E0338AEB7645BCC0FBE6116717C31CC58704B7A6EDB76E2FF67D48F8F10`、ExitCode 1、Parser Error 119件。
- **BOMあり版**: Size 66,927 bytes、SHA256 `4F714DC2A4EC451B16B038287063F0009622916ACAA7A72EF62C8296B092A911`、ExitCode 0、Parser Error 0件。
- **バイト差分**: BOM 3バイト以外は同一。
- **結論**: BOM欠落が10100／stdout `?`障害の直接原因。
- **試験データ**: TestVault差分なし。本番データ不使用。
- **現在の正式本番PowerShell**: Size 75,488 bytes、SHA256 `3B929018983E0786FE0853B8F389EF8624A4A4BF6D10E14E4F29BE12551D6030`。
- **ロールバック方針**: 旧BOMなし版は既知の障害版であり、ロールバック対象ではない。
- **証跡統合**: 比較目的、入力、結果、ハッシュ、結論を本レポートへ統合済み。
- **生試験物**: `BOM_COMPARE_20260730`配下の生試験物は、運用、復旧、再現、監査に不要。
- **処分方針**: Phase C-1.1で削除対象として確定。削除はPhase C-3で実行予定。
