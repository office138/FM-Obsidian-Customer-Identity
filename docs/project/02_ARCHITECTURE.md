# 02_ARCHITECTURE

現時点で確認済みの設計・実装情報の最新版のみをまとめる（変更履歴は04_REVIEW_LOGを参照）。

## 1. 全体構成

```
FileMaker (呼出元) ───► Perform Script
                         ├─ EXT-obs_内部CallPS-PAYLOAD (id=307)
                         │   ├─ CHECK / COMPARE / APPLY
                         │   └─ PIPE response
                         │
                         └─ EXT-obs_内部CallPS-SYNC-NOTE
                             ├─ SYNC_NOTE
                             └─ JSON response
                                      │
                                      ▼
             PowerShell (FM-Obsidian-Bridge-Payload.ps1)
             ├─ payload decode / JSON parse
             ├─ action == SYNC_NOTE 早期分岐 (Assert-ObsidianReady 前)
             └─ legacy MODE (CHECK/COMPARE/APPLY) 経路
                                      │
                                      ▼
             Obsidian Vault (01_顧客/…/Markdown)
                                      │
             obsidian_index.json (キャッシュ)
```

呼出元スクリプト（FileMaker側）：
- `EXT-obs_OBSノート-開く`（id=299）：通常のノート検索・開く・一方向同期呼出し
- **EXT-obs_内部CallPS-PAYLOAD（id=307）**：MODE系（CHECK, COMPARE, APPLY）窓口。PIPE response固定。
- **EXT-obs_内部CallPS-SYNC-NOTE**：SYNC_NOTE専用窓口。JSON response固定。
- `EXT-obs_損保最新証券-突合`（id=313）：CSV突合（COMPAREモード、307を直接呼出し）
- `EXT-obs_ホスト名自動入力`（id=297）／`EXT-obs_パス自動入力`（id=298）：端末設定補助

## 2. データ正本の対応

| 項目 | 正本 | 現行実装での扱い |
|---|---|---|
| 顧客UUID | FileMaker `顧客::pk_CLIENT`（`Get(UUID)`自動入力） | payloadの`pk_CLIENT`として送信。**【Phase 1B-3で仕様置換】現行PowerShellコード（Phase 1B-3未実装）はYAML `UUID`を照合なしで上書きするが、確定仕様では通常`SYNC_NOTE`はUUID一致ノートだけを更新し、同一UUID値の再記録だけを許可する。UUID欠損の既存候補を検出した場合は停止して`UUID_MIGRATION_REQUIRED`を返し、UUID初回記録は別の明示操作`MIGRATE_UUID`でのみ行う。UUID不一致では停止して`UUID_MISMATCH`を返し、自動上書き・自動修復を行わない。詳細は`Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節を正とする** |
| 会社名 | FileMaker `顧客::NAME` | payloadの`companyNameRaw` |
| 代表者 | FileMaker `顧客::CEO` | payloadの`CEO` |
| フリガナ | FileMaker `顧客::RUBY` | payloadの`RUBY`（`KanaHankaku(Self)`で半角カナへ自動正規化） |
| ランク | FileMaker `顧客::RANK1LYear`（昨年度基準） | payloadの`RANK` |
| noteType | FileMaker側ボタン引数（表示名文字列：契約/事故/決算書/その他/契約一覧/事故一覧） | PowerShell側`Get-IconPrefix`のワイルドカード部分一致で判定 |
| VaultRoot | `z_sysClientPC::OB_VAULTPATH`+`OB_VAULTNAME`（優先）、フォールバックで`Get(ドキュメントパス)`から生成 | z_sysClientPCは他テーブルとのリレーションなし（孤立テーブル、4レコードのみ） |
| index（キャッシュ） | `scripts\obsidian_index.json` | フラットな`{UUID: {relpath, lastWrite, folderName, nameNorm, noteType}}`構造 |

> **UUID識別・検索・重複・移行処理の確定仕様は、`Project/03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節（2026-07-26）を正本とする。** 上表「顧客UUID」行の「現行実装での扱い」列は、Phase 1B-3仕様がコードへ反映される前の現行PowerShell実装の事実を併記したものであり、確定仕様そのものではない。indexは再構築可能なキャッシュであり、identityの正本またはUUID自動修復の根拠として使用しない。

## 3. 現行payload構造

### EXT-obs_OBSノート-開く（id=299）が生成するpayload
```
VaultRoot, noteType, pk_CLIENT, companyNameRaw, CEO, RUBY, RANK,
obs_RELPATH, obs_URL, fm_LASTMODIFIED, MODE("CHECK"|"APPLY"), MIGRATE_LEGACY(0|1)
[条件付き] folderNameConfirmed
```

### EXT-obs_損保最新証券-突合（id=313）が生成するCOMPARE用payload
```
MODE("COMPARE"), csvPath, VaultRoot, pk_CLIENT, companyNameRaw, CEO, RUBY, RANK, noteType
```

### 3.1 transportスクリプト構成と責務

本節はコンポーネント境界のみを記述する。型・null正規化・error分岐の詳細仕様は `Project/03_DECISIONS.md` を正本とする。

**既存 `EXT-obs_内部CallPS-PAYLOAD`（307）**

- CHECK／COMPARE／APPLY専用のPIPE transportとして維持する。**今回のSYNC_NOTE対応では307を変更しない。**
- SYNC_NOTEを処理せず、JSON responseを返さない。`requestId` を参照・生成・検証しない。

**新規 `EXT-obs_内部CallPS-SYNC-NOTE`**

- SYNC_NOTE専用のJSON transport。responseはJSON object 1件。
- payload全体をPowerShellへ渡す。transport用途で参照するのは `VaultRoot` と `requestId` のみ。
- `requestId` は呼出元が生成し、transportは生成しない（正規化のみ行う）。
- `protocolVersion` はSYNC_NOTEで必須。詳細な型制約と対応error codeは `03_DECISIONS.md` を正本とする。
- `VaultRoot` の型・Trim・必須検証の詳細も `03_DECISIONS.md` を正本とする。
- 業務responseの意味を再解釈しない。
- 既存307と新規transportの間でresponse形式を自動判別しない。呼出元299がどちらを呼ぶかを決定する。

**transport error responseの境界**

- 必須5キーは `protocolVersion` / `requestId` / `status` / `code` / `userMessage`。
- `status` は `OK` または `NG`。`requestId` は `JSONString` または JSON null。`code` は非空 `JSONString`。`userMessage` は `JSONString`。
- 一般responseには内部技術情報、絶対パス、実行コマンド、payload、stack trace、BE生エラー等を含めない。禁止項目の完全一覧は `Project/03_DECISIONS.md` を正とする。

**error codeの生成層**

- FileMaker transportが自身で生成するのは7コード：`INVALID_PAYLOAD` / `MISSING_REQUIRED_FIELD` / `PAYLOAD_FILE_WRITE_FAILED` / `POWERSHELL_SCRIPT_NOT_FOUND` / `POWERSHELL_LAUNCH_FAILED` / `EMPTY_POWERSHELL_RESPONSE` / `INVALID_POWERSHELL_RESPONSE`。
- PowerShellが入力・action／protocol検証で生成するのは2コード：`UNSUPPORTED_ACTION` / `UNSUPPORTED_PROTOCOL_VERSION`。
- 生成層を混同しない。FileMaker transportは有効なPowerShell responseの業務codeを再解釈しない。response形状が不正な場合だけ `INVALID_POWERSHELL_RESPONSE` とする。詳細は `03_DECISIONS.md` を正本とする。

**共通PowerShell `FM-Obsidian-Bridge-Payload.ps1`**

- 専用ps1へ分割せず、SYNC_NOTE早期分岐を追加する。
- 分岐位置は payload decode後・JSON parse後・action判定後であり、legacy VaultRoot検証、`Assert-ObsidianReady`、`Write-Host`、PIPE出力関数のいずれよりも前とする。
- SYNC_NOTE経路では `Write-Host`、既存PIPE出力関数、COMPAREデバッグ出力を禁止する。stdoutへ出すのはJSON object 1件のみ。

**一時ファイルとcleanup責務**

- ファイル名は `_syncnote_<FileMaker内部UUID>.tmp`（suffixは `.tmp`）。`requestId` をファイル名へ使用せず、FileMaker内部UUIDにより同時実行衝突を回避する。payloadにはPIIが含まれ得る。
- 正常経路ではPowerShellがpayload読込直後に削除する。PowerShellスクリプト未存在・起動失敗・書込失敗後にファイルが残存した場合等は、FileMaker側が存在確認後にcleanupを試行する。
- cleanup失敗で主エラーを上書きしない。cleanupの内部技術情報を一般responseへ含めない。詳細な全分岐は `03_DECISIONS.md` を参照する。

## 4. プロトコル世代差と一方向同期への転換

現行299にはCHECK/APPLY用分岐が残存しているが、現行PowerShellは `MODE` が `"COMPARE"` かどうかしか判定せず、常に空diffB64 (`e30=`) を返すため到達不能。
Phase 0.5で最重要業務方針が「FileMaker→Obsidian一方向同期」として確定したため、双方向同期（CHECK/APPLY）は実装対象外となり、新action `SYNC_NOTE` に統合・縮退する。

## 5. Phase 1A read-only調査で確定した追加事実（2026-07-22）

- **307のエラー系挙動**: 307は正常payload/responseを解析しない中継処理だが、一時ファイル書込み失敗時および `$stdout` 空の場合に生エラーダイアログを表示し空resultを返すパスを持つ。
- **299のレスポンス解析**: `Substitute($stdout,"|","¶")` → `GetValue(;N)` で固定位置解析。
- **実在action/statusコード (5種)**: `OK|OPENED`／`OK|CREATED`／`OK|NEED_FOLDER_CONFIRM`／`NG|ERROR`／`NG|FILE_NOT_FOUND`。

## 6. Phase 1B read-only調査で確定した構造的・プロトコル事実（2026-07-24）

1. **実在noteType (6種)**: `契約一覧` / `事故一覧` / `契約` / `事故` / `決算書` / `その他` の6種がレイアウトボタン引数として実在。現行コード上は全6種で `New-Item`（自動作成）を実行するが、新プロトコルでは業務上の自動作成許可（`CREATED`）と禁止（`NOTE_NOT_FOUND`）を明示的に切り分ける。
2. **313番の呼出構造**: 313（突合）は **299 を経由せず直接 307 を呼出す**（DDR Step 127）。313 は `$result` を変数に格納するが有効なエラー分岐・表示処理を持たない。
3. **現行YAML処理の実態**: `Update-Yaml-Robust` は文字列・行ベースであり、`tags:` の全置換、管理キーの固定順再生成、インラインコメント消去等の性質を持つ。YAML構文検証がないため、`---` 境界不正時に YAML が二重生成されるリスクがある。
4. **`fm_managed_tags` 異常形の扱い**: 現行コードでは未知キーとして末尾に保持される。新プロトコルでは実更新前（`Update-Yaml-Robust` 冒頭）に検知し、`INVALID_MANAGED_TAGS` または `INVALID_YAML` で安全に中止する設計とする。
5. **YAML編集方式の確定**: Phase 1 では外部 YAML パーサーを導入せず、PowerShell 単体で完結する行保持型 frontmatter 編集を採用する。
