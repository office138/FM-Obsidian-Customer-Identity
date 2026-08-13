# filename: diff_checker_jiko.py
# 機能：事故一覧突合 (ClaimNo/お問合せ番号ベース・状態正規化・スペース無視・テーブル修正・FM状態表示変更版)

import sys
import os
import re
from datetime import datetime
import diff_core

# --- 設定 ---
# CSVの項目定義 (ヘッダーなし4項目)
FM_IDX = {
    'date': 0,    # 1. 事故日
    'status': 1,  # 2. 状態 (1-9)
    'policy': 2,  # 3. 証券番号
    'claim': 3    # 4. ClaimNo
}

# Obsidian側のテーブル定義 (0始まりのインデックス)
OB_IDX_MAP = {'date': 0, 'status': 1, 'policy': 4, 'claim': 7, 'inquiry': 8, 'content': 2}

# ターゲットセクション
TARGET_SECTIONS = ["🚨対応中", "✅完了"]

def normalize_date(date_str):
    if not date_str: return "-"
    clean = date_str.replace('-', '/').replace('.', '/').strip()
    return clean

def normalize_str(s):
    if not s: return ""
    return s.strip().replace("　", "")

# --- 独自解析関数 (スペース無視対応版) ---
def parse_md_table_robust(md_path, target_sections, target_columns_map):
    if not os.path.exists(md_path):
        return []

    data_list = []
    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    table_pattern = re.compile(r'^\s*\|.*\|\s*$')
    is_target_scope = False
    
    required_headers = {"証券番号", "状態", "事故日"}

    for line in lines:
        stripped = line.strip()
        
        if stripped.startswith('#'):
            header_clean = stripped.lstrip('#').strip().replace(" ", "").replace("　", "")
            is_target_scope = any(header_clean.startswith(t.replace(" ", "").replace("　", "")) for t in target_sections)
            continue
        
        if not is_target_scope:
            continue

        if not table_pattern.match(stripped):
            continue
        if "---" in stripped: continue 
        
        cols = [c.strip() for c in stripped.split('|')]
        real_cols = cols[1:-1]

        columns_set = set(real_cols)
        match_count = sum(1 for h in required_headers if any(h in c for c in columns_set))
        if match_count >= 2:
            continue

        max_idx = max(target_columns_map.values())
        if len(real_cols) <= max_idx:
            continue

        row_data = {}
        for key, idx in target_columns_map.items():
            row_data[key] = real_cols[idx]
        
        data_list.append(row_data)

    return data_list

# --- 状態正規化ロジック ---
def get_normalized_fm_status(val_str):
    try:
        val = int(val_str)
        if 7 <= val <= 9:
            return "完了"
        else:
            return "完了以外"
    except:
        return "完了以外" 

def get_normalized_ob_status(val_str):
    s = normalize_str(val_str)
    if s == "完了":
        return "完了"
    else:
        return "完了以外"

def main():
    if len(sys.argv) < 3:
        print("Usage: python diff_checker_jiko.py <csv_path> <md_path>")
        sys.exit(1)

    csv_path = sys.argv[1]
    md_path = sys.argv[2]
    cust_dir = os.path.dirname(md_path)

    print(f"--- 事故データ突合開始 (Robust Mode) ---")

    try:
        raw_fm = diff_core.load_csv_data(csv_path)
        raw_ob = parse_md_table_robust(md_path, TARGET_SECTIONS, OB_IDX_MAP)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

    # FMデータ整形
    fm_list = []
    for r in raw_fm:
        if len(r) < 4: continue 
        s_date = normalize_date(r[FM_IDX['date']])
        s_status_raw = normalize_str(r[FM_IDX['status']])
        s_policy = normalize_str(r[FM_IDX['policy']])
        s_claim = normalize_str(r[FM_IDX['claim']])
        s_status_norm = get_normalized_fm_status(s_status_raw)

        fm_list.append({
            'date': s_date,
            'status_raw': s_status_raw,
            'status_norm': s_status_norm,
            'policy': s_policy,
            'claim': s_claim,
            'matched': False
        })

    # OBデータ整形
    ob_list = []
    for r in raw_ob:
        s_date = normalize_date(r['date'])
        s_status_raw = normalize_str(r['status'])
        s_policy = normalize_str(r['policy'])
        s_claim = normalize_str(r['claim'])
        s_inquiry = normalize_str(r['inquiry'])
        s_content = r.get('content', '')
        s_status_norm = get_normalized_ob_status(s_status_raw)

        ob_list.append({
            'date': s_date,
            'status_raw': s_status_raw,
            'status_norm': s_status_norm,
            'policy': s_policy,
            'claim': s_claim,
            'inquiry': s_inquiry,
            'content': s_content,
            'matched': False
        })

    # 突合ロジック
    ob_claim_map = {}
    ob_inquiry_map = {}
    for idx, item in enumerate(ob_list):
        if item['claim']: ob_claim_map[item['claim']] = idx
        if item['inquiry']: ob_inquiry_map[item['inquiry']] = idx

    list_mismatch = [] 

    for fm_item in fm_list:
        target_claim = fm_item['claim']
        if not target_claim: continue

        matched_idx = ob_claim_map.get(target_claim)
        if matched_idx is None:
            matched_idx = ob_inquiry_map.get(target_claim)
            
        if matched_idx is not None:
            ob_item = ob_list[matched_idx]
            fm_item['matched'] = True
            ob_item['matched'] = True
            
            if fm_item['status_norm'] != ob_item['status_norm']:
                list_mismatch.append({'fm': fm_item, 'ob': ob_item})

    list_fm_only = [x for x in fm_list if not x['matched']]
    list_ob_only = [x for x in ob_list if not x['matched']]

    # --- レポート生成 ---
    report_lines = []
    report_lines.append(f"**事故データ突合レポート**")
    report_lines.append(f"実行日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    report_lines.append("")

    has_diff = False

    if list_fm_only:
        has_diff = True
        report_lines.append("## ① FM Only")
        report_lines.append("Obsidianに存在しない、またはキー(ClaimNo/お問合せNo)が一致しないデータ")
        report_lines.append("")
        report_lines.append("|事故日|証券番号|ClaimNo|状態(FM)|")
        report_lines.append("|---|---|---|---|")
        for x in list_fm_only:
            report_lines.append(f"|{x['date']}|{x['policy']}|{x['claim']}|{x['status_norm']}|")
        report_lines.append("")

    if list_ob_only:
        has_diff = True
        report_lines.append("## ② OB Only")
        report_lines.append("FMデータに存在しない(キー不一致)データ")
        report_lines.append("")
        report_lines.append("|事故日|証券番号|ClaimNo|お問合せNo|状態(OB)|事故内容|")
        report_lines.append("|---|---|---|---|---|---|")
        for x in list_ob_only:
            report_lines.append(f"|{x['date']}|{x['policy']}|{x['claim']}|{x['inquiry']}|{x['status_raw']}|{x['content']}|")
        report_lines.append("")

    if list_mismatch:
        has_diff = True
        report_lines.append("## ③ 状態不一致")
        report_lines.append("キーは一致したが、完了判定が食い違っているデータ")
        report_lines.append("")
        report_lines.append("|事故日|証券番号|ClaimNo|状態(FM)|状態(OB)|判定|")
        report_lines.append("|---|---|---|---|---|---|")
        for m in list_mismatch:
            f = m['fm']
            o = m['ob']
            diff_str = f"{f['status_norm']} ⇔ {o['status_norm']}"
            # ★修正箇所: f['status_raw'] を f['status_norm'] に変更
            report_lines.append(f"|{f['date']}|{f['policy']}|{f['claim']}|{f['status_norm']}|{o['status_raw']}|{diff_str}|")
        report_lines.append("")

    if not has_diff:
        report_lines.append("## ✅ 差異はありません")
        report_lines.append("すべてのデータが一致しています。")

    out_file = os.path.join(cust_dir, "突合結果(事故).md")
    diff_core.write_report(out_file, report_lines)
    print(f"\n突合完了: {out_file}")

    diff_core.generate_dashboard(cust_dir)

if __name__ == "__main__":
    main()