# EXT-obs_顧客名・代表者名同期 追加仕様：obs_RELPATH / obs_URL の正式パスへの更新

作成日: 2026-07-29 / 作成者: Claude Cowork
状態: **ドラフトのみ。FileMaker未登録・本番実行なし。**

対象: `EXT-obs_顧客名・代表者名同期`（最終ドラフトA・最終ドラフトBの両方に共通で適用可能）
目的: `CUSTOMER_IDENTITY_UPDATED`成功後、PowerShell応答の`newFolder`/`renamedNotes`を用いて
`顧客::obs_RELPATH`と`顧客::obs_URL`を正式パスへ更新する。

## 0. 前回ドラフトからの位置づけ

最終ドラフトA・Bはいずれも「7. 未確定事項」の4番目で次のように明記していた。

> 成功時にFileMaker側フィールドを更新する設計は採用していない(未確認フィールドの推測追加を避けるため)。

本ドキュメントはこの未確定事項を解消するための**追加仕様**である。既存ドラフトの本文(セクション1〜8)は
一切変更しない。追加は次の2箇所のみ。

1. セクション1「顧客レコード情報の取得」に1行追加（更新前の`obs_RELPATH`を保持する）
2. `$respCode = "CUSTOMER_IDENTITY_UPDATED"`ブロック内、既存の最終ダイアログの直前に
   新規ステップ群を追加し、最終ダイアログのメッセージ文字列に1変数を連結する

`EXT-obs_内部CallPS-PAYLOAD`・`EXT-obs_OBSノート-開く`・PowerShell本体はいずれも変更しない。

---

## 1. 前提調査（read-only）

### 1.1 PowerShell応答スキーマの確認結果

`New-UCIResponse`（本体 442〜457行付近）を確認した。

- `oldFolder`・`newFolder`は**folderRenamedの真偽に関わらず常に応答へ含まれる**
  （`folderRenamed=false`の場合は`oldFolder == newFolder`になるだけで、キー自体は欠落しない）。
- `renamedNoteCount`・`renamedNotes`は**該当ノートが0件の場合、キー自体が応答から欠落する**
  （`if ($renamedNoteCount -gt 0) { ... }`のガードがあるため）。FileMakerの
  `JSONGetElement`は存在しないキーに対し`"?"`始まりのエラー文字列を返すため、
  この欠落を「0件」として扱う分岐が必要。
- `renamedNotes`は`{ oldName, newName }`（**ファイル名のみ。フルパスではない**）の配列。
- `newFolder`・`oldFolder`も**フォルダの葉名のみ**（`01_顧客`配下のフォルダ名。フルパスではない）。
- 応答に`url`相当のキーは存在しない（`obs_URL`はこの応答からは組み立てられず、FileMaker側で
  URIを構築する必要がある）。

### 1.2 obs_RELPATH / obs_URL の実際の値形式の確認結果

`EXT-obs_OBSノート-開く.txt`（既存・変更しない）を確認した。同スクリプトは
legacy CHECK/APPLYモードの応答（パイプ区切り）の第3・第4値をそのまま
`フィールド設定`で`obs_URL`・`obs_RELPATH`へ書き込んでいる。この値はPowerShell本体の
`Get-RelPath`（65〜68行）・`Get-ObsidianOpenUrl`（70〜76行）が生成したものであり、

- `obs_RELPATH`の形式: `01_顧客/<フォルダ名>/<ファイル名>.md`
  （**スラッシュ区切り・.md拡張子を含む**。バックスラッシュではない）
- `obs_URL`の形式: `obsidian://open?vault=<vaultNameのURLエンコード>&file=<relPathのURLエンコード>`
  （`[Uri]::EscapeDataString`で**文字列全体**をエンコード。`/`もエンコード対象＝`%2F`になる）

この2点は今回の追加仕様でも同じ形式を再現する。

### 1.3 URLエンコードの手段の確認結果

PowerShellの`[Uri]::EscapeDataString`に相当するFileMaker側の手段を調査した。

- BaseElementsプラグイン（本ソリューションで既に使用中。`BE_FileExists`等）には
  汎用のURLパーセントエンコード関数は存在しない（`BE_OpenURL`はURLを開くのみで、
  エンコードは行わない。公式Functions一覧で確認済み）。
- FileMaker Pro純正の**`GetAsURLEncoded ( text )`**関数（v8.5〜、Claris公式ヘルプで確認済み）が
  この用途に使える。UTF-8変換後、`: - _ . ! ~ * ' ( )`以外の文字を`%HH`形式に変換する。
  `/`は保存対象文字に含まれないため`%2F`に変換される＝PowerShell側の`EscapeDataString`と
  実用上同等の結果になる。

  既知の差異（機能に影響しない）:
  - 16進数の大文字/小文字（PS: `%E3`大文字 / FileMaker: `%e3`小文字）。RFC 3986上は
    大文字小文字を区別しないため、URIとしての解釈は同一。
  - `: ! * ' ( )`をFileMakerは非エンコードのまま許容するが、PSはエンコードする。
    本システムのフォルダ名・ファイル名・Vault名にこれらの文字が使われる想定はないため、
    実害はないと判断する。

以上により、`GetAsURLEncoded`を採用する。

---

## 2. 追加箇所A：セクション1への1行追加

既存ドラフトのセクション1（「顧客レコード情報の取得」）の末尾に以下を追加する。

```
変数を設定 [ $obsRelPathBefore ; 値: 顧客::obs_RELPATH ]
```

これは、PowerShell実行前の時点での`obs_RELPATH`（更新前の値）を保持するためのものであり、
このスクリプトが「どのノートに対応するobs_RELPATH/obs_URLだったか」を判定するための
唯一の手がかりとなる。この時点の値はレコードのカレント値をそのまま読むだけであり、
書き込みは行わない。

---

## 3. 追加箇所B：CUSTOMER_IDENTITY_UPDATED成功時の新規ステップ群

既存ドラフトの以下の部分（A・B共通）：

```
If [ $respCode = "CUSTOMER_IDENTITY_UPDATED" ]
  変数を設定 [ $folderMsg ; 値: "" ]
  If [ $respFolderRenamed = "1" ]
    ...(既存。変更なし)...
  End If

  カスタムダイアログを表示 [ "顧客名・代表者名同期" ; "顧客情報を更新しました。¶更新ファイル数：" & $respUpdatedFiles & $folderMsg ; ボタン: "OK" ]
  現在のスクリプト終了
End If
```

の、`End If`（folderRenamedブロックの終わり）と最終`カスタムダイアログを表示`の**間**に、
以下の新規ステップ群を挿入する。

```
# -----------------------------------------------------------
# 9. obs_RELPATH / obs_URL の正式パスへの更新
#    (newFolder / renamedNotes を使用する。対応ノートが不明な場合は更新しない)
# -----------------------------------------------------------
変数を設定 [ $obsSyncMsg ; 値: "" ]
変数を設定 [ $obsSyncSkipReason ; 値: "" ]

If [ not IsEmpty ( $obsRelPathBefore ) ]

  変数を設定 [ $obsSyncSegs ; 値: Substitute ( $obsRelPathBefore ; "/" ; "¶" ) ]
  変数を設定 [ $obsSyncSegCount ; 値: ValueCount ( $obsSyncSegs ) ]

  If [ $obsSyncSegCount < 3 ]
    変数を設定 [ $obsSyncSkipReason ; 値: "既存のobs_RELPATHの形式が想定外です(区切り数不足)。obs_RELPATH=" & $obsRelPathBefore ]
  Else
    変数を設定 [ $obsSyncRootSeg ; 値: GetValue ( $obsSyncSegs ; 1 ) ]
    変数を設定 [ $obsSyncOldFolderSeg ; 値: GetValue ( $obsSyncSegs ; $obsSyncSegCount - 1 ) ]
    変数を設定 [ $obsSyncOldNoteFileName ; 値: GetValue ( $obsSyncSegs ; $obsSyncSegCount ) ]

    変数を設定 [ $obsSyncOldFolder ; 値: JSONGetElement ( $stdout ; "oldFolder" ) ]
    変数を設定 [ $obsSyncNewFolder ; 値: JSONGetElement ( $stdout ; "newFolder" ) ]

    If [
      Left ( $obsSyncOldFolder ; 1 ) = "?" or
      Left ( $obsSyncNewFolder ; 1 ) = "?" or
      IsEmpty ( $obsSyncNewFolder )
    ]
      変数を設定 [ $obsSyncSkipReason ; 値: "応答からoldFolder/newFolderを取得できませんでした。" ]
    Else If [ $obsSyncOldFolderSeg ≠ $obsSyncOldFolder ]
      変数を設定 [ $obsSyncSkipReason ; 値:
        "既存のobs_RELPATHが指すフォルダ名(" & $obsSyncOldFolderSeg &
        ")と、今回処理された顧客フォルダ名(" & $obsSyncOldFolder & ")が一致しません。" ]
    Else
      # ---- ここまでで「対応ノート不明」ではないと判定済み。以降は確定的な計算のみ ----

      変数を設定 [ $obsSyncRenamedNoteCountRaw ; 値: JSONGetElement ( $stdout ; "renamedNoteCount" ) ]
      変数を設定 [ $obsSyncRenamedNoteCount ; 値:
        If ( Left ( $obsSyncRenamedNoteCountRaw ; 1 ) = "?" or IsEmpty ( $obsSyncRenamedNoteCountRaw ) ;
          0 ;
          GetAsNumber ( $obsSyncRenamedNoteCountRaw )
        )
      ]

      # 既定はリネームなし(未変更)。renamedNotesに合致するoldNameがあれば置き換える。
      変数を設定 [ $obsSyncNewNoteFileName ; 値: $obsSyncOldNoteFileName ]

      If [ $obsSyncRenamedNoteCount > 0 ]
        変数を設定 [ $obsSyncI ; 値: 0 ]
        変数を設定 [ $obsSyncFound ; 値: 0 ]
        Loop
          Exit Loop If [ $obsSyncI ≥ $obsSyncRenamedNoteCount ]

          変数を設定 [ $obsSyncCurOld ; 値: JSONGetElement ( $stdout ; "renamedNotes[" & $obsSyncI & "].oldName" ) ]
          変数を設定 [ $obsSyncCurNew ; 値: JSONGetElement ( $stdout ; "renamedNotes[" & $obsSyncI & "].newName" ) ]

          If [
            not ( Left ( $obsSyncCurOld ; 1 ) = "?" ) and
            not ( Left ( $obsSyncCurNew ; 1 ) = "?" ) and
            $obsSyncCurOld = $obsSyncOldNoteFileName
          ]
            変数を設定 [ $obsSyncNewNoteFileName ; 値: $obsSyncCurNew ]
            変数を設定 [ $obsSyncFound ; 値: 1 ]
          End If

          変数を設定 [ $obsSyncI ; 値: $obsSyncI + 1 ]
          Exit Loop If [ $obsSyncFound = 1 ]
        End Loop
      End If

      変数を設定 [ $obsSyncNewRelPath ; 値:
        $obsSyncRootSeg & "/" & $obsSyncNewFolder & "/" & $obsSyncNewNoteFileName
      ]

      変数を設定 [ $obsSyncVaultName ; 値:
        Let ( [
          p = z_sysClientPC::OB_VAULTPATH ;
          v = z_sysClientPC::OB_VAULTNAME
        ] ;
          If ( not IsEmpty ( p ) and not IsEmpty ( v ) ; v ; "【Vault】INS" )
        )
      ]
      # ↑ $vaultRoot組立(セクション2)と同一ロジックの葉名相当。新規ロジックの発明ではない。

      変数を設定 [ $obsSyncNewUrl ; 値:
        "obsidian://open?vault=" & GetAsURLEncoded ( $obsSyncVaultName ) &
        "&file=" & GetAsURLEncoded ( $obsSyncNewRelPath )
      ]

      フィールド設定 [ 顧客::obs_RELPATH ; $obsSyncNewRelPath ]
      フィールド設定 [ 顧客::obs_URL ; $obsSyncNewUrl ]

      変数を設定 [ $obsSyncMsg ; 値: "¶Obsidian参照パスを更新しました：" & $obsSyncNewRelPath ]
    End If
  End If

Else
  変数を設定 [ $obsSyncSkipReason ; 値: "obs_RELPATHが未設定です(初回同期前と判断)。" ]
End If

# obsRelPathBeforeが元々空だった場合（初回同期前）は、通知なしで静かにスキップする。
# それ以外の理由でスキップした場合のみ、参考情報として最終ダイアログに理由を表示する。
If [ IsEmpty ( $obsSyncMsg ) and not IsEmpty ( $obsSyncSkipReason ) and not IsEmpty ( $obsRelPathBefore ) ]
  変数を設定 [ $obsSyncMsg ; 値: "¶(参考)obs_RELPATH/obs_URLは今回更新しませんでした。理由：" & $obsSyncSkipReason ]
End If
```

そのうえで、既存の最終ダイアログの行を以下のように**変更**する（`$obsSyncMsg`を末尾に連結するのみ。
既存文言・既存変数は変更しない）。

```
カスタムダイアログを表示 [ "顧客名・代表者名同期" ; "顧客情報を更新しました。¶更新ファイル数：" & $respUpdatedFiles & $folderMsg & $obsSyncMsg ; ボタン: "OK" ]
現在のスクリプト終了
```

---

## 4. 「対応ノートが不明な場合」の判定基準（推測更新をしないための3条件）

以下のいずれかに該当する場合、`obs_RELPATH`/`obs_URL`は**更新せず、既存値を保持したまま**とする。
いずれの条件も、PowerShell応答またはFileMaker既存フィールドの実値のみで判定し、
値を推測・補完する処理は一切行わない。

| 条件 | 判定内容 | スキップ時の扱い |
|---|---|---|
| ① 初回同期前 | `顧客::obs_RELPATH`が空 | 通知なしで静かにスキップ（初回はこのスクリプトの対象外。既存のOBSノート-開くフローが後で正しく設定する） |
| ② 形式不正 | `obs_RELPATH`が`/`区切りで3セグメント未満 | 最終ダイアログに理由と現在値を表示してスキップ |
| ③ フォルダ不一致 | `obs_RELPATH`のフォルダセグメントと、応答の`oldFolder`が一致しない | 最終ダイアログに理由（両方の値）を表示してスキップ。obs_RELPATHが別の状態を指している可能性があるため、推測で上書きしない |

条件③は、「このレコードの`obs_RELPATH`が今回処理されたフォルダと同一顧客・同一フォルダ状態を
指している」ことを裏付けるための唯一の検証手段である。この検証にはVault実体ファイルの読み取りは
含まれない（PowerShell本体を経由しない直接ファイルアクセスは行わない）。

ノート単位（ファイル名）の対応判定は「推測」ではなく、応答の`renamedNotes`配列に
**完全一致するoldNameがあるかどうか**のみで判定する。一致しなければ「そのノートは
今回リネームされなかった」という応答上の事実に基づき、ファイル名を不変とする
（これは事実の反映であり、推測ではない）。

---

## 5. 変更しないものの確認

- `EXT-obs_内部CallPS-PAYLOAD`：無改修（本追加仕様からの呼び出しも発生しない）
- `EXT-obs_OBSノート-開く`：無改修
- `FM-Obsidian-Bridge-Payload.ps1`：無改修。応答スキーマの読み取りのみで、新規キーの追加要求は行っていない
- Git操作：実施していない（add/commit/push禁止を遵守）
- 更新対象フィールドは`顧客::obs_RELPATH`・`顧客::obs_URL`の2つのみ。
  `obs_LASTSYNCAT`・`obs_LASTKNOWNWRITE`は本追加仕様の対象外のため触れない
  （今回の指示にない項目への推測的な拡張を避けるため）。

---

## 6. 未確定事項・未検証事項

1. `GetAsURLEncoded`が実機のFileMaker Proバージョンで期待どおり動作するかは、
   実機での動作確認が必須。本ドキュメントの記述はClaris公式ヘルプの仕様記述に基づくが、
   Python再現テストのみでの合格を許容しないという方針と同様、**FileMaker実機での
   目視確認をもって初めて合格とする**。
2. `renamedNotes`配列のJSONパス表記（`renamedNotes[0].oldName`）が実機のFileMaker JSON関数で
   意図通り解析されるかは実機確認が必要。
3. 条件③（フォルダ不一致）でスキップが多発する場合、既存の`obs_RELPATH`がそもそも
   最新化されていない顧客が多く残っている可能性がある。その場合は本追加仕様とは別に、
   `EXT-obs_UUID先行同期統合_設計書_20260729.md`で検討されているlegacy CHECK経由の
   再取得フローの適用要否を、別途人間が判断する必要がある。

---

## 7. 実装前判定

**B: 設計は妥当だが、GetAsURLEncoded・JSON配列パス表記の実機動作確認が未実施。**

---

## 8. 次にユーザーがFileMakerで行う作業

1. 既存の`EXT-obs_顧客名・代表者名同期`（最終ドラフトA or B、実機バージョンに応じて選択済みのもの）に、
   本ドキュメントの「2. 追加箇所A」「3. 追加箇所B」をそのとおり転記する。
2. テスト用の顧客レコードで、社名変更を伴う`UPDATE_CUSTOMER_IDENTITY`を実行し、
   `obs_RELPATH`・`obs_URL`が正しい新パスに更新されることを確認する。
3. 条件①〜③のスキップ分岐についても、意図的に不一致な`obs_RELPATH`を仕込んだ状態で
   実行し、推測更新されず正しくスキップされることを確認する。
4. 問題なければChatGPTへ共有しレビューを受ける。
