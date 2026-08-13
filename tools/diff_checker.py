# filename: diff_checker.py
# 機能：FM最新一覧ポータルとOB契約一覧を突合 (契約用)

from datetime import datetime
import sys
import csv
import os
import re
import diff_core # 共通エンジン読み込み

def parse_currency(value_str):
    """カンマ区切りの円表記を数値に変換"""
    if not value_str: return 0
    clean_str = re.sub(r'[^\d]', '', value_str)
    return int(clean_str) if clean_str else 0

def get_obsidian_data(md_path):
    data = {}
    if not os.path.exists(md_path): return None, "File Not Found"

    with open(md_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    in_table = False
    table_row_pattern = re.compile(r'^\s*\|.*\|\s*$')

    for line in lines:
        line = line.strip()
        # 契約一覧セクションの後のテーブルを探す
        if "## 契約一覧" in line:
            in_table = True
            continue
        
        if in_table and table_row_pattern.match(line):
            if "---" in line: continue
            if "証券番号" in line and "合計保険料" in line: continue
            if "**合計**" in line: continue

            cols = [c.strip() for c in line.split('|')]
            if len(cols) < 7: continue

            policy_num = cols[1]
            ins_type = cols[4]
            premium_str = cols[6]

            if "生保" in ins_type: continue
            if policy_num:
                data[policy_num] = parse_currency(premium_str)
    
    return data, None

def main():
    if len(sys.argv) < 3:
        print("Usage: python diff_checker.py <csv_path> <md_path>")
        sys.exit(1)

    csv_path = sys.argv[1]
    md_path = sys.argv[2]
    cust_dir = os.path.dirname(md_path)
    
    # 1. FileMaker CSV読み込み
    fm_data = {}
    try:
        rows = diff_core.load_csv_data(csv_path) # diff_core利用
        for row in rows:
            if len(row) < 2: continue
            p_num = row[0].strip()
            p_val = parse_currency(row[1])
            fm_data[p_num] = p_val
    except Exception as e:
        print(f"Error reading CSV: {e}")
        sys.exit(1)

    # 2. Obsidian MD読み込み
    ob_data, error = get_obsidian_data(md_path)
    if error:
        # ファイルがない場合は空として続行（FM Only全件として出す運用の場合）
        ob_data = {}

    # 3. 突合処理
    fm_keys = set(fm_data.keys())
    ob_keys = set(ob_data.keys())

    diff_fm_only = fm_keys - ob_keys
    diff_ob_only = ob_keys - fm_keys
    diff_mismatch = []

    common_keys = fm_keys & ob_keys
    for k in common_keys:
        if fm_data[k] != ob_data[k]:
            diff_mismatch.append((k, fm_data[k], ob_data[k]))

    # 4. 結果出力（ファイル名変更: 突合結果(契約).md）
    output_path = os.path.join(cust_dir, "突合結果(契約).md")

    report_content = []
    # report_content.append(f"# 突合結果(契約)")
    report_content.append(f"実行日時: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    has_diff = False

    if diff_fm_only:
        has_diff = True
        report_content.append("## ① FM Only")
        report_content.append("| 証券番号 | FM保険料 |")
        report_content.append("|---|---|")
        for k in diff_fm_only:
            report_content.append(f"| {k} | {fm_data[k]:,} |")
        report_content.append("")

    if diff_ob_only:
        has_diff = True
        report_content.append("## ② OB Only")
        report_content.append("| 証券番号 | OB保険料 |")
        report_content.append("|---|---|")
        for k in diff_ob_only:
            report_content.append(f"| {k} | {ob_data[k]:,} |")
        report_content.append("")

    if diff_mismatch:
        has_diff = True
        report_content.append("## ③ 金額不一致")
        report_content.append("| 証券番号 | FM保険料 | OB保険料 | 差額 |")
        report_content.append("|---|---|---|---|")
        for k, fm_val, ob_val in diff_mismatch:
            diff_val = fm_val - ob_val
            report_content.append(f"| {k} | {fm_val:,} | {ob_val:,} | {diff_val:,} |")
        report_content.append("")

    if not has_diff:
        report_content.append("## ✅ 差異はありません")
        report_content.append("すべてのデータが一致しています。")

    diff_core.write_report(output_path, report_content)
    print(f"契約突合完了: {output_path}")

    # ★★★ ダッシュボード更新 ★★★
    diff_core.generate_dashboard(cust_dir)

if __name__ == "__main__":
    main()