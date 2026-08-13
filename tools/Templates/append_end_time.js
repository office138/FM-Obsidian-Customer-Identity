module.exports = () => {
  // 1. エディタの情報を取得
  const view = app.workspace.activeLeaf.view;
  if (!view || view.getViewType() !== "markdown") {
    new Notice("エラー:ノートが開かれていません");
    return "";
  }
  
  const editor = view.editor;
  const cursor = editor.getCursor();
  
  // 2. カーソルがある行の文字を読み取る
  const lineText = editor.getLine(cursor.line);

  // 3. 行の中から「※開始:HH:mm」を探す
  // （全角・半角コロン両方に対応できるようにしています）
  const match = lineText.match(/※開始[:：](\d{2}:\d{2})/);

  if (!match) {
    new Notice("エラー：この行に「※開始:HH:mm」が見つかりません！");
    return "";
  }

  // 4. 時間計算
  const originalStartText = match[0]; // "※開始：09:00" という文字そのもの
  const startTimeStr = match[1];      // "09:00" という時間部分
  
  const now = window.moment();
  const endTimeStr = now.format("HH:mm");
  const startTime = window.moment(startTimeStr, "HH:mm");

  // 差分計算
  let diff = now.diff(startTime);
  if (diff < 0) diff += 24 * 60 * 60 * 1000;
  
  const duration = window.moment.utc(diff).format("HH:mm");

  // 5. 新しい文字列を作成（ハイライト == で囲む）
  // 出力形式： ==※開始：09:00 → 終了：09:30 (00:30)==
  const newText = `==${originalStartText} → 終了:${endTimeStr} (${duration})== `;

  // 6. 行の一部を置換する
  const newLineContent = lineText.replace(originalStartText, newText);
  editor.setLine(cursor.line, newLineContent);

  // カーソルを行末に移動（便利にするため）
  editor.setCursor(cursor.line, newLineContent.length);

  // 7. Templater側では何も挿入しない（すでにeditor.setLineで書き換えたため）
  return "";
};