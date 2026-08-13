/**
 * QuickAdd Script
 * 目的：
 * 1) アクティブノートを「999_履歴保管(古いファイル)」へコピー退避
 * - ファイル名: 「■削除前(ユーザー名)_オリジナル名」
 * ※ユーザー名はPCのログイン名を自動取得
 * - 重複時: 末尾に数字を直接付加 (例: ...20260129(木)1.md)
 * * 2) 以下の前処理を実行
 * - 「> [!danger] ... 予定タスク(追加) ...」以降をすべてカット
 * - 「**※予定タスクを一番下に追加しました。**」行を削除し、不要な空行を詰める
 * * 3) 退避後、以下2箇所の「完了タスク（- [x] / ~~）」を削除し、空行を詰める
 * - [!quote] 【終了タスク】 ブロック
 * - [!todo]  【更改】 ブロック
 * * 4) 「終了タスクブロック」と「実行中タスクブロック」の間は空行2行を確保
 */

module.exports = async (params) => {
  const { app } = params;
  const Notice = app?.constructor?.Notice || window.Notice;

  const activeFile = app.workspace.getActiveFile();
  if (!activeFile) {
    new Notice("アクティブなノートがありません。");
    return;
  }

  // =========
  // 設定：ユーザー名の取得とフォルダ設定
  // =========
  
  // ユーザー名の取得ロジック
  let userName = "unknown";
  try {
    // PC版 Obsidian (Node.js環境) であれば os モジュールが使える
    const os = require('os');
    const userInfo = os.userInfo();
    userName = userInfo.username; 
  } catch (e) {
    // モバイル版など os モジュールが使えない場合のフォールバック
    userName = "mobile";
    console.log("ユーザー名の取得に失敗したため、mobileとして扱います:", e);
  }

  const BACKUP_FOLDER = "999_履歴保管(古いファイル)";
  const BACKUP_PREFIX = `■削除前(${userName})_`;

  // 削除対象の特定行（完全一致または部分一致で除去）
  const TARGET_REMOVE_LINE = "**※予定タスクを一番下に追加しました。**";
  
  // 以降をすべて削除する境界線（部分一致）
  const DANGER_BLOCK_MARKER = "予定タスク(追加)"; // "> [!danger] ... 🔴" 等が含まれる行

  // =========
  // Utility
  // =========
  const ensureFolderExists = async (folderPath) => {
    const existing = app.vault.getAbstractFileByPath(folderPath);
    if (existing) return;

    const parts = folderPath.split("/").filter(Boolean);
    let current = "";
    for (const p of parts) {
      current = current ? `${current}/${p}` : p;
      const f = app.vault.getAbstractFileByPath(current);
      if (!f) await app.vault.createFolder(current);
    }
  };

  const fileExists = (path) => !!app.vault.getAbstractFileByPath(path);

  const splitNameExt = (filename) => {
    const idx = filename.lastIndexOf(".");
    if (idx <= 0) return { name: filename, ext: "" };
    return { name: filename.slice(0, idx), ext: filename.slice(idx) };
  };

  // ファイル名重複時の処理（末尾に数字を直接付加：file1.md, file2.md...）
  const makeUniquePath = (folder, filename) => {
    const { name, ext } = splitNameExt(filename);
    
    // まずそのままのファイル名をチェック
    let candidate = `${folder}/${name}${ext}`;
    if (!fileExists(candidate)) return candidate;

    // 重複時のルール: ファイル名の後ろに数字を付加
    let n = 1;
    while (true) {
      candidate = `${folder}/${name}${n}${ext}`;
      if (!fileExists(candidate)) return candidate;
      n++;
    }
  };

  const collapseBlankLines = (arrLines) => {
    const out = [];
    let prevBlank = false;

    for (const l of arrLines) {
      const isBlank = l.trim() === "";
      if (isBlank) {
        if (!prevBlank) out.push("");
        prevBlank = true;
      } else {
        out.push(l);
        prevBlank = false;
      }
    }

    // 先頭/末尾の空行を除去
    while (out.length && out[0].trim() === "") out.shift();
    while (out.length && out[out.length - 1].trim() === "") out.pop();

    return out;
  };

  // 完了タスク判定
  const isDoneTaskLine = (l) => {
    if (l.trim() === "") return false;
    if (l.includes("~~")) return true;
    return /^\s*(?:>\s*)?[-*]\s+\[x\]\s+/i.test(l);
  };

  // ブロック見出し検出
  const isEndHeader = (l) => l.includes("【終了タスク】") && l.includes("[!quote]");
  const isRunHeader = (l) => l.includes("【実行中タスク】") && l.includes("[!todo]");
  const isKokaiHeader = (l) => l.includes("【更改】") && l.includes("[!todo]");
  // Dangerブロック検出
  const isDangerHeader = (l) => l.includes(DANGER_BLOCK_MARKER) && l.includes("[!danger]");

  // 指定範囲 [start, endExclusive) を「完了タスク削除＆空行整理」して返す
  const cleanBlock = (blockLines) => {
    let deleted = 0;
    const kept = [];

    for (const l of blockLines) {
      if (isDoneTaskLine(l)) {
        deleted++;
      } else {
        kept.push(l);
      }
    }

    const cleaned = collapseBlankLines(kept);
    return { cleaned, deleted };
  };

  // =========
  // 1) 退避コピー（削除前バックアップ）
  // =========
  await ensureFolderExists(BACKUP_FOLDER);

  const originalName = activeFile.name;
  const backupName = `${BACKUP_PREFIX}${originalName}`;
  const backupPath = makeUniquePath(BACKUP_FOLDER, backupName);

  await app.vault.copy(activeFile, backupPath);

  // =========
  // 2) 本体編集
  // =========
  const text = await app.vault.read(activeFile);
  let lines = text.split("\n");

  // --- 追加機能 A: Dangerブロック以降を全削除 ---
  // 先にこれを実行することで、削除対象領域内の不要な計算を避けます
  const dangerIdx = lines.findIndex(isDangerHeader);
  if (dangerIdx !== -1) {
    // Danger行が見つかったら、それより手前だけを残す（Danger行自体も削除されます）
    lines = lines.slice(0, dangerIdx);
  }

  // --- 追加機能 B: 特定の行を削除して空行を詰める ---
  const tempLines = [];
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes(TARGET_REMOVE_LINE)) {
      // 該当行は削除（tempLinesに追加しない）

      // 該当行が消えることで前後の空行が連続してしまうのを防ぐため、
      // 削除した行の「直前が空行」かつ「直後も空行」だった場合、直後の空行を1つ詰める
      const isPrevBlank = tempLines.length === 0 || tempLines[tempLines.length - 1].trim() === "";
      const isNextBlank = (i + 1 < lines.length) && lines[i + 1].trim() === "";
      
      if (isPrevBlank && isNextBlank) {
        i++; // 次の空行をスキップして詰める
      }
    } else {
      tempLines.push(lines[i]);
    }
  }
  lines = tempLines;

  // --- 既存機能: ヘッダー位置の再計算 ---
  const endHeaderIdx = lines.findIndex(isEndHeader);
  const runHeaderIdx = lines.findIndex(isRunHeader);
  const kokaiHeaderIdx = lines.findIndex(isKokaiHeader);

  if (endHeaderIdx === -1 || runHeaderIdx === -1 || endHeaderIdx >= runHeaderIdx) {
    new Notice("見出し構成が不正なため、タスク整理はスキップしました。\n（バックアップ作成済）");
    return;
  }

  let deletedEnd = 0;
  let deletedKokai = 0;

  // --- 終了タスクブロック（見出し直後～実行中見出し直前）
  const endBlockStart = endHeaderIdx + 1;
  const endBlockEndExclusive = runHeaderIdx;

  const endBlockLines = lines.slice(endBlockStart, endBlockEndExclusive);
  const endRes = cleanBlock(endBlockLines);
  deletedEnd = endRes.deleted;

  // 終了タスクブロックと実行中ブロックの間：空行2行を必ず確保
  const endBlockFinal = [...endRes.cleaned, "", ""];

  // --- 更改ブロック（見出し直後～ファイル末尾）
  let kokaiBlockFinal = null;
  if (kokaiHeaderIdx !== -1) {
    const kokaiBlockStart = kokaiHeaderIdx + 1;
    // lines.length は Danger削除後の長さになっています
    const kokaiBlockEndExclusive = lines.length; 

    const kokaiBlockLines = lines.slice(kokaiBlockStart, kokaiBlockEndExclusive);
    const kokaiRes = cleanBlock(kokaiBlockLines);
    deletedKokai = kokaiRes.deleted;

    kokaiBlockFinal = kokaiRes.cleaned.length ? [...kokaiRes.cleaned, ""] : [];
  }

  // --- 全文再構築
  let newLines;

  if (kokaiHeaderIdx === -1) {
    // 更改が無い場合
    newLines = [
      ...lines.slice(0, endBlockStart),
      ...endBlockFinal,
      ...lines.slice(runHeaderIdx),
    ];
  } else {
    // 更改もある場合
    newLines = [
      ...lines.slice(0, endBlockStart),
      ...endBlockFinal,
      ...lines.slice(runHeaderIdx, kokaiHeaderIdx + 1), 
      ...(kokaiBlockFinal ?? []),
    ];
  }

  await app.vault.modify(activeFile, newLines.join("\n"));

  new Notice(
    `バックアップ: ${backupPath.split("/").pop()}\n` +
    `完了削除: ${deletedEnd + deletedKokai}件`
  );
};