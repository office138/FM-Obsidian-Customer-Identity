# filename: diff_core.py
import csv
import os
import re
from datetime import datetime

# --- 既存機能: CSV/MD解析 ---

def load_csv_data(csv_path):
    """CSV読み込み (UTF-8-SIG / CP932 自動判別)"""
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    rows = []
    try:
        with open(csv_path, 'r', encoding='utf-8-sig', newline='') as f:
            reader = csv.reader(f)
            rows = [row for row in reader if row]
    except UnicodeDecodeError:
        with open(csv_path, 'r', encoding='cp932', newline='') as f:
            reader = csv.reader(f)
            rows = [row for row in reader if row]
    return rows

def parse_md_table_in_sections(md_path, target_sections, target_columns_map):
    """指定セクション配下のMarkdownテーブルのみ解析"""
    if not os.path.exists(md_path):
        return []

    data_list = []
    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    table_pattern = re.compile(r'^\s*\|.*\|\s*$')
    current_section = None
    is_target_scope = False
    
    # 必須ヘッダーキーワード
    required_headers = {"証券番号", "状態", "事故日"}

    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        
        if stripped.startswith('#'):
            header_text = stripped.lstrip('#').strip()
            current_section = header_text
            is_target_scope = any(header_text.startswith(t) for t in target_sections)
            continue
        
        if not is_target_scope:
            continue

        if not table_pattern.match(stripped):
            continue
        if "---" in stripped: continue 
        
        cols = [c.strip() for c in stripped.split('|')]
        if len(cols) < 3: continue 
        real_cols = cols[1:-1]

        columns_set = set(real_cols)
        match_count = sum(1 for h in required_headers if any(h in c for c in columns_set))
        if match_count >= 2:
            continue

        row_data = {}
        max_idx = max(target_columns_map.values())
        if len(real_cols) <= max_idx:
            print(f"Warning: Line {line_num} in {os.path.basename(md_path)} has insufficient columns. Skipped.")
            continue

        for key, idx in target_columns_map.items():
            row_data[key] = real_cols[idx]
        
        data_list.append(row_data)

    return data_list

def write_report(output_path, lines):
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines))

# --- 新規機能: ダッシュボード生成 ---

def analyze_diff_file(md_path):
    """
    突合結果ファイルを解析して状態と件数を返す
    戻り値: { 'status': 'OK'|'NG'|'NONE', 'fm_only': int, 'ob_only': int }
    """
    if not os.path.exists(md_path):
        return {'status': 'NONE', 'fm_only': 0, 'ob_only': 0}

    with open(md_path, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.splitlines()

    # 差分なし判定
    if "差異はありません" in content:
        return {'status': 'OK', 'fm_only': 0, 'ob_only': 0}

    # 件数カウント (簡易ロジック: ヘッダー配下のテーブル行数)
    fm_count = 0
    ob_count = 0
    current_mode = None # 'FM' or 'OB'

    table_row_pattern = re.compile(r'^\s*\|.*\|\s*$')

    for line in lines:
        stripped = line.strip()
        
        if "## ① FM Only" in stripped:
            current_mode = 'FM'
            continue
        elif "## ② OB Only" in stripped:
            current_mode = 'OB'
            continue
        elif stripped.startswith('#'):
            current_mode = None
            continue

        if current_mode and table_row_pattern.match(stripped):
            if "---" in stripped or "証券番号" in stripped: # 区切り線やヘッダーは除外
                continue
            
            if current_mode == 'FM':
                fm_count += 1
            elif current_mode == 'OB':
                ob_count += 1
    
    # どちらかに差分があればNG
    status = 'NG' if (fm_count > 0 or ob_count > 0) else 'OK'
    return {'status': status, 'fm_only': fm_count, 'ob_only': ob_count}

def generate_dashboard(cust_dir):
    """ダッシュボード生成メイン関数"""
    
    # ファイルパス定義
    contract_diff = os.path.join(cust_dir, "突合結果(契約).md")
    jiko_diff     = os.path.join(cust_dir, "突合結果(事故).md")
    dashboard_path = os.path.join(cust_dir, "突合ダッシュボード.md")

    # 解析実行
    res_contract = analyze_diff_file(contract_diff)
    res_jiko     = analyze_diff_file(jiko_diff)

    # アイコン定義
    ICON_OK   = "🟢"
    ICON_NG   = "🔴"
    ICON_WARN = "🟡"

    # --- 総合判定ロジック ---
    # 契約: OK/NG/NONE, 事故: OK/NG/NONE
    # NONE(未実行)はNG扱いとして判定フローに流すか、専用表示にする
    
    total_status_str = ""
    
    c_stat = res_contract['status']
    j_stat = res_jiko['status']

    # 判定マトリクス
    if c_stat == 'OK' and j_stat == 'OK':
        total_status_str = f"{ICON_OK} 完全整合"
    elif c_stat == 'NG' and j_stat == 'OK':
        total_status_str = f"{ICON_WARN} 契約要確認"
    elif c_stat == 'OK' and j_stat == 'NG':
        total_status_str = f"{ICON_WARN} 事故要確認"
    elif c_stat == 'NG' and j_stat == 'NG':
        total_status_str = f"{ICON_NG} 両方差異"
    else:
        # どちらかが未実行の場合など
        total_status_str = "⚪ 未完了あり"

    # --- Markdown生成 ---
    lines = []
    lines.append(f"最終更新：{datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append("")
    lines.append("---")
    lines.append("")

    # 1. 契約セクション
    lines.append("## 契約整合性")
    if c_stat == 'NONE':
        lines.append("状態：⚪ 未実行")
    else:
        icon = ICON_OK if c_stat == 'OK' else ICON_NG
        diff_sum = res_contract['fm_only'] + res_contract['ob_only']
        lines.append(f"状態：{icon} {'正常' if c_stat == 'OK' else '差異あり'}")
        lines.append(f"差分件数：{diff_sum}件")
    lines.append("[[突合結果(契約)]]")
    lines.append("")
    lines.append("---")

    # 2. 事故セクション
    lines.append("## 事故整合性")
    if j_stat == 'NONE':
        lines.append("状態：⚪ 未実行")
    else:
        icon = ICON_OK if j_stat == 'OK' else ICON_NG
        lines.append(f"状態：{icon} {'正常' if j_stat == 'OK' else '差異あり'}")
        lines.append(f"FM Only：{res_jiko['fm_only']}件")
        lines.append(f"OB Only：{res_jiko['ob_only']}件")
    lines.append("[[突合結果(事故)]]")
    lines.append("")
    lines.append("---")

    # 3. 総合判定
    lines.append("## 総合判定")
    lines.append(total_status_str)

    # 書込
    write_report(dashboard_path, lines)
    print(f"\n>> ダッシュボード更新完了: {os.path.basename(dashboard_path)}")