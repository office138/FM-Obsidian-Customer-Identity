# -*- coding: utf-8 -*-
"""
UUID識別子付き正式命名規則への常時正規化(2026-07-29)の focused test。

対象: FM-Obsidian-Bridge-Payload.ps1 の Invoke-UpdateCustomerIdentity へ追加した
      フォルダ名・ノートファイル名のUUID識別子付き常時正規化ロジック、
      衝突事前チェック、YAML修復ポリシー、ロールバック拡張。

このテストはWindows PowerShell 5.1実機ではなく、追加した新規ロジックをPythonで
忠実に再現して検証したものであり、実機での最終確認の代わりにはならない。
Windows PowerShell 5.1実機での確認は Test-UciUuidNormalization_20260729.ps1 で行う。
"""
import os, re, shutil, sys

BASE = "/tmp/uci_uuid_norm_test/vault/01_顧客"

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

def get_prefix_map():
    return {get_icon_prefix(nt): nt for nt in ["契約一覧","事故一覧","契約","事故","決算書","その他"]}

def sanitize_leaf_name(s, fallback="NO_NAME"):
    if s is None or s.strip() == "":
        return fallback
    t = s.strip()
    t = re.sub(r"[\x00-\x1f\x7f]", "", t)
    t = re.sub(r"\s+|　+", "", t)
    t = re.sub(r'[\\/:*?"<>|]', "－", t)
    t = t.strip("・_-－ .")
    if t.strip() == "":
        t = fallback
    if re.match(r'^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$', t):
        t = t + "_File"
    return t

def get_note_name_norm(name_raw, note_type_like):
    n = name_raw.strip()
    if "一覧" in note_type_like:
        n = n.replace("株式会社", "㈱").replace("有限会社", "㈲")
        n = n.replace("（株）", "㈱").replace("(株)", "㈱")
        n = n.replace("（有）", "㈲").replace("(有)", "㈲")
    else:
        for r in ["株式会社","有限会社","合同会社","合名会社","合資会社","（株）","(株)","㈱","有限","（有）","(有)","㈲"]:
            n = n.replace(r, "")
    return sanitize_leaf_name(n, "NO_NAME")

def get_uuid_suffix(pk_client):
    return "_[" + pk_client[:8].upper() + "]"

def is_valid_uuid_format(s):
    return re.match(r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$', s) is not None

def get_yaml_header_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8-sig") as f:
        content = f.read()
    if content == "":
        return []
    lines = content.splitlines()
    if len(lines) == 0 or lines[0].strip() != "---":
        return list(lines)
    end_idx = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break
    if end_idx == -1:
        return None
    if end_idx == 1:
        return []
    return lines[1:end_idx]

def get_yaml_body_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8-sig") as f:
        content = f.read()
    if content == "":
        return []
    lines = content.splitlines()
    if len(lines) == 0 or lines[0].strip() != "---":
        return list(lines)
    end_idx = -1
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break
    if end_idx == -1:
        return None
    return lines[end_idx+1:]

def get_yaml_scalar_value(header_lines, key_prefix):
    if header_lines is None:
        return ""
    for line in header_lines:
        t = line.strip()
        if t.startswith(key_prefix):
            v = t[len(key_prefix):].strip()
            if len(v) >= 2 and ((v[0]=='"' and v[-1]=='"') or (v[0]=="'" and v[-1]=="'")):
                v = v[1:-1]
            return v
    return ""

def get_yaml_tag_values(header_lines):
    result = []
    if header_lines is None:
        return result
    in_tags = False
    for line in header_lines:
        t = line.strip()
        if t == "tags:" or t.startswith("tags:"):
            in_tags = True
            continue
        if in_tags:
            m = re.match(r"^\s*-\s*(.*)$", line)
            if m:
                v = m.group(1).strip()
                if len(v) >= 2 and ((v[0]=='"' and v[-1]=='"') or (v[0]=="'" and v[-1]=="'")):
                    v = v[1:-1]
                result.append(v)
            else:
                in_tags = False
    return result

def update_yaml_robust(path, rank, cust, ceo, ruby, uuid, total_premium=None):
    """既存Update-Yaml-Robustの忠実な再現(境界確定であれば内容の正誤を問わず再生成)。"""
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8-sig") as f:
        content = f.read()
    lines = content.splitlines() if content != "" else []
    clean_tags = []
    for val in [cust, ceo, ruby]:
        if val and val.strip() != "":
            c = re.sub(r"[\s　]+", "", val)
            if c != "":
                clean_tags.append(c)
    start_idx = -1; end_idx = -1
    for i, l in enumerate(lines):
        if l.strip() == "---":
            if start_idx == -1:
                start_idx = i
            else:
                end_idx = i
                break
    if start_idx == 0 and end_idx > 0:
        old_header = lines[1:end_idx] if end_idx > 1 else []
        body_lines = lines[end_idx+1:] if len(lines) > end_idx+1 else []
    else:
        old_header = []
        body_lines = lines
    kept = []
    skip_mode = False
    for line in old_header:
        trim = line.strip()
        if trim.startswith("tags:"):
            skip_mode = True; continue
        if trim.startswith("UUID:"):
            skip_mode = False; continue
        if trim.startswith("ランク:"):
            skip_mode = False; continue
        if trim.startswith("総合計保険料:"):
            skip_mode = False; continue
        if skip_mode:
            if re.match(r"^\s*-", line):
                continue
            skip_mode = False
            if trim.startswith("UUID:") or trim.startswith("ランク:") or trim.startswith("総合計保険料:"):
                continue
        kept.append(line)
    new_header = ["tags:"]
    for tag in clean_tags:
        new_header.append(f'  - "{tag}"')
    new_header.append(f"UUID: {uuid}")
    new_header.append(f"ランク: {rank}")
    if total_premium and total_premium.strip() != "":
        new_header.append(f"総合計保険料: {total_premium}")
    new_header.extend(kept)
    final_content = ["---"] + new_header + ["---"] + body_lines
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(final_content) + "\n")

def write_note(folder, filename, uuid, tags=None, rank="A", body="本文サンプル", broken_uuid_format=False, no_frontmatter=False, unclosed=False):
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, filename)
    if no_frontmatter:
        content = body
    elif unclosed:
        content = f"---\ntags:\n  - \"x\"\nUUID: {uuid}\n{body}\n"
    else:
        tag_lines = ""
        for t in (tags or []):
            tag_lines += f'  - "{t}"\n'
        content = f"---\ntags:\n{tag_lines}UUID: {uuid}\nランク: {rank}\n---\n{body}\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return path


def invoke_update_customer_identity(folder_path, company_name_raw, ceo, ruby, rank, pk_client, fail_at_index=None):
    """新ロジックの忠実な再現。folder_path = 対象顧客フォルダの絶対パス(既に一意特定済みとする)。
    戻り値: (status, code, response_dict)
    """
    current_folder_name = os.path.basename(folder_path)
    parent_dir = os.path.dirname(folder_path)

    # Step1相当: フォルダ内の全.mdからUUID完全一致するものをmatchedNotesとする
    matched_notes = []
    for fname in os.listdir(folder_path):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(folder_path, fname)
        hdr = get_yaml_header_lines(fpath)
        if hdr is None:
            continue
        u = get_yaml_scalar_value(hdr, "UUID:")
        if u.strip() != "" and u.strip().upper() == pk_client.upper():
            matched_notes.append(fpath)

    if len(matched_notes) == 0:
        return ("NG", "CUSTOMER_NOT_FOUND", {})

    # Step3相当: フォルダ内整合性確認 + 修復候補収集
    repair_candidates = []
    for fname in os.listdir(folder_path):
        if not fname.endswith(".md"):
            continue
        fpath = os.path.join(folder_path, fname)
        hdr = get_yaml_header_lines(fpath)
        if hdr is None:
            return ("NG", "YAML_BODY_BOUNDARY_UNRESOLVED", {"filePath": fpath})
        u = get_yaml_scalar_value(hdr, "UUID:")
        if u.strip() != "":
            if not is_valid_uuid_format(u.strip()):
                repair_candidates.append(fpath)
                continue
            if u.strip().upper() != pk_client.upper():
                return ("NG", "FOLDER_UUID_MIXED", {})

    # Step4相当: フォルダ名決定
    uuid_suffix = get_uuid_suffix(pk_client)
    new_folder_base = sanitize_leaf_name(company_name_raw, "NO_NAME")
    new_folder_name = new_folder_base + uuid_suffix
    folder_needs_rename = (new_folder_name != current_folder_name)
    if folder_needs_rename:
        for d in os.listdir(parent_dir):
            full = os.path.join(parent_dir, d)
            if os.path.isdir(full) and d == new_folder_name and d != current_folder_name:
                return ("NG", "TARGET_FOLDER_ALREADY_EXISTS", {})

    # Step4.5相当: ノートリネームプラン
    prefix_map = get_prefix_map()
    all_targets = matched_notes + repair_candidates
    plan = []
    for orig in all_targets:
        cur_name = os.path.basename(orig)
        is_direct_child = (os.path.dirname(orig) == folder_path)
        rec_prefix = None
        for pfx in prefix_map.keys():
            if cur_name.startswith(pfx + "_"):
                rec_prefix = pfx
                break
        needs_rename = False
        target_name = cur_name
        if rec_prefix is not None and is_direct_child:
            note_type_like = prefix_map[rec_prefix]
            name_norm = get_note_name_norm(company_name_raw, note_type_like)
            target_name = f"{rec_prefix}_{name_norm}{uuid_suffix}.md"
            needs_rename = (target_name != cur_name)
        plan.append({"orig": orig, "curFileName": cur_name, "recognizedPrefix": rec_prefix,
                     "targetFileName": target_name, "needsRename": needs_rename})

    any_note_needs_rename = any(p["needsRename"] for p in plan)
    any_repair_pending = len(repair_candidates) > 0

    # Step5相当: NO_CHANGE判定(タグ・ランク比較)
    clean_tags = []
    for val in [company_name_raw, ceo, ruby]:
        if val and val.strip() != "":
            c = re.sub(r"[\s　]+", "", val)
            if c != "":
                clean_tags.append(c)
    any_note_needs_update = False
    for p in matched_notes:
        hdr = get_yaml_header_lines(p)
        cur_rank = get_yaml_scalar_value(hdr, "ランク:")
        cur_tags = get_yaml_tag_values(hdr)
        tags_same = (len(cur_tags) == len(clean_tags)) and all(a == b for a, b in zip(cur_tags, clean_tags))
        if cur_rank.strip() != rank.strip() or not tags_same:
            any_note_needs_update = True
            break

    if not folder_needs_rename and not any_note_needs_update and not any_note_needs_rename and not any_repair_pending:
        return ("OK", "NO_CHANGE", {"folderRenamed": False})

    # Step4.6相当: 衝突事前チェック
    seen = {}
    for p in plan:
        if p["recognizedPrefix"] is None:
            continue
        if p["targetFileName"] in seen:
            return ("NG", "NOTE_TYPE_UUID_CONFLICT", {})
        seen[p["targetFileName"]] = True
    plan_cur_names = {p["curFileName"] for p in plan}
    for p in plan:
        if not p["needsRename"]:
            continue
        prospective = os.path.join(folder_path, p["targetFileName"])
        if os.path.exists(prospective) and p["targetFileName"] not in plan_cur_names:
            coll_hdr = get_yaml_header_lines(prospective)
            coll_uuid = get_yaml_scalar_value(coll_hdr, "UUID:")
            coll_tags = get_yaml_tag_values(coll_hdr)
            return ("NG", "TARGET_NOTE_FILENAME_CONFLICT", {
                "conflictPath": prospective, "conflictUuid": coll_uuid,
                "conflictCustomerName": coll_tags[0] if len(coll_tags) >= 1 else "",
                "conflictRepresentative": coll_tags[1] if len(coll_tags) >= 2 else "",
                "suggestedCanonicalName": p["targetFileName"],
            })

    # Step6相当: バックアップ取得
    note_pairs = []
    backups = {}
    for p in plan:
        orig = p["orig"]
        rel = os.path.basename(orig)  # 直下のみが対象なのでrel=ファイル名相当で十分(このシミュレーションでは)
        body_lines = get_yaml_body_lines(orig)
        orig_body = "\n".join(body_lines) if body_lines is not None else None
        with open(orig, "rb") as f:
            backups[rel] = f.read()
        note_pairs.append({"orig": orig, "rel": rel, "newPath": None, "origBody": orig_body,
                            "needsRename": p["needsRename"], "targetFileName": p["targetFileName"],
                            "curFileName": p["curFileName"], "renamed": False})

    # Step7相当: フォルダリネーム
    active_folder_path = folder_path
    if folder_needs_rename:
        new_path = os.path.join(parent_dir, new_folder_name)
        os.rename(folder_path, new_path)
        active_folder_path = new_path
    for pair in note_pairs:
        pair["newPath"] = os.path.join(active_folder_path, pair["rel"])

    # Step8/9相当: リネーム+YAML更新+検証(+ロールバック)
    processed = []
    write_error = None
    updated_count = 0
    for idx, pair in enumerate(note_pairs):
        processed.append(pair)
        try:
            if fail_at_index is not None and idx == fail_at_index:
                raise RuntimeError("意図的な注入失敗(テスト用)")
            if pair["needsRename"]:
                os.rename(pair["newPath"], os.path.join(active_folder_path, pair["targetFileName"]))
                pair["renamed"] = True
                pair["newPath"] = os.path.join(active_folder_path, pair["targetFileName"])
            hdr_before = get_yaml_header_lines(pair["newPath"])
            existing_premium = get_yaml_scalar_value(hdr_before, "総合計保険料:")
            premium_to_pass = existing_premium if existing_premium.strip() != "" else None
            update_yaml_robust(pair["newPath"], rank, company_name_raw, ceo, ruby, pk_client, premium_to_pass)
            hdr_after = get_yaml_header_lines(pair["newPath"])
            if hdr_after is None:
                raise RuntimeError("更新後のYAML再読込みに失敗しました。")
            u_after = get_yaml_scalar_value(hdr_after, "UUID:")
            r_after = get_yaml_scalar_value(hdr_after, "ランク:")
            if u_after.upper() != pk_client.upper() or r_after.strip() != rank.strip():
                raise RuntimeError("更新後のYAML内容(UUID/ランク)が期待値と一致しません。")
            if pair["origBody"] is not None:
                body_after_lines = get_yaml_body_lines(pair["newPath"])
                body_after = "\n".join(body_after_lines) if body_after_lines is not None else None
                if body_after != pair["origBody"]:
                    raise RuntimeError("更新後の本文が更新前と一致しません。")
            updated_count += 1
        except Exception as e:
            write_error = str(e)
            break

    if write_error is not None:
        rollback_ok = True
        for pair in processed:
            try:
                restore_path = pair["newPath"]
                if pair["renamed"]:
                    if os.path.exists(pair["newPath"]):
                        os.rename(pair["newPath"], os.path.join(active_folder_path, pair["curFileName"]))
                    restore_path = os.path.join(active_folder_path, pair["curFileName"])
                with open(restore_path, "wb") as f:
                    f.write(backups[pair["rel"]])
            except Exception:
                rollback_ok = False
        if folder_needs_rename:
            try:
                os.rename(active_folder_path, os.path.join(parent_dir, current_folder_name))
            except Exception:
                rollback_ok = False
        if not rollback_ok:
            return ("NG", "UPDATE_ROLLBACK_FAILED", {})
        return ("NG", "NOTE_UPDATE_FAILED", {})

    final_folder_name = new_folder_name if folder_needs_rename else current_folder_name
    renamed_notes = [{"oldName": p["curFileName"], "newName": p["targetFileName"]} for p in note_pairs if p["renamed"]]
    return ("OK", "CUSTOMER_IDENTITY_UPDATED", {
        "folderRenamed": folder_needs_rename, "finalFolderName": final_folder_name,
        "updatedCount": updated_count, "uuidSuffix": uuid_suffix, "renamedNotes": renamed_notes,
    })


results = []
def check(name, cond, detail=""):
    results.append((name, "PASS" if cond else "FAIL", detail))

def reset():
    if os.path.exists(BASE):
        shutil.rmtree(BASE)
    os.makedirs(BASE, exist_ok=True)

UUID_A = "2250BA49-7A95-AA4B-9FBE-C0E0EB4AD1D1"
UUID_B = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
SUFFIX_A = "_[2250BA49]"

# ---- Case1: 社名変更なし・UUID識別子なし → フォルダ+全ノートへ識別子付与 ----
reset()
folder = os.path.join(BASE, "Faithウエダ㈱")
write_note(folder, "🟨契約_Faithウエダ.md", UUID_A, tags=["Faithウエダ㈱","代表太郎"], rank="A")
status, code, resp = invoke_update_customer_identity(folder, "Faithウエダ㈱", "代表太郎", "", "A", UUID_A)
new_folder = os.path.join(BASE, "Faithウエダ㈱" + SUFFIX_A)
check("Case1_status_OK", status == "OK" and code == "CUSTOMER_IDENTITY_UPDATED", f"{status}/{code}")
check("Case1_フォルダ名にUUID付与", os.path.isdir(new_folder))
check("Case1_旧フォルダ消滅", not os.path.isdir(folder))
expected_note = os.path.join(new_folder, f"🟨契約_Faithウエダ{SUFFIX_A}.md")
check("Case1_ノート名にUUID付与", os.path.isfile(expected_note))
check("Case1_旧ノート名消滅", not os.path.isfile(os.path.join(new_folder, "🟨契約_Faithウエダ.md")))
if os.path.isfile(expected_note):
    with open(expected_note, encoding="utf-8-sig") as f:
        body = f.read()
    check("Case1_本文保持", "本文サンプル" in body)

# ---- Case2: 社名変更あり・UUID識別子なし → リネーム+識別子付与 ----
reset()
folder = os.path.join(BASE, "旧会社名")
write_note(folder, "🟨契約_旧会社名.md", UUID_A, tags=["旧会社名","代表太郎"], rank="A")
status, code, resp = invoke_update_customer_identity(folder, "新会社名", "代表太郎", "", "A", UUID_A)
new_folder = os.path.join(BASE, "新会社名" + SUFFIX_A)
check("Case2_status_OK", status == "OK" and code == "CUSTOMER_IDENTITY_UPDATED", f"{status}/{code}")
check("Case2_フォルダ名リネーム+付与", os.path.isdir(new_folder))
check("Case2_ノート名リネーム+付与", os.path.isfile(os.path.join(new_folder, f"🟨契約_新会社名{SUFFIX_A}.md")))

# ---- Case3: 社名変更あり・UUID識別子は既に付いている → 名前部分だけ更新、識別子重複なし ----
reset()
folder = os.path.join(BASE, "旧会社名" + SUFFIX_A)
write_note(folder, f"🟨契約_旧会社名{SUFFIX_A}.md", UUID_A, tags=["旧会社名","代表太郎"], rank="A")
status, code, resp = invoke_update_customer_identity(folder, "新会社名", "代表太郎", "", "A", UUID_A)
new_folder = os.path.join(BASE, "新会社名" + SUFFIX_A)
check("Case3_status_OK", status == "OK" and code == "CUSTOMER_IDENTITY_UPDATED", f"{status}/{code}")
check("Case3_フォルダ名は名前部分のみ更新", os.path.isdir(new_folder))
new_note = os.path.join(new_folder, f"🟨契約_新会社名{SUFFIX_A}.md")
check("Case3_ノート名は名前部分のみ更新", os.path.isfile(new_note))
check("Case3_識別子重複なし", "_[2250BA49]_[2250BA49]" not in os.path.basename(new_note))
check("Case3_フォルダ名にも識別子重複なし", "_[2250BA49]_[2250BA49]" not in os.path.basename(new_folder))

# ---- Case4: 既に完全正式名 → 変更なし・NO_CHANGE ----
reset()
folder = os.path.join(BASE, "Faithウエダ㈱" + SUFFIX_A)
note_path = write_note(folder, f"🟨契約_Faithウエダ{SUFFIX_A}.md", UUID_A, tags=["Faithウエダ㈱","代表太郎"], rank="A")
with open(note_path, "rb") as f:
    before_bytes = f.read()
status, code, resp = invoke_update_customer_identity(folder, "Faithウエダ㈱", "代表太郎", "", "A", UUID_A)
check("Case4_NO_CHANGE", status == "OK" and code == "NO_CHANGE", f"{status}/{code}")
with open(note_path, "rb") as f:
    after_bytes = f.read()
check("Case4_ファイル内容ハッシュ不変", before_bytes == after_bytes)

# ---- Case5: 6noteType全てが同一UUID配下に共存 → 全て正しく識別子付き正式名へ ----
reset()
folder = os.path.join(BASE, "Faithウエダ㈱")
notes_map = {
    "契約": "🟨契約_Faithウエダ.md",
    "事故": "🟥事故_Faithウエダ.md",
    "決算書": "◻️決算書_Faithウエダ.md",
    "その他": "⬛その他_Faithウエダ.md",
    "契約一覧": "✡️一覧_Faithウエダ㈱.md",
    "事故一覧": "⛔一覧_Faithウエダ㈱.md",
}
for nt, fname in notes_map.items():
    write_note(folder, fname, UUID_A, tags=["Faithウエダ㈱","代表太郎"], rank="A", body=f"本文_{nt}")
status, code, resp = invoke_update_customer_identity(folder, "Faithウエダ㈱", "代表太郎", "", "A", UUID_A)
new_folder = os.path.join(BASE, "Faithウエダ㈱" + SUFFIX_A)
check("Case5_status_OK", status == "OK" and code == "CUSTOMER_IDENTITY_UPDATED", f"{status}/{code}")
expected = {
    "契約": f"🟨契約_Faithウエダ{SUFFIX_A}.md",
    "事故": f"🟥事故_Faithウエダ{SUFFIX_A}.md",
    "決算書": f"◻️決算書_Faithウエダ{SUFFIX_A}.md",
    "その他": f"⬛その他_Faithウエダ{SUFFIX_A}.md",
    "契約一覧": f"✡️一覧_Faithウエダ㈱{SUFFIX_A}.md",
    "事故一覧": f"⛔一覧_Faithウエダ㈱{SUFFIX_A}.md",
}
for nt, fname in expected.items():
    p = os.path.join(new_folder, fname)
    ok = os.path.isfile(p)
    if ok:
        with open(p, encoding="utf-8-sig") as f:
            ok = ok and (f"本文_{nt}" in f.read())
    check(f"Case5_{nt}_正式名+本文保持", ok, fname)

# ---- Case6: UUIDなし補助ノート → ファイル名・内容とも不変 ----
reset()
folder = os.path.join(BASE, "Faithウエダ㈱")
write_note(folder, "🟨契約_Faithウエダ.md", UUID_A, tags=["Faithウエダ㈱","代表太郎"], rank="A")
aux_path = os.path.join(folder, "補助メモ.md")
with open(aux_path, "w", encoding="utf-8") as f:
    f.write("UUIDなしの補助ノート本文")
with open(aux_path, "rb") as f:
    aux_before = f.read()
status, code, resp = invoke_update_customer_identity(folder, "Faithウエダ㈱", "代表太郎", "", "A", UUID_A)
new_folder = os.path.join(BASE, "Faithウエダ㈱" + SUFFIX_A)
moved_aux = os.path.join(new_folder, "補助メモ.md")
check("Case6_補助ノートはファイル名不変(フォルダ内に同名で存在)", os.path.isfile(moved_aux))
if os.path.isfile(moved_aux):
    with open(moved_aux, "rb") as f:
        aux_after = f.read()
    check("Case6_補助ノート内容不変", aux_before == aux_after)

# ---- Case7: 別UUIDノートが同一フォルダに混在 → FOLDER_UUID_MIXEDで停止 ----
reset()
folder = os.path.join(BASE, "混在顧客")
write_note(folder, "🟨契約_混在顧客.md", UUID_A, tags=["混在顧客","代表太郎"], rank="A")
write_note(folder, "🟥事故_別顧客.md", UUID_B, tags=["別顧客","別代表"], rank="B")
status, code, resp = invoke_update_customer_identity(folder, "混在顧客", "代表太郎", "", "A", UUID_A)
check("Case7_FOLDER_UUID_MIXEDで停止", status == "NG" and code == "FOLDER_UUID_MIXED", f"{status}/{code}")
check("Case7_フォルダ名不変", os.path.isdir(folder))

# ---- Case8: 同一社名・異なるUUID識別子の2顧客が共存 ----
reset()
UUID_C = "9F13C842-0000-0000-0000-000000000000"
f8a = os.path.join(BASE, "Faithウエダ㈱_顧客A")
f8b = os.path.join(BASE, "Faithウエダ㈱_顧客B")
write_note(f8a, "🟨契約_Faithウエダ.md", UUID_A, tags=["Faithウエダ㈱","代表A"], rank="A")
write_note(f8b, "🟨契約_Faithウエダ.md", UUID_C, tags=["Faithウエダ㈱","代表B"], rank="A")
s1, c1, r1 = invoke_update_customer_identity(f8a, "Faithウエダ㈱", "代表A", "", "A", UUID_A)
s2, c2, r2 = invoke_update_customer_identity(f8b, "Faithウエダ㈱", "代表B", "", "A", UUID_C)
# フォルダ名は常にcompanyNameRaw+UUID接尾辞から再生成されるため、テスト用に付けた
# "_顧客A"/"_顧客B"の区別用サフィックスは変更後は残らない(想定どおりの挙動)。
new_a = os.path.join(BASE, "Faithウエダ㈱" + SUFFIX_A)
new_b = os.path.join(BASE, "Faithウエダ㈱" + "_[9F13C842]")
check("Case8_顧客A正常処理", s1 == "OK" and c1 == "CUSTOMER_IDENTITY_UPDATED", f"{s1}/{c1}")
check("Case8_顧客B正常処理", s2 == "OK" and c2 == "CUSTOMER_IDENTITY_UPDATED", f"{s2}/{c2}")
check("Case8_両者共存(A)", os.path.isdir(new_a))
check("Case8_両者共存(B)", os.path.isdir(new_b))

# ---- Case9: 変更先の正式名パスに無関係な別ファイルが既に存在(異常衝突) ----
# 衝突先ファイルが「有効な別UUID」を持っていると、Step3のフォルダ内整合性確認
# (FOLDER_UUID_MIXED)がこの衝突検出より先に発火してしまう(意図した安全設計)。
# そのため、この衝突シナリオを現実的に再現するには「UUIDキー自体を持たない」
# 衝突ファイル(例: 手動で置かれた無関係なメモ)を用いる。
reset()
folder = os.path.join(BASE, "衝突顧客")
write_note(folder, "🟨契約_衝突顧客旧名.md", UUID_A, tags=["衝突顧客","代表太郎"], rank="A", body="正しい本文")
# 衝突先(変更後に一致するはずの名前)に無関係な別ファイル(UUIDキーなし)を先に置いておく
conflict_path = os.path.join(folder, f"🟨契約_衝突顧客{SUFFIX_A}.md")
with open(conflict_path, "w", encoding="utf-8") as f:
    f.write("無関係な既存ファイル(UUIDキーなし)")
with open(conflict_path, "rb") as f:
    conflict_before = f.read()
status, code, resp = invoke_update_customer_identity(folder, "衝突顧客", "代表太郎", "", "A", UUID_A)
check("Case9_TARGET_NOTE_FILENAME_CONFLICTで停止", status == "NG" and code == "TARGET_NOTE_FILENAME_CONFLICT", f"{status}/{code}")
with open(conflict_path, "rb") as f:
    conflict_after = f.read()
check("Case9_衝突先ファイル内容不変(上書きなし)", conflict_before == conflict_after)
check("Case9_元の旧名ノートも残存(削除なし)", os.path.isfile(os.path.join(folder, "🟨契約_衝突顧客旧名.md")))

# ---- Case10: YAML管理キーが壊れているが本文境界は確定 → 修復+正式名化、本文保持 ----
# 注記: Step1/Step2の顧客フォルダ解決は「有効な形式でUUIDが完全一致するノートが
# 最低1件フォルダ内に存在すること」を前提とする(既存仕様、今回変更していない)。
# そのため修復対象の壊れたノート単体では顧客フォルダ自体を解決できない。
# 現実的なシナリオとして、同一フォルダ内に他の正常なノートが1件存在する状態を再現する。
reset()
folder = os.path.join(BASE, "修復顧客")
write_note(folder, "🟨契約_修復顧客.md", UUID_A, tags=["修復顧客","代表太郎"], rank="A", body="正常ノート本文")
p10 = os.path.join(folder, "🟥事故_修復顧客.md")
with open(p10, "w", encoding="utf-8") as f:
    # UUID行の形式が不正(短すぎる) + tagsが壊れている。境界(開始・終了---)は確定できる。
    f.write("---\ntags:\n  broken: yes\nUUID: not-a-uuid\nrank_typo: A\n---\n本文は保持されるべき\n")
status, code, resp = invoke_update_customer_identity(folder, "修復顧客", "代表太郎", "カブシキガイシャ", "A", UUID_A)
new_folder = os.path.join(BASE, "修復顧客" + SUFFIX_A)
new_note = os.path.join(new_folder, f"🟥事故_修復顧客{SUFFIX_A}.md")
check("Case10_status_OK", status == "OK" and code == "CUSTOMER_IDENTITY_UPDATED", f"{status}/{code}")
check("Case10_修復後に正式名へリネーム", os.path.isfile(new_note))
if os.path.isfile(new_note):
    hdr = get_yaml_header_lines(new_note)
    u = get_yaml_scalar_value(hdr, "UUID:")
    check("Case10_UUIDがFileMaker値に修復", u.upper() == UUID_A.upper())
    with open(new_note, encoding="utf-8-sig") as f:
        body = f.read()
    check("Case10_本文完全保持", "本文は保持されるべき" in body)

# ---- Case11: frontmatter開始はあるが終了---が見つからない(境界判定不能) ----
# Case10同様、顧客フォルダ自体を解決するため同一フォルダ内に正常なノートを1件用意する。
reset()
folder = os.path.join(BASE, "境界不能顧客")
write_note(folder, "🟨契約_境界不能顧客.md", UUID_A, tags=["境界不能顧客","代表太郎"], rank="A", body="正常ノート本文")
p11 = write_note(folder, "🟥事故_境界不能顧客.md", UUID_A, unclosed=True, body="本文相当(終了---なし)")
with open(p11, "rb") as f:
    before11 = f.read()
status, code, resp = invoke_update_customer_identity(folder, "境界不能顧客", "代表太郎", "", "A", UUID_A)
check("Case11_YAML_BODY_BOUNDARY_UNRESOLVEDで停止", status == "NG" and code == "YAML_BODY_BOUNDARY_UNRESOLVED", f"{status}/{code}")
with open(p11, "rb") as f:
    after11 = f.read()
check("Case11_元ファイル完全不変", before11 == after11)

# ---- Case12: 途中で注入失敗 → 全リネーム・内容が完全ロールバック ----
reset()
folder = os.path.join(BASE, "ロールバック顧客")
write_note(folder, "🟨契約_ロールバック顧客.md", UUID_A, tags=["ロールバック顧客","代表太郎"], rank="A", body="本文1")
write_note(folder, "🟥事故_ロールバック顧客.md", UUID_A, tags=["ロールバック顧客","代表太郎"], rank="A", body="本文2")
before_files = {}
for fn in os.listdir(folder):
    with open(os.path.join(folder, fn), "rb") as f:
        before_files[fn] = f.read()
status, code, resp = invoke_update_customer_identity(folder, "新ロールバック顧客", "代表太郎", "", "A", UUID_A, fail_at_index=1)
check("Case12_NOTE_UPDATE_FAILEDでロールバック", status == "NG" and code == "NOTE_UPDATE_FAILED", f"{status}/{code}")
check("Case12_フォルダ名は元に戻っている", os.path.isdir(folder) and not os.path.isdir(os.path.join(BASE, "新ロールバック顧客" + SUFFIX_A)))
after_files = {}
if os.path.isdir(folder):
    for fn in os.listdir(folder):
        with open(os.path.join(folder, fn), "rb") as f:
            after_files[fn] = f.read()
check("Case12_全ファイル名・内容が完全復元", before_files == after_files, f"before={list(before_files.keys())} after={list(after_files.keys())}")

# ---- Case13: 正規化後、UUID+noteType優先解決(task f)が正しく機能する(重複ノート作成なし) ----
reset()
folder = os.path.join(BASE, "統合確認顧客")
write_note(folder, "🟨契約_統合確認顧客.md", UUID_A, tags=["統合確認顧客","代表太郎"], rank="A")
status, code, resp = invoke_update_customer_identity(folder, "統合確認顧客", "代表太郎", "", "A", UUID_A)
new_folder = os.path.join(BASE, "統合確認顧客" + SUFFIX_A)
canonical_note = f"🟨契約_統合確認顧客{SUFFIX_A}.md"
# legacy CHECKのGet-UuidNoteTypeMatches相当: 同一プレフィックス+同一UUIDのノートが1件だけ見つかるはず
matches = []
if os.path.isdir(new_folder):
    for fn in os.listdir(new_folder):
        if fn.startswith("🟨契約_"):
            hdr = get_yaml_header_lines(os.path.join(new_folder, fn))
            u = get_yaml_scalar_value(hdr, "UUID:")
            if u.upper() == UUID_A.upper():
                matches.append(fn)
check("Case13_正規化後もUUID優先解決で1件のみ一致(重複作成なし)", len(matches) == 1 and matches[0] == canonical_note, f"matches={matches}")

print(f"{'ケース':55s} {'結果':6s} 詳細")
pass_count = 0
for name, res, detail in results:
    print(f"{name:55s} {res:6s} {detail}")
    if res == "PASS":
        pass_count += 1
print()
print(f"{pass_count} / {len(results)} PASS")
sys.exit(0 if pass_count == len(results) else 1)
