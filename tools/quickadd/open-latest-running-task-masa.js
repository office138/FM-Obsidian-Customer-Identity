/*
2026/01/26 Ver01.00
QuickAdd - Macro (open-latest-running-task-masa.js)
機能:
- フォルダ「50_masaタスク管理」直下から、【実行中】*.md の “最新” を開く
  優先順位:
  1) ファイル名が「【実行中】YYYYMMDD(曜).md」に一致するものだけ対象
  2) YYYYMMDD が最大のファイル
  3) 同一 YYYYMMDD が複数なら、更新日時 (modified time) が最新のファイル
- サブフォルダは無視
- 同じペインで開く
*/

module.exports = async (params) => {
  const app = params.app;
  const vault = app.vault;

  const TARGET_FOLDER = "50_masaタスク管理";
  const PREFIX = "【実行中】";
  const EXT = ".md";

  // 例: 【実行中】20260126(月).md
  const re = /^【実行中】(\d{8})\([^)]+\)\.md$/;

  // --- helpers ---
  const toIntDate = (yyyymmdd) => {
    // "20260126" -> 20260126 (number)
    const n = Number(yyyymmdd);
    return Number.isFinite(n) ? n : -1;
  };

  const getMtime = (tfile) => {
    // Obsidian: file.stat.mtime is ms since epoch
    return (tfile && tfile.stat && typeof tfile.stat.mtime === "number") ? tfile.stat.mtime : 0;
  };

  // --- main ---
  const folder = vault.getAbstractFileByPath(TARGET_FOLDER);

  if (!folder || folder.children === undefined) {
    new Notice(`フォルダが見つかりません: ${TARGET_FOLDER}`);
    return;
  }

  // folder.children は AbstractFile の配列（直下のみ）
  const candidates = folder.children
    .filter(f => f && f.path && f.path.startsWith(TARGET_FOLDER + "/"))
    .filter(f => f.extension === "md") // .md のみ
    .filter(f => f.name.startsWith(PREFIX))
    .map(f => {
      const m = re.exec(f.name);
      if (!m) return null;
      const dateStr = m[1]; // YYYYMMDD
      return {
        file: f,
        dateInt: toIntDate(dateStr),
        mtime: getMtime(f),
      };
    })
    .filter(Boolean);

  if (candidates.length === 0) {
    new Notice(`「${TARGET_FOLDER}」に ${PREFIX}*.md が見つかりません`);
    return;
  }

  // ソート: 日付 desc → mtime desc
  candidates.sort((a, b) => {
    if (b.dateInt !== a.dateInt) return b.dateInt - a.dateInt;
    return b.mtime - a.mtime;
  });

  const latest = candidates[0].file;

  // 同じペインで開く
  await app.workspace.getLeaf(false).openFile(latest, { active: true });

  // 任意: 通知（不要ならコメントアウト）
  // new Notice(`開きました: ${latest.name}`);
};
