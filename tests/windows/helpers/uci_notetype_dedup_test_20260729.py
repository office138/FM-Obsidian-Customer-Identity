# -*- coding: utf-8 -*-
"""
Get-UuidNoteTypeMatches および挿入した分岐ロジックの focused test。
実際のファイルI/O(一時ディレクトリ)を用い、PowerShellの新規関数と同一の
アルゴリズム(アイコン接頭辞グロブ + frontmatter内UUID一致)をPythonで忠実に再現して検証する。

対象修正: FM-Obsidian-Bridge-Payload.ps1 の Get-UuidNoteTypeMatches 追加、および
legacy CHECKの $existing フォルダ解決ブロックへのUUID+noteType優先解決の挿入
(2026-07-29、社名変更後の重複ノート作成防止)。

このテストはWindows PowerShell 5.1実機ではなくPython上でロジックを再現したものであり、
実機での最終確認の代わりにはならない。
"""
import os, shutil, sys

BASE = "/tmp/uci_notetype_test/vault/01_顧客"

ICON_PREFIX = {
    "契約一覧": "✡️一覧",
    "事故一覧": "⛔一覧",
    "契約":   "\U0001F7E8契約",
    "事故":   "\U0001F7E5事故",
    "決算書": "◻️決算書",
    "その他": "⬛その他",
}

def get_icon_prefix(note_type):
    if "契約一覧" in note_type: return ICON_PREFIX["契約一覧"]
    if "事故一覧" in note_type: return ICON_PREFIX["事故一覧"]
    if "契約" in note_type: return ICON_PREFIX["契約"]
    if "事故" in note_type: return ICON_PREFIX["事故"]
    if "決算" in note_type: return ICON_PREFIX["決算書"]
    return ICON_PREFIX["その他"]

def get_yaml_header_lines(path):
    if not os.path.exists(path): return []
    with open(path, "r", encoding="utf-8-sig") as f:
        content = f.read()
    if content == "":
        return []
    lines = content.splitlines()
    if len(lines) == 0: return []
    if lines[0].strip() != "---": return []
    end_idx = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break
    if end_idx == -1: return None
    if end_idx == 1: return []
    return lines[1:end_idx]

def get_yaml_scalar_value(header_lines, key_prefix):
    if header_lines is None: return ""
    for line in header_lines:
        t = line.strip()
        if t.startswith(key_prefix):
            v = t[len(key_prefix):].strip()
            if len(v) >= 2 and ((v[0]=='"' and v[-1]=='"') or (v[0]=="'" and v[-1]=="'")):
                v = v[1:-1]
            return v
    return ""

def get_uuid_notetype_matches(folder_path, icon_prefix, uuid):
    matched = []
    if not uuid or uuid.strip() == "":
        return matched
    if not os.path.isdir(folder_path):
        return matched
    for fname in os.listdir(folder_path):
        if not fname.endswith(".md"): continue
        if not fname.startswith(icon_prefix + "_"): continue
        fpath = os.path.join(folder_path, fname)
        hdr = get_yaml_header_lines(fpath)
        if hdr is None: continue
        u = get_yaml_scalar_value(hdr, "UUID:")
        if u.strip() != "" and u.strip().upper() == uuid.strip().upper():
            matched.append(fpath)
    return matched

def resolve(folder_path, note_type, uuid, name_norm):
    icon_prefix = get_icon_prefix(note_type)
    canonical_file = f"{icon_prefix}_{name_norm}.md"
    matches = get_uuid_notetype_matches(folder_path, icon_prefix, uuid)
    if len(matches) >= 2:
        return ("CONFLICT", None, len(matches))
    elif len(matches) == 1:
        return ("MATCHED_EXISTING", matches[0], 1)
    else:
        candidate = os.path.join(folder_path, canonical_file)
        exists = os.path.exists(candidate)
        return ("FALLTHROUGH_CANONICAL", candidate, 0 if not exists else "exists-but-0-uuid-match")

def write_note(folder, filename, uuid, body="本文サンプル"):
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, filename)
    yaml = f"---\ntags:\n  - \"テスト\"\nUUID: {uuid}\nランク: A\n---\n{body}\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(yaml)
    return path

def reset():
    if os.path.exists(BASE):
        shutil.rmtree(BASE)
    os.makedirs(BASE, exist_ok=True)

results = []

def check(name, cond, detail=""):
    results.append((name, "PASS" if cond else "FAIL", detail))

UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
UUID_B = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"

# Case 1
reset()
folder = os.path.join(BASE, "新顧客名")
write_note(folder, "🟨契約_旧顧客名.md", UUID_A)
status, path, n = resolve(folder, "契約", UUID_A, "新顧客名")
check("Case1_既存旧名ノート採用", status == "MATCHED_EXISTING" and path.endswith("🟨契約_旧顧客名.md"), f"status={status} path={path}")
check("Case1_新規ファイル未作成", not os.path.exists(os.path.join(folder, "🟨契約_新顧客名.md")))
check("Case1_同一UUIDノート数1", len([f for f in os.listdir(folder) if f.endswith(".md")]) == 1)

# Case 2
reset()
folder = os.path.join(BASE, "複数種別顧客")
write_note(folder, "🟨契約_旧複数種別顧客.md", UUID_A)
write_note(folder, "🟥事故_旧複数種別顧客.md", UUID_A)
write_note(folder, "◻️決算書_旧複数種別顧客.md", UUID_A)
write_note(folder, "⬛その他_旧複数種別顧客.md", UUID_A)
write_note(folder, "✡️一覧_旧複数種別顧客.md", UUID_A)
write_note(folder, "⛔一覧_旧複数種別顧客.md", UUID_A)
for nt, fname in [("契約","🟨契約_旧複数種別顧客.md"),("事故","🟥事故_旧複数種別顧客.md"),
                   ("決算書","◻️決算書_旧複数種別顧客.md"),("その他","⬛その他_旧複数種別顧客.md"),
                   ("契約一覧","✡️一覧_旧複数種別顧客.md"),("事故一覧","⛔一覧_旧複数種別顧客.md")]:
    status, path, n = resolve(folder, nt, UUID_A, "新複数種別顧客")
    check(f"Case2_{nt}_1件採用", status=="MATCHED_EXISTING" and path.endswith(fname), f"status={status} path={path}")
all_files_after = set(os.listdir(folder))
check("Case2_他ノート変更削除なし", all_files_after == {"🟨契約_旧複数種別顧客.md","🟥事故_旧複数種別顧客.md","◻️決算書_旧複数種別顧客.md","⬛その他_旧複数種別顧客.md","✡️一覧_旧複数種別顧客.md","⛔一覧_旧複数種別顧客.md"})

# Case 3
reset()
folder = os.path.join(BASE, "新規相当顧客")
os.makedirs(folder, exist_ok=True)
status, path, n = resolve(folder, "契約", UUID_A, "新規相当顧客")
check("Case3_フォールバック", status == "FALLTHROUGH_CANONICAL", f"status={status}")

# Case 4
reset()
folder = os.path.join(BASE, "重複顧客")
write_note(folder, "🟨契約_旧顧客名A.md", UUID_A)
write_note(folder, "🟨契約_旧顧客名B.md", UUID_A)
status, path, n = resolve(folder, "契約", UUID_A, "新顧客名")
check("Case4_競合検出", status == "CONFLICT" and n == 2, f"status={status} n={n}")
check("Case4_ファイル変更なし", set(os.listdir(folder)) == {"🟨契約_旧顧客名A.md","🟨契約_旧顧客名B.md"})

# Case 5
reset()
folder = os.path.join(BASE, "別顧客")
write_note(folder, "🟨契約_別顧客.md", UUID_B)
status, path, n = resolve(folder, "契約", UUID_A, "新顧客名")
check("Case5_UUID不一致は0件扱い", status == "FALLTHROUGH_CANONICAL", f"status={status}")

# Case 6
reset()
folder = os.path.join(BASE, "種別不一致顧客")
write_note(folder, "🟨契約_旧顧客名.md", UUID_A)
status, path, n = resolve(folder, "事故", UUID_A, "新顧客名")
check("Case6_noteType不一致は0件扱い", status == "FALLTHROUGH_CANONICAL", f"status={status}")
check("Case6_契約ノート変更なし", os.path.exists(os.path.join(folder, "🟨契約_旧顧客名.md")))

# 追加: 不正YAML
reset()
folder = os.path.join(BASE, "不正YAML顧客")
os.makedirs(folder, exist_ok=True)
with open(os.path.join(folder, "🟨契約_不正YAML顧客.md"), "w", encoding="utf-8") as f:
    f.write("---\ntags:\n  - \"x\"\nUUID: " + UUID_A + "\n本文のみ(終了---なし)\n")
status, path, n = resolve(folder, "契約", UUID_A, "不正YAML顧客")
check("追加_不正YAMLは候補除外(0件扱い)", status == "FALLTHROUGH_CANONICAL", f"status={status}")

print(f"{'ケース':40s} {'結果':6s} 詳細")
pass_count = 0
for name, res, detail in results:
    print(f"{name:40s} {res:6s} {detail}")
    if res == "PASS": pass_count += 1
print()
print(f"{pass_count} / {len(results)} PASS")
sys.exit(0 if pass_count == len(results) else 1)
