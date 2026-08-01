# EXT-obs_顧客名・代表者名同期 最終仕様：obs_RELPATH / obs_URL の正式パスへの更新（改訂2）

作成日: 2026-07-29 / 作成者: Claude Cowork
状態: **ドラフトのみ。FileMaker未登録・本番実行なし。**
位置づけ: `EXT-obs_顧客名代表者名同期_obs_RELPATH_obs_URL更新_最終仕様_20260729.md`（以下「改訂1」）を、
ユーザー指示9件に基づき全面補正した版。改訂1・前回の「追加仕様」版はいずれも削除せず保持する。

対象: `EXT-obs_顧客名・代表者名同期`（FileMaker Pro 19.5.1以上・最終ドラフトA系統）
変更しない: `EXT-obs_内部CallPS-PAYLOAD` / `EXT-obs_OBSノート-開く` / `FM-Obsidian-Bridge-Payload.ps1` / Git操作

---

## 1. 改訂1からの変更点一覧（今回の指示9件との対応）

| # | 指示内容 | 改訂1 | 改訂2 |
|---|---|---|---|
| 1 | `$obsUrlBefore`も実行前に保存 | `$obsRelPathBefore`のみ保存 | セクション1に`$obsUrlBefore = 顧客::obs_URL`を追加保存 |
| 2 | 失敗時、FileMaker側2フィールドを元値へベストエフォート復旧 | 復旧処理なし | `$obsSyncFieldUpdateFailed=1`検出後、`obs_RELPATH`/`obs_URL`を元値へ再設定しレコード確定を再試行(結果は`recovery.*`としてエラーJSONへ格納) |
| 3 | silentMode=falseの時だけダイアログ表示。必ず`現在のスクリプト終了 [ $obsSyncErrorJson ]`で返す | 常にダイアログ表示、終了時の戻り値指定なし | `$silentMode`をセクション1で決定(既定=false=表示)。ダイアログは`If [ not $silentMode ]`内のみ。終了は必ず`現在のスクリプト終了 [ $obsSyncErrorJson ]` |
| 4 | oldFolder/newFolderは常にJSONString・非空を検証 | `Left(x,1)="?"`と`newFolder`のみ`IsEmpty`確認 | `JSONGetElementType`で両方`JSONString`であること、両方`IsEmpty`でないことを検証 |
| 5 | renamedNoteCountはキー欠落時のみ0。存在時はJSONNumber・0以上整数を検証 | `Left(x,1)="?"`または空なら0扱い（型検証なし） | `JSONGetElementType`で欠落判定(`Left(type,1)="?"`)。存在する場合は`JSONNumber`かつ0以上の整数であることを検証し、不正なら安全停止 |
| 6 | セグメント数は「3未満」でなく「3以外」を拒否 | `$obsSyncSegCount < 3` | `$obsSyncSegCount ≠ 3` |
| 7 | `knownNGCodes`へ`NOTE_TYPE_UUID_CONFLICT`も追加 | 参考記載のみ(追加せず) | 追加する |
| 8 | 復元手順から「内容完全同一」記述を削除。内容差分確認の手順を追加 | 「内容は完全同一」と記載(誤り) | 実際はCRLF/LF差(12バイト)のみで内容自体は同一という調査結果を、テキスト正規化比較の実施結果として記載し直し、復元スクリプトに事前diff確認ステップを追加 |
| 9 | PS本体・CallPS-PAYLOAD・OBSノート-開く・Gitは変更しない | 遵守 | 遵守（変更なし。本ターンもSHA256で再確認） |

---

## 2. 指示8に関する訂正（重要）

前回、現状ファイルとバックアップファイルの内容を「完全同一」と報告したが、これは`cat`/テキスト表示による
目視比較のみに基づく誤った記述だった。今回、バイト単位で再確認した結果は次のとおり。

| | Length(バイト) | SHA256 |
|---|---|---|
| 現状（Vault内・UUID付与後） | 250 | `69b49d8f920f0fa215be7a36fa73cbb266c46ae59a6feca56e87d828702a21c0` |
| バックアップ（UUID付与前） | 238 | `ff271edf2cfc1b4ccaea6b692b802d158d9d5ab41292ba85c8c27a8da1f5269c` |

`diff`による行単位比較の結果、差分は**全12行すべてに改行コードの差（現状=CRLF `\r\n`、バックアップ=LF `\n`）
があるのみ**で、12行×1バイト＝12バイトの差（250−238）とちょうど一致する。改行コードを正規化した上で
比較すると、可視テキスト内容（tags・UUID・ランク・本文）に差分はない。ただし、これは「調査時点で
確認できた差分の説明」であり、「内容が完全同一である」という前回の断定は誤りだったため撤回する。
復元前には、改めて第7章の手順内で自動的に内容差分を確認する。

---

## 3. 挿入位置（変更なし。3箇所）

1. セクション1「顧客レコード情報の取得」の末尾
2. `$respCode = "CUSTOMER_IDENTITY_UPDATED"`ブロック内、`folderRenamed`処理の`End If`と
   最終ダイアログの間
3. セクション8の`$knownNGCodes`

---

## 4. セクション1への追加（改訂2）

```
変数を設定 [ $obsRelPathBefore ; 値: 顧客::obs_RELPATH ]
変数を設定 [ $obsUrlBefore ; 値: 顧客::obs_URL ]
変数を設定 [ $silentMode ; 値:
  not IsEmpty ( Get ( スクリプト引数 ) ) and
  (
    Get ( スクリプト引数 ) = "1" or
    Lower ( Get ( スクリプト引数 ) ) = "true" or
    Lower ( Get ( スクリプト引数 ) ) = "silent"
  )
]
```

`$silentMode`は新規の任意スクリプト引数。既存ドラフトは「スクリプト引数：なし」を前提としていたため、
引数を渡さず呼び出す既存の呼び出し元は影響を受けない（`Get(スクリプト引数)`が空なら`$silentMode=false`。
これは改訂1までの「常にダイアログ表示」という挙動と同じ）。`$silentMode`は本仕様の
`FILEMAKER_PATH_UPDATE_FAILED`ダイアログの表示可否のみに使用し、他の既存ダイアログの表示可否には
一切影響しない。

---

## 5. `$knownNGCodes`の変更（改訂2）

変更前（改訂1時点）：
```
変数を設定 [ $knownNGCodes ; 値:
  "CUSTOMER_NOT_FOUND¶UUID_FOLDER_CONFLICT¶FOLDER_UUID_MIXED¶INVALID_YAML¶INVALID_UUID¶TARGET_FOLDER_ALREADY_EXISTS¶FOLDER_RENAME_FAILED¶NOTE_UPDATE_FAILED¶UPDATE_ROLLBACK_FAILED¶MISSING_REQUIRED_FIELD¶UNSUPPORTED_PROTOCOL_VERSION¶INVALID_VAULT_ROOT¶INVALID_CUSTOMER_NAME¶EXECUTION_FAILED¶INVALID_PAYLOAD¶TARGET_NOTE_FILENAME_CONFLICT¶YAML_BODY_BOUNDARY_UNRESOLVED"
]
```

変更後（今回追加：`NOTE_TYPE_UUID_CONFLICT`）：
```
変数を設定 [ $knownNGCodes ; 値:
  "CUSTOMER_NOT_FOUND¶UUID_FOLDER_CONFLICT¶FOLDER_UUID_MIXED¶INVALID_YAML¶INVALID_UUID¶TARGET_FOLDER_ALREADY_EXISTS¶FOLDER_RENAME_FAILED¶NOTE_UPDATE_FAILED¶UPDATE_ROLLBACK_FAILED¶MISSING_REQUIRED_FIELD¶UNSUPPORTED_PROTOCOL_VERSION¶INVALID_VAULT_ROOT¶INVALID_CUSTOMER_NAME¶EXECUTION_FAILED¶INVALID_PAYLOAD¶TARGET_NOTE_FILENAME_CONFLICT¶YAML_BODY_BOUNDARY_UNRESOLVED¶NOTE_TYPE_UUID_CONFLICT"
]
```

本体コード（721行目・1016行目）を再確認し、`NOTE_TYPE_UUID_CONFLICT`が`UPDATE_CUSTOMER_IDENTITY`から
実際に返りうるNGコードであることを確認済み。

---

## 6. 新規ステップ群（改訂2・全文）

`$respCode = "CUSTOMER_IDENTITY_UPDATED"`ブロック内、`folderRenamed`処理の`End If`の直後、
既存の最終ダイアログの前に挿入する。

```
# -----------------------------------------------------------
# 9. obs_RELPATH / obs_URL の正式パスへの更新
#    (newFolder / renamedNotes を使用する。対応ノートが不明な場合は更新しない)
# -----------------------------------------------------------
変数を設定 [ $obsSyncMsg ; 値: "" ]
変数を設定 [ $obsSyncSkipReason ; 値: "" ]
変数を設定 [ $obsSyncDialogTitle ; 値: "顧客名・代表者名同期" ]

If [ IsEmpty ( $obsRelPathBefore ) ]
  変数を設定 [ $obsSyncSkipReason ; 値: "obs_RELPATHが未設定です(初回同期前と判断)。" ]

Else
  変数を設定 [ $obsSyncSegs ; 値: Substitute ( $obsRelPathBefore ; "/" ; "¶" ) ]
  変数を設定 [ $obsSyncSegCount ; 値: ValueCount ( $obsSyncSegs ) ]

  If [ $obsSyncSegCount ≠ 3 ]
    変数を設定 [ $obsSyncSkipReason ; 値: "既存のobs_RELPATHの区切り数が3ではありません(実際=" & $obsSyncSegCount & ")。obs_RELPATH=" & $obsRelPathBefore ]

  Else
    変数を設定 [ $obsSyncRootSeg ; 値: GetValue ( $obsSyncSegs ; 1 ) ]
    変数を設定 [ $obsSyncOldFolderSeg ; 値: GetValue ( $obsSyncSegs ; 2 ) ]
    変数を設定 [ $obsSyncOldNoteFileName ; 値: GetValue ( $obsSyncSegs ; 3 ) ]

    If [ $obsSyncRootSeg ≠ "01_顧客" ]
      変数を設定 [ $obsSyncSkipReason ; 値: "既存のobs_RELPATHの先頭セグメントが「01_顧客」ではありません(" & $obsSyncRootSeg & ")。" ]

    Else If [ IsEmpty ( $obsSyncOldNoteFileName ) or not ( Right ( $obsSyncOldNoteFileName ; 3 ) = ".md" ) ]
      変数を設定 [ $obsSyncSkipReason ; 値: "既存のobs_RELPATHのファイル名部分が空、または.mdで終わっていません(" & $obsSyncOldNoteFileName & ")。" ]

    Else
      変数を設定 [ $obsSyncOldFolder ; 値: JSONGetElement ( $stdout ; "oldFolder" ) ]
      変数を設定 [ $obsSyncNewFolder ; 値: JSONGetElement ( $stdout ; "newFolder" ) ]
      変数を設定 [ $obsSyncOldFolderType ; 値: JSONGetElementType ( $stdout ; "oldFolder" ) ]
      変数を設定 [ $obsSyncNewFolderType ; 値: JSONGetElementType ( $stdout ; "newFolder" ) ]

      If [
        $obsSyncOldFolderType ≠ JSONString or
        $obsSyncNewFolderType ≠ JSONString or
        IsEmpty ( $obsSyncOldFolder ) or
        IsEmpty ( $obsSyncNewFolder )
      ]
        変数を設定 [ $obsSyncSkipReason ; 値: "応答のoldFolder/newFolderがJSONString型でない、または空です。" ]

      Else If [ $obsSyncOldFolderSeg ≠ $obsSyncOldFolder ]
        変数を設定 [ $obsSyncSkipReason ; 値:
          "既存のobs_RELPATHが指すフォルダ名(" & $obsSyncOldFolderSeg &
          ")と、今回処理された顧客フォルダ名(" & $obsSyncOldFolder & ")が一致しません。" ]

      Else
        # ---- ここまでで「対応ノート不明」ではないと判定済み。renamedNoteCountの検証・解析へ ----

        変数を設定 [ $obsSyncRenamedNoteCountType ; 値: JSONGetElementType ( $stdout ; "renamedNoteCount" ) ]

        If [ Left ( $obsSyncRenamedNoteCountType ; 1 ) = "?" ]
          # キー自体が存在しない場合のみ0件として扱う
          変数を設定 [ $obsSyncRenamedNoteCount ; 値: 0 ]
        Else
          変数を設定 [ $obsSyncRenamedNoteCountRaw ; 値: JSONGetElement ( $stdout ; "renamedNoteCount" ) ]
          変数を設定 [ $obsSyncRenamedNoteCountNum ; 値: GetAsNumber ( $obsSyncRenamedNoteCountRaw ) ]

          If [
            $obsSyncRenamedNoteCountType ≠ JSONNumber or
            $obsSyncRenamedNoteCountNum < 0 or
            Int ( $obsSyncRenamedNoteCountNum ) ≠ $obsSyncRenamedNoteCountNum
          ]
            変数を設定 [ $obsSyncSkipReason ; 値: "renamedNoteCountが0以上の整数(JSONNumber)ではありません。値=" & $obsSyncRenamedNoteCountRaw ]
            変数を設定 [ $obsSyncRenamedNoteCount ; 値: 0 ]
          Else
            変数を設定 [ $obsSyncRenamedNoteCount ; 値: $obsSyncRenamedNoteCountNum ]
          End If
        End If

        変数を設定 [ $obsSyncNewNoteFileName ; 値: $obsSyncOldNoteFileName ]

        If [ IsEmpty ( $obsSyncSkipReason ) and $obsSyncRenamedNoteCount > 0 ]
          変数を設定 [ $obsSyncI ; 値: 0 ]
          変数を設定 [ $obsSyncMatchCount ; 値: 0 ]
          変数を設定 [ $obsSyncMatchedNewName ; 値: "" ]
          変数を設定 [ $obsSyncParseAbort ; 値: 0 ]

          Loop
            Exit Loop If [ $obsSyncI ≥ $obsSyncRenamedNoteCount ]

            変数を設定 [ $obsSyncCurOldType ; 値: JSONGetElementType ( $stdout ; "renamedNotes[" & $obsSyncI & "].oldName" ) ]
            変数を設定 [ $obsSyncCurNewType ; 値: JSONGetElementType ( $stdout ; "renamedNotes[" & $obsSyncI & "].newName" ) ]

            If [ $obsSyncCurOldType ≠ JSONString or $obsSyncCurNewType ≠ JSONString ]
              変数を設定 [ $obsSyncParseAbort ; 値: 1 ]
              Exit Loop If [ 1 ]
            End If

            変数を設定 [ $obsSyncCurOld ; 値: JSONGetElement ( $stdout ; "renamedNotes[" & $obsSyncI & "].oldName" ) ]
            変数を設定 [ $obsSyncCurNew ; 値: JSONGetElement ( $stdout ; "renamedNotes[" & $obsSyncI & "].newName" ) ]

            If [ IsEmpty ( $obsSyncCurOld ) or IsEmpty ( $obsSyncCurNew ) ]
              変数を設定 [ $obsSyncParseAbort ; 値: 1 ]
              Exit Loop If [ 1 ]
            End If

            If [ $obsSyncCurOld = $obsSyncOldNoteFileName ]
              変数を設定 [ $obsSyncMatchCount ; 値: $obsSyncMatchCount + 1 ]
              変数を設定 [ $obsSyncMatchedNewName ; 値: $obsSyncCurNew ]
            End If

            変数を設定 [ $obsSyncI ; 値: $obsSyncI + 1 ]
          End Loop

          If [ $obsSyncParseAbort = 1 ]
            変数を設定 [ $obsSyncSkipReason ; 値: "renamedNotes配列の要素に型不正・空値・解析不能な項目が含まれていたため、安全のため更新しませんでした。" ]
          Else If [ $obsSyncMatchCount = 0 or $obsSyncMatchCount ≥ 2 ]
            変数を設定 [ $obsSyncSkipReason ; 値:
              "renamedNotes内でこのノート名(" & $obsSyncOldNoteFileName & ")との一致が" &
              $obsSyncMatchCount & "件でした(1件のみを正常とみなします)。推測更新は行いません。" ]
          Else
            変数を設定 [ $obsSyncNewNoteFileName ; 値: $obsSyncMatchedNewName ]
          End If
        End If

        # ---- ここまで安全停止していなければ、新パス・新URLを計算し書き込む ----
        If [ IsEmpty ( $obsSyncSkipReason ) ]

          変数を設定 [ $obsSyncNewRelPath ; 値:
            "01_顧客" & "/" & $obsSyncNewFolder & "/" & $obsSyncNewNoteFileName
          ]

          変数を設定 [ $obsSyncVaultName ; 値:
            Let ( [
              p = z_sysClientPC::OB_VAULTPATH ;
              v = z_sysClientPC::OB_VAULTNAME
            ] ;
              If ( not IsEmpty ( p ) and not IsEmpty ( v ) ; v ; "【Vault】INS" )
            )
          ]

          変数を設定 [ $obsSyncNewUrl ; 値:
            "obsidian://open?vault=" & GetAsURLEncoded ( $obsSyncVaultName ) &
            "&file=" & GetAsURLEncoded ( $obsSyncNewRelPath )
          ]

          # ---- フィールド更新(各ステップ直後にGet(最終エラー)を確認) ----
          変数を設定 [ $obsSyncFieldUpdateFailed ; 値: 0 ]
          変数を設定 [ $obsSyncFailedStep ; 値: "" ]
          変数を設定 [ $obsSyncLastErrorCode ; 値: 0 ]

          フィールド設定 [ 顧客::obs_RELPATH ; $obsSyncNewRelPath ]
          変数を設定 [ $obsSyncLastErrorCode ; 値: Get ( 最終エラー ) ]
          If [ $obsSyncLastErrorCode ≠ 0 ]
            変数を設定 [ $obsSyncFieldUpdateFailed ; 値: 1 ]
            変数を設定 [ $obsSyncFailedStep ; 値: "obs_RELPATH書込み" ]
          End If

          If [ $obsSyncFieldUpdateFailed = 0 ]
            フィールド設定 [ 顧客::obs_URL ; $obsSyncNewUrl ]
            変数を設定 [ $obsSyncLastErrorCode ; 値: Get ( 最終エラー ) ]
            If [ $obsSyncLastErrorCode ≠ 0 ]
              変数を設定 [ $obsSyncFieldUpdateFailed ; 値: 1 ]
              変数を設定 [ $obsSyncFailedStep ; 値: "obs_URL書込み" ]
            End If
          End If

          If [ $obsSyncFieldUpdateFailed = 0 ]
            レコード/検索条件確定 [ NoInteract: オン ]
            変数を設定 [ $obsSyncLastErrorCode ; 値: Get ( 最終エラー ) ]
            If [ $obsSyncLastErrorCode ≠ 0 ]
              変数を設定 [ $obsSyncFieldUpdateFailed ; 値: 1 ]
              変数を設定 [ $obsSyncFailedStep ; 値: "レコード確定" ]
            End If
          End If

          If [ $obsSyncFieldUpdateFailed = 1 ]

            # ---- ベストエフォート復旧：obs_RELPATH/obs_URLを元値へ戻す ----
            変数を設定 [ $obsSyncRecoverErr1 ; 値: 0 ]
            変数を設定 [ $obsSyncRecoverErr2 ; 値: 0 ]
            変数を設定 [ $obsSyncRecoverErr3 ; 値: 0 ]
            変数を設定 [ $obsSyncRecoverOk ; 値: 1 ]

            フィールド設定 [ 顧客::obs_RELPATH ; $obsRelPathBefore ]
            変数を設定 [ $obsSyncRecoverErr1 ; 値: Get ( 最終エラー ) ]
            If [ $obsSyncRecoverErr1 ≠ 0 ]
              変数を設定 [ $obsSyncRecoverOk ; 値: 0 ]
            End If

            フィールド設定 [ 顧客::obs_URL ; $obsUrlBefore ]
            変数を設定 [ $obsSyncRecoverErr2 ; 値: Get ( 最終エラー ) ]
            If [ $obsSyncRecoverErr2 ≠ 0 ]
              変数を設定 [ $obsSyncRecoverOk ; 値: 0 ]
            End If

            レコード/検索条件確定 [ NoInteract: オン ]
            変数を設定 [ $obsSyncRecoverErr3 ; 値: Get ( 最終エラー ) ]
            If [ $obsSyncRecoverErr3 ≠ 0 ]
              変数を設定 [ $obsSyncRecoverOk ; 値: 0 ]
            End If

            変数を設定 [ $obsSyncErrorJson ; 値:
              JSONSetElement ( "{}" ;
                [ "status" ; "NG" ; JSONString ] ;
                [ "code" ; "FILEMAKER_PATH_UPDATE_FAILED" ; JSONString ] ;
                [ "requestId" ; $requestId ; JSONString ] ;
                [ "vaultSideUpdated" ; True ; JSONBoolean ] ;
                [ "fileMakerSideUpdated" ; False ; JSONBoolean ] ;
                [ "failedAtStep" ; $obsSyncFailedStep ; JSONString ] ;
                [ "lastErrorCode" ; $obsSyncLastErrorCode ; JSONNumber ] ;
                [ "attemptedNewRelPath" ; $obsSyncNewRelPath ; JSONString ] ;
                [ "attemptedNewUrl" ; $obsSyncNewUrl ; JSONString ] ;
                [ "recovery.attempted" ; True ; JSONBoolean ] ;
                [ "recovery.succeeded" ; $obsSyncRecoverOk = 1 ; JSONBoolean ] ;
                [ "recovery.obsRelPathRestoreErrorCode" ; $obsSyncRecoverErr1 ; JSONNumber ] ;
                [ "recovery.obsUrlRestoreErrorCode" ; $obsSyncRecoverErr2 ; JSONNumber ] ;
                [ "recovery.commitErrorCode" ; $obsSyncRecoverErr3 ; JSONNumber ] ;
                [ "recovery.restoredRelPath" ; $obsRelPathBefore ; JSONString ] ;
                [ "recovery.restoredUrl" ; $obsUrlBefore ; JSONString ]
              )
            ]

            If [ not $silentMode ]
              カスタムダイアログを表示 [ "Obsidian連携エラー(要復旧確認)" ;
                "顧客名・代表者名の同期(Obsidian Vault側)自体はすでに成功していますが、" &
                "FileMaker側のobs_RELPATH／obs_URLの更新に失敗しました。¶" &
                "Vault側は自動的に元へ戻していません(自動ロールバックは行いません)。¶" &
                "FileMaker側フィールドについては元値への復旧を試みました。¶" &
                "失敗箇所：" & $obsSyncFailedStep & "¶Get(最終エラー) = " & $obsSyncLastErrorCode & "¶¶" &
                "詳細(内部エラーJSON)：¶" & $obsSyncErrorJson ;
                ボタン: "OK" ]
            End If

            現在のスクリプト終了 [ $obsSyncErrorJson ]
          End If

          変数を設定 [ $obsSyncMsg ; 値: "¶Obsidian参照パスを更新しました：" & $obsSyncNewRelPath ]
        End If
      End If
    End If
  End If
End If

# obsRelPathBeforeが元々空だった場合（初回同期前）は、通知なしで静かにスキップする。
# それ以外の理由でスキップした場合のみ、参考情報として最終ダイアログに理由を表示し、
# タイトルを変更して視認性を上げる(Vault側の成功自体は隠さない)。
If [ IsEmpty ( $obsSyncMsg ) and not IsEmpty ( $obsSyncSkipReason ) and not IsEmpty ( $obsRelPathBefore ) ]
  変数を設定 [ $obsSyncMsg ; 値: "¶(参考)obs_RELPATH/obs_URLは今回更新しませんでした。理由：" & $obsSyncSkipReason ]
  変数を設定 [ $obsSyncDialogTitle ; 値: "顧客名・代表者名同期（要確認：Obsidian参照パス未更新）" ]
End If
```

最終ダイアログ（変更なし。改訂1と同じ）：

```
カスタムダイアログを表示 [ $obsSyncDialogTitle ; "顧客情報を更新しました。¶更新ファイル数：" & $respUpdatedFiles & $folderMsg & $obsSyncMsg ; ボタン: "OK" ]
現在のスクリプト終了
```

---

## 7. 判定基準まとめ（改訂2で更新した箇所に★）

| # | 条件 | 扱い |
|---|---|---|
| 1 | `obs_RELPATH`が空 | 通知なしで静かにスキップ |
| 2★ | `/`区切りが3以外（3未満・3超過とも） | スキップ＋理由表示 |
| 3 | 先頭セグメントが`01_顧客`でない | スキップ＋理由表示 |
| 4 | 末尾ファイル名が空または`.md`で終わらない | スキップ＋理由表示 |
| 5★ | `oldFolder`/`newFolder`がJSONString型でない、または空 | スキップ＋理由表示 |
| 6 | `obs_RELPATH`のフォルダ名と応答の`oldFolder`が不一致 | スキップ＋理由表示 |
| 7★ | `renamedNoteCount`が存在するのにJSONNumber・0以上整数でない | スキップ＋理由表示 |
| 8 | `renamedNotes`要素の型不正・空値 | スキップ＋理由表示（安全停止） |
| 9 | `renamedNotes`内のoldName一致が0件または2件以上 | スキップ＋理由表示（安全停止） |
| 10★ | フィールド設定・レコード確定のいずれかで`Get(最終エラー)≠0` | 元値へのベストエフォート復旧を試行→結果を含むJSONを生成→`silentMode=false`の場合のみダイアログ表示→必ず`現在のスクリプト終了 [ $obsSyncErrorJson ]` |

---

## 8. 変更しないものの確認（本ターン再確認）

- `FM-Obsidian-Bridge-Payload.ps1`：SHA256 `17ff7e78dd129e6f90447f22c9e13fc53e6064a1d4d3c763e6586da35e61c96a`（不変）
- `EXT-obs_内部CallPS-PAYLOAD.txt`：SHA256 `23a5645200da9566244f6882ec82fdfb25e4a7e88e00b68cd1efaf65816e5fc8`（不変）
- `EXT-obs_OBSノート-開く.txt`：SHA256 `0a78fa5b76c38c7c402c7d8965263510df4306f1f372019bc519cc17a69fb647`（不変）
- Git操作：本ターンも一切実施していない

---

## 9. E2E再試験前の復元手順（改訂：内容差分の事前確認ステップを追加）

### 9.1 調査結果の訂正（第2章の再掲）

前回「内容は完全同一」と報告したが誤りだった。実際は、現状ファイル（250バイト・改行CRLF）と
バックアップファイル（238バイト・改行LF）とで、**改行コードの違いのみ**が確認された差分であり、
可視テキスト内容そのものに差分はない。この判定は「改行コードを正規化してからの文字列比較」という
具体的な手順で確認したものであり、以後この手順を復元スクリプト自体にも組み込む（下記9.2）。

対象:
- 現状（変更後・UUID付与済み）：
  `【Vault】INS\01_顧客\【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後_[2250BA49]\`
  └ `🟨契約_【E2Eテスト_削除予定】FMOBS検証_20260729_変更後_[2250BA49].md`
- バックアップ（UUID付与前）：
  `<BACKUP_ROOT>\WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\E2E_Backup_20260729_2253\【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後\`（ローカル履歴証跡。GitHub cloneには含まれない）
  └ `🟨契約_【E2Eテスト_削除予定】FMOBS検証_20260729.md`

### 9.2 復元手順（PowerShell。ユーザー自身の実機での実行が必要。Claudeは未実行）

```powershell
# ★ 実行前に必ず内容を目視確認すること。Claudeはこのスクリプトを実行していない。
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$custRoot   = "<VAULT_ROOT>\01_顧客"
$currentDir = Join-Path $custRoot "【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後_[2250BA49]"
$backupDir  = "<BACKUP_ROOT>\WindowsTestKit_UPDATE_CUSTOMER_IDENTITY\E2E_Backup_20260729_2253\【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後"
$restoreDir = Join-Path $custRoot "【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後"

# 1. 事前確認：想定どおりの現況か
if (-not (Test-Path -LiteralPath $currentDir)) { throw "現状フォルダが見つかりません: $currentDir" }
if (-not (Test-Path -LiteralPath $backupDir))  { throw "バックアップフォルダが見つかりません: $backupDir" }
if (Test-Path -LiteralPath $restoreDir) { throw "復元先が既に存在します。手動確認が必要です: $restoreDir" }

$curFiles = Get-ChildItem -LiteralPath $currentDir -File
$bakFiles = Get-ChildItem -LiteralPath $backupDir -File
Write-Host "現状ファイル数: $($curFiles.Count) / バックアップファイル数: $($bakFiles.Count)"
if ($curFiles.Count -ne 1 -or $bakFiles.Count -ne 1) {
    throw "想定外のファイル件数です。手動確認が必要です(想定=各1件)。"
}

# 2. 内容差分の事前確認(改行コードを正規化したうえで比較する。「同一」と決め打ちしない)
$curContent = [System.IO.File]::ReadAllText($curFiles[0].FullName) -replace "`r`n","`n" -replace "`r","`n"
$bakContent = [System.IO.File]::ReadAllText($bakFiles[0].FullName) -replace "`r`n","`n" -replace "`r","`n"

Write-Host ("現状Length=" + $curFiles[0].Length + " / バックアップLength=" + $bakFiles[0].Length)
Write-Host ("現状SHA256=" + (Get-FileHash -LiteralPath $curFiles[0].FullName -Algorithm SHA256).Hash)
Write-Host ("バックアップSHA256=" + (Get-FileHash -LiteralPath $bakFiles[0].FullName -Algorithm SHA256).Hash)

if ($curContent -ne $bakContent) {
    Write-Host "=== 改行コード正規化後も内容に差分があります。復元を中止します ==="
    Write-Host "--- 現状(正規化後) ---"
    Write-Host $curContent
    Write-Host "--- バックアップ(正規化後) ---"
    Write-Host $bakContent
    throw "内容に実質的な差分があるため、自動復元を中止しました。手動確認が必要です。"
}
Write-Host "内容差分確認: 改行コード(CRLF/LF)の違いのみで、正規化後の内容に差分はありません。復元を続行します。"

# 3. 現状フォルダを削除せず退避(リネーム)する
$asideName = "【E2Eテスト_削除予定】株式会社FMOBS検証_20260729_変更後_[2250BA49]_PRE_RESTORE_" + (Get-Date -Format "yyyyMMdd_HHmmss")
Rename-Item -LiteralPath $currentDir -NewName $asideName -ErrorAction Stop
$asideDir = Join-Path $custRoot $asideName
Write-Host "現状フォルダを退避しました: $asideDir"

# 4. バックアップからUUID付与前の状態を復元(コピー。バックアップ側は残す)
Copy-Item -LiteralPath $backupDir -Destination $restoreDir -Recurse -ErrorAction Stop
Write-Host "復元しました: $restoreDir"

# 5. 検証
$restoredFiles = Get-ChildItem -LiteralPath $restoreDir -File
foreach ($f in $restoredFiles) {
    $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    Write-Host ("復元ファイル: {0} / SHA256: {1}" -f $f.Name, $h)
}
Write-Host "退避フォルダ(安全のため削除しない): $asideDir"
Write-Host "[完了] 対象顧客フォルダのみを復元しました。01_顧客配下の他フォルダには一切触れていません。"
```

### 9.3 復元後にユーザーが確認すべきこと

1. スクリプト実行時のコンソール出力で、改行コード正規化後の内容差分確認が「差分なし」で
   通過したことを確認する（「実質的な差分があるため中止」となった場合は、本手順を使わず
   手動で内容を確認すること）。
2. 復元後のファイルSHA256が、バックアップの`ff271edf2cfc1b4ccaea6b692b802d158d9d5ab41292ba85c8c27a8da1f5269c`
   と一致すること（改行コードがLFのまま復元されるため、このSHA256と一致するはず）。
3. 退避フォルダ（`..._PRE_RESTORE_YYYYMMDD_HHmmss`）が削除されず残っていること。
4. FileMaker側の該当顧客レコード（`顧客::pk_CLIENT = 2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1`）の
   `obs_RELPATH`・`obs_URL`もこの復元後の状態（UUID未付与のパス）に合わせて、必要であれば
   ユーザー自身が確認・修正すること（本手順はVault側の復元のみを行う）。

---

## 10. 未確定事項・未検証事項

1. `JSONSetElement`のドット区切りパス（`recovery.attempted`等）によるネストしたオブジェクトの
   自動生成は、Claris公式仕様上は標準的な機能だが、実機での動作確認はまだ行っていない。
2. `$silentMode`をスクリプト引数から判定する設計は新規追加であり、実機での動作確認が必要。
   既存の「スクリプト引数：なし」という前提運用（引数を渡さない呼び出し）とは後方互換であることを
   確認済み（`Get(スクリプト引数)`が空の場合は`$silentMode=false`となり、従来どおりダイアログが
   表示される）。
3. 第9章の復元用PowerShellスクリプトは、Claude自身が実行したものではない
   （本番Vaultへの書込みとなるため、Claudeの制約上実行不可）。ユーザーの実機での実行・
   確認結果をもって初めて「検証済み」とする。

---

## 11. 実装前判定

**B: 設計・実装は指示通りだが、上記未確定事項3点の実機確認が未実施。**

---

## 12. 次にユーザーが行う作業

1. 本ドキュメント第4〜6章を`EXT-obs_顧客名・代表者名同期`へ転記する（`$knownNGCodes`の変更を含む）。
2. 第9章の復元手順を実機で確認のうえ実行し、対象顧客フォルダを実行前状態へ復元する。
3. 復元完了後、正常系・条件1〜10の各スキップ／安全停止／復旧パスを、あらためてテストデータで確認する。
4. 問題なければChatGPTへ共有しレビューを受ける。
