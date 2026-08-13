// QuickAdd: 選択テキスト整形（空行削除 / 行頭 > 付与 / >直後スペース補正 / *→＊）
// 仕様（確定）
// - インデントがあっても無視して「> 」は必ず行の1文字目に付与する
// - 既に「>」で始まる行は「>text」→「> text」に正規化（> の直後は半角スペース1つ）
// - 空欄行（空 or 空白のみ）は削除
// - 半角アスタリスク「*」は全角「＊」へ置換
// - 選択範囲にコードブロックは含まれない前提

module.exports = async (params) => {
  const { Notice, MarkdownView } = require("obsidian");
  const view = params.app.workspace.getActiveViewOfType(MarkdownView);
  const editor = view?.editor;

  if (!editor) {
    new Notice("エディタが見つかりません。Markdownノートを開いてください。");
    return;
  }

  const selected = editor.getSelection();
  if (!selected) {
    new Notice("テキストを選択してから実行してください。");
    return;
  }

  // 改行コードを保持（CRLF/ LF）
  const hasCRLF = selected.includes("\r\n");
  const normalized = selected.replace(/\r\n/g, "\n");

  const lines = normalized.split("\n");
  const out = [];

  for (let line of lines) {
    // 空欄行（空 or 空白のみ）は削除
    if (/^\s*$/.test(line)) continue;

    // 半角 * → 全角 ＊（行全体に適用）
    line = line.replace(/\*/g, "＊");

    // 行頭のインデントは捨てる（> は常に先頭）
    const trimmedLeft = line.replace(/^\s+/, "");

    // 既に > で始まるなら「> 」に正規化、無ければ付与
    let processed;
    if (trimmedLeft.startsWith(">")) {
      processed = trimmedLeft.replace(/^>\s*/, "> ");
    } else {
      processed = `> ${trimmedLeft}`;
    }

    out.push(processed);
  }

  const result = out.join("\n");
  editor.replaceSelection(hasCRLF ? result.replace(/\n/g, "\r\n") : result);
};
