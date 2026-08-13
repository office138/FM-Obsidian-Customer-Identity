// QuickAdd Script
// 2026/01/26 copy-selection-clipboard-clean-prefix.js
// 選択テキストの各行先頭から
// 「- [ ](+任意のスペース)」「>(+任意のスペース)」「半角/全角スペース」を削除してクリップボードへコピー

module.exports = async () => {
  const editor = app.workspace.activeEditor?.editor;
  if (!editor) {
    new Notice("エディタが見つかりません。");
    return;
  }

  const selected = editor.getSelection();
  if (!selected) {
    new Notice("テキストを選択してください。");
    return;
  }

  const cleaned = selected
    .split(/\r?\n/)
    .map(line =>
      line.replace(
        /^(?:-\s\[\s\]\s*|>\s*|[\u0020\u3000]+)/,
        ""
      )
    )
    .join("\n");

  // Obsidian Desktop（Electron）
  try {
    const { clipboard } = require("electron");
    clipboard.writeText(cleaned);
    new Notice("クリップボードへコピーしました。");
    return;
  } catch (_) {}

  // フォールバック
  try {
    await navigator.clipboard.writeText(cleaned);
    new Notice("クリップボードへコピーしました。");
  } catch (e) {
    console.error(e);
    new Notice("クリップボードへのコピーに失敗しました。");
  }
};
