# UPDATE_CUSTOMER_IDENTITY — Windows PowerShell 5.1 実行検証キット

## これは何か

Claude Cowork の実行環境(Linuxサンドボックス)には PowerShell が一切インストールできず
(GitHub / packages.microsoft.com がネットワーク許可リストで遮断されているため)、
本フェーズが求める「Windows PowerShell 5.1 による実コード実行」を Claude 側では実施できませんでした。

代わりに、Windows実機で実行できる自己完結型のテストハーネスを用意しました。
`Run-UCITests.ps1` が、本番Vaultとは完全に別の使い捨てテスト用Vaultを自動生成し、
`FM-Obsidian-Bridge-Payload.ps1` の `UPDATE_CUSTOMER_IDENTITY` action を実際に呼び出して、
結果を自動判定・レポート出力します(機能テスト23件＋構文確認1件＝総24結果)。

**本番Vault (`【Vault】INS`) には一切書き込みません。対象PowerShellも書き換えません。**
(ロールバック試験でのみ、失敗注入のための一時コピーを TestRoot 配下に作成しますが、
テスト直後に確実に削除し、削除できたことと対象PowerShell本体のSHA256が変化していないことを
実行終了時に自動確認します。詳細は「補正内容」節を参照。)

## 2026-07-28 補正内容(このキットのみ改修。対象PowerShellは無改修)

1. **ロールバック試験の注入方式を変更**: 「読み取り専用属性で書込み自体を失敗させる」方式から、
   「テスト専用の一時コピーに対して、書込み成功後・再読込確認より前に例外をthrowする1行だけを
   注入する」方式へ変更した。仕様書第15節が明示的に求める「書込み自体は完了したが、その後の
   再読込検証で失敗したケース」をより正確に再現する。対象PowerShell本体は読み取り専用でしか
   参照しない。
2. **終了時整合性確認を追加**: テスト終了後、(a) 失敗注入用の一時コピーが残存していないこと、
   (b) 対象PowerShell本体のSHA256が既知値
   (`04c48003fb1b462214cd85edb457d84b0b0e9e893fe913432faae7234fb524b5`)
   から変化していないことを自動確認し、「安全確認」として別集計で報告する。
3. **TestRootの絶対パス安全確認を強化**: 文字列の部分一致(正規表現)ではなく、
   `[System.IO.Path]::GetFullPath()` で絶対パス化したうえでの厳密な一致/包含判定に変更した。
   本番Vault配下・ドライブルート・空パス・Windows/Program Files/ユーザープロファイル等の
   危険な上位フォルダを無条件で拒否する。
4. **実行環境の強制確認を追加**: スクリプト開始直後に `$PSVersionTable` を検査し、
   Windows PowerShell 5.1 (Desktop Edition) 以外(`pwsh.exe`など)での実行を即座に拒否する。
5. **件数表記を統一**: 「機能テスト23件＋構文確認1件＝総24結果」に表記を統一した
   (内訳は変更なし。正常系10・異常系9・ロールバック1・改行コード3＝機能23、構文確認1)。
6. `INVALID_PAYLOAD`エラーコード未使用の件は、既知事項として記録するのみとし、
   対象PowerShellへの改修は行っていない(前回報告のとおり)。

## 2026-07-28 追加補正(ChatGPTレビュー反映。B判定時の必須修正)

**構文エラー時に即時停止するよう変更した。** 従来は構文確認の結果を記録するだけで、
対象PowerShellに構文エラーがあっても後続23件の機能テストがそのまま実行され、同じ構文エラー
由来の連続FAILと本来の機能試験結果が混在する設計になっていた。これを、次のとおり修正した。

- `Invoke-SyntaxCheck` が真偽値(`$syntaxOk`)を返すようにした。
- 構文エラーが1件でもあれば、機能テストへは一切進まず、その場で `_report.txt`/`_report.json`
  を出力したうえで `exit 1` する(再起動プロンプトで確定した停止条件「Windows PowerShell 5.1
  パーサーで構文エラーが1件でもあれば、機能テストを開始せず停止する」に合わせた)。
- レポート出力処理を `Write-FinalReport` 関数に切り出し、通常終了時・構文エラーによる
  早期停止時の両方から呼べるようにした(早期停止時もレポートは必ず残る)。
- 件数確認(機能23+構文1=総24)を、単なる警告表示から「安全確認」の1項目
  (`テスト件数確認`)として記録し、不一致の場合は終了コードにも反映するようにした。
- 終了コードは `$failCount -gt 0 -or $safetyFail -gt 0 -or -not $IntegrityOk -or -not $countOk`
  のいずれかに該当すれば `1`、それ以外は `0` とした。

## 実行手順

1. repository rootの `tests\windows` を実行ディレクトリとし、TestKitルートは `<TESTKIT_ROOT>` とする。

2. Windows PowerShell 5.1 (`powershell.exe`、`pwsh.exe` ではない) を管理者権限不要で起動する。

3. 次を実行する。

   ```powershell
   cd <REPOSITORY_ROOT>\tests\windows
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Run-UCITests.ps1 `
       -TargetScript "<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1" `
       -ProductionVaultRoot "<VAULT_ROOT>"
   ```

   `-TargetScript` はrepository rootのPowerShellを指定する。`-ProductionVaultRoot`には環境固有の
   `<VAULT_ROOT>`を明示する。

4. 実行が終わると、コンソールに各テストの PASS/FAIL が表示され、最後に
   `TestVault_UPDATE_CUSTOMER_IDENTITY\_report.txt` と `_report.json` が生成される。

5. `_report.txt` の内容をそのまま Claude または ChatGPT に貼り付けて共有すれば、
   結果の解析・最終報告書の作成を引き継げる。

## 自動実行される内容

- 構文確認: `[System.Management.Automation.Language.Parser]::ParseFile()` で対象スクリプトを
  実際にパースし、ParseError件数を報告する(Windows実機での初の真の構文確認)。
- 正常系10件: 顧客名変更+フォルダリネーム、代表者名変更、RUBY変更、RANK変更、複数UUID一致ノート
  更新、総合計保険料保持、noteTypeありの保持、noteTypeなしの非追加、UUIDなし補助ノート不変、
  NO_CHANGE再実行。
- 異常系9件: CUSTOMER_NOT_FOUND、UUID_FOLDER_CONFLICT、FOLDER_UUID_MIXED、INVALID_YAML(未クローズ)、
  INVALID_YAML(UUID形式不正)、INVALID_UUID(pk_CLIENT)、TARGET_FOLDER_ALREADY_EXISTS、
  protocolVersion文字列"1"拒否、requestId数値拒否。
- ロールバック重点試験1件: 対象PowerShellの一時コピーに「書込み成功後・再読込確認より前」の
  throwを注入し(2件目のノート処理時に発火)、フォルダ名・両ノートの内容がともに元へ復元される
  こと、応答が `NOTE_UPDATE_FAILED` であることを確認する。一時コピーはテスト直後に削除し、
  削除できたことを確認する。
- 改行コード試験3件: LF / CRLF / 混在改行の本文を用意し、更新後も本文の文字内容が変わらないこと
  (改行コード自体がCRLFへ正規化されるのは第14節で合意済みの既知動作として許容)を確認する。
- 各テストで stdout が JSON単体であること(旧PIPE形式`OK|...`/`NG|...`の混入がないこと)も同時に検証する。

## 自動化できなかった項目(手動確認が必要)

以下は安全に自動再現する方法がなかったため、今回のキットには含めていない。
必要であれば個別に手動確認すること。

- **FOLDER_RENAME_FAILED**: フォルダのリネームそのものを失敗させるには、フォルダ内のファイルを
  別プロセスで開いてロックする、または ACL でリネーム権限を拒否する必要があり、環境依存が大きい。
  手動確認する場合は、対象フォルダ内のファイルをエディタ等で開いたままにしてロックした状態で
  実行し、`FOLDER_RENAME_FAILED` が返ることを確認する。
- **UPDATE_ROLLBACK_FAILED**: ロールバック(バイト列復元・フォルダ名復元)自体を失敗させる必要が
  あり、ノート復元とフォルダ復元の両方を意図的に失敗させる安全な方法がなかった。
  手動確認する場合は、ロールバック対象ノートを書込み不可な場所(読み取り専用+フォルダも
  読み取り専用など)に置いた上で失敗を注入し、応答が `UPDATE_ROLLBACK_FAILED` になることを確認する。

## 非干渉確認(別途、手動でのgit差分確認を推奨)

このキットはコード差分は見ない。既存 COMPARE / 既存PIPE応答関数 / `.gitignore` /
既存未追跡ファイルへの非干渉は、Claude Cowork側で `git diff --stat` により
「426行追加・0行削除」であることを確認済み(本レポートに同梱の最終報告を参照)。
Windows実機でも念のため `git status --short` と `git diff --stat` を確認することを推奨する。
