# 05_IMPLEMENTATION_PLAN

> GitHub版注記: repository rootは `<REPOSITORY_ROOT>`、本番PowerShellは `<REPOSITORY_ROOT>\FM-Obsidian-Bridge-Payload.ps1` と表記し、環境固有値はプレースホルダーへ置換する。
設計書 第22章（移行計画）をベースとした実装計画。Phase 0.5完了後、Phase 1A（一方向同期プロトコル確定）および **Phase 1B read-only調査（正式完了、2026-07-24）** を経て再設計。**実装コードはまだ一切開始していない。** 下記「実装開始前のゲート条件」が文書上で明確になり、ChatGPTの再レビューで承認を得るまでは着手しない。

## Phase 0〜0.5：静的調査・実機確認・業務方針確定（完了）

## 実装開始前のゲート条件

以下がすべて文書上で明確になり、ChatGPTの再レビューで承認を得るまで、Phase 1の実装コードは書かない。

- 一方向同期用payloadとresponseの仕様（Phase 1Aで確定）
- UUID不一致時の停止ルール（`03_DECISIONS.md`に採用済み）
- 実装前設計判断3項目（①noteType別自動作成可否、②YAML編集方式の詳細仕様、③307責務分離および新規SYNC_NOTE transport構造化エラー設計）の確定（**確定済み**）
- UUIDなし既存ノートの移行ルール（Phase 1C-M。`MIGRATE_UUID`のpayload構造、FileMaker側起動UI、ユーザー確認済みフラグ、response構造、migration前snapshot／journalの形式・保存先・復旧手順は未決定であり、`03_DECISIONS.md`「未決定・要確認」節を参照）
- rename対象ファイルの具体的な命名規則（Phase 1E）
- バックアップmanifest仕様およびロールバック方針（Phase 1G）
- **noteType内部コード体系の確定**（2026-07-26追加、`USER_DECISION_PENDING`）：設計書第6章5コード（`DESIGN_V4_1`）と現行6表示値（`CURRENT_OPERATIONAL_FACT`）の対応が未確定（`Evidence.DetectedNoteType`の型に直結）。詳細は末尾「Phase 1B-3後」節参照

---

## Phase 1：一方向同期前提の再設計

### Phase 1A：一方向同期プロトコル確定（正式完了、2026-07-23）

- **新action名**: `SYNC_NOTE`
- **通信契約**: `protocolVersion` (初期値1), `requestId` (呼出元生成)
- **response形式**: `SYNC_NOTE` ＝ JSON専用、既存action ＝ パイプ区切り維持
- **表示マトリクス**: 機械判定用 `code` / 利用者向け `userMessage` / 調査用 `details` / 追跡用 `requestId` の分離。
- **307の扱い（【過去案・不採用】/ 新規独立分離）**: 307はMODE系PIPE専用として維持し構造化JSONを返さない。新規 `EXT-obs_内部CallPS-SYNC-NOTE` がSYNC_NOTE専用の構造化JSON responseを担当し、transport自身の文書化済み7コードを最小構造化JSONで返す。

---

### Phase 1B：read-only調査および基本設計（正式完了、2026-07-24）

Phase 1B read-only調査（Antigravity実施、ChatGPTレビュー・承認）により以下が確定した。

#### 1. noteType実在確認と呼出構造
- DDR上実在するnoteType: `契約一覧`, `事故一覧`, `契約`, `事故`, `決算書`, `その他` (全6種)
- 呼出構造:
  - 通常ノート処理: 299 (`EXT-obs_OBSノート-開く`) → 307 (`EXT-obs_内部CallPS-PAYLOAD`) → PowerShell
  - 損保最新証券突合: 313 (`EXT-obs_損保最新証券-突合`) → 307 (`EXT-obs_内部CallPS-PAYLOAD`) → PowerShell (※ 313は 299 を経由しない、DDR Step 127)

#### 2. YAML編集方式方針
- Phase 1 では外部 YAML パーサーを導入せず、PowerShell 単体で完結する行保持型 frontmatter 編集（方式A拡張）を採用。
- 未対応構文（閉じていない frontmatter、非先頭 frontmatter、重複キー、複雑な入れ子、`fm_managed_tags` 型不正等）は `Update-Yaml-Robust` 冒頭（実更新前）に検知し、`INVALID_YAML` または `INVALID_MANAGED_TAGS` で安全に即時中止する。

#### 3. 新規SYNC_NOTE transport 構造化エラーレスポンス設計
新規 `EXT-obs_内部CallPS-SYNC-NOTE` transport は `$payloadJson` から `requestId` を参照・正規化し、requestIdを生成しない。payload全体をPowerShellへ渡し、transport自身の `INVALID_PAYLOAD` / `MISSING_REQUIRED_FIELD` / `PAYLOAD_FILE_WRITE_FAILED` / `POWERSHELL_SCRIPT_NOT_FOUND` / `POWERSHELL_LAUNCH_FAILED` / `EMPTY_POWERSHELL_RESPONSE` / `INVALID_POWERSHELL_RESPONSE` を最小構造化JSONで返却する。業務responseの意味は解析しない。

```json
{
  "protocolVersion": 1,
  "requestId": "<caller-generated-request-id>",
  "status": "NG",
  "code": "POWERSHELL_LAUNCH_FAILED",
  "userMessage": "処理を開始できませんでした。"
}
```

呼出元payloadのrequestIdが欠落、JSON null、または空JSONStringの場合、transport error responseのrequestIdはJSON nullとする。

---

### Phase 1C：UUID検索エンジン・SYNC_NOTE UUID判定設計

- **変更対象**: PowerShell側の顧客特定・UUID状態判定ロジック。現行は名前検索のみであるため、Vault全体または管理対象ノート集合から`pk_CLIENT` UUIDを検索する処理を第一手段として追加する。
- **設計原則**: UUID一致検索を名前起点の検索より先行させる。①UUID一致検索→②一意特定→③現在名称比較→④rename計画生成→⑤競合確認→⑥バックアップ→⑦rename→⑧YAML更新→⑨結果検証の順とする（rename本体はPhase 1E）。名前・会社名・folderName・relpath・ファイル名はidentityとして使用しない。これらによる検索結果はUUID欠損候補または別UUID競合候補の検出にだけ使用し、これらの値だけで顧客identityを確定しない。indexは再構築可能なキャッシュであり、indexだけを根拠にUUIDを判定・修復しない。
- **UUID照合ルール（Phase 1B-3統一仕様。`03_DECISIONS.md`「Phase 1B-3 UUID統一仕様確定」節を正とする）**:
  - UUID一意一致: 通常`SYNC_NOTE`の更新対象とする。同一UUID値の再記録を許可する。
  - UUID欠損の既存管理対象ノート候補が存在する場合: `SYNC_NOTE`を停止し`UUID_MIGRATION_REQUIRED`を返す。通常同期内でUUIDを自動付与しない。UUID初回記録はPhase 1C-Mの`MIGRATE_UUID`でのみ行う。
  - 候補ノートに受信値と異なる非空UUIDが存在する場合: 停止し`UUID_MISMATCH`を返す。UUIDの自動上書き・自動修復を行わない。
  - 受信UUIDと一致する管理対象ノートが複数存在する場合: 停止し`DUPLICATE_UUID`を返す。`DUPLICATE_UUID`は同一UUIDへの複数ノート一致専用とし、UUID不一致へ流用しない。
  - 同一顧客UUIDかつ同一noteTypeの管理対象ノートが複数存在する場合: 停止し`DUPLICATE_NOTE_TYPE`を返す。
  - 新規ノート作成は、UUID一致ノートなし、UUID欠損のmigration候補なし、別UUIDの競合候補なし、duplicate UUIDなし、duplicate noteTypeなしのすべてを満たす場合だけ許可する。
  - indexと実ファイルが不一致の場合は、indexの値だけで判定せず実ファイルを再探索する。再探索後も一意性を確定できない場合は安全停止する。index再構築のタイミングおよび専用codeは本Phaseでは確定しない。
  - `UUID_MISMATCH`は過去案・未採用から正式採用へ変更する。`UUID_MIGRATION_REQUIRED`は新規正式採用とする。`UUID_DUPLICATE`は引き続き不採用とする。

---

### Phase 1C-M：UUID移行（`MIGRATE_UUID`、Phase 1B-3で新設・通常同期から分離）

- **計画対象**: 新規action`MIGRATE_UUID`の設計および実装。`SYNC_NOTE`とは独立した明示操作とする。FileMaker側の起動UI、payload構造、ユーザー確認済みフラグの形式、response構造、migration前snapshot／journalの形式・保存先・復旧手順は未決定であり、本文書では確定しない（`03_DECISIONS.md`「未決定・要確認」節を参照）。
- **起動条件（最低条件。`03_DECISIONS.md` 1B3-9を正とする）**: FileMaker側から明示的に起動すること、対象ノート相対パスを明示すること、ユーザー確認済みフラグがあること、対象ノートのUUIDが欠損していること、既存UUIDがある場合は停止すること、同一受信UUIDを持つ別ノートが存在しないこと、対象noteTypeが一意であること、`managed_by: filemaker_obsidian_bridge`であること、migration前にsnapshotまたはjournalを作成すること。
- **処理範囲**: migrationではUUIDの初回記録だけを行う。会社名、代表者、ランク等の業務項目を同一処理で同期しない。migration成功後、別の`SYNC_NOTE`を実行して業務項目を同期する。
- **未決定事項**: payload構造、FileMaker側起動UI、ユーザー確認済みフラグの形式、snapshot／journalの形式・保存先・復旧手順、response構造およびエラーcodeの返却形式は未決定である。本Phaseで独断確定しない。

---

### Phase 1C／1C-M focused test候補

- UUID一意一致時に通常`SYNC_NOTE`で更新できること
- UUID欠損候補検出時に`SYNC_NOTE`が停止し`UUID_MIGRATION_REQUIRED`を返すこと
- UUID不一致検出時に停止し`UUID_MISMATCH`を返すこと
- duplicate UUID検出時に停止し`DUPLICATE_UUID`を返すこと
- duplicate noteType検出時に停止し`DUPLICATE_NOTE_TYPE`を返すこと
- migration候補または別UUID競合候補が存在する場合に新規ノートを作成しないこと
- `MIGRATE_UUID`対象に既存UUIDがある場合に停止すること
- `MIGRATE_UUID`実行時に同一受信UUIDを持つ別ノートが存在する場合に停止すること
- `MIGRATE_UUID`対象のnoteTypeが重複する場合に停止すること
- `MIGRATE_UUID`でUUIDだけが初回記録され、業務項目が変更されないこと
- migration成功後に別の`SYNC_NOTE`で業務項目を同期すること
- indexと実ファイルが不一致の場合にindex値だけでUUID判定・修復しないこと
- 実ファイル再探索後も一意性を確定できない場合に安全停止すること

---

### Phase 1D：管理対象YAML更新（行保持型編集）

- **変更対象**: PowerShell `Update-Yaml-Robust`。
- **構造方針**: 現行日本語キー構造（`tags:`/`UUID:`/`ランク:`/`総合計保険料:`）を維持。後方互換の追加キー `managed_by: filemaker_obsidian_bridge` および `fm_managed_tags` を追加。
- **tags更新アルゴリズム**: `更新後tags = 既存tags - 既存fm_managed_tags + 今回のFileMaker管理タグ`。ユーザー独自タグは保持。`fm_managed_tags` 欠損時は既存タグを保持し `LEGACY_TAG_OWNERSHIP_UNKNOWN` warning を返却。
- **防御処理**: 実更新前に構文検証を実行し、不正時は `INVALID_YAML` / `INVALID_MANAGED_TAGS` で即時中止。

---

### Phase 1E：社名変更rename（疑似トランザクション）

- **手順**: ①manifest作成→②競合確認→③バックアップ作成→④一時名称更新→⑤フォルダrename→⑥ノートrename→⑦YAML更新→⑧リンク更新→⑨完了検証→⑩成功記録→⑪失敗時ロールバック。部分更新は成功扱いにしない。

---

### Phase 1F：代表者変更

- フォルダ・ファイル名の rename を発生させず、YAML 該当キー・タグ・表示項目のみを更新。

---

### Phase 1G：バックアップ・ロールバック・ログ

- 全ての書き込み処理（YAML更新・rename）に先立ち、`snapshot` バックアップおよび `audit log` を作成。

---

### Phase 1H：FileMaker側統合

- 299番の `SYNC_NOTE` JSONレスポンス解析処理の実装、旧CHECK/APPLYコードの整理、新規 `EXT-obs_内部CallPS-SYNC-NOTE` transportの実装、313番のNG応答対応方針の決定と適用。

---

## 実装対象外（確定）
- ObsidianからFileMakerへの逆反映
- CHECK/APPLYによる双方向差分同期の完成
- `recommend.winner` による勝敗判定・競合解決

## 現時点の着手可否判断
**Phase 1の実装コードはまだ1行も書いていない。** Phase 1Bは2026-07-24付で正式完了（承認）した。次は「実装前設計判断3項目」の確定を受けた後、Phase 1C/1D等の実装設計ゲート判定へ進む。実装コードは指示があるまで書かない。


## Phase 1B-2 文書確定
1. 文書再補正
2. ChatGPT一次レビュー
3. Claude独立レビュー
4. 必要最小限補正
5. ChatGPT最終承認
6. ユーザーによる実装開始承認

※ 現時点では実装未着手

## 実装開始後の候補順序
1. 新規 `EXT-obs_内部CallPS-SYNC-NOTE` のFileMaker実装
2. transport単体の入力・エラーresponse確認
3. PowerShellへSYNC_NOTE早期分岐追加
4. SYNC_NOTE専用JSON出力関数追加
5. PowerShell focused test
6. 既存CHECK / COMPARE / APPLY回帰確認
7. FileMakerとPowerShell間の最小E2E
8. Vault実ノートを変更しないdry-run／検証モード
9. ユーザー承認後に限定的実ノート確認

## Phase 1B-3後：設計書原本再取得とnoteType体系実態確認（2026-07-26、read-only）

設計書原本再取得（`DESIGN_V4_1`、SHA256 `E1D73703A3B6030E60BC8E610F0EF80D0C314DDDED65F9D171F1FA801743E96D`）。noteType体系（`DESIGN_V4_1`5コード vs `CURRENT_OPERATIONAL_FACT`6表示値、Vault465件）は`USER_DECISION_PENDING`。ChatGPT推奨案B（`CHATGPT_RECOMMENDATION`）・第24章Phase1関連4項目（No.5/10/14/16）も`USER_DECISION_PENDING`。既存465ノートの`managed_by`未反映（0件）はresolver初期実装とは別ゲート。

**実装開始ゲート：CLOSED。** noteType体系未決定のため、Phase1C（`Resolve-UuidCandidate`等）の`noteType`関連入出力仕様は本節の決定を待つ。理由：noteType体系未決定／内部コード未承認／将来予約コード未決定／第24章No.5・10・14・16未決定／設計書Version4.2改訂方針未承認。
