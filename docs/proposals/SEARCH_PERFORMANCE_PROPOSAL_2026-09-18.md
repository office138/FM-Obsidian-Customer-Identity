# FM-Obsidian-Bridge 検索速度改善 提案書

- 日付: 2026-09-18
- 対象: `FM-Obsidian-Bridge-Payload.ps1` Ver 9.1.1 (SHA256 `3AFDF25C…9CB50B`)
- 種別: **提案 (Investigation / Design)** — 本体コードは本提案では一切変更していない
- 位置付け: `docs/current/DEVELOPMENT_ENTRY_PROTOCOL.md` の 13-step protocol における
  「調査・設計」段階の成果物。実装は Human authorization 後に別途行う。

---

## 0. 結論(要約)

| 順位 | 施策 | 変更範囲 | 効果(合成Vault 6,150ノート) | 挙動変更 |
|---|---|---|---|---|
| **Tier 0** | 同一結果を3回計算している `Get-UciUuidMatchedCustomerFolders` 呼び出しを1回に統合 | OPEN/CHECK/COMPARE 各3行削除・1行変更 | **約 -4.4 秒 / 呼び出し (66% 削減)** | なし(純粋な重複除去) |
| **Tier 1** | frontmatter だけを StreamReader で読む + `Get-ChildItem -Recurse` を .NET 直接列挙へ | helper 4関数の内部実装 | 全Vault走査 2,261ms → **約 430ms (5.3x)** | なし(等価性テスト 142/142 PASS) |
| **Tier 2** | (path, size, mtime) キーの増分UUIDキャッシュ | Tier1 に +1関数 | 全Vault走査 → **約 560ms→ warm 時 ~200-560ms** ※列挙は毎回実施 | なし(全ファイル列挙は維持) |
| **Tier 3** | FileMaker 側フロー: UCI → CHECK の 2 プロセス起動・4 回全走査を 1 プロセス・1 走査へ | FileMaker スクリプト + action 追加 | プロセス起動 1 回分(~0.6s) + 全走査 1 回分 | **要仕様調整** |
| **Tier 4** | pk_CLIENT → 顧客フォルダ の永続インデックス + 検証 | 新設計 | 12ms (O(1)) | **要仕様調整**(衝突検出の範囲) |

**推奨:** Tier 0 → Tier 1 → Tier 2 の順で実装。この 3 つは判定規則・戻り値・エラーコード契約を
一切変えずに、1 クリックあたりの PowerShell 側検索時間を **約 9 秒 → 1 秒未満** (合成 Vault 基準) に
できる見込み。Tier 3/4 は仕様の再確認が必要なため、別サイクルで扱う。

---

## 1. なぜ遅いのか(計測に基づく原因分析)

### 1.1 計測環境

- 合成 Vault: 顧客フォルダ 1,500 / Markdown 6,150 ファイル / 1 ノート約 150 行(契約一覧テーブル相当)
  (`tools/perf/New-SyntheticVault.ps1` で生成。顧客実データは含まない)
- 実行: PowerShell 7.4.6 / Linux サンドボックス。
  **本番の Windows PowerShell 5.1 では `Get-ChildItem` と PSObject 生成が更に遅いため、
  実機の絶対値は本表より大きく、改善比率も大きくなる見込み。**
- 計測スクリプト: `tools/perf/Measure-SearchHotspots.ps1`
  (本体 `.ps1` から AST で関数定義のみを抽出して実行。本体は読み取りのみ)

### 1.2 1 回の OPEN / CHECK 呼び出しで実行される検索コスト

```
=== [A] 現行実装: Invoke-OpenObsidianNotes が1回の呼び出しで実行する検索 ===
A1 Get-UciUuidMatchedCustomerFolders (全再帰) x1                  2,261.0 ms
A2 同関数 3回目まで (本体は同じ結果を3回計算)                        6,598.5 ms   ← 最大要因
A3 Get-UciFolderEvidence (顧客フォルダ再帰)                            3.7 ms
A4 Get-UuidNoteTypeMatches x2 + OutOfScope x2                        12.2 ms
A5 identity未確定時: Get-UuidNoteTypeMatchesInTree (全再帰)          488.1 ms
A6 legacy候補: Normalize-ForMatch x 全フォルダ                       148.9 ms

=== [B] 単体要素のコスト分解 ===
B1 Get-ChildItem -Recurse -Filter *.md (列挙のみ)                    173.9 ms
B2 [IO.Directory]::EnumerateFiles (列挙のみ)                          21.0 ms   (8.3x)
B3 全ファイル Get-YamlHeaderLines (Test-Path+Get-Item+ReadAllLines)  1,626.0 ms
B4 全ファイル Get-YamlUuidFast (StreamReaderで先頭のみ)                469.3 ms   (3.5x)

=== [C] 最適化案の複合効果 ===
C1 EnumerateFiles + YamlUuidFast で全Vault UUID走査 1回              380.6 ms   (5.9x vs A1)
C2 インデックス構築(全走査1回)                                        411.3 ms
C3 インデックス参照 + 該当フォルダのみ再検証                           12.2 ms
```

### 1.3 原因 ①: 同一の全再帰走査を 1 呼び出しで 3 回実行している(最大要因)

`Invoke-OpenObsidianNotes` / `Invoke-CheckObsidianNotes` / `Invoke-CompareObsidianNotes` の
3 関数すべてに、**同じ引数で同じ関数を呼ぶブロックが 3 回**存在する。

```powershell
# L4796-4799  (Customer Folder Merge v1: 複数フォルダ衝突時の Fail-Closed 保護)
$matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
if ($matchedFoldersList.Count -ge 2) { Out-NG "UUID_FOLDER_CONFLICT" ... }

# L4802-4805  ← 上と完全に同一のブロックが重複(コピー&ペースト起因と推定)
$matchedFoldersList = @(Get-UciUuidMatchedCustomerFolders $custRoot $uuid)
if ($matchedFoldersList.Count -ge 2) { Out-NG "UUID_FOLDER_CONFLICT" ... }

# L4898  (v9.0.0 Step B: identity discovery)  ← 3 回目
$identityInfo = Get-UciUuidMatchedCustomerFolders $custRoot $uuid
```

同じ行番号パターンが CHECK (L5356/5362/5458) と COMPARE (L5979/5985/6081) にもある。
なお L4796 のブロックは `@(...)` で hashtable を包んでいるため `.Count` は常に 1 となり、
**実質的に何も検出していない**(判定は L4904 の `$identityFolders.Count -ge 2` が担っている)。

→ 1 回にすれば **-66%**。判定ロジックは L4898 以降がそのまま担うので挙動は不変。

### 1.4 原因 ②: 全ファイルを「全文」読んでいる

`Get-YamlHeaderLines` は 1 ファイルごとに
`Test-Path` → `Get-Item` → `[IO.File]::ReadAllLines` (全文) → 配列スライス を行う。
UUID の判定に必要なのは先頭の frontmatter (通常 5〜10 行) だけであり、
契約一覧のような数百行のテーブルを毎回全て読み込んでいる (B3 vs B4: 3.5x)。

### 1.5 原因 ③: `Get-ChildItem -Recurse` の PSObject オーバーヘッド

`Get-ChildItem` は 1 ファイルごとに PSObject ラップと provider パス解決を行う。
.NET の `DirectoryInfo.GetFiles/GetDirectories` 直接呼び出しに比べ 8x 遅い (B1 vs B2)。

### 1.6 原因 ④: FileMaker 側フローで PowerShell プロセスが 2 回起動し、全走査が計 4 回走る

`filemaker/EXT-obs_OBSノート-開く.txt` の流れ:

```
2A. UUID先行同期  → EXT-obs_顧客名・代表者名同期 → powershell.exe 起動 #1
                     Invoke-UpdateCustomerIdentity: 01_顧客 全再帰走査 ×1 (L907)
2B. CHECK         → EXT-obs_内部CallPS-PAYLOAD      → powershell.exe 起動 #2
                     Invoke-CheckObsidianNotes:      01_顧客 全再帰走査 ×3 (原因①)
```

→ 1 クリックで **プロセス起動 2 回 + 全 Vault 走査 4 回**。
合成 Vault では PowerShell 側だけで約 9 秒 (2.26s × 4)、加えて起動 ~0.6s × 2。

### 1.7 その他(小)

- `Assert-ObsidianReady` の `Get-Process "Obsidian"` — 数十 ms。
- identity 未確定時のみ: `Get-UuidNoteTypeMatchesInTree` 全再帰 (488ms) と
  `Normalize-ForMatch` を全フォルダ名に適用 (149ms、正規表現 8 回/フォルダ)。
- `Load-IndexSafe` の `obsidian_index.json` は読み書きされているが検索には使われていない。

---

## 2. 提案の詳細

### Tier 0 — 重複呼び出しの統合(最優先・最小 diff)

**変更内容(OPEN / CHECK / COMPARE の 3 箇所で同じ):**

1. L4796-4805 の重複ブロック 2 つを削除。
2. L4898 の `$identityInfo = Get-UciUuidMatchedCustomerFolders $custRoot $uuid` はそのまま。
   (L4904 の `$identityFolders.Count -ge 2` → `UUID_FOLDER_CONFLICT` が衝突検出を担う。
   エラーコード・メッセージは L4906 のものが出力される。)

**挙動差分:** なし。L4796/4802 の判定は前述のとおり常に偽であり、実際の衝突検出は L4904 で行われている。
念のため、L4798 と L4906 のメッセージ文言が異なる点は、Human review 時に「どちらを残すか」を確認する
(現状 L4906 の文言が出力されている)。

**効果:** 走査 3 回 → 1 回。合成 Vault で 6.6s → 2.3s。

### Tier 1 — frontmatter 限定読み込み + .NET 直接列挙

対象 helper (いずれも読み取り専用関数):

| 現行関数 | 置換内容 |
|---|---|
| `Get-UciUuidMatchedCustomerFolders` | `Get-MdFilesOrdered` で列挙 + `Read-YamlUuidFast` で UUID 取得 |
| `Get-UciFolderEvidence` | 同上 |
| `Get-UuidNoteTypeMatchesInTree` | 同上(パターン `"${iconPrefix}_*.md"`) |
| (UCI) L907 / L974 の inline 走査 | 同上 |

**等価性の担保 (`tools/perf/Prototype-FastUuidScan.ps1` + `Test-FastScanEquivalence.ps1`):**

- frontmatter 境界規則は `Get-YamlHeaderLines` と同一
  (1 行目 `---` / 次の `Trim() -eq "---"` 行で終端 / 終端なし → InvalidYaml)。
- `UUID:` 取り出しは `Get-YamlScalarValue "UUID:"` と同一
  (最初に一致した行、`"…"` / `'…'` を 1 組だけ剥がす)。**本文中の UUID は見ない。**
- 列挙順序は `Get-ChildItem -Recurse` と同一
  (各ディレクトリ: ファイル名順 → サブディレクトリ名順で再帰) に固定し、
  `detailPath`(「最初に見つかった不正ファイル」)が現行と一致することを確認済み。
- 再解析ポイント(ジャンクション/シンボリックリンク)配下へは降下しない
  (現行 `Get-ChildItem -Recurse` は降下する。安全側の差分。`-FollowReparse` で現行互換も可)。

```
=== Equivalence: Get-UciUuidMatchedCustomerFolders ===   12/12 PASS  (通常/引用UUID/小文字/BOM+CRLF/unresolved/該当なし)
=== Equivalence: Get-UciFolderEvidence ===              123/123 PASS (InvalidYaml/Conflict/InvalidUuid/Matched/NoEvidence)
=== Equivalence: Get-UuidNoteTypeMatchesInTree ===        6/6 PASS
=== Cache invalidation ===                                1/1 PASS
RESULT: pass=142 fail=0
  time: orig=16,526ms  fast=4,881ms  (6 lookups)  → 3.4x
```

**Windows PowerShell 5.1 互換性:** プロトタイプは .NET Framework 4.x に存在する API のみを使用
(`StreamReader`, `DirectoryInfo.GetFiles/GetDirectories`, `Array.Sort(keys, items, comparer)`,
`StringComparer`)。`RuntimeInformation.IsOSPlatform` のみ 4.7.1+ 依存のため、本体組込み時は
`$PSVersionTable.PSEdition -eq 'Desktop'` 判定に置き換えることを推奨。

### Tier 2 — 増分 UUID キャッシュ (`scripts/uuid_cache.json`)

- 毎回 **全ファイルを列挙する**(=Vault 全体の衝突検出・unresolved 検出は維持)が、
  `(path, size, LastWriteTimeUtc.Ticks)` が前回と一致するファイルは frontmatter を再読込しない。
- 列挙に無いパスはキャッシュから自然に落ちる(削除・リネーム追従)。
- 書き込みは tmp → Copy(overwrite) で原子的に置換。読めない/壊れている場合は空キャッシュとして再構築。
- `.gitignore` の `*.json` は対象外なので、本番 Vault 側の `scripts/` に置く運用
  (既存 `obsidian_index.json` と同じ場所)。

```
Get-VaultUuidTable warm: 561ms  hit=6161 miss=0        (cold: ~2,000ms)
after 1 file modified:   hit=6160 miss=1               ← 変更ファイルだけ再読込
```

**注意:** Obsidian が frontmatter を書き換えると mtime/size が変わるためキャッシュは自動失効する。
mtime を変えずに内容だけ変わるケース(タイムスタンプ保持コピー等)は理論上検出できないため、
「キャッシュは高速化のヒントであり、採用直前に対象ノートは必ず再読込して UUID を再検証する」
(現行 L5017-5034 の hint 再検証と同じ構造)を設計原則とする。

### Tier 3 — FileMaker 側フローの統合 (要仕様調整)

現行は UCI (プロセス #1) → CHECK (プロセス #2) の 2 段構成。案:

- **3-a (小):** UCI が返す JSON に解決済み顧客フォルダ名(`resolvedFolder`)を含め、
  CHECK payload に `folderHint` として渡す。CHECK 側は hint フォルダの evidence を先に評価し、
  `Matched` なら全走査を **省略せず後回し** にする…のではなく、
  全走査は identity authority のため省略できない → 効果は限定的。**Tier 2 があれば不要。**
- **3-b (中):** `action = "SYNC_AND_CHECK"` を新設し、UCI と CHECK を 1 プロセスで連続実行。
  走査結果(`Get-VaultUuidTable` の Rows)を両者で共有。
  → プロセス起動 1 回削減(~0.6s) + 全走査 1 回削減。
  応答契約が「JSON (UCI)」と「`OK|…` パイプ区切り (CHECK)」で異なるため、
  FileMaker 側スクリプトの改修と `docs/current/SPECIFICATION.md` の更新が必要。

### Tier 4 — pk_CLIENT → 顧客フォルダ 永続インデックス (要仕様調整)

`C3` のとおり O(1) 参照 + 該当フォルダのみ再検証で **12ms**。ただし
「01_顧客 配下のどこかに同 UUID の別フォルダが存在する」衝突は、
インデックスが最新でなければ検出できない。v9.0.0 の
「customer identity は完全 UUID 走査でのみ確定」原則と衝突するため、
採用するなら (a) バックグラウンド更新 + (b) 定期フル走査による整合性確認 の設計が前提。
本提案では **推奨しない**(Tier 0-2 で十分な効果が得られるため)。

---

## 3. 期待効果の見積り(合成 Vault 6,150 ノート・1 クリックあたり)

| 段階 | 全走査回数 | 1 走査コスト | 走査合計 | 備考 |
|---|---|---|---|---|
| 現行 | 4 (UCI 1 + CHECK 3) | 2,261 ms | **≈ 9.0 s** | + プロセス起動 2 回 |
| Tier 0 | 2 (UCI 1 + CHECK 1) | 2,261 ms | ≈ 4.5 s | |
| Tier 0+1 | 2 | ≈ 430 ms | ≈ 0.9 s | |
| Tier 0+1+2 (warm) | 2 | ≈ 200-560 ms | **≈ 0.4-1.1 s** | 変更ファイルのみ再読込 |
| + Tier 3-b | 1 | 同上 | ≈ 0.2-0.6 s | プロセス起動も 1 回 |

実機 (Windows PS 5.1) では現行の絶対値がこれより大きいことが予想されるため、
体感の改善幅はさらに大きくなる見込み。

---

## 4. 実装時の検証計画(DEVELOPMENT_ENTRY_PROTOCOL 準拠)

1. `tools/Test-CurrentBaseline.ps1` で baseline guard PASS を確認してから着手。
2. Tier 0: 削除する 6 ブロック(3 関数 × 2)の行番号を diff で明示。
   `tests/windows/Run-UCITests.ps1` full regression。
3. Tier 1: `tools/perf/Test-FastScanEquivalence.ps1` を **本体組込み後の関数**に対して再実行し
   142/142 PASS を確認。加えて Windows 実機で
   - 8.3 短縮パス / 長いパス
   - ジャンクション配下(現行との差分: 降下しない)
   - BOM 付き / CRLF / 引用付き UUID / frontmatter 未閉鎖
   の fixture を `tests/fixtures/` に追加。
4. Tier 2: キャッシュ破損・部分書き込み・削除追従・mtime 逆行のテストを追加。
5. `docs/current/ARCHITECTURE_DESIGN.md` §3.3 の直後に「§3.4 Search Path Performance」を追加し、
   `current-baseline.json` の SHA/size は Human authorization 後に更新。

---

## 5. 添付ツール(本 PR で追加。本体 `.ps1` は無変更)

| パス | 用途 |
|---|---|
| `tools/perf/New-SyntheticVault.ps1` | 顧客実データを含まない合成 Vault 生成 |
| `tools/perf/Measure-SearchHotspots.ps1` | 本体から関数を AST 抽出して現行コストを分解計測 (read-only) |
| `tools/perf/Prototype-FastUuidScan.ps1` | Tier 1/2 の参照実装 (本体未組込み) |
| `tools/perf/Test-FastScanEquivalence.ps1` | 現行 vs プロトタイプの結果完全一致テスト + 時間比較 |

実行例:

```powershell
pwsh -NoProfile -File tools/perf/New-SyntheticVault.ps1 -Root C:\Temp\synthvault -Customers 1500
pwsh -NoProfile -File tools/perf/Measure-SearchHotspots.ps1 -VaultRoot C:\Temp\synthvault
pwsh -NoProfile -File tools/perf/Test-FastScanEquivalence.ps1 -VaultRoot C:\Temp\synthvault
```
