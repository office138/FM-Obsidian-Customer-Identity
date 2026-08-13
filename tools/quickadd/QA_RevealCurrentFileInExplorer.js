// QA_RevealCurrentFileInExplorer.js（QuickAdd User Script 用）
// 現在開いているファイルを、左のファイルエクスプローラで選択状態にする
// 方針：
// 1) Obsidian公式コマンドをそのまま利用（最も安定・保守不要）
// 2) 最低限のエラーハンドリングで堅牢性を確保

module.exports = async (params) => {
  const _app = params?.app ?? app;

  try {
    _app.commands.executeCommandById("file-explorer:reveal-active-file");
  } catch (e) {
    console.error("[QA_RevealCurrentFileInExplorer]", e);
    try {
      new Notice("現在ファイルの表示に失敗しました。");
    } catch (_) {}
  }
};